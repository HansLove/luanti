-- Marker GUI for Persistent Map Mod (Hashimon UX fork)

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

local active_waypoints = {}

local marker_gui = {
	formspec_version = 6,
	window_width = 26,
	window_height = 15,
	padding = 0.5,
	button_height = 0.55,
	button_width = 2.0,
	list_item_height = 1.65,
	scroll_y = 1.8,
	scroll_height = 8.5,
	scrollbar_width = 0.45,
	add_section_y = 10.8,
	footer_y = 13.2,
	header_height = 1.2,
	_row_ids = {},
	_scroll_pos = {},
}

local function truncate_text(text, max_len)
	if not text or #text <= max_len then
		return text or ""
	end
	return text:sub(1, max_len - 3) .. "..."
end

local function get_player_markers_list(player_name)
	-- Player-owned markers only; global system markers (e.g. vwar) are rendered separately.
	local player_data_entry = persistent_map.get_player_data(player_name)
	if not player_data_entry then
		return {}
	end

	local markers = player_data_entry.markers
	local marker_list = {}

	for marker_id, marker in pairs(markers) do
		table.insert(marker_list, {
			id = marker_id,
			name = marker.name or "Unnamed",
			x = marker.x,
			y = marker.y,
			z = marker.z,
			color_index = marker.color_index,
			timestamp = marker.timestamp,
		})
	end

	table.sort(marker_list, function(a, b)
		return (a.timestamp or 0) > (b.timestamp or 0)
	end)

	return marker_list
end

local function addWaypointHud(player, marker)
	local player_name = player:get_player_name()
	local wayName = marker.name or "Unnamed"
	local wayPos = vector.new(marker.x, marker.y, marker.z)

	if active_waypoints[player_name] then
		player:hud_remove(active_waypoints[player_name].hudId)
		active_waypoints[player_name] = nil
	end

	local hudId = player:hud_add({
		hud_elem_type = "waypoint",
		name = wayName,
		text = "m",
		number = 0xFFFFFF,
		world_pos = wayPos,
	})

	active_waypoints[player_name] = {
		hudId = hudId,
		marker_id = marker.id,
		name = wayName,
	}

	return hudId
end

local function removeWaypointHud(player)
	local player_name = player:get_player_name()
	if active_waypoints[player_name] then
		player:hud_remove(active_waypoints[player_name].hudId)
		active_waypoints[player_name] = nil
		return true
	end
	return false
end

local function hasWaypointForMarker(player_name, marker_id)
	return active_waypoints[player_name]
		and active_waypoints[player_name].marker_id == marker_id
end

local function can_teleport(player_name)
	return minetest.check_player_privs(player_name, { teleport = true })
		or minetest.check_player_privs(player_name, { server = true })
end

local function marker_id_for_index(player_name, index)
	local rows = marker_gui._row_ids[player_name]
	if not rows then
		return nil
	end
	return rows[tonumber(index)]
end

