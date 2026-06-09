local ADDON_NAME = ...
local Core = AutoCallboardCore
AutoCallboardRuntime = AutoCallboardRuntime or {}

local ADDON_TITLE = "AutoCallboard"
local ADDON_PREFIX = "|cffb58cffACB:|r "

local frame = CreateFrame("Frame")
local controlFrame
local button
local minimapButton
local minimapText
local debugWindow
local helpWindow
local debugEditBox
local debugEditBoxUpdating = false
local debugReadOnlyText = ""
local dataWindow
local dataEditBox
local questWindow
local currentQuestRows = {}
local knownQuestRows = {}
local questStatusText
local startRollButton
local knownPageText
local knownScrollFrame
local questSearchBox
local questSearchText = ""
local characterProfileKey
local state
local pendingInteractAt
local pendingAcceptUntil
local hookedDebugFrames = {}
local lastMouseFocus
local nextDebugProbeAt
local knownScrollOffset = 0
local updatingKnownScrollBar = false
local rolling = false
local rollPausedReason
local rollPauseMessage
local rollCount = 0
local nextRollAt
local pendingReroll = false
local pendingRerollUntil
local lastObjectiveSignature
local selectedQuest
local nextSelectedQuestCheckAt
local lastCapturedSignature
local nextQuestRefreshAt
local nextQuestWatchAt
local registeredSpecialFrames = {}
local callboardActiveUntil
local fallbackCooldownUntil
local nextSummonCastAt
local preClickCooldownRemaining = 0
local preClickWasActive = false
local preClickWasUsable = true
local preClickTargetedBoardName
local summonStatusText
local ShowDebugWindow

local INTERACT_DELAY = 1.25
local ACCEPT_WINDOW = 12
local ACCEPTED_QUEST_SHARE_TIMEOUT = 8
local ACCEPTED_QUEST_SHARE_RETRY_INTERVAL = 0.35
local DEBUG_PROBE_INTERVAL = 0.25
local KNOWN_ROWS = 10
local QUEST_ROW_HEIGHT = 28
local QUEST_WINDOW_WIDTH = 620
local CURRENT_QUEST_ROW_WIDTH = 570
local KNOWN_QUEST_ROW_WIDTH = 556
local QUEST_REFRESH_INTERVAL = 0.4
local QUEST_WATCH_INTERVAL = 0.5
local ROLL_EVAL_INTERVAL = 0.5
local BOARD_TARGET_PRIMARY_NAMES = { "Objectives Board", "Objective Board" }
local BOARD_OBJECT_IDS = { [600600] = true }

AutoCallboardRuntime.controlCollapsedWidth = 300
AutoCallboardRuntime.controlCollapsedHeight = 84
AutoCallboardRuntime.controlExpandedWidth = 640
AutoCallboardRuntime.controlExpandedHeight = 684
AutoCallboardRuntime.questPanelAnimationSeconds = 0.35

local WHITE8X8 = "Interface\\Buttons\\WHITE8X8"
local BUTTON_FONT = "Fonts\\FRIZQT__.TTF"
local function RGB(r, g, b, a)
  return r / 255, g / 255, b / 255, a or 1
end

local THEME = {
  bg = { RGB(5, 5, 5, 0.96) },
  bgSoft = { RGB(5, 5, 5, 0.86) },
  card = { RGB(5, 5, 5, 0.92) },
  debugList = { RGB(18, 18, 18, 0.96) },
  border = { RGB(75, 46, 131, 1) },
  borderDim = { RGB(75, 46, 131, 0.65) },
  button = { RGB(75, 46, 131, 1) },
  buttonBorder = { RGB(75, 46, 131, 1) },
  buttonStop = { RGB(209, 246, 246, 1) },
  buttonDisabledBorder = { RGB(75, 46, 131, 0) },
  buttonHoverBorder = { RGB(232, 121, 255, 1) },
  buttonText = { RGB(209, 209, 246, 1) },
  buttonDisabledText = { RGB(209, 209, 246, 0.45) },
  checkbox = { RGB(5, 5, 5, 1) },
  checkboxBorder = { RGB(75, 46, 131, 1) },
  checkboxChecked = { RGB(176, 72, 248, 1) },
  close = { RGB(5, 5, 5, 1) },
  closeBorder = { RGB(5, 5, 5, 1) },
  closeText = { RGB(176, 72, 248, 1) },
  text = { RGB(209, 246, 246, 1) },
  muted = { RGB(209, 227, 246, 0.78) },
  title = { RGB(209, 209, 246, 1) },
  gold = { RGB(209, 209, 246, 1) },
  good = { RGB(209, 246, 246, 1) },
  heading = { RGB(176, 72, 248, 1) },
}

local function GetAddonVersion()
  if GetAddOnMetadata and ADDON_NAME then
    return GetAddOnMetadata(ADDON_NAME, "Version") or "unknown"
  end

  return "unknown"
end

local function ApplyColor(target, methodName, color)
  if target and target[methodName] and color then
    target[methodName](target, color[1], color[2], color[3], color[4] or 1)
  end
end

local function IsMouseOverFrame(target)
  if not target then
    return false
  end

  if target.IsMouseOver and target:IsMouseOver() then
    return true
  end

  return MouseIsOver and MouseIsOver(target) or false
end

local function SetButtonVisual(target, mode)
  if not target then
    return
  end

  local disabled = target.IsEnabled and not target:IsEnabled()
  local visualMode = mode or (IsMouseOverFrame(target) and "hover" or nil)
  local bg = THEME.button
  local isStopState = target._acbRollState == "stop"
  local border = disabled and THEME.buttonDisabledBorder or THEME.buttonBorder
  local text = disabled and THEME.buttonDisabledText or THEME.buttonText
  local glossAlpha = 0.08

  if isStopState then
    bg = THEME.buttonStop
  end

  if not disabled and visualMode == "hover" then
    border = THEME.buttonHoverBorder
  elseif not disabled and visualMode == "down" then
    border = THEME.buttonHoverBorder
  end

  ApplyColor(target, "SetBackdropColor", bg)
  ApplyColor(target, "SetBackdropBorderColor", border)

  if target.GetFontString and target:GetFontString() then
    target:GetFontString():SetTextColor(text[1], text[2], text[3], text[4] or 1)
  end

  if target._acbGloss then
    target._acbGloss:SetVertexColor(1, 1, 1, glossAlpha)
  end
end

local function SkinCloseButton(target, parent)
  if not target then
    return
  end

  target:SetWidth(18)
  target:SetHeight(18)

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
    ApplyColor(target, "SetBackdropColor", THEME.close)
    ApplyColor(target, "SetBackdropBorderColor", THEME.closeBorder)
  end

  local text = target:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER", target, "CENTER", 0, 0)
  text:SetText("X")
  text:SetTextColor(THEME.closeText[1], THEME.closeText[2], THEME.closeText[3], THEME.closeText[4] or 1)

  target:SetScript("OnClick", function()
    if parent then
      parent:Hide()
    end
    end)
  target:SetScript("OnEnter", function()
    ApplyColor(target, "SetBackdropColor", THEME.close)
    ApplyColor(target, "SetBackdropBorderColor", THEME.closeBorder)
    text:SetTextColor(THEME.closeText[1], THEME.closeText[2], THEME.closeText[3], THEME.closeText[4] or 1)
    end)
  target:SetScript("OnLeave", function()
    ApplyColor(target, "SetBackdropColor", THEME.close)
    ApplyColor(target, "SetBackdropBorderColor", THEME.closeBorder)
    text:SetTextColor(THEME.closeText[1], THEME.closeText[2], THEME.closeText[3], THEME.closeText[4] or 1)
    end)
end

local function SkinFrame(target, variant)
  if not target or not target.SetBackdrop then
    return
  end

  target:SetBackdrop({
    bgFile = WHITE8X8,
    edgeFile = WHITE8X8,
    edgeSize = 1,
  })
  ApplyColor(target, "SetBackdropColor", variant == "soft" and THEME.card or THEME.bg)
  ApplyColor(target, "SetBackdropBorderColor", variant == "soft" and THEME.borderDim or THEME.border)
end

local function StripButtonChrome(target)
  if not target then
    return
  end

  if target.SetNormalTexture then
    target:SetNormalTexture("")
  end
  if target.SetHighlightTexture then
    target:SetHighlightTexture("")
  end
  if target.SetPushedTexture then
    target:SetPushedTexture("")
  end
  if target.SetDisabledTexture then
    target:SetDisabledTexture("")
  end

  if target.GetRegions then
    local regions = { target:GetRegions() }
    for i = 1, table.getn(regions) do
      local region = regions[i]
      if region and region.GetObjectType and region:GetObjectType() == "Texture" and region ~= target._acbGloss then
        if region.SetTexture then
          region:SetTexture(nil)
        end
        if region.SetAlpha then
          region:SetAlpha(0)
        end
        if region.Hide then
          region:Hide()
        end
      end
    end
  end
end

local function StripFrameTextures(target)
  if not target or not target.GetRegions then
    return
  end

  local regions = { target:GetRegions() }
  for i = 1, table.getn(regions) do
    local region = regions[i]
    if region and region.GetObjectType and region:GetObjectType() == "Texture" then
      if region.SetTexture then
        region:SetTexture(nil)
      end
      if region.SetAlpha then
        region:SetAlpha(0)
      end
      if region.Hide then
        region:Hide()
      end
    end
  end
end

local function SkinButton(target)
  if not target then
    return
  end

  StripButtonChrome(target)

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
    ApplyColor(target, "SetBackdropColor", THEME.button)
    ApplyColor(target, "SetBackdropBorderColor", THEME.buttonBorder)
  end

  if target.SetNormalFontObject then
    target:SetNormalFontObject(GameFontNormalSmall)
  end

  if target.SetHighlightFontObject then
    target:SetHighlightFontObject(GameFontHighlightSmall)
  end

  if target.SetDisabledTextColor then
    target:SetDisabledTextColor(THEME.buttonDisabledText[1], THEME.buttonDisabledText[2], THEME.buttonDisabledText[3])
  end

  if target.GetFontString and target:GetFontString() then
    local fontString = target:GetFontString()
    fontString:ClearAllPoints()
    fontString:SetPoint("CENTER", target, "CENTER", 0, 0)
    fontString:SetJustifyH("CENTER")
    fontString:SetJustifyV("MIDDLE")
    fontString:SetFont(BUTTON_FONT, 10, "OUTLINE")
  end

  if not target._acbGloss and target.CreateTexture then
    local gloss = target:CreateTexture(nil, "OVERLAY")
    gloss:SetTexture(WHITE8X8)
    gloss:SetHeight(1)
    gloss:SetPoint("TOPLEFT", target, "TOPLEFT", 1, -1)
    gloss:SetPoint("TOPRIGHT", target, "TOPRIGHT", -1, -1)
    target._acbGloss = gloss
  end

  SetButtonVisual(target)

  if not target._acbButtonHooks and target.HookScript then
    target:HookScript("OnEnter", function(self)
      SetButtonVisual(self, "hover")
      end)
    target:HookScript("OnLeave", function(self)
      SetButtonVisual(self)
      end)
    target:HookScript("OnMouseDown", function(self)
      SetButtonVisual(self, "down")
      end)
    target:HookScript("OnMouseUp", function(self)
      SetButtonVisual(self)
      end)
    target:HookScript("OnEnable", function(self)
      SetButtonVisual(self)
      end)
    target:HookScript("OnDisable", function(self)
      SetButtonVisual(self)
      end)
    target._acbButtonHooks = true
  end
end

local function SetScrollButtonVisual(target, mode)
  if not target then
    return
  end

  local visualMode = mode or (IsMouseOverFrame(target) and "hover" or nil)

  ApplyColor(target, "SetBackdropColor", THEME.button)
  ApplyColor(target, "SetBackdropBorderColor", visualMode == "hover" and THEME.buttonHoverBorder or THEME.buttonBorder)

  if target._acbScrollGlyph then
    target._acbScrollGlyph:SetTextColor(THEME.buttonText[1], THEME.buttonText[2], THEME.buttonText[3], THEME.buttonText[4] or 1)
  end
end

local function SkinScrollButton(target, glyph)
  if not target then
    return
  end

  StripButtonChrome(target)
  target:SetWidth(18)
  target:SetHeight(18)

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
  end

  if not target._acbScrollGlyph and target.CreateFontString then
    local label = target:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("CENTER", target, "CENTER", 0, 0)
    label:SetFont(BUTTON_FONT, 9, "OUTLINE")
    target._acbScrollGlyph = label
  end

  if target._acbScrollGlyph then
    target._acbScrollGlyph:SetText(glyph or "")
  end

  SetScrollButtonVisual(target)

  if not target._acbScrollHooks and target.HookScript then
    target:HookScript("OnEnter", function(self)
      SetScrollButtonVisual(self, "hover")
      end)
    target:HookScript("OnLeave", function(self)
      SetScrollButtonVisual(self)
      end)
    target:HookScript("OnMouseDown", function(self)
      SetScrollButtonVisual(self, "hover")
      end)
    target:HookScript("OnMouseUp", function(self)
      SetScrollButtonVisual(self)
      end)
    target._acbScrollHooks = true
  end
end

local function SkinScrollBar(scrollFrame)
  if not scrollFrame or not scrollFrame.GetName then
    return
  end

  local frameName = scrollFrame:GetName()
  local scrollBar = _G[frameName .. "ScrollBar"] or scrollFrame.ScrollBar

  if not scrollBar then
    return
  end

  local scrollBarName = scrollBar.GetName and scrollBar:GetName() or frameName .. "ScrollBar"
  local upButton = _G[scrollBarName .. "ScrollUpButton"] or _G[frameName .. "ScrollUpButton"]
  local downButton = _G[scrollBarName .. "ScrollDownButton"] or _G[frameName .. "ScrollDownButton"]

  StripFrameTextures(scrollBar)
  scrollBar:SetWidth(18)

  if scrollBar.SetBackdrop then
    scrollBar:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
    ApplyColor(scrollBar, "SetBackdropColor", THEME.bg)
    ApplyColor(scrollBar, "SetBackdropBorderColor", THEME.borderDim)
  end

  SkinScrollButton(upButton, "^")
  SkinScrollButton(downButton, "v")

  if scrollBar.GetThumbTexture then
    local thumb = scrollBar:GetThumbTexture()
    if thumb then
      thumb:SetTexture(WHITE8X8)
      thumb:SetVertexColor(THEME.button[1], THEME.button[2], THEME.button[3], THEME.button[4] or 1)
      thumb:Show()
    end
  end

  scrollBar._acbUpButton = upButton
  scrollBar._acbDownButton = downButton
  scrollFrame._acbScrollBar = scrollBar

  return scrollBar
end

local function SetCheckboxVisual(target, mode)
  if not target then
    return
  end

  local visualMode = mode or (IsMouseOverFrame(target) and "hover" or nil)

  ApplyColor(target, "SetBackdropColor", THEME.checkbox)
  ApplyColor(target, "SetBackdropBorderColor", visualMode == "hover" and THEME.buttonHoverBorder or THEME.checkboxBorder)

  if target._acbCheck then
    if target.GetChecked and target:GetChecked() then
      target._acbCheck:Show()
    else
      target._acbCheck:Hide()
    end
  end
end

local function SkinCheckbox(target)
  if not target then
    return
  end

  StripButtonChrome(target)
  target:SetWidth(18)
  target:SetHeight(18)

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
  end

  if not target._acbCheck and target.CreateTexture then
    local check = target:CreateTexture(nil, "OVERLAY")
    check:SetTexture(WHITE8X8)
    check:SetPoint("TOPLEFT", target, "TOPLEFT", 4, -4)
    check:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -4, 4)
    check:SetVertexColor(THEME.checkboxChecked[1], THEME.checkboxChecked[2], THEME.checkboxChecked[3], THEME.checkboxChecked[4] or 1)
    target._acbCheck = check
  end

  SetCheckboxVisual(target)

  if not target._acbCheckboxHooks and target.HookScript then
    target:HookScript("OnEnter", function(self)
      SetCheckboxVisual(self, "hover")
      end)
    target:HookScript("OnLeave", function(self)
      SetCheckboxVisual(self)
      end)
    target:HookScript("OnClick", function(self)
      SetCheckboxVisual(self)
      end)
    target._acbCheckboxHooks = true
  end
end

local function SkinEditBox(target)
  if not target then
    return
  end

  StripFrameTextures(target)

  if target.SetTextColor then
    target:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
  end

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
    ApplyColor(target, "SetBackdropColor", THEME.bgSoft)
    ApplyColor(target, "SetBackdropBorderColor", THEME.borderDim)
  end
end

local function SkinScrollPanel(target)
  if not target then
    return
  end

  StripFrameTextures(target)

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
    ApplyColor(target, "SetBackdropColor", THEME.bg)
    ApplyColor(target, "SetBackdropBorderColor", THEME.borderDim)
  end
end

local function SkinTitleText(target)
  if target and target.SetTextColor then
    target:SetTextColor(THEME.title[1], THEME.title[2], THEME.title[3])
  end
end

local function SkinHeadingText(target)
  if target and target.SetTextColor then
    target:SetTextColor(THEME.heading[1], THEME.heading[2], THEME.heading[3], THEME.heading[4] or 1)
  end
end

local function SkinMutedText(target)
  if target and target.SetTextColor then
    target:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3])
  end
end

local function Print(message)
  DEFAULT_CHAT_FRAME:AddMessage(ADDON_PREFIX .. message)
end

local function SkinHelpButton(target)
  if not target then
    return
  end

  target:SetWidth(18)
  target:SetHeight(18)

  if target.SetBackdrop then
    target:SetBackdrop({
      bgFile = WHITE8X8,
      edgeFile = WHITE8X8,
      edgeSize = 1,
    })
    ApplyColor(target, "SetBackdropColor", THEME.close)
    ApplyColor(target, "SetBackdropBorderColor", THEME.closeBorder)
  end

  target._acbHelpText = target:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  target._acbHelpText:SetPoint("CENTER", target, "CENTER", 0, 0)
  target._acbHelpText:SetText("?")
  target._acbHelpText:SetTextColor(THEME.closeText[1], THEME.closeText[2], THEME.closeText[3], THEME.closeText[4] or 1)

  target:SetScript("OnEnter", function()
    ApplyColor(target, "SetBackdropColor", THEME.close)
    ApplyColor(target, "SetBackdropBorderColor", THEME.closeBorder)
    target._acbHelpText:SetTextColor(THEME.closeText[1], THEME.closeText[2], THEME.closeText[3], THEME.closeText[4] or 1)
    end)
  target:SetScript("OnLeave", function()
    ApplyColor(target, "SetBackdropColor", THEME.close)
    ApplyColor(target, "SetBackdropBorderColor", THEME.closeBorder)
    target._acbHelpText:SetTextColor(THEME.closeText[1], THEME.closeText[2], THEME.closeText[3], THEME.closeText[4] or 1)
    end)
end

local UpdateRollToggleButtons
local StopRolling
local TargetCallboard
local ClearRollPause

function AutoCallboardRuntime.GetSummonMacroText()
  if state and state.summonSpell and state.summonSpell ~= "" then
    return "/cast " .. state.summonSpell
  end

  return nil
end

local function ApplyState(nextState)
  state = Core.mergeState(nextState)
  AutoCallboardDB = state

  if questWindow and questWindow:IsShown() and UpdateQuestWindow then
    UpdateQuestWindow()
  end

  if minimapButton then
    PositionMinimapButton()
  end
end

local function GetCharacterProfileKey()
  local playerName = UnitName and UnitName("player") or "Unknown"
  local realmName = GetRealmName and GetRealmName() or "UnknownRealm"

  if playerName == "" then
    playerName = "Unknown"
  end

  if realmName == "" then
    realmName = "UnknownRealm"
  end

  return realmName .. "/" .. playerName
end

local function ApplyCharacterProfile()
  characterProfileKey = GetCharacterProfileKey()

  local nextState = Core.mergeState(state)
  nextState.characterProfiles = Core.copyCharacterProfiles(state.characterProfiles)
  nextState.characterProfiles[characterProfileKey] = nextState.characterProfiles[characterProfileKey] or {
      desiredQuests = Core.copyDesiredMap(state.desiredQuests),
    }
  nextState.desiredQuests = Core.copyDesiredMap(nextState.characterProfiles[characterProfileKey].desiredQuests)

  state = nextState
  AutoCallboardDB = state
end

local function SaveCharacterDesiredQuests()
  if not characterProfileKey then
    characterProfileKey = GetCharacterProfileKey()
  end

  local nextState = Core.mergeState(state)
  nextState.characterProfiles = Core.copyCharacterProfiles(state.characterProfiles)
  nextState.characterProfiles[characterProfileKey] = nextState.characterProfiles[characterProfileKey] or {}
  nextState.characterProfiles[characterProfileKey].desiredQuests = Core.copyDesiredMap(nextState.desiredQuests)

  state = nextState
  AutoCallboardDB = state
end

local function RegisterSpecialFrame(frameName)
  if type(frameName) ~= "string" or frameName == "" or registeredSpecialFrames[frameName] then
    return
  end

  if type(UISpecialFrames) ~= "table" then
    return
  end

  for i = 1, table.getn(UISpecialFrames) do
    if UISpecialFrames[i] == frameName then
      registeredSpecialFrames[frameName] = true
      return
    end
  end

  table.insert(UISpecialFrames, frameName)
  registeredSpecialFrames[frameName] = true
end

local function HelpName(text)
  return "|cffb048f8" .. tostring(text or "") .. "|r"
end

