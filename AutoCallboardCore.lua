local Core = {}

local DEFAULTS = {
    targetName = "Callboard",
    summonSpell = "Summon Callboard",
    summonSpellID = 600647,
    summonDuration = 30,
    summonCooldown = 45,
    rerollFrame = "ObjectivesMainFrame.rerollBtn",
    objectivePrefix = "ObjectiveFrame",
    objectiveButtonField = "selectBtn",
    autoAccept = true,
    autoAcceptShared = false,
    autoCurrentInstanceQuest = false,
    autoSelect = false,
    maxRerolls = 50,
    rerollDelay = 1.6,
    knownQuests = {},
    desiredQuests = {},
    characterProfiles = {},
    questPanelExpanded = false,
    debug = {
        enabled = false,
        mouseWatch = false,
        sniffer = false,
        maxLog = 120,
    },
    goldTracker = {
        totalSpent = 0,
        trackedQuestCount = 0,
        lastQuestSpent = 0,
    },
    buttonShown = true,
    button = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
    minimap = {
        shown = true,
        angle = 225,
    },
}

local AUTO_CURRENT_INSTANCE_WARNING_TEXT = "Not all dungeons and raids have an AutoCallboard quest. If no matching quest exists, AutoCallboard will keep rolling until it reaches your limit or you stop it."

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function objectiveTextParts(value)
    local text = trim(value)
    local cleanText, zoneOrSort, questType = string.match(text, "^(.-),%s*(%d+)%s*,%s*(%d+)%s*%.?%s*$")

    if cleanText then
        return trim(cleanText), tonumber(zoneOrSort) or 0, tonumber(questType) or 0
    end

    return text, 0, 0
end

-- The Callboard categories are a fixed, small set. The server API has been seen
-- delivering reward magnitudes (e.g. 601921, 230570, 5443) in the questType
-- field, so any value outside this set is treated as "unknown" (0).
local VALID_QUEST_TYPES = { [1] = true, [2] = true, [3] = true, [4] = true }

function Core.sanitizeQuestType(value)
    value = tonumber(value) or 0
    if VALID_QUEST_TYPES[value] then
        return value
    end

    return 0
end

local function containsAny(value, needles)
    value = string.lower(trim(value))

    for i = 1, table.getn(needles) do
        if string.find(value, needles[i], 1, true) then
            return true
        end
    end

    return false
end

local function normalizeMatchText(value)
    value = string.lower(trim(value))
    value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    value = value:gsub("[^%w]+", " ")
    value = value:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    return value
end

local function appendUniqueNormalized(values, seen, value)
    value = normalizeMatchText(value)

    if value == "" or seen[value] then
        return
    end

    seen[value] = true
    table.insert(values, value)
end

local PROFESSION_HINTS = {
    "bulk order:",
    "crafting materials:",
    "saronite",
    "cobalt bar",
    "titanium",
    "eternal earth",
    "eternal air",
    "eternal fire",
    "eternal water",
    "eternal shadow",
    "eternal life",
    "icethorn",
    "adder's tongue",
    "lichbloom",
    "frost lotus",
    "borean leather",
    "arctic fur",
    "dragonfin",
    "glacial salmon",
    "constrictor grass",
}

local RAID_HINTS = {
    "malygos",
    "kelthuzad",
    "kel'thuzad",
    "sartharion",
    "naxxramas",
    "obsidian sanctum",
    "eye of eternity",
    "construct quarter",
}

local DUNGEON_HINTS = {
    "keristrasza",
    "ingvar",
    "king ymiron",
    "prophet tharon'ja",
    "tharon'ja",
    "utgarde pinnacle",
    "drak'tharon keep",
    "the nexus.",
    "the nexus ",
}

local CURRENT_INSTANCE_ALIASES = {
    ["utgarde keep"] = { "utgarde keep", "ingvar", "ingvar the plunderer" },
    ["utgarde pinnacle"] = { "utgarde pinnacle", "king ymiron", "ymiron" },
    ["azjol nerub"] = { "azjol nerub", "anub arak" },
    ["the oculus"] = { "the oculus", "oculus", "ley guardian eregos", "eregos" },
    ["oculus"] = { "the oculus", "oculus", "ley guardian eregos", "eregos" },
    ["halls of lightning"] = { "halls of lightning", "loken" },
    ["halls of stone"] = { "halls of stone", "sjonnir", "sjonnir the ironshaper" },
    ["the culling of stratholme"] = { "the culling of stratholme", "culling of stratholme", "mal ganis" },
    ["culling of stratholme"] = { "the culling of stratholme", "culling of stratholme", "mal ganis" },
    ["drak tharon keep"] = { "drak tharon keep", "prophet tharon ja", "the prophet tharon ja", "tharon ja" },
    ["gundrak"] = { "gundrak", "gal darah" },
    ["ahn kahet the old kingdom"] = { "ahn kahet", "old kingdom", "herald volazj" },
    ["ahn kahet"] = { "ahn kahet", "old kingdom", "herald volazj" },
    ["the violet hold"] = { "the violet hold", "violet hold", "cyanigosa" },
    ["violet hold"] = { "the violet hold", "violet hold", "cyanigosa" },
    ["the nexus"] = { "the nexus", "keristrasza" },
    ["nexus"] = { "the nexus", "keristrasza" },
    ["trial of the champion"] = { "trial of the champion", "the black knight", "black knight" },
    ["the forge of souls"] = { "the forge of souls", "forge of souls", "devourer of souls" },
    ["forge of souls"] = { "the forge of souls", "forge of souls", "devourer of souls" },
    ["pit of saron"] = { "pit of saron", "overlord tyrannus", "tyrannus" },
    ["halls of reflection"] = { "halls of reflection", "escaped from arthas", "marwyn", "falric" },
    ["naxxramas"] = { "naxxramas", "kel thuzad", "kelthuzad" },
    ["the eye of eternity"] = { "the eye of eternity", "eye of eternity", "malygos" },
    ["eye of eternity"] = { "the eye of eternity", "eye of eternity", "malygos" },
    ["the obsidian sanctum"] = { "the obsidian sanctum", "obsidian sanctum", "sartharion" },
    ["obsidian sanctum"] = { "the obsidian sanctum", "obsidian sanctum", "sartharion" },
    ["vault of archavon"] = { "vault of archavon", "toravon", "archavon", "emalon", "koralon" },
}

