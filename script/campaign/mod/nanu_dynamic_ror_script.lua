
require("nanu_dynamic_ror_data");

-------- MCT VARIABLES --------
local ror_button_enabled = false;
local grant_free_ror = true;
local player_ror_modifier = 100;
local ai_ror_enabled = true;
local ai_ror_chance = 10;
local max_rors_per_turn = 5;
local max_faction_rors_per_turn = 1;
local randomize_ror_choice = false;
local rename_units = true;
local minimum_unit_rank = 0;
local increase_unit_rank = true;
local debug_mode = true;
local missileScalar = 1.25;
local earlyTurnScalar = 0.4;

local earlyTurnThreshold = 40;

local minKillsRankZero = 500; --The baFse minimum amount of kills needed to become an RoR at unit rank 0
local minKillsRankNine = 200; --The base minimum amount of kills needed to become an RoR at unit rank 9

local baseDamageFactor = 65; -- The base amount of damage each kill made by the unit is worth
local damageModifierMin = 0.25; --The lowest amount the damage modifier can be
local damageModifierMax = 2; --The highest amount the damage modifier can be

local baseUnitCostValue = 750; -- The base cost at which the unit cost modifier will equal 1
local unitCostFactor = 2; -- This value controls how strong the unit cost scalar can get (it will always be 1 at baseUnitCostValue and always be 0 at 0)
local unitCostMaxScalar = 2.0; --The maximum unit cost scalar
local unitCostMinScalar = 0.2; --The minimum unit cost scalar

local unitHealthScalarMin = 0.5; --How low Unit Health Scalar can be at 0 hitpoints
local unitHealthScalarMax = 1.0; --How low Unit Health Scalar can be at at 100 hitpoints

local decisiveVictoryScalar = 1.0;
local closeVictoryScalar = 0.8;
local heroicVictoryScalar = 0.6;
local pyrrhicVictoryScalar = 0.6;

local decisiveDefeatScalar = 0.0;
local closeDefeatScalar = 0.0;
local valiantDefeatScalar = 0.0;
local crushingDefeatScalar = 0.0;

-------- SCRIPT VARIABLES --------
local enable_ror_button_listener --used to keep the listener from firing multiple times
local event_on_ror = true; --does the player receive an event in their feed after a unit becomes an RoR
local rors_this_turn = 0; --how many RoRs have been created this turn, global
local faction_rors = {}; --how many RoRs have been created this turn for this faction, ex: {"wh_main_emp_empire" = 2}
local modded_content_ready = false;

--Need to load this immediately to ensure its ready before mods load
core:add_listener(
    "DynamicRoRModdedContentReady",
    "DynamicRoRModdedContentReady",
    true,
    function(context)
        dynamic_ror_log("DynamicRoRModdedContentReady");
        modded_content_ready = true;
    end,
    true
);

-------- SAVED VARIABLES --------
local free_ror = false;
local saved_rors = {};
local primary_faction = "";


function nanu_dynamic_ror_script()

    local faction_list = cm:model():world():faction_list();
    
    dynamic_ror_log("free_ror = "..tostring(free_ror));
    dynamic_ror_log("saved_rors = "..table.tostring(saved_rors));
    
    --Disable all purchasable effects, wait a quarter of a second to allow other mods to execute
    core:get_tm():real_callback(
        function()
            for i = 0, faction_list:num_items() - 1 do
                local faction = faction_list:item_at(i);
                
                for j = 1, #Dynamic_RoR_EffectList do
                    local effect = Dynamic_RoR_EffectList[j];
                    cm:faction_set_unit_purchasable_effect_lock_state(faction, effect, effect, false);
                    if faction:is_human() then
                        dynamic_ror_log("disabing "..effect.." ("..common.get_localised_string("effect_bundles_localised_title_"..effect)..") for faction "..faction:name());
                    end
                    cm:faction_set_unit_purchasable_effect_lock_state(faction, effect, effect, true);
                end
            end
        end,
        1000
    );
    
    --button listeners
    dynamic_ror_button_listeners();
    
    
    --data tracking
    core:add_listener(
        "DynamicRoR_FactionTurnStart",
        "FactionTurnStart",
        function(context)
        
            return context:faction():is_human() and (primary_faction == context:faction():name() or primary_faction == "" or primary_faction == nil);
        end,
        function(context)
            dynamic_ror_log("DynamicRoR_FactionTurnStart...")
            
            --reset and clear data
            primary_faction = context:faction():name();
            faction_rors = {};
            rors_this_turn = 0;
        
            dynamic_ror_log("rors_this_turn = " .. rors_this_turn)
        end,
        true
    );
    
    core:add_listener(
        "DynamicRoR_BattleCompleted",
        "CharacterCompletedBattle",
        function(context)
            local battle = cm:model():pending_battle();
        
            dynamic_ror_log("DynamicRoR_BattleCompleted...")
            
            dynamic_ror_log("rors_this_turn = " .. rors_this_turn)
            dynamic_ror_log("max_rors_per_turn = " .. max_rors_per_turn)
            
            if battle and battle:is_null_interface() == false and rors_this_turn < max_rors_per_turn
            then
                return true;
            end 
        end,
        function(context)
            local battle = cm:model():pending_battle();
            
            dynamic_ror_log("DynamicRoR_BattleCompleted");
            
            if not battle or battle:is_null_interface() then
                dynamic_ror_log("   ERROR: INVALID BATTLE");
                return;
            end
                
            local num_attackers = cm:pending_battle_cache_num_attackers();
            local num_defenders = cm:pending_battle_cache_num_defenders();
            local lightning_strike_battle = battle:night_battle();
            
            dynamic_ror_log("num_attackers = "..num_attackers)
            dynamic_ror_log("num_defenders = "..num_defenders)
            
            if battle:attacker_won() then
                --roll attackers
                for i = 1, num_attackers do
                    local char_cqi, mf_cqi, faction_name = cm:pending_battle_cache_get_attacker(i);
                    local char_obj = cm:model():character_for_command_queue_index(char_cqi);
                    
                    if i > 1 and lightning_strike_battle then
                        break;
                    end 
                    
                    if faction_rors[faction_name] == nil or faction_rors[faction_name] < max_faction_rors_per_turn then
                        --Attempt to make RoR from characters army
                        --core:trigger_custom_event("DynamicRorsPlayerCharacterWonBattle", {character = char_obj, battle = battle, isAttacker = true})
                        
                        local unit_object = dynamic_ror_CharacterBattleCompleted(char_obj, battle, true);
                        if unit_object ~= nil then
                            rors_this_turn = rors_this_turn + 1;
                            
                            if faction_rors[faction_name] then
                                faction_rors[faction_name] = faction_rors[faction_name] + 1;
                            else
                                faction_rors[faction_name] = 1;
                            end
                            break;
                        end
                    end
                    break;
                end
            end
            
            if battle:defender_won() then
                --roll defenders
                for i = 1, num_defenders do
                    local char_cqi, mf_cqi, faction_name = cm:pending_battle_cache_get_defender(i);
                    local char_obj = cm:model():character_for_command_queue_index(char_cqi);
                    
                    if i > 1 and lightning_strike_battle then
                        break;
                    end 
                    
                    if faction_rors[faction_name] == nil or faction_rors[faction_name] < max_faction_rors_per_turn then
                        --Attempt to make RoR from characters army
                        --core:trigger_custom_event("DynamicRorsPlayerCharacterWonBattle", {character = char_obj, battle = battle, isAttacker = true})
                        
                        local unit_object = dynamic_ror_CharacterBattleCompleted(char_obj, battle, false);
                        if unit_object ~= nil then
                            rors_this_turn = rors_this_turn + 1;
                            
                            if faction_rors[faction_name] then
                                faction_rors[faction_name] = faction_rors[faction_name] + 1;
                            else
                                faction_rors[faction_name] = 1;
                            end
                            break;
                        end
                    end
                end
            end 
        end,
        true
    );
    
end