local function GetHelpText()
  local lines = {
    "1. Begin in " .. HelpName("Quests") .. ".",
    "   Tick the box beside every quest you want the addon to hunt for.",
    "   Anything ticked is treated as a wanted quest.",
    "",
    "2. A new install starts with a small list.",
    "   Every quest that appears on the board gets recorded automatically.",
    "   The list fills out the more you roll.",
    "   Export/Import can copy the list between installs.",
    "",
    "3. Press " .. HelpName("Start") .. " once your picks are set.",
    "   Start on its own casts nothing.",
    "   It sits idle until board data is readable, then begins rerolling.",
    "",
    "4. Press " .. HelpName("Callboard") .. " whenever no board is up.",
    "   Standing near a permanent Objectives Board instead?",
    "   Click that board once so the addon can read its quests.",
    "",
    "5. Rolling halts the moment a ticked quest lands.",
    "   The addon grabs that quest for you and pauses itself.",
    "   Once you've completed it, rolling is ready to resume.",
    "",
    "6. Press " .. HelpName("Stop") .. " whenever you've had enough.",
    "",
    "7. Mind your wallet.",
    "   Every reroll has a price.",
    "   Hunting a low-odds quest can burn through dozens of attempts.",
    "",
    "Helpful buttons:",
    "",
    "- " .. HelpName("Callboard") .. ": opens a nearby board, or casts the summon.",
    "- " .. HelpName("Start") .. ": kicks off rolling and flips to Stop while running.",
    "- " .. HelpName("Share") .. ": pushes your most recently accepted quest again.",
    "- " .. HelpName("Auto Accept Quests") .. ": accepts quests shared by party or raid members.",
    "  It does not filter by quest ID or quest name.",
    "- " .. HelpName("Search") .. ": narrows the known list by title, objective, type, or reward.",
    "- " .. HelpName("Select") .. ": grabs one of the quests currently showing on the board.",
    "- " .. HelpName("Export") .. " / " .. HelpName("Import") .. ": copies the learned quest list in or out.",
  }

  return table.concat(lines, "\n")
end

local function ShowAddonHelp(kind)
  if not helpWindow then
    helpWindow = CreateFrame("Frame", "AutoCallboardHelpWindow", UIParent)
    RegisterSpecialFrame("AutoCallboardHelpWindow")
    helpWindow:SetWidth(430)
    helpWindow:SetHeight(560)
    helpWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    helpWindow:SetFrameStrata("FULLSCREEN_DIALOG")
    if helpWindow.SetToplevel then
      helpWindow:SetToplevel(true)
    end
    helpWindow:SetMovable(true)
    helpWindow:EnableMouse(true)
    helpWindow:RegisterForDrag("LeftButton")
    helpWindow:SetClampedToScreen(true)
    SkinFrame(helpWindow)
    helpWindow:SetScript("OnDragStart", function(self)
      self:StartMoving()
      end)
    helpWindow:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      end)

    helpWindow.title = helpWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    helpWindow.title:SetPoint("TOP", helpWindow, "TOP", 0, -18)
    SkinHeadingText(helpWindow.title)

    helpWindow.closeButton = CreateFrame("Button", nil, helpWindow)
    helpWindow.closeButton:SetPoint("TOPRIGHT", helpWindow, "TOPRIGHT", -4, -4)
    SkinCloseButton(helpWindow.closeButton, helpWindow)

    helpWindow.body = helpWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    helpWindow.body:SetPoint("TOPLEFT", helpWindow, "TOPLEFT", 24, -52)
    helpWindow.body:SetPoint("BOTTOMRIGHT", helpWindow, "BOTTOMRIGHT", -24, 44)
    helpWindow.body:SetJustifyH("LEFT")
    helpWindow.body:SetJustifyV("TOP")
    helpWindow.body:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3], THEME.text[4] or 1)

    helpWindow.okButton = CreateFrame("Button", nil, helpWindow, "UIPanelButtonTemplate")
    helpWindow.okButton:SetWidth(78)
    helpWindow.okButton:SetHeight(24)
    helpWindow.okButton:SetText("Close")
    helpWindow.okButton:SetPoint("BOTTOMRIGHT", helpWindow, "BOTTOMRIGHT", -24, 18)
    SkinButton(helpWindow.okButton)
    helpWindow.okButton:SetScript("OnClick", function()
      helpWindow:Hide()
      end)
  end

  helpWindow.title:SetText("AutoCallboard Help")
  helpWindow.body:SetText(GetHelpText())
  helpWindow:Show()
  if helpWindow.Raise then
    helpWindow:Raise()
  end
end

local function SecondsRemaining(untilTime)
  if not untilTime then
    return 0
  end

  return math.max(0, untilTime - GetTime())
end

local SyncCallboardActiveFromCooldown
local GetFallbackCooldownRemaining

local function IsCallboardActive()
  if SecondsRemaining(callboardActiveUntil) > 0 then
    return true
  end

  if SecondsRemaining(AutoCallboardRuntime.objectiveBoardReadyUntil) > 0 then
    return true
  end

  if AutoCallboardRuntime.GetNpcBoardInfo and AutoCallboardRuntime.GetNpcBoardInfo() then
    return true
  end

  if AutoCallboardRuntime.IsCallboardUiPresent and AutoCallboardRuntime.IsCallboardUiPresent() then
    return true
  end

  return false
end

local function GetCallboardCooldownRemaining()
  if not state then
    return 0, false
  end

  if GetSpellCooldown and state.summonSpellID then
    local start, duration = GetSpellCooldown(state.summonSpellID)

    if start then
      if start > 0 and duration and duration > 1.5 then
        return math.max(0, start + duration - GetTime()), true
      end

      return 0, true
    end
  end

  if GetSpellCooldown and state.summonSpell and state.summonSpell ~= "" then
    local start, duration = GetSpellCooldown(state.summonSpell)

    if start then
      if start > 0 and duration and duration > 1.5 then
        return math.max(0, start + duration - GetTime()), true
      end

      return 0, true
    end
  end

  if GetItemCooldown and state.summonSpellID then
    local start, duration = GetItemCooldown(state.summonSpellID)

    if start and start > 0 and duration and duration > 1.5 then
      return math.max(0, start + duration - GetTime()), true
    end
  end

  return 0, false
end

GetFallbackCooldownRemaining = function()
  return SecondsRemaining(fallbackCooldownUntil)
end

local function GetSummonCooldownRemaining()
  local cooldownRemaining, observed = GetCallboardCooldownRemaining()

  if observed then
    if cooldownRemaining <= 0 then
      fallbackCooldownUntil = nil
      callboardActiveUntil = nil
    end

    return cooldownRemaining
  end

  return GetFallbackCooldownRemaining()
end

SyncCallboardActiveFromCooldown = function(source)
  if source == "cooldown inference" then
    local now = GetTime()

    if AutoCallboardRuntime.nextCooldownInferenceAt and now < AutoCallboardRuntime.nextCooldownInferenceAt then
      return SecondsRemaining(callboardActiveUntil) > 0
    end

    AutoCallboardRuntime.nextCooldownInferenceAt = now + 0.5
  end

  if AutoCallboardRuntime.StartCallboardTimersFromCooldown and AutoCallboardRuntime.StartCallboardTimersFromCooldown(source) then
    return SecondsRemaining(callboardActiveUntil) > 0
  end

  return false
end

function AutoCallboardRuntime.StartCallboardTimersFromCooldown(source)
  if not state then
    return false
  end

  local cooldownRemaining, observed = GetCallboardCooldownRemaining()
  local inactiveCooldownTail = math.max(0, (state.summonCooldown or 45) - (state.summonDuration or 30))

  if cooldownRemaining <= 0 then
    if observed then
      fallbackCooldownUntil = nil
      callboardActiveUntil = nil
    end

    return false
  end

  local now = GetTime()
  local activeRemaining = 0
  fallbackCooldownUntil = now + cooldownRemaining

  if cooldownRemaining > inactiveCooldownTail then
    activeRemaining = math.min(state.summonDuration or 30, cooldownRemaining - inactiveCooldownTail)
    callboardActiveUntil = now + activeRemaining
  else
    callboardActiveUntil = nil
  end

  if source ~= "cooldown inference" then
    AppendDebugLog("summon", "synced timers from spell cooldown source=" .. tostring(source) .. " active=" .. tostring(activeRemaining) .. " cooldown=" .. tostring(cooldownRemaining))
  end

  if source ~= "cooldown inference" and activeRemaining > 0 and ResumeRollingAfterCallboardActive and AutoCallboardRuntime.IsCallboardDataAvailable and AutoCallboardRuntime.IsCallboardDataAvailable() then
    ResumeRollingAfterCallboardActive(source)
  end

  return true
end

function AutoCallboardRuntime.QueueSummonCooldownSync()
  AutoCallboardRuntime.pendingCooldownSyncUntil = GetTime() + 3
end

function AutoCallboardRuntime.SyncPendingSummonCooldown()
  if not AutoCallboardRuntime.pendingCooldownSyncUntil then
    return
  end

  if AutoCallboardRuntime.StartCallboardTimersFromCooldown("pending cooldown sync") then
    AutoCallboardRuntime.pendingCooldownSyncUntil = nil
    UpdateSummonStatus()
    return
  end

  if GetTime() > AutoCallboardRuntime.pendingCooldownSyncUntil then
    AutoCallboardRuntime.pendingCooldownSyncUntil = nil
  end
end

local function IsSummonSpellUsable()
  if IsUsableSpell and state.summonSpell and state.summonSpell ~= "" then
    local usable = IsUsableSpell(state.summonSpell)

    if usable ~= nil then
      return usable ~= false and usable ~= 0
    end
  end

  if IsUsableSpell and state.summonSpellID then
    local usable = IsUsableSpell(state.summonSpellID)

    if usable ~= nil then
      return usable ~= false and usable ~= 0
    end
  end

  return true
end

local function MarkCallboardSummoned(source)
  AutoCallboardRuntime.pendingSummonVerifyUntil = nil
  AutoCallboardRuntime.pendingSummonSource = nil
  AutoCallboardRuntime.QueueSummonCooldownSync()

  if AutoCallboardRuntime.StartCallboardTimersFromCooldown(source) then
    return
  end

  local now = GetTime()
  callboardActiveUntil = now + state.summonDuration
  fallbackCooldownUntil = now + state.summonCooldown
  AppendDebugLog("summon", "started fallback timer " .. tostring(source) .. " active=" .. tostring(state.summonDuration) .. " cooldown=" .. tostring(state.summonCooldown))

  if ResumeRollingAfterCallboardActive and AutoCallboardRuntime.IsCallboardDataAvailable and AutoCallboardRuntime.IsCallboardDataAvailable() then
    ResumeRollingAfterCallboardActive(source)
  end
end

function AutoCallboardRuntime.BeginSummonAttempt(source)
  AutoCallboardRuntime.pendingSummonSource = source
  AutoCallboardRuntime.pendingSummonVerifyUntil = GetTime() + 2.5
  AppendDebugLog("summon", "waiting for verified summon source=" .. tostring(source))
end

function AutoCallboardRuntime.CheckPendingSummonAttempt()
  if not AutoCallboardRuntime.pendingSummonVerifyUntil then
    return
  end

  local source = tostring(AutoCallboardRuntime.pendingSummonSource)

  if AutoCallboardRuntime.IsCallboardUiPresent and AutoCallboardRuntime.IsCallboardUiPresent() then
    MarkCallboardSummoned(source .. " ui verified")
    QueueCallboardFollowup(source .. " ui verified")
    return
  end

  if GetSummonCooldownRemaining() > 0 or SecondsRemaining(callboardActiveUntil) > 0 then
    MarkCallboardSummoned(source .. " cooldown verified")
    QueueCallboardFollowup(source .. " cooldown verified")
    return
  end

  if GetTime() <= AutoCallboardRuntime.pendingSummonVerifyUntil then
    return
  end

  AutoCallboardRuntime.pendingSummonVerifyUntil = nil
  AutoCallboardRuntime.pendingSummonSource = nil
  nextSummonCastAt = nil
  AppendDebugLog("summon", "summon attempt was not verified source=" .. tostring(source))

  if rolling then
    SetRollPause("no_callboard", "Paused: waiting for Callboard. Rolling will resume when it opens.")
  end

  UpdateSummonStatus()
end

local function FormatSeconds(value)
  return tostring(math.floor(math.max(0, value or 0))) .. "s"
end

UpdateSummonStatus = function()
  if not summonStatusText or not state then
    return
  end

  local activeRemaining = SecondsRemaining(callboardActiveUntil)
  local cooldownRemaining = GetSummonCooldownRemaining()

  if activeRemaining > 0 then
    summonStatusText:SetText("Callboard active: " .. FormatSeconds(activeRemaining) .. " | cooldown: " .. FormatSeconds(cooldownRemaining))
  elseif cooldownRemaining > 0 then
    summonStatusText:SetText("Callboard cooldown: " .. FormatSeconds(cooldownRemaining))
  else
    summonStatusText:SetText("Callboard ready.")
  end
end

local function GetObjectivesService()
  if ProjectEbonhold and ProjectEbonhold.ObjectivesService then
    return ProjectEbonhold.ObjectivesService
  end

  return nil
end

local function GetCurrentObjectives()
  local service = GetObjectivesService()

  if service and service.GetCurrentObjectives then
    local objectives = service.GetCurrentObjectives()
    if type(objectives) == "table" then
      return objectives
    end
  end

  return {}
end

local function GetActiveObjective()
  local service = GetObjectivesService()

  if service and service.GetActiveObjective then
    local objective = service.GetActiveObjective()
    if type(objective) == "table" then
      return objective
    end
  end

  return nil
end

function AutoCallboardRuntime.FrameIsVisibleOrShown(target)
  if not target then
    return false
  end

  if target.IsVisible and target:IsVisible() then
    return true
  end

  if not target.IsVisible and target.IsShown and target:IsShown() then
    return true
  end

  return false
end

function AutoCallboardRuntime.AnyFrameInChainVisible(target, maxDepth)
  local current = target
  local depth = 0

  while current and depth < (maxDepth or 5) do
    if AutoCallboardRuntime.FrameIsVisibleOrShown(current) then
      return true
    end

    current = current.GetParent and current:GetParent() or nil
    depth = depth + 1
  end

  return false
end

function AutoCallboardRuntime.IsCallboardUiPresent()
  if not state then
    return false
  end

  if AutoCallboardRuntime.FrameIsVisibleOrShown(_G.ObjectivesMainFrame) then
    return true
  end

  for i = 1, 3 do
    if AutoCallboardRuntime.FrameIsVisibleOrShown(_G[state.objectivePrefix .. tostring(i)]) then
      return true
    end
  end

  return AutoCallboardRuntime.FrameIsVisibleOrShown(ResolveFramePath(state.rerollFrame))
end

function AutoCallboardRuntime.HasCurrentObjectiveData()
  return table.getn(GetCurrentObjectives()) > 0
end

function AutoCallboardRuntime.IsCallboardDataAvailable()
  if AutoCallboardRuntime.IsCallboardUiPresent() then
    return true
  end

  if AutoCallboardRuntime.GetNpcBoardInfo
      and AutoCallboardRuntime.GetNpcBoardInfo()
      and AutoCallboardRuntime.HasCurrentObjectiveData() then
    return true
  end

  return AutoCallboardRuntime.objectiveBoardAccessOpen
      and SecondsRemaining(AutoCallboardRuntime.objectiveBoardReadyUntil) > 0
      and AutoCallboardRuntime.HasCurrentObjectiveData()
end

function AutoCallboardRuntime.IsCallboardReadyForQuestActions()
  return AutoCallboardRuntime.GetBoardAccessState("quest actions").ok
end

function AutoCallboardRuntime.GetBoardAccessState(action)
  local service = GetObjectivesService()
  local uiOpen = AutoCallboardRuntime.IsCallboardUiPresent()
  local sessionOpen = AutoCallboardRuntime.objectiveBoardAccessOpen
      and SecondsRemaining(AutoCallboardRuntime.objectiveBoardReadyUntil) > 0
  local npcBoard = AutoCallboardRuntime.GetNpcBoardInfo and AutoCallboardRuntime.GetNpcBoardInfo() or nil
  local dataReady = AutoCallboardRuntime.HasCurrentObjectiveData()
  local activeRemaining = SecondsRemaining(callboardActiveUntil)

  if not service then
    return {
      ok = false,
      reason = "objectives_service_missing",
      message = "Project Ebonhold objective service is not loaded.",
    }
  end

  if uiOpen or sessionOpen or npcBoard then
    if dataReady then
      return {
        ok = true,
        boardOpen = true,
        source = uiOpen and "objectives_ui" or npcBoard and "npc_token" or "objectives_gossip",
        reason = "ready",
        message = "Board is open.",
        boardName = npcBoard and npcBoard.name or nil,
        boardObjectId = npcBoard and npcBoard.objectId or nil,
      }
    end

    return {
      ok = false,
      boardOpen = true,
      needsData = true,
      source = uiOpen and "objectives_ui" or npcBoard and "npc_token" or "objectives_gossip",
      reason = "objective_data_missing",
      message = "Board is open, but objective data is not ready yet.",
      boardName = npcBoard and npcBoard.name or nil,
      boardObjectId = npcBoard and npcBoard.objectId or nil,
    }
  end

  if activeRemaining > 0 then
    return {
      ok = false,
      callboardActive = true,
      reason = "board_window_not_open",
      message = "Callboard is active, but the board window is not open. Click the board.",
    }
  end

  return {
    ok = false,
    reason = "board_not_open",
    message = "Paused: click the Objectives Board, or use Callboard.",
    action = action,
  }
end

function AutoCallboardRuntime.RequestObjectiveBoardData(source)
  local now = GetTime()

  if AutoCallboardRuntime.HasCurrentObjectiveData() then
    AutoCallboardRuntime.objectiveRequestPendingUntil = nil
    AutoCallboardRuntime.objectiveRequestAttempts = 0
    return true
  end

  if AutoCallboardRuntime.objectiveRequestPendingUntil and now < AutoCallboardRuntime.objectiveRequestPendingUntil then
    return true
  end

  if AutoCallboardRuntime.nextObjectiveRequestAt and now < AutoCallboardRuntime.nextObjectiveRequestAt then
    return true
  end

  if AutoCallboardRuntime.objectiveRequestAttempts and AutoCallboardRuntime.objectiveRequestAttempts >= 2 then
    return false
  end

  local service = GetObjectivesService()
  if not service or not service.RequestObjectives then
    return false
  end

  AutoCallboardRuntime.objectiveRequestAttempts = (AutoCallboardRuntime.objectiveRequestAttempts or 0) + 1
  AutoCallboardRuntime.objectiveRequestPendingUntil = now + 2.5
  AutoCallboardRuntime.nextObjectiveRequestAt = now + 3
  service.RequestObjectives()
  AppendDebugLog("summon", "requested Objectives Board data source=" .. tostring(source) .. " attempt=" .. tostring(AutoCallboardRuntime.objectiveRequestAttempts))

  return true
end

function AutoCallboardRuntime.CleanBoardText(value)
  if type(value) ~= "string" then
    return ""
  end

  value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  value = value:gsub("^%s+", ""):gsub("%s+$", "")

  return value
end

function AutoCallboardRuntime.IsObjectiveBoardName(value)
  value = AutoCallboardRuntime.CleanBoardText(value)

  for i = 1, table.getn(BOARD_TARGET_PRIMARY_NAMES) do
    if value == BOARD_TARGET_PRIMARY_NAMES[i] then
      return true, value
    end
  end

  return false, value
end

function AutoCallboardRuntime.IsObjectiveBoardGossipName(npcName)
  return AutoCallboardRuntime.IsObjectiveBoardName(npcName)
end

function AutoCallboardRuntime.ExtractBoardObjectIdFromGuid(guid)
  if type(guid) ~= "string" then
    return nil
  end

  local hex = guid:gsub("^0x", "")
  if string.len(hex) < 10 then
    return nil
  end

  local prefix = string.sub(hex, 1, 4)
  if prefix ~= "F110" and prefix ~= "F130" then
    return nil
  end

  return tonumber(string.sub(hex, 5, 10), 16)
end

function AutoCallboardRuntime.IsKnownBoardObjectId(objectId)
  return objectId and BOARD_OBJECT_IDS[tonumber(objectId)] == true
end

function AutoCallboardRuntime.IsBoardNpcName(value)
  local isObjectiveName, cleanName = AutoCallboardRuntime.IsObjectiveBoardName(value)
  if isObjectiveName then
    return true, cleanName
  end

  if state and cleanName == state.targetName then
    return true, cleanName
  end

  return false, cleanName
end

function AutoCallboardRuntime.IsGossipFrameOpen()
  return GossipFrame and GossipFrame.IsShown and GossipFrame:IsShown()
end

function AutoCallboardRuntime.GetNpcBoardInfo()
  if not AutoCallboardRuntime.IsGossipFrameOpen() then
    return nil
  end

  local name = UnitName and AutoCallboardRuntime.CleanBoardText(UnitName("npc")) or ""
  local guid = UnitGUID and UnitGUID("npc") or nil
  local objectId = AutoCallboardRuntime.ExtractBoardObjectIdFromGuid(guid)
  local nameMatches, cleanName = AutoCallboardRuntime.IsBoardNpcName(name)
  local idMatches = AutoCallboardRuntime.IsKnownBoardObjectId(objectId)

  if not nameMatches and not idMatches then
    return nil
  end

  return {
    name = cleanName,
    guid = guid,
    objectId = objectId,
    nameMatches = nameMatches,
    idMatches = idMatches,
  }
end

function AutoCallboardRuntime.GetTooltipLineText(index)
  local line = _G["GameTooltipTextLeft" .. tostring(index)]

  if line and line.GetText then
    return line:GetText()
  end

  return nil
end

function AutoCallboardRuntime.GetWorldTooltipBoardName()
  if not GameTooltip or not GameTooltip.IsShown or not GameTooltip:IsShown() then
    return nil
  end

  local focus = GetMouseFocus and GetMouseFocus() or nil
  local worldTooltip = WorldFrame and focus == WorldFrame

  if not worldTooltip and GameTooltip.IsOwned and WorldFrame and GameTooltip:IsOwned(WorldFrame) then
    worldTooltip = true
  end

  if not worldTooltip then
    return nil
  end

  for i = 1, 4 do
    local isBoard, boardName = AutoCallboardRuntime.IsObjectiveBoardName(AutoCallboardRuntime.GetTooltipLineText(i))

    if isBoard then
      return boardName
    end
  end

  return nil
end