local OPEN_WORLD_TITLE_PREFIXES = {
    "a growing menace:",
    "clear the roads",
    "no mercy:",
    "pacify ",
    "sweep and clear:",
    "storm peaks trophy",
}

local function copyDefaults()
    return {
        targetName = DEFAULTS.targetName,
        summonSpell = DEFAULTS.summonSpell,
        summonSpellID = DEFAULTS.summonSpellID,
        summonDuration = DEFAULTS.summonDuration,
        summonCooldown = DEFAULTS.summonCooldown,
        rerollFrame = DEFAULTS.rerollFrame,
        objectivePrefix = DEFAULTS.objectivePrefix,
        objectiveButtonField = DEFAULTS.objectiveButtonField,
        autoAccept = DEFAULTS.autoAccept,
        autoAcceptShared = DEFAULTS.autoAcceptShared,
        autoCurrentInstanceQuest = DEFAULTS.autoCurrentInstanceQuest,
        autoSelect = DEFAULTS.autoSelect,
        maxRerolls = DEFAULTS.maxRerolls,
        rerollDelay = DEFAULTS.rerollDelay,
        knownQuests = {},
        desiredQuests = {},
        characterProfiles = {},
        questPanelExpanded = DEFAULTS.questPanelExpanded,
        debug = {
            enabled = DEFAULTS.debug.enabled,
            mouseWatch = DEFAULTS.debug.mouseWatch,
            sniffer = DEFAULTS.debug.sniffer,
            maxLog = DEFAULTS.debug.maxLog,
        },
        goldTracker = {
            totalSpent = DEFAULTS.goldTracker.totalSpent,
            trackedQuestCount = DEFAULTS.goldTracker.trackedQuestCount,
            lastQuestSpent = DEFAULTS.goldTracker.lastQuestSpent,
        },
        buttonShown = DEFAULTS.buttonShown,
        button = {
            point = DEFAULTS.button.point,
            relativePoint = DEFAULTS.button.relativePoint,
            x = DEFAULTS.button.x,
            y = DEFAULTS.button.y,
        },
        minimap = {
            shown = DEFAULTS.minimap.shown,
            angle = DEFAULTS.minimap.angle,
        },
    }
end

function Core.defaultState()
    return copyDefaults()
end

function Core.autoCurrentInstanceWarningText()
    return AUTO_CURRENT_INSTANCE_WARNING_TEXT
end

function Core.mergeState(saved)
    local state = copyDefaults()

    if type(saved) ~= "table" then
        return state
    end

    if trim(saved.targetName) ~= "" then
        state.targetName = trim(saved.targetName)
    end

    if type(saved.summonSpell) == "string" then
        state.summonSpell = trim(saved.summonSpell)
    end

    if type(saved.summonSpellID) == "number" then
        state.summonSpellID = saved.summonSpellID
    end

    if type(saved.summonDuration) == "number" and saved.summonDuration >= 1 then
        state.summonDuration = saved.summonDuration
    end

    if type(saved.summonCooldown) == "number" and saved.summonCooldown >= 1 then
        state.summonCooldown = saved.summonCooldown
    end

    if trim(saved.rerollFrame) ~= "" then
        state.rerollFrame = trim(saved.rerollFrame)
    end

    if trim(saved.objectivePrefix) ~= "" then
        state.objectivePrefix = trim(saved.objectivePrefix)
    end

    if trim(saved.objectiveButtonField) ~= "" then
        state.objectiveButtonField = trim(saved.objectiveButtonField)
    end

    if type(saved.autoAccept) == "boolean" then
        state.autoAccept = saved.autoAccept
    end

    if type(saved.autoAcceptShared) == "boolean" then
        state.autoAcceptShared = saved.autoAcceptShared
    elseif type(saved.autoAcceptSharedBoard) == "boolean" then
        state.autoAcceptShared = saved.autoAcceptSharedBoard
    end

    if type(saved.autoCurrentInstanceQuest) == "boolean" then
        state.autoCurrentInstanceQuest = saved.autoCurrentInstanceQuest
    end

    if type(saved.autoSelect) == "boolean" then
        state.autoSelect = saved.autoSelect
    end

    if type(saved.maxRerolls) == "number" and saved.maxRerolls >= 1 then
        state.maxRerolls = saved.maxRerolls
    end

    if type(saved.rerollDelay) == "number" and saved.rerollDelay >= 0.5 then
        state.rerollDelay = saved.rerollDelay
    end

    if type(saved.knownQuests) == "table" then
        state.knownQuests = Core.copyQuestList(saved.knownQuests)
    end

    if type(saved.desiredQuests) == "table" then
        state.desiredQuests = Core.copyDesiredMap(saved.desiredQuests)
    end

    if type(saved.characterProfiles) == "table" then
        state.characterProfiles = Core.copyCharacterProfiles(saved.characterProfiles)
    end

    if type(saved.questPanelExpanded) == "boolean" then
        state.questPanelExpanded = saved.questPanelExpanded
    end

    if type(saved.debug) == "table" then
        if type(saved.debug.enabled) == "boolean" then
            state.debug.enabled = saved.debug.enabled
        end

        if type(saved.debug.mouseWatch) == "boolean" then
            state.debug.mouseWatch = saved.debug.mouseWatch
        end

        if type(saved.debug.sniffer) == "boolean" then
            state.debug.sniffer = saved.debug.sniffer
        end

        if type(saved.debug.maxLog) == "number" and saved.debug.maxLog >= 20 then
            state.debug.maxLog = saved.debug.maxLog
        end
    end

    if type(saved.goldTracker) == "table" then
        if type(saved.goldTracker.totalSpent) == "number" and saved.goldTracker.totalSpent >= 0 then
            state.goldTracker.totalSpent = math.floor(saved.goldTracker.totalSpent)
        end

        if type(saved.goldTracker.trackedQuestCount) == "number" and saved.goldTracker.trackedQuestCount >= 0 then
            state.goldTracker.trackedQuestCount = math.floor(saved.goldTracker.trackedQuestCount)
        end

        if type(saved.goldTracker.lastQuestSpent) == "number" and saved.goldTracker.lastQuestSpent >= 0 then
            state.goldTracker.lastQuestSpent = math.floor(saved.goldTracker.lastQuestSpent)
        end
    end

    if type(saved.buttonShown) == "boolean" then
        state.buttonShown = saved.buttonShown
    end

    if type(saved.button) == "table" then
        if trim(saved.button.point) ~= "" then
            state.button.point = trim(saved.button.point)
        end

        if trim(saved.button.relativePoint) ~= "" then
            state.button.relativePoint = trim(saved.button.relativePoint)
        end

        if type(saved.button.x) == "number" then
            state.button.x = saved.button.x
        end

        if type(saved.button.y) == "number" then
            state.button.y = saved.button.y
        end
    end

    if type(saved.minimap) == "table" then
        if type(saved.minimap.shown) == "boolean" then
            state.minimap.shown = saved.minimap.shown
        end

        if type(saved.minimap.angle) == "number" then
            state.minimap.angle = saved.minimap.angle
        end
    end

    return state
