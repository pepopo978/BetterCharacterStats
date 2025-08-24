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
		ranged_crit = 0
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
		ranged_crit = 0
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
		hit_debuff = 0
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

function BCS:GetPlayerAura(searchText, auraType)
	if not auraType then
		-- Buffs
		-- http://blue.cardplace.com/cache/wow-dungeons/624230.htm
		-- 32 buffs max
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
	elseif auraType == "HARMFUL" then
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
end

function BCS:GetHitRating(hitOnly)
	local hit = 0
	if BCS.needScanGear then
		BCScache["gear"].hit = 0
		twipe(SetBonus.hit)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value = strfind(text, L["Equip: Improves your chance to hit by (%d)%%."])
						if value then
							BCScache["gear"].hit = BCScache["gear"].hit + tonumber(value)
						end
						_, _, value = strfind(text, L["/Hit %+(%d+)"])
						if value then
							BCScache["gear"].hit = BCScache["gear"].hit + tonumber(value)
						end
						_, _, value = strfind(text, L["^Equip: Improves your chance to hit with spells and attacks by (%d+)%%"])
						if value then
							BCScache["gear"].hit = BCScache["gear"].hit + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Improves your chance to hit by (%d)%%."])
						if value and setName and not SetBonus.hit[setName] then
							SetBonus.hit[setName] = true
							BCScache["gear"].hit = BCScache["gear"].hit + tonumber(value)
							break
						end
					end
				end
			end
		end
	end

	if BCS.needScanAuras then
		BCScache["auras"].hit = 0
		BCScache["auras"].hit_debuff = 0
		-- Buffs
		local _, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit increased by (%d)%%."])
		if hitFromAura then
			BCScache["auras"].hit = BCScache["auras"].hit + tonumber(hitFromAura)
		end
		_, _, hitFromAura = BCS:GetPlayerAura(L["Improves your chance to hit by (%d+)%%."])
		if hitFromAura then
			BCScache["auras"].hit = BCScache["auras"].hit + tonumber(hitFromAura)
		end
		_, _, hitFromAura = BCS:GetPlayerAura(L["Increases attack power by %d+ and chance to hit by (%d+)%%."])
		if hitFromAura then
			BCScache["auras"].hit = BCScache["auras"].hit + tonumber(hitFromAura)
		end
		-- Debuffs
		_, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit reduced by (%d+)%%."], "HARMFUL")
		if hitFromAura then
			BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + tonumber(hitFromAura)
		end
		_, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec."], "HARMFUL")
		if hitFromAura then
			BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + tonumber(hitFromAura)
		end
		hitFromAura = BCS:GetPlayerAura(L["Lowered chance to hit."], "HARMFUL")
		if hitFromAura then
			BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + 25
		end
	end

	if BCS.needScanTalents then
		BCScache["talents"].hit = 0
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Rogue
						local _, _, value = strfind(text, L["Increases your chance to hit with melee weapons by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Hunter
						_, _, value = strfind(text, L["Increases hit chance by (%d)%% and increases the chance movement impairing effects will be resisted by an additional %d+%%."])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Druid
						-- Natural Weapons
						_, _, value = strfind(text, L["Also increases chance to hit with melee attacks and spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Paladin
						-- Precision
						_, _, value = strfind(text, L["Increases your chance to hit with melee attacks and spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Shaman
						-- Elemental Devastation
						_, _, value = strfind(text, L["Increases your chance to hit with spells and melee attacks by (%d+)%%"])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
					end
				end
			end
		end
	end
	hit = BCScache["talents"].hit + BCScache["gear"].hit + BCScache["auras"].hit
	if not hitOnly then
		hit = hit - BCScache["auras"].hit_debuff
		-- Dust Cloud OP
		if hit < 0 then
			hit = 0
		end
		return hit
	else
		return hit
	end
end

function BCS:GetRangedHitRating()
	if BCS.needScanGear then
		BCScache["gear"].ranged_hit = 0
		-- Gear
		if BCS_Tooltip:SetInventoryItem("player", 18) then
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					local _, _, value = strfind(text, L["+(%d)%% Ranged Hit"])
					if value then
						BCScache["gear"].ranged_hit = BCScache["gear"].ranged_hit + tonumber(value)
						break
					end
				end
			end
		end
	end
	local ranged_hit = BCS:GetHitRating(true) + BCScache["gear"].ranged_hit - BCScache["auras"].hit_debuff
	if ranged_hit < 0 then
		ranged_hit = 0
	end
	return ranged_hit
end

function BCS:GetSpellHitRating()
	local hit = 0
	local hit_fire = 0
	local hit_frost = 0
	local hit_arcane = 0
	local hit_shadow = 0
	local hit_holy = 0
	if BCS.needScanGear then
		BCScache["gear"].spell_hit = 0
		twipe(SetBonus.spellHit)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value = strfind(text, L["Equip: Improves your chance to hit with spells by (%d)%%."])
						if value then
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
						_, _, value = strfind(text, L["/Spell Hit %+(%d+)"])
						if value then
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
						_, _, value = strfind(text, L["^Equip: Improves your chance to hit with spells and attacks by (%d+)%%"])
						if value then
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
						-- Scythe of Elune
						_, _, value = strfind(text, L["Improves your chance to hit and get a critical strike with spells by (%d+)%%"])
						if value then
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Improves your chance to hit with spells by (%d)%%."])
						if value and setName and not SetBonus.spellHit[setName] then
							SetBonus.spellHit[setName] = true
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
					end
				end
			end
		end
	end
	if BCS.needScanTalents then
		BCScache["talents"].spell_hit = 0
		BCScache["talents"].spell_hit_fire = 0
		BCScache["talents"].spell_hit_frost = 0
		BCScache["talents"].spell_hit_arcane = 0
		BCScache["talents"].spell_hit_shadow = 0
		BCScache["talents"].spell_hit_holy = 0
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Mage
						-- Elemental Precision
						local _, _, value = strfind(text, L["Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_fire = BCScache["talents"].spell_hit_fire + tonumber(value)
							BCScache["talents"].spell_hit_frost = BCScache["talents"].spell_hit_frost + tonumber(value)
							break
						end
						-- Arcane Focus
						_, _, value = strfind(text, L["Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_arcane = BCScache["talents"].spell_hit_arcane + tonumber(value)
							break
						end
						-- Priest
						-- Piercing Light
						_, _, value = strfind(text, L["Reduces the chance for enemies to resist your Holy and Discipline spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_holy = BCScache["talents"].spell_hit_holy + tonumber(value)
							break
						end
						-- Shadow Focus
						_, _, value = strfind(text, L["Reduces your target's chance to resist your Shadow spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_shadow = BCScache["talents"].spell_hit_shadow + tonumber(value)
							break
						end
						-- Druid
						-- Natural Weapons
						_, _, value = strfind(text, L["Also increases chance to hit with melee attacks and spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
							break
						end
						-- Paladin
						-- Precision
						_, _, value = strfind(text, L["Increases your chance to hit with melee attacks and spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
							break
						end
						-- Shaman
						-- Elemental Devastation
						_, _, value = strfind(text, L["Increases your chance to hit with spells and melee attacks by (%d+)%%"])
						if value and rank > 0 then
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
							break
						end
						-- Warlock
						-- Suppression
						_, _, value = strfind(text, L["Reduces the chance for enemies to resist your Affliction spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_shadow = BCScache["talents"].spell_hit_shadow + tonumber(value)
							break
						end
					end
				end
			end
		end
	end
	if BCS.needScanAuras then
		BCScache["auras"].spell_hit = 0
		-- Buffs
		local _, _, hitFromAura = BCS:GetPlayerAura(L["Spell hit chance increased by (%d+)%%."])
		if hitFromAura then
			BCScache["auras"].spell_hit = BCScache["auras"].spell_hit + tonumber(hitFromAura)
		end
		-- Elemental Devastation
		_, _, hitFromAura = BCS:GetPlayerAura(L["Increases your chance to hit with spells by (%d+)%%"])
		if hitFromAura then
			BCScache["auras"].spell_hit = BCScache["auras"].spell_hit + tonumber(hitFromAura)
		end
	end
	hit = BCScache["gear"].spell_hit + BCScache["talents"].spell_hit + BCScache["auras"].spell_hit
	hit_fire = BCScache["talents"].spell_hit_fire
	hit_frost = BCScache["talents"].spell_hit_frost
	hit_arcane = BCScache["talents"].spell_hit_arcane
	hit_shadow = BCScache["talents"].spell_hit_shadow
	hit_holy = BCScache["talents"].spell_hit_holy
	return hit, hit_fire, hit_frost, hit_arcane, hit_shadow, hit_holy
end

function BCS:GetCritChance()
	local crit = 0
	-- Spellbook
	for tab = 1, GetNumSpellTabs() do
		local _, _, offset, numSpells = GetSpellTabInfo(tab)
		for spell = 1, numSpells do
			local currentPage = ceil(spell/SPELLS_PER_PAGE)
			local SpellID = spell + offset + ( SPELLS_PER_PAGE * (currentPage - 1))
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

	if BCS.needScanTalents then
		BCScache["talents"].ranged_crit = 0
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Lethal Shots
						local _, _, value = strfind(text, L["Increases your critical strike chance with ranged weapons by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].ranged_crit = BCScache["talents"].ranged_crit + tonumber(value)
							break
						end
						-- Killer Instinct
						_, _, value = strfind(text, L["Increases your critical strike chance with all attacks by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].ranged_crit = BCScache["talents"].ranged_crit + tonumber(value)
							break
						end
					end
				end
			end
		end
	end

	if BCS.needScanGear then
		BCScache["gear"].ranged_crit = 0
		twipe(SetBonus.rangedCrit)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value = strfind(text, L["Equip: Improves your chance to get a critical strike by (%d)%%."])
						if value then
							BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + tonumber(value)
						end
						_, _, value = strfind(text, L["Equip: Improves your chance to get a critical strike with missile weapons by (%d)%%."])
						if value then
							BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + tonumber(value)
						end
						-- Might of the Scourge (shoulder enchant)
						_, _, value = strfind(text, L["%+(%d+)%% Critical Strike"])
						if value then
							BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Improves your chance to get a critical strike by (%d)%%."])
						if value and setName and not SetBonus.rangedCrit[setName] then
							SetBonus.rangedCrit[setName] = true
							BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + tonumber(value)
						end
					end
				end
			end
		end
	end
	if BCS.needScanAuras then
		BCScache["auras"].ranged_crit = 0
		-- Buffs
		-- Rallying Cry of the Dragonslayer
		local critFromAura = BCS:GetPlayerAura(L["Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + 5
		end
		-- Elixir of the Mongoose
		_, _, critFromAura = BCS:GetPlayerAura(L["Agility increased by 25, Critical hit chance increases by (%d)%%."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + tonumber(critFromAura)
		end
		-- Songflower Serenade
		_, _, critFromAura = BCS:GetPlayerAura(L["Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + tonumber(critFromAura)
		end
		-- Tricks of the Trade
		_, _, critFromAura = BCS:GetPlayerAura(L["Critical strike chance increased by (%d+)%%."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + tonumber(critFromAura)
		end
		-- Leader of the Pack
		_, _, critFromAura = BCS:GetPlayerAura(L["Increases ranged and melee critical chance by (%d+)%%."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + tonumber(critFromAura)
		end
	end

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
	local spellCrit = 0;
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

	if BCS.needScanGear then
		BCScache["gear"].spell_crit = 0
		twipe(SetBonus.spellCrit)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value = strfind(text, L["Equip: Improves your chance to get a critical strike with spells by (%d)%%."])
						if value then
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end
						_, _, value = strfind(text, L["(%d)%% Spell Critical Strike"])
						if value then
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end
						-- Scythe of Elune
						_, _, value = strfind(text, L["Improves your chance to hit and get a critical strike with spells by (%d+)%%"])
						if value then
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Improves your chance to get a critical strike with spells by (%d)%%."])
						if value and setName and not SetBonus.spellCrit[setName] then
							SetBonus.spellCrit[setName] = true
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end
					end
				end
			end
		end
		if BCS_Tooltip:SetInventoryItem("player", 16) then
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					if strfind(text, L["^Brilliant Wizard Oil"]) then
						BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + 1
						break
					end
				end
			end
		end
	end

	if BCS.needScanAuras then
		BCScache["auras"].spell_crit = 0
		-- Buffs
		local _, _, critFromAura = BCS:GetPlayerAura(L["Chance for a critical hit with a spell increased by (%d+)%%."])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		critFromAura = BCS:GetPlayerAura(L["Inner Focus"])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + 25
		end
		-- Power of the Guardian / Moonkin Aura
		_, _, critFromAura = BCS:GetPlayerAura(L["Increases spell critical chance by (%d)%%."])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		_, _, critFromAura = BCS:GetPlayerAura(L["Chance to get a critical strike with spells is increased by (%d+)%%"])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		_, _, critFromAura = BCS:GetPlayerAura(L["While active, target's critical hit chance with spells and attacks increases by 10%%."])--SoD spell? 23964
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + 10
		end
		_, _, critFromAura = BCS:GetPlayerAura(L["Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+."])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		critFromAura = BCS:GetPlayerAura(L["Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration."])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + 10
		end
		_, _, critFromAura = BCS:GetPlayerAura(L["Critical strike chance with spells and melee attacks increased by (%d+)%%."])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		-- Debuffs
		_, _, critFromAura = BCS:GetPlayerAura(L["Spell critical-hit chance reduced by (%d+)%%."], "HARMFUL")
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit - tonumber(critFromAura)
		end
	end

	if BCS.needScanTalents then
		BCScache["talents"].spell_crit = 0
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Arcane Instability
						local _, _, value = strfind(text, L["Increases your spell damage and critical srike chance by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_crit = BCScache["talents"].spell_crit + tonumber(value)
							break
						end
					end
				end
			end
		end
	end

	spellCrit = spellCrit + BCScache["talents"].spell_crit + BCScache["gear"].spell_crit + BCScache["auras"].spell_crit

	return spellCrit
end

function BCS:GetSpellCritFromClass(class)
	if not class then
		return 0, 0, 0, 0, 0, 0
	end

	if class == "PALADIN" then
		if BCS.needScanTalents or BCS.needScanAuras then
			BCScache["talents"].paladin_holy_light = 0
			BCScache["talents"].paladin_flash = 0
			BCScache["talents"].paladin_shock = 0
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Holy Power
							local _, _, value = strfind(text, L["Increases the critical effect chance of your Holy Light and Flash of Light by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].paladin_holy_light = BCScache["talents"].paladin_holy_light + tonumber(value)
								BCScache["talents"].paladin_flash = BCScache["talents"].paladin_flash + tonumber(value)
								break
							end
							-- Divine Favor
							_, _, value = strfind(text, L["Improves your chance to get a critical strike with Holy Shock by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].paladin_shock = BCScache["talents"].paladin_shock + tonumber(value)
								break
							end
						end
					end
				end
			end
		end

		return BCScache["talents"].paladin_holy_light,
				BCScache["talents"].paladin_flash,
				BCScache["talents"].paladin_shock, 0, 0, 0

	elseif class == "DRUID" then
		if BCS.needScanTalents then
			BCScache["talents"].druid_moonfire = 0
			BCScache["talents"].druid_regrowth = 0
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Improved Moonfire
							local _, _, value = strfind(text, L["Increases the damage and critical strike chance of your Moonfire spell by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].druid_moonfire = BCScache["talents"].druid_moonfire + tonumber(value)
								break
							end
							-- Improved Regrowth
							_, _, value = strfind(text, L["Increases the critical effect chance of your Regrowth spell by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].druid_regrowth = BCScache["talents"].druid_regrowth + tonumber(value)
								break
							end
						end
					end
				end
			end
		end

		return BCScache["talents"].druid_moonfire,
				BCScache["talents"].druid_regrowth, 0, 0, 0, 0

	elseif class == "WARLOCK" then
		if BCS.needScanTalents then
			BCScache["talents"].warlock_destruction_spells = 0
			BCScache["talents"].warlock_searing_pain = 0
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Devastation
							local _, _, value = strfind(text, L["Increases the critical strike chance of your Destruction spells by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].warlock_destruction_spells = BCScache["talents"].warlock_destruction_spells + tonumber(value)
								BCScache["talents"].warlock_searing_pain = BCScache["talents"].warlock_searing_pain + tonumber(value)
								break
							end
							-- Improved Searing Pain
							_, _, value = strfind(text, L["Increases the critical strike chance of your Searing Pain spell by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].warlock_searing_pain = BCScache["talents"].warlock_searing_pain + tonumber(value)
								break
							end
						end
					end
				end
			end
		end

		return BCScache["talents"].warlock_destruction_spells,
				BCScache["talents"].warlock_searing_pain, 0, 0, 0, 0

	elseif class == "MAGE" then
		if BCS.needScanTalents or BCS.needScanAuras then
			BCScache["talents"].mage_arcane_spells = 0
			BCScache["talents"].mage_fire_spells = 0
			BCScache["talents"].mage_fireblast = 0
			BCScache["talents"].mage_scorch = 0
			BCScache["talents"].mage_flamestrike = 0
			BCScache["talents"].mage_shatter = 0
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Arcane Impact
							local _, _, value = strfind(text, L["Increases the critical strike chance of your Arcane Explosion and Arcane Missiles spells by an additional (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].mage_arcane_spells = BCScache["talents"].mage_arcane_spells + tonumber(value)
								break
							end
							-- Incinerate
							_, _, value = strfind(text, L["Increases the critical strike chance of your Fire Blast and Scorch spells by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].mage_fireblast = BCScache["talents"].mage_fireblast + tonumber(value)
								BCScache["talents"].mage_scorch = BCScache["talents"].mage_scorch + tonumber(value)
								break
							end
							-- Improved Flamestrike
							_, _, value = strfind(text, L["Increases the critical strike chance of your Flamestrike spell by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].mage_flamestrike = BCScache["talents"].mage_flamestrike + tonumber(value)
								break
							end
							-- Critical Mass
							_, _, value = strfind(text, L["Increases the critical strike chance of your Fire spells by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].mage_fire_spells = BCScache["talents"].mage_fire_spells + tonumber(value)
								BCScache["talents"].mage_fireblast = BCScache["talents"].mage_fireblast + tonumber(value)
								BCScache["talents"].mage_flamestrike = BCScache["talents"].mage_flamestrike + tonumber(value)
								BCScache["talents"].mage_scorch = BCScache["talents"].mage_scorch + tonumber(value)
								break
							end
							-- Shatter
							_, _, value = strfind(text, L["Increases the critical strike chance of all your spells against frozen targets by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].mage_shatter = BCScache["talents"].mage_shatter + tonumber(value)
								break
							end
						end
					end
				end
			end
			-- Buffs
			-- Combustion
			local _, _, value = BCS:GetPlayerAura(L["Increases critical strike chance from Fire damage spells by (%d+)%%."])
			if value then
				BCScache["talents"].mage_fire_spells = BCScache["talents"].mage_fire_spells + tonumber(value)
				BCScache["talents"].mage_fireblast = BCScache["talents"].mage_fireblast + tonumber(value)
				BCScache["talents"].mage_flamestrike = BCScache["talents"].mage_flamestrike + tonumber(value)
				BCScache["talents"].mage_scorch = BCScache["talents"].mage_scorch + tonumber(value)
			end
		end

		return BCScache["talents"].mage_arcane_spells,
				BCScache["talents"].mage_fire_spells,
				BCScache["talents"].mage_fireblast,
				BCScache["talents"].mage_scorch,
				BCScache["talents"].mage_flamestrike,
				BCScache["talents"].mage_shatter

	elseif class == "PRIEST" then
		if BCS.needScanTalents then
			BCScache["talents"].priest_holy_spells = 0
			BCScache["talents"].priest_discipline_spells = 0
			BCScache["talents"].priest_offensive_spells = 0
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Divinity
							local _, _, value = strfind(text, L["Increases the critical effect chance of your Holy and Discipline spells by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].priest_holy_spells = BCScache["talents"].priest_holy_spells + tonumber(value)
								BCScache["talents"].priest_discipline_spells = BCScache["talents"].priest_discipline_spells + tonumber(value)
								break
							end
							-- Force of Will
							_, _, value = strfind(text, L["Increases your spell damage and the critical strike chance of your offensive spells by (%d+)%%"])
							if value and rank > 0 then
								BCScache["talents"].priest_offensive_spells = BCScache["talents"].priest_offensive_spells + tonumber(value)
								break
							end
						end
					end
				end
			end
		end
		if BCS.needScanGear then
			BCScache["gear"].priest_holy_spells = 0
			BCScache["gear"].priest_prayer = 0
			-- Gear
			for slot = 1, 19 do
				if BCS_Tooltip:SetInventoryItem("player", slot) then
					local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
					if eqItemLink then
						BCS_Tooltip:ClearLines()
						BCS_Tooltip:SetHyperlink(eqItemLink)
					end
					local setName
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							-- Set Bonuses
							local _, _, value = strfind(text, setPattern)
							if value then
								setName = value
							end
							_, _, value = strfind(text, L["^Set: Improves your chance to get a critical strike with Holy spells by (%d)%%."])
							if value and setName and not SetBonus.spellCritClass[setName] then
								SetBonus.spellCritClass[setName] = true
								BCScache["gear"].priest_holy_spells = BCScache["gear"].priest_holy_spells + tonumber(value)
							end
							_, _, value = strfind(text, L["^Set: Increases your chance of a critical hit with Prayer of Healing by (%d+)%%."])
							if value and setName and not SetBonus.spellCritClass[setName] then
								SetBonus.spellCritClass[setName] = true
								BCScache["gear"].priest_prayer = BCScache["gear"].priest_prayer + tonumber(value)
							end
						end
					end
				end
			end
		end

		local holySpells = BCScache["talents"].priest_holy_spells + BCScache["gear"].priest_holy_spells

		return holySpells,
				BCScache["talents"].priest_discipline_spells,
				BCScache["talents"].priest_offensive_spells,
				BCScache["gear"].priest_prayer, 0, 0

	elseif class == "SHAMAN" then
		if BCS.needScanTalents then
			BCScache["talents"].shaman_lightning_bolt = 0
			BCScache["talents"].shaman_chain_lightning = 0
			BCScache["talents"].shaman_lightning_shield = 0
			BCScache["talents"].shaman_firefrost_spells = 0
			BCScache["talents"].shaman_healing_spells = 0
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Call of Thunder
							local _, _, value = strfind(text, L["Increases the critical strike chance of your Lightning Bolt and Chain Lightning spells by an additional (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].shaman_lightning_bolt = BCScache["talents"].shaman_lightning_bolt + tonumber(value)
								BCScache["talents"].shaman_chain_lightning = BCScache["talents"].shaman_chain_lightning + tonumber(value)
								break
							end
							-- Tidal Mastery
							_, _, value = strfind(text, L["Increases the critical effect chance of your healing and lightning spells by (%d+)%%."])
							if value and rank > 0 then
								BCScache["talents"].shaman_lightning_bolt = BCScache["talents"].shaman_lightning_bolt + tonumber(value)
								BCScache["talents"].shaman_chain_lightning = BCScache["talents"].shaman_chain_lightning + tonumber(value)
								BCScache["talents"].shaman_lightning_shield = BCScache["talents"].shaman_lightning_shield + tonumber(value)
								BCScache["talents"].shaman_healing_spells = BCScache["talents"].shaman_healing_spells + tonumber(value)
								break
							end
						end
					end
				end
			end
		end
		if BCS.needScanAuras then
			BCScache["auras"].shaman_lightning_bolt = 0
			BCScache["auras"].shaman_chain_lightning = 0
			BCScache["auras"].shaman_firefrost_spells = 0
			-- Buffs
			local hasAura = BCS:GetPlayerAura(L["Elemental Mastery"])
			if hasAura then
				BCScache["auras"].shaman_lightning_bolt = 100
				BCScache["auras"].shaman_chain_lightning = 100
				BCScache["auras"].shaman_firefrost_spells = 100
			end
		end

		local lightningBolt = BCScache["auras"].shaman_lightning_bolt + BCScache["talents"].shaman_lightning_bolt
		local chainLightning = BCScache["auras"].shaman_chain_lightning + BCScache["talents"].shaman_chain_lightning

		return lightningBolt, chainLightning,
				BCScache["talents"].shaman_lightning_shield,
				BCScache["auras"].shaman_firefrost_spells,
				BCScache["talents"].shaman_healing_spells, 0

	else
		return 0, 0, 0, 0, 0, 0
	end
end

local impInnerFire = nil
local spiritualGuidance = nil
function BCS:GetSpellPower(school)
	if school then
		local key = strlower(school)
		if BCS.needScanGear then
			BCScache["gear"][key] = 0
			-- Gear
			for slot = 1, 19 do
				if BCS_Tooltip:SetInventoryItem("player", slot) then
					local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
					if eqItemLink then
						BCS_Tooltip:ClearLines()
						BCS_Tooltip:SetHyperlink(eqItemLink)
					end
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, value = strfind(text, L["Equip: Increases damage done by "..school.." spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"][key] = BCScache["gear"][key] + tonumber(value)
							end
							_, _, value = strfind(text, L[school.." Damage %+(%d+)"])
							if value then
								BCScache["gear"][key] = BCScache["gear"][key] + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) "..school.." Spell Damage"])
							if value then
								BCScache["gear"][key] = BCScache["gear"][key] + tonumber(value)
							end
						end
					end
				end
			end
		end

		if BCS.needScanAuras then
			BCScache["auras"][key] = 0
			-- Buffs
			local _, _, spellPowerFromAura = BCS:GetPlayerAura(L[school.." damage dealt by spells and abilities is increased by up to (%d+)"])
			if spellPowerFromAura then
				BCScache["auras"][key] = BCScache["auras"][key] + tonumber(spellPowerFromAura)
			end
		end

		return BCScache["gear"][key] + BCScache["auras"][key]
	else
		local damageAndHealing = 0
		local damageOnly = 0
		if BCS.needScanGear then
			twipe(SetBonus.spellPower)
			BCScache["gear"].damage_and_healing = 0
			BCScache["gear"].only_damage = 0
			BCScache["gear"].arcane = 0
			BCScache["gear"].fire = 0
			BCScache["gear"].frost = 0
			BCScache["gear"].holy = 0
			BCScache["gear"].nature = 0
			BCScache["gear"].shadow = 0
			-- Gear
			for slot = 1, 19 do
				if BCS_Tooltip:SetInventoryItem("player", slot) then
					local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
					if eqItemLink then
						BCS_Tooltip:ClearLines()
						BCS_Tooltip:SetHyperlink(eqItemLink)
					end
					local setName
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							-- Generic bonus on most gear
							local _, _, value = strfind(text, L["Equip: Increases damage and healing done by magical spells and effects by up to (%d+)%."])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							-- Spell Power (weapon/bracer enchant) apparently gives healing too
							-- Arcanum of Focus (Head/Legs enchant)
							-- Power of the Scourge (Shoulder enchant)
							_, _, value = strfind(text, L["Spell Damage %+(%d+)"])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							-- Zandalar Signet of Mojo (Shoulder enchant)
							_, _, value = strfind(text, L["^%+(%d+) Spell Damage and Healing"])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							-- Enchanted Armor Kit (Leatherworking)
							_, _, value = strfind(text, L["^%+(%d+) Damage and Healing Spells"])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							-- Atiesh (druid/priest)
							_, _, value = strfind(text, L["Equip: Increases your spell damage by up to (%d+) and your healing by up to %d+."])
							if value then
								BCScache["gear"].only_damage = BCScache["gear"].only_damage + tonumber(value)
							end
							-- Scythe of Elune
							_, _, value = strfind(text, L["Increases damage done by magical spells and effects by up to (%d+)"])
							if value then
								BCScache["gear"].only_damage = BCScache["gear"].only_damage + tonumber(value)
							end
							-- Arcane
							_, _, value = strfind(text, L["Equip: Increases damage done by Arcane spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].arcane = BCScache["gear"].arcane + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) Arcane Spell Damage"])
							if value then
								BCScache["gear"].arcane = BCScache["gear"].arcane + tonumber(value)
							end
							_, _, value = strfind(text, L["Arcane Damage %+(%d+)"])
							if value then
								BCScache["gear"].arcane = BCScache["gear"].arcane + tonumber(value)
							end
							-- Fire
							_, _, value = strfind(text, L["Equip: Increases damage done by Fire spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].fire = BCScache["gear"].fire + tonumber(value)
							end
							_, _, value = strfind(text, L["Fire Damage %+(%d+)"])
							if value then
								BCScache["gear"].fire = BCScache["gear"].fire + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) Fire Spell Damage"])
							if value then
								BCScache["gear"].fire = BCScache["gear"].fire + tonumber(value)
							end
							-- Frost
							_, _, value = strfind(text, L["Equip: Increases damage done by Frost spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].frost = BCScache["gear"].frost + tonumber(value)
							end
							_, _, value = strfind(text, L["Frost Damage %+(%d+)"])
							if value then
								BCScache["gear"].frost = BCScache["gear"].frost + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) Frost Spell Damage"])
							if value then
								BCScache["gear"].frost = BCScache["gear"].frost + tonumber(value)
							end
							-- Holy
							_, _, value = strfind(text, L["Equip: Increases damage done by Holy spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].holy = BCScache["gear"].holy + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) Holy Spell Damage"])
							if value then
								BCScache["gear"].holy = BCScache["gear"].holy + tonumber(value)
							end
							_, _, value = strfind(text, L["Holy Damage %+(%d+)"])
							if value then
								BCScache["gear"].holy = BCScache["gear"].holy + tonumber(value)
							end
							-- Nature
							_, _, value = strfind(text, L["Equip: Increases damage done by Nature spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].nature = BCScache["gear"].nature + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) Nature Spell Damage"])
							if value then
								BCScache["gear"].nature = BCScache["gear"].nature + tonumber(value)
							end
							_, _, value = strfind(text, L["Nature Damage %+(%d+)"])
							if value then
								BCScache["gear"].nature = BCScache["gear"].nature + tonumber(value)
							end
							-- Shadow
							_, _, value = strfind(text, L["Equip: Increases damage done by Shadow spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].shadow = BCScache["gear"].shadow + tonumber(value)
							end
							_, _, value = strfind(text, L["Shadow Damage %+(%d+)"])
							if value then
								BCScache["gear"].shadow = BCScache["gear"].shadow + tonumber(value)
							end
							_, _, value = strfind(text, L["^%+(%d+) Shadow Spell Damage"])
							if value then
								BCScache["gear"].shadow = BCScache["gear"].shadow + tonumber(value)
							end
							-- Set Bonuses
							_, _, value = strfind(text, setPattern)
							if value then
								setName = value
							end
							_, _, value = strfind(text, L["^Set: Increases damage and healing done by magical spells and effects by up to (%d+)%."])
							if value and setName and not SetBonus.spellPower[setName] then
								SetBonus.spellPower[setName] = true
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
						end
					end
				end
			end
			-- SetHyperLink doesnt show temporary enhancements, have to use SetInventoryItem
			if BCS_Tooltip:SetInventoryItem("player", 16) then
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						-- apparently gives healing too
						if strfind(text, L["^Brilliant Wizard Oil"]) then
							BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 36
							break
						end
						if strfind(text, L["^Lesser Wizard Oil"]) then
							BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 16
							break
						end
						if strfind(text, L["^Minor Wizard Oil"]) then
							BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 8
							break
						end
						if strfind(text, L["^Wizard Oil"]) then
							BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + 24
							break
						end
					end
				end
			end
		end

		if BCS.needScanTalents then
			impInnerFire = nil
			spiritualGuidance = nil
			-- Talents
			for tab = 1, GetNumTalentTabs() do
				for talent = 1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line = 1, BCS_Tooltip:NumLines() do
						local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
						if text then
							local _, _, _, _, rank = GetTalentInfo(tab, talent)
							-- Priest
							-- Spiritual Guidance
							local _, _, value = strfind(text, L["Increases spell damage and healing by up to (%d+)%% of your total Spirit."])
							if value and rank > 0 then
								spiritualGuidance = tonumber(value)
								break
							end
							-- Improved Inner Fire
							_, _, value = strfind(text, L["Increases the effects of your Inner Fire spell by (%d+)%%."])
							if value and rank > 0 then
								impInnerFire = tonumber(value)
								break
							end
						end
					end
				end
			end
		end
		if BCS.needScanAuras then
			BCScache["auras"].damage_and_healing = 0
			BCScache["auras"].only_damage = 0
			-- Buffs
			local _, _, spellPowerFromAura = BCS:GetPlayerAura(L["Magical damage dealt is increased by up to (%d+)."])
			if spellPowerFromAura then
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			_, _, spellPowerFromAura = BCS:GetPlayerAura(L["Increases damage and healing done by magical spells and effects by up to (%d+)"])
			if spellPowerFromAura then
				BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + tonumber(spellPowerFromAura)
			end
			-- Dreamtonic/Arcane Elixir
			_, _, spellPowerFromAura = BCS:GetPlayerAura(L["Magical damage dealt by spells and abilities is increased by up to (%d+)"])
			if spellPowerFromAura then
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			-- Dreamshard Elixir
			_, _, spellPowerFromAura = BCS:GetPlayerAura(L["Spell damage is increased by up to (%d+)"])
			if spellPowerFromAura then
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			-- Flask of Supreme Power
			_, _, spellPowerFromAura = BCS:GetPlayerAura(L["Spell damage increased by up to (%d+)"])
			if spellPowerFromAura then
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			-- Danonzo's Tel'Abim Delight
			_, _, spellPowerFromAura = BCS:GetPlayerAura(L["Spell Damage increased by (%d+)"])
			if spellPowerFromAura then
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			-- Inner Fire
			_, _, spellPowerFromAura = BCS:GetPlayerAura(L["Increased damage done by magical spells and effects by (%d+)."])
			if spellPowerFromAura then
				spellPowerFromAura = tonumber(spellPowerFromAura)
				if impInnerFire then
					spellPowerFromAura = floor((spellPowerFromAura * (impInnerFire/100)) + (spellPowerFromAura))
				end
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + spellPowerFromAura
			end
		end
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

		if spiritualGuidance ~= nil then
			BCScache["talents"].damage_and_healing = 0
			local _, spirit = UnitStat("player", 5)
			BCScache["talents"].damage_and_healing = BCScache["talents"].damage_and_healing + floor(((spiritualGuidance / 100) * spirit))
		end

		damageAndHealing = BCScache["gear"].damage_and_healing + BCScache["talents"].damage_and_healing + BCScache["auras"].damage_and_healing
		damageOnly = BCScache["auras"].only_damage + BCScache["gear"].only_damage

		return damageAndHealing, secondaryPower, secondaryPowerName, damageOnly
	end
end

local ironClad = nil
-- This is stuff that gives ONLY healing, we count stuff that gives both damage and healing in GetSpellPower
function BCS:GetHealingPower()
	local healPower = 0;
	if BCS.needScanTalents then
		ironClad = nil
		BCScache["talents"].healing = 0
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Paladin
						-- Ironclad
						local _, _, value = strfind(text, L["Increases your healing power by (%d+)%% of your Armor."])
						if value and rank > 0 then
							ironClad = tonumber(value)
							break
						end
					end
				end
			end
		end
	end
	if BCS.needScanGear then
		BCScache["gear"].healing = 0
		twipe(SetBonus.healingPower)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value = strfind(text, L["Equip: Increases healing done by spells and effects by up to (%d+)."])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						-- Atiesh (druid/priest)
						_, _, value = strfind(text, L["Equip: Increases your spell damage by up to %d+ and your healing by up to (%d+)."])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						-- Enchant Weapon/Gloves/Bracers - Healing Power
						_, _, value = strfind(text, L["Healing Spells %+(%d+)"])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						-- Zandalar Signet of Serenity (Shoulder enchant)
						_, _, value = strfind(text, L["^%+(%d+) Healing Spells"])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						-- Beautiful Diamond Gemstone (Jewelcrafting)
						-- Resilience of the Scourge (Shoulder enchant)
						_, _, value = strfind(text, L["Healing %+(%d+)"])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Increases healing done by spells and effects by up to (%d+)%."])
						if value and setName and not SetBonus.healingPower[setName] then
							SetBonus.healingPower[setName] = true
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
					end
				end
			end
		end
		-- SetHyperLink doesnt show temporary enhancements, have to use SetInventoryItem
		if BCS_Tooltip:SetInventoryItem("player", 16) then
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					if strfind(text, L["^Brilliant Mana Oil"]) then
						BCScache["gear"].healing = BCScache["gear"].healing + 25
						break
					end
				end
			end
		end
	end
	local treebonus = nil
	if BCS.needScanAuras then
		BCScache["auras"].healing = 0
		-- Buffs
		local _, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing done by magical spells is increased by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		-- Tree of Life (own)
		local found = BCS:GetPlayerAura(L["Tree of Life Form"]) and BCS:GetPlayerAura(L["Tree of Life Aura"])
		local _, spirit = UnitStat("player", 5)
		if found then
			treebonus = spirit * 0.2
		end
		-- Sweet Surprise
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Increases healing done by magical spells by up to (%d+) for 3600 sec."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		-- Unstable Power
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing increased by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		-- The Eye of the Dead
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing spells increased by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		-- Power of the Guardian
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Increases healing done by magical spells and effects by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		-- Dreamshard Elixir
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing done is increased by up to (%d+)"])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		-- Empowering Herbal Salad
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing Bonus increased by (%d+)"])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
	end
	if ironClad ~= nil then
		BCScache["talents"].healing = 0
		local base = UnitArmor("player")
		local _, agility = UnitStat("player", 2)
		local armorFromGear = base - (agility * 2)
		BCScache["talents"].healing = floor(((ironClad / 100) * armorFromGear))
	end
	healPower = BCScache["gear"].healing + BCScache["auras"].healing + BCScache["talents"].healing

	return healPower, treebonus, BCScache["talents"].healing
end

local waterShield = nil
function BCS:GetManaRegen()
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

	local casting = 0
	local mp5 = 0

	if BCS.needScanTalents then
		waterShield = nil
		BCScache["talents"].casting = 0
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Priest (Meditation) / Druid (Reflection) / Mage (Arcane Meditation) / Shaman (Improved Water Shield)
						local _, _, value = strfind(text, L["Allows (%d+)%% of your Mana regeneration to continue while casting."])
						if value and rank > 0 then
							BCScache["talents"].casting = BCScache["talents"].casting + tonumber(value)
							waterShield = rank
							break
						end
					end
				end
			end
		end
	end

	if BCS.needScanGear then
		BCScache["gear"].mp5 = 0
		BCScache["gear"].casting = 0
		twipe(SetBonus.mp5)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local text = _G[BCS_Prefix .. "TextLeft" .. line]:GetText()
					if text then
						local _, _, value = strfind(text, L["^Mana Regen %+(%d+)"])
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_, _, value = strfind(text, L["Equip: Restores (%d+) mana per 5 sec."])
						if value and not strfind(text, L["to all party members"]) then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_, _, value = strfind(text, L["^Healing %+%d+ and (%d+) mana per 5 sec."])
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_, _, value = strfind(text, L["^%+(%d+) mana every 5 sec."])
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_, _, value = strfind(text, L["^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting."])
						if value then
							BCScache["gear"].casting = BCScache["gear"].casting + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Allows (%d+)%% of your Mana regeneration to continue while casting."])
						if value and setName and not SetBonus.mp5[setName] then
							SetBonus.mp5[setName] = true
							BCScache["gear"].casting = BCScache["gear"].casting + tonumber(value)
						end
						_, _, value = strfind(text, L["^Set: Restores (%d+) mana per 5 sec."])
						if value and setName and not SetBonus.mp5[setName] then
							SetBonus.mp5[setName] = true
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
					end
				end
			end
		end
		-- SetHyperLink doesnt show temporary enhancements, have to use SetInventoryItem
		if BCS_Tooltip:SetInventoryItem("player", 16) then
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					if strfind(text, L["^Brilliant Mana Oil"]) then
						BCScache["gear"].mp5 = BCScache["gear"].mp5 + 12
						break
					end
					if strfind(text, L["^Lesser Mana Oil"]) then
						BCScache["gear"].mp5 = BCScache["gear"].mp5 + 8
						break
					end
					if strfind(text, L["^Minor Mana Oil"]) then
						BCScache["gear"].mp5 = BCScache["gear"].mp5 + 4
						break
					end
				end
			end
		end
	end

	if BCS.needScanAuras then
		BCScache["auras"].casting = 0
		BCScache["auras"].mp5 = 0
		-- Buffs
		-- Improved Shadowform
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, numSpells = GetSpellTabInfo(tab);
			for s = offset + 1, offset + numSpells do
				local spell = GetSpellName(s, BOOKTYPE_SPELL);
				if spell == L["Improved Shadowform"] and BCS:GetPlayerAura(L["Shadowform"]) then
					BCScache["auras"].casting = BCScache["auras"].casting + 15
				end
			end
		end
		-- Warchief's Blessing
		local _, _, mp5FromAura = BCS:GetPlayerAura(L["Increases hitpoints by 300. 15%% haste to melee attacks. (%d+) mana regen every 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + 10
		end
		-- Epiphany
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana per 5 sec."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)
		end
		-- Nightfin Soup
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Regenerating (%d+) Mana every 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)*2.5 -- had to double the mp5FromAura because the item is a true mp5 tick
		end
		-- Mageblood Potion
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Regenerate (%d+) mana per 5 sec."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)
		end
		-- Fizzy Energy Drink and Sagefin
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Mana Regeneration increased by (%d+) every 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)*2.5
		end
		-- Second Wind
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana every 1 sec."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)*5 -- had to multiply by 5 the mp5FromAura because the item is a sec per tick
		end
		-- Power of the Guardian
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana per 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)
		end
		-- Aura of the blue dragon
		local _, _, castingFromAura = BCS:GetPlayerAura(L["(%d+)%% of your Mana regeneration continuing while casting."])
		if castingFromAura then
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
		-- Mage Armor
		_, _, castingFromAura = BCS:GetPlayerAura(L["(%d+)%% of your mana regeneration to continue while casting."])
		if castingFromAura then
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
		-- Sylvan Blessing
		_, _, castingFromAura = BCS:GetPlayerAura(L["Allows (%d+)%% of mana regeneration while casting."])
		if castingFromAura then
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
		-- Improved Water Shield
		if waterShield ~= nil then
			for i = 1, 32 do
				local icon, stacks = UnitBuff("player", i)
				if icon and stacks and icon == "Interface\\Icons\\Ability_Shaman_WaterShield" then
					BCScache["auras"].casting = BCScache["auras"].casting + (tonumber(stacks) * waterShield)
					break
				end
			end
		end
		-- Innervate
		local value
		_, _, value, castingFromAura = BCS:GetPlayerAura(L["Mana regeneration increased by (%d+)%%.  (%d+)%% Mana regeneration may continue while casting."])
		if castingFromAura then
			base = base + (base * (tonumber(value) / 100))
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
		-- Strider Presence
		_, _, castingFromAura = BCS:GetPlayerAura(L["continue (%d+)%% of their Mana regeneration"])
		if castingFromAura then
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
	end

	casting = BCScache["auras"].casting + BCScache["talents"].casting + BCScache["gear"].casting
	mp5 = BCScache["auras"].mp5 + BCScache["gear"].mp5

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

-- Weapon Skill code adapted from https://github.com/pepopo978/BetterCharacterStats
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
	local _, _, id = string.find(GetInventoryItemLink("player", GetInventorySlotInfo(slot)) or "", "(item:%d+:%d+:%d+:%d+)");
	if not id then
		return
	end

	local _, _, _, _, _, itemType = GetItemInfo(id);

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

-- https://us.forums.blizzard.com/en/wow/t/block-value-formula/283718/18
local enhancingTotems = nil
function BCS:GetBlockValue()
	local blockValue = 0
	local _, strength = UnitStat("player", 1)
	local mod = 0
	-- Gear
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
	-- Talents
	enhancingTotems = nil
	for tab = 1, GetNumTalentTabs() do
		for talent = 1, GetNumTalents(tab) do
			BCS_Tooltip:SetTalent(tab, talent)
			for line = 1, BCS_Tooltip:NumLines() do
				local left = _G[BCS_Prefix .. "TextLeft" .. line]
				local text = left:GetText()
				if text then
					local _, _, _, _, rank = GetTalentInfo(tab, talent)
					-- Warrior/Paladin
					local _, _, value = strfind(text, L["amount of damage absorbed by your shield by (%d+)%%"])
					if value and rank > 0 then
						mod = mod + tonumber(value)
						break
					end
					-- Shaman
					-- Shield Specialization
					_, _, value = strfind(text, L["increases the amount blocked by (%d+)%%"])
					if value and rank > 0 then
						mod = mod + tonumber(value)
						break
					end
					-- Enhancing Totems
					_, _, value = strfind(text, L["increases block amount by (%d+)%%"])
					if value and rank > 0 then
						enhancingTotems = tonumber(value)
						break
					end
				end
			end
		end
	end
	-- Buffs
	-- Glyph of Deflection
	local _, _, value = BCS:GetPlayerAura(L["Block value increased by (%d+)."])
	if value then
		blockValue = blockValue + tonumber(value)
	end
	-- Stoneskin Totem (talented)
	if enhancingTotems and BCS:GetPlayerAura(L["^Stoneskin$"]) then
		mod = mod + enhancingTotems
	end

	mod = mod / 100
	blockValue = blockValue + (strength / 20 - 1)
	blockValue = floor(blockValue + blockValue * mod)

	if blockValue < 0 then
		blockValue = 0
	end

	return blockValue
end

local vengefulStrikes
function BCS:GetHaste()
	if BCS.needScanTalents then
		BCScache["talents"].spell_haste = 0
		vengefulStrikes = nil
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local left = _G[BCS_Prefix .. "TextLeft" .. line]
					local text = left:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Priest (Mental Strength)
						local _, _, value = strfind(text, L["Increases your total intellect by %d+%% and your spell casting speed by (%d+)%%"])
						if value and rank > 0 then
							BCScache["talents"].spell_haste = BCScache["talents"].spell_haste + tonumber(value)
							break
						end
						-- Paladin (Vengeful Strikes)
						_, _, value = strfind(text, L["Zeal increases your attack and casting speed by an additional (%d+)%% per stack"])
						if value and rank > 0 then
							vengefulStrikes = tonumber(value)
							break
						end
					end
				end
			end
		end
	end

	if BCS.needScanGear then
		BCScache["gear"].haste = 0
		BCScache["gear"].spell_haste = 0
		-- Gear
		twipe(SetBonus.haste)
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local left = _G[BCS_Prefix .. "TextLeft" .. line]
					local text = left:GetText()
					if text then
						local _, _, value = strfind(text, L["^Equip: Increases your attack and casting speed by (%d+)%%"])
						if value then
							BCScache["gear"].haste = BCScache["gear"].haste + tonumber(value)
						end
						_, _, value = strfind(text, L["^Equip: Increases your casting speed by (%d+)%%"])
						if value then
							BCScache["gear"].spell_haste = BCScache["gear"].spell_haste + tonumber(value)
						end
						-- Sigil of Quickness (shoulder enchant)
						_, _, value = strfind(text, L["^%+(%d+)%% Haste"])
						if value then
							BCScache["gear"].haste = BCScache["gear"].haste + tonumber(value)
						end
						-- Arcanum of Rapidity (gives spell haste too on TWoW?)
						_, _, value = strfind(text, L["^Attack speed %+(%d+)%%"])
						if value then
							BCScache["gear"].haste = BCScache["gear"].haste + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Increases your attack and casting speed by (%d+)%%"])
						if value and setName and not SetBonus.haste[setName] then
							SetBonus.haste[setName] = true
							BCScache["gear"].haste = BCScache["gear"].haste + tonumber(value)
						end
					end
				end
			end
		end
	end

	if BCS.needScanAuras then
		BCScache["auras"].haste = 0
		BCScache["auras"].spell_haste = 0
		-- Buffs
		-- Bloodlust (self buff)
		local _, _, value, value2 = BCS:GetPlayerAura(L["^Increases attack speed by (%d+)%% and spell casting speed by (%d+)%%"])
		if value then
			BCScache["auras"].haste = BCScache["auras"].haste + tonumber(value)
			-- BCScache["auras"].spell_haste = BCScache["auras"].spell_haste + tonumber(value2)
		end
		-- Bloodlust (proc for party members)
		_, _, value = BCS:GetPlayerAura(L["^Increases attack and spell casting speed by (%d+)%%"])
		if value then
			BCScache["auras"].haste = BCScache["auras"].haste + tonumber(value)
		end
		-- Master Demonologist (imp)
		_, _, value = BCS:GetPlayerAura(L["increases casting speed by (%d+)%%"])
		if value then
			BCScache["auras"].spell_haste = BCScache["auras"].spell_haste + tonumber(value)
		end
		-- Master Demonologist (infernal)
		_, _, value = BCS:GetPlayerAura(L["^Increases casting and attack speed by (%d+)%%"])
		if value then
			BCScache["auras"].haste = BCScache["auras"].haste + tonumber(value)
		end
		-- Chastise
		_, _, value = BCS:GetPlayerAura(L["^Increases attack and casting speed by (%d+)%%"])
		if value then
			BCScache["auras"].haste = BCScache["auras"].haste + tonumber(value)
		end
		-- Arcane Power
		_, _, value = BCS:GetPlayerAura(L["^Casting speed increased by (%d+)%%"])
		if value then
			BCScache["auras"].spell_haste = BCScache["auras"].spell_haste + tonumber(value)
		end
		-- Zeal
		_, _, value = BCS:GetPlayerAura(L["^Attack and casting speed increased by (%d+)%%"])
		if value then
			value = tonumber(value)
			if vengefulStrikes then
				for i = 1, 32 do
					local icon, stacks = UnitBuff("player", i)
					if icon and stacks and icon == "Interface\\Icons\\Spell_Holy_CrusaderStrike" then
						value = value + (vengefulStrikes * stacks)
						break
					end
				end
			end
			BCScache["auras"].haste = BCScache["auras"].haste + value
		end
		-- Power of the Guardian (Druid)
		_, _, value = BCS:GetPlayerAura(L["^Increases your attack and casting speed by (%d+)%%"])
		if value then
			BCScache["auras"].haste = BCScache["auras"].haste + tonumber(value)
		end
	end

	local _, race = UnitRace("player")
	local haste = race == "NightElf" and 1 or 0
	haste = haste + BCScache["gear"].haste + BCScache["auras"].haste
	local spellHaste = BCScache["gear"].spell_haste + BCScache["auras"].spell_haste + BCScache["talents"].spell_haste

	return haste, spellHaste
end

local masterOfArms
function BCS:GetArmorPen()
	if BCS.needScanTalents then
		BCScache["talents"].armor_pen = 0
		masterOfArms = nil
		-- Talents
		for tab = 1, GetNumTalentTabs() do
			for talent = 1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line = 1, BCS_Tooltip:NumLines() do
					local left = _G[BCS_Prefix .. "TextLeft" .. line]
					local text = left:GetText()
					if text then
						local _, _, _, _, rank = GetTalentInfo(tab, talent)
						-- Warrior (Master of Arms)
						local _, _, value = strfind(text, L["Causes your attacks to ignore (%d+) of your target's Armor per level"])
						if value and rank > 0 then
							masterOfArms = tonumber(value) * UnitLevel("player")
							break
						end
					end
				end
			end
		end
	end

	if BCS.needScanGear then
		BCScache["gear"].armor_pen = 0
		twipe(SetBonus.armor_pen)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local left = _G[BCS_Prefix .. "TextLeft" .. line]
					local text = left:GetText()
					if text then
						local _, _, value = strfind(text, L["^Equip: Your attacks ignore (%d+) of the target's armor"])
						if value then
							BCScache["gear"].armor_pen = BCScache["gear"].armor_pen + tonumber(value)
						end
						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Your attacks ignore (%d+) of the target's armor"])
						if value and setName and not SetBonus.armor_pen[setName] then
							SetBonus.armor_pen[setName] = true
							BCScache["gear"].armor_pen = BCScache["gear"].armor_pen + tonumber(value)
						end
					end
				end
			end
		end
	end

	if BCS.needScanAuras then
		BCScache["auras"].armor_pen = 0
		-- Buffs
		-- Bonereaver's Edge
		local _, _, value = BCS:GetPlayerAura(L["^Ignore (%d+) of enemies' armor"])
		if value then
			BCScache["auras"].armor_pen = BCScache["auras"].armor_pen + tonumber(value)
		end
		-- Badge of the Swarmguard
		_, _, value = BCS:GetPlayerAura(L["^Current target's armor is reduced by (%d+)"])
		if value then
			BCScache["auras"].armor_pen = BCScache["auras"].armor_pen + tonumber(value)
		end
	end

	if masterOfArms then
		BCScache["talents"].armor_pen = 0
		local _, _, itemID = strfind(GetInventoryItemLink("player", 16) or "", "item:(%d+)")
		if itemID then
			local itemName, itemLink, itemQuality, itemMinLevel, itemType, itemSubType = GetItemInfo(itemID)
			if itemSubType and (itemSubType == L["One-Handed Maces"] or itemSubType == L["Two-Handed Maces"]) then
				BCScache["talents"].armor_pen = masterOfArms
			end
		end
	end

	return BCScache["gear"].armor_pen + BCScache["auras"].armor_pen + BCScache["talents"].armor_pen, BCScache["talents"].armor_pen
end

function BCS:GetSpellPen()
	if BCS.needScanGear then
		BCScache["gear"].spell_pen = 0
		twipe(SetBonus.spell_pen)
		-- Gear
		for slot = 1, 19 do
			if BCS_Tooltip:SetInventoryItem("player", slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink("player", slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then
					BCS_Tooltip:ClearLines()
					BCS_Tooltip:SetHyperlink(eqItemLink)
				end
				local setName
				for line = 1, BCS_Tooltip:NumLines() do
					local left = _G[BCS_Prefix .. "TextLeft" .. line]
					local text = left:GetText()
					if text then
						local _, _, value = strfind(text, L["^Equip: Decreases the magical resistances of your spell targets by (%d+)"])
						if value then
							BCScache["gear"].spell_pen = BCScache["gear"].spell_pen + tonumber(value)
						end
						_, _, value = strfind(text, L["^%+(%d+) Spell Penetration"])
						if value then
							BCScache["gear"].spell_pen = BCScache["gear"].spell_pen + tonumber(value)
						end

						-- Set Bonuses
						_, _, value = strfind(text, setPattern)
						if value then
							setName = value
						end
						_, _, value = strfind(text, L["^Set: Decreases the magical resistances of your spell targets by (%d+)"])
						if value and setName and not SetBonus.spell_pen[setName] then
							SetBonus.spell_pen[setName] = true
							BCScache["gear"].spell_pen = BCScache["gear"].spell_pen + tonumber(value)
						end
					end
				end
			end
		end
	end

	return BCScache["gear"].spell_pen
end

function BCS:GetHPRegen()
	-- "Regenerate (%d+) health every 5 sec."
	-- "Increases your movement speed by 15% and restores 60 Health per 5 sec. Half of this effect is granted to allies within 30 yards."
	-- "Equip: Restores 16 health per 5 sec."
	-- "Set: Restores 8 health per 5 sec."
end