function persistent_map.show_marker_gui(player_name)
	local player = minetest.get_player_by_name(player_name)
	if not player then
		return
	end

	local markers = get_player_markers_list(player_name)
	local can_tp = can_teleport(player_name)
	local pad = marker_gui.padding
	local list_x = pad
	local list_width = marker_gui.window_width - pad * 2 - marker_gui.scrollbar_width - 0.15
	local scroll_y = marker_gui.scroll_y
	local scroll_h = marker_gui.scroll_height
	local scrollbar_x = list_x + list_width + 0.1

	local formspec = {}
	formspec[1] = string.format("formspec_version[%d]", marker_gui.formspec_version)
	formspec[2] = string.format("size[%.2f,%.2f]", marker_gui.window_width, marker_gui.window_height)
	formspec[3] = "bgcolor[#0d0d14C0;true]"
	formspec[4] = "style_type[box;bgcolor=#1a1a2e;border=true]"
	formspec[5] = "style_type[button;border=true;bgcolor=#2d2d44]"

	local header_y = pad
	formspec[6] = string.format(
		"label[%.2f,%.2f;Marker Management  —  Total: %d]",
		pad,
		header_y,
		#markers
	)

	formspec[7] = string.format(
		"box[%.2f,%.2f;%.2f,%.2f;#0d0d14]",
		list_x,
		scroll_y - 0.05,
		list_width + marker_gui.scrollbar_width + 0.2,
		scroll_h + 0.1
	)

	formspec[8] = string.format(
		"scroll_container[%.2f,%.2f;%.2f,%.2f;marker_list;vertical;0.1;0.5]",
		list_x,
		scroll_y,
		list_width,
		scroll_h
	)

	local formspec_index = 9
	marker_gui._row_ids[player_name] = {}

	if #markers == 0 then
		formspec[formspec_index] = string.format(
			"label[%.2f,%.2f;No markers yet. Use /map or add one below.]",
			0.4,
			0.4
		)
		formspec_index = formspec_index + 1
	else
		local btn_w = marker_gui.button_width
		local btn_h = marker_gui.button_height
		local gap = 0.08
		local player_pos = player:get_pos()

		for i, marker in ipairs(markers) do
			marker_gui._row_ids[player_name][i] = marker.id
			local y_pos = (i - 1) * marker_gui.list_item_height
			local color = persistent_map.marker_colors[marker.color_index]
				or persistent_map.marker_colors[1]

			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;%s]",
				0.15,
				y_pos + 0.08,
				0.45,
				0.45,
				color.color
			)
			formspec_index = formspec_index + 1

			local coords_text = string.format(
				"(%d,%d,%d)",
				math.floor(marker.x),
				math.floor(marker.y),
				math.floor(marker.z)
			)
			local distance = ""
			if player_pos then
				local dist = vector.distance(
					player_pos,
					vector.new(marker.x, marker.y, marker.z)
				)
				distance = string.format(" — %.0fm", dist)
			end

			local title = truncate_text(marker.name, 28)
			formspec[formspec_index] = string.format(
				"label[%.2f,%.2f;%s  %s%s]",
				0.7,
				y_pos + 0.05,
				minetest.formspec_escape(title),
				coords_text,
				distance
			)
			formspec_index = formspec_index + 1

			local btn_y = y_pos + 0.55
			local bx = 0.15
			local has_waypoint = hasWaypointForMarker(player_name, marker.id)

			formspec[formspec_index] = string.format(
				"button[%.2f,%.2f;%.2f,%.2f;edit_name_%d;Ren]",
				bx, btn_y, btn_w * 0.75, btn_h, i
			)
			formspec_index = formspec_index + 1
			bx = bx + btn_w * 0.75 + gap

			formspec[formspec_index] = string.format(
				"button[%.2f,%.2f;%.2f,%.2f;edit_color_%d;Col]",
				bx, btn_y, btn_w * 0.75, btn_h, i
			)
			formspec_index = formspec_index + 1
			bx = bx + btn_w * 0.75 + gap

			local waypoint_label = has_waypoint and "Hide" or "WP"
			local waypoint_action = has_waypoint and "remove_waypoint_" or "show_waypoint_"
			formspec[formspec_index] = string.format(
				"button[%.2f,%.2f;%.2f,%.2f;%s%d;%s]",
				bx, btn_y, btn_w * 0.75, btn_h, waypoint_action, i, waypoint_label
			)
			formspec_index = formspec_index + 1
			bx = bx + btn_w * 0.75 + gap

			formspec[formspec_index] = string.format(
				"button[%.2f,%.2f;%.2f,%.2f;show_map_%d;Map]",
				bx, btn_y, btn_w * 0.75, btn_h, i
			)
			formspec_index = formspec_index + 1
			bx = bx + btn_w * 0.75 + gap

			formspec[formspec_index] = string.format(
				"button[%.2f,%.2f;%.2f,%.2f;delete_%d;Del]",
				bx, btn_y, btn_w * 0.75, btn_h, i
			)
			formspec_index = formspec_index + 1

			if can_tp then
				bx = bx + btn_w * 0.75 + gap
				formspec[formspec_index] = string.format(
					"button[%.2f,%.2f;%.2f,%.2f;teleport_%d;TP]",
					bx, btn_y, btn_w * 0.65, btn_h, i
				)
				formspec_index = formspec_index + 1
			end

			if i < #markers then
				formspec[formspec_index] = string.format(
					"box[%.2f,%.2f;%.2f,%.2f;#404060]",
					0,
					y_pos + marker_gui.list_item_height - 0.06,
					list_width - 0.1,
					0.03
				)
				formspec_index = formspec_index + 1
			end
		end
	end

	formspec[formspec_index] = "scroll_container_end[]"
	formspec_index = formspec_index + 1

	if #markers > 0 and #markers * marker_gui.list_item_height > scroll_h then
		local scroll_initial = marker_gui._scroll_pos[player_name] or "0"
		formspec[formspec_index] = string.format(
			"scrollbar[%.2f,%.2f;%.2f,%.2f;vertical;marker_list;%s]",
			scrollbar_x,
			scroll_y,
			marker_gui.scrollbar_width,
			scroll_h,
			scroll_initial
		)
		formspec_index = formspec_index + 1
	end

	local add_y = marker_gui.add_section_y
	formspec[formspec_index] = string.format(
		"label[%.2f,%.2f;Add Marker by Coordinates:]",
		pad,
		add_y
	)
	formspec_index = formspec_index + 1

	local field_width = 2.8
	local field_spacing = 0.25
	local fields_start_x = pad
	local field_y = add_y + 0.55

	formspec[formspec_index] = string.format("label[%.2f,%.2f;X:]", fields_start_x, add_y + 0.25)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,0.75;coord_x;;]",
		fields_start_x,
		field_y,
		field_width
	)
	formspec_index = formspec_index + 1

	local y_field_x = fields_start_x + field_width + field_spacing
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Y:]", y_field_x, add_y + 0.25)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,0.75;coord_y;;]",
		y_field_x,
		field_y,
		field_width
	)
	formspec_index = formspec_index + 1

	local z_field_x = y_field_x + field_width + field_spacing
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Z:]", z_field_x, add_y + 0.25)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,0.75;coord_z;;]",
		z_field_x,
		field_y,
		field_width
	)
	formspec_index = formspec_index + 1

	local name_field_x = z_field_x + field_width + field_spacing
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Name:]", name_field_x, add_y + 0.25)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,0.75;marker_name;;]",
		name_field_x,
		field_y,
		field_width
	)
	formspec_index = formspec_index + 1

	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,0.75;add_marker;Add Marker]",
		name_field_x + field_width + field_spacing,
		field_y,
		2.8
	)
	formspec_index = formspec_index + 1

	local footer_y = marker_gui.footer_y
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;close;Close]",
		pad,
		footer_y,
		marker_gui.button_width + 0.5,
		marker_gui.button_height
	)
	formspec_index = formspec_index + 1

	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;open_map;Open Map]",
		pad + marker_gui.button_width + 0.8,
		footer_y,
		marker_gui.button_width + 0.5,
		marker_gui.button_height
	)
	formspec_index = formspec_index + 1

	if #markers > 0 then
		formspec[formspec_index] = string.format(
			"button[%.2f,%.2f;%.2f,%.2f;delete_all_confirm;Delete All]",
			marker_gui.window_width - pad - marker_gui.button_width - 0.5,
			footer_y,
			marker_gui.button_width + 0.5,
			marker_gui.button_height
		)
		formspec_index = formspec_index + 1
	end

	if not can_tp then
		formspec[formspec_index] = string.format(
			"label[%.2f,%.2f;Note: 'teleport' privilege required for TP]",
			pad,
			footer_y + marker_gui.button_height + 0.12
		)
		formspec_index = formspec_index + 1
	end

	minetest.show_formspec(player_name, "persistent_map:marker_gui", table.concat(formspec))