end

function Core.parseSlash(input)
    local message = trim(input)

    if message == "" or message == "run" or message == "call" then
        return { kind = "run" }
    end

    local command, rest = message:match("^(%S+)%s*(.-)$")
    command = command and command:lower() or ""
    rest = trim(rest)

    if command == "help" then
        return { kind = "help" }
    end

    if command == "show" then
        return { kind = "show" }
    end

    if command == "hide" then
        return { kind = "hide" }
    end

    if command == "reset" then
        return { kind = "reset" }
    end

    if command == "clearquests" or command == "clearquestlist" or command == "clearknownquests" then
        return { kind = "clearQuestList", confirmed = rest:lower() == "confirm" }
    end

    if command == "name" then
        if rest == "" then
            return { kind = "invalid", message = "Usage: /acb name Callboard" }
        end

        return { kind = "set", field = "targetName", value = rest }
    end

    if command == "spell" then
        local lowered = rest:lower()

        if rest == "" then
            return { kind = "invalid", message = "Usage: /acb spell Summon Callboard, or /acb spell off" }
        end

        if lowered == "off" or lowered == "none" or lowered == "disabled" then
            return { kind = "set", field = "summonSpell", value = "" }
        end

        return { kind = "set", field = "summonSpell", value = rest }
    end

    if command == "id" or command == "spellid" then
        local spellID = tonumber(rest)

        if not spellID then
            return { kind = "invalid", message = "Usage: /acb id 600647" }
        end

        return { kind = "set", field = "summonSpellID", value = spellID }
    end

    if command == "reroll" then
        if rest == "" then
            return { kind = "reroll" }
        end

        return { kind = "set", field = "rerollFrame", value = rest }
    end

    if command == "objective" or command == "obj" or command == "pick" then
        local index = tonumber(rest)

        if not index or index < 1 or index > 3 then
            return { kind = "invalid", message = "Usage: /acb objective 1, /acb objective 2, or /acb objective 3" }
        end

        return { kind = "objective", index = index }
    end

    if command == "1" or command == "2" or command == "3" then
        return { kind = "objective", index = tonumber(command) }
    end

    if command == "buttonfield" then
        if rest == "" then
            return { kind = "invalid", message = "Usage: /acb buttonfield selectBtn" }
        end

        return { kind = "set", field = "objectiveButtonField", value = rest }
    end

    if command == "accept" then
        local lowered = rest:lower()

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "set", field = "autoAccept", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "set", field = "autoAccept", value = false }
        end

        return { kind = "invalid", message = "Usage: /acb accept on, or /acb accept off" }
    end

    if command == "autoacceptquests" or command == "autoacceptquest"
            or command == "shareaccept" or command == "sharedaccept" or command == "acceptshared" then
        local lowered = rest:lower()

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "set", field = "autoAcceptShared", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "set", field = "autoAcceptShared", value = false }
        end

        return { kind = "invalid", message = "Usage: /acb autoacceptquests on, or /acb autoacceptquests off" }
    end

    if command == "autoinstance" or command == "currentinstance" or command == "instancequest" then
        local lowered = rest:lower()

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "set", field = "autoCurrentInstanceQuest", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "set", field = "autoCurrentInstanceQuest", value = false }
        end

        return { kind = "invalid", message = "Usage: /acb autoinstance on, or /acb autoinstance off" }
    end

    if command == "quests" or command == "quest" then
        return { kind = "quests" }
    end

    if command == "roll" or command == "autoroll" then
        return { kind = "roll" }
    end

    if command == "stop" then
        return { kind = "stop" }
    end

    if command == "export" then
        return { kind = "data", action = "export" }
    end

    if command == "import" then
        return { kind = "data", action = "import" }
    end

    if command == "autoselect" then
        local lowered = rest:lower()

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "set", field = "autoSelect", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "set", field = "autoSelect", value = false }
        end

        return { kind = "invalid", message = "Usage: /acb autoselect on, or /acb autoselect off" }
    end

    if command == "maxrolls" then
        local value = tonumber(rest)

        if not value or value < 1 then
            return { kind = "invalid", message = "Usage: /acb maxrolls 50" }
        end

        return { kind = "set", field = "maxRerolls", value = math.floor(value) }
    end

    if command == "debug" then
        local lowered = rest:lower()

        if rest == "" then
            return { kind = "debug", action = "open" }
        end

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "debug", action = "enabled", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "debug", action = "enabled", value = false }
        end

        return { kind = "invalid", message = "Usage: /acb debug, /acb debug on, or /acb debug off" }
    end

    if command == "watch" then
        local lowered = rest:lower()

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "debug", action = "mouseWatch", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "debug", action = "mouseWatch", value = false }
        end

        return { kind = "invalid", message = "Usage: /acb watch on, or /acb watch off" }
    end

    if command == "sniff" or command == "sniffer" then
        local lowered = rest:lower()

        if rest == "" or lowered == "dump" then
            return { kind = "debug", action = "sniffDump" }
        end

        if lowered == "on" or lowered == "true" or lowered == "yes" then
            return { kind = "debug", action = "sniffer", value = true }
        end

        if lowered == "off" or lowered == "false" or lowered == "no" then
            return { kind = "debug", action = "sniffer", value = false }
        end

        if lowered == "clear" then
            return { kind = "debug", action = "sniffClear" }
        end

        return { kind = "invalid", message = "Usage: /acb sniff on, /acb sniff off, /acb sniff, or /acb sniff clear" }
    end

    if command == "etrace" or command == "eventtrace" then
        return { kind = "debug", action = "etrace" }
    end

    if command == "inspect" then
        return { kind = "debug", action = "inspect" }
    end

    if command == "dump" then
        return { kind = "debug", action = "dump" }
    end

    if command == "cooldown" or command == "cd" then
        return { kind = "debug", action = "cooldown" }
    end

    if command == "log" or command == "logs" then
        return { kind = "debug", action = "logs" }
    end

    if command == "clearlogs" then
        return { kind = "debug", action = "clearlogs" }
    end

    return { kind = "unknown", message = "Unknown AutoCallboard command. Try /acb help." }
