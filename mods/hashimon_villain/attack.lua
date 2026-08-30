-- Possessed combat: profile-driven primary/secondary attacks.

hashimon_villain = hashimon_villain or {}

local MELEE_RANGE = 2.5
local MELEE_DAMAGE = 4
local MELEE_COOLDOWN = 0.8
local BLAST_COOLDOWN = 3

hashimon_villain._melee_cd = hashimon_villain._melee_cd or {}
hashimon_villain._blast_cd = hashimon_villain._blast_cd or {}

local function profile(self)
	return self.monster_profile or hashimon_villain.get_profile(self.body_id)
end

local function can_melee(name)
	local t = hashimon_villain._melee_cd[name]
	return not t or t <= core.get_us_time()
end

local function mark_melee(name)
	hashimon_villain._melee_cd[name] = core.get_us_time() + MELEE_COOLDOWN * 1e6
end

local function can_blast(name)
	local t = hashimon_villain._blast_cd[name]
	return not t or t <= core.get_us_time()
end

local function mark_blast(name)
	hashimon_villain._blast_cd[name] = core.get_us_time() + BLAST_COOLDOWN * 1e6
end

local function nearest_target_in_front(self, rider_obj, range)
	local pos = self.object:get_pos()
	if not pos then
		return nil
	end
	local look = rider_obj:get_look_dir()
	local nearest
	local nearest_dist = range * range
	for _, obj in ipairs(core.get_objects_inside_radius(pos, range)) do
		if obj ~= self.object and obj ~= rider_obj then
			local tpos = obj:get_pos()
			if tpos then
				local dx, dy, dz = tpos.x - pos.x, tpos.y - pos.y, tpos.z - pos.z
				local dist = dx * dx + dy * dy + dz * dz
				if dist < nearest_dist then
					local len = math.sqrt(dist)
					if len > 0.001 then
						local dot = (dx / len) * look.x + (dy / len) * look.y + (dz / len) * look.z
						if dot > 0.3 then
							nearest_dist = dist
							nearest = obj
						end
					end
				end
			end
		end
	end
	return nearest
end

local function do_melee(self, rider_obj)
	local name = rider_obj:get_player_name()
	if not can_melee(name) then
		return
	end
	local target = nearest_target_in_front(self, rider_obj, MELEE_RANGE)
	if not target then
		return
	end
	mark_melee(name)
	if target:is_player() then
		target:set_hp((target:get_hp() or 20) - MELEE_DAMAGE)
	else
		target:punch(self.object, 1.0, {
			full_punch_interval = 1.0,
			damage_groups = { fleshy = MELEE_DAMAGE },
		}, nil)
	end
	core.sound_play("default_punch", { pos = self.object:get_pos(), max_hear_distance = 12 }, true)
end

local function do_breath(self, rider_obj)
	local name = rider_obj:get_player_name()
	local p = profile(self)
	hashimon_villain.launch_breath(
		self.object,
		rider_obj:get_look_dir(),
		name,
		p,
		"villain_breath:" .. name
	)
end

local function do_blast(self, rider_obj)
	if not core.get_modpath("hashimon_entities") then
		return
	end
	local p = profile(self)
	if p.secondary_attack ~= "blast_tnt" then
		return
	end
	local name = rider_obj:get_player_name()
	if not can_blast(name) then
		return
	end
	if not hashimon or not hashimon.launch_blast_from_entity then
		return
	end

	local fake_creature = {
		id = "villain_" .. (self.body_id or "mob"),
		dna = { traits = {} },
		element = "fuego",
	}
	mark_blast(name)
	local ok = hashimon.launch_blast_from_entity(
		self.object,
		rider_obj:get_look_dir(),
		name,
		fake_creature,
		"villain_blast:" .. name
	)
	if not ok then
		hashimon_villain._blast_cd[name] = nil
	end
end

function hashimon_villain.step_possessed_attack(self, rider_obj, control, _dtime)
	if not control.dig then
		return
	end

	local p = profile(self)
	if control.sneak then
		if p.secondary_attack == "blast_tnt" then
			do_blast(self, rider_obj)
		end
		return
	end

	if p.primary_attack == "breath" then
		do_breath(self, rider_obj)
	elseif p.primary_attack == "melee" then
		do_melee(self, rider_obj)
	end
end

--- AI ranged breath toward chase target (never TNT).
function hashimon_villain.ai_breath_at_target(self)
	local target = self._chase_target
	if not target or not target:get_pos() then
		return false
	end
	local pos = self.object:get_pos()
	if not pos then
		return false
	end
	local tpos = target:get_pos()
	local dir = hashimon_villain.dir_toward(pos, tpos)
	local p = profile(self)
	local key = "ai:" .. tostring(self.body_id) .. ":" .. tostring(self.object)
	return hashimon_villain.launch_breath(self.object, dir, nil, p, key)
end
