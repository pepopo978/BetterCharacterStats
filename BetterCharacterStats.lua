BCS = BCS or {}
BCSConfig = BCSConfig or {}

local L, IndexLeft, IndexRight
L = BCS.L

BCS.PLAYERSTAT_DROPDOWN_OPTIONS = {
	"PLAYERSTAT_BASE_STATS",
	"PLAYERSTAT_MELEE_COMBAT",
	"PLAYERSTAT_MELEE_BOSS",
	"PLAYERSTAT_RANGED_COMBAT",
	"PLAYERSTAT_SPELL_COMBAT",
	"PLAYERSTAT_SPELL_SCHOOLS",
	"PLAYERSTAT_DEFENSES",
}

BCS.MELEEHIT = {
	["ROGUE"] = {
		5, -- pvp
		8, -- yellow cap
		24.6, -- white cap
	},
}

BCS.SPELLHIT = {
	-- soon(tm)
}

BCS.PaperDollFrame = PaperDollFrame

BCS.Debug = false
BCS.DebugStack = {}

function BCS:DebugTrace(start, limit)
	BCS.Debug = nil
	local length = getn(BCS.DebugStack)
	if not start then
		start = 1
	end
	if start > length then
		start = length
	end
	if not limit then
		limit = start + 30
	end

	BCS:Print("length: " .. length)
	BCS:Print("start: " .. start)
	BCS:Print("limit: " .. limit)

	for i = start, length, 1 do
		BCS:Print("[" .. i .. "] Event: " .. BCS.DebugStack[i].E)
		BCS:Print(format(
				"[%d] `- Arguments: %s, %s, %s, %s, %s",
				i,
				BCS.DebugStack[i].arg1,
				BCS.DebugStack[i].arg2,
				BCS.DebugStack[i].arg3,
				BCS.DebugStack[i].arg4,
				BCS.DebugStack[i].arg5
		))
		if i >= limit then
			i = length
		end
	end

end

function BCS:Print(message)
	ChatFrame2:AddMessage("[BCS] " .. message, 0.63, 0.86, 1.0)
end

function BCS:OnLoad()
	CharacterAttributesFrame:Hide()
	PaperDollFrame:UnregisterEvent('UNIT_DAMAGE')
	PaperDollFrame:UnregisterEvent('PLAYER_DAMAGE_DONE_MODS')
	PaperDollFrame:UnregisterEvent('UNIT_ATTACK_SPEED')
	PaperDollFrame:UnregisterEvent('UNIT_RANGEDDAMAGE')
	PaperDollFrame:UnregisterEvent('UNIT_ATTACK')
	PaperDollFrame:UnregisterEvent('UNIT_STATS')
	PaperDollFrame:UnregisterEvent('UNIT_ATTACK_POWER')
	PaperDollFrame:UnregisterEvent('UNIT_RANGED_ATTACK_POWER')

	self.Frame = BCSFrame
	self.needUpdate = nil

	self.Frame:RegisterEvent("ADDON_LOADED")
	self.Frame:RegisterEvent("UNIT_INVENTORY_CHANGED") -- fires when equipment changes
	self.Frame:RegisterEvent("CHARACTER_POINTS_CHANGED") -- fires when learning talent
	self.Frame:RegisterEvent("PLAYER_AURAS_CHANGED") -- buffs/warrior stances

	local _, classFileName = UnitClass("Player")
	self.playerClass = strupper(classFileName)
end

function BCS:OnEvent()
	--[[if BCS.Debug then
		local t = {
			E = event,
			arg1 = arg1 or "nil",
			arg2 = arg2 or "nil",
			arg3 = arg3 or "nil",
			arg4 = arg4 or "nil",
			arg5 = arg5 or "nil",
		}
		tinsert(BCS.DebugStack, t)
	end]]

	if
	event == "PLAYER_AURAS_CHANGED" or
			event == "CHARACTER_POINTS_CHANGED"
	then
		if BCS.PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
		if BCS.PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "ADDON_LOADED" and arg1 == "BetterCharacterStats" then
		IndexLeft = BCSConfig["DropdownLeft"] or BCS.PLAYERSTAT_DROPDOWN_OPTIONS[1]
		IndexRight = BCSConfig["DropdownRight"] or BCS.PLAYERSTAT_DROPDOWN_OPTIONS[2]

		UIDropDownMenu_SetSelectedValue(PlayerStatFrameLeftDropDown, IndexLeft)
		UIDropDownMenu_SetSelectedValue(PlayerStatFrameRightDropDown, IndexRight)
	end
end

function BCS:OnShow()
	if BCS.needUpdate then
		BCS.needUpdate = nil
		BCS:UpdateStats()
	end
end

-- debugging / profiling
--local avgV = {}
--local avg = 0
function BCS:UpdateStats()
	--[[if BCS.Debug then
		local e = event or "nil"
		BCS:Print("Update due to " .. e)
	end
	local beginTime = debugprofilestop()]]

	BCS:UpdatePaperdollStats("PlayerStatFrameLeft", IndexLeft)
	BCS:UpdatePaperdollStats("PlayerStatFrameRight", IndexRight)

	--[[local timeUsed = debugprofilestop()-beginTime
	table.insert(avgV, timeUsed)
	avg = 0

	for i,v in ipairs(avgV) do
		avg = avg + v
	end
	avg = avg / getn(avgV)

	BCS:Print(format("Average: %d (%d results), Exact: %d", avg, getn(avgV), timeUsed))]]
