-- El vector psicológico de Alen: fisiología, emoción y personalidad.
--
-- Dos reglas gobiernan este fichero y explican casi todas sus decisiones:
--
-- 1. NO SE GUARDA LO QUE SE PUEDE DERIVAR. Un `sleep_desire` almacenado puede
--    acabar contradiciendo a `fatigue`, y un Alen con fatiga 90 y sueño 5 es un
--    bug que nadie detecta nunca. Es la misma ley que gobierna a los Hashimons:
--    stats y rango se derivan del ADN, no se almacenan, para que no puedan
--    divergir. Aquí sólo viven ocho campos; el resto son funciones.
--
-- 2. NADA DE ESTO ES UN RELOJ NUEVO. Los decaimientos corren en el tick táctico
--    de 1 Hz que ya existía, y el tiempo sin observadores se resuelve con
--    aritmética una sola vez, en catch_up(). Cero observadores sigue siendo
--    cero CPU.

hashimon_alen = hashimon_alen or {}

-- --------------------------------------------------------------------------
-- Constantes. Las vidas medias están en segundos y se multiplican por
-- `patience`, así que un Alen impaciente se calma antes.
-- --------------------------------------------------------------------------

-- Aguante, revisado tras la segunda partida: "se cansa luego luego... debería ser
-- 10 veces con más resistencia". El depósito es 2.5× más grande y se llena igual de
-- rápido (el ciclo completo sigue siendo ~60 s), así que puede sostener una pelea
-- larga sin quedarse seco a la tercera.
hashimon_alen.MAX_ENERGY = 250
hashimon_alen.ENERGY_REGEN = 4.2          -- /s → ciclo completo en ~60 s
hashimon_alen.ENERGY_REGEN_COMBAT = 0.35  -- no se recarga peleando

-- La ira dura SIETE MINUTOS, no noventa segundos. Desde el punto de vista de Alen,
-- que un ser inferior lo haya tocado no es un incidente que se olvida mientras
-- todavía lo tiene delante.
hashimon_alen.ANGER_HALF_LIFE = 420
hashimon_alen.GRUDGE_HALF_LIFE = 43200    -- 12 h: el rencor sobrevive a la noche
hashimon_alen.GRUDGE_FLOOR_AT = 35        -- la cicatriz se hace ANTES...
hashimon_alen.GRUDGE_FLOOR = 30           -- ...y deja más marca

-- Fatiga diez veces más lenta. Antes se agotaba en cinco minutos de vuelo y se iba
-- a dormir; ahora aguanta una sesión entera.
hashimon_alen.FATIGUE_HALF_LIFE_AWAKE = 1800
hashimon_alen.FATIGUE_HALF_LIFE_ASLEEP = 600
hashimon_alen.FATIGUE_PER_S_FLYING = 0.035
hashimon_alen.FATIGUE_PER_S_GROUND = 0.008

hashimon_alen.BOREDOM_PER_S = 0.25        -- sólo con público delante
hashimon_alen.DESTRUCTION_DRIFT = 0.0004  -- rumia lenta, incluso sin nadie
hashimon_alen.DESTRUCTION_OFFLINE_CAP = 60

hashimon_alen.AWAKE_FULL = 18000          -- 5 h despierto antes de que el tiempo pese
hashimon_alen.CATCH_UP_MAX = 7 * 24 * 3600

-- Techos de conocimiento. Van desde el primer día y no en una fase de limpieza
-- posterior: la ficha se serializa entera cada 5 s, así que un mapa sin techo no
-- es deuda técnica futura, es degradación silenciosa del servidor.
hashimon_alen.MAX_KNOWN_PLAYERS = 200
hashimon_alen.MAX_KNOWN_PLACES = 300

