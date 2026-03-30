package main

import (
	"bufio"
	"encoding/binary"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Steam struct {
		APIKey string `yaml:"api_key"`
		AppID  int    `yaml:"app_id"`
	} `yaml:"steam"`
	Paths struct {
		LogsDir      string `yaml:"logs_dir"`
		CommandsFile string `yaml:"commands_file"`
	} `yaml:"paths"`
	Rules struct {
		MinHours            int  `yaml:"min_hours"`
		BlockFamilySharing  bool `yaml:"block_family_sharing"`
		BlockPrivateProfile bool `yaml:"block_private_profile"`
		KickDelaySeconds    int  `yaml:"kick_delay_seconds"`
	} `yaml:"rules"`
	Messages struct {
		NotEnoughHours string `yaml:"not_enough_hours"`
		FamilySharing  string `yaml:"family_sharing"`
		PrivateProfile string `yaml:"private_profile"`
		SteamAPIError  string `yaml:"steam_api_error"`
	} `yaml:"messages"`
	RCON struct {
		Host     string `yaml:"host"`
		Port     int    `yaml:"port"`
		Password string `yaml:"password"`
	} `yaml:"rcon"`
	AntiGrief struct {
		Enabled           bool   `yaml:"enabled"`
		MaxRemovals       int    `yaml:"max_removals"`
		TimeWindowSeconds int    `yaml:"time_window_seconds"`
		Action            string `yaml:"action"`
		Message           string `yaml:"message"`
	} `yaml:"anti_grief"`
	WhitelistSteam []string `yaml:"whitelist_steam"`
	WhitelistGrief []string `yaml:"whitelist_grief"`
	Log       struct {
		File  string `yaml:"file"`
		Level string `yaml:"level"`
	} `yaml:"log"`
}

// Steam API responses
type OwnedGamesResponse struct {
	Response struct {
		GameCount int `json:"game_count"`
		Games     []struct {
			AppID           int `json:"appid"`
			PlaytimeForever int `json:"playtime_forever"` // minutes
		} `json:"games"`
	} `json:"response"`
}

type PlayerSummaryResponse struct {
	Response struct {
		Players []struct {
			SteamID                  string `json:"steamid"`
			CommunityVisibilityState int    `json:"communityvisibilitystate"`
			PersonaName              string `json:"personaname"`
		} `json:"players"`
	} `json:"response"`
}

type SharedGameResponse struct {
	Response struct {
		OwnerSteamID string `json:"ownersteamid"`
	} `json:"response"`
}

type CachedResult struct {
	Passed  bool
	Hours   int
	Reason  string
	CheckedAt time.Time
}

var (
	cfg    Config
	logger *log.Logger
	cache  = make(map[string]*CachedResult) // steamID -> result
)

func loadConfig(path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return fmt.Errorf("cannot read config: %w", err)
	}
	return yaml.Unmarshal(data, &cfg)
}

func isWhitelistedSteam(username, steamID string) bool {
	for _, entry := range cfg.WhitelistSteam {
		if entry == steamID || entry == username {
			return true
		}
	}
	return false
}

func isWhitelistedGrief(username, steamID string) bool {
	for _, entry := range cfg.WhitelistGrief {
		if entry == steamID || entry == username {
			return true
		}
	}
	return false
}

func steamAPIGet(url string, result interface{}) error {
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		return fmt.Errorf("HTTP error: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return fmt.Errorf("HTTP status %d", resp.StatusCode)
	}

	return json.NewDecoder(resp.Body).Decode(result)
}

// Check if profile is public
func checkProfileVisibility(steamID string) (bool, string, error) {
	url := fmt.Sprintf("https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=%s&steamids=%s",
		cfg.Steam.APIKey, steamID)

	var resp PlayerSummaryResponse
	if err := steamAPIGet(url, &resp); err != nil {
		return false, "", err
	}

	if len(resp.Response.Players) == 0 {
		return false, "", fmt.Errorf("player not found")
	}

	player := resp.Response.Players[0]
	// 3 = public, 1 = private
	return player.CommunityVisibilityState == 3, player.PersonaName, nil
}

