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

if type(Journal) == "table" then
  Journal.Forever = Forever
end

return Forever
