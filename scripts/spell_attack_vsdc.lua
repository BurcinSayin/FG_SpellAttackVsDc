---
--- Generated by EmmyLua(https://github.com/EmmyLua)
--- Created by orin.
--- DateTime: 9.06.2021 09:45
---

weapon_action_traits = {
	["trip"] = "SKILLVS:Athletics:VS:REF",
    ["grapple"] = "SKILLVS:Athletics:VS:FORT",
	["disarm"] = "SKILLVS:Athletics:VS:REF",
	["shove"] = "SKILLVS:Athletics:VS:FORT",
    ["ranged trip"] = "SKILLVS:Athletics:VS:REF",
};

local baseAttackFunc = nil;

function onInit()
    baseAttackFunc = ActionAttack.getRoll;
    ActionAttack.getRoll = customFunc;

	ActionsManager.registerModHandler("vsdc", modVsDcCustom);
	ActionsManager.registerResultHandler("vsdc", onVsDCCustom);

    OptionsManager.registerOption2("SpellVsDcLog", false, "option_spvsdc_header", "option_spvsdc_logging_label", "option_entry_cycler", { labels = "chat|console", values="chat|console", baselabel = "option_val_off", baseval="off", default="off"});
end

function onVsDCCustom(rSource, rTarget, rRoll)
	local nTargetDC = 0;
	
	if rRoll.sVsDcCustomSource and rRoll.sVsDcCustomSource ~= "" then
		local sTargetDC = string.match(rRoll.sTargetDefense, "Dc(%d+)");
		if sTargetDC and sTargetDC ~= "" then
			nTargetDC = tonumber(sTargetDC) or 0;
		end
    end

	if nTargetDC > 0 then
		local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
		local nTotal = ActionsManager.total(rRoll);
		local sResult = GameSystem.getd20CheckResult(rRoll.aDice[1].result, nTotal, nTargetDC);
		
		if sResult ~= "" then
			rMessage.text = rMessage.text .. " [" .. sResult .. "]";
		end
		Comm.deliverChatMessage(rMessage);
	else
		ActionVsDC.onVsDC(rSource, rTarget, rRoll);
	end
end


function customFunc(rActor, rAction)

    logToChat("ActionAttack.getRoll",rActor, rAction);

    local bCtrlDown = Input.isControlPressed();

    local aActionTraits = nil;
    if bCtrlDown and rAction.type == "attack" then
        aActionTraits = StringManager.split(rAction.traits, ",", true);
    elseif rAction.type == "cast" then
        aActionTraits = StringManager.split(rAction.savetraits, ",", true);
    end


    local sSkillName = nil;
    local sSkillAgainst = nil;
    logToChat("ACTION TRAITS",aActionTraits);
	if aActionTraits and #aActionTraits > 0 then
		for _, sActionTrait in pairs(aActionTraits) do
			if sActionTrait and sActionTrait ~= "" then
                if bCtrlDown and rAction.type == "attack" then
					sActionTrait = sActionTrait:lower();
                    local sWeaponTrait = weapon_action_traits[sActionTrait];
                    if sWeaponTrait and sWeaponTrait ~= "" then
                        sSkillName,sSkillAgainst = string.match(weapon_action_traits[sActionTrait], "SKILLVS:(%w+):VS:(%w+)");
                        rAction.label = rAction.label .. " [" .. sActionTrait .. "]"; 
						rAction.sAbilityTitle = StringManager.titleCase(sActionTrait);
                    end
                else
                    sSkillName,sSkillAgainst = string.match(sActionTrait, "SKILLVS:(%w+):VS:(%w+)");
                end
                if sSkillName and sSkillName ~= "" and sSkillAgainst and sSkillAgainst ~= "" then
					sSkillName = StringManager.titleCase(sSkillName);
					sSkillAgainst = StringManager.titleCase(sSkillAgainst);
                    break;
                end
			end
		end
	end

    if sSkillName and sSkillName ~= "" and sSkillAgainst and sSkillAgainst ~= "" then
        return tranformActionAndRoll(rActor,rAction,sSkillName,sSkillAgainst);
    end

    local rRoll = baseAttackFunc(rActor, rAction);

    logToChat(rRoll);

    return rRoll;

end

-- { s'type' = s'attack', s'traits' = s'Uncommon, Trip', s'order' = #1, s'properties' = s'', s'range' = s'M', s'modifier' = #15, s'nWeaponBonus' = #0, s'stat' = s'strength', s'crit' = #20, s'label' = s'Khopesh' }
-- { s'type' = s'skill', s'label' = s'Demoralize', s'order' = #1, s'sTargeting' = s'', s'sTargetDefense' = s'will', s'sAbilityTitle' = s'Demoralize', s'sSource' = s'combattracker.list.id-00001', s'modifier' = #0, s'traits' = s'Auditory, Concentrate, Emotion, Fear, Mental', s'sSourceAction' = s'Intimidation', s'meta' = s'', s'actionnodename' = s'charsheet.id-00007.activityset.id-00003.sections.id-00023.activities.id-00002.actions.id-00001' }
function tranformActionAndRoll(rActor,rAction,sSkillName,sSkillAgainst)

	local rVsDcAction = { };
	rVsDcAction.type = "skill";
	rVsDcAction.order = rAction.order;
	rVsDcAction.sSource = rActor.sCTNode;
	rVsDcAction.sTargetDefense = sSkillAgainst;
	rVsDcAction.sSourceAction = sSkillName;

	rVsDcAction.label = rAction.label;
	rVsDcAction.sAbilityTitle = rAction.sAbilityTitle;

	-- local nSkillModifier, sProficency = CharManager.getSkillValue(rActor, sSkillName, nil);
    if rAction.type == "attack" then
		rVsDcAction.sActivityusage = "map";
		rVsDcAction.traits = "attack";
		if rAction.order == 2 then
			ModifierManager.setKey("ATT_MULTI_2", true);
			ModifierManager.setKey("ATT_MULTI_3", false);
		elseif rAction.order == 3 then
			ModifierManager.setKey("ATT_MULTI_2", false);
			ModifierManager.setKey("ATT_MULTI_3", true);
		end
    end

	rAction.sSourceAction = sSkillName;
    rAction.sTargetDefense = sSkillAgainst;

    local vsDcRoll = ActionVsDC.getRoll(nil,rActor,rVsDcAction);
	vsDcRoll.sVsDcCustomType = rAction.type;

	if rAction.type == "attack" then
		vsDcRoll.nVsDcCustomBonus = rAction.nWeaponBonus;
		vsDcRoll.sVsDcCustomSkill = string.lower(StringManager.trim(sSkillName));
    end

    logToChat("VsDCRoll:",vsDcRoll);
    return vsDcRoll;
end

function modVsDcCustom(rSource, rTarget, rRoll)
	logToChat("modVsDcCustom - START.  = ", rSource, rTarget, rRoll);

    if rRoll.sVsDcCustomType and rRoll.sVsDcCustomType ~= "" then
        ActionVsDC.clearCritState(rSource);
        if rRoll.sVsDcCustomType == "attack" then
			local aSkillFilter = {};
			aSkillFilter["skill"] = rRoll.sVsDcCustomSkill;
			
			local aSKILLEffectsUntyped, aSKILLEffectBonuses, aSKILLEffectPenalties, nEffectCount;
			aSKILLEffectsUntyped, aSKILLEffectBonuses, aSKILLEffectPenalties, nEffectCount = EffectManagerPFRPG2.getEffectsBonusByType(rSource, {"SKILL"}, true, aSkillFilter, rTarget, nil, nil, true);

			local nBonus = 0;
			local nDelta = 0;
			if aSKILLEffectBonuses["item"] then
				nBonus = aSKILLEffectBonuses["item"];
			end
			if rRoll.nVsDcCustomBonus and rRoll.nVsDcCustomBonus > nBonus then
				nDelta = rRoll.nVsDcCustomBonus - nBonus;
				rRoll.nMod = rRoll.nMod + nDelta;
				rRoll.sDesc = rRoll.sDesc .. " [WEAPON: " .. nDelta .. "]";
			end
        end
    end

	ActionVsDC.modVsDC(rSource, rTarget, rRoll);

	logToChat("modVsDcCustom - END.  = ", rSource, rTarget, rRoll);
end

function applyMultiAttackMod(rSource, rTarget, rRoll)
    local aAddDesc = {};
	local nAddMod = 0;
    
    -- Get weapon traits and properties to the roll structure.
	local sTraits = "";
	if rRoll.traits and rRoll.traits ~= "" then
		sTraits = rRoll.traits:lower();
	end

	local bMultiAtk2 = ModifierStack.getModifierKey("ATT_MULTI_2") or (rRoll.sVsDcCustomSource == "attack2");
	local bMultiAtk3 = ModifierStack.getModifierKey("ATT_MULTI_3") or (rRoll.sVsDcCustomSource == "attack3");

    if Session.IsHost then
		local wGMCT = Interface.findWindow("combattracker_host", "combattracker");
		GlobalDebug.consoleObjects("modAttack.  Resetting CT MA buttons.  wGMCT = ", wGMCT);
		if wGMCT then
			wGMCT["ATT_MULTI_2"].setValue(0);
			wGMCT["ATT_MULTI_3"].setValue(0);
		end
	else
		local wGMCT = Interface.findWindow("combattracker_client", "combattracker");
		GlobalDebug.consoleObjects("modAttack.  Resetting CT MA buttons.  wGMCT = ", wGMCT);
		if wGMCT then
			wGMCT["ATT_MULTI_2"].setValue(0);
			wGMCT["ATT_MULTI_3"].setValue(0);
		end	
	end

    local nMultiAttack2PenaltyEff = -5;
	local nMultiAttack3PenaltyEff = -10;

    if rSource then
		-- Get MAP effects.  This assumes that agile is not included in this, and agile is 1 less for MAP2 and 2 less for MAP3.
		if bMultiAtk2 then
			local nMultiAttack2PenaltyTempEff = EffectManagerPFRPG2.getEffectsBonus(rSource, {"MAP2"}, true, aAttackFilter, rTarget, nil, nil, true);	
			if nMultiAttack2PenaltyTempEff ~= 0 and nMultiAttack2PenaltyTempEff ~= -5 then
				bEffects = true;
				--nAddMod = nAddMod + nMultiAttack2PenaltyEff + 5;
				nMultiAttack2PenaltyEff = nMultiAttack2PenaltyTempEff;
				GlobalDebug.consoleObjects("MAP2 effect = ", nMultiAttack2PenaltyEff);
			else
				local nMultiAttackPenaltyEff = EffectManagerPFRPG2.getEffectsBonus(rSource, {"MAP"}, true, aAttackFilter, rTarget, nil, nil, true);
				if nMultiAttackPenaltyEff ~= 0 and nMultiAttackPenaltyEff ~= -5 then
					bEffects = true;
					--nAddMod = nAddMod + nMultiAttackPenaltyEff + 5;
					nMultiAttack2PenaltyEff = nMultiAttackPenaltyEff;
					GlobalDebug.consoleObjects("MAP effect = ", nMultiAttackPenaltyEff);
				end
			end			
		elseif bMultiAtk3 then
			local nMultiAttack3PenaltyTempEff = EffectManagerPFRPG2.getEffectsBonus(rSource, {"MAP3"}, true, aAttackFilter, rTarget, nil, nil, true);	
			if nMultiAttack3PenaltyTempEff ~= 0 and nMultiAttack3PenaltyTempEff ~= -10 then
				bEffects = true;
				--nAddMod = nAddMod + nMultiAttack3PenaltyEff + 10;
				nMultiAttack3PenaltyEff = nMultiAttack3PenaltyTempEff;
				GlobalDebug.consoleObjects("MAP3 effect = ", nMultiAttack3PenaltyEff);
			else
				local nMultiAttackPenaltyEff = EffectManagerPFRPG2.getEffectsBonus(rSource, {"MAP"}, true, aAttackFilter, rTarget, nil, nil, true);
				if nMultiAttackPenaltyEff ~= 0 and nMultiAttackPenaltyEff ~= -5 then
					bEffects = true;
					--nAddMod = nAddMod + (nMultiAttackPenaltyEff * 2) + 10;
					nMultiAttack3PenaltyEff = nMultiAttackPenaltyEff * 2;
					GlobalDebug.consoleObjects("MAP effect = ", nMultiAttackPenaltyEff * 2);
				end				
			end				
		end		
	end

    local nAgileMod = 0;
	if string.find(sTraits, "agile") then
		nAgileMod = 1;
		table.insert(aAddDesc, "[Agile]")
	end	
	-- Set the final MAP penalty.
	if bMultiAtk2 then
		nAddMod = nAddMod + nMultiAttack2PenaltyEff + nAgileMod;
		table.insert(aAddDesc, "[MULTI ATK #2: " .. nMultiAttack2PenaltyEff + nAgileMod .. "]");
	elseif bMultiAtk3 then
		nAddMod = nAddMod + nMultiAttack3PenaltyEff + (nAgileMod * 2);
		table.insert(aAddDesc, "[MULTI ATK #3: " .. nMultiAttack3PenaltyEff  + (nAgileMod * 2) .. "]");
	end	
	
	if #aAddDesc > 0 then
		rRoll.sDesc = rRoll.sDesc .. " " .. table.concat(aAddDesc, " ");
	end
	rRoll.nMod = rRoll.nMod + nAddMod;
end

function logToChat(...)
    local logOption = OptionsManager.getOption("SpellVsDcLog"):lower();

    if logOption == "chat" then
        Debug.chat(...);
    elseif logOption == "console" then
        Debug.console(...);
    end

end