// Check if playing via Family Sharing
func checkFamilySharing(steamID string) (bool, error) {
	url := fmt.Sprintf("https://api.steampowered.com/IPlayerService/IsPlayingSharedGame/v1/?key=%s&steamid=%s&appid_playing=%d",
		cfg.Steam.APIKey, steamID, cfg.Steam.AppID)

	var resp SharedGameResponse
	if err := steamAPIGet(url, &resp); err != nil {
		return false, err
	}

	// ownersteamid != "0" means family sharing
	return resp.Response.OwnerSteamID != "0" && resp.Response.OwnerSteamID != "", nil
}

// Get playtime in hours
func getPlaytimeHours(steamID string) (int, error) {
	url := fmt.Sprintf("https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=%s&steamid=%s",
		cfg.Steam.APIKey, steamID)

	var resp OwnedGamesResponse
	if err := steamAPIGet(url, &resp); err != nil {
		return 0, err
	}

	for _, game := range resp.Response.Games {
		if game.AppID == cfg.Steam.AppID {
			return game.PlaytimeForever / 60, nil
		}
	}

	// Game not found in library — could be private or doesn't own it
	return -1, nil
}

// Source RCON protocol
func rconSendPacket(conn net.Conn, id int32, pktType int32, body string) error {
	payload := []byte(body)
	size := int32(4 + 4 + len(payload) + 2) // id + type + body + 2 null bytes
	buf := new(bytes.Buffer)
	binary.Write(buf, binary.LittleEndian, size)
	binary.Write(buf, binary.LittleEndian, id)
	binary.Write(buf, binary.LittleEndian, pktType)
	buf.Write(payload)
	buf.Write([]byte{0, 0})
	_, err := conn.Write(buf.Bytes())
	return err
}

func rconReadPacket(conn net.Conn) (int32, int32, string, error) {
	conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	var size, id, pktType int32
	if err := binary.Read(conn, binary.LittleEndian, &size); err != nil {
		return 0, 0, "", err
	}
	if err := binary.Read(conn, binary.LittleEndian, &id); err != nil {
		return 0, 0, "", err
	}
	if err := binary.Read(conn, binary.LittleEndian, &pktType); err != nil {
		return 0, 0, "", err
	}
	body := make([]byte, size-8)
	if _, err := io.ReadFull(conn, body); err != nil {
		return 0, 0, "", err
	}
	// Trim null terminators
	return id, pktType, strings.TrimRight(string(body), "\x00"), nil
}

func rconExec(command string) (string, error) {
	addr := fmt.Sprintf("%s:%d", cfg.RCON.Host, cfg.RCON.Port)
	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		return "", fmt.Errorf("RCON connect failed: %w", err)
	}
	defer conn.Close()

	// Auth (type 3)
	if err := rconSendPacket(conn, 1, 3, cfg.RCON.Password); err != nil {
		return "", fmt.Errorf("RCON auth send failed: %w", err)
	}
	id, _, _, err := rconReadPacket(conn)
	if err != nil {
		return "", fmt.Errorf("RCON auth read failed: %w", err)
	}
	if id == -1 {
		return "", fmt.Errorf("RCON auth failed: bad password")
	}

	// Command (type 2)
	if err := rconSendPacket(conn, 2, 2, command); err != nil {
		return "", fmt.Errorf("RCON command send failed: %w", err)
	}
	_, _, response, err := rconReadPacket(conn)
	if err != nil {
		return "", fmt.Errorf("RCON command read failed: %w", err)
	}

	return response, nil
}

