-- Todo Tracker: small ToDo list styled after the Questie tracker.
-- Transparent while idle (backdrop only on mouseover), freely movable
-- via the title bar; position and ToDos are saved per character.
-- Adding: plus button next to the title (inline input) or Alt+D
-- (centered quick-add; Enter adds and clears the field, Escape closes).
-- Slash commands: /todo (quick-add), /todo add <text>, /todo help.
-- The window is hidden while the list is empty.

local GOLD = "|cFFFFD100"
local WHITE = "|cFFEEEEEE"
local GREY = "|cFFA6A6A6"
local R = "|r"

local FRAME_WIDTH = 240
local ROW_HEIGHT = 20
local TITLE_HEIGHT = 24

-- Labels for the key bindings UI (category ADDONS, see Bindings.xml)
BINDING_HEADER_TODOTRACKER = "Todo Tracker"
_G["BINDING_NAME_TODOTRACKER_QUICKADD"] = "Quick-add a ToDo"
_G["BINDING_NAME_TODOTRACKER_QUICKADD_MULTI"] = "Quick-add several ToDos (stays open)"

local DB  -- points to TodoTrackerDB after ADDON_LOADED
local AddTodo, ToggleTodo, DeleteTodo, Redraw

------------------------------------------------------------------------
-- Main frame (Questie recipe: invisible, backdrop only on mouseover)
------------------------------------------------------------------------
local frame = CreateFrame("Frame", "TodoTrackerFrame", UIParent,
    BackdropTemplateMixin and "BackdropTemplate")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetSize(FRAME_WIDTH, 32)
frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
-- Idle state: slightly darkened, border invisible; stronger on mouseover
frame:SetBackdropColor(0, 0, 0, 0.25)
frame:SetBackdropBorderColor(1, 1, 1, 0)

local function Unfade()
    frame:SetBackdropColor(0, 0, 0, 0.5)
    frame:SetBackdropBorderColor(1, 1, 1, 0.5)
end

local function Fade()
    -- Guard: don't flicker when moving between child frames
    if MouseIsOver(frame) then return end
    frame:SetBackdropColor(0, 0, 0, 0.25)
    frame:SetBackdropBorderColor(1, 1, 1, 0)
end

frame:EnableMouse(true)
frame:SetScript("OnEnter", Unfade)
frame:SetScript("OnLeave", Fade)

local function SavePosition()
    local point, _, relPoint, x, y = frame:GetPoint()
    DB.pos = { point, relPoint, x, y }
end

local function RestorePosition()
    frame:ClearAllPoints()
    local ok = DB.pos and pcall(frame.SetPoint, frame,
        DB.pos[1], UIParent, DB.pos[2], DB.pos[3], DB.pos[4])
    if not ok then
        DB.pos = nil
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -100, 0)
    end
end

------------------------------------------------------------------------
-- Title bar: sole drag handle + plus button
------------------------------------------------------------------------
local titleBar = CreateFrame("Button", nil, frame)
titleBar:SetPoint("TOPLEFT", 0, 0)
titleBar:SetPoint("TOPRIGHT", 0, 0)
titleBar:SetHeight(TITLE_HEIGHT)
titleBar:RegisterForDrag("LeftButton")
titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
titleBar:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SavePosition()
end)
titleBar:SetScript("OnEnter", Unfade)
titleBar:SetScript("OnLeave", Fade)

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetPoint("TOPLEFT", 8, -6)
titleText:SetText(GOLD .. "ToDo" .. R)

local plusBtn = CreateFrame("Button", nil, titleBar)
plusBtn:SetSize(16, 16)
plusBtn:SetPoint("LEFT", titleText, "RIGHT", 6, 0)
plusBtn:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
plusBtn:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
plusBtn:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight", "ADD")
plusBtn:SetScript("OnEnter", Unfade)
plusBtn:SetScript("OnLeave", Fade)

------------------------------------------------------------------------
-- Inline input below the title bar (plus button)
------------------------------------------------------------------------
local inlineEdit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
inlineEdit:SetHeight(20)
inlineEdit:SetAutoFocus(false)
inlineEdit:SetMaxLetters(120)
inlineEdit:Hide()

local function CloseInlineEdit()
    inlineEdit:SetText("")
    inlineEdit:ClearFocus()
    inlineEdit:Hide()
    Redraw()
end

inlineEdit:SetScript("OnEnterPressed", function(self)
    local text = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" then AddTodo(text) end
    CloseInlineEdit()
end)
inlineEdit:SetScript("OnEscapePressed", CloseInlineEdit)
inlineEdit:HookScript("OnEditFocusLost", function(self)
    if self:IsShown() then CloseInlineEdit() end
end)

plusBtn:SetScript("OnClick", function()
    if inlineEdit:IsShown() then
        CloseInlineEdit()
    else
        inlineEdit:Show()
        Redraw()
        inlineEdit:SetFocus()
    end
end)