--- @function dynamic_ror_CharacterBattleCompleted
--- @param character CHARACTER_SCRIPT_INTERFACE
--- @param character PENDING_BATTLE_SCRIPT_INTERFACE
--- @desc Is called for each character following a battle
function dynamic_ror_CharacterBattleCompleted(character, battle, isAttacker)

    if character == nil or character:is_null_interface() then
        out("\t ERROR: Invalid character interface provided!");
        return;
    end
    
    if battle == nil or battle:is_null_interface() then
        out("\t ERROR: Invalid battle interface provided!");
        return;
    end
    
    --Roll AI before calculating anything
    if not character:faction():is_human() then
        local roll = cm:random_number(100, 1);
        
        if roll > ai_ror_chance then
            return;
        end
    else
        --disable system when ror chance = 0
        if player_ror_modifier == 0 or not player_ror_modifier then
            return;
        end 
    end
    
    
    local character_subtype_key = character:character_subtype_key()
    
    dynamic_ror_log("dynamic_ror_CharacterBattleCompleted called");
    
    
    dynamic_ror_log("\t Character Key: ".. character_subtype_key);
    dynamic_ror_log("\t Character CQI: ".. character:command_queue_index());
    dynamic_ror_log("\t Character Faction: ".. character:faction():name());
    
    local region_context = "";
    local region = character:region();
    
    if region and region:is_null_interface() == false then
        region_context = region:name() or "";
    end
    
    if character:is_at_sea() then
        region_context = "ocean";
    end
            
    --TESTING
    
    local garrison = battle:contested_garrison();
    local is_settlement_battle = false
    
    if garrison and garrison:is_null_interface() == false then
        dynamic_ror_log("Settlment Battle")
        is_settlement_battle = true;
    else
        dynamic_ror_log("Not a Settlment Battle")
    end 
    
    --effect keywords
    local battle_contexts = {};
    local enemy_contexts = {};
    local ally_contexts = {};
            
    local battle_context;
    local casualties = 0;
    local enemy_casualties = 0;
    
    local damage_dealt = 0;
    local damage_taken = 0;
    local cp_kill_score = 0;
    local cp_kill_score_enemy = 0;
    local hp_lost = 0;
    local hp_lost_enemy = 0;
                
    local num_attackers = cm:pending_battle_cache_num_attackers();
    local num_defenders = cm:pending_battle_cache_num_defenders();      
    
    if isAttacker then
        battle_context = battle:attacker_battle_result();
        
        casualties = battle:attacker_casulaties();
        enemy_casualties = battle:defender_casulaties();
        
        damage_dealt = battle:defender_total_hp_lost();
        damage_taken = battle:attacker_total_hp_lost();
        
        cp_kill_score = battle:attacker_ending_cp_kill_score();
        cp_kill_score_enemy = battle:defender_ending_cp_kill_score();
        
        hp_lost = battle:attacker_total_hp_lost();
        hp_lost_enemy = battle:defender_total_hp_lost();
    else
        battle_context = battle:defender_battle_result();
        
        casualties = battle:defender_casulaties();
        enemy_casualties = battle:attacker_casulaties();
        
        damage_dealt = battle:attacker_total_hp_lost();
        damage_taken = battle:defender_total_hp_lost();
        
        cp_kill_score = battle:defender_ending_cp_kill_score();
        cp_kill_score_enemy = battle:attacker_ending_cp_kill_score();
        
        hp_lost = battle:defender_total_hp_lost();
        hp_lost_enemy = battle:attacker_total_hp_lost();
    end
    
    local force = character:military_force();
    
    local valid_units = {};
    
    for i = 1, force:unit_list():num_items() - 1 do
        local unit = force:unit_list():item_at(i);
        if unit and unit:is_null_interface() == false then
            local can_be_ror = false;
            local effect_list = unit:get_unit_purchasable_effects();
            
            for j = 0, effect_list:num_items() - 1 do
                local effect_interface = effect_list:item_at(j);
                if string.find(effect_interface:record_key(), "dynamic_ror") then
                    local purchased_effects = unit:get_unit_purchased_effects();
                    if purchased_effects and purchased_effects:num_items() > 0 then
                        for k = 0, purchased_effects:num_items() - 1 do
                            local purchased_effect = purchased_effects:item_at(k);
                            if string.find(purchased_effect:record_key(), "dynamic_ror") then
                                can_be_ror = false;
                                break;
                            end
                        end
                    else
                        can_be_ror = true;
                    end
                    break;
                end
            end
            if can_be_ror then
                table.insert(valid_units, #valid_units + 1, unit);
            end
        end
    end
    
    dynamic_ror_log("Number of valid_units  ".. #valid_units)
    
    if #valid_units > 0 then
    
        num_attackers = cm:pending_battle_cache_num_attackers();
        num_defenders = cm:pending_battle_cache_num_defenders(); 
        
--         dynamic_ror_log("num_attackers = "..num_attackers);
--         dynamic_ror_log("num_defenders = "..num_defenders);
        
        local attacker_culture_list = {};
        local defender_culture_list = {};
        
        local attacker_faction_list = {};
        local defender_faction_list = {};
        
        local attacker_subtype_list = {};
        local defender_subtype_list = {};
        
        for i = 1, num_attackers do 
            local char_cqi, mf_cqi, faction_name = cm:pending_battle_cache_get_attacker(i);
            local char_obj = cm:model():character_for_command_queue_index(char_cqi);
            
            if char_obj ~= character then
                local char_subtype = cm:pending_battle_cache_get_attacker_subtype(i);
                
                if char_subtype then
                    attacker_subtype_list[char_subtype] = true;
                end
                
                if faction_name and cm:model():world():faction_exists(faction_name) and faction_name ~= character:faction():name() then
                    attacker_faction_list[faction_name] = true;
                    
                    local faction = cm:model():world():faction_by_key(faction_name);
                    
                    attacker_culture_list[faction:culture()] = true;
                end
            end
        end
        
        for i = 1, num_defenders do 
            local char_cqi, mf_cqi, faction_name = cm:pending_battle_cache_get_defender(i);
            local char_obj = cm:model():character_for_command_queue_index(char_cqi);
            
            if char_obj ~= character then
                local char_subtype = cm:pending_battle_cache_get_defender_subtype(i);
                
                if char_subtype then
                    defender_subtype_list[char_subtype] = true;
                end
                
                local char_cqi, mf_cqi, faction_name = cm:pending_battle_cache_get_defender(i);
                
                if faction_name and cm:model():world():faction_exists(faction_name) and faction_name ~= character:faction():name() then
                    defender_faction_list[faction_name] = true;
                    
                    local faction = cm:model():world():faction_by_key(faction_name);
                    
                    defender_culture_list[faction:culture()] = true;
                end
            end
        end
        
        dynamic_ror_log("Battle Type =  ".. battle:battle_type());
            
        if character:faction():is_human() then 
        
            --if character is defender get the ui index
        
            local ui_index = 0;
            
            if isAttacker and character ~= battle:attacker() then
            
                dynamic_ror_log("Character is not primary Attacker!")
    
                --fixes a crash with lightning strike battles
                if lightning_strike_battle then
                    dynamic_ror_log(character_subtype_key .. " is not the main attacker! Returning...")
                    return;
                end 
                
                dynamic_ror_log(character_subtype_key .. " is not the main attacker! Searching battle:secondary_defenders()...");
                
                local attacker_list = battle:secondary_attackers();
                
                if attacker_list and attacker_list:num_items() > 0 then
                    for i = 0, attacker_list:num_items() - 1 do
                        ui_index = i + 1;
                        if character == attacker_list:item_at(i) then
                            dynamic_ror_log("Matched character at index: " .. i)
                            break;
                        end
                    end
                end
            end
            
            if not isAttacker and character ~= battle:defender()  then
    
                --fixes a crash with lightning strike battles
                if lightning_strike_battle then
                    dynamic_ror_log(character_subtype_key .. " is not the main defender! Returning...")
                    return;
                end 
                
                dynamic_ror_log(character_subtype_key .. " is not the main defender! Searching battle:secondary_defenders()...")
                
                local defender_list = battle:secondary_defenders();
                
                if defender_list and defender_list:num_items() > 0 then
                    for i = 0, defender_list:num_items() - 1 do
                        ui_index = i + 1;
                        if character == defender_list:item_at(i) then
                            dynamic_ror_log("Matched character at index: " .. i)
                            break;
                        end
                    end
                end
            end
            
            dynamic_ror_log("ui_index: " .. ui_index)
            
            ------------------------ PLAYER MODIFIER ------------------------
            
            if player_ror_modifier == 0 then
                return;
            end 
                            
            local player_modifier = 1;   

            if player_ror_modifier < 100 then
                player_modifier = 100 / player_ror_modifier; 
            else
                if player_ror_modifier == 500 then
                    player_modifier = 0; --500 is guaranteed
                else
                    player_modifier = 1 / ( math.pow(2, ( (player_ror_modifier - 100) / 100 )));
                end 
            
            end 
            
            -----------------------------------------------------------------
                                 
            ------------------------ DAMAGE MODIFIER ------------------------
            --increases chance based on the ratio of kills/damage Helps with Ogres/Monstrous units and single entity doomstacks
        
            --Damage dealt gets doubled on settlement battle victories. I don't know why
            if isAttacker and is_settlement_battle then
                damage_dealt = damage_dealt / 2;
            end
            
            --TESTING
            dynamic_ror_log("casualties: ".. casualties)
            dynamic_ror_log("enemy_casualties: ".. enemy_casualties)
            dynamic_ror_log("damage_dealt: ".. damage_dealt)
            dynamic_ror_log("damage_taken: ".. damage_taken)
            dynamic_ror_log("cp_kill_score: ".. cp_kill_score)
            dynamic_ror_log("cp_kill_score_enemy: ".. cp_kill_score_enemy)
            dynamic_ror_log("hp_lost: ".. hp_lost)
            dynamic_ror_log("hp_lost_enemy: ".. hp_lost_enemy)
            local damage_modifier = baseDamageFactor * enemy_casualties / damage_dealt;
            
            dynamic_ror_log("\tcalculated damage_modifier: " .. damage_modifier);
            
            damage_modifier = math.min(math.max(damage_modifier, damageModifierMin), damageModifierMax);
            
            dynamic_ror_log("\tcapped damage_modifier: " .. damage_modifier);
            
            -----------------------------------------------------------------
                                                    
            ------------------------ BATTLE MODIFIER ------------------------
            --increases or decreases minKills based on the result of the battle
            local battle_modifier = 1;
            
            dynamic_ror_log("\tbattle_context: " .. battle_context)
            
            if battle_context == "decisive_victory" then
                battle_modifier = decisiveVictoryScalar;
            end
            
            if battle_context == "close_victory" then
                battle_modifier = closeVictoryScalar;
            end
            
            if battle_context == "pyrrhic_victory" then
                battle_modifier = pyrrhicVictoryScalar;
            end
            
            if battle_context == "heroic_victory" then
                battle_modifier = heroicVictoryScalar;
            end 
            
            if battle_context == "decisive_defeat" then
                battle_modifier = decisiveDefeatScalar;
            end
            
            if battle_context == "close_defeat" then
                battle_modifier = closeDefeatScalar;
            end
            
            if battle_context == "valiant_defeat" then
                battle_modifier = valiantDefeatScalar;
            end
            
            if battle_context == "crushing_defeat" then
                battle_modifier = crushingDefeatScalar;
            end 
            
            if battle_modifier == 0 then
                dynamic_ror_log("battle_modifier is " .. battle_modifier .. "!, aborting Dynamic RoR generation...");
                return;
            end 
            
            -----------------------------------------------------------------
        
            --remove previous listener if exists to avoid crashes
            core:remove_listener("dynamic_ror_PanelOpenedCampaign_" .. ui_index)
            
            dynamic_ror_log("adding listener dynamic_ror_PanelOpenedCampaign_" .. ui_index)
            core:add_listener(
                "dynamic_ror_PanelOpenedCampaign_" .. ui_index,
                "PanelOpenedCampaign",
                function(context)
                    local panel = context.string;
                    return panel == "popup_battle_results"
                end,
                function(context)
                    core:get_tm():real_callback(function()
                    
                        dynamic_ror_log("dynamic_ror_PanelOpenedCampaign_"..ui_index);
                        
                        --remove listener immediately to avoid crashes
                        core:remove_listener("dynamic_ror_PanelOpenedCampaign_" .. ui_index)
                        
                        --last chance to clean up dead/garrison characters
                        if not character or character:is_null_interface() or character:has_military_force() == false 
                        or not character:military_force() or character:military_force():is_null_interface() then
                            return;
                        end 
                        
                        --remake list for human players, use unit kills, damage, etc to determine eligibility
                        valid_units = {};
                    
                        dynamic_ror_log("ui_index: " .. ui_index)
                            
                        local unitList_component = find_uicomponent( core:get_ui_root(), "popup_battle_results", "allies_combatants_panel", "army", "units_and_banners_parent", "units_window", "listview", "list_clip", "list_box", "commander_header_" .. ui_index, "units");
                        
                        local index = 1;
                        
                        local unit_list = character:military_force():unit_list();
                        
                        local chosen_unit_object;
                
                        if unitList_component then
--                             dynamic_ror_log("unitList_component exists")
--                             dynamic_ror_log("unit_list:num_items() = ".. unit_list:num_items());
--                             dynamic_ror_log("unitList_component:ChildCount() = ".. unitList_component:ChildCount());
                        
                            for i = 1, unitList_component:ChildCount() - 1 do
                            
--                                     dynamic_ror_log("index: " .. index);
--                                     dynamic_ror_log("i: " .. i);
--                                     dynamic_ror_log("unitList_component:ChildCount(): " .. unitList_component:ChildCount());
--                                     dynamic_ror_log("unit_list:num_items(): " .. unit_list:num_items());
                        
                                    local unit_component = find_child_uicomponent_by_index(unitList_component, i);
                                    
                                    if unit_component and unit_component:CurrentState() == "active" then
                                    
                                        local unit = unit_list:item_at(index);
                                        
                                        if unit and unit:is_null_interface() == false then
                                            
                                            dynamic_ror_log("Checking Unit " .. unit:unit_key());
                                        
                                            local can_be_ror = true;
                                            
                                            ----------------------------- UNIT RANK -----------------------------
                                            local unit_rank = unit:experience_level();
                                            dynamic_ror_log("\tunit rank: " .. unit_rank);
                                            
                                            if minimum_unit_rank > unit_rank and (grant_free_ror == false or free_ror == false) then
                                                can_be_ror = false;
                                            end 
                                            ---------------------------------------------------------------------
                                    
                                            
                                            ---------------------------- CHECK EFFECTS --------------------------
                                            if can_be_ror then
                                                can_be_ror = false;
                                                local effect_list = unit:get_unit_purchasable_effects();
                                                
                                                for j = 0, effect_list:num_items() - 1 do
                                                    local effect_interface = effect_list:item_at(j);
                                                    
                                                    -- check all effects for "dynamic_ror", stop at first occurance
                                                    if string.find(effect_interface:record_key(), "dynamic_ror") then
                                                        --dynamic_ror_log(effect_interface:record_key())
                                                        local purchased_effects = unit:get_unit_purchased_effects();
                                                        
                                                        --Check if unit is already a dynamic RoR
                                                        if purchased_effects and purchased_effects:num_items() > 0 then
                                                            for k = 0, purchased_effects:num_items() - 1 do
                                                                local purchased_effect = purchased_effects:item_at(k);
                                                                if string.find(purchased_effect:record_key(), "dynamic_ror") then
                                                                    dynamic_ror_log("Unit is already a Dynamic RoR!")
                                                                    can_be_ror = false;
                                                                    break;
                                                                end
                                                            end
                                                        else
                                                            can_be_ror = true;
                                                        end
                                                        break;
                                                    end
                                                end
                                            end
                                            ---------------------------------------------------------------------
                                            
                                            if can_be_ror then
                                            
                                                ------------------------ SCRAPE KILL COUNT ------------------------
                                                local killCount_component = find_uicomponent( unit_component, "card_image_holder", "common_list", "label_kills");
                                                local numKillsString = killCount_component:GetStateText();
                                                local numKills = tonumber(numKillsString);
                                                
                                            
                                                --for first RoR choose the unit that got the most kills
                                                if grant_free_ror == true and free_ror == true then
                                                
                                                    if randomize_ror_choice then
                                                        local unit_object = {};
                                                        unit_object.unit = unit;
                                                        unit_object.cqi = unit:command_queue_index();
                                                        unit_object.unit_key = unit:unit_key();
                                                        unit_object.numKills = numKills;
                                                        table.insert(valid_units, #valid_units + 1, unit_object);
                                                        dynamic_ror_log("Adding unit "..unit:unit_key().." to valid units")
                                                    else
                                                        if valid_units[1] == nil then
                                                            local unit_object = {};
                                                            unit_object.unit = unit;
                                                            unit_object.cqi = unit:command_queue_index();
                                                            unit_object.unit_key = unit:unit_key();
                                                            unit_object.numKills = numKills;
                                                            valid_units[1] = unit_object;
                                                            dynamic_ror_log("Adding unit "..unit:unit_key().." to valid units")
                                                        else
                                                            if valid_units[1].numKills == nil or valid_units[1].numKills < numKills then
                                                                local unit_object = {};
                                                                unit_object.unit = unit;
                                                                unit_object.cqi = unit:command_queue_index();
                                                                unit_object.unit_key = unit:unit_key();
                                                                unit_object.numKills = numKills;
                                                                valid_units[1] = unit_object;
                                                                dynamic_ror_log("Adding unit "..unit:unit_key().." to valid units")
                                                            end
                                                        end 
                                                    end
                                            
                                                else
                                                                                                      
                                                    dynamic_ror_log("\tplayer modifier: " .. player_modifier);
                                                    dynamic_ror_log("\tbattle_modifier: " .. battle_modifier);
                                                    dynamic_ror_log("\tdamage_modifier: " .. damage_modifier);
                                                
                                                    ------------------------ COST MODIFIER --------------------------
                                                    
                                                    --increases or decreases minKills based on how much the unit costs in custom battles
                                                    local unit_cost = unit:get_unit_custom_battle_cost();
                                                    --dynamic_ror_log("\tunit_cost: " .. unit_cost);
                                                    
                                                    local unit_cost_modifier = 1
                                                    
                                                    --apply cap for units higher than base but still apply scalar to those lower
                                                    if unitCostFactor == 1 then
                                                        unit_cost_modifier = 1;
                                                    else
                                                        unit_cost_modifier = unitCostFactor - (unitCostFactor * baseUnitCostValue * (unitCostFactor - 1))/(unit_cost + (baseUnitCostValue * (unitCostFactor - 1)));
                                                    end 
                                                    
                                                    dynamic_ror_log("\tunit_cost_modifier: " .. unit_cost_modifier);
                                                    
                                                    -----------------------------------------------------------------
                                                    
                                                    ------------------------ HEALTH MODIFIER ------------------------
                                                    
                                                    local remaining_health_modifier ;
                                                    
                                                    --increases  or decreases minKills based on how much health the unit had left 
                                                    local remaining_health = unit:percentage_proportion_of_full_strength();
                                                    
                                                    dynamic_ror_log("\tremaining health: " .. remaining_health);
                                                    
                                                    remaining_health_modifier = unitHealthScalarMax -(math.pow(remaining_health - 100, 2)* (unitHealthScalarMax - unitHealthScalarMin))/10000;
                                                    
                                                    dynamic_ror_log("\tremaining_health_modifier: " .. remaining_health_modifier);
                                                    -----------------------------------------------------------------
                                                    
                                                    ------------------------ CLASS MODIFIER ------------------------
                                                    
                                                    local class_modifier = 1;
                                                    local unit_class = unit:unit_class();
                                                    
                                                    for _,class in pairs(Dynamc_RoR_Script_Data["missile_classes"]) do
                                                        if string.find(unit_class, class) then
                                                            class_modifier = missileScalar;
                                                            break;
                                                        end 
                                                    end 
                                                    
                                                    dynamic_ror_log("\tclass_modifier: " .. class_modifier);
                                                    
                                                    -----------------------------------------------------------------
                                                    
                                                    
                                                    ------------------------ Turn Modifier ------------------------
                                                    
                                                    --Calculate base min kills
                                                    local early_turn_modifier = 1;
                                                    
                                                    if earlyTurnThreshold > cm:turn_number() and earlyTurnScalar < 1 then
                                                        early_turn_modifier = 1 - ( math.pow(cm:turn_number() - 1 - earlyTurnThreshold, 2) * ( 1 - earlyTurnScalar ) ) / math.pow(earlyTurnThreshold, 2);
                                                    end 
                                                    
                                                    dynamic_ror_log("\tearly_turn_modifier: " .. early_turn_modifier);
                                                
                                                    --------------------------------------------------------------
                                                    
                                                    ------------------------ MINIMUM KILLS ------------------------
                                                    
                                                    --Calculate base min kills
                                                    local minKills = math.floor(((minKillsRankZero - minKillsRankNine) * math.pow((((10 * unit_rank) / 9) - 10), 2))/100 + minKillsRankNine);
                                                    
                                                    dynamic_ror_log("\tbase minimum kills needed: " .. minKills);
                                                
                                                    --------------------------------------------------------------
                                                    
                                                    
                                                    
                                                    --Calculate modifier
                                                    local modifier = player_modifier * damage_modifier * remaining_health_modifier * unit_cost_modifier * battle_modifier * class_modifier * early_turn_modifier;
                                                    
                                                    dynamic_ror_log("\tcombined modifier: " .. modifier);
                                                    
                                                    --Apply modifier
                                                    minKills = math.floor(minKills * modifier); 
                                                    
                                                    dynamic_ror_log("\tminimum kills needed: " .. minKills);
                                                    dynamic_ror_log("\tunit kill count: " .. numKills);
                                                    
                                                    if numKills >= minKills then
                                                        local unit_object = {};
                                                        unit_object.unit = unit;
                                                        unit_object.cqi = unit:command_queue_index();
                                                        unit_object.minKills = minKills;
                                                        unit_object.numKills = numKills;
                                                        unit_object.unit_key = unit:unit_key();
                                                        unit_object.contexts = {};
                                                        
                                                        if remaining_health < 0.4 then
                                                            table.insert(unit_object.contexts, #unit_object.contexts + 1, "survivor");
                                                        end 
                                                        
                                                        table.insert(valid_units, #valid_units + 1, unit_object);
                                                        dynamic_ror_log("\tAdding unit " .. unit:unit_key() .. " to valid units");
                                                    
                                                        if chosen_unit_object == nil then
                                                            chosen_unit_object = unit_object;
                                                        else 
                                                            if (chosen_unit_object.numKills - chosen_unit_object.minKills) < (unit_object.numKills - unit_object.minKills) then
                                                                chosen_unit_object = unit_object;
                                                            end
                                                        end 
                                                    
                                                    end 
                                                    
                                                end
                                            end
                                        
                                            index = index + 1;
                                        end
                                    end
--                                 else 
--                                     break;
                                --end
                            end 
                        end
                                
                        if #valid_units > 0 then
                        
                            dynamic_ror_log("valid units = "..table.tostring(valid_units))
                            
                            if chosen_unit_object == nil then
                                chosen_unit_object = valid_units[1];
                            end
                            
                            if #valid_units > 1 and randomize_ror_choice then
                                chosen_unit_object = valid_units[cm:random_number(#valid_units, 1)]
                            end
                            
                            --battle context
                            table.insert(battle_contexts, #battle_contexts + 1, battle_context);
                            
                            local battle_context_object = {};
                            battle_context_object["battle_contexts"] = battle_contexts;
                            battle_context_object["isAttacker"] = isAttacker;
                            battle_context_object["defender_culture_list"] = defender_culture_list or {};
                            battle_context_object["defender_faction_list"] = defender_faction_list or {};
                            battle_context_object["defender_subtype_list"] = defender_subtype_list or {};
                            battle_context_object["attacker_culture_list"] = attacker_culture_list or {};
                            battle_context_object["attacker_faction_list"] = attacker_faction_list or {};
                            battle_context_object["attacker_subtype_list"] = attacker_subtype_list or {};
                            battle_context_object["region_context"] = region_context or "";
                            
                            chosen_unit_object["is_player_unit"] = true;
                            
                            free_ror = false;
                            return dynamic_ror_make_unit_ror(chosen_unit_object, battle_context_object);
                        else
                            dynamic_ror_log("No valid units found!")
                        end
                        
                    end, 300)
                    
                end,
                true
            );
        else
                            
            --battle context
            table.insert(battle_contexts, #battle_contexts + 1, battle_context);
            
            local battle_context_object = {};
            battle_context_object["battle_contexts"] = battle_contexts;
            battle_context_object["isAttacker"] = isAttacker;
            battle_context_object["defender_culture_list"] = defender_culture_list or {};
            battle_context_object["defender_faction_list"] = defender_faction_list or {};
            battle_context_object["defender_subtype_list"] = defender_subtype_list or {};
            battle_context_object["attacker_culture_list"] = attacker_culture_list or {};
            battle_context_object["attacker_faction_list"] = attacker_faction_list or {};
            battle_context_object["attacker_subtype_list"] = attacker_subtype_list or {};
            battle_context_object["region_context"] = region_context or "";
                        
            local unit_object = {};
            local unit = valid_units[cm:random_number(#valid_units, 1)];
            unit_object.unit = unit;
            unit_object.cqi = unit:command_queue_index();
            unit_object.contexts = {};
            
            return dynamic_ror_make_unit_ror(unit_object, battle_context_object);
        end
    end
end


--- @function dynamic_ror_make_unit_ror 
--- @param unit unit_object
--- @param battle_context_object battle_context_object
--- @desc Adds effects and renames the provided unit based on the given contexts
function dynamic_ror_make_unit_ror(unit_object, battle_context_object)

    --wait for modded content to be ready before attempting to create RoR
    if modded_content_ready == false then
        core:add_listener(
            "DynamicRoRModdedContentReady_".. unit_object.cqi,
            "DynamicRoRModdedContentReady",
            true,
            function(context)
                dynamic_ror_log("DynamicRoRModdedContentReady_".. unit_object.cqi);
                dynamic_ror_make_unit_ror(unit_object, battle_context_object);
            end,
            true
        );
        return;
    end 

    local unit = unit_object.unit;
    
    if not unit or unit:is_null_interface() == true then
        if unit_object.cqi then
            unit = cm:model():unit_for_command_queue_index(unit_object.cqi)
        end 
    end 
    
    unit_object.cqi = unit:command_queue_index();
    
    
    if unit and unit:is_null_interface() == false then
        dynamic_ror_log("Creating RoR with unit: "..unit:unit_key());
    
        local effect_list = unit:get_unit_purchasable_effects();
        
        for j = 0, effect_list:num_items() - 1 do
            local effect_interface = effect_list:item_at(j);
            if string.find(effect_interface:record_key(), "dynamic_ror") then
                local purchased_effects = unit:get_unit_purchased_effects();
                if purchased_effects and purchased_effects:num_items() > 0 then
                    for k = 0, purchased_effects:num_items() - 1 do
                        if string.find(purchased_effects:item_at(k):record_key(), "dynamic_ror") then
                            dynamic_ror_log("ERROR: Unit "..unit:unit_key().." is already an RoR!")
                            return;
                        end
                    end
                end
                break;
            end
        end
        
        local enemy_contexts = {};
        local ally_contexts = {};
        local battle_contexts = {};
        local region_context = battle_context_object["region_context"];
        local isAttacker = battle_context_object["isAttacker"];
        local character = unit:force_commander();
        local character_subtype_key;
        
        if character and character:is_null_interface() == false then
            character_subtype_key = character:character_subtype_key();
        end 
        
        --Character Context
        if character_subtype_key and Dynamic_RoR_Legendary_Lord_Keywords[character_subtype_key] then
            for _, keyword in pairs(Dynamic_RoR_Legendary_Lord_Keywords[character_subtype_key]) do
                table.insert(battle_contexts, #battle_contexts + 1, keyword.."_lord");
            end
        end 
        
        --Culture Keywords
        for culture_key, _ in pairs(battle_context_object["defender_culture_list"]) do 
            for culture, word_list in pairs(Dynamic_RoR_Culture_Keywords) do
                if culture == culture_key then
                    for _, keyword in pairs(word_list) do
                        if isAttacker then
                            table.insert(enemy_contexts, #enemy_contexts + 1, keyword);
                        else
                            table.insert(ally_contexts, #ally_contexts + 1, keyword);
                        end
                    end
                end
            end
        end
        
        --Faction Keywords
        for faction_key, _ in pairs(battle_context_object["defender_faction_list"]) do 
            for faction, word_list in pairs(Dynamic_RoR_Faction_Keywords) do
                if faction == faction_key then
                    for _, keyword in pairs(word_list) do
                        if isAttacker then
                            table.insert(enemy_contexts, #enemy_contexts + 1, keyword);
                        else
                            table.insert(ally_contexts, #ally_contexts + 1, keyword);
                        end
                    end
                end
            end
        end
        
        --Legendary Lord Keywords
        for subtype_key, _ in pairs(battle_context_object["defender_subtype_list"]) do 
            for subtype, word_list in pairs(Dynamic_RoR_Legendary_Lord_Keywords) do
                if subtype == subtype_key then
                    for _, keyword in pairs(word_list) do
                        if isAttacker then
                            table.insert(enemy_contexts, #enemy_contexts + 1, keyword);
                        else
                            table.insert(ally_contexts, #ally_contexts + 1, keyword);
                        end
                    end
                end
            end
        end
        
        --Culture Keywords
        for culture_key, _ in pairs(battle_context_object["attacker_culture_list"]) do 
            for culture, word_list in pairs(Dynamic_RoR_Culture_Keywords) do
                if culture == culture_key then
                    for _, keyword in pairs(word_list) do
                        if isAttacker then
                            table.insert(ally_contexts, #ally_contexts + 1, keyword);
                        else
                            table.insert(enemy_contexts, #enemy_contexts + 1, keyword);
                        end
                    end
                end
            end
        end
        
        --Faction Keywords
        for faction_key, _ in pairs(battle_context_object["attacker_faction_list"]) do 
            for faction, word_list in pairs(Dynamic_RoR_Faction_Keywords) do
                if faction == faction_key then
                    for _, keyword in pairs(word_list) do
                        if isAttacker then
                            table.insert(ally_contexts, #ally_contexts + 1, keyword);
                        else
                            table.insert(enemy_contexts, #enemy_contexts + 1, keyword);
                        end
                    end
                end
            end
        end
        
        --Legendary Lord Keywords
        for subtype_key, _ in pairs(battle_context_object["attacker_subtype_list"]) do 
            for subtype, word_list in pairs(Dynamic_RoR_Legendary_Lord_Keywords) do
                if subtype == subtype_key then
                    for _, keyword in pairs(word_list) do
                        if isAttacker then
                            table.insert(ally_contexts, #ally_contexts + 1, keyword);
                        else
                            table.insert(enemy_contexts, #enemy_contexts + 1, keyword);
                        end
                    end
                end
            end
        end
        
        --add unit contexts
        if unit_object.contexts ~= nil then
            for i = 1, #unit_object.contexts do
                table.insert(battle_contexts, #battle_contexts + 1, unit_object.contexts[i]);
            end
        end 
        
        dynamic_ror_log("battle_contexts: ".. table.tostring(battle_contexts));
        dynamic_ror_log("ally_contexts: ".. table.tostring(ally_contexts));
        dynamic_ror_log("enemy_contexts: ".. table.tostring(enemy_contexts));
        dynamic_ror_log("region_context: ".. region_context);
        
        
        local ror_effects = {};
        
        ror_effects = dynamic_ror_get_ror_effects(unit, enemy_contexts, ally_contexts, battle_contexts, region_context);
        
        dynamic_ror_log("   Effects to add: "..table.tostring(ror_effects));
        
        if not table.empty(ror_effects) then
        
            if increase_unit_rank then
                cm:add_experience_to_unit(unit, 9);
            end 
        
            local effect_list = unit:get_unit_purchasable_effects();
            
            unit_object.effect_list = {};
            unit_object.purchased_effects = {};
         
            for i = 0, effect_list:num_items() - 1 do
                local effect_interface = effect_list:item_at(i);
                
                if ror_effects[effect_interface:record_key()] then	
    
                    dynamic_ror_log("adding "..effect_interface:record_key().." to unit "..unit:unit_key().." in army belonging to "..common.get_localised_string(character:get_forename()).." "..common.get_localised_string(character:get_surname()));
                    cm:faction_set_unit_purchasable_effect_lock_state(character:faction(), effect_interface:record_key(), effect_interface:record_key(), false);
                    cm:faction_purchase_unit_effect(character:faction(), unit, effect_interface);
                    cm:faction_set_unit_purchasable_effect_lock_state(character:faction(), effect_interface:record_key(), effect_interface:record_key(), true);
                    
                    table.insert(unit_object.effect_list, #unit_object.effect_list + 1, effect_interface:record_key());
                end
            end
        else
            out("Dynamic RoR creation failed!")
            return;
        end
        
        if rename_units then
            local unit_name = dynamic_ror_generate_unit_name(unit_object);
            
            if unit_name then
                dynamic_ror_log("Renaming unit with key: "..unit:unit_key().." to " .. unit_name);
                cm:change_custom_unit_name(unit, unit_name);
                dynamic_ror_log("Unit succesfully renamed " .. unit_name);
            else
                --only do error debug rename if player unit
                if unit_object["is_player_unit"] then
                    unit_name = "ERROR RENAME ME PLEASE";
                    dynamic_ror_log("Renaming unit with key: "..unit:unit_key().." to " .. unit_name);
                    cm:change_custom_unit_name(unit, unit_name);
                    dynamic_ror_log("Unit succesfully renamed " .. unit_name);
                end
            end
            
            unit_object.generated_name = unit_name;
        end
        
        unit_object.unit = nil; --clear interface reference
        
        table.insert(saved_rors, #saved_rors + 1, unit_object);
        
        out("Dynamic RoR object created: \n\t" .. table.tostring(unit_object));
        
        if event_on_ror and unit_object["is_player_unit"] then
            local faction = unit:faction();
            local mf = unit:military_force();
            local ch = unit:force_commander();
            
            --dynamic_ror_log("character subtype = ".. ch:character_subtype_key())
            --dynamic_ror_log("character cqi = ".. ch:command_queue_index())
            
            --cm:trigger_incident(faction:name(), "nanu_dynamic_ror_incident_ror_created_no_target", true);
            cm:trigger_incident_with_targets(faction:command_queue_index(), "nanu_dynamic_ror_incident_ror_created", 0, 0, ch:command_queue_index(), 0, 0, 0);
        end
        
        return unit_object;
    else
        out("Dynamic RoR creation failed!")
    end
end
  
--- @function dynamic_ror_get_ror_effects
--- @param unit UNIT_SCRIPT_INTERFACE
--- @param enemy_contexts string []
--- @param ally_contexts string []
--- @param battle_contexts string []
--- @param region_context string
--- @desc Returns a list of effects to be applied to the provided unit based on the given contexts
function dynamic_ror_get_ror_effects(unit, enemy_contexts, ally_contexts, battle_contexts, region_context)
   
    local output_effects = {};
    
    local effect_data_object = {
        ["contexts"] = {
            ["enemy_contexts"] = enemy_contexts or {},
            ["ally_contexts"] = ally_contexts or {},
            ["battle_contexts"] = battle_contexts or {},
            ["climate_contexts"] = {},
        }
    };
    
    dynamic_ror_log("keywords:"..table.tostring(battle_contexts))

    if unit and unit:is_null_interface() == false then
        local character = unit:force_commander();
        
        dynamic_ror_log("region_context: ".. region_context);
        local region = cm:get_region(region_context);
        
        if region and region:is_null_interface() == false then
            local settlement = region:settlement();
            if settlement and settlement:is_null_interface() == false then
                table.insert(effect_data_object["contexts"]["climate_contexts"], #effect_data_object["contexts"]["climate_contexts"] + 1, settlement:get_climate());
            end
        else 
            if character and character:is_null_interface() == false then
                if character:sea_region() and character:sea_region():is_null_interface() == false then
                    table.insert(effect_data_object["contexts"]["climate_contexts"], #effect_data_object["contexts"]["climate_contexts"] + 1, "climate_ocean");
                end 
            end 
        end 
        
        dynamic_ror_log("battle_contexts: "..table.tostring(effect_data_object["contexts"]["battle_contexts"]))
        dynamic_ror_log("ally_contexts: "..table.tostring(effect_data_object["contexts"]["ally_contexts"]))
        dynamic_ror_log("enemy_contexts: "..table.tostring(effect_data_object["contexts"]["enemy_contexts"]))
        dynamic_ror_log("climate_contexts: "..table.tostring(effect_data_object["contexts"]["climate_contexts"]))

        dynamic_ror_log("");
        dynamic_ror_log("---------------------------------------------");
        dynamic_ror_log("");
        
        
        effect_data_object["effect_lists"] = {};
        local effect_list = unit:get_unit_purchasable_effects();

        for i = 0, effect_list:num_items() - 1 do
            local effect_interface = effect_list:item_at(i);
            local effect_key = effect_interface:record_key();
            
            if string.find(effect_key, "dynamic_ror") then
                --dynamic_ror_log("effect to add: ".. effect_key);
                
                for index, data in pairs(Dynamc_RoR_Script_Data["effect_keywords"]) do
                
                    if data["is_effect_type"] then
                    
                        local effect_keyword = data["keyword"];
                        local search_text = "_" .. effect_keyword .. "_";
                        local table_name = effect_keyword .. "_effects";
                        
                        if not effect_data_object["effect_lists"][table_name] then
                            --dynamic_ror_log("\t Adding effect list for effect_keyword: " .. effect_keyword)
                            effect_data_object["effect_lists"][table_name] = {};
                            effect_data_object["has_" .. effect_keyword .. "_effect"] = false;
                        end 
                        
                        if string.find(effect_key, search_text) then
                        
                            local add_effect = true;
                            
                            --Contexts
                            if data["has_contexts"] then
                                
                                for context, context_data in pairs(Dynamc_RoR_Script_Data["effect_context_keywords"]) do
                                    
                                    if add_effect == false then
                                        break;
                                    end 
                                    
                                    local context_table_name = context_data["table_name"];

                                    if string.find(effect_key, context) then
                                        --dynamic_ror_log("\t\t Found context \"" .. context .. "\"! Checking context list: " .. context_table_name .. "...")
                                        add_effect = false;
                                        for _, keyword in pairs(effect_data_object["contexts"][context_table_name]) do
                                        
                                            if context_data["format"] == "keyword_context" then
                                                search_text = keyword .. "_" ..  context;
                                            elseif context_data["format"] == "context_keyword" then
                                                search_text = context .. "_" ..  keyword;
                                            else
                                                add_effect = false;
                                                break;
                                            end 
                                            
                                            
                                            --dynamic_ror_log("\t\t\t searching for context \"" .. search_text .. "\" in effect key: \"" .. effect_key .. "\"...")
                                        
                                            if string.find(effect_key, search_text)  then
                                                --dynamic_ror_log("\t\t\t context \"" .. search_text .. "\" found in " .. context_table_name .. "!")
                                                add_effect = true;
                                                break;
                                            end
                                        end
                                    end
                                end 
                            end 
                        
                            if add_effect then
                                table.insert(effect_data_object["effect_lists"][table_name], #effect_data_object["effect_lists"][table_name] + 1, effect_key);
                            end 
                            break;
                        end 
                    end 
                end 
            end
        end
        
        for table_name, list in pairs(effect_data_object["effect_lists"]) do
            dynamic_ror_log(table_name .. ":".. table.tostring(list));
        end 
        
        local scripted_ammo_effects = effect_data_object["effect_lists"]["scripted_ammo_type_effects"]; --scripted ammo types have special logic
        local ammo_damage_type = "";
        local ammo_visual_type = "";
        local base_chance = 25;
        local roll;
        local chance;
        local base_effect_weight = 15;
        
        for index, data in pairs(Dynamc_RoR_Script_Data["effect_keywords"]) do
            
            local keyword = data["keyword"];
            
            if data["is_effect_type"] and keyword ~= "scripted_ammo_type" then
                
                local table_name = keyword .. "_effects";
                local max_allowed = data["max_allowed"] or 1;
                local weight = (data["weight"] or 0);
                
                for i = 1, max_allowed do
                
                    effect_list = effect_data_object["effect_lists"][table_name];
                
                    dynamic_ror_log("\t base_chance: " .. base_chance);
                    dynamic_ror_log("\t " .. table_name .. " length: " .. #effect_list);
                    dynamic_ror_log("\t " .. table_name .. " weight: " .. weight);
                    
                    local effect_list_chance = #effect_list * 5;
                    
                    dynamic_ror_log("\t " .. table_name .. " chance: " .. effect_list_chance);
                
                    if #effect_list <= 0 then
                        dynamic_ror_log(table_name .. " is empty! adjusting base chance " .. base_chance .. " by " .. weight);
                        base_chance = base_chance + weight;
                        break;
                    end
                    
                    roll = cm:random_number(100, 1);
                    chance = math.min(base_chance + #effect_list * 5, 95);
                    
                    dynamic_ror_log(keyword .. " effect roll: ".. roll ..", chance: " .. chance);
                    
                    if roll <= chance then
                        local effect = effect_list[cm:random_number(#effect_list, 1)];
                        
                        dynamic_ror_log("Roll succeeded!");
                        local base_weight = base_effect_weight * table.length(output_effects);
                        
                        if base_weight > 0 then
                            dynamic_ror_log("\t adjusting base chance " .. base_chance .. " by -" .. base_weight .. " from effect count");
                            base_chance = base_chance - base_weight;
                        end 
                    
                        dynamic_ror_log(" adding " .. keyword .. " effect: " .. effect);
                        output_effects[effect] = true;
                        
                        
                        dynamic_ror_log("\t adjusting base chance " .. base_chance .. " by -" .. weight .. " from effect keyword: " .. keyword);
                        
                        base_chance = base_chance - weight;
                        effect_data_object["has_" .. keyword .. "_effect"] = true;
                        
                        --Ammo Types
                        local ammo_type_string = "";
                        
                        if string.find(effect, "_ammo_type_") then
                            has_ammo_effect = true;
                        
                            --only do scripted ammo logic for units that have scripted ammo effects
                            if #effect_data_object["effect_lists"][table_name] > 0 then
                                ammo_type_string = string.match(effect, "_ammo_type_(.*)$");
                                if ammo_type_string and ammo_type_string ~= "" then
                                    
                                    for key, ammo_data in pairs(Dynamc_RoR_Script_Data["ammo_visual_types"]) do
                                        if string.find(ammo_type_string, key) then
                                            if ammo_data["combined_visual_types"] and ammo_visual_type and ammo_visual_type ~= "" and ammo_visual_type ~= key then
                                                for base_visual_type, combined_visual_type in pairs(ammo_data["combined_visual_types"]) do 
                                                    if ammo_visual_type == base_visual_type then
                                                        ammo_visual_type = combined_visual_type;
                                                    end 
                                                end 
                                            else
                                                ammo_visual_type = key;
                                            end 
                                            break;
                                        end 
                                    end 
                                    
                                    for key, ammo_data in pairs(Dynamc_RoR_Script_Data["ammo_damage_types"]) do
                                        if string.find(ammo_type_string, key) then
                                            ammo_damage_type = key;
                                            break;
                                        end 
                                    end 
                                else
                                    ammo_type_string = "";
                                end
                            end
                        end
                        
                        --apply exclusion
                        if data["exclusive"] then
                            effect_data_object["effect_lists"][table_name] = {};
                        end 
                        
                        --Filter other effect lists
                        local filters = {};
                        
                        if data["exclusive"] or data["do_exclusion_logic"] then
                            
                            dynamic_ror_log("\t Running exclusion logic... ");
                            dynamic_ror_log("\t\t Generating filter list...");
                            
                            for j = 0, 1 do
                            
                                for k = index, #Dynamc_RoR_Script_Data["effect_keywords"] do
                                
                                    local effect_data = Dynamc_RoR_Script_Data["effect_keywords"][k];
                                    local effect_keyword = effect_data["keyword"];
                                    local effect_table_name = effect_keyword .. "_effects";
                                    local search_text = "_" .. effect_keyword .. "_";
                                    
                                    if not effect_data["ignore_filters"] then
                                    
                                        --create filter list, apply base change weights, clear exclusive effects
                                        if j == 0 then
                                            if string.find(effect, search_text) then
                                                effect_data_object["has_" .. effect_keyword .. "_effect"] = true;
                                                
                                                --apply weights
                                                if k == index then
                                                    dynamic_ror_log("\t\t\t base chance already adjusted for effect " .. effect_keyword .. ", skipping...")
                                                else
                                                    
                                                    local effect_weight = (effect_data["weight"] or 0);
                                                    dynamic_ror_log("\t\t\t adjusting base chance " .. base_chance .. " by -" .. effect_weight .. " from effect keyword: " .. effect_keyword);
                                                    base_chance = base_chance - effect_weight;
                                                end 
                                                
                                                if effect_data["exclusive"] then
                                                
                                                    --add to filter list
                                                    --dynamic_ror_log("\t\t Adding \"" .. effect_keyword .. "\" to filter list");
                                                    table.insert(filters, #filters + 1, effect_keyword)
                                                    
                                                    --clear exclusive effects
                                                    effect_data_object["effect_lists"][effect_table_name] = {};
                                                end 
                                            end
                                        --apply filter lsit
                                        else 
                                            local table_to_filter_name = effect_table_name;
                                            local effects_to_check = effect_data_object["effect_lists"][table_to_filter_name];
                                            
                                            if effects_to_check and #effects_to_check > 0 then
                                                dynamic_ror_log("\t\t Applying filters to " .. table_to_filter_name);
                                                local temp_effect_list = {};
                                                
                                                for _, e in pairs(effects_to_check) do 
                                                    local keep_effect = true;
                                                    
                                                    dynamic_ror_log("\t\t\t Checking effect: \"" .. e .. "\"");
                                                    
                                                    --basic filter
                                                    for _, filtered_keyword in pairs(filters) do
                                                        if string.find(e, filtered_keyword) then
                                                            dynamic_ror_log("\t\t\t\t Found : \"" .. filtered_keyword .. "\"!");
                                                            keep_effect = false;
                                                            break;
                                                        end 
                                                    end 
                                                    
                                                    --damage filter
                                                    if keep_effect then
                                                        for damage_type_key, damage_type_data in pairs(Dynamc_RoR_Script_Data["damage_types"]) do
                                                            if (string.find(effect, damage_type_key)) then
                                                                for exclusive_type,_ in pairs(damage_type_data["exclusive_damage_types"]) do
                                                                    if string.find(e, exclusive_type) then
                                                                        --dynamic_ror_log("\t\t\t Found : \"" .. exclusive_type .. "\"!");
                                                                        keep_effect = false;
                                                                        break;
                                                                    end 
                                                                end 
                                                            end
                                                        end 
                                                    end
                    
                                                    --ammo filter
                                                    if keep_effect and #scripted_ammo_effects > 0 and string.find(e, "_ammo_type_") then
                                                    
                                                        --filter exclusive visual types
                                                        if ammo_visual_type ~= "" then
                                                            for ammo_type_key, ammo_data in pairs(Dynamc_RoR_Script_Data["ammo_visual_types"]) do
                                                                if ammo_visual_type == ammo_type_key and ammo_data["exclusive_visual_types"] then
                                                                    for exclusive_type,_ in pairs(ammo_data["exclusive_visual_types"]) do
                                                                        if(string.find(ammo_type_string, exclusive_type)) then
                                                                            --dynamic_ror_log("\t\t\t Found : \"" .. exclusive_type .. "\"!");
                                                                            keep_effect = false;
                                                                            break;
                                                                        end 
                                                                    end 
                                                                end 
                                                            end 
                                                        end
                                                            
                                                        --ensure only one ammo type. TODO: make combined ammo types with similar logic to visual types
                                                        if keep_effect and ammo_damage_type ~= "" then
                                                            for ammo_type_key,_ in pairs(Dynamc_RoR_Script_Data["ammo_damage_types"]) do
                                                                if (string.find(e, ammo_type_key)) then
                                                                    --dynamic_ror_log("\t\t\t Found : \"" .. ammo_type_key .. "\"!");
                                                                    keep_effect = false;
                                                                    break;
                                                                end
                                                            end 
                                                        end
                                                    end  
                                                        
                                                    if keep_effect then 
                                                        table.insert(temp_effect_list, #temp_effect_list + 1, e);
                                                    else
                                                        dynamic_ror_log("\t\t\t\t Removing effect..." );
                                                    end
                                                end 
                                                effect_data_object["effect_lists"][effect_table_name] = temp_effect_list;
                                            end
                                        end 
                                    end 
                                end 
                            end 
                        end 
                        
                    else 
                        dynamic_ror_log("\t Roll failed to meet chance! adjusting base chance " .. base_chance .. " by " .. weight + base_effect_weight);
                        base_chance = base_chance + weight + base_effect_weight;
                    end 
                end 
            end 
            
        end 
        
        if #scripted_ammo_effects > 0 and (ammo_damage_type ~= "" or ammo_visual_type ~= "") then
            local effect = "nanu_dynamic_ror_scripted_ammo_type";
            
            dynamic_ror_log("scripted_ammo_effects:" .. table.tostring(scripted_ammo_effects));
            
            dynamic_ror_log("ammo_damage_type: " .. ammo_damage_type);
            dynamic_ror_log("ammo_visual_type: " .. ammo_visual_type);
            
            if ammo_damage_type ~= "" then
            
                local effect_key = effect .. "_" .. ammo_damage_type;
                dynamic_ror_log("\tchecking for scripted effect: " .. effect_key);
                
                if table.check_value(scripted_ammo_effects, effect_key) then
                    dynamic_ror_log("\tFound!");
                    effect = effect_key;
                
                    if ammo_visual_type ~= "" then
                    
                        effect_key = effect_key .. "_" .. ammo_visual_type;
                        dynamic_ror_log("\tchecking for scripted effect: " .. effect_key);
                    
                        if table.check_value(scripted_ammo_effects, effect_key) then
                            dynamic_ror_log("\tFound!");
                            effect = effect_key;
                        end 
                    end 
                else
                    effect_key = effect .. "_" .. ammo_visual_type;
                    dynamic_ror_log("\tchecking for scripted effect: " .. effect_key);
                    
                    --only apply scripted effect if exists
                    if table.check_value(scripted_ammo_effects, effect_key) then
                        dynamic_ror_log("\tFound!");
                        effect = effect_key;
                    end
                end
                
            else
                if ammo_visual_type ~= "" then
                    
                    local effect_key = effect .. "_" .. ammo_visual_type;
                    dynamic_ror_log("\tchecking for scripted effect: " .. effect_key);
                    
                    --only apply scripted effect if exists
                    if table.check_value(scripted_ammo_effects, effect_key) then
                        dynamic_ror_log("\tFound!");
                        effect = effect_key;
                    end
                end
            end
            
            if table.check_value(scripted_ammo_effects, effect) then
            
                output_effects[effect] = true;
                
                dynamic_ror_log("scripted_ammo_effect: " .. effect)
                
                --remove generic ammo effect
                for e,_ in pairs(output_effects) do
                   if string.find(e, "dynamic_ror_ranged_ammo_type") then
                       output_effects[e] = nil;
                   end 
                end 
            end
        end 
    end
    
    return output_effects
end      

--- @function dynamic_ror_generate_unit_name
--- @param unit UNIT_SCRIPT_INTERFACE
--- @desc Returns a name for the unit provided based on the purchased effects applied to it
function dynamic_ror_generate_unit_name(unit_object)

    local unit = unit_object.unit;
    local ror_effect_list = unit_object.effect_list

    if unit and unit:is_null_interface() == false then
    
        local character = unit:force_commander();
        local region = character:region();
        local faction = character:faction();
        local region_key;
        
        if region and region:is_null_interface() == false then
            region_key = region:name();
            
            dynamic_ror_log("region_key: ".. region_key);
            dynamic_ror_log("region name: ".. common.get_localised_string("regions_onscreen_".. region_key));
        else
            if character:sea_region() and character:sea_region():is_null_interface() == false then
                region = character:sea_region();
                region_key = region:name();
            end 
        end 
        
        if faction:is_null_interface() or character:is_null_interface() then
            dynamic_ror_log("ERROR: faction or character are null")
            return nil;
        end
        
        
        local keywords = {};
        
        ---------- BASIC KEYWORDS ----------
        keywords["basic"] = true;
        --------------------------------
        
        ---------- CULTURE KEYWORDS ----------
        local is_greenskin = false; --used to replace  "The" with "Da" for generated name
        
        local culture_keywords = {};
        table.insert(culture_keywords, #culture_keywords + 1, "basic");
        for _, keyword in pairs(Dynamic_RoR_Culture_Keywords[character:faction():culture()]) do
            table.insert_if_absent(culture_keywords, keyword);
            
            if string.find(keyword, "greenskin") then
                is_greenskin = true;
            end 
        end
        --------------------------------
        
        ---------- FACTION KEYWORDS ----------
        if Dynamic_RoR_Faction_Keywords[character:faction():name()] then 
            for _, keyword in pairs(Dynamic_RoR_Faction_Keywords[character:faction():name()]) do
                table.insert_if_absent(culture_keywords, keyword);
                
                if string.find(keyword, "greenskin") then
                    is_greenskin = true;
                end 
            end
        end 
        --------------------------------------
        
        ---------- UNIT KEYWORDS ----------
        
        --add unit class
        keywords[unit:unit_class()] = true;
        local is_single_entity = false;
        
        --some units have specific keywords associated with them that aren't in their key
        if Dynamic_RoR_Unit_Keywords[unit:unit_key()] then
            for i = 1, #Dynamic_RoR_Unit_Keywords[unit:unit_key()] do
                local keyword = Dynamic_RoR_Unit_Keywords[unit:unit_key()][i];
            
                if string.find(keyword, "culture_") then
                    table.insert(culture_keywords, #culture_keywords + 1, string.gsub(keyword, "culture_", ""));
                else
                    keywords[keyword] = true;
                    
                    if keyword == "arcane_fire" then
                        keywords["magic_attacks"] = true;
                        keywords["flaming_attacks"] = true;
                    end 
                    
                                
                    if keyword == "single_entity" then
                        is_single_entity = true;
                    end 
                end 
            end 
        end 
        --------------------------------
        
        ---------- LORD SUBTYPE ----------
        local lord_subtype = character:character_subtype_key();
        
        keywords[lord_subtype] = true; 
        
        if Dynamic_RoR_Legendary_Lord_Keywords[lord_subtype] then
            for _, keyword in pairs(Dynamic_RoR_Legendary_Lord_Keywords[lord_subtype]) do
                table.insert_if_absent(culture_keywords, keyword);
            end
        end 
        --------------------------------
        
        
        ---------- GENERATE KEYWORD LIST -----------
        
        dynamic_ror_log("Culture Keywords "..table.tostring(culture_keywords));
        
        for i = 1, #ror_effect_list do
            local effect_key = ror_effect_list[i];
            
            for word_type, word_list in pairs(Dynamic_RoR_NameData) do
                for j = 1, #culture_keywords do
                    local culture_keyword = culture_keywords[j];
                    --dynamic_ror_log("\tChecking for culture: "..culture_keyword.." in effect "..effect_key);
                    if word_list[culture_keyword] then
                        --dynamic_ror_log("       Checking Word List: "..table.tostring(word_list[culture_keyword]));
                        for key, names in pairs(word_list[culture_keyword]) do
                            if keywords[key] == nil and string.find(effect_key, key) then
                                --dynamic_ror_log("\t\tFound keyword "..key.." in effect "..effect_key)
                                keywords[key] = true;
                    
                                if keyword == "arcane_fire" then
                                    keywords["magic_attacks"] = true;
                                    keywords["flaming_attacks"] = true;
                                end 
                            end
                            
                            --unit keywords
                            if keywords[key] == nil then
                                local k = key;
                                
                                if string.find(key, "_unit") then
                                    k = string.gsub(key, "_unit", "")
                                end 
                                    
                                if string.find(unit:unit_key(), k) then
                                    keywords[key] = true;
                        
                                    if keyword == "arcane_fire" then
                                        keywords["magic_attacks"] = true;
                                        keywords["flaming_attacks"] = true;
                                    end 
                                end
                            end
                        end
                    end
                end
            end
        end
        
        dynamic_ror_log("Keyword generation finished: "..table.tostring(keywords));
        ---------------------------------------------
        
        ---------- GET ADJECTIVES ---------
        
        local adjective_list = {}; 
        
        for i = 1, #culture_keywords do
            local culture = Dynamic_RoR_NameData.adjective[culture_keywords[i]];
            if culture then
                for keyword, adjectives in pairs(culture) do
                    if keywords[keyword] then
                        for _, adjective in pairs(adjectives) do
                            table.insert(adjective_list, #adjective_list, adjective);
                        end
                    end
                end 
            end
        end
        
        local prefix_list = {};
        local suffix_list = {};
        
        local location_prefix_list = {};
        local location_suffix_list = {};
        
        local possessive_prefix_list = {};
        local possessive_suffix_list = {};
        
        
        ---------- LOCATION ---------------
        
        if region_key and Dynamic_RoR_Region_Data[region_key] then
            local region_data = Dynamic_RoR_Region_Data[region_key];
            
            --handle arrays or objects
            for _, location in pairs(region_data) do
                if location.prefix then
                    table.insert(location_prefix_list, #location_prefix_list + 1, location);
                end
                
                if location.suffix then 
                    table.insert(location_suffix_list, #location_suffix_list + 1, location);
                end 
            end 
        else
            if region and region:is_null_interface() == false then
                region_name = common.get_localised_string("regions_onscreen_".. region_key);
                
                --exclude regions with 'of' (long and clunky)
                if not string.find(string.lower(region_name), "of ") then
                
                    local location = {
                        suffix = "of ".. region_name,
                        prefix = region_name,
                        is_location = true,
                    };
                    
                    if string.find(region_name, "The ") then
                        location.suffix = "of the "..string.gsub(region_name, "The ", "");
                        location.prefix = string.gsub(region_name, "The ", "");
                    end
                    
                    table.insert(location_prefix_list, #location_prefix_list + 1, location);
                    table.insert(location_suffix_list, #location_suffix_list + 1, location);
                end
            end 
        end 
        
        -----------------------------------
        
        ---------- LORD NAME ---------------
        local lord_name;
        local forename = common.get_localised_string(character:get_forename());
        local surname = common.get_localised_string(character:get_surname());
            
        if surname ~= "" then
            --no "the Bloody" or "the Magnificent," only real last names
            if not string.find(string.lower(surname), "the ") then
            
                --make sure capital letter is uppercase
                surname = surname:sub(1,1):upper()..surname:sub(2);
                local lord_name_adjective = {
                    prefix = surname..'\'s',
                    is_possessive = true,
                    is_lord_name = true
                };
                
                table.insert(possessive_prefix_list, #possessive_prefix_list + 1, lord_name_adjective);
            end
        end
            
        if forename ~= "" then
            local lord_name_adjective = {
                prefix = forename.." "..surname..'\'s',
                is_possessive = true,
                is_lord_name = true
            };
            
            table.insert(possessive_prefix_list, #possessive_prefix_list + 1, lord_name_adjective);
        end
        
        -----------------------------------
        
        if adjective_list then
            
            --dynamic_ror_log("Adjective List: ".. table.tostring(adjective_list));
            
            for j = 1, #adjective_list do
                local adjective = adjective_list[j];
                local add_to_list = true;
                
                --Some adjectives have culture requirements
                if adjective.required_cultures then
                    add_to_list = false;
                    for _, culture in pairs(adjective.required_cultures) do
                        for k, culture_keyword in pairs(culture_keywords) do
                            if culture == culture_keyword then
                                add_to_list = true;
                                break;
                            end
                        end
                        
                        if add_to_list == true then
                            break;
                        end
                    end
                end
                
                --Some adjectives have further keyword requirements
                if adjective.keywords then
                    add_to_list = false;
                    for _, k in pairs(adjective.keywords) do
                    
                        --check keywords
                        for _, keyword in pairs(keywords) do 
                            if k == keyword then
                                --dynamic_ror_log("found "..k.." in "..table.tostring(adjective.keywords))
                                add_to_list = true; 
                                break;
                            end
                        end 
                        
                        --check effects
                        if add_to_list == false then
                            for _, v in pairs(ror_effect_list) do 
                                --dynamic_ror_log("found "..k.." in "..v)
                                if string.find(v, k) then
                                    add_to_list = true;
                                    break;
                                end
                            end
                        end
                        
                        --check unit key
                        if add_to_list == false and string.find(unit:unit_key(), k) then
                            add_to_list = true; 
                            break;
                        end 
                    end
                end
                
                --Blacklisted keywords
                if adjective.blacklisted_keywords then
                    for _,k  in pairs(adjective.blacklisted_keywords) do
                        for _, v in pairs(keywords) do 
                            if k == v then
                                add_to_list = false;
                                break;
                            end
                        end
                        
                        --check effects
                        if add_to_list == true then
                            for _, v in pairs(ror_effect_list) do 
                                if string.find(v, k) then
                                    add_to_list = false;
                                    break;
                                end
                            end
                        end
                    
                        --check unit key
                        if add_to_list == true and string.find(unit:unit_key(), k) then
                            add_to_list = false; 
                            break;
                        end 
                    end
                end
                
                --Blacklisted cultures
                if adjective.blacklisted_cultures then
                    for _,k in pairs(adjective.blacklisted_cultures) do
                        for _, v in pairs(culture_keywords) do 
                            if k == v then
                                add_to_list = false;
                                break;
                            end
                        end
                    end
                end
                
                if add_to_list == true then
                    
                    --dynamic_ror_log("adjective to add: ".. table.tostring(adjective));
                
                    if adjective.is_possessive then
                        if adjective.prefix then
                            table.insert(possessive_prefix_list, #possessive_prefix_list + 1, adjective);
                        end
                        if adjective.suffix then
                            table.insert(possessive_suffix_list, #possessive_suffix_list + 1, adjective);
                        end
                    elseif adjective.is_location then
                        if adjective.prefix then
                            table.insert(location_prefix_list, #location_prefix_list + 1, adjective);
                        end
                        if adjective.suffix then
                            table.insert(location_suffix_list, #location_suffix_list + 1, adjective);
                        end
                    else
                        if adjective.prefix then
                            table.insert(prefix_list, #prefix_list + 1, adjective);
                        end
                        if adjective.suffix then
                            table.insert(suffix_list, #suffix_list + 1, adjective);
                        end
                    end
                end
            end
        end
        
        --dynamic_ror_log("prefix_list: ".. table.tostring(prefix_list));
        --dynamic_ror_log("suffix_list: ".. table.tostring(suffix_list));
        --dynamic_ror_log("location_prefix_list: "..table.tostring(location_prefix_list));
        --dynamic_ror_log("location_suffix_list: "..table.tostring(location_suffix_list));
        --dynamic_ror_log("possessive_prefix_list: "..table.tostring(possessive_prefix_list));
        --dynamic_ror_log("possessive_suffix_list: "..table.tostring(possessive_suffix_list));
        
        ---------------------------------------
        
        ---------- CULTURE NOUNS -------------
        
        local culture_noun_list = {};
        
        for i = 1, #culture_keywords do
            local culture = Dynamic_RoR_NameData.noun[culture_keywords[i]];
            if culture then
                for keyword, nouns in pairs(culture) do
                    if not culture_noun_list[keyword] then
                        culture_noun_list[keyword] = {};
                    end
                    
                    for j = 1, #nouns do
                        table.insert(culture_noun_list[keyword], #culture_noun_list[keyword] + 1, nouns[j])
                    end
                end
            end
        end
        
        --------------------------------------
        
        ---------- GENERATE NOUN LIST ----------
        
        local noun_list = {};
        local max_noun_roll = 0;
        
        for keyword,_ in pairs(keywords) do
            
            if keyword then
                --dynamic_ror_log("searching for keyword "..keyword);
                
                
                ------ CULTURE NOUNS -------
                if culture_noun_list[keyword] then
                
                    local list = culture_noun_list[keyword];
                    
                    --make sure this is an indexed table
                    if culture_noun_list[keyword] and table.empty(culture_noun_list[keyword]) == false then
                        local nouns = culture_noun_list[keyword];
                        for j = 1, #nouns do
                            local item = nouns[j];
                            local add_word = true;
                            
                            --Only add word to single entity if it has a non plural variant
                            if is_single_entity and not item.noun_single then
                                add_word = false;
                            end
                            
                            --keyword requirements (only one needed)
                            if item.keywords and add_word == true then
                                --dynamic_ror_log("required keywords = "..table.tostring(item));
                                add_word = false;
                                for _,k in pairs(item.keywords) do
                                    if add_word == false then
                                        for _, v in pairs(keywords) do 
                                            if k == v then
                                                add_word = true;
                                                break;
                                            end
                                        end
                                        
                                        if add_word == false then
                                            --not all keywords are pulled into keyword list, some are specific to requiremets/exclusions
                                            for _, v in pairs(ror_effect_list) do 
                                                if string.find(v, k) then
                                                    add_word = true;
                                                    break;
                                                end
                                            end
                                        end
                                        
                                        if add_word == false then
                                            --some nouns have unit key specific keywords
                                            if string.find(unit:unit_key(), k) then
                                                add_word = true;
                                                break;
                                            end
                                        end
                                    end
                                end
                            end
                            
                            --Blacklisted keywords
                            if item.blacklisted_keywords and add_word == true  then
                            
                                for _, k in pairs(item.blacklisted_keywords) do
                                    for _, v in pairs(keywords) do 
                                        if k == v then
                                            add_word = false;
                                            break;
                                        end 
                                    end 
                                    
                                    --check effects
                                    if add_word == true then
                                        for _, v in pairs(ror_effect_list) do 
                                            if string.find(v, k) then
                                                add_word = false;
                                                break;
                                            end 
                                        end 
                                    end 
                                    
                                    --check unit key
                                    if add_word == true and string.find(unit:unit_key(), k) then
                                        add_word = false;
                                        break;
                                    end 
                                end 
                            end 
                            
                            --Required cultures
                            if item.required_cultures and add_word == true  then
                                add_word = false;
                                for _,k in pairs(item.required_cultures) do
                                    for _, v in pairs(culture_keywords) do 
                                        if k == v then
                                            add_word = true;
                                            break;
                                        end
                                    end
                                end
                            end
                            
                            if add_word then
                                local noun_object = {};
                                for key, value in pairs(item) do
                                    noun_object[key] = value;
                                end
                                
                                noun_object["prefix_list"] = {};
                                noun_object["suffix_list"] = {};
                                noun_object["max_prefix_roll"] = 0;
                                noun_object["max_suffix_roll"] = 0;
                                
                                if noun_object["adjective_pos"] == "both" or noun_object["adjective_pos"] == "prefix" then
                                    for i = 1, #prefix_list do 
                                        local adjective = prefix_list[i];
                                        local add_adjective = true;
                                        local weight = 4;
                                        
                                        if adjective["weight"] then
                                            weight = adjective["weight"];
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["blacklisted_noun_types"] then
                                            for k, _ in pairs(adjective["blacklisted_noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = false;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["noun_types"] and not table.empty(adjective["noun_types"]) then
                                            add_adjective = false;
                                            
                                            for _, k in pairs(adjective["noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = true;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if noun_object["exclusive_keywords"] and adjective["exclusive_keywords"] then
                                            for __, noun_keyword in pairs(noun_object["exclusive_keywords"]) do
                                                for _, adjective_keyword in pairs(adjective["exclusive_keywords"]) do
                                                    if noun_keyword == adjective_keyword then
                                                        add_adjective = false;
                                                        break;
                                                    end 
                                                end 
                                                if add_adjective == false then
                                                    break;
                                                end
                                            end 
                                        end 
                                        
                                        if add_adjective then
                                            local adjective_object = {};
                                            for key, value in pairs(adjective) do
                                                adjective_object[key] = value;
                                            end
                                            
                                            adjective_object["weight"] = weight;
                                            noun_object["max_prefix_roll"] = noun_object["max_prefix_roll"] + weight;
                                            
                                            table.insert(noun_object["prefix_list"], #noun_object["prefix_list"] + 1, adjective_object);
                                        end 
                                    end 
                                end 
                                
                                if noun_object["adjective_pos"] == "both" or noun_object["adjective_pos"] == "suffix" then
                                    for i = 1, #suffix_list do 
                                        local adjective = suffix_list[i];
                                        local add_adjective = true;
                                        local weight = 4;
                                        
                                        if adjective["weight"] then
                                            weight = adjective["weight"];
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["blacklisted_noun_types"] then
                                            for k, _ in pairs(adjective["blacklisted_noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = false;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["noun_types"] and not table.empty(adjective["noun_types"]) then
                                            add_adjective = false;
                                            for _, v in pairs(adjective["noun_types"]) do
                                                if v == noun_object["noun_type"] then
                                                    add_adjective = true;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if noun_object["exclusive_keywords"] and adjective["exclusive_keywords"] then
                                            for __, noun_keyword in pairs(noun_object["exclusive_keywords"]) do
                                                for _, adjective_keyword in pairs(adjective["exclusive_keywords"]) do
                                                    if noun_keyword == adjective_keyword then
                                                        add_adjective = false;
                                                        break;
                                                    end 
                                                end 
                                                if add_adjective == false then
                                                    break;
                                                end
                                            end 
                                        end 
                                        
                                        if add_adjective then
                                            local adjective_object = {};
                                            for key, value in pairs(adjective) do
                                                adjective_object[key] = value;
                                            end
                                            
                                            adjective_object["weight"] = weight;
                                            noun_object["max_suffix_roll"] = noun_object["max_suffix_roll"] + weight;
                                            
                                            table.insert(noun_object["suffix_list"], #noun_object["suffix_list"] + 1, adjective_object);
                                        end 
                                    end 
                                end 
                                
                                
                                if noun_object["possessive_pos"] == "both" or noun_object["possessive_pos"] == "prefix" then
                                    for i = 1, #possessive_prefix_list do 
                                        local adjective = possessive_prefix_list[i];
                                        local add_adjective = true;
                                        local weight = 2;
                                        
                                        if adjective.is_lord_name then 
                                            if noun_object.no_lord_name then
                                                add_adjective = false;
                                            else 
                                                weight = 1;
                                            end
                                        end 
                                        
                                        if adjective["weight"] then
                                            weight = adjective["weight"];
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["blacklisted_noun_types"] then
                                            for k, _ in pairs(adjective["blacklisted_noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = false;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["noun_types"] and not table.empty(adjective["noun_types"]) then
                                            add_adjective = false;
                                            for _, v in pairs(adjective["noun_types"]) do
                                                if v == noun_object["noun_type"] then
                                                    add_adjective = true;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if noun_object["exclusive_keywords"] and adjective["exclusive_keywords"] then
                                            for __, noun_keyword in pairs(noun_object["exclusive_keywords"]) do
                                                for _, adjective_keyword in pairs(adjective["exclusive_keywords"]) do
                                                    if noun_keyword == adjective_keyword then
                                                        add_adjective = false;
                                                        break;
                                                    end 
                                                end 
                                                if add_adjective == false then
                                                    break;
                                                end
                                            end 
                                        end 
                                        
                                        if add_adjective then
                                            local adjective_object = {};
                                            for key, value in pairs(adjective) do
                                                adjective_object[key] = value;
                                            end
                                            
                                            adjective_object["weight"] = weight;
                                            noun_object["max_prefix_roll"] = noun_object["max_prefix_roll"] + weight;
                                            
                                            table.insert(noun_object["prefix_list"], #noun_object["prefix_list"] + 1, adjective_object);
                                        end 
                                    end 
                                end 
                                
                                if noun_object["possessive_pos"] == "both" or noun_object["possessive_pos"] == "suffix" then
                                    for i = 1, #possessive_suffix_list do 
                                        local adjective = possessive_suffix_list[i];
                                        local add_adjective = true;
                                        local weight = 2;
                                        
                                        if adjective.is_lord_name then 
                                            if noun_object.no_lord_name then
                                                add_adjective = false;
                                            else 
                                                weight = 1;
                                            end
                                        end
                                        
                                        if adjective["weight"] then
                                            weight = adjective["weight"];
                                        end  
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["blacklisted_noun_types"] then
                                            for k, _ in pairs(adjective["blacklisted_noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = false;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["noun_types"] and not table.empty(adjective["noun_types"]) then
                                            add_adjective = false;
                                            for _, v in pairs(adjective["noun_types"]) do
                                                if v == noun_object["noun_type"] then
                                                    add_adjective = true;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if noun_object["exclusive_keywords"] and adjective["exclusive_keywords"] then
                                            for __, noun_keyword in pairs(noun_object["exclusive_keywords"]) do
                                                for _, adjective_keyword in pairs(adjective["exclusive_keywords"]) do
                                                    if noun_keyword == adjective_keyword then
                                                        add_adjective = false;
                                                        break;
                                                    end 
                                                end 
                                                if add_adjective == false then
                                                    break;
                                                end
                                            end 
                                        end 
                                        
                                        if add_adjective then
                                            local adjective_object = {};
                                            for key, value in pairs(adjective) do
                                                adjective_object[key] = value;
                                            end
                                            
                                            adjective_object["weight"] = weight;
                                            noun_object["max_suffix_roll"] = noun_object["max_suffix_roll"] + weight;
                                            
                                            table.insert(noun_object["suffix_list"], #noun_object["suffix_list"] + 1, adjective_object);
                                        end 
                                    end 
                                end 
                                
                                
                                if noun_object["location_pos"] == "both" or noun_object["location_pos"] == "prefix" then
                                    for i = 1, #location_prefix_list do 
                                        local adjective = location_prefix_list[i];
                                        local add_adjective = true;
                                        local weight = 1;
                                        
                                        if adjective["weight"] then
                                            weight = adjective["weight"];
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["blacklisted_noun_types"] then
                                            for k, _ in pairs(adjective["blacklisted_noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = false;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["noun_types"] and not table.empty(adjective["noun_types"]) then
                                            add_adjective = false;
                                            for _, v in pairs(adjective["noun_types"]) do
                                                if v == noun_object["noun_type"] then
                                                    add_adjective = true;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if noun_object["exclusive_keywords"] and adjective["exclusive_keywords"] then
                                            for __, noun_keyword in pairs(noun_object["exclusive_keywords"]) do
                                                for _, adjective_keyword in pairs(adjective["exclusive_keywords"]) do
                                                    if noun_keyword == adjective_keyword then
                                                        add_adjective = false;
                                                        break;
                                                    end 
                                                end 
                                                if add_adjective == false then
                                                    break;
                                                end
                                            end 
                                        end 
                                        
                                        if add_adjective then
                                            local adjective_object = {};
                                            for key, value in pairs(adjective) do
                                                adjective_object[key] = value;
                                            end
                                            
                                            adjective_object["weight"] = weight;
                                            noun_object["max_prefix_roll"] = noun_object["max_prefix_roll"] + weight;
                                            
                                            table.insert(noun_object["prefix_list"], #noun_object["prefix_list"] + 1, adjective_object);
                                        end 
                                    end 
                                end 
                                
                                if noun_object["location_pos"] == "both" or noun_object["location_pos"] == "suffix" then
                                    for i = 1, #location_suffix_list do
                                        local adjective = location_suffix_list[i];
                                        local add_adjective = true;
                                        local weight = 1;
                                        
                                        if adjective["weight"] then
                                            weight = adjective["weight"];
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["blacklisted_noun_types"] then
                                            for k, _ in pairs(adjective["blacklisted_noun_types"]) do
                                                if k == noun_object["noun_type"] then
                                                    add_adjective = false;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if add_adjective and noun_object["noun_type"] and adjective["noun_types"] and not table.empty(adjective["noun_types"]) then
                                            add_adjective = false;
                                            for _, v in pairs(adjective["noun_types"]) do
                                                if v == noun_object["noun_type"] then
                                                    add_adjective = true;
                                                    break;
                                                end 
                                            end 
                                        end 
                                        
                                        if noun_object["exclusive_keywords"] and adjective["exclusive_keywords"] then
                                            for __, noun_keyword in pairs(noun_object["exclusive_keywords"]) do
                                                for _, adjective_keyword in pairs(adjective["exclusive_keywords"]) do
                                                    if noun_keyword == adjective_keyword then
                                                        add_adjective = false;
                                                        break;
                                                    end 
                                                end 
                                                if add_adjective == false then
                                                    break;
                                                end
                                            end 
                                        end 
                                        
                                        if add_adjective then
                                            local adjective_object = {};
                                            for key, value in pairs(adjective) do
                                                adjective_object[key] = value;
                                            end
                                            
                                            adjective_object["weight"] = weight;
                                            noun_object["max_suffix_roll"] = noun_object["max_suffix_roll"] + weight;
                                            
                                            table.insert(noun_object["suffix_list"], #noun_object["suffix_list"] + 1, adjective_object);
                                        end 
                                    end 
                                end 
                                
                                --0 by default, some have high weights, others 0 to ensure they only apply when they have adjectives
                                if not noun_object["weight"] then
                                    noun_object["weight"] = 0;
                                end 
                                
                                
                                if (noun_object["max_prefix_roll"] + noun_object["max_suffix_roll"]) <= 0 then
                                    noun_object["weight"] = 0;
                                else
                                    noun_object["weight"] = noun_object["weight"] + (noun_object["max_prefix_roll"] + noun_object["max_suffix_roll"]);
                                end 
                                
                                
                                if noun_object["minimum_weight"] and noun_object["weight"] < noun_object["minimum_weight"] then 
                                    noun_object["weight"] = noun_object["minimum_weight"];
                                end 
                                
                                
                                table.insert(noun_list, #noun_list + 1, noun_object);
                                max_noun_roll = max_noun_roll + noun_object["weight"];
                            end
                        end
                    end
                end
            end
        end
        
        --dynamic_ror_log("noun_list = ".. table.tostring(noun_list));
        
        --------------------------------------------
          
        ---------- ROLL NOUN -------------      
        local noun;
        dynamic_ror_log("   max_noun_roll: "..max_noun_roll)
        if #noun_list >= 1 and max_noun_roll > 0 then
                
            local roll = cm:random_number(max_noun_roll, 1);
            
            dynamic_ror_log("   noun_roll: " .. roll)
            
            local sum = 0;
            
            for i = 1, #noun_list do
                local noun_object = noun_list[i];
                if noun_object["weight"] then
                    sum = sum + noun_object["weight"];
                    dynamic_ror_log("sum: "..sum)
                    if sum >= roll then
                        noun = noun_object;
                        break;
                    end 
                end 
            end 
        end
        
        if not noun then
            dynamic_ror_log("ERROR: COULD NOT GENERATE NOUNS FOR ROR");
            
            return nil;
        end
        
        dynamic_ror_log("noun: "..table.tostring(noun));
        --------------------------------
        
        
        local name;
        
        if is_single_entity then
            if keywords["female"] and noun.noun_single_female then
                name = noun.noun_single_female;
            else
                name = noun.noun_single;
            end 
        else
            if keywords["female"] and noun.noun_plural_female then
                name = noun.noun_plural_female ;
            else
                name = noun.noun_plural;
            end 
        end
        
        
        if not name then
            return nil;
        end
        
        dynamic_ror_log("noun = " .. name);
        
        ---------- ROLL ADJECTIVES -------------
        
        local roll = 100;
        local adjective_chance = 0;
        local adjective_count = 0;
        
        local prefix_possessive = "The ";
        local prefix_adjective = "";
        local prefix_location = "";
        local suffix = "";
        local prefix_count = 0; --limit to two prefixes
        
        if is_greenskin then
            prefix_possessive = "Da ";
        end 
        
        dynamic_ror_log("Rolling Adjectives");
        
        if (#noun["prefix_list"] + #noun["suffix_list"]) > 0 then
            adjective_chance = 100;
        end 
        
        dynamic_ror_log("adjective_chance: ".. adjective_chance);
        dynamic_ror_log("adjective roll: ".. roll);
        
        while roll <= adjective_chance do
        
            dynamic_ror_log("adjective roll: ".. roll);
            dynamic_ror_log("adjective_chance: "..adjective_chance);
        
            local adjective;
            local index = 0;
            --both
            if #noun["prefix_list"] + #noun["suffix_list"] > 0 then
            
                local prefix_chance = noun["max_prefix_roll"];
                
                if prefix_chance > 0 and prefix_chance >= cm:random_number((noun["max_prefix_roll"] + noun["max_suffix_roll"]), 1) then
                
                    local adjective_roll = cm:random_number(noun["max_prefix_roll"], 1);
                    local sum = 0;
            
                    dynamic_ror_log("\t rolling prefixes...")
                    dynamic_ror_log("\t adjective_roll = "..adjective_roll);
                    
                    for _, item in pairs(noun["prefix_list"]) do 
                
                        dynamic_ror_log("\t current sum = "..sum)
                        dynamic_ror_log("\t item[\"weight\"] = ".. item["weight"]);
                        
                        sum = sum + item["weight"];
                        if sum >= adjective_roll then
                            adjective = item;
                            adjective["pos"] = "prefix";
                            break;
                        end 
                    end 
                else
                
                    local adjective_roll = cm:random_number(noun["max_suffix_roll"], 1);
                    local sum = 0;
            
                    dynamic_ror_log("\t rolling suffixes...")
                    dynamic_ror_log("\t adjective_roll = "..adjective_roll);
                    
                    for _, item in pairs(noun["suffix_list"]) do 
                
                        dynamic_ror_log("\t current sum = "..sum)
                        dynamic_ror_log("\t item[\"weight\"] = ".. item["weight"]);
                        
                        sum = sum + item["weight"];
                        if sum >= adjective_roll then
                            adjective = item;
                            adjective["pos"] = "suffix";
                            break;
                        end 
                    end 
                end
            end
            
            if adjective then
                
                adjective_count = adjective_count + 1
                
                if adjective["pos"] == "suffix" then
                    suffix = " "..adjective["suffix"];
                    noun["suffix_list"] = {};
                
                --filter out suffixes
                else 
                    prefix_count = prefix_count + 1;
                    if adjective.is_location then
                        prefix_location = adjective["prefix"].." ";
                    elseif adjective.is_possessive then
                        prefix_possessive = adjective["prefix"].." ";
                    else
                        prefix_adjective = adjective["prefix"].." ";
                    end 
                    
                    if #noun["suffix_list"] > 0 then
                        local new_suffix_list = {};
                        noun["max_suffix_roll"] = 0;
                        
                        --filter out suffixes
                        for _, suffix in pairs(noun["suffix_list"]) do 
                            local add_adjective = true;
                            
                            --location exclusivity
                            if add_adjective == true and adjective.is_location and suffix.is_location then
                                add_adjective = false;
                            end 
                            
                            --possessive exclusivity
                            if add_adjective == true and adjective.is_possessive and suffix.is_possessive then
                                add_adjective = false;
                            end 
                    
                            --exclusive keywords
                            if add_adjective == true and adjective["exclusive_keywords"] and suffix["exclusive_keywords"] then
                                for j = 1, #adjective["exclusive_keywords"] do
                                    if add_adjective == false then
                                        break;
                                    end 
                                    for k = 1, #suffix["exclusive_keywords"] do 
                                        if adjective["exclusive_keywords"] == suffix["exclusive_keywords"][k] then
                                            add_adjective = false;
                                            break;
                                        end 
                                    end 
                                end 
                            end 
                                
                            --prevents duplicates for adjectives with suffix and prefix
                            if add_adjective == true and suffix["suffix"] and adjective["suffix"] and suffix["suffix"] == adjective["suffix"] then
                                add_adjective = false;
                            end
                            
                            if add_adjective == true then 
                                noun["max_suffix_roll"] = noun["max_suffix_roll"] + suffix["weight"];
                                table.insert(new_suffix_list, #new_suffix_list + 1, suffix);
                            end 
                        end 
                        noun["suffix_list"] = new_suffix_list;
                    end 
                end 
                   
                local new_prefix_list ={};
                noun["max_prefix_roll"] = 0;
                
                --filter out prefixes
                for i, prefix in pairs(noun["prefix_list"]) do 
                    local add_adjective = true;
                    
                    --remove self
                    if i == index and adjective["pos"] == "prefix" then
                        add_adjective = false;
                    end 
                    
                    --location exclusivity
                    if add_adjective == true and adjective.is_location and (prefix.is_possessive or prefix.is_location) then
                        add_adjective = false;
                    end 
                    
                    --possessive exclusivity
                    if add_adjective == true and adjective.is_possessive and (prefix.is_possessive or prefix.is_location) then
                        add_adjective = false;
                    end 
                    
                    --exclusive keywords
                    if add_adjective == true and adjective["exclusive_keywords"] and prefix["exclusive_keywords"] then
                        for j = 1, #adjective["exclusive_keywords"] do
                            if add_adjective == false then
                                break;
                            end 
                            for k = 1, #prefix["exclusive_keywords"] do 
                                if adjective["exclusive_keywords"] == prefix["exclusive_keywords"][k] then
                                    add_adjective = false;
                                    break;
                                end 
                            end 
                        end 
                    end 
                    
                    --prevents duplicates for adjectives with suffix and prefix
                    if add_adjective == true and prefix["prefix"] and adjective["prefix"] and prefix["prefix"] == adjective["prefix"] then
                        add_adjective = false;
                    end
                    
                    if add_adjective == true then 
                        noun["max_prefix_roll"] = noun["max_prefix_roll"] + prefix["weight"];
                        table.insert(new_prefix_list, #new_prefix_list + 1, prefix);
                    end 
                end 
                noun["prefix_list"] = new_prefix_list;
                
                if noun["max_prefix_roll"] + noun["max_suffix_roll"] > 0 and prefix_count < 2 then
                    adjective_chance = (100 / (adjective_count * 2)) + (noun["max_prefix_roll"] + noun["max_suffix_roll"]);
                else 
                    adjective_chance = 0;
                end 
                
            else
                break;
            end 
            
            roll = cm:random_number(100, 1);
        end 
        
        dynamic_ror_log("prefix_possessive: ".. prefix_possessive)
        dynamic_ror_log("prefix_adjective: ".. prefix_adjective)
        dynamic_ror_log("prefix_location: ".. prefix_location)
        dynamic_ror_log("name: ".. name)
        dynamic_ror_log("suffix: ".. suffix)
        
        name = prefix_possessive..prefix_adjective..prefix_location..name..suffix;
        
        dynamic_ror_log("name: "..name);
        ------------------------------
        
        return name; --"Royal Altdorf Greatsword Company of Honour and also Glory and stuff"
    end
end

--- @function dynamic_ror_button_listeners
--- @desc Sets up listeners for RoR button UI to function
function dynamic_ror_button_listeners()

    core:add_listener(
        "DynamicRoR_CharacterSelected",
        "CharacterSelected",
        function(context)
            return ror_button_enabled;
        end,
        function(context)
            dynamic_ror_log("DynamicRoR_CharacterSelected");
            core:remove_listener("DynamicRoR_UnitSelected");    
            
            if context:character():faction():is_human() then
            
                local selected_character = context:character();
                
                core:add_listener(
                    "DynamicRoR_UnitSelected",
                    "ComponentLClickUp",
                    function(context)
                        --dynamic_ror_log(context.string);
                        return string.find(context.string, "LandUnit")
                    end,
                    function(context)
                        dynamic_ror_log("DynamicRoR_UnitSelected");
                        
                        local selected_unit_index = string.gsub(context.string, "LandUnit ", "");
                        selected_unit_index = tonumber(selected_unit_index);
                        
                        local units = find_uicomponent(
                            core:get_ui_root(),
                            "units_panel",
                            "main_units_panel",
                            "units"
                        );
                        
                        local ror_button = find_uicomponent(
                            core:get_ui_root(),
                            "units_panel",
                            "main_units_panel",
                            "button_group_unit",
                            "ror_button"
                        );
                        
                        if ror_button then
                            core:remove_listener("DynamicRoR_ButtonSelected");
                            ror_button:SetState("inactive");
                            
                            if ror_button_enabled == false then
                                return
                            end
                        end
                        
                        if selected_unit_index == nil then
                            return;
                        end
                        
                        --filter out agents
                        for i = 0, units:ChildCount() - 1 do
                            local unit_component = find_child_uicomponent_by_index(units, i);
                            if string.find(unit_component:Id(), "LandUnit") then
                                break;
                            else
                                selected_unit_index = selected_unit_index + 1;
                            end
                        end
                        
                        local unit = selected_character:military_force():unit_list():item_at(selected_unit_index);
                        
                        --local unit = context:unit();
                        if unit and unit:is_null_interface() == false then
                            local effect_list = unit:get_unit_purchasable_effects();
                            for i = 0, effect_list:num_items() - 1 do
                                local effect_interface = effect_list:item_at(i);
                                
                                if string.find(effect_interface:record_key(), "dynamic_ror") then
                                    if ror_button then
                                        ror_button:SetState("active");
                                        dynamic_ror_add_ror_button_listener(unit)
                                    else
                                        dynamic_ror_create_ror_button(unit);
                                    end
                                    
                                    --dynamic_ror_log(effect_interface:record_key());
                                    break
                                end
                            end
                        end
                    end,
                    true
                );
            
            end
        end,
        true
    );
end

--- @function dynamic_ror_create_ror_button
--- @param unit UNIT_SCRIPT_INTERFACE
--- @desc Creates the Make RoR button in the button_group_unit UI component 
function dynamic_ror_create_ror_button(unit)

    local button_parent = find_uicomponent(core:get_ui_root(), "units_panel", "main_units_panel", "button_group_unit");
    local ror_button;
    
    if button_parent then
        --dynamic_ror_log("button_parent: "..button_parent:Id());
    else
        --dynamic_ror_log("   button_parent not found, aborting");
        return;
    end

    --local ror_button = find_uicomponent(button_parent, "ror_button");
    local button_disband = find_uicomponent(
		core:get_ui_root(),
		"units_panel",
		"main_units_panel",
		"button_group_unit",
		"button_disband"
    );
    
    if button_disband then
        --ror_button = core:get_or_create_component("ror_button", "ui/templates/square_medium_button", button_parent)
		local button_disband_id = "ror_button";
		local existing_button_address = UIComponent(button_disband:Parent()):Find(button_disband_id);
		if not existing_button_address then
			ror_button = UIComponent(button_disband:CopyComponent(button_disband_id));
			ror_button:SetState("active");
		else
			ror_button = UIComponent(existing_button_address);
		end
        ror_button:SetImagePath("ui/skins/default/icon_adc_reinforcements.png");
		ror_button:SetVisible(true);
        ror_button:SetTooltipText("Make Unit RoR", true);
        --dynamic_ror_log("button created");
        
        dynamic_ror_add_ror_button_listener(unit);
    else
        --dynamic_ror_log("   button_parent not found, aborting");
        return;
    end
    
end

--- @function dynamic_ror_add_ror_button_listener
--- @param unit UNIT_SCRIPT_INTERFACE
--- @desc Creates the Make RoR button in the button_group_unit UI component 
function dynamic_ror_add_ror_button_listener(unit)

    if unit and unit:is_null_interface() == false then
        dynamic_ror_log("adding Dynamic RoR Button Listener for unit: ".. unit:unit_key());
        
        enable_ror_button_listener = true;
        
        core:add_listener(
            "DynamicRoR_ButtonSelected",
            "ComponentLClickUp",
            function(context)
                return context.string == "ror_button" and ror_button_enabled;
            end,
            function(context)
                if enable_ror_button_listener then
                    enable_ror_button_listener = false
                    out("dynamic_ror_button selected");
                    
                    local unit_object = {};
                    
                    unit_object.unit = unit;
                    unit_object.cqi = unit:command_queue_index();
                    unit_object.unit_key = unit:unit_key();
                    unit_object.contexts = {};
                    unit_object.is_player_unit = true;
                    
                    local battle_contexts = {};
                    local defender_culture_list = {};
                    local defender_faction_list = {};
                    local defender_subtype_list = {};
                    local attacker_culture_list = {};
                    local attacker_faction_list = {};
                    local attacker_subtype_list = {};
                    local region_context = "";
                    
                    if unit:force_commander() and unit:force_commander():is_null_interface() == false then
                        local subtype = unit:force_commander():character_subtype_key();
                        if Dynamic_RoR_Legendary_Lord_Keywords[subtype] then
                            for _, keyword in pairs(Dynamic_RoR_Legendary_Lord_Keywords[subtype]) do 
                                table.insert(battle_contexts, #battle_contexts + 1, keyword);
                            end 
                        end 
                        
                        local region = unit:force_commander():region();
                        if region and region:is_null_interface() == false then
                            region_context = region:name();
                        else
                            local sea_region = unit:force_commander():sea_region();
                            if sea_region and sea_region:is_null_interface() == false then
                                region_context = sea_region:name();
                            end 
                        end 
                    end 
                    
                    
                    --battle context
                    local battle_context_object = {};
                    battle_context_object["battle_contexts"] = battle_contexts or {};
                    battle_context_object["isAttacker"] = true;
                    battle_context_object["defender_culture_list"] = defender_culture_list or {};
                    battle_context_object["defender_faction_list"] = defender_faction_list or {};
                    battle_context_object["defender_subtype_list"] = defender_subtype_list or {};
                    battle_context_object["attacker_culture_list"] = attacker_culture_list or {};
                    battle_context_object["attacker_faction_list"] = attacker_faction_list or {};
                    battle_context_object["attacker_subtype_list"] = attacker_subtype_list or {};
                    battle_context_object["region_context"] = region_context or "";
                    
                    unit_object["is_player_unit"] = true;
                    
                    dynamic_ror_make_unit_ror(unit_object, battle_context_object);
                end
            end,
            true
        );
        
    end
end

function dynamic_ror_log(string)
    if debug_mode and string and type(string) == "string" then
        out(string);
    end 
end 

---------------------------
--- MCT SETTINGS ---
---------------------------

core:add_listener(
	"nanu_dynamic_rors_mct_init",
	"MctInitialized",
	true,
	function(context)
		local nanu_dynamic_rors_mct = context:mct():get_mod_by_key("nanu_dynamic_rors");
		
		if not nanu_dynamic_rors_mct then
            dynamic_ror_log("nanu_dynamic_rors not found, aborting")
			return
		end

		ror_button_enabled = nanu_dynamic_rors_mct:get_option_by_key("ror_button_enabled"):get_finalized_setting();
        grant_free_ror = nanu_dynamic_rors_mct:get_option_by_key("grant_free_ror"):get_finalized_setting();
		player_ror_modifier = nanu_dynamic_rors_mct:get_option_by_key("player_ror_modifier"):get_finalized_setting();
		ai_ror_enabled = nanu_dynamic_rors_mct:get_option_by_key("ai_ror_enabled"):get_finalized_setting();
		ai_ror_chance = nanu_dynamic_rors_mct:get_option_by_key("ai_ror_chance"):get_finalized_setting();
		max_rors_per_turn = nanu_dynamic_rors_mct:get_option_by_key("max_rors_per_turn"):get_finalized_setting();
		max_faction_rors_per_turn = nanu_dynamic_rors_mct:get_option_by_key("max_faction_rors_per_turn"):get_finalized_setting();
		randomize_ror_choice = nanu_dynamic_rors_mct:get_option_by_key("randomize_ror_choice"):get_finalized_setting();
		rename_units = nanu_dynamic_rors_mct:get_option_by_key("rename_units"):get_finalized_setting();
		minimum_unit_rank = nanu_dynamic_rors_mct:get_option_by_key("minimum_unit_rank"):get_finalized_setting();
		increase_unit_rank = nanu_dynamic_rors_mct:get_option_by_key("increase_unit_rank"):get_finalized_setting();
		
		
		missileScalar = nanu_dynamic_rors_mct:get_option_by_key("missileScalar"):get_finalized_setting();
		minKillsRankZero = nanu_dynamic_rors_mct:get_option_by_key("minKillsRankZero"):get_finalized_setting();
		minKillsRankNine = nanu_dynamic_rors_mct:get_option_by_key("minKillsRankNine"):get_finalized_setting();
		baseDamageFactor = nanu_dynamic_rors_mct:get_option_by_key("baseDamageFactor"):get_finalized_setting();
		damageModifierMin = nanu_dynamic_rors_mct:get_option_by_key("damageModifierMin"):get_finalized_setting();
		damageModifierMax = nanu_dynamic_rors_mct:get_option_by_key("damageModifierMax"):get_finalized_setting();
		baseUnitCostValue = nanu_dynamic_rors_mct:get_option_by_key("baseUnitCostValue"):get_finalized_setting();
		unitCostFactor = nanu_dynamic_rors_mct:get_option_by_key("unitCostFactor"):get_finalized_setting();
		unitCostMaxScalar = nanu_dynamic_rors_mct:get_option_by_key("baseUnitCostValue"):get_finalized_setting();
		unitCostMinScalar = nanu_dynamic_rors_mct:get_option_by_key("unitCostMinScalar"):get_finalized_setting();
		unitHealthScalarMin = nanu_dynamic_rors_mct:get_option_by_key("unitHealthScalarMin"):get_finalized_setting();
		unitHealthScalarMax = nanu_dynamic_rors_mct:get_option_by_key("unitHealthScalarMax"):get_finalized_setting();
		earlyTurnScalar = nanu_dynamic_rors_mct:get_option_by_key("earlyTurnScalar"):get_finalized_setting();
		earlyTurnThreshold = nanu_dynamic_rors_mct:get_option_by_key("earlyTurnThreshold"):get_finalized_setting();
		
		decisiveVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("decisiveVictoryScalar"):get_finalized_setting();
		closeVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("closeVictoryScalar"):get_finalized_setting();
		heroicVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("heroicVictoryScalar"):get_finalized_setting();
		pyrrhicVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("pyrrhicVictoryScalar"):get_finalized_setting();
		debug_mode = nanu_dynamic_rors_mct:get_option_by_key("debug_mode"):get_finalized_setting();

		
		out("Nanu Dynamic RoRs MCT values Initialized")
		out("\t debug_mode: ".. tostring(debug_mode));
		dynamic_ror_log("\t ror_button_enabled: ".. tostring(ror_button_enabled));
		dynamic_ror_log("\t grant_free_ror: ".. tostring(grant_free_ror));
		dynamic_ror_log("\t rename_units: ".. tostring(rename_units));
		dynamic_ror_log("\t randomize_ror_choice: ".. tostring(randomize_ror_choice));
		dynamic_ror_log("\t ai_ror_enabled: ".. tostring(ai_ror_enabled));
		dynamic_ror_log("\t player_ror_modifier: ".. player_ror_modifier);
		dynamic_ror_log("\t ai_ror_chance: ".. ai_ror_chance);
		dynamic_ror_log("\t max_rors_per_turn: ".. max_rors_per_turn);
		dynamic_ror_log("\t max_faction_rors_per_turn: ".. max_faction_rors_per_turn);
		dynamic_ror_log("\t minimum_unit_rank: ".. minimum_unit_rank);
		dynamic_ror_log("\t increase_unit_rank: ".. tostring(increase_unit_rank));
		
		dynamic_ror_log("\t missileScalar: ".. tostring(missileScalar));
		dynamic_ror_log("\t minKillsRankZero: ".. tostring(minKillsRankZero));
		dynamic_ror_log("\t minKillsRankNine: ".. tostring(minKillsRankNine));
		dynamic_ror_log("\t baseDamageFactor: ".. tostring(baseDamageFactor));
		dynamic_ror_log("\t damageModifierMin: ".. tostring(damageModifierMin));
		dynamic_ror_log("\t damageModifierMax: ".. tostring(damageModifierMax));
		dynamic_ror_log("\t baseUnitCostValue: ".. tostring(baseUnitCostValue));
		dynamic_ror_log("\t unitCostFactor: ".. tostring(unitCostFactor));
		dynamic_ror_log("\t unitCostMaxScalar: ".. tostring(unitCostMaxScalar));
		dynamic_ror_log("\t unitCostMinScalar: ".. tostring(unitCostMinScalar));
		dynamic_ror_log("\t unitHealthScalarMin: ".. tostring(unitHealthScalarMin));
		dynamic_ror_log("\t unitHealthScalarMax: ".. tostring(unitHealthScalarMax));
		dynamic_ror_log("\t earlyTurnScalar: ".. tostring(earlyTurnScalar));
		dynamic_ror_log("\t earlyTurnThreshold: ".. tostring(earlyTurnThreshold));
		
		dynamic_ror_log("\t decisiveVictoryScalar: ".. tostring(decisiveVictoryScalar));
		dynamic_ror_log("\t closeVictoryScalar: ".. tostring(closeVictoryScalar));
		dynamic_ror_log("\t heroicVictoryScalar: ".. tostring(heroicVictoryScalar));
		dynamic_ror_log("\t pyrrhicVictoryScalar: ".. tostring(pyrrhicVictoryScalar));
		
	end,
	true
)

core:add_listener(
	"nanu_dynamic_rors_fin",
	"MctFinalized",
	true,
	function(context)
		local nanu_dynamic_rors_mct = context:mct():get_mod_by_key("nanu_dynamic_rors");
		
		if not nanu_dynamic_rors_mct then
            dynamic_ror_log("nanu_dynamic_rors not found, aborting")
			return
		end

		ror_button_enabled = nanu_dynamic_rors_mct:get_option_by_key("ror_button_enabled"):get_finalized_setting();
        grant_free_ror = nanu_dynamic_rors_mct:get_option_by_key("grant_free_ror"):get_finalized_setting();
		player_ror_modifier = nanu_dynamic_rors_mct:get_option_by_key("player_ror_modifier"):get_finalized_setting();
		ai_ror_enabled = nanu_dynamic_rors_mct:get_option_by_key("ai_ror_enabled"):get_finalized_setting();
		ai_ror_chance = nanu_dynamic_rors_mct:get_option_by_key("ai_ror_chance"):get_finalized_setting();
		max_rors_per_turn = nanu_dynamic_rors_mct:get_option_by_key("max_rors_per_turn"):get_finalized_setting();
		max_faction_rors_per_turn = nanu_dynamic_rors_mct:get_option_by_key("max_faction_rors_per_turn"):get_finalized_setting();
		randomize_ror_choice = nanu_dynamic_rors_mct:get_option_by_key("randomize_ror_choice"):get_finalized_setting();
		rename_units = nanu_dynamic_rors_mct:get_option_by_key("rename_units"):get_finalized_setting();
		minimum_unit_rank = nanu_dynamic_rors_mct:get_option_by_key("minimum_unit_rank"):get_finalized_setting();
		increase_unit_rank = nanu_dynamic_rors_mct:get_option_by_key("increase_unit_rank"):get_finalized_setting();
		debug_mode = nanu_dynamic_rors_mct:get_option_by_key("debug_mode"):get_finalized_setting();
		
		
		missileScalar = nanu_dynamic_rors_mct:get_option_by_key("missileScalar"):get_finalized_setting();
		minKillsRankZero = nanu_dynamic_rors_mct:get_option_by_key("minKillsRankZero"):get_finalized_setting();
		minKillsRankNine = nanu_dynamic_rors_mct:get_option_by_key("minKillsRankNine"):get_finalized_setting();
		baseDamageFactor = nanu_dynamic_rors_mct:get_option_by_key("baseDamageFactor"):get_finalized_setting();
		damageModifierMin = nanu_dynamic_rors_mct:get_option_by_key("damageModifierMin"):get_finalized_setting();
		damageModifierMax = nanu_dynamic_rors_mct:get_option_by_key("damageModifierMax"):get_finalized_setting();
		baseUnitCostValue = nanu_dynamic_rors_mct:get_option_by_key("baseUnitCostValue"):get_finalized_setting();
		unitCostFactor = nanu_dynamic_rors_mct:get_option_by_key("unitCostFactor"):get_finalized_setting();
		unitCostMaxScalar = nanu_dynamic_rors_mct:get_option_by_key("baseUnitCostValue"):get_finalized_setting();
		unitCostMinScalar = nanu_dynamic_rors_mct:get_option_by_key("unitCostMinScalar"):get_finalized_setting();
		unitHealthScalarMin = nanu_dynamic_rors_mct:get_option_by_key("unitHealthScalarMin"):get_finalized_setting();
		unitHealthScalarMax = nanu_dynamic_rors_mct:get_option_by_key("unitHealthScalarMax"):get_finalized_setting();
		earlyTurnScalar = nanu_dynamic_rors_mct:get_option_by_key("earlyTurnScalar"):get_finalized_setting();
		earlyTurnThreshold = nanu_dynamic_rors_mct:get_option_by_key("earlyTurnThreshold"):get_finalized_setting();
		
		decisiveVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("decisiveVictoryScalar"):get_finalized_setting();
		closeVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("closeVictoryScalar"):get_finalized_setting();
		heroicVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("heroicVictoryScalar"):get_finalized_setting();
		pyrrhicVictoryScalar = nanu_dynamic_rors_mct:get_option_by_key("pyrrhicVictoryScalar"):get_finalized_setting();

		
		out("Nanu Dynamic RoRs MCT values Initialized")
		out("\t debug_mode: ".. tostring(debug_mode));
		dynamic_ror_log("\t ror_button_enabled: ".. tostring(ror_button_enabled));
		dynamic_ror_log("\t grant_free_ror: ".. tostring(grant_free_ror));
		dynamic_ror_log("\t rename_units: ".. tostring(rename_units));
		dynamic_ror_log("\t randomize_ror_choice: ".. tostring(randomize_ror_choice));
		dynamic_ror_log("\t ai_ror_enabled: ".. tostring(ai_ror_enabled));
		dynamic_ror_log("\t player_ror_modifier: ".. player_ror_modifier);
		dynamic_ror_log("\t ai_ror_chance: ".. ai_ror_chance);
		dynamic_ror_log("\t max_rors_per_turn: ".. max_rors_per_turn);
		dynamic_ror_log("\t max_faction_rors_per_turn: ".. max_faction_rors_per_turn);
		dynamic_ror_log("\t minimum_unit_rank: ".. minimum_unit_rank);
		dynamic_ror_log("\t increase_unit_rank: ".. tostring(increase_unit_rank));
		
		dynamic_ror_log("\t missileScalar: ".. tostring(missileScalar));
		dynamic_ror_log("\t minKillsRankZero: ".. tostring(minKillsRankZero));
		dynamic_ror_log("\t minKillsRankNine: ".. tostring(minKillsRankNine));
		dynamic_ror_log("\t baseDamageFactor: ".. tostring(baseDamageFactor));
		dynamic_ror_log("\t damageModifierMin: ".. tostring(damageModifierMin));
		dynamic_ror_log("\t damageModifierMax: ".. tostring(damageModifierMax));
		dynamic_ror_log("\t baseUnitCostValue: ".. tostring(baseUnitCostValue));
		dynamic_ror_log("\t unitCostFactor: ".. tostring(unitCostFactor));
		dynamic_ror_log("\t unitCostMaxScalar: ".. tostring(unitCostMaxScalar));
		dynamic_ror_log("\t unitCostMinScalar: ".. tostring(unitCostMinScalar));
		dynamic_ror_log("\t unitHealthScalarMin: ".. tostring(unitHealthScalarMin));
		dynamic_ror_log("\t unitHealthScalarMax: ".. tostring(unitHealthScalarMax));
		dynamic_ror_log("\t earlyTurnScalar: ".. tostring(earlyTurnScalar));
		dynamic_ror_log("\t earlyTurnThreshold: ".. tostring(earlyTurnThreshold));
		
		dynamic_ror_log("\t decisiveVictoryScalar: ".. tostring(decisiveVictoryScalar));
		dynamic_ror_log("\t closeVictoryScalar: ".. tostring(closeVictoryScalar));
		dynamic_ror_log("\t heroicVictoryScalar: ".. tostring(heroicVictoryScalar));
		dynamic_ror_log("\t pyrrhicVictoryScalar: ".. tostring(pyrrhicVictoryScalar));
	end,
	true
)
      
---------------------------
---   Saving / Loading  ---
---------------------------

cm:add_saving_game_callback(
    function(context)
        cm:save_named_value("nanu_dynamic_rors_free_ror", free_ror, context)
        --cm:save_named_value("nanu_dynamic_rors_saved_rors", saved_rors, context)
        cm:save_named_value("nanu_dynamic_rors_primary_faction", primary_faction, context)
   	end
);
cm:add_loading_game_callback(
	function(context)
		free_ror = cm:load_named_value("nanu_dynamic_rors_free_ror", true, context)
		--saved_rors = cm:load_named_value("nanu_dynamic_rors_saved_rors", {}, context)
		primary_faction = cm:load_named_value("nanu_dynamic_rors_primary_faction", "", context)
	end
);          
            
            
---------------------------
---   HELPER FUNCTIONS  ---
---------------------------   
function table.insert_if_absent (self, value)
    if not table.check_value(self, value) then
        table.insert(self, #self + 1, value);
    end
end

function table.check_value (self, value)
    for _, k in pairs(self) do
        if k == value then
            return true;
        end 
    end
    return false;
end
         
            
            
            
            
            
            
            
            