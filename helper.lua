BCS = BCS or {}

local BCS_Tooltip = getglobal("BetterCharacterStatsTooltip") or CreateFrame("GameTooltip", "BetterCharacterStatsTooltip", nil, "GameTooltipTemplate")
local BCS_Prefix = "BetterCharacterStatsTooltip"
BCS_Tooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local L = BCS["L"]

local strfind = strfind
local tonumber = tonumber
local tinsert = tinsert

local function tContains(table, item)
	local index = 1
	while table[index] do
		if ( item == table[index] ) then
			return 1
		end
		index = index + 1
	end
	return nil
end
--cache;
--[1] - gear; [2] - talents; [3] - buffs
BCScache = BCScache or {
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
		spell_crit = 0,
		casting = 0,
		mp5 = 0,
		hit = 0,
		ranged_hit = 0,
		ranged_crit = 0
	},
	["auras"] = {
		damage_and_healing = 0,
		only_damage = 0, -- +dmg to all schools, comes from buffs only currently, needed to calculate healing
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
function BCS:GetPlayerAura(searchText, auraType)
	if not auraType then
		-- buffs
		-- http://blue.cardplace.com/cache/wow-dungeons/624230.htm
		-- 32 buffs max
		for i=0, 31 do
			local index = GetPlayerBuff(i, 'HELPFUL')
			if index > -1 then
				BCS_Tooltip:SetPlayerBuff(index)
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						if left:GetText() == "Power of the Guardian" and searchText == "Power of the Guardian Crit" then
							searchText = "Increases spell critical chance by (%d)%%."
							left = getglobal(BCS_Prefix .. "TextLeft" .. 2)
						end
						local value = {strfind(left:GetText(), searchText)}
						if value[1] then
							return unpack(value)
						end
					end
				end
			end
		end
	elseif auraType == 'HARMFUL' then
		for i=0, 6 do
			local index = GetPlayerBuff(i, auraType)
			if index > -1 then
				BCS_Tooltip:SetPlayerBuff(index)
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local value = {strfind(left:GetText(), searchText)}
						if value[1] then
							return unpack(value)
						end
					end
				end
			end
		end
	end
end

function BCS:GetHitRating(hitOnly)
	local Hit_Set_Bonus = {}
	local hit = 0

	if BCS.needScanGear then
		BCScache["gear"].hit = 0
		--scan gear
		for slot=1, 19 do
			if BCS_Tooltip:SetInventoryItem('player', slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
				local SET_NAME = nil
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to hit by (%d)%%."])
						if value then
							BCScache["gear"].hit = BCScache["gear"].hit + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["/Hit %+(%d+)"])
						if value then
							BCScache["gear"].hit = BCScache["gear"].hit + tonumber(value)
						end

						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end
						_,_, value = strfind(left:GetText(), L["^Set: Improves your chance to hit by (%d)%%."])
						if value and SET_NAME and not tContains(Hit_Set_Bonus, SET_NAME) then
							tinsert(Hit_Set_Bonus, SET_NAME)
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
		-- buffs
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
		-- debuffs
		_, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit reduced by (%d+)%%."], 'HARMFUL')
		if hitFromAura then
			BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + tonumber(hitFromAura)
		end
		_, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec."], 'HARMFUL')
		if hitFromAura then
			BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + tonumber(hitFromAura)
		end
		hitFromAura = BCS:GetPlayerAura(L["Lowered chance to hit."], 'HARMFUL')
		if hitFromAura then
			BCScache["auras"].hit_debuff = BCScache["auras"].hit_debuff + 25
		end
	end

	if BCS.needScanTalents then
		BCScache["talents"].hit = 0
		--scan talents
		for tab=1, GetNumTalentTabs() do
			for talent=1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
						-- Rogue
						local _,_, value = strfind(left:GetText(), L["Increases your chance to hit with melee weapons by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Hunter
						_,_, value = strfind(left:GetText(), L["Increases hit chance by (%d)%% and increases the chance movement impairing effects will be resisted by an additional %d+%%."])
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Druid
						-- Natural Weapons
						_,_, value = strfind(left:GetText(), "Also increases chance to hit with melee attacks and spells by (%d+)%%.")
						if value and rank > 0 then
							BCScache["talents"].hit = BCScache["talents"].hit + tonumber(value)
							break
						end
						-- Paladin & Shaman
						-- Precision & Nature's Guidance
						_,_, value = strfind(left:GetText(), "Increases your chance to hit with melee attacks and spells by (%d+)%%.")
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
		if hit < 0 then hit = 0 end -- Dust Cloud OP
		return hit
	else
		return hit
	end
end

function BCS:GetRangedHitRating()
	if BCS.needScanGear then
		BCScache["gear"].ranged_hit = 0
		if BCS_Tooltip:SetInventoryItem("player", 18) then
			for line=1, BCS_Tooltip:NumLines() do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["+(%d)%% Hit"])
					if value then
						BCScache["gear"].ranged_hit = BCScache["gear"].ranged_hit + tonumber(value)
						break
					end
				end
			end
		end
	end
	local ranged_hit = BCS:GetHitRating(true) + BCScache["gear"].ranged_hit - BCScache["auras"].hit_debuff
	if ranged_hit < 0 then ranged_hit = 0 end
	return ranged_hit
end

function BCS:GetSpellHitRating()
	local hit = 0
	local hit_fire = 0
	local hit_frost = 0
	local hit_arcane = 0
	local hit_shadow = 0
	local hit_Set_Bonus = {}
	if BCS.needScanGear then
		BCScache["gear"].spell_hit = 0
		-- scan gear
		for slot=1, 19 do
			if BCS_Tooltip:SetInventoryItem('player', slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
				local SET_NAME
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to hit with spells by (%d)%%."])
						if value then
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["/Spell Hit %+(%d+)"])
						if value then
							BCScache["gear"].spell_hit = BCScache["gear"].spell_hit + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end
						_, _, value = strfind(left:GetText(), L["^Set: Improves your chance to hit with spells by (%d)%%."])
						if value and SET_NAME and not tContains(hit_Set_Bonus, SET_NAME) then
							tinsert(hit_Set_Bonus, SET_NAME)
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
		-- scan talents
		for tab=1, GetNumTalentTabs() do
			for talent=1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
						-- Mage
						-- Elemental Precision
						local _,_, value = strfind(left:GetText(), L["Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_fire = BCScache["talents"].spell_hit_fire + tonumber(value)
							BCScache["talents"].spell_hit_frost = BCScache["talents"].spell_hit_frost + tonumber(value)
							break
						end
						-- Arcane Focus
						_,_, value = strfind(left:GetText(), L["Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_arcane = BCScache["talents"].spell_hit_arcane + tonumber(value)
							break
						end
						-- Priest
						-- Shadow Focus
						_,_, value = strfind(left:GetText(), L["Reduces your target's chance to resist your Shadow spells by (%d+)%%."])
						if value and rank > 0 then
							BCScache["talents"].spell_hit_shadow = BCScache["talents"].spell_hit_shadow + tonumber(value)
							break
						end
						-- Druid
						-- Natural Weapons
						_,_, value = strfind(left:GetText(), "Also increases chance to hit with melee attacks and spells by (%d+)%%.")
						if value and rank > 0 then
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
							break
						end
						-- Paladin & Shaman
						-- Precision & Nature's Guidance
						_,_, value = strfind(left:GetText(), "Increases your chance to hit with melee weapons and spells by (%d+)%%.")
						if value and rank > 0 then
							BCScache["talents"].spell_hit = BCScache["talents"].spell_hit + tonumber(value)
							break
						end
					end
				end
			end
		end
	end
	-- buffs
	if BCS.needScanAuras then
		BCScache["auras"].spell_hit = 0
		local _, _, hitFromAura = BCS:GetPlayerAura(L["Spell hit chance increased by (%d+)%%."])
		if hitFromAura then
			BCScache["auras"].spell_hit = BCScache["auras"].spell_hit + tonumber(hitFromAura)
		end
	end
	hit = BCScache["gear"].spell_hit + BCScache["talents"].spell_hit + BCScache["auras"].spell_hit
	hit_fire = BCScache["talents"].spell_hit_fire
	hit_frost = BCScache["talents"].spell_hit_frost
	hit_arcane = BCScache["talents"].spell_hit_arcane
	hit_shadow = BCScache["talents"].spell_hit_shadow
	return hit, hit_fire, hit_frost, hit_arcane, hit_shadow
end

function BCS:GetCritChance() -- so easy lol, wish i could say same about other stuff
	local crit = 0
	--scan spellbook
	for tab=1, GetNumSpellTabs() do
		local name, texture, offset, numSpells = GetSpellTabInfo(tab)
		for spell=1, numSpells do
			local currentPage = ceil(spell/SPELLS_PER_PAGE)
			local SpellID = spell + offset + ( SPELLS_PER_PAGE * (currentPage - 1))
			BCS_Tooltip:SetSpell(SpellID, BOOKTYPE_SPELL)
			for line=1, BCS_Tooltip:NumLines() do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["([%d.]+)%% chance to crit"])
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
	local _, class = UnitClass("player")
	local _, agility = UnitStat("player", 2)
	local vallvl1 = 0
	local vallvl60 = 0
	local classrate = 0
	if class == "MAGE" then vallvl1 = 12.9 vallvl60 = 20
	elseif class == "ROGUE" then vallvl1 = 2.2 vallvl60 = 29
	elseif class == "HUNTER" then vallvl1 = 3.5 vallvl60 = 53
	elseif class == "PRIEST" then vallvl1 = 11 vallvl60 = 20
	elseif class == "WARLOCK" then vallvl1 = 8.4 vallvl60 = 20
	elseif class == "WARRIOR" then vallvl1 = 3.9 vallvl60 = 20
	else return crit end
	classrate = vallvl1 * (60 - UnitLevel("player")) / 59 + vallvl60 * (UnitLevel("player") - 1) / 59
	crit = agility / classrate
	if BCS.needScanTalents then
		BCScache["talents"].ranged_crit = 0
		--scan talents
		for tab=1, GetNumTalentTabs() do
			for talent=1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
						local _,_, value = strfind(left:GetText(), L["Increases your critical strike chance with ranged weapons by (%d)%%."])
						if value and rank > 0 then
							BCScache["talents"].ranged_crit = BCScache["talents"].ranged_crit + tonumber(value)
							break
						end
						_,_, value = strfind(left:GetText(), L["Increases your critical strike chance with all attacks by (%d)%%."])
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
		--scan gear
		local Crit_Set_Bonus = {}
		for slot=1, 19 do
			if BCS_Tooltip:SetInventoryItem('player', slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
				local SET_NAME
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to get a critical strike by (%d)%%."])
						if value then
							BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + tonumber(value)
						end

						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end
						_, _, value = strfind(left:GetText(), L["^Set: Improves your chance to get a critical strike by (%d)%%."])
						if value and SET_NAME and not tContains(Crit_Set_Bonus, SET_NAME) then
							tinsert(Crit_Set_Bonus, SET_NAME)
							BCScache["gear"].ranged_crit = BCScache["gear"].ranged_crit + tonumber(value)
						end
					end
				end
			end
		end
	end
	if BCS.needScanAuras then
		BCScache["auras"].ranged_crit = 0
		--buffs
		--ony head
		local critFromAura = BCS:GetPlayerAura(L["Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + 5
		end
		--mongoose
		_, _, critFromAura = BCS:GetPlayerAura(L["Agility increased by 25, Critical hit chance increases by (%d)%%."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + tonumber(critFromAura)
		end
		--songflower
		_, _, critFromAura = BCS:GetPlayerAura(L["Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+."])
		if critFromAura then
			BCScache["auras"].ranged_crit = BCScache["auras"].ranged_crit + tonumber(critFromAura)
		end
	end
	if class == "MAGE" then crit = crit + 3.2
	elseif class == "PRIEST" then crit = crit + 3
	elseif class == "WARLOCK" then crit = crit + 2
	end
	crit = crit + BCScache["gear"].ranged_crit + BCScache["talents"].ranged_crit + BCScache["auras"].ranged_crit
	return crit
end

function BCS:GetSpellCritChance()
	-- school crit: most likely never
	local Crit_Set_Bonus = {}
	local spellCrit = 0;
	local _, intellect = UnitStat("player", 4)
	local _, class = UnitClass("player")
	
	-- values from vmangos core 
	local playerLevel = UnitLevel("player")
	if class == "MAGE" then
		spellCrit = 3.7 + intellect / (14.77 + .65 * playerLevel)
	elseif class == "WARLOCK" then
		spellCrit = 3.18 + intellect / (11.30 + .82 * playerLevel)
	elseif class == "PRIEST" then
		spellCrit = 2.97 + intellect / (10.03 + .82 * playerLevel)
	elseif class == "DRUID" then
		spellCrit = 3.33 + intellect / (12.41 + .79 * playerLevel)
	elseif class == "SHAMAN" then
		spellCrit = 3.54 + intellect / (11.51 + .8 * playerLevel)
	elseif class == "PALADIN" then
		spellCrit = 3.7 + intellect / (14.77 + .65 * playerLevel)
	end
	if BCS.needScanGear then
		BCScache["gear"].spell_crit = 0
		--scan gear
		for slot=1, 19 do
			if BCS_Tooltip:SetInventoryItem('player', slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
				local SET_NAME = nil
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to get a critical strike with spells by (%d)%%."])
						if value then
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end

						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end
						_, _, value = strfind(left:GetText(), L["^Set: Improves your chance to get a critical strike with spells by (%d)%%."])
						if value and SET_NAME and not tContains(Crit_Set_Bonus, SET_NAME) then
							tinsert(Crit_Set_Bonus, SET_NAME)
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), "(%d)%% Spell Critical Strike")
						if value then
							BCScache["gear"].spell_crit = BCScache["gear"].spell_crit + tonumber(value)
						end
					end
				end
			end
		end
	end

	if BCS.needScanAuras then
		BCScache["auras"].spell_crit = 0
		-- buffs
		local _, _, critFromAura = BCS:GetPlayerAura(L["Chance for a critical hit with a spell increased by (%d+)%%."])
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		_, _, critFromAura = BCS:GetPlayerAura("(Moonkin Aura)")
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + 3
		end
		_, _, critFromAura = BCS:GetPlayerAura("Power of the Guardian Crit")
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit + tonumber(critFromAura)
		end
		_, _, critFromAura = BCS:GetPlayerAura("Chance to get a critical strike with spells is increased by (%d+)%%")
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
		-- debuffs
		_, _, _, critFromAura = BCS:GetPlayerAura(L["Melee critical-hit chance reduced by (%d+)%%.\r\nSpell critical-hit chance reduced by (%d+)%%."], 'HARMFUL')
		if critFromAura then
			BCScache["auras"].spell_crit = BCScache["auras"].spell_crit - tonumber(critFromAura)
		end
	end

	spellCrit = spellCrit + BCScache["gear"].spell_crit + BCScache["auras"].spell_crit

	return spellCrit
end

function BCS:GetSpellPower(school)
	if school then
		local spellPower = 0;
		--scan gear
		if BCS.needScanGear then
			if school == "Arcane" then BCScache["gear"].arcane = 0
			elseif school == "Fire" then BCScache["gear"].fire = 0
			elseif school == "Frost" then BCScache["gear"].frost = 0
			elseif school == "Holy" then BCScache["gear"].holy = 0
			elseif school == "Nature" then BCScache["gear"].nature = 0
			elseif school == "Shadow" then BCScache["gear"].shadow = 0
			end
			for slot=1, 19 do
				if BCS_Tooltip:SetInventoryItem("player", slot) then
					for line=1, BCS_Tooltip:NumLines() do
						local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
						if left:GetText() then
							local _,_, value = strfind(left:GetText(), L["Equip: Increases damage done by "..school.." spells and effects by up to (%d+)."])
							if value then
								spellPower = spellPower + tonumber(value)
							end
							if L[school.." Damage %+(%d+)"] then
								_,_, value = strfind(left:GetText(), L[school.." Damage %+(%d+)"])
								if value then
									spellPower = spellPower + tonumber(value)
								end
							end
							if L["^%+(%d+) "..school.." Spell Damage"] then
								_,_, value = strfind(left:GetText(), L["^%+(%d+) "..school.." Spell Damage"])
								if value then
									spellPower = spellPower + tonumber(value)
								end
							end
						end
					end
				end
			end
			if school == "Arcane" then BCScache["gear"].arcane = spellPower
			elseif school == "Fire" then BCScache["gear"].fire = spellPower
			elseif school == "Frost" then BCScache["gear"].frost = spellPower
			elseif school == "Holy" then BCScache["gear"].holy = spellPower
			elseif school == "Nature" then BCScache["gear"].nature = spellPower
			elseif school == "Shadow" then BCScache["gear"].shadow = spellPower
			end
		else
			if school == "Arcane" then spellPower = BCScache["gear"].arcane
			elseif school == "Fire" then spellPower = BCScache["gear"].fire
			elseif school == "Frost" then spellPower = BCScache["gear"].frost
			elseif school == "Holy" then spellPower = BCScache["gear"].holy
			elseif school == "Nature" then spellPower = BCScache["gear"].nature
			elseif school == "Shadow" then spellPower = BCScache["gear"].shadow
			end
		end

		return spellPower
	else
		local spellPower = 0
		local damagePower = 0
		local SpellPower_Set_Bonus = {}
		if BCS.needScanGear then
			BCScache["gear"].damage_and_healing = 0
			BCScache["gear"].arcane = 0
			BCScache["gear"].fire = 0
			BCScache["gear"].frost = 0
			BCScache["gear"].holy = 0
			BCScache["gear"].nature = 0
			BCScache["gear"].shadow = 0
			-- scan gear
			for slot=1, 19 do
				if BCS_Tooltip:SetInventoryItem('player', slot) then
					local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
					if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
					local SET_NAME
					for line=1, BCS_Tooltip:NumLines() do
						local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
						if left:GetText() then
							local _,_, value = strfind(left:GetText(), L["Equip: Increases damage and healing done by magical spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), "Equip: Increases your spell damage by up to (%d+)")
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["Spell Damage %+(%d+)"])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Spell Damage and Healing"])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Damage and Healing Spells"])
							if value then
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Arcane spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].arcane = BCScache["gear"].arcane + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Arcane Spell Damage"])
							if value then
								BCScache["gear"].arcane = BCScache["gear"].arcane + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Fire spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].fire = BCScache["gear"].fire + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["Fire Damage %+(%d+)"])
							if value then
								BCScache["gear"].fire = BCScache["gear"].fire + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Fire Spell Damage"])
							if value then
								BCScache["gear"].fire = BCScache["gear"].fire + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Frost spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].frost = BCScache["gear"].frost + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["Frost Damage %+(%d+)"])
							if value then
								BCScache["gear"].frost = BCScache["gear"].frost + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Frost Spell Damage"])
							if value then
								BCScache["gear"].frost = BCScache["gear"].frost + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Holy spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].holy = BCScache["gear"].holy + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Holy Spell Damage"])
							if value then
								BCScache["gear"].holy = BCScache["gear"].holy + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Nature spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].nature = BCScache["gear"].nature + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Nature Spell Damage"])
							if value then
								BCScache["gear"].nature = BCScache["gear"].nature + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Shadow spells and effects by up to (%d+)."])
							if value then
								BCScache["gear"].shadow = BCScache["gear"].shadow + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["Shadow Damage %+(%d+)"])
							if value then
								BCScache["gear"].shadow = BCScache["gear"].shadow + tonumber(value)
							end
							_,_, value = strfind(left:GetText(), L["^%+(%d+) Shadow Spell Damage"])
							if value then
								BCScache["gear"].shadow = BCScache["gear"].shadow + tonumber(value)
							end
							
							_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
							if value then
								SET_NAME = value
							end

							_, _, value = strfind(left:GetText(), L["^Set: Increases damage and healing done by magical spells and effects by up to (%d+)%."])
							if value and SET_NAME and not tContains(SpellPower_Set_Bonus, SET_NAME) then
								tinsert(SpellPower_Set_Bonus, SET_NAME)
								BCScache["gear"].damage_and_healing = BCScache["gear"].damage_and_healing + tonumber(value)
							end
						end
					end
				end
			end
		end

		if BCS.needScanTalents then
			BCScache["talents"].damage_and_healing = 0
			-- scan talents
			for tab=1, GetNumTalentTabs() do
				for talent=1, GetNumTalents(tab) do
					BCS_Tooltip:SetTalent(tab, talent)
					for line=1, BCS_Tooltip:NumLines() do
						local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
						if left:GetText() then
							local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
							-- Priest
							-- Spiritual Guidance
							local _,_, value = strfind(left:GetText(), L["Increases spell damage and healing by up to (%d+)%% of your total Spirit."])
							if value and rank > 0 then
								local stat, spirit = UnitStat("player", 5)
								BCScache["talents"].damage_and_healing = BCScache["talents"].damage_and_healing + floor(((tonumber(value) / 100) * spirit))
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
			-- buffs
			local _, _, spellPowerFromAura = BCS:GetPlayerAura(L["Magical damage dealt is increased by up to (%d+)."])
			if spellPowerFromAura then
				BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + tonumber(spellPowerFromAura)
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			
			_, _, spellPowerFromAura = BCS:GetPlayerAura("Increases damage and healing done by magical spells and effects by up to (%d+).")
			if spellPowerFromAura then
				BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + tonumber(spellPowerFromAura)
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			
			_, _, spellPowerFromAura = BCS:GetPlayerAura("Magical damage dealt by spells and abilities is increased by up to (%d+)")
			if spellPowerFromAura then
				BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + tonumber(spellPowerFromAura)
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			
			_, _, spellPowerFromAura = BCS:GetPlayerAura("Spell damage is increased by up to (%d+)")
			if spellPowerFromAura then
				BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + tonumber(spellPowerFromAura)
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
			--turtle wow spell power food 
			_, _, spellPowerFromAura = BCS:GetPlayerAura("Spell Damage increased by (%d+)")
			if spellPowerFromAura then
				BCScache["auras"].damage_and_healing = BCScache["auras"].damage_and_healing + tonumber(spellPowerFromAura)
				BCScache["auras"].only_damage = BCScache["auras"].only_damage + tonumber(spellPowerFromAura)
			end
		end
		local secondaryPower = 0
		local secondaryPowerName = ""
	
		if BCScache["gear"].arcane > secondaryPower then
			secondaryPower = BCScache["gear"].arcane
			secondaryPowerName = L.SPELL_SCHOOL_ARCANE
		end
		if BCScache["gear"].fire > secondaryPower then
			secondaryPower = BCScache["gear"].fire
			secondaryPowerName = L.SPELL_SCHOOL_FIRE
		end
		if BCScache["gear"].frost > secondaryPower then
			secondaryPower = BCScache["gear"].frost
			secondaryPowerName = L.SPELL_SCHOOL_FROST
		end
		if BCScache["gear"].holy > secondaryPower then
			secondaryPower = BCScache["gear"].holy
			secondaryPowerName = L.SPELL_SCHOOL_HOLY
		end
		if BCScache["gear"].nature > secondaryPower then
			secondaryPower = BCScache["gear"].nature
			secondaryPowerName = L.SPELL_SCHOOL_NATURE
		end
		if BCScache["gear"].shadow > secondaryPower then
			secondaryPower = BCScache["gear"].shadow
			secondaryPowerName = L.SPELL_SCHOOL_SHADOW
		end

		spellPower = BCScache["gear"].damage_and_healing + BCScache["talents"].damage_and_healing + BCScache["auras"].damage_and_healing
		damagePower = BCScache["auras"].only_damage

		return spellPower, secondaryPower, secondaryPowerName, damagePower
	end