end

function Core.questTitle(quest)
    if type(quest) ~= "table" then
        return ""
    end

    return trim(quest.title)
end

function Core.objectiveText(quest)
    if type(quest) ~= "table" then
        return ""
    end

    local cleanText = objectiveTextParts(quest.objectiveText)
    return cleanText
end

function Core.inferQuestType(quest)
    if type(quest) ~= "table" then
        return 0
    end

    local title = Core.questTitle(quest)
    local objective = Core.objectiveText(quest)
    local combined = title .. " " .. objective

    if containsAny(combined, PROFESSION_HINTS) then
        return 4
    end

    if containsAny(combined, RAID_HINTS) then
        return 3
    end

    if containsAny(combined, DUNGEON_HINTS) then
        return 2
    end

    if containsAny(title, OPEN_WORLD_TITLE_PREFIXES)
            or string.find(string.lower(objective), "^kill%s+%d+")
            or string.find(string.lower(objective), "^collect%s+%d+%s+rare") then
        return 1
    end

    return 0
end

function Core.questKey(quest)
    if type(quest) ~= "table" then
        return nil
    end

    local questID = tonumber(quest.questId or quest.id)
    if questID and questID > 0 then
        return "id:" .. tostring(math.floor(questID))
    end

    local title = Core.questTitle(quest)
    if title == "" then
        return nil
    end

    return "title:" .. title:lower()
end

function Core.copyQuestList(quests)
    local copy = {}

    if type(quests) ~= "table" then
        return copy
    end

    for i = 1, table.getn(quests) do
        local quest = quests[i]
        if type(quest) == "table" then
            local zoneOrSort, questType = Core.objectiveMetadata(quest)
            table.insert(copy, {
                key = quest.key,
                questId = tonumber(quest.questId) or 0,
                title = trim(quest.title),
                objectiveText = Core.objectiveText(quest),
                zoneOrSort = zoneOrSort,
                questType = questType,
                normalSoulAshes = tonumber(quest.normalSoulAshes) or 0,
                hc1SoulAshes = tonumber(quest.hc1SoulAshes) or 0,
                hc2SoulAshes = tonumber(quest.hc2SoulAshes) or 0,
                hc3SoulAshes = tonumber(quest.hc3SoulAshes) or 0,
                hc4SoulAshes = tonumber(quest.hc4SoulAshes) or 0,
                normalXp = tonumber(quest.normalXp) or 0,
                hc1Xp = tonumber(quest.hc1Xp) or 0,
                hc2Xp = tonumber(quest.hc2Xp) or 0,
                hc3Xp = tonumber(quest.hc3Xp) or 0,
                hc4Xp = tonumber(quest.hc4Xp) or 0,
                seen = tonumber(quest.seen) or 1,
                lastSeenRoll = tonumber(quest.lastSeenRoll) or 0,
            })
        end
    end

    return copy
end

function Core.copyDesiredMap(desired)
    local copy = {}

    if type(desired) ~= "table" then
        return copy
    end

    for key, value in pairs(desired) do
        if type(key) == "string" and value == true then
            copy[key] = true
        end
    end

    return copy
end

function Core.questMatchesTypeFilter(quest, enabledQuestTypes)
    if not Core.hasEnabledQuestTypeFilter(enabledQuestTypes) then
        return true
    end

    local questType = tonumber(quest and quest.questType) or 0
    return Core.questTypeFilterEnabled(enabledQuestTypes, questType)
end

