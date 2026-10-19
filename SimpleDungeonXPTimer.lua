SimpleDungeonXPTimerDB = SimpleDungeonXPTimerDB or {}

local timerFrame = CreateFrame("Frame", "SimpleDungeonXPTimerWindow", UIParent)
local saved = SimpleDungeonXPTimerDB

local MIN_WIDTH, MIN_HEIGHT = 150, 58
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 190, 66
local elapsedSinceRefresh = 0
local active = false

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

local function SetInstanceState()
    local inInstance = IsInInstance()

    if inInstance then
        if not saved.startedAt then
            saved.startedAt = time()
        end
        active = true
        timerFrame:Show()
        UpdateDisplay()
    else
        active = false
        saved.startedAt = nil
        timerFrame:Hide()
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

timerFrame.resizeHandle = CreateFrame("Button", nil, timerFrame)
timerFrame.resizeHandle:SetWidth(16)
timerFrame.resizeHandle:SetHeight(16)
timerFrame.resizeHandle:SetPoint("BOTTOMRIGHT", -3, 3)
timerFrame.resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
timerFrame.resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
timerFrame.resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
timerFrame.resizeHandle:SetScript("OnMouseDown", function()
    timerFrame:StartSizing("BOTTOMRIGHT")
end)
timerFrame.resizeHandle:SetScript("OnMouseUp", function()
    timerFrame:StopMovingOrSizing()
    SaveGeometry()
end)

timerFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
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
    if not active then
        return
    end

    elapsedSinceRefresh = elapsedSinceRefresh + elapsed
    if elapsedSinceRefresh >= 0.25 then
        elapsedSinceRefresh = 0
        UpdateDisplay()
    end
end)

timerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
timerFrame:SetScript("OnEvent", SetInstanceState)

if saved.point then
    timerFrame:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
else
    timerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -18, -250)
end

SetInstanceState()
