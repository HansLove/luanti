-- Nose Atu — cosmic owlbeast that lives at Y >= 5000 (space and above).
--
-- Authored in blender_sources/Nose_atu.blend. One glTF track, two clips:
--   idle  frames 1–40
--   hyper frames 40–65  (fly / "run")
-- Blender is 24 fps; glTF stores those as seconds, which Luanti uses as frame
-- numbers (doc/lua_api.md play_animation).

local modpath = core.get_modpath("hashimon_entities")

local MESH = "nose_atu.glb"
local TEXTURE = "nose_atu.jpg"
local ENTITY = "hashimon_entities:nose_atu"

-- glTF is 10 mesh units per node. Mesh is ~11.0 units tall; 2.7 ≈ 3 nodes.
local VISUAL_SIZE = 2.7

local FPS = 24
local ANIM_TRACK = 1
local ANIM_IDLE = { x = 1 / FPS, y = 40 / FPS }
local ANIM_HYPER = { x = 40 / FPS, y = 65 / FPS }

local SPACE_YMIN = 5000
local SPACE_YMAX = 32767
if otherworlds
	and otherworlds.settings
	and otherworlds.settings.space_asteroids
then
	SPACE_YMIN = otherworlds.settings.space_asteroids.YMIN or SPACE_YMIN
end

local CRUISE_SPEED = 4.2
local HYPER_SPEED = 7.5
local HOVER_SPEED = 0.45
local RETARGET_MIN = 5
local RETARGET_MAX = 11
local SPAWN_RADIUS = 80
local MAX_NEAR_PLAYER = 2

local model_present = false
do
	local f = io.open(modpath .. "/models/" .. MESH, "r")
	if f then
		f:close()
		model_present = true
	end
end

local function vec_len(v)
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function play_clip(self, name)
	if self._anim == name then
		return
	end
	self._anim = name
	local range = name == "hyper" and ANIM_HYPER or ANIM_IDLE
	local speed = name == "hyper" and 1.15 or 1.0
	local ok, err = pcall(function()
		self.object:play_animation(ANIM_TRACK, {
			min_frame = range.x,
			max_frame = range.y,
			speed = speed,
			loop = true,
			blend = 0.18,
		})
	end)
	if not ok then
		core.log("warning", "[hashimon_entities] nose_atu: play_animation failed ("
			.. tostring(err) .. ") — falling back to set_animation")
		self.object:set_animation(range, speed, 0.18, true)
	end
end

local function pick_target(pos)
	local dist = 14 + math.random() * 22
	local yaw = math.random() * math.pi * 2
	local pitch = (math.random() - 0.5) * 0.7
	local target = {
		x = pos.x + math.cos(yaw) * math.cos(pitch) * dist,
		y = pos.y + math.sin(pitch) * dist,
		z = pos.z + math.sin(yaw) * math.cos(pitch) * dist,
	}
	target.y = math.max(SPACE_YMIN + 6, math.min(SPACE_YMAX - 6, target.y))
	return target
end

local function apply_size(self, size)
	size = size or VISUAL_SIZE
	local scale = size / VISUAL_SIZE
	local box = {
		-0.7 * scale, -0.2 * scale, -1.4 * scale,
		0.7 * scale, 2.9 * scale, 1.4 * scale,
	}
	self._visual_size = size
	self.object:set_properties({
		visual_size = { x = size, y = size, z = size },
		collisionbox = box,
		selectionbox = box,
	})
end

