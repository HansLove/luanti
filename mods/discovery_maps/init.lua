-- Persistent Fullscreen Map Mod for Luanti

persistent_map = {}

-- Configuration
persistent_map.tile_size = 128 -- blocks per tile side
persistent_map.map_image_size = 128 -- pixels per tile image
persistent_map.scan_interval = 0.5 -- seconds between discovery checks
persistent_map.max_height = 80
persistent_map.min_height = -10
persistent_map.gui_tile_size = 5.0 -- formspec size for each tile (much larger)
persistent_map.view_radius = 6 -- tiles in each direction from center (13x13 grid, much bigger)
persistent_map.marker_scale = 7 -- Scale factor for markers (configurable)
persistent_map.player_marker_scale = 4 -- Scale factor for player marker (configurable)
persistent_map.marker_name_scale = 2.0 -- Base scale for marker name text (configurable)
persistent_map.marker_name_font_multiplier = 16 -- Font size multiplier for marker names (configurable)
persistent_map.marker_name_padding = 0.1 -- Padding between marker and name text
persistent_map.marker_name_min_zoom = 0.5 -- Minimum zoom level to show marker names
persistent_map.marker_name_zoom_multiplier = 1.5 -- Multiplier for text scale based on zoom
persistent_map.marker_name_char_width = 0.2 -- Character width estimation for text centering
persistent_map.marker_name_text_height = 0.3 -- Text height for positioning

-- Formspec UI Configuration
persistent_map.ui = {
	button_size = 5,           -- Size of navigation, zoom, and delete buttons (legacy)
	side_panel_button_size = 3.5,
	color_button_size = 3.5,     -- Size of marker color selection buttons in side panel
	side_panel_width = 15.0,      -- Width of left and right control panels
	padding = 1.0,               -- General padding around UI elements
	header_height = 1.0,         -- Height of the header area
	-- Bottom info section configuration
	info_bottom_margin = 4,      -- Distance from bottom of formspec to info section
	info_line_spacing = 2.0,     -- Vertical spacing between info lines
	info_left_align_with_panel = true,  -- Whether to align left info with left panel (true) or use padding (false)
	-- Navigation panel configuration
	nav_panel_offset = 2,        -- Vertical offset for navigation panel from header
	nav_section_spacing = 1,     -- Spacing between navigation sections
	nav_button_spacing = 0.2,    -- Spacing between navigation buttons
	nav_button_multiplier = 1.2, -- Multiplier for west button positioning
	nav_center_button_offset = 1, -- Offset for center button from other nav buttons
	zoom_section_offset = 2,     -- Offset for zoom section from navigation buttons
	zoom_button_spacing = 0.5,   -- Spacing for zoom buttons
	-- Marker panel configuration
	marker_name_label_spacing = 0.8, -- Spacing between "Marker Name:" label and input field
	marker_name_field_offset = 0.5, -- Offset for marker name input field
	marker_name_field_height = 1.0, -- Height of marker name input field
	marker_colors_offset = 2.8,  -- Offset for marker color buttons from coord fields
	colors_per_row = 2,          -- Number of color buttons per row
	color_button_spacing = 0.5,  -- Horizontal spacing between color buttons
	color_button_row_spacing = 0.3, -- Vertical spacing between color button rows
	delete_buttons_offset = 1,   -- Offset for delete buttons from color buttons
	delete_button_spacing = 0.3, -- Spacing between delete buttons
	-- Layout configuration
	formspec_version = 6,        -- Formspec version to use
	min_formspec_height = 25,    -- Minimum height for formspec
	header_title_offset = 4,     -- Offset for centering header title
	scroll_content_center = 0.5, -- Centering factor for scroll content
	field_width_offset = 0.5,    -- Width offset for input fields
	button_width_offset = 0.5,   -- Width offset for buttons
	-- Hardcoded value replacements
	half_divisor = 2,            -- Divisor for calculating half values (button_size / 2)
	arrow_height_factor = 0.5,   -- Factor for arrow height calculation in player marker
	total_width_factor = 0.5,    -- Factor for calculating half total width
	padding_multiplier = 2,      -- Multiplier for padding calculations
}

-- Player marker configuration
persistent_map.player_marker = {
	arrow_size = 0.25,           -- Base size of player arrow
	arrow_height = 0.35,         -- Height of player arrow
	main_body_size = 0.2,        -- Size of main body square
	tip_size = 0.14,             -- Size of directional tip
	mid_section_size = 0.16,     -- Size of mid-section indicator
	wing_size = 0.1,             -- Size of wing indicators
	mid_section_factor = 0.5,    -- Factor for mid-section positioning
	wing_factor = 0.6,           -- Factor for wing positioning
}

-- Map marker configuration
persistent_map.map_marker = {
	scale_factor = 0.15,         -- Base scale factor for markers
	half_size_factor = 0.5,      -- Factor for calculating half marker size
	text_center_factor = 0.6,    -- Factor for centering text -(pos offsets text left)
	position_flip_factor = 1.0,  -- Factor for flipping Z position (1.0 = flip, 0.0 = no flip)
}

-- Map generation configuration
persistent_map.generation = {
	default_color_r = 100,       -- Default color red component
	default_color_g = 100,       -- Default color green component
	default_color_b = 100,       -- Default color blue component
	alpha_value = 255,           -- Alpha value for colors
	min_radius = 2,              -- Minimum radius for view calculations
	y_scan_step = -1,            -- Step for Y scanning (negative = top to bottom)
	tile_center_offset = 2,      -- Offset for tile center calculation (tile_size / 2)
	initial_discovery_delay = 0.1, -- Delay for initial tile discovery on player join
}

-- Zoom configuration
-- At max zoom, one tile should fill the screen (map area is ~65 units, base tile is 5, so need ~13x zoom)
persistent_map.zoom_levels = {0.125, 0.25, 0.5, 1.0, 2.0, 4.0, 6.0, 8.0, 10.0, 13.0, 16.0, 20.0}
persistent_map.default_zoom_index = 4 -- Default to 1.0x zoom
persistent_map.min_zoom_index = 1
persistent_map.max_zoom_index = 12

-- Zoom level offsets for proper player centering
-- These offsets compensate for the player marker appearing off-center at higher zoom levels
-- Values correspond to navigation button clicks: East = +X, South = -Z
persistent_map.zoom_offsets = {
	[1] = {x = 0, z = 0},    -- 0.125x zoom
	[2] = {x = 0, z = 0},    -- 0.25x zoom
	[3] = {x = 0, z = 0},    -- 0.5x zoom
	[4] = {x = 0, z = 0},    -- 1.0x zoom
	[5] = {x = 0, z = 0},    -- 2.0x zoom
	[6] = {x = 1, z = -1},   -- 4.0x zoom
	[7] = {x = 2, z = -1},   -- 6.0x zoom
	[8] = {x = 2, z = -2},   -- 8.0x zoom
	[9] = {x = 2, z = -2},   -- 10.0x zoom
	[10] = {x = 2, z = -2},  -- 13.0x zoom
	[11] = {x = 2, z = -2},  -- 16.0x zoom
	[12] = {x = 2, z = -2},  -- 20.0x zoom
}

-- Zoom level X offsets for marker name text positioning
persistent_map.marker_name_zoom_x_offsets = {
	[1] = 0.0,
	[2] = 0.0,
	[3] = 0.0,
	[4] = 0.0,
	[5] = 0.0,
	[6] = 5,
	[7] = 10,
	[8] = 20,
	[9] = 25,
	[10] = 30,
	[11] = 30,
	[12] = 30,
}

-- World bounds (genesis region) — set by refresh_world_bounds() from mapgen_limit
persistent_map.world_size = 0
persistent_map.total_world_tiles = 0
persistent_map.world_min = nil
persistent_map.world_max = nil
persistent_map.tile_min = nil
persistent_map.tile_max = nil

-- Marker system configuration
persistent_map.marker_colors = {
	{name = "Red", color = "#FF0000"},
	{name = "Blue", color = "#0000FF"},
	{name = "Green", color = "#00FF00"},
	{name = "Yellow", color = "#FFFF00"},
	{name = "Purple", color = "#FF00FF"},
	{name = "Orange", color = "#FF8000"},
	{name = "White", color = "#FFFFFF"},
	{name = "Pink", color = "#FF80FF"}
}
persistent_map.marker_delete_distance = 25 -- blocks within which player can delete markers

local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local S = minetest.get_translator(modname)

-- Storage
local storage = minetest.get_mod_storage()
local worldpath = minetest.get_worldpath()
local map_path = worldpath .. "/persistent_maps/"
minetest.mkdir(map_path)

-- Make storage accessible to other modules
persistent_map.storage = storage
persistent_map.map_path = map_path

dofile(modpath .. "/system-markers.lua")
dofile(modpath .. "/map-navigation.lua")

