-- Guard behaviour for Creatura morphology bodies.
--
-- The aggro model, damage numbers and elemental cubes all live in
-- hashimon_entities (defense.lua / element_cube.lua); this file is only the
-- Creatura adapter, so a rigged body guards with its real walk/run/melee
-- animations and pathfinding instead of the raw velocity push used by the
-- sprite and voxel tiers.
--
-- Score 0.8 — above follow_owner (0.4) and tamed_stay (0.5): a Hashimon that
-- is told to sit still defends anyway. That is the point of a guard.

hashimon_bodies = hashimon_bodies or {}

local GUARD_SCORE = 0.8

creatura.register_utility("hashimon:guard_owner", function(self, _target)
	local function func(mob)
		if not hashimon.guard_target_for then
			return true
		end
		local live_target = hashimon.guard_target_for(mob)
		if not live_target then
			return true
		end

		local alive, _, tpos = mob:get_target(live_target)
		if not alive or not tpos then
			return true
		end

		local pos = mob.object:get_pos()
		if not pos then
			return true
		end

		if mob:get_action() then
			return
		end

		local guard = hashimon.GUARD
		local dx, dy, dz = tpos.x - pos.x, tpos.y - pos.y, tpos.z - pos.z
		local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
		local reach = math.max(guard.melee_range, (mob.width or 0.5) + 1)

		if dist <= reach then
			hashimon.guard_melee(mob, live_target)
			local anim = (mob.animations and mob.animations.melee) and "melee" or "stand"
			creatura.action_idle(mob, 0.3, anim)
			return
		end

		if dist >= guard.ranged_min_range then
			hashimon.guard_try_ranged(mob, live_target)
		end

		local run_anim = (mob.animations and mob.animations.run) and "run" or "walk"
		animalia.action_pursue(mob, live_target, 1, nil, 1.0, run_anim)
	end
	self:set_utility(func)
end)

hashimon_bodies.mob_ai_guard_owner = {
	utility = "hashimon:guard_owner",
	step_delay = 0.1,
	get_score = function(self)
		if not hashimon.guard_target_for then
			return 0
		end
		local target = hashimon.guard_target_for(self)
		if not target then
			return 0
		end
		return GUARD_SCORE, { self, target }
	end,
}