end

function BCS:GetHealingPower()
	local healPower = 0;
	local healPower_Set_Bonus = {}
	if BCS.needScanGear then
		BCScache["gear"].healing = 0
		--scan gear
		for slot=1, 19 do
			if BCS_Tooltip:SetInventoryItem('player', slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
				local SET_NAME
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["Equip: Increases healing done by spells and effects by up to (%d+)."])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), "Equip: Increases your spell damage by up to 120 and your healing by up to (300).")
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value) - 120
						end
						_,_, value = strfind(left:GetText(), L["Healing Spells %+(%d+)"])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^Healing %+(%d+) and %d+ mana per 5 sec."])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Healing Spells"])
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), "^Brilliant Mana Oil %((%d+) min%)")
						if value then
							BCScache["gear"].healing = BCScache["gear"].healing + 25
						end
						
						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end
						_, _, value = strfind(left:GetText(), L["^Set: Increases healing done by spells and effects by up to (%d+)%."])
						if value and SET_NAME and not tContains(healPower_Set_Bonus, SET_NAME) then
							tinsert(healPower_Set_Bonus, SET_NAME)
							BCScache["gear"].healing = BCScache["gear"].healing + tonumber(value)
						end
					end
				end
			end
		end
	end
	
	-- buffs
	local treebonus = nil
	if BCS.needScanAuras then
		BCScache["auras"].healing = 0
		local _, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing done by magical spells is increased by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		--Tree of Life (own)
		local found = BCS:GetPlayerAura("Tree of Life Form") and BCS:GetPlayerAura("Tree of Life Aura")
		local _, spirit = UnitStat("player", 5)
		if found then
			treebonus = spirit * 0.2
		end
		--Sweet Surprise
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Increases healing done by magical spells by up to (%d+) for 3600 sec."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		--Unstable Power
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing increased by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		--The Eye of the Dead
		_, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing spells increased by up to (%d+)."])
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		--Power of the Guardian
		_, _, healPowerFromAura = BCS:GetPlayerAura("Increases healing done by magical spells and effects by up to (%d+).")
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		_, _, healPowerFromAura = BCS:GetPlayerAura("Increases damage and healing done by magical spells and effects by up to (%d+).")
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
		--Dreamshard Elixir
		_, _, healPowerFromAura = BCS:GetPlayerAura("Healing done is increased by up to (%d+)")
		if healPowerFromAura then
			BCScache["auras"].healing = BCScache["auras"].healing + tonumber(healPowerFromAura)
		end
	end

	healPower = BCScache["gear"].healing + BCScache["auras"].healing

	return healPower, treebonus
