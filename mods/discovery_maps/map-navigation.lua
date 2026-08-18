-- Keyboard pan and fit-to-discovered view for persistent_map

local S = minetest.get_translator("discovery_maps")

local function view_radius_for_zoom_index(zoom_index)
	local zoom_factor = persistent_map.zoom_levels[zoom_index]
	return math.max(
		persistent_map.generation.min_radius,
		math.floor(persistent_map.view_radius / zoom_factor)
	)
end

function persistent_map.apply_map_pan(player_name, dx, dz)
	local offset = persistent_map.get_map_view_offset(player_name) or { x = 0, z = 0 }
	offset.x = offset.x + dx
	offset.z = offset.z + dz
	persistent_map.set_map_view_offset(player_name, offset)
	persistent_map.show_map(player_name)
end

local function get_discovered_bounds(player_name)
	local data = persistent_map.get_player_data(player_name)
	if not data or not data.discovered_tiles then
		return nil
	end

	local min_x, max_x, min_z, max_z
	for tile_id in pairs(data.discovered_tiles) do
		local tx, tz = tile_id:match("^tile_(-?%d+)_(-?%d+)$")
		if tx and tz then
			tx = tonumber(tx)
			tz = tonumber(tz)
			if not min_x or tx < min_x then min_x = tx end
			if not max_x or tx > max_x then max_x = tx end
			if not min_z or tz < min_z then min_z = tz end
			if not max_z or tz > max_z then max_z = tz end
		end
	end

	if not min_x then
		return nil
	end
	return min_x, max_x, min_z, max_z
end

local function pick_zoom_index_for_radius(needed_radius)
	for i = persistent_map.min_zoom_index, persistent_map.max_zoom_index do
		if view_radius_for_zoom_index(i) >= needed_radius then
			return i
		end
	end
	return persistent_map.min_zoom_index
end

function persistent_map.fit_map_to_discovered(player_name)
	local min_x, max_x, min_z, max_z = get_discovered_bounds(player_name)
	if not min_x then
		minetest.chat_send_player(player_name, S("No discovered tiles to show"))
		return false
	end

	local player = minetest.get_player_by_name(player_name)
	if not player then
		return false
	end
	local pos = player:get_pos()
	if not pos then
		return false
	end

	local center_tile_x = math.floor(pos.x / persistent_map.tile_size)
	local center_tile_z = math.floor(pos.z / persistent_map.tile_size)

	local bbox_cx = (min_x + max_x) / 2
	local bbox_cz = (min_z + max_z) / 2
	local span_x = max_x - min_x + 1
	local span_z = max_z - min_z + 1
	local needed_radius = math.ceil(math.max(span_x, span_z) / 2)

	local chosen_index = pick_zoom_index_for_radius(needed_radius)
	local zoom_offset = persistent_map.zoom_offsets[chosen_index] or { x = 0, z = 0 }

	persistent_map.set_map_zoom_level(player_name, chosen_index)
	persistent_map.set_map_view_offset(player_name, {
		x = math.floor(bbox_cx - center_tile_x - zoom_offset.x),
		z = math.floor(bbox_cz - center_tile_z - zoom_offset.z),
	})
	persistent_map.show_map(player_name)

	if view_radius_for_zoom_index(chosen_index) < needed_radius then
		minetest.chat_send_player(
			player_name,
			S("Exploration is very large — showing maximum zoom out. Pan to see more.")
		)
	end
	return true
end

function persistent_map.try_handle_map_navigation(player_name, fields)
	local fast = persistent_map.pan_fast_step

	if fields.key_up or fields.nav_north then
		persistent_map.apply_map_pan(player_name, 0, 1)
		return true
	elseif fields.key_down or fields.nav_south then
		persistent_map.apply_map_pan(player_name, 0, -1)
		return true
	elseif fields.key_left or fields.nav_west then
		persistent_map.apply_map_pan(player_name, -1, 0)
		return true
	elseif fields.key_right or fields.nav_east then
		persistent_map.apply_map_pan(player_name, 1, 0)
		return true
	elseif fields.nav_fast_north then
		persistent_map.apply_map_pan(player_name, 0, fast)
		return true
	elseif fields.nav_fast_south then
		persistent_map.apply_map_pan(player_name, 0, -fast)
		return true
	elseif fields.nav_fast_west then
		persistent_map.apply_map_pan(player_name, -fast, 0)
		return true
	elseif fields.nav_fast_east then
		persistent_map.apply_map_pan(player_name, fast, 0)
		return true
	elseif fields.nav_center then
		persistent_map.set_map_view_offset(player_name, { x = 0, z = 0 })
		persistent_map.show_map(player_name)
		return true
	elseif fields.fit_discovered then
		persistent_map.fit_map_to_discovered(player_name)
		return true
	end

	return false
end
