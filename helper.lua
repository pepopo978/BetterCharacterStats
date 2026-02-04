local _G = _G or getfenv(0)

BCS = BCS or {}

local BCS_Tooltip = BetterCharacterStatsTooltip or CreateFrame("GameTooltip", "BetterCharacterStatsTooltip", nil, "GameTooltipTemplate")
local BCS_Prefix = "BetterCharacterStatsTooltip"
BCS_Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local L = BCS["L"]
local setPattern = "(.+) %(%d/%d%)"
local strfind = strfind
local tonumber = tonumber
local _, playerClass = UnitClass("player")

local function twipe(table)
	if type(table) ~= "table" then
		return nil
	end
	for k in pairs(table) do
		table[k] = nil
	end
end

local BCScache = {
	["gear"] = {
		damage_and_healing = 0,
		only_damage = 0,
		arcane = 0,
		fire = 0,
		frost = 0,
		holy = 0,
		nature = 0,
		shadow = 0,
		healing = 0,
		mp5 = 0,
		casting = 0,
		spell_hit = 0,
		spell_crit = 0,
		hit = 0,
		ranged_hit = 0,
		ranged_crit = 0,
		haste = 0,
		spell_haste = 0,
		armor_pen = 0,
		spell_pen = 0,
		-- class specific
		priest_holy_spells = 0,
		priest_prayer = 0
	},
	["talents"] = {
		damage_and_healing = 0,
		healing = 0,
		spell_hit = 0,
		spell_hit_fire = 0,
		spell_hit_frost = 0,
		spell_hit_arcane = 0,
		spell_hit_shadow = 0,
		spell_hit_holy = 0,
		spell_crit = 0,
		casting = 0,
		mp5 = 0,
		hit = 0,
		ranged_hit = 0,
		ranged_crit = 0,
		haste = 0,
		spell_haste = 0,
		armor_pen = 0,
		-- Block-related talent modifiers
		block_mod = 0,
		enhancing_totems = 0,
		-- class specific stored in separate tables
	},
	["auras"] = {
		damage_and_healing = 0,
		only_damage = 0,
		arcane = 0,
		fire = 0,
		frost = 0,
		holy = 0,
		nature = 0,
		shadow = 0,
		healing = 0,
		mp5 = 0,
		casting = 0,
		spell_hit = 0,
		spell_crit = 0,
		hit = 0,
		ranged_hit = 0,
		ranged_crit = 0,
		hit_debuff = 0,
		haste = 0,
		spell_haste = 0,
		armor_pen = 0
	},
	["skills"] = {
		mh = 0,
		oh = 0,
		ranged = 0
	}
}

local SetBonus = {
	hit = {},
	spellHit = {},
	rangedCrit = {},
	spellCrit = {},
	spellCritClass = {},
	spellPower = {},
	healingPower = {},
	mp5 = {},
	haste = {},
	armor_pen = {},
	spell_pen = {},
}

-- Item-level cache: stores parsed stats by full item link to avoid re-parsing unchanged items
local ItemCache = {}
-- Track currently equipped item links by slot
local EquippedItems = {}