-- --------------------------------------------------------------------------
-- Personalidad: seis rasgos constantes, derivados de una semilla guardada al
-- nacer. El mismo Alen es siempre la misma personalidad; un Alen renacido es
-- otra. Es exactamente el trato que ya tienen los Hashimons con su ADN, y por
-- eso usa el mismo primitivo: sha256.
-- --------------------------------------------------------------------------

local TRAIT_NAMES = { "wrath", "patience", "vanity", "curiosity", "cruelty", "pride" }

-- Se remapea a [0.12, 0.88]: un rasgo de 0 exacto convierte una vida media en
-- cero y una personalidad en una división por cero.
local TRAIT_MIN, TRAIT_SPAN = 0.12, 0.76

local traits_cache, traits_cache_seed

local function neutral_traits()
	local t = {}
	for _, n in ipairs(TRAIT_NAMES) do
		t[n] = 0.5
	end
	return t
end

function hashimon_alen.new_seed()
	return core.sha256(tostring(os.time()) .. ":" .. tostring(math.random(1, 2 ^ 30)))
end

function hashimon_alen.traits()
	local s = hashimon_alen.get_state()
	if not s.seed then
		return neutral_traits()
	end
	if traits_cache and traits_cache_seed == s.seed then
		return traits_cache
	end
	local t = {}
	for _, name in ipairs(TRAIT_NAMES) do
		local hex = core.sha256(s.seed .. ":" .. name):sub(1, 8)
		t[name] = TRAIT_MIN + (tonumber(hex, 16) / 0xFFFFFFFF) * TRAIT_SPAN
	end
	traits_cache, traits_cache_seed = t, s.seed
	return t
end

--- Un rasgo como MULTIPLICADOR centrado en 1, no como escala desde cero.
---
--- Esto se corrigió tras la primera partida. Usar el rasgo crudo (0.12 – 0.88)
--- como multiplicador da un factor 7× entre un Alen y otro: uno con `patience`
--- baja se calmaba en 11 segundos y uno con `wrath` baja casi no reaccionaba a
--- los golpes. La personalidad debe ser un MATIZ, no un interruptor que puede
--- dejar al villano inerte. Con spread 0.35 el rango queda en [0.73, 1.27].
function hashimon_alen.trait_mult(name, spread)
	local t = hashimon_alen.traits()[name] or 0.5
	return 1 + (t - 0.5) * 2 * (spread or 0.35)
end

-- --------------------------------------------------------------------------
-- Matemática de decaimiento
-- --------------------------------------------------------------------------

local function clamp(v, lo, hi)
	if v < lo then return lo end
	if v > hi then return hi end
	return v
end

hashimon_alen.clamp = clamp

--- Vida media, no lineal. Un decaimiento lineal baja al mismo ritmo estando
--- furioso que estando casi calmado, y eso se lee como un robot enfriándose. La
--- vida media desinfla el pico deprisa y luego deja un rescoldo — que es
--- justamente "se está calmando, pero no lo ha olvidado".
function hashimon_alen.decay_half_life(value, dt, half_life)
	if not value or value <= 0 then return 0 end
	if not half_life or half_life <= 0 then return 0 end
	return value * 0.5 ^ (dt / half_life)
end

--- Decae, pero nunca por debajo de `floor` si la marca ya se hizo. Es lo que
--- hace que dejar ir no sea perdonar.
local function decay_with_floor(value, dt, half_life, floor_v, marked)
	local out = hashimon_alen.decay_half_life(value, dt, half_life)
	if marked and out < floor_v then
		return floor_v
	end
	return out
end

hashimon_alen.decay_with_floor = decay_with_floor

-- --------------------------------------------------------------------------
-- Derivados. Ninguno de estos se almacena jamás.
-- --------------------------------------------------------------------------

--- Cuánta noche es ahora, 0 (mediodía) a 1 (medianoche).
local function nightness()
	local tod = core.get_timeofday() or 0.5
	local d = math.abs(tod - 0.5)     -- 0 en mediodía, 0.5 en medianoche
	return clamp(d / 0.5, 0, 1)
