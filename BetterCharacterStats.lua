BCS = BCS or {}
BCSConfig = BCSConfig or {}

local L, IndexLeft, IndexRight
L = BCS.L
--aura bonuses from other players;
--[1] - Tree of Life; [2] - Brilliance
local aura = { .0, .0 }
BCS.PLAYERSTAT_DROPDOWN_OPTIONS = {
	"PLAYERSTAT_BASE_STATS",
	"PLAYERSTAT_MELEE_COMBAT",
	"PLAYERSTAT_MELEE_BOSS",
	"PLAYERSTAT_RANGED_COMBAT",
	"PLAYERSTAT_SPELL_COMBAT",
	"PLAYERSTAT_SPELL_SCHOOLS",
	"PLAYERSTAT_DEFENSES",
	"PLAYERSTAT_DEFENSES_BOSS",
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
	self.Frame:RegisterEvent("CHAT_MSG_SKILL") --gaining weapon skill
	self.Frame:RegisterEvent("CHAT_MSG_ADDON")
end
-- Scan stuff depending on event, but make sure to scan everything when addon is loaded
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
	if event == "CHAT_MSG_ADDON" and arg1 == "bcs" then
		BCS.needScanAuras = true
		local type, player, amount = hcstrsplit(",", arg2)
		if type and player and amount then
			if player ~= UnitName("player") then
				amount = tonumber(amount)
				if type == "TREE" then
					--BCS:Print("got tree response amount="..amount)
					if amount >= aura[1] then
						aura[1] = amount
						if BCS.PaperDollFrame:IsVisible() then
							BCS:UpdateStats()
						else
							BCS.needUpdate = true
						end
					end
				elseif type == "BRILLIANCE" then
					--BCS:Print("got mage response amount="..amount)
					if amount >= aura[2] then
						aura[2] = amount
						if BCS.PaperDollFrame:IsVisible() then
							BCS:UpdateStats()
						else
							BCS.needUpdate = true
						end
					end
				end
			end
		end
	elseif event == "PLAYER_AURAS_CHANGED" then
		BCS.needScanAuras = true
		if not BCS:GetPlayerAura("Tree of Life Aura") then
			aura[1] = 0
		end
		if not BCS:GetPlayerAura("Brilliance Aura") then
			aura[2] = 0
		end
		if BCS.PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "CHARACTER_POINTS_CHANGED" then
		BCS.needScanTalents = true
		if BCS.PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "CHAT_MSG_SKILL" then
		BCS.needScanSkills = true
		if BCS.PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
		BCS.needScanGear = true
		BCS.needScanSkills = true
		if BCS.PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "ADDON_LOADED" and arg1 == "BetterCharacterStats" then
		BCSFrame:UnregisterEvent("ADDON_LOADED")
		BCS.needScanGear = true
		BCS.needScanTalents = true
		BCS.needScanAuras = true
		BCS.needScanSkills = true

		IndexLeft = BCSConfig["DropdownLeft"] or BCS.PLAYERSTAT_DROPDOWN_OPTIONS[1]
		IndexRight = BCSConfig["DropdownRight"] or BCS.PLAYERSTAT_DROPDOWN_OPTIONS[2]

		UIDropDownMenu_SetSelectedValue(PlayerStatFrameLeftDropDown, IndexLeft)
		UIDropDownMenu_SetSelectedValue(PlayerStatFrameRightDropDown, IndexRight)
	end
end
--sending messages
local sender = CreateFrame("Frame", "BCSsender")
sender:RegisterEvent("PLAYER_AURAS_CHANGED")
sender:RegisterEvent("CHAT_MSG_ADDON")
sender:SetScript("OnEvent", function()
	if not (UnitInParty("player") or UnitInRaid("player")) then
		return
	end
	if event then
		local player = UnitName("player")
		if event == "PLAYER_AURAS_CHANGED" then
			if BCS:GetPlayerAura("Tree of Life Aura") then
				ChatThrottleLib:SendAddonMessage("BULK", "bcs", "TREE" .. "," .. player, "PARTY")
				--BCS:Print("sent tree request")
			end
			if BCS:GetPlayerAura("Brilliance Aura") then
				ChatThrottleLib:SendAddonMessage("BULK", "bcs", "BRILLIANCE" .. "," .. player, "PARTY")
				--BCS:Print("sent mage request")
			end
		end
		if event == "CHAT_MSG_ADDON" and arg1 == "bcs" then
			local type, name, amount = hcstrsplit(",", arg2)
			if name ~= player then
				local _, treebonus = BCS:GetHealingPower()
				local _, _, _, brilliance = BCS:GetManaRegen()
				if not amount and type == "TREE" and treebonus then
					ChatThrottleLib:SendAddonMessage("BULK", "bcs", "TREE" .. "," .. player .. "," .. treebonus, "PARTY")
					--BCS:Print("sent tree response, amount="..treebonus)
				end
				if not amount and type == "BRILLIANCE" and brilliance then
					ChatThrottleLib:SendAddonMessage("BULK", "bcs", "BRILLIANCE" .. "," .. player .. "," .. brilliance, "PARTY")
					--BCS:Print("sent mage response, amount="..brilliance)
				end
			end
		end
	end
end)

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
	BCS.needScanGear = false
	BCS.needScanTalents = false
	BCS.needScanAuras = false
	BCS.needScanSkills = false
	--[[local timeUsed = debugprofilestop()-beginTime
	table.insert(avgV, timeUsed)
	avg = 0

	for i,v in ipairs(avgV) do
		avg = avg + v
	end
	avg = avg / getn(avgV)

	BCS:Print(format("Average: %d (%d results), Exact: %d", avg, getn(avgV), timeUsed))]]
end

function BCS:AddTooltip(frame)
	if frame.tooltip then
		frame:SetScript("OnEnter", function()
			GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
			GameTooltip:SetText(this.tooltip)
			if this.tooltipSubtext then
				GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
			end
			GameTooltip:Show()
		end)
		frame:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
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

	BCS:AddTooltip(frame)
end

function BCS:GetMissChanceRaw(wepSkill)
	local diff = wepSkill - 315
	local miss = 5

	if diff < -10 then
		miss = miss - diff * 0.2;
	else
		miss = miss - diff * 0.1;
	end

	local hitChance = BCS:GetHitRating()
	-- if skill diff < -10 then subtract one from +hit, if there is any +hit
	if (diff < -10) and (hitChance > 0) then
		hitChance = hitChance - 1
	end
	miss = miss - hitChance

	return miss
end

function BCS:GetMissChance(wepSkill)
	return max(0, min(BCS:GetMissChanceRaw(wepSkill), 60))
end

function BCS:GetDualWieldMissChance(wepSkill)
	return max(0, min(BCS:GetMissChanceRaw(wepSkill) + 19, 60))
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
	local cap = 100 - self:GetDualWieldMissChance(wepSkill) - self:GetGlanceChance(wepSkill) - self:GetDodgeChance(wepSkill);
	if (cap > 100) then
		cap = 100;
	end
	if (cap < 0) then
		cap = 0;
	end
	return cap;
end

function BCS:GetCritCap(wepSkill)
	local cap = 100 - self:GetMissChance(wepSkill) - self:GetGlanceChance(wepSkill) - self:GetDodgeChance(wepSkill);
	if (cap > 100) then
		cap = 100;
	end
	if (cap < 0) then
		cap = 0;
	end
	return cap;
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

	local damageText = getglobal(statFrame:GetName() .. "StatText")
	local damageFrame = statFrame
	local speed, offhandSpeed = UnitAttackSpeed("player")
	speed = format("%.2f", speed)
	if (offhandSpeed) then
		offhandSpeed = format("%.2f", offhandSpeed)
	end
	local text
	if (offhandSpeed) then
		text = speed .. " | " .. offhandSpeed
	else
		text = speed
	end

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
	local label = getglobal(statFrame:GetName() .. "Label")
	local value = getglobal(statFrame:GetName() .. "StatText")
	label:SetText(TEXT(SPEED) .. ":")
	value:SetText(text)
	statFrame:SetScript("OnEnter", CharacterDamageFrame_OnEnter)
	statFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

function BCS:SetAttackPower(statFrame)
	local base, posBuff, negBuff = UnitAttackPower("player")
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. MELEE_ATTACK_POWER .. " "
	local effectiveStat = base + posBuff + negBuff
	if ((posBuff == 0) and (negBuff == 0)) then
		text:SetText(effectiveStat)
		statFrame.tooltip = tooltipText .. base .. FONT_COLOR_CODE_CLOSE
	else
		tooltipText = tooltipText .. effectiveStat
		if (posBuff > 0 or negBuff < 0) then
			tooltipText = tooltipText .. " (" .. (base - posBuff - negBuff) .. FONT_COLOR_CODE_CLOSE
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

		if (negBuff < 0) then
			text:SetText(RED_FONT_COLOR_CODE .. effectiveStat .. FONT_COLOR_CODE_CLOSE)
		else
			text:SetText(GREEN_FONT_COLOR_CODE .. effectiveStat .. FONT_COLOR_CODE_CLOSE)
		end
	end
	label:SetText(TEXT(ATTACK_POWER_COLON))
	PaperDollFormatStat(MELEE_ATTACK_POWER, base, posBuff, negBuff, frame, text)
	frame.tooltipSubtext = format(MELEE_ATTACK_POWER_TOOLTIP, max((base + posBuff + negBuff), 0) / ATTACK_POWER_MAGIC_NUMBER)
	BCS:AddTooltip(frame)
end

function BCS:SetSpellPower(statFrame, school)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	local colorPos = "|cff20ff20"
	--local colorNeg = "|cffff2020"

	if school then
		label:SetText(L["SPELL_SCHOOL_" .. strupper(school)])
		local base = BCS:GetSpellPower()
		local fromSchool = BCS:GetSpellPower(school)
		local output = base + fromSchool

		if fromSchool > 0 then
			output = colorPos .. output .. "|r"
		end

		text:SetText(output)

		frame.tooltip = format(L.SPELL_SCHOOL_TOOLTIP, school)
		frame.tooltipSubtext = format(L.SPELL_SCHOOL_TOOLTIP_SUB, strlower(school))
	else
		local power, secondaryPower, secondaryName = BCS:GetSpellPower()

		label:SetText(L.SPELL_POWER_COLON)
		if secondaryPower > 0 then
			text:SetText(colorPos .. power + secondaryPower)
		else
			text:SetText(power + secondaryPower)
		end

		if secondaryPower ~= 0 then
			frame.tooltip = format(L.SPELL_POWER_SECONDARY_TOOLTIP, (power + secondaryPower), power, secondaryPower, secondaryName)
			frame.tooltipSubtext = format(L.SPELL_POWER_SECONDARY_TOOLTIP_SUB)
		else
			frame.tooltip = format(L.SPELL_POWER_TOOLTIP, power)
			frame.tooltipSubtext = format(L.SPELL_POWER_TOOLTIP_SUB)
		end
	end
	BCS:AddTooltip(frame)
end

function BCS:SetRating(statFrame, ratingType)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.MELEE_HIT_RATING_COLON)

	if ratingType == "MELEE" then
		local rating = BCS:GetHitRating()
		rating = rating .. "%"
		text:SetText(rating)

		frame.tooltip = (L.MELEE_HIT_TOOLTIP)
		frame.tooltipSubtext = format(L.MELEE_HIT_TOOLTIP_SUB)

	elseif ratingType == "RANGED" then
		-- If no ranged attack then set to n/a
		if UnitHasRelicSlot("player") or not (GetInventoryItemLink("player", 18)) then
			text:SetText(NOT_APPLICABLE)
			return
		end
		local rating = BCS:GetRangedHitRating()
		rating = rating .. "%"
		text:SetText(rating)

		frame.tooltip = (L.RANGED_HIT_TOOLTIP)
		frame.tooltipSubtext = format(L.RANGED_HIT_TOOLTIP_SUB)

	elseif ratingType == "SPELL" then
		local spell_hit, spell_hit_fire, spell_hit_frost, spell_hit_arcane, spell_hit_shadow = BCS:GetSpellHitRating()

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
		frame.tooltipSubtext = format(L.SPELL_HIT_TOOLTIP_SUB)
	end

	BCS:AddTooltip(frame)