end

local function GetRegenMPPerSpirit()
	local addvalue = 0
	local stat, Spirit, posBuff, negBuff = UnitStat("player", 5)
	local lClass, class = UnitClass("player")

	if class == "DRUID" then
		addvalue = (Spirit / 5 + 15)
	elseif class == "HUNTER" then
		addvalue = (Spirit / 5 + 15)
	elseif class == "MAGE" then
		addvalue = (Spirit / 4 + 12.5)
	elseif class == "PALADIN" then
		addvalue = (Spirit / 5 + 15)
	elseif class == "PRIEST" then
		addvalue = (Spirit / 4 + 12.5)
	elseif class == "SHAMAN" then
		addvalue = (Spirit / 5 + 17)
	elseif class == "WARLOCK" then
		addvalue = (Spirit / 5 + 15)
	end

	return addvalue
end

function BCS:GetManaRegen()
	local base = GetRegenMPPerSpirit()
	local casting = 0
	local mp5 = 0
	local mp5_Set_Bonus = {}
	if BCS.needScanGear then
		BCScache["gear"].mp5 = 0
		BCScache["gear"].casting = 0
		--scan gear
		for slot=1, 19 do
			if BCS_Tooltip:SetInventoryItem('player', slot) then
				local _, _, eqItemLink = strfind(GetInventoryItemLink('player', slot), "(item:%d+:%d+:%d+:%d+)")
				if eqItemLink then BCS_Tooltip:ClearLines() BCS_Tooltip:SetHyperlink(eqItemLink) end
				local SET_NAME
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["^Mana Regen %+(%d+)"])
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["Equip: Restores (%d+) mana per 5 sec."])
						if value and not strfind(left:GetText(), "to all party members") then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^Healing %+%d+ and (%d+) mana per 5 sec."])
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) mana every 5 sec."])
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), "^Brilliant Mana Oil %((%d+) min%)")
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + 12
						end
						_,_, value = strfind(left:GetText(), "^Lesser Mana Oil %((%d+) min%)")
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + 8
						end
						_,_, value = strfind(left:GetText(), "^Minor Mana Oil %((%d+) min%)")
						if value then
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + 4
						end
						_,_, value = strfind(left:GetText(), "^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting.")
						if value then
							BCScache["gear"].casting = BCScache["gear"].casting + tonumber(value)
						end

						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end
						_,_, value = strfind(left:GetText(), L["^Set: Allows (%d+)%% of your Mana regeneration to continue while casting."])
						if value and SET_NAME and not tContains(mp5_Set_Bonus, SET_NAME) then
							tinsert(mp5_Set_Bonus, SET_NAME)
							BCScache["gear"].casting = BCScache["gear"].casting + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), "^Set: Restores (%d+) mana per 5 sec.")
						if value and SET_NAME and not tContains(mp5_Set_Bonus, SET_NAME) then
							tinsert(mp5_Set_Bonus, SET_NAME)
							BCScache["gear"].mp5 = BCScache["gear"].mp5 + tonumber(value)
						end
					end
				end
			end
		end
	end

	-- buffs
	if BCS.needScanAuras then
		BCScache["auras"].casting = 0
		BCScache["auras"].mp5 = 0
		-- improved Shadowform
		for i = 1, MAX_SKILLLINE_TABS do
			local name, texture, offset, numSpells = GetSpellTabInfo(i);
			for s = offset + 1, offset + numSpells do
			local spell = GetSpellName(s, BOOKTYPE_SPELL);
				if spell == "Improved Shadowform" and BCS:GetPlayerAura("Shadowform") then
					BCScache["auras"].casting = BCScache["auras"].casting + 15
				end
			end
		end
		-- Warchief's Blessing
		local _, _, mp5FromAura = BCS:GetPlayerAura(L["Increases hitpoints by 300. 15%% haste to melee attacks. (%d+) mana regen every 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + 10
		end
		--Epiphany 
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana per 5 sec."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)
		end
		--Nightfin Soup 
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Regenerating (%d+) Mana every 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)*2.5 -- had to double the mp5FromAura because the item is a true mp5 tick
		end
		--Mageblood Potion 
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Regenerate (%d+) mana per 5 sec."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)
		end
		--Fizzy Energy Drink and Sagefin
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Mana Regeneration increased by (%d+) every 5 seconds."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)*2.5
		end
		--Second Wind
		_, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana every 1 sec."])
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)*5 -- had to multiply by 5 the mp5FromAura because the item is a sec per tick
		end
		--Power of the Guardian
		_, _, mp5FromAura = BCS:GetPlayerAura("Restores (%d+) mana per 5 seconds.")
		if mp5FromAura then
			BCScache["auras"].mp5 = BCScache["auras"].mp5 + tonumber(mp5FromAura)
		end
		--Aura of the blue dragon
		local _, _, castingFromAura = BCS:GetPlayerAura(L["(%d+)%% of your Mana regeneration continuing while casting."])
		if castingFromAura then
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
		--Mage Armor
		_, _, castingFromAura = BCS:GetPlayerAura(L["(%d+)%% of your mana regeneration to continue while casting."])
		if castingFromAura then
			BCScache["auras"].casting = BCScache["auras"].casting + tonumber(castingFromAura)
		end
	end

	mp5 = BCScache["auras"].mp5 + BCScache["gear"].mp5

	-- scan talents
	local brilliance = nil
	if BCS.needScanTalents then
		BCScache["talents"].casting = 0
		for tab=1, GetNumTalentTabs() do
			for talent=1, GetNumTalents(tab) do
				BCS_Tooltip:SetTalent(tab, talent)
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
						-- Priest (Meditation) / Druid (Reflection) / Mage (Arcane Meditation)
						local _,_, value = strfind(left:GetText(), L["Allows (%d+)%% of your Mana regeneration to continue while casting."])
						if value and rank > 0 then
							BCScache["talents"].casting = BCScache["talents"].casting + tonumber(value)
							break
						end
						-- Brilliance Aura (own)
						if strfind(left:GetText(), "Brilliance Aura") and rank > 0 and BCS:GetPlayerAura("Brilliance Aura") then
							brilliance = (base + (mp5 * 0.4)) * 0.15
						end
					end
				end
			end
		end
	end

	casting = BCScache["auras"].casting + BCScache["talents"].casting + BCScache["gear"].casting

	if casting > 100 then
		casting = 100
	end

	return base, casting, mp5, brilliance