-- Unified gear scanning: parses all equipment ONCE and extracts ALL stats
local function ScanAllGear()
	-- Reset all gear cache values
	BCScache["gear"].damage_and_healing = 0
	BCScache["gear"].only_damage = 0
	BCScache["gear"].arcane = 0
	BCScache["gear"].fire = 0
	BCScache["gear"].frost = 0
	BCScache["gear"].holy = 0
	BCScache["gear"].nature = 0
	BCScache["gear"].shadow = 0
	BCScache["gear"].healing = 0
	BCScache["gear"].mp5 = 0
	BCScache["gear"].casting = 0
	BCScache["gear"].spell_hit = 0
	BCScache["gear"].spell_crit = 0
	BCScache["gear"].hit = 0
	BCScache["gear"].ranged_hit = 0
	BCScache["gear"].ranged_crit = 0
	BCScache["gear"].haste = 0
	BCScache["gear"].spell_haste = 0
	BCScache["gear"].armor_pen = 0
	BCScache["gear"].spell_pen = 0
	BCScache["gear"].priest_holy_spells = 0
	BCScache["gear"].priest_prayer = 0

	-- Reset set bonuses
	twipe(SetBonus.hit)
	twipe(SetBonus.spellHit)
	twipe(SetBonus.rangedCrit)
	twipe(SetBonus.spellCrit)
	twipe(SetBonus.spellCritClass)
	twipe(SetBonus.spellPower)
	twipe(SetBonus.healingPower)
	twipe(SetBonus.mp5)
	twipe(SetBonus.haste)
	twipe(SetBonus.armor_pen)
	twipe(SetBonus.spell_pen)

	-- Scan all equipment slots ONCE
	for slot = 1, 19 do
		local itemLink = GetInventoryItemLink("player", slot)
		if itemLink then
			-- Check cache using full item link (avoids strfind on cache hit)
			local cached = ItemCache[itemLink]
			if not cached then
				-- Extract item link for SetHyperlink only when not cached
				local _, _, eqItemLink = strfind(itemLink, "(item:%d+:%d+:%d+:%d+)")
				if not eqItemLink then
					-- Invalid link, skip this slot
					EquippedItems[slot] = nil
				else
					-- Parse the item and cache it
					cached = {}
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)

					local setName
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, value

							-- ===== HIT =====
							_, _, value = strfind(text, L["Equip: Improves your chance to hit by (%d)%%."])
							if value then cached.hit = (cached.hit or 0) + tonumber(value) end

							_, _, value = strfind(text, L["/Hit %+(%d+)"])
							if value then cached.hit = (cached.hit or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^Equip: Improves your chance to hit with spells and attacks by (%d+)%%"])
							if value then
								cached.hit = (cached.hit or 0) + tonumber(value)
								cached.spell_hit = (cached.spell_hit or 0) + tonumber(value)
							end

							-- ===== SPELL HIT =====
							_, _, value = strfind(text, L["Equip: Improves your chance to hit with spells by (%d)%%."])
							if value then cached.spell_hit = (cached.spell_hit or 0) + tonumber(value) end

							_, _, value = strfind(text, L["/Spell Hit %+(%d+)"])
							if value then cached.spell_hit = (cached.spell_hit or 0) + tonumber(value) end

							-- Scythe of Elune (hit + crit)
							_, _, value = strfind(text, L["Improves your chance to hit and get a critical strike with spells by (%d+)%%"])
							if value then
								cached.spell_hit = (cached.spell_hit or 0) + tonumber(value)
								cached.spell_crit = (cached.spell_crit or 0) + tonumber(value)
							end

							-- ===== RANGED HIT (slot 18 only) =====
							if slot == 18 then
								_, _, value = strfind(text, L["+(%d)%% Ranged Hit"])
								if value then cached.ranged_hit = (cached.ranged_hit or 0) + tonumber(value) end
							end

							-- ===== CRIT =====
							_, _, value = strfind(text, L["Equip: Improves your chance to get a critical strike by (%d)%%."])
							if value then cached.ranged_crit = (cached.ranged_crit or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Improves your chance to get a critical strike with missile weapons by (%d)%%."])
							if value then cached.ranged_crit = (cached.ranged_crit or 0) + tonumber(value) end

							_, _, value = strfind(text, L["%+(%d+)%% Critical Strike"])
							if value then cached.ranged_crit = (cached.ranged_crit or 0) + tonumber(value) end

							-- ===== SPELL CRIT =====
							_, _, value = strfind(text, L["Equip: Improves your chance to get a critical strike with spells by (%d)%%."])
							if value then cached.spell_crit = (cached.spell_crit or 0) + tonumber(value) end

							_, _, value = strfind(text, L["(%d)%% Spell Critical Strike"])
							if value then cached.spell_crit = (cached.spell_crit or 0) + tonumber(value) end

							-- ===== SPELL POWER (damage and healing) =====
							_, _, value = strfind(text, L["Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%."])
							if value then cached.damage_and_healing = (cached.damage_and_healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Spell Damage %+(%d+)"])
							if value then cached.damage_and_healing = (cached.damage_and_healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+) Spell Damage and Healing"])
							if value then cached.damage_and_healing = (cached.damage_and_healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+) Damage and Healing Spells"])
							if value then cached.damage_and_healing = (cached.damage_and_healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+) Spell Power"])
							if value then cached.damage_and_healing = (cached.damage_and_healing or 0) + tonumber(value) end

							-- Atiesh (druid/priest) - damage only portion
							_, _, value = strfind(text, L["Equip: Increases your spell damage by up to (%d+) and your healing by up to %d+."])
							if value then cached.only_damage = (cached.only_damage or 0) + tonumber(value) end

							-- Scythe of Elune damage only
							_, _, value = strfind(text, L["Increases damage done by magical spells and effects by up to (%d+)"])
							if value then cached.only_damage = (cached.only_damage or 0) + tonumber(value) end

							-- ===== SCHOOL SPECIFIC SPELL POWER =====
							_, _, value = strfind(text, L["Equip: Increases damage done by Arcane spells and effects by up to (%d+)."])
							if value then cached.arcane = (cached.arcane or 0) + tonumber(value) end
							_, _, value = strfind(text, L["^%+(%d+) Arcane Spell Damage"])
							if value then cached.arcane = (cached.arcane or 0) + tonumber(value) end
							_, _, value = strfind(text, L["Arcane Damage %+(%d+)"])
							if value then cached.arcane = (cached.arcane or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Increases damage done by Fire spells and effects by up to (%d+)."])
							if value then cached.fire = (cached.fire or 0) + tonumber(value) end
							_, _, value = strfind(text, L["Fire Damage %+(%d+)"])
							if value then cached.fire = (cached.fire or 0) + tonumber(value) end
							_, _, value = strfind(text, L["^%+(%d+) Fire Spell Damage"])
							if value then cached.fire = (cached.fire or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Increases damage done by Frost spells and effects by up to (%d+)."])
							if value then cached.frost = (cached.frost or 0) + tonumber(value) end
							_, _, value = strfind(text, L["Frost Damage %+(%d+)"])
							if value then cached.frost = (cached.frost or 0) + tonumber(value) end
							_, _, value = strfind(text, L["^%+(%d+) Frost Spell Damage"])
							if value then cached.frost = (cached.frost or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Increases damage done by Holy spells and effects by up to (%d+)."])
							if value then cached.holy = (cached.holy or 0) + tonumber(value) end
							_, _, value = strfind(text, L["^%+(%d+) Holy Spell Damage"])
							if value then cached.holy = (cached.holy or 0) + tonumber(value) end
							_, _, value = strfind(text, L["Holy Damage %+(%d+)"])
							if value then cached.holy = (cached.holy or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Increases damage done by Nature spells and effects by up to (%d+)."])
							if value then cached.nature = (cached.nature or 0) + tonumber(value) end
							_, _, value = strfind(text, L["^%+(%d+) Nature Spell Damage"])
							if value then cached.nature = (cached.nature or 0) + tonumber(value) end
							_, _, value = strfind(text, L["Nature Damage %+(%d+)"])
							if value then cached.nature = (cached.nature or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Increases damage done by Shadow spells and effects by up to (%d+)."])
							if value then cached.shadow = (cached.shadow or 0) + tonumber(value) end
							_, _, value = strfind(text, L["Shadow Damage %+(%d+)"])
							if value then cached.shadow = (cached.shadow or 0) + tonumber(value) end
							_, _, value = strfind(text, L["^%+(%d+) Shadow Spell Damage"])
							if value then cached.shadow = (cached.shadow or 0) + tonumber(value) end

							-- ===== HEALING =====
							_, _, value = strfind(text, L["Equip: Increases healing done by spells and effects by up to (%d+)."])
							if value then cached.healing = (cached.healing or 0) + tonumber(value) end

							-- Atiesh healing portion
							_, _, value = strfind(text, L["Equip: Increases your spell damage by up to %d+ and your healing by up to (%d+)."])
							if value then cached.healing = (cached.healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Healing Spells %+(%d+)"])
							if value then cached.healing = (cached.healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+) Healing Spells"])
							if value then cached.healing = (cached.healing or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Healing %+(%d+)"])
							if value then cached.healing = (cached.healing or 0) + tonumber(value) end

							-- ===== MP5 =====
							_, _, value = strfind(text, L["^Mana Regen %+(%d+)"])
							if value then cached.mp5 = (cached.mp5 or 0) + tonumber(value) end

							_, _, value = strfind(text, L["Equip: Restores (%d+) mana per 5 sec."])
							if value and not strfind(text, L["to all party members"]) then
								cached.mp5 = (cached.mp5 or 0) + tonumber(value)
							end

							_, _, value = strfind(text, L["^Healing %+%d+ and (%d+) mana per 5 sec."])
							if value then cached.mp5 = (cached.mp5 or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+) mana every 5 sec."])
							if value then cached.mp5 = (cached.mp5 or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting."])
							if value then cached.casting = (cached.casting or 0) + tonumber(value) end

							-- ===== HASTE =====
							_, _, value = strfind(text, L["^Equip: Increases your attack and casting speed by (%d+)%%"])
							if value then cached.haste = (cached.haste or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^Equip: Increases your casting speed by (%d+)%%"])
							if value then cached.spell_haste = (cached.spell_haste or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+)%% Haste"])
							if value then cached.haste = (cached.haste or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^Attack Speed %+(%d+)%%"])
							if value then cached.haste = (cached.haste or 0) + tonumber(value) end

							-- ===== ARMOR PEN =====
							_, _, value = strfind(text, L["^Equip: Your attacks ignore (%d+) of the target's armor"])
							if value then cached.armor_pen = (cached.armor_pen or 0) + tonumber(value) end

							-- ===== SPELL PEN =====
							_, _, value = strfind(text, L["^Equip: Decreases the magical resistances of your spell targets by (%d+)"])
							if value then cached.spell_pen = (cached.spell_pen or 0) + tonumber(value) end

							_, _, value = strfind(text, L["^%+(%d+) Spell Penetration"])
							if value then cached.spell_pen = (cached.spell_pen or 0) + tonumber(value) end

							-- ===== SET BONUSES =====
							_, _, value = strfind(text, setPattern)
							if value then
								cached.setName = value
							end

							-- Set bonus: hit
							_, _, value = strfind(text, L["^Set: Improves your chance to hit by (%d)%%."])
							if value and cached.setName then
								cached.set_hit = tonumber(value)
								cached.set_hit_name = cached.setName
							end

							-- Set bonus: spell hit
							_, _, value = strfind(text, L["^Set: Improves your chance to hit with spells by (%d)%%."])
							if value and cached.setName then
								cached.set_spell_hit = tonumber(value)
								cached.set_spell_hit_name = cached.setName
							end

							-- Set bonus: ranged crit
							_, _, value = strfind(text, L["^Set: Improves your chance to get a critical strike by (%d)%%."])
							if value and cached.setName then
								cached.set_ranged_crit = tonumber(value)
								cached.set_ranged_crit_name = cached.setName
							end

							-- Set bonus: spell crit
							_, _, value = strfind(text, L["^Set: Improves your chance to get a critical strike with spells by (%d)%%."])
							if value and cached.setName then
								cached.set_spell_crit = tonumber(value)
								cached.set_spell_crit_name = cached.setName
							end

							-- Set bonus: spell power
							_, _, value = strfind(text, L["^Set: Increases damage and healing done by magical spells and effects by up to (%d+)%."])
							if value and cached.setName then
								cached.set_spell_power = tonumber(value)
								cached.set_spell_power_name = cached.setName
							end

							-- Set bonus: healing
							_, _, value = strfind(text, L["^Set: Increases healing done by spells and effects by up to (%d+)%."])
							if value and cached.setName then
								cached.set_healing = tonumber(value)
								cached.set_healing_name = cached.setName
							end

							-- Set bonus: mp5
							_, _, value = strfind(text, L["^Set: Allows (%d+)%% of your Mana regeneration to continue while casting."])
							if value and cached.setName then
								cached.set_casting = tonumber(value)
								cached.set_casting_name = cached.setName
							end

							_, _, value = strfind(text, L["^Set: Restores (%d+) mana per 5 sec."])
							if value and cached.setName then
								cached.set_mp5 = tonumber(value)
								cached.set_mp5_name = cached.setName
							end

							-- Set bonus: haste
							_, _, value = strfind(text, L["^Set: Increases your attack and casting speed by (%d+)%%"])
							if value and cached.setName then
								cached.set_haste = tonumber(value)
								cached.set_haste_name = cached.setName
							end

							-- Set bonus: armor pen
							_, _, value = strfind(text, L["^Set: Your attacks ignore (%d+) of the target's armor"])
							if value and cached.setName then
								cached.set_armor_pen = tonumber(value)
								cached.set_armor_pen_name = cached.setName
							end

							-- Set bonus: spell pen
							_, _, value = strfind(text, L["^Set: Decreases the magical resistances of your spell targets by (%d+)"])
							if value and cached.setName then
								cached.set_spell_pen = tonumber(value)
								cached.set_spell_pen_name = cached.setName
							end

							-- Priest set bonuses
							if playerClass == "PRIEST" then
								_, _, value = strfind(text, L["^Set: Improves your chance to get a critical strike with Holy spells by (%d)%%."])
								if value and cached.setName then
									cached.set_priest_holy = tonumber(value)
									cached.set_priest_holy_name = cached.setName
								end

								_, _, value = strfind(text, L["^Set: Increases your chance of a critical hit with Prayer of Healing by (%d+)%%."])
								if value and cached.setName then
									cached.set_priest_prayer = tonumber(value)
									cached.set_priest_prayer_name = cached.setName
								end
							end
						end
					end
					ItemCache[itemLink] = cached
				end
			end

			if cached then
				-- Add cached values to totals
				BCScache["gear"].hit = BCScache["gear"].hit + (cached.hit or 0)
				BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + (cached.spell_hit or 0)
				BCScache["gear"].ranged_hit = BCScache["gear"].ranged_hit + (cached.ranged_hit or 0)
				BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + (cached.ranged_crit or 0)
				BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + (cached.spell_crit or 0)
				BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + (cached.damage_and_healing or 0)
				BCScache["gear"].only_damage = BCScache["gear"].only_damage + (cached.only_damage or 0)
				BCScache["gear"].arcane = BCScache["gear"].arcane + (cached.arcane or 0)
				BCScache["gear"].fire = BCScache["gear"].fire + (cached.fire or 0)
				BCScache["gear"].frost = BCScache["gear"].frost + (cached.frost or 0)
				BCScache["gear"].holy = BCScache["gear"].holy + (cached.holy or 0)
				BCScache["gear"].nature = BCScache["gear"].nature + (cached.nature or 0)
				BCScache["gear"].shadow = BCScache["gear"].shadow + (cached.shadow or 0)
				BCScache["gear"].healing = BCScache["gear"].healing + (cached.healing or 0)
				BCScache["gear"].mp5 = BCScache["gear"].mp5 + (cached.mp5 or 0)
				BCScache["gear"].casting = BCScache["gear"].casting + (cached.casting or 0)
				BCScache["gear"].haste = BCScache["gear"].haste + (cached.haste or 0)
				BCScache["gear"].spell_haste = BCScache["gear"].spell_haste + (cached.spell_haste or 0)
				BCScache["gear"].armor_pen = BCScache["gear"].armor_pen + (cached.armor_pen or 0)
				BCScache["gear"].spell_pen = BCScache["gear"].spell_pen + (cached.spell_pen or 0)

				-- Handle set bonuses (only count once per set)
				if cached.set_hit and cached.set_hit_name and not SetBonus.hit[cached.set_hit_name] then
					SetBonus.hit[cached.set_hit_name] = true
					BCScache["gear"].hit = BCScache["gear"].hit + cached.set_hit
				end
				if cached.set_spell_hit and cached.set_spell_hit_name and not SetBonus.spellHit[cached.set_spell_hit_name] then
					SetBonus.spellHit[cached.set_spell_hit_name] = true
					BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + cached.set_spell_hit
				end
				if cached.set_ranged_crit and cached.set_ranged_crit_name and not SetBonus.rangedCrit[cached.set_ranged_crit_name] then
					SetBonus.rangedCrit[cached.set_ranged_crit_name] = true
					BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + cached.set_ranged_crit
				end
				if cached.set_spell_crit and cached.set_spell_crit_name and not SetBonus.spellCrit[cached.set_spell_crit_name] then
					SetBonus.spellCrit[cached.set_spell_crit_name] = true
					BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + cached.set_spell_crit
				end
				if cached.set_spell_power and cached.set_spell_power_name and not SetBonus.spellPower[cached.set_spell_power_name] then
					SetBonus.spellPower[cached.set_spell_power_name] = true
					BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + cached.set_spell_power
				end
				if cached.set_healing and cached.set_healing_name and not SetBonus.healingPower[cached.set_healing_name] then
					SetBonus.healingPower[cached.set_healing_name] = true
					BCScache["gear"].healing = BCScache["gear"].healing + cached.set_healing
				end
				if cached.set_casting and cached.set_casting_name and not SetBonus.mp5[cached.set_casting_name] then
					SetBonus.mp5[cached.set_casting_name] = true
					BCScache["gear"].casting = BCScache["gear"].casting + cached.set_casting
				end
				if cached.set_mp5 and cached.set_mp5_name and not SetBonus.mp5[cached.set_mp5_name] then
					SetBonus.mp5[cached.set_mp5_name] = true
					BCScache["gear"].mp5 = BCScache["gear"].mp5 + cached.set_mp5
				end
				if cached.set_haste and cached.set_haste_name and not SetBonus.haste[cached.set_haste_name] then
					SetBonus.haste[cached.set_haste_name] = true
					BCScache["gear"].haste = BCScache["gear"].haste + cached.set_haste
				end
				if cached.set_armor_pen and cached.set_armor_pen_name and not SetBonus.armor_pen[cached.set_armor_pen_name] then
					SetBonus.armor_pen[cached.set_armor_pen_name] = true
					BCScache["gear"].armor_pen = BCScache["gear"].armor_pen + cached.set_armor_pen
				end
				if cached.set_spell_pen and cached.set_spell_pen_name and not SetBonus.spell_pen[cached.set_spell_pen_name] then
					SetBonus.spell_pen[cached.set_spell_pen_name] = true
					BCScache["gear"].spell_pen = BCScache["gear"].spell_pen + cached.set_spell_pen
				end
				-- Priest set bonuses
				if playerClass == "PRIEST" then
					if cached.set_priest_holy and cached.set_priest_holy_name and not SetBonus.spellCritClass[cached.set_priest_holy_name] then
						SetBonus.spellCritClass[cached.set_priest_holy_name] = true
						BCScache["gear"].priest_holy_spells = BCScache["gear"].priest_holy_spells + cached.set_priest_holy
					end
					if cached.set_priest_prayer and cached.set_priest_prayer_name and not SetBonus.spellCritClass[cached.set_priest_prayer_name] then
						SetBonus.spellCritClass[cached.set_priest_prayer_name] = true
						BCScache["gear"].priest_prayer = BCScache["gear"].priest_prayer + cached.set_priest_prayer
					end
				end

				EquippedItems[slot] = itemLink
			end
		else
			EquippedItems[slot] = nil
		end
	end

	-- Scan weapon for temporary enhancements (wizard oils, mana oils)
	-- These must use SetInventoryItem, not SetHyperlink
	if BCS_Tooltip:SetInventoryItem("player", 16) then
		for line = 1, BCS_Tooltip:NumLines() do
			local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
			if text then
				if strfind(text, L["^Brilliant Wizard Oil"]) then
					BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 36
					BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + 1
					break
				elseif strfind(text, L["^Lesser Wizard Oil"]) then
					BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 16
					break
				elseif strfind(text, L["^Minor Wizard Oil"]) then
					BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 8
					break
				elseif strfind(text, L["^Wizard Oil"]) then
					BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 24
					break
				elseif strfind(text, L["^Brilliant Mana Oil"]) then
					BCScache["gear"].healing = BCScache["gear"].healing + 25
					BCScache["gear"].mp5 = BCScache["gear"].mp5 + 12
					break
				elseif strfind(text, L["^Lesser Mana Oil"]) then
					BCScache["gear"].mp5 = BCScache["gear"].mp5 + 8
					break
				elseif strfind(text, L["^Minor Mana Oil"]) then
					BCScache["gear"].mp5 = BCScache["gear"].mp5 + 4
					break
				end
			end
		end
	end
end

-- Talent cache variables (class-specific)
local TalentCache = {}
local impInnerFire = nil
local spiritualGuidance = nil
local ironClad = nil
local toughness = nil
local waterShield = nil
local vengefulStrikes = nil
local masterOfArms = nil
local enhancingTotems = nil

-- Unified talent scanning
local function ScanAllTalents()
	-- Reset talent cache values
	BCScache["talents"].hit = 0
	BCScache["talents"].spell_hit = 0
	BCScache["talents"].spell_hit_fire = 0
	BCScache["talents"].spell_hit_frost = 0
	BCScache["talents"].spell_hit_arcane = 0
	BCScache["talents"].spell_hit_shadow = 0
	BCScache["talents"].spell_hit_holy = 0
	BCScache["talents"].ranged_crit = 0
	BCScache["talents"].spell_crit = 0
	BCScache["talents"].damage_and_healing = 0
	BCScache["talents"].healing = 0
	BCScache["talents"].casting = 0
	BCScache["talents"].haste = 0
	BCScache["talents"].spell_haste = 0
	BCScache["talents"].armor_pen = 0
	BCScache["talents"].block_mod = 0
	BCScache["talents"].enhancing_totems = 0

	-- Reset class-specific talent variables
	impInnerFire = nil
	spiritualGuidance = nil
	ironClad = nil
	toughness = nil
	waterShield = nil
	vengefulStrikes = nil
	masterOfArms = nil
	enhancingTotems = nil

	-- Reset class-specific talent caches
	twipe(TalentCache)

	-- Scan all talents ONCE
	for tab = 1, GetNumTalentTabs() do
		for talent = 1, GetNumTalents(tab) do
			BCS_Tooltip:SetTalent(tab, talent)
			local _, _, _, _, rank = GetTalentInfo(tab, talent)
			if rank and rank > 0 then
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value

						-- ===== MELEE HIT =====
						-- Rogue
						_, _, value = strfind(text, L["Increases your chance to hit with melee weapons by (%d)%%."])
						if value then BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value) end

						-- Hunter
						_, _, value = strfind(text, L["Increases hit chance by (%d)%% and increases the chance movement impairing effects will be resisted by an additional %d+%%."])
						if value then BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value) end

						-- Druid Natural Weapons / Paladin Precision
						_, _, value = strfind(text, L["Also increases chance to hit with melee attacks and spells by (%d+)%%."])
						if value then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
						end

						_, _, value = strfind(text, L["Increases your chance to hit with melee attacks and spells by (%d+)%%."])
						if value then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
						end

						-- Shaman Elemental Devastation (proc)
						_, _, value = strfind(text, L["Increases your chance to hit with spells and melee attacks by (%d+)%%"])
						if value then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
						end

						-- ===== SPELL HIT (school-specific) =====
						-- Mage Elemental Precision
						_, _, value = strfind(text, L["Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%."])
						if value then
							BCScache["talents"].spell_hit_fire = BCScache["talents"].spell_hit_fire + tonumber(value)
							BCScache["talents"].spell_hit_frost = BCScache["talents"].spell_hit_frost + tonumber(value)
						end

						-- Mage Arcane Focus
						_, _, value = strfind(text, L["Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%."])
						if value then BCScache["talents"].spell_hit_arcane = BCScache["talents"].spell_hit_arcane + tonumber(value) end

						-- Priest Piercing Light
						_, _, value = strfind(text, L["Reduces the chance for enemies to resist your Holy and Discipline spells by (%d+)%%."])
						if value then BCScache["talents"].spell_hit_holy = BCScache["talents"].spell_hit_holy + tonumber(value) end

						-- Priest Shadow Focus
						_, _, value = strfind(text, L["Reduces your target's chance to resist your Shadow spells by (%d+)%%."])
						if value then BCScache["talents"].spell_hit_shadow = BCScache["talents"].spell_hit_shadow + tonumber(value) end

						-- Warlock Suppression
						_, _, value = strfind(text, L["Reduces the chance for enemies to resist your Affliction spells by (%d+)%%."])
						if value then BCScache["talents"].spell_hit_shadow = BCScache["talents"].spell_hit_shadow + tonumber(value) end

						-- ===== RANGED CRIT =====
						-- Hunter Lethal Shots
						_, _, value = strfind(text, L["Increases your critical strike chance with ranged weapons by (%d)%%."])
						if value then BCScache["talents"].ranged_crit = BCScache["talents"].ranged_crit + tonumber(value) end

						-- Hunter Killer Instinct
						_, _, value = strfind(text, L["Increases your critical strike chance with all attacks by (%d)%%."])
						if value then BCScache["talents"].ranged_crit = BCScache["talents"].ranged_crit + tonumber(value) end

						-- ===== SPELL CRIT =====
						-- Mage Arcane Instability
						_, _, value = strfind(text, L["Increases your spell damage and critical srike chance by (%d+)%%."])
						if value then BCScache["talents"].spell_crit = BCScache["talents"].spell_crit + tonumber(value) end

						-- ===== MANA REGEN =====
						-- Priest Meditation / Druid Reflection / Mage Arcane Meditation
						_, _, value = strfind(text, L["Allows (%d+)%% of your Mana regeneration to continue while casting."])
						if value then
							BCScache["talents"].casting = BCScache["talents"].casting + tonumber(value)
							waterShield = rank
						end

						-- ===== HASTE =====
						-- Priest Mental Strength
						_, _, value = strfind(text, L["Increases your total intellect by %d+%% and your spell casting speed by (%d+)%%"])
						if value then BCScache["talents"].spell_haste = BCScache["talents"].spell_haste + tonumber(value) end

						-- Paladin Vengeful Strikes
						_, _, value = strfind(text, L["Zeal increases your attack and casting speed by an additional (%d+)%% per stack"])
						if value then vengefulStrikes = tonumber(value) end

						-- Rogue Blade Rush
						_, _, value = strfind(text, L["Increases your melee attack speed by (%d+)%%"])
						if value then BCScache["talents"].haste = BCScache["talents"].haste + tonumber(value) end

						-- ===== ARMOR PEN =====
						-- Warrior Master of Arms
						_, _, value = strfind(text, L["Causes your attacks to ignore (%d+) of your target's Armor per level"])
						if value then masterOfArms = tonumber(value) * UnitLevel("player") end

						-- ===== CLASS-SPECIFIC TALENTS =====
						-- Priest Spiritual Guidance
						_, _, value = strfind(text, L["Increases spell damage and healing by up to (%d+)%% of your total Spirit."])
						if value then spiritualGuidance = tonumber(value) end

						-- Priest Improved Inner Fire
						_, _, value = strfind(text, L["Increases the effects of your Inner Fire spell by (%d+)%%."])
						if value then impInnerFire = tonumber(value) end

						-- Paladin Ironclad
						_, _, value = strfind(text, L["Increases your healing power by (%d+)%% of your Armor."])
						if value then ironClad = tonumber(value) end

						-- Paladin Toughness
						_, _, value = strfind(text, L["Increases your armor value from items by (%d+)%%."])
						if value then toughness = tonumber(value) end

						-- Shaman Enhancing Totems
						_, _, value = strfind(text, L["increases block amount by (%d+)%%"])
						if value then
							enhancingTotems = tonumber(value)
							BCScache["talents"].enhancing_totems = tonumber(value)
						end

						-- ===== BLOCK VALUE TALENTS =====
						-- Warrior/Paladin Shield Specialization
						_, _, value = strfind(text, L["amount of damage absorbed by your shield by (%d+)%%"])
						if value then BCScache["talents"].block_mod = BCScache["talents"].block_mod + tonumber(value) end

						-- Shaman Shield Specialization
						_, _, value = strfind(text, L["increases the amount blocked by (%d+)%%"])
						if value then BCScache["talents"].block_mod = BCScache["talents"].block_mod + tonumber(value) end

						-- ===== CLASS-SPECIFIC SPELL CRIT =====
						if playerClass == "PALADIN" then
							-- Holy Power
							_, _, value = strfind(text, L["Increases the critical effect chance of your Holy Light and Flash of Light by (%d+)%%."])
							if value then
								TalentCache.paladin_holy_light = (TalentCache.paladin_holy_light or 0) + tonumber(value)
								TalentCache.paladin_flash = (TalentCache.paladin_flash or 0) + tonumber(value)
							end
							-- Divine Favor
							_, _, value = strfind(text, L["Improves your chance to get a critical strike with Holy Shock by (%d+)%%."])
							if value then TalentCache.paladin_shock = (TalentCache.paladin_shock or 0) + tonumber(value) end

						elseif playerClass == "DRUID" then
							-- Improved Moonfire
							_, _, value = strfind(text, L["Increases the damage and critical strike chance of your Moonfire spell by (%d+)%%."])
							if value then TalentCache.druid_moonfire = (TalentCache.druid_moonfire or 0) + tonumber(value) end
							-- Improved Regrowth
							_, _, value = strfind(text, L["Increases the critical effect chance of your Regrowth spell by (%d+)%%."])
							if value then TalentCache.druid_regrowth = (TalentCache.druid_regrowth or 0) + tonumber(value) end

						elseif playerClass == "WARLOCK" then
							-- Devastation
							_, _, value = strfind(text, L["Increases the critical strike chance of your Destruction spells by (%d+)%%."])
							if value then
								TalentCache.warlock_destruction_spells = (TalentCache.warlock_destruction_spells or 0) + tonumber(value)
								TalentCache.warlock_searing_pain = (TalentCache.warlock_searing_pain or 0) + tonumber(value)
							end
							-- Improved Searing Pain
							_, _, value = strfind(text, L["Increases the critical strike chance of your Searing Pain spell by (%d+)%%."])
							if value then TalentCache.warlock_searing_pain = (TalentCache.warlock_searing_pain or 0) + tonumber(value) end

						elseif playerClass == "MAGE" then
							-- Arcane Impact
							_, _, value = strfind(text, L["Increases the critical strike chance of your Arcane Explosion and Arcane Missiles spells by an additional (%d+)%%."])
							if value then TalentCache.mage_arcane_spells = (TalentCache.mage_arcane_spells or 0) + tonumber(value) end
							-- Incinerate
							_, _, value = strfind(text, L["Increases the critical strike chance of your Fire Blast and Scorch spells by (%d+)%%."])
							if value then
								TalentCache.mage_fireblast = (TalentCache.mage_fireblast or 0) + tonumber(value)
								TalentCache.mage_scorch = (TalentCache.mage_scorch or 0) + tonumber(value)
							end
							-- Improved Flamestrike
							_, _, value = strfind(text, L["Increases the critical strike chance of your Flamestrike spell by (%d+)%%."])
							if value then TalentCache.mage_flamestrike = (TalentCache.mage_flamestrike or 0) + tonumber(value) end
							-- Critical Mass
							_, _, value = strfind(text, L["Increases the critical strike chance of your Fire spells by (%d+)%%."])
							if value then
								TalentCache.mage_fire_spells = (TalentCache.mage_fire_spells or 0) + tonumber(value)
								TalentCache.mage_fireblast = (TalentCache.mage_fireblast or 0) + tonumber(value)
								TalentCache.mage_flamestrike = (TalentCache.mage_flamestrike or 0) + tonumber(value)
								TalentCache.mage_scorch = (TalentCache.mage_scorch or 0) + tonumber(value)
							end
							-- Shatter
							_, _, value = strfind(text, L["Increases the critical strike chance of all your spells against frozen targets by (%d+)%%."])
							if value then TalentCache.mage_shatter = (TalentCache.mage_shatter or 0) + tonumber(value) end

						elseif playerClass == "PRIEST" then
							-- Divinity
							_, _, value = strfind(text, L["Increases the critical effect chance of your Holy and Discipline spells by (%d+)%%."])
							if value then
								TalentCache.priest_holy_spells = (TalentCache.priest_holy_spells or 0) + tonumber(value)
								TalentCache.priest_discipline_spells = (TalentCache.priest_discipline_spells or 0) + tonumber(value)
							end
							-- Force of Will
							_, _, value = strfind(text, L["Increases your spell damage and the critical strike chance of your offensive spells by (%d+)%%"])
							if value then TalentCache.priest_offensive_spells = (TalentCache.priest_offensive_spells or 0) + tonumber(value) end

						elseif playerClass == "SHAMAN" then
							-- Call of Thunder
							_, _, value = strfind(text, L["Increases the critical strike chance of your Lightning Bolt and Chain Lightning spells by an additional (%d+)%%."])
							if value then
								TalentCache.shaman_lightning_bolt = (TalentCache.shaman_lightning_bolt or 0) + tonumber(value)
								TalentCache.shaman_chain_lightning = (TalentCache.shaman_chain_lightning or 0) + tonumber(value)
							end
							-- Tidal Mastery
							_, _, value = strfind(text, L["Increases the critical effect chance of your healing and lightning spells by (%d+)%%."])
							if value then
								TalentCache.shaman_lightning_bolt = (TalentCache.shaman_lightning_bolt or 0) + tonumber(value)
								TalentCache.shaman_chain_lightning = (TalentCache.shaman_chain_lightning or 0) + tonumber(value)
								TalentCache.shaman_lightning_shield = (TalentCache.shaman_lightning_shield or 0) + tonumber(value)
								TalentCache.shaman_healing_spells = (TalentCache.shaman_healing_spells or 0) + tonumber(value)
							end
						end
					end
				end
			end
		end
	end
end

-- Aura cache for quick lookups
local AuraCache = {
	buffs = {},  -- text -> count (multiple buffs can have same text)
	debuffs = {}, -- text -> count
	zealStacks = 0,       -- cached during main scan
	waterShieldStacks = 0 -- cached during main scan
}

-- Buff parse cache: stores parsed stat values keyed by tooltip text
-- This avoids re-parsing the same buff text repeatedly when auras change
-- Structure: BuffTextParseCache[text] = { stat_key = value } or false if no stats found
local BuffTextParseCache = {}
local DebuffTextParseCache = {}

-- Parse a single buff text line and return a table of found stats
-- Returns false if no stats found, or a table of {stat_key = value}
local function ParseBuffText(text)
	local result = {}
	local found = false
	local _, _, value, value2

	-- ===== HIT =====
	_, _, value = strfind(text, L["Chance to hit increased by (%d)%%."])
	if value then result.hit = (result.hit or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Improves your chance to hit by (%d+)%%."])
	if value then result.hit = (result.hit or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases attack power by %d+ and chance to hit by (%d+)%%."])
	if value then result.hit = (result.hit or 0) + tonumber(value); found = true end

	-- ===== SPELL HIT =====
	_, _, value = strfind(text, L["Spell hit chance increased by (%d+)%%."])
	if value then result.spell_hit = (result.spell_hit or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases your chance to hit with spells by (%d+)%%"])
	if value then result.spell_hit = (result.spell_hit or 0) + tonumber(value); found = true end

	-- ===== RANGED CRIT =====
	if strfind(text, L["Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration."]) then
		result.ranged_crit = (result.ranged_crit or 0) + 5
		result.spell_crit = (result.spell_crit or 0) + 10
		found = true
	end

	_, _, value = strfind(text, L["Agility increased by 25, Critical hit chance increases by (%d)%%."])
	if value then result.ranged_crit = (result.ranged_crit or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+."])
	if value then
		result.ranged_crit = (result.ranged_crit or 0) + tonumber(value)
		result.spell_crit = (result.spell_crit or 0) + tonumber(value)
		found = true
	end

	_, _, value = strfind(text, L["Critical strike chance increased by (%d+)%%."])
	if value then result.ranged_crit = (result.ranged_crit or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases ranged and melee critical chance by (%d+)%%."])
	if value then result.ranged_crit = (result.ranged_crit or 0) + tonumber(value); found = true end

	-- ===== SPELL CRIT =====
	_, _, value = strfind(text, L["Chance for a critical hit with a spell increased by (%d+)%%."])
	if value then result.spell_crit = (result.spell_crit or 0) + tonumber(value); found = true end

	if strfind(text, L["Inner Focus"]) then
		result.spell_crit = (result.spell_crit or 0) + 25
		found = true
	end

	_, _, value = strfind(text, L["Increases spell critical chance by (%d)%%."])
	if value then result.spell_crit = (result.spell_crit or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Chance to get a critical strike with spells is increased by (%d+)%%"])
	if value then result.spell_crit = (result.spell_crit or 0) + tonumber(value); found = true end

	if strfind(text, L["While active, target's critical hit chance with spells and attacks increases by 10%%."]) then
		result.spell_crit = (result.spell_crit or 0) + 10
		found = true
	end

	_, _, value = strfind(text, L["Critical strike chance with spells and melee attacks increased by (%d+)%%."])
	if value then result.spell_crit = (result.spell_crit or 0) + tonumber(value); found = true end

	-- ===== SPELL POWER =====
	_, _, value = strfind(text, L["Magical damage dealt is increased by up to (%d+)."])
	if value then result.only_damage = (result.only_damage or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases damage and healing done by magical spells and effects by up to (%d+)%."])
	if value then result.damage_and_healing = (result.damage_and_healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Magical damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.only_damage = (result.only_damage or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Spell damage is increased by up to (%d+)"])
	if value then result.only_damage = (result.only_damage or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Spell damage increased by up to (%d+)"])
	if value then result.only_damage = (result.only_damage or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Spell Damage increased by (%d+)"])
	if value then result.only_damage = (result.only_damage or 0) + tonumber(value); found = true end

	-- Inner Fire (raw value, talent modifier applied later)
	_, _, value = strfind(text, L["Increased damage done by magical spells and effects by (%d+)."])
	if value then result.inner_fire = tonumber(value); found = true end

	-- School-specific auras
	_, _, value = strfind(text, L["Arcane damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.arcane = (result.arcane or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Fire damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.fire = (result.fire or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Frost damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.frost = (result.frost or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Holy damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.holy = (result.holy or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Nature damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.nature = (result.nature or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Shadow damage dealt by spells and abilities is increased by up to (%d+)"])
	if value then result.shadow = (result.shadow or 0) + tonumber(value); found = true end

	-- ===== HEALING =====
	_, _, value = strfind(text, L["Healing done by magical spells is increased by up to (%d+)."])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases healing done by magical spells by up to (%d+) for 3600 sec."])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Healing increased by up to (%d+)."])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Healing spells increased by up to (%d+)."])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Increases healing done by magical spells and effects by up to (%d+)."])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Healing done is increased by up to (%d+)"])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Healing Bonus increased by (%d+)"])
	if value then result.healing = (result.healing or 0) + tonumber(value); found = true end

	-- ===== MP5 =====
	_, _, value = strfind(text, L["Increases hitpoints by 300. 15%% haste to melee attacks. (%d+) mana regen every 5 seconds."])
	if value then result.mp5 = (result.mp5 or 0) + 10; found = true end

	_, _, value = strfind(text, L["Restores (%d+) mana per 5 sec."])
	if value then result.mp5 = (result.mp5 or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Regenerating (%d+) Mana every 5 seconds."])
	if value then result.mp5 = (result.mp5 or 0) + tonumber(value) * 2.5; found = true end

	_, _, value = strfind(text, L["Regenerate (%d+) mana per 5 sec."])
	if value then result.mp5 = (result.mp5 or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Mana Regeneration increased by (%d+) every 5 seconds."])
	if value then result.mp5 = (result.mp5 or 0) + tonumber(value) * 2.5; found = true end

	_, _, value = strfind(text, L["Restores (%d+) mana every 1 sec."])
	if value then result.mp5 = (result.mp5 or 0) + tonumber(value) * 5; found = true end

	_, _, value = strfind(text, L["Restores (%d+) mana per 5 seconds."])
	if value then result.mp5 = (result.mp5 or 0) + tonumber(value); found = true end

	-- ===== CASTING % =====
	_, _, value = strfind(text, L["(%d+)%% of your Mana regeneration continuing while casting."])
	if value then result.casting = (result.casting or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["(%d+)%% of your mana regeneration to continue while casting."])
	if value then result.casting = (result.casting or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Allows (%d+)%% of mana regeneration while casting."])
	if value then result.casting = (result.casting or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["continue (%d+)%% of their Mana regeneration"])
	if value then result.casting = (result.casting or 0) + tonumber(value); found = true end

	-- ===== HASTE =====
	_, _, value, value2 = strfind(text, L["^Increases attack speed by (%d+)%% and spell casting speed by (%d+)%%"])
	if value then result.haste = (result.haste or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["^Increases attack and spell casting speed by (%d+)%%"])
	if value then result.haste = (result.haste or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["increases casting speed by (%d+)%%"])
	if value then result.spell_haste = (result.spell_haste or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["^Increases casting and attack speed by (%d+)%%"])
	if value then result.haste = (result.haste or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["^Increases attack and casting speed by (%d+)%%"])
	if value then result.haste = (result.haste or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["^Casting speed increased by (%d+)%%"])
	if value then result.spell_haste = (result.spell_haste or 0) + tonumber(value); found = true end

	-- Zeal base haste (raw value, vengeful strikes modifier applied later)
	_, _, value = strfind(text, L["^Attack and casting speed increased by (%d+)%%"])
	if value then result.zeal_haste = tonumber(value); found = true end

	_, _, value = strfind(text, L["^Increases your attack and casting speed by (%d+)%%"])
	if value then result.haste = (result.haste or 0) + tonumber(value); found = true end

	-- ===== ARMOR PEN =====
	_, _, value = strfind(text, L["^Ignore (%d+) of enemies' armor"])
	if value then result.armor_pen = (result.armor_pen or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["^Current target's armor is reduced by (%d+)"])
	if value then result.armor_pen = (result.armor_pen or 0) + tonumber(value); found = true end

	-- ===== CLASS-SPECIFIC AURAS =====
	if playerClass == "WARLOCK" then
		_, _, value = strfind(text, L["Increases critical strike chance of Fire spells by (%d+)%%"])
		if value then result.warlock_fire_spells = tonumber(value); found = true end
	elseif playerClass == "MAGE" then
		_, _, value = strfind(text, L["Increases critical strike chance from Fire damage spells by (%d+)%%."])
		if value then result.mage_fire_spells = tonumber(value); found = true end
	elseif playerClass == "SHAMAN" then
		if strfind(text, L["Elemental Mastery"]) then
			result.shaman_elemental_mastery = true
			found = true
		end
	end

	return found and result or false
end

-- Parse a single debuff text line and return a table of found stats
local function ParseDebuffText(text)
	local result = {}
	local found = false
	local _, _, value

	_, _, value = strfind(text, L["Chance to hit reduced by (%d+)%%."])
	if value then result.hit_debuff = (result.hit_debuff or 0) + tonumber(value); found = true end

	_, _, value = strfind(text, L["Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec."])
	if value then result.hit_debuff = (result.hit_debuff or 0) + tonumber(value); found = true end

	if strfind(text, L["Lowered chance to hit."]) then
		result.hit_debuff = (result.hit_debuff or 0) + 25
		found = true
	end

	_, _, value = strfind(text, L["Spell critical-hit chance reduced by (%d+)%%."])
	if value then result.spell_crit_debuff = tonumber(value); found = true end

	return found and result or false
end

-- Apply cached buff stats to BCScache["auras"], handling dynamic modifiers
-- count: number of times this text appeared (for duplicate buff text)
local function ApplyBuffStats(stats, count)
	if not stats then return end
	count = count or 1

	-- Direct stat additions (multiplied by count)
	if stats.hit then BCScache["auras"].hit = BCScache["auras"].hit + stats.hit * count end
	if stats.spell_hit then BCScache["auras"].spell_hit = BCScache["auras"].spell_hit + stats.spell_hit * count end
	if stats.ranged_crit then BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + stats.ranged_crit * count end
	if stats.spell_crit then BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + stats.spell_crit * count end
	if stats.only_damage then BCScache["auras"].only_damage = BCScache["auras"].only_damage + stats.only_damage * count end
	if stats.damage_and_healing then BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + stats.damage_and_healing * count end
	if stats.arcane then BCScache["auras"].arcane = BCScache["auras"].arcane + stats.arcane * count end
	if stats.fire then BCScache["auras"].fire = BCScache["auras"].fire + stats.fire * count end
	if stats.frost then BCScache["auras"].frost = BCScache["auras"].frost + stats.frost * count end
	if stats.holy then BCScache["auras"].holy = BCScache["auras"].holy + stats.holy * count end
	if stats.nature then BCScache["auras"].nature = BCScache["auras"].nature + stats.nature * count end
	if stats.shadow then BCScache["auras"].shadow = BCScache["auras"].shadow + stats.shadow * count end
	if stats.healing then BCScache["auras"].healing = BCScache["auras"].healing + stats.healing * count end
	if stats.mp5 then BCScache["auras"].mp5 = BCScache["auras"].mp5 + stats.mp5 * count end
	if stats.casting then BCScache["auras"].casting = BCScache["auras"].casting + stats.casting * count end
	if stats.haste then BCScache["auras"].haste = BCScache["auras"].haste + stats.haste * count end
	if stats.spell_haste then BCScache["auras"].spell_haste = BCScache["auras"].spell_haste + stats.spell_haste * count end
	if stats.armor_pen then BCScache["auras"].armor_pen = BCScache["auras"].armor_pen + stats.armor_pen * count end

	-- Inner Fire with talent modifier (multiplied by count)
	if stats.inner_fire then
		local value = stats.inner_fire
		if impInnerFire then
			value = floor((value * (impInnerFire / 100)) + value)
		end
		BCScache["auras"].only_damage = BCScache["auras"].only_damage + value * count
	end

	-- Zeal with Vengeful Strikes modifier (uses cached stacks from main scan)
	-- Note: count not applied here as zeal stacks are already tracked separately
	if stats.zeal_haste then
		local value = stats.zeal_haste
		if vengefulStrikes and AuraCache.zealStacks > 0 then
			value = value + (vengefulStrikes * AuraCache.zealStacks)
		end
		BCScache["auras"].haste = BCScache["auras"].haste + value
	end

	-- Class-specific TalentCache updates (multiplied by count)
	if stats.warlock_fire_spells then
		TalentCache.warlock_fire_spells = (TalentCache.warlock_fire_spells or 0) + stats.warlock_fire_spells * count
	end
	if stats.mage_fire_spells then
		TalentCache.mage_fire_spells = (TalentCache.mage_fire_spells or 0) + stats.mage_fire_spells * count
		TalentCache.mage_fireblast = (TalentCache.mage_fireblast or 0) + stats.mage_fire_spells * count
		TalentCache.mage_flamestrike = (TalentCache.mage_flamestrike or 0) + stats.mage_fire_spells * count
		TalentCache.mage_scorch = (TalentCache.mage_scorch or 0) + stats.mage_fire_spells * count
	end
	if stats.shaman_elemental_mastery then
		TalentCache.shaman_lightning_bolt = 100
		TalentCache.shaman_chain_lightning = 100
		TalentCache.shaman_firefrost_spells = 100
	end
end

-- Apply cached debuff stats to BCScache["auras"]
-- count: number of times this text appeared
local function ApplyDebuffStats(stats, count)
	if not stats then return end
	count = count or 1

	if stats.hit_debuff then BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + stats.hit_debuff * count end
	if stats.spell_crit_debuff then BCScache["auras"].spell_crit = BCScache["auras"].spell_crit - stats.spell_crit_debuff * count end
end

-- Unified aura scanning
local function ScanAllAuras()
	-- Reset aura cache values
	BCScache["auras"].hit = 0
	BCScache["auras"].hit_debuff = 0
	BCScache["auras"].spell_hit = 0
	BCScache["auras"].ranged_crit = 0
	BCScache["auras"].spell_crit = 0
	BCScache["auras"].damage_and_healing = 0
	BCScache["auras"].only_damage = 0
	BCScache["auras"].arcane = 0
	BCScache["auras"].fire = 0
	BCScache["auras"].frost = 0
	BCScache["auras"].holy = 0
	BCScache["auras"].nature = 0
	BCScache["auras"].shadow = 0
	BCScache["auras"].healing = 0
	BCScache["auras"].mp5 = 0
	BCScache["auras"].casting = 0
	BCScache["auras"].haste = 0
	BCScache["auras"].spell_haste = 0
	BCScache["auras"].armor_pen = 0

	-- Reset aura text cache
	twipe(AuraCache.buffs)
	twipe(AuraCache.debuffs)
	AuraCache.zealStacks = 0
	AuraCache.waterShieldStacks = 0

	-- Scan all buffs ONCE and cache their tooltip text + specific stacks we need
	for i = 0, 31 do
		local index = GetPlayerBuff(i, "HELPFUL")
		if index > -1 then
			-- Cache icon/stacks for buffs we need later (avoids re-looping)
			local icon, stacks = UnitBuff("player", i)
			if icon then
				if icon == "Interface\\Icons\\Spell_Holy_CrusaderStrike" then
					AuraCache.zealStacks = stacks or 0
				elseif icon == "Interface\\Icons\\Ability_Shaman_WaterShield" then
					AuraCache.waterShieldStacks = stacks or 0
				end
			end

			BCS_Tooltip:SetPlayerBuff(index)
			for line = 1, BCS_Tooltip:NumLines() do
				local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
				if text then
					AuraCache.buffs[text] = (AuraCache.buffs[text] or 0) + 1
				end
			end
		end
	end

	-- Scan debuffs
	for i = 0, 6 do
		local index = GetPlayerBuff(i, "HARMFUL")
		if index > -1 then
			BCS_Tooltip:SetPlayerBuff(index)
			for line = 1, BCS_Tooltip:NumLines() do
				local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
				if text then
					AuraCache.debuffs[text] = (AuraCache.debuffs[text] or 0) + 1
				end
			end
		end
	end

	-- Process buffs using parse cache
	for text, count in pairs(AuraCache.buffs) do
		-- Check parse cache first
		local cached = BuffTextParseCache[text]
		if cached == nil then
			-- Not in cache, parse and store result
			cached = ParseBuffText(text)
			BuffTextParseCache[text] = cached
		end
		-- Apply cached stats (false means no stats found, skip)
		-- Multiply by count in case multiple buffs have same text
		if cached then
			ApplyBuffStats(cached, count)
		end
	end

	-- Process debuffs using parse cache
	for text, count in pairs(AuraCache.debuffs) do
		-- Check parse cache first
		local cached = DebuffTextParseCache[text]
		if cached == nil then
			-- Not in cache, parse and store result
			cached = ParseDebuffText(text)
			DebuffTextParseCache[text] = cached
		end
		-- Apply cached stats (false means no stats found, skip)
		if cached then
			ApplyDebuffStats(cached, count)
		end
	end

	-- Handle Improved Shadowform (requires scanning spellbook)
	if playerClass == "PRIEST" then
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, numSpells = GetSpellTabInfo(tab)
			for s = offset + 1, offset + numSpells do
				local spell = GetSpellName(s, BOOKTYPE_SPELL)
				if spell == L["Improved Shadowform"] and (AuraCache.buffs[L["Shadowform"]] or 0) > 0 then
					BCScache["auras"].casting = BCScache["auras"].casting + 15
					break
				end
			end
		end
	end

	-- Handle Improved Water Shield (uses cached stacks from main scan)
	if waterShield and AuraCache.waterShieldStacks > 0 then
		BCScache["auras"].casting = BCScache["auras"].casting + (AuraCache.waterShieldStacks * waterShield)
	end
end

-- Run all scans based on dirty flags
function BCS:RunScans()
	if BCS.needScanGear then
		ScanAllGear()
	end
	if BCS.needScanTalents then
		ScanAllTalents()
	end
	if BCS.needScanAuras then
		ScanAllAuras()
	end
end

-- Expose scan functions for external use
BCS.ScanAllGear = ScanAllGear
BCS.ScanAllTalents = ScanAllTalents
BCS.ScanAllAuras = ScanAllAuras

-- Helper to check if aura text exists (for compatibility with existing code)
function BCS:HasAura(searchText, auraType)
	if not auraType then
		for text, _ in pairs(AuraCache.buffs) do
			if strfind(text, searchText) then
				return true
			end
		end
	else
		for text, _ in pairs(AuraCache.debuffs) do
			if strfind(text, searchText) then
				return true
			end
		end
	end
	return false
end

-- GetPlayerAura now uses the cached aura text from ScanAllAuras
function BCS:GetPlayerAura(searchText, auraType)
	local cache = auraType == "HARMFUL" and AuraCache.debuffs or AuraCache.buffs

	-- Check if we have any cached auras (if not, we need to scan first)
	local hasCache = false
	for _ in pairs(cache) do hasCache = true; break end
	if not hasCache then
		-- Fallback to direct scan if cache is empty
		if not auraType then
			local _, numValues = gsub(searchText, "%(%%d%+?%)", "")
			if numValues > 0 then
				local total1, total2 = 0, 0
				local s, e
				for i = 0, 31 do
					local index = GetPlayerBuff(i, "HELPFUL")
					if index > -1 then
						BCS_Tooltip:SetPlayerBuff(index)
						for line = 1, BCS_Tooltip:NumLines() do
							local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
							if text then
								local _s, _e, amount, amount2 = strfind(text, searchText)
								if amount then
									total1 = total1 + tonumber(amount)
									s, e = _s, _e
								end
								if amount2 then
									total2 = total2 + tonumber(amount2)
									s, e = _s, _e
								end
							end
						end
					end
				end
				total1 = total1 > 0 and total1 or nil
				total2 = total2 > 0 and total2 or nil
				return s, e, total1, total2
			end
			for i = 0, 31 do
				local index = GetPlayerBuff(i, "HELPFUL")
				if index > -1 then
					BCS_Tooltip:SetPlayerBuff(index)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							if strfind(text, searchText) then
								return strfind(text, searchText)
							end
						end
					end
				end
			end
		else
			for i = 0, 6 do
				local index = GetPlayerBuff(i, auraType)
				if index > -1 then
					BCS_Tooltip:SetPlayerBuff(index)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							if strfind(text, searchText) then
								return strfind(text, searchText)
							end
						end
					end
				end
			end
		end
		return nil
	end

	-- Use cached aura text
	local _, numValues = gsub(searchText, "%(%%d%+?%)", "")
	if numValues > 0 then
		local total1, total2 = 0, 0
		local s, e
		for text, _ in pairs(cache) do
			local _s, _e, amount, amount2 = strfind(text, searchText)
			if amount then
				total1 = total1 + tonumber(amount)
				s, e = _s, _e
			end
			if amount2 then
				total2 = total2 + tonumber(amount2)
				s, e = _s, _e
			end
		end
		total1 = total1 > 0 and total1 or nil
		total2 = total2 > 0 and total2 or nil
		return s, e, total1, total2
	end

	for text, _ in pairs(cache) do
		if strfind(text, searchText) then
			return strfind(text, searchText)
		end
	end
	return nil
end

function BCS:GetHitRating(hitOnly)
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	local hit = BCScache["talents"].hit + BCScache["gear"].hit + BCScache["auras"].hit
	if not hitOnly then
		hit = hit - BCScache["auras"].hit_debuff
		if hit < 0 then
			hit = 0
		end
		return hit
	else
		return hit
	end
end

function BCS:GetRangedHitRating()
	-- All scanning now done by ScanAllGear
	local ranged_hit = BCS:GetHitRating(true) + BCScache["gear"].ranged_hit - BCScache["auras"].hit_debuff
	if ranged_hit < 0 then
		ranged_hit = 0
	end
	return ranged_hit
end

function BCS:GetSpellHitRating()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	local hit = BCScache["gear"].spell_hit + BCScache["talents"].spell_hit + BCScache["auras"].spell_hit
	local hit_fire = BCScache["talents"].spell_hit_fire
	local hit_frost = BCScache["talents"].spell_hit_frost
	local hit_arcane = BCScache["talents"].spell_hit_arcane
	local hit_shadow = BCScache["talents"].spell_hit_shadow
	local hit_holy = BCScache["talents"].spell_hit_holy
	return hit, hit_fire, hit_frost, hit_arcane, hit_shadow, hit_holy
end

function BCS:GetCritChance()
	local crit = 0
	-- Spellbook
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(tab)
		for spell = 1, numSpells do
			local currentPage = ceil(spell / SPELLS_PER_PAGE)
			local SpellID = spell + offset + (SPELLS_PER_PAGE * (currentPage - 1))
			BCS_Tooltip:SetSpell(SpellID, BOOKTYPE_SPELL)
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					local _, _, value = strfind(text, L["([%d.]+)%% chance to crit"])
					if value then
						crit = crit + tonumber(value)
						break
					end
				end
			end
		end
	end

	return crit
end

function BCS:GetRangedCritChance()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	-- values from vmangos core
	local crit = 0
	local _, agility = UnitStat("player", 2)
	local vallvl1 = 0
	local vallvl60 = 0
	local classrate = 0

	if playerClass == "MAGE" then
		vallvl1 = 12.9
		vallvl60 = 20
	elseif playerClass == "ROGUE" then
		vallvl1 = 2.2
		vallvl60 = 29
	elseif playerClass == "HUNTER" then
		vallvl1 = 3.5
		vallvl60 = 53
	elseif playerClass == "PRIEST" then
		vallvl1 = 11
		vallvl60 = 20
	elseif playerClass == "WARLOCK" then
		vallvl1 = 8.4
		vallvl60 = 20
	elseif playerClass == "WARRIOR" then
		vallvl1 = 3.9
		vallvl60 = 20
	else
		return crit
	end

	classrate = vallvl1 * (60 - UnitLevel("player")) / 59 + vallvl60 * (UnitLevel("player") - 1) / 59
	crit = agility / classrate

	if playerClass == "MAGE" then
		crit = crit + 3.2
	elseif playerClass == "PRIEST" then
		crit = crit + 3
	elseif playerClass == "WARLOCK" then
		crit = crit + 2
	end

	crit = crit + BCScache["gear"].ranged_crit + BCScache["talents"].ranged_crit + BCScache["auras"].ranged_crit

	return crit
end

function BCS:GetSpellCritChance()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	local spellCrit = 0
	local _, intellect = UnitStat("player", 4)

	-- values from vmangos core
	local playerLevel = UnitLevel("player")
	if playerClass == "MAGE" then
		spellCrit = 3.7 + intellect / (14.77 + .65 * playerLevel)
	elseif playerClass == "WARLOCK" then
		spellCrit = 3.18 + intellect / (11.30 + .82 * playerLevel)
	elseif playerClass == "PRIEST" then
		spellCrit = 2.97 + intellect / (10.03 + .82 * playerLevel)
	elseif playerClass == "DRUID" then
		spellCrit = 3.33 + intellect / (12.41 + .79 * playerLevel)
	elseif playerClass == "SHAMAN" then
		spellCrit = 3.54 + intellect / (11.51 + .8 * playerLevel)
	elseif playerClass == "PALADIN" then
		spellCrit = 3.7 + intellect / (14.77 + .65 * playerLevel)
	end

	spellCrit = spellCrit + BCScache["talents"].spell_crit + BCScache["gear"].spell_crit + BCScache["auras"].spell_crit

	return spellCrit
end

function BCS:GetSpellCritFromClass(class)
	-- All scanning now done by ScanAllTalents/ScanAllAuras
	if not class then
		return 0, 0, 0, 0, 0, 0
	end

	if class == "PALADIN" then
		return TalentCache.paladin_holy_light or 0,
			TalentCache.paladin_flash or 0,
			TalentCache.paladin_shock or 0, 0, 0, 0

	elseif class == "DRUID" then
		return TalentCache.druid_moonfire or 0,
			TalentCache.druid_regrowth or 0, 0, 0, 0, 0

	elseif class == "WARLOCK" then
		return TalentCache.warlock_destruction_spells or 0,
			TalentCache.warlock_searing_pain or 0,
			TalentCache.warlock_fire_spells or 0, 0, 0, 0

	elseif class == "MAGE" then
		return TalentCache.mage_arcane_spells or 0,
			TalentCache.mage_fire_spells or 0,
			TalentCache.mage_fireblast or 0,
			TalentCache.mage_scorch or 0,
			TalentCache.mage_flamestrike or 0,
			TalentCache.mage_shatter or 0

	elseif class == "PRIEST" then
		local holySpells = (TalentCache.priest_holy_spells or 0) + BCScache["gear"].priest_holy_spells
		return holySpells,
			TalentCache.priest_discipline_spells or 0,
			TalentCache.priest_offensive_spells or 0,
			BCScache["gear"].priest_prayer, 0, 0

	elseif class == "SHAMAN" then
		local lightningBolt = (TalentCache.shaman_lightning_bolt or 0)
		local chainLightning = (TalentCache.shaman_chain_lightning or 0)
		return lightningBolt, chainLightning,
			TalentCache.shaman_lightning_shield or 0,
			TalentCache.shaman_firefrost_spells or 0,
			TalentCache.shaman_healing_spells or 0, 0

	else
		return 0, 0, 0, 0, 0, 0
	end
end

function BCS:GetSpellPower(school)
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	if school then
		local key = strlower(school)
		return (BCScache["gear"][key] or 0) + (BCScache["auras"][key] or 0)
	else
		-- Calculate talent bonus from spirit if applicable
		local talentDamageAndHealing = 0
		if spiritualGuidance then
			local _, spirit = UnitStat("player", 5)
			talentDamageAndHealing = floor((spiritualGuidance / 100) * spirit)
		end

		local damageAndHealing = BCScache["gear"].damage_and_healing + talentDamageAndHealing + BCScache["auras"].damage_and_healing
		local damageOnly = BCScache["auras"].only_damage + BCScache["gear"].only_damage

		-- Find highest school-specific power
		local secondaryPower = 0
		local secondaryPowerName = ""
		local arcane = BCScache["gear"].arcane + BCScache["auras"].arcane
		local fire = BCScache["gear"].fire + BCScache["auras"].fire
		local frost = BCScache["gear"].frost + BCScache["auras"].frost
		local nature = BCScache["gear"].nature + BCScache["auras"].nature
		local shadow = BCScache["gear"].shadow + BCScache["auras"].shadow
		local holy = BCScache["gear"].holy + BCScache["auras"].holy

		if arcane > secondaryPower then
			secondaryPower = arcane
			secondaryPowerName = L.SPELL_SCHOOL_ARCANE
		end
		if fire > secondaryPower then
			secondaryPower = fire
			secondaryPowerName = L.SPELL_SCHOOL_FIRE
		end
		if frost > secondaryPower then
			secondaryPower = frost
			secondaryPowerName = L.SPELL_SCHOOL_FROST
		end
		if holy > secondaryPower then
			secondaryPower = holy
			secondaryPowerName = L.SPELL_SCHOOL_HOLY
		end
		if nature > secondaryPower then
			secondaryPower = nature
			secondaryPowerName = L.SPELL_SCHOOL_NATURE
		end
		if shadow > secondaryPower then
			secondaryPower = shadow
			secondaryPowerName = L.SPELL_SCHOOL_SHADOW
		end

		return damageAndHealing, secondaryPower, secondaryPowerName, damageOnly
	end
end

-- This is stuff that gives ONLY healing, we count stuff that gives both damage and healing in GetSpellPower
function BCS:GetHealingPower()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	local treebonus = nil

	-- Check for Tree of Life aura
	local found = BCS:GetPlayerAura(L["Tree of Life Form"]) and BCS:GetPlayerAura(L["Tree of Life Aura"])
	if found then
		local _, spirit = UnitStat("player", 5)
		treebonus = spirit * 0.2
	end

	-- Calculate talent healing from Ironclad if applicable
	local talentHealing = 0
	if ironClad then
		local base = UnitArmor("player")
		local _, agility = UnitStat("player", 2)
		local armorFromGear = base - (agility * 2)
		if toughness then
			armorFromGear = armorFromGear / (1 + toughness / 100)
		end
		talentHealing = floor((ironClad / 100) * armorFromGear)
	end

	local healPower = BCScache["gear"].healing + BCScache["auras"].healing + talentHealing

	return healPower, treebonus, talentHealing
end

function BCS:GetManaRegen()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	local _, spirit = UnitStat("player", 5)
	local base = 0

	if playerClass == "DRUID" then
		base = (spirit / 5 + 15)
	elseif playerClass == "HUNTER" then
		base = (spirit / 5 + 15)
	elseif playerClass == "MAGE" then
		base = (spirit / 4 + 12.5)
	elseif playerClass == "PALADIN" then
		base = (spirit / 5 + 15)
	elseif playerClass == "PRIEST" then
		base = (spirit / 4 + 12.5)
	elseif playerClass == "SHAMAN" then
		base = (spirit / 5 + 17)
	elseif playerClass == "WARLOCK" then
		base = (spirit / 5 + 15)
	end

	-- Check for Innervate (modifies base)
	local _, _, value, castingFromAura = BCS:GetPlayerAura(L["Mana regeneration increased by (%d+)%%.  (%d+)%% Mana regeneration may continue while casting."])
	if value then
		base = base + (base * (tonumber(value) / 100))
	end

	local casting = BCScache["auras"].casting + BCScache["talents"].casting + BCScache["gear"].casting
	local mp5 = BCScache["auras"].mp5 + BCScache["gear"].mp5

	-- Human racial
	local _, race = UnitRace("player")
	if race == "Human" then
		casting = casting + 5
	end
	if casting > 100 then
		casting = 100
	end

	return base, casting, mp5
end

--Weapon Skill code adapted from https://github.com/pepopo978/BetterCharacterStats
function BCS:GetWeaponSkill(skillName)
	-- loop through skills
	local skillIndex = 1
	while true do
		local name, _, _, skillRank, _, skillModifier = GetSkillLineInfo(skillIndex)
		if not name then
			return 0
		end

		if name == skillName then
			return skillRank + skillModifier
		end

		skillIndex = skillIndex + 1
	end
end

function BCS:GetWeaponSkillForWeaponType(weaponType)
	if weaponType == "Daggers" then
		return BCS:GetWeaponSkill("Daggers")
	elseif weaponType == "One-Handed Swords" then
		return BCS:GetWeaponSkill("Swords")
	elseif weaponType == "Two-Handed Swords" then
		return BCS:GetWeaponSkill("Two-Handed Swords")
	elseif weaponType == "One-Handed Axes" then
		return BCS:GetWeaponSkill("Axes")
	elseif weaponType == "Two-Handed Axes" then
		return BCS:GetWeaponSkill("Two-Handed Axes")
	elseif weaponType == "One-Handed Maces" then
		return BCS:GetWeaponSkill("Maces")
	elseif weaponType == "Two-Handed Maces" then
		return BCS:GetWeaponSkill("Two-Handed Maces")
	elseif weaponType == "Staves" then
		return BCS:GetWeaponSkill("Staves")
	elseif weaponType == "Polearms" then
		return BCS:GetWeaponSkill("Polearms")
	elseif weaponType == "Fist Weapons" then
		return BCS:GetWeaponSkill("Unarmed")
	elseif weaponType == "Bows" then
		return BCS:GetWeaponSkill("Bows")
	elseif weaponType == "Crossbows" then
		return BCS:GetWeaponSkill("Crossbows")
	elseif weaponType == "Guns" then
		return BCS:GetWeaponSkill("Guns")
	elseif weaponType == "Thrown" then
		return BCS:GetWeaponSkill("Thrown")
	elseif weaponType == "Wands" then
		return BCS:GetWeaponSkill("Wands")
	end
	-- no weapon equipped
	return BCS:GetWeaponSkill("Unarmed")
end

function BCS:GetItemTypeForSlot(slot)
	local _, _, id = string.find(GetInventoryItemLink("player", GetInventorySlotInfo(slot)) or "", "(item:%d+:%d+:%d+:%d+)")
	if not id then
		return
	end

	local _, _, _, _, _, itemType = GetItemInfo(id)

	return itemType
end

function BCS:GetMHWeaponSkill()
	if not BCS.needScanSkills then
		return BCScache["skills"].mh
	end
	local itemType = BCS:GetItemTypeForSlot("MainHandSlot")
	BCScache["skills"].mh = BCS:GetWeaponSkillForWeaponType(itemType)

	return BCScache["skills"].mh
end

function BCS:GetOHWeaponSkill()
	if not BCS.needScanSkills then
		return BCScache["skills"].oh
	end

	local itemType = BCS:GetItemTypeForSlot("SecondaryHandSlot")
	BCScache["skills"].oh = BCS:GetWeaponSkillForWeaponType(itemType)

	return BCScache["skills"].oh
end

function BCS:GetRangedWeaponSkill()
	if not BCS.needScanSkills then
		return BCScache["skills"].ranged
	end

	local itemType = BCS:GetItemTypeForSlot("RangedSlot")
	BCScache["skills"].ranged = BCS:GetWeaponSkillForWeaponType(itemType)

	return BCScache["skills"].ranged
end

--https://us.forums.blizzard.com/en/wow/t/block-value-formula/283718/18
function BCS:GetBlockValue()
	local blockValue = 0
	local _, strength = UnitStat("player", 1)

	-- Use cached talent values instead of re-scanning
	local mod = BCScache["talents"].block_mod

	-- Gear (still scanned here as block value isn't in the gear cache)
	for slot = 1, 19 do
		if BCS_Tooltip:SetInventoryItem("player", slot) then
			local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
			if eqItemLink then
				BCS_Tooltip:ClearLines()
				BCS_Tooltip:SetHyperlink(eqItemLink)
			end
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					local _, _, value = strfind(text, L["(%d+) Block"])
					if value then
						blockValue = blockValue + tonumber(value)
					end
					_, _, value = strfind(text, L["Equip: Increases the block value of your shield by (%d+)."])
					if value then
						blockValue = blockValue + tonumber(value)
					end
					_, _, value = strfind(text, L["Block Value %+(%d+)"])
					if value then
						blockValue = blockValue + tonumber(value)
					end
				end
			end
		end
	end

	-- Buffs
	--Glyph of Deflection
	local _, _, value = BCS:GetPlayerAura(L["Block value increased by (%d+)."])
	if value then
		blockValue = blockValue + tonumber(value)
	end
	-- Stoneskin Totem (talented via Enhancing Totems)
	if BCScache["talents"].enhancing_totems > 0 and BCS:GetPlayerAura(L["^Stoneskin$"]) then
		mod = mod + BCScache["talents"].enhancing_totems
	end

	mod = mod / 100
	blockValue = blockValue + (strength / 20 - 1)
	blockValue = floor(blockValue + blockValue * mod)

	if blockValue < 0 then
		blockValue = 0
	end

	return blockValue
end

function BCS:GetHaste()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	local _, race = UnitRace("player")
	local haste = race == "NightElf" and 1 or 0

	haste = haste + BCScache["gear"].haste + BCScache["auras"].haste + BCScache["talents"].haste
	local spellHaste = BCScache["gear"].spell_haste + BCScache["auras"].spell_haste + BCScache["talents"].spell_haste

	return haste, spellHaste
end

function BCS:GetArmorPen()
	-- All scanning now done by ScanAllGear/ScanAllTalents/ScanAllAuras
	-- Handle Master of Arms (requires checking weapon type)
	local talentArmorPen = 0
	if masterOfArms then
		local _, _, itemID = strfind(GetInventoryItemLink("player", 16) or "", "item:(%d+)")
		if itemID then
			local itemName, itemLink, itemQuality, itemMinLevel, itemType, itemSubType = GetItemInfo(itemID)
			if itemSubType and (itemSubType == L["One-Handed Maces"] or itemSubType == L["Two-Handed Maces"]) then
				talentArmorPen = masterOfArms
			end
		end
	end

	return BCScache["gear"].armor_pen + BCScache["auras"].armor_pen + talentArmorPen, talentArmorPen
end

function BCS:GetSpellPen()
	-- All scanning now done by ScanAllGear
	return BCScache["gear"].spell_pen
end

function BCS:GetHPRegen()
	-- "Regenerate (%d+) health every 5 sec."
	-- "Increases your movement speed by 15% and restores 60 Health per 5 sec. Half of this effect is granted to allies within 30 yards."
	-- "Equip: Restores 16 health per 5 sec."
	-- "Set: Restores 8 health per 5 sec."
end