end

function hashimon_alen.sleep_desire()
	local s = hashimon_alen.get_state()
	local awake_for = os.time() - (s.slept_at or os.time())
	local by_time = clamp(awake_for / hashimon_alen.AWAKE_FULL * 100, 0, 100)
	return clamp(0.5 * (s.fatigue or 0) + 0.3 * by_time + 0.2 * nightness() * 100, 0, 100)
end

--- Lectura del momento, no un depósito: vida, energía e historial contra este
--- adversario en concreto.
function hashimon_alen.confidence(target_name)
	local s = hashimon_alen.get_state()
	local base = 55 * (s.hp or 0) / hashimon_alen.MAX_HP
		+ 35 * (s.energy or 0) / hashimon_alen.MAX_ENERGY
	local rel = target_name and hashimon_alen.knows and hashimon_alen.knows(target_name)
	if rel then
		base = base + clamp(((rel.beaten or 0) - (rel.beaten_by or 0)) * 8, -25, 25)
		base = base - (rel.fear or 0) * 0.15
	end
	return clamp(base, 0, 100)
end

--- La etiqueta de humor. Hoy `mood` se escribía desde el nombre de la táctica,
--- lo que ya era una derivación disfrazada de campo; aquí es explícita y no
--- puede mentir sobre los números.
function hashimon_alen.mood_label()
	local s = hashimon_alen.get_state()
	if not s.awake then
		return "dormido"
	end
	local tier = hashimon_alen.tier and hashimon_alen.tier().name or "CALM"
	if tier == "WRATHFUL" then return "iracundo" end
	if tier == "ANGRY" then return "furioso" end
	if (s.energy or 100) < 20 then return "agotado" end
	if hashimon_alen.sleep_desire() > 70 then return "somnoliento" end
	if (s.boredom or 0) > 65 then return "aburrido" end
	if tier == "IRRITATED" then return "irritado" end
	return "acecho"
end

-- --------------------------------------------------------------------------
-- Gasto y ganancia de energía
-- --------------------------------------------------------------------------

--- Intenta pagar `cost`. Devuelve false si no llega — es lo que impide que el
--- ataque mayor se convierta en spam sin necesidad de un enfriamiento aparte.
function hashimon_alen.spend_energy(cost)
	local s = hashimon_alen.get_state()
	if (s.energy or 0) < cost then
		return false
	end
	s.energy = s.energy - cost
	if s.energy <= 0.5 and hashimon_alen.note_event then
		s.energy = 0
		hashimon_alen.note_event("energia_agotada", nil, {})
	end
	return true
end

function hashimon_alen.has_energy(cost)
	return (hashimon_alen.get_state().energy or 0) >= cost
end

-- --------------------------------------------------------------------------
-- El paso de 1 Hz. Vive dentro del tick táctico que ya existía.
-- --------------------------------------------------------------------------

function hashimon_alen.psyche_step(dt, ctx)
	local s = hashimon_alen.get_state()
	ctx = ctx or {}

	s.anger = hashimon_alen.decay_half_life(s.anger or 0, dt,
		hashimon_alen.ANGER_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4))

	local regen = hashimon_alen.ENERGY_REGEN * dt
	if ctx.in_combat then
		regen = regen * hashimon_alen.ENERGY_REGEN_COMBAT
	elseif not s.awake then
		regen = regen * 3 -- dormir es como se recupera de verdad
	end
	s.energy = math.min(hashimon_alen.MAX_ENERGY, (s.energy or 0) + regen)

	if s.awake then
		local per_s = ctx.flying and hashimon_alen.FATIGUE_PER_S_FLYING
			or hashimon_alen.FATIGUE_PER_S_GROUND
		s.fatigue = clamp((s.fatigue or 0) + per_s * dt, 0, 100)
	else
		s.fatigue = hashimon_alen.decay_half_life(s.fatigue or 0, dt,
			hashimon_alen.FATIGUE_HALF_LIFE_ASLEEP)
	end

	-- El aburrimiento sólo corre con público delante. Sin nadie a quien aburrirse
	-- no hay aburrimiento — ver catch_up(), donde esto importa de verdad.
	if ctx.observed and not ctx.target then
		s.boredom = clamp((s.boredom or 0) + hashimon_alen.BOREDOM_PER_S * dt, 0, 100)
	end

	if hashimon_alen.decay_relationships then
		hashimon_alen.decay_relationships(dt)
	end

	s.last_state_update_at = os.time()
