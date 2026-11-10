local _, Journal = ...

-- Pure Forever rules. No WoW calls in this file so lua5.4 can load it outside the client.
-- Evidence and remaining unknowns live in docs/FOREVER.md.

local Forever = {}

local HEARTH_SPELL_IDS = {
  [8690] = true, -- Hearthstone
  [556] = true, -- Astral Recall
}

function Forever.displayName(given, surname, realm)
  if type(given) ~= "string" or given == "" then
    return nil
  end
  if type(surname) == "string" and surname ~= "" and surname ~= realm then
    return given .. " " .. surname
  end
  return given
end

function Forever.characterKey(given, surname, realm)
  local name = Forever.displayName(given, surname, realm)
  if name and type(realm) == "string" and realm ~= "" then
    return name .. "-" .. realm
  end
  if name then
    return name
  end
  return "Unknown"
end

function Forever.normalizePersonName(name)
  if type(name) ~= "string" then
    return nil
  end
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  name = name:gsub("{rt%d}", "")
  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return nil
  end
  return name
end

-- Forever QUEST_ACCEPTED is the mainline payload: the quest id.
-- A classic (questLogIndex, questID) pair is not supported in this port.
function Forever.questAcceptId(questID)
  if type(questID) ~= "number" then
    return nil
  end
  return questID
end

-- C_Spell.GetSpellInfo returns one table. A bare string is only accepted from a test double.
function Forever.spellInfoName(info)
  if type(info) == "table" then
    if type(info.name) == "string" and info.name ~= "" then
      return info.name
    end
    return nil
  end
  if type(info) == "string" and info ~= "" then
    return info
  end
  return nil
end

function Forever.isHearthSpellId(spellId)
  return HEARTH_SPELL_IDS[spellId] == true
end

function Forever.killNameFromXpMessage(msg)
  if type(msg) ~= "string" then
    return nil
  end
  local name = msg:match("^(.-) dies, you gain %d+ experience")
  if name and name ~= "" then
    return name
  end
  return nil
end

-- Two sources (combat log and the XP chat line) can describe one kill.
-- Count both when they are the same source. Skip the second source inside the window.
function Forever.shouldCountKill(previous, source, at, window)
  if type(previous) == "table" and previous.source ~= source then
    if type(previous.at) == "number" and type(at) == "number" and type(window) == "number" then
      if (at - previous.at) < window then
        return false
      end
    end
  end
  return true
end

-- Registering these events fires ADDON_ACTION_FORBIDDEN on Forever / Midnight.
-- pcall does not swallow that notice. Do not call RegisterEvent for them.
Forever.forbiddenRegistration = {
  COMBAT_LOG_EVENT = true,
  COMBAT_LOG_EVENT_UNFILTERED = true,
}

Forever.loadEventNames = {
  "PLAYER_LOGIN",
  "PLAYER_LOGOUT",
  "QUEST_ACCEPTED",
  "QUEST_TURNED_IN",
  "CHAT_MSG_SYSTEM",
  "PLAYER_XP_UPDATE",
  "CHAT_MSG_LOOT",
  "CHAT_MSG_MONEY",
  "PLAYER_CONTROL_LOST",
  "PLAYER_CONTROL_GAINED",
  "PLAYER_EQUIPMENT_CHANGED",
  "PLAYER_ENTERING_WORLD",
  "ZONE_CHANGED_NEW_AREA",
  "ZONE_CHANGED",
  "PLAYER_DEAD",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_LEVEL_UP",
  "UNIT_SPELLCAST_SUCCEEDED",
  "SCREENSHOT_SUCCEEDED",
  "CHAT_MSG_COMBAT_FACTION_CHANGE",
  "CHAT_MSG_SKILL",
  "CHAT_MSG_COMBAT_XP_GAIN",
  "PARTY_INVITE_REQUEST",
  "GROUP_ROSTER_UPDATE",
}

function Forever.registrationDecision(eventName)
  if Forever.forbiddenRegistration[eventName] then
    return "skip-forbidden"
  end
  return "register"
end

-- registerFn is called only for events the client still allows.
-- A forbidden name is recorded and never passed to registerFn.
function Forever.applyRegistrations(eventNames, registerFn)
  local results = {}
  for _, eventName in ipairs(eventNames) do
    if Forever.registrationDecision(eventName) == "skip-forbidden" then
      results[eventName] = "skipped-forbidden"
    else
      local ok, err = pcall(registerFn, eventName)
      if ok then
        results[eventName] = "registered"
      else
        results[eventName] = tostring(err)
      end
    end
  end
  return results
end

-- Schema stays v3. A different schemaVersion must not wipe sessions.
function Forever.databaseAction(db, currentSchema)
  if type(db) ~= "table" then
    return "create"
  end
  if db.schemaVersion ~= currentSchema then
    return "keep-mismatch"
  end
  return "keep"
end