end

local function show_color_selection_dialog(player_name, marker_id)
	local player = minetest.get_player_by_name(player_name)
	if not player then
		return
	end

	local player_data_entry = persistent_map.get_player_data(player_name)
	if not player_data_entry or not player_data_entry.markers[marker_id] then
		minetest.chat_send_player(player_name, "Error: Marker not found")
		return
	end

	local marker = player_data_entry.markers[marker_id]
	local current_color_index = marker.color_index or 1

	local formspec = {}
	formspec[1] = string.format("formspec_version[%d]", marker_gui.formspec_version)
	formspec[2] = "size[8,6]"
	formspec[3] = "bgcolor[#00000080;true]"
	formspec[4] = string.format(
		"label[4,0.5;Select Color for '%s']",
		minetest.formspec_escape(marker.name or "Unnamed")
	)

	local colors_per_row = 4
	local button_size = 1.5
	local button_spacing = 0.2
	local start_x = 1
	local start_y = 1.5
	local formspec_index = 5

	for i, color_info in ipairs(persistent_map.marker_colors) do
		local row = math.floor((i - 1) / colors_per_row)
		local col = (i - 1) % colors_per_row
		local btn_x = start_x + col * (button_size + button_spacing)
		local btn_y = start_y + row * (button_size + button_spacing)

		formspec[formspec_index] = string.format(
			"box[%.2f,%.2f;%.2f,%.2f;%s]",
			btn_x,
			btn_y,
			button_size,
			button_size,
			color_info.color
		)
		formspec_index = formspec_index + 1

		if i == current_color_index then
			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;#FFFFFF40]",
				btn_x - 0.1,
				btn_y - 0.1,
				button_size + 0.2,
				button_size + 0.2
			)
			formspec_index = formspec_index + 1
		end

		formspec[formspec_index] = string.format(
			"button[%.2f,%.2f;%.2f,%.2f;select_color_%d_%s;%s]",
			btn_x,
			btn_y,
			button_size,
			button_size,
			i,
			marker_id,
			color_info.name
		)
		formspec_index = formspec_index + 1
	end

	formspec[formspec_index] = "button[2,4.5;2,0.8;cancel_color_edit;Cancel]"
	minetest.show_formspec(player_name, "persistent_map:color_selection", table.concat(formspec))
