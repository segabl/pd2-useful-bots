-- Count bots for crew alive bonus
local on_executed_original = ElementMissionEnd.on_executed
function ElementMissionEnd:on_executed(instigator, ...)
	if not self._values.enabled or self._values.state ~= "success" or managers.platform:presence() ~= "Playing" then
		return on_executed_original(self, instigator, ...)
	end

	local num_winners = managers.network:session():amount_of_alive_players() + managers.groupai:state():amount_of_winning_ai_criminals()

	managers.network:session():send_to_peers("mission_ended", true, num_winners)
	game_state_machine:change_state_by_name("victoryscreen", {
		num_winners = num_winners,
		personal_win = alive(managers.player:player_unit())
	})

	ElementMissionEnd.super.on_executed(self, instigator)
end
