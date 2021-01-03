TeamAILogicAssault._mark_special_chk_t = math.huge  -- hacky way to stop the vanilla special mark code

function TeamAILogicAssault.mark_enemy(data, criminal, to_mark)
	criminal:sound():say(to_mark:base():char_tweak().priority_shout .. "x_any", true)
	managers.network:session():send_to_peers_synched("play_distance_interact_redirect", data.unit, "cmd_point")
	data.unit:movement():play_redirect("cmd_point")
	to_mark:contour():add("mark_enemy", true)
end