-- Player data - isolated per player
local player_data = {}
local map_view_offset = {} -- Stores view offset for each player
local map_zoom_level = {} -- Stores zoom level index for each player
local map_open = {} -- Players with persistent_map:map formspec open
local last_place_color = {} -- Last color index used when placing markers
local tile_repair_queue = {} -- Per-player missing PNG tiles to regenerate
local tile_repair_pending = {} -- Dedupe in-flight tile generation
local frontier_notified = {} -- One-shot genesis frontier message per edge visit

persistent_map.pending_tile_color = "#7A8A9A"
persistent_map.pan_fast_step = 3

function persistent_map.mark_map_open(player_name, open)
	if open then
		map_open[player_name] = true
	else
		map_open[player_name] = nil
	end
end

function persistent_map.refresh_map_if_open(player_name)
	if map_open[player_name] then
		persistent_map.show_map(player_name)
	end
end

local nodecolors = dofile(modpath .. "/nodecolors.lua")

-- Cache for node colors to avoid repeated lookups
local node_color_cache = {}

-- Get color for a node with caching
local function get_node_color(nodename)
	local cached_color = node_color_cache[nodename]
	if cached_color then
		return cached_color
	end
	
	local color = nodecolors.get_color(nodename)
	node_color_cache[nodename] = color
	return color
end

-- Convert world position to tile coordinates with proper orientation
-- X increases East, Z increases North
local function pos_to_tile_coords(pos)
	return math.floor(pos.x / persistent_map.tile_size),
	       math.floor(pos.z / persistent_map.tile_size)
end

-- Convert tile coordinates to world position (center of tile)
local function tile_coords_to_pos(tile_x, tile_z)
	return vector.new(
		tile_x * persistent_map.tile_size + persistent_map.tile_size / 2,
		0,
		tile_z * persistent_map.tile_size + persistent_map.tile_size / 2
	)
end

-- Get tile ID from coordinates
local function get_tile_id(tile_x, tile_z)
	return string.format("tile_%d_%d", tile_x, tile_z)
end

function persistent_map.refresh_world_bounds()
	local minp, maxp = minetest.get_mapgen_edges()
	local min_x, max_x = minp.x, maxp.x
	local min_z, max_z = minp.z, maxp.z

	local config_limit = tonumber(minetest.settings:get("discovery_maps_genesis_limit"))
	if config_limit and config_limit > 0 then
		local mapgen_limit = tonumber(minetest.get_mapgen_setting("mapgen_limit")) or config_limit
		local effective = math.min(config_limit, mapgen_limit)
		min_x = -effective
		max_x = effective
		min_z = -effective
		max_z = effective
	end

	persistent_map.world_min = { x = min_x, z = min_z }
	persistent_map.world_max = { x = max_x, z = max_z }

	local ts = persistent_map.tile_size
	persistent_map.tile_min = {
		x = math.floor(min_x / ts),
		z = math.floor(min_z / ts),
	}
	persistent_map.tile_max = {
		x = math.floor(max_x / ts),
		z = math.floor(max_z / ts),
	}

	local tiles_x = persistent_map.tile_max.x - persistent_map.tile_min.x + 1
	local tiles_z = persistent_map.tile_max.z - persistent_map.tile_min.z + 1
	persistent_map.total_world_tiles = tiles_x * tiles_z
	persistent_map.world_size = math.max(max_x - min_x + 1, max_z - min_z + 1)

	minetest.log(
		"action",
		string.format(
			"[persistent_map] Genesis bounds X[%d..%d] Z[%d..%d] (%d tiles)",
			min_x, max_x, min_z, max_z, persistent_map.total_world_tiles
		)
	)
end

function persistent_map.is_tile_in_bounds(tile_x, tile_z)
	if not persistent_map.world_min then
		return true
	end
	local ts = persistent_map.tile_size
	local tile_min_x = tile_x * ts
	local tile_max_x = (tile_x + 1) * ts - 1
	local tile_min_z = tile_z * ts
	local tile_max_z = (tile_z + 1) * ts - 1
	local wmin = persistent_map.world_min
	local wmax = persistent_map.world_max
	return tile_min_x <= wmax.x and tile_max_x >= wmin.x
		and tile_min_z <= wmax.z and tile_max_z >= wmin.z
end

function persistent_map.is_pos_in_bounds(pos)
	if not persistent_map.world_min or not pos then
		return true
	end
	local wmin = persistent_map.world_min
	local wmax = persistent_map.world_max
	return pos.x >= wmin.x and pos.x <= wmax.x
		and pos.z >= wmin.z and pos.z <= wmax.z
end

function persistent_map.is_coord_in_bounds(world_x, world_z)
	if not persistent_map.world_min then
		return true
	end
	return world_x >= persistent_map.world_min.x and world_x <= persistent_map.world_max.x
		and world_z >= persistent_map.world_min.z and world_z <= persistent_map.world_max.z
end

persistent_map.refresh_world_bounds()

-- Check if tile exists on disk
local function tile_exists(tile_id)
	local filename = map_path .. tile_id .. ".png"
	local file = io.open(filename, "r")
	if file then
		file:close()
		return true
	end
	return false
end

function persistent_map.center_map_on_coords(player_name, world_x, world_z)
	local player = minetest.get_player_by_name(player_name)
	if not player then
		return false, "Player not found"
	end
	local pos = player:get_pos()
	if not pos then
		return false, "Could not read player position"
	end
	local target_tile_x = math.floor(world_x / persistent_map.tile_size)
	local target_tile_z = math.floor(world_z / persistent_map.tile_size)
	if not persistent_map.is_tile_in_bounds(target_tile_x, target_tile_z) then
		return false, "Coordinates are outside the genesis map region"
	end
	local center_tile_x, center_tile_z = pos_to_tile_coords(pos)
	map_view_offset[player_name] = {
		x = target_tile_x - center_tile_x,
		z = target_tile_z - center_tile_z,
	}
	return true
end

function persistent_map.view_center_world_coords(player_name)
	local player = minetest.get_player_by_name(player_name)
	if not player then
		return nil
	end
	local pos = player:get_pos()
	if not pos then
		return nil
	end
	local view_offset = map_view_offset[player_name] or { x = 0, z = 0 }
	local zoom_index = map_zoom_level[player_name] or persistent_map.default_zoom_index
	local zoom_offset = persistent_map.zoom_offsets[zoom_index] or { x = 0, z = 0 }
	local center_tile_x, center_tile_z = pos_to_tile_coords(pos)
	local view_center_x = center_tile_x + view_offset.x + zoom_offset.x
	local view_center_z = center_tile_z + view_offset.z + zoom_offset.z
	local ts = persistent_map.tile_size
	return {
		x = math.floor(view_center_x * ts + ts / 2),
		y = math.floor(pos.y),
		z = math.floor(view_center_z * ts + ts / 2),
		tile_x = view_center_x,
		tile_z = view_center_z,
	}
end

local function queue_tile_repair(player_name, tile_x, tile_z)
	if not persistent_map.is_tile_in_bounds(tile_x, tile_z) then
		return
	end
	if not tile_repair_queue[player_name] then
		tile_repair_queue[player_name] = {}
	end
	local key = get_tile_id(tile_x, tile_z)
	if tile_exists(key) or tile_repair_pending[key] then
		return
	end
	tile_repair_queue[player_name][key] = { x = tile_x, z = tile_z }
end

-- Marker system functions
local function load_player_markers(player_name)
	local data = storage:get_string("markers_" .. player_name)
	if data == "" then
		return {}
	end
	local markers = minetest.deserialize(data) or {}
	
	-- Migrate existing markers to include names if they don't have them
	for marker_id, marker in pairs(markers) do
		if not marker.name then
			marker.name = string.format("Marker %d,%d", math.floor(marker.x), math.floor(marker.z))
		end
	end
	
	return markers
end

local function save_player_markers(player_name, markers)
	storage:set_string("markers_" .. player_name, minetest.serialize(markers))
end

local function add_marker(player_name, pos, color_index, name)
	if not player_data[player_name] then
		return false
	end
	if not persistent_map.is_pos_in_bounds(pos) then
		return false, "Cannot place marker outside the genesis map region"
	end
	
	local markers = player_data[player_name].markers
	local marker_id = string.format("marker_%d_%d_%d", math.floor(pos.x), math.floor(pos.y), math.floor(pos.z))
	
	-- Check if marker already exists at this position
	if markers[marker_id] then
		return false, "Marker already exists at this position"
	end
	
	-- Add marker with name
	markers[marker_id] = {
		x = pos.x,
		y = pos.y,
		z = pos.z,
		color_index = color_index,
		name = name or "Unnamed",
		timestamp = os.time()
	}
	
	save_player_markers(player_name, markers)
	return true, "Marker '" .. (name or "Unnamed") .. "' placed"