end

-- --------------------------------------------------------------------------
-- El borde de materialización. Se llama UNA vez, al instanciar la entidad.
-- Esto es lo que permite que Alen evolucione mientras nadie lo mira sin gastar
-- un solo ciclo: no se simula el tiempo, se resuelve.
-- --------------------------------------------------------------------------

function hashimon_alen.catch_up()
	local s = hashimon_alen.get_state()
	local now = os.time()
	local last = s.last_state_update_at or now
	local elapsed = now - last

	-- Un reloj de sistema que retrocede y un mundo abandonado seis meses son las
	-- dos formas en que esta función produce números absurdos.
	if elapsed <= 0 then
		s.last_state_update_at = now
		return 0
	end
	elapsed = math.min(elapsed, hashimon_alen.CATCH_UP_MAX)


	s.anger = hashimon_alen.decay_half_life(s.anger or 0, elapsed,
		hashimon_alen.ANGER_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4))

	s.energy = math.min(hashimon_alen.MAX_ENERGY,
		(s.energy or 0) + hashimon_alen.ENERGY_REGEN * elapsed)

	s.fatigue = hashimon_alen.decay_half_life(s.fatigue or 0, elapsed,
		s.awake and hashimon_alen.FATIGUE_HALF_LIFE_AWAKE
		or hashimon_alen.FATIGUE_HALF_LIFE_ASLEEP)

	-- boredom: intencionalmente intacto. Si subiera sin observadores, entrar a un
	-- servidor vacío por primera vez te encontraría con un Alen furioso de tedio,
	-- que es lo contrario de lo que el aburrimiento debe significar.

	s.destruction_desire = math.min(hashimon_alen.DESTRUCTION_OFFLINE_CAP,
		(s.destruction_desire or 0) + elapsed * hashimon_alen.DESTRUCTION_DRIFT)

	if not s.awake then
		s.hp = math.min(hashimon_alen.MAX_HP, (s.hp or 0) + elapsed * 0.05)
	end

	if hashimon_alen.decay_relationships then
		hashimon_alen.decay_relationships(elapsed)
	end
	if hashimon_alen.prune_knowledge then
		hashimon_alen.prune_knowledge()
	end

	s.last_state_update_at = now
	core.log("action", string.format(
		"[alen] puesta al día: %d s fuera · ira %.0f · energía %.0f · fatiga %.0f",
		elapsed, s.anger or 0, s.energy or 0, s.fatigue or 0))
	return elapsed
end

--- Dormirse y despertar son modos discretos, no umbrales. "Dormido" no es "muy
--- cansado": es otra cosa, con otras reglas de recuperación y otra reacción al
--- daño.
function hashimon_alen.fall_asleep()
	local s = hashimon_alen.get_state()
	s.awake = false
	s.slept_at = os.time()
end

function hashimon_alen.wake_up(reason)
	local s = hashimon_alen.get_state()
	if s.awake then return end
	s.awake = true
	s.slept_at = os.time()
	s.fatigue = math.max(0, (s.fatigue or 0) - 40)
	if hashimon_alen.note_event then
		hashimon_alen.note_event("despertar", nil, { motivo = reason or "descansado" })
	end
end

