local _, Journal = ...
Journal = Journal or _G.Journal or {}

local frame = CreateFrame("Frame")
Journal.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
  Journal.Emit(event, ...)
end)

local events = {
  "PLAYER_LOGIN",
  "PLAYER_LOGOUT",
  "QUEST_ACCEPTED",
  "QUEST_TURNED_IN",
  "CHAT_MSG_SYSTEM",
  "PLAYER_XP_UPDATE",
  "COMBAT_LOG_EVENT_UNFILTERED",
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
  -- Forever roster event. PARTY_MEMBERS_CHANGED is not registered: an unknown event throws.
  "PARTY_INVITE_REQUEST",
  "GROUP_ROSTER_UPDATE",
}

Journal.eventRegistration = {}
for _, eventName in ipairs(events) do
  local ok, err = pcall(frame.RegisterEvent, frame, eventName)
  if ok then
    Journal.eventRegistration[eventName] = "registered"
  else
    Journal.eventRegistration[eventName] = tostring(err)
  end
end

function Journal:ReportCompat()
  local function say(text)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffffd200Journal:|r " .. text)
    end
  end

  say("schema " .. tostring(Journal.CURRENT_SCHEMA))
  local sessions = self.db and self.db.sessions
  local sessionCount = 0
  if type(sessions) == "table" then
    sessionCount = #sessions
  end
  say("sessions " .. tostring(sessionCount))
  say("character " .. tostring(self:GetCharacterKey()))
  say("combatLog " .. tostring(self.combatLogState or "unseen"))
  say("taxiHook " .. tostring(self.taxiHookStatus or "unset"))
  say("partyRoster " .. tostring(self.partyRosterStatus or "unset"))

  local version, build, _, tocVersion = "unknown", "unknown", nil, "unknown"
  if type(GetBuildInfo) == "function" then
    version, build, _, tocVersion = GetBuildInfo()
  end
  say("client " .. tostring(version) .. " build " .. tostring(build) .. " interface " .. tostring(tocVersion))
  say("projectId " .. tostring(WOW_PROJECT_ID))
  if WOW_PROJECT_CAMELOT ~= nil then
    say("projectCamelot " .. tostring(WOW_PROJECT_CAMELOT))
  end

  if self.eventRegistration then
    local names = {}
    for eventName in pairs(self.eventRegistration) do
      table.insert(names, eventName)
    end
    table.sort(names)
    for _, eventName in ipairs(names) do
      local status = self.eventRegistration[eventName]
      if status ~= "registered" then
        say("event " .. eventName .. " FAILED " .. status)
      end
    end
  end
end
