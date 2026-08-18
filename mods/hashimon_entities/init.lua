local modpath = core.get_modpath("hashimon_entities")

dofile(modpath .. "/entities.lua")
dofile(modpath .. "/mount.lua")
dofile(modpath .. "/voxel_body.lua")
dofile(modpath .. "/attack.lua")

if core.get_modpath("animalia") and core.get_modpath("creatura") then
	dofile(modpath .. "/companion.lua")
end

-- Roster creatures render via their own tier chain (custom GLB > procedural
-- voxel body > sprite), never the generic wolf companion — see
-- spawn_creature_entity() in entities.lua. companion.lua stays registered
-- (harmless if Animalia+Creatura are present) but is no longer auto-spawned.
core.log("action", "[hashimon_entities] Roster render chain: media > voxel body > sprite")
