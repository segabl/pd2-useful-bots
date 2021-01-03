-- fully count bots for balancing multiplier
function GroupAIStateBase:_get_balancing_multiplier(balance_multipliers)
	return balance_multipliers[math.clamp(table.count(self:all_char_criminals(), function (u_data) return not u_data.status end), 1, #balance_multipliers)]
end
