-- AI brain: 3D chase + breath-only ranged attack for flyers.

hashimon_ai_brain = hashimon_ai_brain or {}

hashimon_ai_brain.THINK_INTERVAL = 4
hashimon_ai_brain.ALLOWED_PROCESSES = { "idle", "patrol", "chase", "attack", "flee" }
hashimon_ai_brain.ATTACK_INTERVAL = 2.5
hashimon_ai_brain.RANGED_MIN_DIST = 6
hashimon_ai_brain.RANGED_MAX_DIST = 16
hashimon_ai_brain.RANGED_IDEAL_DIST = 10

hashimon_ai_brain._pending = hashimon_ai_brain._pending or {}

function hashimon_ai_brain.should_think(ent)
	if not ent then
		return false
	end
	if ent.possessor then
		return false
	end
	if ent.controller_mode == "human" then
		return false
	end
	if ent.controller_mode ~= "ai" then
		return false
	end
	return true
end

local function profile(self)
	return self.monster_profile or (hashimon_villain and hashimon_villain.get_profile(self.body_id))
end

local function is_flyer(self)
	local p = profile(self)
	return p and hashimon_villain and hashimon_villain.is_flyer_profile(p)
end

local function is_ranged(self)
	local p = profile(self)
	return p and p.ai_prefer_ranged and p.primary_attack == "breath"
end

local function dist_to_target(self)
	local target = self._chase_target
	if not target or not target:get_pos() then
		return math.huge
	end
	local pos = self.object:get_pos()
	local tpos = target:get_pos()
	if not pos then
		return math.huge
	end
	local dx, dy, dz = tpos.x - pos.x, tpos.y - pos.y, tpos.z - pos.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function hashimon_ai_brain.step_think(self, dtime)
	if not hashimon_ai_brain.should_think(self) then
		return
	end

	self._ai_timer = (self._ai_timer or hashimon_ai_brain.THINK_INTERVAL) - dtime
	if self._ai_timer > 0 then
		hashimon_ai_brain._apply_process(self, dtime)
		return
	end

	self._ai_timer = hashimon_ai_brain.THINK_INTERVAL
	self._ai_process = self._ai_process or "patrol"
	hashimon_ai_brain._decide_heuristic(self)
	hashimon_ai_brain._apply_process(self, dtime)
end

function hashimon_ai_brain._decide_heuristic(self)
	local pos = self.object:get_pos()
	if not pos then
		self._ai_process = "idle"
		return
	end

	local nearest_player
	local nearest_dist_sq = math.huge
	for _, obj in ipairs(core.get_objects_inside_radius(pos, 32)) do
		if obj:is_player() then
			local ppos = obj:get_pos()
			if ppos then
				local dx, dy, dz = ppos.x - pos.x, ppos.y - pos.y, ppos.z - pos.z
				local dist = dx * dx + dy * dy + dz * dz
				if dist < nearest_dist_sq then
					nearest_dist_sq = dist
					nearest_player = obj
				end
			end
		end
	end

	self._chase_target = nearest_player
	if not nearest_player then
		self._ai_process = "patrol"
		return
	end

	local dist = math.sqrt(nearest_dist_sq)
	if is_ranged(self) then
		if dist <= hashimon_ai_brain.RANGED_MAX_DIST and dist >= hashimon_ai_brain.RANGED_MIN_DIST then
			self._ai_process = "attack"
		elseif dist < hashimon_ai_brain.RANGED_MIN_DIST then
			self._ai_process = "flee"
		else
			self._ai_process = "chase"
		end
		return
	end

	if dist < 2.5 then
		self._ai_process = "attack"
	elseif dist < 24 then
		self._ai_process = "chase"
	else
		self._ai_process = "patrol"
	end
end

function hashimon_ai_brain._chase_flyer(self, pos, tpos, speed)
	local dx = tpos.x - pos.x
	local dy = tpos.y - pos.y + 3
	local dz = tpos.z - pos.z
	local len = math.sqrt(dx * dx + dy * dy + dz * dz)
	if len < 0.001 then
		return
	end
	local vx = dx / len * speed
	local vy = dy / len * speed
	local vz = dz / len * speed
	self.object:set_velocity({ x = vx, y = vy, z = vz })
	self.object:set_yaw(-math.atan2(dx, dz))
end

