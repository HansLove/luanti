-- Alen Gregory — el villano único de Hashimon.
--
-- Entidad propia sobre la API base de Luanti: sin creatura, sin animalia, sin
-- draconis. Para UN jefe, esos frameworks cobran su abstracción (ciclo de vida de
-- la entidad, acoplamiento hitbox/visual_size) sin dar a cambio lo suyo, que es
-- gestionar poblaciones de mobs.
--
-- Orden de carga: cuerpo → ficha → psique → conocimiento → voz → vuelo → salto
-- → ataques → locomoción → táctica → entidad → canal → chat → comandos. La psique va justo tras la ficha
-- porque todo lo demás la lee; el conocimiento tras la psique porque usa sus
-- rasgos; la voz tras el conocimiento porque saluda según la relación.
-- La entidad va después de la táctica porque la usa; los comandos van al final.

local modpath = core.get_modpath("hashimon_alen")

dofile(modpath .. "/body.lua")
dofile(modpath .. "/state.lua")
dofile(modpath .. "/psyche.lua")
dofile(modpath .. "/knowledge.lua")
dofile(modpath .. "/voice.lua")
dofile(modpath .. "/flight.lua")
dofile(modpath .. "/teleport.lua")
dofile(modpath .. "/attacks.lua")
dofile(modpath .. "/locomotion.lua")
dofile(modpath .. "/brain.lua")
dofile(modpath .. "/entity.lua")
dofile(modpath .. "/orders.lua")
dofile(modpath .. "/chat.lua")
dofile(modpath .. "/commands.lua")

-- La memoria vieja (met/wins/losses) se reforma a relaciones en una sola pasada.
hashimon_alen.migrate_knowledge()

core.log("action", "[hashimon_alen] Alen Gregory cargado — singleton, ficha en mod_storage")