func sendMessageAndKick(username, message string) {
	// Send personal message via file bridge (server Lua sends to specific player via loadstring)
	if message != "" {
		logger.Printf("ACTION: personal message to %s", username)
		f, err := os.OpenFile(cfg.Paths.CommandsFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err == nil {
			f.WriteString(fmt.Sprintf("msguser %s %s\n", username, message))
			f.Close()
		}
	}

	// Wait for player to read message
	if cfg.Rules.KickDelaySeconds > 0 {
		time.Sleep(time.Duration(cfg.Rules.KickDelaySeconds) * time.Second)
	}

	// Kick via RCON (server-side, cannot be bypassed)
	logger.Printf("ACTION: RCON kick %s", username)
	resp, err := rconExec(fmt.Sprintf("kickuser %s", username))
	if err != nil {
		logger.Printf("ERROR: RCON kick failed: %v", err)
	} else {
		logger.Printf("RCON response: %s", resp)
	}
}

func formatMessage(template string, vars map[string]string) string {
	result := template
	for k, v := range vars {
		result = strings.ReplaceAll(result, "{"+k+"}", v)
	}
	return result
}

func checkPlayer(username, steamID string) {
	logger.Printf("Checking player: %s (SteamID: %s)", username, steamID)

	if isWhitelistedSteam(username, steamID) {
		logger.Printf("PASS: %s is whitelisted", username)
		return
	}

	// Check cache (persists until restart)
	if cached, ok := cache[steamID]; ok {
		if cached.Passed {
			logger.Printf("PASS: %s — cached (%d hours)", username, cached.Hours)
		} else {
			logger.Printf("KICK: %s — cached (%s)", username, cached.Reason)
			go sendMessageAndKick(username, cached.Reason)
		}
		return
	}

	// 1. Check profile visibility
	isPublic, personaName, err := checkProfileVisibility(steamID)
	if err != nil {
		logger.Printf("WARN: Steam API error for %s: %v — letting player through", username, err)
		return
	}

	if personaName != "" {
		logger.Printf("  Steam name: %s", personaName)
	}

	if !isPublic {
		if cfg.Rules.BlockPrivateProfile {
			logger.Printf("KICK: %s — private profile", username)
			msg := cfg.Messages.PrivateProfile
			cache[steamID] = &CachedResult{Passed: false, Reason: msg}
			go sendMessageAndKick(username, msg)
			return
		}
		logger.Printf("WARN: %s has private profile, cannot verify hours", username)
		return
	}

	// 2. Check Family Sharing
	if cfg.Rules.BlockFamilySharing {
		isShared, err := checkFamilySharing(steamID)
		if err != nil {
			logger.Printf("WARN: Family sharing check failed for %s: %v — skipping", username, err)
		} else if isShared {
			logger.Printf("KICK: %s — Family Sharing detected", username)
			msg := cfg.Messages.FamilySharing
			cache[steamID] = &CachedResult{Passed: false, Reason: msg}
			go sendMessageAndKick(username, msg)
			return
		}
	}

	// 3. Check playtime
	if cfg.Rules.MinHours > 0 {
		hours, err := getPlaytimeHours(steamID)
		if err != nil {
			logger.Printf("WARN: Playtime check failed for %s: %v — skipping", username, err)
			return
		}

		if hours < 0 {
			if cfg.Rules.BlockPrivateProfile {
				logger.Printf("KICK: %s — game list is hidden (profile public but games private)", username)
				cache[steamID] = &CachedResult{Passed: false, Reason: cfg.Messages.PrivateProfile}
				go sendMessageAndKick(username, cfg.Messages.PrivateProfile)
			} else {
				logger.Printf("WARN: %s — game list hidden, cannot verify hours, letting through", username)
			}
			return
		}

		if hours < cfg.Rules.MinHours {
			logger.Printf("KICK: %s — only %d hours (min: %d)", username, hours, cfg.Rules.MinHours)
			msg := formatMessage(cfg.Messages.NotEnoughHours, map[string]string{
				"min_hours": fmt.Sprintf("%d", cfg.Rules.MinHours),
				"hours":     fmt.Sprintf("%d", hours),
			})
			cache[steamID] = &CachedResult{Passed: false, Hours: hours, Reason: msg}
			go sendMessageAndKick(username, msg)
			return
		}

		logger.Printf("PASS: %s — %d hours", username, hours)
		cache[steamID] = &CachedResult{Passed: true, Hours: hours}
	} else {
		logger.Printf("PASS: %s — hours check disabled", username)
	}
}

// Find the latest *_user.txt across logs dir and all logs_* subdirectories
func findLatestUserLog(logsDir string) string {
	var best string
	var bestName string

	// Check files in root logs dir
	entries, err := os.ReadDir(logsDir)
	if err != nil {
		return ""
	}

	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), "_user.txt") {
			if entry.Name() > bestName {
				bestName = entry.Name()
				best = filepath.Join(logsDir, entry.Name())
			}
		}
		// Check inside logs_* subdirectories
		if entry.IsDir() && strings.HasPrefix(entry.Name(), "logs_") {
			subDir := filepath.Join(logsDir, entry.Name())
			files, err := os.ReadDir(subDir)
			if err != nil {
				continue
			}
			for _, f := range files {
				if !f.IsDir() && strings.HasSuffix(f.Name(), "_user.txt") {
					if f.Name() > bestName {
						bestName = f.Name()
						best = filepath.Join(subDir, f.Name())
					}
				}
			}
		}
	}
	return best
}

