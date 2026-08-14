local modpath = core.get_modpath("hashimon_entities")

dofile(modpath .. "/entities.lua")
dofile(modpath .. "/attack.lua")

if core.get_modpath("animalia") and core.get_modpath("creatura") then
	dofile(modpath .. "/companion.lua")
end

if not hashimon.use_companion then
	core.log("action", "[hashimon_entities] Using sprite fallback (enable Animalia + Creatura for wolf 3D)")
end