function Core.questTypeFilterEnabled(enabledQuestTypes, questType)
    if type(enabledQuestTypes) ~= "table" then
        return false
    end

    questType = tonumber(questType) or 0

    return enabledQuestTypes[questType] == true or enabledQuestTypes[tostring(questType)] == true
end

function Core.hasEnabledQuestTypeFilter(enabledQuestTypes)
    if type(enabledQuestTypes) ~= "table" then
        return false
    end

    for _, enabled in pairs(enabledQuestTypes) do
        if enabled == true then
            return true
        end
    end

    return false
end

function Core.hasAllPrimaryQuestTypeFilters(enabledQuestTypes)
    if type(enabledQuestTypes) ~= "table" then
        return false
    end

    return Core.questTypeFilterEnabled(enabledQuestTypes, 1)
            and Core.questTypeFilterEnabled(enabledQuestTypes, 2)
            and Core.questTypeFilterEnabled(enabledQuestTypes, 3)
            and Core.questTypeFilterEnabled(enabledQuestTypes, 4)
end

function Core.needsKnownTypeFallback(quests, enabledQuestTypes)
    if type(quests) ~= "table" or not Core.hasAllPrimaryQuestTypeFilters(enabledQuestTypes) then
        return false
    end

    if table.getn(quests) == 0 then
        return false
    end

    local hasKnownType = false

    for i = 1, table.getn(quests) do
        if Core.questMatchesTypeFilter(quests[i], enabledQuestTypes) then
            return false
        end

        if (tonumber(quests[i] and quests[i].questType) or 0) > 0 then
            hasKnownType = true
        end
    end

    return not hasKnownType
end

function Core.hasDesiredQuests(desired)
    if type(desired) ~= "table" then
        return false
    end

    for _, enabled in pairs(desired) do
        if enabled == true then
            return true
        end
    end

    return false
end

function Core.hasDesiredKnownQuest(quests, desired)
    if type(quests) ~= "table" or not Core.hasDesiredQuests(desired) then
        return false
    end

    for i = 1, table.getn(quests) do
        local quest = quests[i]
        local key = type(quest) == "table" and type(quest.key) == "string" and quest.key or Core.questKey(quest)
        if key and desired[key] == true then
            return true
        end
    end

    return false
end

function Core.needsUntargetedRollConfirm(desired)
    return not Core.hasDesiredQuests(desired)
end

function Core.questTypeCounts(quests)
    local counts = {}

    if type(quests) ~= "table" then
        return counts
    end

    for i = 1, table.getn(quests) do
        local questType = tonumber(quests[i] and quests[i].questType) or 0
        counts[questType] = (counts[questType] or 0) + 1
    end

    return counts
end

function Core.questMatchesKnownFilter(quest, enabledQuestTypes, desired)
    if type(enabledQuestTypes) == "table" then
        for _, enabled in pairs(enabledQuestTypes) do
            if enabled == true then
                return Core.questMatchesTypeFilter(quest, enabledQuestTypes)
            end
        end
    end

    if not Core.hasDesiredQuests(desired) then
        return true
    end

    local key = type(quest) == "table" and type(quest.key) == "string" and quest.key or Core.questKey(quest)
    return type(desired) == "table" and key ~= nil and desired[key] == true
end

function Core.copyCharacterProfiles(profiles)
    local copy = {}

    if type(profiles) ~= "table" then
        return copy
    end

    for profileKey, profile in pairs(profiles) do
        if type(profileKey) == "string" and type(profile) == "table" then
            copy[profileKey] = {
                desiredQuests = Core.copyDesiredMap(profile.desiredQuests),
            }
        end
    end

    return copy
end

function Core.clearQuestListState(currentState)
    local nextState = Core.mergeState(currentState)

    nextState.knownQuests = {}
    nextState.desiredQuests = {}
    nextState.characterProfiles = Core.copyCharacterProfiles(nextState.characterProfiles)

    for _, profile in pairs(nextState.characterProfiles) do
        profile.desiredQuests = {}
    end

    return nextState
end

function Core.objectiveMetadata(objective)
    local _, parsedZone, parsedType = objectiveTextParts(objective and objective.objectiveText)
    parsedZone = tonumber(parsedZone) or 0
    parsedType = Core.sanitizeQuestType(parsedType)

    local storedZone = tonumber(objective and objective.zoneOrSort) or 0
    local storedType = Core.sanitizeQuestType(objective and objective.questType)

    -- The server appends the real ",<zoneOrSort>,<questType>" to the objective
    -- text while filling the structured fields with reward magnitudes, so the
    -- text suffix is authoritative. Fall back to a sanitized stored value, then
    -- to name-based inference only when nothing reliable is available.
    local zoneOrSort = parsedZone > 0 and parsedZone or storedZone
    local questType = parsedType > 0 and parsedType or storedType

    if questType == 0 then
        questType = Core.inferQuestType(objective)
    end

    return zoneOrSort, questType
end

-- Surfaces exactly what the server API delivered for an objective versus what the
-- addon derived, so the debug log can show whether bad data is coming from the
-- API (reward magnitudes in the questType field, real values only in the text
-- suffix). Pure reporting; it never mutates the objective.
function Core.describeObjectiveMetadata(objective)
    local cleanText, parsedZone, parsedType = objectiveTextParts(objective and objective.objectiveText)
    local rawType = tonumber(objective and objective.questType) or 0
    local sanitizedRawType = Core.sanitizeQuestType(rawType)
    local finalZone, finalType = Core.objectiveMetadata(objective)

    return {
        rawText = trim(objective and objective.objectiveText),
        cleanText = cleanText,
        rawZone = tonumber(objective and objective.zoneOrSort) or 0,
        rawType = rawType,
        rawTypeRejected = rawType ~= 0 and sanitizedRawType == 0,
        hasSuffix = (tonumber(parsedZone) or 0) > 0 or Core.sanitizeQuestType(parsedType) > 0,
        suffixZone = tonumber(parsedZone) or 0,
        suffixType = Core.sanitizeQuestType(parsedType),
        finalZone = finalZone,
        finalType = finalType,
    }
