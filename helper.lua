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

function BCS:GetPlayerAura(searchText, auraType)
	if not auraType then
		-- buffs
		-- http://blue.cardplace.com/cache/wow-dungeons/624230.htm
		-- 32 buffs max
		for i=0, 31 do
			local index = GetPlayerBuff(i, 'HELPFUL')
			if index > -1 then
				BCS_Tooltip:SetPlayerBuff(index)
				local MAX_LINES = BCS_Tooltip:NumLines()
					
				for line=1, MAX_LINES do
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
				local MAX_LINES = BCS_Tooltip:NumLines()
					
				for line=1, MAX_LINES do
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

local Cache_GetHitRating_Tab, Cache_GetHitRating_Talent
local hit_debuff = 0
function BCS:GetHitRating(hitOnly)
	local Hit_Set_Bonus = {}
	local hit = 0;
	local MAX_INVENTORY_SLOTS = 19;
	hit_debuff = 0;
	
	for slot=0, MAX_INVENTORY_SLOTS do
		local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
		if hasItem then
			local MAX_LINES = BCS_Tooltip:NumLines()
			local SET_NAME = nil
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to hit by (%d)%%."])
					if value then
						hit = hit + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["/Hit %+(%d+)"])
					if value then
						hit = hit + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
					if value then
						SET_NAME = value
					end
					_,_, value = strfind(left:GetText(), L["^Set: Improves your chance to hit by (%d)%%."])
					if value and SET_NAME and not tContains(Hit_Set_Bonus, SET_NAME) then
						tinsert(Hit_Set_Bonus, SET_NAME)
						hit = hit + tonumber(value)
						line = MAX_LINES
					end
				end
			end
			
		end
	end

	-- buffs
	local _, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit increased by (%d)%%."])
	if hitFromAura then
		hit = hit + tonumber(hitFromAura)
	end
	 _, _, hitFromAura = BCS:GetPlayerAura(L["Improves your chance to hit by (%d+)%%."])
	if hitFromAura then
		hit = hit + tonumber(hitFromAura)
	end
	 _, _, hitFromAura = BCS:GetPlayerAura(L["Increases attack power by %d+ and chance to hit by (%d+)%%."])
	if hitFromAura then
		hit = hit + tonumber(hitFromAura)
	end
	-- debuffs
	_, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit reduced by (%d+)%%."], 'HARMFUL')
	if hitFromAura then
		hit_debuff = hit_debuff + tonumber(hitFromAura)
	end
	_, _, hitFromAura = BCS:GetPlayerAura(L["Chance to hit decreased by (%d+)%% and %d+ Nature damage every %d+ sec."], 'HARMFUL')
	if hitFromAura then
		hit_debuff = hit_debuff + tonumber(hitFromAura)
	end
	hitFromAura = BCS:GetPlayerAura(L["Lowered chance to hit."], 'HARMFUL')
	if hitFromAura then
		hit_debuff = hit_debuff + 25
	end
	
	local MAX_TABS = GetNumTalentTabs()
	-- speedup
	if Cache_GetHitRating_Tab and Cache_GetHitRating_Talent then
		BCS_Tooltip:SetTalent(Cache_GetHitRating_Tab, Cache_GetHitRating_Talent)
		local MAX_LINES = BCS_Tooltip:NumLines()
		
		for line=1, MAX_LINES do
			local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
			if left:GetText() then
				-- rogues
				local _,_, value = strfind(left:GetText(), L["Increases your chance to hit with melee weapons by (%d)%%."])
				local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(Cache_GetHitRating_Tab, Cache_GetHitRating_Talent)
				if value and rank > 0 then
					hit = hit + tonumber(value)
					line = MAX_LINES
				end
				
				-- hunters
				_,_, value = strfind(left:GetText(), L["Increases hit chance by (%d)%% and increases the chance movement impairing effects will be resisted by an additional %d+%%."])
				name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(Cache_GetHitRating_Tab, Cache_GetHitRating_Talent)
				if value and rank > 0 then
					hit = hit + tonumber(value)
					line = MAX_LINES
				end
			end
		end
		
		if not hitOnly then
			hit = hit - hit_debuff
			if hit < 0 then hit = 0 end
			return hit
		else
			return hit
		end
	end
	
	for tab=1, MAX_TABS do
		local MAX_TALENTS = GetNumTalents(tab)
		
		for talent=1, MAX_TALENTS do
			BCS_Tooltip:SetTalent(tab, talent);
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					-- rogues
					local _,_, value = strfind(left:GetText(), L["Increases your chance to hit with melee weapons by (%d)%%."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit = hit + tonumber(value)
						
						Cache_GetHitRating_Tab = tab
						Cache_GetHitRating_Talent = talent
						
						line = MAX_LINES
						talent = MAX_TALENTS
						tab = MAX_TABS
					end
					
					-- hunters
					_,_, value = strfind(left:GetText(), L["Increases hit chance by (%d)%% and increases the chance movement impairing effects will be resisted by an additional %d+%%."])
					name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit = hit + tonumber(value)
						
						Cache_GetHitRating_Tab = tab
						Cache_GetHitRating_Talent = talent
						
						line = MAX_LINES
						talent = MAX_TALENTS
						tab = MAX_TABS
					end
					
					-- Druid
					-- Natural Weapons
					_,_, value = strfind(left:GetText(), "Also increases chance to hit with melee attacks and spells by (%d+)%%.")
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit = hit + tonumber(value)
						line = MAX_LINES
					end
					
					-- Paladin & Shaman
					-- Precision & Nature's Guidance
					_,_, value = strfind(left:GetText(), "Increases your chance to hit with melee attacks and spells by (%d+)%%.")
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit = hit + tonumber(value)
						line = MAX_LINES
					end
					
				end	
			end
			
		end
	end
	
	if not hitOnly then
		hit = hit - hit_debuff
		if hit < 0 then hit = 0 end -- Dust Cloud OP
		return hit
	else
		return hit
	end
end

function BCS:GetRangedHitRating()
	local melee_hit = BCS:GetHitRating(true)
	local ranged_hit = melee_hit
	local debuff = hit_debuff

	local hasItem = BCS_Tooltip:SetInventoryItem("player", 18) -- ranged enchant
	if hasItem then
		local MAX_LINES = BCS_Tooltip:NumLines()
		for line=1, MAX_LINES do
			local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
			if left:GetText() then
				local _,_, value = strfind(left:GetText(), L["+(%d)%% Hit"])
				if value then
					ranged_hit = ranged_hit + tonumber(value)
					line = MAX_LINES
				end
			end
		end
	end
	
	ranged_hit = ranged_hit - debuff
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
	
	-- scan gear
	local MAX_INVENTORY_SLOTS = 19
	for slot=0, MAX_INVENTORY_SLOTS do
		local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
		
		if hasItem then
			local SET_NAME
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to hit with spells by (%d)%%."])
					if value then
						hit = hit + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["/Spell Hit %+(%d+)"])
					if value then
						hit = hit + tonumber(value)
					end
					
					_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
					if value then
						SET_NAME = value
					end
					_, _, value = strfind(left:GetText(), L["^Set: Improves your chance to hit with spells by (%d)%%."])
					if value and SET_NAME and not tContains(hit_Set_Bonus, SET_NAME) then
						tinsert(hit_Set_Bonus, SET_NAME)
						hit = hit + tonumber(value)
					end
				end
			end
		
		end
	end
	
	-- scan talents
	local MAX_TABS = GetNumTalentTabs()
	
	for tab=1, MAX_TABS do
		local MAX_TALENTS = GetNumTalents(tab)
		
		for talent=1, MAX_TALENTS do
			BCS_Tooltip:SetTalent(tab, talent)
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					-- Mage
					-- Elemental Precision
					local _,_, value = strfind(left:GetText(), L["Reduces the chance that the opponent can resist your Frost and Fire spells by (%d)%%."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit_fire = hit_fire + tonumber(value)
						hit_frost = hit_frost + tonumber(value)
						line = MAX_LINES
					end
					
					-- Arcane Focus
					_,_, value = strfind(left:GetText(), L["Reduces the chance that the opponent can resist your Arcane spells by (%d+)%%."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit_arcane = hit_arcane + tonumber(value)
						line = MAX_LINES
					end
					
					-- Priest
					-- Shadow Focus
					_,_, value = strfind(left:GetText(), L["Reduces your target's chance to resist your Shadow spells by (%d+)%%."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit_shadow = hit_shadow + tonumber(value)
						line = MAX_LINES
					end
					
					-- Druid
					-- Natural Weapons
					_,_, value = strfind(left:GetText(), "Also increases chance to hit with melee attacks and spells by (%d+)%%.")
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit = hit + tonumber(value)
						line = MAX_LINES
					end
					
					-- Paladin & Shaman
					-- Precision & Nature's Guidance
					_,_, value = strfind(left:GetText(), "Increases your chance to hit with melee weapons and spells by (%d+)%%.")
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						hit = hit + tonumber(value)
						line = MAX_LINES
					end
				end	
			end
			
		end
	end
	
	-- buffs
	local _, _, hitFromAura = BCS:GetPlayerAura(L["Spell hit chance increased by (%d+)%%."])
	if hitFromAura then
		hit = hit + tonumber(hitFromAura)
	end
	
	return hit, hit_fire, hit_frost, hit_arcane, hit_shadow
end

local Cache_GetCritChance_SpellID, Cache_GetCritChance_BookType, Cache_GetCritChance_Line
local Cache_GetCritChance_Tab, Cache_GetCritChance_Talent
function BCS:GetCritChance()
	local crit = 0
	local _, class = UnitClass('player')
	
	if class == 'HUNTER' then
	
		local MAX_TABS = GetNumTalentTabs()
		-- speedup
		if Cache_GetCritChance_Tab and Cache_GetCritChance_Talent then
			BCS_Tooltip:SetTalent(Cache_GetCritChance_Tab, Cache_GetCritChance_Talent)
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["Increases your critical strike chance with all attacks by (%d)%%."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(Cache_GetCritChance_Tab, Cache_GetCritChance_Talent)
					if value and rank > 0 then
						crit = crit + tonumber(value)
						line = MAX_LINES
					end
				end
			end
		else
			for tab=1, MAX_TABS do
				local MAX_TALENTS = GetNumTalents(tab)
				for talent=1, MAX_TALENTS do
					BCS_Tooltip:SetTalent(tab, talent);
					local MAX_LINES = BCS_Tooltip:NumLines()
					
					for line=1, MAX_LINES do
						local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
						if left:GetText() then
							local _,_, value = strfind(left:GetText(), L["Increases your critical strike chance with all attacks by (%d)%%."])
							local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
							if value and rank > 0 then
								crit = crit + tonumber(value)
								
								Cache_GetCritChance_Tab = tab
								Cache_GetCritChance_Talent = talent
								
								line = MAX_LINES
								talent = MAX_TALENTS
								tab = MAX_TABS
							end
						end	
					end
					
				end
			end
		end
		
	end
	
	-- speedup
	if Cache_GetCritChance_SpellID and Cache_GetCritChance_BookType and Cache_GetCritChance_Line then
	
		BCS_Tooltip:SetSpell(Cache_GetCritChance_SpellID, Cache_GetCritChance_BookType)
		local left = getglobal(BCS_Prefix .. "TextLeft" .. Cache_GetCritChance_Line)
		if left:GetText() then
			local _,_, value = strfind(left:GetText(), L["([%d.]+)%% chance to crit"])
			if value then
				crit = crit + tonumber(value)
			end
		end
		
		return crit
	end
	
	local MAX_TABS = GetNumSpellTabs()
	
	for tab=1, MAX_TABS do
		local name, texture, offset, numSpells = GetSpellTabInfo(tab)
		
		for spell=1, numSpells do
			local currentPage = ceil(spell/SPELLS_PER_PAGE)
			local SpellID = spell + offset + ( SPELLS_PER_PAGE * (currentPage - 1))

			BCS_Tooltip:SetSpell(SpellID, BOOKTYPE_SPELL)
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["([%d.]+)%% chance to crit"])
					if value then
						crit = crit + tonumber(value)
						
						Cache_GetCritChance_SpellID = SpellID
						Cache_GetCritChance_BookType = BOOKTYPE_SPELL
						Cache_GetCritChance_Line = line
						
						line = MAX_LINES
						spell = numSpells
						tab = MAX_TABS
					end
				end
			end
			
		end
	end
	
	return crit
end

local Cache_GetRangedCritChance_Tab, Cache_GetRangedCritChance_Talent, Cache_GetRangedCritChance_Line
function BCS:GetRangedCritChance()
	local crit = BCS:GetCritChance()
	
	if Cache_GetRangedCritChance_Tab and Cache_GetRangedCritChance_Talent and Cache_GetRangedCritChance_Line then
		BCS_Tooltip:SetTalent(Cache_GetRangedCritChance_Tab, Cache_GetRangedCritChance_Talent)
		local left = getglobal(BCS_Prefix .. "TextLeft" .. Cache_GetRangedCritChance_Line)
		
		if left:GetText() then
			local _,_, value = strfind(left:GetText(), L["Increases your critical strike chance with ranged weapons by (%d)%%."])
			local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(Cache_GetRangedCritChance_Tab, Cache_GetRangedCritChance_Talent)
			if value and rank > 0 then
				crit = crit + tonumber(value)
			end
		end
	
		return crit
	end
	
	local MAX_TABS = GetNumTalentTabs()
	
	for tab=1, MAX_TABS do
		local MAX_TALENTS = GetNumTalents(tab)
		
		for talent=1, MAX_TALENTS do
			BCS_Tooltip:SetTalent(tab, talent);
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["Increases your critical strike chance with ranged weapons by (%d)%%."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						crit = crit + tonumber(value)
						
						line = MAX_LINES
						talent = MAX_TALENTS
						tab = MAX_TABS
					end
				end
			end
			
		end
	end
	
	return crit
end

function BCS:GetSpellCritChance()
	-- school crit: most likely never
	local Crit_Set_Bonus = {}
	local spellCrit = 0;
	local _, intelect = UnitStat("player", 4)
	local _, class = UnitClass("player")
	
	-- values from vmangos core 
	local playerLevel = UnitLevel("player")
	if class == "MAGE" then
		spellCrit = 3.7 + intelect / (14.77 + .65 * playerLevel)
	elseif class == "WARLOCK" then
		spellCrit = 3.18 + intelect / (11.30 + .82 * playerLevel)
	elseif class == "PRIEST" then
		spellCrit = 2.97 + intelect / (10.03 + .82 * playerLevel)
	elseif class == "DRUID" then
		spellCrit = 3.33 + intelect / (12.41 + .79 * playerLevel)
	elseif class == "SHAMAN" then
		spellCrit = 3.54 + intelect / (11.51 + .8 * playerLevel)
	elseif class == "PALADIN" then
		spellCrit = 3.7 + intelect / (14.77 + .65 * playerLevel)
	end
	--[[
	-- values from theorycraft / http://wow.allakhazam.com/forum.html?forum=21&mid=1157230638252681707
	if class == "MAGE" then
		spellCrit = 0.2 + (intelect / 59.5)
	elseif class == "WARLOCK" then
		spellCrit = 1.7 + (intelect / 60.6)
	elseif class == "PRIEST" then
		spellCrit = 0.8 + (intelect / 59.56)
	elseif class == "DRUID" then
		spellCrit = 1.8 + (intelect / 60)
	elseif class == "SHAMAN" then
		spellCrit = 1.8 + (intelect / 59.2)
	elseif class == "PALADIN" then
		spellCrit = intelect / 29.5
	end
	--]]
	local MAX_INVENTORY_SLOTS = 19
	
	for slot=0, MAX_INVENTORY_SLOTS do
		local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
		
		if hasItem then
			local SET_NAME = nil
			
			for line=1, BCS_Tooltip:NumLines() do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)

				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["Equip: Improves your chance to get a critical strike with spells by (%d)%%."])
					if value then
						spellCrit = spellCrit + tonumber(value)
					end
					
					_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
					if value then
						SET_NAME = value
					end

					_, _, value = strfind(left:GetText(), L["^Set: Improves your chance to get a critical strike with spells by (%d)%%."])
					if value and SET_NAME and not tContains(Crit_Set_Bonus, SET_NAME) then
						tinsert(Crit_Set_Bonus, SET_NAME)
						spellCrit = spellCrit + tonumber(value)
					end
					
					local _,_, value = strfind(left:GetText(), "(%d)%% Spell Critical Strike")
					if value then
						spellCrit = spellCrit + tonumber(value)
					end

				end
			end
		end
		
	end
	
	-- buffs
	local _, _, critFromAura = BCS:GetPlayerAura(L["Chance for a critical hit with a spell increased by (%d+)%%."])
	if critFromAura then
		spellCrit = spellCrit + tonumber(critFromAura)
	end
	_, _, critFromAura = BCS:GetPlayerAura("(Moonkin Aura)")
	if critFromAura then
		spellCrit = spellCrit + 3
	end
	_, _, critFromAura = BCS:GetPlayerAura("Power of the Guardian Crit")
	if critFromAura then
		spellCrit = spellCrit + tonumber(critFromAura)
	end
	_, _, critFromAura = BCS:GetPlayerAura("Chance to get a critical strike with spells is increased by (%d+)%%")
	if critFromAura then
		spellCrit = spellCrit + tonumber(critFromAura)
	end
	_, _, critFromAura = BCS:GetPlayerAura(L["While active, target's critical hit chance with spells and attacks increases by 10%%."])
	if critFromAura then
		spellCrit = spellCrit + 10
	end
	_, _, critFromAura = BCS:GetPlayerAura(L["Increases chance for a melee, ranged, or spell critical by (%d+)%% and all attributes by %d+."])
	if critFromAura then
		spellCrit = spellCrit + tonumber(critFromAura)
	end
	critFromAura = BCS:GetPlayerAura(L["Increases critical chance of spells by 10%%, melee and ranged by 5%% and grants 140 attack power. 120 minute duration."])
	if critFromAura then
		spellCrit = spellCrit + 10
	end
	_, _, critFromAura = BCS:GetPlayerAura(L["Critical strike chance with spells and melee attacks increased by (%d+)%%."])
	if critFromAura then
		spellCrit = spellCrit + tonumber(critFromAura)
	end
	-- debuffs
	_, _, _, critFromAura = BCS:GetPlayerAura(L["Melee critical-hit chance reduced by (%d+)%%.\r\nSpell critical-hit chance reduced by (%d+)%%."], 'HARMFUL')
	if critFromAura then
		spellCrit = spellCrit - tonumber(critFromAura)
	end

	return spellCrit
end

function BCS:GetSpellPower(school)
	if school then
		if not L["Equip: Increases damage done by "..school.." spells and effects by up to (%d+)."] then return -1 end
		local spellPower = 0;
		local MAX_INVENTORY_SLOTS = 19
		
		for slot=0, MAX_INVENTORY_SLOTS do
			local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
			
			if hasItem then
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
		
		return spellPower
	else
		local spellPower = 0;
		local arcanePower = 0;
		local firePower = 0;
		local frostPower = 0;
		local holyPower = 0;
		local naturePower = 0;
		local shadowPower = 0;
		local damagePower = 0;
		local MAX_INVENTORY_SLOTS = 19
		
		local SpellPower_Set_Bonus = {}
		
		-- scan gear
		for slot=0, MAX_INVENTORY_SLOTS do
			local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
			
			if hasItem then
				local SET_NAME
				
				for line=1, BCS_Tooltip:NumLines() do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					
					if left:GetText() then
						local _,_, value = strfind(left:GetText(), L["Equip: Increases damage and healing done by magical spells and effects by up to (%d+)."])
						if value then
							spellPower = spellPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), "Equip: Increases your spell damage by up to (%d+)")
						if value then
							spellPower = spellPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["Spell Damage %+(%d+)"])
						if value then
							spellPower = spellPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Spell Damage and Healing"])
						if value then
							spellPower = spellPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Damage and Healing Spells"])
						if value then
							spellPower = spellPower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Arcane spells and effects by up to (%d+)."])
						if value then
							arcanePower = arcanePower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Arcane Spell Damage"])
						if value then
							arcanePower = arcanePower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Fire spells and effects by up to (%d+)."])
						if value then
							firePower = firePower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["Fire Damage %+(%d+)"])
						if value then
							firePower = firePower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Fire Spell Damage"])
						if value then
							firePower = firePower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Frost spells and effects by up to (%d+)."])
						if value then
							frostPower = frostPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["Frost Damage %+(%d+)"])
						if value then
							frostPower = frostPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Frost Spell Damage"])
						if value then
							frostPower = frostPower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Holy spells and effects by up to (%d+)."])
						if value then
							holyPower = holyPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Holy Spell Damage"])
						if value then
							holyPower = holyPower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Nature spells and effects by up to (%d+)."])
						if value then
							naturePower = naturePower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Nature Spell Damage"])
						if value then
							naturePower = naturePower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), L["Equip: Increases damage done by Shadow spells and effects by up to (%d+)."])
						if value then
							shadowPower = shadowPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["Shadow Damage %+(%d+)"])
						if value then
							shadowPower = shadowPower + tonumber(value)
						end
						_,_, value = strfind(left:GetText(), L["^%+(%d+) Shadow Spell Damage"])
						if value then
							shadowPower = shadowPower + tonumber(value)
						end
						
						_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
						if value then
							SET_NAME = value
						end

						_, _, value = strfind(left:GetText(), L["^Set: Increases damage and healing done by magical spells and effects by up to (%d+)%."])
						if value and SET_NAME and not tContains(SpellPower_Set_Bonus, SET_NAME) then
							tinsert(SpellPower_Set_Bonus, SET_NAME)
							spellPower = spellPower + tonumber(value)
						end
						
					end
				end
			end
			
		end
		
		-- scan talents
		local MAX_TABS = GetNumTalentTabs()
		
		for tab=1, MAX_TABS do
			local MAX_TALENTS = GetNumTalents(tab)
			
			for talent=1, MAX_TALENTS do
				BCS_Tooltip:SetTalent(tab, talent)
				local MAX_LINES = BCS_Tooltip:NumLines()
				
				for line=1, MAX_LINES do
					local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
					if left:GetText() then
						-- Priest
						-- Spiritual Guidance
						local _,_, value = strfind(left:GetText(), L["Increases spell damage and healing by up to (%d+)%% of your total Spirit."])
						local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
						if value and rank > 0 then
							local stat, effectiveStat = UnitStat("player", 5)
							spellPower = spellPower + floor(((tonumber(value) / 100) * effectiveStat))
							
							-- nothing more is currenlty supported, break out of the loops
							line = MAX_LINES
							talent = MAX_TALENTS
							tab = MAX_TABS
						end
					end	
				end
				
			end
		end
		
		-- buffs
		local _, _, spellPowerFromAura = BCS:GetPlayerAura(L["Magical damage dealt is increased by up to (%d+)."])
		if spellPowerFromAura then
			spellPower = spellPower + tonumber(spellPowerFromAura)
			damagePower = damagePower + tonumber(spellPowerFromAura)
		end
		
		_, _, spellPowerFromAura = BCS:GetPlayerAura("Increases damage and healing done by magical spells and effects by up to (%d+).")
		if spellPowerFromAura then
			spellPower = spellPower + tonumber(spellPowerFromAura)
			damagePower = damagePower + tonumber(spellPowerFromAura)
		end
		
		_, _, spellPowerFromAura = BCS:GetPlayerAura("Magical damage dealt by spells and abilities is increased by up to (%d+)")
		if spellPowerFromAura then
			spellPower = spellPower + tonumber(spellPowerFromAura)
			damagePower = damagePower + tonumber(spellPowerFromAura)
		end
		
		_, _, spellPowerFromAura = BCS:GetPlayerAura("Spell damage is increased by up to (%d+)")
		if spellPowerFromAura then
			spellPower = spellPower + tonumber(spellPowerFromAura)
			damagePower = damagePower + tonumber(spellPowerFromAura)
		end

		_, _, spellPowerFromAura = BCS:GetPlayerAura("Spell Damage increased by (%d+)")
		if spellPowerFromAura then
			spellPower = spellPower + tonumber(spellPowerFromAura)
			damagePower = damagePower + tonumber(spellPowerFromAura)
		end
		
		local secondaryPower = 0
		local secondaryPowerName = ""
		
		if arcanePower > secondaryPower then
			secondaryPower = arcanePower
			secondaryPowerName = L.SPELL_SCHOOL_ARCANE
		end
		if firePower > secondaryPower then
			secondaryPower = firePower
			secondaryPowerName = L.SPELL_SCHOOL_FIRE
		end
		if frostPower > secondaryPower then
			secondaryPower = frostPower
			secondaryPowerName = L.SPELL_SCHOOL_FROST
		end
		if holyPower > secondaryPower then
			secondaryPower = holyPower
			secondaryPowerName = L.SPELL_SCHOOL_HOLY
		end
		if naturePower > secondaryPower then
			secondaryPower = naturePower
			secondaryPowerName = L.SPELL_SCHOOL_NATURE
		end
		if shadowPower > secondaryPower then
			secondaryPower = shadowPower
			secondaryPowerName = L.SPELL_SCHOOL_SHADOW
		end
		
		return spellPower, secondaryPower, secondaryPowerName, damagePower
	end
