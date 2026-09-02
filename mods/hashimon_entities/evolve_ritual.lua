-- Evolve / devolve ritual: mese crystal + orbiting shards → burst → Hashimon
-- respawns at target stage (★11 titan / ★6 adult / ★1 baby). Local-only.
--
-- Luanti server mods only see control bits (sneak, left, right, aux1, …) —
-- not raw letter keys. Beta binds (no Zoom/Z, no Jump/Space):
--   Hold Shift+D (strafe right) ≥1s → titan ★11
--   Hold Shift+A (strafe left)  ≥1s → baby ★1
-- Hotbar tools optional via /hashimon ritualkit (not given on join).

hashimon = hashimon or {}

hashimon.EVOLVE_STAGE_BABY = 1
hashimon.EVOLVE_STAGE_ADULT = 6
hashimon.EVOLVE_STAGE_TITAN = 11
hashimon.EVOLVE_RANGE = 8
hashimon.EVOLVE_SPIN_T = 1.6
hashimon.EVOLVE_KEY_CD = 3.0
hashimon.EVOLVE_HOLD_T = 1.0 -- seconds to hold combo before ritual fires
-- Hold-based binds on for beta (friendly; no hotbar required).
hashimon.evolve_hold_enabled = true
-- Legacy rising-edge sneak+jump (off — conflicts with jump taps).
hashimon.evolve_keybind_enabled = false
-- Hotbar kit off by default for beta; /hashimon ritualkit still works.
hashimon.ritual_kit_on_join = false

hashimon._evolve_rituals = hashimon._evolve_rituals or {}
hashimon._evolve_key_held = hashimon._evolve_key_held or {}
hashimon._evolve_key_cd = hashimon._evolve_key_cd or {}
hashimon._evolve_hold = hashimon._evolve_hold or {} -- [name] = { mode, t, hinted, fired }

local SPIN_RATE = 7.5
local ORBIT_RATE = 4.2
local ORBIT_RADIUS = 0.85 -- slightly wider orbit for presence
local SHARD_COUNT = 3

local CORE_TEX = "default_mese_crystal.png"
local SHARD_TEXES = {
	"default_mese_crystal_fragment.png",
	"default_diamond.png",
	"default_mese_crystal_fragment.png^[colorize:#A5F3FC:60",
}
local PARTICLE_TEX = "default_mese_crystal_fragment.png^[colorize:#E0F2FE:80"

local ITEM_ASCEND = "hashimon_entities:ritual_ascend"
local ITEM_BABY = "hashimon_entities:ritual_baby"

local function cube_textures(tex)
	return { tex, tex, tex, tex, tex, tex }
end

local function creature_from(ent)
	if not ent then
		return nil
	end
	if hashimon.creature_from_entity then
		return hashimon.creature_from_entity(ent)
	end
	return ent.hashimon_creature or ent.creature
end

local function normalize_stage(stage)
	stage = tonumber(stage) or hashimon.EVOLVE_STAGE_ADULT
	if stage < 1 then stage = 1 end
	if stage > 33 then stage = 33 end
	return math.floor(stage)
end

local function stage_label(stage)
	if stage <= hashimon.EVOLVE_STAGE_BABY then
		return "forma baby"
	end
	if stage >= hashimon.EVOLVE_STAGE_TITAN then
		return "modo titan"
	end
	if stage >= hashimon.EVOLVE_STAGE_ADULT then
		return "fase II adulta"
	end
	return "★" .. tostring(stage)
end

