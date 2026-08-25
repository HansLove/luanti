local modpath = core.get_modpath("hashimon_entities")

dofile(modpath .. "/entities.lua")
dofile(modpath .. "/mount.lua")
dofile(modpath .. "/voxel_body.lua")
dofile(modpath .. "/attack.lua")

if core.get_modpath("animalia") and core.get_modpath("creatura") then
	dofile(modpath .. "/companion.lua")
end

-- Roster creatures render via tier chain: premium GLB > morphology > voxel > sprite.
-- See spawn_creature_entity() in entities.lua.
core.log("action", "[hashimon_entities] Roster render chain: premium GLB > morphology > voxel > sprite")