end

local function remove_marker_near_player(player_name, player_pos)
	if not player_data[player_name] then
		return false, "Player data not found"
	end
	
	local markers = player_data[player_name].markers
	local removed_count = 0
	
	-- Find markers within delete distance
	for marker_id, marker in pairs(markers) do
		local marker_pos = vector.new(marker.x, marker.y, marker.z)
		local distance = vector.distance(player_pos, marker_pos)
		
		if distance <= persistent_map.marker_delete_distance then
			markers[marker_id] = nil
			removed_count = removed_count + 1
		end
	end
	
	if removed_count > 0 then
		save_player_markers(player_name, markers)
		return true, string.format("Removed %d marker(s)", removed_count)
	else
		return false, "No markers found nearby"
	end
end

-- Delete all markers for a player
local function delete_all_markers(player_name)
	if not player_data[player_name] then
		return false, "Player data not found"
	end
	
	-- Clear markers only
	player_data[player_name].markers = {}
	save_player_markers(player_name, {})
	
	return true, "All markers deleted"
end

-- Accessor functions for marker-gui.lua
function persistent_map.get_player_data(player_name)
	return player_data[player_name]
end

function persistent_map.get_map_view_offset(player_name)
	return map_view_offset[player_name]
end

function persistent_map.set_map_view_offset(player_name, offset)
	map_view_offset[player_name] = offset
end

function persistent_map.get_map_zoom_level(player_name)
	return map_zoom_level[player_name]
end

function persistent_map.set_map_zoom_level(player_name, zoom_level)
	map_zoom_level[player_name] = zoom_level
end

function persistent_map.delete_all_markers_for_player(player_name)
	return delete_all_markers(player_name)
end

function persistent_map.save_markers_for_player(player_name, markers)
	return save_player_markers(player_name, markers)
end

function persistent_map.add_marker_for_player(player_name, pos, name, color_index)
	return add_marker(player_name, pos, color_index or 1, name)
end

-- Generate a single map tile with proper coordinate mapping
local function generate_tile(tile_x, tile_z, callback)
	local tile_id = get_tile_id(tile_x, tile_z)

	if not persistent_map.is_tile_in_bounds(tile_x, tile_z) then
		if callback then
			callback(tile_id)
		end
		return tile_id
	end

	-- Skip if already exists
	if tile_exists(tile_id) then
		if callback then callback(tile_id) end
		return tile_id
	end
	
	-- Calculate world bounds for this tile
	local minp = vector.new(
		tile_x * persistent_map.tile_size,
		persistent_map.min_height,
		tile_z * persistent_map.tile_size
	)
	local maxp = vector.new(
		(tile_x + 1) * persistent_map.tile_size - 1,
		persistent_map.max_height,
		(tile_z + 1) * persistent_map.tile_size - 1
	)
	
	-- Emerge area first
	minetest.emerge_area(minp, maxp, function(blockpos, action, calls_remaining)
		if calls_remaining > 0 then return end
		
		-- Generate pixel data with proper orientation
		-- Image coordinates: (0,0) at top-left, x increases right, y increases down
		-- World coordinates: x increases east, z increases north
		local pixels = {}
		local pixel_count = persistent_map.tile_size * persistent_map.tile_size
		
		-- Pre-allocate pixel array for better performance
		for i = 1, pixel_count do
			pixels[i] = ""
		end
		
		local tile_size = persistent_map.tile_size
		local min_x, max_z = minp.x, maxp.z
		local max_y, min_y = maxp.y, minp.y
		local default_color = string.char(persistent_map.generation.default_color_r, persistent_map.generation.default_color_g, persistent_map.generation.default_color_b, persistent_map.generation.alpha_value)
		
		-- Iterate through world coordinates properly
		-- For image: top-to-bottom corresponds to north-to-south (z decreasing)
		-- For image: left-to-right corresponds to west-to-east (x increasing)
		local pixel_index = 1
		for img_y = 0, tile_size - 1 do
			local world_z = max_z - img_y  -- Flip Z to match image orientation
			for img_x = 0, tile_size - 1 do
				local world_x = min_x + img_x
				
				local color = default_color
				
				-- Scan from top to bottom for surface node
				for y = max_y, min_y, -1 do
					local node = minetest.get_node({x=world_x, y=y, z=world_z})
					if node.name ~= "air" and node.name ~= "ignore" then
						local node_color = get_node_color(node.name)
						color = string.char(node_color[1], node_color[2], node_color[3], persistent_map.generation.alpha_value)
						break
					end
				end
				
				pixels[pixel_index] = color
				pixel_index = pixel_index + 1
			end
		end
		
		-- Save as PNG
		local filename = map_path .. tile_id .. ".png"
		local png_data = minetest.encode_png(
			persistent_map.tile_size,
			persistent_map.tile_size,
			table.concat(pixels)
		)
		minetest.safe_file_write(filename, png_data)
		
		-- Load texture dynamically
		minetest.dynamic_add_media(filename, function()
			if callback then callback(tile_id) end
		end)
	end)
	
	return tile_id
end

local function ensure_tile_generated(player_name, tile_x, tile_z)
	if not persistent_map.is_tile_in_bounds(tile_x, tile_z) then
		return
	end
	local tile_id = get_tile_id(tile_x, tile_z)
	if tile_exists(tile_id) or tile_repair_pending[tile_id] then
		return
	end
	tile_repair_pending[tile_id] = true
	generate_tile(tile_x, tile_z, function()
		tile_repair_pending[tile_id] = nil
		local filename = map_path .. tile_id .. ".png"
		minetest.dynamic_add_media({
			filepath = filename,
			to_player = player_name,
		}, function()
			persistent_map.refresh_map_if_open(player_name)
		end)
	end)
end

-- Load player discovered tiles
local function load_player_tiles(player_name)
	local data = storage:get_string("player_" .. player_name)
	if data == "" then
		return {}
	end
	return minetest.deserialize(data) or {}
end

-- Save player discovered tiles
local function save_player_tiles(player_name, tiles)
	storage:set_string("player_" .. player_name, minetest.serialize(tiles))
end

-- Check if a tile is discovered by a specific player
local function is_tile_discovered(player_name, tile_x, tile_z)
	if not player_data[player_name] then
		return false
	end
	
	local tiles = player_data[player_name].discovered_tiles
	local tile_id = get_tile_id(tile_x, tile_z)
	return tiles[tile_id] ~= nil
end

-- Add discovered tile for player
local function add_discovered_tile(player_name, tile_x, tile_z, callback)
	if not player_data[player_name] then
		return false
	end
	if not persistent_map.is_tile_in_bounds(tile_x, tile_z) then
		return false
	end

	local tiles = player_data[player_name].discovered_tiles
	local tile_id = get_tile_id(tile_x, tile_z)
	
	-- Check if already discovered
	if tiles[tile_id] then
		return false
	end
	
	-- Add to player's discovered tiles
	tiles[tile_id] = {x = tile_x, z = tile_z}
	save_player_tiles(player_name, tiles)
	
	-- Generate tile if it doesn't exist (shared resource)
	generate_tile(tile_x, tile_z, function(id)
		minetest.log("action", "[persistent_map] Generated tile: " .. id .. " for " .. player_name)
		
		-- Send the tile to this specific player
		local filename = map_path .. tile_id .. ".png"
		minetest.dynamic_add_media({
			filepath = filename,
			to_player = player_name,
		}, function(pname)
			minetest.log("action", "[persistent_map] Sent tile " .. id .. " to " .. pname)
			-- Call the callback after tile generation and sending is complete
			if callback then
				callback()
			end
		end)
	end)
	
	return true
end

-- Get player's position within their current tile (0.0 to 1.0)
local function get_position_in_tile(pos)
	local tile_x, tile_z = pos_to_tile_coords(pos)
	local tile_world_x = tile_x * persistent_map.tile_size
	local tile_world_z = tile_z * persistent_map.tile_size
	
	local offset_x = (pos.x - tile_world_x) / persistent_map.tile_size
	local offset_z = (pos.z - tile_world_z) / persistent_map.tile_size
	
	return offset_x, offset_z
end

