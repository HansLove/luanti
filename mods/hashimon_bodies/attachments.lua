-- L2 attachment prefabs (horns, tail glow, aura) via attached cube parts + particles.

hashimon_bodies = hashimon_bodies or {}

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

local SLOT_OFFSETS = {
	canine_wolf = {
		horns = { x = 0, y = 2.2, z = 1.2 },
		wings = { x = 0, y = 1.8, z = 0 },
		tail_glow = { x = -1.8, y = 1.0, z = 0 },
		markings = { x = 0, y = 1.5, z = 0 },
	},
	avian_bat = {
		horns = { x = 0, y = 1.2, z = 0.4 },
		wings = { x = 0, y = 0.8, z = 0 },
		tail_glow = { x = 0, y = 0.5, z = -0.5 },
		markings = { x = 0, y = 0.9, z = 0 },
	},
	dragon_wyvern = {
		horns = { x = 0, y = 3.5, z = 2.0 },
		wings = { x = 0, y = 2.5, z = 0.5 },
		tail_glow = { x = -2.5, y = 2.0, z = 0 },
		markings = { x = 0, y = 2.8, z = 0 },
	},
}

local ATTACH_VISUAL = {
	horns = { size = { x = 0.12, y = 0.25, z = 0.12 }, hex_key = "accent" },
	wings = { size = { x = 0.35, y = 0.08, z = 0.2 }, hex_key = "base" },
	tail_glow = { size = { x = 0.15, y = 0.15, z = 0.15 }, hex_key = "accent" },
	markings = { size = { x = 0.5, y = 0.06, z = 0.35 }, hex_key = "marking" },
}

local function spawn_attach(parent, body_id, kind, ramp)
	local slots = SLOT_OFFSETS[body_id] or SLOT_OFFSETS.canine_wolf
	local off = slots[kind]
	local vis = ATTACH_VISUAL[kind]
	if not off or not vis then
		return
	end
	local hex = ramp[vis.hex_key] and ramp[vis.hex_key].hex or ramp.base.hex
	local obj = core.add_entity(parent:get_pos(), "hashimon_bodies:attach_part")
	if not obj then
		return
	end
	local tex = colorize(hex)
	obj:set_properties({
		textures = { tex, tex, tex, tex, tex, tex },
		visual_size = vis.size,
	})
	obj:set_attach(parent, "", {
		x = off.x * 10,
		y = off.y * 10,
		z = off.z * 10,
	}, { x = 0, y = 0, z = 0 })
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
