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

if failures > 0 then
  io.stderr:write(failures .. " failure(s)\n")
  os.exit(1)
end

print("forever_compat_test: ok")
