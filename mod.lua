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
		targeting_priority = {
			base_priority = 1, -- 1 = by weapon stats, 2 = by distance, 3 = vanilla
			player_aim = 1.5,
			critical = 2,
			marked = 1.5,
			damaged = 1.2,
			domination = 2,
			enemies = { -- multipliers for specific enemy types
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
		targeting_priority = {
			priority = -1,
			max = 5,
		},
		base_priority = {
			priority = 100,
			items = { "menu_useful_bots_weapon_stats", "menu_useful_bots_distance", "menu_useful_bots_vanilla" }
		},
		enemies = {
			priority = -1,
			max = 5
		}
	}
	UsefulBots.menu_builder = MenuBuilder:new("useful_bots", UsefulBots.settings, UsefulBots.params)

	Hooks:Add("MenuManagerBuildCustomMenus", "MenuManagerBuildCustomMenusUsefulBots", function(menu_manager, nodes)
		local loc = managers.localization
		HopLib:load_localization(UsefulBots.mod_path .. "loc/", loc)
		loc:add_localized_strings({
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

if RequiredScript then

	local fname = UsefulBots.mod_path .. RequiredScript:gsub(".+/(.+)", "lua/%1.lua")
	if io.file_is_readable(fname) then
		dofile(fname)
	end

end
