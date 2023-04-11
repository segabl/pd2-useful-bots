local enter_original = PlayerDriving.enter
function PlayerDriving:enter(...)
	local should_stay = {}

	-- Save should stay state
	if UsefulBots.settings.hold_position then
		for _, ai in pairs(managers.groupai:state():all_AI_criminals()) do
			local movement = ai.unit:movement()
			if movement and movement._should_stay then
				table.insert(should_stay, movement)
				movement._should_stay = false
			end
		end
	end

	enter_original(self, ...)

	-- Restore should stay state
	for _, movement in pairs(should_stay) do
		movement._should_stay = true
	end
end
