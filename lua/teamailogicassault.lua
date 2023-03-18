TeamAILogicAssault._mark_special_chk_t = math.huge  -- hacky way to stop the vanilla special mark code

function TeamAILogicAssault.mark_enemy(data, criminal, to_mark)
	if to_mark:base().char_tweak then
		criminal:sound():say(to_mark:base():char_tweak().priority_shout .. "x_any", true)
	end
	managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, "cmd_point")
	data.unit:movement():play_redirect("cmd_point")
	to_mark:contour():add("mark_enemy", true)
end

if not Keepers then
	Hooks:PostHook(TeamAILogicAssault, "action_complete_clbk", "action_complete_clbk_ub", TeamAILogicIdle._check_objective_pos)
end

-- This function is disabled in vanilla but is not part of TeamAILogicAssault so it might crash in other logics when called with data.logic._upd_sneak_spotting
function TeamAILogicAssault._upd_sneak_spotting(data, my_data)
end

-- Wait before switching to idle
local _chk_exit_attack_logic_original = TeamAILogicAssault._chk_exit_attack_logic
function TeamAILogicAssault._chk_exit_attack_logic(data, new_reaction, ...)
	local my_data = data.internal_data
	local wanted_state = TeamAILogicBase._get_logic_state_from_reaction(data, new_reaction)

	if wanted_state == "idle" then
		if not my_data.switch_to_idle_t then
			if CopLogicBase.is_obstructed(data, data.objective, nil, nil) then
				my_data.switch_to_idle_t = data.t + (data.objective and data.objective.type == "defend_area" and 12 or 6)
			end
			return
		elseif my_data.switch_to_idle_t > data.t then
			return
		end
	end

	my_data.switch_to_idle_t = nil

	return _chk_exit_attack_logic_original(data, new_reaction, ...)
end
