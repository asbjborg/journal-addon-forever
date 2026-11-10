local Forever = dofile("JournalingAddon/core/Forever.lua")

local failures = 0

local function expect(label, actual, expected)
  if actual ~= expected then
    failures = failures + 1
    io.stderr:write(label .. "\n  expected: " .. tostring(expected) .. "\n  actual:   " .. tostring(actual) .. "\n")
  end
end

expect("given name only", Forever.displayName("Mira", nil, "Example Realm"), "Mira")
expect("surname kept", Forever.displayName("Mira", "Ashford", "Example Realm"), "Mira Ashford")
expect("surname equal to realm is not a surname", Forever.displayName("Mira", "Example Realm", "Example Realm"), "Mira")
expect("hyphen stays in the given name", Forever.displayName("Anne-Marie", nil, "Example Realm"), "Anne-Marie")
expect("hyphen plus surname", Forever.displayName("Anne-Marie", "Ashford", "Example Realm"), "Anne-Marie Ashford")

expect(
  "character key keeps hyphen and realm",
  Forever.characterKey("Anne-Marie", "Ashford", "Example Realm"),
  "Anne-Marie Ashford-Example Realm"
)
expect("missing name", Forever.characterKey(nil, nil, nil), "Unknown")

expect("normalize keeps hyphen", Forever.normalizePersonName("  Anne-Marie  "), "Anne-Marie")
expect("normalize strips color and raid icon", Forever.normalizePersonName("|cffff0000{rt1}Mira Ashford|r"), "Mira Ashford")

expect("quest id", Forever.questAcceptId(1001), 1001)
expect("quest id rejects a title", Forever.questAcceptId("North Mill"), nil)

expect("spell table", Forever.spellInfoName({ name = "Hearthstone", iconID = 1 }), "Hearthstone")
expect("spell string", Forever.spellInfoName("Hearthstone"), "Hearthstone")
expect("spell empty table", Forever.spellInfoName({}), nil)
expect("hearth 8690", Forever.isHearthSpellId(8690), true)
expect("hearth 556", Forever.isHearthSpellId(556), true)
expect("not hearth", Forever.isHearthSpellId(133), false)

expect(
  "kill name",
  Forever.killNameFromXpMessage("Road Wolf dies, you gain 40 experience."),
  "Road Wolf"
)
expect("xp without a death is not a kill", Forever.killNameFromXpMessage("You gain 40 experience."), nil)

expect("same source counts twice", Forever.shouldCountKill({ source = "chat", at = 10 }, "chat", 10.2, 1.5), true)
expect("other source inside window does not", Forever.shouldCountKill({ source = "combatlog", at = 10 }, "chat", 10.4, 1.5), false)
expect("other source after window does", Forever.shouldCountKill({ source = "combatlog", at = 10 }, "chat", 12, 1.5), true)

local kept = {
  schemaVersion = 3,
  sessions = {
    { characterKey = "Mira-Example Realm", entries = { { msg = "Note: hello" } } },
  },
}
expect("matching schema keeps", Forever.databaseAction(kept, 3), "keep")
expect("mismatched schema still keeps", Forever.databaseAction({ schemaVersion = 2, sessions = { { entries = {} } } }, 3), "keep-mismatch")
expect("nil database creates", Forever.databaseAction(nil, 3), "create")

expect("cleu is forbidden", Forever.registrationDecision("COMBAT_LOG_EVENT_UNFILTERED"), "skip-forbidden")
expect("filtered combat log is forbidden", Forever.registrationDecision("COMBAT_LOG_EVENT"), "skip-forbidden")
expect("login stays registered", Forever.registrationDecision("PLAYER_LOGIN"), "register")
expect("xp chat stays registered", Forever.registrationDecision("CHAT_MSG_COMBAT_XP_GAIN"), "register")

local function countNotices(notices)
  local n = 0
  for _ in pairs(notices) do
    n = n + 1
  end
  return n
end