function AutoCallboardRuntime.MarkObjectiveBoardAccess(source, boardName, duration)
  local accessDuration = tonumber(duration) or (state and state.summonDuration or 30)
  AutoCallboardRuntime.objectiveBoardReadyUntil = GetTime() + accessDuration
  AutoCallboardRuntime.objectiveBoardAccessOpen = true
  AutoCallboardRuntime.manualBoardOpenRequired = false
  AppendDebugLog("guard", "board access source=" .. tostring(source) .. " name=" .. tostring(boardName) .. " duration=" .. tostring(accessDuration))
end

function AutoCallboardRuntime.DetectBoardAccess(source)
  if IsCallboardActive() then
    return true
  end

  local targeted, targetName = TargetCallboard()
  if targeted then
    AutoCallboardRuntime.MarkObjectiveBoardAccess(source, targetName)
    return true
  end

  return false
end

function AutoCallboardRuntime.MarkObjectiveBoardOpened(source)
  AutoCallboardRuntime.objectiveBoardReadyUntil = GetTime() + (state and state.summonDuration or 30)
  AutoCallboardRuntime.objectiveBoardAccessOpen = true
  AutoCallboardRuntime.manualBoardOpenRequired = false
  AutoCallboardRuntime.RequestObjectiveBoardData(source)
  AppendDebugLog("guard", "board opened source=" .. tostring(source))

  if rolling and (rollPausedReason == "manual_board" or rollPausedReason == "no_callboard") then
    ClearRollPause()
    nextRollAt = GetTime() + 0.2
  end
end

function AutoCallboardRuntime.MarkObjectiveBoardClosed(source)
  if not AutoCallboardRuntime.objectiveBoardAccessOpen then
    return
  end

  AutoCallboardRuntime.objectiveBoardAccessOpen = false
  AutoCallboardRuntime.objectiveBoardReadyUntil = nil
  AppendDebugLog("guard", "board closed source=" .. tostring(source))

  if rolling and rollPausedReason ~= "quest_selected" and not IsCallboardActive() then
    AutoCallboardRuntime.SetManualBoardOpenRequired(source)
  end
end

local function ObjectiveSignature(objectives)
  local parts = {}

  if type(objectives) ~= "table" then
    return ""
  end

  for i = 1, table.getn(objectives) do
    table.insert(parts, Core.questKey(objectives[i]) or tostring(i))
  end

  return table.concat(parts, "|")
end

local function CaptureCurrentObjectives()
  if not state then
    return {}
  end

  if not AutoCallboardRuntime.IsCallboardDataAvailable() then
    lastCapturedSignature = nil
    return {}
  end

  local objectives = GetCurrentObjectives()
  local signature = ObjectiveSignature(objectives)

  if signature == lastCapturedSignature then
    return objectives
  end

  lastCapturedSignature = signature
  local previousCount = table.getn(state.knownQuests or {})
  local nextState = Core.mergeState(state)
  nextState.knownQuests = Core.captureKnownQuests(state.knownQuests, objectives, rollCount)
  state = nextState
  AutoCallboardDB = state

  local nextCount = table.getn(state.knownQuests or {})
  if nextCount > previousCount then
    AppendDebugLog("quest-watch", "learned " .. tostring(nextCount - previousCount) .. " quest(s); known=" .. tostring(nextCount) .. " signature=" .. signature)
  end

  return objectives
end

local function CountDesiredQuests()
  local count = 0

  for _, enabled in pairs(state.desiredQuests or {}) do
    if enabled then
      count = count + 1
    end
  end

  return count
end

local function SetQuestStatus(message)
  if questStatusText then
    questStatusText:SetText(message)
  end

  AppendDebugLog("quest", message)
end

local function RequireActiveCallboard(action)
  local access = AutoCallboardRuntime.GetBoardAccessState(action)

  if access.ok then
    return true
  end

  local message = access.message or "Board is not ready for " .. tostring(action) .. "."
  SetQuestStatus(message)
  Print(message)
  AppendDebugLog("guard", "blocked " .. tostring(action) .. " reason=" .. tostring(access.reason) .. " source=" .. tostring(access.source or "none"))

  return false
end

SetRollPause = function(reason, message)
  if rollPausedReason == reason and rollPauseMessage == message then
    return
  end

  rollPausedReason = reason
  rollPauseMessage = message
  pendingReroll = false
  nextRollAt = nil
  pendingRerollUntil = nil

  if message then
    SetQuestStatus(message)
  end

  AppendDebugLog("roll", "paused reason=" .. tostring(reason))
end

ClearRollPause = function(reason)
  if reason and rollPausedReason ~= reason then
    return
  end

  if rollPausedReason then
    AppendDebugLog("roll", "resumed from " .. tostring(rollPausedReason))
  end

  rollPausedReason = nil
  rollPauseMessage = nil
end

AutoCallboardRuntime.SetManualBoardOpenRequired = function(source)
  AutoCallboardRuntime.manualBoardOpenRequired = true
  AutoCallboardRuntime.objectiveRequestPendingUntil = nil
  AutoCallboardRuntime.nextObjectiveRequestAt = nil
  pendingInteractAt = nil
  AutoCallboardRuntime.pendingInteractSource = nil
  pendingAcceptUntil = nil
  SetRollPause("manual_board", "Paused: click the Objectives Board, or use Callboard.")
  AppendDebugLog("guard", "board required before rolling source=" .. tostring(source))
end

local function StartSelectedQuestPause(quest, index)
  if not rolling or not quest then
    return
  end

  selectedQuest = {
    key = Core.questKey(quest),
    questId = tonumber(quest.questId or quest.id) or 0,
    title = Core.questTitle(quest),
    selectedAt = GetTime(),
    seenInLog = false,
    seenActiveObjective = false,
  }
  rollCount = 0
  nextSelectedQuestCheckAt = nil
  SetRollPause("quest_selected", "Paused: selected " .. QuestLabel(quest) .. " in slot " .. tostring(index) .. ".")
end

local function NormalizeQuestTitle(title)
  title = tostring(title or ""):lower()
  title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  title = title:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  return title
end

function AutoCallboardRuntime.GetQuestLogEntryInfo(index)
  if not GetQuestLogTitle then
    return nil
  end

  local title, _, _, fourth, fifth, sixth, seventh, eighth, ninth = GetQuestLogTitle(index)
  if not title then
    return nil
  end

  local wrathQuestID = tonumber(ninth)
  if wrathQuestID and wrathQuestID > 0 then
    return {
      title = title,
      isHeader = fifth,
      isComplete = seventh,
      questID = wrathQuestID,
    }
  end

  local questID = tonumber(eighth)
  return {
    title = title,
    isHeader = fourth,
    isComplete = sixth,
    questID = questID,
  }
end

local function GetQuestIdFromLogIndex(index)
  local entry = AutoCallboardRuntime.GetQuestLogEntryInfo(index)
  if entry and tonumber(entry.questID) and tonumber(entry.questID) > 0 then
    return tonumber(entry.questID)
  end

  if GetQuestLogQuestID then
    local questID = GetQuestLogQuestID(index)
    if tonumber(questID) and tonumber(questID) > 0 then
      return tonumber(questID)
    end
  end

  if GetQuestLink then
    local link = GetQuestLink(index)
    local questID = link and link:match("quest:(%d+)")
    if questID then
      return tonumber(questID)
    end
  end

  return nil
end

local function FindSelectedQuestInLog()
  if not selectedQuest or not GetNumQuestLogEntries or not GetQuestLogTitle then
    return false, false
  end

  local selectedID = tonumber(selectedQuest.questId) or 0
  local selectedTitle = NormalizeQuestTitle(selectedQuest.title)
  local entries = GetNumQuestLogEntries()

  for i = 1, entries do
    local entry = AutoCallboardRuntime.GetQuestLogEntryInfo(i)

    if entry and not entry.isHeader then
      local questID = tonumber(entry.questID) or GetQuestIdFromLogIndex(i)
      local idMatches = selectedID > 0 and questID == selectedID
      local titleMatches = selectedTitle ~= "" and NormalizeQuestTitle(entry.title) == selectedTitle

      if idMatches or titleMatches then
        return true, entry.isComplete == true or entry.isComplete == 1
      end
    end
  end

  return false, false
end

function AutoCallboardRuntime.FindQuestLogIndexByID(questID, preferredIndex)
  questID = tonumber(questID) or 0
  if questID <= 0 or not GetNumQuestLogEntries then
    return nil
  end

  if preferredIndex then
    local preferredEntry = AutoCallboardRuntime.GetQuestLogEntryInfo(preferredIndex)
    if preferredEntry and not preferredEntry.isHeader and tonumber(preferredEntry.questID) == questID then
      return preferredIndex, preferredEntry
    end
  end

  for i = 1, GetNumQuestLogEntries() do
    local entry = AutoCallboardRuntime.GetQuestLogEntryInfo(i)
    if entry and not entry.isHeader and tonumber(entry.questID) == questID then
      return i, entry
    end
  end

  return nil
end

function AutoCallboardRuntime.QuestShareLabel(quest)
  if not quest then
    return "quest"
  end

  local questID = tonumber(quest.questID) or tonumber(quest.questId) or 0
  local title = tostring(quest.title or "")
  if title ~= "" and questID > 0 then
    return tostring(questID) .. " " .. title
  end

  if questID > 0 then
    return tostring(questID)
  end

  if title ~= "" then
    return title
  end

  return "quest"
end

function AutoCallboardRuntime.ShareQuestLogIndex(index, quest, source)
  if not index or not SelectQuestLogEntry then
    AppendDebugLog("quest", "share blocked source=" .. tostring(source) .. " reason=missing SelectQuestLogEntry")
    return false, "Quest log selection is not available."
  end

  if not QuestLogPushQuest then
    AppendDebugLog("quest", "share blocked source=" .. tostring(source) .. " reason=missing QuestLogPushQuest")
    return false, "Quest sharing is not available."
  end

  local previousIndex = GetQuestLogSelection and GetQuestLogSelection() or nil
  SelectQuestLogEntry(index)

  if GetQuestLogPushable and not GetQuestLogPushable() then
    if previousIndex then
      SelectQuestLogEntry(previousIndex)
    end

    AppendDebugLog("quest", "share skipped source=" .. tostring(source) .. " quest=" .. AutoCallboardRuntime.QuestShareLabel(quest) .. " reason=not pushable")
    return false, "Quest is not shareable: " .. AutoCallboardRuntime.QuestShareLabel(quest)
  end

  QuestLogPushQuest()

  if previousIndex then
    SelectQuestLogEntry(previousIndex)
  end

  AppendDebugLog("quest", "shared source=" .. tostring(source) .. " quest=" .. AutoCallboardRuntime.QuestShareLabel(quest) .. " index=" .. tostring(index))
  return true
end

function AutoCallboardRuntime.ShareAcceptedQuest(source, silent)
  if not AutoCallboardRuntime.lastAcceptedQuest then
    if not silent then
      Print("No accepted quest recorded yet.")
    end
    AppendDebugLog("quest", "share skipped source=" .. tostring(source) .. " reason=no accepted quest")
    return false
  end

  local lastAcceptedQuest = AutoCallboardRuntime.lastAcceptedQuest
  local index, entry = AutoCallboardRuntime.FindQuestLogIndexByID(lastAcceptedQuest.questID, lastAcceptedQuest.questLogIndex)
  if entry and entry.title and entry.title ~= "" then
    lastAcceptedQuest.title = entry.title
  end

  if not index then
    if not silent then
      Print("Accepted quest is not in the quest log yet: " .. AutoCallboardRuntime.QuestShareLabel(lastAcceptedQuest))
    end
    AppendDebugLog("quest", "share pending source=" .. tostring(source) .. " quest=" .. AutoCallboardRuntime.QuestShareLabel(lastAcceptedQuest))
    return false, "pending"
  end

  local shared, message = AutoCallboardRuntime.ShareQuestLogIndex(index, {
      questID = lastAcceptedQuest.questID,
      title = lastAcceptedQuest.title,
    }, source)

  if shared then
    SetQuestStatus("Shared accepted quest: " .. AutoCallboardRuntime.QuestShareLabel(lastAcceptedQuest))
    if not silent then
      Print("Shared accepted quest: " .. AutoCallboardRuntime.QuestShareLabel(lastAcceptedQuest))
    end
  elseif message and not silent then
    Print(message)
  end

  return shared, message
end

function AutoCallboardRuntime.ProcessPendingAcceptedQuestShare(source)
  local pendingAcceptedQuestShare = AutoCallboardRuntime.pendingAcceptedQuestShare
  if not pendingAcceptedQuestShare then
    return
  end

  local now = GetTime()
  if pendingAcceptedQuestShare.nextAttemptAt and now < pendingAcceptedQuestShare.nextAttemptAt then
    return
  end

  if pendingAcceptedQuestShare.expiresAt and now > pendingAcceptedQuestShare.expiresAt then
    AppendDebugLog("quest", "share expired source=" .. tostring(source) .. " quest=" .. AutoCallboardRuntime.QuestShareLabel(pendingAcceptedQuestShare))
    AutoCallboardRuntime.pendingAcceptedQuestShare = nil
    return
  end

  pendingAcceptedQuestShare.nextAttemptAt = now + ACCEPTED_QUEST_SHARE_RETRY_INTERVAL
  local shared, message = AutoCallboardRuntime.ShareAcceptedQuest(source, true)

  if shared or message ~= "pending" then
    AutoCallboardRuntime.pendingAcceptedQuestShare = nil
  end
end

function AutoCallboardRuntime.TrackAcceptedQuest(arg1, arg2)
  local first = tonumber(arg1)
  local second = tonumber(arg2)
  local questLogIndex = second and first or nil
  local questID = second
  local entry

  if questLogIndex then
    entry = AutoCallboardRuntime.GetQuestLogEntryInfo(questLogIndex)
  elseif first then
    local possibleEntry = AutoCallboardRuntime.GetQuestLogEntryInfo(first)
    if possibleEntry and tonumber(possibleEntry.questID) and tonumber(possibleEntry.questID) ~= first then
      questLogIndex = first
      questID = tonumber(possibleEntry.questID)
      entry = possibleEntry
    else
      questID = first
    end
  end

  if (not questID or questID <= 0) and entry and tonumber(entry.questID) then
    questID = tonumber(entry.questID)
  end

  if not questID or questID <= 0 then
    AppendDebugLog("quest", "accepted quest id unavailable arg1=" .. tostring(arg1) .. " arg2=" .. tostring(arg2))
    return
  end

  AutoCallboardRuntime.lastAcceptedQuest = {
    questID = questID,
    questLogIndex = questLogIndex,
    title = entry and entry.title or "",
    acceptedAt = GetTime(),
  }
  AutoCallboardRuntime.pendingAcceptedQuestShare = {
    questID = questID,
    title = AutoCallboardRuntime.lastAcceptedQuest.title,
    questLogIndex = questLogIndex,
    expiresAt = GetTime() + ACCEPTED_QUEST_SHARE_TIMEOUT,
    nextAttemptAt = nil,
  }

  Print("Accepted quest: " .. AutoCallboardRuntime.QuestShareLabel(AutoCallboardRuntime.lastAcceptedQuest))
  AppendDebugLog("quest", "accepted " .. AutoCallboardRuntime.QuestShareLabel(AutoCallboardRuntime.lastAcceptedQuest) .. " index=" .. tostring(questLogIndex or "unknown"))
  if AutoCallboardRuntime.UpdateShareButtonState then
    AutoCallboardRuntime.UpdateShareButtonState()
  end
  AutoCallboardRuntime.ProcessPendingAcceptedQuestShare("QUEST_ACCEPTED")
end

function AutoCallboardRuntime.GetQuestOfferTitle()
  if GetTitleText then
    local ok, value = pcall(GetTitleText)
    if ok and type(value) == "string" and value ~= "" then
      return value
    end
  end

  if QuestTitleText and QuestTitleText.GetText then
    return QuestTitleText:GetText() or ""
  end

  return ""
end

function AutoCallboardRuntime.GetQuestOfferSourceName()
  if QuestFrameNpcNameText and QuestFrameNpcNameText.GetText then
    return QuestFrameNpcNameText:GetText()
  end

  return nil
end

function AutoCallboardRuntime.SafeUnitCheck(checker, unit)
  if not checker or not unit or unit == "" then
    return false
  end

  local ok, value = pcall(checker, unit)
  return ok and value
end

function AutoCallboardRuntime.IsQuestOfferFromGroupPlayer()
  local sourceName = AutoCallboardRuntime.GetQuestOfferSourceName()
  if not sourceName or sourceName == "" then
    return false, sourceName
  end

  local isPlayer = AutoCallboardRuntime.SafeUnitCheck(UnitIsPlayer, "questnpc")
      or AutoCallboardRuntime.SafeUnitCheck(UnitIsPlayer, sourceName)
  local inGroup = AutoCallboardRuntime.SafeUnitCheck(UnitInParty, "questnpc")
      or AutoCallboardRuntime.SafeUnitCheck(UnitInRaid, "questnpc")
      or AutoCallboardRuntime.SafeUnitCheck(UnitInParty, sourceName)
      or AutoCallboardRuntime.SafeUnitCheck(UnitInRaid, sourceName)

  return isPlayer and inGroup, sourceName
end

function AutoCallboardRuntime.AcceptCurrentQuestOffer(source)
  if AcceptQuest then
    AcceptQuest()
  elseif QuestFrameAcceptButton then
    QuestFrameAcceptButton:Click()
  else
    AppendDebugLog("quest", "auto accept blocked source=" .. tostring(source) .. " reason=no accept API")
    return false
  end

  return true
end

function AutoCallboardRuntime.TryAutoAcceptSharedQuest(source)
  if not state or not state.autoAcceptShared then
    return false
  end

  local now = GetTime()
  if AutoCallboardRuntime.lastSharedAutoAcceptAt and now - AutoCallboardRuntime.lastSharedAutoAcceptAt < 0.5 then
    return false
  end

  local fromGroupPlayer, sourceName = AutoCallboardRuntime.IsQuestOfferFromGroupPlayer()
  if not fromGroupPlayer then
    AppendDebugLog("quest", "shared auto accept skipped source=" .. tostring(source) .. " giver=" .. tostring(sourceName or "none"))
    return false
  end

  if AutoCallboardRuntime.AcceptCurrentQuestOffer(source) then
    AutoCallboardRuntime.lastSharedAutoAcceptAt = now
    local title = AutoCallboardRuntime.GetQuestOfferTitle()
    Print("Accepted shared quest" .. (title ~= "" and ": " .. title or "."))
    AppendDebugLog("quest", "accepted shared quest source=" .. tostring(source) .. " giver=" .. tostring(sourceName or "unknown") .. " title=" .. tostring(title))
    return true
  end

  return false
end

function AutoCallboardRuntime.InstallSharedQuestAutoAcceptHook()
  if AutoCallboardRuntime.sharedQuestAutoAcceptHooked or not QuestFrame then
    return
  end

  AutoCallboardRuntime.sharedQuestAutoAcceptHooked = true

  if QuestFrame.HookScript then
    QuestFrame:HookScript("OnShow", function()
      AutoCallboardRuntime.TryAutoAcceptSharedQuest("QuestFrame OnShow")
      end)
    return
  end

  if QuestFrame.GetScript and QuestFrame.SetScript then
    local previousOnShow = QuestFrame:GetScript("OnShow")
    QuestFrame:SetScript("OnShow", function(self, ...)
      if previousOnShow then
        previousOnShow(self, ...)
      end

      AutoCallboardRuntime.TryAutoAcceptSharedQuest("QuestFrame OnShow")
      end)
  end
end

function AutoCallboardRuntime.ConfirmSharedQuestAccept(source)
  if not state or not state.autoAcceptShared then
    return false
  end

  if StaticPopup_Visible and StaticPopup_Visible("QUEST_ACCEPT") and StaticPopup_Hide then
    StaticPopup_Hide("QUEST_ACCEPT")
  end

  if ConfirmAcceptQuest then
    ConfirmAcceptQuest()
    AppendDebugLog("quest", "confirmed shared quest source=" .. tostring(source))
    return true
  end

  return false
end

local function IsSelectedQuestDone()
  if not selectedQuest then
    return false
  end

  local questID = tonumber(selectedQuest.questId) or 0
  local activeObjective = GetActiveObjective()
  local activeQuestID = tonumber(activeObjective and activeObjective.questId) or 0

  if activeObjective then
    if (questID > 0 and activeQuestID == questID) or (selectedQuest.title ~= "" and NormalizeQuestTitle(Core.questTitle(activeObjective)) == NormalizeQuestTitle(selectedQuest.title)) then
      selectedQuest.seenActiveObjective = true
      return false
    end

    if selectedQuest.seenActiveObjective then
      return true
    end
  elseif selectedQuest.seenActiveObjective then
    return true
  end

  if questID > 0 and IsQuestFlaggedCompleted and IsQuestFlaggedCompleted(questID) then
    return true
  end

  local found, complete = FindSelectedQuestInLog()
  if found then
    selectedQuest.seenInLog = true
    return complete
  end

  if selectedQuest.seenInLog then
    return true
  end

  return false
end

local function ResumeAfterSelectedQuest(source)
  local title = selectedQuest and selectedQuest.title or "selected quest"
  selectedQuest = nil
  nextSelectedQuestCheckAt = nil
  rollCount = 0
  ClearRollPause("quest_selected")
  if GetSummonCooldownRemaining() > 0 then
    SetRollPause("no_callboard", "Quest done: " .. title .. ". Waiting for Callboard cooldown.")
  else
    SetRollPause("no_callboard", "Quest done: " .. title .. ". Checking objective data again.")
  end
  AppendDebugLog("quest", "quest done source=" .. tostring(source) .. " title=" .. tostring(title))
end

local function CheckSelectedQuestProgress(source)
  if not rolling or rollPausedReason ~= "quest_selected" or not selectedQuest then
    return
  end

  local now = GetTime()
  if nextSelectedQuestCheckAt and now < nextSelectedQuestCheckAt then
    return
  end

  nextSelectedQuestCheckAt = now + 1

  if IsSelectedQuestDone() then
    ResumeAfterSelectedQuest(source)
  end
end