core.register_entity(ENTITY, {
	initial_properties = {
		visual = "mesh",
		mesh = MESH,
		-- Luanti never reads glTF-embedded images. It also binds the mesh to
		-- textures[baseColorTexture.index] in the glTF textures[] array, not
		-- to Lua textures[1]. This file's array is: 0=normal, 1=base_color,
		-- 2=metallic_roughness — so the color map has to sit at slot 1 or the
		-- mesh renders untextured (solid dark).
		textures = { TEXTURE, TEXTURE, TEXTURE },
		visual_size = { x = VISUAL_SIZE, y = VISUAL_SIZE, z = VISUAL_SIZE },
		collisionbox = { -0.7, -0.2, -1.4, 0.7, 2.9, 1.4 },
		selectionbox = { -0.7, -0.2, -1.4, 0.7, 2.9, 1.4 },
		physical = true,
		collide_with_objects = false,
		pointable = true,
		static_save = false,
		hp_max = 40,
		glow = 8,
		shaded = false,
		makes_footstep_sound = false,
		backface_culling = false,
		automatic_face_movement_dir = 0.0,
		automatic_face_movement_max_rotation_per_sec = 160,
		stepheight = 1.5,
		infotext = "Nose Atu",
	},

	on_activate = function(self, _staticdata)
		self.object:set_armor_groups({ immortal = 1 })
		self.object:set_acceleration({ x = 0, y = 0, z = 0 })
		self.object:set_nametag_attributes({
			text = "Nose Atu",
			color = "#C4B5FD",
		})
		apply_size(self, self._visual_size or VISUAL_SIZE)
		play_clip(self, "idle")
		local pos = self.object:get_pos()
		if pos then
			self._target = pick_target(pos)
		end
		self._retarget = RETARGET_MIN + math.random() * (RETARGET_MAX - RETARGET_MIN)
	end,

	on_step = function(self, dtime)
		local pos = self.object:get_pos()
		if not pos then
			return
		end

		self._retarget = (self._retarget or RETARGET_MIN) - dtime
		if not self._target or self._retarget <= 0 then
			self._target = pick_target(pos)
			self._retarget = RETARGET_MIN + math.random() * (RETARGET_MAX - RETARGET_MIN)
		end

		local dx = self._target.x - pos.x
		local dy = self._target.y - pos.y
		local dz = self._target.z - pos.z
		local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

		if dist < 2.5 then
			self.object:set_velocity({
				x = dx * 0.15,
				y = dy * 0.15,
				z = dz * 0.15,
			})
			play_clip(self, "idle")
			return
		end

		local speed = dist > 18 and HYPER_SPEED or CRUISE_SPEED
		local inv = speed / dist
		self.object:set_velocity({
			x = dx * inv,
			y = dy * inv,
			z = dz * inv,
		})

		local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
		if vec_len(vel) > HOVER_SPEED then
			play_clip(self, "hyper")
		else
			play_clip(self, "idle")
		end
	end,

	on_punch = function(self, puncher)
		if puncher and puncher:is_player() then
			core.chat_send_player(puncher:get_player_name(),
				"[Hashimon] Nose Atu — flies the 5K layer and above.")
		end
	end,
})

local function count_nearby(pos, radius)
	local n = 0
	for _, obj in ipairs(core.get_objects_inside_radius(pos, radius)) do
		local ent = obj:get_luaentity()
		if ent and ent.name == ENTITY then
			n = n + 1
		end
	end
	return n
end

local function spawn_at(pos, size)
	if not model_present then
		return nil
	end
	local obj = core.add_entity(pos, ENTITY)
	if obj then
		local ent = obj:get_luaentity()
		if ent then
			apply_size(ent, size)
		end
	end
	return obj
end

local spawn_timer = 0
core.register_globalstep(function(dtime)
	if not model_present then
		return
	end
	spawn_timer = spawn_timer + dtime
	if spawn_timer < 22 then
		return
	end
	spawn_timer = 0

	for _, player in ipairs(core.get_connected_players()) do
		local pos = player:get_pos()
		if pos and pos.y >= SPACE_YMIN and pos.y <= SPACE_YMAX then
			if count_nearby(pos, SPAWN_RADIUS) < MAX_NEAR_PLAYER and math.random() < 0.35 then
				local angle = math.random() * math.pi * 2
				local dist = 18 + math.random() * 28
				local spawn = {
					x = pos.x + math.cos(angle) * dist,
					y = pos.y + 6 + math.random() * 14,
					z = pos.z + math.sin(angle) * dist,
				}
				spawn.y = math.max(SPACE_YMIN + 4, spawn.y)
				local node = core.get_node(spawn)
				local nodedef = core.registered_nodes[node.name]
				if nodedef and not nodedef.walkable then
					spawn_at(spawn)
				end
			end
		end
	end
end)

core.register_chatcommand("nose_atu", {
	params = "[size]",
	description = "Spawn Nose Atu in front of you (optional visual_size, default "
		.. tostring(VISUAL_SIZE) .. ")",
	privs = { server = true },
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "player not found"
		end
		if not model_present then
			return false, "models/" .. MESH .. " is missing — export the .blend and restart"
		end

		local size = tonumber(param) or VISUAL_SIZE
		if size <= 0 then
			return false, "size must be > 0"
		end

		local pos = player:get_pos()
		local look = player:get_look_dir()
		local spawn = {
			x = pos.x + look.x * 8,
			y = pos.y + 2,
			z = pos.z + look.z * 8,
		}
		if not spawn_at(spawn, size) then
			return false, "add_entity returned nil — see the server log"
		end
		return true, string.format(
			"Nose Atu at %.1f, %.1f, %.1f (visual_size %.1f) — idle 1–40, hyper 40–65",
			spawn.x, spawn.y, spawn.z, size
		)
	end,
})

if model_present then
	core.log("action", string.format(
		"[hashimon_entities] Nose Atu registered (%s) — lives Y >= %d, /nose_atu to spawn",
		MESH, SPACE_YMIN
	))
else
	core.log("warning", "[hashimon_entities] Nose Atu registered but models/" .. MESH
		.. " is MISSING — /nose_atu will refuse until the file is exported there")
end