end

function BCS:SetStat(statFrame, statIndex)
	local label = getglobal(statFrame:GetName() .. "Label")
	local text = getglobal(statFrame:GetName() .. "StatText")
	local stat
	local effectiveStat
	local posBuff
	local negBuff
	local statIndexTable = {
		"STRENGTH",
		"AGILITY",
		"STAMINA",
		"INTELLECT",
		"SPIRIT",
	}

	statFrame:SetScript("OnEnter", function()
		PaperDollStatTooltip("player", statIndexTable[statIndex])
	end)

	statFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	label:SetText(TEXT(getglobal("SPELL_STAT" .. (statIndex - 1) .. "_NAME")) .. ":")
	stat, effectiveStat, posBuff, negBuff = UnitStat("player", statIndex)

	-- Set the tooltip text
	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. getglobal("SPELL_STAT" .. (statIndex - 1) .. "_NAME") .. " "

	if ((posBuff == 0) and (negBuff == 0)) then
		text:SetText(effectiveStat)
		statFrame.tooltip = tooltipText .. effectiveStat .. FONT_COLOR_CODE_CLOSE
	else
		tooltipText = tooltipText .. effectiveStat
		if (posBuff > 0 or negBuff < 0) then
			tooltipText = tooltipText .. " (" .. (stat - posBuff - negBuff) .. FONT_COLOR_CODE_CLOSE
		end
		if (posBuff > 0) then
			tooltipText = tooltipText .. FONT_COLOR_CODE_CLOSE .. GREEN_FONT_COLOR_CODE .. "+" .. posBuff .. FONT_COLOR_CODE_CLOSE
		end
		if (negBuff < 0) then
			tooltipText = tooltipText .. RED_FONT_COLOR_CODE .. " " .. negBuff .. FONT_COLOR_CODE_CLOSE
		end
		if (posBuff > 0 or negBuff < 0) then
			tooltipText = tooltipText .. HIGHLIGHT_FONT_COLOR_CODE .. ")" .. FONT_COLOR_CODE_CLOSE
		end
		statFrame.tooltip = tooltipText

		-- If there are any negative buffs then show the main number in red even if there are
		-- positive buffs. Otherwise show in green.
		if (negBuff < 0) then
			text:SetText(RED_FONT_COLOR_CODE .. effectiveStat .. FONT_COLOR_CODE_CLOSE)
		else
			text:SetText(GREEN_FONT_COLOR_CODE .. effectiveStat .. FONT_COLOR_CODE_CLOSE)
		end
	end
end

function BCS:SetArmor(statFrame)

	local base, effectiveArmor, armor, posBuff, negBuff = UnitArmor("player")
	local totalBufs = posBuff + negBuff
	local frame = statFrame
	local label = getglobal(frame:GetName() .. "Label")
	local text = getglobal(frame:GetName() .. "StatText")

	PaperDollFormatStat(ARMOR, base, posBuff, negBuff, frame, text)
	label:SetText(TEXT(ARMOR_COLON))

	local playerLevel = UnitLevel("player")
	local armorReduction = effectiveArmor / ((85 * playerLevel) + 400)
	armorReduction = 100 * (armorReduction / (armorReduction + 1))

	frame.tooltipSubtext = format(ARMOR_TOOLTIP, playerLevel, armorReduction)

	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip)
		GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function BCS:GetSlotItemId(slot)
	local _, _, id = string.find(GetInventoryItemLink("player", GetInventorySlotInfo(slot)) or "", "item:(%d+):%d+:%d+:%d+");
	if id then
		return tonumber(id)
	else
		return 0
	end
end

function BCS:GetGlovesItemId()
	return BCS:GetSlotItemId("HandsSlot")
end

function BCS:GetHeadItemId()
	return BCS:GetSlotItemId("HeadSlot")
end

function BCS:GetNeckItemId()
	return BCS:GetSlotItemId("NeckSlot")
end

function BCS:GetWaistItemId()
	return BCS:GetSlotItemId("WaistSlot")
end

function BCS:GetShoulderItemId()
	return BCS:GetSlotItemId("ShoulderSlot")
end

function BCS:GetChestItemId()
	return BCS:GetSlotItemId("ChestSlot")
end

function BCS:GetLegsItemId()
	return BCS:GetSlotItemId("LegsSlot")
end

function BCS:GetFeetItemId()
	return BCS:GetSlotItemId("FeetSlot")
end

function BCS:GetMainHandItemId()
	return BCS:GetSlotItemId("MainHandSlot")
end

function BCS:GetOffHandItemId()
	return BCS:GetSlotItemId("SecondaryHandSlot")
end

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
	elseif weaponType == "Fist Weapons" then
		return BCS:GetWeaponSkill("Unarmed")
	end

	return 0
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
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = BCS:GetItemInfoForSlot("MainHandSlot")

	return BCS:GetWeaponSkillForWeaponType(itemType)
end

function BCS:GetOHWeaponSkill()
	local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType,
	itemStackCount, itemEquipLoc, itemTexture, itemSellPrice = BCS:GetItemInfoForSlot("SecondaryHandSlot")

	return BCS:GetWeaponSkillForWeaponType(itemType)
end

function BCS:GetMissChance(wepSkill)
	local diff = 315 - wepSkill;

	if diff > 10 then
		return 5 + diff * 0.2;
	else
		return 5 + diff * 0.1;
	end
