

-------- MOD COMPATIBILITY --------
Dynamic_RoR_ModList = {};
Dynamic_RoR_Modded_Effect_List = {};
Dynamic_RoR_Modded_Unit_Keywords = {};
Dynamic_RoR_Modded_Faction_Keywords = {};
Dynamic_RoR_Modded_Legendary_Lord_Keywords = {};
Dynamic_RoR_Modded_Culture_Keywords = {};
Dynamic_RoR_Modded_Region_Data = {};
Dynamic_RoR_Modded_NameData = {};


function nanu_dynamic_ror_mod_compatibility()

    out("Adding DynamicRoRModReady listener")
    core:add_listener(
        "DynamicRoRModReady",
        "DynamicRoRModReady",
        true,
        function(context)
            local mod_name = context:mod_name();
            out("DynamicRoRModReady_".. mod_name);
            Dynamic_RoR_ModList[mod_name] = true;   
            
            out("Dynamic_RoR_ModList = ".. table.tostring(Dynamic_RoR_ModList));
            --don't add modded content until all modded data are loaded
            for mod, ready in pairs(Dynamic_RoR_ModList) do 
                if not ready then 
                    return;
                end 
            end 
            
            DynamicRoRs_AddModdedContent();
        end,
        true
    );

    core:trigger_custom_event("DynamicRoR_RegisterMods", {});
    
    core:get_tm():real_callback(
        function()
            out("Dynamic_RoR_ModList = ".. table.tostring(Dynamic_RoR_ModList));
            if table.empty(Dynamic_RoR_ModList) then
                out("no mods registered after 250 ms, enabling Dynamic RoRs")
                core:trigger_custom_event("DynamicRoRModdedContentReady", {})
            end 
        end,
        250
    );
