local addon = CreateFrame("Frame", "SimpleDungeonXP")

------------------------------------------------
-- Saved Variables
------------------------------------------------

SimpleDungeonXPDB = SimpleDungeonXPDB or {}

if not SimpleDungeonXPDB.history then
    SimpleDungeonXPDB.history = {}
end

if not SimpleDungeonXPDB.minimap then
    SimpleDungeonXPDB.minimap = {
        angle = 180,
        hide  = false
    }
end

-- Persistent active run state (survives /reload)
if SimpleDungeonXPDB.activeRun == nil then
    SimpleDungeonXPDB.activeRun = false
end

------------------------------------------------
-- ALL Variables (declared first!)
------------------------------------------------

local running     = false
local dungeonName = ""
local startTime   = 0
local startXP     = 0
local startXPMax  = 0   -- UnitXPMax at run start, used for levelup detection

local gainedXP = 0
local mobs     = 0
local liveXPReference = 0

local sortKey = nil
local sortAsc = true
local rows    = {}

local frame
local title
local close
local scrollFrame
local scrollChild
local headerButtons
local clearBtn
local DeleteRun

-- Flag: waiting for GetInstanceInfo to return a valid name
local pendingStart        = false
local pendingStartElapsed = 0

------------------------------------------------
-- Helpers
------------------------------------------------

