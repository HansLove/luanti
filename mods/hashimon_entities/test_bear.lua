-- Development-only proof of concept: our own Blender-authored animated GLB.
--
-- Answers exactly one question — does Blender -> GLB -> Luanti skeletal
-- animation work? — and deliberately nothing else. No DNA, no speciesKey, no
-- PoW, no roster, no evolution. Additive: it touches no existing entity.
--
-- Plain core.register_entity rather than creatura.register_mob, for two reasons:
--   1. it matches the repo. The existing GLB path (hashimon_entities:creature in
--      entities.lua) is a plain entity; Creatura drives the .b3d bodies over in
--      hashimon_bodies, and Creatura has no glTF-specific animation handling.
--   2. a POC should isolate its variable. Creatura's AI, physics and animation
--      FSM would sit between the model and the screen, and a mesh problem would
--      surface as "the mob is broken" instead of "the mesh is broken".

local modpath = core.get_modpath("hashimon_entities")

local MESH = "hashimon_super_bear.glb"

-- glTF is fixed at 10 mesh units per node. 11.8 comes from the model's measured
-- bounding box (1.14 x 1.02 x 1.47 mesh units) and puts the bear at ~1.2 nodes
-- tall, roughly player height. Tune live with /htestsize if it still looks off.
local VISUAL_SIZE = 11.8

-- Track 1 = the first animation track, addressed by INDEX, not by name.
-- read_track_id (src/script/lua_api/l_object.cpp) takes a number as an index and
-- a string as a name, so this works whether or not Blender named the action.
local ANIM_TRACK = 1

local model_present = false
do
	local f = io.open(modpath .. "/models/" .. MESH, "r")
	if f then
		f:close()
		model_present = true
	end
end

core.register_entity("hashimon_entities:test_bear", {
	initial_properties = {
		visual = "mesh",
		mesh = MESH,
		-- Extracted from the GLB, because Luanti never reads glTF-embedded images.
		-- 2048x2048 JPEG, ~3.8MB — that is nearly the whole asset, and every
		-- client downloads it on first spawn. Worth halving to 1024 before this
		-- pattern is used for more than one test creature.
		textures = { "hashimon_super_bear.jpg" },
		visual_size = { x = VISUAL_SIZE, y = VISUAL_SIZE, z = VISUAL_SIZE },
		collisionbox = { -0.5, 0.0, -0.5, 0.5, 1.2, 0.5 },
		selectionbox = { -0.5, 0.0, -0.5, 0.5, 1.2, 0.5 },
		physical = true,
		collide_with_objects = false,
		static_save = false,
		hp_max = 20,
		infotext = "Hashimon test bear (POC)",
	},

	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })

		-- play_animation with no spec: max_frame defaults to infinity and the
		-- client clamps it to the track's real first/last frame, so the whole
		-- animation plays at its true length without us knowing the duration.
		-- Default speed is 1.0, which is what glTF needs — its keyframe times
		-- ARE the frame numbers, in seconds (doc/lua_api.md:437).
		local ok, err = pcall(function()
			self.object:play_animation(ANIM_TRACK)
		end)
		if ok then
			core.log("action", "[hashimon_entities] test_bear: play_animation(track "
				.. tostring(ANIM_TRACK) .. ") applied, auto-clamped to track length")
		else
			core.log("warning", "[hashimon_entities] test_bear: play_animation failed ("
				.. tostring(err) .. ") — client older than 5.17? Falling back to set_animation")
			-- Same engine path: l_set_animation builds the identical TrackAnimSpec
			-- and calls setAnimation(track 0). So the client clamps this range to
			-- the track's real length too, which makes over-specifying the SAFE
			-- direction — 600 collapses to whatever the clip actually is. devtest
			-- relies on the same trick (y = 140 for a 5s spider clip).
			-- Units are seconds, and speed must be 1.0 for glTF.
			self.object:set_animation({ x = 0, y = 600 }, 1.0, 0, true)
		end
	end,
})

core.register_chatcommand("htest", {
	description = "Spawn the animated GLB test bear in front of you (dev POC)",
	privs = { server = true },
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "player not found"
		end
		if not model_present then
			return false, "models/" .. MESH .. " is missing — copy the .glb there and restart the server"
		end

		local pos = player:get_pos()
		local look = player:get_look_dir()
		local spawn = {
			x = pos.x + look.x * 3,
			y = pos.y + 0.5,
			z = pos.z + look.z * 3,
		}

		local obj = core.add_entity(spawn, "hashimon_entities:test_bear")
		if not obj then
			return false, "add_entity returned nil — see the server log"
		end
		return true, string.format("test bear spawned at %.1f, %.1f, %.1f (visual_size %d)",
			spawn.x, spawn.y, spawn.z, VISUAL_SIZE)
	end,
})

core.register_chatcommand("htestsize", {
	params = "<size>",
	description = "Re-scale every spawned test bear (dev POC)",
	privs = { server = true },
	func = function(name, param)
		local size = tonumber(param)
		if not size or size <= 0 then
			return false, "usage: /htestsize <number>, e.g. /htestsize 4"
		end
		local player = core.get_player_by_name(name)
		if not player then
			return false, "player not found"
		end
		local count = 0
		for _, obj in ipairs(core.get_objects_inside_radius(player:get_pos(), 50)) do
			local ent = obj:get_luaentity()
			if ent and ent.name == "hashimon_entities:test_bear" then
				obj:set_properties({ visual_size = { x = size, y = size, z = size } })
				count = count + 1
			end
		end
		return true, count .. " test bear(s) rescaled to " .. size
			.. " — write the value that looks right into test_bear.lua"
	end,
})

if model_present then
	core.log("action", "[hashimon_entities] test_bear registered (" .. MESH .. ") — /htest to spawn")
else
	core.log("warning", "[hashimon_entities] test_bear registered but models/" .. MESH
		.. " is MISSING — /htest will refuse until the file is copied there")
end