------------------------------------------------------------------------
-- Row pool + redraw (single mutation sink, pattern: KamisayoRotation)
------------------------------------------------------------------------
local rows = {}

local function AcquireRow(i)
    local row = rows[i]
    if not row then
        row = CreateFrame("Button", nil, frame)
        row:SetSize(FRAME_WIDTH - 8, ROW_HEIGHT)
        row:RegisterForClicks("RightButtonUp")
        row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then DeleteTodo(self.index) end
        end)
        row:SetScript("OnEnter", function(self)
            Unfade()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Right-click to delete", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
            Fade()
        end)

        row.check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
        row.check:SetSize(24, 24)
        row.check:SetPoint("LEFT", 2, 0)
        row.check:SetScript("OnClick", function(self)
            ToggleTodo(row.index, self:GetChecked())
        end)
        row.check:SetScript("OnEnter", Unfade)
        row.check:SetScript("OnLeave", Fade)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row.check, "RIGHT", 2, 0)
        row.text:SetWidth(FRAME_WIDTH - 40)
        row.text:SetJustifyH("LEFT")
        row.text:SetWordWrap(false)  -- single line, long titles end with "..."

        rows[i] = row
    end
    row:Show()
    return row
end

Redraw = function()
    -- Empty list: hide the window entirely (the first ToDo arrives via
    -- Alt+D); an open inline input counts as "not empty" so the window
    -- stays visible while typing
    if #DB.todos == 0 and not inlineEdit:IsShown() then
        frame:Hide()
        return
    end
    frame:Show()

    local y = -(TITLE_HEIGHT + 2)
    if inlineEdit:IsShown() then
        inlineEdit:ClearAllPoints()
        inlineEdit:SetPoint("TOPLEFT", 12, y)
        inlineEdit:SetPoint("TOPRIGHT", -8, y)
        y = y - 24
    end
    for i, todo in ipairs(DB.todos) do
        local row = AcquireRow(i)
        row.index = i
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 4, y)
        row.check:SetChecked(todo.done)
        row.text:SetText((todo.done and GREY or WHITE) .. todo.text .. R)
        y = y - ROW_HEIGHT
    end
    for i = #DB.todos + 1, #rows do
        rows[i]:Hide()
    end
    frame:SetHeight(math.max(32, -y + 6))
end

------------------------------------------------------------------------
-- Mutation handlers
------------------------------------------------------------------------
AddTodo = function(text)
    table.insert(DB.todos, { text = text, done = false })
    Redraw()
end

ToggleTodo = function(i, checked)
    if DB.todos[i] then
        DB.todos[i].done = checked and true or false
        Redraw()
    end
end

DeleteTodo = function(i)
    if DB.todos[i] then
        table.remove(DB.todos, i)
        Redraw()
    end
end

------------------------------------------------------------------------
-- Quick-add: centered input via Alt+D (see Bindings.xml)
------------------------------------------------------------------------
local quickFrame = CreateFrame("Frame", "TodoTrackerQuickAdd", UIParent,
    BackdropTemplateMixin and "BackdropTemplate")
quickFrame:SetSize(320, 52)
quickFrame:SetPoint("CENTER", 0, 150)
quickFrame:SetFrameStrata("DIALOG")
quickFrame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
quickFrame:SetBackdropColor(0, 0, 0, 0.85)
quickFrame:SetBackdropBorderColor(1, 1, 1, 0.7)
quickFrame:Hide()

local quickLabel = quickFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
quickLabel:SetPoint("TOPLEFT", 12, -8)
quickLabel:SetText(GOLD .. "New ToDo" .. R)

local quickEdit = CreateFrame("EditBox", nil, quickFrame, "InputBoxTemplate")
quickEdit:SetHeight(20)
quickEdit:SetPoint("TOPLEFT", 16, -24)
quickEdit:SetPoint("TOPRIGHT", -10, -24)
quickEdit:SetAutoFocus(false)
quickEdit:SetMaxLetters(120)

local function CloseQuickAdd()
    quickEdit:SetText("")
    quickEdit:ClearFocus()
    quickFrame:Hide()
end

-- Enter adds the ToDo. In "several" mode the field is only cleared so
-- more ToDos can follow (Escape closes); in single mode the dialog closes.
local multiMode = true
quickEdit:SetScript("OnEnterPressed", function(self)
    local text = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    if text ~= "" then AddTodo(text) end
    if multiMode then
        self:SetText("")
    else
        CloseQuickAdd()
    end
end)
quickEdit:SetScript("OnEscapePressed", CloseQuickAdd)
quickEdit:HookScript("OnEditFocusLost", function()
    if quickFrame:IsShown() then CloseQuickAdd() end
end)

-- The keypress that triggers the binding (Alt+D) still lands as the
-- character "d" in the edit box after SetFocus -- so discard the first
-- character during the opening frame (the flag expires next frame)
local suppressChar = false
quickEdit:SetScript("OnChar", function(self)
    if suppressChar then
        suppressChar = false
        self:SetText("")
    end
end)

