-- Hashimon native player avatars (Bob). Replaces Minetest Game Sam on join.
-- Mesh: models/hashimon_bob.glb — clips authored in Blender (24 fps → Luanti frames).
--
-- IMPORTANT: 3d_armor + player_api keep a Sam-format skin (character.png UV atlas)
-- in player_data.textures. set_model() reuses that list, so Bob's mesh would get
-- Sam colors painted on wrong UVs ("embutido"). Always force hashimon_bob.png after
-- set_model, and block 3d_armor visual overrides while Bob is active.

hashimon = hashimon or {}

local MODEL_BOB = "hashimon_bob.glb"
local TEX_BOB = "hashimon_bob.png"

-- Mesh height ~6.15 glTF units → human ~1.7 nodes ⇒ visual_size ≈ 2.76
local BOB_VISUAL = 2.76

-- Clips from bob.glb (track to frame 390; locomotion still stand/walk/sit).
-- Extra frames 81–390 reserved / authored; sit remains 71–80 until sit art extends.
local BOB_ANIMS = {
	stand = { x = 0, y = 31 },
	walk = { x = 41, y = 70 },
	sit = {
		x = 71,
		y = 80,
		eye_height = 0.8,
		override_local = true,
		collisionbox = { -0.3, 0.0, -0.3, 0.3, 1.0, 0.3 },
	},
	mine = { x = 0, y = 31 },
	walk_mine = { x = 41, y = 70 },
	lay = {
		x = 0,
		y = 31,
		eye_height = 0.3,
		override_local = true,
		collisionbox = { -0.6, 0.0, -0.6, 0.6, 0.3, 0.6 },
	},
}

hashimon.PLAYER_MODELS = {
	bob = {
		id = "bob",
		mesh = MODEL_BOB,
		texture = TEX_BOB,
		label = "Bob",
	},
}

hashimon.PLAYER_DEFAULT_AVATAR = "bob"

local function model_file_ok(mesh)
	local modpath = core.get_modpath("hashimon_players")
	if not modpath then
		return false
	end
	local f = io.open(modpath .. "/models/" .. mesh, "r")
	if f then
		f:close()
		return true
	end
	return false
end

function hashimon.get_player_avatar(player)
	if not player or not player:is_player() then
		return hashimon.PLAYER_DEFAULT_AVATAR
	end
	local meta = player:get_meta()
	local id = meta:get_string("hashimon:avatar")
	if id == "" or not hashimon.PLAYER_MODELS[id] then
		return hashimon.PLAYER_DEFAULT_AVATAR
	end
	return id
end

--- Bone convention of the current player mesh ("hashimon" or "sam").
function hashimon.player_attach_target(player)
	if not player or not player:is_player() then
		return "sam"
	end
	local sk = player:get_meta():get_string("hashimon:skeleton")
	if sk == "hashimon" then
		return "hashimon"
	end
	local props = player:get_properties()
	if props and props.mesh == MODEL_BOB then
		return "hashimon"
	end
	return "sam"
end

--- True when this player should use Hashimon mesh UVs (not Sam character.png).
function hashimon.player_uses_native_skin(player)
	return hashimon.player_attach_target(player) == "hashimon"
end

function hashimon.apply_player_avatar(player, avatar_id)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	avatar_id = avatar_id or hashimon.get_player_avatar(player)
	local def = hashimon.PLAYER_MODELS[avatar_id]
	if not def then
		return false, "unknown"
	end
	if not player_api or not player_api.set_model then
		return false, "no_player_api"
	end
	if not model_file_ok(def.mesh) then
		core.log("error", "[hashimon_players] missing model " .. def.mesh)
		return false, "missing_mesh"
	end

	local tex = def.texture or TEX_BOB
	-- Clear any Sam/3d_armor texture list BEFORE set_model, otherwise
	-- player_api keeps player_data.textures (character.png layers).
	if player_api.set_textures then
		player_api.set_textures(player, { tex })
	end
	player_api.set_model(player, def.mesh)
	-- set_model is a no-op if already on this mesh — force texture again.
	if player_api.set_textures then
		player_api.set_textures(player, { tex })
	end
	player:set_properties({
		mesh = def.mesh,
		textures = { tex },
		visual = "mesh",
		visual_size = { x = BOB_VISUAL, y = BOB_VISUAL },
	})
	player:get_meta():set_string("hashimon:skeleton", "hashimon")
	player:get_meta():set_string("hashimon:avatar", avatar_id)
	return true, def.label or avatar_id
end

function hashimon.set_player_avatar(player, avatar_id)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	avatar_id = (avatar_id or ""):lower()
	local def = hashimon.PLAYER_MODELS[avatar_id]
	if not def then
		return false, "unknown"
	end
	if not model_file_ok(def.mesh) then
		return false, "missing_mesh"
	end
	player:get_meta():set_string("hashimon:avatar", avatar_id)
	return hashimon.apply_player_avatar(player, avatar_id)
end

-- 3d_armor paints Sam UV layers ([skin, armor, wield]). Block that while Bob is on.
local function patch_armor_visuals()
	if not armor or not armor.update_player_visuals then
		return
	end
	if armor._hashimon_bob_patched then
		return
	end
	armor._hashimon_bob_patched = true
	local prev = armor.update_player_visuals
	armor.update_player_visuals = function(self, player)
		if player and hashimon.player_uses_native_skin(player) then
			local avatar = hashimon.get_player_avatar(player)
			local def = hashimon.PLAYER_MODELS[avatar]
			local tex = (def and def.texture) or TEX_BOB
			if player_api and player_api.set_textures then
				player_api.set_textures(player, { tex })
			else
				player:set_properties({ textures = { tex } })
			end
			if self.run_callbacks then
				self:run_callbacks("on_update", player)
			end
			return
		end
		return prev(self, player)
	end
	core.log("action", "[hashimon_players] 3d_armor visuals patched for Bob")
end

if not player_api or not player_api.register_model then
	core.log("error", "[hashimon_players] player_api missing — Bob not registered")
elseif not model_file_ok(MODEL_BOB) then
	core.log("error", "[hashimon_players] missing models/hashimon_bob.glb — Sam remains")
else
	player_api.register_model(MODEL_BOB, {
		animation_speed = 30,
		textures = { TEX_BOB },
		animations = BOB_ANIMS,
		collisionbox = { -0.3, 0.0, -0.3, 0.3, 1.7, 0.3 },
		stepheight = 0.6,
		eye_height = 1.47,
		visual_size = { x = BOB_VISUAL, y = BOB_VISUAL },
	})

	core.register_on_mods_loaded(function()
		patch_armor_visuals()
	end)

	core.register_on_joinplayer(function(player)
		-- Beat player_api Sam + 3d_armor_character.b3d (same-frame and delayed init).
		local function apply()
			if not player or not player:get_player_name() then
				return
			end
			hashimon.apply_player_avatar(player)
		end
		core.after(0, apply)
		core.after(0.5, apply)
		core.after(1.5, function()
			apply()
			local name = player and player:get_player_name()
			if name then
				core.chat_send_player(name,
					"[Hashimon] Avatar: Bob (textura propia, no skin Sam) — /hashimon avatar bob")
			end
		end)
	end)

	core.log("action", "[hashimon_players] Bob registered (stand 0–31, walk 41–70, sit 71–80)")
end
