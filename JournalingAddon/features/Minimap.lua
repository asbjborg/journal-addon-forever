local _, Journal = ...
Journal = Journal or _G.Journal or {}

local MENU_WIDTH = 220
local MENU_ROW = 22
local MENU_PAD = 6

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

function Journal:RestoreMinimapButtonLayer()
  local button = self.minimapButton
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
end

function Journal:HideMinimapMenu()
  if self.minimapMenu then
    self.minimapMenu:Hide()
  end
end

-- Plain Frame and Button. Escape uses UISpecialFrames. A fullscreen button
-- closes the menu when the click is not on the menu or the minimap button.
function Journal:EnsureMinimapMenu()
  if self.minimapMenu then
    return
  end

  local catcher = CreateFrame("Button", nil, UIParent)
  catcher:SetAllPoints(UIParent)
  catcher:SetFrameStrata("FULLSCREEN_DIALOG")
  catcher:SetFrameLevel(1)
  catcher:EnableMouse(true)
  catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
  catcher:SetScript("OnClick", function()
    if Journal.Forever.minimapMenuDismiss("outside") then
      Journal:HideMinimapMenu()
    end
  end)
  catcher:Hide()

  local menu = CreateFrame("Frame", "JournalMinimapMenu", UIParent)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetFrameLevel(2)
  menu:EnableMouse(true)
  menu:Hide()

  local background = menu:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
  background:SetVertexColor(0, 0, 0, 0.95)

  local items = Journal.Forever.menuItems()
  menu:SetSize(MENU_WIDTH, MENU_PAD * 2 + MENU_ROW * #items)

  for index, item in ipairs(items) do
    local row = CreateFrame("Button", nil, menu)
    row:SetSize(MENU_WIDTH - MENU_PAD * 2, MENU_ROW)
    row:SetPoint("TOPLEFT", menu, "TOPLEFT", MENU_PAD, -MENU_PAD - (index - 1) * MENU_ROW)
    row:RegisterForClicks("LeftButtonUp")

    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", row, "LEFT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    label:SetJustifyH("LEFT")
    label:SetText(item.label)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")

    local token = item.token
    row:SetScript("OnClick", function()
      Journal:HideMinimapMenu()
      Journal:DispatchJournalCommand(token)
    end)
  end

  menu:SetScript("OnShow", function()
    catcher:Show()
  end)
  menu:SetScript("OnHide", function()
    catcher:Hide()
    Journal:RestoreMinimapButtonLayer()
  end)

  table.insert(UISpecialFrames, "JournalMinimapMenu")
  self.minimapMenu = menu
  self.minimapMenuCatcher = catcher
end

function Journal:ShowMinimapMenu()
  self:EnsureMinimapMenu()
  local button = self.minimapButton
  local menu = self.minimapMenu
  button:SetFrameStrata("FULLSCREEN_DIALOG")
  button:SetFrameLevel(menu:GetFrameLevel() + 5)
  menu:ClearAllPoints()
  menu:SetPoint("TOPRIGHT", button, "TOPLEFT", -4, 0)
  menu:Show()
end

function Journal:ToggleMinimapMenu()
  self:EnsureMinimapMenu()
  if self.minimapMenu:IsShown() then
    self:HideMinimapMenu()
    return
  end
  self:ShowMinimapMenu()
end

function Journal:InitMinimapButton()
  if self.minimapButton then
    return
  end

  local button = CreateFrame("Button", "JournalingAddonMinimapButton", Minimap)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(Minimap:GetFrameLevel() + 5)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  Journal.Forever.applyMinimapButtonChrome(button)

  button:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local title, leftClick, rightClick = Journal.Forever.minimapTooltip()
    GameTooltip:SetText(title)
    GameTooltip:AddLine(leftClick, 1, 1, 1, true)
    GameTooltip:AddLine(rightClick, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  button:SetScript("OnMouseDown", function(self)
    self.downX, self.downY = GetCursorPosition()
    Journal.Forever.placeMinimapIcon(self.icon, true)
  end)
  button:SetScript("OnMouseUp", function(self)
    Journal.Forever.placeMinimapIcon(self.icon, false)
  end)
  button:SetScript("OnClick", function(self, mouseButton)
    local x, y = GetCursorPosition()
    local dx = x - self.downX
    local dy = y - self.downY
    local action = Journal.Forever.minimapClickAction(mouseButton, dx, dy)
    if action == "toggle" then
      Journal:HideMinimapMenu()
      Journal:ToggleUI()
    elseif action == "menu" then
      GameTooltip:Hide()
      Journal:ToggleMinimapMenu()
    end
  end)
  button:SetScript("OnDragStart", function(self)
    Journal:HideMinimapMenu()
    GameTooltip:Hide()
    self:SetScript("OnUpdate", function()
      Journal:PlaceMinimapButton(Journal:MinimapCursorAngle())
    end)
  end)
  button:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    Journal:PlaceMinimapButton(Journal:MinimapCursorAngle())
    Journal.Forever.storeMinimapAngle(JournalDB, self.angle)
    Journal.Forever.placeMinimapIcon(self.icon, false)
  end)

  self.minimapButton = button
  self:PlaceMinimapButton(Journal.Forever.savedMinimapAngle(JournalDB.settings))
end

Journal.On("PLAYER_LOGIN", function()
  Journal:InitMinimapButton()
end)
