if not get_mct then return end
local mct = get_mct()
local nanu_dynamic_ror_mct = mct:register_mod("nanu_dynamic_rors")

nanu_dynamic_ror_mct:set_title("Nanu's Dynamic Regiments of Renown");
nanu_dynamic_ror_mct:set_author("Nanu")

local nanu_dynamic_rors_options = nanu_dynamic_ror_mct:add_new_section("nanu_dynamic_rors_options", "Nanu's Dynamic RoRs Options", true)

local nanu_dynamic_ror_enable_debug_mode = nanu_dynamic_ror_mct:add_new_option("debug_mode", "checkbox")
nanu_dynamic_ror_enable_debug_mode:set_default_value(true)
nanu_dynamic_ror_enable_debug_mode:set_text("Enable Debug Logging")
nanu_dynamic_ror_enable_debug_mode:set_tooltip_text("Enables logging for Dynamic RoRs. This is only necessary if you're using the Script Debug Activator mod and don't want to see Dynamic RoRs logs. \n\nWARNING: I can't help you debug issues you have with Dynamic RoRs if you disable this feature!")

local nanu_dynamic_ror_grant_free_ror = nanu_dynamic_ror_mct:add_new_option("grant_free_ror", "checkbox")
nanu_dynamic_ror_grant_free_ror:set_default_value(true)
nanu_dynamic_ror_grant_free_ror:set_text("Grant Free Ror")
nanu_dynamic_ror_grant_free_ror:set_tooltip_text("Grant the player a free Dynamic Regiment of Renown after the first battle of a new campaign or ongoing campaign that did not have this mod active.")

local nanu_dynamic_ror_randomize_ror_choice = nanu_dynamic_ror_mct:add_new_option("randomize_ror_choice", "checkbox")
nanu_dynamic_ror_randomize_ror_choice:set_default_value(false)
nanu_dynamic_ror_randomize_ror_choice:set_text("Randomize RoR Choice")
nanu_dynamic_ror_randomize_ror_choice:set_tooltip_text("Randomize the choice of eligible units to become a Dynamic RoR rather than choosing the one that performed the best. Setting this to true increases the chances of units that perform averagely being chosen over those that deal more damage.")

local nanu_dynamic_ror_rename_units = nanu_dynamic_ror_mct:add_new_option("rename_units", "checkbox")
nanu_dynamic_ror_rename_units:set_default_value(true)
nanu_dynamic_ror_rename_units:set_text("Enable Dynamic Naming")
nanu_dynamic_ror_rename_units:set_tooltip_text("Enable the dynamic naming system. Disabling this setting will cause your Dynamic RoRs to retain their original names.")

local nanu_dynamic_ror_ai_ror_enabled = nanu_dynamic_ror_mct:add_new_option("ai_ror_enabled", "checkbox")
nanu_dynamic_ror_ai_ror_enabled:set_default_value(true)
nanu_dynamic_ror_ai_ror_enabled:set_text("Enable AI RoRs")
nanu_dynamic_ror_ai_ror_enabled:set_tooltip_text("Allow the AI factions to recieve Dynamic Regiments of Renown following a battle.")

local nanu_dynamic_increase_unit_rank = nanu_dynamic_ror_mct:add_new_option("increase_unit_rank", "checkbox")
nanu_dynamic_increase_unit_rank:set_default_value(true)
nanu_dynamic_increase_unit_rank:set_text("Increase Unit Rank to Level 9")
nanu_dynamic_increase_unit_rank:set_tooltip_text("Sets the unit's rank to level 9 upon becoming a Dynamic RoR. All vanilla RoRs are level 9 by default. Set this to false to allow the unit to level up normally instead of jumping in veterancy")

local nanu_dynamic_ror_minimum_unit_rank = nanu_dynamic_ror_mct:add_new_option("minimum_unit_rank", "slider")
nanu_dynamic_ror_minimum_unit_rank:slider_set_min_max(0, 9)
nanu_dynamic_ror_minimum_unit_rank:slider_set_step_size(1)
nanu_dynamic_ror_minimum_unit_rank:set_default_value(0)
nanu_dynamic_ror_minimum_unit_rank:set_text("Minimum Unit Rank")
nanu_dynamic_ror_minimum_unit_rank:set_tooltip_text("The minumum rank a unit must be to be eligible to become a Dynamic RoR.")

