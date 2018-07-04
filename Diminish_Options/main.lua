local _, NS = ...
local Widgets = NS.Widgets
local Panel = NS.Panel
local TestMode = NS.TestMode
local L = NS.L

NS.PLAYER_NAME = UnitName("player") .. "-" .. GetRealmName()

NS.unitFrames = {
    [L.PLAYER] = "player", -- localized, unlocalized unitID
    [L.TARGET] = "target",
    [L.FOCUS] = "focus",
    [L.PARTY] = "party",
    [L.ARENA] = "arena",
}

-- Proxy table for diminish savedvariables
-- Was originally used to automatically create a new DB profile on any DB option change,
-- now it's just a lazy way to keep correct db reference to DiminishDB profile
NS.GetDBProxy = function(key1, key2, key3)
    return setmetatable({}, {
        __index = function(self, key)
            if key3 then -- proxy for nested tables
                return DIMINISH_NS.db[key1][key2][key3][key]
            elseif key2 then
                return DIMINISH_NS.db[key1][key2][key]
            elseif key1 then
                return DIMINISH_NS.db[key1][key]
            else
                return DIMINISH_NS.db[key]
            end
        end,

        __newindex = function(self, key, value)
            local tbl
            if key3 then
                tbl = DIMINISH_NS.db[key1][key2][key3]
            elseif key2 then
                tbl = DIMINISH_NS.db[key1][key2]
            elseif key1 then
                tbl = DIMINISH_NS.db[key1]
            else
                tbl = DIMINISH_NS.db
            end
            tbl[key] = value
        end,
    })
end