local function ToggleDesiredQuest(key)
  local nextState = Core.mergeState(state)
  nextState.desiredQuests = Core.toggleDesired(state.desiredQuests, key)
  state = nextState
  SaveCharacterDesiredQuests()

  if not rolling then
    EvaluateCurrentObjectives()
  end

  if questWindow and questWindow:IsShown() then
    UpdateQuestWindow()
  end
end

function AutoCallboardRuntime.CloseObjectiveBoardAfterSelection(source)
  if GossipFrame then
    if GossipFrame.SetAlpha then
      GossipFrame:SetAlpha(1)
    end

    if GossipFrame.EnableMouse then
      GossipFrame:EnableMouse(true)
    end

    if GossipFrame.ClearAllPoints and GossipFrame.SetPoint then
      GossipFrame:ClearAllPoints()
      GossipFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
    end
  end

  if GossipFrameCloseButton and GossipFrameCloseButton.Click then
    GossipFrameCloseButton:Click()
  elseif CloseGossip then
    CloseGossip()
  elseif GossipFrame and HideUIPanel then
    HideUIPanel(GossipFrame)
  end

  if ProjectEbonhold and ProjectEbonhold.ObjectivesUI and ProjectEbonhold.ObjectivesUI.HideObjectives then
    ProjectEbonhold.ObjectivesUI.HideObjectives()
  elseif _G.ObjectivesMainFrame and _G.ObjectivesMainFrame.Hide then
    _G.ObjectivesMainFrame:Hide()
  end

  AppendDebugLog("guard", "closed board after selection source=" .. tostring(source))
end

local function SelectObjectiveIndex(index)
  if not index then
    return false
  end

  if not RequireActiveCallboard("selecting a quest") then
    return false
  end

  local objective = GetCurrentObjectives()[index]
  local selected

  if ProjectEbonhold and ProjectEbonhold.sendToServer and ProjectEbonhold.CS and ProjectEbonhold.CS.REQUEST_SELECT_OBJECTIVE then
    ProjectEbonhold.sendToServer(ProjectEbonhold.CS.REQUEST_SELECT_OBJECTIVE, tostring(index - 1))
    selected = true
  else
    selected = ClickNamedFrame(state.objectivePrefix .. tostring(index) .. "." .. state.objectiveButtonField, "Objective " .. tostring(index))
  end

  if selected then
    SetQuestStatus("Selected objective slot " .. tostring(index) .. ".")
    StartSelectedQuestPause(objective, index)
    AutoCallboardRuntime.CloseObjectiveBoardAfterSelection("selected slot " .. tostring(index))
  end

  return selected
end

StopRolling = function(message)
  rolling = false
  rollPausedReason = nil
  rollPauseMessage = nil
  AutoCallboardRuntime.manualBoardOpenRequired = false
  AutoCallboardRuntime.objectiveBoardReadyUntil = nil
  AutoCallboardRuntime.objectiveBoardAccessOpen = false
  AutoCallboardRuntime.objectiveRequestPendingUntil = nil
  AutoCallboardRuntime.nextObjectiveRequestAt = nil
  AutoCallboardRuntime.objectiveRequestAttempts = 0
  pendingReroll = false
  nextRollAt = nil
  pendingRerollUntil = nil
  selectedQuest = nil
  nextSelectedQuestCheckAt = nil
  AutoCallboardRuntime.blockedMatchKey = nil

  if message then
    SetQuestStatus(message)
  end

  UpdateRollToggleButtons()

  if UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

local function HandleMatch(match)
  pendingReroll = false
  nextRollAt = nil
  pendingRerollUntil = nil

  local title = Core.questTitle(match.quest)
  local matchKey = tostring(match.index) .. ":" .. tostring(match.key)

  if not AutoCallboardRuntime.IsCallboardReadyForQuestActions() then
    SetRollPause("no_callboard", "Found wanted quest: " .. title .. ". Waiting for Callboard.")
    nextRollAt = GetTime() + ROLL_EVAL_INTERVAL

    if AutoCallboardRuntime.blockedMatchKey ~= matchKey then
      AutoCallboardRuntime.blockedMatchKey = matchKey
      AppendDebugLog("quest", "hard stop on wanted quest slot=" .. tostring(match.index) .. " key=" .. tostring(match.key) .. " title=" .. title)
      AppendDebugLog("quest", "matched wanted quest but callboard ui is not ready")
    end
  elseif SelectObjectiveIndex(match.index) then
    AutoCallboardRuntime.blockedMatchKey = nil
    AppendDebugLog("quest", "hard stop on wanted quest slot=" .. tostring(match.index) .. " key=" .. tostring(match.key) .. " title=" .. title)
    SetQuestStatus("Found and selected wanted quest: " .. title .. " in slot " .. tostring(match.index) .. ".")
  else
    local shouldLogBlockedMatch = AutoCallboardRuntime.blockedMatchKey ~= matchKey
    AutoCallboardRuntime.blockedMatchKey = matchKey
    nextRollAt = GetTime() + ROLL_EVAL_INTERVAL

    if shouldLogBlockedMatch then
      AppendDebugLog("quest", "hard stop on wanted quest slot=" .. tostring(match.index) .. " key=" .. tostring(match.key) .. " title=" .. title)
      AppendDebugLog("quest", "wanted quest selection failed title=" .. tostring(title))
      SetQuestStatus("Found wanted quest: " .. title .. " in slot " .. tostring(match.index) .. ", but selection failed.")
    elseif questStatusText then
      questStatusText:SetText("Found wanted quest: " .. title .. " in slot " .. tostring(match.index) .. ", but selection failed.")
    end

    SetRollPause("no_callboard", "Found wanted quest: " .. title .. ". Waiting for selectable Callboard UI.")
  end

  if UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

EvaluateCurrentObjectives = function()
  if not AutoCallboardRuntime.IsCallboardDataAvailable() then
    AppendDebugLog("quest", "skipped objective evaluation because live quest data is not available")
    return false
  end

  local objectives = CaptureCurrentObjectives()
  local match = Core.findDesiredObjective(objectives, state.desiredQuests)

  if match then
    HandleMatch(match)
    return true
  end

  return false
end

ResumeRollingAfterCallboardActive = function(source)
  if not rolling then
    return
  end

  if not AutoCallboardRuntime.IsCallboardDataAvailable() then
    SetRollPause("no_callboard", "Paused: waiting for Callboard UI.")
    AppendDebugLog("roll", "resume blocked until live quest data is available source=" .. tostring(source))
    return
  end

  if rollPausedReason == "quest_selected" then
    return
  end

  if rollPausedReason == "no_callboard" or rollPausedReason == "no_wanted" then
    ClearRollPause()
  end

  pendingReroll = false
  pendingRerollUntil = nil
  nextRollAt = GetTime() + 0.2
  lastObjectiveSignature = ObjectiveSignature(CaptureCurrentObjectives())
  SetQuestStatus("Callboard active. Resuming roll.")
  AppendDebugLog("roll", "callboard active resume source=" .. tostring(source))

  if EvaluateCurrentObjectives() then
    return
  end
end

local function RequestObjectiveReroll()
  if not RequireActiveCallboard("rerolling") then
    return false
  end

  local service = GetObjectivesService()

  if service and service.RequestRerollObjectives then
    if service.CanAffordReroll and not service.CanAffordReroll() then
      return false
    end

    service.RequestRerollObjectives()
    return true
  end

  return ClickNamedFrame(state.rerollFrame, "Reroll")
end

local function ConfirmRerollPopupIfVisible()
  if StaticPopup_Visible and not StaticPopup_Visible("EBONHOLD_CONFIRM_REROLL") then
    return false
  end

  for i = 1, 4 do
    local popup = _G["StaticPopup" .. tostring(i)]
    if popup and popup:IsShown() and popup.which == "EBONHOLD_CONFIRM_REROLL" then
      local confirmButton = _G["StaticPopup" .. tostring(i) .. "Button1"]
      if confirmButton and confirmButton.Click then
        confirmButton:Click()
        AppendDebugLog("reroll", "confirmed EBONHOLD_CONFIRM_REROLL via StaticPopup" .. tostring(i) .. "Button1")
        return true
      end
    end
  end

  return false
end

local function BypassRerollConfirm()
  if not RequireActiveCallboard("rerolling") then
    return false
  end

  local service = GetObjectivesService()

  if service and service.RequestRerollObjectives then
    if RequestObjectiveReroll() then
      AppendDebugLog("reroll", "requested reroll through ObjectivesService")
      ConfirmRerollPopupIfVisible()
      return true
    end

    return false
  end

  if RequestObjectiveReroll() then
    ConfirmRerollPopupIfVisible()
    return true
  end

  if ClickNamedFrame(state.rerollFrame, "Reroll") then
    ConfirmRerollPopupIfVisible()
    return true
  end

  return false
end

local function ProcessRolling()
  if not rolling then
    return
  end

  if CountDesiredQuests() == 0 then
    SetRollPause("no_wanted", "Paused: pick at least one wanted quest.")
    return
  end

  if rollPausedReason == "quest_selected" then
    CheckSelectedQuestProgress("poll")
    return
  end

  local activeObjective = GetActiveObjective()
  if activeObjective then
    StartSelectedQuestPause(activeObjective, "active")
    return
  end

  if AutoCallboardRuntime.objectiveRequestPendingUntil and GetTime() >= AutoCallboardRuntime.objectiveRequestPendingUntil and not AutoCallboardRuntime.HasCurrentObjectiveData() then
    AutoCallboardRuntime.objectiveRequestPendingUntil = nil
  end

  local boardAccess = AutoCallboardRuntime.GetBoardAccessState("rolling")

  if not boardAccess.ok then
    if boardAccess.boardOpen and boardAccess.needsData then
      SetRollPause("no_callboard", boardAccess.message)

      if AutoCallboardRuntime.RequestObjectiveBoardData("roll " .. tostring(boardAccess.reason)) then
        return
      end
    end

    AutoCallboardRuntime.SetManualBoardOpenRequired("roll board guard:" .. tostring(boardAccess.reason))
    return
  end

  if AutoCallboardRuntime.manualBoardOpenRequired then
    AutoCallboardRuntime.manualBoardOpenRequired = false
    AppendDebugLog("guard", "board access detected after manual pause source=" .. tostring(boardAccess.source))
  end

  if rollPausedReason == "no_callboard" or rollPausedReason == "no_wanted" or rollPausedReason == "manual_board" then
    ClearRollPause()
  end

  local now = GetTime()
  local objectives = GetCurrentObjectives()
  local signature = ObjectiveSignature(objectives)

  if nextRollAt and now < nextRollAt then
    return
  end

  if pendingReroll then
    if signature == lastObjectiveSignature and now < pendingRerollUntil then
      return
    end

    pendingReroll = false
    lastObjectiveSignature = signature

    if EvaluateCurrentObjectives() then
      return
    end

    nextRollAt = now + 0.2
    UpdateQuestWindow()
    return
  end

  if EvaluateCurrentObjectives() then
    return
  end

  if rollCount >= state.maxRerolls then
    StopRolling("Stopped after " .. tostring(rollCount) .. " reroll(s). No wanted quest found.")
    return
  end

  lastObjectiveSignature = signature

  if BypassRerollConfirm() then
    rollCount = rollCount + 1
    pendingReroll = true
    pendingRerollUntil = now + state.rerollDelay
    SetQuestStatus("Reroll " .. tostring(rollCount) .. "/" .. tostring(state.maxRerolls) .. " requested.")
  else
    StopRolling("Could not reroll. Check gold or Callboard UI.")
  end
end

local function RefreshQuestWindowIfNeeded()
  if not questWindow or not questWindow:IsShown() then
    return
  end

  local now = GetTime()
  if nextQuestRefreshAt and now < nextQuestRefreshAt then
    return
  end

  nextQuestRefreshAt = now + QUEST_REFRESH_INTERVAL

  local signature = ObjectiveSignature(GetCurrentObjectives())
  if signature ~= lastCapturedSignature then
    CaptureCurrentObjectives()

    if rolling and EvaluateCurrentObjectives() then
      return
    end

    UpdateQuestWindow()
  end
end

local function WatchCurrentObjectives()
  if not state or not GetObjectivesService() then
    return
  end

  local now = GetTime()
  if nextQuestWatchAt and now < nextQuestWatchAt then
    return
  end

  nextQuestWatchAt = now + QUEST_WATCH_INTERVAL
  local beforeSignature = lastCapturedSignature
  local beforeCount = table.getn(state.knownQuests or {})
  local objectives = CaptureCurrentObjectives()
  local afterCount = table.getn(state.knownQuests or {})

  if questWindow and questWindow:IsShown() and (ObjectiveSignature(objectives) ~= beforeSignature or afterCount ~= beforeCount) then
    UpdateQuestWindow()
  end
end

StartRolling = function()
  if CountDesiredQuests() == 0 then
    SetQuestStatus("Pick at least one wanted quest first.")
    Print("Pick at least one wanted quest first. Use /acb quests if you need the list.")
    return
  end

  rollCount = 0
  selectedQuest = nil
  rollPausedReason = nil
  rollPauseMessage = nil
  local activeBoardSession = AutoCallboardRuntime.IsCallboardUiPresent()
      or (AutoCallboardRuntime.objectiveBoardAccessOpen
      and SecondsRemaining(AutoCallboardRuntime.objectiveBoardReadyUntil) > 0)
  AutoCallboardRuntime.manualBoardOpenRequired = false
  if not activeBoardSession then
    AutoCallboardRuntime.objectiveBoardReadyUntil = nil
    AutoCallboardRuntime.objectiveBoardAccessOpen = false
  end
  AutoCallboardRuntime.objectiveRequestPendingUntil = nil
  AutoCallboardRuntime.nextObjectiveRequestAt = nil
  AutoCallboardRuntime.objectiveRequestAttempts = 0
  pendingInteractAt = nil
  AutoCallboardRuntime.pendingInteractSource = nil
  nextSelectedQuestCheckAt = nil
  pendingReroll = false
  AutoCallboardRuntime.blockedMatchKey = nil
  rolling = true
  nextRollAt = GetTime()
  lastObjectiveSignature = ObjectiveSignature(CaptureCurrentObjectives())

  local activeObjective = GetActiveObjective()
  if activeObjective then
    StartSelectedQuestPause(activeObjective, "active")
    return
  end

  local boardAccess = AutoCallboardRuntime.GetBoardAccessState("start")

  if not boardAccess.ok then
    if boardAccess.boardOpen and boardAccess.needsData then
      SetRollPause("no_callboard", boardAccess.message)
      if not AutoCallboardRuntime.RequestObjectiveBoardData("start " .. tostring(boardAccess.reason)) then
        AutoCallboardRuntime.SetManualBoardOpenRequired("start data missing")
      end
    else
      AutoCallboardRuntime.SetManualBoardOpenRequired("start board guard:" .. tostring(boardAccess.reason))
    end
  elseif not EvaluateCurrentObjectives() then
    SetQuestStatus("Rolling for " .. tostring(CountDesiredQuests()) .. " wanted quest(s).")
  end

  UpdateRollToggleButtons()
end

local function EnsureDebugLog()
  if type(AutoCallboardDebugLog) ~= "table" then
    AutoCallboardDebugLog = {}
  end

  return AutoCallboardDebugLog
end

local function CompactText(value)
  if value == nil then
    return "nil"
  end

  value = tostring(value)
  value = value:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  value = value:gsub("|", "/")
  value = value:gsub("%s+", " ")

  if value:len() > 80 then
    return value:sub(1, 77) .. "..."
  end

  return value
end

local function FrameName(target)
  if not target then
    return "nil"
  end

  if target.GetName and target:GetName() then
    return target:GetName()
  end

  return tostring(target)
end

local function FrameType(target)
  if target and target.GetObjectType then
    return target:GetObjectType()
  end

  return type(target)
end

AppendDebugLog = function(kind, message)
  local log = EnsureDebugLog()
  local entry = {
    time = GetTime and GetTime() or 0,
    kind = kind,
    message = message,
  }

  table.insert(log, entry)

  local maxLog = state and state.debug and state.debug.maxLog or 120
  while table.getn(log) > maxLog do
    table.remove(log, 1)
  end

  if debugWindow and debugWindow:IsShown() and UpdateDebugWindow then
    UpdateDebugWindow()
  end
end

function AutoCallboardRuntime.SafeUnitValue(unit, getter)
  if not getter then
    return nil
  end

  local ok, value = pcall(getter, unit)
  if ok then
    return value
  end

  return nil
end

function AutoCallboardRuntime.SafeInteractDistance(unit, index)
  if not CheckInteractDistance then
    return nil
  end

  local ok, value = pcall(CheckInteractDistance, unit, index)
  if ok then
    return value
  end

  return nil
end

function AutoCallboardRuntime.SniffUnitLine(unit)
  local name = AutoCallboardRuntime.SafeUnitValue(unit, UnitName)
  local guid = AutoCallboardRuntime.SafeUnitValue(unit, UnitGUID)
  local exists = AutoCallboardRuntime.SafeUnitValue(unit, UnitExists)
  local objectId = AutoCallboardRuntime.ExtractBoardObjectIdFromGuid and AutoCallboardRuntime.ExtractBoardObjectIdFromGuid(guid) or nil
  local knownBoard = AutoCallboardRuntime.IsKnownBoardObjectId and AutoCallboardRuntime.IsKnownBoardObjectId(objectId) or false
  local distance3 = AutoCallboardRuntime.SafeInteractDistance(unit, 3)

  return tostring(unit)
      .. " exists=" .. tostring(exists)
      .. " name=" .. CompactText(name)
      .. " guid=" .. tostring(guid)
      .. " id=" .. tostring(objectId)
      .. " knownBoard=" .. tostring(knownBoard)
      .. " interact3=" .. tostring(distance3)
end

function AutoCallboardRuntime.SniffGossipLine()
  local name = AutoCallboardRuntime.GossipDebugName and AutoCallboardRuntime.GossipDebugName() or "none"
  local shown = AutoCallboardRuntime.IsGossipFrameOpen and AutoCallboardRuntime.IsGossipFrameOpen() or false
  local text = "unavailable"
  local optionCount = "unavailable"

  if GetGossipText then
    local ok, value = pcall(GetGossipText)
    if ok then
      text = CompactText(value)
    end
  end

  if GetNumGossipOptions then
    local ok, value = pcall(GetNumGossipOptions)
    if ok then
      optionCount = tostring(value)
    end
  end

  return "gossip shown=" .. tostring(shown) .. " name=" .. CompactText(name) .. " options=" .. tostring(optionCount) .. " text=" .. text
end

function AutoCallboardRuntime.SniffBoardAccessLine()
  local access = AutoCallboardRuntime.GetBoardAccessState and AutoCallboardRuntime.GetBoardAccessState("sniff") or nil

  if not access then
    return "access unavailable"
  end

  return "access ok=" .. tostring(access.ok)
      .. " reason=" .. tostring(access.reason)
      .. " source=" .. tostring(access.source or "none")
      .. " boardName=" .. tostring(access.boardName or "none")
      .. " boardObjectId=" .. tostring(access.boardObjectId or "none")
      .. " data=" .. tostring(AutoCallboardRuntime.HasCurrentObjectiveData and AutoCallboardRuntime.HasCurrentObjectiveData() or false)
end

function AutoCallboardRuntime.AppendInteractionSniffSnapshot(source, event, arg1, arg2, arg3, arg4, arg5)
  AppendDebugLog("sniff", "source=" .. tostring(source) .. " event=" .. tostring(event) .. " args: 1=" .. CompactText(arg1) .. ", 2=" .. CompactText(arg2) .. ", 3=" .. CompactText(arg3) .. ", 4=" .. CompactText(arg4) .. ", 5=" .. CompactText(arg5))
  AppendDebugLog("sniff", AutoCallboardRuntime.SniffBoardAccessLine())
  AppendDebugLog("sniff", AutoCallboardRuntime.SniffGossipLine())
  AppendDebugLog("sniff", AutoCallboardRuntime.SniffUnitLine("npc"))
  AppendDebugLog("sniff", AutoCallboardRuntime.SniffUnitLine("target"))
  AppendDebugLog("sniff", AutoCallboardRuntime.SniffUnitLine("mouseover"))
end

function AutoCallboardRuntime.IsInteractionSnifferEnabled()
  return state and state.debug and state.debug.sniffer
end

function AutoCallboardRuntime.InstallInteractionSnifferHooks()
  if AutoCallboardRuntime.worldFrameSnifferHooked or not WorldFrame or not WorldFrame.HookScript then
    return
  end

  AutoCallboardRuntime.worldFrameSnifferHooked = true
  WorldFrame:HookScript("OnMouseDown", function(_, buttonName)
    if AutoCallboardRuntime.IsInteractionSnifferEnabled() then
      AutoCallboardRuntime.AppendInteractionSniffSnapshot("WorldFrame OnMouseDown " .. tostring(buttonName), "WORLD_MOUSE_DOWN")
    end
    end)
  WorldFrame:HookScript("OnMouseUp", function(_, buttonName)
    if AutoCallboardRuntime.IsInteractionSnifferEnabled() then
      AutoCallboardRuntime.AppendInteractionSniffSnapshot("WorldFrame OnMouseUp " .. tostring(buttonName), "WORLD_MOUSE_UP")
    end
    end)
end

function AutoCallboardRuntime.SetInteractionSnifferEnabled(value)
  local nextState = Core.mergeState(state)
  nextState.debug.sniffer = value and true or false
  if nextState.debug.sniffer and (not nextState.debug.maxLog or nextState.debug.maxLog < 240) then
    nextState.debug.maxLog = 240
  end
  ApplyState(nextState)
  AutoCallboardRuntime.InstallInteractionSnifferHooks()
  AppendDebugLog("sniff", "interaction sniffer " .. (nextState.debug.sniffer and "on" or "off"))
  if nextState.debug.sniffer then
    AutoCallboardRuntime.AppendInteractionSniffSnapshot("sniff on", "MANUAL_SNIFF_ON")
  end
  ShowDebugWindow()
end