// Parse PZ user.txt line for "fully connected" events
// Format: [23-03-26 20:14:54.597] 76561198034616829 "Kosmonavt" fully connected (11668,6928,0).
func parseUserLine(line string) (steamID, username string, ok bool) {
	if !strings.Contains(line, "fully connected") {
		return "", "", false
	}

	// Find SteamID (first number after ] )
	idx := strings.Index(line, "] ")
	if idx < 0 {
		return "", "", false
	}
	rest := line[idx+2:]
	parts := strings.SplitN(rest, " ", 2)
	if len(parts) < 2 {
		return "", "", false
	}
	steamID = parts[0]

	// Find username in quotes
	q1 := strings.Index(rest, "\"")
	if q1 < 0 {
		return "", "", false
	}
	q2 := strings.Index(rest[q1+1:], "\"")
	if q2 < 0 {
		return "", "", false
	}
	username = rest[q1+1 : q1+1+q2]

	return steamID, username, true
}

func watchAndTail(logsDir string) {
	var currentPath string
	var file *os.File
	var reader *bufio.Reader

	for {
		// Check for newer file every 10 seconds
		latest := findLatestUserLog(logsDir)

		if latest != "" && latest != currentPath {
			// New file found — switch
			if file != nil {
				file.Close()
			}

			var err error
			file, err = os.Open(latest)
			if err != nil {
				logger.Printf("ERROR: cannot open %s: %v", latest, err)
				time.Sleep(10 * time.Second)
				continue
			}

			if currentPath == "" {
				// First start — seek to end (don't process old entries)
				file.Seek(0, io.SeekEnd)
				logger.Printf("Tailing (from end): %s", latest)
			} else {
				// Server restarted — read new file from beginning
				logger.Printf("Server restarted, switched to: %s", latest)
			}

			currentPath = latest
			reader = bufio.NewReader(file)
		}

		if reader == nil {
			logger.Printf("Waiting for PZ user.txt in: %s", logsDir)
			time.Sleep(10 * time.Second)
			continue
		}

		// Read available lines
		hasData := false
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				break
			}
			hasData = true
			line = strings.TrimSpace(line)
			if steamID, username, ok := parseUserLine(line); ok {
				logger.Printf("Player connected: %s (SteamID: %s)", username, steamID)
				go checkPlayer(username, steamID)
			}
		}

		if !hasData {
			time.Sleep(1 * time.Second)
		}
	}
}

// --- Anti-grief: monitor map.txt for mass object removal ---

// Track removal timestamps per player
var griefTracker = make(map[string][]time.Time) // username -> list of removal times
var griefKicked = make(map[string]bool)          // already kicked this session

