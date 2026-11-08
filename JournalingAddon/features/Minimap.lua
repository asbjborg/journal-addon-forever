local _, Journal = ...
Journal = Journal or _G.Journal or {}

function Journal:MinimapCursorAngle()
  local scale = Minimap:GetEffectiveScale()
  local cx, cy = GetCursorPosition()
  local mx, my = Minimap:GetCenter()
  return Journal.Forever.minimapAngleDegrees(cx / scale - mx, cy / scale - my)
end

function Journal:PlaceMinimapButton(angle)
  local button = self.minimapButton
  local x, y = Journal.Forever.minimapOffset(
    angle,
    Minimap:GetWidth() / 2,
    Minimap:GetHeight() / 2,
    Journal.Forever.MINIMAP_PADDING
  )
  button.angle = angle
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

function Journal:InitMinimapButton()
  if self.minimapButton then
    return
  end

  local button = CreateFrame("Button", "JournalingAddonMinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  button:RegisterForClicks("LeftButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

  local icon = button:CreateTexture(nil, "BACKGROUND")
  icon:SetTexture("Interface\\Icons\\INV_Misc_Book_09")
  icon:SetAllPoints()
  icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  button.icon = icon

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local title, action = Journal.Forever.minimapTooltip()
    GameTooltip:SetText(title)
    GameTooltip:AddLine(action, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:SetScript("OnMouseDown", function(self)
    self.downX, self.downY = GetCursorPosition()
  end)
  button:SetScript("OnClick", function(self, mouseButton)
    local x, y = GetCursorPosition()
    local dx = x - self.downX
    local dy = y - self.downY
    if Journal.Forever.minimapShouldToggle(mouseButton, dx, dy) then
      Journal:ToggleUI()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
      Journal:PlaceMinimapButton(Journal:MinimapCursorAngle())
    end)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    Journal:PlaceMinimapButton(Journal:MinimapCursorAngle())
    Journal.Forever.storeMinimapAngle(JournalDB, self.angle)
  end)

  self.minimapButton = button
  self:PlaceMinimapButton(Journal.Forever.savedMinimapAngle(JournalDB.settings))
end

Journal.On("PLAYER_LOGIN", function()
  Journal:InitMinimapButton()
end)
