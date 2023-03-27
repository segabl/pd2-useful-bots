-- no crouch
if not UsefulBots.settings.no_crouch then
	return
end

Hooks:PostHook(CharacterTweakData, "init", "init_ub", function (self)
	for _, v in pairs(self) do
		if type(v) == "table" and v.access == "teamAI1" then
			v.allowed_poses = { stand = true }
		end
	end
end)
