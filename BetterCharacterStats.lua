local _G = _G or getfenv(0)

BCS = BCS or {}
BCSConfig = BCSConfig or {}

local L, IndexLeft, IndexRight
L = BCS.L

local AceEvent = AceLibrary:HasInstance("AceEvent-2.0") and AceLibrary("AceEvent-2.0")

-- Tree of Life aura bonus from other players, your own is calculated in GetHealingPower()
local aura = .0
local playerName = UnitName("player")
local _, playerClass = UnitClass("player")

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
	PaperDollFrame:UnregisterEvent("UNIT_DAMAGE")
	PaperDollFrame:UnregisterEvent("PLAYER_DAMAGE_DONE_MODS")
	PaperDollFrame:UnregisterEvent("UNIT_ATTACK_SPEED")
	PaperDollFrame:UnregisterEvent("UNIT_RANGEDDAMAGE")
	PaperDollFrame:UnregisterEvent("UNIT_ATTACK")
	PaperDollFrame:UnregisterEvent("UNIT_STATS")
	PaperDollFrame:UnregisterEvent("UNIT_ATTACK_POWER")
	PaperDollFrame:UnregisterEvent("UNIT_RANGED_ATTACK_POWER")
	BCSFrame:RegisterEvent("ADDON_LOADED")
	BCSFrame:RegisterEvent("UNIT_INVENTORY_CHANGED") -- fires when equipment changes
	BCSFrame:RegisterEvent("CHARACTER_POINTS_CHANGED") -- fires when learning talent
	BCSFrame:RegisterEvent("PLAYER_AURAS_CHANGED") -- buffs/warrior stances
	BCSFrame:RegisterEvent("CHAT_MSG_SKILL") -- gaining weapon skill
	BCSFrame:RegisterEvent("CHAT_MSG_ADDON") -- needed to recieve aura bonuses from other people
	BCS.needUpdate = false
    -- there is less space for player character model with this addon, shorten it slightly
    CharacterModelFrame:SetHeight(CharacterModelFrame:GetHeight() - 19)
end

-- Scan stuff depending on event, but make sure to scan everything when addon is loaded
function BCS:OnEvent()
	if BCS.Debug then
		local t = {
			E = event,
			arg1 = arg1 or "nil",
			arg2 = arg2 or "nil",
			arg3 = arg3 or "nil",
			arg4 = arg4 or "nil",
			arg5 = arg5 or "nil",
		}
		tinsert(BCS.DebugStack, t)
	end
	if event == "CHAT_MSG_ADDON" and arg1 == "bcs" then
        if (GetNumPartyMembers() + GetNumRaidMembers()) == 0 then
            return
        end
		local _, _, type, name, amount = strfind(arg2 or "", "(%u+),(%a+),?(%d*)")
        if name ~= playerName then
            amount = tonumber(amount)
            if amount then
                --BCS:Print("got tree response amount="..amount)
                if amount >= aura then
                    aura = amount
                    BCS.needScanAuras = true
                    if PaperDollFrame:IsVisible() then
                        BCS:UpdateStats()
                    else
                        BCS.needUpdate = true
                    end
                end
            elseif playerClass == "DRUID" then
                BCS.needScanAuras = true
                local _, treebonus = BCS:GetHealingPower()
                if treebonus then
                    SendAddonMessage("bcs", "TREE"..","..playerName..","..treebonus, "PARTY")
                    --BCS:Print("sent tree response, amount="..treebonus)
                end
            end
        end
	elseif event == "PLAYER_AURAS_CHANGED" then
		BCS.needScanAuras = true
        local hasTreeAura = BCS:GetPlayerAura(L["Tree of Life Aura"])
		if not hasTreeAura then
			aura = 0
        else
            SendAddonMessage("bcs", "TREE"..","..playerName, "PARTY")
            --BCS:Print("sent tree request")
		end
		if PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "CHARACTER_POINTS_CHANGED" then
		BCS.needScanTalents = true
		if PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "CHAT_MSG_SKILL" then
		BCS.needScanSkills = true
		if PaperDollFrame:IsVisible() then
			BCS:UpdateStats()
		else
			BCS.needUpdate = true
		end
	elseif event == "UNIT_INVENTORY_CHANGED" and arg1 == "player" then
		BCS.needScanGear = true
		BCS.needScanSkills = true
		if PaperDollFrame:IsVisible() then
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

function BCS:OnShow()
	if BCS.needUpdate then
		BCS.needUpdate = false
		BCS:UpdateStats()
	end
end

-- debugging / profiling
local avgV = {}
local avg = 0
function BCS:UpdateStats()
	local beginTime
	if BCS.Debug then
		local e = event or "nil"
		BCS:Print("Update due to " .. e)
		beginTime = debugprofilestop()
	end

	BCS:UpdatePaperdollStats("PlayerStatFrameLeft", IndexLeft)
	BCS:UpdatePaperdollStats("PlayerStatFrameRight", IndexRight)
	BCS.needScanGear = false
	BCS.needScanTalents = false
	BCS.needScanAuras = false
	BCS.needScanSkills = false

	if BCS.Debug then
		local timeUsed = debugprofilestop() - beginTime
		table.insert(avgV, timeUsed)
		avg = 0
		for i, v in ipairs(avgV) do
			avg = avg + v
		end
		avg = avg / getn(avgV)
		BCS:Print(format("Average: %d (%d results), Exact: %d", avg, getn(avgV), timeUsed))
	end