-- Minimap button position is one number on JournalDB.settings.
-- It is not a session field and it does not change the schema.
Forever.MINIMAP_ANGLE_KEY = "minimapAngle"
Forever.DEFAULT_MINIMAP_ANGLE = 225
Forever.MINIMAP_DRAG_THRESHOLD = 8
Forever.MINIMAP_PADDING = 5

-- Single-argument math.atan, so the same function runs in WoW and in Lua 5.4.
function Forever.atan2(y, x)
  if x > 0 then
    return math.atan(y / x)
  end
  if x < 0 then
    if y < 0 then
      return math.atan(y / x) - math.pi
    end
    return math.atan(y / x) + math.pi
  end
  if y > 0 then
    return math.pi / 2
  end
  if y < 0 then
    return -math.pi / 2
  end
  return 0
end

function Forever.normalizeDegrees(degrees)
  return degrees % 360
end

-- Point on the minimap frame's edge, then padding further out along the same ray.
-- A circle would tuck the button into the corner of a square minimap.
function Forever.minimapOffset(angleDegrees, halfWidth, halfHeight, padding)
  local radians = math.rad(angleDegrees)
  local dx = math.cos(radians)
  local dy = math.sin(radians)
  local reach = math.huge
  if dx ~= 0 then
    reach = math.min(reach, halfWidth / math.abs(dx))
  end
  if dy ~= 0 then
    reach = math.min(reach, halfHeight / math.abs(dy))
  end
  local x = dx * reach
  local y = dy * reach
  local length = math.sqrt(x * x + y * y)
  return x + (x / length) * padding, y + (y / length) * padding
end

function Forever.minimapAngleDegrees(dx, dy)
  return Forever.normalizeDegrees(math.deg(Forever.atan2(dy, dx)))
end

function Forever.savedMinimapAngle(settings)
  local angle = settings[Forever.MINIMAP_ANGLE_KEY]
  if angle == nil then
    return Forever.DEFAULT_MINIMAP_ANGLE
  end
  return Forever.normalizeDegrees(angle)
end

function Forever.storeMinimapAngle(db, angle)
  db.settings[Forever.MINIMAP_ANGLE_KEY] = Forever.normalizeDegrees(angle)
end

-- A left click that did not move past the drag threshold toggles the journal.
-- Any other button, and a left button that dragged, does not.
function Forever.minimapShouldToggle(button, dx, dy)
  if button ~= "LeftButton" then
    return false
  end
  if math.abs(dx) + math.abs(dy) > Forever.MINIMAP_DRAG_THRESHOLD then
    return false
  end
  return true
end

-- "toggle" opens the journal, "menu" opens the command menu, "none" does neither.
function Forever.minimapClickAction(button, dx, dy)
  if Forever.minimapShouldToggle(button, dx, dy) then
    return "toggle"
  end
  if button == "RightButton" then
    return "menu"
  end
  return "none"
end

function Forever.minimapTooltip()
  return "JournalingAddon", "Left-click to toggle the journal", "Right-click for commands"
end

-- LibDBIcon-1.0 minor 56 (the Questie copy). Mainline uses a 31 frame, a 50
-- MiniMap-TrackingBorder at TOPLEFT, and an 18 icon at CENTER. The classic
-- branch uses a 20 UI-Minimap-Background. The zoom highlight is drawn ADD.
-- Pressed icons move 1px down-right. The 0.05 crop is that library's rest inset.
Forever.MINIMAP_BUTTON_SIZE = 31
Forever.MINIMAP_BORDER_SIZE = 50
Forever.MINIMAP_BACKGROUND_SIZE = 20
Forever.MINIMAP_ICON_SIZE = 18
Forever.MINIMAP_ICON_NUDGE = 1
Forever.MINIMAP_ICON_CROP = 0.05
Forever.MINIMAP_HIGHLIGHT = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight"
Forever.MINIMAP_BORDER = "Interface\\Minimap\\MiniMap-TrackingBorder"
Forever.MINIMAP_BACKGROUND = "Interface\\Minimap\\UI-Minimap-Background"
Forever.MINIMAP_ICON = "Interface\\Icons\\INV_Misc_Book_09"
Forever.MINIMAP_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

function Forever.setRegionTexture(region, path)
  local ok, found = pcall(region.SetTexture, region, path)
  if not ok or found == false then
    pcall(region.Hide, region)
    return false
  end
  return true
end

