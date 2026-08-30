-- Monster profiles: archetype, attacks, spawn height, camera, flight.

hashimon_villain = hashimon_villain or {}

hashimon_villain.PROFILES = {
	dragon_wyvern = {
		archetype = "flyer",
		display = "Dragón del Cielo",
		spawn_offset_y = 6,
		primary_attack = "breath",
		secondary_attack = "blast_tnt",
		ai_prefer_ranged = true,
		breath_tint = "#F97316",
		size_mult = 0.55,
		seat = { x = 0, y = 4.5, z = 5.5 },
		eye_first = { x = 0, y = 1, z = 2 },
		eye_third = { x = 0, y = 5, z = -12 },
		fly_speed = 10,
		fly_boost = 2.0,
		breath_spawn = { forward = 2.5, up = 1.5 },
	},
	dragon_fire = {
		archetype = "flyer",
		display = "Dragón de Fuego",
		spawn_offset_y = 8,
		primary_attack = "breath",
		secondary_attack = "blast_tnt",
		ai_prefer_ranged = true,
		breath_tint = "#EF4444",
		size_mult = 0.4,
		seat = { x = 0, y = 6, z = 7 },
		eye_first = { x = 0, y = 1.5, z = 2 },
		eye_third = { x = 0, y = 7, z = -14 },
		fly_speed = 9,
		fly_boost = 2.0,
		breath_spawn = { forward = 3.0, up = 2.0 },
	},
	dragon_ice = {
		archetype = "flyer",
		display = "Dragón de Hielo",
		spawn_offset_y = 8,
		primary_attack = "breath",
		secondary_attack = "blast_tnt",
		ai_prefer_ranged = true,
		breath_tint = "#38BDF8",
		size_mult = 0.4,
		seat = { x = 0, y = 6, z = 7 },
		eye_first = { x = 0, y = 1.5, z = 2 },
		eye_third = { x = 0, y = 7, z = -14 },
		fly_speed = 9,
		fly_boost = 2.0,
		breath_spawn = { forward = 3.0, up = 2.0 },
	},
	avian_bat = {
		archetype = "flyer",
		display = "Murciélago Gigante",
		spawn_offset_y = 4,
		primary_attack = "breath",
		secondary_attack = "none",
		ai_prefer_ranged = true,
		breath_tint = "#A855F7",
		size_mult = 1.0,
		seat = { x = 0, y = 0.8, z = 1.2 },
		eye_first = { x = 0, y = 0.5, z = 0.5 },
		eye_third = { x = 0, y = 2, z = -5 },
		fly_speed = 10,
		fly_boost = 2.0,
		breath_spawn = { forward = 1.2, up = 0.5 },
	},
	humanoid_orc = {
		archetype = "ground",
		display = "Orco del Bosque",
		spawn_offset_y = 0,
		primary_attack = "melee",
		secondary_attack = "blast_tnt",
		ai_prefer_ranged = false,
		size_mult = 1.0,
		seat = { x = 0, y = 1.2, z = 0 },
		eye_first = { x = 0, y = 1.5, z = 0 },
		eye_third = { x = 0, y = 2.5, z = -4 },
	},
	construct_golem = {
		archetype = "ground",
		display = "Golem de Piedra",
		spawn_offset_y = 0,
		primary_attack = "melee",
		secondary_attack = "blast_tnt",
		ai_prefer_ranged = false,
		size_mult = 1.0,
		seat = { x = 0, y = 1.8, z = 0 },
		eye_first = { x = 0, y = 1.5, z = 0 },
		eye_third = { x = 0, y = 2.5, z = -4 },
	},
}

hashimon_villain.DEFAULT_BODY_CANDIDATES = { "dragon_wyvern", "avian_bat" }

local GROUND_DEFAULT = {
	archetype = "ground",
	display = nil,
	spawn_offset_y = 0,
	primary_attack = "melee",
	secondary_attack = "none",
	ai_prefer_ranged = false,
	breath_tint = "#F97316",
	size_mult = 1.0,
	seat = { x = 0, y = 1.0, z = 0 },
	eye_first = { x = 0, y = 1.5, z = 0 },
	eye_third = { x = 0, y = 2.5, z = -4 },
}

local FLYER_DEFAULT = {
	archetype = "flyer",
	display = nil,
	spawn_offset_y = 4,
	primary_attack = "breath",
	secondary_attack = "none",
	ai_prefer_ranged = true,
	breath_tint = "#F97316",
	size_mult = 1.0,
	seat = { x = 0, y = 1.5, z = 2 },
	eye_first = { x = 0, y = 1, z = 1 },
	eye_third = { x = 0, y = 3, z = -6 },
	fly_speed = 10,
	fly_boost = 2.0,
	breath_spawn = { forward = 1.5, up = 0.8 },
}

function hashimon_villain.get_profile(body_id)
	local p = hashimon_villain.PROFILES[body_id]
	if p then
		return p
	end
	local body_def = hashimon.get_body and hashimon.get_body(body_id)
	local caps = body_def and body_def.capabilities or {}
	local base = caps.fly and FLYER_DEFAULT or GROUND_DEFAULT
	local copy = {}
	for k, v in pairs(base) do
		copy[k] = v
	end
	copy.display = "Villano " .. body_id
	return copy
end

function hashimon_villain.display_name(body_id)
	local p = hashimon_villain.get_profile(body_id)
	return (p and p.display) or ("Villano " .. body_id)
end

function hashimon_villain.is_flyer_profile(profile)
	return profile and profile.archetype == "flyer"
end

function hashimon_villain.default_body_id()
	for _, body_id in ipairs(hashimon_villain.DEFAULT_BODY_CANDIDATES) do
		if hashimon.get_body(body_id) then
			local entity_name = "hashimon_villain:" .. body_id
			if core.registered_entities[entity_name] then
				return body_id
			end
		end
	end
	for _, body_id in ipairs(hashimon_villain.DEFAULT_BODY_CANDIDATES) do
		if hashimon.get_body(body_id) then
			return body_id
		end
	end
	return nil
end

function hashimon_villain.spawn_pos_for(body_id, base_pos)
	local profile = hashimon_villain.get_profile(body_id)
	return {
		x = base_pos.x,
		y = base_pos.y + (profile.spawn_offset_y or 0),
		z = base_pos.z,
	}
end

function hashimon_villain.possess_controls_hint(body_id)
	local profile = hashimon_villain.get_profile(body_id)
	if hashimon_villain.is_flyer_profile(profile) then
		local extra = ""
		if profile.secondary_attack == "blast_tnt" then
			extra = ", shift+click=explosión TNT"
		end
		return "WASD mover, espacio=subir, agacharse=bajar, sprint=vuelo rápido, click=aliento"
			.. extra
			.. " — usa F7 para 3ª persona. /hv release soltar"
	end
	return "WASD mover, espacio=saltar, click=melee, shift+click=blast, /hv release soltar"
end
