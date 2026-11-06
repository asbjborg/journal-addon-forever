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

if failures > 0 then
  io.stderr:write(failures .. " failure(s)\n")
  os.exit(1)
end

print("forever_compat_test: ok")
