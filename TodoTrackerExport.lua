-- Todo Tracker: pixel export for external tools (e.g. WoW-Companion).
-- Addons cannot write files or talk to the network, so the current ToDo
-- list is rendered as a strip of coloured blocks in the top-left corner
-- of the screen; a companion app reads it via screen capture.
--
-- Wire format (bytes): "TD" | version(1) | seq(2) | payloadLen(2) | crc8(1)
--                      | nameLen(1) name | realmLen(1) realm | count(1)
--                      | per todo: flags(1, bit0 = done) | textLen(1) | text
-- Bytes are split into base-4 digits (4 per byte); every block carries 3
-- digits as R/G/B using only 4 brightness LEVELS (0.10 .. 0.52, never pure
-- black). Real displays apply gain/gamma/HDR mapping (measured: x1.9 with
-- clipping above ~0.5), so 16 levels are not distinguishable everywhere;
-- 4 well-spaced levels survive. The strip starts with a CALIBRATION RAMP
-- of the 4 grey levels so the reader can learn the actual mapping.
-- Blocks are BLOCK_PX physical pixels wide/high.

local BLOCK_PX = 4         -- physical pixels per block
local COLS = 128           -- blocks per row (512 px wide at BLOCK_PX = 4)
local MAX_ROWS = 8
local MAX_TEXT = 80        -- bytes per ToDo text
local VERSION = 3          -- 3 = base-4 digits, 4 levels, 4-block calibration ramp
local LEVELS = { 0.10, 0.24, 0.38, 0.52 }
local RAMP = #LEVELS       -- calibration blocks before the data
local TICK = 1.0           -- seconds between change checks

local exportFrame = CreateFrame("Frame", "TodoTrackerExportFrame", UIParent)
exportFrame:SetFrameStrata("TOOLTIP")
exportFrame:SetFrameLevel(10000)
exportFrame:EnableMouse(false)
exportFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
exportFrame:Hide()

local textures = {}
local lastBlob, seq = nil, 0

local function BlockSize()
    local _, physH = GetPhysicalScreenSize()
    local unitsPerPhysicalPixel = 768 / physH / exportFrame:GetEffectiveScale()
    return BLOCK_PX * unitsPerPhysicalPixel
end

local function Crc8(s)
    local crc = 0
    for i = 1, #s do
        crc = bit.bxor(crc, s:byte(i))
        for _ = 1, 8 do
            if bit.band(crc, 0x80) ~= 0 then
                crc = bit.band(bit.bxor(bit.lshift(crc, 1), 0x07), 0xFF)
            else
                crc = bit.band(bit.lshift(crc, 1), 0xFF)
            end
        end
    end
    return crc
end

local function U16(n) return string.char(bit.band(bit.rshift(n, 8), 0xFF), bit.band(n, 0xFF)) end

local function Serialize()
    local db = TodoTrackerDB
    if not db or not db.todos then return nil end
    local name = (UnitName("player") or ""):sub(1, 40)
    local realm = (GetRealmName() or ""):sub(1, 40)
    local parts = { string.char(#name), name, string.char(#realm), realm }
    local count = math.min(#db.todos, 255)
    parts[#parts + 1] = string.char(count)
    for i = 1, count do
        local t = db.todos[i]
        local text = tostring(t.text or ""):sub(1, MAX_TEXT)
        parts[#parts + 1] = string.char(t.done and 1 or 0, #text) .. text
    end
    return table.concat(parts)
end

local function Render(payload)
    local blob = "TD" .. string.char(VERSION) .. U16(seq) .. U16(#payload) .. string.char(Crc8(payload)) .. payload
    -- bytes -> base-4 digits -> blocks (3 digits each)
    local digits = {}
    for i = 1, #blob do
        local b = blob:byte(i)
        digits[#digits + 1] = bit.band(bit.rshift(b, 6), 3)
        digits[#digits + 1] = bit.band(bit.rshift(b, 4), 3)
        digits[#digits + 1] = bit.band(bit.rshift(b, 2), 3)
        digits[#digits + 1] = bit.band(b, 3)
    end
    while #digits % 3 ~= 0 do digits[#digits + 1] = 0 end
    local nBlocks = RAMP + #digits / 3
    local rows = math.ceil(nBlocks / COLS)
    if rows > MAX_ROWS then return false end
    local size = BlockSize()
    exportFrame:SetSize(COLS * size, rows * size)
    for b = 1, nBlocks do
        local tex = textures[b]
        if not tex then
            tex = exportFrame:CreateTexture(nil, "OVERLAY")
            textures[b] = tex
        end
        local col, row = (b - 1) % COLS, math.floor((b - 1) / COLS)
        tex:ClearAllPoints()
        tex:SetPoint("TOPLEFT", exportFrame, "TOPLEFT", col * size, -row * size)
        tex:SetSize(size, size)
        if b <= RAMP then
            local g = LEVELS[b]
            tex:SetColorTexture(g, g, g, 1)      -- calibration ramp
        else
            local n = (b - RAMP - 1) * 3
            tex:SetColorTexture(LEVELS[digits[n + 1] + 1], LEVELS[digits[n + 2] + 1], LEVELS[digits[n + 3] + 1], 1)
        end
        tex:Show()
    end
    for b = nBlocks + 1, #textures do textures[b]:Hide() end
    return true
end

local function Enabled()
    return TodoTrackerDB and TodoTrackerDB.export ~= false
end

local function Update(force)
    if not Enabled() then exportFrame:Hide(); return end
    local payload = Serialize()
    if not payload then return end
    if force or payload ~= lastBlob then
        if payload ~= lastBlob then seq = (seq + 1) % 65536 end
        lastBlob = payload
        if Render(payload) then exportFrame:Show() else exportFrame:Hide() end
    end
end

local elapsed = 0
exportFrame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= TICK then
        elapsed = 0
        Update(false)
    end
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("UI_SCALE_CHANGED")
events:RegisterEvent("DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function()
    if TodoTrackerDB then
        lastBlob = nil
        Update(true)
        -- the OnUpdate only runs while shown; keep a ticker for re-enabling
        if not events.ticker then
            events.ticker = C_Timer.NewTicker(TICK, function() if not exportFrame:IsShown() then Update(false) end end)
        end
    end
end)

-- Slash: /todo export on|off|status  (hooks into the existing handler)
local previous = SlashCmdList["TODOTRACKER"]
SlashCmdList["TODOTRACKER"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
    if (cmd or ""):lower() == "export" then
        rest = (rest or ""):lower()
        if rest == "on" then TodoTrackerDB.export = true; lastBlob = nil; Update(true)
        elseif rest == "off" then TodoTrackerDB.export = false; Update(true) end
        DEFAULT_CHAT_FRAME:AddMessage("|cFFFFD100Todo Tracker|r pixel export: " ..
            (Enabled() and "|cFF00FF00on|r" or "|cFFFF4040off|r") ..
            " (|cFFFFD100/todo export on|off|r)")
        return
    end
    if previous then previous(msg) end
end
