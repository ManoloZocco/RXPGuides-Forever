-- Minimal fake WoW API for tests. Stubs.install(opts) defines globals; the runner
-- rolls them back after each test.
--
-- opts.talents  = { [tab] = { { name=, tier=, column=, maxRank=, rank= }, ... } }
-- opts.tabNames = { [tab] = "Feral Combat" }
-- opts.modernTabInfo = true  -> GetTalentTabInfo returns id, name, ... (11.x order)
-- opts.spells   = { [spellID] = "Spell Name" }
-- opts.noGetSpellInfo = true  -> only C_Spell.GetSpellName exists
-- opts.class (token, default "DRUID"), opts.level (default 10), opts.playerName
-- opts.addonEnableState = number (C_AddOns.GetAddOnEnableState result)
-- opts.legacyAddonApi = true  -> no C_AddOns; global GetAddOnEnableState(char, addon)
-- opts.talentGroups (default 1), opts.activeTalentGroup (default 1)

local Stubs = {}

local function newFontString()
    local fs = { shown = true, text = nil, points = {} }
    function fs:SetText(t) self.text = t end
    function fs:GetText() return self.text end
    function fs:Show() self.shown = true end
    function fs:Hide() self.shown = false end
    function fs:IsShown() return self.shown end
    function fs:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function fs:ClearAllPoints() self.points = {} end
    function fs:SetWidth() end
    function fs:SetJustifyH() end
    function fs:SetTextColor() end
    return fs
end

function Stubs.newFrame(name)
    local f = { name = name, events = {}, scripts = {}, shown = true, children = {}, points = {} }
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:GetScript(k) return self.scripts[k] end
    function f:HookScript(k, fn)
        local prev = self.scripts[k]
        self.scripts[k] = function(...) if prev then prev(...) end fn(...) end
    end
    function f:CreateFontString()
        local fs = newFontString()
        self.children[#self.children + 1] = fs
        return fs
    end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function f:SetParent(p) self.parent = p end
    return f
end

function Stubs.install(opts)
    opts = opts or {}
    local ctx = { frames = {}, opts = opts }
    local talents = opts.talents or {}

    _G.GetNumTalentTabs = function() return #talents end
    _G.GetNumTalents = function(tab) return talents[tab] and #talents[tab] or 0 end
    _G.GetTalentInfo = function(tab, i)
        local t = talents[tab] and talents[tab][i]
        if not t then return nil end
        return t.name, "icon", t.tier, t.column, t.rank or 0, t.maxRank
    end
    _G.GetTalentTabInfo = function(tab)
        local name = opts.tabNames and opts.tabNames[tab] or ("Tab" .. tab)
        if opts.modernTabInfo then return 100 + tab, name, "desc", "icon", 0 end
        return name, "icon", 0, "bg"
    end

    local spells = opts.spells or {}
    if opts.noGetSpellInfo then
        _G.GetSpellInfo = nil
    else
        _G.GetSpellInfo = function(id) return spells[id], nil, "icon" end
    end
    _G.C_Spell = { GetSpellName = function(id) return spells[id] end }

    _G.UnitClass = function() return "Class", opts.class or "DRUID" end
    _G.UnitLevel = function() return opts.level or 10 end
    _G.UnitName = function() return opts.playerName or "Tester" end
    _G.GetNumTalentGroups = function() return opts.talentGroups or 1 end
    _G.GetActiveTalentGroup = function() return opts.activeTalentGroup or 1 end

    if opts.legacyAddonApi then
        _G.C_AddOns = nil
        _G.GetAddOnEnableState = function(char, addon)
            ctx.legacyArgs = { char, addon }
            return opts.addonEnableState or 0
        end
    else
        _G.C_AddOns = {
            GetAddOnEnableState = function(addon, char)
                ctx.modernArgs = { addon, char }
                return opts.addonEnableState or 0
            end,
        }
    end

    _G.print = function(...)
        ctx.printed = ctx.printed or {}
        local parts = {}
        for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
        ctx.printed[#ctx.printed + 1] = table.concat(parts, " ")
    end

    _G.CreateFrame = function(_, name, parent)
        local f = Stubs.newFrame(name)
        f.parent = parent
        ctx.frames[#ctx.frames + 1] = f
        if name then _G[name] = f end
        return f
    end

    -- Deliver an event to every stub frame registered for it.
    function ctx.fire(event, ...)
        for _, f in ipairs(ctx.frames) do
            if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
        end
    end

    return ctx
end

return Stubs