end

local function show_name_edit_dialog(player_name, marker_id)
	local player_data_entry = persistent_map.get_player_data(player_name)
	if not player_data_entry or not player_data_entry.markers[marker_id] then
		minetest.chat_send_player(player_name, "Error: Marker not found")
		return
	end

	local marker = player_data_entry.markers[marker_id]
	local current_name = marker.name or "Unnamed"

	local formspec = {
		string.format("formspec_version[%d]", marker_gui.formspec_version),
		"size[8,4]",
		"bgcolor[#00000080;true]",
		"label[4,0.5;Edit Marker Name]",
		string.format("label[1,1.2;Current name: %s]", minetest.formspec_escape(current_name)),
		string.format(
			"field[1,1.8;6,0.8;new_marker_name;New name:;%s]",
			minetest.formspec_escape(current_name)
		),
		string.format("field[0,0;0,0;marker_id_hidden;;%s]", marker_id),
		"button[1,2.8;2,0.8;save_name;Save]",
		"button[4,2.8;2,0.8;cancel_name_edit;Cancel]",
	}

	minetest.show_formspec(player_name, "persistent_map:name_edit", table.concat(formspec))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "persistent_map:marker_gui" then
		return
	end

	local player_name = player:get_player_name()

	if fields.marker_list then
		marker_gui._scroll_pos[player_name] = fields.marker_list
	end

	if fields.close or fields.quit then
		return
	end

	if fields.open_map then
		persistent_map.set_map_view_offset(player_name, { x = 0, z = 0 })
		if not persistent_map.get_map_zoom_level(player_name) then
			persistent_map.set_map_zoom_level(player_name, persistent_map.default_zoom_index)
		end
		persistent_map.show_map(player_name)
		return
	end

	if fields.delete_all_confirm then
		local success, message = persistent_map.delete_all_markers_for_player(player_name)
		minetest.chat_send_player(player_name, message)
		if success then
			persistent_map.show_marker_gui(player_name)
		end
		return
	end

	if fields.add_marker then
		local x = tonumber(fields.coord_x or "")
		local y = tonumber(fields.coord_y or "")
		local z = tonumber(fields.coord_z or "")
		local name_str = fields.marker_name or ""

		if not x or not y or not z then
			minetest.chat_send_player(
				player_name,
				"Error: Enter valid numeric coordinates for X, Y, and Z"
			)
			return
		end

		if not persistent_map.is_coord_in_bounds(x, z) then
			minetest.chat_send_player(
				player_name,
				"Error: Coordinates are outside the genesis map region"
			)
			return
		end

		if name_str == "" then
			name_str = string.format("Marker at %d,%d,%d", math.floor(x), math.floor(y), math.floor(z))
		end

		local success, message = persistent_map.add_marker_for_player(
			player_name,
			{ x = x, y = y, z = z },
			name_str
		)
		minetest.chat_send_player(player_name, message)
		if success then
			persistent_map.show_marker_gui(player_name)
		end
		return
	end

	for field_name, _ in pairs(fields) do
		local delete_idx = field_name:match("^delete_(%d+)$")
		if delete_idx then
			local marker_id = marker_id_for_index(player_name, delete_idx)
			local player_data_entry = persistent_map.get_player_data(player_name)
			if marker_id and player_data_entry and player_data_entry.markers[marker_id] then
				local marker = player_data_entry.markers[marker_id]
				player_data_entry.markers[marker_id] = nil
				persistent_map.save_markers_for_player(player_name, player_data_entry.markers)
				minetest.chat_send_player(
					player_name,
					string.format("Deleted marker '%s'", marker.name or "Unnamed")
				)
				persistent_map.show_marker_gui(player_name)
			end
			return
		end

		local show_map_idx = field_name:match("^show_map_(%d+)$")
		if show_map_idx then
			local marker_id = marker_id_for_index(player_name, show_map_idx)
			local player_data_entry = persistent_map.get_player_data(player_name)
			if marker_id and player_data_entry and player_data_entry.markers[marker_id] then
				local marker = player_data_entry.markers[marker_id]
				local ok, err = persistent_map.center_map_on_coords(player_name, marker.x, marker.z)
				if not ok then
					minetest.chat_send_player(player_name, err or "Marker is outside the genesis map region")
					return
				end
				if not persistent_map.get_map_zoom_level(player_name) then
					persistent_map.set_map_zoom_level(player_name, persistent_map.default_zoom_index)
				end
				persistent_map.show_map(player_name)
				minetest.chat_send_player(
					player_name,
					string.format("Map centered on '%s'", marker.name or "Unnamed")
				)
			end
			return
		end

		local teleport_idx = field_name:match("^teleport_(%d+)$")
		if teleport_idx then
			if not can_teleport(player_name) then
				minetest.chat_send_player(player_name, "You need the 'teleport' privilege.")
				return
			end
			local marker_id = marker_id_for_index(player_name, teleport_idx)
			local player_data_entry = persistent_map.get_player_data(player_name)
			if marker_id and player_data_entry and player_data_entry.markers[marker_id] then
				local marker = player_data_entry.markers[marker_id]
				local pos = vector.new(marker.x, marker.y + 1, marker.z)
				for y_offset = 2, 10 do
					local test_pos = vector.new(marker.x, marker.y + y_offset, marker.z)
					if minetest.get_node(test_pos).name == "air"
						and minetest.get_node(vector.add(test_pos, { x = 0, y = 1, z = 0 })).name == "air"
					then
						pos = test_pos
						break
					end
				end
				player:set_pos(pos)
				minetest.chat_send_player(
					player_name,
					string.format("Teleported to '%s'", marker.name or "Unnamed")
				)
				minetest.close_formspec(player_name, "persistent_map:marker_gui")
			end
			return
		end

		local edit_color_idx = field_name:match("^edit_color_(%d+)$")
		if edit_color_idx then
			local marker_id = marker_id_for_index(player_name, edit_color_idx)
			if marker_id then
				show_color_selection_dialog(player_name, marker_id)
			end
			return
		end

		local edit_name_idx = field_name:match("^edit_name_(%d+)$")
		if edit_name_idx then
			local marker_id = marker_id_for_index(player_name, edit_name_idx)
			if marker_id then
				show_name_edit_dialog(player_name, marker_id)
			end
			return
		end

		local show_waypoint_idx = field_name:match("^show_waypoint_(%d+)$")
		if show_waypoint_idx then
			local marker_id = marker_id_for_index(player_name, show_waypoint_idx)
			local player_data_entry = persistent_map.get_player_data(player_name)
			if marker_id and player_data_entry and player_data_entry.markers[marker_id] then
				local marker = player_data_entry.markers[marker_id]
				marker.id = marker_id
				addWaypointHud(player, marker)
				minetest.chat_send_player(
					player_name,
					string.format("Waypoint set for '%s'", marker.name or "Unnamed")
				)
				persistent_map.show_marker_gui(player_name)
			end
			return
		end

		local remove_waypoint_idx = field_name:match("^remove_waypoint_(%d+)$")
		if remove_waypoint_idx then
			if removeWaypointHud(player) then
				minetest.chat_send_player(player_name, "Waypoint removed")
			else
				minetest.chat_send_player(player_name, "No active waypoint")
			end
			persistent_map.show_marker_gui(player_name)
			return
		end
	end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "persistent_map:name_edit" then
		return
	end

	local player_name = player:get_player_name()

	if fields.cancel_name_edit or fields.quit then
		persistent_map.show_marker_gui(player_name)
		return
	end

	if fields.save_name then
		local new_name = string.gsub(fields.new_marker_name or "", "^%s*(.-)%s*$", "%1")
		local marker_id = fields.marker_id_hidden or ""

		if marker_id == "" then
			minetest.chat_send_player(player_name, "Error: Invalid marker ID")
			persistent_map.show_marker_gui(player_name)
			return
		end
		if new_name == "" then
			minetest.chat_send_player(player_name, "Error: Marker name cannot be empty")
			return
		end

		local player_data_entry = persistent_map.get_player_data(player_name)
		if player_data_entry and player_data_entry.markers[marker_id] then
			local old_name = player_data_entry.markers[marker_id].name or "Unnamed"
			player_data_entry.markers[marker_id].name = new_name
			persistent_map.save_markers_for_player(player_name, player_data_entry.markers)
			minetest.chat_send_player(
				player_name,
				string.format("Renamed marker from '%s' to '%s'", old_name, new_name)
			)
		end
		persistent_map.show_marker_gui(player_name)
	end
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "persistent_map:color_selection" then
		return
	end

	local player_name = player:get_player_name()

	if fields.cancel_color_edit or fields.quit then
		persistent_map.show_marker_gui(player_name)
		return
	end

	for field_name, _ in pairs(fields) do
		local color_match = field_name:match("^select_color_(%d+)_(.+)$")
		if color_match then
			local color_index = tonumber(color_match)
			local marker_id = field_name:match("^select_color_%d+_(.+)$")
			local player_data_entry = persistent_map.get_player_data(player_name)
			if color_index and marker_id and player_data_entry and player_data_entry.markers[marker_id] then
				local marker = player_data_entry.markers[marker_id]
				marker.color_index = color_index
				persistent_map.save_markers_for_player(player_name, player_data_entry.markers)
				minetest.chat_send_player(
					player_name,
					string.format(
						"Changed color of '%s' to %s",
						marker.name or "Unnamed",
						persistent_map.marker_colors[color_index].name
					)
				)
			end
			persistent_map.show_marker_gui(player_name)
			return
		end
	end
end)

minetest.register_chatcommand("markers", {
	description = S("Open the marker management interface"),
	func = function(name)
		persistent_map.show_marker_gui(name)
		return true, S("Marker GUI opened")
	end,
})

minetest.register_chatcommand("marker", {
	description = S("Open the marker management interface"),
	func = function(name)
		persistent_map.show_marker_gui(name)
		return true, S("Marker GUI opened")
	end,
})

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
	active_waypoints[player_name] = nil
	marker_gui._row_ids[player_name] = nil
	marker_gui._scroll_pos[player_name] = nil
end)

minetest.log("action", "[persistent_map] Marker GUI loaded (Hashimon UX)")
