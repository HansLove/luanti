-- POC: controlled impact-flight — launch once, bore a tunnel through voxels
-- (dirt AND stone), boom FX, brake by depth cleared. High yeets (100–200)
-- need look-ahead past one frame of travel or the engine stops you in stone
-- before TNT ever fires.

hashimon = hashimon or {}

-- Tunables (see README)
hashimon.IMPACT_LAUNCH_SPEED = 40
hashimon.IMPACT_MIN_SPEED_FOR_BOOM = 8
hashimon.IMPACT_BRAKE_PER_NODE = 0.92 -- per solid node cleared (gentler than old ×0.55 boom)
hashimon.IMPACT_BRAKE_FLOOR = 0.35 -- never multiply below this in one step
hashimon.IMPACT_BOOM_COOLDOWN = 0.12
hashimon.IMPACT_MAX_FLIGHT_T = 12
hashimon.IMPACT_MAX_RADIUS = 3
hashimon.IMPACT_MAX_TUNNEL = 18 -- nodes along path cleared per step
hashimon.IMPACT_MAX_SPEED = 200

-- Default off: only /hashimon yeet launches. Set true to also yeet on punch.
hashimon.impact_flight_enabled = false
-- In-game bind: sneak + aux1 (Shift + E / Special by default). Mods cannot
-- bind arbitrary keys like P from the server.
hashimon.impact_keybind_enabled = true
hashimon.IMPACT_KEY_COOLDOWN = 2.0

hashimon._impact_flights = hashimon._impact_flights or {}
hashimon._impact_key_held = hashimon._impact_key_held or {}
hashimon._impact_key_cd = hashimon._impact_key_cd or {}
hashimon._has_tnt = hashimon._has_tnt or (core.get_modpath("tnt") ~= nil)

local function clamp(n, lo, hi)
	if n < lo then return lo end
	if n > hi then return hi end
	return n
end

local function vel_len(v)
	if not v then
		return 0
	end
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function normalize(dir)
	local len = vel_len(dir)
	if len < 0.001 then
		return { x = 0, y = 0, z = 1 }
	end
	return { x = dir.x / len, y = dir.y / len, z = dir.z / len }
end

local function is_solid(nodename)
	if not nodename or nodename == "air" or nodename == "ignore"
		or nodename == "vacuum:vacuum" then
		return false
	end
	local def = core.registered_nodes[nodename]
	if not def then
		return true
	end
	-- Liquids don't block a yeet tunnel
	if def.liquidtype and def.liquidtype ~= "none" then
		return false
	end
	return def.walkable ~= false
end

local function can_break(nodename, pname, pos)
	if not is_solid(nodename) then
		return false
	end
	if core.get_item_group(nodename, "immortal") > 0 then
		return false
	end
	if core.is_protected(pos, pname) then
		return false
	end
	return true
end

local function protect_flyer(player, on)
	local name = player:get_player_name()
	local flight = hashimon._impact_flights[name]
	if not flight then
		return
	end
	if on then
		local props = player:get_properties()
		flight._saved_armor = props.armor_groups
		player:set_armor_groups({ immortal = 1, fleshy = 100 })
	elseif flight._saved_armor then
		player:set_armor_groups(flight._saved_armor)
		flight._saved_armor = nil
	else
		player:set_armor_groups({ fleshy = 100 })
	end
end

function hashimon.clear_impact_flight(player)
	if not player or not player.get_player_name then
		return
	end
	local name = player:get_player_name()
	local flight = hashimon._impact_flights[name]
	if flight then
		protect_flyer(player, false)
	end
	hashimon._impact_flights[name] = nil
end

local function emit_burst(pos, r)
	core.add_particlespawner({
		amount = 18 + r * 8,
		time = 0.12,
		minpos = { x = pos.x - r, y = pos.y - r, z = pos.z - r },
		maxpos = { x = pos.x + r, y = pos.y + r, z = pos.z + r },
		minvel = { x = -3, y = 1, z = -3 },
		maxvel = { x = 3, y = 8, z = 3 },
		minexptime = 0.25,
		maxexptime = 0.7,
		minsize = 1.2,
		maxsize = 3.5,
		texture = "default_mese_crystal_fragment.png",
	})