end

function Core.captureKnownQuests(existing, objectives, rollCount)
    local known = Core.copyQuestList(existing)
    local indexByKey = {}

    for i = 1, table.getn(known) do
        if type(known[i].key) == "string" then
            indexByKey[known[i].key] = i
        end
    end

    if not Core.isObjectiveChoiceList(objectives) then
        return known
    end

    for i = 1, table.getn(objectives) do
        local objective = objectives[i]
        local key = Core.questKey(objective)
        local title = Core.questTitle(objective)

        if key and title ~= "" then
            local zoneOrSort, questType = Core.objectiveMetadata(objective)
            local existingIndex = indexByKey[key]
            if existingIndex then
                known[existingIndex].seen = (known[existingIndex].seen or 0) + 1
                known[existingIndex].lastSeenRoll = rollCount or known[existingIndex].lastSeenRoll or 0
                known[existingIndex].objectiveText = Core.objectiveText(objective)
                known[existingIndex].zoneOrSort = zoneOrSort > 0 and zoneOrSort or known[existingIndex].zoneOrSort or 0
                known[existingIndex].questType = questType > 0 and questType or known[existingIndex].questType or 0
                known[existingIndex].normalSoulAshes = tonumber(objective.normalSoulAshes) or 0
                known[existingIndex].hc1SoulAshes = tonumber(objective.hc1SoulAshes) or 0
                known[existingIndex].hc2SoulAshes = tonumber(objective.hc2SoulAshes) or 0
                known[existingIndex].hc3SoulAshes = tonumber(objective.hc3SoulAshes) or 0
                known[existingIndex].hc4SoulAshes = tonumber(objective.hc4SoulAshes) or 0
                known[existingIndex].normalXp = tonumber(objective.normalXp) or 0
                known[existingIndex].hc1Xp = tonumber(objective.hc1Xp) or 0
                known[existingIndex].hc2Xp = tonumber(objective.hc2Xp) or 0
                known[existingIndex].hc3Xp = tonumber(objective.hc3Xp) or 0
                known[existingIndex].hc4Xp = tonumber(objective.hc4Xp) or 0
            else
                table.insert(known, {
                    key = key,
                    questId = tonumber(objective.questId) or 0,
                    title = title,
                    objectiveText = Core.objectiveText(objective),
                    zoneOrSort = zoneOrSort,
                    questType = questType,
                    normalSoulAshes = tonumber(objective.normalSoulAshes) or 0,
                    hc1SoulAshes = tonumber(objective.hc1SoulAshes) or 0,
                    hc2SoulAshes = tonumber(objective.hc2SoulAshes) or 0,
                    hc3SoulAshes = tonumber(objective.hc3SoulAshes) or 0,
                    hc4SoulAshes = tonumber(objective.hc4SoulAshes) or 0,
                    normalXp = tonumber(objective.normalXp) or 0,
                    hc1Xp = tonumber(objective.hc1Xp) or 0,
                    hc2Xp = tonumber(objective.hc2Xp) or 0,
                    hc3Xp = tonumber(objective.hc3Xp) or 0,
                    hc4Xp = tonumber(objective.hc4Xp) or 0,
                    seen = 1,
                    lastSeenRoll = rollCount or 0,
                })
                indexByKey[key] = table.getn(known)
            end
        end
    end

    table.sort(known, function(a, b)
        return (a.title or "") < (b.title or "")
    end)

    return known
end

function Core.isObjectiveChoiceList(objectives)
    if type(objectives) ~= "table" or table.getn(objectives) < 3 then
        return false
    end

    for i = 1, 3 do
        if Core.questKey(objectives[i]) == nil or Core.questTitle(objectives[i]) == "" then
            return false
        end
    end

    return true
end

