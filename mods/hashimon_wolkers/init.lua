-- hashimon_wolkers — la población nativa de los towns (docs/WOLKERS_V1.md).
--
-- Lo que este mod NO hace, y es lo importante: no crea wolkers, no los mata y no los cuenta.
-- El censo vive en la API. Aquí sólo se les da cuerpo mientras haya alguien mirando, se les
-- deja actuar con una FSM que no cuesta nada, y se reporta lo único que el servidor no puede
-- saber — dónde acabaron y quién cayó peleando.
--
-- MIT — Hashimon, 2026.

hashimon_wolkers = hashimon_wolkers or {}

if not hashimon or not hashimon.fetch_wolkers then
	core.log("warning", "[hashimon_wolkers] hashimon_core (fetch_wolkers) no encontrado — mod inactivo.")
	return
end

local path = core.get_modpath("hashimon_wolkers")
dofile(path .. "/appearance.lua")
dofile(path .. "/entity.lua")
dofile(path .. "/brain.lua")
dofile(path .. "/sync.lua")
dofile(path .. "/commands.lua")

core.log("action", "[hashimon_wolkers] listo — 3 cuerpos, FSM local, consejo del servidor.")
