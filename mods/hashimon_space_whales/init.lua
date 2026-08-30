-- Voxel space whales: solid living_* silhouette (body, head, flukes, fins) + slow drift.
-- No dmobs mesh. Asteroids stay as scenery; whales are built creatures.

local MODNAME = "hashimon_space_whales"
local ENTITY = MODNAME .. ":living_island"
local DECK_LEGACY = MODNAME .. ":deck"

local SPACE_YMIN = 5000
local SPACE_YMAX = 5999
if otherworlds
	and otherworlds.settings
	and otherworlds.settings.space_asteroids
then
	SPACE_YMIN = otherworlds.settings.space_asteroids.YMIN or SPACE_YMIN
	SPACE_YMAX = otherworlds.settings.space_asteroids.YMAX or SPACE_YMAX
end

local SCALE_MIN = 6
local SCALE_MAX = 16
local SCALE_DEFAULT = 10
local CLUSTER_MIN = 60
local CLUSTER_MAX = 1200
local MAX_NEAR_ISLANDS = 2
local MAX_GLOBAL_ISLANDS = 4
local DRIFT_INTERVAL = 4.0
local AUTO_SPAWN_INTERVAL = 90
local NEAR_RADIUS = 80

local TINTS = {
	{ id = "orange", hex = "#E85D12", amount = 85, trail = "#E85D12" },
	{ id = "amber", hex = "#FF6A1A", amount = 90, trail = "#FF6A1A" },
	{ id = "red", hex = "#DC2626", amount = 80, trail = "#DC2626" },
	{ id = "crimson", hex = "#B91C1C", amount = 75, trail = "#B91C1C" },
	{ id = "pink", hex = "#EC4899", amount = 80, trail = "#EC4899" },
	{ id = "rose", hex = "#FB7185", amount = 75, trail = "#FB7185" },
}

local MATERIALS = {
	stone = {
		desc = "Living Whale Stone",
		tile = "default_stone.png",
		groups = { cracky = 3, stone = 1, not_in_creative_inventory = 1 },
		sounds = default and default.node_sound_stone_defaults and default.node_sound_stone_defaults(),
	},
	cobble = {
		desc = "Living Whale Cobble",
		tile = "default_cobble.png",
		groups = { cracky = 3, stone = 2, not_in_creative_inventory = 1 },
		sounds = default and default.node_sound_stone_defaults and default.node_sound_stone_defaults(),
	},
	gravel = {
		desc = "Living Whale Gravel",
		tile = "default_gravel.png",
		groups = { crumbly = 2, not_in_creative_inventory = 1 },
		sounds = default and default.node_sound_dirt_defaults and default.node_sound_dirt_defaults({
			footstep = { name = "default_gravel_footstep", gain = 0.2 },
		}),
	},
	dust = {
		desc = "Living Whale Dust",
		tile = "default_dirt.png",
		groups = { crumbly = 3, not_in_creative_inventory = 1 },
		sounds = default and default.node_sound_dirt_defaults and default.node_sound_dirt_defaults(),
	},
	ice = {
		desc = "Living Whale Ice",
		tile = "default_ice.png",
		groups = { cracky = 3, cool = 1, not_in_creative_inventory = 1 },
		sounds = default and default.node_sound_glass_defaults and default.node_sound_glass_defaults(),
	},
	snow = {
		desc = "Living Whale Snow",
		tile = "default_snow.png",
		groups = { crumbly = 3, puts_out_fire = 1, not_in_creative_inventory = 1 },
		sounds = default and default.node_sound_dirt_defaults and default.node_sound_dirt_defaults({
			footstep = { name = "default_snow_footstep", gain = 0.15 },
		}),
	},
}

local LIVING_KIND = {}
local KIND_TINT_TO_NODE = {}

local function colorize_tile(tile, hex, amount)
	return tile .. "^[colorize:" .. hex .. ":" .. tostring(amount)
end