end

function BCS:GetDualWieldMissChance(wepSkill)
	local diff = 315 - wepSkill;
	local miss;

	if diff > 10 then
		miss = 5 + diff * 0.2;
	else
		miss = 5 + diff * 0.1;
	end

	miss = miss * 0.8 + 20;

	local hitChance = BCS:GetHitRating()

	if diff > 10 then
		miss = miss - (hitChance - 1);
	else
		miss = miss - (hitChance);
	end

	return miss
end

function BCS:GetGlanceChance(wepSkill)
	return 10 + 15 * 2;
end

function BCS:GetGlanceReduction(wepSkill)
	local diff = 315 - wepSkill;
    local low = math.max(math.min(1.3 - 0.05 * diff, 0.91), 0.01);
    local high = math.max(math.min(1.2 - 0.03 * diff, 0.99), 0.2);
    return 100 * ((high - low) / 2 + low);
end

function BCS:GetDodgeChance(wepSkill)
	return math.max(5 + (315 - wepSkill) * 0.1, 0);
end

function BCS:GetDualWieldCritCap(wepSkill)
	return 100 - self:GetDualWieldMissChance(wepSkill) - self:GetGlanceChance(wepSkill) - self:GetDodgeChance(wepSkill);
end

function BCS:GetCritCap(wepSkill)
	return 100 - self:GetMissChance(wepSkill) - self:GetGlanceChance(wepSkill) - self:GetDodgeChance(wepSkill);
end

function BCS:SetDamage(statFrame)
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(TEXT(DAMAGE_COLON))
	local damageText = getglobal(statFrame:GetName() .. "StatText")
	local damageFrame = statFrame

	damageFrame:SetScript("OnEnter", CharacterDamageFrame_OnEnter)
	damageFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	local speed, offhandSpeed = UnitAttackSpeed("player")

	local minDamage
	local maxDamage
	local minOffHandDamage
	local maxOffHandDamage
	local physicalBonusPos
	local physicalBonusNeg
	local percent
	minDamage, maxDamage, minOffHandDamage, maxOffHandDamage, physicalBonusPos, physicalBonusNeg, percent = UnitDamage("player")
	local displayMin = max(floor(minDamage), 1)
	local displayMax = max(ceil(maxDamage), 1)

	minDamage = (minDamage / percent) - physicalBonusPos - physicalBonusNeg
	maxDamage = (maxDamage / percent) - physicalBonusPos - physicalBonusNeg

	local baseDamage = (minDamage + maxDamage) * 0.5
	local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent
	local totalBonus = (fullDamage - baseDamage)
	local damagePerSecond = (max(fullDamage, 1) / speed)
	local damageTooltip = max(floor(minDamage), 1) .. " - " .. max(ceil(maxDamage), 1)

	local colorPos = "|cff20ff20"
	local colorNeg = "|cffff2020"
	if (totalBonus == 0) then
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(displayMin .. " - " .. displayMax)
		else
			damageText:SetText(displayMin .. "-" .. displayMax)
		end
	else

		local color
		if (totalBonus > 0) then
			color = colorPos
		else
			color = colorNeg
		end
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(color .. displayMin .. " - " .. displayMax .. "|r")
		else
			damageText:SetText(color .. displayMin .. "-" .. displayMax .. "|r")
		end
		if (physicalBonusPos > 0) then
			damageTooltip = damageTooltip .. colorPos .. " +" .. physicalBonusPos .. "|r"
		end
		if (physicalBonusNeg < 0) then
			damageTooltip = damageTooltip .. colorNeg .. " " .. physicalBonusNeg .. "|r"
		end
		if (percent > 1) then
			damageTooltip = damageTooltip .. colorPos .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		elseif (percent < 1) then
			damageTooltip = damageTooltip .. colorNeg .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		end

	end
	damageFrame.damage = damageTooltip
	damageFrame.attackSpeed = speed
	damageFrame.dps = damagePerSecond

	-- If there's an offhand speed then add the offhand info to the tooltip
	if (offhandSpeed) then
		minOffHandDamage = (minOffHandDamage / percent) - physicalBonusPos - physicalBonusNeg
		maxOffHandDamage = (maxOffHandDamage / percent) - physicalBonusPos - physicalBonusNeg

		local offhandBaseDamage = (minOffHandDamage + maxOffHandDamage) * 0.5
		local offhandFullDamage = (offhandBaseDamage + physicalBonusPos + physicalBonusNeg) * percent
		local offhandDamagePerSecond = (max(offhandFullDamage, 1) / offhandSpeed)
		local offhandDamageTooltip = max(floor(minOffHandDamage), 1) .. " - " .. max(ceil(maxOffHandDamage), 1)
		if (physicalBonusPos > 0) then
			offhandDamageTooltip = offhandDamageTooltip .. colorPos .. " +" .. physicalBonusPos .. "|r"
		end
		if (physicalBonusNeg < 0) then
			offhandDamageTooltip = offhandDamageTooltip .. colorNeg .. " " .. physicalBonusNeg .. "|r"
		end
		if (percent > 1) then
			offhandDamageTooltip = offhandDamageTooltip .. colorPos .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		elseif (percent < 1) then
			offhandDamageTooltip = offhandDamageTooltip .. colorNeg .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		end
		damageFrame.offhandDamage = offhandDamageTooltip
		damageFrame.offhandAttackSpeed = offhandSpeed
		damageFrame.offhandDps = offhandDamagePerSecond
	else
		damageFrame.offhandAttackSpeed = nil
	end

