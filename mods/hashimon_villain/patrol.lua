-- Minimal patrol / idle when AI brain is absent or in idle mode.

hashimon_villain = hashimon_villain or {}

local PATROL_RADIUS = 12

function hashimon_villain.step_patrol_stub(self, dtime)
	if hashimon_villain.is_human_controlled(self) then
		return
	end

	self._patrol_timer = (self._patrol_timer or 0) - dtime
	if self._patrol_timer > 0 then
		hashimon_villain._move_toward_patrol_target(self)
		return
	end

	self._patrol_timer = math.random(4, 10)
	local anchor = self.patrol_anchor or self.object:get_pos()
	if not anchor then
		return
	end

	local angle = math.random() * math.pi * 2
	local dist = math.random() * PATROL_RADIUS
	self._patrol_target = {
		x = anchor.x + math.cos(angle) * dist,
		y = anchor.y,
		z = anchor.z + math.sin(angle) * dist,
	}
end

function hashimon_villain._move_toward_patrol_target(self)
	local target = self._patrol_target
	if not target then
		return
	end
	local pos = self.object:get_pos()
	if not pos then
		return
	end

	local dx = target.x - pos.x
	local dz = target.z - pos.z
	local horiz = math.sqrt(dx * dx + dz * dz)
	if horiz < 1.0 then
		self._patrol_target = nil
		self.object:set_velocity({ x = 0, y = (self.object:get_velocity() or {}).y or 0, z = 0 })
		return
	end

	local speed = self.speed or 3
	local nx, nz = dx / horiz * speed, dz / horiz * speed
	local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
	self.object:set_velocity({ x = nx, y = vel.y, z = nz })
	self.object:set_yaw(-math.atan2(dx, dz))
end
