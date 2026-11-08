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

local tipTitle, tipAction = Forever.minimapTooltip()
expect("tooltip names the addon", tipTitle, "JournalingAddon")
expect("tooltip names the click", tipAction, "Left-click to toggle the journal")

local function readFile(path)
  local handle = assert(io.open(path, "r"))
  local text = handle:read("*a")
  handle:close()
  return text
end

local ui = readFile("JournalingAddon/JournalUI.lua")
expect("slash command is still /journal", ui:find('SLASH_JOURNAL1 = "/journal"', 1, true) ~= nil, true)
expect("slash note command stays", ui:find('arg == "note"', 1, true) ~= nil, true)
expect("slash compat command stays", ui:find('arg == "compat"', 1, true) ~= nil, true)
expect("slash wipe command stays", ui:find('arg == "wipe"', 1, true) ~= nil, true)
expect("bare /journal still calls ToggleUI", ui:find("Journal:ToggleUI()", 1, true) ~= nil, true)

local minimap = readFile("JournalingAddon/features/Minimap.lua")
expect("minimap click uses the shared decision", minimap:find("minimapShouldToggle", 1, true) ~= nil, true)
expect("minimap click calls ToggleUI", minimap:find("Journal:ToggleUI()", 1, true) ~= nil, true)
expect("minimap does not register a combat log", minimap:find("COMBAT_LOG", 1, true) == nil, true)
expect("minimap does not register events itself", minimap:find("RegisterEvent", 1, true) == nil, true)
expect("minimap does not mention schema", minimap:find("schemaVersion", 1, true) == nil, true)

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