end

function BCS:SetAttackSpeed(statFrame)
	local speed, offhandSpeed = UnitAttackSpeed("player")
	speed = format("%.2f", speed)
	if (offhandSpeed) then
		offhandSpeed = format("%.2f", offhandSpeed)
	end
	local text
	if (offhandSpeed) then
		text = speed .. " / " .. offhandSpeed
	else
		text = speed
	end

	local label = getglobal(statFrame:GetName() .. "Label")
	local value = getglobal(statFrame:GetName() .. "StatText")

	label:SetText(TEXT(SPEED) .. ":")
	value:SetText(text)

	--[[statFrame.tooltip = HIGHLIGHT_FONT_COLOR_CODE..format(PAPERDOLLFRAME_TOOLTIP_FORMAT, ATTACK_SPEED).." "..text..FONT_COLOR_CODE_CLOSE;
	statFrame.tooltip2 = format(CR_HASTE_RATING_TOOLTIP, GetCombatRating(CR_HASTE_MELEE), GetCombatRatingBonus(CR_HASTE_MELEE));]]

	statFrame:Show()
end

function BCS:SetAttackPower(statFrame)
	local base, posBuff, negBuff = UnitAttackPower("player")

	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(TEXT(ATTACK_POWER_COLON))

	PaperDollFormatStat(MELEE_ATTACK_POWER, base, posBuff, negBuff, frame, text)
	frame.tooltipSubtext = format(MELEE_ATTACK_POWER_TOOLTIP, max((base + posBuff + negBuff), 0) / ATTACK_POWER_MAGIC_NUMBER)
end

function BCS:SetSpellPower(statFrame, school)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	local colorPos = "|cff20ff20"
	local colorNeg = "|cffff2020"

	if school then
		label:SetText(L["SPELL_SCHOOL_" .. strupper(school)])
		local base = BCS:GetSpellPower()
		local fromSchool = BCS:GetSpellPower(school)
		local output = base + fromSchool

		if fromSchool > 0 then
			output = colorPos .. output .. "|r"
		end

		text:SetText(output)
	else
		local power, secondaryPower, secondaryName = BCS:GetSpellPower()

		label:SetText(L.SPELL_POWER_COLON)
		text:SetText(power + secondaryPower)

		if secondaryPower > 0 then
			frame.tooltip = format(L.SPELL_POWER_SECONDARY_TOOLTIP, (power + secondaryPower), power, secondaryPower, secondaryName)

			frame:SetScript("OnEnter", function()
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(this.tooltip)
				GameTooltip:Show()
			end)
			frame:SetScript("OnLeave", function()
				GameTooltip:Hide()
			end)
		end

	end
end

function BCS:SetRating(statFrame, ratingType)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.MELEE_HIT_RATING_COLON)

	local colorPos = "|cff20ff20"
	local colorNeg = "|cffff2020"

	if ratingType == "MELEE" then
		local rating = BCS:GetHitRating()
		if BCS.MELEEHIT[BCS.playerClass] then
			if rating < BCS.MELEEHIT[BCS.playerClass][1] then
				rating = colorNeg .. rating .. "%|r"
			elseif rating >= BCS.MELEEHIT[BCS.playerClass][2] then
				rating = colorPos .. rating .. "%|r"
			else
				rating = rating .. "%"
			end
		else
			rating = rating .. "%"
		end
		text:SetText(rating)

		frame.tooltip = L.MELEE_HIT_TOOLTIP
		if L[BCS.playerClass .. "_MELEE_HIT_TOOLTIP"] then
			frame.tooltipSubtext = L[BCS.playerClass .. "_MELEE_HIT_TOOLTIP"]
		end
	elseif ratingType == "RANGED" then
		local rating = BCS:GetRangedHitRating()
		if BCS.MELEEHIT[BCS.playerClass] then
			if rating < BCS.MELEEHIT[BCS.playerClass][1] then
				rating = colorNeg .. rating .. "%|r"
			elseif rating >= BCS.MELEEHIT[BCS.playerClass][2] then
				rating = colorPos .. rating .. "%|r"
			else
				rating = rating .. "%"
			end
		else
			rating = rating .. "%"
		end
		text:SetText(rating)

		frame.tooltip = L.MELEE_HIT_TOOLTIP
		if L[BCS.playerClass .. "_MELEE_HIT_TOOLTIP"] then
			frame.tooltipSubtext = L[BCS.playerClass .. "_MELEE_HIT_TOOLTIP"]
		end
	elseif ratingType == "SPELL" then
		local spell_hit, spell_hit_fire, spell_hit_frost, spell_hit_arcane, spell_hit_shadow = BCS:GetSpellHitRating()
		--[[if BCS.SPELLHIT[BCS.playerClass] then
			if spell_hit < BCS.SPELLHIT[BCS.playerClass][1] then
				spell_hit = colorNeg .. spell_hit .. "%|r"
			elseif spell_hit >= BCS.SPELLHIT[BCS.playerClass][2] then
				spell_hit = colorPos .. spell_hit .. "%|r"
			else
				spell_hit = spell_hit .. "%"
			end
		else
			spell_hit = spell_hit .. "%"
		end]]

		if spell_hit_fire > 0 or spell_hit_frost > 0 or spell_hit_arcane > 0 or spell_hit_shadow > 0 then
			-- got spell hit from talents
			local spell_hit_other, spell_hit_other_type

			spell_hit_other = 0
			spell_hit_other_type = ""

			if spell_hit_fire > spell_hit_other then
				spell_hit_other = spell_hit_fire
				spell_hit_other_type = L.SPELL_SCHOOL_FIRE
			end
			if spell_hit_frost > spell_hit_other then
				spell_hit_other = spell_hit_frost
				spell_hit_other_type = L.SPELL_SCHOOL_FROST
			end
			if spell_hit_arcane > spell_hit_other then
				spell_hit_other = spell_hit_arcane
				spell_hit_other_type = L.SPELL_SCHOOL_ARCANE
			end
			if spell_hit_shadow > spell_hit_other then
				spell_hit_other = spell_hit_shadow
				spell_hit_other_type = L.SPELL_SCHOOL_SHADOW
			end

			frame.tooltip = format(L.SPELL_HIT_SECONDARY_TOOLTIP, spell_hit + spell_hit_other, spell_hit, spell_hit_other, spell_hit_other_type)
			text:SetText(spell_hit + spell_hit_other .. "%")
		else
			frame.tooltip = L.SPELL_HIT_TOOLTIP
			text:SetText(spell_hit .. "%")
		end

		-- class specific tooltip
		if L[BCS.playerClass .. "_SPELL_HIT_TOOLTIP"] then
			frame.tooltipSubtext = L[BCS.playerClass .. "_SPELL_HIT_TOOLTIP"]
		end
	end

	if frame.tooltip then
		frame:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(this.tooltip)
			GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
			GameTooltip:Show()
		end)
		frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