// Find latest *_map.txt
func findLatestMapLog(logsDir string) string {
	var best string
	var bestName string

	entries, err := os.ReadDir(logsDir)
	if err != nil {
		return ""
	}

	for _, entry := range entries {
		if !entry.IsDir() && strings.HasSuffix(entry.Name(), "_map.txt") {
			if entry.Name() > bestName {
				bestName = entry.Name()
				best = filepath.Join(logsDir, entry.Name())
			}
		}
		if entry.IsDir() && strings.HasPrefix(entry.Name(), "logs_") {
			subDir := filepath.Join(logsDir, entry.Name())
			files, err := os.ReadDir(subDir)
			if err != nil {
				continue
			}
			for _, f := range files {
				if !f.IsDir() && strings.HasSuffix(f.Name(), "_map.txt") {
					if f.Name() > bestName {
						bestName = f.Name()
						best = filepath.Join(subDir, f.Name())
					}
				}
			}
		}
	}
	return best
}

// Parse map.txt line: [24-03-26 08:57:04.219] 76561198034616829 "Kosmonavt" removed IsoObject (...) at 12274,6932,0.
func parseMapRemoval(line string) (steamID, username string, ok bool) {
	if !strings.Contains(line, "\" removed ") {
		return "", "", false
	}

	idx := strings.Index(line, "] ")
	if idx < 0 {
		return "", "", false
	}
	rest := line[idx+2:]
	parts := strings.SplitN(rest, " ", 2)
	if len(parts) < 2 {
		return "", "", false
	}
	steamID = parts[0]

	q1 := strings.Index(rest, "\"")
	if q1 < 0 {
		return "", "", false
	}
	q2 := strings.Index(rest[q1+1:], "\"")
	if q2 < 0 {
		return "", "", false
	}
	username = rest[q1+1 : q1+1+q2]
	return steamID, username, true
}

func trackRemoval(steamID, username string) {
	if griefKicked[username] {
		return
	}

	now := time.Now()
	window := time.Duration(cfg.AntiGrief.TimeWindowSeconds) * time.Second

	griefTracker[username] = append(griefTracker[username], now)
	cutoff := now.Add(-window)
	times := griefTracker[username]
	start := 0
	for start < len(times) && times[start].Before(cutoff) {
		start++
	}
	griefTracker[username] = times[start:]

	count := len(griefTracker[username])
	if count >= cfg.AntiGrief.MaxRemovals {
		griefKicked[username] = true
		logger.Printf("GRIEF: %s (SteamID: %s) — %d removals in %ds! Action: %s",
			username, steamID, count, cfg.AntiGrief.TimeWindowSeconds, cfg.AntiGrief.Action)

		switch cfg.AntiGrief.Action {
		case "kick":
			go sendMessageAndKick(username, cfg.AntiGrief.Message)
		case "ban":
			go func(u, sid string, c int) {
				reason := fmt.Sprintf("Anti-grief: %d removals in %ds", c, cfg.AntiGrief.TimeWindowSeconds)
				logger.Printf("ACTION: RCON banid %s — %s", sid, reason)
				rconExec(fmt.Sprintf("banuser %s", u))
				// Collect removed objects for restore
				collectAndRestore(sid, u)
			}(username, steamID, count)
		}
	}
}

// Parse all removed objects by a player from map.txt, write restore commands
func collectAndRestore(steamID, username string) {
	latest := findLatestMapLog(cfg.Paths.LogsDir)
	if latest == "" {
		logger.Printf("RESTORE: no map.txt found")
		return
	}

	file, err := os.Open(latest)
	if err != nil {
		logger.Printf("RESTORE: cannot open %s: %v", latest, err)
		return
	}
	defer file.Close()

	// Collect all "removed" lines for this player
	var restoreItems []string
	scanner := bufio.NewScanner(file)
	searchPrefix := fmt.Sprintf("%s \"%s\" removed ", steamID, username)

	for scanner.Scan() {
		line := scanner.Text()
		idx := strings.Index(line, "] ")
		if idx < 0 {
			continue
		}
		rest := line[idx+2:]
		if !strings.HasPrefix(rest, searchPrefix) {
			continue
		}

		// Extract sprite name: removed IsoObject (sprite_name) at x,y,z.
		p1 := strings.Index(rest, "(")
		p2 := strings.Index(rest, ")")
		a := strings.Index(rest, " at ")
		if p1 < 0 || p2 < 0 || a < 0 {
			continue
		}
		sprite := rest[p1+1 : p2]
		coords := strings.TrimSuffix(rest[a+4:], ".")
		restoreItems = append(restoreItems, fmt.Sprintf("restore %s %s", sprite, coords))
	}

	if len(restoreItems) == 0 {
		logger.Printf("RESTORE: no objects to restore for %s", username)
		return
	}

	logger.Printf("RESTORE: writing %d restore commands for %s", len(restoreItems), username)

	f, err := os.OpenFile(cfg.Paths.CommandsFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		logger.Printf("RESTORE: cannot open commands file: %v", err)
		return
	}
	defer f.Close()

	for _, cmd := range restoreItems {
		f.WriteString(cmd + "\n")
	}
}

