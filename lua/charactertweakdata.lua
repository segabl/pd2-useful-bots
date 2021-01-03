-- no crouch
local init_original = CharacterTweakData.init
function CharacterTweakData:init(...)
	local result = init_original(self, ...)
	for k, v in pairs(self) do
		if type(v) == "table" then
			if v.access == "teamAI1" and UsefulBots.settings.no_crouch then
				v.allowed_poses = { stand = true }
			end
		end
	end
	return result
end
