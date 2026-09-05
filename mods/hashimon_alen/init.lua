-- Alen Gregory — el villano único de Hashimon.
--
-- Entidad propia sobre la API base de Luanti: sin creatura, sin animalia, sin
-- draconis. Para UN jefe, esos frameworks cobran su abstracción (ciclo de vida de
-- la entidad, acoplamiento hitbox/visual_size) sin dar a cambio lo suyo, que es
-- gestionar poblaciones de mobs.
--
-- Orden de carga: cuerpo → ficha → vuelo → salto → táctica → entidad → canal → comandos.
-- La entidad va después de la táctica porque la usa; los comandos van al final.

local modpath = core.get_modpath("hashimon_alen")

dofile(modpath .. "/body.lua")
dofile(modpath .. "/state.lua")
dofile(modpath .. "/flight.lua")
dofile(modpath .. "/teleport.lua")
dofile(modpath .. "/brain.lua")
dofile(modpath .. "/entity.lua")
dofile(modpath .. "/orders.lua")
dofile(modpath .. "/commands.lua")

core.log("action", "[hashimon_alen] Alen Gregory cargado — singleton, ficha en mod_storage")
