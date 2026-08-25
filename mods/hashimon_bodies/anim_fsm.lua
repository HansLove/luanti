-- Animation state machine: idle / walk / run / fly from horizontal velocity.

hashimon_bodies = hashimon_bodies or {}

function hashimon_bodies.update_anim_fsm(self, body_def)
	if not self.object or not body_def or not body_def.animations then
		return
	end
	local vel = self.object:get_velocity()
	local horiz = math.sqrt(vel.x * vel.x + vel.z * vel.z)
	local caps = body_def.capabilities or {}
	local anim_name = "stand"

	if caps.fly and (horiz > 1.5 or (vel.y and math.abs(vel.y) > 0.8)) then
		anim_name = body_def.animations.fly and "fly"
			or (body_def.animations.hover and "hover" or "walk")
	elseif horiz > (caps.run and 5 or 99) and body_def.animations.run then
		anim_name = "run"
	elseif horiz > 0.35 and body_def.animations.walk then
		anim_name = "walk"
	else
		anim_name = "stand"
	end

	if self._hashimon_anim == anim_name then
		return
	end
	self._hashimon_anim = anim_name

	local spec = body_def.animations[anim_name] or body_def.animations.stand
	if not spec then
		return
	end
	local range = spec.range or { x = 1, y = 60 }
	local speed = spec.speed or 20
	local loop = spec.loop ~= false
	if self.set_animation then
		self:set_animation(range, speed, loop)
	else
		self.object:set_animation(range, speed, loop and 0 or 1, loop)
	end
end
