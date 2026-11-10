if RXP_SGJ_DISABLED then return end
local _, MSC = "RXPGuides", RXP_SGJ_NS

-- =============================================================
-- Raid / World Buff Assumption Engine (all versions)
-- The buffs themselves (what each one adds, by rank) are in Buffs_<version>.lua
-- (MSC.BuffList). TBC also has hit credits for Totem of Wrath, Improved Faerie
-- Fire and Draenei, used by its rating caps.
-- =============================================================

MSC.BuffEngine = MSC.BuffEngine or {}
local BE = MSC.BuffEngine

local pairs, ipairs = pairs, ipairs
local math_max, math_min = math.max, math.min
local wipe = wipe or table.wipe
local UnitRace = UnitRace
local UnitLevel = UnitLevel
local GetCombatRating = GetCombatRating

-- -------------------------------------------------------------
-- Preset toggle tables (buff id -> default on)
-- -------------------------------------------------------------

local RAID_PRESETS, WORLD_PRESETS
if MSC.IsTBC then
    RAID_PRESETS = {
        off = {},
        full25 = {
            TOTEM_OF_WRATH = true, IMPROVED_FAERIE_FIRE = true, HEROIC_PRESENCE = true,
            MOONKIN_AURA = true, LEADER_OF_THE_PACK = true, BLESSING_OF_KINGS = true,
            MARK_OF_THE_WILD = true, TRUESHOT_AURA = true, STRENGTH_OF_EARTH_TOTEM = true,
            GRACE_OF_AIR_TOTEM = true, POWER_WORD_FORTITUDE = true, ARCANE_INTELLECT = true,
            DIVINE_SPIRIT = true, BLESSING_OF_MIGHT = true, BATTLE_SHOUT = true,
            WRATH_OF_AIR_TOTEM = true, UNLEASHED_RAGE = true,
        },
        minimal10 = {
            IMPROVED_FAERIE_FIRE = true, HEROIC_PRESENCE = true, BLESSING_OF_KINGS = true,
            TOTEM_OF_WRATH = true, MARK_OF_THE_WILD = true, POWER_WORD_FORTITUDE = true,
            ARCANE_INTELLECT = true,
        },
    }
else
    -- Era and Forever: Paladins are Alliance and Shamans Horde, so their buffs
    -- are only assumed for that side (BE:GetAssumedBuffSum).
    RAID_PRESETS = {
        off = {},
        raid = {
            MARK_OF_THE_WILD = true, POWER_WORD_FORTITUDE = true, DIVINE_SPIRIT = true,
            ARCANE_INTELLECT = true, BLESSING_OF_KINGS = true, BLESSING_OF_MIGHT = true,
            BATTLE_SHOUT = true, TRUESHOT_AURA = true, BLOOD_PACT = true,
            STRENGTH_OF_EARTH_TOTEM = true, GRACE_OF_AIR_TOTEM = true,
        },
        group = {
            MARK_OF_THE_WILD = true, POWER_WORD_FORTITUDE = true, ARCANE_INTELLECT = true,
            BLESSING_OF_KINGS = true, STRENGTH_OF_EARTH_TOTEM = true,
        },
    }
end
WORLD_PRESETS = {
    off = {},
    full = {
        RALLYING_CRY_OF_THE_DRAGONSLAYER = true, SPIRIT_OF_ZANDALAR = true, SONGFLOWER_SERENADE = true,
        WARCHIEF_S_BLESSING = true, MIGHT_OF_STORMWIND = true,
        FENGUS_FEROCITY = true, MOL_DAR_S_MOXIE = true, SLIP_KIK_S_SAVVY = true,
    },
    dmTribute = { FENGUS_FEROCITY = true, MOL_DAR_S_MOXIE = true, SLIP_KIK_S_SAVVY = true },
}

-- Saved settings from before the buff lists were generated used other keys.
local OLD_KEYS = {
    STRENGTH_OF_EARTH = "STRENGTH_OF_EARTH_TOTEM", GRACE_OF_AIR = "GRACE_OF_AIR_TOTEM",
    DRAGONSLAYER = "RALLYING_CRY_OF_THE_DRAGONSLAYER", FACTION_HEAD = "RALLYING_CRY_OF_THE_DRAGONSLAYER",
    SONGFLOWER = "SONGFLOWER_SERENADE", FENGUS = "FENGUS_FEROCITY", MOLDAR = "MOL_DAR_S_MOXIE",
    SLIPKIK = "SLIP_KIK_S_SAVVY",
}
-- Era and Forever showed TBC's preset names before they had their own.
local OLD_PRESETS = { full25 = "raid", minimal10 = "group" }