--- Nearest owned roster Hashimon within max_dist.
function hashimon.find_nearest_owned_entity(player, max_dist)
	if not player or not player:is_player() then
		return nil
	end
	local name = player:get_player_name()
	local ppos = player:get_pos()
	if not ppos then
		return nil
	end
	max_dist = max_dist or hashimon.EVOLVE_RANGE
	local max2 = max_dist * max_dist

	local best_obj, best_ent, best_c, best_d2

	local roster = hashimon.get_roster_entities and hashimon.get_roster_entities(name) or {}
	for _, ref in ipairs(roster) do
		local ent = ref and ref:get_luaentity()
		local rpos = ref and ref:get_pos()
		local c = creature_from(ent)
		if ent and rpos and c then
			local dx = rpos.x - ppos.x
			local dy = rpos.y - ppos.y
			local dz = rpos.z - ppos.z
			local d2 = dx * dx + dy * dy + dz * dz
			if d2 <= max2 and (not best_d2 or d2 < best_d2) then
				best_obj, best_ent, best_c, best_d2 = ref, ent, c, d2
			end
		end
	end

	if not best_obj then
		for _, obj in ipairs(core.get_objects_inside_radius(ppos, max_dist)) do
			local ent = obj:get_luaentity()
			if ent and not obj:is_player() then
				local owns = hashimon.player_owns_mount
					and hashimon.player_owns_mount(name, ent, ent.owner)
				local c = creature_from(ent)
				local rpos = obj:get_pos()
				if owns and c and rpos then
					local dx = rpos.x - ppos.x
					local dy = rpos.y - ppos.y
					local dz = rpos.z - ppos.z
					local d2 = dx * dx + dy * dy + dz * dz
					if not best_d2 or d2 < best_d2 then
						best_obj, best_ent, best_c, best_d2 = obj, ent, c, d2
					end
				end
			end
		end
	end

	if not best_obj then
		return nil
	end
	return best_obj, best_ent, best_c, math.sqrt(best_d2)
end

local function emit_spin_sparks(pos)
	core.add_particlespawner({
		amount = 10,
		time = 0.1,
		minpos = { x = pos.x - 0.45, y = pos.y - 0.15, z = pos.z - 0.45 },
		maxpos = { x = pos.x + 0.45, y = pos.y + 0.55, z = pos.z + 0.45 },
		minvel = { x = -0.4, y = 0.6, z = -0.4 },
		maxvel = { x = 0.4, y = 1.6, z = 0.4 },
		minacc = { x = 0, y = 0.2, z = 0 },
		maxacc = { x = 0, y = 0.5, z = 0 },
		minexptime = 0.35,
		maxexptime = 0.7,
		minsize = 0.8,
		maxsize = 1.8,
		texture = PARTICLE_TEX,
		glow = 11,
	})
end

local function clear_shards(self)
	if not self.shards then
		return
	end
	for _, ref in ipairs(self.shards) do
		if ref and ref:get_luaentity() then
			ref:remove()
		end
	end
	self.shards = nil
end

local function ritual_boom(pos)
	core.sound_play("default_glass_footstep", {
		pos = pos, gain = 1.2, max_hear_distance = 24,
	}, true)
	core.add_particlespawner({
		amount = 48,
		time = 0.18,
		minpos = { x = pos.x - 0.3, y = pos.y - 0.2, z = pos.z - 0.3 },
		maxpos = { x = pos.x + 0.3, y = pos.y + 0.5, z = pos.z + 0.3 },
		minvel = { x = -5, y = 1, z = -5 },
		maxvel = { x = 5, y = 8, z = 5 },
		minexptime = 0.35,
		maxexptime = 0.9,
		minsize = 1.2,
		maxsize = 3.0,
		texture = "default_mese_crystal_fragment.png",
		glow = 14,
	})
	core.add_particlespawner({
		amount = 20,
		time = 0.12,
		minpos = { x = pos.x - 0.2, y = pos.y, z = pos.z - 0.2 },
		maxpos = { x = pos.x + 0.2, y = pos.y + 0.4, z = pos.z + 0.2 },
		minvel = { x = -2, y = 2, z = -2 },
		maxvel = { x = 2, y = 6, z = 2 },
		minexptime = 0.4,
		maxexptime = 0.8,
		minsize = 1.0,
		maxsize = 2.2,
		texture = "default_diamond.png^[colorize:#A5F3FC:40",
		glow = 12,
	})
	if hashimon._has_tnt and tnt and tnt.boom then
		tnt.boom(pos, {
			radius = 1,
			damage_radius = 0,
			explode_center = true,
			ignore_protection = false,
		})
	end
end