end

--- Dig a sphere. Returns nodes removed. Works on stone (unlike weak TNT feel
--- when radius is tiny / player already clipped into the wall).
local function dig_sphere(center, radius, pname)
	local r = math.max(1, math.floor(radius + 0.5))
	local removed = 0
	local hit_protected = false
	for dx = -r, r do
		for dy = -r, r do
			for dz = -r, r do
				if dx * dx + dy * dy + dz * dz <= r * r + 0.25 then
					local p = {
						x = math.floor(center.x + dx + 0.5),
						y = math.floor(center.y + dy + 0.5),
						z = math.floor(center.z + dz + 0.5),
					}
					local node = core.get_node(p)
					if is_solid(node.name) then
						if core.is_protected(p, pname) then
							hit_protected = true
						elseif can_break(node.name, pname, p) then
							core.remove_node(p)
							removed = removed + 1
						end
					end
				end
			end
		end
	end
	return removed, hit_protected
end

local function fx_boom(pos, radius, pname)
	if core.is_protected(pos, pname) then
		return
	end
	if hashimon._has_tnt and tnt and tnt.boom then
		-- Visual + eject drops; dig_sphere already opened the path so stone is gone.
		tnt.boom(pos, {
			radius = math.max(1, radius),
			damage_radius = 0,
			explode_center = true,
			ignore_protection = false,
		})
	else
		emit_burst(pos, radius)
	end
end

--- Tunnel depth / cross-section from current speed.
local function tunnel_dims(speed)
	-- At 100: depth ~10, radius 2; at 200: depth 18, radius 3
	local depth = clamp(math.floor(speed / 10), 2, hashimon.IMPACT_MAX_TUNNEL)
	local radius = clamp(math.floor(speed / 45) + 1, 1, hashimon.IMPACT_MAX_RADIUS)
	return depth, radius
end

--- Look-ahead must exceed one physics step of travel or we embed in stone.
local function look_ahead_for(speed, dtime)
	return clamp(speed * math.max(dtime, 0.05) * 2.5 + 2, 2, 16)
end

--- Bore along dir from player: clear spheres along the path, optional TNT FX.
--- Returns removed count, whether we hit protection, last dig center.
local function bore_tunnel(from, dir, depth, radius, pname, do_fx)
	local removed = 0
	local protected = false
	local last = from
	for i = 0, depth do
		local center = {
			x = from.x + dir.x * i,
			y = from.y + dir.y * i,
			z = from.z + dir.z * i,
		}
		local n, prot = dig_sphere(center, radius, pname)
		removed = removed + n
		if prot then
			protected = true
			break
		end
		last = center
		if do_fx and n > 0 and i % math.max(2, math.floor(radius + 1)) == 0 then
			fx_boom(center, radius, pname)
		end
	end
	return removed, protected, last
end

--- Launch player in `dir` at `speed` (nodes/s). Enters impact_flight state.
function hashimon.launch_impact(player, dir, speed)
	if not player or not player:is_player() then
		return false
	end
	local name = player:get_player_name()
	dir = normalize(dir or player:get_look_dir())
	speed = tonumber(speed) or hashimon.IMPACT_LAUNCH_SPEED
	speed = clamp(speed, 5, hashimon.IMPACT_MAX_SPEED)

	hashimon.clear_impact_flight(player)

	-- Pre-clear a short corridor so the first frame isn't a faceplant into stone.
	local pos = player:get_pos()
	if pos then
		local from = { x = pos.x, y = pos.y + 0.9, z = pos.z }
		local depth, radius = tunnel_dims(speed)
		bore_tunnel(from, dir, math.min(depth, 4), radius, name, true)
	end

	local impulse = {
		x = dir.x * speed,
		y = dir.y * speed + math.max(2, speed * 0.08),
		z = dir.z * speed,
	}
	player:add_velocity(impulse)

	hashimon._impact_flights[name] = {
		dir = dir,
		speed0 = speed,
		t = 0,
		last_boom = -1,
		residual = speed, -- intended remaining punch-through budget
	}
	protect_flyer(player, true)
	return true