-- Preset choices for the options dropdowns: { value, English L key }.
function BE:GetRaidPresetOptions()
    if MSC.IsTBC then
        return { { "off", "Off" }, { "full25", "25-Man Full" }, { "minimal10", "10-Man Minimal" } }
    end
    return { { "off", "Off" }, { "raid", "Full Raid" }, { "group", "5-Player Group" } }
end

-- -------------------------------------------------------------
-- Spec role resolution
-- -------------------------------------------------------------

function BE:GetSpecRole(specKey)
    if not specKey then return "all" end
    local s = tostring(specKey):upper()
    if s:find("PVP") then return "pvp" end
    if s:find("BALANCE") or s:find("CASTER") then return "caster" end
    if s:find("ELE") or s:find("ELEMENTAL") then return "caster" end
    if s:find("SHADOW") or s:find("DESTRO") or s:find("AFFL") then return "caster" end
    if s:find("ARCANE") or s:find("FROST") or s:find("FIRE") and s:find("MAGE") == nil then
        if s:find("MAGE") or s == "FROST" or s == "FIRE" or s == "ARCANE" then return "caster" end
    end
    if s:find("MAGE") or s:find("WARLOCK") or s:find("PRIEST") or s:find("HOLY") or s:find("DISC") then
        if not s:find("PALADIN") then return "caster" end
    end
    if s:find("RESTO") or s:find("HEAL") or s:find("TREE") then return "healer" end
    if s:find("PROT") or s:find("BEAR") or s:find("TANK") then return "tank" end
    if s:find("HUNT") then return "hunter" end
    if s:find("ENH") then return "enhancement" end
    if s:find("FERAL") or s:find("CAT") or s:find("ROGUE") or s:find("FURY") or s:find("ARMS") or s:find("RET") or s:find("COMBAT") or s:find("MUTI") then
        return "melee"
    end
    if s:find("WARRIOR") or s:find("PALADIN") or s:find("SHAMAN") then return "melee" end
    return "all"
end

function BE:RoleMatches(roles, specKey)
    if not roles then return true end
    local role = self:GetSpecRole(specKey)
    for _, r in ipairs(roles) do
        if r == "all" or r == role then return true end
        if r == "physical" and (role == "melee" or role == "hunter" or role == "enhancement") then return true end
        if r == "caster" and role == "caster" then return true end
        if r == "dps" and role ~= "healer" and role ~= "tank" then return true end
    end
    return false
end

function BE:IsPlayerDraenei()
    local _, race = UnitRace("player")
    return race == "Draenei"
end

function BE:GetPlayerFaction()
    local faction = UnitFactionGroup("player")
    return faction -- "Alliance" or "Horde"
end

-- -------------------------------------------------------------
-- Settings helpers
-- -------------------------------------------------------------

function BE:InitSettings()
    if not RXP_SGJ_Settings then return end
    if RXP_SGJ_Settings.AssumeRaidBuffs == nil then RXP_SGJ_Settings.AssumeRaidBuffs = false end
    if RXP_SGJ_Settings.AssumeWorldBuffs == nil then RXP_SGJ_Settings.AssumeWorldBuffs = false end
    if RXP_SGJ_Settings.RaidBuffPreset == nil then RXP_SGJ_Settings.RaidBuffPreset = "off" end
    if RXP_SGJ_Settings.WorldBuffPreset == nil then RXP_SGJ_Settings.WorldBuffPreset = "off" end
    if not RXP_SGJ_Settings.RaidBuffToggles then RXP_SGJ_Settings.RaidBuffToggles = {} end
    if not RXP_SGJ_Settings.WorldBuffToggles then RXP_SGJ_Settings.WorldBuffToggles = {} end
    if RXP_SGJ_Settings.ContentPhase == nil then RXP_SGJ_Settings.ContentPhase = 1 end
    -- Old keys and preset names (see OLD_KEYS / OLD_PRESETS)
    for _, toggles in ipairs({ RXP_SGJ_Settings.RaidBuffToggles, RXP_SGJ_Settings.WorldBuffToggles }) do
        for old, new in pairs(OLD_KEYS) do
            if toggles[old] ~= nil then
                if toggles[new] == nil then toggles[new] = toggles[old] end
                toggles[old] = nil
            end
        end
    end
    if not MSC.IsTBC and OLD_PRESETS[RXP_SGJ_Settings.RaidBuffPreset] then
        local preset = OLD_PRESETS[RXP_SGJ_Settings.RaidBuffPreset]
        RXP_SGJ_Settings.RaidBuffPreset = preset
        RXP_SGJ_Settings.RaidBuffToggles = {}
        for id, on in pairs(RAID_PRESETS[preset]) do RXP_SGJ_Settings.RaidBuffToggles[id] = on end
    end