end

function BCS:SetMeleeCritChance(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.MELEE_CRIT_COLON)
	text:SetText(format("%.2f%%", BCS:GetCritChance()))
end

function BCS:SetWeaponSkill(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.WEAPON_SKILL_COLON)

	if OffhandHasWeapon() == 1 then
		text:SetText(format("M %d | O %d", BCS:GetMHWeaponSkill(), BCS:GetOHWeaponSkill()))
	else
		text:SetText(format("%d", BCS:GetMHWeaponSkill()))
	end
end

function BCS:SetMissChance(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.MISS_CHANCE_COLON)

	if OffhandHasWeapon() == 1 then
		text:SetText(format("%.1f%% | %.1f%%",
				BCS:GetDualWieldMissChance(BCS:GetMHWeaponSkill()),
				BCS:GetDualWieldMissChance(BCS:GetOHWeaponSkill())))
	else
		text:SetText(format("%.1f%%", BCS:GetMissChance(BCS:GetMHWeaponSkill())))
	end
end

function BCS:SetGlanceReduction(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.GLANCE_REDUCTION_COLON)

	if OffhandHasWeapon() == 1 then
		text:SetText(format("%d%% | %d%%",
				BCS:GetGlanceReduction(BCS:GetMHWeaponSkill()),
				BCS:GetGlanceReduction(BCS:GetOHWeaponSkill())))
	else
		text:SetText(format("%d%%", BCS:GetGlanceReduction(BCS:GetMHWeaponSkill())))
	end
end

function BCS:SetDodgeChance(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.DODGE_CHANCE_COLON)
	if OffhandHasWeapon() == 1 then
		text:SetText(format("%.1f%% | %.1f%%",
				BCS:GetDodgeChance(BCS:GetMHWeaponSkill()),
				BCS:GetDodgeChance(BCS:GetOHWeaponSkill())))
	else
		text:SetText(format("%.1f%%", BCS:GetDodgeChance(BCS:GetMHWeaponSkill())))
	end
end

function BCS:SetCritCap(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.CRIT_CAP_COLON)

	if OffhandHasWeapon() == 1 then
		text:SetText(format("%.1f%% | %.1f%%",
				BCS:GetDualWieldCritCap(BCS:GetMHWeaponSkill()),
				BCS:GetDualWieldCritCap(BCS:GetOHWeaponSkill())))
	else
		text:SetText(format("%.1f%%", BCS:GetCritCap(BCS:GetMHWeaponSkill())))
	end
end

function BCS:SetBossCrit(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.BOSS_CRIT_COLON)

	local critChance = BCS:GetCritChance()
	if OffhandHasWeapon() == 1 then
		text:SetText(format("%.1f%% | %.1f%%",
				math.min(critChance, BCS:GetDualWieldCritCap(BCS:GetMHWeaponSkill())),
				math.min(critChance, BCS:GetDualWieldCritCap(BCS:GetOHWeaponSkill()))
		))
	else
		text:SetText(format("%.1f%%", math.min(critChance, BCS:GetCritCap(BCS:GetMHWeaponSkill()))))
	end
end

function BCS:SetSpellCritChance(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.SPELL_CRIT_COLON)
	text:SetText(format("%.2f%%", BCS:GetSpellCritChance()))
end

function BCS:SetRangedCritChance(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.RANGED_CRIT_COLON)
	text:SetText(format("%.1f%%", BCS:GetRangedCritChance()))
end

