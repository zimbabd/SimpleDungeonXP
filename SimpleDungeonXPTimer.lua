local loadedAddonName = ...

SimpleDungeonXPTimerDB = SimpleDungeonXPTimerDB or {}

local timerFrame = CreateFrame("Frame", "SimpleDungeonXPTimerWindow", UIParent)
local saved = SimpleDungeonXPTimerDB
if not saved.lockConfigured then
    saved.locked = true
    saved.lockConfigured = true
elseif saved.locked == nil then
    saved.locked = true
end

local MIN_WIDTH, MIN_HEIGHT = 150, 58
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 190, 66
local RETURN_GRACE_PERIOD = 15
local elapsedSinceRefresh = 0
local active = false
local pauseTimeRemaining = saved.pausedAt and math.max(0, RETURN_GRACE_PERIOD - (time() - saved.pausedAt)) or 0

local function SaveGeometry()
    local point, _, relativePoint, x, y = timerFrame:GetPoint(1)
    saved.point = point
    saved.relativePoint = relativePoint
    saved.x = x
    saved.y = y
    saved.width = timerFrame:GetWidth()
    saved.height = timerFrame:GetHeight()
end

local function FormatElapsed(seconds)
    seconds = math.max(0, math.floor(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local remainingSeconds = seconds % 60
    return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds)
end

local function UpdateDisplay()
    if active and saved.startedAt then
        timerFrame.timeText:SetText(FormatElapsed(time() - saved.startedAt))
    end
end

local function UpdateFuse()
    local fuseBar = timerFrame.fuseBar
    if not fuseBar then
        return
    end

    if saved.pausedAt then
        local wallClockRemaining = RETURN_GRACE_PERIOD - (time() - saved.pausedAt)
        pauseTimeRemaining = math.max(0, math.min(pauseTimeRemaining, wallClockRemaining))
        fuseBar:SetValue(pauseTimeRemaining)
        if pauseTimeRemaining > 0 then
            fuseBar:Show()
            return
        end
    end

    fuseBar:Hide()
end

local function UpdateVisibility()
    if active or saved.pausedAt then
        timerFrame:Show()
    else
        timerFrame:Hide()
    end
    UpdateFuse()
end

local function UpdateLockState()
    timerFrame:SetResizable(not saved.locked)
    if saved.locked then
        timerFrame.resizeHandle:Hide()
        timerFrame:SetBackdropColor(0.04, 0.06, 0.07, 0)
        timerFrame:SetBackdropBorderColor(1, 1, 1, 0)
    else
        timerFrame.resizeHandle:Show()
        timerFrame:SetBackdropColor(0.04, 0.06, 0.07, 0.92)
        timerFrame:SetBackdropBorderColor(1, 1, 1, 1)
    end
    timerFrame.lockButton.icon:SetTexture(saved.locked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up")
end

function SimpleDungeonXPTimer_SetLocked(locked)
    if saved.locked == locked then
        return
    end

    saved.locked = locked
    saved.lockConfigured = true
    UpdateLockState()
    print("|cff00ff00Simple Dungeon XP:|r Dungeon Timer " .. (locked and "LOCKED" or "UNLOCKED"))
end

function SimpleDungeonXPTimer_Lock()
    SimpleDungeonXPTimer_SetLocked(true)
end

function SimpleDungeonXPTimer_Unlock()
    SimpleDungeonXPTimer_SetLocked(false)
end

local function SetInstanceState()
    local inInstance = IsInInstance()
    local currentTime = time()

    if inInstance then
        local instanceName, _, _, _, _, _, _, instanceMapID = GetInstanceInfo()
        local instanceKey = instanceMapID or instanceName

        if saved.pausedAt then
            local pauseDuration = currentTime - saved.pausedAt
            if pauseDuration <= RETURN_GRACE_PERIOD and saved.instanceKey == instanceKey then
                saved.startedAt = currentTime - (saved.pausedElapsed or 0)
            else
                saved.startedAt = currentTime
            end
            saved.pausedAt = nil
            saved.pausedElapsed = nil
            pauseTimeRemaining = 0
        elseif not saved.startedAt or (saved.instanceKey and saved.instanceKey ~= instanceKey) then
            saved.startedAt = currentTime
        end

        saved.instanceKey = instanceKey
        active = true
        UpdateVisibility()
        UpdateDisplay()
    else
        if active and saved.startedAt then
            saved.pausedElapsed = currentTime - saved.startedAt
            saved.pausedAt = currentTime
            pauseTimeRemaining = RETURN_GRACE_PERIOD
            timerFrame.timeText:SetText(FormatElapsed(saved.pausedElapsed))
        end
        active = false
        if saved.pausedAt and currentTime - saved.pausedAt > RETURN_GRACE_PERIOD then
            saved.startedAt = nil
            saved.pausedAt = nil
            saved.pausedElapsed = nil
            saved.instanceKey = nil
            pauseTimeRemaining = 0
            timerFrame.timeText:SetText("00:00:00")
        end
        UpdateVisibility()
    end
end

timerFrame:SetWidth(saved.width or DEFAULT_WIDTH)
timerFrame:SetHeight(saved.height or DEFAULT_HEIGHT)
timerFrame:SetResizable(true)
timerFrame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
timerFrame:SetMaxResize(600, 300)
timerFrame:SetClampedToScreen(true)
timerFrame:SetFrameStrata("MEDIUM")
timerFrame:SetMovable(true)
timerFrame:EnableMouse(true)
timerFrame:RegisterForDrag("LeftButton")
timerFrame:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
timerFrame:SetBackdropColor(0.04, 0.06, 0.07, 0.92)
timerFrame:SetBackdropBorderColor(1, 1, 1, 1)

timerFrame.title = timerFrame:CreateFontString(nil, "OVERLAY")
timerFrame.title:SetPoint("TOP", timerFrame, "TOP", 0, -8)
timerFrame.title:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
timerFrame.title:SetText("INSTANCE TIME")
timerFrame.title:SetTextColor(0.65, 0.85, 0.78)

timerFrame.timeText = timerFrame:CreateFontString(nil, "OVERLAY")
timerFrame.timeText:SetPoint("CENTER", timerFrame, "CENTER", 0, -7)
timerFrame.timeText:SetFont("Fonts\\ARIALN.TTF", 24, "OUTLINE")
timerFrame.timeText:SetText("00:00:00")
timerFrame.timeText:SetTextColor(1, 1, 1)

timerFrame.fuseBar = CreateFrame("StatusBar", nil, timerFrame)
timerFrame.fuseBar:SetPoint("BOTTOMLEFT", 24, 10)
timerFrame.fuseBar:SetPoint("BOTTOMRIGHT", -24, 10)
timerFrame.fuseBar:SetHeight(3)
timerFrame.fuseBar:SetMinMaxValues(0, RETURN_GRACE_PERIOD)
timerFrame.fuseBar:SetValue(0)
timerFrame.fuseBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
timerFrame.fuseBar:SetStatusBarColor(1, 0.32, 0.08, 1)
timerFrame.fuseBar.background = timerFrame.fuseBar:CreateTexture(nil, "BACKGROUND")
timerFrame.fuseBar.background:SetAllPoints(timerFrame.fuseBar)
timerFrame.fuseBar.background:SetTexture(0.12, 0.08, 0.06, 0.8)
timerFrame.fuseBar:Hide()

timerFrame.resizeHandle = CreateFrame("Button", nil, timerFrame)
timerFrame.resizeHandle:SetWidth(16)
timerFrame.resizeHandle:SetHeight(16)
timerFrame.resizeHandle:SetPoint("BOTTOMRIGHT", -3, 3)
timerFrame.resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
timerFrame.resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
timerFrame.resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
timerFrame.resizeHandle:SetScript("OnMouseDown", function()
    if not saved.locked then
        timerFrame:StartSizing("BOTTOMRIGHT")
    end
end)
timerFrame.resizeHandle:SetScript("OnMouseUp", function()
    timerFrame:StopMovingOrSizing()
    SaveGeometry()
end)

timerFrame.lockButton = CreateFrame("Button", nil, timerFrame)
timerFrame.lockButton:SetWidth(22)
timerFrame.lockButton:SetHeight(22)
timerFrame.lockButton:SetPoint("BOTTOMLEFT", 2, 1)
timerFrame.lockButton:SetFrameLevel(timerFrame:GetFrameLevel() + 3)
timerFrame.lockButton.icon = timerFrame.lockButton:CreateTexture(nil, "ARTWORK")
timerFrame.lockButton.icon:SetAllPoints(timerFrame.lockButton)
timerFrame.lockButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
timerFrame.lockButton:SetScript("OnClick", function()
    SimpleDungeonXPTimer_SetLocked(not saved.locked)
end)
timerFrame.lockButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    local lockTexture = saved.locked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up"
    GameTooltip:SetText("|T" .. lockTexture .. ":16:16|t")
    GameTooltip:AddLine(saved.locked and "Unlock timer" or "Lock timer")
    GameTooltip:Show()
end)
timerFrame.lockButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
timerFrame:SetScript("OnDragStart", function(self)
    if not saved.locked then
        self:StartMoving()
    end
end)
timerFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveGeometry()
end)

