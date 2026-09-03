-- Additional MIT-licensed bodies (Animalia, Draconis, marinaramobs).
-- Generated from those mods' own definitions; see ../LICENSE-ASSETS.md.

local R = hashimon_bodies.register_creatura_body

R({
	id = "livestock_cow",
	bones = {
		head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	family = "livestock",
	mesh = "animalia_cow.b3d",
	textures = { "animalia_cow_1.png", "animalia_cow_2.png", "animalia_cow_3.png", "animalia_cow_4.png", "animalia_cow_5.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.5, height = 1.0 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 10, loop = true },
		walk = { range = { x = 71, y = 89 }, speed = 15, loop = true },
		run = { range = { x = 71, y = 89 }, speed = 30, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "livestock_pig",
	bones = {
		head = "Head", torso = "Torso", arm_l = "Arm.L",
		arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	family = "livestock",
	mesh = "animalia_pig.b3d",
	textures = { "animalia_pig_1.png", "animalia_pig_2.png", "animalia_pig_3.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.35, height = 0.7 },
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 20, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 30, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "livestock_sheep",
	bones = {
		head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	family = "livestock",
	mesh = "animalia_sheep.b3d",
	textures = { "animalia_sheep.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.4, height = 0.8 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 10, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 20, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 30, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "cervid_reindeer",
	bones = {
		head = "Head", neck = "Neck", torso = "Torso",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	family = "cervid",
	-- Grafo V1 §6: Natural (salvo B alt futuro). Fuera de Genesis Road — si no,
	-- a ~11★ el progreso cae en alce/venado en vez de road_adult.
	natural_only = true,
	mesh = "animalia_reindeer.b3d",
	textures = { "animalia_reindeer.png", "animalia_reindeer_calf.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.45, height = 0.9 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 10, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 30, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "avian_chicken",
	bones = {
		head = "Head", torso = "Torso", tail = "Tail",
		leg_l = "Leg.L", leg_r = "Leg.R", wing_l = "Wing.L", wing_r = "Wing.R" },
	family = "avian",
	-- Grafo V1 §6: sale a Natural — no escalón Genesis (evita pollo a 11★ Beacon).
	natural_only = true,
	mesh = "animalia_chicken.b3d",
	textures = { "animalia_chicken_1.png", "animalia_chicken_2.png", "animalia_chicken_3.png", "animalia_rooster_1.png", "animalia_rooster_2.png", "animalia_rooster_3.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.25, height = 0.5 },
	animations = {
		stand = { range = { x = 1, y = 39 }, speed = 20, loop = true },
		walk = { range = { x = 41, y = 59 }, speed = 30, loop = true },
		run = { range = { x = 41, y = 59 }, speed = 45, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "avian_turkey",
	bones = { head = "Head", neck = "Neck", torso = "Torso" },
	family = "avian",
	-- Grafo V1 §6: sale a Natural — no escalón Genesis.
	natural_only = true,
	mesh = "animalia_turkey.b3d",
	textures = { "animalia_turkey_hen.png", "animalia_turkey_tom.png", "animalia_turkey_chick.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.3, height = 0.6 },
	animations = {
		stand = { range = { x = 0, y = 0 }, speed = 1, loop = true },
		walk = { range = { x = 10, y = 30 }, speed = 30, loop = true },
		run = { range = { x = 40, y = 60 }, speed = 45, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "rodent_opossum",
	bones = {
		head = "Head", torso = "Torso", tail = "Tail",
		arm_l = "Arm.L", arm_r = "Arm.R", leg_l = "Leg.L", leg_r = "Leg.R" },
	family = "rodent",
	mesh = "animalia_opossum.b3d",
	textures = { "animalia_opossum.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.25, height = 0.4 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 10, loop = true },
		walk = { range = { x = 70, y = 89 }, speed = 30, loop = true },
		run = { range = { x = 100, y = 119 }, speed = 45, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "aquatic_dolphin",
	family = "aquatic",
	mesh = "Dolphin.b3d",
	textures = { "texturedolphin.png", "adolphin.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 0.51 },
	animations = {
		stand = { range = { x = 0, y = 100 }, speed = 50, loop = true },
		swim = { range = { x = 200, y = 300 }, speed = 50, loop = true },
	},
	capabilities = { walk = false, run = false, fly = false, swim = true, mount = false },
})

R({
	id = "aquatic_octopus",
	family = "aquatic",
	mesh = "Octopus.b3d",
	textures = { "textureoctopus.png", "aoctopus.png", "marinaramobs_octopusink.png", "marinaramobs_octopus_raw.png", "marinaramobs_octopus_cooked.png" },
	visual_size_base = 0.5,
	hitbox = { width = 0.5, height = 0.96 },
	animations = {
		stand = { range = { x = 0, y = 100 }, speed = 50, loop = true },
		swim = { range = { x = 100, y = 200 }, speed = 50, loop = true },
	},
	capabilities = { walk = false, run = false, fly = false, swim = true, mount = false },
})

R({
	id = "aquatic_jellyfish",
	family = "aquatic",
	mesh = "Jellyfish.b3d",
	textures = { "texturejellyfish.png", "ajellyfish.png" },
	visual_size_base = 4.0,
	hitbox = { width = 0.3, height = 0.96 },
	animations = {
		stand = { range = { x = 0, y = 100 }, speed = 25, loop = true },
		swim = { range = { x = 100, y = 200 }, speed = 25, loop = true },
	},
	capabilities = { walk = false, run = false, fly = false, swim = true, mount = false },
})

R({
	id = "aquatic_parrotfish",
	family = "aquatic",
	mesh = "Parrotfish.b3d",
	textures = { "textureparrotfish.png", "aparrotfish.png", "marinaramobs_exotic_fish_raw.png", "marinaramobs_exotic_fish_cooked.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 0.51 },
	animations = {
		stand = { range = { x = 0, y = 100 }, speed = 100, loop = true },
		swim = { range = { x = 200, y = 300 }, speed = 100, loop = true },
	},
	capabilities = { walk = false, run = false, fly = false, swim = true, mount = false },
})

R({
	id = "aquatic_nautilus",
	family = "aquatic",
	mesh = "Nautilus.b3d",
	textures = { "texturenautilus.png", "anautilus.png", "marinaramobs_nautilusshell.png" },
	visual_size_base = 2.0,
	hitbox = { width = 0.2, height = 0.51 },
	animations = {
		stand = { range = { x = 0, y = 100 }, speed = 50, loop = true },
		swim = { range = { x = 100, y = 200 }, speed = 50, loop = true },
	},
	capabilities = { walk = false, run = false, fly = false, swim = true, mount = false },
})

R({
	id = "dragon_fire",
	family = "dragon",
	mesh = "draconis_fire_dragon.b3d",
	textures = { "unknown.png" },
	visual_size_base = 20.0,
	hitbox = { width = 2.5, height = 5.0 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 20, loop = true },
		walk = { range = { x = 211, y = 249 }, speed = 40, loop = true },
		hover = { range = { x = 321, y = 359 }, speed = 30, loop = true },
		fly = { range = { x = 401, y = 439 }, speed = 30, loop = true },
	},
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	mount_view = {
		bone = "Torso",
		seat = { x = 0, y = 0, z = 3 },
		rot = { x = 0, y = 0, z = 0 },
		eye_first = { x = 0, y = 12, z = 5 },
		eye_third = { x = 0, y = 15, z = -10 },
		hide_rider = true,
	},
})

R({
	id = "dragon_ice",
	family = "dragon",
	mesh = "draconis_ice_dragon.b3d",
	textures = { "unknown.png" },
	visual_size_base = 20.0,
	hitbox = { width = 2.5, height = 5.0 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 20, loop = true },
		walk = { range = { x = 211, y = 249 }, speed = 40, loop = true },
		hover = { range = { x = 321, y = 359 }, speed = 30, loop = true },
		fly = { range = { x = 401, y = 439 }, speed = 30, loop = true },
	},
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
	mount_view = {
		bone = "Torso",
		seat = { x = 0, y = 0, z = 3 },
		rot = { x = 0, y = 0, z = 0 },
		eye_first = { x = 0, y = 12, z = 5 },
		eye_third = { x = 0, y = 15, z = -10 },
		hide_rider = true,
	},
})

core.log("action", "[hashimon_bodies] +14 extra MIT bodies")