end

local function StatFrame_OnUpdate()
	local elapsed = arg1
	this.time = (this.time or 0.2) - elapsed
	if this.time <= 0 then
		this.time = 0.2
		local OnEnter = this:GetScript("OnEnter")
		if OnEnter then
			if GameTooltip:IsOwned(this) then
				OnEnter()
			end
		end
	end
end

local function AddTooltip(statFrame, tooltipExtra)
    if statFrame.tooltip then
        statFrame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.tooltip, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, false)
            GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)
            if tooltipExtra then
                GameTooltip:AddLine(tooltipExtra)
            end
            GameTooltip:Show()
        end)
        statFrame:SetScript("OnUpdate", StatFrame_OnUpdate)
    else
        statFrame:SetScript("OnUpdate", nil)
        statFrame:SetScript("OnEnter", nil)
    end
end

local function StatFrameMeleeDamage_OnEnter()
	-- Main hand weapon
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText(INVTYPE_WEAPONMAINHAND, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(ATTACK_SPEED_COLON, format("%.2f", this.attackSpeed), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(DAMAGE_COLON, this.damage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(DAMAGE_PER_SECOND, format("%.1f", this.dps), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	-- Check for offhand weapon
	if this.offhandAttackSpeed then
		GameTooltip:AddLine("\n")
		GameTooltip:AddLine(INVTYPE_WEAPONOFFHAND, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddDoubleLine(ATTACK_SPEED_COLON, format("%.2f", this.offhandAttackSpeed), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddDoubleLine(DAMAGE_COLON, this.offhandDamage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		GameTooltip:AddDoubleLine(DAMAGE_PER_SECOND, format("%.1f", this.offhandDps), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	if this.haste and this.haste > 0 then
		GameTooltip:AddLine("\n")
		GameTooltip:AddDoubleLine(L.HASTE_COLON, format("%d%%", this.haste), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		if this.armorPen and this.armorPen > 0 then
			GameTooltip:AddDoubleLine(L.ARMOR_PEN_COLON, format("%d", this.armorPen), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	elseif this.armorPen and this.armorPen > 0 then
		GameTooltip:AddLine("\n")
		GameTooltip:AddDoubleLine(L.ARMOR_PEN_COLON, format("%d", this.armorPen), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	GameTooltip:Show()
end

local function StatFrameRangedDamage_OnEnter()
	if not this.damage then
		return
	end
	GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
	GameTooltip:SetText(INVTYPE_RANGED, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(ATTACK_SPEED_COLON, format("%.2f", this.attackSpeed), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(DAMAGE_COLON, this.damage, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	GameTooltip:AddDoubleLine(DAMAGE_PER_SECOND, format("%.1f", this.dps), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	if this.haste and this.haste > 0 then
		GameTooltip:AddLine("\n")
		GameTooltip:AddDoubleLine(L.HASTE_COLON, format("%d%%", this.haste), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		if this.armorPen and this.armorPen > 0 then
			GameTooltip:AddDoubleLine(L.ARMOR_PEN_COLON, format("%d", this.armorPen), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
		end
	elseif this.armorPen and this.armorPen > 0 then
		GameTooltip:AddLine("\n")
		GameTooltip:AddDoubleLine(L.ARMOR_PEN_COLON, format("%d", this.armorPen), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b)
	end
	GameTooltip:Show()
end

local function AddDamageTooltip(damageText, statFrame, speed, offhandSpeed, ranged)
	local rangedAttackSpeed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent
	local minOffHandDamage, maxOffHandDamage

	if ranged then
		rangedAttackSpeed, minDamage, maxDamage, physicalBonusPos, physicalBonusNeg, percent = UnitRangedDamage("player")
		speed = rangedAttackSpeed
	else
		minDamage, maxDamage, minOffHandDamage, maxOffHandDamage, physicalBonusPos, physicalBonusNeg, percent = UnitDamage("player")
	end

	local displayMin = max(floor(minDamage), 1)
	local displayMax = max(ceil(maxDamage), 1)

	minDamage = (minDamage / percent) - physicalBonusPos - physicalBonusNeg
	maxDamage = (maxDamage / percent) - physicalBonusPos - physicalBonusNeg

	local baseDamage = (minDamage + maxDamage) * 0.5
	local fullDamage = (baseDamage + physicalBonusPos + physicalBonusNeg) * percent
	local totalBonus = (fullDamage - baseDamage)
	local damagePerSecond = (max(fullDamage, 1) / speed)
	local damageTooltip = max(floor(minDamage), 1) .. " - " .. max(ceil(maxDamage), 1)
	local green = "|cff20ff20"
	local red = "|cffff2020"

	if (totalBonus == 0) then
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(displayMin .. " - " .. displayMax)
		else
			damageText:SetText(displayMin .. "-" .. displayMax)
		end
	else
		local color
		if (totalBonus > 0) then
			color = green
		else
			color = red
		end
		if ((displayMin < 100) and (displayMax < 100)) then
			damageText:SetText(color .. displayMin .. " - " .. displayMax .. "|r")
		else
			damageText:SetText(color .. displayMin .. "-" .. displayMax .. "|r")
		end
		if (physicalBonusPos > 0) then
			damageTooltip = damageTooltip .. green .. " +" .. physicalBonusPos .. "|r"
		end
		if (physicalBonusNeg < 0) then
			damageTooltip = damageTooltip .. red .. " " .. physicalBonusNeg .. "|r"
		end
		if (percent > 1) then
			damageTooltip = damageTooltip .. green .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		elseif (percent < 1) then
			damageTooltip = damageTooltip .. red .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		end
	end
	statFrame.damage = damageTooltip
	statFrame.attackSpeed = speed
	statFrame.dps = damagePerSecond

	-- If there's an offhand speed then add the offhand info to the tooltip
	if (offhandSpeed) then
		minOffHandDamage = (minOffHandDamage / percent) - physicalBonusPos - physicalBonusNeg
		maxOffHandDamage = (maxOffHandDamage / percent) - physicalBonusPos - physicalBonusNeg

		local offhandBaseDamage = (minOffHandDamage + maxOffHandDamage) * 0.5
		local offhandFullDamage = (offhandBaseDamage + physicalBonusPos + physicalBonusNeg) * percent
		local offhandDamagePerSecond = (max(offhandFullDamage, 1) / offhandSpeed)
		local offhandDamageTooltip = max(floor(minOffHandDamage), 1) .. " - " .. max(ceil(maxOffHandDamage), 1)
		if (physicalBonusPos > 0) then
			offhandDamageTooltip = offhandDamageTooltip .. green .. " +" .. physicalBonusPos .. "|r"
		end
		if (physicalBonusNeg < 0) then
			offhandDamageTooltip = offhandDamageTooltip .. red .. " " .. physicalBonusNeg .. "|r"
		end
		if (percent > 1) then
			offhandDamageTooltip = offhandDamageTooltip .. green .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		elseif (percent < 1) then
			offhandDamageTooltip = offhandDamageTooltip .. red .. " x" .. floor(percent * 100 + 0.5) .. "%|r"
		end
		statFrame.offhandDamage = offhandDamageTooltip
		statFrame.offhandAttackSpeed = offhandSpeed
		statFrame.offhandDps = offhandDamagePerSecond
	else
		statFrame.offhandAttackSpeed = nil
	end

	statFrame.haste = BCS:GetHaste()
	statFrame.armorPen, statFrame.armorPenFromTalent = BCS:GetArmorPen()

	if ranged then
		statFrame.armorPen = statFrame.armorPen - statFrame.armorPenFromTalent
		statFrame:SetScript("OnEnter", StatFrameRangedDamage_OnEnter)
	else
		statFrame:SetScript("OnEnter", StatFrameMeleeDamage_OnEnter)
	end

	if statFrame.damage then
		statFrame:SetScript("OnUpdate", StatFrame_OnUpdate)
	else
		statFrame:SetScript("OnUpdate", nil)
	end
end

function BCS:SetStat(statFrame, statIndex)
	local label = _G[statFrame:GetName() .. "Label"]
	local text = _G[statFrame:GetName() .. "StatText"]
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


	label:SetText(_G["SPELL_STAT" .. (statIndex - 1) .. "_NAME"] .. ":")
	local stat, effectiveStat, posBuff, negBuff = UnitStat("player", statIndex)

	-- Set the tooltip text
	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. _G["SPELL_STAT" .. (statIndex - 1) .. "_NAME"] .. " "

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
	local label = _G[statFrame:GetName() .. "Label"]
	local text = _G[statFrame:GetName() .. "StatText"]

	PaperDollFormatStat(ARMOR, base, posBuff, negBuff, statFrame, text)
	label:SetText(ARMOR_COLON)

	local playerLevel = UnitLevel("player")
	local armorReduction = effectiveArmor / ((85 * playerLevel) + 400)
	armorReduction = 100 * (armorReduction / (armorReduction + 1))

	statFrame.tooltipSubtext = format(ARMOR_TOOLTIP, playerLevel, armorReduction)

	AddTooltip(statFrame)
end

function BCS:GetMissChanceRaw(wepSkill)
	local diff = wepSkill - 315
	local miss = 5

	if TURTLE_WOW_VERSION ~= nil then
		miss = miss - (diff * 0.2) - BCS:GetHitRating()
	else
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
	end
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
	if TURTLE_WOW_VERSION ~= nil then
		return 65 + (wepSkill - 300) * 2
	else
		local diff = 315 - wepSkill;
		local low = math.max(math.min(1.3 - 0.05 * diff, 0.91), 0.01);
		local high = math.max(math.min(1.2 - 0.03 * diff, 0.99), 0.2);
		return 100 * ((high - low) / 2 + low);
	end
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

function BCS:GetEffectiveBlockChance(leveldiff)
	local block = GetBlockChance() - ((5 * leveldiff) * 0.04)
	if block < 0 then
		block = 0
	end
	return block
end

function BCS:GetEffectiveParryChance(leveldiff)
	local parry = GetParryChance() - ((5 * leveldiff) * 0.04)
	if parry < 0 then
		parry = 0
	end
	return parry
end

function BCS:GetEffectiveDodgeChance(leveldiff)
	local dodge = GetDodgeChance() - ((5 * leveldiff) * 0.04)
	if dodge < 0 then
		dodge = 0
	end
	return dodge
end

function BCS:SetDamage(statFrame)
	local damageText = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
	local speed, offhandSpeed = UnitAttackSpeed("player")

	AddDamageTooltip(damageText, statFrame, speed, offhandSpeed)

	label:SetText(DAMAGE_COLON)
end

function BCS:SetAttackSpeed(statFrame)
	local damageText = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
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

	AddDamageTooltip(damageText, statFrame, speed, offhandSpeed)

	label:SetText(SPEED .. ":")
	damageText:SetText(text)
end

function BCS:SetAttackPower(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. MELEE_ATTACK_POWER .. " "
	local base, posBuff, negBuff = UnitAttackPower("player")
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

	label:SetText(ATTACK_POWER_COLON)
	PaperDollFormatStat(MELEE_ATTACK_POWER, base, posBuff, negBuff, statFrame, text)
	statFrame.tooltipSubtext = format(MELEE_ATTACK_POWER_TOOLTIP, max((base + posBuff + negBuff), 0) / ATTACK_POWER_MAGIC_NUMBER)

	AddTooltip(statFrame)
end

function BCS:SetSpellPower(statFrame, school)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
	local green = "|cff20ff20"

	if school then
		local base, _, _, dmgOnly = BCS:GetSpellPower()
		local fromSchool = BCS:GetSpellPower(school)
		local total = base + dmgOnly + fromSchool

		if fromSchool > 0 then
			text:SetText(green .. total .. "|r")
		else
			text:SetText(total)
		end

		label:SetText(L["SPELL_SCHOOL_" .. strupper(school)])

		if fromSchool > 0 then
			statFrame.tooltip = format(L.SPELL_SCHOOL_SECONDARY_TOOLTIP, school, total, base + dmgOnly, fromSchool)
		else
			statFrame.tooltip = format(L.SPELL_SCHOOL_TOOLTIP, school, total)
		end
		statFrame.tooltipSubtext = format(L.SPELL_SCHOOL_TOOLTIP_SUB, strlower(school))
	else
		local damageAndHealing, secondaryPower, secondaryName, damageOnly = BCS:GetSpellPower()
		local total = damageAndHealing + damageOnly

		label:SetText(L.SPELL_POWER_COLON)
		if secondaryPower > 0 then
			text:SetText(green .. total + secondaryPower)
		else
			text:SetText(total + secondaryPower)
		end

		if secondaryPower ~= 0 then
			statFrame.tooltip = format(L.SPELL_POWER_SECONDARY_TOOLTIP, (total + secondaryPower), total, secondaryPower, secondaryName)
			statFrame.tooltipSubtext = format(L.SPELL_POWER_SECONDARY_TOOLTIP_SUB)
		else
			statFrame.tooltip = format(L.SPELL_POWER_TOOLTIP, total)
			statFrame.tooltipSubtext = format(L.SPELL_POWER_TOOLTIP_SUB)
		end
	end

	AddTooltip(statFrame)
end

function BCS:SetHitRating(statFrame, ratingType)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
	label:SetText(L.MELEE_HIT_RATING_COLON)

	if ratingType == "MELEE" then
		local rating = BCS:GetHitRating()
		rating = rating .. "%"
		text:SetText(rating)

		statFrame.tooltip = (L.MELEE_HIT_TOOLTIP)
		statFrame.tooltipSubtext = format(L.MELEE_HIT_TOOLTIP_SUB)

	elseif ratingType == "RANGED" then
		-- If no ranged attack then set to n/a
		if UnitHasRelicSlot("player") or not GetInventoryItemLink("player", 18) then
			text:SetText(NOT_APPLICABLE)
			return
		end

		local rating = BCS:GetRangedHitRating()
		rating = rating .. "%"
		text:SetText(rating)

		statFrame.tooltip = (L.RANGED_HIT_TOOLTIP)
		statFrame.tooltipSubtext = format(L.RANGED_HIT_TOOLTIP_SUB)

	elseif ratingType == "SPELL" then
		local spell_hit, spell_hit_fire, spell_hit_frost, spell_hit_arcane, spell_hit_shadow, spell_hit_holy = BCS:GetSpellHitRating()
		local spellPen = BCS:GetSpellPen()

		text:SetText(spell_hit .. "%")

		statFrame.tooltip = format(L.SPELL_HIT_TOOLTIP)
		statFrame.tooltipSubtext = format(L.SPELL_HIT_TOOLTIP_SUB)

		if statFrame.tooltip then
			statFrame:SetScript("OnEnter", function()
				GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
				GameTooltip:SetText(this.tooltip)
				GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)

				if spell_hit_fire > 0 then
					GameTooltip:AddLine(format(L.HIT_FIRE, spell_hit + spell_hit_fire))
				end
				if spell_hit_frost > 0 then
					GameTooltip:AddLine(format(L.HIT_FROST, spell_hit + spell_hit_frost))
				end
				if spell_hit_arcane > 0 then
					GameTooltip:AddLine(format(L.HIT_ARCANE, spell_hit + spell_hit_arcane))
				end
				if spell_hit_shadow > 0 then
					if playerClass == "WARLOCK" then
						GameTooltip:AddLine(format(L.HIT_AFFLICTION, spell_hit + spell_hit_shadow))
					else
						GameTooltip:AddLine(format(L.HIT_SHADOW, spell_hit + spell_hit_shadow))
					end
				end
				if spell_hit_holy > 0 then
					GameTooltip:AddLine(format(L.HIT_HOLY_DISC, spell_hit + spell_hit_holy))
				end
				if spellPen > 0 then
					GameTooltip:AddLine(format(L.SPELL_PEN, spellPen))
				end
				GameTooltip:Show()
			end)
		end
	end

	if ratingType ~= "SPELL" then
		AddTooltip(statFrame)
	end
end

function BCS:SetMeleeCritChance(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.MELEE_CRIT_COLON)
	text:SetText(format("%.2f%%", BCS:GetCritChance()))

	statFrame.tooltip = (L.MELEE_CRIT_TOOLTIP)
	statFrame.tooltipSubtext = (L.MELEE_CRIT_TOOLTIP_SUB)

	AddTooltip(statFrame)
end

function BCS:SetWeaponSkill(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.WEAPON_SKILL_COLON)

	if OffhandHasWeapon() == 1 then
		text:SetText(format("%d | %d", BCS:GetMHWeaponSkill(), BCS:GetOHWeaponSkill()))
	else
		text:SetText(format("%d", BCS:GetMHWeaponSkill()))
	end

	statFrame.tooltip = format(L.MELEE_WEAPON_SKILL_TOOLTIP)
	statFrame.tooltipSubtext = format(L.MELEE_WEAPON_SKILL_TOOLTIP_SUB)

	AddTooltip(statFrame)
end

function BCS:SetRangedWeaponSkill(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.WEAPON_SKILL_COLON)

	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not GetInventoryItemLink("player", 18) then
		text:SetText(NOT_APPLICABLE)
		return
	end

	text:SetText(format("%d", BCS:GetRangedWeaponSkill()))

	statFrame.tooltip = format(L.RANGED_WEAPON_SKILL_TOOLTIP)
	statFrame.tooltipSubtext = format(L.RANGED_WEAPON_SKILL_TOOLTIP_SUB)

	AddTooltip(statFrame)
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
	AddTooltip(statFrame)
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
	AddTooltip(statFrame)
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
	AddTooltip(statFrame)
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

	AddTooltip(statFrame)
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
	AddTooltip(statFrame)
end

function BCS:SetSpellCritChance(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.SPELL_CRIT_COLON)

	local generic = BCS:GetSpellCritChance()
	local spell1, spell2, spell3, spell4, spell5, spell6 = BCS:GetSpellCritFromClass(playerClass)
	local total1 = generic + spell1
	local total2 = generic + spell2
	local total3 = generic + spell3
	local total4 = generic + spell4
	local total5 = generic + spell5
	local total6 = generic + spell6

	if total1 > 100 then total1 = 100 end
	if total2 > 100 then total2 = 100 end
	if total3 > 100 then total3 = 100 end
	if total4 > 100 then total4 = 100 end
	if total5 > 100 then total5 = 100 end
	if total6 > 100 then total6 = 100 end

	text:SetText(format("%.2f%%", generic))

	-- warlock spells that can crit are all destruction so just add this to generic
	if playerClass == "WARLOCK" and spell1 > 0 then
		text:SetText(format("%.2f%%", generic + spell1))

	-- if priest have both talents add lowest to generic cos there will be no more spells left that can crit
	elseif playerClass == "PRIEST" and spell3 > 0 and spell2 > 0 then
		if spell2 < spell3 then
			text:SetText(format("%.2f%%", generic + spell2))
		elseif spell2 >= spell3 then
			text:SetText(format("%.2f%%", generic + spell3))
		end
	end

	statFrame.tooltip = format(L.SPELL_CRIT_TOOLTIP)
	statFrame.tooltipSubtext = format(L.SPELL_CRIT_TOOLTIP_SUB)

	statFrame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
		GameTooltip:SetText(this.tooltip)
		GameTooltip:AddLine(this.tooltipSubtext, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1)

		if playerClass == "DRUID" then
			if spell1 > 0 then
				GameTooltip:AddLine(format(L.CRIT_MOONFIRE, total1))
			end
			if spell2 > 0 then
				GameTooltip:AddLine(format(L.CRIT_REGROWTH, total2))
			end

		elseif playerClass == "PALADIN" then
			if spell1 > 0 then
				GameTooltip:AddLine(format(L.CRIT_HOLYLIGHT, total1))
			end
			if spell2 > 0 then
				GameTooltip:AddLine(format(L.CRIT_FLASHOFLIGHT, total2))
			end
			if spell3 > 0 then
				GameTooltip:AddLine(format(L.CRIT_HOLYSHOCK, total3))
			end

		elseif playerClass == "WARLOCK" then
			if spell2 > 0 and spell2 ~= spell1 then
				GameTooltip:AddLine(format(L.CRIT_SEARING, total2))
			end

		elseif playerClass == "PRIEST" then -- all healing spells are holy, change tooltip if player have both talents
			if spell1 > 0 then
				if spell3 > 0 then
					GameTooltip:AddLine(format(L.CRIT_HEALING, total1))
				end
				GameTooltip:AddLine(format(L.CRIT_HOLY, total1 + spell3))
			end
			if spell2 > 0 then
				GameTooltip:AddLine(format(L.CRIT_DISC, total2 + spell3))
			end
			if spell3 > 0 then
				if spell2 > 0 then
					GameTooltip:AddLine(format(L.CRIT_SHADOW, total3))
				else
					GameTooltip:AddLine(format(L.CRIT_OFFENCE, total3))
				end
				GameTooltip:AddLine(format("Smite: %.2f%%", total4))
			end
			if spell4 > 0 then
				GameTooltip:AddLine(format(L.CRIT_PRAYER, total4 + spell1))
			end

		elseif playerClass == "MAGE" then -- dont show specific spells if they have same chance as fire spells
			if spell1 > 0 then
				GameTooltip:AddLine(format(L.CRIT_ARCANE, total1))
			end
			if spell2 > 0 then
				GameTooltip:AddLine(format(L.CRIT_FIRE, total2))
			end
			if spell3 > 0 and spell3 ~= spell2 then
				GameTooltip:AddLine(format(L.CRIT_FIREBLAST, total3))
			end
			if spell4 > 0 and spell4 ~= spell2 then
				GameTooltip:AddLine(format(L.CRIT_SCORCH, total4))
			end
			if spell5 > 0 and spell5 ~= spell2 then
				GameTooltip:AddLine(format(L.CRIT_FLAMESTRIKE, total5))
			end
			if spell6 > 0 then
				GameTooltip:AddLine(format(L.CRIT_FROZEN, total6))
			end

		elseif playerClass == "SHAMAN" then
			if spell1 > 0 then
				GameTooltip:AddLine(format(L.CRIT_LIGHTNINGBOLT, total1))
			end
			if spell2 > 0 then
				GameTooltip:AddLine(format(L.CRIT_CHAINLIGHTNING, total2))
			end
			if spell3 > 0 then
				GameTooltip:AddLine(format(L.CRIT_LIGHTNINGSHIELD, total3))
			end
			if spell4 > 0 then
				GameTooltip:AddLine(format(L.CRIT_FIREFROST, total4))
			end
			if spell5 > 0 then
				GameTooltip:AddLine(format(L.CRIT_HEALING, total5))
			end
		end

		GameTooltip:Show()
	end)
end

function BCS:SetRangedCritChance(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.RANGED_CRIT_COLON)

	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not GetInventoryItemLink("player", 18) then
		text:SetText(NOT_APPLICABLE)
		return
	end

	local crit = BCS:GetRangedCritChance()
	-- apply skill difference modifier
	local skill = BCS:GetRangedWeaponSkill()
	local level = UnitLevel("player")
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

	AddTooltip(statFrame)
end

function BCS:SetHealing(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
	local damageAndHealing = BCS:GetSpellPower()
	local healingOnly, treebonus, ironclad = BCS:GetHealingPower()
	local total = damageAndHealing + healingOnly
	local tooltipExtra

	if ironclad > 0 then
		tooltipExtra = format(L.IRONCLAD, ironclad)
	end

	if treebonus and aura <= treebonus then
		total = total + treebonus
	elseif (not treebonus and aura > 0) or (treebonus and aura > treebonus) then
		total = total + aura
	end

	label:SetText(L.HEAL_POWER_COLON)
	text:SetText(format("%d", total))

	if healingOnly ~= 0 then
		statFrame.tooltip = format(L.SPELL_HEALING_POWER_SECONDARY_TOOLTIP, (total), damageAndHealing, healingOnly)
	else
		statFrame.tooltip = format(L.SPELL_HEALING_POWER_TOOLTIP, (total))
	end
	statFrame.tooltipSubtext = format(L.SPELL_HEALING_POWER_TOOLTIP_SUB)

	AddTooltip(statFrame, tooltipExtra)
end

function BCS:SetManaRegen(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.MANA_REGEN_COLON)

	-- if not a mana user and not a druid set to N/A
	if UnitPowerType("player") ~= 0 and playerClass ~= "DRUID" then
		text:SetText(NOT_APPLICABLE)
		statFrame.tooltip = nil
		return
	end

	local base, casting, mp5 = BCS:GetManaRegen()
	local mp2 = mp5 * 0.4
	local totalRegen = base + mp2
	local totalRegenWhileCasting = (casting / 100) * base + mp2
	if totalRegenWhileCasting ~= totalRegen then
		text:SetText(format("%d (%d)", totalRegen, totalRegenWhileCasting))
	else
		text:SetText(format("%d", totalRegen))
	end

	statFrame.tooltip = format(L.SPELL_MANA_REGEN_TOOLTIP, totalRegen, totalRegenWhileCasting)
	statFrame.tooltipSubtext = format(L.SPELL_MANA_REGEN_TOOLTIP_SUB, base, casting, mp5, mp2)

	AddTooltip(statFrame)
end

function BCS:SetSpellHaste(statFrame)
    local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.HASTE_COLON)

	local haste, spellOnly = BCS:GetHaste()
	local total = haste + spellOnly
	text:SetText(format("%d%%", total))

	statFrame.tooltip = L.SPELL_HASTE_TOOLTIP
	statFrame.tooltipSubtext = L.SPELL_HASTE_TOOLTIP_SUB

	AddTooltip(statFrame)
end

function BCS:SetDodge(statFrame, leveldiff)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.DODGE_COLON)
	text:SetText(format("%.2f%%", BCS:GetEffectiveDodgeChance(leveldiff)))

	statFrame.tooltip = format(L.PLAYER_DODGE_TOOLTIP)
	statFrame.tooltipSubtext = format(L.PLAYER_DODGE_TOOLTIP_SUB)

	AddTooltip(statFrame)
end

function BCS:SetParry(statFrame, leveldiff)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(L.PARRY_COLON)
	text:SetText(format("%.2f%%", BCS:GetEffectiveParryChance(leveldiff)))

	statFrame.tooltip = format(L.PLAYER_PARRY_TOOLTIP)
	statFrame.tooltipSubtext = format(L.PLAYER_PARRY_TOOLTIP_SUB)

	AddTooltip(statFrame)
end

function BCS:SetBlock(statFrame, leveldiff)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]
	local blockChance = BCS:GetEffectiveBlockChance(leveldiff)
	local tooltipExtra

	if blockChance > 0 then
		tooltipExtra = L.BLOCK_VALUE .. BCS:GetBlockValue()
	end

	label:SetText(L.BLOCK_COLON)
	text:SetText(format("%.2f%%", blockChance))

	statFrame.tooltip = format(L.PLAYER_BLOCK_TOOLTIP)
	statFrame.tooltipSubtext = format(L.PLAYER_BLOCK_TOOLTIP_SUB)

	AddTooltip(statFrame, tooltipExtra)
end

function BCS:SetTotalAvoidance(statFrame, leveldiff)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	-- apply skill modifier
	local base, mod = UnitDefense("player")
	local skillDiff = (base + mod) - ((300) + (leveldiff * 5))
	local missChance = 5 + (skillDiff * 0.04)

	local block = BCS:GetEffectiveBlockChance(leveldiff)
	local parry = BCS:GetEffectiveParryChance(leveldiff)
	local dodge = BCS:GetEffectiveDodgeChance(leveldiff)

	local total = missChance + (block + parry + dodge)

	if total < 0 then
		total = 0
	end

	label:SetText(L.TOTAL_COLON)
	text:SetText(format("%.2f%%", total))

	statFrame.tooltip = format(L.TOTAL_AVOIDANCE_TOOLTIP)
	statFrame.tooltipSubtext = format(L.TOTAL_AVOIDANCE_TOOLTIP_SUB)

	AddTooltip(statFrame)
end

function BCS:SetDefense(statFrame)
	local base, modifier = UnitDefense("player")
	local label = _G[statFrame:GetName() .. "Label"]
	local text = _G[statFrame:GetName() .. "StatText"]
	local posBuff = 0
	local negBuff = 0

	label:SetText(DEFENSE_COLON)

	if (modifier > 0) then
		posBuff = modifier
	elseif (modifier < 0) then
		negBuff = modifier
	end

	PaperDollFormatStat(DEFENSE_COLON, base, posBuff, negBuff, statFrame, text)
	statFrame.tooltip = format(L.DEFENSE_TOOLTIP)
	statFrame.tooltipSubtext = format(L.DEFENSE_TOOLTIP_SUB)

	AddTooltip(statFrame)
end

function BCS:SetRangedDamage(statFrame)
	local label = _G[statFrame:GetName() .. "Label"]
	local damageText = _G[statFrame:GetName() .. "StatText"]

	label:SetText(DAMAGE_COLON)

	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not GetInventoryItemLink("player", 18) then
		damageText:SetText(NOT_APPLICABLE)
		statFrame.damage = nil
		return
	end

	AddDamageTooltip(damageText, statFrame, nil, nil, true)
end

function BCS:SetRangedAttackSpeed(statFrame)
	local label = _G[statFrame:GetName() .. "Label"]
	local damageText = _G[statFrame:GetName() .. "StatText"]

	label:SetText(SPEED .. ":")

	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not GetInventoryItemLink("player", 18) then
		damageText:SetText(NOT_APPLICABLE)
		statFrame.damage = nil
		return
	end

	AddDamageTooltip(damageText, statFrame, nil, nil, true)

	damageText:SetText(format("%.2f", UnitRangedDamage("player")))
end

function BCS:SetRangedAttackPower(statFrame)
	local text = _G[statFrame:GetName() .. "StatText"]
	local label = _G[statFrame:GetName() .. "Label"]

	label:SetText(ATTACK_POWER_COLON)

	-- If no ranged attack then set to n/a
	if UnitHasRelicSlot("player") or not GetInventoryItemLink("player", 18) then
		text:SetText(NOT_APPLICABLE)
		statFrame.tooltip = nil
		return
	end

	if HasWandEquipped() then
		text:SetText("--")
		statFrame.tooltip = nil
		return
	end

	local base, posBuff, negBuff = UnitRangedAttackPower("player")
	local tooltipText = HIGHLIGHT_FONT_COLOR_CODE .. RANGED_ATTACK_POWER .. " "
	local effectiveStat = base + posBuff + negBuff

	PaperDollFormatStat(RANGED_ATTACK_POWER, base, posBuff, negBuff, statFrame, text)
	statFrame.tooltipSubtext = format(RANGED_ATTACK_POWER_TOOLTIP, base / ATTACK_POWER_MAGIC_NUMBER)

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

	label:SetText(ATTACK_POWER_COLON)

	PaperDollFormatStat(RANGED_ATTACK_POWER, base, posBuff, negBuff, statFrame, text)
	statFrame.tooltipSubtext = format(RANGED_ATTACK_POWER_TOOLTIP, max((base + posBuff + negBuff), 0) / ATTACK_POWER_MAGIC_NUMBER)

	AddTooltip(statFrame)
end

function BCS:UpdatePaperdollStats(prefix, index)
	local stat1 = _G[prefix .. 1]
	local stat2 = _G[prefix .. 2]
	local stat3 = _G[prefix .. 3]
	local stat4 = _G[prefix .. 4]
	local stat5 = _G[prefix .. 5]
	local stat6 = _G[prefix .. 6]

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
		BCS:SetHitRating(stat5, "MELEE")
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
		BCS:SetHitRating(stat5, "RANGED")
		BCS:SetRangedCritChance(stat6)
	elseif (index == "PLAYERSTAT_SPELL_COMBAT") then
		BCS:SetSpellPower(stat1)
		BCS:SetHitRating(stat2, "SPELL")
		BCS:SetSpellCritChance(stat3)
		BCS:SetHealing(stat4)
		BCS:SetManaRegen(stat5)
		BCS:SetSpellHaste(stat6)
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

	UIDropDownMenu_SetSelectedValue(_G[this.owner], this.value)
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

	UIDropDownMenu_SetSelectedValue(_G[this.owner], this.value)
	IndexRight = this.value
	BCSConfig["DropdownRight"] = IndexRight
	BCS:UpdatePaperdollStats("PlayerStatFrameRight", this.value)

	BCS.needScanGear = false
	BCS.needScanTalents = false
	BCS.needScanAuras = false
	BCS.needScanSkills = false
end

local info = {}

local function PlayerStatFrameLeftDropDown_Initialize()
	for i = 1, getn(BCS.PLAYERSTAT_DROPDOWN_OPTIONS) do
		info.text = BCS.L[BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]]
		info.func = PlayerStatFrameLeftDropDown_OnClick
		info.value = BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]
		info.checked = nil
		info.owner = UIDROPDOWNMENU_OPEN_MENU
		if not (UnitHasRelicSlot("player") and info.value == "PLAYERSTAT_RANGED_COMBAT") then
			UIDropDownMenu_AddButton(info)
		end
	end
end

local function PlayerStatFrameRightDropDown_Initialize()
	for i = 1, getn(BCS.PLAYERSTAT_DROPDOWN_OPTIONS) do
		info.text = BCS.L[BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]]
		info.func = PlayerStatFrameRightDropDown_OnClick
		info.value = BCS.PLAYERSTAT_DROPDOWN_OPTIONS[i]
		info.checked = nil
		info.owner = UIDROPDOWNMENU_OPEN_MENU
		if not (UnitHasRelicSlot("player") and info.value == "PLAYERSTAT_RANGED_COMBAT") then
			UIDropDownMenu_AddButton(info)
		end
	end
end

function PlayerStatFrameLeftDropDown_OnLoad()
	RaiseFrameLevel(this)
	RaiseFrameLevel(_G[this:GetName() .. "Button"])
	UIDropDownMenu_Initialize(this, PlayerStatFrameLeftDropDown_Initialize)
	UIDropDownMenu_SetWidth(99, this)
	UIDropDownMenu_JustifyText("LEFT")
end

function PlayerStatFrameRightDropDown_OnLoad()
	RaiseFrameLevel(this)
	RaiseFrameLevel(_G[this:GetName() .. "Button"])
	UIDropDownMenu_Initialize(this, PlayerStatFrameRightDropDown_Initialize)
	UIDropDownMenu_SetWidth(99, this)
	UIDropDownMenu_JustifyText("LEFT")
end
