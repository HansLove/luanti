-- Hashimon companion mob — wolf mesh/animations from Animalia, minimal tamed AI.

if not core.get_modpath("animalia") or not core.get_modpath("creatura") then
	return
end

if not animalia or not animalia.mob_ai then
	core.log("warning", "[hashimon_entities] Animalia API not ready — companion mob skipped")
	return
end

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
	if not minetest.get_player_by_name(self.owner) then
		return
	end
	animalia.pets[self.owner] = animalia.pets[self.owner] or {}
	if not is_value_in_table(animalia.pets[self.owner], self.object) then
		table.insert(animalia.pets[self.owner], self.object)
	end
end

creatura.register_mob("hashimon_entities:companion", {
	visual_size = { x = 10, y = 10 },
	mesh = "animalia_wolf.b3d",
	textures = {
		"animalia_wolf_1.png",
		"animalia_wolf_2.png",
		"animalia_wolf_3.png",
		"animalia_wolf_4.png",
	},
	makes_footstep_sound = true,
	static_save = false,

	max_health = 20,
	armor_groups = { immortal = 1 },
	damage = 0,
	speed = 4,
	tracking_range = 24,
	despawn_after = false,
	stepheight = 1.1,
	sounds = {},
	hitbox = {
		width = 0.35,
		height = 0.7,
	},
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 20, frame_blend = 0.3, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 30, frame_blend = 0.3, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 40, frame_blend = 0.3, loop = true },
		sit = { range = { x = 130, y = 139 }, speed = 10, frame_blend = 0.3, loop = true },
	},

	flee_puncher = false,
	assist_owner = false,
	catch_with_net = false,
	catch_with_lasso = false,
	head_data = {
		offset = { x = 0, y = 0.22, z = 0 },
		pitch_correction = -35,
		pivot_h = 0.45,
		pivot_v = 0.45,
	},

	utility_stack = {
		animalia.mob_ai.tamed_stay,
		(hashimon_bodies and hashimon_bodies.mob_ai_follow_owner)
			or animalia.mob_ai.tamed_follow_owner,
	},

	activate_func = function(self)
		animalia.initialize_api(self)

		local pending = hashimon.dequeue_companion_setup()
		if pending then
			self.hashimon_creature = pending.creature
			self.owner = pending.owner
			self:memorize("owner", pending.owner)
			self.order = "follow"
			self:memorize("order", "follow")
			hashimon.apply_companion_visuals(self, pending.creature)
		else
			self.hashimon_creature = self:recall("hashimon_creature")
			self.owner = self:recall("owner")
			if self.hashimon_creature then
				hashimon.apply_companion_visuals(self, self.hashimon_creature)
			end
		end

		animalia.protect_from_despawn(self)
		register_owner_pet(self)
	end,

	step_func = function(self, dtime)
		if self.rider and hashimon.step_mounted then
			hashimon.step_mounted(self, dtime)
			return
		end
		animalia.step_timers(self)
		animalia.head_tracking(self)
	end,

	deactivate_func = function(self)
		if self.owner and animalia.pets[self.owner] then
			for i, object in ipairs(animalia.pets[self.owner]) do
				if object == self.object then
					animalia.pets[self.owner][i] = nil
				end
			end
		end
	end,

	on_rightclick = function(self, clicker)
		if not clicker:is_player() then
			return
		end
		if hashimon.try_owner_carry
			and hashimon.try_owner_carry(
				clicker,
				self.object,
				self.hashimon_creature,
				self.owner
			)
		then
			return
		end
		if hashimon.try_owner_mount
			and hashimon.try_owner_mount(
				clicker,
				self.object,
				self.hashimon_creature,
				self.owner
			)
		then
			return
		end
		hashimon.send_creature_stats(clicker:get_player_name(), self.hashimon_creature)
	end,

	on_punch = function(self, puncher, _time_from_last_punch, _tool_capabilities, _direction, _damage)
		if not puncher or not puncher:is_player() then
			return
		end
		hashimon.send_creature_stats(puncher:get_player_name(), self.hashimon_creature)
	end,
})

hashimon.use_companion = true
core.log("action", "[hashimon_entities] Wolf companion mob registered (Animalia mesh)")