end

    
function DynamicRoRs_AddModdedContent()
    out("    DynamicRoRs_AddModdedContent starting");
    
    ------- UNIT KEYWORDS -------
    out("\t adding modded unit keywords");
    for unit_key, keywords in pairs(Dynamic_RoR_Modded_Unit_Keywords) do
    
        --out("\t\tUnit Key: ".. unit_key);
        --out("\t\tKeywords to Add: ".. table.tostring(keywords));
        
        if Dynamic_RoR_Unit_Keywords[unit_key] then
            for _, keyword in pairs(keywords) do
                table.insert_if_absent(Dynamic_RoR_Unit_Keywords[unit_key], keyword);
            end 
        else
            Dynamic_RoR_Unit_Keywords[unit_key] = keywords;
        end 
    
        --out("\t\tDynamic_RoR_Unit_Keywords[".. unit_key .."] = ".. table.tostring(Dynamic_RoR_Unit_Keywords[unit_key]));
    end
    out("\n");
    
    ------- LEGENDARY LORD KEYWORDS -------
    out("\t adding legendary lord keywords");
    for subtype_key, keywords in pairs(Dynamic_RoR_Modded_Legendary_Lord_Keywords) do
    
        --out("\tSubtype Key: ".. subtype_key);
        --out("\t\tKeywords to Add: ".. table.tostring(keywords));
        
        if Dynamic_RoR_Legendary_Lord_Keywords[subtype_key] then
            for _, keyword in pairs(keywords) do
                table.insert_if_absent(Dynamic_RoR_Legendary_Lord_Keywords[subtype_key], keyword);
            end 
        else
            Dynamic_RoR_Legendary_Lord_Keywords[subtype_key] = keywords;
        end 
    
        --out("\tDynamic_RoR_Legendary_Lord_Keywords[".. subtype_key .."] = "..table.tostring(Dynamic_RoR_Legendary_Lord_Keywords[subtype_key]));
    end
    out("\n");
    
    ------- NAME DATA -------
    out("\tadding modded names data");
    for word_type, word_data in pairs(Dynamic_RoR_Modded_NameData) do
        if Dynamic_RoR_NameData[word_type] then
            for culture, culture_data in pairs(word_data) do
                if Dynamic_RoR_NameData[word_type][culture] then
                    for keyword, word_list in pairs(culture_data) do
                        if Dynamic_RoR_NameData[word_type][culture][keyword] then
                            for _, word in pairs(word_list) do
                                table.insert_if_absent(Dynamic_RoR_NameData[word_type][culture][keyword], keyword);
                            end 
                        else
                            Dynamic_RoR_NameData[word_type][culture][keyword] = word_list;
                        end 
                        --out("\t\tDynamic_RoR_NameData[".. word_type .."][".. culture .."][".. keyword .."] = "..table.tostring(Dynamic_RoR_NameData[word_type][culture][keyword]));
                    end 
                else
                    Dynamic_RoR_NameData[word_type][culture] = culture_data;
                    --out("\t\tDynamic_RoR_NameData[".. word_type .."][".. culture .."] = ".. table.tostring(Dynamic_RoR_NameData[word_type][culture]));
                end
            end 
        end 
    end
    out("\n");
    
    ------- FACTION DATA -------
    out("\t adding modded faction keywords");
    for faction_key, keywords in pairs(Dynamic_RoR_Modded_Faction_Keywords) do
    
        --out("\t\tFaction Key: ".. faction_key);
        --out("\t\tKeywords to Add: ".. table.tostring(keywords));
        
        if Dynamic_RoR_Faction_Keywords[faction_key] then
            for _, keyword in pairs(keywords) do
                table.insert_if_absent(Dynamic_RoR_Faction_Keywords[faction_key], keyword);
            end 
        else
            Dynamic_RoR_Faction_Keywords[faction_key] = keywords;
        end 
    
        --out("Dynamic_RoR_Faction_Keywords[".. faction_key .."] = "..table.tostring(Dynamic_RoR_Faction_Keywords[faction_key]));
    end
    out("\n");
    
    ------- CULTURE DATA -------
    out("\t adding modded culture keywords");
    for culture_key, keywords in pairs(Dynamic_RoR_Modded_Culture_Keywords) do
    
        --out("\t\tCulture Key: ".. culture_key);
        --out("\t\tKeywords to Add: ".. table.tostring(keywords));
        
        if Dynamic_RoR_Culture_Keywords[culture_key] then
            for _, keyword in pairs(keywords) do
                table.insert_if_absent(Dynamic_RoR_Culture_Keywords[culture_key], keyword);
            end 
        else
            Dynamic_RoR_Culture_Keywords[culture_key] = keywords;
        end 
    
        --out("\t\tDynamic_RoR_Culture_Keywords[".. culture_key .."] = "..table.tostring(Dynamic_RoR_Culture_Keywords[culture_key]));
    end
    out("\n");
    
    ------- REGION DATA -------
    out("\t adding modded region data");
    for region_key, region_data in pairs(Dynamic_RoR_Modded_Region_Data) do
        if Dynamic_RoR_Region_Data[region_key] then
            if region_data[1] then
                for i, value in pairs(region_data) do
                    table.insert(Dynamic_RoR_Region_Data[region_key], #Dynamic_RoR_Region_Data[region_key] + 1, value);
                end 
            else 
                table.insert(Dynamic_RoR_Region_Data[region_key], #Dynamic_RoR_Region_Data[region_key] + 1, region_data);
            end 
        else 
            Dynamic_RoR_Region_Data[region_key] = {};
            if region_data[1] then
                for i, value in pairs(region_data) do
                    table.insert(Dynamic_RoR_Region_Data[region_key], #Dynamic_RoR_Region_Data[region_key] + 1, value);
                end 
            else 
                table.insert(Dynamic_RoR_Region_Data[region_key], #Dynamic_RoR_Region_Data[region_key] + 1, region_data);
            end 
        end 
        
        --out("\t\tDynamic_RoR_Region_Data[".. region_key .."] = "..table.tostring(Dynamic_RoR_Region_Data[region_key]));
    end 
    out("\n");
    
    ------- EFFECTS -------
    out("\t adding modded effects");
    local faction_list = cm:model():world():faction_list();
    --Disable all purchasable effects
    for i = 0, faction_list:num_items() - 1 do
        local faction = faction_list:item_at(i);
        
        for j = 1, #Dynamic_RoR_Modded_Effect_List do
            local effect = Dynamic_RoR_Modded_Effect_List[j];
            cm:faction_set_unit_purchasable_effect_lock_state(faction, effect, effect, false);
            cm:faction_set_unit_purchasable_effect_lock_state(faction, effect, effect, true);
        end
    end
    out("\n");
    
    core:trigger_custom_event("DynamicRoRModdedContentReady", {})
end