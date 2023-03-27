-- Helper function to look for matching ids
function ContourExt:find_id_match(id_match)
	for _, setup in ipairs(self._contour_list or {}) do
		if setup.type and setup.type:match(id_match) then
			return setup.type
		end
	end
end