end

function BCS:SetMeleeCritChance(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.MELEE_CRIT_COLON)
	text:SetText(format("%.2f%%", BCS:GetCritChance()))

	statFrame.tooltip = (L.MELEE_CRIT_TOOLTIP)
	statFrame.tooltipSubtext = (L.MELEE_CRIT_TOOLTIP_SUB)

	BCS:AddTooltip(statFrame)
end

function BCS:SetWeaponSkill(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.WEAPON_SKILL_COLON)
	if OffhandHasWeapon() == 1 then
		text:SetText(format("%d | %d", BCS:GetMHWeaponSkill(), BCS:GetOHWeaponSkill()))
	else
		text:SetText(format("%d", BCS:GetMHWeaponSkill()))
	end
	statFrame.tooltip = format(L.MELEE_WEAPON_SKILL_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_WEAPON_SKILL_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetRangedWeaponSkill(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.WEAPON_SKILL_COLON)
	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not (GetInventoryItemLink("player", 18)) then
		text:SetText(NOT_APPLICABLE)
		return
	end
	text:SetText(format("%d", BCS:GetRangedWeaponSkill()))
	statFrame.tooltip = format(L.RANGED_WEAPON_SKILL_TOOLTIP)
	statFrame.tooltipSubtext = format(L.RANGED_WEAPON_SKILL_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetBossMissChance(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.MISS_CHANCE_COLON)

	local mh_miss = BCS:GetMissChance(BCS:GetMHWeaponSkill())

	if OffhandHasWeapon() == 1 then
		text:SetText(format("%.1f%% | %.1f%%",
				BCS:GetDualWieldMissChance(BCS:GetMHWeaponSkill()),
				BCS:GetDualWieldMissChance(BCS:GetOHWeaponSkill())))
	else
		text:SetText(format("%.1f%%", mh_miss))
	end

	statFrame.tooltip = format(L.MELEE_MISS_VS_BOSS_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_MISS_VS_BOSS_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetBossGlanceReduction(statFrame)
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

	statFrame.tooltip = format(L.MELEE_GLANCE_VS_BOSS_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_GLANCE_VS_BOSS_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetBossDodgeChance(statFrame)
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

	statFrame.tooltip = format(L.MELEE_DODGE_VS_BOSS_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_DODGE_VS_BOSS_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetBossCritCap(statFrame)
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

	statFrame.tooltip = format(L.MELEE_CRIT_CAP_VS_BOSS_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_CRIT_CAP_VS_BOSS_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetEffectiveBossCrit(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.BOSS_CRIT_COLON)

	local critChance = BCS:GetCritChance() - 3 -- 3 % crit reduction vs lvl 63
	if OffhandHasWeapon() == 1 then
		text:SetText(format("%.1f%% | %.1f%%",
				math.min(critChance, BCS:GetDualWieldCritCap(BCS:GetMHWeaponSkill())),
				math.min(critChance, BCS:GetDualWieldCritCap(BCS:GetOHWeaponSkill()))
		))
	else
		text:SetText(format("%.1f%%", math.min(critChance, BCS:GetCritCap(BCS:GetMHWeaponSkill()))))
	end

	statFrame.tooltip = format(L.MELEE_EFF_CRIT_VS_BOSS_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_EFF_CRIT_VS_BOSS_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetSpellCritChance(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	label:SetText(L.SPELL_CRIT_COLON)
	text:SetText(format("%.2f%%", BCS:GetSpellCritChance()))
	frame.tooltip = format(L.SPELL_CRIT_TOOLTIP)
	frame.tooltipSubtext = format(L.SPELL_CRIT_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
end

function BCS:SetRangedCritChance(statFrame)
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.RANGED_CRIT_COLON)
	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not (GetInventoryItemLink("player", 18)) then
		text:SetText(NOT_APPLICABLE)
		return
	end
	local crit = BCS:GetRangedCritChance()
	local skill = BCS:GetRangedWeaponSkill()
	local level = UnitLevel("player")
	-- apply skill difference modifier
	local skillDiff = skill - (level * 5)
	if (skill >= (level * 5)) then
		crit = crit + (skillDiff * 0.04)
	else
		crit = crit + (skillDiff * 0.2)
	end
	if crit < 0 then
		crit = 0
	end
	text:SetText(format("%.2f%%", crit))
	statFrame.tooltip = (L.RANGED_CRIT_TOOLTIP)
	statFrame.tooltipSubtext = (L.RANGED_CRIT_TOOLTIP_SUB)
	BCS:AddTooltip(statFrame)
end

function BCS:SetHealing(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")

	local power, _, _, dmg = BCS:GetSpellPower()
	local heal, treebonus = BCS:GetHealingPower()
	power = power - dmg
	local total = power + heal
	if treebonus and aura[1] <= treebonus then
		total = total + treebonus
	elseif (not treebonus and aura[1] > 0) or (treebonus and aura[1] > treebonus) then
		total = total + aura[1]
	end
	label:SetText(L.HEAL_POWER_COLON)
	text:SetText(format("%.f", total))
	if heal ~= 0 then
		frame.tooltip = format(L.SPELL_HEALING_POWER_SECONDARY_TOOLTIP, (total), power, heal)
	else
		frame.tooltip = format(L.SPELL_HEALING_POWER_TOOLTIP, (total))
	end
	frame.tooltipSubtext = format(L.SPELL_HEALING_POWER_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
end

function BCS:SetManaRegen(statFrame)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	label:SetText(L.MANA_REGEN_COLON)
	-- if not a mana user and not a druid set to N/A
	local _, class = UnitClass("player")
	if (UnitPowerType("player") ~= 0 and not (class == "DRUID")) then
		text:SetText(NOT_APPLICABLE)
		frame.tooltip = nil
	else
		local base, casting, mp5, brilliance = BCS:GetManaRegen()
		local mp2 = mp5 * 0.4
		local totalRegen = base + mp2
		if brilliance and aura[2] <= brilliance then
			totalRegen = totalRegen + brilliance
		elseif (not brilliance and aura[2] > 0) or (brilliance and aura[2] > brilliance) then
			totalRegen = totalRegen + aura[2]
		end
		local totalRegenWhileCasting = (casting / 100) * base + mp2

		text:SetText(format("%.0f (%.0f)", totalRegen, totalRegenWhileCasting))
		frame.tooltip = format(L.SPELL_MANA_REGEN_TOOLTIP, totalRegen, totalRegenWhileCasting)
		frame.tooltipSubtext = format(L.SPELL_MANA_REGEN_TOOLTIP_SUB, base, casting, mp5, mp2)
		BCS:AddTooltip(frame)
	end
end

function BCS:SetDodge(statFrame, leveldiff)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	local lvldiff = leveldiff
	local dodge = GetDodgeChance() - ((5* lvldiff) * 0.04)


	label:SetText(L.DODGE_COLON)
	text:SetText(format("%.2f%%", dodge))

	frame.tooltip = format(L.PLAYER_DODGE_TOOLTIP)
	frame.tooltipSubtext = format(L.PLAYER_DODGE_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
end

function BCS:SetParry(statFrame, leveldiff)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	local lvldiff = leveldiff
	local parry = GetParryChance() - ((5* lvldiff) * 0.04)


	label:SetText(L.PARRY_COLON)
	text:SetText(format("%.2f%%", parry))

	frame.tooltip = format(L.PLAYER_PARRY_TOOLTIP)
	frame.tooltipSubtext = format(L.PLAYER_PARRY_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
end

function BCS:SetBlock(statFrame, leveldiff)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	local lvldiff = leveldiff
	local block = GetBlockChance() - ((5* lvldiff) * 0.04)

	label:SetText(L.BLOCK_COLON)
	text:SetText(format("%.2f%%", block))

	frame.tooltip = format(L.PLAYER_BLOCK_TOOLTIP)
	frame.tooltipSubtext = format(L.PLAYER_BLOCK_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
end
function BCS:SetTotalAvoidance(statFrame, leveldiff)
	local frame = statFrame
	local text = getglobal(statFrame:GetName() .. "StatText")
	local label = getglobal(statFrame:GetName() .. "Label")
	local lvldiff = leveldiff
	-- apply skill modifier
	local base, mod = UnitDefense("player")
	local skillDiff = (base + mod) - ((base)+(lvldiff * 5))
	local missChance = 5 - (skillDiff * 0.04)


	local block = GetBlockChance() + (skillDiff * 0.04)
	local parry = GetParryChance() + (skillDiff * 0.04)
	local dodge = GetDodgeChance() + (skillDiff * 0.04)
	local total = missChance + (block + parry + dodge)
	
	if total > 999 then
		total = 999
	end
	if total < 0 then
		total = 0
	end
	
	label:SetText(L.TOTAL_COLON)
	text:SetText(format("%.2f%%", total))

	frame.tooltip = format(L.TOTAL_AVOIDANCE_TOOLTIP)
	frame.tooltipSubtext = format(L.TOTAL_AVOIDANCE_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
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
	frame.tooltip = format(L.DEFENSE_TOOLTIP)
	frame.tooltipSubtext = format(L.DEFENSE_TOOLTIP_SUB)
	BCS:AddTooltip(frame)
end

function BCS:SetRangedDamage(statFrame)
	local label = getglobal(statFrame:GetName() .. "Label")
	local damageText = getglobal(statFrame:GetName() .. "StatText")
	local damageFrame = statFrame
	label:SetText(TEXT(DAMAGE_COLON))
	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not (GetInventoryItemLink("player", 18)) then
		damageText:SetText(NOT_APPLICABLE)
		damageFrame.damage = nil
		return
	end
	damageFrame:SetScript("OnEnter", CharacterRangedDamageFrame_OnEnter)
	damageFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

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
	if UnitHasRelicSlot("player") or not (GetInventoryItemLink("player", 18)) then
		damageText:SetText(NOT_APPLICABLE)
		damageFrame.damage = nil
		return
	end
	damageFrame:SetScript("OnEnter", CharacterRangedDamageFrame_OnEnter)
	damageFrame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

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
	if UnitHasRelicSlot("player") or not (GetInventoryItemLink("player", 18)) then
		text:SetText(NOT_APPLICABLE)
		frame.tooltip = nil
		return
	end
	if (HasWandEquipped()) then
		text:SetText("--");
		frame.tooltip = nil;
		return ;
	end
	local base, posBuff, negBuff = UnitRangedAttackPower("player")
	PaperDollFormatStat(RANGED_ATTACK_POWER, base, posBuff, negBuff, frame, text)
	frame.tooltipSubtext = format(RANGED_ATTACK_POWER_TOOLTIP, base / ATTACK_POWER_MAGIC_NUMBER)

	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. RANGED_ATTACK_POWER .. " "
	local effectiveStat = base + posBuff + negBuff
	if ((posBuff == 0) and (negBuff == 0)) then
		text:SetText(effectiveStat)
		statFrame.tooltip = tooltipText .. base .. FONT_COLOR_CODE_CLOSE
	else
		tooltipText = tooltipText .. effectiveStat
		if (posBuff > 0 or negBuff < 0) then
			tooltipText = tooltipText .. " (" .. (base - posBuff - negBuff) .. FONT_COLOR_CODE_CLOSE
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

		if (negBuff < 0) then
			text:SetText(RED_FONT_COLOR_CODE .. effectiveStat .. FONT_COLOR_CODE_CLOSE)
		else
			text:SetText(GREEN_FONT_COLOR_CODE .. effectiveStat .. FONT_COLOR_CODE_CLOSE)
		end
	end
	label:SetText(TEXT(ATTACK_POWER_COLON))
	PaperDollFormatStat(RANGED_ATTACK_POWER, base, posBuff, negBuff, frame, text)
	frame.tooltipSubtext = format(RANGED_ATTACK_POWER_TOOLTIP, max((base + posBuff + negBuff), 0) / ATTACK_POWER_MAGIC_NUMBER)
	BCS:AddTooltip(frame)
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
		BCS:SetWeaponSkill(stat1)
		BCS:SetDamage(stat2)
		BCS:SetAttackSpeed(stat3)
		BCS:SetAttackPower(stat4)
		BCS:SetRating(stat5, "MELEE")
		BCS:SetMeleeCritChance(stat6)
	elseif (index == "PLAYERSTAT_MELEE_BOSS") then
		BCS:SetWeaponSkill(stat1)
		BCS:SetBossMissChance(stat2)
		BCS:SetBossDodgeChance(stat3)
		BCS:SetBossGlanceReduction(stat4)
		BCS:SetBossCritCap(stat5)
		BCS:SetEffectiveBossCrit(stat6)
	elseif (index == "PLAYERSTAT_RANGED_COMBAT") then
		BCS:SetRangedWeaponSkill(stat1)
		BCS:SetRangedDamage(stat2)
		BCS:SetRangedAttackSpeed(stat3)
		BCS:SetRangedAttackPower(stat4)
		BCS:SetRating(stat5, "RANGED")
		BCS:SetRangedCritChance(stat6)
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
		BCS:SetDodge(stat3, 0)
		BCS:SetParry(stat4, 0)
		BCS:SetBlock(stat5, 0)
		BCS:SetTotalAvoidance(stat6, 0)
	elseif (index == "PLAYERSTAT_DEFENSES_BOSS") then
		BCS:SetArmor(stat1)
		BCS:SetDefense(stat2)
		BCS:SetDodge(stat3, 3)
		BCS:SetParry(stat4, 3)
		BCS:SetBlock(stat5, 3)
		BCS:SetTotalAvoidance(stat6, 3)
	end
end

local function PlayerStatFrameLeftDropDown_OnClick()
	BCS.needScanGear = true
	BCS.needScanTalents = true
	BCS.needScanAuras = true
	BCS.needScanSkills = true
	UIDropDownMenu_SetSelectedValue(getglobal(this.owner), this.value)
	IndexLeft = this.value
	BCSConfig["DropdownLeft"] = IndexLeft
	BCS:UpdatePaperdollStats("PlayerStatFrameLeft", this.value)
	BCS.needScanGear = false
	BCS.needScanTalents = false
	BCS.needScanAuras = false
	BCS.needScanSkills = false
end

local function PlayerStatFrameRightDropDown_OnClick()
	BCS.needScanGear = true
	BCS.needScanTalents = true
	BCS.needScanAuras = true
	BCS.needScanSkills = true
	UIDropDownMenu_SetSelectedValue(getglobal(this.owner), this.value)
	IndexRight = this.value
	BCSConfig["DropdownRight"] = IndexRight
	BCS:UpdatePaperdollStats("PlayerStatFrameRight", this.value)
	BCS.needScanGear = false
	BCS.needScanTalents = false
	BCS.needScanAuras = false
	BCS.needScanSkills = false
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
--[[
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
end)]]
