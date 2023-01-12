-- fully count bots for balancing multiplier
function GroupAIStateBase:_get_balancing_multiplier(balance_multipliers)
	return balance_multipliers[math.clamp(table.count(self:all_char_criminals(), function (u_data) return not u_data.status end), 1, #balance_multipliers)]
end

if UsefulBots.settings.hold_position then
	function GroupAIStateBase:upd_team_AI_distance()
	end
end

if not UsefulBots.settings.battle_cries then
	function GroupAIStateBase:chk_say_teamAI_combat_chatter()
	end
end

-- more accurate distance check for team ai revive SO
local _execute_so_original = GroupAIStateBase._execute_so
function GroupAIStateBase:_execute_so(so_data, so_rooms, so_administered, ...)
	local so_objective = so_data.objective
	if so_data.AI_group ~= "friendlies" then
		return _execute_so_original(self, so_data, so_rooms, so_administered, ...)
	end

	local mvec_dis = mvector3.distance
	local mvec_dis_sq = mvector3.distance_sq
	local pos = so_data.search_pos
	local nav_seg = so_objective.nav_seg
	local so_access = so_data.access
	local max_dis = so_data.search_dis_sq or math.huge
	local closest_u_data, closest_dis, closest_dis_sq = nil, math.huge, math.huge
	local nav_manager = managers.navigation
	local access_f = nav_manager.check_access
	local inspire_available = so_objective.type == "revive" and managers.player:is_custom_cooldown_not_active("team", "crew_inspire")
	local inspire_u_data

	local function check_allowed(u_key, u_unit_dat)
		return (not so_administered or not so_administered[u_key]) and (so_objective.forced or u_unit_dat.unit:brain():is_available_for_assignment(so_objective)) and (not so_data.verification_clbk or so_data.verification_clbk(u_unit_dat.unit)) and access_f(nav_manager, so_access, u_unit_dat.so_access, 0)
	end

	local function get_distance(u_key, u_unit_data)
		local path = nav_manager:search_coarse({
			access_pos = u_unit_data.so_access,
			from_seg = u_unit_data.seg,
			to_seg = nav_seg,
			id = u_key
		})

		if not path or #path < 2 then
			return math.huge
		end

		local dis = 0
		local current = u_unit_data.m_pos
		for i = 2, #path do
			local nxt = path[i][2]
			if current and nxt then
				dis = dis + mvec_dis(current, nxt)
			end
			current = nxt
		end

		return dis
	end

	for u_key, u_unit_data in pairs(self._ai_criminals) do
		if check_allowed(u_key, u_unit_data) then
			local dis_sq =  mvec_dis_sq(pos, u_unit_data.m_pos)
			if dis_sq < max_dis then
				if inspire_available and not inspire_u_data and dis_sq < 810000 then
					inspire_u_data = u_unit_data
				end

				local dis = get_distance(u_key, u_unit_data)
				if dis < closest_dis or dis == closest_dis and dis_sq < closest_dis_sq then
					closest_u_data = u_unit_data
					closest_dis = dis
					closest_dis_sq = dis_sq
				end
			end
		end
	end

	if closest_dis > 1000 and inspire_u_data then
		closest_u_data = inspire_u_data
	end

	if not closest_u_data then
		return
	end

	closest_u_data.unit:brain():set_objective(self.clone_objective(so_objective))
	if so_data.admin_clbk then
		so_data.admin_clbk(closest_u_data.unit)
	end

	return closest_u_data
end

if Keepers then
	return
end

-- Make bots return to their hold objective
local _determine_objective_for_criminal_AI_original = GroupAIStateBase._determine_objective_for_criminal_AI
function GroupAIStateBase:_determine_objective_for_criminal_AI(unit, ...)
	local movement = unit:movement()
	if movement._should_stay and movement._should_stay_objective then
		return movement._should_stay_objective
	end

	return _determine_objective_for_criminal_AI_original(self, unit, ...)
end

Hooks:PostHook(GroupAIStateBase, "on_player_criminal_death", "on_player_criminal_death_ub", function (self)
	for _, u_data in pairs(self._player_criminals) do
		if u_data.status ~= "dead" then
			return
		end
	end

	for _, u_data in pairs(self._ai_criminals) do
		u_data.unit:movement():set_should_stay(false)
	end
end)