function BCS:SetHealing(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	local power, _, _, dmg = BCS:GetSpellPower()
	local heal = BCS:GetHealingPower()

	power = power - dmg

	label:SetText(L.HEAL_POWER_COLON)
	text:SetText(power + heal)

	frame.tooltip = format(L.SPELL_HEALING_POWER_TOOLTIP, (power + heal), power, heal)

	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function BCS:SetManaRegen(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	local base, casting, mp5 = BCS:GetManaRegen()
	local mp2 = mp5 * 0.4
	local totalRegen = base + mp2
	local totalRegenWhileCasting = (casting / 100) * base + mp2

	label:SetText(L.MANA_REGEN_COLON)
	text:SetText(format("%d |cffBF40BF(%d)|r", totalRegen, totalRegenWhileCasting))

	frame.tooltip = format(L.SPELL_MANA_REGEN_TOOLTIP, totalRegen, totalRegenWhileCasting, base, casting, mp5, mp2)

	frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip)
		GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function BCS:SetDodge(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.DODGE_COLON)
	text:SetText(format("%.2f%%", GetDodgeChance()))
end

function BCS:SetParry(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.PARRY_COLON)
	text:SetText(format("%.2f%%", GetParryChance()))
end

function BCS:SetBlock(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.BLOCK_COLON)
	text:SetText(format("%.2f%%", GetBlockChance()))
end

function BCS:SetDefense(statFrame)
	local base, modifier = UnitDefense("player")

	local frame = statFrame
	local label = getglobal(statFrame:GetName() .. "Label")
	local text = getglobal(statFrame:GetName() .. "StatText")

	label:SetText(TEXT(DEFENSE_COLON))

	local posBuff = 0
	local negBuff = 0
	if (modifier > 0) then
		posBuff = modifier
	elseif (modifier < 0) then
		negBuff = modifier
	end
	PaperDollFormatStat(DEFENSE_COLON, base, posBuff, negBuff, frame, text)
end

function BCS:SetRangedDamage(statFrame)
	local label = getglobal(statFrame:GetName() .. "Label")
	local damageText = getglobal(statFrame:GetName() .. "StatText")
	local damageFrame = statFrame

	label:SetText(TEXT(DAMAGE_COLON))

	damageFrame:SetScript("OnEnter", CharacterRangedDamageFrame_OnEnter)
	damageFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	-- If no ranged attack then set to n/a
	if (PaperDollFrame.noRanged) then
		damageText:SetText(NOT_APPLICABLE)
		damageFrame.damage = nil
		return
	end

	local rangedAttackSpeed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
	local displayMin = max(floor(minDamage), 1)
	local displayMax = max(ceil(maxDamage), 1)

	minDamage = (minDamage / percent) - physicalBonusPos - physicalBonusNeg
	maxDamage = (maxDamage / percent) - physicalBonusPos - physicalBonusNeg

	local baseDamage = (minDamage + maxDamage) * 0.5
	local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent
	local totalBonus = (fullDamage - baseDamage)
	local damagePerSecond = (max(fullDamage, 1) / rangedAttackSpeed)
	local tooltip = max(floor(minDamage), 1) .. " - " .. max(ceil(maxDamage), 1)

	if (totalBonus == 0) then
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(displayMin .. " - " .. displayMax)
		else
			damageText:SetText(displayMin .. "-" .. displayMax)
		end
	else
		local colorPos = "|cff20ff20"
		local colorNeg = "|cffff2020"
		local color
		if (totalBonus > 0) then
			color = colorPos
		else
			color = colorNeg
		end
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(color .. displayMin .. " - " .. displayMax .. "|r")
		else
			damageText:SetText(color .. displayMin .. "-" .. displayMax .. "|r")
		end
		if (physicalBonusPos > 0) then
			tooltip = tooltip .. colorPos .. " +" .. physicalBonusPos .. "|r"
		end
		if (physicalBonusNeg < 0) then
			tooltip = tooltip .. colorNeg .. " " .. physicalBonusNeg .. "|r"
		end
		if (percent > 1) then
			tooltip = tooltip .. colorPos .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		elseif (percent < 1) then
			tooltip = tooltip .. colorNeg .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		end
		damageFrame.tooltip = tooltip .. " " .. format(TEXT(DPS_TEMPLATE), damagePerSecond)
	end
	damageFrame.attackSpeed = rangedAttackSpeed
	damageFrame.damage = tooltip
	damageFrame.dps = damagePerSecond
end

function BCS:SetRangedAttackSpeed(startFrame)
	local label = getglobal(startFrame:GetName() .. "Label")
	local damageText = getglobal(startFrame:GetName() .. "StatText")
	local damageFrame = startFrame

	label:SetText(TEXT(SPEED) .. ":")

	-- If no ranged attack then set to n/a
	if (PaperDollFrame.noRanged) then
		damageText:SetText(NOT_APPLICABLE)
		damageFrame.damage = nil
		return
	end

	local rangedAttackSpeed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
	local displayMin = max(floor(minDamage), 1)
	local displayMax = max(ceil(maxDamage), 1)

	minDamage = (minDamage / percent) - physicalBonusPos - physicalBonusNeg
	maxDamage = (maxDamage / percent) - physicalBonusPos - physicalBonusNeg

	local baseDamage = (minDamage + maxDamage) * 0.5
	local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent
	local totalBonus = (fullDamage - baseDamage)
	local damagePerSecond = (max(fullDamage, 1) / rangedAttackSpeed)
	local tooltip = max(floor(minDamage), 1) .. " - " .. max(ceil(maxDamage), 1)

	if (totalBonus == 0) then
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(displayMin .. " - " .. displayMax)
		else
			damageText:SetText(displayMin .. "-" .. displayMax)
		end
	else
		local colorPos = "|cff20ff20"
		local colorNeg = "|cffff2020"
		local color
		if (totalBonus > 0) then
			color = colorPos
		else
			color = colorNeg
		end
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(color .. displayMin .. " - " .. displayMax .. "|r")
		else
			damageText:SetText(color .. displayMin .. "-" .. displayMax .. "|r")
		end
		if (physicalBonusPos > 0) then
			tooltip = tooltip .. colorPos .. " +" .. physicalBonusPos .. "|r"
		end
		if (physicalBonusNeg < 0) then
			tooltip = tooltip .. colorNeg .. " " .. physicalBonusNeg .. "|r"
		end
		if (percent > 1) then
			tooltip = tooltip .. colorPos .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		elseif (percent < 1) then
			tooltip = tooltip .. colorNeg .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		end
		damageFrame.tooltip = tooltip .. " " .. format(TEXT(DPS_TEMPLATE), damagePerSecond)
	end

	damageText:SetText(format("%.2f", rangedAttackSpeed))

	damageFrame.attackSpeed = rangedAttackSpeed
	damageFrame.damage = tooltip
	damageFrame.dps = damagePerSecond
end

function BCS:SetRangedAttackPower(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(TEXT(ATTACK_POWER_COLON))

	-- If no ranged attack then set to n/a
	if (PaperDollFrame.noRanged) then
		text:SetText(NOT_APPLICABLE)
		frame.tooltip = nil
		return
	end
	if (HasWandEquipped()) then
		text:SetText("--")
		frame.tooltip = nil
		return
	end

	local base, posBuff, negBuff = UnitRangedAttackPower("player")
	PaperDollFormatStat(RANGED_ATTACK_POWER, base, posBuff, negBuff, frame, text)
	frame.tooltipSubtext = format(RANGED_ATTACK_POWER_TOOLTIP, base / ATTACK_POWER_MAGIC_NUMBER)
end

function BCS:UpdatePaperdollStats(prefix, index)
	local stat1 = getglobal(prefix .. 1)
	local stat2 = getglobal(prefix .. 2)
	local stat3 = getglobal(prefix .. 3)
	local stat4 = getglobal(prefix .. 4)
	local stat5 = getglobal(prefix .. 5)
	local stat6 = getglobal(prefix .. 6)

	stat1:SetScript("OnEnter", nil)
	stat2:SetScript("OnEnter", nil)
	stat3:SetScript("OnEnter", nil)
	stat4:SetScript("OnEnter", nil)
	stat4:SetScript("OnEnter", nil)
	stat5:SetScript("OnEnter", nil)
	stat6:SetScript("OnEnter", nil)

	stat1.tooltip = nil
	stat2.tooltip = nil
	stat3.tooltip = nil
	stat4.tooltip = nil
	stat4.tooltip = nil
	stat5.tooltip = nil
	stat6.tooltip = nil

	stat4:Show()
	stat5:Show()
	stat6:Show()

	if (index == "PLAYERSTAT_BASE_STATS") then
		BCS:SetStat(stat1, 1)
		BCS:SetStat(stat2, 2)
		BCS:SetStat(stat3, 3)
		BCS:SetStat(stat4, 4)
		BCS:SetStat(stat5, 5)
		BCS:SetArmor(stat6)
	elseif (index == "PLAYERSTAT_MELEE_COMBAT") then
		BCS:SetDamage(stat1)
		BCS:SetAttackSpeed(stat2)
		BCS:SetAttackPower(stat3)
		BCS:SetRating(stat4, "MELEE")
		BCS:SetMeleeCritChance(stat5)
		stat6:Hide()
	elseif (index == "PLAYERSTAT_MELEE_BOSS") then
		BCS:SetWeaponSkill(stat1)
		BCS:SetMissChance(stat2)
		BCS:SetDodgeChance(stat3)
		BCS:SetGlanceReduction(stat4)
		BCS:SetCritCap(stat5)
		BCS:SetBossCrit(stat6)
	elseif (index == "PLAYERSTAT_RANGED_COMBAT") then
		BCS:SetRangedDamage(stat1)
		BCS:SetRangedAttackSpeed(stat2)
		BCS:SetRangedAttackPower(stat3)
		BCS:SetRating(stat4, "RANGED")
		BCS:SetRangedCritChance(stat5)
		stat6:Hide()
	elseif (index == "PLAYERSTAT_SPELL_COMBAT") then
		BCS:SetSpellPower(stat1)
		BCS:SetRating(stat2, "SPELL")
		BCS:SetSpellCritChance(stat3)
		BCS:SetHealing(stat4)
		BCS:SetManaRegen(stat5)
		stat6:Hide()
	elseif (index == "PLAYERSTAT_SPELL_SCHOOLS") then
		BCS:SetSpellPower(stat1, "Arcane")
		BCS:SetSpellPower(stat2, "Fire")
		BCS:SetSpellPower(stat3, "Frost")
		BCS:SetSpellPower(stat4, "Holy")
		BCS:SetSpellPower(stat5, "Nature")
		BCS:SetSpellPower(stat6, "Shadow")
	elseif (index == "PLAYERSTAT_DEFENSES") then
		BCS:SetArmor(stat1)
		BCS:SetDefense(stat2)
		BCS:SetDodge(stat3)
		BCS:SetParry(stat4)
		BCS:SetBlock(stat5)
		stat6:Hide()
	end
end

local function PlayerStatFrameLeftDropDown_OnClick()
	UIDropDownMenu_SetSelectedValue(getglobal(this.owner), this.value)
	IndexLeft = this.value
	BCSConfig["DropdownLeft"] = IndexLeft
	BCS:UpdatePaperdollStats("PlayerStatFrameLeft", this.value)
end

local function PlayerStatFrameRightDropDown_OnClick()
	UIDropDownMenu_SetSelectedValue(getglobal(this.owner), this.value)
	IndexRight = this.value
	BCSConfig["DropdownRight"] = IndexRight
	BCS:UpdatePaperdollStats("PlayerStatFrameRight", this.value)
end

local function PlayerStatFrameLeftDropDown_Initialize()
	local info = {}
	local checked = nil
	for i = 1, getn(BCS.PLAYERSTAT_DROPDOWN_OPTIONS) do
		info.text = BCS.L[BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]]
		info.func = PlayerStatFrameLeftDropDown_OnClick
		info.value = BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]
		info.checked = checked
		info.owner = UIDROPDOWNMENU_OPEN_MENU
		UIDropDownMenu_AddButton(info)
	end
