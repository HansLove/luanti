hashimon_vwar = hashimon_vwar or {}

if not core.get_modpath("mg_villages") or not mg_villages then
	core.log("warning", "[hashimon_village_war] mg_villages not found — mod inactive")
	return
end

local modpath = core.get_modpath("hashimon_village_war")

dofile(modpath .. "/storage.lua")
dofile(modpath .. "/map_sync.lua")
dofile(modpath .. "/protection.lua")
dofile(modpath .. "/commands.lua")

core.register_on_mods_loaded(function()
	hashimon_vwar.load_war_villages()
	local count = 0
	for _ in pairs(hashimon_vwar.war_villages) do
		count = count + 1
	end
	core.log("action", "[hashimon_village_war] Loaded " .. count .. " village(s) at war")
	if hashimon_vwar.sync_war_map_markers then
		hashimon_vwar.sync_war_map_markers()
	end
end)
