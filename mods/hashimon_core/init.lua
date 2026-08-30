hashimon = hashimon or {}

-- Must run in init.lua main chunk (not dofile sub-chunks) or Luanti blocks HTTP.
-- Kept in a local: lua_api.md forbids storing the HTTP table in a global.
local http = core.request_http_api()
if not http then
	core.log("error", "[hashimon_core] HTTP API unavailable. Add hashimon_core to secure.http_mods in minetest.conf")
end

dofile(core.get_modpath("hashimon_core") .. "/api.lua")
hashimon.set_http(http)
hashimon.set_http = nil
dofile(core.get_modpath("hashimon_core") .. "/auth_handler.lua")
dofile(core.get_modpath("hashimon_core") .. "/login_form.lua")
dofile(core.get_modpath("hashimon_core") .. "/session.lua")
dofile(core.get_modpath("hashimon_core") .. "/registry.lua")
dofile(core.get_modpath("hashimon_core") .. "/media.lua")
dofile(core.get_modpath("hashimon_core") .. "/birth_identity.lua")
dofile(core.get_modpath("hashimon_core") .. "/dna_compiler.lua")
dofile(core.get_modpath("hashimon_core") .. "/morphology.lua")