end

local function PlayerStatFrameRightDropDown_Initialize()
	local info = {}
	local checked = nil
	for i = 1, getn(BCS.PLAYERSTAT_DROPDOWN_OPTIONS) do
		info.text = BCS.L[BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]]
		info.func = PlayerStatFrameRightDropDown_OnClick
		info.value = BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]
		info.checked = checked
		info.owner = UIDROPDOWNMENU_OPEN_MENU
		UIDropDownMenu_AddButton(info)
	end
end

function PlayerStatFrameLeftDropDown_OnLoad()
	RaiseFrameLevel(this)
	RaiseFrameLevel(getglobal(this:GetName() .. "Button"))
	UIDropDownMenu_Initialize(this, PlayerStatFrameLeftDropDown_Initialize)
	UIDropDownMenu_SetWidth(99, this)
	UIDropDownMenu_JustifyText("LEFT")
end

function PlayerStatFrameRightDropDown_OnLoad()
	RaiseFrameLevel(this)
	RaiseFrameLevel(getglobal(this:GetName() .. "Button"))
	UIDropDownMenu_Initialize(this, PlayerStatFrameRightDropDown_Initialize)
	UIDropDownMenu_SetWidth(99, this)
	UIDropDownMenu_JustifyText("LEFT")
end

--pfUI.api.strsplit
function hcstrsplit(delimiter, subject)
	if not subject then
		return nil
	end
	local delimiter, fields = delimiter or ":", {}
	local pattern = string.format("([^%s]+)", delimiter)
	string.gsub(subject, pattern, function(c)
		fields[table.getn(fields) + 1] = c
	end)
	return unpack(fields)