function AutoCallboardRuntime.OpenEventTrace()
  local opened = false

  if EventTraceFrame then
    if EventTraceFrame.Show then
      EventTraceFrame:Show()
      opened = true
    end

    if EventTraceFrame.StartEventCapture then
      pcall(EventTraceFrame.StartEventCapture, EventTraceFrame)
    end
  elseif SlashCmdList and SlashCmdList.EVENTTRACE then
    local ok = pcall(SlashCmdList.EVENTTRACE, "")
    opened = ok
  end

  if opened then
    AppendDebugLog("debug", "EventTrace opened")
    Print("EventTrace opened. Use it with /acb sniff for board testing.")
  else
    AppendDebugLog("debug", "EventTrace is not available in this client")
    Print("EventTrace is not available in this client.")
  end
end

local function FormatDebugLogs()
  local log = EnsureDebugLog()
  local lines = {}

  table.insert(lines, "AutoCallboard Debug Log")
  table.insert(lines, "Version: " .. GetAddonVersion())
  table.insert(lines, "Interaction sniffer: " .. tostring(state and state.debug and state.debug.sniffer or false))
  table.insert(lines, "Use Select All, then Ctrl+C to copy this text.")
  table.insert(lines, "Default reroll target: ObjectivesMainFrame.rerollBtn")
  table.insert(lines, "Default objective targets: ObjectiveFrame1.selectBtn, ObjectiveFrame2.selectBtn, ObjectiveFrame3.selectBtn")
  table.insert(lines, "")

  for i = 1, table.getn(log) do
    local entry = log[i]
    table.insert(lines, string.format("%03d  %.3f  %-12s  %s", i, entry.time or 0, tostring(entry.kind), tostring(entry.message)))
  end

  return table.concat(lines, "\n")
end

UpdateDebugWindow = function()
  if not debugEditBox then
    return
  end

  local text = FormatDebugLogs()
  local lineCount = 1

  for _ in string.gmatch(text, "\n") do
    lineCount = lineCount + 1
  end

  debugEditBox:SetHeight(math.max(330, lineCount * 14))
  debugReadOnlyText = text
  debugEditBoxUpdating = true
  debugEditBox:SetText(text)
  debugEditBox:SetCursorPosition(0)
  debugEditBoxUpdating = false

  if AutoCallboardRuntime.debugScrollFrame then
    ApplyColor(AutoCallboardRuntime.debugScrollFrame, "SetBackdropBorderColor", THEME.borderDim)
  end

  if AutoCallboardRuntime.debugSelectionText then
    AutoCallboardRuntime.debugSelectionText:Hide()
  end
end

local function SetDebugSelectionVisible(selected)
  if AutoCallboardRuntime.debugScrollFrame then
    ApplyColor(AutoCallboardRuntime.debugScrollFrame, "SetBackdropBorderColor", selected and THEME.buttonHoverBorder or THEME.borderDim)
  end

  if AutoCallboardRuntime.debugSelectionText then
    if selected then
      AutoCallboardRuntime.debugSelectionText:Show()
    else
      AutoCallboardRuntime.debugSelectionText:Hide()
    end
  end
end

ShowDebugWindow = function()
  if not debugWindow then
    debugWindow = CreateFrame("Frame", "AutoCallboardDebugWindow", UIParent)
    RegisterSpecialFrame("AutoCallboardDebugWindow")
    debugWindow:SetWidth(720)
    debugWindow:SetHeight(430)
    debugWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    debugWindow:SetFrameStrata("DIALOG")
    if debugWindow.SetToplevel then
      debugWindow:SetToplevel(true)
    end
    debugWindow:SetMovable(true)
    debugWindow:EnableMouse(true)
    debugWindow:RegisterForDrag("LeftButton")
    debugWindow:SetClampedToScreen(true)
    SkinFrame(debugWindow)
    debugWindow:SetScript("OnDragStart", function(self)
      self:StartMoving()
      end)
    debugWindow:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      end)

    local title = debugWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", debugWindow, "TOP", 0, -18)
    title:SetText("AutoCallboard Debug")
    SkinTitleText(title)

    local closeButton = CreateFrame("Button", nil, debugWindow)
    closeButton:SetPoint("TOPRIGHT", debugWindow, "TOPRIGHT", -4, -4)
    SkinCloseButton(closeButton, debugWindow)

    AutoCallboardRuntime.debugScrollFrame = CreateFrame("ScrollFrame", "AutoCallboardDebugScrollFrame", debugWindow, "UIPanelScrollFrameTemplate")
    AutoCallboardRuntime.debugScrollFrame:SetPoint("TOPLEFT", debugWindow, "TOPLEFT", 24, -48)
    AutoCallboardRuntime.debugScrollFrame:SetPoint("BOTTOMRIGHT", debugWindow, "BOTTOMRIGHT", -36, 54)
    SkinScrollPanel(AutoCallboardRuntime.debugScrollFrame)
    ApplyColor(AutoCallboardRuntime.debugScrollFrame, "SetBackdropColor", THEME.debugList)
    SkinScrollBar(AutoCallboardRuntime.debugScrollFrame)

    debugEditBox = CreateFrame("EditBox", "AutoCallboardDebugEditBox", AutoCallboardRuntime.debugScrollFrame)
    debugEditBox:SetMultiLine(true)
    debugEditBox:SetAutoFocus(false)
    debugEditBox:SetFontObject(ChatFontNormal)
    debugEditBox:SetWidth(650)
    debugEditBox:SetHeight(330)
    if debugEditBox.SetTextInsets then
      debugEditBox:SetTextInsets(3, 3, 3, 3)
    end
    StripFrameTextures(debugEditBox)
    if debugEditBox.SetTextColor then
      debugEditBox:SetTextColor(THEME.text[1], THEME.text[2], THEME.text[3])
    end
    if debugEditBox.SetBackdrop then
      debugEditBox:SetBackdrop(nil)
    end
    debugEditBox:SetScript("OnTextChanged", function(self)
      if debugEditBoxUpdating then
        return
      end

      debugEditBoxUpdating = true
      self:SetText(debugReadOnlyText)
      self:HighlightText()
      debugEditBoxUpdating = false
      end)
    debugEditBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      debugWindow:Hide()
      end)
    AutoCallboardRuntime.debugScrollFrame:SetScrollChild(debugEditBox)

    local selectButton = CreateFrame("Button", nil, debugWindow, "UIPanelButtonTemplate")
    selectButton:SetWidth(84)
    selectButton:SetHeight(24)
    selectButton:SetText("Select All")
    selectButton:SetPoint("BOTTOMLEFT", debugWindow, "BOTTOMLEFT", 24, 22)
    SkinButton(selectButton)
    selectButton:SetScript("OnClick", function()
      UpdateDebugWindow()
      debugEditBox:SetFocus()
      debugEditBox:HighlightText()
      SetDebugSelectionVisible(true)
      end)

    local refreshButton = CreateFrame("Button", nil, debugWindow, "UIPanelButtonTemplate")
    refreshButton:SetWidth(76)
    refreshButton:SetHeight(24)
    refreshButton:SetText("Refresh")
    refreshButton:SetPoint("LEFT", selectButton, "RIGHT", 8, 0)
    SkinButton(refreshButton)
    refreshButton:SetScript("OnClick", function()
      UpdateDebugWindow()
      SetDebugSelectionVisible(false)
      end)

    local clearButton = CreateFrame("Button", nil, debugWindow, "UIPanelButtonTemplate")
    clearButton:SetWidth(76)
    clearButton:SetHeight(24)
    clearButton:SetText("Clear")
    clearButton:SetPoint("LEFT", refreshButton, "RIGHT", 8, 0)
    SkinButton(clearButton)
    clearButton:SetScript("OnClick", function()
      AutoCallboardDebugLog = {}
      UpdateDebugWindow()
      SetDebugSelectionVisible(false)
      end)

    AutoCallboardRuntime.debugSelectionText = debugWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    AutoCallboardRuntime.debugSelectionText:SetPoint("LEFT", clearButton, "RIGHT", 12, 0)
    AutoCallboardRuntime.debugSelectionText:SetText("Selected")
    SkinHeadingText(AutoCallboardRuntime.debugSelectionText)
    AutoCallboardRuntime.debugSelectionText:Hide()
  end

  UpdateDebugWindow()
  debugWindow:Show()
end

local function FrameText(target)
  local texts = {}

  if target and target.GetText then
    local value = target:GetText()
    if value and value ~= "" then
      table.insert(texts, CompactText(value))
    end
  end

  if target and target.GetRegions then
    local regions = { target:GetRegions() }
    for i = 1, table.getn(regions) do
      local region = regions[i]
      if region and region.GetText then
        local value = region:GetText()
        if value and value ~= "" then
          table.insert(texts, CompactText(value))
        end
      end
    end
  end

  if table.getn(texts) == 0 then
    return ""
  end

  return table.concat(texts, " | ")
end

local function FrameSummary(target)
  if not target then
    return "nil"
  end

  local parts = { FrameName(target), FrameType(target) }

  if target.GetID then
    table.insert(parts, "id=" .. tostring(target:GetID()))
  end

  if target.IsShown then
    table.insert(parts, "shown=" .. tostring(target:IsShown() and true or false))
  end

  if target.IsVisible then
    table.insert(parts, "visible=" .. tostring(target:IsVisible() and true or false))
  end

  if target.IsEnabled then
    table.insert(parts, "enabled=" .. tostring(target:IsEnabled() and true or false))
  end

  local text = FrameText(target)
  if text ~= "" then
    table.insert(parts, "text=\"" .. text .. "\"")
  end

  return table.concat(parts, " ")
end

ResolveFramePath = function(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end

  local current

  for segment in string.gmatch(path, "[^%.]+") do
    if not current then
      current = _G[segment]
    else
      current = current[segment]
    end

    if not current then
      return nil
    end
  end

  return current
end

local function PrintFrameChain(target, label)
  if not target then
    AppendDebugLog("inspect", label .. ": no frame")
    return
  end

  AppendDebugLog("inspect", label .. ": " .. FrameSummary(target))

  local parent = target.GetParent and target:GetParent() or nil
  local depth = 1

  while parent and depth <= 6 do
    local message = "parent " .. tostring(depth) .. ": " .. FrameSummary(parent)
    AppendDebugLog("inspect", message)
    parent = parent.GetParent and parent:GetParent() or nil
    depth = depth + 1
  end
end

local function InspectMouseFocus()
  local focus = GetMouseFocus and GetMouseFocus() or nil
  PrintFrameChain(focus, "mouse focus")
  ShowDebugWindow()
end

local function DumpKnownFrames()
  PrintFrameChain(ResolveFramePath(state.rerollFrame), "reroll click target")
  PrintFrameChain(_G.ObjectivesMainFrame, "objectives main frame")

  for i = 1, 3 do
    local frameName = state.objectivePrefix .. tostring(i)
    PrintFrameChain(_G[frameName], "objective " .. tostring(i) .. " frame")
    PrintFrameChain(ResolveFramePath(frameName .. "." .. state.objectiveButtonField), "objective " .. tostring(i) .. " click target")
  end

  ShowDebugWindow()
end

function AutoCallboardRuntime.UnitDebugName(unit)
  if UnitExists and UnitExists(unit) then
    return tostring(UnitName(unit) or "unknown")
  end

  return "none"
end

function AutoCallboardRuntime.TooltipDebugText()
  local parts = {}

  if GameTooltip and GameTooltip.IsShown and GameTooltip:IsShown() then
    table.insert(parts, "shown=true")
  else
    table.insert(parts, "shown=false")
  end

  for i = 1, 4 do
    local text = AutoCallboardRuntime.CleanBoardText(AutoCallboardRuntime.GetTooltipLineText(i))

    if text ~= "" then
      table.insert(parts, tostring(i) .. "=\"" .. CompactText(text) .. "\"")
    end
  end

  return table.concat(parts, " ")
end

function AutoCallboardRuntime.GossipDebugName()
  if GossipFrameNpcNameText and GossipFrameNpcNameText.GetText then
    local text = AutoCallboardRuntime.CleanBoardText(GossipFrameNpcNameText:GetText())

    if text ~= "" then
      return text
    end
  end

  return "none"
end

function AutoCallboardRuntime.ProximityDebugText()
  if _G.ClosestGameObjectPosition then
    return "ClosestGameObjectPosition=available objectIDs=600600"
  end

  return "ClosestGameObjectPosition=unavailable objectIDs=600600"
end

function AutoCallboardRuntime.AppendBoardDetectionDebugSnapshot()
  local focus = GetMouseFocus and GetMouseFocus() or nil
  local access = AutoCallboardRuntime.GetBoardAccessState("debug")
  local npcBoard = AutoCallboardRuntime.GetNpcBoardInfo and AutoCallboardRuntime.GetNpcBoardInfo() or nil
  AppendDebugLog("debug", "board target=" .. AutoCallboardRuntime.UnitDebugName("target") .. " mouseover=" .. AutoCallboardRuntime.UnitDebugName("mouseover") .. " focus=" .. FrameSummary(focus))
  AppendDebugLog("debug", "board access ok=" .. tostring(access.ok) .. " reason=" .. tostring(access.reason) .. " source=" .. tostring(access.source or "none") .. " ui=" .. tostring(AutoCallboardRuntime.IsCallboardUiPresent()) .. " session=" .. tostring(AutoCallboardRuntime.objectiveBoardAccessOpen) .. " data=" .. tostring(AutoCallboardRuntime.HasCurrentObjectiveData()))
  if npcBoard then
    AppendDebugLog("debug", "board npc name=" .. tostring(npcBoard.name) .. " id=" .. tostring(npcBoard.objectId) .. " guid=" .. tostring(npcBoard.guid) .. " nameMatch=" .. tostring(npcBoard.nameMatches) .. " idMatch=" .. tostring(npcBoard.idMatches))
  else
    AppendDebugLog("debug", "board npc=none gossipOpen=" .. tostring(AutoCallboardRuntime.IsGossipFrameOpen()))
  end
  AppendDebugLog("debug", "board proximity " .. AutoCallboardRuntime.ProximityDebugText())
  AppendDebugLog("debug", "board tooltip=" .. AutoCallboardRuntime.TooltipDebugText() .. " worldMatch=" .. tostring(AutoCallboardRuntime.GetWorldTooltipBoardName() or "none") .. " gossip=" .. AutoCallboardRuntime.GossipDebugName())
end

local function PrintRecentLogs()
  ShowDebugWindow()
end

local function ClearDebugLogs()
  AutoCallboardDebugLog = {}
  ShowDebugWindow()
end

local function SetQuestDataText(text)
  if not dataEditBox then
    return
  end

  text = text or ""

  local lineCount = 1
  for _ in string.gmatch(text, "\n") do
    lineCount = lineCount + 1
  end

  dataEditBox:SetHeight(math.max(330, lineCount * 14))
  dataEditBox:SetText(text)
  dataEditBox:SetCursorPosition(0)
end

local function ImportQuestDataFromText(text)
  local quests, imported, skipped = Core.importKnownQuestText(text)

  if imported <= 0 then
    Print("No quest data imported. Make sure the text starts with ACBQUESTS1.")
    AppendDebugLog("import", "failed imported=0 skipped=" .. tostring(skipped))
    return
  end

  local beforeCount = table.getn(state.knownQuests or {})
  local nextState = Core.mergeState(state)
  nextState.knownQuests = Core.mergeKnownQuestLists(state.knownQuests, quests)
  ApplyState(nextState)

  local afterCount = table.getn(state.knownQuests or {})
  Print("Imported " .. tostring(imported) .. " quest(s). Known quests: " .. tostring(afterCount) .. ".")
  AppendDebugLog("import", "imported=" .. tostring(imported) .. " skipped=" .. tostring(skipped) .. " known=" .. tostring(beforeCount) .. "->" .. tostring(afterCount))

  if questWindow and questWindow:IsShown() then
    UpdateQuestWindow()
  end
end

local function ShowQuestDataWindow(mode)
  if not dataWindow then
    dataWindow = CreateFrame("Frame", "AutoCallboardQuestDataWindow", UIParent)
    RegisterSpecialFrame("AutoCallboardQuestDataWindow")
    dataWindow:SetWidth(720)
    dataWindow:SetHeight(430)
    dataWindow:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dataWindow:SetFrameStrata("FULLSCREEN_DIALOG")
    if dataWindow.SetToplevel then
      dataWindow:SetToplevel(true)
    end
    dataWindow:SetMovable(true)
    dataWindow:EnableMouse(true)
    dataWindow:RegisterForDrag("LeftButton")
    dataWindow:SetClampedToScreen(true)
    SkinFrame(dataWindow)
    dataWindow:SetScript("OnDragStart", function(self)
      self:StartMoving()
      end)
    dataWindow:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      end)

    local title = dataWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", dataWindow, "TOP", 0, -18)
    title:SetText("AutoCallboard Quest Data")
    SkinTitleText(title)

    local closeButton = CreateFrame("Button", nil, dataWindow)
    closeButton:SetPoint("TOPRIGHT", dataWindow, "TOPRIGHT", -4, -4)
    SkinCloseButton(closeButton, dataWindow)

    local scrollFrame = CreateFrame("ScrollFrame", "AutoCallboardQuestDataScrollFrame", dataWindow, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", dataWindow, "TOPLEFT", 24, -48)
    scrollFrame:SetPoint("BOTTOMRIGHT", dataWindow, "BOTTOMRIGHT", -36, 54)
    SkinScrollPanel(scrollFrame)
    SkinScrollBar(scrollFrame)

    dataEditBox = CreateFrame("EditBox", "AutoCallboardQuestDataEditBox", scrollFrame)
    dataEditBox:SetMultiLine(true)
    dataEditBox:SetAutoFocus(false)
    dataEditBox:SetFontObject(ChatFontNormal)
    dataEditBox:SetWidth(650)
    dataEditBox:SetHeight(330)
    SkinEditBox(dataEditBox)
    ApplyColor(dataEditBox, "SetBackdropColor", THEME.bg)
    dataEditBox:SetScript("OnEscapePressed", function(self)
      self:ClearFocus()
      dataWindow:Hide()
      end)
    scrollFrame:SetScrollChild(dataEditBox)

    local exportButton = CreateFrame("Button", nil, dataWindow, "UIPanelButtonTemplate")
    exportButton:SetWidth(76)
    exportButton:SetHeight(24)
    exportButton:SetText("Export")
    exportButton:SetPoint("BOTTOMLEFT", dataWindow, "BOTTOMLEFT", 24, 22)
    SkinButton(exportButton)
    exportButton:SetScript("OnClick", function()
      CaptureCurrentObjectives()
      SetQuestDataText(Core.exportKnownQuestText(state.knownQuests))
      dataEditBox:SetFocus()
      dataEditBox:HighlightText()
      end)

    local importButton = CreateFrame("Button", nil, dataWindow, "UIPanelButtonTemplate")
    importButton:SetWidth(76)
    importButton:SetHeight(24)
    importButton:SetText("Import")
    importButton:SetPoint("LEFT", exportButton, "RIGHT", 8, 0)
    SkinButton(importButton)
    importButton:SetScript("OnClick", function()
      ImportQuestDataFromText(dataEditBox:GetText() or "")
      end)

    local selectButton = CreateFrame("Button", nil, dataWindow, "UIPanelButtonTemplate")
    selectButton:SetWidth(84)
    selectButton:SetHeight(24)
    selectButton:SetText("Select All")
    selectButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)
    SkinButton(selectButton)
    selectButton:SetScript("OnClick", function()
      dataEditBox:SetFocus()
      dataEditBox:HighlightText()
      end)

    local clearButton = CreateFrame("Button", nil, dataWindow, "UIPanelButtonTemplate")
    clearButton:SetWidth(64)
    clearButton:SetHeight(24)
    clearButton:SetText("Clear")
    clearButton:SetPoint("LEFT", selectButton, "RIGHT", 8, 0)
    SkinButton(clearButton)
    clearButton:SetScript("OnClick", function()
      SetQuestDataText("")
      dataEditBox:SetFocus()
      end)
  end

  if mode == "export" then
    CaptureCurrentObjectives()
    SetQuestDataText(Core.exportKnownQuestText(state.knownQuests))
  elseif mode == "import" then
    SetQuestDataText("")
  end

  dataWindow:Show()
  if dataWindow.Raise then
    dataWindow:Raise()
  end
  dataEditBox:SetFocus()

  if mode == "export" then
    dataEditBox:HighlightText()
  end
end

QuestLabel = function(quest)
  local title = Core.questTitle(quest)
  local questID = tonumber(quest and quest.questId)

  if title == "" then
    title = "Unknown quest"
  end

  if questID and questID > 0 then
    return title .. " (" .. tostring(math.floor(questID)) .. ")"
  end

  return title
end

function AutoCallboardRuntime.AppendCooldownProbe(apiName, label, start, duration, enabled)
  local remaining = "n/a"
  local stateText = "unknown"

  if start and duration then
    if start > 0 and duration > 0 then
      remaining = FormatSeconds(math.max(0, start + duration - GetTime()))
    else
      remaining = "0s"
    end

    stateText = start > 0 and duration > 1.5 and "ON CD" or "READY"
  end

  AppendDebugLog("debug", apiName .. " " .. label .. " state=" .. stateText .. " start=" .. tostring(start) .. " duration=" .. tostring(duration) .. " enabled=" .. tostring(enabled) .. " remaining=" .. remaining)
end

