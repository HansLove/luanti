-- Shared Creatura mob callbacks for morphology bodies.

hashimon_bodies = hashimon_bodies or {}

local function is_value_in_table(tbl, val)
	for _, v in pairs(tbl) do
		if v == val then
			return true
		end
	end
	return false
end

local function register_owner_pet(self)
	if not self.owner then
		return
	end
	if not core.get_player_by_name(self.owner) then
		return
	end
	if not animalia or not animalia.pets then
		return
	end
	animalia.pets[self.owner] = animalia.pets[self.owner] or {}
	if not is_value_in_table(animalia.pets[self.owner], self.object) then
		table.insert(animalia.pets[self.owner], self.object)
	end
end

function hashimon_bodies.apply_morphology(self, creature, morph)
	if not creature or not morph then
		return
	end
	self.hashimon_creature = creature
	self.hashimon_morph = morph

	local textures = self.textures or {}
	local n = #textures
	if n > 0 and self.set_texture then
		local idx = ((morph.texture_index or 1) - 1) % n + 1
		self:set_texture(idx, textures)
	end

	-- One modifier only. Concatenating a second, element-coloured colorize here
	-- is what flattened every creature into its element's colour.
	self.object:set_texture_mod(morph.texture_mod or "")
	self.object:set_properties({
		visual_size = morph.visual_size,
	})
	self.object:set_nametag_attributes({
		text = hashimon.nametag_for_creature(creature),
		color = "#E0E7FF",
	})

	-- Clear first: bone scale is multiplicative against the animation, so
	-- re-applying without clearing would compound on every respawn/resync.
	hashimon_bodies.clear_proportions(self, morph)
	local shaped = hashimon_bodies.apply_proportions(self, morph)
	if shaped > 0 then
		local p = morph.proportions or {}
		local t = p.traits or {}
		local function axis_or(trait, vec, fallback)
			if type(trait) == "number" then
				return trait
			end
			if type(vec) == "table" and type(vec.x) == "number" then
				return vec.x
			end
			return fallback
		end
		core.log("info", string.format(
			"[hashimon_bodies] %s: %d bone(s) shaped (head %.2f neck %.2f torso %.2f limbs %.2f)",
			tostring(morph.body_id), shaped,
			axis_or(t.headScale, p.head, 1),
			axis_or(t.neckLength, p.neck, 1),
			axis_or(t.torsoWidth, p.torso, 1),
			axis_or(t.limbLength, p.limbs, 1)))
	end

	hashimon_bodies.apply_attachments(self, morph)
end

function hashimon_bodies.make_activate(body_def)
	return function(self)
		animalia.initialize_api(self)

		local pending = hashimon.dequeue_morph_setup()
		if pending then
			self.owner = pending.owner
			self:memorize("owner", pending.owner)
			self.order = "follow"
			self:memorize("order", "follow")
			hashimon_bodies.apply_morphology(self, pending.creature, pending.morph)
		else
			self.owner = self:recall("owner")
			local creature = self:recall("hashimon_creature")
			local morph = self:recall("hashimon_morph")
			if creature and morph then
				hashimon_bodies.apply_morphology(self, creature, morph)
			end
		end

		animalia.protect_from_despawn(self)
		register_owner_pet(self)
	end
end

function hashimon_bodies.make_step(body_def)
	return function(self)
		animalia.step_timers(self)
		if animalia.head_tracking then
			animalia.head_tracking(self)
		end
		hashimon_bodies.update_anim_fsm(self, body_def)
		if self.hashimon_morph then
			self._aura_tick = (self._aura_tick or 0) + 1
			if self._aura_tick % 9 == 0 then
				hashimon_bodies.update_aura(self, self.hashimon_morph, 0.45)
			end
		end
	end
end

function hashimon_bodies.make_deactivate()
	return function(self)
		hashimon_bodies.clear_attachments(self.object)
		if self.owner and animalia and animalia.pets and animalia.pets[self.owner] then
			for i, object in ipairs(animalia.pets[self.owner]) do
				if object == self.object then
					animalia.pets[self.owner][i] = nil
				end
			end
		end
	end
end

function hashimon_bodies.register_creatura_body(body_def)
	hashimon.register_body(body_def)

	creatura.register_mob("hashimon_bodies:" .. body_def.id, {
		visual_size = { x = body_def.visual_size_base or 10, y = body_def.visual_size_base or 10 },
		mesh = body_def.mesh,
		textures = body_def.textures,
		makes_footstep_sound = body_def.makes_footstep_sound ~= false,
		static_save = false,

		max_health = 20,
		armor_groups = { immortal = 1 },
		damage = 0,
		speed = body_def.speed or 4,
		tracking_range = 24,
		despawn_after = false,
		stepheight = body_def.stepheight or 1.1,
		max_fall = body_def.max_fall,
		sounds = body_def.sounds or {},
		hitbox = body_def.hitbox or { width = 0.35, height = 0.7 },
		animations = body_def.animations,

		flee_puncher = false,
		assist_owner = false,
		catch_with_net = false,
		catch_with_lasso = false,
		head_data = body_def.head_data,

		utility_stack = {
			animalia.mob_ai.tamed_stay,
			animalia.mob_ai.tamed_follow_owner,
		},

		activate_func = hashimon_bodies.make_activate(body_def),
		step_func = hashimon_bodies.make_step(body_def),
		deactivate_func = hashimon_bodies.make_deactivate(),

		on_rightclick = function(self, clicker)
			if not clicker:is_player() then
				return
			end
			-- Provided by hashimon_entities when that mod is loaded (no hard dep — avoids cycle).
			if hashimon.try_shift_blast_attack
				and hashimon.try_shift_blast_attack(
					clicker,
					self.object,
					self.hashimon_creature,
					self.owner
				)
			then
				return
			end
			if hashimon.send_creature_stats then
				hashimon.send_creature_stats(clicker:get_player_name(), self.hashimon_creature)
			end
		end,

		on_punch = function(self, puncher)
			if not puncher or not puncher:is_player() then
				return
			end
			if hashimon.send_creature_stats then
				hashimon.send_creature_stats(puncher:get_player_name(), self.hashimon_creature)
			end
		end,
	})
end