for _, tint in ipairs(TINTS) do
	for kind, mat in pairs(MATERIALS) do
		local nodename = MODNAME .. ":living_" .. kind .. "_" .. tint.id
		core.register_node(nodename, {
			description = mat.desc .. " (" .. tint.id .. ")",
			tiles = { colorize_tile(mat.tile, tint.hex, tint.amount) },
			is_ground_content = false,
			groups = mat.groups,
			sounds = mat.sounds,
			drop = "",
		})
		LIVING_KIND[nodename] = kind
		KIND_TINT_TO_NODE[kind] = KIND_TINT_TO_NODE[kind] or {}
		KIND_TINT_TO_NODE[kind][tint.id] = nodename
	end
end

core.register_node(DECK_LEGACY, {
	description = "Obsolete Whale Deck",
	drawtype = "airlike",
	paramtype = "light",
	sunlight_propagates = true,
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	drop = "",
	groups = { not_in_creative_inventory = 1 },
})

core.register_abm({
	label = "hashimon_space_whales remove legacy decks",
	nodenames = { DECK_LEGACY },
	interval = 3,
	chance = 1,
	action = function(pos)
		core.remove_node(pos)
	end,
})

local function pos_key(p)
	return string.format("%d:%d:%d", p.x, p.y, p.z)
end

local function copy_pos(p)
	return { x = p.x, y = p.y, z = p.z }
end

local function is_replaceable_space(name)
	return name == "air" or name == "asteroid:atmos" or name == DECK_LEGACY
end