end

local function step_impact_flight(player, name, flight, dtime)
	flight.t = flight.t + dtime
	local max_t = hashimon.IMPACT_MAX_FLIGHT_T + flight.speed0 * 0.02
	if flight.t > max_t then
		hashimon.clear_impact_flight(player)
		return
	end

	local vel = player:get_velocity() or { x = 0, y = 0, z = 0 }
	local speed = vel_len(vel)
	local dir = flight.dir
	if speed > 2 then
		dir = normalize(vel)
		flight.dir = dir
	end

	local pos = player:get_pos()
	if not pos then
		hashimon.clear_impact_flight(player)
		return
	end

	-- Stuck in / against stone: velocity collapsed but we still have budget.
	local stuck = speed < hashimon.IMPACT_MIN_SPEED_FOR_BOOM
		and flight.residual > hashimon.IMPACT_MIN_SPEED_FOR_BOOM
		and flight.t > 0.05

	if speed < hashimon.IMPACT_MIN_SPEED_FOR_BOOM * 0.25
		and flight.residual < hashimon.IMPACT_MIN_SPEED_FOR_BOOM
		and flight.t > 0.35 then
		hashimon.clear_impact_flight(player)
		return
	end

	if speed < hashimon.IMPACT_MIN_SPEED_FOR_BOOM and not stuck then
		return
	end

	local depth, radius = tunnel_dims(math.max(speed, flight.residual))
	-- Always look far enough for this frame's travel + a buffer into the wall.
	local ahead = look_ahead_for(math.max(speed, flight.residual), dtime)
	depth = math.max(depth, math.ceil(ahead))

	local from = {
		x = pos.x + dir.x * 0.4,
		y = pos.y + 0.9 + dir.y * 0.4,
		z = pos.z + dir.z * 0.4,
	}

	local do_fx = (flight.t - flight.last_boom) >= hashimon.IMPACT_BOOM_COOLDOWN
	local removed, protected, last = bore_tunnel(from, dir, depth, radius, name, do_fx)

	if do_fx and removed > 0 then
		flight.last_boom = flight.t
		fx_boom(last, radius, name)
	end

	if protected and removed == 0 then
		player:set_velocity({ x = 0, y = math.min(vel.y, 0), z = 0 })
		hashimon.clear_impact_flight(player)
		return
	end

	if removed > 0 then
		-- Brake by material punched through; keep enough speed to finish the mountain.
		local brake = hashimon.IMPACT_BRAKE_PER_NODE ^ math.min(removed, 12)
		brake = math.max(brake, hashimon.IMPACT_BRAKE_FLOOR)
		flight.residual = math.max(0, flight.residual * brake)

		local keep = math.max(speed * brake, flight.residual * 0.85)
		if stuck then
			-- Re-apply residual punch so we leave the pocket we just dug.
			keep = math.max(keep, flight.residual)
		end
		player:set_velocity({
			x = dir.x * keep,
			y = dir.y * keep * 0.85,
			z = dir.z * keep,
		})
	elseif stuck then
		-- Nothing to dig but we're stopped — empty air pocket; nudge forward.
		player:add_velocity({
			x = dir.x * math.max(8, flight.residual * 0.3),
			y = dir.y * 4,
			z = dir.z * math.max(8, flight.residual * 0.3),
		})
		flight.residual = flight.residual * 0.9
	end

	if flight.residual < hashimon.IMPACT_MIN_SPEED_FOR_BOOM
		and vel_len(player:get_velocity()) < hashimon.IMPACT_MIN_SPEED_FOR_BOOM then
		hashimon.clear_impact_flight(player)
	end
end

