-- Personal-space follow for Creatura morphology bodies.
-- Replaces Animalia's tamed_follow_owner (stops at width+1 ≈ sticky).

hashimon_bodies = hashimon_bodies or {}

local function xz_dist(a, b)
	local dx = a.x - b.x
	local dz = a.z - b.z
	return math.sqrt(dx * dx + dz * dz)
end

local function comfort_resume(obj)
	if hashimon and hashimon.follow_resume_for then
		return hashimon.follow_resume_for(obj)
	end
	local comfort = (hashimon and hashimon.FOLLOW_COMFORT) or 5.5
	local resume = (hashimon and hashimon.FOLLOW_RESUME) or 7.5
	if obj and obj.get_properties then
		local props = obj:get_properties()
		local box = props and props.collisionbox
		if box and #box >= 6 then
			local half_w = math.max(
				math.abs(box[1]), math.abs(box[4]),
				math.abs(box[3]), math.abs(box[6])
			)
			comfort = math.max(comfort, half_w + 2)
		end
	end
	if resume < comfort + 1.5 then
		resume = comfort + 1.5
	end
	return resume, comfort
end

creatura.register_utility("hashimon:follow_owner", function(self, player)
	local function func(mob)
		local owner = player
			or (mob.owner and core.get_player_by_name(mob.owner))
		if not owner then
			return true
		end

		local pos = mob.object:get_pos()
		local target_pos = owner:get_pos()
		if not pos or not target_pos then
			return true
		end

		if not mob:get_action() then
			local dist = xz_dist(pos, target_pos)
			local resume, comfort = comfort_resume(mob.object)

			if mob._follow_active then
				if dist <= comfort then
					mob._follow_active = false
					creatura.action_idle(mob, 1)
				else
					animalia.action_pursue(mob, owner)
				end
			else
				if dist > resume then
					mob._follow_active = true
					animalia.action_pursue(mob, owner)
				else
					creatura.action_idle(mob, 1)
				end
			end
		end
	end
	self:set_utility(func)
end)

hashimon_bodies.mob_ai_follow_owner = {
	utility = "hashimon:follow_owner",
	get_score = function(self)
		if self.owner and self.order == "follow" then
			return 0.4, { self }
		end

		local lasso_holder = type(self._lassod_to) == "string"
			and core.get_player_by_name(self._lassod_to)
		local player = lasso_holder or creatura.get_nearby_player(self)

		if lasso_holder or (player and self.follow_wielded_item and self:follow_wielded_item(player)) then
			return 0.4, { self, player }
		end
		return 0
	end,
}