-- The client records ADDON_ACTION_FORBIDDEN when the protected registration
-- is attempted. pcall catches the Lua error and still leaves the notice.
local function clientRegister(eventName, notices)
  if Forever.forbiddenRegistration[eventName] then
    notices[#notices + 1] = "ADDON_ACTION_FORBIDDEN UNKNOWN()"
    error("protected")
  end
  return true
end

local directNotices = {}
local directOk = pcall(clientRegister, "COMBAT_LOG_EVENT_UNFILTERED", directNotices)
expect("pcall catches the lua error", directOk, false)
expect("pcall still records the forbidden notice", countNotices(directNotices), 1)
expect("notice names the protected call", directNotices[1], "ADDON_ACTION_FORBIDDEN UNKNOWN()")

local loadNotices = {}
local loadResults = Forever.applyRegistrations(Forever.loadEventNames, function(eventName)
  return clientRegister(eventName, loadNotices)
end)
expect("production load emits no forbidden notice", countNotices(loadNotices), 0)
expect("production list has no cleu result", loadResults["COMBAT_LOG_EVENT_UNFILTERED"], nil)
expect("production list registers xp chat", loadResults["CHAT_MSG_COMBAT_XP_GAIN"], "registered")
expect("production list registers roster", loadResults["GROUP_ROSTER_UPDATE"], "registered")

local mixedNotices = {}
local mixedResults = Forever.applyRegistrations({
  "PLAYER_LOGIN",
  "COMBAT_LOG_EVENT_UNFILTERED",
  "CHAT_MSG_LOOT",
}, function(eventName)
  return clientRegister(eventName, mixedNotices)
end)
expect("a listed cleu is not called", countNotices(mixedNotices), 0)
expect("a listed cleu is skipped", mixedResults["COMBAT_LOG_EVENT_UNFILTERED"], "skipped-forbidden")
expect("neighbors of cleu still register", mixedResults["PLAYER_LOGIN"], "registered")
expect("loot still registers", mixedResults["CHAT_MSG_LOOT"], "registered")

local function near(label, actual, expected)
  local delta = math.abs(actual - expected)
  if delta > 0.001 and math.abs(delta - 360) > 0.001 then
    failures = failures + 1
    io.stderr:write(label .. "\n  expected: " .. tostring(expected) .. "\n  actual:   " .. tostring(actual) .. "\n")
  end
end

expect("unset minimap angle is the default", Forever.savedMinimapAngle({}), Forever.DEFAULT_MINIMAP_ANGLE)
local untouchedSettings = { afkNoteMinutes = 10, loginNoteMinutes = 30 }
expect("reading the angle does not write the key", Forever.savedMinimapAngle(untouchedSettings), 225)
expect("settings stay without a minimap key", untouchedSettings.minimapAngle, nil)
expect("afk setting stays", untouchedSettings.afkNoteMinutes, 10)

local savedJournal = {
  schemaVersion = 3,
  lastLogoutAt = 100,
  sessions = {
    {
      characterKey = "Mira-Example Realm",
      entries = {
        { type = "death", msg = "Died.", seq = 1 },
        { type = "note", msg = "Note: hello", seq = 2 },
      },
    },
  },
  settings = { afkNoteMinutes = 10, loginNoteMinutes = 30 },
}
local sessionsBefore = savedJournal.sessions
local entriesBefore = savedJournal.sessions[1].entries
Forever.storeMinimapAngle(savedJournal, -135)
expect("angle is stored on settings", savedJournal.settings.minimapAngle, 225)
expect("schema stays 3", savedJournal.schemaVersion, 3)
expect("logout stamp stays", savedJournal.lastLogoutAt, 100)
expect("sessions table is the same object", savedJournal.sessions, sessionsBefore)
expect("entries table is the same object", savedJournal.sessions[1].entries, entriesBefore)
expect("first saved line stays", entriesBefore[1].msg, "Died.")
expect("second saved line stays", entriesBefore[2].msg, "Note: hello")
expect("entry count stays", #entriesBefore, 2)
expect("other settings stay", savedJournal.settings.loginNoteMinutes, 30)
expect("stored angle reads back", Forever.savedMinimapAngle(savedJournal.settings), 225)
expect("database action still keeps the journal", Forever.databaseAction(savedJournal, 3), "keep")

local eastX, eastY = Forever.minimapOffset(0, 70, 90, 5)
near("angle 0 points east", eastX, 75)
near("angle 0 has no northing", eastY, 0)
local northX, northY = Forever.minimapOffset(90, 70, 90, 5)
near("angle 90 has no easting", northX, 0)
near("angle 90 uses the taller side", northY, 95)
local cornerX, cornerY = Forever.minimapOffset(45, 70, 70, 5)
local cornerPad = 5 * math.sqrt(2) / 2
near("corner sits outside the square", cornerX, 70 + cornerPad)
near("corner stays on the diagonal", cornerY, cornerX)

local function roundTrip(degrees)
  local x, y = Forever.minimapOffset(degrees, 70, 70, 5)
  return Forever.minimapAngleDegrees(x, y)
end

near("round trip 0", roundTrip(0), 0)
near("round trip 90", roundTrip(90), 90)
near("round trip 180", roundTrip(180), 180)
near("round trip 225", roundTrip(225), 225)
near("round trip 270", roundTrip(270), 270)
near("round trip -45 wraps", roundTrip(-45), 315)

expect("left click toggles", Forever.minimapShouldToggle("LeftButton", 0, 0), true)
expect("left click inside the drag threshold toggles", Forever.minimapShouldToggle("LeftButton", 8, 0), true)
expect("a drag does not toggle", Forever.minimapShouldToggle("LeftButton", 9, 0), false)
expect("a diagonal drag does not toggle", Forever.minimapShouldToggle("LeftButton", 5, 5), false)
expect("right click does not toggle", Forever.minimapShouldToggle("RightButton", 0, 0), false)
expect("middle click does not toggle", Forever.minimapShouldToggle("MiddleButton", 0, 0), false)

local tipTitle, tipLeft, tipRight = Forever.minimapTooltip()
expect("tooltip names the addon", tipTitle, "JournalingAddon")
expect("tooltip names the left click", tipLeft, "Left-click to toggle the journal")
expect("tooltip names the right click", tipRight, "Right-click for commands")

expect("left click action toggles", Forever.minimapClickAction("LeftButton", 0, 0), "toggle")
expect("left click inside the drag threshold still toggles", Forever.minimapClickAction("LeftButton", 8, 0), "toggle")
expect("a drag is not a click action", Forever.minimapClickAction("LeftButton", 9, 0), "none")
expect("a diagonal drag is not a click action", Forever.minimapClickAction("LeftButton", 5, 5), "none")
expect("right click opens the menu", Forever.minimapClickAction("RightButton", 0, 0), "menu")
expect("right click does not toggle when it opens the menu", Forever.minimapClickAction("RightButton", 0, 0) == "toggle", false)
expect("middle click does nothing", Forever.minimapClickAction("MiddleButton", 0, 0), "none")

expect("escape closes the menu", Forever.minimapMenuDismiss("ESCAPE"), true)
expect("an outside click closes the menu", Forever.minimapMenuDismiss("outside"), true)
expect("enter does not close the menu", Forever.minimapMenuDismiss("ENTER"), false)
expect("a left button name is not the outside signal", Forever.minimapMenuDismiss("LeftButton"), false)

local menuLabels = {}
for _, item in ipairs(Forever.menuItems()) do
  menuLabels[#menuLabels + 1] = item.label
  expect("menu " .. item.label .. " uses the slash method", Forever.dispatchMethod(item.token), item.method)
end
expect("menu starts with add note", menuLabels[1], "Add note…")
expect("menu opens the journal", menuLabels[2], "Open/close journal")
expect("menu runs compat", menuLabels[3], "Compat check")
expect("menu shows help", menuLabels[4], "Help")
expect("menu captures", menuLabels[5], "Capture…")
expect("menu starts a session", menuLabels[6], "New session")
expect("menu toggles debug", menuLabels[7], "Toggle debug")
expect("menu length", #menuLabels, 7)

local function menuLists(token)
  for _, item in ipairs(Forever.menuItems()) do
    if item.token == token then
      return true
    end
  end
  return false
end

expect("menu lists note", menuLists("note"), true)
expect("menu lists the bare journal command", menuLists(""), true)
expect("menu lists compat", menuLists("compat"), true)
expect("menu lists help", menuLists("help"), true)
expect("menu lists capture", menuLists("capture"), true)
expect("menu lists reset", menuLists("reset"), true)
expect("menu lists debug", menuLists("debug"), true)
expect("menu omits wipe", menuLists("wipe"), false)
expect("menu omits clear", menuLists("clear"), false)
expect("menu omits undo", menuLists("undo"), false)

expect("wipe stays a slash command", Forever.commandByToken("wipe").method, "WipeJournalData")
expect("wipe is marked off the menu", Forever.commandByToken("wipe").menu, false)
expect("clear stays a slash command", Forever.dispatchMethod("clear"), "ClearJournalSession")
expect("undo stays a slash command", Forever.dispatchMethod("undo"), "UndoJournalEntry")
expect("capture alias uses the capture dialog", Forever.dispatchMethod("capture-target"), "ShowTargetCaptureDialog")
expect("bare slash toggles", Forever.dispatchMethod(""), "ToggleUI")
expect("unknown slash text still toggles", Forever.dispatchMethod("nope"), "ToggleUI")
expect("note slash opens the note dialog", Forever.dispatchMethod("note"), "ShowNoteCaptureDialog")

local menuJournal = {
  schemaVersion = 3,
  sessions = {
    {
      characterKey = "Mira-Example Realm",
      entries = {
        { type = "death", msg = "Died.", seq = 1 },
      },
    },
  },
  settings = { minimapAngle = 225, afkNoteMinutes = 10 },
}
local menuSessions = menuJournal.sessions
local menuEntries = menuJournal.sessions[1].entries
Forever.menuItems()
Forever.minimapClickAction("RightButton", 0, 0)
Forever.minimapMenuDismiss("ESCAPE")
expect("opening the menu keeps schema 3", menuJournal.schemaVersion, 3)
expect("opening the menu keeps the sessions table", menuJournal.sessions, menuSessions)
expect("opening the menu keeps the entries table", menuJournal.sessions[1].entries, menuEntries)
expect("opening the menu adds no entry", #menuEntries, 1)
expect("opening the menu keeps the death line", menuEntries[1].msg, "Died.")
expect("opening the menu keeps the angle", menuJournal.settings.minimapAngle, 225)

local function appendNote(db, text)
  local entry = Forever.noteEntryData(text)
  if not entry then
    return nil
  end
  local stored = {
    v = db.schemaVersion,
    type = entry.type,
    data = { text = entry.data.text },
    msg = entry.msg,
  }
  db.sessions[1].entries[#db.sessions[1].entries + 1] = stored
  return stored
end

expect("empty note saves nothing", appendNote(menuJournal, ""), nil)
expect("whitespace note saves nothing", appendNote(menuJournal, " \t\n "), nil)
expect("blank note leaves the death line alone", #menuEntries, 1)
expect("nil note saves nothing", Forever.noteEntryData(nil), nil)

local fromSlash = appendNote(menuJournal, "The north road is quiet.")
local fromDialog = Forever.noteEntryData("The north road is quiet.")
expect("dialog type matches /journal note", fromDialog.type, fromSlash.type)
expect("dialog text matches /journal note", fromDialog.data.text, fromSlash.data.text)
expect("dialog line matches /journal note", fromDialog.msg, fromSlash.msg)
expect("saved line is the note text", fromSlash.msg, "Note: The north road is quiet.")
expect("one note was added", #menuEntries, 2)
expect("death line stays first", menuEntries[1].msg, "Died.")
expect("schema stays 3 after the note", menuJournal.schemaVersion, 3)
expect("still one session after the note", #menuJournal.sessions, 1)
expect("sessions table stays the same object", menuJournal.sessions, menuSessions)
expect("angle stays after the note", menuJournal.settings.minimapAngle, 225)
expect("a padded note keeps its spaces", Forever.noteEntryData("  hello  ").data.text, "  hello  ")
expect("database action still keeps the menu journal", Forever.databaseAction(menuJournal, 3), "keep")

local function readFile(path)
  local handle = assert(io.open(path, "r"))
  local text = handle:read("*a")
  handle:close()
  return text
end

local ui = readFile("JournalingAddon/JournalUI.lua")
expect("slash command is still /journal", ui:find('SLASH_JOURNAL1 = "/journal"', 1, true) ~= nil, true)
expect("slash trims then dispatches", ui:find("Journal:DispatchJournalCommand(arg)", 1, true) ~= nil, true)
expect("dispatch calls the shared method", ui:find("self[method](self)", 1, true) ~= nil, true)
expect("help still lists note", ui:find("  /journal note - Add a note", 1, true) ~= nil, true)
expect("help still lists compat", ui:find("  /journal compat - Print Forever client checks", 1, true) ~= nil, true)
expect("help still lists wipe", ui:find("  /journal wipe - Wipe all journal data", 1, true) ~= nil, true)
expect("bare /journal still calls ToggleUI", ui:find("function Journal:ToggleUI()", 1, true) ~= nil, true)

local minimap = readFile("JournalingAddon/features/Minimap.lua")
expect("minimap click uses the shared action", minimap:find("minimapClickAction", 1, true) ~= nil, true)
expect("minimap click calls ToggleUI", minimap:find("Journal:ToggleUI()", 1, true) ~= nil, true)
expect("minimap right click is registered", minimap:find('RegisterForClicks("LeftButtonUp", "RightButtonUp")', 1, true) ~= nil, true)
expect("minimap menu uses the slash dispatch", minimap:find("Journal:DispatchJournalCommand(token)", 1, true) ~= nil, true)
expect("minimap menu does not open the note dialog itself", minimap:find("ShowNoteCaptureDialog", 1, true) == nil, true)
expect("minimap menu does not name wipe", minimap:find("wipe", 1, true) == nil, true)
expect("minimap menu does not name Wipe", minimap:find("Wipe", 1, true) == nil, true)
expect("escape is UISpecialFrames", minimap:find('table.insert(UISpecialFrames, "JournalMinimapMenu")', 1, true) ~= nil, true)
expect("outside click uses the dismiss decision", minimap:find('minimapMenuDismiss("outside")', 1, true) ~= nil, true)
expect("minimap does not register a combat log", minimap:find("COMBAT_LOG", 1, true) == nil, true)
expect("minimap does not register events itself", minimap:find("RegisterEvent", 1, true) == nil, true)
expect("minimap does not mention schema", minimap:find("schemaVersion", 1, true) == nil, true)
expect("square highlight is gone", minimap:find("ButtonHilight-Square", 1, true) == nil, true)
expect("minimap draws the round chrome", minimap:find("applyMinimapButtonChrome", 1, true) ~= nil, true)
expect("press nudges the icon", minimap:find("placeMinimapIcon(self.icon, true)", 1, true) ~= nil, true)
expect("release restores the icon", minimap:find('OnMouseUp", function(self)\n    Journal.Forever.placeMinimapIcon(self.icon, false)', 1, true) ~= nil, true)
local dragStopAt = minimap:find('button:SetScript("OnDragStop"', 1, true)
local dragStopChunk = minimap:sub(dragStopAt, dragStopAt + 280)
expect("drag stop restores the icon", dragStopChunk:find("placeMinimapIcon(self.icon, false)", 1, true) ~= nil, true)
expect("drag still stores the angle", dragStopChunk:find("storeMinimapAngle(JournalDB, self.angle)", 1, true) ~= nil, true)
expect("drag is still registered", minimap:find('RegisterForDrag("LeftButton")', 1, true) ~= nil, true)

local function fakeRegion(failPaths, options)
  local region = { anchor = {}, hidden = false }
  function region:SetSize(w, h)
    self.w = w
    self.h = h
  end
  function region:SetPoint(point, x, y)
    self.anchor = { point, x, y }
  end
  function region:ClearAllPoints()
    self.anchor = {}
  end
  function region:SetTexture(path, horizWrap, vertWrap)
    if horizWrap ~= nil and options.rejectWrap then
      error("wrap rejected")
    end
    local failure = failPaths[path]
    if failure == "error" then
      error("missing texture " .. path)
    end
    if failure == "false" then
      return false
    end
    self.path = path
    self.wrap = { horizWrap, vertWrap }
    return true
  end
  function region:Hide()
    self.hidden = true
  end
  function region:SetAllPoints(other)
    self.allPoints = other
  end
  function region:SetTexCoord(left, right, top, bottom)
    self.coord = { left, right, top, bottom }
  end
  function region:AddMaskTexture(mask)
    self.appliedMask = mask
  end
  function region:SetBlendMode(mode)
    self.blend = mode
  end
  return region
end

local function regionByLayer(button, layer)
  for _, region in ipairs(button.regions) do
    if region.layer == layer then
      return region
    end
  end
  return nil
end

local function fakeButton(options)
  local button = { regions = {} }
  function button:SetSize(w, h)
    self.w = w
    self.h = h
  end
  function button:SetHighlightTexture(path, blend)
    if options.rejectBlend and blend ~= nil then
      error("blend rejected")
    end
    if options.highlightError then
      error("missing highlight")
    end
    self.highlightPath = path
    self.highlightBlend = blend
    self.highlight = fakeRegion(options.failPaths, options)
    self.highlight.path = path
  end
  function button:GetHighlightTexture()
    return self.highlight
  end
  function button:CreateTexture(_, layer)
    local created = fakeRegion(options.failPaths, options)
    created.layer = layer
    self.regions[#self.regions + 1] = created
    return created
  end
  if options.maskApi then
    function button:CreateMaskTexture()
      return fakeRegion(options.failPaths, options)
    end
  end
  return button
end

local function applyChrome(options)
  local button = fakeButton(options)
  local ok, err = pcall(Forever.applyMinimapButtonChrome, button)
  return ok, err, button
end

expect("highlight path", Forever.MINIMAP_HIGHLIGHT, "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
expect("border path", Forever.MINIMAP_BORDER, "Interface\\Minimap\\MiniMap-TrackingBorder")
expect("background path", Forever.MINIMAP_BACKGROUND, "Interface\\Minimap\\UI-Minimap-Background")
expect("icon path", Forever.MINIMAP_ICON, "Interface\\Icons\\INV_Misc_Book_09")
expect("mask path", Forever.MINIMAP_MASK, "Interface\\CharacterFrame\\TempPortraitAlphaMask")

local maskOk, maskErr, masked = applyChrome({ maskApi = true, failPaths = {} })
expect("mask setup does not raise", maskOk, true)
if not maskOk then
  io.stderr:write(tostring(maskErr) .. "\n")
end
expect("frame is 31", masked.w, 31)
expect("frame height is 31", masked.h, 31)
expect("highlight is the zoom texture", masked.highlightPath, Forever.MINIMAP_HIGHLIGHT)
expect("highlight argument is ADD", masked.highlightBlend, "ADD")
expect("highlight blend is ADD", masked.highlight.blend, "ADD")
local border = regionByLayer(masked, "OVERLAY")
local background = regionByLayer(masked, "BACKGROUND")
local icon = regionByLayer(masked, "ARTWORK")
expect("border layer exists", border ~= nil, true)
expect("border is 50", border.w, 50)
expect("border height is 50", border.h, 50)
expect("border anchors TOPLEFT", border.anchor[1], "TOPLEFT")
expect("border x is 0", border.anchor[2], 0)
expect("border y is 0", border.anchor[3], 0)
expect("border texture", border.path, Forever.MINIMAP_BORDER)
expect("border stays shown", border.hidden, false)
expect("background is 20", background.w, 20)
expect("background height is 20", background.h, 20)
expect("background anchors CENTER", background.anchor[1], "CENTER")
expect("background texture", background.path, Forever.MINIMAP_BACKGROUND)
expect("icon is 18", icon.w, 18)
expect("icon height is 18", icon.h, 18)
expect("icon anchors CENTER", icon.anchor[1], "CENTER")
expect("icon rest x is 0", icon.anchor[2], 0)
expect("icon rest y is 0", icon.anchor[3], 0)
expect("icon texture", icon.path, Forever.MINIMAP_ICON)
expect("mask was applied", icon.appliedMask ~= nil, true)
expect("mask covers the icon", icon.appliedMask.allPoints, icon)
expect("mask texture", icon.appliedMask.path, Forever.MINIMAP_MASK)
expect("mask clamps horizontally", icon.appliedMask.wrap[1], "CLAMPTOBLACKADDITIVE")
expect("mask clamps vertically", icon.appliedMask.wrap[2], "CLAMPTOBLACKADDITIVE")
expect("mask path skips the crop", icon.coord, nil)

local plainMaskOk, plainMaskErr, plainMasked = applyChrome({
  maskApi = true,
  failPaths = {},
  rejectWrap = true,
})
expect("rejected mask wrap does not raise", plainMaskOk, true)
if not plainMaskOk then
  io.stderr:write(tostring(plainMaskErr) .. "\n")
end
local plainIcon = regionByLayer(plainMasked, "ARTWORK")
expect("plain mask path still masks", plainIcon.appliedMask ~= nil, true)
expect("plain mask texture", plainIcon.appliedMask.path, Forever.MINIMAP_MASK)
expect("plain mask has no wrap", plainIcon.appliedMask.wrap[1], nil)
expect("plain mask skips the crop", plainIcon.coord, nil)

Forever.placeMinimapIcon(icon, true)
expect("pressed point", icon.anchor[1], "CENTER")
expect("pressed nudge x", icon.anchor[2], 1)
expect("pressed nudge y", icon.anchor[3], -1)
Forever.placeMinimapIcon(icon, false)
expect("released x", icon.anchor[2], 0)
expect("released y", icon.anchor[3], 0)

local cropOk, cropErr, cropped = applyChrome({ maskApi = false, failPaths = {} })
expect("crop setup does not raise", cropOk, true)
if not cropOk then
  io.stderr:write(tostring(cropErr) .. "\n")
end
local croppedIcon = regionByLayer(cropped, "ARTWORK")
expect("missing mask api crops", croppedIcon.coord[1], Forever.MINIMAP_ICON_CROP)
expect("crop right edge", croppedIcon.coord[2], 1 - Forever.MINIMAP_ICON_CROP)
expect("crop top edge", croppedIcon.coord[3], Forever.MINIMAP_ICON_CROP)
expect("crop bottom edge", croppedIcon.coord[4], 1 - Forever.MINIMAP_ICON_CROP)
expect("crop path has no mask", croppedIcon.appliedMask, nil)
expect("crop frame is still 31", cropped.w, 31)
expect("crop border is still 50", regionByLayer(cropped, "OVERLAY").w, 50)

local brokenPaths = {
  [Forever.MINIMAP_BORDER] = "error",
  [Forever.MINIMAP_BACKGROUND] = "error",
  [Forever.MINIMAP_ICON] = "error",
  [Forever.MINIMAP_MASK] = "error",
}
local brokenOk, brokenErr, broken = applyChrome({
  maskApi = true,
  failPaths = brokenPaths,
  highlightError = true,
})
expect("missing textures do not raise", brokenOk, true)
if not brokenOk then
  io.stderr:write(tostring(brokenErr) .. "\n")
end
expect("missing highlight is skipped", broken.highlightPath, nil)
expect("missing border is hidden", regionByLayer(broken, "OVERLAY").hidden, true)
expect("missing background is hidden", regionByLayer(broken, "BACKGROUND").hidden, true)
expect("missing icon is hidden", regionByLayer(broken, "ARTWORK").hidden, true)
expect("missing mask texture falls back to crop", regionByLayer(broken, "ARTWORK").coord[1], Forever.MINIMAP_ICON_CROP)

local falsePaths = {
  [Forever.MINIMAP_BORDER] = "false",
  [Forever.MINIMAP_BACKGROUND] = "false",
  [Forever.MINIMAP_ICON] = "false",
  [Forever.MINIMAP_MASK] = "false",
}
local falseOk, falseErr, falseButton = applyChrome({ maskApi = true, failPaths = falsePaths })
expect("a false texture does not raise", falseOk, true)
if not falseOk then
  io.stderr:write(tostring(falseErr) .. "\n")
end
expect("a false border is hidden", regionByLayer(falseButton, "OVERLAY").hidden, true)
expect("a false background is hidden", regionByLayer(falseButton, "BACKGROUND").hidden, true)
expect("a false icon is hidden", regionByLayer(falseButton, "ARTWORK").hidden, true)
expect("a false mask texture falls back to crop", regionByLayer(falseButton, "ARTWORK").coord[1], Forever.MINIMAP_ICON_CROP)

local blendOk, blendErr, blendButton = applyChrome({ maskApi = false, failPaths = {}, rejectBlend = true })
expect("rejected ADD highlight does not raise", blendOk, true)
if not blendOk then
  io.stderr:write(tostring(blendErr) .. "\n")
end
expect("highlight still uses the zoom texture", blendButton.highlightPath, Forever.MINIMAP_HIGHLIGHT)
expect("highlight blend is applied on the texture", blendButton.highlight.blend, "ADD")

local chromeJournal = {
  schemaVersion = 3,
  sessions = {
    {
      characterKey = "Mira-Example Realm",
      entries = {
        { type = "death", msg = "Died.", seq = 1 },
      },
    },
  },
  settings = { minimapAngle = 225, afkNoteMinutes = 10 },
}
local chromeSessions = chromeJournal.sessions
local chromeEntries = chromeJournal.sessions[1].entries
Forever.applyMinimapButtonChrome(fakeButton({ maskApi = true, failPaths = {} }))
expect("chrome leaves schema 3", chromeJournal.schemaVersion, 3)
expect("chrome leaves the sessions table", chromeJournal.sessions, chromeSessions)
expect("chrome leaves the entries table", chromeJournal.sessions[1].entries, chromeEntries)
expect("chrome adds no entry", #chromeEntries, 1)
expect("chrome leaves the death line", chromeEntries[1].msg, "Died.")
expect("chrome leaves the saved angle", chromeJournal.settings.minimapAngle, 225)
expect("chrome leaves the other setting", chromeJournal.settings.afkNoteMinutes, 10)
expect("left click still toggles after chrome", Forever.minimapClickAction("LeftButton", 0, 0), "toggle")
expect("drag still is not a click after chrome", Forever.minimapClickAction("LeftButton", 9, 0), "none")
expect("right click still opens the menu after chrome", Forever.minimapClickAction("RightButton", 0, 0), "menu")
Forever.storeMinimapAngle(chromeJournal, 10)
expect("angle still stores after chrome", chromeJournal.settings.minimapAngle, 10)
expect("schema stays 3 after that store", chromeJournal.schemaVersion, 3)
expect("sessions stay the same object after that store", chromeJournal.sessions, chromeSessions)

local notes = readFile("JournalingAddon/features/Notes.lua")
local shots = readFile("JournalingAddon/features/Screenshots.lua")
local events = readFile("JournalingAddon/core/Events.lua")
local owners = {
  ToggleUI = ui,
  ShowNoteCaptureDialog = notes,
  ShowTargetCaptureDialog = shots,
  ReportCompat = events,
  ShowJournalHelp = ui,
  ToggleJournalDebug = ui,
  UndoJournalEntry = ui,
  ClearJournalSession = ui,
  ResetJournalSession = ui,
  WipeJournalData = ui,
}
for _, command in ipairs(Forever.JOURNAL_COMMANDS) do
  local owner = owners[command.method]
  expect(
    command.method .. " is the slash function",
    owner:find("function Journal:" .. command.method .. "(", 1, true) ~= nil,
    true
  )
end
expect("note dialog save uses noteTextToSave", notes:find("noteTextToSave", 1, true) ~= nil, true)
expect("capture note uses noteEntryData", notes:find("noteEntryData", 1, true) ~= nil, true)
expect("note renderer still prefixes Note", notes:find('return "Note: " ..', 1, true) ~= nil, true)

local storage = readFile("JournalingAddon/core/Storage.lua")
local initStart = storage:find("function Journal:InitDB", 1, true)
local initEnd = storage:find("function Journal:GetSetting", 1, true)
local initDb = storage:sub(initStart, initEnd - 1)
expect("load does not write the minimap angle", initDb:find("minimapAngle", 1, true) == nil, true)
expect("load still avoids ResetDatabase", initDb:find("self:ResetDatabase", 1, true) == nil, true)

if failures > 0 then
  io.stderr:write(failures .. " failure(s)\n")
  os.exit(1)
end

print("forever_compat_test: ok")