local function OpenQuickAdd(several)
    multiMode = several and true or false
    quickLabel:SetText(GOLD .. "New ToDo" .. R .. GREY ..
        (multiMode and "  (Enter adds, Esc closes)" or "  (Enter adds & closes)") .. R)
    quickFrame:Show()
    quickEdit:SetText("")
    quickEdit:SetFocus()
    suppressChar = true
    C_Timer.After(0, function() suppressChar = false end)
end

-- Globals: called by the key bindings (Bindings.xml) and /todo
function TodoTracker_ShowQuickAdd()        -- Alt+D: one ToDo, closes after Enter
    if not DB then return end  -- not ready before ADDON_LOADED
    OpenQuickAdd(false)
end

function TodoTracker_ShowQuickAddMulti()   -- Alt+Shift+D: several, Esc closes
    if not DB then return end
    OpenQuickAdd(true)
end

------------------------------------------------------------------------
-- Slash command: /todo help (features + interactions as a list)
------------------------------------------------------------------------
local function PrintHelp()
    local function line(msg) DEFAULT_CHAT_FRAME:AddMessage(msg) end
    line(GOLD .. "Todo Tracker" .. R .. GREY .. " -- commands & usage:" .. R)
    line(GOLD .. " - /todo add <text>" .. R .. WHITE .. " -- add a new ToDo" .. R)
    line(GOLD .. " - /todo" .. R .. WHITE .. " or " .. GOLD .. "Alt+D" .. R .. WHITE ..
        " -- quick-add one ToDo (Enter adds and closes)" .. R)
    line(GOLD .. " - /todo help" .. R .. WHITE .. " -- show this help" .. R)
    line(GOLD .. " - /todo multi" .. R .. WHITE .. " or " .. GOLD .. "Alt+Shift+D" .. R .. WHITE ..
        " -- quick-add several ToDos in a row (stays open, Esc closes)" .. R)
    line(GOLD .. " - /todo export on|off" .. R .. WHITE ..
        " -- pixel export for companion apps (top-left colour strip)" .. R)
    line(GREY .. " In the window:" .. R)
    line(WHITE .. " - " .. GOLD .. "Plus button" .. R .. WHITE ..
        " next to the title -- inline input for adding" .. R)
    line(WHITE .. " - " .. GOLD .. "Checkbox" .. R .. WHITE .. " -- mark a ToDo as done" .. R)
    line(WHITE .. " - " .. GOLD .. "Right-click" .. R .. WHITE .. " a row -- delete the ToDo" .. R)
    line(WHITE .. " - " .. GOLD .. "Drag the title bar" .. R .. WHITE ..
        " -- move the window (position is saved per character)" .. R)
    line(GREY .. " The window is hidden while the list is empty; it is" ..
        " transparent and only highlighted on mouseover." .. R)
end

SLASH_TODOTRACKER1 = "/todo"
SlashCmdList["TODOTRACKER"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = msg:match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    if cmd == "help" or cmd == "?" then
        PrintHelp()
    elseif cmd == "add" and rest ~= "" then
        if DB then AddTodo(rest) end
    elseif cmd == "multi" then
        TodoTracker_ShowQuickAddMulti()
    elseif cmd == "" then
        TodoTracker_ShowQuickAdd()
    else
        PrintHelp()
    end
end

------------------------------------------------------------------------
-- Events: DB init, position restore, one-time auto-bind to Alt+D
------------------------------------------------------------------------
local function TryAutoBind()
    if InCombatLockdown() then return false end
    local action = GetBindingAction("ALT-D") or ""
    -- "KAMISAYOTODO_QUICKADD" = orphaned binding from the addon's old name
    if not GetBindingKey("TODOTRACKER_QUICKADD")
        and (action == "" or action == "KAMISAYOTODO_QUICKADD") then
        SetBinding("ALT-D", "TODOTRACKER_QUICKADD")
        SaveBindings(GetCurrentBindingSet())
    end
    if not GetBindingKey("TODOTRACKER_QUICKADD_MULTI") and (GetBindingAction("ALT-SHIFT-D") or "") == "" then
        SetBinding("ALT-SHIFT-D", "TODOTRACKER_QUICKADD_MULTI")
        SaveBindings(GetCurrentBindingSet())
    end
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "TodoTracker" then return end
        self:UnregisterEvent("ADDON_LOADED")
        TodoTrackerDB = TodoTrackerDB or {}
        DB = TodoTrackerDB
        DB.todos = DB.todos or {}
        RestorePosition()
        Redraw()
    elseif event == "PLAYER_LOGIN" then
        -- Auto-bind only once: if the user removes the binding later,
        -- that choice is respected
        if DB and not DB.boundOnce2 then
            DB.boundOnce, DB.boundOnce2 = true, true
            if not TryAutoBind() then
                self:RegisterEvent("PLAYER_REGEN_ENABLED")
            end
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        TryAutoBind()
    end
end)