func watchMapLog(logsDir string) {
	var currentPath string
	var file *os.File
	var reader *bufio.Reader

	for {
		latest := findLatestMapLog(logsDir)

		if latest != "" && latest != currentPath {
			if file != nil {
				file.Close()
			}

			var err error
			file, err = os.Open(latest)
			if err != nil {
				logger.Printf("ERROR: cannot open map log %s: %v", latest, err)
				time.Sleep(10 * time.Second)
				continue
			}

			if currentPath == "" {
				file.Seek(0, io.SeekEnd)
				logger.Printf("Anti-grief tailing (from end): %s", latest)
			} else {
				logger.Printf("Anti-grief switched to: %s", latest)
			}

			currentPath = latest
			reader = bufio.NewReader(file)
		}

		if reader == nil {
			time.Sleep(10 * time.Second)
			continue
		}

		hasData := false
		for {
			line, err := reader.ReadString('\n')
			if err != nil {
				break
			}
			hasData = true
			line = strings.TrimSpace(line)
			if steamID, username, ok := parseMapRemoval(line); ok {
				if !isWhitelistedGrief(username, steamID) {
					trackRemoval(steamID, username)
				}
			}
		}

		if !hasData {
			time.Sleep(1 * time.Second)
		}
	}
}

func main() {
	configPath := "config.yaml"
	if len(os.Args) > 1 {
		configPath = os.Args[1]
	}

	if err := loadConfig(configPath); err != nil {
		log.Fatalf("Config error: %v", err)
	}

	// Setup logger
	var logWriter io.Writer = os.Stdout
	if cfg.Log.File != "" {
		f, err := os.OpenFile(cfg.Log.File, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			log.Fatalf("Cannot open log file: %v", err)
		}
		defer f.Close()
		logWriter = io.MultiWriter(os.Stdout, f)
	}
	logger = log.New(logWriter, "[steam-guard] ", log.LstdFlags)

	logger.Printf("Steam Guard started")
	logger.Printf("  PZ logs dir: %s", cfg.Paths.LogsDir)
	logger.Printf("  Commands file: %s", cfg.Paths.CommandsFile)
	logger.Printf("  Min hours: %d", cfg.Rules.MinHours)
	logger.Printf("  Block family sharing: %v", cfg.Rules.BlockFamilySharing)
	logger.Printf("  Block private profile: %v", cfg.Rules.BlockPrivateProfile)
	logger.Printf("  Whitelist steam: %d, grief: %d", len(cfg.WhitelistSteam), len(cfg.WhitelistGrief))

	if cfg.Steam.APIKey == "" || cfg.Steam.APIKey == "YOUR_STEAM_API_KEY_HERE" {
		logger.Fatal("Steam API key not configured! Get one at https://steamcommunity.com/dev/apikey")
	}

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go watchAndTail(cfg.Paths.LogsDir)

	if cfg.AntiGrief.Enabled {
		logger.Printf("  Anti-grief: %d removals / %ds = kick", cfg.AntiGrief.MaxRemovals, cfg.AntiGrief.TimeWindowSeconds)
		go watchMapLog(cfg.Paths.LogsDir)
	}

	<-sigChan
	logger.Printf("Steam Guard stopped")
}