local nanu_dynamic_ror_player_ror_modifier = nanu_dynamic_ror_mct:add_new_option("player_ror_modifier", "slider")
nanu_dynamic_ror_player_ror_modifier:slider_set_min_max(0, 500)
nanu_dynamic_ror_player_ror_modifier:slider_set_step_size(5)
nanu_dynamic_ror_player_ror_modifier:set_default_value(100)
nanu_dynamic_ror_player_ror_modifier:set_text("Base RoR Chance")
nanu_dynamic_ror_player_ror_modifier:set_tooltip_text("This value is a percentage that directly affects the the criteria for units to become RoRs. Increasing it will increase how many RoRs you will generate. Decreasing it will reduce how many you generate. Setting it to 0 will disable Dynamic RoRs for the player entirely.")

local nanu_dynamic_ror_ai_ror_chance = nanu_dynamic_ror_mct:add_new_option("ai_ror_chance", "slider")
nanu_dynamic_ror_ai_ror_chance:slider_set_min_max(0, 100)
nanu_dynamic_ror_ai_ror_chance:slider_set_step_size(5)
nanu_dynamic_ror_ai_ror_chance:set_default_value(10)
nanu_dynamic_ror_ai_ror_chance:set_text("Base AI RoR Chance")
nanu_dynamic_ror_ai_ror_chance:set_tooltip_text("The base chance for AI to recieve Dynamic Regiments of Renown following a battle. Set to 0 to disable.")

local nanu_dynamic_ror_max_rors_per_turn = nanu_dynamic_ror_mct:add_new_option("max_rors_per_turn", "slider")
nanu_dynamic_ror_max_rors_per_turn:slider_set_min_max(1, 10)
nanu_dynamic_ror_max_rors_per_turn:slider_set_step_size(1)
nanu_dynamic_ror_max_rors_per_turn:set_default_value(3)
nanu_dynamic_ror_max_rors_per_turn:set_text("Max RoRs per turn")
nanu_dynamic_ror_max_rors_per_turn:set_tooltip_text("The maximum number of Regimemts of Renown that can be generated per turn across all factions. Count is reset to 0 on players turn.")

local nanu_dynamic_ror_max_faction_rors_per_turn = nanu_dynamic_ror_mct:add_new_option("max_faction_rors_per_turn", "slider")
nanu_dynamic_ror_max_faction_rors_per_turn:slider_set_min_max(0, 10)
nanu_dynamic_ror_max_faction_rors_per_turn:slider_set_step_size(1)
nanu_dynamic_ror_max_faction_rors_per_turn:set_default_value(1)
nanu_dynamic_ror_max_faction_rors_per_turn:set_text("Max RoRs per Faction per turn")
nanu_dynamic_ror_max_faction_rors_per_turn:set_tooltip_text("The maximum number of Regimemts of Renown that can be generated per turn for each faction. Setting this value higher than Max RoRs per turn will not increase the Max RoRs per turn.")



local nanu_dynamic_rors_advanced_options = nanu_dynamic_ror_mct:add_new_section("nanu_dynamic_rors_advanced_options", "Advanced Options", true)

local nanu_dynamic_ror_ror_button_enabled = nanu_dynamic_ror_mct:add_new_option("ror_button_enabled", "checkbox")
nanu_dynamic_ror_ror_button_enabled:set_default_value(false)
nanu_dynamic_ror_ror_button_enabled:set_text("Enable Make Dynamic RoR Button")
nanu_dynamic_ror_ror_button_enabled:set_tooltip_text("Adds a button to the unit icon list that will instantly convert a non Dynamic RoR to a Dynamic RoR. No contexts are provided, the unit will use its generic list of effects.")

