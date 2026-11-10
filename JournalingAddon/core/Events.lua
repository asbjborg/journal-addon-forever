local _, Journal = ...
Journal = Journal or _G.Journal or {}

local frame = CreateFrame("Frame")
Journal.frame = frame

frame:SetScript("OnEvent", function(_, event, ...)
  Journal.Emit(event, ...)
end)

-- PARTY_MEMBERS_CHANGED is not in this list: an unknown event throws.
-- COMBAT_LOG_EVENT_UNFILTERED is not registered: Forever treats that
-- registration as a protected call and emits ADDON_ACTION_FORBIDDEN.
-- pcall does not stop that notice, so applyRegistrations never calls it.
Journal.eventRegistration = Journal.Forever.applyRegistrations(Journal.Forever.loadEventNames, function(eventName)
  frame:RegisterEvent(eventName)
end)
Journal.combatLogState = "not-registered"

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
