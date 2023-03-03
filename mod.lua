if not HopLib then
	return
end

if not UsefulBots then
	UsefulBots = {}
	UsefulBots.mod_path = ModPath
	UsefulBots.settings = {
		no_crouch = false,
		dominate_enemies = 1, -- 1 = yes, 2 = assist only, 3 = no
		mark_specials = true,
		announce_low_hp = true,
		hold_position = true,
		battle_cries = true,
		save_hostages = true,
		block_slow_vehicles = true,
		ammo_drops = true,
		save_inspire = true,
		stop_at_player = false,
		targeting_priority = {
			base_priority = 1, -- 1 = by weapon stats, 2 = by distance, 3 = vanilla
			player_aim = 1.5,
			critical = 2,
			marked = 1.5,
			damaged = 1.2,
			domination = 2,
			enemies = { -- multipliers for specific enemy types
				marshal_marksman = 1,
				marshal_shield = 1,
				medic = 2,
				phalanx_minion = 1,
				phalanx_vip = 1,
				shield = 1,
				sniper = 1.5,
				spooc = 2,
				tank = 1,
				tank_hw = 1,
				tank_medic = 2,
				tank_mini = 1,
				taser = 1.7,
				turret = 0.5
			}
		}
	}
	UsefulBots.params = {
		dominate_enemies = {
			priority = 100,
			items = { "dialog_yes", "menu_useful_bots_assist_only", "dialog_no" }
		},
		mark_specials = {
			priority = 99,
			divider = 16
		},
		hold_position = { priority = 98 },
		stop_at_player = { priority = 97 },
		block_slow_vehicles = { priority = 96 },
		no_crouch = {
			priority = 95,
			divider = 16
		},
		announce_low_hp = { priority = 94 },
		battle_cries = {
			priority = 93,
			divider = 16
		},
		targeting_priority = {
			priority = -1000,
			max = 5,
			divider = -16
		},
		base_priority = {
			priority = 100,
			items = { "menu_useful_bots_weapon_stats", "menu_useful_bots_distance", "menu_useful_bots_vanilla" },
			divider = 16
		},
		enemies = {
			priority = -1000,
			max = 5,
			divider = -16
		}
	}
	UsefulBots.menu_builder = MenuBuilder:new("useful_bots", UsefulBots.settings, UsefulBots.params)

	function UsefulBots:get_assist_SO(unit)
		return {
			interval = 1,
			chance_inc = 1,
			base_chance = 0,
			usage_amount = 1,
			AI_group = "friendlies",
			search_pos = unit:position(),
			objective = self:get_assist_objective(unit)
		}
	end

	function UsefulBots:get_assist_objective(unit)
		return {
			type = "defend_area",
			scan = true,
			assist_unit = unit,
			haste = "run",
			pose = "stand",
			nav_seg = unit:movement():nav_tracker():nav_segment()
		}
	end

	function UsefulBots:stop_assist_objective(unit)
		for _, c_data in pairs(managers.groupai:state():all_AI_criminals()) do
			local brain = c_data.unit:brain()
			local objective = brain:objective()
			if objective and objective.assist_unit == unit then
				brain:set_objective(managers.groupai:state():_determine_objective_for_criminal_AI(c_data.unit))
			end
		end
	end

	function UsefulBots:force_attention(attention_unit)
		if not attention_unit:movement():team().foes.criminal1 then
			return
		end

		for _, c_data in pairs(managers.groupai:state():all_AI_criminals()) do
			local brain = c_data.unit:brain()
			local logic = brain._current_logic
			local logic_data = brain._logic_data
			local internal_logic_data = logic_data.internal_data

			if internal_logic_data.detection_task_key then
				logic.damage_clbk(logic_data, {
					attacker_unit = attention_unit,
					result = {}
				})
				if internal_logic_data.queued_tasks then
					CopLogicBase.unqueue_task(internal_logic_data, internal_logic_data.detection_task_key)
				end
				logic._upd_enemy_detection(logic_data)
			end
		end
	end

	Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusUsefulBots", function(menu_manager, nodes)
		local loc = managers.localization
		HopLib:load_localization(UsefulBots.mod_path .. "loc/", loc)
		loc:add_localized_strings({
			menu_useful_bots_marshal_marksman = loc:text("ene_male_marshal_marksman"),
			menu_useful_bots_marshal_shield = loc:text("ene_male_marshal_shield"),
			menu_useful_bots_medic = loc:text("ene_medic"),
			menu_useful_bots_phalanx_minion = loc:text("ene_phalanx"),
			menu_useful_bots_phalanx_vip = loc:text("ene_vip"),
			menu_useful_bots_shield = loc:text("ene_shield"),
			menu_useful_bots_sniper = loc:text("ene_sniper"),
			menu_useful_bots_spooc = loc:text("ene_spook"),
			menu_useful_bots_tank = loc:text("ene_bulldozer_1"),
			menu_useful_bots_tank_hw = loc:text("ene_bulldozer_4"),
			menu_useful_bots_tank_medic = loc:text("ene_bulldozer_medic"),
			menu_useful_bots_tank_mini = loc:text("ene_bulldozer_minigun"),
			menu_useful_bots_taser = loc:text("ene_tazer"),
			menu_useful_bots_turret = loc:text("tweak_swat_van_turret_module"),
		})
		UsefulBots.menu_builder:create_menu(nodes)
	end)

end

HopLib:run_required(UsefulBots.mod_path .. "lua/")