-- Show map GUI with player-centered view and proper orientation
function persistent_map.show_map(player_name)
	local player = minetest.get_player_by_name(player_name)
	if not player then return end
	
	-- Ensure player data exists
	if not player_data[player_name] then
		minetest.log("warning", "[persistent_map] Player data not found for " .. player_name)
		return
	end
	
	local tiles = player_data[player_name].discovered_tiles
	local markers = player_data[player_name].markers
	local pos = player:get_pos()
	local center_tile_x, center_tile_z = pos_to_tile_coords(pos)
	
	-- Get current view offset (defaults to 0, 0 - centered on player)
	local view_offset = map_view_offset[player_name] or {x = 0, z = 0}
	
	-- Get current zoom level (defaults to default zoom)
	local zoom_index = map_zoom_level[player_name] or persistent_map.default_zoom_index
	local zoom_factor = persistent_map.zoom_levels[zoom_index]
	
	-- Get zoom-specific offset for proper player centering
	local zoom_offset = persistent_map.zoom_offsets[zoom_index] or {x = 0, z = 0}
	
	-- Apply both manual view offset and zoom-specific centering offset
	local view_center_x = center_tile_x + view_offset.x + zoom_offset.x
	local view_center_z = center_tile_z + view_offset.z + zoom_offset.z
	
	-- Calculate player's precise position within the tile (for marker placement)
	local offset_x, offset_z = get_position_in_tile(pos)
	
	-- View configuration - adjust radius based on zoom to keep reasonable map size
	-- At higher zoom levels, show fewer tiles but make them much larger
	local base_radius = persistent_map.view_radius
	local radius = math.max(persistent_map.generation.min_radius, math.floor(base_radius / zoom_factor))
	local view_size = radius * 2 + 1
	local tile_display_size = persistent_map.gui_tile_size * zoom_factor
	
	-- FIXED LAYOUT: Static formspec size regardless of zoom
	-- Use base tile size for layout calculations to keep formspec static
	local base_tile_size = persistent_map.gui_tile_size
	local base_view_size = persistent_map.view_radius * 2 + 1
	local map_width = base_view_size * base_tile_size
	local map_height = base_view_size * base_tile_size
	
	-- Side panels beside map (uses vertical space; avoids bottom-toolbar overlap)
	local side_panel_width = persistent_map.ui.side_panel_width
	local padding = persistent_map.ui.padding
	local header_height = persistent_map.ui.header_height
	local button_size = persistent_map.ui.button_size
	local side_btn = persistent_map.ui.side_panel_button_size
	local left_panel_x = padding
	local map_x = left_panel_x + side_panel_width + padding
	local right_panel_x = map_x + map_width + padding
	local total_width = padding + side_panel_width + padding + map_width + padding + side_panel_width + padding
	local total_height = math.max(
		map_height + header_height + padding * persistent_map.ui.padding_multiplier,
		persistent_map.ui.min_formspec_height
	)

	local half_total_width = total_width * persistent_map.ui.total_width_factor
	local map_start_y = padding + header_height
	
	-- Use table for better performance than repeated string.format calls
	local formspec = {}
	formspec[1] = string.format("formspec_version[%d]", persistent_map.ui.formspec_version)
	formspec[2] = string.format("size[%.2f,%.2f]", total_width, total_height)
	formspec[3] = "bgcolor[#000000FF;true]"
	-- field_close_on_enter needs a field name: field_close_on_enter[<name>;<bool>].
	-- The bare "[false]" form is invalid and logs "Invalid field_close_on_enter
	-- element(1):'false'". Declare it per text field so Enter navigates/submits
	-- instead of closing the whole map.
	formspec[4] = "field_close_on_enter[goto_x;false]"
		.. "field_close_on_enter[goto_z;false]"
		.. "field_close_on_enter[marker_name;false]"
	formspec[5] = string.format("label[%.2f,%.2f;Discovered Map - Close with ESC]", half_total_width - persistent_map.ui.header_title_offset, padding)
	local formspec_index = 6
	
	-- Add scrollable container for the map area (2D: vertical outer, horizontal inner)
	local scroll_width = map_width
	local scroll_height = map_height
	local actual_content_width = view_size * tile_display_size
	local actual_content_height = view_size * tile_display_size
	local h_scroll = math.max(0, (actual_content_width - scroll_width) * persistent_map.ui.scroll_content_center)
	local v_scroll = math.max(0, (actual_content_height - scroll_height) * persistent_map.ui.scroll_content_center)

	formspec[formspec_index] = string.format(
		"scroll_container[%.2f,%.2f;%.2f,%.2f;map_scroll_y;vertical;%.2f]",
		map_x, map_start_y, scroll_width, scroll_height, v_scroll
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"scroll_container[0,0;%.2f,%.2f;map_scroll;horizontal;%.2f]",
		actual_content_width, actual_content_height, h_scroll
	)
	formspec_index = formspec_index + 1
	
	-- Count discovered tiles in view
	local discovered_count = 0
	local total_tiles = view_size * view_size
	
	-- Pre-calculate values for the tile loop
	local player_tiles = player_data[player_name].discovered_tiles
	
	-- Draw tiles in a grid with proper orientation
	-- GUI grid: (0,0) at top-left, x increases right, y increases down
	-- World grid: x increases east, z increases north
	-- Map display: North at top, East at right
	for gui_row = 0, view_size - 1 do
		local tile_z_base = view_center_z + radius - gui_row  -- Pre-calculate Z base
		local gui_y = gui_row * tile_display_size
		
		for gui_col = 0, view_size - 1 do
			-- Convert GUI grid position to world tile coordinates
			local tile_x = view_center_x + gui_col - radius
			local tile_z = tile_z_base
			
			-- Calculate GUI position within scroll container (relative to container origin)
			local gui_x = gui_col * tile_display_size
			
			-- Check if THIS PLAYER has discovered this tile (optimized lookup)
			local tile_id = string.format("tile_%d_%d", tile_x, tile_z)
			if player_tiles[tile_id] then
				discovered_count = discovered_count + 1
				
				-- Verify tile exists before trying to display
				if tile_exists(tile_id) then
					formspec[formspec_index] = string.format(
						"image[%.2f,%.2f;%.2f,%.2f;%s.png]",
						gui_x, gui_y, tile_display_size, tile_display_size, tile_id
					)
				else
					-- Discovered but PNG not ready yet
					formspec[formspec_index] = string.format(
						"box[%.2f,%.2f;%.2f,%.2f;%s]",
						gui_x, gui_y, tile_display_size, tile_display_size,
						persistent_map.pending_tile_color
					)
					ensure_tile_generated(player_name, tile_x, tile_z)
				end
			else
				-- Draw undiscovered tile (fog of war)
				formspec[formspec_index] = string.format(
					"box[%.2f,%.2f;%.2f,%.2f;#000000]",
					gui_x, gui_y, tile_display_size, tile_display_size
				)
			end
			formspec_index = formspec_index + 1

			if hashimon_vwar and hashimon_vwar.tile_in_war_zone
				and hashimon_vwar.tile_in_war_zone(tile_x, tile_z) then
				formspec[formspec_index] = string.format(
					"box[%.2f,%.2f;%.2f,%.2f;#FF0000AA]",
					gui_x, gui_y, tile_display_size, tile_display_size
				)
				formspec_index = formspec_index + 1
			end
		end
	end
	
	-- Draw markers on the map (optimized)
	local marker_scale_factor = persistent_map.map_marker.scale_factor * persistent_map.marker_scale * zoom_factor
	local half_marker_size = marker_scale_factor * persistent_map.map_marker.half_size_factor
	local tile_size_f = persistent_map.tile_size
	
	for marker_id, marker in pairs(markers) do
		-- Inline tile coordinate calculation for better performance
		local marker_tile_x = math.floor(marker.x / tile_size_f)
		local marker_tile_z = math.floor(marker.z / tile_size_f)
		
		-- Check if marker is within visible area
		local marker_offset_x = marker_tile_x - view_center_x
		local marker_offset_z = marker_tile_z - view_center_z
		
		if math.abs(marker_offset_x) <= radius and math.abs(marker_offset_z) <= radius then
			-- Convert world tile offset to GUI position
			local gui_col = marker_offset_x + radius
			local gui_row = radius - marker_offset_z  -- Flip Z for display
			
			local marker_tile_gui_x = gui_col * tile_display_size
			local marker_tile_gui_y = gui_row * tile_display_size
			
			-- Calculate precise position within tile (inlined for performance)
			local tile_world_x = marker_tile_x * tile_size_f
			local tile_world_z = marker_tile_z * tile_size_f
			local marker_offset_in_tile_x = (marker.x - tile_world_x) / tile_size_f
			local marker_offset_in_tile_z = (marker.z - tile_world_z) / tile_size_f
			
			local marker_gui_x = marker_tile_gui_x + (marker_offset_in_tile_x * tile_display_size)
			local marker_gui_y = marker_tile_gui_y + ((1.0 - marker_offset_in_tile_z) * tile_display_size)  -- Flip Z offset
			
			-- Draw marker dot (scaled with zoom) - stack 5 transparent squares for solid appearance
			local color = persistent_map.marker_colors[marker.color_index] or persistent_map.marker_colors[1]
			for stack_layer = 1, 5 do
				formspec[formspec_index] = string.format(
					"box[%.2f,%.2f;%.2f,%.2f;%s]",
					marker_gui_x - half_marker_size, marker_gui_y - half_marker_size,
					marker_scale_factor, marker_scale_factor, color.color
				)
				formspec_index = formspec_index + 1
			end
			
			-- Draw marker name above the marker (if it has a name and zoom is sufficient)
			local marker_name = marker.name or "Unnamed"
			if marker_name ~= "" and zoom_factor >= persistent_map.marker_name_min_zoom then  -- Show names at lower zoom levels too
				-- Scale text size with zoom factor using configurable values
				local text_scale = math.max(persistent_map.marker_name_scale, zoom_factor * persistent_map.marker_name_zoom_multiplier)
				local char_width = persistent_map.marker_name_char_width * text_scale  -- Character width estimation scaled
				local text_height = persistent_map.marker_name_text_height * text_scale  -- Text height scaled
				
				local name_y = marker_gui_y - half_marker_size - (text_height + persistent_map.marker_name_padding)  -- Position above marker with configurable padding
				local text_width = string.len(marker_name) * char_width
				local name_x = marker_gui_x - (text_width * persistent_map.map_marker.text_center_factor)  -- Center text properly
				
				-- Apply zoom-specific X offset for marker name positioning
				local marker_name_x_offset = persistent_map.marker_name_zoom_x_offsets[zoom_index] or 0.0
				name_x = name_x + marker_name_x_offset
				
				-- Add the marker name label with configurable font size
				formspec[formspec_index] = string.format(
					"style[marker_name_%s;font_size=+%d]",
					marker_id, math.floor(text_scale * persistent_map.marker_name_font_multiplier)
				)
				formspec_index = formspec_index + 1
				
				formspec[formspec_index] = string.format(
					"label[%.2f,%.2f;%s]",
					name_x, name_y, minetest.formspec_escape(marker_name)
				)
				formspec_index = formspec_index + 1
			end
		end
	end

	local marker_ctx = {
		view_center_x = view_center_x,
		view_center_z = view_center_z,
		radius = radius,
		tile_display_size = tile_display_size,
		zoom_factor = zoom_factor,
		zoom_index = zoom_index,
		tile_size_f = tile_size_f,
	}

	if persistent_map.get_system_markers and persistent_map.render_map_marker then
		for marker_key, marker in pairs(persistent_map.get_system_markers()) do
			formspec_index = persistent_map.render_map_marker(
				formspec, formspec_index, marker_key, marker, marker_ctx
			)
		end
	end
	
	-- Draw player position marker with proper orientation
	local player_tile_offset_x = center_tile_x - view_center_x
	local player_tile_offset_z = center_tile_z - view_center_z
	
	-- Check if player is within visible grid
	if math.abs(player_tile_offset_x) <= radius and math.abs(player_tile_offset_z) <= radius then
		-- Convert world tile offset to GUI position
		local gui_col = player_tile_offset_x + radius
		local gui_row = radius - player_tile_offset_z  -- Flip Z for display
		
		local marker_tile_x = gui_col * tile_display_size
		local marker_tile_y = gui_row * tile_display_size
		
		-- Add the offset within the current tile
		-- Note: offset_z needs to be flipped for display (north = negative GUI y)
		local marker_x = marker_tile_x + (offset_x * tile_display_size)
		local marker_y = marker_tile_y + ((persistent_map.map_marker.position_flip_factor - offset_z) * tile_display_size)  -- Flip Z offset
		
		-- Get player's look direction (yaw is in radians)
		local yaw = player:get_look_horizontal()
		-- Convert yaw to compass direction (0 = north, π/2 = east, π = south, 3π/2 = west)
		-- In Luanti: yaw 0 = north, π/2 = west, π = south, 3π/2 = east
		-- We need to convert this to degrees and adjust for our triangle (which points north at 0°)
		local angle = math.deg(-yaw)  -- Convert to degrees, no additional offset needed
		
		-- Create a triangular arrow pointing in the direction the player is facing (scaled with zoom)
		local scale = persistent_map.player_marker_scale * zoom_factor
		local size = persistent_map.player_marker.arrow_size * scale
		local arrow_height = persistent_map.player_marker.arrow_height * scale
		
		-- Calculate rotation matrix for the triangle
		local rad = math.rad(angle)
		local cos_a = math.cos(rad)
		local sin_a = math.sin(rad)
		
		-- Define triangle points (pointing up initially = north)
		local x1, y1 = 0, -arrow_height
		local x2, y2 = -size, arrow_height * persistent_map.ui.arrow_height_factor
		local x3, y3 = size, arrow_height * persistent_map.ui.arrow_height_factor
		
		-- Rotate points
		local rx1 = x1 * cos_a - y1 * sin_a
		local ry1 = x1 * sin_a + y1 * cos_a
		local rx2 = x2 * cos_a - y2 * sin_a
		local ry2 = x2 * sin_a + y2 * cos_a
		local rx3 = x3 * cos_a - y3 * sin_a
		local ry3 = x3 * sin_a + y3 * cos_a
		
		-- Translate to marker position
		local p1x, p1y = marker_x + rx1, marker_y + ry1
		
		-- Draw filled triangle using boxes to approximate it (all scaled) - stack 5 for solid appearance
		-- Main body (red square at center)
		local main_size = persistent_map.player_marker.main_body_size * scale
		local half_main = main_size * persistent_map.map_marker.half_size_factor
		for stack_layer = 1, 5 do
			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;#FF0000]",
				marker_x - half_main, marker_y - half_main, main_size, main_size
			)
			formspec_index = formspec_index + 1
		end
		
		-- Draw directional indicator line (pointing direction - the tip)
		local tip_size = persistent_map.player_marker.tip_size * scale
		local half_tip = tip_size * persistent_map.map_marker.half_size_factor
		for stack_layer = 1, 5 do
			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;#FF0000]",
				p1x - half_tip, p1y - half_tip, tip_size, tip_size
			)
			formspec_index = formspec_index + 1
		end
		
		-- Additional points to make the arrow more visible (mid-section)
		local mid1x = marker_x + (rx1 * persistent_map.player_marker.mid_section_factor)
		local mid1y = marker_y + (ry1 * persistent_map.player_marker.mid_section_factor)
		local mid_size = persistent_map.player_marker.mid_section_size * scale
		local half_mid = mid_size * persistent_map.map_marker.half_size_factor
		for stack_layer = 1, 5 do
			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;#FF0000]",
				mid1x - half_mid, mid1y - half_mid, mid_size, mid_size
			)
			formspec_index = formspec_index + 1
		end
		
		-- Wing indicators (base of arrow)
		local wing1x = marker_x + (rx2 * persistent_map.player_marker.wing_factor)
		local wing1y = marker_y + (ry2 * persistent_map.player_marker.wing_factor)
		local wing2x = marker_x + (rx3 * persistent_map.player_marker.wing_factor)
		local wing2y = marker_y + (ry3 * persistent_map.player_marker.wing_factor)
		local wing_size = persistent_map.player_marker.wing_size * scale
		local half_wing = wing_size * persistent_map.map_marker.half_size_factor
		
		for stack_layer = 1, 5 do
			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;#FF0000]",
				wing1x - half_wing, wing1y - half_wing, wing_size, wing_size
			)
			formspec_index = formspec_index + 1
		end
		
		for stack_layer = 1, 5 do
			formspec[formspec_index] = string.format(
				"box[%.2f,%.2f;%.2f,%.2f;#FF0000]",
				wing2x - half_wing, wing2y - half_wing, wing_size, wing_size
			)
			formspec_index = formspec_index + 1
		end
	end
	
	-- Draw party member markers (if player is in a party)
	if persistent_map.get_party_member_positions then
		local party_members = persistent_map.get_party_member_positions(player_name)
		local party_marker_scale = persistent_map.player_marker_scale * zoom_factor * 0.8 -- Slightly smaller than main player
		
		for member_name, member_data in pairs(party_members) do
			local member_pos = member_data.pos
			local member_yaw = member_data.yaw
			
			-- Convert member position to tile coordinates
			local member_tile_x, member_tile_z = pos_to_tile_coords(member_pos)
			local member_tile_offset_x = member_tile_x - view_center_x
			local member_tile_offset_z = member_tile_z - view_center_z
			
			-- Check if member is within visible grid
			if math.abs(member_tile_offset_x) <= radius and math.abs(member_tile_offset_z) <= radius then
				-- Convert world tile offset to GUI position
				local gui_col = member_tile_offset_x + radius
				local gui_row = radius - member_tile_offset_z  -- Flip Z for display
				
				local member_tile_x_gui = gui_col * tile_display_size
				local member_tile_y_gui = gui_row * tile_display_size
				
				-- Calculate precise position within tile
				local member_offset_x, member_offset_z = get_position_in_tile(member_pos)
				local member_marker_x = member_tile_x_gui + (member_offset_x * tile_display_size)
				local member_marker_y = member_tile_y_gui + ((persistent_map.map_marker.position_flip_factor - member_offset_z) * tile_display_size)
				
				-- Draw party member marker (blue triangle)
				local member_angle = math.deg(-member_yaw)
				local member_scale = party_marker_scale
				local member_size = persistent_map.player_marker.arrow_size * member_scale
				local member_arrow_height = persistent_map.player_marker.arrow_height * member_scale
				
				-- Calculate rotation matrix for the triangle
				local member_rad = math.rad(member_angle)
				local member_cos_a = math.cos(member_rad)
				local member_sin_a = math.sin(member_rad)
				
				-- Define triangle points (pointing up initially = north)
				local mx1, my1 = 0, -member_arrow_height
				local mx2, my2 = -member_size, member_arrow_height * persistent_map.ui.arrow_height_factor
				local mx3, my3 = member_size, member_arrow_height * persistent_map.ui.arrow_height_factor
				
				-- Rotate points
				local mrx1 = mx1 * member_cos_a - my1 * member_sin_a
				local mry1 = mx1 * member_sin_a + my1 * member_cos_a
				local mrx2 = mx2 * member_cos_a - my2 * member_sin_a
				local mry2 = mx2 * member_sin_a + my2 * member_cos_a
				local mrx3 = mx3 * member_cos_a - my3 * member_sin_a
				local mry3 = mx3 * member_sin_a + my3 * member_cos_a
				
				-- Main body (blue square at center) - stack 5 for solid appearance
				local member_main_size = persistent_map.player_marker.main_body_size * member_scale
				local member_half_main = member_main_size * persistent_map.map_marker.half_size_factor
				for stack_layer = 1, 5 do
					formspec[formspec_index] = string.format(
						"box[%.2f,%.2f;%.2f,%.2f;#0080FF]",
						member_marker_x - member_half_main, member_marker_y - member_half_main, member_main_size, member_main_size
					)
					formspec_index = formspec_index + 1
				end
				
				-- Draw directional indicator (the tip)
				local member_p1x, member_p1y = member_marker_x + mrx1, member_marker_y + mry1
				local member_tip_size = persistent_map.player_marker.tip_size * member_scale
				local member_half_tip = member_tip_size * persistent_map.map_marker.half_size_factor
				for stack_layer = 1, 5 do
					formspec[formspec_index] = string.format(
						"box[%.2f,%.2f;%.2f,%.2f;#0080FF]",
						member_p1x - member_half_tip, member_p1y - member_half_tip, member_tip_size, member_tip_size
					)
					formspec_index = formspec_index + 1
				end
				
				-- Mid-section indicator
				local member_mid1x = member_marker_x + (mrx1 * persistent_map.player_marker.mid_section_factor)
				local member_mid1y = member_marker_y + (mry1 * persistent_map.player_marker.mid_section_factor)
				local member_mid_size = persistent_map.player_marker.mid_section_size * member_scale
				local member_half_mid = member_mid_size * persistent_map.map_marker.half_size_factor
				for stack_layer = 1, 5 do
					formspec[formspec_index] = string.format(
						"box[%.2f,%.2f;%.2f,%.2f;#0080FF]",
						member_mid1x - member_half_mid, member_mid1y - member_half_mid, member_mid_size, member_mid_size
					)
					formspec_index = formspec_index + 1
				end
				
				-- Wing indicators (base of arrow)
				local member_wing1x = member_marker_x + (mrx2 * persistent_map.player_marker.wing_factor)
				local member_wing1y = member_marker_y + (mry2 * persistent_map.player_marker.wing_factor)
				local member_wing2x = member_marker_x + (mrx3 * persistent_map.player_marker.wing_factor)
				local member_wing2y = member_marker_y + (mry3 * persistent_map.player_marker.wing_factor)
				local member_wing_size = persistent_map.player_marker.wing_size * member_scale
				local member_half_wing = member_wing_size * persistent_map.map_marker.half_size_factor
				
				for stack_layer = 1, 5 do
					formspec[formspec_index] = string.format(
						"box[%.2f,%.2f;%.2f,%.2f;#0080FF]",
						member_wing1x - member_half_wing, member_wing1y - member_half_wing, member_wing_size, member_wing_size
					)
					formspec_index = formspec_index + 1
				end
				
				for stack_layer = 1, 5 do
					formspec[formspec_index] = string.format(
						"box[%.2f,%.2f;%.2f,%.2f;#0080FF]",
						member_wing2x - member_half_wing, member_wing2y - member_half_wing, member_wing_size, member_wing_size
					)
					formspec_index = formspec_index + 1
				end
				
				-- Draw player name above the marker (if zoom is sufficient)
				if zoom_factor >= persistent_map.marker_name_min_zoom then
					local name_scale = math.max(persistent_map.marker_name_scale, zoom_factor * persistent_map.marker_name_zoom_multiplier)
					local name_char_width = persistent_map.marker_name_char_width * name_scale
					local name_text_height = persistent_map.marker_name_text_height * name_scale
					
					local name_y = member_marker_y - member_half_main - (name_text_height + persistent_map.marker_name_padding)
					local name_text_width = string.len(member_name) * name_char_width
					local name_x = member_marker_x - (name_text_width * persistent_map.map_marker.text_center_factor)
					
					-- Apply zoom-specific X offset for party member name positioning
					local member_name_x_offset = persistent_map.marker_name_zoom_x_offsets[zoom_index] or 0.0
					name_x = name_x + member_name_x_offset
					
					-- Add the member name label
					formspec[formspec_index] = string.format(
						"style[party_member_%s;font_size=+%d]",
						member_name, math.floor(name_scale * persistent_map.marker_name_font_multiplier)
					)
					formspec_index = formspec_index + 1
					
					formspec[formspec_index] = string.format(
						"label[%.2f,%.2f;%s]",
						name_x, name_y, minetest.formspec_escape(member_name)
					)
					formspec_index = formspec_index + 1
				end
			end
		end
	end
	
	-- Close scroll containers (inner horizontal, outer vertical)
	formspec[formspec_index] = "scroll_container_end[]"
	formspec_index = formspec_index + 1
	formspec[formspec_index] = "scroll_container_end[]"
	formspec_index = formspec_index + 1
	
	-- LEFT PANEL: Navigation + fast pan + go-to
	local left_panel_y = padding + header_height + persistent_map.ui.nav_panel_offset
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Navigation:]", left_panel_x, left_panel_y)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"label[%.2f,%.2f;Arrows: pan map (click map if keys don't respond)]",
		left_panel_x, left_panel_y + 0.45
	)
	formspec_index = formspec_index + 1

	local nav_start_y = left_panel_y + persistent_map.ui.nav_section_spacing + 0.5
	local nav_center_x = left_panel_x + side_panel_width / 2
	local half_side = side_btn / persistent_map.ui.half_divisor
	local nav_gap = persistent_map.ui.nav_button_spacing

	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_north;N ↑]",
		nav_center_x - half_side, nav_start_y, side_btn, side_btn
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_west;W ←]",
		nav_center_x - side_btn * persistent_map.ui.nav_button_multiplier,
		nav_start_y + side_btn + nav_gap, side_btn, side_btn
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_east;E →]",
		nav_center_x + nav_gap, nav_start_y + side_btn + nav_gap, side_btn, side_btn
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_south;S ↓]",
		nav_center_x - half_side,
		nav_start_y + side_btn * persistent_map.ui.padding_multiplier + nav_gap * persistent_map.ui.padding_multiplier,
		side_btn, side_btn
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_center;Center on Player]",
		left_panel_x, nav_start_y + side_btn * 3 + persistent_map.ui.nav_center_button_offset,
		side_panel_width - persistent_map.ui.button_width_offset, side_btn
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;fit_discovered;Ver todo descubierto]",
		left_panel_x, nav_start_y + side_btn * 4 + persistent_map.ui.nav_center_button_offset,
		side_panel_width - persistent_map.ui.button_width_offset, side_btn
	)
	formspec_index = formspec_index + 1

	local zoom_y = nav_start_y + side_btn * 5 + persistent_map.ui.zoom_section_offset
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Zoom: %.1fx]", left_panel_x, zoom_y, zoom_factor)
	formspec_index = formspec_index + 1
	local zoom_button_width = (side_panel_width - persistent_map.ui.nav_center_button_offset) / persistent_map.ui.half_divisor
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;zoom_out;Zoom Out (-)]",
		left_panel_x, zoom_y + persistent_map.ui.zoom_button_spacing, zoom_button_width, side_btn
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;zoom_in;Zoom In (+)]",
		left_panel_x + zoom_button_width + persistent_map.ui.zoom_button_spacing,
		zoom_y + persistent_map.ui.zoom_button_spacing, zoom_button_width, side_btn
	)
	formspec_index = formspec_index + 1

	local fast_y = zoom_y + side_btn + 0.8
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Fast pan (3 tiles):]", left_panel_x, fast_y)
	formspec_index = formspec_index + 1
	local fast_w = (side_panel_width - persistent_map.ui.nav_center_button_offset) / persistent_map.ui.half_divisor
	local fast_row_y = fast_y + 0.6
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_fast_north;N x3]",
		left_panel_x, fast_row_y, fast_w, side_btn * 0.7
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_fast_south;S x3]",
		left_panel_x + fast_w + nav_gap, fast_row_y, fast_w, side_btn * 0.7
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_fast_west;W x3]",
		left_panel_x, fast_row_y + side_btn * 0.75, fast_w, side_btn * 0.7
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;nav_fast_east;E x3]",
		left_panel_x + fast_w + nav_gap, fast_row_y + side_btn * 0.75, fast_w, side_btn * 0.7
	)
	formspec_index = formspec_index + 1

	local goto_y = fast_row_y + side_btn * 1.5 + 0.4
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Go to:]", left_panel_x, goto_y)
	formspec_index = formspec_index + 1
	-- Extra gap so each field's own "X"/"Z" label (drawn just above the field)
	-- clears the "Go to:" header instead of colliding with it.
	local goto_field_y = goto_y + 0.75
	local goto_field_w = (side_panel_width - persistent_map.ui.nav_center_button_offset) / persistent_map.ui.half_divisor
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,0.75;goto_x;X;%d]",
		left_panel_x, goto_field_y, goto_field_w, math.floor(pos.x)
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,0.75;goto_z;Z;%d]",
		left_panel_x + goto_field_w + nav_gap, goto_field_y, goto_field_w, math.floor(pos.z)
	)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,0.75;goto_coords;Go]",
		left_panel_x, goto_field_y + 0.85, side_panel_width - persistent_map.ui.button_width_offset
	)
	formspec_index = formspec_index + 1

	-- RIGHT PANEL: Place marker at player feet
	local right_panel_y = padding + header_height + persistent_map.ui.nav_panel_offset
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Place Marker:]", right_panel_x, right_panel_y)
	formspec_index = formspec_index + 1
	local name_input_y = right_panel_y + persistent_map.ui.nav_section_spacing
	formspec[formspec_index] = string.format("label[%.2f,%.2f;Marker Name:]", right_panel_x, name_input_y)
	formspec_index = formspec_index + 1
	formspec[formspec_index] = string.format(
		"field[%.2f,%.2f;%.2f,%.2f;marker_name;;]",
		right_panel_x, name_input_y + persistent_map.ui.marker_name_label_spacing,
		side_panel_width - persistent_map.ui.field_width_offset, persistent_map.ui.marker_name_field_height
	)
	formspec_index = formspec_index + 1

	local marker_start_y = name_input_y + persistent_map.ui.marker_colors_offset
	local colors_per_row = persistent_map.ui.colors_per_row
	local color_button_size = persistent_map.ui.color_button_size
	for i, color_info in ipairs(persistent_map.marker_colors) do
		local row = math.floor((i - 1) / colors_per_row)
		local col = (i - 1) % colors_per_row
		local btn_x = right_panel_x + col * (color_button_size + persistent_map.ui.color_button_spacing)
		local btn_y = marker_start_y + row * (color_button_size + persistent_map.ui.color_button_row_spacing)
		formspec[formspec_index] = string.format(
			"box[%.2f,%.2f;%.2f,%.2f;%s]",
			btn_x, btn_y, color_button_size, color_button_size, color_info.color
		)
		formspec_index = formspec_index + 1
		formspec[formspec_index] = string.format(
			"button[%.2f,%.2f;%.2f,%.2f;add_marker_%d;%s]",
			btn_x, btn_y, color_button_size, color_button_size, i, color_info.name
		)
		formspec_index = formspec_index + 1
	end

	local manage_y = marker_start_y
		+ math.ceil(#persistent_map.marker_colors / colors_per_row)
			* (color_button_size + persistent_map.ui.color_button_row_spacing)
		+ persistent_map.ui.delete_buttons_offset
	formspec[formspec_index] = string.format(
		"button[%.2f,%.2f;%.2f,%.2f;manage_markers;Manage Markers]",
		right_panel_x, manage_y, side_panel_width - persistent_map.ui.button_width_offset, button_size
	)
	formspec_index = formspec_index + 1

	-- Add coordinate display with discovery stats
	local offset_text = ""
	if view_offset.x ~= 0 or view_offset.z ~= 0 then
		offset_text = string.format(" (View offset: X%+d, Z%+d)", view_offset.x, view_offset.z)
	end
	
	-- Count total discovered tiles for this player
	local total_discovered = 0
	for _ in pairs(tiles) do
		total_discovered = total_discovered + 1
	end
	
	-- Count markers
	local marker_count = 0
	for _ in pairs(markers) do
		marker_count = marker_count + 1
	end
	
	-- BOTTOM INFO SECTION: Spread out information on both sides of the map
	local info_y = total_height - persistent_map.ui.info_bottom_margin
	local left_info_x = persistent_map.ui.info_left_align_with_panel and left_panel_x or padding
	local right_info_x = right_panel_x
	
	-- Left side information (2 pieces)
	table.insert(formspec, string.format(
		"label[%f,%f;Player Coords: X=%d Y=%d Z=%d]",
		left_info_x, info_y,
		math.floor(pos.x), math.floor(pos.y), math.floor(pos.z)
	))
	
	table.insert(formspec, string.format(
		"label[%f,%f;Tile Coords: %d, %d]%s",
		left_info_x, info_y + persistent_map.ui.info_line_spacing,
		center_tile_x, center_tile_z, offset_text
	))
	
	-- Right side information (2 pieces)
	table.insert(formspec, string.format(
		"label[%f,%f;Discovered: %d/%d genesis tiles]",
		right_info_x, info_y,
		total_discovered, persistent_map.total_world_tiles
	))
	
	table.insert(formspec, string.format(
		"label[%f,%f;View: %d/%d tiles (%d markers)]",
		right_info_x, info_y + persistent_map.ui.info_line_spacing,
		discovered_count, total_tiles, marker_count
	))

	persistent_map.mark_map_open(player_name, true)
	minetest.show_formspec(player_name, "persistent_map:map", table.concat(formspec))
end

-- Register chatcommand to open map
minetest.register_chatcommand("map", {
	description = S("Open the persistent map (/map full = fit all discovered)"),
	params = "[full]",
	func = function(name, param)
		param = (param or ""):trim()
		if not map_zoom_level[name] then
			map_zoom_level[name] = persistent_map.default_zoom_index
		end
		if param == "full" then
			persistent_map.fit_map_to_discovered(name)
			return true, S("Map opened — fit to discovered area")
		end
		map_view_offset[name] = {x = 0, z = 0}
		persistent_map.show_map(name)
		return true, S("Map opened")
	end,
})

-- Handle formspec input for navigation with proper orientation and marker system
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "persistent_map:map" then return end
	
	local name = player:get_player_name()

	if fields.quit then
		persistent_map.mark_map_open(name, false)
		return
	end

	if persistent_map.try_handle_map_navigation(name, fields) then
		return
	end

	local offset = map_view_offset[name] or {x = 0, z = 0}
	local updated = false

	if fields.goto_coords then
		local gx = tonumber(fields.goto_x)
		local gz = tonumber(fields.goto_z)
		if gx and gz then
			local ok, err = persistent_map.center_map_on_coords(name, gx, gz)
			if ok then
				offset = map_view_offset[name] or offset
				updated = true
				minetest.chat_send_player(name, string.format("Map centered near X=%d Z=%d", math.floor(gx), math.floor(gz)))
			else
				minetest.chat_send_player(name, err or "Coordinates are outside the genesis map region")
			end
		else
			minetest.chat_send_player(name, "Enter valid numbers for X and Z")
		end
	elseif fields.zoom_in then
		-- Zoom in (increase zoom level)
		local current_zoom = map_zoom_level[name] or persistent_map.default_zoom_index
		if current_zoom < persistent_map.max_zoom_index then
			map_zoom_level[name] = current_zoom + 1
			updated = true
		end
	elseif fields.zoom_out then
		-- Zoom out (decrease zoom level)
		local current_zoom = map_zoom_level[name] or persistent_map.default_zoom_index
		if current_zoom > persistent_map.min_zoom_index then
			map_zoom_level[name] = current_zoom - 1
			updated = true
		end
	elseif fields.manage_markers then
		persistent_map.mark_map_open(name, false)
		persistent_map.show_marker_gui(name)
		return
	else
		-- Color buttons place marker at player feet (upstream behavior)
		for i = 1, #persistent_map.marker_colors do
			if fields["add_marker_" .. i] then
				local pos = player:get_pos()
				if not pos then
					return
				end
				local marker_name = fields.marker_name or ""
				if marker_name == "" then
					marker_name = string.format("Marker %d,%d", math.floor(pos.x), math.floor(pos.z))
				end
				local success, message = add_marker(name, pos, i, marker_name)
				minetest.chat_send_player(name, message)
				if success then
					last_place_color[name] = i
				end
				updated = true
				break
			end
		end
	end
	
	if updated then
		map_view_offset[name] = offset
		persistent_map.show_map(name)
	end
end)