end

function BE:InvalidateCaches()
    if MSC.BumpScoringRevision then
        MSC:BumpScoringRevision()
    else
        MSC.CachedWeights = nil
        MSC.CachedSpecKey = nil
        if MSC.EvaluationCache then wipe(MSC.EvaluationCache) end
        if MSC.SlotCache then wipe(MSC.SlotCache) end
    end
end

function BE:ApplyRaidPreset(preset)
    RXP_SGJ_Settings.RaidBuffPreset = preset
    RXP_SGJ_Settings.RaidBuffToggles = {}
    local src = RAID_PRESETS[preset] or {}
    for id, on in pairs(src) do RXP_SGJ_Settings.RaidBuffToggles[id] = on end
    RXP_SGJ_Settings.AssumeRaidBuffs = (preset ~= "off")
    self:InvalidateCaches()
end

function BE:ApplyWorldPreset(preset)
    RXP_SGJ_Settings.WorldBuffPreset = preset
    RXP_SGJ_Settings.WorldBuffToggles = {}
    local src = WORLD_PRESETS[preset] or {}
    for id, on in pairs(src) do RXP_SGJ_Settings.WorldBuffToggles[id] = on end
    RXP_SGJ_Settings.AssumeWorldBuffs = (preset ~= "off")
    self:InvalidateCaches()
end

-- (The toggle tables are nil after /sgjwipe until InitSettings runs again.)
function BE:IsRaidBuffOn(id)
    if not RXP_SGJ_Settings or not RXP_SGJ_Settings.AssumeRaidBuffs then return false end
    local toggles = RXP_SGJ_Settings.RaidBuffToggles
    return toggles ~= nil and toggles[id] == true
end

function BE:IsWorldBuffOn(id)
    if not RXP_SGJ_Settings or not RXP_SGJ_Settings.AssumeWorldBuffs then return false end
    local toggles = RXP_SGJ_Settings.WorldBuffToggles
    return toggles ~= nil and toggles[id] == true
end

function BE:PlayerHasTalent(talentKey)
    if MSC.GetTalentRank then return (MSC:GetTalentRank(talentKey) or 0) > 0 end
    return false
end

function BE:IsBalanceDruid(specKey)
    local s = tostring(specKey or ""):upper()
    return s:find("BALANCE") ~= nil
end

-- -------------------------------------------------------------
-- Hit cap credits (% subtracted from base cap)
-- -------------------------------------------------------------

function BE:GetPersonalRacialHitPct()
    if self:IsPlayerDraenei() then return 1 end
    return 0
end

function BE:GetRaidHitCreditPct(hitType, specKey)
    if not RXP_SGJ_Settings or not RXP_SGJ_Settings.AssumeRaidBuffs then return 0 end
    local credit = 0

    if hitType ~= "SPELL" and self:IsRaidBuffOn("IMPROVED_FAERIE_FIRE") then
        credit = credit + 3
    end

    if hitType == "SPELL" then
        if self:IsRaidBuffOn("TOTEM_OF_WRATH") and not self:PlayerHasTalent("TOTEM_OF_WRATH") then
            credit = credit + 3
        end
        if self:IsRaidBuffOn("MISERY") and not self:IsRaidBuffOn("TOTEM_OF_WRATH") then
            credit = credit + 3
        end
        if self:IsRaidBuffOn("MOONKIN_AURA") and not self:IsBalanceDruid(specKey) then
            -- spell crit buff, not hit — handled in synergy
        end
    end

    if self:IsRaidBuffOn("HEROIC_PRESENCE") and not self:IsPlayerDraenei() then
        credit = credit + 1
    end

    return credit
