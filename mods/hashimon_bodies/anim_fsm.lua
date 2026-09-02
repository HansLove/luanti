-- Animation state machine: idle / walk / run / swim / fly from velocity.

hashimon_bodies = hashimon_bodies or {}

-- Mismo criterio que hashimon_entities/mount.lua::node_is_liquid, para que
-- montar y animar coincidan en qué cuenta como "en el agua".
local function node_is_liquid(pos)
	local node = core.get_node(pos)
	local def = core.registered_nodes[node.name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end

function hashimon_bodies.update_anim_fsm(self, body_def)
	if not self.object or not body_def or not body_def.animations then
		return
	end
	local vel = self.object:get_velocity()
	local horiz = math.sqrt(vel.x * vel.x + vel.z * vel.z)
	local caps = body_def.capabilities or {}
	local anim_name = "stand"

	-- El nado va PRIMERO: un delfín en el agua no debe caer en la rama de
	-- caminar. Once cuerpos acuáticos declaraban `swim = {...}` desde el
	-- principio y esta función nunca lo consultaba, así que todo el linaje
	-- Depth se movía bajo el agua con su ciclo de caminar.
	if caps.swim and body_def.animations.swim and node_is_liquid(self.object:get_pos()) then
		anim_name = "swim"
	elseif caps.fly and (horiz > 1.5 or (vel.y and math.abs(vel.y) > 0.8)) then
		if self._mount_fly_boost and body_def.animations.fly_boost then
			anim_name = "fly_boost"
		else
			anim_name = body_def.animations.fly and "fly"
				or (body_def.animations.hover and "hover" or "walk")
		end
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