-- Player join - Initialize player data
minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	
	-- Load this player's discovered tiles
	local tiles = load_player_tiles(name)
	
	-- Load this player's markers
	local markers = load_player_markers(name)
	
	-- Initialize player data structure
	player_data[name] = {
		discovered_tiles = tiles,
		markers = markers,
		last_tile_x = nil,
		last_tile_z = nil,
	}
	
	-- Count tiles and markers efficiently
	local tile_count = 0
	for _ in pairs(tiles) do tile_count = tile_count + 1 end
	local marker_count = 0
	for _ in pairs(markers) do marker_count = marker_count + 1 end
	
	minetest.log("action", "[persistent_map] Player " .. name .. " joined with " .. tile_count .. " discovered tiles and " .. marker_count .. " markers")
	
	-- Re-send all of THIS PLAYER's discovered tile textures to the client
	for tile_id, _ in pairs(tiles) do
		local filename = map_path .. tile_id .. ".png"
		local file = io.open(filename, "r")
		if file then
			file:close()
			-- Dynamically add the media for this specific player
			minetest.dynamic_add_media({
				filepath = filename,
				to_player = name,
			}, function(player_name)
				minetest.log("action", "[persistent_map] Reloaded tile " .. tile_id .. " for " .. player_name)
			end)
		else
			minetest.log("warning", "[persistent_map] Tile file not found: " .. tile_id .. " for player " .. name)
			local tx, tz = tile_id:match("^tile_(-?%d+)_(-?%d+)$")
			if tx and tz then
				queue_tile_repair(name, tonumber(tx), tonumber(tz))
			end
		end
	end
	
	-- Trigger initial tile discovery for player's current position
	minetest.after(persistent_map.generation.initial_discovery_delay, function()
		local pos = player:get_pos()
		if pos then
			local tile_x, tile_z = pos_to_tile_coords(pos)
			local data = player_data[name]
			if data then
				local discovered = add_discovered_tile(name, tile_x, tile_z, function()
					-- Send discovery message only after tile generation is complete
					minetest.chat_send_player(name, S("New area discovered!"))
				end)
				if discovered then
					data.last_tile_x = tile_x
					data.last_tile_z = tile_z
				end
			end
		end
	end)