local missileScalar = nanu_dynamic_ror_mct:add_new_option("missileScalar", "slider")
missileScalar:slider_set_precision(2)
missileScalar:slider_set_min_max(0.25, 2)
missileScalar:slider_set_step_size(0.05, 2)
missileScalar:set_default_value(1.25)
missileScalar:set_text("Missile Scalar")
missileScalar:set_tooltip_text("A percent scalar that will be applied to all missile units. This makes it harder for missile units to become Dynamic RoRs. Set to 100 to disable. Going below 100 will make missile units more likely to become Dynamic RoRs. \n\nDefault: 125")

local earlyTurnScalar = nanu_dynamic_ror_mct:add_new_option("earlyTurnScalar", "slider")
earlyTurnScalar:slider_set_precision(2)
earlyTurnScalar:slider_set_min_max(0.10, 1)
earlyTurnScalar:slider_set_step_size(0.05, 1)
earlyTurnScalar:set_default_value(0.5)
earlyTurnScalar:set_text("Early Turn Scalar")
earlyTurnScalar:set_tooltip_text("A percent scalar that makes it easier to get Dynamic RoRs in the early turns of a campaign. This value will slowly increase to 1 until the turn number reaches the Early Turn Threshold, at which point it will be ignored. Lower values make Dynamic RoR generation easier during these early turns. A value of 1 disables this feature. \n\nDefault: 0.5")

local earlyTurnThreshold = nanu_dynamic_ror_mct:add_new_option("earlyTurnThreshold", "slider")
earlyTurnThreshold:slider_set_min_max(5, 100)
earlyTurnThreshold:slider_set_step_size(5)
earlyTurnThreshold:set_default_value(40)
earlyTurnThreshold:set_text("Early Turn Threshold")
earlyTurnThreshold:set_tooltip_text("The turn at which the mod considers the \"early game\" to be over. Early Turn Scalar will scale gradually to 1 as the turn number approaches this value. \n\nDefault: 40")

local minKillsRankZero = nanu_dynamic_ror_mct:add_new_option("minKillsRankZero", "slider")
minKillsRankZero:slider_set_min_max(0, 1500)
minKillsRankZero:slider_set_step_size(5)
minKillsRankZero:set_default_value(500)
minKillsRankZero:set_text("Min Kills Rank 0")
minKillsRankZero:set_tooltip_text("The base number of kills a unit needs to make to be considered elgible to become a Dynamic RoR at rank 0. This value is affected by the following modifiers:\n \n\tBase RoR Chance \n\nBattle Scalar \n\tDamage Scalar \n\tUnit Cost Scalar \n\tUnit Health Scalar. \n\nDefault: 500")

local minKillsRankZero = nanu_dynamic_ror_mct:add_new_option("minKillsRankZero", "slider")
minKillsRankZero:slider_set_min_max(0, 1500)
minKillsRankZero:slider_set_step_size(5)
minKillsRankZero:set_default_value(500)
minKillsRankZero:set_text("Min Kills Rank 0")
minKillsRankZero:set_tooltip_text("The base number of kills a unit needs to make to be considered elgible to become a Dynamic RoR at rank 0. This value is affected by the following modifiers:\n \n\tBase RoR Chance \n\nBattle Scalar \n\tDamage Scalar \n\tUnit Cost Scalar \n\tUnit Health Scalar. \n\nDefault: 500")

local minKillsRankNine = nanu_dynamic_ror_mct:add_new_option("minKillsRankNine", "slider")
minKillsRankNine:slider_set_min_max(0, 1500)
minKillsRankNine:slider_set_step_size(5)
minKillsRankNine:set_default_value(200)
minKillsRankNine:set_text("Min Kills Rank 9")
minKillsRankNine:set_tooltip_text("The base number of kills a unit needs to make to be considered elgible to become a Dynamic RoR at rank 9. This value is affected by the following modifiers:\n \n\tBase RoR Chance \n\nBattle Scalar \n\tDamage Scalar \n\tUnit Cost Scalar \n\tUnit Health Scalar. \n\nDefault: 200")


