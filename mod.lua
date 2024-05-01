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
		defend_reviving = true,
		revive_distance = 25,
		drop_bag_percentage = 0.25,
		targeting_priority = {
			base_priority = 1, -- 1 = by weapon stats, 2 = by distance, 3 = vanilla
			player_aim = 1.5,
			critical = 2,
			marked = 1.5,
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
	UsefulBots.default_settings = deep_clone(UsefulBots.settings)
	UsefulBots.peer_settings = setmetatable({
		[1] = UsefulBots.settings
	}, {
		__index = function(t, k)
			t[k] = deep_clone(UsefulBots.default_settings)
			return t[k]
		end
	})
	UsefulBots.params = {
		dominate_enemies = {
			priority = 99,
			items = { "dialog_yes", "menu_useful_bots_assist_only", "dialog_no" }
		},
		mark_specials = {
			priority = 98,
			divider = 16
		},
		hold_position = { priority = 89 },
		stop_at_player = { priority = 88 },
		block_slow_vehicles = { priority = 87 },
		no_crouch = { priority = 86 },
		defend_reviving = { priority = 85 },
		revive_distance = {
			priority = 84,
			min = 0,
			max = 50,
			step = 1,
			display_precision = 0
		},
		drop_bag_percentage = {
			priority = 83,
			is_percentage = true,
			display_scale = 100,
			display_precision = 0,
			divider = 16
		},
		announce_low_hp = { priority = 79 },
		battle_cries = {
			priority = 78,
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
			divider = 16,
			callback = function(val)
				local enabled = val <= 2
				local menu = MenuHelper:GetMenu("useful_bots_targeting_priority")
				for _, item in pairs(menu and menu._items_list or {}) do
					item:set_enabled(item:name() == "targeting_priority/base_priority" or enabled)
				end
				menu = MenuHelper:GetMenu("useful_bots")
				for _, item in pairs(menu and menu._items_list or {}) do
					if item:name() == "dominate_enemies" then
						item:set_enabled(enabled)
						if not enabled then
							item:set_value(3)
						end
					end
				end
			end
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
			chance_inc = 0,
			base_chance = 1,
			usage_amount = 1,
			AI_group = "friendlies",
			search_pos = unit:position(),
			objective = self:get_assist_objective(unit)
		}
	end

	function UsefulBots:get_assist_objective(unit, receiver)
		local nav_seg = unit:movement():nav_tracker():nav_segment()
		return {
			type = "defend_area",
			scan = true,
			assist_unit = unit,
			haste = "run",
			pose = "stand",
			nav_seg = nav_seg,
			in_place = receiver and receiver:movement():nav_tracker():nav_segment() == nav_seg
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

	function UsefulBots:get_reviving_unit(unit)
		for _, c_data in pairs(managers.groupai:state():all_AI_criminals()) do
			local brain = c_data.unit:brain()
			local objective = brain:objective()
			if objective and objective.type == "revive" and objective.follow_unit == unit then
				return c_data.unit
			end
		end
	end

	function UsefulBots:force_attention(attention_unit)
		for _, c_data in pairs(managers.groupai:state():all_AI_criminals()) do
			local logic_data = c_data.unit:brain()._logic_data
			TeamAILogicBase.force_attention(logic_data, logic_data.internal_data, attention_unit)
		end
	end

	function UsefulBots:player_settings(player_unit)
		local peer = alive(player_unit) and player_unit:network() and player_unit:network():peer()
		return self.peer_settings[peer and peer:id() or 1]
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

		UsefulBots.params.base_priority.callback(UsefulBots.settings.targeting_priority.base_priority)
	end)

	if Network:is_client() then
		Hooks:Add("BaseNetworkSessionOnLoadComplete", "BaseNetworkSessionOnLoadCompleteUsefulBots", function(local_peer)
			LuaNetworking:SendToPeer(1, "useful_bots", json.encode({
				stop_at_player = UsefulBots.settings.stop_at_player
			}))
		end)
	else
		Hooks:Add("NetworkReceivedData", "NetworkReceivedDataUsefulBots", function(sender, id, data)
			if id == "useful_bots" then
				table.replace(UsefulBots.peer_settings[sender], json.decode(data) or {}, true)
			end
		end)
	end
end

HopLib:run_required(UsefulBots.mod_path .. "lua/")
