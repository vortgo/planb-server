if isServer() then return end

local SEND_INTERVAL = 60 -- секунд между отправками
local lastSendTime = 0

local PERKS_PHYSICAL = {"Fitness", "Strength", "Sprinting", "Lightfoot", "Nimble"}
local PERKS_COMBAT = {"Blunt", "Axe", "Spear", "Maintenance", "SmallBlade", "LongBlade", "SmallBlunt"}
local PERKS_FIREARM = {"Aiming", "Reloading"}
local PERKS_CRAFTING = {"Cooking", "Woodwork", "Farming", "Electricity", "Blacksmith", "MetalWelding", "Mechanics", "Tailoring", "Melting", "Mansonry", "FlintKnapping", "Pottery", "Carving", "Glassmaking", "AnimalCare"}
local PERKS_SURVIVALIST = {"Fishing", "Trapping", "PlantScavenging", "Tracking", "Doctor"}
local PERKS_FARMING = {"Farming", "Husbandry", "Butchering"}

local function getPerkCategoryScore(player, category)
    local score = 0
    for _, label in ipairs(category) do
        local perk = Perks[label]
        if perk then
            score = score + player:getPerkLevel(perk)
        end
    end
    return score
end

local function collectAndSend(player)
    local now = os.time()
    if now - lastSendTime < SEND_INTERVAL then return end
    lastSendTime = now

    local data = {
        username = player:getUsername(),
        steamID = getSteamIDFromUsername(player:getUsername()),
        isAlive = player:isAlive(),
        zombieKills = player:getZombieKills(),
        survivorKills = player:getSurvivorKills(),
        hoursSurvived = player:getHoursSurvived(),
        perks = {
            physical = getPerkCategoryScore(player, PERKS_PHYSICAL),
            combat = getPerkCategoryScore(player, PERKS_COMBAT),
            firearm = getPerkCategoryScore(player, PERKS_FIREARM),
            crafting = getPerkCategoryScore(player, PERKS_CRAFTING),
            survivalist = getPerkCategoryScore(player, PERKS_SURVIVALIST),
            farming = getPerkCategoryScore(player, PERKS_FARMING),
        },
    }

    sendClientCommand(player, "SZStats", "playerData", data)
end

local function onPlayerUpdate(player)
    if not player or not player:isAlive() then return end
    collectAndSend(player)
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