function hashimon_ai_brain._chase_ground(self, pos, tpos, speed)
	local dx = tpos.x - pos.x
	local dz = tpos.z - pos.z
	local horiz = math.sqrt(dx * dx + dz * dz)
	if horiz < 0.001 then
		return
	end
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
	self.object:set_velocity({ x = dx / horiz * speed, y = vel.y, z = dz / horiz * speed })
	self.object:set_yaw(-math.atan2(dx, dz))
end

function hashimon_ai_brain._apply_process(self, dtime)
	local process = self._ai_process or "patrol"
	dtime = dtime or 0.05

	if process == "idle" then
		local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		return
	end

	if process == "patrol" then
		if hashimon_villain and hashimon_villain.step_patrol_stub then
			hashimon_villain.step_patrol_stub(self, dtime)
		end
		return
	end

	if process == "chase" and self._chase_target then
		local target = self._chase_target
		if not target:get_pos() then
			self._ai_process = "patrol"
			return
		end
		local pos = self.object:get_pos()
		local tpos = target:get_pos()
		local speed = self.speed or 4
		if is_flyer(self) then
			hashimon_ai_brain._chase_flyer(self, pos, tpos, speed)
		else
			hashimon_ai_brain._chase_ground(self, pos, tpos, speed)
		end
		return
	end

	if process == "attack" then
		local target = self._chase_target
		if not target or not target:get_pos() then
			self._ai_process = "patrol"
			return
		end

		if is_ranged(self) then
			local dist = dist_to_target(self)
			local speed = self.speed or 4
			local pos = self.object:get_pos()
			local tpos = target:get_pos()

			if dist > hashimon_ai_brain.RANGED_MAX_DIST then
				self._ai_process = "chase"
				return
			end
			if dist < hashimon_ai_brain.RANGED_MIN_DIST then
				local dx = pos.x - tpos.x
				local dz = pos.z - tpos.z
				local horiz = math.sqrt(dx * dx + dz * dz)
				if horiz > 0.01 then
					local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
					if is_flyer(self) then
						self.object:set_velocity({
							x = dx / horiz * speed,
							y = vel.y + 0.5,
							z = dz / horiz * speed,
						})
					else
						self.object:set_velocity({ x = dx / horiz * speed, y = vel.y, z = dz / horiz * speed })
					end
				end
			else
				local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
				self.object:set_velocity({ x = vel.x * 0.85, y = vel.y * 0.85, z = vel.z * 0.85 })
				self._ai_attack_timer = (self._ai_attack_timer or 0) - dtime
				if self._ai_attack_timer <= 0 then
					self._ai_attack_timer = hashimon_ai_brain.ATTACK_INTERVAL
					if hashimon_villain and hashimon_villain.ai_breath_at_target then
						hashimon_villain.ai_breath_at_target(self)
					end
				end
				local yaw_dx = tpos.x - pos.x
				local yaw_dz = tpos.z - pos.z
				self.object:set_yaw(-math.atan2(yaw_dx, yaw_dz))
			end
			return
		end

		local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
		self.object:set_velocity({ x = 0, y = vel.y, z = 0 })
		if target:is_player() then
			target:set_hp((target:get_hp() or 20) - 2)
		end
		return
	end

	if process == "flee" then
		local target = self._chase_target
		if target and target:get_pos() then
			local pos = self.object:get_pos()
			local tpos = target:get_pos()
			local dx = pos.x - tpos.x
			local dy = is_flyer(self) and (pos.y - tpos.y + 2) or 0
			local dz = pos.z - tpos.z
			local len = math.sqrt(dx * dx + dy * dy + dz * dz)
			if len > 0.01 then
				local speed = self.speed or 4
				if is_flyer(self) then
					self.object:set_velocity({ x = dx / len * speed, y = dy / len * speed, z = dz / len * speed })
				else
					local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
					self.object:set_velocity({ x = dx / len * speed, y = vel.y, z = dz / len * speed })
				end
			end
		end
	end
end

function hashimon_ai_brain.force_process(self, process_id)
	if not hashimon_ai_brain.should_think(self) then
		return false
	end
	for _, allowed in ipairs(hashimon_ai_brain.ALLOWED_PROCESSES) do
		if allowed == process_id then
			self._ai_process = process_id
			return true
		end
	end
	return false
end

core.log("action", "[hashimon_ai_brain] AI brain contract loaded (flyer ranged mode)")
