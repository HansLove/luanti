-- Villain Creatura entities — visual defs from hashimon body registry, hostile defaults.

hashimon_villain = hashimon_villain or {}

-- Flyers first, then ground bodies.
hashimon_villain.BODY_IDS = {
	"dragon_wyvern",
	"dragon_fire",
	"dragon_ice",
	"avian_bat",
	"humanoid_orc",
	"construct_golem",
}

hashimon_villain.active = hashimon_villain.active or {}

local function display_name(body_id)
	return hashimon_villain.display_name(body_id)
end

local function on_step_ai(self, dtime)
	if hashimon_villain.is_human_controlled(self) then
		hashimon_villain.step_possessed(self, dtime)
	elseif self.controller_mode == hashimon_villain.CONTROLLER_IDLE then
		self.object:set_velocity({ x = 0, y = (self.object:get_velocity() or {}).y or 0, z = 0 })
	elseif hashimon_ai_brain and hashimon_ai_brain.step_think then
		hashimon_ai_brain.step_think(self, dtime)
	else
		hashimon_villain.step_patrol_stub(self, dtime)
	end

	if hashimon_bodies and hashimon_bodies.update_anim_fsm then
		hashimon_bodies.update_anim_fsm(self, self.body_def)
	end
end

function hashimon_villain.register_body(body_id)
	local body_def = hashimon.get_body(body_id)
	if not body_def then
		core.log("warning", "[hashimon_villain] body not in registry: " .. body_id)
		return false
	end

	local entity_name = ":hashimon_villain:" .. body_id
	if core.registered_entities[entity_name] then
		return true
	end

	local profile = hashimon_villain.get_profile(body_id)
	local size_mult = profile.size_mult or 1.0
	local vs = (body_def.visual_size_base or 10) * size_mult
	local base_hitbox = body_def.hitbox or { width = 0.4, height = 2 }
	local hitbox = {
		width = (base_hitbox.width or 0.4) * size_mult,
		height = (base_hitbox.height or 2) * size_mult,
	}

	creatura.register_mob(entity_name, {
		visual_size = { x = vs, y = vs },
		mesh = body_def.mesh,
		textures = body_def.textures,
		makes_footstep_sound = body_def.makes_footstep_sound ~= false,
		static_save = false,

		max_health = 80,
		armor_groups = { fleshy = 100 },
		damage = 4,
		speed = body_def.speed or 4,
		tracking_range = 32,
		despawn_after = false,
		stepheight = body_def.stepheight or 1.1,
		max_fall = body_def.max_fall,
		sounds = body_def.sounds or {},
		hitbox = hitbox,
		animations = body_def.animations,
		head_data = body_def.head_data,

		flee_puncher = true,
		assist_owner = false,
		catch_with_net = false,
		catch_with_lasso = false,

		utility_stack = {},

		activate_func = function(self)
			animalia.initialize_api(self)
			self.body_id = body_id
			self.body_def = body_def
			self.monster_profile = profile
			local caps = body_def.capabilities or {}
			if hashimon_villain.is_flyer_profile(profile) or caps.fly then
				self.possess_speed = profile.fly_speed or ((body_def.speed or 5) + 2)
			else
				self.possess_speed = (body_def.speed or 4) + 1
			end
			hashimon_villain.init_controller(self, hashimon_villain.CONTROLLER_AI)
			self.patrol_anchor = self.object:get_pos()

			self.object:set_nametag_attributes({
				text = display_name(body_id),
				color = "#F87171",
			})

			table.insert(hashimon_villain.active, self.object)
			animalia.protect_from_despawn(self)
		end,

		step_func = function(self, dtime)
			animalia.step_timers(self)
			on_step_ai(self, dtime or 0.05)
		end,

		deactivate_func = function(self)
			for i, obj in ipairs(hashimon_villain.active) do
				if obj == self.object then
					table.remove(hashimon_villain.active, i)
					break
				end
			end
			if self.possessor then
				local player = core.get_player_by_name(self.possessor)
				if player then
					hashimon_villain.release(player)
				end
			end
		end,
	})

	core.log("action", "[hashimon_villain] Registered villain body: " .. body_id)
	return true
end

function hashimon_villain.register_all_bodies()
	for _, body_id in ipairs(hashimon_villain.BODY_IDS) do
		hashimon_villain.register_body(body_id)
	end
end

function hashimon_villain.spawn(body_id, pos, opts)
	opts = opts or {}
	local entity_name = "hashimon_villain:" .. body_id
	if not core.registered_entities[entity_name] then
		return nil, "unknown_body"
	end
	local spawn_pos = hashimon_villain.spawn_pos_for(body_id, pos)
	local obj = core.add_entity(spawn_pos, entity_name)
	if not obj then
		return nil, "spawn_failed"
	end
	local ent = obj:get_luaentity()
	if ent and opts.mode then
		hashimon_villain.set_controller_mode(ent, opts.mode)
	end
	return obj
end

function hashimon_villain.list_active()
	local lines = {}
	for _, obj in ipairs(hashimon_villain.active) do
		if obj and obj:get_luaentity() then
			local ent = obj:get_luaentity()
			local pos = obj:get_pos()
			local loc = pos and string.format("(%.0f, %.0f, %.0f)", pos.x, pos.y, pos.z) or "?"
			local who = ent.possessor and (" poseído por " .. ent.possessor) or ""
			table.insert(lines, string.format("  %s [%s] %s%s",
				ent.body_id or "?",
				ent.controller_mode or "?",
				loc,
				who))
		end
	end
	return lines
end