function AutoCallboardRuntime.AppendCallboardCooldownDebugSnapshot()
  AppendDebugLog("debug", "cooldown linked=" .. FormatSeconds(GetSummonCooldownRemaining()) .. " fallback=" .. FormatSeconds(GetFallbackCooldownRemaining()) .. " active=" .. FormatSeconds(SecondsRemaining(callboardActiveUntil)) .. " castThrottle=" .. FormatSeconds(SecondsRemaining(nextSummonCastAt)))

  if GetSpellCooldown and state and state.summonSpell and state.summonSpell ~= "" then
    local start, duration, enabled = GetSpellCooldown(state.summonSpell)
    AutoCallboardRuntime.AppendCooldownProbe("GetSpellCooldown", tostring(state.summonSpell), start, duration, enabled)
  else
    AppendDebugLog("debug", "GetSpellCooldown spell name unavailable")
  end

  if GetSpellCooldown and state and state.summonSpellID then
    local start, duration, enabled = GetSpellCooldown(state.summonSpellID)
    AutoCallboardRuntime.AppendCooldownProbe("GetSpellCooldown", tostring(state.summonSpellID), start, duration, enabled)
  else
    AppendDebugLog("debug", "GetSpellCooldown spell id unavailable")
  end

  if GetItemCooldown and state and state.summonSpellID then
    local start, duration, enabled = GetItemCooldown(state.summonSpellID)
    AutoCallboardRuntime.AppendCooldownProbe("GetItemCooldown", tostring(state.summonSpellID), start, duration, enabled)
  else
    AppendDebugLog("debug", "GetItemCooldown unavailable")
  end
end

local function AppendQuestDebugSnapshot()
  local objectives = CaptureCurrentObjectives()
  local activeObjective = GetActiveObjective()
  local desiredKeys = {}

  for key, enabled in pairs(state and state.desiredQuests or {}) do
    if enabled then
      table.insert(desiredKeys, key)
    end
  end

  table.sort(desiredKeys)

  local match = Core.findDesiredObjective(objectives, state and state.desiredQuests or {})
  AppendDebugLog("debug", "snapshot profile=" .. tostring(characterProfileKey) .. " rolling=" .. tostring(rolling) .. " roll=" .. tostring(rollCount) .. "/" .. tostring(state and state.maxRerolls) .. " desired=" .. tostring(table.getn(desiredKeys)) .. " current=" .. tostring(table.getn(objectives)) .. " signature=" .. ObjectiveSignature(objectives))
  AppendDebugLog("debug", "pause=" .. tostring(rollPausedReason) .. " selected=" .. tostring(selectedQuest and selectedQuest.title))
  AppendDebugLog("debug", "activeObjective=" .. tostring(activeObjective and QuestLabel(activeObjective) or "none"))
  AppendDebugLog("debug", "objectiveBoard ready=" .. FormatSeconds(SecondsRemaining(AutoCallboardRuntime.objectiveBoardReadyUntil)) .. " pending=" .. FormatSeconds(SecondsRemaining(AutoCallboardRuntime.objectiveRequestPendingUntil)) .. " attempts=" .. tostring(AutoCallboardRuntime.objectiveRequestAttempts or 0) .. " open=" .. tostring(AutoCallboardRuntime.objectiveBoardAccessOpen) .. " manual=" .. tostring(AutoCallboardRuntime.manualBoardOpenRequired))
  AutoCallboardRuntime.AppendBoardDetectionDebugSnapshot()
  AutoCallboardRuntime.AppendCallboardCooldownDebugSnapshot()

  if table.getn(desiredKeys) == 0 then
    AppendDebugLog("debug", "wanted keys: none")
  else
    for i = 1, table.getn(desiredKeys) do
      AppendDebugLog("debug", "wanted " .. tostring(i) .. ": " .. tostring(desiredKeys[i]))
    end
  end

  if match then
    AppendDebugLog("debug", "match slot=" .. tostring(match.index) .. " key=" .. tostring(match.key) .. " quest=" .. QuestLabel(match.quest))
  else
    AppendDebugLog("debug", "match: none")
  end

  for i = 1, table.getn(objectives) do
    local quest = objectives[i]
    local key = Core.questKey(quest)
    local wanted = key and state and state.desiredQuests and state.desiredQuests[key] == true
    AppendDebugLog("debug", "current " .. tostring(i) .. ": key=" .. tostring(key) .. " wanted=" .. tostring(wanted) .. " quest=" .. QuestLabel(quest) .. " objective=\"" .. CompactText(quest and quest.objectiveText) .. "\"")
  end
end

local QUEST_TYPE_NAMES = {
  [1] = "Open World",
  [2] = "Dungeon",
  [3] = "Raid",
  [4] = "Profession",
}

local function QuestMatchesSearch(quest, query)
  if not query or query == "" then
    return true
  end

  if not quest then
    return false
  end

  local questType = tonumber(quest.questType)
  local tooltipParts = {
    tostring(quest.title or ""),
    tostring(quest.objectiveText or ""),
    tostring(quest.questId or ""),
    tostring(quest.zoneOrSort or ""),
    tostring(quest.questType or ""),
    questType and QUEST_TYPE_NAMES[questType] or "",
    tostring(quest.normalXp or ""),
    tostring(quest.hc1Xp or ""),
    tostring(quest.hc2Xp or ""),
    tostring(quest.hc3Xp or ""),
    tostring(quest.hc4Xp or ""),
    tostring(quest.normalSoulAshes or ""),
    tostring(quest.hc1SoulAshes or ""),
    tostring(quest.hc2SoulAshes or ""),
    tostring(quest.hc3SoulAshes or ""),
    tostring(quest.hc4SoulAshes or ""),
    tostring(quest.seen or ""),
    "xp",
    "soul ash",
    "seen",
  }

  local needle = string.lower(query)
  local haystack = table.concat(tooltipParts, " "):lower()

  return string.find(haystack, needle, 1, true) ~= nil
end

local function FilterKnownQuests()
  local filtered = {}
  local quests = state and state.knownQuests or {}

  for i = 1, table.getn(quests) do
    if QuestMatchesSearch(quests[i], questSearchText) then
      table.insert(filtered, quests[i])
    end
  end

  return filtered
end

local function AddRewardLine(label, xp, soulAshes)
  local parts = {}

  if xp and xp > 0 then
    table.insert(parts, tostring(xp) .. " XP")
  end

  if soulAshes and soulAshes > 0 then
    table.insert(parts, tostring(soulAshes) .. " Soul Ash")
  end

  if table.getn(parts) > 0 then
    GameTooltip:AddDoubleLine(label, table.concat(parts, "  "), 0.85, 0.85, 0.85, 1, 1, 1)
  end
end

local function PositionTooltipNearCursor(owner)
  if not GetCursorPosition or not UIParent or not UIParent.GetEffectiveScale then
    GameTooltip:SetPoint("BOTTOMLEFT", owner or UIParent, "TOPRIGHT", 12, 12)
    return
  end

  local scale = UIParent:GetEffectiveScale() or 1
  local cursorX, cursorY = GetCursorPosition()
  local uiWidth = UIParent:GetWidth() or 0
  local uiHeight = UIParent:GetHeight() or 0
  local tooltipWidth = GameTooltip:GetWidth() or 260
  local tooltipHeight = GameTooltip:GetHeight() or 120
  local x = (cursorX / scale) + 18
  local y = (cursorY / scale) + 18

  if uiWidth > 0 and x + tooltipWidth > uiWidth - 8 then
    x = math.max(8, uiWidth - tooltipWidth - 8)
  end

  if uiHeight > 0 and y + tooltipHeight > uiHeight - 8 then
    y = math.max(8, uiHeight - tooltipHeight - 8)
  end

  GameTooltip:ClearAllPoints()
  GameTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function AnchorTooltipNearCursor(owner)
  GameTooltip:SetOwner(owner or UIParent, "ANCHOR_NONE")
  PositionTooltipNearCursor(owner)
end

