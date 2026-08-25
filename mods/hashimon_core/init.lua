hashimon = hashimon or {}

-- Must run in init.lua main chunk (not dofile sub-chunks) or Luanti blocks HTTP.
hashimon.http = core.request_http_api()
if not hashimon.http then
	core.log("error", "[hashimon_core] HTTP API unavailable. Add hashimon_core to secure.http_mods in minetest.conf")
end

dofile(core.get_modpath("hashimon_core") .. "/api.lua")
dofile(core.get_modpath("hashimon_core") .. "/auth_handler.lua")
dofile(core.get_modpath("hashimon_core") .. "/login_form.lua")
dofile(core.get_modpath("hashimon_core") .. "/session.lua")
dofile(core.get_modpath("hashimon_core") .. "/registry.lua")
dofile(core.get_modpath("hashimon_core") .. "/media.lua")
dofile(core.get_modpath("hashimon_core") .. "/dna_compiler.lua")
dofile(core.get_modpath("hashimon_core") .. "/morphology.lua")
