-- Hashimon body pack: prehistoric silhouettes from the paleotest mod.
--
-- LICENCE FIREWALL. This pack contains no code from the upstream mod: only
-- mesh filenames, animation frame ranges and hitboxes read off its definitions.
-- The assets themselves are GPL-3.0 and are NOT copied or redistributed here —
-- paleotest ships its own media, and Luanti resolves media globally across loaded
-- mods, so these names resolve only on a world that already has paleotest.
--
-- With paleotest absent this file registers nothing and the game runs on whatever
-- other packs are installed. See LICENSE.md beside this file.

if not (core.get_modpath("hashimon_bodies") and core.get_modpath("paleotest")) then
	core.log("action", "[hashimon_bodies_paleo] paleotest or hashimon_bodies absent — no bodies registered")
	return
end

local R = hashimon_bodies.register_creatura_body

R({
	id = "theropod_velociraptor",
	family = "theropod",
	mesh = "paleotest_velociraptor.b3d",
	textures = { "paleotest_velociraptor_female.png", "paleotest_velociraptor_male.png", "paleotest_velociraptor_child.png" },
	visual_size_base = 4.0,
	hitbox = { width = 0.2, height = 0.5 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "theropod_carnotaurus",
	family = "theropod",
	mesh = "paleotest_carnotaurus.b3d",
	textures = { "paleotest_carnotaurus_female.png", "paleotest_carnotaurus_male.png", "paleotest_carnotaurus_child.png" },
	visual_size_base = 22.0,
	hitbox = { width = 1.1, height = 2.25 },
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 30, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 40, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "theropod_tyrannosaurus",
	family = "theropod",
	mesh = "paleotest_tyrannosaurus.b3d",
	textures = { "paleotest_tyrannosaurus_female.png", "paleotest_tyrannosaurus_male.png", "paleotest_tyrannosaurus_child.png" },
	visual_size_base = 28.0,
	hitbox = { width = 1.3, height = 2.7 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "feline_smilodon",
	family = "feline",
	mesh = "paleotest_smilodon.b3d",
	textures = { "paleotest_smilodon_female.png", "paleotest_smilodon_male.png", "paleotest_smilodon_child.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.5, height = 0.95 },
	animations = {
		walk = { range = { x = 1, y = 40 }, speed = 35, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 45, loop = true },
		stand = { range = { x = 50, y = 89 }, speed = 15, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "feline_thylacoleo",
	family = "feline",
	mesh = "paleotest_thylacoleo.b3d",
	textures = { "paleotest_thylacoleo_female.png", "paleotest_thylacoleo_male.png", "paleotest_thylacoleo_child.png" },
	visual_size_base = 8.0,
	hitbox = { width = 0.3, height = 0.75 },
	animations = {
		walk = { range = { x = 1, y = 40 }, speed = 20, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 25, loop = true },
		stand = { range = { x = 50, y = 90 }, speed = 15, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "canine_direwolf",
	family = "canine",
	mesh = "paleotest_dire_wolf.b3d",
	textures = { "paleotest_dire_wolf_white.png", "paleotest_dire_wolf_black.png" },
	visual_size_base = 8.0,
	hitbox = { width = 0.3, height = 0.9 },
	animations = {
		walk = { range = { x = 1, y = 40 }, speed = 35, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 45, loop = true },
		stand = { range = { x = 50, y = 89 }, speed = 15, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "marsupial_procoptodon",
	family = "marsupial",
	mesh = "paleotest_procoptodon.b3d",
	textures = { "paleotest_procoptodon_female.png", "paleotest_procoptodon_male.png", "paleotest_procoptodon_child.png" },
	visual_size_base = 13.0,
	hitbox = { width = 0.6, height = 1.4 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 40, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 50, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = false },
})

R({
	id = "ceratopsian_triceratops",
	family = "ceratopsian",
	mesh = "paleotest_triceratops.b3d",
	textures = { "paleotest_triceratops_female.png", "paleotest_triceratops_male.png", "paleotest_triceratops_child.png" },
	visual_size_base = 23.0,
	hitbox = { width = 1.2, height = 2.5 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "stegosaur_stegosaurus",
	family = "stegosaur",
	mesh = "paleotest_stegosaurus.b3d",
	textures = { "paleotest_stegosaurus_female.png", "paleotest_stegosaurus_male.png", "paleotest_stegosaurus_child.png" },
	visual_size_base = 19.0,
	hitbox = { width = 1.2, height = 2.5 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "sauropod_brachiosaurus",
	family = "sauropod",
	mesh = "paleotest_brachiosaurus.b3d",
	textures = { "paleotest_brachiosaurus_female.png", "paleotest_brachiosaurus_male.png", "paleotest_brachiosaurus_child.png" },
	visual_size_base = 40.0,
	hitbox = { width = 2.4, height = 5.25 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 90 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 90 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "megafauna_mammoth",
	family = "megafauna",
	mesh = "paleotest_mammoth.b3d",
	textures = { "paleotest_mammoth_female.png", "paleotest_mammoth_male.png", "paleotest_mammoth_child.png" },
	visual_size_base = 22.0,
	hitbox = { width = 1.2, height = 2.6 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "megafauna_elasmotherium",
	family = "megafauna",
	mesh = "paleotest_elasmotherium.b3d",
	textures = { "paleotest_elasmotherium_female.png", "paleotest_elasmotherium_male.png", "paleotest_elasmotherium_child.png" },
	visual_size_base = 22.0,
	hitbox = { width = 1.2, height = 2.6 },
	animations = {
		stand = { range = { x = 1, y = 59 }, speed = 15, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 20, loop = true },
		run = { range = { x = 70, y = 100 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = false, mount = true },
})

R({
	id = "crocodilian_sarcosuchus",
	family = "crocodilian",
	mesh = "paleotest_sarcosuchus.b3d",
	textures = { "paleotest_sarcosuchus_female.png", "paleotest_sarcosuchus_male.png", "paleotest_sarcosuchus_child.png" },
	visual_size_base = 19.0,
	hitbox = { width = 1.1, height = 1.6 },
	animations = {
		walk = { range = { x = 1, y = 40 }, speed = 35, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 45, loop = true },
		stand = { range = { x = 50, y = 110 }, speed = 15, loop = true },
		swim = { range = { x = 150, y = 170 }, speed = 15, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
})

R({
	id = "crocodilian_spinosaurus",
	family = "crocodilian",
	mesh = "paleotest_spinosaurus.b3d",
	textures = { "paleotest_spinosaurus_female.png", "paleotest_spinosaurus_male.png", "paleotest_spinosaurus_child.png" },
	visual_size_base = 32.0,
	hitbox = { width = 1.3, height = 3.1 },
	animations = {
		stand = { range = { x = 80, y = 139 }, speed = 15, loop = true },
		walk = { range = { x = 1, y = 40 }, speed = 25, loop = true },
		run = { range = { x = 50, y = 70 }, speed = 35, loop = true },
		swim = { range = { x = 180, y = 220 }, speed = 30, loop = true },
	},
	capabilities = { walk = true, run = true, fly = false, swim = true, mount = true },
})

R({
	id = "marine_reptile_mosasaurus",
	family = "marine_reptile",
	mesh = "paleotest_mosasaurus.b3d",
	textures = { "paleotest_mosasaurus_female.png", "paleotest_mosasaurus_male.png", "paleotest_mosasaurus_child.png" },
	visual_size_base = 45.0,
	hitbox = { width = 1.8, height = 2.8 },
	animations = {
		swim = { range = { x = 1, y = 40 }, speed = 20, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 25, loop = true },
	},
	capabilities = { walk = false, run = true, fly = false, swim = true, mount = true },
})

R({
	id = "marine_reptile_plesiosaurus",
	family = "marine_reptile",
	mesh = "paleotest_plesiosaurus.b3d",
	textures = { "paleotest_plesiosaurus_female.png", "paleotest_plesiosaurus_male.png" },
	visual_size_base = 10.0,
	hitbox = { width = 0.5, height = 0.8 },
	animations = {
		swim = { range = { x = 1, y = 40 }, speed = 30, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 35, loop = true },
	},
	capabilities = { walk = false, run = true, fly = false, swim = true, mount = false },
})

R({
	id = "marine_reptile_dunkleosteus",
	family = "marine_reptile",
	mesh = "paleotest_dunkleosteus.b3d",
	textures = { "paleotest_dunkleosteus.png", "paleotest_dunkleosteus_fg.png" },
	visual_size_base = 25.0,
	hitbox = { width = 1.15, height = 1.3 },
	animations = {
		swim = { range = { x = 1, y = 40 }, speed = 30, loop = true },
		run = { range = { x = 1, y = 40 }, speed = 35, loop = true },
	},
	capabilities = { walk = false, run = true, fly = false, swim = true, mount = false },
})

R({
	id = "pterosaur_pteranodon",
	family = "pterosaur",
	mesh = "paleotest_pteranodon.b3d",
	textures = { "paleotest_pteranodon_female.png", "paleotest_pteranodon_male.png", "paleotest_pteranodon_child.png" },
	visual_size_base = 11.0,
	hitbox = { width = 0.3, height = 0.8 },
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 10, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 10, loop = true },
		fly = { range = { x = 130, y = 160 }, speed = 25, loop = true },
	},
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = false },
})

R({
	id = "pterosaur_quetzalcoatlus",
	family = "pterosaur",
	mesh = "paleotest_quetzalcoatlus.b3d",
	textures = { "paleotest_quetzalcoatlus_female.png", "paleotest_quetzalcoatlus_male.png", "paleotest_quetzalcoatlus_child.png" },
	visual_size_base = 24.0,
	hitbox = { width = 0.9, height = 2.45 },
	animations = {
		stand = { range = { x = 1, y = 60 }, speed = 10, loop = true },
		walk = { range = { x = 70, y = 100 }, speed = 15, loop = true },
		fly = { range = { x = 180, y = 210 }, speed = 15, loop = true },
	},
	capabilities = { walk = true, run = false, fly = true, swim = false, mount = true },
})

core.log("action", "[hashimon_bodies_paleo] registered 19 bodies")