end

--Weapon Skill code adapted from https://github.com/pepopo978/BetterCharacterStats
function BCS:GetWeaponSkill(skillName)
	-- loop through skills
	local skillIndex = 1
	while true do
		local name, isHeader, isExpanded, skillRank, numTempPoints, skillModifier,
		skillMaxRank, isAbandonable, stepCost, rankCost, minLevel, skillCostType,
		skillDescription = GetSkillLineInfo(skillIndex)
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

function BCS:GetItemInfoForSlot(slot)
	local _, _, id = string.find(GetInventoryItemLink("player", GetInventorySlotInfo(slot)) or "", "(item:%d+:%d+:%d+:%d+)");
	if not id then
		return
	end

	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(id);

	return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice;
end

function BCS:GetMHWeaponSkill()
	if not BCS.needScanSkills then return BCScache["skills"].mh end
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = BCS:GetItemInfoForSlot("MainHandSlot")
	BCScache["skills"].mh = BCS:GetWeaponSkillForWeaponType(itemType)
	return BCScache["skills"].mh
end

function BCS:GetOHWeaponSkill()
	if not BCS.needScanSkills then return BCScache["skills"].oh end
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = BCS:GetItemInfoForSlot("SecondaryHandSlot")
	BCScache["skills"].oh = BCS:GetWeaponSkillForWeaponType(itemType)
	return BCScache["skills"].oh
end

function BCS:GetRangedWeaponSkill()
	if not BCS.needScanSkills then return BCScache["skills"].ranged end
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = BCS:GetItemInfoForSlot("RangedSlot")
	BCScache["skills"].ranged = BCS:GetWeaponSkillForWeaponType(itemType)
	return BCScache["skills"].ranged
end