end)

-- Player leave - Clean up player data
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	player_data[name] = nil
	map_view_offset[name] = nil
	map_zoom_level[name] = nil
	map_open[name] = nil
	last_place_color[name] = nil
	tile_repair_queue[name] = nil
	frontier_notified[name] = nil
	minetest.log("action", "[persistent_map] Player " .. name .. " left, data cleaned up")
end)

-- Discovery scanner
local scan_timer = 0
local repair_budget = 4

local function check_frontier_notice(player_name, pos)
	if not persistent_map.world_min or not pos then
		return
	end
	local margin = persistent_map.tile_size
	local wmin = persistent_map.world_min
	local wmax = persistent_map.world_max
	local near_edge = pos.x <= wmin.x + margin or pos.x >= wmax.x - margin
		or pos.z <= wmin.z + margin or pos.z >= wmax.z - margin
	if near_edge then
		if not frontier_notified[player_name] then
			minetest.chat_send_player(player_name, S("You have reached the genesis map frontier."))
			frontier_notified[player_name] = true
		end
	else
		frontier_notified[player_name] = nil
	end
end

minetest.register_globalstep(function(dtime)
	-- Background repair of discovered tiles missing PNGs
	for pname, queue in pairs(tile_repair_queue) do
		local repaired = 0
		for tile_id, coords in pairs(queue) do
			if repaired >= repair_budget then
				break
			end
			if not tile_exists(tile_id) and not tile_repair_pending[tile_id] then
				queue[tile_id] = nil
				ensure_tile_generated(pname, coords.x, coords.z)
				repaired = repaired + 1
			elseif tile_exists(tile_id) then
				queue[tile_id] = nil
			end
		end
		if not next(queue) then
			tile_repair_queue[pname] = nil
		end
	end

	scan_timer = scan_timer + dtime
	if scan_timer < persistent_map.scan_interval then return end
	scan_timer = 0
	
	for _, player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		
		-- Ensure player data exists
		if not player_data[name] then
			minetest.log("warning", "[persistent_map] Player data missing for " .. name .. " in globalstep")
		else
			local pos = player:get_pos()
			if pos then
				local tile_x, tile_z = pos_to_tile_coords(pos)

				check_frontier_notice(name, pos)

				local data = player_data[name]

				-- Check if player moved to new tile
				if data.last_tile_x ~= tile_x or data.last_tile_z ~= tile_z then
					local discovered = add_discovered_tile(name, tile_x, tile_z, function()
						-- Send discovery message only after tile generation is complete
						minetest.chat_send_player(name, S("New area discovered!"))
					end)
					if discovered then
						data.last_tile_x = tile_x
						data.last_tile_z = tile_z
					end
				end
			end
		end
	end
end)

