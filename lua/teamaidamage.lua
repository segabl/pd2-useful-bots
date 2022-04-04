-- announce low health
Hooks:PostHook(TeamAIDamage, "_apply_damage", "_apply_damage_ub", function (self)
	local t = TimerManager:game():time()
	if UsefulBots.settings.announce_low_hp and (not self._said_hurt_t or self._said_hurt_t + 10 < t) and self._health_ratio < 0.3 and not self:need_revive() and not self._unit:sound():speaking() then
		self._said_hurt_t = t
		self._unit:sound():say("g80x_plu", true, true)
	end
end)

-- mark taser when tased
local damage_tase_original = TeamAIDamage.damage_tase
function TeamAIDamage:damage_tase(attack_data, ...)
	local result = damage_tase_original(self, attack_data, ...)

	if result then
		local attacker = attack_data.attacker_unit
		if alive(attacker) and attacker:base() and attacker:base().has_tag and attacker:base():has_tag("taser") then
			attacker:contour():add("mark_enemy", true)
		end
	end

	return result
end