local function FormatXP(xp)
    if xp >= 1000000 then
        return string.format("%.1fm", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fk", xp / 1000)
    else
        return xp
    end
end

-- Format raw seconds -> "Xm Ys"
local function FormatDuration(seconds)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    if m > 0 then
        return string.format("%dm %02ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function SaveRun(runDate, entered, left, duration, xph)
    table.insert(
        SimpleDungeonXPDB.history,
        1,
        {
            dungeon  = dungeonName,
            date     = runDate,
            entered  = entered,
            left     = left,
            duration = duration,   -- raw seconds (replaces old float "time")
            xp       = gainedXP,
            xph      = xph,
            mobs     = mobs
        }
    )

    while #SimpleDungeonXPDB.history > 100 do
        table.remove(SimpleDungeonXPDB.history)
    end
end

-- Persist active run to SavedVariables so /reload does not lose progress
local function PersistActiveRun()
    SimpleDungeonXPDB.activeRun = {
        running     = running,
        dungeonName = dungeonName,
        startTime   = startTime,
        startXP     = startXP,
        startXPMax  = startXPMax,
        gainedXP    = gainedXP,
        mobs        = mobs
    }
end

local function ClearActiveRun()
    SimpleDungeonXPDB.activeRun = false
end

-- Restore active run state after /reload inside a dungeon
local function RestoreActiveRun()
    local ar = SimpleDungeonXPDB.activeRun
    if ar and ar.running then
        running      = true
        dungeonName  = ar.dungeonName or ""
        startTime    = ar.startTime   or time()
        startXP      = ar.startXP     or UnitXP("player")
        startXPMax   = ar.startXPMax  or UnitXPMax("player")
        gainedXP     = ar.gainedXP    or 0
        mobs         = ar.mobs        or 0
        print("|cff00ff00Simple Dungeon XP:|r Resumed " .. dungeonName)
    end
end

------------------------------------------------
-- Instance type check
------------------------------------------------

local VALID_INSTANCE_TYPES = {
    party = true,
    raid  = true,
    pvp   = true,
    arena = true,
}

local function IsInTrackedInstance()
    local inInstance, instanceType = IsInInstance()
    return inInstance and VALID_INSTANCE_TYPES[instanceType]
end


------------------------------------------------
-- Dungeon start/end
------------------------------------------------

local function TryStartDungeon()
    local name = GetInstanceInfo()

    -- GetInstanceInfo can return empty string right after loading screen;
    -- return false so the caller retries via OnUpdate
    if not name or name == "" then
        return false
    end

    dungeonName  = name
    startTime    = time()
    startXP      = UnitXP("player")
    startXPMax   = UnitXPMax("player")
    gainedXP     = 0
    mobs         = 0
    running      = true
    pendingStart = false

    PersistActiveRun()

    print("|cff00ff00Simple Dungeon XP:|r " .. name .. " started")
    return true
end

local function StartDungeon()
    -- First attempt immediately; if name is empty, schedule retries via OnUpdate
    if not TryStartDungeon() then
        pendingStart        = true
        pendingStartElapsed = 0
    end
end

local function FinishDungeon()
    if not running then
        return
    end

    local endTime  = time()
    local duration = endTime - startTime

    -- Ignore runs shorter than five minutes
    if duration < 300 then
        running = false
        ClearActiveRun()
        return
    end

    local xph = 0
    if duration > 0 then
        xph = math.floor(gainedXP / duration * 3600)
    end

    local runDate = date("%d.%m.%Y", startTime)
    local entered = date("%a %b %d %H:%M", startTime)
    local left    = date("%a %b %d %H:%M", endTime)

    SaveRun(runDate, entered, left, duration, xph)

    -- Chat summary
    print("|cff00ff00Simple Dungeon XP|r")
    print("|cff00ff00------------------------------------------------|r")
    print("Dungeon      : " .. dungeonName)
    print(string.format("Duration     : %s", FormatDuration(duration)))
    print("XP Gained    : " .. FormatXP(gainedXP))
    print("XP / Hour    : " .. FormatXP(xph))
    print("Mobs Killed  : " .. mobs)
    print("|cff00ff00------------------------------------------------|r")

    running = false
    ClearActiveRun()
end

------------------------------------------------
-- Events
------------------------------------------------

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("PLAYER_ENTERING_WORLD")
addon:RegisterEvent("PLAYER_XP_UPDATE")
addon:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

addon:SetScript("OnEvent", function(self, event, ...)

    -- PLAYER_LOGIN: restore persisted run state (fired once, UI is fully ready)
    if event == "PLAYER_LOGIN" then
        RestoreActiveRun()
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        local inTrackedInstance = IsInTrackedInstance()

        if inTrackedInstance and not running then
            StartDungeon()
        elseif not inTrackedInstance and running then
            FinishDungeon()
        end

        return
    end

    -- XP update: correctly handle levelup
    if event == "PLAYER_XP_UPDATE" then
        if not running then return end

        local currentXP    = UnitXP("player")
        local currentXPMax = UnitXPMax("player")

        if currentXP >= startXP then
            -- Normal gain within the same level
            local diff = currentXP - startXP
            if diff > 0 then
                gainedXP = gainedXP + diff
                mobs = mobs + 1
            end
        else
            -- Levelup: player crossed a level boundary
            -- Gain = (startXPMax - startXP) to ding + currentXP on new level
            local toNextLevel = startXPMax - startXP
            if toNextLevel < 0 then toNextLevel = 0 end
            gainedXP = gainedXP + toNextLevel + currentXP
            mobs = mobs + 1
        end

        startXP    = currentXP
        startXPMax = currentXPMax
        PersistActiveRun()
        return
    end

    -- Count player kills via combat log. NPC kills are counted from XP updates
    -- above, because UNIT_DIED flags are unreliable on some 3.3.5 clients.
    -- CHAT_MSG_COMBAT_XP_GAIN does not exist in 3.3.5 WotLK clients
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not running then return end

        -- WotLK 3.3.5 does not include hideCaster in the event arguments.
        local timestamp, subevent,
              sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
              destGUID, destName, destFlags = ...

        if subevent == "UNIT_DIED" then
            -- COMBATLOG_OBJECT_TYPE_PLAYER      = 0x0400
            -- COMBATLOG_OBJECT_REACTION_HOSTILE = 0x0040
            local isPlayer  = bit.band(destFlags or 0, 0x0400) ~= 0
            local isHostile = bit.band(destFlags or 0, 0x0040) ~= 0
            if isPlayer and isHostile then
                mobs = mobs + 1
                PersistActiveRun()
            end
        end

        return
    end

end)

-- OnUpdate: retry TryStartDungeon while pendingStart == true
-- Gives up after 3 seconds and falls back to "Unknown Dungeon"
addon:SetScript("OnUpdate", function(self, elapsed)
    if not pendingStart then return end

    pendingStartElapsed = pendingStartElapsed + elapsed

    if pendingStartElapsed >= 3 then
        -- Final attempt; fall back to "Unknown Dungeon" if still empty
        pendingStart = false
        local name = GetInstanceInfo()
        dungeonName  = (name and name ~= "") and name or "Unknown Dungeon"
        startTime    = time()
        startXP      = UnitXP("player")
        startXPMax   = UnitXPMax("player")
        gainedXP     = 0
        mobs         = 0
        running      = true
        PersistActiveRun()
        print("|cff00ff00Simple Dungeon XP:|r " .. dungeonName .. " started")
        return
    end

    -- Retry approximately every 0.5 seconds
    if pendingStartElapsed >= 0.5 then
        TryStartDungeon()
    end
end)

------------------------------------------------
-- UI Elements (create frame first, then all child elements)
------------------------------------------------

frame = CreateFrame(
"Frame",
"SimpleDungeonXPWindow",
UIParent
)

frame:SetWidth(750)
frame:SetHeight(400)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
end)

close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", -5, -5)
table.insert(UISpecialFrames, "SimpleDungeonXPWindow")

frame:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 16,
    edgeSize = 16
})
frame:SetFrameStrata("FULLSCREEN_DIALOG")

