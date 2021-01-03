-- announce low health
Hooks:PostHook(TeamAIDamage, "_apply_damage", "_apply_damage_ub", function (self)
	local t = TimerManager:game():time()
	if UsefulBots.settings.announce_low_hp and (not self._said_hurt_t or self._said_hurt_t + 10 < t) and self._health_ratio < 0.3 and not self:need_revive() and not self._unit:sound():speaking() then
		self._said_hurt_t = t
		self._unit:sound():say("g80x_plu", true, true)
	end
end)
