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
	-- All three bat skins are dark and near-flat (sd<0.07, max lum<0.4).
	contrast = { 90, 40 },
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
-- CANINE — Animalia fox (second silhouette in the canine family)
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "canine_fox",
	family = "canine",
	mesh = "animalia_fox.b3d",
	textures = { "animalia_fox_1.png" },
	visual_size_base = 9,
	speed = 4,
	makes_footstep_sound = false,
	hitbox = { width = 0.35, height = 0.5 },
	head_data = {
		offset = { x = 0, y = 0.18, z = 0 },
		pitch_correction = -30,
		pivot_h = 0.4,
		pivot_v = 0.4,
	},
	animations = {
		-- Animalia's fox reuses one clip for walk and run, at different speeds.
		stand = { range = { x = 1, y = 39 }, speed = 10, loop = true },
		walk = { range = { x = 41, y = 59 }, speed = 30, loop = true },
		run = { range = { x = 41, y = 59 }, speed = 45, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- FELINE — Animalia cat (4 high-contrast variants kept of the 9 shipped)
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "feline_cat",
	family = "feline",
	mesh = "animalia_cat.b3d",
	textures = {
		"animalia_cat_2.png", "animalia_cat_5.png",
		"animalia_cat_6.png", "animalia_cat_9.png",
	},
	visual_size_base = 9,
	speed = 4,
	max_fall = 0,
	makes_footstep_sound = false,
	hitbox = { width = 0.2, height = 0.4 },
	head_data = {
		offset = { x = 0, y = 0.14, z = 0 },
		pitch_correction = -25,
		pivot_h = 0.4,
		pivot_v = 0.4,
	},
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 20, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 30, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- URSINE — Animalia grizzly bear (heavy silhouette for Earth/Metal pools)
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "ursine_bear",
	family = "ursine",
	mesh = "animalia_bear.b3d",
	-- Only skin shipped, dark and near-flat (sd 0.038).
	contrast = { 90, 40 },
	textures = { "animalia_bear_grizzly.png" },
	visual_size_base = 10,
	speed = 4,
	max_fall = 3,
	makes_footstep_sound = true,
	hitbox = { width = 0.5, height = 1 },
	head_data = {
		offset = { x = 0, y = 0.35, z = 0 },
		pitch_correction = -45,
		pivot_h = 0.75,
		pivot_v = 1,
	},
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 10, loop = true },
		walk = { range = { x = 61, y = 79 }, speed = 10, loop = true },
		run = { range = { x = 81, y = 99 }, speed = 20, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- EQUINE — Animalia horse. The only registered body large enough to ride;
-- capabilities.mount is metadata only — wiring mount.lua (stage >= 10) to
-- Creatura bodies is separate work, it currently drives voxel bodies.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "equine_horse",
	family = "equine",
	mesh = "animalia_horse.b3d",
	textures = {
		"animalia_horse_1.png",
	},
	visual_size_base = 10,
	speed = 5,
	max_fall = 4,
	stepheight = 1.2,
	makes_footstep_sound = true,
	hitbox = { width = 0.65, height = 1.95 },
	head_data = {
		bone = "Neck.CTRL",
		offset = { x = 0, y = 1.4, z = 0 },
		pitch_correction = 15,
		pivot_h = 1,
		pivot_v = 1.75,
	},
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 10, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 20, loop = true },
		run = { range = { x = 101, y = 119 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

-- ---------------------------------------------------------------------------
-- RODENT — Animalia rat (smallest walking silhouette; "diminutive" builds)
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "rodent_rat",
	family = "rodent",
	mesh = "animalia_rat.b3d",
	textures = { "animalia_rat_1.png", "animalia_rat_2.png" },
	visual_size_base = 7,
	speed = 4,
	makes_footstep_sound = false,
	hitbox = { width = 0.15, height = 0.3 },
	animations = {
		stand = { range = { x = 1, y = 39 }, speed = 20, loop = true },
		walk = { range = { x = 51, y = 69 }, speed = 20, loop = true },
		run = { range = { x = 81, y = 99 }, speed = 45, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- AVIAN — Animalia owl (flight-only clip set: no walk cycle exists)
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "avian_owl",
	family = "avian",
	mesh = "animalia_owl.b3d",
	-- Only skin shipped, low contrast (sd 0.069) though not dark.
	contrast = { 80, 10 },
	textures = { "animalia_owl.png" },
	visual_size_base = 8,
	speed = 4,
	max_fall = 0,
	makes_footstep_sound = false,
	hitbox = { width = 0.15, height = 0.3 },
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 20, loop = true },
		fly = { range = { x = 71, y = 89 }, speed = 30, loop = true },
	},
	capabilities = { walk = false, run = false, fly = true, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- AVIAN — Animalia song bird (walk + fly; 3 species textures)
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "avian_songbird",
	family = "avian",
	mesh = "animalia_bird.b3d",
	textures = {
		"animalia_bluebird.png", "animalia_goldfinch.png",
	},
	visual_size_base = 7,
	speed = 4,
	max_fall = 0,
	makes_footstep_sound = false,
	hitbox = { width = 0.2, height = 0.4 },
	animations = {
		stand = { range = { x = 1, y = 100 }, speed = 30, loop = true },
		walk = { range = { x = 110, y = 130 }, speed = 40, loop = true },
		fly = { range = { x = 140, y = 160 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = false },
})

-- ---------------------------------------------------------------------------
-- AMPHIBIAN — Animalia dart frog. Animalia's frog is a multi-mesh mob; this
-- registry takes one mesh, so the dart frog (3 textures) is used directly.
-- ---------------------------------------------------------------------------
hashimon_bodies.register_creatura_body({
	id = "amphibian_frog",
	family = "amphibian",
	mesh = "animalia_dart_frog.b3d",
	textures = {
		"animalia_dart_frog_2.png", "animalia_dart_frog_3.png",
	},
	visual_size_base = 7,
	speed = 4,
	max_fall = 0,
	makes_footstep_sound = true,
	hitbox = { width = 0.15, height = 0.3 },
	animations = {
		stand = { range = { x = 1, y = 40 }, speed = 10, loop = true },
		walk = { range = { x = 50, y = 80 }, speed = 50, loop = true },
		run = { range = { x = 50, y = 80 }, speed = 60, loop = true },
		swim = { range = { x = 90, y = 110 }, speed = 50, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = false },
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
