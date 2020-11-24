--[[ Auto Menu Builder v1.2 by Hoppip ]]
-- Include this file in your mod and make sure it is executed

AutoMenuBuilder = AutoMenuBuilder or {}

function AutoMenuBuilder:load_settings(settings_table, identifier)
  local file = io.open(SavePath .. identifier .. ".txt", "r")
  if file then
    local data = json.decode(file:read("*all"))
    file:close()
    local function copy_tbl(src, dst)
      for k, v in pairs(src) do
        if type(dst[k]) == type(v) then
          if type(v) == "table" then
            copy_tbl(v, dst[k])
          else
            dst[k] = v
          end
        end
      end
    end
    copy_tbl(data or {}, settings_table)
  end
end

function AutoMenuBuilder:create_menu_from_table(menu_nodes, settings_table, identifier, parent_menu, values, order)
  local function set_value(item_name, item_value)
    local hierarchy = item_name:split("/")
    local tbl = settings_table
    for i = 1, #hierarchy - 1 do
      tbl = tbl[hierarchy[i]]
    end
    tbl[hierarchy[#hierarchy]] = item_value
  end

  MenuCallbackHandler[identifier .. "_toggle"] = function (self, item)
    set_value(item:name(), item:value() == "on")
  end

  MenuCallbackHandler[identifier .. "_value"] = function (self, item)
    set_value(item:name(), item:value())
  end

  MenuCallbackHandler[identifier .. "_save"] = function (self)
    local file = io.open(SavePath .. identifier .. ".txt", "w+")
    if file then
      file:write(json.encode(settings_table))
      file:close()
    end
  end

  values = values or {}
  order = order or {}

  local loc = managers.localization
  local locs = {}

  local function order_tables(tbl)
    local keys = table.map_keys(tbl)
    local num_keys = #keys
    for i, v in ipairs(keys) do
      order[v] = order[v] or num_keys - i
      if type(tbl[v]) == "table" then
        order_tables(tbl[v])
      end
    end
  end
  order_tables(settings_table)

  local function loop_tables(tbl, menu_id, hierarchy, inherited_values)
    hierarchy = hierarchy and hierarchy .. "/" or ""
    MenuHelper:NewMenu(menu_id)
    for k, v in pairs(tbl) do
      local t = type(v)
      local name_id = "menu_" .. identifier .. "_" .. k
      local desc_id = name_id .. "_desc"
      if not loc:exists(name_id) then
        locs[name_id] = k:pretty()
      end
      if t == "boolean" then
        MenuHelper:AddToggle({
          id = hierarchy .. k,
          title = name_id,
          desc = loc:exists(desc_id) and desc_id,
          callback = identifier .. "_toggle",
          value = v,
          menu_id = menu_id,
          priority = order[k]
        })
      elseif t == "number" then
        local vals = values[k] or inherited_values
        if vals and type(vals[1]) == "string" then
          MenuHelper:AddMultipleChoice({
            id = hierarchy .. k,
            title = name_id,
            desc = loc:exists(desc_id) and desc_id,
            callback = identifier .. "_value",
            value = v,
            items = vals,
            menu_id = menu_id,
            priority = order[k]
          })
        else
          MenuHelper:AddSlider({
            id = hierarchy .. k,
            title = name_id,
            desc = loc:exists(desc_id) and desc_id,
            callback = identifier .. "_value",
            value = v,
            min = vals and vals[1] or 0,
            max = vals and vals[2] or 1,
            step = vals and vals[3] or 0.1,
            show_value = true,
            menu_id = menu_id,
            priority = order[k]
          })
        end
      elseif t == "string" then
        MenuHelper:AddInput({
          id = hierarchy .. k,
          title = name_id,
          desc = loc:exists(desc_id) and desc_id,
          callback = identifier .. "_value",
          value = v,
          menu_id = menu_id,
          priority = order[k]
        })
      elseif t == "table" then
        local node_id = menu_id .. "_" .. k
        MenuHelper:AddButton({
          id = hierarchy .. k,
          title = name_id,
          desc = loc:exists(desc_id) and desc_id,
          next_node = node_id,
          menu_id = menu_id,
          priority = order[k]
        })
        loop_tables(v, node_id, hierarchy .. k, values[k] or inherited_values)
      end
    end
    menu_nodes[menu_id] = MenuHelper:BuildMenu(menu_id, { back_callback = identifier .. "_save" })
  end
  loop_tables(settings_table, identifier)

  local name_id = "menu_" .. identifier
  local desc_id = name_id .. "_desc"
  if not loc:exists(name_id) then
    locs[name_id] = identifier:pretty(true)
  end
  loc:add_localized_strings(locs)

  MenuHelper:AddMenuItem(menu_nodes[parent_menu], identifier, name_id, loc:exists(desc_id) and desc_id)
end
