-- Hashimon body pack: constructs, humanoids and oddities from the dmobs mod.
--
-- LICENCE FIREWALL. This pack contains no code from the upstream mod: only
-- mesh filenames, animation frame ranges and hitboxes read off its definitions.
-- The assets themselves are CC BY-SA 3.0 (models/textures; its LGPL code is not used) and are NOT copied or redistributed here —
-- dmobs ships its own media, and Luanti resolves media globally across loaded
-- mods, so these names resolve only on a world that already has dmobs.
--
-- With dmobs absent this file registers nothing and the game runs on whatever
-- other packs are installed. See LICENSE.md beside this file.

if not (core.get_modpath("hashimon_bodies") and core.get_modpath("dmobs")) then
	core.log("action", "[hashimon_bodies_dmobs] dmobs or hashimon_bodies absent — no bodies registered")
	return
end

local R = hashimon_bodies.register_creatura_body

R({
	id = "construct_golem",
	family = "construct",
	mesh = "golem.b3d",
	textures = { "dmobs_golem.png", "default_stone.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 2.5 },
	animations = {
		run = { range = { x = 46, y = 66 }, speed = 10, loop = true },
		stand = { range = { x = 1, y = 20 }, speed = 10, loop = true },
		walk = { range = { x = 46, y = 66 }, speed = 10, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "construct_gnorm",
	family = "construct",
	mesh = "gnorm.b3d",
	textures = { "dmobs_gnorm.png", "mobs_blood.png", "default_dirt.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 1.1 },
	animations = {
		run = { range = { x = 62, y = 81 }, speed = 8, loop = true },
		stand = { range = { x = 2, y = 9 }, speed = 8, loop = true },
		walk = { range = { x = 62, y = 81 }, speed = 8, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "humanoid_orc",
	family = "humanoid",
	mesh = "orc.b3d",
	textures = { "dmobs_orc.png", "mobs_blood.png", "default_desert_sand.png" },
	visual_size_base = 3.0,
	hitbox = { width = 0.4, height = 2.3 },
	animations = {
		run = { range = { x = 2, y = 18 }, speed = 10, loop = true },
		stand = { range = { x = 30, y = 40 }, speed = 10, loop = true },
		walk = { range = { x = 2, y = 18 }, speed = 10, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "humanoid_ogre",
	family = "humanoid",
	mesh = "ogre.b3d",
	textures = { "dmobs_ogre.png", "mobs_blood.png", "default_desert_sand.png" },
	visual_size_base = 3.5,
	hitbox = { width = 0.6, height = 2.8 },
	animations = {
		run = { range = { x = 3, y = 38 }, speed = 10, loop = true },
		stand = { range = { x = 40, y = 70 }, speed = 10, loop = true },
		walk = { range = { x = 3, y = 38 }, speed = 10, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "humanoid_skeleton",
	family = "humanoid",
	mesh = "skeleton.b3d",
	textures = { "dmobs_skeleton.png", "default_stone.png", "default_dirt.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 2.5 },
	animations = {
		run = { range = { x = 46, y = 66 }, speed = 15, loop = true },
		stand = { range = { x = 1, y = 20 }, speed = 15, loop = true },
		walk = { range = { x = 46, y = 66 }, speed = 15, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "flora_treeman",
	family = "flora",
	mesh = "treeman.b3d",
	textures = { "dmobs_treeman.png", "dmobs_treeman2.png", "default_tree.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 3.0 },
	animations = {
		run = { range = { x = 46, y = 66 }, speed = 10, loop = true },
		stand = { range = { x = 1, y = 20 }, speed = 10, loop = true },
		walk = { range = { x = 46, y = 66 }, speed = 10, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "chelonian_tortoise",
	family = "chelonian",
	-- Fuera de las líneas Genesis: no tiene animación `stand` (se congela en pose
	-- de bind) y su `run` y `walk` apuntan al mismo rango, así que tampoco
	-- distingue quieta de andando. La cría propia de Bastion la sustituye.
	-- Sigue registrada y alcanzable por nacimiento salvaje.
	natural_only = true,
	mesh = "tortoise.b3d",
	textures = { "dmobs_tortoise.png", "mobs_blood.png", "default_grass.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.2, height = 0.3 },
	animations = {
		run = { range = { x = 23, y = 43 }, speed = 6, loop = true },
		walk = { range = { x = 23, y = 43 }, speed = 6, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "arthropod_wasp",
	family = "arthropod",
	mesh = "wasp.b3d",
	textures = { "dmobs_wasp.png", "mobs_blood.png", "dmobs_wasp_bg.png" },
	visual_size_base = 3.5,
	hitbox = { width = 0.3, height = 2.0 },
	animations = {
		run = { range = { x = 1, y = 5 }, speed = 6, loop = true },
		stand = { range = { x = 1, y = 5 }, speed = 6, loop = true },
		walk = { range = { x = 1, y = 5 }, speed = 6, loop = true },
	},
	capabilities = { walk = true, run = true, fly = true, swim = false, mount = true },
})

R({
	id = "megafauna_elephant",
	family = "megafauna",
	mesh = "elephant.b3d",
	textures = { "dmobs_elephant.png", "mobs_blood.png", "default_dry_grass.png" },
	visual_size_base = 2.5,
	hitbox = { width = 0.9, height = 2.1 },
	animations = {
		run = { range = { x = 3, y = 19 }, speed = 5, loop = true },
		stand = { range = { x = 20, y = 30 }, speed = 5, loop = true },
		walk = { range = { x = 3, y = 19 }, speed = 5, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "aquatic_whale",
	family = "aquatic",
	mesh = "whale.b3d",
	textures = { "dmobs_whale.png", "mobs_blood.png", "default_water.png" },
	visual_size_base = 2.5,
	hitbox = { width = 0.9, height = 2.1 },
	animations = {
		run = { range = { x = 2, y = 39 }, speed = 5, loop = true },
		stand = { range = { x = 2, y = 39 }, speed = 5, loop = true },
		walk = { range = { x = 2, y = 39 }, speed = 5, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
})

R({
	id = "rodent_hedgehog",
	family = "rodent",
	mesh = "hedgehog.b3d",
	textures = { "dmobs_hedgehog.png", "mobs_blood.png", "wool_brown.png" },
	visual_size_base = 2.0,
	hitbox = { width = 0.2, height = 0.3 },
	animations = {
		run = { range = { x = 1, y = 10 }, speed = 5, loop = true },
		stand = { range = { x = 1, y = 10 }, speed = 5, loop = true },
		walk = { range = { x = 1, y = 10 }, speed = 5, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "ursine_panda",
	family = "ursine",
	mesh = "panda.b3d",
	textures = { "dmobs_panda.png", "mobs_blood.png", "default_papyrus.png" },
	visual_size_base = 1.0,
	hitbox = { width = 0.4, height = 1.0 },
	animations = {
		run = { range = { x = 25, y = 45 }, speed = 6, loop = true },
		walk = { range = { x = 25, y = 45 }, speed = 6, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "canine_badger",
	family = "canine",
	mesh = "badger.b3d",
	textures = { "dmobs_badger.png", "mobs_blood.png", "default_obsidian.png" },
	visual_size_base = 2.0,
	hitbox = { width = 0.3, height = 0.55 },
	animations = {
		run = { range = { x = 34, y = 58 }, speed = 12, loop = true },
		stand = { range = { x = 1, y = 30 }, speed = 12, loop = true },
		walk = { range = { x = 34, y = 58 }, speed = 12, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

core.log("action", "[hashimon_bodies_dmobs] registered 13 bodies")
