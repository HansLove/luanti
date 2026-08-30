if not core.get_modpath("creatura") or not core.get_modpath("animalia") then
	core.log("warning", "[hashimon_villain] Requires creatura + animalia — not loaded")
	return
end

if not animalia or not animalia.mob_ai then
	core.log("warning", "[hashimon_villain] Animalia API not ready")
	return
end

local modpath = core.get_modpath("hashimon_villain")

dofile(modpath .. "/controller.lua")
dofile(modpath .. "/profiles.lua")
dofile(modpath .. "/projectile.lua")
dofile(modpath .. "/patrol.lua")
dofile(modpath .. "/attack.lua")
dofile(modpath .. "/possess.lua")
dofile(modpath .. "/entity.lua")
dofile(modpath .. "/commands.lua")

core.register_on_mods_loaded(function()
	hashimon_villain.register_all_bodies()
	core.log("action", "[hashimon_villain] Villain possession mod loaded")
end)
