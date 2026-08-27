-- Placement, terrain prep, perimeter trees, and schematic registration.

local modpath = core.get_modpath("hashimon_qr_tree")
local TREE_MARGIN = 8

-- get_content_id throws on unknown names; only index registered nodes.
local function content_id_if_known(name)
	if core.registered_nodes[name] or name == "air" or name == "ignore" then
		return core.get_content_id(name)
	end
	return nil
end

local function content_id_set(names)
	local set = {}
	for _, name in ipairs(names) do
		local cid = content_id_if_known(name)
		if cid then
			set[cid] = true
		end
	end
	return set
end

local function sponsor_by_id(id)
	for _, s in ipairs(hashimon_qr_tree.sponsors) do
		if s.id == id then
			return s
		end
	end
	return nil
end

hashimon_qr_tree.sponsor_by_id = sponsor_by_id

local function load_metadata(id)
	local path = modpath .. "/schematics/sponsor_" .. id .. ".json"
	local file = io.open(path, "r")
	if not file then
		return nil, "missing metadata: " .. path
	end
	local raw = file:read("*a")
	file:close()
	local meta = core.parse_json(raw)
	if type(meta) ~= "table" then
		return nil, "invalid metadata JSON"
	end
	return meta
end

hashimon_qr_tree.load_metadata = load_metadata

local function schematic_path(sponsor)
	return modpath .. "/schematics/" .. (sponsor.schematic or ("sponsor_" .. sponsor.id .. ".mts"))
end

hashimon_qr_tree.schematic_path = schematic_path

function hashimon_qr_tree.verify_schematics()
	for _, sponsor in ipairs(hashimon_qr_tree.sponsors) do
		local path = schematic_path(sponsor)
		local handle = io.open(path, "r")
		if not handle then
			core.log("warning", "[hashimon_qr_tree] Schematic not found: " .. path)
		else
			handle:close()
			core.log("action", "[hashimon_qr_tree] Found schematic for " .. sponsor.id)
		end
	end
end

local function surface_y_at(x, z, fallback_y)
	local y_start = fallback_y > 0 and fallback_y or 80
	for y = y_start, -64, -1 do
		local name = core.get_node({ x = x, y = y, z = z }).name
		if name ~= "air" and name ~= "ignore" then
			return y
		end
	end
	return fallback_y > 0 and fallback_y or 20
end

local function flatten_area(p1, p2, surface_y)
	local vm = core.get_voxel_manip()
	if not vm then
		return false
	end
	vm:read_from_map(p1, p2)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	local c_dirt = core.get_content_id("default:dirt")
	local c_stone = core.get_content_id("default:stone")

	for z = p1.z, p2.z do
		for x = p1.x, p2.x do
			for y = p1.y, p2.y do
				local vi = area:index(x, y, z)
				if y < surface_y then
					data[vi] = c_stone
				elseif y == surface_y then
					data[vi] = c_dirt
				else
					data[vi] = c_air
				end
			end
		end
	end

	vm:set_data(data)
	vm:write_to_map()
	return true
end

local function tree_corners(origin, footprint, surface_y)
	local half = math.floor(footprint / 2)
	local y = surface_y + 1
	local off = half + TREE_MARGIN
	return {
		{ x = origin.x - off, y = y, z = origin.z - off },
		{ x = origin.x + off, y = y, z = origin.z - off },
		{ x = origin.x - off, y = y, z = origin.z + off },
		{ x = origin.x + off, y = y, z = origin.z + off },
	}
end

local function spawn_perimeter_trees(corners)
	for _, pos in ipairs(corners) do
		core.spawn_tree(pos, "default:tree")
	end
end

local function remove_trees_near(origin, footprint, surface_y)
	local half = footprint + TREE_MARGIN + 6
	local p1 = { x = origin.x - half, y = surface_y, z = origin.z - half }
	local p2 = { x = origin.x + half, y = surface_y + 20, z = origin.z + half }
	local vm = core.get_voxel_manip()
	if not vm then
		return
	end
	vm:read_from_map(p1, p2)
	local emin, emax = vm:get_emerged_area()
	local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
	local data = vm:get_data()
	local c_air = core.get_content_id("air")
	-- Minetest Game names only — skip anything not registered (e.g. apple_leaves).
	local clearable = content_id_set({
		"default:leaves",
		"default:jungleleaves",
		"default:pine_needles",
		"default:acacia_leaves",
		"default:aspen_leaves",
		"default:tree",
		"default:jungletree",
		"default:pine_tree",
		"default:acacia_tree",
		"default:aspen_tree",
		"default:apple",
	})

	for z = p1.z, p2.z do
		for y = p1.y, p2.y do
			for x = p1.x, p2.x do
				local vi = area:index(x, y, z)
				local cid = data[vi]
				if clearable[cid] then
					data[vi] = c_air
				end
			end
		end
	end
	vm:set_data(data)
	vm:write_to_map()
end