local function spawn_shards(core_obj, ritual)
	ritual.shards = {}
	local cpos = core_obj:get_pos()
	if not cpos then
		return
	end
	for i = 1, SHARD_COUNT do
		local tex = SHARD_TEXES[((i - 1) % #SHARD_TEXES) + 1]
		local shard = core.add_entity(cpos, "hashimon_entities:evolve_shard")
		if shard then
			shard:set_properties({
				textures = cube_textures(tex),
				visual_size = { x = 0.22, y = 0.22 },
				glow = 10,
			})
			local angle = (i - 1) * (2 * math.pi / SHARD_COUNT)
			shard:set_attach(core_obj, "", {
				x = math.cos(angle) * ORBIT_RADIUS * 10,
				y = 0,
				z = math.sin(angle) * ORBIT_RADIUS * 10,
			}, { x = 0, y = 0, z = 0 })
			table.insert(ritual.shards, shard)
		end
	end
end

local function update_shard_orbits(self, t)
	if not self.shards then
		return
	end
	for i, shard in ipairs(self.shards) do
		if shard and shard:get_luaentity() then
			local base = (i - 1) * (2 * math.pi / SHARD_COUNT)
			local angle = base + t * ORBIT_RATE
			local bob = 0.12 * math.sin(t * 6 + base)
			shard:set_attach(self.object, "", {
				x = math.cos(angle) * ORBIT_RADIUS * 10,
				y = bob * 10,
				z = math.sin(angle) * ORBIT_RADIUS * 10,
			}, { x = 0, y = (angle * 57.3) % 360, z = 0 })
		end
	end
end

local function finish_evolve(self)
	local owner = self.owner
	local creature = self.creature
	local old_obj = self.target_obj
	local pos = self.object:get_pos() or self.anchor_pos
	local target = normalize_stage(self.target_stage or hashimon.EVOLVE_STAGE_ADULT)

	hashimon._evolve_rituals[owner] = nil
	clear_shards(self)

	if not creature or not owner or not pos then
		self.object:remove()
		return
	end

	if hashimon.apply_local_stars then
		hashimon.apply_local_stars(creature, target)
	else
		creature.stars = target
		creature.stage = target
		creature.tier = target
	end

	ritual_boom(pos)

	if old_obj and old_obj:get_luaentity() then
		if hashimon.clear_carry_for_object then
			hashimon.clear_carry_for_object(owner, old_obj)
		end
		hashimon.unregister_roster_entity(owner, old_obj)
		old_obj:remove()
	end

	local new_obj = hashimon.respawn_creature_at(pos, creature, owner)
	self.object:remove()

	local label = (creature.name and creature.name ~= "" and creature.name)
		or creature.speciesKey or "Hashimon"
	core.chat_send_player(owner, string.format(
		"[Hashimon] %s → %s ★%d (local — /hashimon sync revierte).",
		label, stage_label(target), target
	))
	return new_obj
end

core.register_entity("hashimon_entities:evolve_shard", {
	initial_properties = {
		visual = "cube",
		textures = cube_textures(SHARD_TEXES[1]),
		visual_size = { x = 0.22, y = 0.22 },
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		glow = 10,
	},
	on_activate = function(self)
		self.object:set_armor_groups({ immortal = 1 })
	end,
})

core.register_entity("hashimon_entities:evolve_core", {
	initial_properties = {
		visual = "cube",
		textures = cube_textures(CORE_TEX),
		visual_size = { x = 0.55, y = 0.55 },
		physical = false,
		collide_with_objects = false,
		pointable = false,
		static_save = false,
		glow = 13,
	},

	on_activate = function(self, _staticdata, _dtime)
		self.object:set_armor_groups({ immortal = 1 })
		self.t = 0
		self._spark_t = 0
		self.done = false
		self.shards = self.shards or {}
	end,

	on_deactivate = function(self)
		clear_shards(self)
	end,

	on_step = function(self, dtime)
		if self.done then
			return
		end
		self.t = (self.t or 0) + dtime
		local t = self.t
		local spin_t = hashimon.EVOLVE_SPIN_T

		self.object:set_yaw((t * SPIN_RATE) % (math.pi * 2))

		local pulse = 0.5 + 0.35 * math.min(1, t / spin_t)
		local wobble = 1 + 0.05 * math.sin(t * 10)
		local s = pulse * wobble
		self.object:set_properties({ visual_size = { x = s, y = s } })

		update_shard_orbits(self, t)

		self._spark_t = (self._spark_t or 0) + dtime
		if self._spark_t >= 0.11 then
			self._spark_t = 0
			local pos = self.object:get_pos()
			if pos then
				emit_spin_sparks(pos)
			end
		end

		if t >= spin_t then
			self.done = true
			finish_evolve(self)
		end
	end,
})

--- Begin ritual on nearest owned Hashimon.
--- @param target_stage number|nil default adult (6); use 1 for baby
function hashimon.start_evolve_ritual(player, target_stage)
	if not player or not player:is_player() then
		return false, "no_player"
	end
	local name = player:get_player_name()
	target_stage = normalize_stage(target_stage or hashimon.EVOLVE_STAGE_ADULT)

	if hashimon._evolve_rituals[name] then
		return false, "busy"
	end
	if hashimon.mounts and hashimon.mounts[name] then
		return false, "mounted"
	end
	if hashimon._impact_flights and hashimon._impact_flights[name] then
		return false, "yeeting"
	end
	if hashimon.carries and hashimon.carries[name] then
		return false, "carrying"
	end

	local obj, ent, creature = hashimon.find_nearest_owned_entity(player, hashimon.EVOLVE_RANGE)
	if not obj or not creature then
		return false, "none_nearby"
	end

	local stage = hashimon.creature_stage and hashimon.creature_stage(creature)
		or (creature.stars or creature.stage or 0)
	if stage == target_stage then
		return false, "same_stage", stage
	end
	if target_stage <= hashimon.EVOLVE_STAGE_BABY and stage <= hashimon.EVOLVE_STAGE_BABY then
		return false, "already_baby", stage
	end
	if target_stage >= hashimon.EVOLVE_STAGE_TITAN and stage >= hashimon.EVOLVE_STAGE_TITAN then
		return false, "already_titan", stage
	end
	if target_stage == hashimon.EVOLVE_STAGE_ADULT and stage == hashimon.EVOLVE_STAGE_ADULT then
		return false, "already_adult", stage
	end

	local pos = obj:get_pos()
	if not pos then
		return false, "none_nearby"
	end

	local props = obj:get_properties()
	ent._evolve_saved_visual = props and props.visual_size
	obj:set_properties({ visual_size = { x = 0.001, y = 0.001 } })
	obj:set_nametag_attributes({ text = "" })

	local core_obj = core.add_entity(
		{ x = pos.x, y = pos.y + 0.6, z = pos.z },
		"hashimon_entities:evolve_core"
	)
	if not core_obj then
		if ent._evolve_saved_visual then
			obj:set_properties({ visual_size = ent._evolve_saved_visual })
		end
		return false, "spawn_failed"
	end

	local ritual = core_obj:get_luaentity()
	ritual.owner = name
	ritual.creature = creature
	ritual.target_obj = obj
	ritual.target_stage = target_stage
	ritual.anchor_pos = { x = pos.x, y = pos.y, z = pos.z }
	spawn_shards(core_obj, ritual)

	hashimon._evolve_rituals[name] = true
	return true
end

local function ritual_err_msg(err, stage, target)
	if err == "none_nearby" then
		return "Acércate a tu Hashimon (menos de 8 bloques)."
	elseif err == "already_adult" then
		return string.format("Ya es fase II adulta (★%d).", stage or hashimon.EVOLVE_STAGE_ADULT)
	elseif err == "already_titan" then
		return string.format("Ya es modo titan (★%d).", stage or hashimon.EVOLVE_STAGE_TITAN)
	elseif err == "already_baby" then
		return string.format("Ya es forma baby (★%d).", stage or hashimon.EVOLVE_STAGE_BABY)
	elseif err == "same_stage" then
		return string.format("Ya está en ★%d.", stage or target or 0)
	elseif err == "mounted" then
		return "Baja del Hashimon primero."
	elseif err == "yeeting" then
		return "Espera a terminar el impacto."
	elseif err == "carrying" then
		return "Suelta el baby primero (/hashimon carry off)."
	elseif err == "busy" then
		return "Ya hay un ritual en curso."
	elseif err == "cooldown" then
		return "Espera un momento antes de otro ritual."
	end
	return "No se pudo iniciar el ritual (" .. tostring(err) .. ")."
end

function hashimon.evolve_ritual_command(name, rest)
	local player = core.get_player_by_name(name)
	if not player then
		return false, "Player not found"
	end
	local sub = (tostring(rest or ""):match("^(%S*)") or ""):lower()
	local target = hashimon.EVOLVE_STAGE_ADULT
	if sub == "baby" or sub == "1" then
		target = hashimon.EVOLVE_STAGE_BABY
	elseif sub == "titan" or sub == "11" then
		target = hashimon.EVOLVE_STAGE_TITAN
	elseif sub == "ritual" or sub == "adult" or sub == "6" then
		target = hashimon.EVOLVE_STAGE_ADULT
	end
	local ok, err, stage = hashimon.start_evolve_ritual(player, target)
	if ok then
		return true, "Ritual iniciado → " .. stage_label(target) .. "…"
	end
	return false, ritual_err_msg(err, stage, target)
end

--- Give Ascender + Baby tools if missing.
function hashimon.give_ritual_kit(player)
	if not player or not player:is_player() then
		return false
	end
	local inv = player:get_inventory()
	if not inv then
		return false
	end
	local added = 0
	for _, itemname in ipairs({ ITEM_ASCEND, ITEM_BABY }) do
		if not inv:contains_item("main", itemname) then
			inv:add_item("main", ItemStack(itemname))
			added = added + 1
		end
	end
	return true, added
end

local function use_ritual_tool(user, target_stage)
	if not user or not user:is_player() then
		return
	end
	local ok, err, stage = hashimon.start_evolve_ritual(user, target_stage)
	local name = user:get_player_name()
	if ok then
		core.chat_send_player(name, "[Hashimon] Ritual → " .. stage_label(target_stage) .. "…")
	else
		core.chat_send_player(name, "[Hashimon] " .. ritual_err_msg(err, stage, target_stage))
	end
end

core.register_tool(ITEM_ASCEND, {
	description = "Ritual Titan (★11)\nOpcional — preferí: mantén Shift+D 1s",
	inventory_image = "default_mese_crystal.png",
	wield_image = "default_mese_crystal.png",
	stack_max = 1,
	range = 8,
	on_use = function(_itemstack, user, _pointed)
		use_ritual_tool(user, hashimon.EVOLVE_STAGE_TITAN)
		return nil -- do not consume
	end,
	on_place = function(itemstack, placer, _pointed)
		use_ritual_tool(placer, hashimon.EVOLVE_STAGE_TITAN)
		return itemstack
	end,
	on_secondary_use = function(itemstack, user, _pointed)
		use_ritual_tool(user, hashimon.EVOLVE_STAGE_TITAN)
		return itemstack
	end,
})

core.register_tool(ITEM_BABY, {
	description = "Ritual Forma Baby (★1)\nOpcional — preferí: mantén Shift+A 1s",
	inventory_image = "default_diamond.png",
	wield_image = "default_diamond.png",
	stack_max = 1,
	range = 8,
	on_use = function(_itemstack, user, _pointed)
		use_ritual_tool(user, hashimon.EVOLVE_STAGE_BABY)
		return nil
	end,
	on_place = function(itemstack, placer, _pointed)
		use_ritual_tool(placer, hashimon.EVOLVE_STAGE_BABY)
		return itemstack
	end,
	on_secondary_use = function(itemstack, user, _pointed)
		use_ritual_tool(user, hashimon.EVOLVE_STAGE_BABY)
		return itemstack
	end,
})

local function try_fire_hold_ritual(player, name, target_stage)
	local now = core.get_us_time() / 1e6
	local last = hashimon._evolve_key_cd[name] or 0
	if now - last < hashimon.EVOLVE_KEY_CD then
		core.chat_send_player(name, "[Hashimon] " .. ritual_err_msg("cooldown"))
		return
	end
	hashimon._evolve_key_cd[name] = now
	local ok, err, stage = hashimon.start_evolve_ritual(player, target_stage)
	if ok then
		core.chat_send_player(name, "[Hashimon] Ritual → " .. stage_label(target_stage) .. "…")
	else
		core.chat_send_player(name, "[Hashimon] " .. ritual_err_msg(err, stage, target_stage))
	end
end

-- Hold Shift+D ≥1s → titan; Hold Shift+A ≥1s → baby.
-- Leaves Zoom (Z), Jump (Space), and yeet (Shift+E) alone.
core.register_globalstep(function(dtime)
	if not hashimon.evolve_hold_enabled then
		-- Legacy rising-edge sneak+jump (off by default).
		if not hashimon.evolve_keybind_enabled then
			return
		end
		local now = core.get_us_time() / 1e6
		for _, player in ipairs(core.get_connected_players()) do
			local name = player:get_player_name()
			local ctrl = player:get_player_control()
			local combo = ctrl.sneak and ctrl.jump
			local was = hashimon._evolve_key_held[name]
			hashimon._evolve_key_held[name] = combo
			if combo and not was then
				local last = hashimon._evolve_key_cd[name] or 0
				if now - last >= hashimon.EVOLVE_KEY_CD then
					hashimon._evolve_key_cd[name] = now
					hashimon.start_evolve_ritual(player, hashimon.EVOLVE_STAGE_ADULT)
				end
			end
		end
		return
	end

	local hold_need = hashimon.EVOLVE_HOLD_T or 1.0
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local ctrl = player:get_player_control()
		local sneak = ctrl.sneak
		-- Strafe only: ignore if both A+D, or if using jump/zoom/yeet bits.
		local want_titan = sneak and ctrl.right and not ctrl.left
			and not ctrl.jump and not ctrl.zoom and not ctrl.aux1
		local want_baby = sneak and ctrl.left and not ctrl.right
			and not ctrl.jump and not ctrl.zoom and not ctrl.aux1

		local mode = nil
		local target = nil
		if want_titan then
			mode, target = "titan", hashimon.EVOLVE_STAGE_TITAN
		elseif want_baby then
			mode, target = "baby", hashimon.EVOLVE_STAGE_BABY
		end

		local st = hashimon._evolve_hold[name]
		if not mode then
			hashimon._evolve_hold[name] = nil
		else
			if not st or st.mode ~= mode then
				st = { mode = mode, t = 0, hinted = false, fired = false }
				hashimon._evolve_hold[name] = st
			end
			st.t = st.t + dtime
			if not st.hinted and st.t >= 0.35 then
				st.hinted = true
				core.chat_send_player(name, string.format(
					"[Hashimon] Mantén… %s (%.0fs)",
					stage_label(target), hold_need
				))
			end
			if not st.fired and st.t >= hold_need then
				st.fired = true
				try_fire_hold_ritual(player, name, target)
			end
		end
	end
end)

core.register_on_joinplayer(function(player)
	core.after(1.5, function()
		if not player or not player:get_player_name() then
			return
		end
		local name = player:get_player_name()
		if hashimon.evolve_hold_enabled then
			core.chat_send_player(name,
				"[Hashimon] Ritual: mantén Shift+D 1s = Titan ★11 · Shift+A 1s = Baby. "
					.. "(Z y Espacio libres). Chat: /hashimon evolve titan|baby")
		end
		if hashimon.ritual_kit_on_join then
			local ok, added = hashimon.give_ritual_kit(player)
			if ok and added and added > 0 then
				core.chat_send_player(name,
					"[Hashimon] Kit ritual opcional en el inventario.")
			end
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	hashimon._evolve_rituals[name] = nil
	hashimon._evolve_key_held[name] = nil
	hashimon._evolve_key_cd[name] = nil
	hashimon._evolve_hold[name] = nil
end)

core.log("action", "[hashimon_entities] evolve_ritual loaded (hold Shift+D titan / Shift+A baby, orbit 0.85)")
