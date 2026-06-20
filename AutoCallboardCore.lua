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

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

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
            table.insert(copy, {
                key = quest.key,
                questId = tonumber(quest.questId) or 0,
                title = trim(quest.title),
                objectiveText = trim(quest.objectiveText),
                zoneOrSort = tonumber(quest.zoneOrSort) or 0,
                questType = tonumber(quest.questType) or 0,
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
    if type(enabledQuestTypes) ~= "table" then
        return true
    end

    local hasEnabledFilter = false
    for _, enabled in pairs(enabledQuestTypes) do
        if enabled == true then
            hasEnabledFilter = true
            break
        end
    end

    if not hasEnabledFilter then
        return true
    end

    local questType = tonumber(quest and quest.questType) or 0
    return enabledQuestTypes[questType] == true
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

function Core.captureKnownQuests(existing, objectives, rollCount)
    local known = Core.copyQuestList(existing)
    local indexByKey = {}

    for i = 1, table.getn(known) do
        if type(known[i].key) == "string" then
            indexByKey[known[i].key] = i
        end
    end

    if type(objectives) ~= "table" then
        return known
    end

    for i = 1, table.getn(objectives) do
        local objective = objectives[i]
        local key = Core.questKey(objective)
        local title = Core.questTitle(objective)

        if key and title ~= "" then
            local existingIndex = indexByKey[key]
            if existingIndex then
                known[existingIndex].seen = (known[existingIndex].seen or 0) + 1
                known[existingIndex].lastSeenRoll = rollCount or known[existingIndex].lastSeenRoll or 0
                known[existingIndex].objectiveText = trim(objective.objectiveText)
                known[existingIndex].zoneOrSort = tonumber(objective.zoneOrSort) or known[existingIndex].zoneOrSort or 0
                known[existingIndex].questType = tonumber(objective.questType) or known[existingIndex].questType or 0
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
                    objectiveText = trim(objective.objectiveText),
                    zoneOrSort = tonumber(objective.zoneOrSort) or 0,
                    questType = tonumber(objective.questType) or 0,
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

local function encodeField(value)
    value = tostring(value or "")
    value = value:gsub("%%", "%%%%")
    value = value:gsub("\t", "%%t")
    value = value:gsub("\r", "%%r")
    value = value:gsub("\n", "%%n")

    return value
end

local function decodeField(value)
    value = tostring(value or "")
    value = value:gsub("%%n", "\n")
    value = value:gsub("%%r", "\r")
    value = value:gsub("%%t", "\t")
    value = value:gsub("%%%%", "%%")

    return value
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
    local lines = { "ACBQUESTS1" }
    local cleanQuests = Core.copyQuestList(quests)

    for i = 1, table.getn(cleanQuests) do
        local quest = cleanQuests[i]
        local fields = {}

        for fieldIndex = 1, table.getn(QUEST_EXPORT_FIELDS) do
            table.insert(fields, encodeField(quest[QUEST_EXPORT_FIELDS[fieldIndex]]))
        end

        table.insert(lines, table.concat(fields, "\t"))
    end

    return table.concat(lines, "\n")
end

function Core.importKnownQuestText(text)
    local quests = {}
    local imported = 0
    local skipped = 0

    if type(text) ~= "string" or trim(text) == "" then
        return quests, imported, skipped + 1
    end

    local firstLine = true

    for line in string.gmatch(text .. "\n", "([^\r\n]*)\r?\n") do
        if firstLine then
            firstLine = false
            local marker = trim(line)
            if marker ~= "ACBQUESTS1" then
                return quests, imported, skipped + 1
            end
        elseif trim(line) ~= "" then
            local rawFields = {}

            for field in string.gmatch(line .. "\t", "([^\t]*)\t") do
                table.insert(rawFields, decodeField(field))
            end

            if table.getn(rawFields) >= table.getn(QUEST_EXPORT_FIELDS) then
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
            else
                skipped = skipped + 1
            end
        end
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

function Core.findDesiredObjective(objectives, desired)
    if type(objectives) ~= "table" or type(desired) ~= "table" then
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

AutoCallboardCore = Core