local baseDamageFactor = nanu_dynamic_ror_mct:add_new_option("baseDamageFactor", "slider")
baseDamageFactor:slider_set_min_max(0, 500)
baseDamageFactor:slider_set_step_size(5)
baseDamageFactor:set_default_value(65)
baseDamageFactor:set_text("Base Damage Factor")
baseDamageFactor:set_tooltip_text("The base amount of damage each kill made by the unit is expected to be worth. This is used to calcualte the Damage Scalar. If the total amount of damage dealt in battle divided by the total amount of kills made in battle is greater than this value, the unit will require less kills to become an RoR.\n\nDefault: 65")

local damageModifierMin = nanu_dynamic_ror_mct:add_new_option("damageModifierMin", "slider")
damageModifierMin:slider_set_precision(2)
damageModifierMin:slider_set_min_max(0, 1)
damageModifierMin:slider_set_step_size(0.05, 2)
damageModifierMin:set_default_value(0.25)
damageModifierMin:set_text("Damage Scalar Minimum")
damageModifierMin:set_tooltip_text("The minumum value that the Damage Scalar can be.\n\nDefault: 0.25")

local damageModifierMax = nanu_dynamic_ror_mct:add_new_option("damageModifierMax", "slider")
damageModifierMax:slider_set_precision(2)
damageModifierMax:slider_set_min_max(1, 4)
damageModifierMax:slider_set_step_size(0.05, 2)
damageModifierMax:set_default_value(2.0)
damageModifierMax:set_text("Damage Scalar Maximum")
damageModifierMax:set_tooltip_text("The maximum value that the Damage Scalar can be.\n\nDefault: 2.0")

local baseUnitCostValue = nanu_dynamic_ror_mct:add_new_option("baseUnitCostValue", "slider")
baseUnitCostValue:slider_set_min_max(0, 1500)
baseUnitCostValue:slider_set_step_size(50)
baseUnitCostValue:set_default_value(750)
baseUnitCostValue:set_text("Base Unit Cost Value")
baseUnitCostValue:set_tooltip_text("The base unit cost each unit is expected to have.  Units greater than this are considered high cost and will require more kills than normal to become an RoR. Units that cose less than this require less kills.\n\nDefault: 750")

local unitCostFactor = nanu_dynamic_ror_mct:add_new_option("unitCostFactor", "slider")
unitCostFactor:slider_set_precision(2)
unitCostFactor:slider_set_min_max(1, 5)
unitCostFactor:slider_set_step_size(0.25, 2)
unitCostFactor:set_default_value(2.0)
unitCostFactor:set_text("Unit Cost Factor")
unitCostFactor:set_tooltip_text("This value controls the how much the unit's cost affects RoR generation when greater than Base Unit Cost Value. A value of 2 means that a high cost unit requires up to a maximum of 2 times the MinKills needed to become an RoR based on their cost. A value of 1 disables unit cost scaling. \n\nDefault: 2.0")

local unitCostMaxScalar = nanu_dynamic_ror_mct:add_new_option("unitCostMaxScalar", "slider")
unitCostMaxScalar:slider_set_precision(1)
unitCostMaxScalar:slider_set_min_max(1, 5)
unitCostMaxScalar:slider_set_step_size(0.1, 1)
unitCostMaxScalar:set_default_value(2.0)
unitCostMaxScalar:set_text("Unit Cost Max Scalar")
unitCostMaxScalar:set_tooltip_text("The maximum value than the Unit Cost scalar can be. The higher this value is the more kills a high cost unit needs to make to become an RoR.\n\nDefault: 2.0")

local unitCostMinScalar = nanu_dynamic_ror_mct:add_new_option("unitCostMinScalar", "slider")
unitCostMinScalar:slider_set_precision(1)
unitCostMinScalar:slider_set_min_max(0.1, 5)
unitCostMinScalar:slider_set_step_size(0.1, 1)
unitCostMinScalar:set_default_value(0.2)
unitCostMinScalar:set_text("Unit Cost Min Scalar")
unitCostMinScalar:set_tooltip_text("The lowest that Unit Cost scalar can be. The lower this value is the less kills a low cost unit needs to make to become an RoR.\n\nDefault: 0.2")