end

--Update announcing code taken from pfUI
local major, minor, fix = hcstrsplit(".", tostring(GetAddOnMetadata("BetterCharacterStats", "Version")))

local alreadyshown = false
local localversion = tonumber(major * 10000 + minor * 100 + fix)
local remoteversion = tonumber(bcsupdateavailable) or 0
local loginchannels = { "BATTLEGROUND", "RAID", "GUILD", "PARTY" }
local groupchannels = { "BATTLEGROUND", "RAID", "PARTY" }

bcsupdater = CreateFrame("Frame")
bcsupdater:RegisterEvent("CHAT_MSG_ADDON")
bcsupdater:RegisterEvent("PLAYER_ENTERING_WORLD")
bcsupdater:RegisterEvent("PARTY_MEMBERS_CHANGED")
bcsupdater:SetScript("OnEvent", function()
	if event == "CHAT_MSG_ADDON" and arg1 == "bcs" then
		local v, remoteversion = hcstrsplit(":", arg2)
		local remoteversion = tonumber(remoteversion)
		if v == "VERSION" and remoteversion then
			if remoteversion > localversion then
				bcsupdateavailable = remoteversion
				if not alreadyshown then
					DEFAULT_CHAT_FRAME:AddMessage("|cffffffffBetterCharacterStats|r New version available! https://github.com/Lexiebean/BetterCharacterStats")
					alreadyshown = true
				end
			end
		end
		--This is a little check that I can use to see if people are actually using the addon.
		if v == "PING?" then
			for _, chan in pairs(loginchannels) do
				SendAddonMessage("bcs", "PONG!:" .. GetAddOnMetadata("BetterCharacterStats", "Version"), chan)
			end
		end
		if v == "PONG!" then
			--print(arg1 .." "..arg2.." "..arg3.." "..arg4)
		end
	end

	if event == "PARTY_MEMBERS_CHANGED" then
		local groupsize = GetNumRaidMembers() > 0 and GetNumRaidMembers() or GetNumPartyMembers() > 0 and GetNumPartyMembers() or 0
		if (this.group or 0) < groupsize then
			for _, chan in pairs(groupchannels) do
				SendAddonMessage("bcs", "VERSION:" .. localversion, chan)
			end
		end
		this.group = groupsize
	end

	if event == "PLAYER_ENTERING_WORLD" then
		if not alreadyshown and localversion < remoteversion then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffffffBetterCharacterStats|r New version available! https://github.com/Lexiebean/BetterCharacterStats")
			bcsupdateavailable = localversion
			alreadyshown = true
		end

		for _, chan in pairs(loginchannels) do
			SendAddonMessage("bcs", "VERSION:" .. localversion, chan)
		end
	end
end)