timerFrame:SetScript("OnSizeChanged", function()
    if timerFrame.timeText then
        local scale = math.min(
            timerFrame:GetWidth() / DEFAULT_WIDTH,
            timerFrame:GetHeight() / DEFAULT_HEIGHT
        )
        timerFrame.timeText:SetFont("Fonts\\ARIALN.TTF", math.max(12, math.min(48, 24 * scale)), "OUTLINE")
        timerFrame.title:SetFont("Fonts\\ARIALN.TTF", math.max(9, math.min(20, 12 * scale)), "OUTLINE")
        SaveGeometry()
    end
end)

timerFrame:SetScript("OnUpdate", function(_, elapsed)
    if active then
        elapsedSinceRefresh = elapsedSinceRefresh + elapsed
        if elapsedSinceRefresh >= 0.25 then
            elapsedSinceRefresh = 0
            UpdateDisplay()
        end
    elseif saved.pausedAt then
        pauseTimeRemaining = pauseTimeRemaining - elapsed
        UpdateFuse()
        if pauseTimeRemaining <= 0 or time() - saved.pausedAt >= RETURN_GRACE_PERIOD then
            saved.startedAt = nil
            saved.pausedAt = nil
            saved.pausedElapsed = nil
            saved.instanceKey = nil
            pauseTimeRemaining = 0
            timerFrame.timeText:SetText("00:00:00")
            UpdateFuse()
            UpdateVisibility()
        end
    end
end)

timerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
timerFrame:RegisterEvent("PLAYER_LOGIN")
timerFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        local version = GetAddOnMetadata(loadedAddonName, "Version") or "unknown"
        print("|cff00ff00Simple Dungeon XP|r v" .. version .. " loaded.")
        return
    end

    SetInstanceState()
end)

UpdateLockState()

if saved.point then
    timerFrame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
else
    timerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, -250)
end

SetInstanceState()
