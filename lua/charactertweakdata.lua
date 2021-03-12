-- no crouch
if not UsefulBots.settings.no_crouch then
	return
end
local init_original = CharacterTweakData.init
function CharacterTweakData:init(...)
	local result = init_original(self, ...)
	for k, v in pairs(self) do
		if type(v) == "table" and v.access == "teamAI1" then
			v.allowed_poses = { stand = true }
		end
	end
	return result
end