-- TempPortraitAlphaMask needs clamp-to-black or the circle edge repeats.
-- A client that rejects the wrap arguments gets the plain path instead.
function Forever.setMaskTexture(region, path)
  local ok, found = pcall(region.SetTexture, region, path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  if ok and found ~= false then
    return true
  end
  return Forever.setRegionTexture(region, path)
end

function Forever.applyMinimapHighlight(button)
  local ok = pcall(button.SetHighlightTexture, button, Forever.MINIMAP_HIGHLIGHT, "ADD")
  if not ok then
    ok = pcall(button.SetHighlightTexture, button, Forever.MINIMAP_HIGHLIGHT)
  end
  if not ok then
    return "skipped"
  end
  local got, highlight = pcall(button.GetHighlightTexture, button)
  if got and highlight then
    pcall(highlight.SetBlendMode, highlight, "ADD")
  end
  return "set"
end

function Forever.placeMinimapIcon(icon, pressed)
  local x, y = 0, 0
  if pressed then
    x = Forever.MINIMAP_ICON_NUDGE
    y = -Forever.MINIMAP_ICON_NUDGE
  end
  icon:ClearAllPoints()
  icon:SetPoint("CENTER", x, y)
end

-- Mask when both calls succeed. A missing mask API or mask texture uses the crop.
function Forever.applyMinimapIconShape(button, icon)
  local created, mask = pcall(button.CreateMaskTexture, button)
  if created and mask and Forever.setMaskTexture(mask, Forever.MINIMAP_MASK) then
    pcall(mask.SetAllPoints, mask, icon)
    local added = pcall(icon.AddMaskTexture, icon, mask)
    if added then
      icon.mask = mask
      return "mask"
    end
  end
  local crop = Forever.MINIMAP_ICON_CROP
  pcall(icon.SetTexCoord, icon, crop, 1 - crop, crop, 1 - crop)
  return "crop"
end

function Forever.applyMinimapButtonChrome(button)
  button:SetSize(Forever.MINIMAP_BUTTON_SIZE, Forever.MINIMAP_BUTTON_SIZE)
  Forever.applyMinimapHighlight(button)

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(Forever.MINIMAP_BORDER_SIZE, Forever.MINIMAP_BORDER_SIZE)
  border:SetPoint("TOPLEFT", 0, 0)
  Forever.setRegionTexture(border, Forever.MINIMAP_BORDER)
  button.border = border

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(Forever.MINIMAP_BACKGROUND_SIZE, Forever.MINIMAP_BACKGROUND_SIZE)
  background:SetPoint("CENTER", 0, 0)
  Forever.setRegionTexture(background, Forever.MINIMAP_BACKGROUND)
  button.background = background

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(Forever.MINIMAP_ICON_SIZE, Forever.MINIMAP_ICON_SIZE)
  Forever.setRegionTexture(icon, Forever.MINIMAP_ICON)
  Forever.placeMinimapIcon(icon, false)
  button.icon = icon
  Forever.applyMinimapIconShape(button, icon)
  return button
end

-- Slash tokens and the minimap menu share this list.
-- menu = false for commands that delete an entry, clear a session, or wipe the database.
-- The bare /journal command is the empty token.
Forever.JOURNAL_COMMANDS = {
  { token = "note", label = "Add note…", menu = true, method = "ShowNoteCaptureDialog" },
  { token = "", label = "Open/close journal", menu = true, method = "ToggleUI" },
  { token = "compat", label = "Compat check", menu = true, method = "ReportCompat" },
  { token = "help", label = "Help", menu = true, method = "ShowJournalHelp" },
  { token = "capture", label = "Capture…", menu = true, method = "ShowTargetCaptureDialog" },
  { token = "reset", label = "New session", menu = true, method = "ResetJournalSession" },
  { token = "debug", label = "Toggle debug", menu = true, method = "ToggleJournalDebug" },
  { token = "undo", label = "Undo last entry", menu = false, method = "UndoJournalEntry" },
  { token = "clear", label = "Clear session", menu = false, method = "ClearJournalSession" },
  { token = "wipe", label = "Wipe journal", menu = false, method = "WipeJournalData" },
}

local JOURNAL_ALIASES = {
  ["capture-target"] = "capture",
}

function Forever.commandByToken(token)
  local aliased = JOURNAL_ALIASES[token]
  if aliased then
    token = aliased
  end
  for _, command in ipairs(Forever.JOURNAL_COMMANDS) do
    if command.token == token then
      return command
    end
  end
  return nil
end

-- Unknown text does what a bare /journal does.
function Forever.dispatchMethod(token)
  local command = Forever.commandByToken(token)
  if command then
    return command.method
  end
  return Forever.commandByToken("").method
end

function Forever.menuItems()
  local items = {}
  for _, command in ipairs(Forever.JOURNAL_COMMANDS) do
    if command.menu then
      items[#items + 1] = command
    end
  end
  return items
end

-- Escape is the key name UISpecialFrames already handles.
-- "outside" is a click that missed both the menu and the minimap button.
function Forever.minimapMenuDismiss(signal)
  return signal == "ESCAPE" or signal == "outside"
end

-- Blank and whitespace-only notes are not entries.
-- Text that contains a visible character is stored unchanged.
function Forever.noteTextToSave(text)
  if type(text) ~= "string" then
    return nil
  end
  if text:find("%S") == nil then
    return nil
  end
  return text
end

function Forever.noteEntryData(text)
  local save = Forever.noteTextToSave(text)
  if not save then
    return nil
  end
  return {
    type = "note",
    data = { text = save },
    msg = "Note: " .. save,
  }
end

if type(Journal) == "table" then
  Journal.Forever = Forever
end

return Forever