local function ShowQuestTooltip(owner, quest, sourceLabel)
  if not quest then
    return
  end

  AnchorTooltipNearCursor(owner)
  GameTooltip:AddLine(Core.questTitle(quest) ~= "" and Core.questTitle(quest) or "Unknown quest", 1, 0.82, 0)

  if sourceLabel then
    GameTooltip:AddLine(sourceLabel, 0.65, 0.8, 1)
  end

  if tonumber(quest.questId) and tonumber(quest.questId) > 0 then
    GameTooltip:AddDoubleLine("Quest ID", tostring(math.floor(tonumber(quest.questId))), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  local questType = tonumber(quest.questType)
  if questType and questType > 0 then
    GameTooltip:AddDoubleLine("Type", QUEST_TYPE_NAMES[questType] or tostring(questType), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  if tonumber(quest.zoneOrSort) and tonumber(quest.zoneOrSort) > 0 then
    GameTooltip:AddDoubleLine("Zone/Sort", tostring(math.floor(tonumber(quest.zoneOrSort))), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  if quest.objectiveText and quest.objectiveText ~= "" then
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(quest.objectiveText, 1, 1, 1, true)
  end

  AddRewardLine("Normal", tonumber(quest.normalXp) or 0, tonumber(quest.normalSoulAshes) or 0)
  AddRewardLine("Heroic 1", tonumber(quest.hc1Xp) or 0, tonumber(quest.hc1SoulAshes) or 0)
  AddRewardLine("Heroic 2", tonumber(quest.hc2Xp) or 0, tonumber(quest.hc2SoulAshes) or 0)
  AddRewardLine("Heroic 3", tonumber(quest.hc3Xp) or 0, tonumber(quest.hc3SoulAshes) or 0)
  AddRewardLine("Heroic 4", tonumber(quest.hc4Xp) or 0, tonumber(quest.hc4SoulAshes) or 0)

  if quest.seen then
    GameTooltip:AddLine(" ")
    GameTooltip:AddDoubleLine("Seen", tostring(quest.seen), 0.8, 0.8, 0.8, 1, 1, 1)
  end

  GameTooltip:Show()
  PositionTooltipNearCursor(owner)
end

local function SetButtonEnabled(target, enabled)
  if not target then
    return
  end

  if enabled then
    target:Enable()
    target:SetAlpha(1)
  else
    target:Disable()
    target:SetAlpha(0.48)
  end

  SetButtonVisual(target)
end

function AutoCallboardRuntime.UpdateShareButtonState()
  local enabled = AutoCallboardRuntime.lastAcceptedQuest ~= nil

  SetButtonEnabled(AutoCallboardRuntime.shareQuestButton, enabled)

  if controlFrame and controlFrame.shareButton then
    SetButtonEnabled(controlFrame.shareButton, enabled)
  end
end

function AutoCallboardRuntime.UpdateAutoAcceptSharedControl()
  local checkbox = AutoCallboardRuntime.autoAcceptSharedCheckbox
  if not checkbox then
    return
  end

  checkbox:SetChecked(state and state.autoAcceptShared)
  SetCheckboxVisual(checkbox)
end

local function RefreshRollButtonMacroState(target)
  if not target or not target._acbRollToggle or not target.SetAttribute then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    return
  end

  if rolling then
    AutoCallboardRuntime.ApplySecureMacroButtonAttributes(target, "", "start")
  else
    AutoCallboardRuntime.ApplySecureMacroButtonAttributes(target, "", "start")
  end
end

local function UpdateRollToggleButtonState(target, canStart)
  if not target then
    return
  end

  if rolling then
    target._acbRollState = "stop"
    target:SetText("Stop")
    SetButtonEnabled(target, true)
    RefreshRollButtonMacroState(target)
    return
  end

  target._acbRollState = nil
  target:SetText("Start")
  SetButtonEnabled(target, canStart)
  RefreshRollButtonMacroState(target)
end

local function IsQuestRollStartAvailable()
  local service = GetObjectivesService()

  return CountDesiredQuests() > 0 and service ~= nil
end

UpdateRollToggleButtons = function()
  if controlFrame and controlFrame.startButton then
    UpdateRollToggleButtonState(controlFrame.startButton, true)
  end

  UpdateRollToggleButtonState(startRollButton, IsQuestRollStartAvailable())
end

function AutoCallboardRuntime.ApplySecureMacroButtonAttributes(target, macroText, label)
  if not target then
    return
  end

  macroText = macroText or ""

  if InCombatLockdown and InCombatLockdown() then
    AppendDebugLog("summon", "deferred secure " .. tostring(label) .. " update in combat")
    return
  end

  if target._acbSecureType == "macro" and target._acbSecureMacroText == macroText then
    return
  end

  target:SetAttribute("type", "macro")
  target:SetAttribute("macrotext", macroText)
  target._acbSecureType = "macro"
  target._acbSecureMacroText = macroText
  AppendDebugLog("summon", "secure " .. tostring(label) .. " macro set to " .. tostring(macroText))
end

function AutoCallboardRuntime.ConfigureStartButton(target)
  if not target then
    return
  end

  target._acbRollToggle = true
  AutoCallboardRuntime.ApplySecureMacroButtonAttributes(target, "", "start")
  target:SetScript("PreClick", function()
    if rolling then
      return
    end

    preClickTargetedBoardName = nil
    preClickCooldownRemaining = GetSummonCooldownRemaining()
    preClickWasActive = IsCallboardActive()
    preClickWasUsable = IsSummonSpellUsable()
    AutoCallboardRuntime.ApplySecureMacroButtonAttributes(target, "", "start")
    end)
  target:SetScript("PostClick", function()
    if rolling then
      StopRolling("Stopped.")
      UpdateSummonStatus()
      return
    end

    if preClickWasActive then
      Print("Callboard is already active for " .. FormatSeconds(SecondsRemaining(callboardActiveUntil)) .. ".")
    else
      AppendDebugLog("summon", "start roll requested; summon skipped")
    end

    StartRolling()
    preClickTargetedBoardName = nil
    UpdateSummonStatus()
    end)
end

local function GetKnownMaxScrollOffset()
  local knownCount = table.getn(FilterKnownQuests())

  return math.max(0, knownCount - KNOWN_ROWS)
end

local function SetKnownScrollOffset(value)
  local maxOffset = GetKnownMaxScrollOffset()
  local nextOffset = math.max(0, math.min(maxOffset, math.floor((tonumber(value) or 0) + 0.5)))

  if nextOffset == knownScrollOffset then
    if knownScrollFrame and knownScrollFrame._acbScrollBar and knownScrollFrame._acbScrollBar.SetValue then
      updatingKnownScrollBar = true
      knownScrollFrame._acbScrollBar:SetValue(nextOffset)
      updatingKnownScrollBar = false
    end
    return
  end

  knownScrollOffset = nextOffset

  if UpdateQuestWindow then
    UpdateQuestWindow()
  end
end

UpdateQuestWindow = function()
  if not questWindow then
    return
  end

  local objectives = CaptureCurrentObjectives()
  local service = GetObjectivesService()
  local desiredCount = CountDesiredQuests()

  for i = 1, 3 do
    local row = currentQuestRows[i]
    local objective = objectives[i]

    if row and objective then
      local key = Core.questKey(objective)
      local wanted = key and state.desiredQuests and state.desiredQuests[key] == true
      row.quest = objective
      row.key = key
      row.title:SetText(tostring(i) .. ". " .. QuestLabel(objective))
      row.title:SetTextColor(wanted and THEME.good[1] or THEME.gold[1], wanted and THEME.good[2] or THEME.gold[2], wanted and THEME.good[3] or THEME.gold[3])
      SetButtonEnabled(row.select, AutoCallboardRuntime.IsCallboardReadyForQuestActions())
      row:Show()
    elseif row then
      row.quest = nil
      row.key = nil
      row:Hide()
    end
  end

  local filteredKnownQuests = FilterKnownQuests()
  local totalKnownCount = table.getn(state.knownQuests or {})
  local knownCount = table.getn(filteredKnownQuests)
  local maxOffset = math.max(0, knownCount - KNOWN_ROWS)

  if knownScrollOffset > maxOffset then
    knownScrollOffset = maxOffset
  elseif knownScrollOffset < 0 then
    knownScrollOffset = 0
  end

  if knownScrollFrame and knownScrollFrame._acbScrollBar then
    local scrollBar = knownScrollFrame._acbScrollBar

    updatingKnownScrollBar = true
    if scrollBar.SetMinMaxValues then
      scrollBar:SetMinMaxValues(0, maxOffset)
    end
    if scrollBar.SetValueStep then
      scrollBar:SetValueStep(1)
    end
    if scrollBar.SetValue then
      scrollBar:SetValue(knownScrollOffset)
    end
    updatingKnownScrollBar = false

    if maxOffset > 0 then
      scrollBar:Show()
    else
      scrollBar:Hide()
    end
  elseif knownScrollFrame and FauxScrollFrame_Update and FauxScrollFrame_GetOffset then
    knownScrollFrame.offset = knownScrollOffset
    FauxScrollFrame_Update(knownScrollFrame, knownCount, KNOWN_ROWS, QUEST_ROW_HEIGHT)
    knownScrollOffset = FauxScrollFrame_GetOffset(knownScrollFrame)
  end

  local offset = knownScrollOffset
  for i = 1, KNOWN_ROWS do
    local row = knownQuestRows[i]
    local quest = filteredKnownQuests[offset + i]

    if row and quest then
      local wanted = quest.key and state.desiredQuests and state.desiredQuests[quest.key] == true
      row.quest = quest
      row.key = quest.key
      row.title:SetText(QuestLabel(quest))
      row.checkbox:SetChecked(wanted)
      SetCheckboxVisual(row.checkbox)
      row.title:SetTextColor(wanted and THEME.good[1] or THEME.gold[1], wanted and THEME.good[2] or THEME.gold[2], wanted and THEME.good[3] or THEME.gold[3])
      row:Show()
    elseif row then
      row.quest = nil
      row.key = nil
      row:Hide()
    end
  end

  if knownPageText then
    if questSearchText ~= "" then
      knownPageText:SetText("Check the quests you want to AutoRoll | Known: " .. tostring(totalKnownCount) .. " | Matches: " .. tostring(knownCount))
    else
      knownPageText:SetText("Check the quests you want to AutoRoll | Known: " .. tostring(totalKnownCount))
    end
  end

  UpdateRollToggleButtonState(startRollButton, desiredCount > 0 and service ~= nil)
  UpdateRollToggleButtonState(controlFrame and controlFrame.startButton or nil, true)
  AutoCallboardRuntime.UpdateAutoAcceptSharedControl()

  if questStatusText then
    local summonSummary = ""
    if IsCallboardActive() then
      summonSummary = " | active " .. FormatSeconds(SecondsRemaining(callboardActiveUntil))
    elseif GetSummonCooldownRemaining() > 0 then
      summonSummary = " | cooldown " .. FormatSeconds(GetSummonCooldownRemaining())
    end

    if not service then
      questStatusText:SetText("ProjectEbonhold objectives are not available yet.")
    elseif rolling and rollPausedReason == "quest_selected" and selectedQuest then
      questStatusText:SetText("Paused: selected " .. tostring(selectedQuest.title or "quest") .. summonSummary)
    elseif rolling and rollPausedReason then
      questStatusText:SetText(tostring(rollPauseMessage or ("Paused: " .. rollPausedReason)) .. summonSummary)
    elseif rolling then
      questStatusText:SetText("Rolling... " .. tostring(rollCount) .. "/" .. tostring(state.maxRerolls) .. " | wanted " .. tostring(desiredCount) .. summonSummary)
    else
      questStatusText:SetText("Selected: " .. tostring(desiredCount) .. summonSummary)
    end
  end
end

local function MakeQuestRow(parent, index, width, isCurrent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetWidth(width)
  row:SetHeight(24)
  SkinFrame(row, "soft")
  row:EnableMouse(true)
  row:SetScript("OnEnter", function(self)
    ShowQuestTooltip(self, self.quest, isCurrent and "Current roll" or "Known quest")
    end)
  row:SetScript("OnLeave", function()
    GameTooltip:Hide()
    end)

  row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  row.title:SetPoint("LEFT", row, "LEFT", 3, 0)
  row.title:SetWidth(isCurrent and (width - 73) or (width - 36))
  row.title:SetJustifyH("LEFT")
  row.title:SetTextColor(THEME.gold[1], THEME.gold[2], THEME.gold[3])

  row:EnableMouseWheel(true)
  row:SetScript("OnMouseWheel", function(_, delta)
    SetKnownScrollOffset(knownScrollOffset - delta)
    end)

  if isCurrent then
    row.select = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.select:SetWidth(58)
    row.select:SetHeight(20)
    row.select:SetText("Select")
    row.select:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    SkinButton(row.select)
    row.select:SetScript("OnClick", function()
      SelectObjectiveIndex(index)
      end)
    row.select:SetScript("OnEnter", function(self)
      SetButtonVisual(self, "hover")
      ShowQuestTooltip(self, row.quest, "Current roll")
      end)
    row.select:SetScript("OnLeave", function(self)
      SetButtonVisual(self)
      GameTooltip:Hide()
      end)
  else
    row.checkbox = CreateFrame("CheckButton", nil, row)
    row.checkbox:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    SkinCheckbox(row.checkbox)
    row.checkbox:SetScript("OnClick", function(self)
      if row.key then
        ToggleDesiredQuest(row.key)
      end
      SetCheckboxVisual(self)
      end)
    row.checkbox:SetScript("OnEnter", function(self)
      SetCheckboxVisual(self, "hover")
      ShowQuestTooltip(self, row.quest, "Known quest")
      end)
    row.checkbox:SetScript("OnLeave", function(self)
      SetCheckboxVisual(self)
      GameTooltip:Hide()
      end)
    row.checkbox:EnableMouseWheel(true)
    row.checkbox:SetScript("OnMouseWheel", function(_, delta)
      SetKnownScrollOffset(knownScrollOffset - delta)
      end)
  end

  return row
end

function AutoCallboardRuntime.SetControlFrameSize(width, height)
  if not controlFrame then
    return
  end

  local centerX = controlFrame:GetCenter()
  local top = controlFrame:GetTop()

  controlFrame:SetWidth(width)
  controlFrame:SetHeight(height)

  if centerX and top then
    controlFrame:ClearAllPoints()
    controlFrame:SetPoint("TOP", UIParent, "BOTTOMLEFT", centerX, top)
  end
end

function AutoCallboardRuntime.PositionControlHeader()
  if not controlFrame or not button then
    return
  end

  local frameWidth = controlFrame:GetWidth()
  local leftOffset = 10
  local buttonRowWidth = button:GetWidth() or 88

  if controlFrame.startButton then
    buttonRowWidth = buttonRowWidth + 5 + (controlFrame.startButton:GetWidth() or 72)
  end

  if controlFrame.shareButton then
    buttonRowWidth = buttonRowWidth + 4 + (controlFrame.shareButton:GetWidth() or 54)
  end

  if controlFrame.questButton then
    buttonRowWidth = buttonRowWidth + 4 + (controlFrame.questButton:GetWidth() or 50)
  end

  if frameWidth and frameWidth > buttonRowWidth then
    leftOffset = (frameWidth - buttonRowWidth) / 2
  end

  if controlFrame.title then
    controlFrame.title:ClearAllPoints()
    controlFrame.title:SetPoint("TOP", controlFrame, "TOP", 0, -8)
  end

  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", leftOffset, -30)

  if summonStatusText then
    summonStatusText:ClearAllPoints()
    summonStatusText:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -5)
    summonStatusText:SetWidth(math.max(180, (frameWidth or AutoCallboardRuntime.controlCollapsedWidth) - 20))
  end
end

function AutoCallboardRuntime.AnimateControlFrameSize(width, height, onComplete)
  if not controlFrame then
    if onComplete then
      onComplete()
    end
    return
  end

  local startWidth = controlFrame:GetWidth()
  local startHeight = controlFrame:GetHeight()
  local startedAt = GetTime()

  if AutoCallboardRuntime.questPanelAnimation then
    AutoCallboardRuntime.questPanelAnimation.finished = true
  end

  AutoCallboardRuntime.questPanelAnimation = {
    finished = false,
    onComplete = onComplete,
    startHeight = startHeight,
    startWidth = startWidth,
    startedAt = startedAt,
    targetHeight = height,
    targetWidth = width,
  }
end

function AutoCallboardRuntime.UpdateQuestPanelAnimation()
  local animation = AutoCallboardRuntime.questPanelAnimation

  if not animation or animation.finished then
    return
  end

  local elapsed = GetTime() - animation.startedAt
  local progress = elapsed / AutoCallboardRuntime.questPanelAnimationSeconds

  if progress >= 1 then
    progress = 1
    animation.finished = true
  end

  local eased = 1 - ((1 - progress) * (1 - progress))
  local width = animation.startWidth + ((animation.targetWidth - animation.startWidth) * eased)
  local height = animation.startHeight + ((animation.targetHeight - animation.startHeight) * eased)

  AutoCallboardRuntime.SetControlFrameSize(width, height)
  AutoCallboardRuntime.PositionControlHeader()

  if animation.finished then
    AutoCallboardRuntime.SetControlFrameSize(animation.targetWidth, animation.targetHeight)
    AutoCallboardRuntime.PositionControlHeader()
    AutoCallboardRuntime.questPanelAnimation = nil

    if animation.onComplete then
      animation.onComplete()
    end
  end
end

function AutoCallboardRuntime.SetQuestPanelExpanded(expanded)
  if not controlFrame then
    return
  end

  if AutoCallboardRuntime.questPanelChanging then
    return
  end

  AutoCallboardRuntime.questPanelChanging = true

  if expanded then
    if not questWindow then
      AutoCallboardRuntime.CreateQuestWindow()
    end

    if summonStatusText then
      summonStatusText:SetWidth(256)
    end

    if controlFrame.questButton then
      controlFrame.questButton:SetText("Hide")
    end

    CaptureCurrentObjectives()
    UpdateQuestWindow()
    AutoCallboardRuntime.AnimateControlFrameSize(AutoCallboardRuntime.controlExpandedWidth, AutoCallboardRuntime.controlExpandedHeight, function()
        if questWindow then
          questWindow:Show()
        end

        AutoCallboardRuntime.questPanelChanging = false
    end)
  else
    if questWindow and questWindow:IsShown() then
      questWindow:Hide()
    end

    if summonStatusText then
      summonStatusText:SetWidth(256)
    end

    if controlFrame.questButton then
      controlFrame.questButton:SetText("Quests")
    end

    AutoCallboardRuntime.AnimateControlFrameSize(AutoCallboardRuntime.controlCollapsedWidth, AutoCallboardRuntime.controlCollapsedHeight, function()
        AutoCallboardRuntime.PositionControlHeader()
        AutoCallboardRuntime.questPanelChanging = false
    end)
  end
end

function AutoCallboardRuntime.ToggleQuestPanel()
  AutoCallboardRuntime.SetQuestPanelExpanded(not (questWindow and questWindow:IsShown()))
end

function AutoCallboardRuntime.CreateQuestWindow()
  questWindow = CreateFrame("Frame", "AutoCallboardQuestWindow", controlFrame or UIParent)
  RegisterSpecialFrame("AutoCallboardQuestWindow")
  questWindow:SetWidth(QUEST_WINDOW_WIDTH)
  questWindow:SetHeight(590)
  questWindow:SetPoint("TOPLEFT", controlFrame or UIParent, "TOPLEFT", controlFrame and 10 or 0, controlFrame and -82 or 0)
  if controlFrame and questWindow.SetFrameLevel then
    questWindow:SetFrameLevel(controlFrame:GetFrameLevel() + 1)
  end
  questWindow:EnableMouse(true)
  questWindow:SetClampedToScreen(true)
  SkinFrame(questWindow)
  questWindow:SetScript("OnHide", function()
    if questSearchBox and questSearchBox.ClearFocus then
      questSearchBox:ClearFocus()
    end

    if controlFrame and not AutoCallboardRuntime.questPanelChanging then
      AutoCallboardRuntime.SetQuestPanelExpanded(false)
    end
    end)

  local title = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", questWindow, "TOP", 0, -18)
  title:SetText("AutoCallboard Quests")
  SkinHeadingText(title)

  local currentHeader = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  currentHeader:SetPoint("TOPLEFT", questWindow, "TOPLEFT", 24, -52)
  currentHeader:SetText("Current Callboard Quests")
  SkinHeadingText(currentHeader)

  for i = 1, 3 do
    currentQuestRows[i] = MakeQuestRow(questWindow, i, CURRENT_QUEST_ROW_WIDTH, true)
    currentQuestRows[i]:SetPoint("TOPLEFT", currentHeader, "BOTTOMLEFT", 0, -8 - ((i - 1) * QUEST_ROW_HEIGHT))
  end

  local searchLabel = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("TOPLEFT", questWindow, "TOPLEFT", 24, -178)
  searchLabel:SetText("Search")
  SkinMutedText(searchLabel)

  questSearchBox = CreateFrame("EditBox", "AutoCallboardQuestSearchBox", questWindow, "InputBoxTemplate")
  questSearchBox:SetWidth(250)
  questSearchBox:SetHeight(24)
  questSearchBox:SetAutoFocus(false)
  questSearchBox:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
  SkinEditBox(questSearchBox)
  questSearchBox:SetScript("OnTextChanged", function(self)
    questSearchText = self:GetText() or ""
    SetKnownScrollOffset(0)
    end)
  questSearchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    end)
  questSearchBox:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
    end)

  local clearSearchButton = CreateFrame("Button", nil, questWindow, "UIPanelButtonTemplate")
  clearSearchButton:SetWidth(54)
  clearSearchButton:SetHeight(22)
  clearSearchButton:SetText("Clear")
  clearSearchButton:SetPoint("LEFT", questSearchBox, "RIGHT", 10, 0)
  SkinButton(clearSearchButton)
  clearSearchButton:SetScript("OnClick", function()
    questSearchBox:SetText("")
    questSearchBox:ClearFocus()
    end)

  AutoCallboardRuntime.autoAcceptSharedCheckbox = CreateFrame("CheckButton", nil, questWindow)
  AutoCallboardRuntime.autoAcceptSharedCheckbox:SetPoint("TOPRIGHT", questWindow, "TOPRIGHT", -24, -178)
  SkinCheckbox(AutoCallboardRuntime.autoAcceptSharedCheckbox)
  AutoCallboardRuntime.autoAcceptSharedCheckbox:SetScript("OnClick", function(self)
    AutoCallboardRuntime.SetField("autoAcceptShared", self:GetChecked() and true or false)
    end)
  AutoCallboardRuntime.autoAcceptSharedCheckbox:SetScript("OnEnter", function(self)
    SetCheckboxVisual(self, "hover")
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Auto Accept Quests")
    GameTooltip:AddLine("Automatically accepts quests shared by party or raid members.", 1, 1, 1)
    GameTooltip:Show()
    end)
  AutoCallboardRuntime.autoAcceptSharedCheckbox:SetScript("OnLeave", function(self)
    SetCheckboxVisual(self)
    GameTooltip:Hide()
    end)

  local autoAcceptSharedLabel = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  autoAcceptSharedLabel:SetPoint("RIGHT", AutoCallboardRuntime.autoAcceptSharedCheckbox, "LEFT", -8, 0)
  autoAcceptSharedLabel:SetText("Auto Accept Quests")
  SkinMutedText(autoAcceptSharedLabel)
  AutoCallboardRuntime.UpdateAutoAcceptSharedControl()

  knownPageText = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  knownPageText:SetPoint("TOPLEFT", questWindow, "TOPLEFT", 24, -216)
  knownPageText:SetWidth(QUEST_WINDOW_WIDTH - 62)
  knownPageText:SetJustifyH("LEFT")
  knownPageText:SetText("Check the quests you want to AutoRoll | Known: 0")
  SkinHeadingText(knownPageText)

  knownScrollFrame = CreateFrame("ScrollFrame", "AutoCallboardKnownQuestScrollFrame", questWindow, "FauxScrollFrameTemplate")
  knownScrollFrame:SetPoint("TOPLEFT", knownPageText, "BOTTOMLEFT", -4, -8)
  knownScrollFrame:SetPoint("BOTTOMRIGHT", questWindow, "BOTTOMRIGHT", -34, 80)
  knownScrollFrame:EnableMouseWheel(true)
  local knownScrollBar = SkinScrollBar(knownScrollFrame)
  if knownScrollBar then
    knownScrollBar:SetScript("OnValueChanged", function(_, value)
      if updatingKnownScrollBar then
        return
      end

      SetKnownScrollOffset(value)
      end)

    if knownScrollBar._acbUpButton then
      knownScrollBar._acbUpButton:SetScript("OnClick", function()
        SetKnownScrollOffset(knownScrollOffset - 1)
        end)
    end

    if knownScrollBar._acbDownButton then
      knownScrollBar._acbDownButton:SetScript("OnClick", function()
        SetKnownScrollOffset(knownScrollOffset + 1)
        end)
    end
  end
  knownScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
    SetKnownScrollOffset(offset)
    end)
  knownScrollFrame:SetScript("OnMouseWheel", function(_, delta)
    SetKnownScrollOffset(knownScrollOffset - delta)
    end)

  for i = 1, KNOWN_ROWS do
    knownQuestRows[i] = MakeQuestRow(questWindow, i, KNOWN_QUEST_ROW_WIDTH, false)
    knownQuestRows[i]:SetPoint("TOPLEFT", knownPageText, "BOTTOMLEFT", 0, -10 - ((i - 1) * QUEST_ROW_HEIGHT))
  end

  local questToolbarWidth = 72 + 8 + 54 + 8 + 66 + 8 + 66

  startRollButton = CreateFrame("Button", nil, questWindow, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  startRollButton:SetWidth(72)
  startRollButton:SetHeight(24)
  startRollButton:SetText("Start")
  startRollButton:SetPoint("BOTTOMLEFT", questWindow, "BOTTOM", -(questToolbarWidth / 2), 46)
  SkinButton(startRollButton)
  AutoCallboardRuntime.ConfigureStartButton(startRollButton)
  UpdateRollToggleButtonState(startRollButton, IsQuestRollStartAvailable())

  AutoCallboardRuntime.shareQuestButton = CreateFrame("Button", nil, questWindow, "UIPanelButtonTemplate")
  AutoCallboardRuntime.shareQuestButton:SetWidth(54)
  AutoCallboardRuntime.shareQuestButton:SetHeight(24)
  AutoCallboardRuntime.shareQuestButton:SetText("Share")
  AutoCallboardRuntime.shareQuestButton:SetPoint("LEFT", startRollButton, "RIGHT", 8, 0)
  SkinButton(AutoCallboardRuntime.shareQuestButton)
  AutoCallboardRuntime.shareQuestButton:SetScript("OnClick", function()
    AutoCallboardRuntime.ShareAcceptedQuest("quest window button")
    end)
  AutoCallboardRuntime.shareQuestButton:SetScript("OnEnter", function(self)
    SetButtonVisual(self, "hover")
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Share")
    GameTooltip:AddLine("Shares the last accepted quest.", 1, 1, 1)
    GameTooltip:Show()
    end)
  AutoCallboardRuntime.shareQuestButton:SetScript("OnLeave", function(self)
    SetButtonVisual(self)
    GameTooltip:Hide()
    end)
  AutoCallboardRuntime.UpdateShareButtonState()

  local exportDataButton = CreateFrame("Button", nil, questWindow, "UIPanelButtonTemplate")
  exportDataButton:SetWidth(66)
  exportDataButton:SetHeight(24)
  exportDataButton:SetText("Export")
  exportDataButton:SetPoint("LEFT", AutoCallboardRuntime.shareQuestButton, "RIGHT", 8, 0)
  SkinButton(exportDataButton)
  exportDataButton:SetScript("OnClick", function()
    ShowQuestDataWindow("export")
    end)

  local importDataButton = CreateFrame("Button", nil, questWindow, "UIPanelButtonTemplate")
  importDataButton:SetWidth(66)
  importDataButton:SetHeight(24)
  importDataButton:SetText("Import")
  importDataButton:SetPoint("LEFT", exportDataButton, "RIGHT", 8, 0)
  SkinButton(importDataButton)
  importDataButton:SetScript("OnClick", function()
    ShowQuestDataWindow("import")
    end)

  questStatusText = questWindow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  questStatusText:SetPoint("BOTTOMLEFT", questWindow, "BOTTOMLEFT", 24, 22)
  questStatusText:SetWidth(540)
  questStatusText:SetJustifyH("LEFT")
  SkinMutedText(questStatusText)

  questWindow:Hide()
end

ShowQuestWindow = function()
  if not questWindow then
    AutoCallboardRuntime.CreateQuestWindow()
  end

  AutoCallboardRuntime.SetQuestPanelExpanded(true)
end

local function HandleDebugAction(action, value)
  if action == "open" then
    local nextState = Core.mergeState(state)
    nextState.debug.enabled = true
    ApplyState(nextState)
    AppendQuestDebugSnapshot()
    DumpKnownFrames()
    ShowDebugWindow()
  elseif action == "enabled" then
    local nextState = Core.mergeState(state)
    nextState.debug.enabled = value
    ApplyState(nextState)
    Print("Debug output is " .. (value and "on" or "off") .. ".")
    if value then
      ShowDebugWindow()
    end
  elseif action == "mouseWatch" then
    local nextState = Core.mergeState(state)
    nextState.debug.mouseWatch = value
    ApplyState(nextState)
    Print("Mouse watch is " .. (value and "on" or "off") .. ".")
  elseif action == "sniffer" then
    AutoCallboardRuntime.SetInteractionSnifferEnabled(value)
  elseif action == "sniffDump" then
    AutoCallboardRuntime.InstallInteractionSnifferHooks()
    AutoCallboardRuntime.AppendInteractionSniffSnapshot("manual", "MANUAL_SNIFF_DUMP")
    ShowDebugWindow()
  elseif action == "sniffClear" then
    AutoCallboardDebugLog = {}
    AppendDebugLog("sniff", "interaction sniffer cleared")
    ShowDebugWindow()
  elseif action == "etrace" then
    AutoCallboardRuntime.OpenEventTrace()
  elseif action == "inspect" then
    InspectMouseFocus()
  elseif action == "dump" then
    DumpKnownFrames()
  elseif action == "cooldown" then
    AutoCallboardRuntime.AppendCallboardCooldownDebugSnapshot()
    ShowDebugWindow()
  elseif action == "logs" then
    PrintRecentLogs()
  elseif action == "clearlogs" then
    ClearDebugLogs()
  end
end

local function SaveButtonPosition()
  if not controlFrame or not state then
    return
  end

  local point, _, relativePoint, x, y = controlFrame:GetPoint(1)
  local nextState = Core.mergeState(state)
  nextState.button = {
    point = point or "CENTER",
    relativePoint = relativePoint or "CENTER",
    x = x or 0,
    y = y or 0,
  }

  ApplyState(nextState)
end

local function PositionButton()
  controlFrame:ClearAllPoints()
  controlFrame:SetPoint(state.button.point, UIParent, state.button.relativePoint, state.button.x, state.button.y)
end

local function SaveMinimapPosition(angle)
  local nextState = Core.mergeState(state)
  nextState.minimap.angle = angle
  nextState.minimap.shown = true
  ApplyState(nextState)
end

PositionMinimapButton = function()
  if not minimapButton or not state then
    return
  end

  if not state.minimap.shown then
    minimapButton:Hide()
    return
  end

  local parent = Minimap or UIParent
  local angle = math.rad(state.minimap.angle or 225)
  local radius = 82
  local x = math.cos(angle) * radius
  local y = math.sin(angle) * radius

  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", parent, "CENTER", x, y)
  minimapButton:Show()
end

local function UpdateMinimapDragPosition()
  if not minimapButton or not Minimap or not GetCursorPosition then
    return
  end

  local scale = Minimap:GetEffectiveScale() or 1
  local cursorX, cursorY = GetCursorPosition()
  local centerX, centerY = Minimap:GetCenter()

  cursorX = cursorX / scale
  cursorY = cursorY / scale

  local angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
  SaveMinimapPosition(angle)
  PositionMinimapButton()
end

local function CreateMinimapButton()
  if minimapButton then
    PositionMinimapButton()
    return
  end

  minimapButton = CreateFrame("Button", "AutoCallboardMinimapButton", Minimap or UIParent)
  minimapButton:SetWidth(32)
  minimapButton:SetHeight(32)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetMovable(true)
  SkinButton(minimapButton)

  minimapText = minimapButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  minimapText:SetPoint("CENTER", minimapButton, "CENTER", 0, 0)
  minimapText:SetText("ACB")
  minimapText:SetTextColor(THEME.gold[1], THEME.gold[2], THEME.gold[3])

  minimapButton:SetScript("OnDragStart", function()
    minimapButton:SetScript("OnUpdate", UpdateMinimapDragPosition)
    end)
  minimapButton:SetScript("OnDragStop", function()
    minimapButton:SetScript("OnUpdate", nil)
    UpdateMinimapDragPosition()
    end)
  minimapButton:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      if controlFrame and not controlFrame:IsShown() then
        local nextState = Core.mergeState(state)
        nextState.buttonShown = true
        ApplyState(nextState)
        controlFrame:Show()
      end

      AutoCallboardRuntime.ToggleQuestPanel()
      return
    end

    if controlFrame and controlFrame:IsShown() then
      controlFrame:Hide()
    elseif controlFrame then
      local nextState = Core.mergeState(state)
      nextState.buttonShown = true
      ApplyState(nextState)
      controlFrame:Show()
    end
    end)
  minimapButton:SetScript("OnEnter", function(self)
    SetButtonVisual(self, "hover")
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("AutoCallboard")
    GameTooltip:AddLine("Left-click: show or hide controls.", 1, 1, 1)
    GameTooltip:AddLine("Right-click: open or close quests.", 1, 1, 1)
    GameTooltip:AddLine("Drag: move minimap button.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
    end)
  minimapButton:SetScript("OnLeave", function(self)
    SetButtonVisual(self)
    GameTooltip:Hide()
    end)

  PositionMinimapButton()
end

local function TargetBoardName(name)
  if not name or name == "" then
    return false
  end

  if TargetByName then
    TargetByName(name, true)
  end

  if UnitExists("target") and UnitName("target") == name then
    return true, name
  end

  return false
end

TargetCallboard = function()
  local found, targetName
  for i = 1, table.getn(BOARD_TARGET_PRIMARY_NAMES) do
    found, targetName = TargetBoardName(BOARD_TARGET_PRIMARY_NAMES[i])
    if found then
      return true, targetName
    end
  end

  found, targetName = TargetBoardName(state.targetName)
  if found then
    return true, targetName
  end

  return false
end

local function TryInteract()
  local source = AutoCallboardRuntime.pendingInteractSource
  pendingInteractAt = nil
  AutoCallboardRuntime.pendingInteractSource = nil

  local targeted, targetName = TargetCallboard()
  if not targeted then
    AutoCallboardRuntime.SetManualBoardOpenRequired(source)
    return
  end

  pendingAcceptUntil = GetTime() + ACCEPT_WINDOW

  if InteractUnit then
    InteractUnit("target")
  else
    SetQuestStatus("Targeted \"" .. targetName .. "\". Right-click it to open the quest.")
  end
end

local function RunFrameScript(target, scriptName)
  if not target.GetScript then
    return false
  end

  local script = target:GetScript(scriptName)
  if not script then
    return false
  end

  script(target, "LeftButton")
  return true
end

ClickNamedFrame = function(frameName, label)
  local target = ResolveFramePath(frameName)

  if not target then
    AppendDebugLog("click", label .. " missing " .. frameName)
    Print(label .. " frame not found: " .. frameName)
    return false
  end

  if target.IsShown and not target:IsShown() then
    AppendDebugLog("click", label .. " hidden " .. FrameSummary(target))
    Print(label .. " frame is not shown yet: " .. frameName)
    return false
  end

  AppendDebugLog("click", label .. " " .. FrameSummary(target))

  local ok, clicked = pcall(function()
        if target.Click then
          target:Click()
          return true
        end

        if RunFrameScript(target, "OnClick") then
          return true
        end

        if RunFrameScript(target, "OnMouseDown") then
          RunFrameScript(target, "OnMouseUp")
          return true
        end

        if RunFrameScript(target, "OnMouseUp") then
          return true
        end

        return false
    end)

  if not ok then
    AppendDebugLog("click", label .. " error " .. frameName)
    Print(label .. " click failed: " .. frameName)
    return false
  end

  if not clicked then
    AppendDebugLog("click", label .. " no script " .. FrameSummary(target))
    Print(label .. " frame has no click script: " .. frameName)
    return false
  end

  return true
end

local function ClickReroll()
  if not RequireActiveCallboard("rerolling") then
    return
  end

  if BypassRerollConfirm() then
    SetQuestStatus("Reroll requested.")
  else
    SetQuestStatus("Could not reroll. Check gold or Callboard UI.")
  end
end

local function ClickObjective(index)
  if not RequireActiveCallboard("selecting a quest") then
    return
  end

  local frameName = state.objectivePrefix .. tostring(index) .. "." .. state.objectiveButtonField

  if not ResolveFramePath(frameName) then
    frameName = state.objectivePrefix .. tostring(index)
  end

  ClickNamedFrame(frameName, "Objective " .. tostring(index))
end

QueueCallboardFollowup = function(source)
  pendingAcceptUntil = GetTime() + ACCEPT_WINDOW
  AppendDebugLog("summon", "queued follow-up from " .. tostring(source))

  if TargetCallboard() then
    TryInteract()
    return
  end

  pendingInteractAt = GetTime() + INTERACT_DELAY
  AutoCallboardRuntime.pendingInteractSource = source
end

StartCallboardFlow = function(silent)
  if IsCallboardActive() then
    ResumeRollingAfterCallboardActive("slash active")
    QueueCallboardFollowup("slash active")

    if not silent then
      Print("Callboard is already active.")
    end

    return
  end

  local targeted, targetName = TargetCallboard()
  if targeted then
    AppendDebugLog("summon", "opening nearby board " .. tostring(targetName))
    QueueCallboardFollowup("slash nearby board")

    if not silent then
      Print("Opening \"" .. targetName .. "\"...")
    end

    UpdateSummonStatus()
    return
  end

  local cooldownRemaining = GetSummonCooldownRemaining()
  if cooldownRemaining > 0 then
    if not silent then
      Print("Summon Callboard is on cooldown for " .. FormatSeconds(cooldownRemaining) .. ".")
    end

    UpdateSummonStatus()
    return
  end

  if not IsSummonSpellUsable() then
    if not silent then
      Print("Summon Callboard is not usable here.")
    end

    AppendDebugLog("summon", "spell not usable")
    UpdateSummonStatus()
    return
  end

  local now = GetTime()

  if nextSummonCastAt and now < nextSummonCastAt then
    SetRollPause("no_callboard", "Paused: waiting for Callboard summon.")
    AppendDebugLog("summon", "summon throttled remaining=" .. tostring(nextSummonCastAt - now))
    UpdateSummonStatus()
    return
  end

  nextSummonCastAt = now + 3

  local summonMacroText = AutoCallboardRuntime.GetSummonMacroText()

  if summonMacroText and RunMacroText then
    AppendDebugLog("summon", "RunMacroText " .. summonMacroText:gsub("\n", " | "))
    RunMacroText(summonMacroText)
    AutoCallboardRuntime.BeginSummonAttempt("slash")

    if not silent then
      Print("Summoning \"" .. state.targetName .. "\"...")
    end
  elseif state.summonSpell ~= "" and CastSpellByName then
    AppendDebugLog("summon", "CastSpellByName " .. state.summonSpell)
    CastSpellByName(state.summonSpell)
    AutoCallboardRuntime.BeginSummonAttempt("slash")

    if not silent then
      Print("Summoning \"" .. state.targetName .. "\"...")
    end
  elseif state.summonSpellID and CastSpellByID then
    AppendDebugLog("summon", "CastSpellByID " .. tostring(state.summonSpellID))
    CastSpellByID(state.summonSpellID)
    AutoCallboardRuntime.BeginSummonAttempt("slash")

    if not silent then
      Print("Summoning \"" .. state.targetName .. "\"...")
    end
  else
    AppendDebugLog("summon", "no spell cast API available")
    TryInteract()
  end

  UpdateSummonStatus()
end

local function ShowHelp()
  ShowAddonHelp("main")
end

function AutoCallboardRuntime.SetField(field, value)
  local nextState = Core.mergeState(state)
  nextState[field] = value
  ApplyState(nextState)

  if field == "targetName" then
    button:SetText(value)
    Print("Callboard target set to \"" .. value .. "\".")
  elseif field == "summonSpell" then
    ApplySummonButtonAttributes()
    Print("Summon spell set to " .. (value ~= "" and "\"" .. value .. "\"" or "off") .. ".")
  elseif field == "summonSpellID" then
    ApplySummonButtonAttributes()
    Print("Summon spell ID set to " .. tostring(value) .. ".")
  elseif field == "rerollFrame" then
    Print("Reroll frame set to " .. value .. ".")
  elseif field == "objectiveButtonField" then
    Print("Objective button field set to " .. value .. ".")
  elseif field == "autoAccept" then
    Print("Quest auto-accept is " .. (value and "on" or "off") .. ".")
  elseif field == "autoAcceptShared" then
    Print("Auto Accept Quests is " .. (value and "on" or "off") .. ".")
  elseif field == "autoSelect" then
    Print("Quest auto-select is " .. (value and "on" or "off") .. ".")
  elseif field == "maxRerolls" then
    Print("Max rerolls set to " .. tostring(value) .. ".")
  end
end

local function HandleSlash(input)
  local parsed = Core.parseSlash(input)

  if parsed.kind == "run" then
    if controlFrame and not controlFrame:IsShown() then
      controlFrame:Show()
    end

    StartCallboardFlow()
  elseif parsed.kind == "help" then
    ShowHelp()
  elseif parsed.kind == "show" then
    local nextState = Core.mergeState(state)
    nextState.buttonShown = true
    ApplyState(nextState)
    controlFrame:Show()
  elseif parsed.kind == "hide" then
    local nextState = Core.mergeState(state)
    nextState.buttonShown = false
    ApplyState(nextState)
    controlFrame:Hide()
  elseif parsed.kind == "reset" then
    ApplyState(Core.defaultState())
    button:SetText(state.targetName)
    ApplySummonButtonAttributes()
    PositionButton()
    controlFrame:Show()
    Print("Settings reset.")
  elseif parsed.kind == "set" then
    AutoCallboardRuntime.SetField(parsed.field, parsed.value)
  elseif parsed.kind == "reroll" then
    ClickReroll()
  elseif parsed.kind == "objective" then
    ClickObjective(parsed.index)
  elseif parsed.kind == "quests" then
    ShowQuestWindow()
  elseif parsed.kind == "roll" then
    StartRolling()
  elseif parsed.kind == "stop" then
    StopRolling("Stopped.")
  elseif parsed.kind == "debug" then
    HandleDebugAction(parsed.action, parsed.value)
  elseif parsed.kind == "data" then
    ShowQuestDataWindow(parsed.action)
  else
    Print(parsed.message)
  end
end

local function HookDebugFrame(frameName, label)
  local target = ResolveFramePath(frameName)

  if not target or hookedDebugFrames[frameName] then
    return
  end

  if not target.HookScript then
    return
  end

  pcall(target.HookScript, target, "OnMouseDown", function()
      AppendDebugLog("mouse-down", label .. " " .. FrameSummary(target))
  end)
  pcall(target.HookScript, target, "OnMouseUp", function()
      AppendDebugLog("mouse-up", label .. " " .. FrameSummary(target))
  end)
  pcall(target.HookScript, target, "OnClick", function()
      AppendDebugLog("on-click", label .. " " .. FrameSummary(target))
  end)

  hookedDebugFrames[frameName] = true
  AppendDebugLog("hook", label .. " " .. FrameSummary(target))
end

local function RefreshDebugHooks()
  if not state or not state.debug or not state.debug.enabled then
    return
  end

  HookDebugFrame(state.rerollFrame, "reroll")

  for i = 1, 3 do
    HookDebugFrame(state.objectivePrefix .. tostring(i), "objective " .. tostring(i) .. " frame")
    HookDebugFrame(state.objectivePrefix .. tostring(i) .. "." .. state.objectiveButtonField, "objective " .. tostring(i) .. " button")
  end
end

local function StartMovingButton(self)
  if IsShiftKeyDown() then
    controlFrame:StartMoving()
  end
end

local function StopMovingButton(self)
  controlFrame:StopMovingOrSizing()
  SaveButtonPosition()
end

local function MakeActionButton(name, text, width, height, point, relativeTo, relativePoint, x, y, onClick, template)
  local actionButton = CreateFrame("Button", name, controlFrame, template or "UIPanelButtonTemplate")
  actionButton:SetWidth(width)
  actionButton:SetHeight(height)
  actionButton:SetText(text)
  actionButton:SetPoint(point, relativeTo, relativePoint, x, y)
  actionButton:RegisterForDrag("LeftButton")
  if template and template:find("SecureActionButtonTemplate", 1, true) then
    actionButton:RegisterForClicks("AnyUp")
  end
  if onClick then
    actionButton:SetScript("OnClick", onClick)
  end
  actionButton:SetScript("OnDragStart", StartMovingButton)
  actionButton:SetScript("OnDragStop", StopMovingButton)
  SkinButton(actionButton)

  return actionButton
end

ApplySummonButtonAttributes = function()
  if not button then
    return
  end

  if InCombatLockdown and InCombatLockdown() then
    AppendDebugLog("summon", "deferred secure button update in combat")
    return
  end

  AutoCallboardRuntime.ApplySecureMacroButtonAttributes(button, AutoCallboardRuntime.GetSummonMacroText(), "callboard")

  if startRollButton then
    AutoCallboardRuntime.ConfigureStartButton(startRollButton)
  end

  if controlFrame and controlFrame.startButton then
    AutoCallboardRuntime.ConfigureStartButton(controlFrame.startButton)
  end

  UpdateRollToggleButtonState(startRollButton, IsQuestRollStartAvailable())
  UpdateRollToggleButtonState(controlFrame and controlFrame.startButton or nil, true)

  button:SetText(state.targetName)
end

local function CreateCallboardButton()
  controlFrame = CreateFrame("Frame", "AutoCallboardFrame", UIParent)
  controlFrame:SetWidth(AutoCallboardRuntime.controlCollapsedWidth)
  controlFrame:SetHeight(AutoCallboardRuntime.controlCollapsedHeight)
  controlFrame:SetFrameStrata("MEDIUM")
  controlFrame:SetMovable(true)
  controlFrame:EnableMouse(true)
  controlFrame:RegisterForDrag("LeftButton")
  controlFrame:SetClampedToScreen(true)
  SkinFrame(controlFrame)
  controlFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
    end)
  controlFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveButtonPosition()
    end)
  controlFrame:SetScript("OnHide", function()
    if questWindow and questWindow:IsShown() then
      questWindow:Hide()
    end

    if debugWindow and debugWindow:IsShown() then
      debugWindow:Hide()
    end

    if helpWindow and helpWindow:IsShown() then
      helpWindow:Hide()
    end
    end)

  controlFrame.closeButton = CreateFrame("Button", nil, controlFrame)
  controlFrame.closeButton:SetPoint("TOPRIGHT", controlFrame, "TOPRIGHT", -4, -4)
  SkinCloseButton(controlFrame.closeButton)
  controlFrame.closeButton:SetScript("OnClick", function()
    if questWindow and questWindow:IsShown() then
      AutoCallboardRuntime.SetQuestPanelExpanded(false)
    else
      controlFrame:Hide()
    end
    end)

  controlFrame.helpButton = CreateFrame("Button", nil, controlFrame)
  controlFrame.helpButton:SetPoint("RIGHT", controlFrame.closeButton, "LEFT", -4, 0)
  SkinHelpButton(controlFrame.helpButton)
  controlFrame.helpButton:SetScript("OnClick", function()
    ShowAddonHelp("main")
    end)

  local title = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  title:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 10, -8)
  title:SetText(ADDON_TITLE)
  SkinTitleText(title)
  controlFrame.title = title

  button = CreateFrame("Button", "AutoCallboardButton", controlFrame, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  button:SetWidth(88)
  button:SetHeight(24)
  button:SetText(state.targetName)
  button:SetPoint("TOPLEFT", controlFrame, "TOPLEFT", 10, -30)
  button:RegisterForClicks("AnyUp")
  button:RegisterForDrag("LeftButton")
  SkinButton(button)
  ApplySummonButtonAttributes()
  button:SetScript("PreClick", function()
    preClickTargetedBoardName = nil
    preClickCooldownRemaining = GetSummonCooldownRemaining()
    preClickWasActive = IsCallboardActive()
    preClickWasUsable = IsSummonSpellUsable()

    if not preClickWasActive then
      local targeted, targetName = TargetCallboard()
      if targeted then
        preClickTargetedBoardName = targetName
        AutoCallboardRuntime.ApplySecureMacroButtonAttributes(button, "", "callboard nearby board")
      else
        ApplySummonButtonAttributes()
      end
    end
    end)
  button:SetScript("PostClick", function()
    if preClickTargetedBoardName then
      AppendDebugLog("summon", "button using nearby board " .. tostring(preClickTargetedBoardName))
      QueueCallboardFollowup("button nearby board")
    elseif preClickWasActive then
      ResumeRollingAfterCallboardActive("secure button active")
      QueueCallboardFollowup("secure button active")
      Print("Callboard is already active for " .. FormatSeconds(SecondsRemaining(callboardActiveUntil)) .. ".")
    elseif preClickCooldownRemaining and preClickCooldownRemaining > 0 then
      Print("Summon Callboard is on cooldown for " .. FormatSeconds(preClickCooldownRemaining) .. ".")
      AppendDebugLog("summon", "blocked secure click cooldown=" .. tostring(preClickCooldownRemaining))
    elseif not preClickWasUsable then
      if TargetCallboard() then
        AppendDebugLog("summon", "button using nearby board fallback")
        QueueCallboardFollowup("button nearby board")
      else
        Print("Summon Callboard is not usable here.")
        AppendDebugLog("summon", "blocked secure click unusable")
      end
    else
      AutoCallboardRuntime.BeginSummonAttempt("secure button")
      Print("Summoning \"" .. state.targetName .. "\"...")
    end

    preClickTargetedBoardName = nil
    ApplySummonButtonAttributes()
    UpdateSummonStatus()
    end)
  button:SetScript("OnDragStart", StartMovingButton)
  button:SetScript("OnDragStop", StopMovingButton)
  button:SetScript("OnEnter", function(self)
    SetButtonVisual(self, "hover")
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("AutoCallboard")
    GameTooltip:AddLine("Click to cast Summon Callboard.", 1, 1, 1)
    GameTooltip:AddLine("Shift-drag any button, or drag the frame edge, to move.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
    end)
  button:SetScript("OnLeave", function(self)
    SetButtonVisual(self)
    GameTooltip:Hide()
    end)

  PositionButton()

  local mainStartButton = MakeActionButton("AutoCallboardStartButton", "Start", 72, 24, "LEFT", button, "RIGHT", 5, 0, nil, "SecureActionButtonTemplate,UIPanelButtonTemplate")
  controlFrame.startButton = mainStartButton
  AutoCallboardRuntime.ConfigureStartButton(mainStartButton)
  UpdateRollToggleButtonState(mainStartButton, true)
  controlFrame.shareButton = MakeActionButton(
      "AutoCallboardShareButton",
      "Share",
      54,
      24,
      "LEFT",
      mainStartButton,
      "RIGHT",
      4,
      0,
      function()
        AutoCallboardRuntime.ShareAcceptedQuest("main button")
      end
    )
  controlFrame.shareButton:SetScript("OnEnter", function(self)
    SetButtonVisual(self, "hover")
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Share")
    GameTooltip:AddLine("Shares the last accepted quest.", 1, 1, 1)
    GameTooltip:Show()
    end)
  controlFrame.shareButton:SetScript("OnLeave", function(self)
    SetButtonVisual(self)
    GameTooltip:Hide()
    end)
  controlFrame.questButton = MakeActionButton(
      "AutoCallboardQuestsButton",
      "Quests",
      50,
      24,
      "LEFT",
      controlFrame.shareButton,
      "RIGHT",
      4,
      0,
      AutoCallboardRuntime.ToggleQuestPanel
    )
  AutoCallboardRuntime.UpdateShareButtonState()

  summonStatusText = controlFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  summonStatusText:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -5)
  summonStatusText:SetWidth(256)
  summonStatusText:SetJustifyH("LEFT")
  SkinMutedText(summonStatusText)
  AutoCallboardRuntime.PositionControlHeader(false)
  UpdateSummonStatus()

  if state.buttonShown then
    controlFrame:Show()
  else
    controlFrame:Hide()
  end
end

frame:SetScript("OnUpdate", function()
  if pendingInteractAt and GetTime() >= pendingInteractAt then
    TryInteract()
  end

  AutoCallboardRuntime.ProcessPendingAcceptedQuestShare("poll")
  UpdateSummonStatus()
  if SyncCallboardActiveFromCooldown then
    SyncCallboardActiveFromCooldown("cooldown inference")
  end
  AutoCallboardRuntime.CheckPendingSummonAttempt()
  AutoCallboardRuntime.SyncPendingSummonCooldown()
  AutoCallboardRuntime.UpdateQuestPanelAnimation()
  WatchCurrentObjectives()
  ProcessRolling()
  RefreshQuestWindowIfNeeded()

  if state and state.debug and state.debug.enabled then
    local now = GetTime()

    if not nextDebugProbeAt or now >= nextDebugProbeAt then
      nextDebugProbeAt = now + DEBUG_PROBE_INTERVAL
      RefreshDebugHooks()

      if state.debug.mouseWatch then
        local focus = GetMouseFocus and GetMouseFocus() or nil

        if focus ~= lastMouseFocus then
          lastMouseFocus = focus
          AppendDebugLog("mouse-focus", FrameSummary(focus))
        end
      end
    end
  end
  end)

frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
  if event ~= "ADDON_LOADED" and state and state.debug and state.debug.enabled then
    AppendDebugLog("event", event)
  end

  if event ~= "ADDON_LOADED" and AutoCallboardRuntime.IsInteractionSnifferEnabled() then
    AutoCallboardRuntime.AppendInteractionSniffSnapshot("event", event, arg1, arg2, arg3, arg4, arg5)
  end

  if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
    ApplyState(AutoCallboardDB)
    ApplyCharacterProfile()
    EnsureDebugLog()
    if AutoCallboardRuntime.IsInteractionSnifferEnabled() then
      AutoCallboardRuntime.InstallInteractionSnifferHooks()
      AppendDebugLog("sniff", "interaction sniffer restored after load")
    end
    AutoCallboardRuntime.InstallSharedQuestAutoAcceptHook()
    CreateCallboardButton()
    CreateMinimapButton()

    SLASH_AUTOCALLBOARD1 = "/acb"
    SLASH_AUTOCALLBOARD2 = "/autocallboard"
    SlashCmdList.AUTOCALLBOARD = HandleSlash

    Print("Loaded. Use /acb help.")
    AppendDebugLog("load", "AutoCallboard loaded")
  elseif event == "GOSSIP_SHOW" then
    local npcName = GossipFrameNpcNameText and GossipFrameNpcNameText:GetText()
    local npcBoard = AutoCallboardRuntime.GetNpcBoardInfo and AutoCallboardRuntime.GetNpcBoardInfo() or nil
    if AutoCallboardRuntime.IsObjectiveBoardGossipName(npcName) or npcBoard then
      AutoCallboardRuntime.MarkObjectiveBoardOpened(event .. ":" .. tostring(npcName) .. ":" .. tostring(npcBoard and npcBoard.objectId or "no-id"))
    end
  elseif event == "GOSSIP_CLOSED" then
    AutoCallboardRuntime.MarkObjectiveBoardClosed(event)
  elseif event == "QUEST_DETAIL" then
    if state and state.autoAccept and pendingAcceptUntil and GetTime() <= pendingAcceptUntil then
      pendingAcceptUntil = nil

      if AcceptQuest then
        AcceptQuest()
      elseif QuestFrameAcceptButton then
        QuestFrameAcceptButton:Click()
      end
    else
      AutoCallboardRuntime.TryAutoAcceptSharedQuest(event)
    end
  elseif event == "QUEST_ACCEPT_CONFIRM" then
    AutoCallboardRuntime.ConfirmSharedQuestAccept(event)
  elseif event == "QUEST_TURNED_IN" then
    local questID = tonumber(arg1) or 0

    if selectedQuest and questID > 0 and tonumber(selectedQuest.questId) == questID then
      ResumeAfterSelectedQuest(event)
    else
      nextSelectedQuestCheckAt = nil
      CheckSelectedQuestProgress(event)
    end
  elseif event == "QUEST_ACCEPTED" then
    AutoCallboardRuntime.TrackAcceptedQuest(arg1, arg2)
    nextSelectedQuestCheckAt = nil
    CheckSelectedQuestProgress(event)
  elseif event == "QUEST_LOG_UPDATE" or event == "QUEST_FINISHED" then
    if event == "QUEST_LOG_UPDATE" then
      AutoCallboardRuntime.ProcessPendingAcceptedQuestShare(event)
    end
    nextSelectedQuestCheckAt = nil
    CheckSelectedQuestProgress(event)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unit = arg1
    local spellName = arg2
    local spellID = tonumber(arg5) or tonumber(arg4) or tonumber(arg3)

    if unit == "player" and ((state.summonSpell ~= "" and spellName == state.summonSpell) or (state.summonSpellID and spellID == state.summonSpellID)) then
      MarkCallboardSummoned("spellcast event")
      QueueCallboardFollowup("spellcast event")
    end
  elseif event == "SPELL_UPDATE_COOLDOWN" then
    if AutoCallboardRuntime.StartCallboardTimersFromCooldown("SPELL_UPDATE_COOLDOWN") then
      UpdateSummonStatus()
    end
  end
  end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("QUEST_DETAIL")
frame:RegisterEvent("QUEST_ACCEPT_CONFIRM")
frame:RegisterEvent("QUEST_ACCEPTED")
frame:RegisterEvent("QUEST_LOG_UPDATE")
frame:RegisterEvent("QUEST_GREETING")
frame:RegisterEvent("QUEST_PROGRESS")
frame:RegisterEvent("QUEST_COMPLETE")
frame:RegisterEvent("QUEST_FINISHED")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
pcall(frame.RegisterEvent, frame, "QUEST_TURNED_IN")
pcall(frame.RegisterEvent, frame, "UNIT_SPELLCAST_SUCCEEDED")
pcall(frame.RegisterEvent, frame, "SPELL_UPDATE_COOLDOWN")
pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
pcall(frame.RegisterEvent, frame, "PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