local function pick_tint()
	return TINTS[math.random(#TINTS)]
end

local function tint_by_id(id)
	for i = 1, #TINTS do
		if TINTS[i].id == id then
			return TINTS[i]
		end
	end
	return TINTS[1]
end

local function cluster_centroid(nodes)
	local sx, sy, sz = 0, 0, 0
	for i = 1, #nodes do
		sx = sx + nodes[i].x
		sy = sy + nodes[i].y
		sz = sz + nodes[i].z
	end
	local n = #nodes
	return { x = sx / n, y = sy / n, z = sz / n }
end

local function count_controllers_near(pos, radius)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == ENTITY then
			n = n + 1
		end
	end
	return n
end

local function count_controllers_global()
	local n = 0
	for _, player in ipairs(core.get_connected_players()) do
		local p = player:get_pos()
		if p and p.y >= SPACE_YMIN - 50 and p.y <= SPACE_YMAX + 50 then
			n = math.max(n, count_controllers_near(p, 200))
		end
	end
	return n
end

local function clear_to_space(pos)
	if core.find_node_near(pos, 1, { "asteroid:atmos" }) then
		core.set_node(pos, { name = "asteroid:atmos" })
	else
		core.set_node(pos, { name = "air" })
	end
end

local function can_shift(nodes, dx, dy, dz)
	local source = {}
	for i = 1, #nodes do
		source[pos_key(nodes[i])] = true
	end
	for i = 1, #nodes do
		local p = nodes[i]
		local dest = { x = p.x + dx, y = p.y + dy, z = p.z + dz }
		if not source[pos_key(dest)] then
			if not is_replaceable_space(core.get_node(dest).name) then
				return false
			end
		end
	end
	return true
end

local function player_standing_on_set(ppos, node_set)
	local fx = math.floor(ppos.x + 0.5)
	local fz = math.floor(ppos.z + 0.5)
	local fy = math.floor(ppos.y + 0.001)
	return node_set[pos_key({ x = fx, y = fy - 1, z = fz })]
		or node_set[pos_key({ x = fx, y = fy, z = fz })]
end

local function carry_players(nodes, dx, dy, dz)
	local set = {}
	for i = 1, #nodes do
		set[pos_key(nodes[i])] = true
	end
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:get_pos()
		if ppos and player_standing_on_set(ppos, set) then
			if player.add_pos then
				player:add_pos({ x = dx, y = dy, z = dz })
			else
				player:set_pos({
					x = ppos.x + dx,
					y = ppos.y + dy,
					z = ppos.z + dz,
				})
			end
		end
	end
end

local function shift_cluster(nodes, dx, dy, dz)
	if dx == 0 and dy == 0 and dz == 0 then
		return nodes
	end
	if not can_shift(nodes, dx, dy, dz) then
		return nil
	end

	carry_players(nodes, dx, dy, dz)

	local saved = {}
	local dest_keys = {}
	for i = 1, #nodes do
		local p = nodes[i]
		local np = { x = p.x + dx, y = p.y + dy, z = p.z + dz }
		saved[i] = { pos = p, node = core.get_node(p), dest = np }
		dest_keys[pos_key(np)] = true
	end

	for i = 1, #saved do
		core.set_node(saved[i].dest, saved[i].node)
	end
	for i = 1, #saved do
		if not dest_keys[pos_key(saved[i].pos)] then
			clear_to_space(saved[i].pos)
		end
	end

	local new_nodes = {}
	for i = 1, #saved do
		new_nodes[i] = saved[i].dest
	end
	return new_nodes
end

local function emit_trail(centroid, dir, tint, scale_hint)
	local trail = (tint and tint.trail) or "#E85D12"
	local tex = "default_mese_crystal_fragment.png^[colorize:" .. trail .. ":90"
	local back = {
		x = centroid.x - (dir.x or 0) * 5,
		y = centroid.y - (dir.y or 0) * 2,
		z = centroid.z - (dir.z or 0) * 5,
	}
	local spread = 1.5 + (scale_hint or 1) * 0.03
	core.add_particlespawner({
		amount = 7,
		time = 0.2,
		minpos = {
			x = back.x - spread,
			y = back.y - spread * 0.35,
			z = back.z - spread,
		},
		maxpos = {
			x = back.x + spread,
			y = back.y + spread * 0.35,
			z = back.z + spread,
		},
		minvel = { x = -0.15, y = -0.05, z = -0.15 },
		maxvel = { x = 0.15, y = 0.12, z = 0.15 },
		minacc = { x = 0, y = 0, z = 0 },
		maxacc = { x = 0, y = 0.01, z = 0 },
		minexptime = 1.5,
		maxexptime = 3.0,
		minsize = 2,
		maxsize = 4.5,
		texture = tex,
		glow = 8,
	})
end

local function horizontal_forward(look)
	local fx, fz = look.x, look.z
	local len = math.sqrt(fx * fx + fz * fz)
	if len < 0.05 then
		return { x = 0, y = 0, z = 1 }
	end
	return { x = fx / len, y = 0, z = fz / len }
end

--- Prefer drift along body axis (tail / +Z local = opposite of head forward)
local function drift_dir_from_forward(forward)
	return { x = -forward.x, y = 0, z = -forward.z }
end

local function random_drift_dir(preferred)
	if preferred and math.random(3) ~= 1 then
		local d = { x = preferred.x, y = 0, z = preferred.z }
		if math.random(10) == 1 then
			d.y = (math.random(2) == 1) and 1 or -1
		end
		-- unit step on dominant axis
		if math.abs(d.x) >= math.abs(d.z) then
			return { x = d.x >= 0 and 1 or -1, y = d.y, z = 0 }
		end
		return { x = 0, y = d.y, z = d.z >= 0 and 1 or -1 }
	end
	local dirs = {
		{ x = 1, y = 0, z = 0 },
		{ x = -1, y = 0, z = 0 },
		{ x = 0, y = 0, z = 1 },
		{ x = 0, y = 0, z = -1 },
	}
	local d = dirs[math.random(#dirs)]
	if math.random(8) == 1 then
		d = { x = d.x, y = (math.random(2) == 1) and 1 or -1, z = d.z }
	end
	return d
end

--- Local whale frame: +Z = tail, -Z = head, +Y = up, +X = right.
--- Returns list of world positions placed, or nil + err.
local function build_whale_shape(origin, scale, tint_id, forward)
	scale = math.max(SCALE_MIN, math.min(SCALE_MAX, scale))
	tint_id = tint_id or pick_tint().id
	forward = forward or { x = 0, y = 0, z = 1 }

	local stone = KIND_TINT_TO_NODE.stone[tint_id]
	local cobble = KIND_TINT_TO_NODE.cobble[tint_id]
	local dust = KIND_TINT_TO_NODE.dust[tint_id]
	if not stone or not cobble or not dust then
		return nil, "missing_nodes"
	end

	local back = { x = -forward.x, y = 0, z = -forward.z }
	local right = { x = forward.z, y = 0, z = -forward.x }

	local ox = math.floor(origin.x + 0.5)
	local oy = math.floor(origin.y + 0.5)
	local oz = math.floor(origin.z + 0.5)

	local rz = scale * 0.48
	local rx = scale * 0.34
	local ry = scale * 0.26
	local flat_y = ry * 0.45
	local fluke_len = math.max(2, math.floor(scale * 0.32))
	local fluke_w = math.max(2, math.floor(scale * 0.38))
	local fin_len = math.max(2, math.floor(scale * 0.22))

	local mask = {} -- key -> {pos, shell}
	local function mark(lx, ly, lz, shell)
		local wx = math.floor(ox + right.x * lx + back.x * lz + 0.5)
		local wy = math.floor(oy + ly + 0.5)
		local wz = math.floor(oz + right.z * lx + back.z * lz + 0.5)
		local k = pos_key({ x = wx, y = wy, z = wz })
		local prev = mask[k]
		if not prev then
			mask[k] = {
				pos = { x = wx, y = wy, z = wz },
				shell = shell and true or false,
			}
		elseif shell then
			prev.shell = true
		end
	end

	local function in_ellipsoid(x, y, z, erx, ery, erz)
		return (x * x) / (erx * erx) + (y * y) / (ery * ery) + (z * z) / (erz * erz) <= 1.0
	end

	-- Body (flat top for walkable back)
	local bx = math.ceil(rx) + 1
	local by = math.ceil(ry) + 1
	local bz = math.ceil(rz) + 1
	for lz = -bz, bz do
		for ly = -by, math.floor(flat_y) do
			for lx = -bx, bx do
				if in_ellipsoid(lx, ly, lz, rx, ry, rz) then
					local shell = in_ellipsoid(lx, ly, lz, rx * 0.78, ry * 0.78, rz * 0.78) == false
					mark(lx, ly, lz, shell)
				end
			end
		end
	end

	-- Head (narrower, toward -Z)
	local hrz = scale * 0.22
	local hrx = rx * 0.72
	local hry = ry * 0.7
	local hcx = 0
	local hcy = -ry * 0.05
	local hcz = -rz - hrz * 0.35
	for lz = math.floor(hcz - hrz) - 1, math.ceil(hcz + hrz) + 1 do
		for ly = math.floor(hcy - hry) - 1, math.min(math.floor(flat_y), math.ceil(hcy + hry)) do
			for lx = math.floor(-hrx) - 1, math.ceil(hrx) + 1 do
				if in_ellipsoid(lx - hcx, ly - hcy, lz - hcz, hrx, hry, hrz) then
					mark(lx, ly, lz, true)
				end
			end
		end
	end

	-- Flukes (horizontal tail plates at +Z)
	local tail_z0 = rz * 0.85
	for side = -1, 1, 2 do
		for fz = 0, fluke_len do
			local taper = 1 - (fz / (fluke_len + 0.01))
			local w = math.max(1, math.floor(fluke_w * taper))
			for fx = 1, w do
				for fy = 0, 1 do
					mark(side * fx, fy - 0.2 * ry, tail_z0 + fz, true)
				end
			end
		end
	end
	-- Tail stem
	for fz = 0, math.max(1, math.floor(fluke_len * 0.4)) do
		for fy = -1, 1 do
			for fx = -1, 1 do
				mark(fx, fy, tail_z0 + fz, true)
			end
		end
	end

	-- Pectoral fins mid-body
	local fin_z = -rz * 0.05
	for side = -1, 1, 2 do
		for f = 1, fin_len do
			local taper = 1 - (f / (fin_len + 0.01)) * 0.7
			for fy = -1, 0 do
				mark(side * (rx * 0.85 + f), fy * taper, fin_z + (1 - taper), true)
			end
		end
	end

	-- Place nodes (only replaceable space)
	local nodes = {}
	local keys_ordered = {}
	for k, info in pairs(mask) do
		keys_ordered[#keys_ordered + 1] = k
	end

	for i = 1, #keys_ordered do
		local info = mask[keys_ordered[i]]
		local p = info.pos
		if not is_replaceable_space(core.get_node(p).name) then
			-- blocked: abort and clean what we placed
			for j = 1, #nodes do
				clear_to_space(nodes[j])
			end
			return nil, "blocked"
		end
		local nodename = dust
		if info.shell then
			nodename = (math.random(3) == 1) and cobble or stone
		elseif math.random(5) == 1 then
			nodename = cobble
		end
		core.set_node(p, { name = nodename })
		nodes[#nodes + 1] = copy_pos(p)
		if #nodes > CLUSTER_MAX then
			for j = 1, #nodes do
				clear_to_space(nodes[j])
			end
			return nil, "too_big"
		end
	end

	if #nodes < CLUSTER_MIN then
		for j = 1, #nodes do
			clear_to_space(nodes[j])
		end
		return nil, "too_small"
	end

	return nodes, tint_id
end

local function spawn_whale_controller(nodes, tint_id, preferred_dir)
	local c = cluster_centroid(nodes)
	local dir = random_drift_dir(preferred_dir)
	local payload = core.write_json({
		tint_id = tint_id,
		dir = dir,
		nodes = nodes,
		axis = preferred_dir,
	}) or ""
	local obj = core.add_entity(c, ENTITY, payload)
	if not obj then
		return nil, "spawn_failed"
	end
	local ent = obj:get_luaentity()
	if ent then
		ent._nodes = nodes
		ent._tint_id = tint_id
		ent._dir = dir
		ent._axis = preferred_dir
		ent._timer = 0
		ent._trail_t = 0
	end
	return obj
end

--- Build + attach controller. origin = body center.
local function spawn_voxel_whale(origin, scale, look)
	if count_controllers_near(origin, NEAR_RADIUS) >= MAX_NEAR_ISLANDS then
		return nil, "too_many_near"
	end
	local tint = pick_tint()
	local forward = horizontal_forward(look or { x = 0, y = 0, z = 1 })
	local nodes, err_or_tint = build_whale_shape(origin, scale, tint.id, forward)
	if not nodes then
		return nil, err_or_tint
	end
	local preferred = drift_dir_from_forward(forward)
	local obj, err = spawn_whale_controller(nodes, tint.id, preferred)
	if not obj then
		for i = 1, #nodes do
			clear_to_space(nodes[i])
		end
		return nil, err or "spawn_failed"
	end
	return obj, tint.id, #nodes, scale
end

core.register_entity(ENTITY, {
	initial_properties = {
		hp_max = 1,
		physical = false,
		collide_with_objects = false,
		pointable = false,
		visual = "sprite",
		visual_size = { x = 0, y = 0 },
		textures = { "default_stone.png" },
		static_save = true,
		is_visible = false,
	},

	on_activate = function(self, staticdata, _dtime_s)
		self._timer = 0
		self._trail_t = 0
		self._dir = random_drift_dir()
		self._nodes = {}
		self._tint_id = TINTS[1].id
		self.object:set_armor_groups({ immortal = 1 })

		if staticdata and staticdata ~= "" then
			local data = core.parse_json(staticdata)
			if type(data) == "table" then
				self._tint_id = data.tint_id or self._tint_id
				self._dir = data.dir or self._dir
				self._nodes = data.nodes or {}
				self._axis = data.axis
			end
		end

		if not self._nodes or #self._nodes == 0 then
			self.object:remove()
			return
		end
		local alive = 0
		for i = 1, #self._nodes do
			if LIVING_KIND[core.get_node(self._nodes[i]).name] then
				alive = alive + 1
			end
		end
		if alive < CLUSTER_MIN / 2 then
			self.object:remove()
		end
	end,

	get_staticdata = function(self)
		return core.write_json({
			tint_id = self._tint_id,
			dir = self._dir,
			nodes = self._nodes,
			axis = self._axis,
		}) or ""
	end,

	on_step = function(self, dtime)
		if not self._nodes or #self._nodes == 0 then
			self.object:remove()
			return
		end

		local tint = tint_by_id(self._tint_id)
		local c = cluster_centroid(self._nodes)
		self.object:set_pos(c)

		self._trail_t = (self._trail_t or 0) + dtime
		if self._trail_t >= 0.8 then
			self._trail_t = 0
			emit_trail(c, self._dir or { x = 1, y = 0, z = 0 }, tint, #self._nodes / 80)
		end

		self._timer = (self._timer or 0) + dtime
		if self._timer < DRIFT_INTERVAL then
			return
		end
		self._timer = 0

		local dir = self._dir or random_drift_dir(self._axis)
		local moved = shift_cluster(self._nodes, dir.x, dir.y, dir.z)
		if not moved then
			for _ = 1, 8 do
				dir = random_drift_dir(self._axis)
				moved = shift_cluster(self._nodes, dir.x, dir.y, dir.z)
				if moved then
					break
				end
			end
		end
		if moved then
			self._nodes = moved
			self._dir = dir
			self.object:set_pos(cluster_centroid(moved))
		else
			self._dir = random_drift_dir(self._axis)
		end
	end,
})

core.register_privilege("hashimon_space_admin", {
	description = "Spawn voxel space whales for testing",
	give_to_singleplayer = true,
})

core.register_chatcommand("space_whale", {
	params = "[" .. SCALE_MIN .. "-" .. SCALE_MAX .. "]",
	description = "Spawn a solid voxel whale silhouette (optional scale)",
	privs = { hashimon_space_admin = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local pos = player:get_pos()
		if not pos then
			return false, "No position."
		end
		if pos.y < SPACE_YMIN - 20 or pos.y > SPACE_YMAX + 20 then
			return false, string.format(
				"Go to space (Y ~%d–%d), then /space_whale.",
				SPACE_YMIN, SPACE_YMAX
			)
		end

		local want = tonumber(param)
		local scale = want
			and math.max(SCALE_MIN, math.min(SCALE_MAX, want))
			or SCALE_DEFAULT

		local look = player:get_look_dir()
		local forward = horizontal_forward(look)
		local offset = 12 + scale * 0.9
		local origin = {
			x = pos.x + forward.x * offset,
			y = pos.y,
			z = pos.z + forward.z * offset,
		}

		local obj, a, b, c = spawn_voxel_whale(origin, scale, look)
		if not obj then
			local err = a
			if err == "too_many_near" then
				return false, "Too many living whales nearby (max "
					.. MAX_NEAR_ISLANDS .. ")."
			end
			if err == "blocked" then
				return false, "Not enough open space ahead — face clear void / atmos."
			end
			return false, "Failed to build whale (" .. tostring(err) .. ")."
		end

		local tint_id, nnodes, used_scale = a, b, c
		return true, string.format(
			"Voxel whale scale %d (%d nodes, tint %s) ahead — walk the back; drifts every ~%.0fs.",
			used_scale, nnodes, tint_id, DRIFT_INTERVAL
		)
	end,
})

-- Occasional auto-spawn of voxel whales in open space near players
local auto_t = 0
core.register_globalstep(function(dtime)
	auto_t = auto_t + dtime
	if auto_t < AUTO_SPAWN_INTERVAL then
		return
	end
	auto_t = 0

	if math.random(3) ~= 1 then
		return
	end

	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos and pos.y >= SPACE_YMIN and pos.y <= SPACE_YMAX then
			if count_controllers_global() >= MAX_GLOBAL_ISLANDS then
				return
			end
			if count_controllers_near(pos, NEAR_RADIUS) < MAX_NEAR_ISLANDS then
				local ang = math.random() * math.pi * 2
				local dist = 35 + math.random(25)
				local origin = {
					x = pos.x + math.cos(ang) * dist,
					y = pos.y + math.random(-4, 4),
					z = pos.z + math.sin(ang) * dist,
				}
				local look = {
					x = pos.x - origin.x,
					y = 0,
					z = pos.z - origin.z,
				}
				spawn_voxel_whale(origin, SCALE_DEFAULT + math.random(-2, 2), look)
				return
			end
		end
	end
end)

core.log("action", string.format(
	"[%s] Voxel whales ready (scale %d–%d, solid silhouette, Y %d–%d)",
	MODNAME, SCALE_MIN, SCALE_MAX, SPACE_YMIN, SPACE_YMAX
))