function hashimon_qr_tree.place_sponsor(id, callback)
	local sponsor = sponsor_by_id(id)
	if not sponsor then
		if callback then callback(false, "unknown sponsor id: " .. tostring(id)) end
		return
	end
	if hashimon_qr_tree.placed[id] then
		if callback then callback(false, sponsor.id .. " already placed") end
		return
	end

	local meta, err = load_metadata(id)
	if not meta then
		if callback then callback(false, err) end
		return
	end

	local footprint = meta.footprint or meta.size_x or 64
	local depth = meta.size_y or 2
	local cx = sponsor.pos.x
	local cz = sponsor.pos.z
	local surface_y = surface_y_at(cx, cz, sponsor.pos.y or 0)
	local half = math.floor(footprint / 2)
	local origin = { x = cx - half, y = surface_y + 1, z = cz - half }
	local p1 = { x = origin.x - 1, y = surface_y - 4, z = origin.z - 1 }
	local p2 = {
		x = origin.x + footprint,
		y = surface_y + depth + 1,
		z = origin.z + footprint,
	}

	core.emerge_area(p1, p2, function(blockpos, action, calls_remaining, total)
		if calls_remaining ~= 0 then
			return
		end

		flatten_area(
			{ x = p1.x, y = surface_y - 3, z = p1.z },
			{ x = p2.x, y = surface_y + depth + 1, z = p2.z },
			surface_y
		)

		local schem_path = schematic_path(sponsor)
		local schem_file = io.open(schem_path, "r")
		if not schem_file then
			if callback then callback(false, "missing schematic: " .. schem_path) end
			return
		end
		schem_file:close()

		local placed = core.place_schematic(origin, schem_path, "0", nil, true)
		if not placed then
			if callback then callback(false, "place_schematic failed for " .. id) end
			return
		end

		spawn_perimeter_trees(tree_corners({ x = cx, z = cz }, footprint, surface_y))

		hashimon_qr_tree.placed[id] = {
			center = { x = cx, y = surface_y, z = cz },
			origin = origin,
			footprint = footprint,
			url = sponsor.url,
			label = sponsor.label,
			placed_at = os.time(),
		}
		hashimon_qr_tree.save_placed_state()

		if callback then
			callback(true, string.format(
				"Placed %s at X=%d Y=%d Z=%d (footprint %d)",
				id, cx, surface_y, cz, footprint
			))
		end
	end)
end

function hashimon_qr_tree.place_all(admin_name, callback)
	local pending = #hashimon_qr_tree.sponsors
	if pending == 0 then
		if callback then callback(true, "no sponsors configured") end
		return
	end
	local errors = {}
	local done = 0
	for _, sponsor in ipairs(hashimon_qr_tree.sponsors) do
		hashimon_qr_tree.place_sponsor(sponsor.id, function(ok, msg)
			done = done + 1
			if not ok then
				table.insert(errors, msg)
			elseif admin_name then
				core.chat_send_player(admin_name, "[QR] " .. msg)
			end
			if done >= pending and callback then
				if #errors > 0 then
					callback(false, table.concat(errors, "; "))
				else
					callback(true, "all sponsors placed")
				end
			end
		end)
	end
end

function hashimon_qr_tree.remove_sponsor(id, callback)
	local record = hashimon_qr_tree.placed[id]
	if not record then
		if callback then callback(false, id .. " is not placed") end
		return
	end

	local origin = record.origin
	local footprint = record.footprint
	local surface_y = record.center.y
	local p1 = { x = origin.x, y = surface_y, z = origin.z }
	local p2 = {
		x = origin.x + footprint - 1,
		y = surface_y + 3,
		z = origin.z + footprint - 1,
	}

	core.emerge_area(p1, p2, function(_, _, calls_remaining)
		if calls_remaining ~= 0 then
			return
		end

		remove_trees_near(record.center, footprint, surface_y)

		local vm = core.get_voxel_manip()
		vm:read_from_map(
			{ x = p1.x - TREE_MARGIN - 6, y = surface_y, z = p1.z - TREE_MARGIN - 6 },
			{ x = p2.x + TREE_MARGIN + 6, y = surface_y + 20, z = p2.z + TREE_MARGIN + 6 }
		)
		local emin, emax = vm:get_emerged_area()
		local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
		local data = vm:get_data()
		local c_air = core.get_content_id("air")
		local c_dirt = core.get_content_id("default:dirt")
		local c_grass = content_id_if_known("default:grass_1")
			or content_id_if_known("default:dirt_with_grass")
			or c_dirt
		local qr_nodes = content_id_set({
			"hashimon_qr_tree:dark",
			"hashimon_qr_tree:light",
		})

		for z = p1.z, p2.z do
			for x = p1.x, p2.x do
				for y = surface_y + 1, surface_y + 3 do
					local vi = area:index(x, y, z)
					if qr_nodes[data[vi]] then
						data[vi] = c_air
					end
				end
				local vi_grass = area:index(x, surface_y + 1, z)
				data[vi_grass] = c_grass
				local vi_dirt = area:index(x, surface_y, z)
				if data[vi_dirt] == c_air then
					data[vi_dirt] = c_dirt
				end
			end
		end
		vm:set_data(data)
		vm:write_to_map()

		hashimon_qr_tree.placed[id] = nil
		hashimon_qr_tree.save_placed_state()
		if callback then callback(true, "Removed " .. id) end
	end)
end

function hashimon_qr_tree.align_player(player, id)
	local record = hashimon_qr_tree.placed[id]
	if not record and hashimon_qr_tree.sponsors then
		local sponsor = sponsor_by_id(id)
		local meta = sponsor and load_metadata(id)
		if sponsor and meta then
			local cx, cz = sponsor.pos.x, sponsor.pos.z
			local surface_y = surface_y_at(cx, cz, sponsor.pos.y or 0)
			record = { center = { x = cx, y = surface_y, z = cz } }
		end
	end
	if not record then
		return false, id .. " not placed — run /qr_tree place " .. id .. " first"
	end

	local c = record.center
	player:set_pos({ x = c.x + 0.5, y = c.y + 32, z = c.z + 0.5 })
	player:set_look_horizontal(0)
	player:set_look_vertical(-math.pi / 2)
	return true, "QR visible — escanea con tu teléfono (F12 screenshot también funciona)"
end