core.register_globalstep(function(dtime)
	local now = core.get_us_time() / 1e6

	for name, flight in pairs(hashimon._impact_flights) do
		local player = core.get_player_by_name(name)
		if not player then
			hashimon._impact_flights[name] = nil
		else
			step_impact_flight(player, name, flight, dtime)
		end
	end

	-- Keybind: sneak + aux1 rising edge (Shift + Special/E).
	if not hashimon.impact_keybind_enabled then
		return
	end
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local ctrl = player:get_player_control()
		local combo = ctrl.sneak and ctrl.aux1
		local was = hashimon._impact_key_held[name]
		hashimon._impact_key_held[name] = combo

		if not combo or was then
			-- need rising edge only
		elseif hashimon.mounts and hashimon.mounts[name] then
			-- Mount uses aux1 for mobility — do not yeet while riding.
		elseif hashimon._impact_flights[name] then
			-- Already in flight.
		else
			local last = hashimon._impact_key_cd[name] or 0
			if now - last >= hashimon.IMPACT_KEY_COOLDOWN then
				hashimon._impact_key_cd[name] = now
				hashimon.launch_impact(player, player:get_look_dir(), hashimon.IMPACT_LAUNCH_SPEED)
			end
		end
	end
end)

core.register_on_joinplayer(function(player)
	-- One-shot hint; aux1 label varies by keymap (often E or Special).
	core.after(2, function()
		if not player or not player:get_player_name() then
			return
		end
		if hashimon.impact_keybind_enabled then
			core.chat_send_player(player:get_player_name(),
				"[Hashimon] Impacto: mantén Shift + E (sneak + Special/aux1). Cooldown 2s. /hashimon yeet keyoff para desactivar.")
		end
	end)
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	hashimon.clear_impact_flight(player)
	hashimon._impact_key_held[name] = nil
	hashimon._impact_key_cd[name] = nil
end)

core.register_on_dieplayer(function(player)
	hashimon.clear_impact_flight(player)
end)

core.register_on_punchplayer(function(player, hitter, _time, _tool, dir, damage)
	if not hashimon.impact_flight_enabled then
		return
	end
	if not player or player:get_hp() <= 0 then
		return
	end
	if damage and damage <= 0 then
		return
	end
	local punch_dir = dir
	if hitter and hitter.get_pos and player.get_pos then
		local a = player:get_pos()
		local b = hitter:get_pos()
		if a and b then
			punch_dir = { x = a.x - b.x, y = a.y - b.y + 0.2, z = a.z - b.z }
		end
	end
	local speed = hashimon.IMPACT_LAUNCH_SPEED
	if damage and damage > 0 then
		speed = clamp(hashimon.IMPACT_LAUNCH_SPEED * (0.5 + damage / 20), 15, 120)
	end
	hashimon.launch_impact(player, punch_dir, speed)
end)

function hashimon.impact_yeet_command(name, rest)
	local player = core.get_player_by_name(name)
	if not player then
		return false, "Player not found"
	end
	if not core.check_player_privs(name, { server = true }) then
		return false, "Requires the server privilege."
	end

	local sub = (rest:match("^(%S*)") or ""):lower()
	if sub == "enable" then
		hashimon.impact_flight_enabled = true
		return true, "Impact flight on punch: ON"
	end
	if sub == "disable" then
		hashimon.impact_flight_enabled = false
		return true, "Impact flight on punch: OFF"
	end
	if sub == "keyon" then
		hashimon.impact_keybind_enabled = true
		return true, "Impact keybind ON — Shift+E (sneak+aux1)"
	end
	if sub == "keyoff" then
		hashimon.impact_keybind_enabled = false
		return true, "Impact keybind OFF"
	end
	if sub == "stop" then
		hashimon.clear_impact_flight(player)
		player:set_velocity({ x = 0, y = 0, z = 0 })
		return true, "Impact flight cleared."
	end

	local speed = tonumber(sub)
	if sub == "" then
		speed = hashimon.IMPACT_LAUNCH_SPEED
	end
	if not speed then
		return false, "Usage: /hashimon yeet [speed|enable|disable|keyon|keyoff|stop]"
	end

	local dir = player:get_look_dir()
	hashimon.launch_impact(player, dir, speed)
	local depth, radius = tunnel_dims(clamp(speed, 5, hashimon.IMPACT_MAX_SPEED))
	return true, string.format(
		"Yeet @ %.0f — tunnel depth~%d r=%d (stone+dirt). Aim at a mountain.",
		speed, depth, radius
	)
end

core.log("action", "[hashimon_entities] impact_flight POC loaded (/hashimon yeet)")