end

function BCS:GetHealingPower()
	local healPower = 0;
	local healPower_Set_Bonus = {}
	local MAX_INVENTORY_SLOTS = 19
	
	for slot=0, MAX_INVENTORY_SLOTS do
		local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
		
		if hasItem then
			local SET_NAME
			
			for line=1, BCS_Tooltip:NumLines() do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["Equip: Increases healing done by spells and effects by up to (%d+)."])
					if value then
						healPower = healPower + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), "Equip: Increases your spell damage by up to 120 and your healing by up to (300).")
					if value then
						healPower = healPower + tonumber(value) - 120
					end
					_,_, value = strfind(left:GetText(), L["Healing Spells %+(%d+)"])
					if value then
						healPower = healPower + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["^Healing %+(%d+) and %d+ mana per 5 sec."])
					if value then
						healPower = healPower + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["^%+(%d+) Healing Spells"])
					if value then
						healPower = healPower + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), "^Brilliant Mana Oil %((%d+) min%)")
					if value then
						healPower = healPower + 25
					end
					
					_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
					if value then
						SET_NAME = value
					end
					_, _, value = strfind(left:GetText(), L["^Set: Increases healing done by spells and effects by up to (%d+)%."])
					if value and SET_NAME and not tContains(healPower_Set_Bonus, SET_NAME) then
						tinsert(healPower_Set_Bonus, SET_NAME)
						healPower = healPower + tonumber(value)
					end
				end
			end
		end
		
	end
	
	-- buffs
	local _, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing done by magical spells is increased by up to (%d+)."])
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
    --Sweet Surprise
    _, _, healPowerFromAura = BCS:GetPlayerAura(L["Increases healing done by magical spells by up to (%d+) for 3600 sec."])
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
    --Unstable Power
    _, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing increased by up to (%d+)."])
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
    --The Eye of the Dead
    _, _, healPowerFromAura = BCS:GetPlayerAura(L["Healing spells increased by up to (%d+)."])
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
	--Power of the Guardian
    _, _, healPowerFromAura = BCS:GetPlayerAura("Increases healing done by magical spells and effects by up to (%d+).")
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
	_, _, healPowerFromAura = BCS:GetPlayerAura("Increases damage and healing done by magical spells and effects by up to (%d+).")
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
	--Dreamshard Elixir
    _, _, healPowerFromAura = BCS:GetPlayerAura("Healing done is increased by up to (%d+)")
	if healPowerFromAura then
		healPower = healPower + tonumber(healPowerFromAura)
	end
	
	return healPower
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
	else
		return addvalue
	end
	return addvalue
