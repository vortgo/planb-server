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
	"os/signal"
	"strconv"
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
		ConnectLog   string `yaml:"connect_log"`
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
	Whitelist []string `yaml:"whitelist"`
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

func isWhitelisted(username, steamID string) bool {
	id, _ := strconv.ParseInt(steamID, 10, 64)
	for _, entry := range cfg.Whitelist {
		if entry == username {
			return true
		}
		entryID, err := strconv.ParseInt(entry, 10, 64)
		if err == nil && id != 0 {
			// Match ±1 to handle Lua double precision loss
			if id == entryID || id-1 == entryID || id+1 == entryID {
				return true
			}
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
	resp, err := rconExec(fmt.Sprintf("kick \"%s\"", username))
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

// Lua doubles lose precision for SteamIDs (>2^53).
// Try ±1 to find the real one using GetOwnedGames (strict about exact ID).
func fixSteamID(steamID string) string {
	id, err := strconv.ParseInt(steamID, 10, 64)
	if err != nil {
		return steamID
	}

	for _, delta := range []int64{0, -1, 1} {
		candidate := fmt.Sprintf("%d", id+delta)
		hours, err := getPlaytimeHours(candidate)
		if err == nil && hours >= 0 {
			if delta != 0 {
				logger.Printf("  SteamID corrected: %s -> %s (precision fix)", steamID, candidate)
			}
			return candidate
		}
	}
	return steamID
}

func checkPlayer(username, steamID string) {
	logger.Printf("Checking player: %s (SteamID: %s)", username, steamID)

	if isWhitelisted(username, steamID) {
		logger.Printf("PASS: %s is whitelisted", username)
		return
	}

	// Fix Lua double precision loss for SteamIDs
	steamID = fixSteamID(steamID)

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

func tailFile(path string) {
	// Wait for file to exist
	for {
		if _, err := os.Stat(path); err == nil {
			break
		}
		logger.Printf("Waiting for connect log: %s", path)
		time.Sleep(5 * time.Second)
	}

	file, err := os.Open(path)
	if err != nil {
		logger.Fatalf("Cannot open connect log: %v", err)
	}
	defer file.Close()

	// Seek to end (only process new lines)
	file.Seek(0, io.SeekEnd)

	reader := bufio.NewReader(file)
	logger.Printf("Tailing connect log: %s", path)

	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			time.Sleep(1 * time.Second)
			continue
		}

		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Format: "2026-03-23 23:32:43 connect Username SteamID IP"
		parts := strings.Fields(line)
		if len(parts) < 5 {
			continue
		}

		// parts[0]=date, parts[1]=time, parts[2]=action, parts[3]=username, parts[4]=steamid
		action := parts[2]
		username := parts[3]
		steamID := parts[4]

		if action == "connect" {
			go checkPlayer(username, steamID)
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
	logger.Printf("  Connect log: %s", cfg.Paths.ConnectLog)
	logger.Printf("  Commands file: %s", cfg.Paths.CommandsFile)
	logger.Printf("  Min hours: %d", cfg.Rules.MinHours)
	logger.Printf("  Block family sharing: %v", cfg.Rules.BlockFamilySharing)
	logger.Printf("  Block private profile: %v", cfg.Rules.BlockPrivateProfile)
	logger.Printf("  Whitelist: %d entries", len(cfg.Whitelist))

	if cfg.Steam.APIKey == "" || cfg.Steam.APIKey == "YOUR_STEAM_API_KEY_HERE" {
		logger.Fatal("Steam API key not configured! Get one at https://steamcommunity.com/dev/apikey")
	}

	// Handle graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	go tailFile(cfg.Paths.ConnectLog)

	<-sigChan
	logger.Printf("Steam Guard stopped")
}