-- --------------------------------------------------------------------------
-- Escalones de ira.
--
-- Cuatro, no cinco. Con bandas de ~20 puntos y una vida media de 90 s, la ira
-- atraviesa una banda intermedia en menos de un minuto y el jugador nunca llega
-- a registrar que existió. Cuatro escalones, con CALM ancho y WRATHFUL difícil
-- de alcanzar, hacen que cada transición se note.
--
-- CALM reproduce exactamente el comportamiento de hoy (vista 48): todo lo nuevo
-- ocurre por encima, así que esto no puede empeorar lo que ya funcionaba.
-- --------------------------------------------------------------------------

hashimon_alen.TIERS = {
	{
		name = "CALM", min = 0,
		sight = 48, pursuit = 60,
		fly_bias = 0,        -- cuánto empuja hacia volar en vez de caminar
		fire = "never",      -- never | provoked | free
		break_nodes = false,
		high_speed = false,
		disengage_bias = 20, -- cuánto le cuesta menos dejar ir
	},
	{
		name = "IRRITATED", min = 25,
		sight = 64, pursuit = 120,
		fly_bias = 15, fire = "provoked", break_nodes = false,
		high_speed = false, disengage_bias = 8,
	},
	{
		name = "ANGRY", min = 55,
		sight = 80, pursuit = 200,
		fly_bias = 40, fire = "free", break_nodes = true,
		high_speed = false, disengage_bias = -10,
	},
	{
		name = "WRATHFUL", min = 80,
		sight = 96, pursuit = 400,
		fly_bias = 70, fire = "free", break_nodes = true,
		high_speed = true, disengage_bias = -30,
	},
}

--- El escalón que corresponde a un valor concreto.
local function tier_for(value)
	local out = hashimon_alen.TIERS[1]
	for i = 2, #hashimon_alen.TIERS do
		if value >= hashimon_alen.TIERS[i].min then
			out = hashimon_alen.TIERS[i]
		else
			break
		end
	end
	return out
end

--- El escalón vigente frente a ALGUIEN EN CONCRETO.
---
--- Este es el arreglo de "le pego y me perdona muy fácil". Antes sólo mandaba la
--- ira, que decae; el rencor persistía y no hacía nada tácticamente. Ahora el
--- rencor hacia quien tienes delante marca un SUELO: alguien que ya te hizo
--- sangrar no vuelve a encontrarse a un dragón calmado, por mucho que la ira del
--- momento se haya enfriado. Un ser inferior que te tocó no se perdona.
function hashimon_alen.tier_toward(name)
	local by_anger = hashimon_alen.tier()
	if not name then return by_anger end
	local r = hashimon_alen.knows(name)
	if not r then return by_anger end
	local by_grudge = tier_for((r.grudge or 0) * 0.9)
	return (by_grudge.min > by_anger.min) and by_grudge or by_anger
end

--- El escalón vigente. Barato: cuatro comparaciones, sin asignar tablas.
function hashimon_alen.tier()
	local anger = hashimon_alen.get_state().anger or 0
	local out = hashimon_alen.TIERS[1]
	for i = 2, #hashimon_alen.TIERS do
		if anger >= hashimon_alen.TIERS[i].min then
			out = hashimon_alen.TIERS[i]
		else
			break
		end
	end
	return out
end

--- Cambia de escalón y avisa. El cruce de escalón es un evento de verdad — es
--- uno de los pocos que justifica despertar al modelo — así que se detecta una
--- sola vez y no en cada tick.
function hashimon_alen.check_tier_change()
	local s = hashimon_alen.get_state()
	local name = hashimon_alen.tier().name
	if s._tier_seen == name then
		return nil
	end
	local before = s._tier_seen
	s._tier_seen = name
	if before and hashimon_alen.note_event then
		hashimon_alen.note_event("cambio_de_ira", s.last_attacker,
			{ de = before, a = name, ira = math.floor(s.anger or 0) })
	end
	return name, before
end