end

function BE:GetTotalHitCreditPct(hitType, specKey, talentPct)
    return (talentPct or 0) + self:GetPersonalRacialHitPct() + self:GetRaidHitCreditPct(hitType, specKey)
end

-- -------------------------------------------------------------
-- Cap hysteresis (shared by all classes)
-- -------------------------------------------------------------

-- Callers pass the game's combat-rating id (the GetCombatRating index), but
-- MSC.CombatRatingScalars (Database.lua) has its own column order:
--   { WepS, Def, Dodge, Parry, Block, Hit, Crit, Haste, SpellHit, SpellCrit, SpellHaste, Resil }
-- Indexing it with the game id read spell hit (8) from the Haste column and
-- ranged hit (7) from the Crit column (spell hit cap 252 rating instead of 202).
local CR_TO_SCALAR_COLUMN = {
    [1] = 1,   -- CR_WEAPON_SKILL
    [2] = 2,   -- CR_DEFENSE_SKILL
    [3] = 3,   -- CR_DODGE
    [4] = 4,   -- CR_PARRY
    [5] = 5,   -- CR_BLOCK
    [6] = 6,   -- CR_HIT_MELEE
    [7] = 6,   -- CR_HIT_RANGED
    [8] = 9,   -- CR_HIT_SPELL
    [9] = 7,   -- CR_CRIT_MELEE
    [10] = 7,  -- CR_CRIT_RANGED
    [11] = 10, -- CR_CRIT_SPELL
    [15] = 12, [16] = 12, [17] = 12, -- CR_CRIT_TAKEN_* (resilience)
    [18] = 8,  -- CR_HASTE_MELEE
    [19] = 8,  -- CR_HASTE_RANGED
    [20] = 11, -- CR_HASTE_SPELL
    [24] = 1,  -- CR_EXPERTISE
}
-- Rating per 1% at level 60, same column order (for the formula fallback).
local SCALAR_AT_60 = { 2.5, 1.5, 12, 20, 5, 10, 14, 10, 8, 14, 10, 25 }

function BE:GetRatingScalar(ratingId, level)
    level = level or UnitLevel("player") or 70
    if level > 70 then level = 70 end
    -- TBC's rating curve is flat below level 10 (the table's 8-9 rows are 0 /
    -- half, which made every point of hit look capped at level 8).
    if level < 10 then level = 10 end
    local col = CR_TO_SCALAR_COLUMN[ratingId] or 6
    local row = MSC.CombatRatingScalars and MSC.CombatRatingScalars[level]
    if row and row[col] and row[col] > 0 then return row[col] end
    -- No row for this level: TBC's formula (level 60 value scaled by
    -- (L - 8) / 52 below 60 and 82 / (262 - 3L) from 60 to 70).
    local mult = (level >= 60) and (82 / (262 - 3 * level)) or ((level - 8) / 52)
    return SCALAR_AT_60[col] * mult
end

--[[
  Apply hard/soft cap to a rating-based stat weight.
  options: { furyCapped, furySoft, hardVal, softMult, hardLabel, softLabel }
]]
function BE:ApplyRatingCap(weights, activeCaps, weightKey, ratingId, baseCapPct, creditPct, options)
    if not weights[weightKey] or weights[weightKey] <= 0.1 then return end
    options = options or {}

    -- Hit Rating from the gear (unbuffed); the live rating until it's scanned
    local GEAR_KIND = { [6] = "MELEE", [7] = "RANGED", [8] = "SPELL" }
    local hitRating = GEAR_KIND[ratingId] and MSC.GetGearHitRating and MSC.GetGearHitRating(GEAR_KIND[ratingId])
        or MSC.SanitizeStat(GetCombatRating(ratingId))
    local scalar = self:GetRatingScalar(ratingId)
    local finalCapRating = math_max(0, baseCapPct - (creditPct or 0)) * scalar
    local hardVal = options.hardVal or 0.05
    local softMult = options.softMult or 0.4
    local hardLabel = options.hardLabel or MSC.L["Hit"]
    local softLabel = options.softLabel or MSC.L["Hit (Soft)"]

    if hitRating >= (finalCapRating + scalar) then
        if options.furyCapped then
            weights[weightKey] = 0.8
            table.insert(activeCaps, MSC.L["Y-Hit (Rage)"])
        else
            weights[weightKey] = hardVal
            table.insert(activeCaps, hardLabel)
        end
    elseif hitRating >= finalCapRating then
        if options.furySoft then
            weights[weightKey] = 1.4
        else
            weights[weightKey] = weights[weightKey] * softMult
        end
        table.insert(activeCaps, softLabel)
    end
