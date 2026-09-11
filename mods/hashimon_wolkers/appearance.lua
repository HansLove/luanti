-- Apariencia de un wolker. GEMELO EXACTO de `appearanceOf` en api/src/domain/wolkers.ts.
--
-- Las dos implementaciones tienen que dar la misma pieza para el mismo id, siempre: el
-- servidor manda `model` en el padrón, y el mundo lo usa tal cual — pero el mod sabe
-- calcularlo solo para poder envejecer a un niño sin volver a preguntar. Si las dos se
-- separan, un wolker cambiaría de cuerpo al reconectar. `test/golden.lua` compara esta
-- función contra vectores generados por el TypeScript; si tocas una, regenera los otros.

hashimon_wolkers = hashimon_wolkers or {}

hashimon_wolkers.CHILD_DAYS = 30

-- El signo ES el sexo: +1 hombre, −1 mujer. Bit bajo del byte 3 del id — un byte distinto
-- del que dan vigor/oficio/temple, para que sexo y rasgos no queden correlacionados.
function hashimon_wolkers.sign_of(id)
	local byte3 = tonumber(id:sub(7, 8), 16) or 0
	if byte3 % 2 == 0 then
		return 1
	end
	return -1
end

--- Tres piezas de lego cubren toda la población: hombre, mujer, y una cría que lleva su
--- signo pero comparte cuerpo. Crecer es cambiar de modelo, no cargar un asset nuevo.
--- @param age_days número de días desde el nacimiento
function hashimon_wolkers.appearance_of(id, age_days)
	local sign = hashimon_wolkers.sign_of(id)
	local stage = (age_days < hashimon_wolkers.CHILD_DAYS) and "child" or "adult"
	local model
	if stage == "child" then
		model = "wolker_small"
	elseif sign == 1 then
		model = "wolker_pos"
	else
		model = "wolker_neg"
	end
	return { sign = sign, stage = stage, model = model }
end

-- Los cuatro oficios, repartidos en 4×64 sobre el byte `oficio`. GEMELO de `roleOf` en
-- api/src/domain/wolkers.ts: el servidor manda el rol en el padrón, pero el mundo sabe
-- calcularlo para no tener que preguntar otra vez cuando una cría crece.
--
-- El oficio es azar del linaje, no una elección del alcalde: una nación puede tener mala
-- mano y quedarse sin guardias, y entonces necesita inmigración o suerte en la camada.
local ROLES = { "granjero", "constructor", "guardia", "porteador" }

function hashimon_wolkers.role_of(oficio)
	local idx = math.floor((oficio % 256) / 64) + 1
	return ROLES[idx] or "granjero"
end

--- Entidad registrada para un modelo. Un nombre por pieza, sin sufijos por wolker.
function hashimon_wolkers.entity_for(model)
	return "hashimon_wolkers:" .. model
end
