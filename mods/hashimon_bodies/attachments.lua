-- L2 attachment prefabs (horns, tail glow, aura) via attached cube parts + particles.

hashimon_bodies = hashimon_bodies or {}

-- Cube props are OFF by default: they were never calibrated and shipped a giant
-- coloured box hanging in the sky above every creature.
--
-- The offsets below were written as node-space values (horns at y = 2.2) and
-- then multiplied by 10 on the way into set_attach, giving 22. For comparison,
-- Animalia seats a rider on a ~2-node-tall horse with an offset of **0.75**
-- (animalia/mobs/horse.lua:392). Ours were roughly thirty times larger than
-- anything in working reference code, which is exactly the block in the sky.
--
-- The maths below is fixed (fractions of the body's real height, no blind ×10),
-- but "fixed" here means "the right shape"; the exact numbers still need one
-- pass of in-game eyeballing before this is worth showing anyone. Flip this to
-- true, adjust SLOT_FRACTIONS, restart, repeat. /hashclean sweeps up strays.
hashimon_bodies.enable_prop_attachments = false

hashimon_bodies._attach_refs = hashimon_bodies._attach_refs or {}

local BASE_TEX = "hashimon_placeholder.png"

local function colorize(hex)
	return BASE_TEX .. "^[colorize:" .. hex .. ":255"
end

core.register_entity("hashimon_bodies:attach_part", {
	initial_properties = {
		visual = "cube",
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
	},
})

-- Slot positions as a FRACTION OF THE BODY'S OWN HEIGHT, not absolute nodes.
-- 1.0 means "at the top of the hitbox". Anything much above 1.2 is floating.
--
-- Expressing them this way is what makes one table correct for a 0.3-node rat
-- and a 1.95-node horse at the same time; the previous absolute values only
-- ever suited the wolf, and every other body inherited them verbatim.
local SLOT_FRACTIONS = {
	horns = { x = 0, y = 1.00, z = 0.35 },
	wings = { x = 0, y = 0.70, z = -0.10 },
	tail_glow = { x = -0.55, y = 0.45, z = 0 },
	markings = { x = 0, y = 0.75, z = 0 },
}

-- Hashimon sockets (SKELETON_STANDARD_V1). When the body declares the socket
-- bone, attach there at {0,0,0}; otherwise fall back to SLOT_FRACTIONS.
local SLOT_SOCKET = {
	horns = "Socket.Head",
	wings = "Socket.Back",
	tail_glow = "Socket.Tail",
	markings = "Socket.Chest",
}

local ATTACH_VISUAL = {
	horns = { size = { x = 0.12, y = 0.25, z = 0.12 }, hex_key = "accent" },
	wings = { size = { x = 0.35, y = 0.08, z = 0.2 }, hex_key = "base" },
	tail_glow = { size = { x = 0.15, y = 0.15, z = 0.15 }, hex_key = "accent" },
	markings = { size = { x = 0.5, y = 0.06, z = 0.35 }, hex_key = "marking" },
}

--- Attachment offset for one slot on one body, in set_attach units.
---
--- Two conversions live here and both were wrong before:
---   * the offset is a fraction of the body's real hitbox height, so the same
---     table suits a rat and a horse;
---   * it is NOT blindly multiplied by 10. The doc's "multiply by 10" note is
---     about converting world positions, but the parent here is a mesh scaled
---     by visual_size, and the offset rides that scale. Animalia's own reference
---     (a rider on a ~2-node horse) uses 0.75 — see the note at the top of this
---     file for how far off the old numbers were.
local function slot_offset(body_id, kind)
	local frac = SLOT_FRACTIONS[kind]
	if not frac then
		return nil, 1
	end
	local body = hashimon.get_body and hashimon.get_body(body_id)
	local height = (body and body.hitbox and body.hitbox.height) or 0.7
	return {
		x = frac.x * height,
		y = frac.y * height,
		z = frac.z * height,
	}, height / 0.7
end

local function body_has_socket(body, socket_name)
	if not body or not body.bones or not socket_name then
		return false
	end
	for _, bone in pairs(body.bones) do
		if bone == socket_name then
			return true
		end
	end
	if body.mount_view and body.mount_view.bone == socket_name then
		return true
	end
	return false
end

local function spawn_attach(parent, body_id, kind, ramp)
	local vis = ATTACH_VISUAL[kind]
	if not vis then
		return
	end
	local body = hashimon.get_body and hashimon.get_body(body_id)
	local socket = SLOT_SOCKET[kind]
	local use_socket = socket and body_has_socket(body, socket)
		and hashimon.attach_to_socket

	local off, scale
	if use_socket then
		off = { x = 0, y = 0, z = 0 }
		local height = (body and body.hitbox and body.hitbox.height) or 0.7
		scale = height / 0.7
	else
		off, scale = slot_offset(body_id, kind)
		if not off then
			return
		end
	end

	local hex = ramp[vis.hex_key] and ramp[vis.hex_key].hex or ramp.base.hex
	local obj = core.add_entity(parent:get_pos(), "hashimon_bodies:attach_part")
	if not obj then
		return
	end
	local tex = colorize(hex)
	-- The prop scales with the body too: a wolf-sized horn on a rat reads as a
	-- crate balanced on its head.
	obj:set_properties({
		textures = { tex, tex, tex, tex, tex, tex },
		visual_size = {
			x = vis.size.x * scale,
			y = vis.size.y * scale,
			z = vis.size.z * scale,
		},
	})
	if use_socket then
		hashimon.attach_to_socket(parent, socket, obj, off, { x = 0, y = 0, z = 0 }, "hashimon")
	else
		-- No ×10 here on purpose; see slot_offset's note.
		obj:set_attach(parent, "", off, { x = 0, y = 0, z = 0 })
	end
	return obj
end

function hashimon_bodies.clear_attachments(parent)
	local list = hashimon_bodies._attach_refs[parent]
	if not list then
		return
	end
	for _, ref in ipairs(list) do
		if ref and ref:get_luaentity() then
			ref:remove()
		end
	end
	hashimon_bodies._attach_refs[parent] = nil
end

function hashimon_bodies.apply_attachments(self, morph)
	if not self.object or not morph or not morph.attachments then
		return
	end
	hashimon_bodies.clear_attachments(self.object)
	if not hashimon_bodies.enable_prop_attachments then
		return -- aura still runs; it is a world-space particle, not an attachment
	end
	local refs = {}
	for _, kind in ipairs(morph.attachments) do
		if kind ~= "aura" then
			local ref = spawn_attach(self.object, morph.body_id, kind, morph.ramp)
			if ref then
				table.insert(refs, ref)
			end
		end
	end
	if #refs > 0 then
		hashimon_bodies._attach_refs[self.object] = refs
	end
end

function hashimon_bodies.update_aura(self, morph, dtime)
	if not morph or not morph.aura or not self.object then
		return
	end
	self._aura_accum = (self._aura_accum or 0) + dtime
	if self._aura_accum < 0.45 then
		return
	end
	self._aura_accum = 0
	local pos = self.object:get_pos()
	if not pos then
		return
	end
	local hex = morph.ramp.accent and morph.ramp.accent.hex or "#ffffff"
	core.add_particle({
		pos = { x = pos.x, y = pos.y + 0.6, z = pos.z },
		velocity = { x = 0, y = 0.4, z = 0 },
		acceleration = { x = 0, y = 0.2, z = 0 },
		expirationtime = 0.6,
		size = 0.8 + (morph.stage or 1) * 0.05,
		collisiondetection = false,
		texture = "hashimon_placeholder.png^[colorize:" .. hex .. ":200",
	})
end

-- Sweep up prop cubes left floating by the miscalibrated offsets. They are
-- static_save = false so they die with the block they are in, but a player who
-- already has one parked in the sky needs it gone now, and detached orphans
-- never get cleared by clear_attachments (that is keyed on a live parent).
core.register_chatcommand("hashclean", {
	description = "Remove stray Hashimon prop cubes near you (dev)",
	privs = { server = true },
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "player not found"
		end
		local removed = 0
		for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), 120)) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "hashimon_bodies:attach_part" then
				obj:remove()
				removed = removed + 1
			end
		end
		return true, removed .. " prop cube(s) removed"
	end,
})
