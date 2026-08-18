-- Neon Dream Bat — custom Meshy GLB import for Hashiworld local testing.
-- Mesh has embedded textures; no skeletal walk clips in this export (see README).

local model_file = "neon_dream_bat.glb"

core.register_entity("neon_dream_bat:creature", {
	initial_properties = {
		visual = "mesh",
		mesh = model_file,
		-- GLB carries its own materials/textures; empty slot is fine on 5.10+.
		textures = {},
		visual_size = { x = 1, y = 1, z = 1 },
		backface_culling = true,
		physical = false,
		collide_with_objects = false,
		pointable = true,
	},

	on_activate = function(self)
		local props = self.object:get_properties()
		props.mesh = model_file
		self.object:set_properties(props)
	end,

	on_step = function(self, dtime)
		-- Idle spin only (cosmetic). Real walk needs skinned GLB + set_animation.
		local rot = self.object:get_rotation()
		self.object:set_rotation({
			x = rot.x,
			y = (rot.y + dtime * 0.3) % (math.pi * 2),
			z = rot.z,
		})
	end,

	on_punch = function(self, _puncher)
		self.object:remove()
	end,
})

core.register_craftitem("neon_dream_bat:model", {
	description = "Neon Dream Bat (Meshy test)",
	inventory_image = "neon_dream_bat_inv.png",
	on_place = function(itemstack, _placer, pointed_thing)
		if pointed_thing.type ~= "node" then
			return itemstack
		end
		local pos = core.get_pointed_thing_position(pointed_thing, true)
		if not pos then
			return itemstack
		end
		core.add_entity(pos, "neon_dream_bat:creature")
		itemstack:take_item()
		return itemstack
	end,
})

core.register_chatcommand("spawn_neon_dream_bat", {
	description = "Spawn Neon Dream Bat GLB in front of you (Hashiworld mesh import test)",
	privs = {},
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end

		local pos = player:get_pos()
		local look = player:get_look_dir()
		pos.x = pos.x + look.x * 3
		pos.y = pos.y + 1.5
		pos.z = pos.z + look.z * 3

		core.add_entity(pos, "neon_dream_bat:creature")
		return true, "Spawned neon_dream_bat at " .. core.pos_to_string(pos)
			.. " (punch to remove). Mesh is ~59MB — first load may hitch."
	end,
})

core.log("action", "[neon_dream_bat] Loaded — /spawn_neon_dream_bat")