end

function BE:ApplyMeleeHitCap(weights, activeCaps, currentSpec, talentHitPct, ratingId, options)
    options = options or {}
    local baseCapPct = (currentSpec and currentSpec:find("Leveling")) and 5 or 9
    local credit = self:GetTotalHitCreditPct("MELEE", currentSpec, talentHitPct or 0)
    local isFury = currentSpec and (currentSpec:find("FURY") or currentSpec:find("DW"))
    self:ApplyRatingCap(weights, activeCaps, "ITEM_MOD_HIT_RATING_SHORT", ratingId or 6, baseCapPct, credit, {
        furyCapped = options.furyCapped or isFury,
        furySoft = options.furySoft or isFury,
        hardVal = options.hardVal or (isFury and 0.8 or 0.1),
        softMult = options.softMult or 0.4,
        hardLabel = options.hardLabel or MSC.L["Hit"],
        softLabel = options.softLabel or MSC.L["Hit (Soft)"],
    })
end

function BE:ApplySpellHitCap(weights, activeCaps, currentSpec, talentHitPct, options)
    options = options or {}
    local baseCapPct = 16
    if currentSpec and currentSpec:find("PVP") then baseCapPct = 4
    elseif currentSpec and currentSpec:find("Leveling") then baseCapPct = 6 end
    local credit = self:GetTotalHitCreditPct("SPELL", currentSpec, talentHitPct or 0)
    self:ApplyRatingCap(weights, activeCaps, "ITEM_MOD_HIT_SPELL_RATING_SHORT", 8, baseCapPct, credit, {
        hardVal = options.hardVal or 0.05,
        softMult = options.softMult or 0.4,
        hardLabel = options.hardLabel or MSC.L["Hit"],
        softLabel = options.softLabel or MSC.L["Hit (Soft)"],
    })
end

-- -------------------------------------------------------------
-- Assumed buffs
-- -------------------------------------------------------------

local STAT_KEYS = {
    str = "ITEM_MOD_STRENGTH_SHORT",
    agi = "ITEM_MOD_AGILITY_SHORT",
    sta = "ITEM_MOD_STAMINA_SHORT",
    int = "ITEM_MOD_INTELLECT_SHORT",
    spi = "ITEM_MOD_SPIRIT_SHORT",
}

-- The rank of a buff a player of `level` gets (the highest one learned by
-- then), or nil below the first rank.
local function RankAt(entry, level)
    local id
    for _, r in ipairs(entry.ranks) do
        if r[1] <= level then id = r[2] end
    end
    return id
end

-- Sum (MSC.NewBuffSum) of every assumed raid and world buff that's on, at
-- the player's level. nil when none is assumed. On Era and Forever, Paladin
-- buffs are Alliance-only and Shaman totems Horde-only.
local assumedSum, assumedKey = nil, nil
function BE:GetAssumedBuffSum()
    if not RXP_SGJ_Settings or not MSC.BuffList or not MSC.BuffAuras or not MSC.NewBuffSum then return nil end
    if not RXP_SGJ_Settings.AssumeRaidBuffs and not RXP_SGJ_Settings.AssumeWorldBuffs then return nil end
    local level = UnitLevel("player") or 1
    local faction = UnitFactionGroup and UnitFactionGroup("player") or nil
    local key = (MSC.ScoringRevision or 0) .. "|" .. level .. "|" .. tostring(faction)
    if assumedKey == key then return assumedSum end
    local sum, any = MSC.NewBuffSum(), false
    for buffKey, entry in pairs(MSC.BuffList) do
        local wrongSide = not MSC.IsTBC and ((entry.source == "PALADIN" and faction == "Horde") or (entry.source == "SHAMAN" and faction == "Alliance"))
        if (self:IsRaidBuffOn(buffKey) or self:IsWorldBuffOn(buffKey)) and not wrongSide then
            local id = RankAt(entry, level)
            local b = id and MSC.BuffAuras[id]
            if b then
                MSC.AddBuffEffects(sum, b)
                any = true
            end
        end
    end
    assumedSum, assumedKey = any and sum or nil, key
    return assumedSum