local function encodeField(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%%%")
    value = value:gsub("|", "%%p")
    value = value:gsub("%^", "%%h")
    value = value:gsub("\t", "%%t")
    value = value:gsub("\r", "%%r")
    value = value:gsub("\n", "%%n")

    return value
end

local function decodeField(value)
    value = tostring(value or "")

    return (value:gsub("%%([nrt%%ph])", {
        n = "\n",
        r = "\r",
        t = "\t",
        ["%"] = "%",
        p = "|",
        h = "^",
    }))
end

local function importMarker(line)
    return trim(tostring(line or ""):gsub("^\239\187\191", ""))
end

local function splitPlain(value, separator)
    local fields = {}
    local startIndex = 1

    while true do
        local separatorStart, separatorEnd = string.find(value, separator, startIndex, true)
        if not separatorStart then
            table.insert(fields, string.sub(value, startIndex))
            break
        end

        table.insert(fields, string.sub(value, startIndex, separatorStart - 1))
        startIndex = separatorEnd + 1
    end

    return fields
end

local function countPlain(value, needle)
    local count = 0
    local startIndex = 1

    while true do
        local matchStart, matchEnd = string.find(value, needle, startIndex, true)
        if not matchStart then
            break
        end

        count = count + 1
        startIndex = matchEnd + 1
    end

    return count
end

local QUEST_EXPORT_FIELDS = {
    "key",
    "questId",
    "title",
    "objectiveText",
    "zoneOrSort",
    "questType",
    "normalSoulAshes",
    "hc1SoulAshes",
    "hc2SoulAshes",
    "hc3SoulAshes",
    "hc4SoulAshes",
    "normalXp",
    "hc1Xp",
    "hc2Xp",
    "hc3Xp",
    "hc4Xp",
    "seen",
    "lastSeenRoll",
}

function Core.exportKnownQuestText(quests)
    local lines = { "ACBQUESTS3" }
    local cleanQuests = Core.copyQuestList(quests)

    for i = 1, table.getn(cleanQuests) do
        local quest = cleanQuests[i]
        local fields = {}

        for fieldIndex = 1, table.getn(QUEST_EXPORT_FIELDS) do
            table.insert(fields, encodeField(quest[QUEST_EXPORT_FIELDS[fieldIndex]]))
        end

        table.insert(lines, table.concat(fields, " ^ "))
    end

    return table.concat(lines, "\n")
end

local function decodeFields(fields)
    for i = 1, table.getn(fields) do
        fields[i] = decodeField(fields[i])
    end

    return fields
end

local function splitQuestImportFields(line, marker)
    local fields

    if marker == "ACBQUESTS1" then
        return decodeFields(splitPlain(line, "\t")), "ACBQUESTS1"
    end

    if marker == "ACBQUESTS3" then
        return decodeFields(splitPlain(line, " ^ ")), "ACBQUESTS3"
    end

    fields = splitPlain(line, " | ")
    if marker == "ACBQUESTS2" or table.getn(fields) >= table.getn(QUEST_EXPORT_FIELDS) then
        if table.getn(fields) < table.getn(QUEST_EXPORT_FIELDS) then
            fields = splitPlain(line, " // ")
        end

        return decodeFields(fields), "ACBQUESTS2"
    end

    fields = splitPlain(line, " ^ ")
    if table.getn(fields) >= table.getn(QUEST_EXPORT_FIELDS) then
        return decodeFields(fields), "ACBQUESTS3"
    end

    fields = splitPlain(line, " // ")
    if table.getn(fields) >= table.getn(QUEST_EXPORT_FIELDS) then
        return decodeFields(fields), "ACBQUESTS2"
    end

    fields = splitPlain(line, "\t")
    if table.getn(fields) < table.getn(QUEST_EXPORT_FIELDS) then
        return fields, nil
    end

    return decodeFields(fields), "ACBQUESTS1"
end

function Core.analyzeQuestImportText(text)
    local info = {
        textLength = type(text) == "string" and string.len(text) or 0,
        fieldCount = table.getn(QUEST_EXPORT_FIELDS),
        lineCount = 0,
        nonEmptyLineCount = 0,
        marker = nil,
        markerLine = 0,
        dataLineCount = 0,
        importableLineCount = 0,
        invalidLineCount = 0,
        firstLine = "",
        samples = {},
    }

    if type(text) ~= "string" or trim(text) == "" then
        return info
    end

    local marker = nil
    local stopped = false

    for line in string.gmatch(text .. "\n", "([^\r\n]*)\r?\n") do
        info.lineCount = info.lineCount + 1

        local cleanLine = importMarker(line)
        local trimmedLine = trim(line)
        if info.firstLine == "" and trimmedLine ~= "" then
            info.firstLine = cleanLine
        end

        if cleanLine == "```" and (marker or info.dataLineCount > 0) then
            stopped = true
            break
        elseif cleanLine == "ACBQUESTS1" or cleanLine == "ACBQUESTS2" or cleanLine == "ACBQUESTS3" then
            marker = cleanLine
            info.marker = cleanLine
            info.markerLine = info.lineCount
            info.nonEmptyLineCount = info.nonEmptyLineCount + 1
        elseif trimmedLine ~= "" and string.sub(cleanLine, 1, 3) ~= "```" then
            info.nonEmptyLineCount = info.nonEmptyLineCount + 1
            info.dataLineCount = info.dataLineCount + 1

            local v3Fields = table.getn(splitPlain(line, " ^ "))
            local v2Fields = table.getn(splitPlain(line, " | "))
            local slashFields = table.getn(splitPlain(line, " // "))
            local v1Fields = table.getn(splitPlain(line, "\t"))
            local rawFields, inferredMarker = splitQuestImportFields(line, marker)
            local activeFields = table.getn(rawFields)
            local importable = activeFields >= info.fieldCount

            if importable then
                info.importableLineCount = info.importableLineCount + 1
            else
                info.invalidLineCount = info.invalidLineCount + 1
            end

            if table.getn(info.samples) < 5 then
                table.insert(info.samples, {
                    line = info.lineCount,
                    length = string.len(line),
                    marker = marker or inferredMarker or "none",
                    v3Separators = countPlain(line, " ^ "),
                    v2Separators = countPlain(line, " | "),
                    slashSeparators = countPlain(line, " // "),
                    tabSeparators = countPlain(line, "\t"),
                    v3Fields = v3Fields,
                    v2Fields = v2Fields,
                    slashFields = slashFields,
                    v1Fields = v1Fields,
                    activeFields = activeFields,
                    importable = importable,
                    preview = cleanLine,
                })
            end
        end
    end

    info.stoppedAtFence = stopped

    return info
end

function Core.importKnownQuestText(text)
    local quests = {}
    local imported = 0
    local skipped = 0

    if type(text) ~= "string" or trim(text) == "" then
        return quests, imported, skipped + 1
    end

    local marker = nil

    for line in string.gmatch(text .. "\n", "([^\r\n]*)\r?\n") do
        local cleanLine = importMarker(line)

        if cleanLine == "```" and (marker or imported > 0) then
            break
        elseif cleanLine == "ACBQUESTS1" or cleanLine == "ACBQUESTS2" or cleanLine == "ACBQUESTS3" then
            marker = cleanLine
        elseif trim(line) ~= "" and string.sub(cleanLine, 1, 3) ~= "```" then
            local rawFields, inferredMarker = splitQuestImportFields(line, marker)

            if table.getn(rawFields) >= table.getn(QUEST_EXPORT_FIELDS) then
                marker = marker or inferredMarker
                local quest = {}

                for fieldIndex = 1, table.getn(QUEST_EXPORT_FIELDS) do
                    quest[QUEST_EXPORT_FIELDS[fieldIndex]] = rawFields[fieldIndex]
                end

                local cleanQuest = Core.copyQuestList({ quest })[1]
                if cleanQuest and Core.questKey(cleanQuest) then
                    table.insert(quests, cleanQuest)
                    imported = imported + 1
                else
                    skipped = skipped + 1
                end
            elseif marker or imported > 0 then
                skipped = skipped + 1
            end
        end
    end

    if not marker and imported == 0 then
        return quests, imported, skipped + 1
    end

    return quests, imported, skipped
end

function Core.mergeKnownQuestLists(existing, incoming)
    local merged = Core.copyQuestList(existing)
    local indexByKey = {}

    for i = 1, table.getn(merged) do
        if type(merged[i].key) == "string" then
            indexByKey[merged[i].key] = i
        end
    end

    local cleanIncoming = Core.copyQuestList(incoming)

    for i = 1, table.getn(cleanIncoming) do
        local quest = cleanIncoming[i]
        local key = type(quest.key) == "string" and quest.key ~= "" and quest.key or Core.questKey(quest)
        local existingIndex = key and indexByKey[key]

        if existingIndex then
            quest.seen = math.max(tonumber(merged[existingIndex].seen) or 0, tonumber(quest.seen) or 0)
            quest.lastSeenRoll = math.max(tonumber(merged[existingIndex].lastSeenRoll) or 0, tonumber(quest.lastSeenRoll) or 0)
            merged[existingIndex] = quest
        elseif key then
            table.insert(merged, quest)
            indexByKey[key] = table.getn(merged)
        end
    end

    table.sort(merged, function(a, b)
        return (a.title or "") < (b.title or "")
    end)

    return merged
end

function Core.toggleDesired(desired, key, enabled)
    local copy = Core.copyDesiredMap(desired)

    if type(key) ~= "string" or key == "" then
        return copy
    end

    if enabled == false or copy[key] then
        copy[key] = nil
    else
        copy[key] = true
    end

    return copy
end

function Core.currentInstanceQuestType(instanceType)
    instanceType = normalizeMatchText(instanceType)

    if instanceType == "party" then
        return 2
    end

    if instanceType == "raid" then
        return 3
    end

    return 0
end

function Core.buildCurrentInstanceTarget(info)
    if type(info) ~= "table" then
        return nil
    end

    local questType = Core.sanitizeQuestType(info.questType)
    if questType == 0 then
        questType = Core.currentInstanceQuestType(info.instanceType)
    end

    if questType ~= 2 and questType ~= 3 then
        return nil
    end

    local aliases = {}
    local seen = {}
    appendUniqueNormalized(aliases, seen, info.name)
    appendUniqueNormalized(aliases, seen, info.realZoneText)
    appendUniqueNormalized(aliases, seen, info.zoneText)
    appendUniqueNormalized(aliases, seen, info.minimapZoneText)

    if type(info.names) == "table" then
        for i = 1, table.getn(info.names) do
            appendUniqueNormalized(aliases, seen, info.names[i])
        end
    end

    if type(info.aliases) == "table" then
        for i = 1, table.getn(info.aliases) do
            appendUniqueNormalized(aliases, seen, info.aliases[i])
        end
    end

    local originalCount = table.getn(aliases)
    for i = 1, originalCount do
        local mappedAliases = CURRENT_INSTANCE_ALIASES[aliases[i]]
        if type(mappedAliases) == "table" then
            for j = 1, table.getn(mappedAliases) do
                appendUniqueNormalized(aliases, seen, mappedAliases[j])
            end
        end
    end

    if table.getn(aliases) == 0 then
        return nil
    end

    return {
        instanceType = trim(info.instanceType),
        name = trim(info.name) ~= "" and trim(info.name) or aliases[1],
        questType = questType,
        aliases = aliases,
    }
end

function Core.questMatchesCurrentInstance(quest, target)
    target = Core.buildCurrentInstanceTarget(target)

    if type(quest) ~= "table" or not target then
        return false
    end

    local _, questType = Core.objectiveMetadata(quest)
    if questType ~= target.questType then
        return false
    end

    local combined = normalizeMatchText(Core.questTitle(quest) .. " " .. Core.objectiveText(quest))

    for i = 1, table.getn(target.aliases) do
        local alias = target.aliases[i]
        if alias ~= "" and string.find(combined, alias, 1, true) then
            return true, alias
        end
    end

    return false
end

function Core.findCurrentInstanceObjective(objectives, target)
    target = Core.buildCurrentInstanceTarget(target)

    if not Core.isObjectiveChoiceList(objectives) or not target then
        return nil
    end

    for i = 1, table.getn(objectives) do
        local matched, alias = Core.questMatchesCurrentInstance(objectives[i], target)
        if matched then
            return {
                index = i,
                key = Core.questKey(objectives[i]),
                quest = objectives[i],
                source = "currentInstance",
                label = "current instance quest",
                matchedAlias = alias,
                questType = target.questType,
                target = target,
            }
        end
    end

    return nil
end

function Core.findDesiredObjective(objectives, desired)
    if not Core.isObjectiveChoiceList(objectives) or type(desired) ~= "table" then
        return nil
    end

    for i = 1, table.getn(objectives) do
        local key = Core.questKey(objectives[i])
        if key and desired[key] then
            return {
                index = i,
                key = key,
                quest = objectives[i],
            }
        end
    end

    return nil
end

function Core.findRollObjective(objectives, desired, currentInstanceTarget)
    if Core.buildCurrentInstanceTarget(currentInstanceTarget) then
        return Core.findCurrentInstanceObjective(objectives, currentInstanceTarget)
    end

    return Core.findDesiredObjective(objectives, desired)
end

AutoCallboardCore = Core
