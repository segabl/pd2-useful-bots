-- Skip run start and stop animations in between nav segment movement
Hooks:PreHook(CriminalActionWalk, "init", "init_ub", function (self, action_desc, common_data)
	local my_data = common_data.ext_brain._logic_data and common_data.ext_brain._logic_data.internal_data
	if not my_data or not my_data.coarse_path or not my_data.coarse_path_index then
		return
	end

	self._tweaked_char = true
	self._old_no_run_start = common_data.char_tweak.no_run_start
	self._old_no_run_stop = common_data.char_tweak.no_run_stop

	common_data.char_tweak.no_run_start = my_data.coarse_path_index > 1 or common_data.char_tweak.no_run_start
	common_data.char_tweak.no_run_stop = my_data.coarse_path_index < #my_data.coarse_path - 1 or common_data.char_tweak.no_run_stop
end)

Hooks:PostHook(CriminalActionWalk, "on_exit", "on_exit_ub", function (self)
	if self._tweaked_char then
		self._common_data.char_tweak.no_run_start = self._old_no_run_start
		self._common_data.char_tweak.no_run_stop = self._old_no_run_stop
	end
end)