end

-- Assumed % buffs make every point of a stat on gear worth more (Blessing
-- of Kings: +10% to each), so that stat's weight goes up by the same factor;
-- likewise Attack Power with a % Attack Power buff. Flat buffs don't change
-- what a point of gear is worth: they're added to the stats the caps and
-- thresholds read (MSC.GetJudgingStats).
function BE:ApplyStatSynergy(weights, specKey)
    local a = self:GetAssumedBuffSum()
    if not a then return end
    for s, key in pairs(STAT_KEYS) do
        if a.mult[s] ~= 1 and weights[key] then weights[key] = weights[key] * a.mult[s] end
    end
    if a.apMult ~= 1 and weights["ITEM_MOD_ATTACK_POWER_SHORT"] then
        weights["ITEM_MOD_ATTACK_POWER_SHORT"] = weights["ITEM_MOD_ATTACK_POWER_SHORT"] * a.apMult
    end
    if a.rapMult ~= 1 and weights["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] then
        weights["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] = weights["ITEM_MOD_RANGED_ATTACK_POWER_SHORT"] * a.rapMult
    end
end

-- -------------------------------------------------------------
-- SAFETY_CAPS effective base (rating) for Evaluator
-- -------------------------------------------------------------

function BE:GetEffectiveHitRatingBase(statKey, classTalentKey, talentRatingPerRank, specKey)
    local base = 202 -- 16% spell hit in rating at 70
    if statKey == "ITEM_MOD_HIT_RATING_SHORT" then base = 142 end -- 9% melee

    local creditRating = 0
    local _, playerClass = UnitClass("player")
    local scalar = self:GetRatingScalar((statKey == "ITEM_MOD_HIT_SPELL_RATING_SHORT") and 8 or 6)

    if playerClass == "SHAMAN" and statKey == "ITEM_MOD_HIT_SPELL_RATING_SHORT" then
        local prec = (MSC.GetTalentRank and MSC:GetTalentRank("ELEMENTAL_PRECISION") or 0) * 2
        local natGuid = (MSC.GetTalentRank and MSC:GetTalentRank("NATURE_GUIDANCE") or 0) * 1
        local wrath = (MSC.GetTalentRank and MSC:GetTalentRank("TOTEM_OF_WRATH") or 0) > 0 and 3 or 0
        creditRating = (prec + natGuid + wrath) * scalar
    elseif classTalentKey and MSC.GetTalentRank then
        local talentRank = MSC:GetTalentRank(classTalentKey) or 0
        creditRating = talentRank * (talentRatingPerRank or 0)
    end

    local hitType = (statKey == "ITEM_MOD_HIT_SPELL_RATING_SHORT") and "SPELL" or "MELEE"
    local creditPct = self:GetRaidHitCreditPct(hitType, specKey) + self:GetPersonalRacialHitPct()
    creditRating = creditRating + creditPct * scalar

    return math_max(0, base - creditRating)
end

-- `source` is an English L key: Interface.lua translates it when drawing
-- (MSC.L[mod.source]) and compares it to "Heroic Presence (Racial)", so it
-- stays untranslated here. The keys are listed in Localization.lua.
function BE:GetCapModifiersForUI(specKey, hitType)
    local mods = {}
    if self:GetPersonalRacialHitPct() > 0 then
        table.insert(mods, { source = "Heroic Presence (Racial)", val = 1, isPct = true })
    end
    if RXP_SGJ_Settings and RXP_SGJ_Settings.AssumeRaidBuffs then
        if hitType ~= "SPELL" and self:IsRaidBuffOn("IMPROVED_FAERIE_FIRE") then
            table.insert(mods, { source = "Improved Faerie Fire", val = 3, isPct = true })
        end
        if self:IsRaidBuffOn("TOTEM_OF_WRATH") and not self:PlayerHasTalent("TOTEM_OF_WRATH") then
            table.insert(mods, { source = "Totem of Wrath", val = 3, isPct = true })
        end
        if self:IsRaidBuffOn("HEROIC_PRESENCE") and not self:IsPlayerDraenei() then
            table.insert(mods, { source = "Draenei in Raid", val = 1, isPct = true })
        end
    end
    return mods
end

BE.InitSettings()
