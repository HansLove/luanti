-- Ephemeral tide path for Agua mounts in air. Looks like water but does NOT
-- use the liquid engine (no flood / flowing). mount.lua treats this node as
-- swim-contact for water-mode mounts only.

hashimon = hashimon or {}

hashimon.TIDE_WAKE_NODE = "hashimon_entities:tide_wake"
hashimon.TIDE_WAKE_TTL = 3.5
hashimon.TIDE_WAKE_MAX_PER_MOUNT = 40

core.register_node("hashimon_entities:tide_wake", {
	description = "Marea efímera (Hashimon)",
	drawtype = "glasslike",
	tiles = { "hashimon_tide_wake.png^[opacity:160" },
	use_texture_alpha = "blend",
	paramtype = "light",
	walkable = false,
	pointable = false,
	diggable = false,
	buildable_to = true,
	floodable = true,
	drop = "",
	drowning = 0,
	-- Not a real liquid: no flowing / flood. mount.lua treats it as swim contact.
	liquidtype = "none",
	post_effect_color = { a = 64, r = 56, g = 140, b = 200 },
	groups = { not_in_creative_inventory = 1, dig_immediate = 3 },
	sunlight_propagates = true,
})

local function pos_key(pos)
	return string.format("%d:%d:%d", math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
end

--- True if this node is our ephemeral wake (not real ocean water).
function hashimon.is_tide_wake(pos)
	if not pos then
		return false
	end
	return core.get_node(pos).name == hashimon.TIDE_WAKE_NODE
end

--- Remove one wake node if it is still ours.
function hashimon.remove_tide_wake_at(pos)
	if not pos then
		return
	end
	local p = vector.round(pos)
	if core.get_node(p).name == hashimon.TIDE_WAKE_NODE then
		core.remove_node(p)
	end
end

--- Drop every wake tracked on this mount entity (dismount / cleanup).
function hashimon.clear_tide_wakes(ent)
	if not ent or not ent._tide_wake_list then
		return
	end
	for _, p in ipairs(ent._tide_wake_list) do
		hashimon.remove_tide_wake_at(p)
	end
	ent._tide_wake_list = {}
	ent._tide_wake_keys = {}
	ent._tide_wake_count = 0
end

local function track_wake(ent, p)
	ent._tide_wake_list = ent._tide_wake_list or {}
	ent._tide_wake_keys = ent._tide_wake_keys or {}
	ent._tide_wake_count = ent._tide_wake_count or 0
	local key = pos_key(p)
	if ent._tide_wake_keys[key] then
		return
	end
	-- Cap: drop oldest.
	local max_n = hashimon.TIDE_WAKE_MAX_PER_MOUNT
	while ent._tide_wake_count >= max_n and #ent._tide_wake_list > 0 do
		local old = table.remove(ent._tide_wake_list, 1)
		local ok = pos_key(old)
		ent._tide_wake_keys[ok] = nil
		ent._tide_wake_count = math.max(0, ent._tide_wake_count - 1)
		hashimon.remove_tide_wake_at(old)
	end
	ent._tide_wake_keys[key] = true
	ent._tide_wake_list[#ent._tide_wake_list + 1] = p
	ent._tide_wake_count = ent._tide_wake_count + 1
end

local function untrack_wake(ent, p)
	if not ent or not ent._tide_wake_keys then
		return
	end
	local key = pos_key(p)
	if not ent._tide_wake_keys[key] then
		return
	end
	ent._tide_wake_keys[key] = nil
	ent._tide_wake_count = math.max(0, (ent._tide_wake_count or 1) - 1)
	local list = ent._tide_wake_list or {}
	for i = #list, 1, -1 do
		if pos_key(list[i]) == key then
			table.remove(list, i)
			break
		end
	end
end

--- Place a wake cube if the cell is replaceable and unprotected.
--- @return boolean placed
function hashimon.place_tide_wake(pos, ent, ttl)
	if not pos then
		return false
	end
	local p = vector.round(pos)
	local name = (ent and ent.rider) or ""
	if core.is_protected(p, name) then
		return false
	end
	local cur = core.get_node(p).name
	if cur == hashimon.TIDE_WAKE_NODE then
		return false
	end
	local def = core.registered_nodes[cur]
	if cur ~= "air" and not (def and def.buildable_to) then
		return false
	end
	core.set_node(p, { name = hashimon.TIDE_WAKE_NODE })
	if ent then
		track_wake(ent, p)
	end
	local life = ttl or hashimon.TIDE_WAKE_TTL
	core.after(life, function()
		hashimon.remove_tide_wake_at(p)
		if ent then
			untrack_wake(ent, p)
		end
	end)
	return true
end

--- Lay a short segment of wake along the mount path (center + one below).
function hashimon.lay_tide_wake_segment(ent, pos, dir)
	if not ent or not pos then
		return 0
	end
	local n = 0
	local ttl = hashimon.TIDE_WAKE_TTL
	if hashimon.place_tide_wake(pos, ent, ttl) then
		n = n + 1
	end
	local below = { x = pos.x, y = pos.y - 1, z = pos.z }
	if hashimon.place_tide_wake(below, ent, ttl) then
		n = n + 1
	end
	if dir then
		local ahead = {
			x = pos.x + dir.x,
			y = pos.y + dir.y * 0.3,
			z = pos.z + dir.z,
		}
		if hashimon.place_tide_wake(ahead, ent, ttl) then
			n = n + 1
		end
	end
	return n
end