frame:Hide()

title = frame:CreateFontString(nil, "OVERLAY")
title:SetPoint("TOP", 0, -15)
title:SetFont("Fonts\\ARIALN.TTF", 20)
title:SetText("Simple Dungeon XP")

------------------------------------------------
-- Scroll Frame & Child
------------------------------------------------

scrollFrame = CreateFrame("ScrollFrame", "SimpleDungeonXPScrollFrame", frame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 20, -85)
scrollFrame:SetPoint("BOTTOMRIGHT", -32, 10)

scrollChild = CreateFrame("Frame", "SimpleDungeonXPScrollChild", scrollFrame)
scrollChild:SetWidth(700)
scrollChild:SetHeight(1)
scrollFrame:SetScrollChild(scrollChild)

------------------------------------------------
-- Row factory and table functions
------------------------------------------------

local function CreateRow(index)
    local row = {}

    row.frame = CreateFrame("Frame", nil, scrollChild)
    row.frame:SetWidth(700)
    row.frame:SetHeight(24)
    local y = -((index - 1) * 24)
    row.frame:SetPoint("TOPLEFT", 0, y)
    row.frame:EnableMouse(true)

    row.bg = row.frame:CreateTexture(nil, "BACKGROUND")
    row.bg:SetPoint("TOPLEFT", 0, -1)
    row.bg:SetPoint("BOTTOMRIGHT", 0, 1)
    row.bg:SetTexture(0, 0, 0, 0)

    row.frame:SetScript("OnEnter", function()
        row.bg:SetTexture(0.3, 0.3, 0.3, 0.5)
    end)
    row.frame:SetScript("OnLeave", function()
        row.bg:SetTexture(0, 0, 0, 0)
    end)

    row.num  = row.frame:CreateFontString(nil, "OVERLAY")
    row.name = row.frame:CreateFontString(nil, "OVERLAY")
    row.time = row.frame:CreateFontString(nil, "OVERLAY")
    row.xp   = row.frame:CreateFontString(nil, "OVERLAY")
    row.xph  = row.frame:CreateFontString(nil, "OVERLAY")

    local font = "Fonts\\ARIALN.TTF"
    row.num:SetFont(font, 16)
    row.name:SetFont(font, 16)
    row.time:SetFont(font, 16)
    row.xp:SetFont(font, 16)
    row.xph:SetFont(font, 16)

    row.num:SetPoint("TOPLEFT",   0, 0)
    row.name:SetPoint("TOPLEFT",  35, 0)
    row.time:SetPoint("TOPLEFT", 280, 0)
    row.xp:SetPoint("TOPLEFT",   380, 0)
    row.xph:SetPoint("TOPLEFT",  500, 0)

    row.deleteBtn = CreateFrame("Button", nil, row.frame, "UIPanelCloseButton")
    row.deleteBtn:SetWidth(20)
    row.deleteBtn:SetHeight(20)
    row.deleteBtn:SetPoint("TOPRIGHT", 0, 0)

    return row
end

