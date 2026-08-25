if not core.get_modpath("creatura") or not core.get_modpath("animalia") then
	core.log("warning", "[hashimon_bodies] Requires creatura + animalia — not loaded")
	return
end

if not animalia or not animalia.mob_ai then
	core.log("warning", "[hashimon_bodies] Animalia API not ready")
	return
end

local modpath = core.get_modpath("hashimon_bodies")

dofile(modpath .. "/anim_fsm.lua")
dofile(modpath .. "/attachments.lua")
dofile(modpath .. "/mobs/common.lua")
dofile(modpath .. "/spawn.lua")

-- ---------------------------------------------------------------------------
-- CANINE — Animalia wolf
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "canine_wolf",
	family = "canine",
	mesh = "animalia_wolf.b3d",
	textures = {
		"animalia_wolf_1.png",
		"animalia_wolf_2.png",
		"animalia_wolf_3.png",
		"animalia_wolf_4.png",
	},
	visual_size_base = 10,
	speed = 4,
	makes_footstep_sound = true,
	hitbox = { width = 0.35, height = 0.7 },
	head_data = {
		offset = { x = 0, y = 0.22, z = 0 },
		pitch_correction = -35,
		pivot_h = 0.45,
		pivot_v = 0.45,
	},
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 20, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 30, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- AVIAN — Animalia bat
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "avian_bat",
	family = "avian",
	mesh = "animalia_bat.b3d",
	textures = {
		"animalia_bat_1.png",
		"animalia_bat_2.png",
		"animalia_bat_3.png",
	},
	visual_size_base = 7,
	speed = 4,
	max_fall = 0,
	makes_footstep_sound = false,
	hitbox = { width = 0.15, height = 0.3 },
	animations = {
		stand = { range = { x = 1, y = 40 }, speed = 10, loop = true },
		walk = { range = { x = 51, y = 69 }, speed = 30, loop = true },
		fly = { range = { x = 81, y = 99 }, speed = 80, loop = true },
	},
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- DRAGON — Draconis jungle wyvern (optional mod)
-- ---------------------------------------------------------------------------
if core.get_modpath("draconis") then
	hashimon_bodies.register_creatura_body({
		id = "dragon_wyvern",
		family = "dragon",
		mesh = "draconis_jungle_wyvern.b3d",
		textures = {
			"draconis_jungle_wyvern_amber.png",
			"draconis_jungle_wyvern_aquamarine.png",
			"draconis_jungle_wyvern_jade.png",
			"draconis_jungle_wyvern_ruby.png",
		},
		visual_size_base = 8,
		speed = 5,
		stepheight = 1.51,
		max_fall = 0,
		makes_footstep_sound = true,
		hitbox = { width = 1.5, height = 2 },
		animations = {
			stand = { range = { x = 1, y = 59 }, speed = 20, loop = true },
			walk = { range = { x = 91, y = 119 }, speed = 30, loop = true },
			fly = { range = { x = 181, y = 209 }, speed = 30, loop = true },
			hover = { range = { x = 151, y = 179 }, speed = 30, loop = true },
		},
		capabilities = { walk = true, run = false, fly = true, swim = false, mount = false },
	})
else
	core.log("action", "[hashimon_bodies] draconis not loaded — dragon_wyvern body skipped")
end

core.log("action", "[hashimon_bodies] Registered morphology bodies: "
	.. table.concat(hashimon.list_bodies(), ", "))