function Panel:Setup()
    local Icons = DIMINISH_NS.Icons
    local frames = self.frames
    local db = NS.GetDBProxy()

    local notes = GetAddOnMetadata(self.name, "Notes-" .. GetLocale()) or GetAddOnMetadata(self.name, "Notes")
    Widgets:CreateHeader(self, gsub(self.name, "_", " "), GetAddOnMetadata("Diminish", "Version"), notes)

    local subCooldown = Widgets:CreateSubHeader(self, L.HEADER_COOLDOWN)
    subCooldown:SetPoint("TOPLEFT", 16, -50)


    frames.displayMode = Widgets:CreateCheckbox(self, L.DISPLAYMODE, L.DISPLAYMODE_TOOLTIP, function(cb)
        db.displayMode = cb:GetChecked() and "ON_AURA_START" or "ON_AURA_END"
    end)
    frames.displayMode:SetPoint("LEFT", subCooldown, 10, -70)


    frames.timerSwipe = Widgets:CreateCheckbox(self, L.TIMERSWIPE, L.TIMERSWIPE_TOOLTIP, function()
        db.timerSwipe = not db.timerSwipe
        Icons:OnFrameConfigChanged()
    end)
    frames.timerSwipe:SetPoint("LEFT", frames.displayMode, 0, -40)


    frames.timerText = Widgets:CreateCheckbox(self, L.TIMERTEXT, L.TIMERTEXT_TOOLTIP, function()
        Widgets:ToggleState(frames.timerColors, frames.timerText:GetChecked())
        Widgets:ToggleState(frames.timerTextSize, frames.timerText:GetChecked())

        db.timerText = not db.timerText
        Icons:OnFrameConfigChanged()
    end)
    frames.timerText:SetPoint("LEFT", frames.timerSwipe, 0, -40)


    frames.timerColors = Widgets:CreateCheckbox(self, L.TIMERCOLORS, L.TIMERCOLORS_TOOLTIP, function()
        db.timerColors = not db.timerColors
        Icons:OnFrameConfigChanged()
        DIMINISH_NS.Timers:ResetAll()
    end)
    frames.timerColors:SetPoint("LEFT", frames.timerText, 15, -40)


    frames.timerTextSize = Widgets:CreateSlider(self, L.TIMERTEXTSIZE, L.TIMERTEXTSIZE_TOOLTIP, 7, 35, 1, function(_, value)
        db.timerTextSize = value
        Icons:OnFrameConfigChanged()
    end)
    frames.timerTextSize:SetPoint("LEFT", frames.timerColors, 10, -50)

    -------------------------------------------------------------------

    local subMisc = Widgets:CreateSubHeader(self, L.HEADER_MISC)
    subMisc:SetPoint("TOPRIGHT", -64, -50)


    frames.showCategoryText = Widgets:CreateCheckbox(self, L.SHOWCATEGORYTEXT, L.SHOWCATEGORYTEXT_TOOLTIP, function(cb)
        db.showCategoryText = not db.showCategoryText
        Icons:OnFrameConfigChanged()
    end)
    frames.showCategoryText:SetPoint("RIGHT", -225, 160)


    frames.trackNPCs = Widgets:CreateCheckbox(self, L.TRACKNPCS, L.TRACKNPCS_TOOLTIP, function()
        db.trackNPCs = not db.trackNPCs

        for _, unit in pairs({ "target", "focus" }) do
            local cfg = db.unitFrames[unit]
            cfg.disabledCategories[DIMINISH_NS.CATEGORIES.TAUNT] = not db.trackNPCs
            cfg.zones.party = db.trackNPCs
            cfg.zones.scenario = db.trackNPCs
            cfg.zones.raid = db.trackNPCs
        end

        DIMINISH_NS.Diminish:ToggleForZone()
    end)
    frames.trackNPCs:SetPoint("LEFT", frames.showCategoryText, 0, -40)

    frames.spellBookTextures = Widgets:CreateCheckbox(self, L.SPELLBOOKTEXTURES, L.SPELLBOOKTEXTURES_TOOLTIP, function()
        db.spellBookTextures = not db.spellBookTextures
    end)
    frames.spellBookTextures:SetPoint("LEFT", frames.trackNPCs, 0, -40)

    frames.colorBlind = Widgets:CreateCheckbox(self, L.COLORBLIND, format(L.COLORBLIND_TOOLTIP, L.TIMERTEXT), function()
        db.colorBlind = not db.colorBlind
        Icons:OnFrameConfigChanged()
    end)
    frames.colorBlind:SetPoint("LEFT", frames.spellBookTextures, 0, -40)


    do
        local textures = {
            { text = L.DEFAULT, value = {
                edgeFile = "Interface\\BUTTONS\\UI-Quickslot-Depress",
                layer = "BORDER",
                edgeSize = 2.5,
                name = L.DEFAULT, -- keep a reference to text in db so we can set correct dropdown value on login
            }},

            { text = L.TEXTURE_GLOW, value = {
                edgeFile = "Interface\\BUTTONS\\UI-Quickslot-Depress",
                layer = "OVERLAY",
                edgeSize = 1,
                name = L.TEXTURE_GLOW,
            }},

            { text = L.TEXTURE_BRIGHT, value = {
                edgeFile = "Interface\\BUTTONS\\WHITE8X8",
                --isBackdrop = true,
                edgeSize = 1.5,
                layer = "BORDER",
                name = L.TEXTURE_BRIGHT,
            }},

            { text = L.TEXTURE_NONE, value = {
                layer = "BORDER",
                edgeFile = "",
                edgeSize = 0,
                name = L.TEXTURE_NONE,
            }},
        }

        frames.border = LibStub("PhanxConfig-Dropdown").CreateDropdown(self, L.SELECTBORDER, L.SELECTBORDER_TOOLTIP, textures)
        frames.border:SetPoint("LEFT", frames.colorBlind, 7, -55)
        frames.border:SetWidth(180)

        frames.border.OnValueChanged = function(self, value)
            if not value or value == EMPTY then return end
            db.border = value
            Icons:OnFrameConfigChanged()
        end
    end

    -------------------------------------------------------------------

    local tip = self:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
    tip:SetJustifyH("LEFT")
    tip:SetText(L.TARGETTIP)
    tip:SetPoint("CENTER", self, 0, -220)
    tip:Hide()


    -- Show drag anchors
    local unlock = Widgets:CreateButton(self, L.UNLOCK, L.UNLOCK_TOOLTIP, function(btn)
        if InCombatLockdown() then
            return print(L.COMBATLOCKDOWN_ERROR)
        end

        if btn:GetText() == L.UNLOCK then
            btn:SetText(L.STOP)
            if DIMINISH_NS.db.unitFrames.target.enabled or DIMINISH_NS.db.unitFrames.focus.enabled then
                tip:Show()
            end
            TestMode:ShowAnchors()
        else
            TestMode:HideAnchors()
            btn:SetText(L.UNLOCK)
            tip:Hide()
        end
    end)
    unlock:SetPoint("BOTTOMLEFT", self, 15, 15)
    unlock:SetSize(200, 25)


    -- Test mode for timers
    local testBtn = Widgets:CreateButton(self, L.TEST, L.TEST_TOOLTIP, function(btn)
        if InCombatLockdown() then
            return print(L.COMBATLOCKDOWN_ERROR)
        end

        btn:SetText(btn:GetText() == L.TEST and L.STOP or L.TEST)
        if DIMINISH_NS.db.unitFrames.target.enabled or DIMINISH_NS.db.unitFrames.focus.enabled or tip:IsShown() then
            tip:SetShown(btn:GetText() ~= L.TEST)
        end
        TestMode:Test()
    end)
    testBtn:SetSize(200, 25)
    --testBtn:SetAttribute("type", "macro")
    --testBtn:SetAttribute("macrotext", "/target [@player]\n/focus [@player]\n/diminishtest")
    testBtn:SetPoint("BOTTOMRIGHT", self, -15, 15)
end

function Panel:refresh()
    local frames = self.frames

    -- Refresh value of all widgets
    for setting, value in pairs(DIMINISH_NS.db) do
        if frames[setting] then
            if frames[setting]:IsObjectType("Slider") then
                frames[setting]:SetValue(value)
            elseif frames[setting]:IsObjectType("CheckButton") then
                if value == "ON_AURA_END" then
                    value = false
                elseif value == "ON_AURA_START" then
                    value = true
                end
                frames[setting]:SetChecked(value)
            elseif frames[setting].items then -- phanx dropdown
                frames[setting]:SetValue(value.name)
            end
        end
    end

    -- Disable rest of timer options if timer countdown is not checked
    Widgets:ToggleState(frames.timerColors, frames.timerText:GetChecked())
    Widgets:ToggleState(frames.timerTextSize, frames.timerText:GetChecked())
end

SLASH_DIMINISH1 = "/diminish"
SlashCmdList.DIMINISH = function()
    InterfaceOptionsFrame_OpenToCategory(Panel)
    InterfaceOptionsFrame_OpenToCategory(Panel) -- double to fix blizz bug
end