local function SortRuns(a, b)
    if not sortKey then return false end
    local valA = a[sortKey] or 0
    local valB = b[sortKey] or 0
    if type(valA) == "string" then
        valA = valA:lower()
        valB = valB:lower()
    end
    if sortAsc then
        return valA < valB
    else
        return valA > valB
    end
end

local function UpdateWindow()
    for _, row in ipairs(rows) do
        row.num:SetText("")
        row.name:SetText("")
        row.time:SetText("")
        row.xp:SetText("")
        row.xph:SetText("")
        row.deleteBtn:Hide()
    end

    local bestXPH = 0
    for _, v in ipairs(SimpleDungeonXPDB.history) do
        if (v.xph or 0) > bestXPH then
            bestXPH = v.xph
        end
    end

    local display = {}
    for i, v in ipairs(SimpleDungeonXPDB.history) do
        display[i] = v
    end

    if sortKey then
        table.sort(display, SortRuns)
    end

    for i, v in ipairs(display) do
        if not rows[i] then
            rows[i] = CreateRow(i)
        end

        local color = ""
        if bestXPH > 0 and (v.xph or 0) == bestXPH then
            color = "|cff00ff00"
        end
        local reset = "|r"

        -- Support both new (duration = integer seconds) and
        -- old (time = float minutes) saved variable formats
        local timeStr
        if v.duration then
            timeStr = FormatDuration(v.duration)
        else
            timeStr = string.format("%dm", math.floor(v.time or 0))
        end

        rows[i].num:SetText(color .. i .. reset)
        rows[i].name:SetText(color .. (v.dungeon or "Unknown") .. reset)
        rows[i].time:SetText(color .. timeStr .. reset)
        rows[i].xp:SetText(color .. FormatXP(v.xp or 0) .. reset)
        rows[i].xph:SetText(color .. FormatXP(v.xph or 0) .. reset)
        rows[i].deleteBtn:Show()

        -- Capture entry in local scope so the closure is correct
        local entry = v
        rows[i].deleteBtn:SetScript("OnClick", function()
            DeleteRun(entry)
        end)
    end

    scrollChild:SetHeight(math.max(1, #display * 24))
end

function DeleteRun(runToDelete)
    for i, run in ipairs(SimpleDungeonXPDB.history) do
        if run == runToDelete then
            table.remove(SimpleDungeonXPDB.history, i)
            break
        end
    end
    UpdateWindow()
end

-- Clear History Button
clearBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
clearBtn:SetWidth(100)
clearBtn:SetHeight(24)
clearBtn:SetPoint("TOPRIGHT", -10, -30)
clearBtn:SetText("Clear History")

local function ClearHistory()
    StaticPopupDialogs["SIMPLEDUNGEONXP_CLEAR_HISTORY"] = {
        text = "Are you sure you want to clear all dungeon history?",
        button1 = "Yes",
        button2 = "No",
        OnAccept = function()
            SimpleDungeonXPDB.history = {}
            UpdateWindow()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
    StaticPopup_Show("SIMPLEDUNGEONXP_CLEAR_HISTORY")
end

clearBtn:SetScript("OnClick", ClearHistory)

frame:SetScript("OnShow", UpdateWindow)

------------------------------------------------
-- Header Buttons
------------------------------------------------

headerButtons = {}

local function CreateHeaderButton(text, key, x)
    local btn = CreateFrame("Button", nil, frame)
    btn:SetWidth(150)
    btn:SetHeight(24)
    btn:SetPoint("TOPLEFT", x, -48)

    local fs = btn:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("LEFT", 0, 0)
    fs:SetFont("Fonts\\ARIALN.TTF", 16)
    fs:SetText(text)
    btn.text = fs

    if key then
        btn:SetScript("OnClick", function()
            if sortKey == key then
                sortAsc = not sortAsc
            else
                sortKey = key
                sortAsc = true
            end
            UpdateWindow()
        end)
    end

    return btn
end

headerButtons.num  = CreateHeaderButton("#",         nil,        20)
headerButtons.name = CreateHeaderButton("Dungeon",   "dungeon",  55)
headerButtons.time = CreateHeaderButton("Time",      "duration", 300)
headerButtons.xp   = CreateHeaderButton("XP",        "xp",       400)
headerButtons.xph  = CreateHeaderButton("XP / Hour", "xph",      520)

------------------------------------------------
-- Slash Commands
------------------------------------------------

SLASH_SIMPLEDXP1 = "/sdxp"

SlashCmdList["SIMPLEDXP"] = function(msg)
    if msg == "reset" then
        SimpleDungeonXPDB.history = {}
        print("|cff00ff00Simple Dungeon XP:|r history cleared")
    else
        if frame:IsShown() then
            frame:Hide()
        else
            UpdateWindow()
            frame:Show()
        end
    end
end

------------------------------------------------
-- Minimap Button
------------------------------------------------

local LDB    = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

local minimapMenu = CreateFrame("Frame", "SimpleDungeonXPMinimapMenu", UIParent)
minimapMenu:SetWidth(140)
minimapMenu:SetHeight(106)
minimapMenu:SetFrameStrata("TOOLTIP")
minimapMenu:SetClampedToScreen(true)
minimapMenu:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
minimapMenu:SetBackdropColor(0.04, 0.06, 0.07, 0.96)
minimapMenu:Hide()
table.insert(UISpecialFrames, "SimpleDungeonXPMinimapMenu")

local function CreateTimerMenuButton(text, index, action)
    local button = CreateFrame("Button", nil, minimapMenu)
    button:SetWidth(128)
    button:SetHeight(22)
    button:SetPoint("TOP", minimapMenu, "TOP", 0, -4 - ((index - 1) * 24))
    button:EnableMouse(true)

    button.highlight = button:CreateTexture(nil, "BACKGROUND")
    button.highlight:SetAllPoints(button)
    button.highlight:SetTexture(1, 1, 1, 0.14)
    button.highlight:Hide()

    button.label = button:CreateFontString(nil, "OVERLAY")
    button.label:SetPoint("LEFT", button, "LEFT", 12, 0)
    button.label:SetFont("Fonts\\FRIZQT__.TTF", 12)
    button.label:SetText(text)
    button.label:SetTextColor(0.92, 0.92, 0.92)

    button:SetScript("OnEnter", function(self)
        self.highlight:Show()
        self.label:SetTextColor(1, 0.82, 0)
    end)
    button:SetScript("OnLeave", function(self)
        self.highlight:Hide()
        self.label:SetTextColor(0.92, 0.92, 0.92)
    end)
    button:SetScript("OnClick", function()
        action()
        minimapMenu:Hide()
    end)
    return button
end

CreateTimerMenuButton("Show", 1, SimpleDungeonXPTimer_Show)
CreateTimerMenuButton("Hide", 2, SimpleDungeonXPTimer_Hide)
CreateTimerMenuButton("Lock", 3, SimpleDungeonXPTimer_Lock)
CreateTimerMenuButton("Unlock", 4, SimpleDungeonXPTimer_Unlock)

local function ToggleMinimapMenu()
    if minimapMenu:IsShown() then
        minimapMenu:Hide()
        return
    end

    local cursorX, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    minimapMenu:ClearAllPoints()
    minimapMenu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", cursorX / scale, cursorY / scale)
    minimapMenu:Show()
end

local minimapObject = LDB:NewDataObject(
    "SimpleDungeonXP",
    {
        type  = "launcher",
        text  = "Simple Dungeon XP",
        icon  = "Interface\\AddOns\\SimpleDungeonXP\\simpledungeonxp",
        OnClick = function(self, button)
            if button == "RightButton" then
                ToggleMinimapMenu()
            elseif button == "LeftButton" then
                if frame:IsShown() then
                    frame:Hide()
                else
                    UpdateWindow()
                    frame:Show()
                end
            end
        end,
        OnTooltipShow = function(tooltip)
            tooltip:AddLine("Simple Dungeon XP")
            tooltip:AddLine("/sdxp - open window")
        end
    }
)

SimpleDungeonXPMinimapDB = SimpleDungeonXPMinimapDB or {
        minimapPos = 225,
    }

DBIcon:Register(
    "SimpleDungeonXP",
    minimapObject,
    SimpleDungeonXPMinimapDB
)