local unitHealthScalarMin = nanu_dynamic_ror_mct:add_new_option("unitHealthScalarMin", "slider")
unitHealthScalarMin:slider_set_precision(2)
unitHealthScalarMin:slider_set_min_max(0.1, 5)
unitHealthScalarMin:slider_set_step_size(0.4, 2)
unitHealthScalarMin:set_default_value(0.4)
unitHealthScalarMin:set_text("Unit Health Min Scalar")
unitHealthScalarMin:set_tooltip_text("How low the Unit Health Scalar is when the unit has 0 hitpoints (the closest a unit will get to this without dying is 1% of max health, so just above this value). The lower this value is the less kills a low health unit needs to make to become an RoR.\n\nDefault: 0.4")

local unitHealthScalarMax = nanu_dynamic_ror_mct:add_new_option("unitHealthScalarMax", "slider")
unitHealthScalarMax:slider_set_precision(1)
unitHealthScalarMax:slider_set_min_max(0.1, 5)
unitHealthScalarMax:slider_set_step_size(0.1, 1)
unitHealthScalarMax:set_default_value(1.0)
unitHealthScalarMax:set_text("Unit Health Max Scalar")
unitHealthScalarMax:set_tooltip_text("How high the Unit Health Scalar is when the unit has 100% hitpoints. The lower this value is the less kills a full health unit needs to make to become an RoR.\n\nDefault: 1.0")


local decisiveVictoryScalar = nanu_dynamic_ror_mct:add_new_option("decisiveVictoryScalar", "slider")
decisiveVictoryScalar:slider_set_precision(1)
decisiveVictoryScalar:slider_set_min_max(0.0, 5.0)
decisiveVictoryScalar:slider_set_step_size(0.1, 1)
decisiveVictoryScalar:set_default_value(1.0)
decisiveVictoryScalar:set_text("Decisive Victory Scalar")
decisiveVictoryScalar:set_tooltip_text("How much a Decisive Victory affects the MinKills. Lower values lower the number of kills a unit needs to make to become an RoR. Higher values mean the unit needs more kills. 1.0 means no effect.\n\nDefault: 1.0")

local closeVictoryScalar = nanu_dynamic_ror_mct:add_new_option("closeVictoryScalar", "slider")
closeVictoryScalar:slider_set_precision(1)
closeVictoryScalar:slider_set_min_max(0.0, 5.0)
closeVictoryScalar:slider_set_step_size(0.1, 1)
closeVictoryScalar:set_default_value(0.8)
closeVictoryScalar:set_text("Close Victory Scalar")
closeVictoryScalar:set_tooltip_text("How much a Close Victory affects the MinKills. Lower values lower the number of kills a unit needs to make to become an RoR. Higher values mean the unit needs more kills. 1.0 means no effect.\n\nDefault: 0.8")

local heroicVictoryScalar = nanu_dynamic_ror_mct:add_new_option("heroicVictoryScalar", "slider")
heroicVictoryScalar:slider_set_precision(1)
heroicVictoryScalar:slider_set_min_max(0.0, 5.0)
heroicVictoryScalar:slider_set_step_size(0.1, 1)
heroicVictoryScalar:set_default_value(0.6)
heroicVictoryScalar:set_text("Heroic Victory Scalar")
heroicVictoryScalar:set_tooltip_text("How much a Heroic Victory affects the MinKills. Lower values lower the number of kills a unit needs to make to become an RoR. Higher values mean the unit needs more kills. 1.0 means no effect.\n\nDefault: 0.6")

local pyrrhicVictoryScalar = nanu_dynamic_ror_mct:add_new_option("pyrrhicVictoryScalar", "slider")
pyrrhicVictoryScalar:slider_set_precision(1)
pyrrhicVictoryScalar:slider_set_min_max(0.0, 5.0)
pyrrhicVictoryScalar:slider_set_step_size(0.1, 1)
pyrrhicVictoryScalar:set_default_value(0.6)
pyrrhicVictoryScalar:set_text("Pyrrhic Victory Scalar")
pyrrhicVictoryScalar:set_tooltip_text("How much a Pyrrhic Victory affects the MinKills. Lower values lower the number of kills a unit needs to make to become an RoR. Higher values mean the unit needs more kills. 1.0 means no effect.\n\nDefault: 0.6")
















