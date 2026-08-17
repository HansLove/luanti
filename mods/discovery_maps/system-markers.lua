-- Global system markers (managed by other mods, e.g. hashimon_vwar)

local STORAGE_KEY = "system_markers"
local system_markers = {}

local function load_system_markers()
	local raw = persistent_map.storage:get_string(STORAGE_KEY)
	if raw == "" then
		system_markers = {}
		return
	end
	local parsed = minetest.deserialize(raw)
	system_markers = type(parsed) == "table" and parsed or {}
end

local function save_system_markers()
	persistent_map.storage:set_string(STORAGE_KEY, minetest.serialize(system_markers))
end

function persistent_map.upsert_system_marker(source, marker_id, pos, name, color_index, meta)
	if not source or not marker_id or not pos then
		return false
	end
	local key = source .. ":" .. marker_id
	system_markers[key] = {
		source = source,
		id = marker_id,
		x = pos.x,
		y = pos.y,
		z = pos.z,
		name = name or "System",
		color_index = color_index or 6,
		meta = meta or {},
		timestamp = os.time(),
	}
	save_system_markers()
	return true
end

function persistent_map.remove_system_marker(source, marker_id)
	if not source or not marker_id then
		return false
	end
	system_markers[source .. ":" .. marker_id] = nil
	save_system_markers()
	return true
end

function persistent_map.remove_all_system_markers(source)
	if not source then
		return false
	end
	for key, marker in pairs(system_markers) do
		if marker.source == source then
			system_markers[key] = nil
		end
	end
	save_system_markers()
	return true
end

function persistent_map.get_system_markers()
	return system_markers
end

-- Draw one marker on the map formspec; returns updated formspec_index.
function persistent_map.render_map_marker(formspec, formspec_index, marker_key, marker, ctx)
	local view_center_x = ctx.view_center_x
	local view_center_z = ctx.view_center_z
	local radius = ctx.radius
	local tile_display_size = ctx.tile_display_size
	local zoom_factor = ctx.zoom_factor
	local zoom_index = ctx.zoom_index
	local tile_size_f = ctx.tile_size_f

	local marker_tile_x = math.floor(marker.x / tile_size_f)
	local marker_tile_z = math.floor(marker.z / tile_size_f)
	local marker_offset_x = marker_tile_x - view_center_x
	local marker_offset_z = marker_tile_z - view_center_z

	if math.abs(marker_offset_x) > radius or math.abs(marker_offset_z) > radius then
		return formspec_index
	end

	local gui_col = marker_offset_x + radius
	local gui_row = radius - marker_offset_z
	local marker_tile_gui_x = gui_col * tile_display_size
	local marker_tile_gui_y = gui_row * tile_display_size

	local tile_world_x = marker_tile_x * tile_size_f
	local tile_world_z = marker_tile_z * tile_size_f
	local marker_offset_in_tile_x = (marker.x - tile_world_x) / tile_size_f
	local marker_offset_in_tile_z = (marker.z - tile_world_z) / tile_size_f

	local marker_gui_x = marker_tile_gui_x + (marker_offset_in_tile_x * tile_display_size)
	local marker_gui_y = marker_tile_gui_y + ((1.0 - marker_offset_in_tile_z) * tile_display_size)

	local marker_scale_factor = persistent_map.map_marker.scale_factor
		* persistent_map.marker_scale * zoom_factor
	local half_marker_size = marker_scale_factor * persistent_map.map_marker.half_size_factor
	local color = persistent_map.marker_colors[marker.color_index] or persistent_map.marker_colors[6]

	for _ = 1, 5 do
		formspec[formspec_index] = string.format(
			"box[%.2f,%.2f;%.2f,%.2f;%s]",
			marker_gui_x - half_marker_size, marker_gui_y - half_marker_size,
			marker_scale_factor, marker_scale_factor, color.color
		)
		formspec_index = formspec_index + 1
	end

	local marker_name = marker.name or "Unnamed"
	if marker_name ~= "" and zoom_factor >= persistent_map.marker_name_min_zoom then
		local text_scale = math.max(
			persistent_map.marker_name_scale,
			zoom_factor * persistent_map.marker_name_zoom_multiplier
		)
		local char_width = persistent_map.marker_name_char_width * text_scale
		local text_height = persistent_map.marker_name_text_height * text_scale
		local name_y = marker_gui_y - half_marker_size - (text_height + persistent_map.marker_name_padding)
		local text_width = string.len(marker_name) * char_width
		local name_x = marker_gui_x - (text_width * persistent_map.map_marker.text_center_factor)
		local marker_name_x_offset = persistent_map.marker_name_zoom_x_offsets[zoom_index] or 0.0
		name_x = name_x + marker_name_x_offset

		local style_id = "sys_marker_" .. minetest.formspec_escape(marker_key):gsub("[^%w]", "_")
		formspec[formspec_index] = string.format(
			"style[%s;font_size=+%d]",
			style_id, math.floor(text_scale * persistent_map.marker_name_font_multiplier)
		)
		formspec_index = formspec_index + 1

		formspec[formspec_index] = string.format(
			"label[%.2f,%.2f;%s]",
			name_x, name_y, minetest.formspec_escape(marker_name)
		)
		formspec_index = formspec_index + 1
	end

	return formspec_index
end

load_system_markers()