-- Register map book item
minetest.register_craftitem("discovery_maps:map_book", {
	description = S("Map Book") .. "\n" .. S("Right-click to open the persistent map"),
	inventory_image = "default_book.png^[colorize:#8B4513:120",
	stack_max = 1,
	on_use = function(itemstack, user, pointed_thing)
		if user and user:is_player() then
			local player_name = user:get_player_name()
			-- Reset view offset when opening map
			map_view_offset[player_name] = {x = 0, z = 0}
			-- Initialize zoom level if not set
			if not map_zoom_level[player_name] then
				map_zoom_level[player_name] = persistent_map.default_zoom_index
			end
			persistent_map.show_map(player_name)
		end
		return itemstack
	end,
})

-- Register craft recipe for map book
minetest.register_craft({
	output = "discovery_maps:map_book",
	recipe = {
		{"default:paper", "default:paper", "default:paper"},
		{"default:paper", "default:book", "default:paper"},
		{"default:paper", "default:paper", "default:paper"}
	}
})


minetest.register_craft({
	output = "discovery_maps:map_book",
	recipe = {
		{"mcl_core:paper", "mcl_core:paper", "mcl_core:paper"},
		{"mcl_core:paper", "mcl_books:writable_book", "mcl_core:paper"},
		{"mcl_core:paper", "mcl_core:paper", "mcl_core:paper"}
	}
})