end

function BCS:GetManaRegen()
	local base = GetRegenMPPerSpirit()
	local casting = 0
	local mp5 = 0
	local mp5_Set_Bonus = {}
	local MAX_INVENTORY_SLOTS = 19
	
	for slot=0, MAX_INVENTORY_SLOTS do
		local hasItem = BCS_Tooltip:SetInventoryItem("player", slot)
		
		if hasItem then
			local SET_NAME

			for line=1, BCS_Tooltip:NumLines() do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				
				if left:GetText() then
					local _,_, value = strfind(left:GetText(), L["^Mana Regen %+(%d+)"])
					if value then
						mp5 = mp5 + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["Equip: Restores (%d+) mana per 5 sec."])
					if value and not strfind(left:GetText(), "to all party members") then
						mp5 = mp5 + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["^Healing %+%d+ and (%d+) mana per 5 sec."])
					if value then
						mp5 = mp5 + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), L["^%+(%d+) mana every 5 sec."])
					if value then
						mp5 = mp5 + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), "^Brilliant Mana Oil %((%d+) min%)")
					if value then
						mp5 = mp5 + 12
					end
					_,_, value = strfind(left:GetText(), "^Lesser Mana Oil %((%d+) min%)")
					if value then
						mp5 = mp5 + 8
					end
					_,_, value = strfind(left:GetText(), "^Minor Mana Oil %((%d+) min%)")
					if value then
						mp5 = mp5 + 4
					end
					_,_, value = strfind(left:GetText(), "^Equip: Allows (%d+)%% of your Mana regeneration to continue while casting.")
					if value then
						casting = casting + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), "(.+) %(%d/%d%)")
					if value then
						SET_NAME = value
					end
					_,_, value = strfind(left:GetText(), L["^Set: Allows (%d+)%% of your Mana regeneration to continue while casting."])
					if value and SET_NAME and not tContains(mp5_Set_Bonus, SET_NAME) then
						tinsert(mp5_Set_Bonus, SET_NAME)
						casting = casting + tonumber(value)
					end
					_,_, value = strfind(left:GetText(), "^Set: Restores (%d+) mana per 5 sec.")
					if value and SET_NAME and not tContains(mp5_Set_Bonus, SET_NAME) then
						tinsert(mp5_Set_Bonus, SET_NAME)
						mp5 = mp5 + tonumber(value)
					end
				end
			end
		end
	end
	
	-- scan talents
	local MAX_TABS = GetNumTalentTabs()
	
	for tab=1, MAX_TABS do
		local MAX_TALENTS = GetNumTalents(tab)
		
		for talent=1, MAX_TALENTS do
			BCS_Tooltip:SetTalent(tab, talent)
			local MAX_LINES = BCS_Tooltip:NumLines()
			
			for line=1, MAX_LINES do
				local left = getglobal(BCS_Prefix .. "TextLeft" .. line)
				if left:GetText() then
					-- Priest (Meditation) / Druid (Reflection)
					local _,_, value = strfind(left:GetText(), L["Allows (%d+)%% of your Mana regeneration to continue while casting."])
					local name, iconTexture, tier, column, rank, maxRank, isExceptional, meetsPrereq = GetTalentInfo(tab, talent)
					if value and rank > 0 then
						casting = casting + tonumber(value)
					end
				end	
			end
			
		end
	end
		
	-- buffs
	-- Warchief's Blessing
	local _, _, mp5FromAura = BCS:GetPlayerAura(L["Increases hitpoints by 300. 15%% haste to melee attacks. (%d+) mana regen every 5 seconds."])
	if mp5FromAura then
		mp5 = mp5 + 10
	end
	--Epiphany 
	 _, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana per 5 sec."])
	if mp5FromAura then
		mp5 = mp5 + tonumber(mp5FromAura)
	end
	--Nightfin Soup 
	 _, _, mp5FromAura = BCS:GetPlayerAura(L["Regenerating (%d+) Mana every 5 seconds."])
	if mp5FromAura then
		mp5 = mp5 + tonumber(mp5FromAura)*2.5 -- had to double the mp5FromAura because the item is a true mp5 tick
	end
	--Mageblood Potion 
	 _, _, mp5FromAura = BCS:GetPlayerAura(L["Regenerate (%d+) mana per 5 sec."])
	if mp5FromAura then
		mp5 = mp5 + tonumber(mp5FromAura)
	end
	--Fizzy Energy Drink and Sagefin
	 _, _, mp5FromAura = BCS:GetPlayerAura(L["Mana Regeneration increased by (%d+) every 5 seconds."])
	if mp5FromAura then
		mp5 = mp5 + tonumber(mp5FromAura)*2.5
	end
	--Second Wind
	 _, _, mp5FromAura = BCS:GetPlayerAura(L["Restores (%d+) mana every 1 sec."])
	if mp5FromAura then
		mp5 = mp5 + tonumber(mp5FromAura)*5 -- had to multiply by 5 the mp5FromAura because the item is a sec per tick
	end
	--Aura of the blue dragon
	 _, _, castingFromAura = BCS:GetPlayerAura(L["(%d+)%% of your Mana regeneration continuing while casting."])
	if mp5FromAura then
		casting = casting + tonumber(castingFromAura)
	end
	--Power of the Guardian
	 _, _, castingFromAura = BCS:GetPlayerAura("Restores (%d+) mana per 5 seconds.")
	if mp5FromAura then
		mp5 = mp5 + tonumber(mp5FromAura)
	end
	if casting > 100 then
		casting = 100
	end
	return base, casting, mp5
end
