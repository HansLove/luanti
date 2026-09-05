-- Animation state machine: idle / walk / run / swim / fly from velocity.
--
-- Fly mounts often hover nearly still (gravity 0). Without treating `_mount_fly`
-- as "in flight", the FSM falls through to stand/idle and the wings freeze in
-- a grounded pose. `fly` is the hover/standby clip until a dedicated one exists.
--
-- Use Creatura `:animate` when available so `_anim` stays in sync (object-level
-- set_animation alone lets Creatura think it's still on "stand" and fight us).
-- Boost/rocket/dive changes are debounced so brief input edges don't restart
-- the clip every tick (the visible "tic").

hashimon_bodies = hashimon_bodies or {}

local FLY_HOLD = 0.18 -- seconds before leaving a special fly clip for base fly

-- Mismo criterio que hashimon_entities/mount.lua (líquido real + marea efímera).
local function node_is_liquid(pos)
	local node = core.get_node(pos)
	if node.name == "hashimon_entities:tide_wake" then
		return true
	end
	local def = core.registered_nodes[node.name]
	return def and def.liquidtype and def.liquidtype ~= "none"
end

local function play_anim(self, anim_name, anims)
	local spec = anims[anim_name] or anims.stand
	if not spec then
		return
	end
	-- Prefer Creatura's animate: it no-ops when the same clip is already playing.
	if self.animate then
		self:animate(anim_name)
		return
	end
	local range = spec.range or { x = 1, y = 60 }
	local speed = spec.speed or 20
	local loop = spec.loop ~= false
	local blend = (type(spec.frame_blend) == "number" and spec.frame_blend) or 0
	if self.set_animation then
		self:set_animation(range, speed, loop)
	else
		self.object:set_animation(range, speed, blend, loop)
	end
end

function hashimon_bodies.update_anim_fsm(self, body_def)
	if not self.object or not body_def or not body_def.animations then
		return
	end
	local vel = self.object:get_velocity()
	local horiz = math.sqrt(vel.x * vel.x + vel.z * vel.z)
	local caps = body_def.capabilities or {}
	local anims = body_def.animations
	local want = "stand"

	-- El nado va PRIMERO: un delfín en el agua no debe caer en la rama de
	-- caminar. Once cuerpos acuáticos declaraban `swim = {...}` desde el
	-- principio y esta función nunca lo consultaba, así que todo el linaje
	-- Depth se movía bajo el agua con su ciclo de caminar.
	if caps.swim and anims.swim and node_is_liquid(self.object:get_pos()) then
		-- Hyper-nado (Sprint/aux1): swim_boost si el cuerpo lo declara.
		if self._water_hyper and anims.swim_boost then
			want = "swim_boost"
		else
			want = "swim"
		end
	elseif caps.fly and anims.fly and (
		self._mount_fly
		or horiz > 1.5
		or (vel.y and math.abs(vel.y) > 0.8)
	) then
		-- Mounted air: always in the fly family (hover = fly). Special clips
		-- override; hold them briefly so aux1/jump edges don't tic-restart.
		if self._skyrocket_active and anims.fly_rocket then
			want = "fly_rocket"
		elseif self._dive_active and anims.fly_dive then
			want = "fly_dive"
		elseif (self._skyrocket_active or self._dive_active or self._mount_fly_boost)
			and anims.fly_boost then
			want = "fly_boost"
		else
			want = "fly"
		end
	elseif self._mount_run_boost
		and anims.run_boost then
		want = "run_boost"
	elseif self._mount_run_boost
		and anims.run then
		want = "run"
	elseif horiz > (caps.run and 5 or 99) and anims.run then
		want = "run"
	elseif horiz > 0.35 and anims.walk then
		want = "walk"
	else
		want = "stand"
	end

	-- Debounce leaving special fly clips → base fly (not the reverse).
	local cur = self._hashimon_anim
	if want == "fly"
		and (cur == "fly_boost" or cur == "fly_rocket" or cur == "fly_dive")
	then
		local hold = self._anim_fly_hold or 0
		hold = hold + (self.dtime or 0.05)
		self._anim_fly_hold = hold
		if hold < FLY_HOLD then
			want = cur
		else
			self._anim_fly_hold = 0
		end
	elseif want == "fly_boost" or want == "fly_rocket" or want == "fly_dive" then
		self._anim_fly_hold = 0
	end

	if cur == want then
		return
	end
	self._hashimon_anim = want
	play_anim(self, want, anims)
end