-- Give map book to new players
minetest.register_on_newplayer(function(player)
	local inv = player:get_inventory()
	if inv:room_for_item("main", "discovery_maps:map_book") then
		inv:add_item("main", "discovery_maps:map_book")
		minetest.chat_send_player(player:get_player_name(),
			S("Welcome! You've been given a Map Book. left-click it to explore the world!"))
	end
end)

minetest.register_chatcommand("mapgo", {
	params = "<X> <Z>",
	description = "Center the map view on world coordinates",
	func = function(name, param)
		local x, z = param:match("^(%S+)%s+(%S+)$")
		x, z = tonumber(x), tonumber(z)
		if not x or not z then
			return false, "Usage: /mapgo X Z"
		end
		local ok, err = persistent_map.center_map_on_coords(name, x, z)
		if not ok then
			return false, err or "Coordinates are outside the genesis map region"
		end
		persistent_map.show_map(name)
		return true, string.format("Map centered on X=%d Z=%d", math.floor(x), math.floor(z))
	end,
})

minetest.register_chatcommand("mark", {
	params = "<X> <Y> <Z> [name]",
	description = "Place a map marker at world coordinates",
	func = function(name, param)
		local x, y, z, label = param:match("^(%S+)%s+(%S+)%s+(%S+)%s*(.*)$")
		x, y, z = tonumber(x), tonumber(y), tonumber(z)
		if not x or not y or not z then
			return false, "Usage: /mark X Y Z [name]"
		end
		label = (label and label:gsub("^%s+", "") or "")
		if label == "" then
			label = string.format("Marker %d,%d", math.floor(x), math.floor(z))
		end
		local ok, msg = persistent_map.add_marker_for_player(name, { x = x, y = y, z = z }, label, 1)
		return ok, msg
	end,
})

dofile(modpath .. "/marker-gui.lua")
dofile(modpath .. "/marker-share.lua")
dofile(modpath .. "/map-party.lua")
dofile(modpath .. "/map-party-gui.lua")
dofile(modpath .. "/minimap.lua")
minetest.log("action", "[persistent_map] Persistent map mod loaded successfully (Hashimon UX fork)")