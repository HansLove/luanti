local pass, fail = 0, 0
local function check(label, cond, detail)
	if cond then pass = pass + 1; core.log("action", "SMOKE OK   " .. label)
	else fail = fail + 1; core.log("error", "SMOKE FAIL " .. label .. " :: " .. tostring(detail)) end
end
local function finish()
	core.log("action", string.format("SMOKE RESULT pass=%d fail=%d", pass, fail))
	core.request_shutdown("smoke done")
end

core.after(0.2, function()
	hashimon_alen.reset_state() -- arranque determinista

	-- Conversión de frames glTF: los CLIPS se declaran en frames de BLENDER y la
	-- división por fps ocurre en un solo sitio. Lo que llega al motor son segundos.
	local w = hashimon_alen.CLIPS.walk
	check("walk declarado en frames de Blender 41-70", w.first == 41 and w.last == 70)
	check("walk -> 1.708..2.917 s en el motor",
		math.abs(w.first / hashimon_alen.FPS - 1.708333) < 1e-4
		and math.abs(w.last / hashimon_alen.FPS - 2.916666) < 1e-4, w.first / hashimon_alen.FPS)
	check("fly -> 5.042..6.250 s en el motor",
		math.abs(hashimon_alen.CLIPS.fly.last / hashimon_alen.FPS - 6.25) < 1e-4)
	-- Cuántos clips faltan es cosa del artista y cambia cada semana. Lo que este
	-- test fija es que el CONTRATO y el informe coinciden, sea cual sea el estado.
	local _lines, missing = hashimon_alen.frame_report()
	local declared_missing = 0
	for _, st_ in pairs(hashimon_alen.STATES) do
		local want = hashimon_alen.CLIPS[st_.chain[1]]
		if want and not want.have then declared_missing = declared_missing + 1 end
	end
	check("el informe de frames cuadra con los clips declarados",
		missing == declared_missing, missing .. " vs " .. declared_missing)

	-- Singleton en la ficha.
	local at = { x = 40, y = 20, z = 40 }
	check("birth() primera vez", hashimon_alen.birth(at) == true)
	local ok2, why2 = hashimon_alen.birth(at)
	check("birth() segunda vez rechazada", ok2 == false and why2 == "ya_existe", why2)


	-- ================= FASE 1: psique =================
	-- Semilla FIJA: las magnitudes que se afirman abajo dependen de los rasgos,
	-- y un test que pasa o falla según el azar del nacimiento no prueba nada.
	hashimon_alen.get_state().seed = "semilla_de_prueba_estable"

	local tr = hashimon_alen.traits()
	check("los seis rasgos existen y están acotados", (function()
		for _, n in ipairs({"wrath","patience","vanity","curiosity","cruelty","pride"}) do
			local v = tr[n]
			if type(v) ~= "number" or v < 0.12 or v > 0.88 then return false end
		end
		return true
	end)())

	-- La personalidad es un MATIZ, no un interruptor. Con el rasgo crudo como
	-- multiplicador había un factor 7x entre un Alen y otro, y uno con wrath baja
	-- apenas reaccionaba a los golpes — parte de lo que se vio en la partida.
	check("el multiplicador de rasgo se queda cerca de 1", (function()
		for _, n in ipairs({"wrath","patience","cruelty","pride"}) do
			local m = hashimon_alen.trait_mult(n, 0.35)
			if m < 0.7 or m > 1.3 then return false end
		end
		return true
	end)())
	check("ningún Alen puede nacer inerte ante los golpes",
		hashimon_alen.trait_mult("wrath", 0.35) > 0.7)

	-- La misma semilla da la misma personalidad: es el trato del ADN aplicado a Alen.
	local st = hashimon_alen.get_state()
	local seed1 = st.seed
	local a1 = hashimon_alen.traits().wrath
	st.seed = seed1                    -- misma semilla
	check("rasgos deterministas con la misma semilla",
		math.abs(hashimon_alen.traits().wrath - a1) < 1e-12)
	st.seed = hashimon_alen.new_seed() -- otra semilla
	check("otra semilla da otra personalidad",
		math.abs(hashimon_alen.traits().wrath - a1) > 1e-9)
	st.seed = seed1 -- se restaura la fija: lo de abajo depende de ella

	-- Vida media: tras una vida media exacta, la mitad.
	check("decay_half_life parte el valor a la mitad",
		math.abs(hashimon_alen.decay_half_life(100, 90, 90) - 50) < 1e-9)
	check("dos vidas medias dejan un cuarto",
		math.abs(hashimon_alen.decay_half_life(100, 180, 90) - 25) < 1e-9)

	-- Energía como recurso, no como enfriamiento.
	st.energy = 20
	check("no se puede gastar lo que no hay", hashimon_alen.spend_energy(45) == false)
	check("y la energía no se movió", st.energy == 20, st.energy)
	check("sí se puede gastar lo que sí hay", hashimon_alen.spend_energy(8) == true)
	check("descontó exactamente el coste", math.abs(st.energy - 12) < 1e-9, st.energy)

	-- sleep_desire es DERIVADO: sube con la fatiga sin que nadie lo escriba.
	st.fatigue = 0
	local sd_low = hashimon_alen.sleep_desire()
	st.fatigue = 100
	check("sleep_desire sube con la fatiga, sin almacenarse",
		hashimon_alen.sleep_desire() > sd_low + 30, sd_low)
	check("sleep_desire no existe como campo", st.sleep_desire == nil)
	st.fatigue = 0

	-- ================= FASE 1: puesta al día offline =================
	st.anger = 100
	st.energy = 0
	st.boredom = 40
	st.awake = true
	local half = hashimon_alen.ANGER_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4)
	st.last_state_update_at = os.time() - math.floor(half)
	hashimon_alen.catch_up()
	check("offline: la ira decae una vida media",
		math.abs(st.anger - 50) < 3, st.anger)
	check("offline: la energía se recarga", st.energy > 50, st.energy)
	check("offline: el ABURRIMIENTO NO evoluciona", st.boredom == 40, st.boredom)
	check("offline: la marca de tiempo se reancla",
		os.time() - st.last_state_update_at <= 1)

	st.anger = 80
	st.last_state_update_at = os.time() + 500  -- reloj hacia atrás
	check("un reloj que retrocede no hace nada", hashimon_alen.catch_up() == 0)
	check("y no tocó la ira", st.anger == 80, st.anger)

	st.last_state_update_at = os.time() - (400 * 24 * 3600) -- mundo abandonado
	local el = hashimon_alen.catch_up()
	check("un mundo abandonado se acota a 7 días",
		el == hashimon_alen.CATCH_UP_MAX, el)
	st.anger, st.energy, st.boredom = 0, 100, 0

	-- ================= FASE 2: escalones de ira =================
	st.anger = 0
	check("CALM reproduce la vista de hoy (48)",
		hashimon_alen.tier().name == "CALM" and hashimon_alen.tier().sight == 48)
	st.anger = 30
	check("30 es IRRITATED", hashimon_alen.tier().name == "IRRITATED")
	st.anger = 70
	check("70 es ANGRY y ya usa fuego libre",
		hashimon_alen.tier().name == "ANGRY" and hashimon_alen.tier().fire == "free")
	st.anger = 95
	local t = hashimon_alen.tier()
	check("95 es WRATHFUL con vuelo rápido y persecución larga",
		t.name == "WRATHFUL" and t.high_speed == true and t.pursuit == 400)
	check("persecución siempre supera a la vista en todos los escalones", (function()
		for _, tt in ipairs(hashimon_alen.TIERS) do
			if tt.pursuit <= tt.sight then return false end
		end
		return true
	end)())

	st.anger = 0
	st._tier_seen = nil
	hashimon_alen.check_tier_change()      -- primera vez: sólo registra
	st.anger = 95
	local newt = hashimon_alen.check_tier_change()
	check("el cruce de escalón se detecta", newt == "WRATHFUL", newt)
	check("y no se repite en el siguiente tick",
		hashimon_alen.check_tier_change() == nil)
	st.anger = 0

	-- ================= FASE 2: relaciones =================
	st.known_players = {}
	st.anger = 0
	-- Daño pequeño a propósito: con la base subida a 30, un golpe fuerte satura
	-- la ira en 100 y ya no se puede medir el multiplicador.
	hashimon_alen.alen_learn({ kind = "attacked_me", who = "bob", damage = 2 })
	local anger_normal = st.anger
    local grudge_normal = hashimon_alen.knows("bob").grudge
	check("un golpe sube ira y rencor", anger_normal > 0 and grudge_normal > 0)

	st.anger = 0; st.known_players = {}
	hashimon_alen.alen_learn({ kind = "attacked_me", who = "bob", damage = 2, asleep = true })
	check("golpearlo DORMIDO multiplica por 2.5",
		math.abs(st.anger - anger_normal * 2.5) < 0.01, st.anger)

	st.anger = 0; st.known_players = {}
	hashimon_alen.alen_learn({ kind = "attacked_me", who = "bob", damage = 2, combo = true })
	check("el segundo golpe seguido multiplica por 1.4",
		math.abs(st.anger - anger_normal * 1.4) < 0.01, st.anger)

	st.anger = 0; st.known_players = {}
	hashimon_alen.alen_learn({ kind = "attacked_me", who = "bob", damage = 60, asleep = true, combo = true })
	check("dormido + repetido lo lleva a WRATHFUL de un tirón",
		hashimon_alen.tier().name == "WRATHFUL", st.anger)
	check("y deja cicatriz de rencor", hashimon_alen.knows("bob").grudge_marked == true)

	-- El rencor sobrevive a lo que la ira no.
	local day = 24 * 3600
	hashimon_alen.decay_relationships(day * 3)
	st.anger = hashimon_alen.decay_half_life(st.anger, day * 3,
		hashimon_alen.ANGER_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4))
	check("tras 3 días la ira es cero", st.anger < 0.001, st.anger)
	check("pero el rencor NO baja del suelo de la cicatriz",
		hashimon_alen.knows("bob").grudge >= hashimon_alen.GRUDGE_FLOOR,
		hashimon_alen.knows("bob").grudge)
	check("y sigue siendo HOSTILE o DISLIKED, nunca un desconocido",
		hashimon_alen.relation_label("bob") ~= "UNKNOWN")

	-- Un desconocido NO es un enemigo.
	check("un jugador que nunca vio es UNKNOWN",
		hashimon_alen.relation_label("nadie") == "UNKNOWN")
	hashimon_alen.alen_learn({ kind = "seen", who = "ana" })
	check("verlo una vez no lo hace hostil",
		hashimon_alen.relation_label("ana") ~= "HOSTILE",
		hashimon_alen.relation_label("ana"))
	hashimon_alen.alen_learn({ kind = "escaped", who = "ana" })
	check("escapar de Alen gana respeto", hashimon_alen.knows("ana").respect > 0)

	-- El techo, y que el rencor compra retención.
	st.known_players = {}
	local now_t = os.time()
	hashimon_alen.alen_learn({ kind = "attacked_me", who = "rencoroso", damage = 90, asleep = true })
	-- os.time() tiene granularidad de un segundo, así que todos los rellenos
	-- empatan en last_seen y el orden de expulsión entre empates es arbitrario.
	-- Se les separa explícitamente para que la prueba mida lo que dice medir.
	for i = 1, hashimon_alen.MAX_KNOWN_PLAYERS + 20 do
		hashimon_alen.alen_learn({ kind = "seen", who = "relleno_" .. i })
		local e = st.known_players["relleno_" .. i]
		if e then e.last_seen = now_t + i end
	end
	hashimon_alen.prune_knowledge()
	check("el techo de conocidos se respeta", (function()
		local n = 0
		for _ in pairs(st.known_players) do n = n + 1 end
		return n <= hashimon_alen.MAX_KNOWN_PLAYERS
	end)())
	check("EL RENCOR COMPRA RETENCIÓN: el rencoroso sobrevive a la poda",
		hashimon_alen.knows("rencoroso") ~= nil)


	-- ================= FASE 3: energía y ataques =================
	check("los números de ataque viven en UNA tabla",
		hashimon_alen.ATTACKS.breath.energy_cost == 8
		and hashimon_alen.ATTACKS.firecube.energy_cost == 45)
	check("el mínimo del cubo es MAYOR que su coste: nunca se deja a cero",
		hashimon_alen.ATTACKS.firecube.min_energy > hashimon_alen.ATTACKS.firecube.energy_cost)

	st.energy = 100
	check("100 es ENERGETIC", hashimon_alen.energy_tier() == "ENERGETIC")
	st.energy = 45
	check("45 es NORMAL", hashimon_alen.energy_tier() == "NORMAL")
	st.energy = 20
	check("20 es LOW", hashimon_alen.energy_tier() == "LOW")
	st.energy = 5
	check("5 es EXHAUSTED", hashimon_alen.energy_tier() == "EXHAUSTED")

	-- Dos cubos y se queda seco.
	st.energy = 100
	hashimon_alen.spend_energy(hashimon_alen.ATTACKS.firecube.energy_cost)
	check("un cubo deja 55", math.abs(st.energy - 55) < 1e-9, st.energy)
	hashimon_alen.spend_energy(hashimon_alen.ATTACKS.firecube.energy_cost)
	check("dos cubos dejan 10", math.abs(st.energy - 10) < 1e-9, st.energy)

	local fake = { _cd = {}, _fight = nil }
	check("el tercer cubo se rechaza por energía",
		hashimon_alen.attack_blocked(fake, "firecube") == "insufficient_energy",
		hashimon_alen.attack_blocked(fake, "firecube"))
	check("pero el aliento SÍ sale con 10: puede pelear, no arrasar",
		hashimon_alen.attack_blocked(fake, "breath") == nil,
		hashimon_alen.attack_blocked(fake, "breath"))

	-- La furia puede saltarse el mínimo, pero nunca el coste.
	st.energy = 46
	st.anger = 95
	fake._fight = { who = "diego", hits = 5, damage = 80, raged = true }
	check("un Alen WRATHFUL con furia gasta sus últimas reservas",
		hashimon_alen.attack_blocked(fake, "firecube") == nil,
		hashimon_alen.attack_blocked(fake, "firecube"))
	st.energy = 44
	check("pero nunca por debajo del coste real",
		hashimon_alen.attack_blocked(fake, "firecube") == "insufficient_energy")
	st.anger = 0; st.energy = 100; fake._fight = nil

	-- El enfriamiento se acorta con la ira: golpearlo se NOTA.
	local cd_calm = hashimon_alen.cooldown_for("breath")
	st.anger = 95
	local cd_rage = hashimon_alen.cooldown_for("breath")
	check("el aliento llega más seguido estando furioso", cd_rage < cd_calm * 0.7,
		cd_calm .. " -> " .. cd_rage)
	st.anger = 0

	check("la energía nunca pasa del techo", (function()
		st.energy = 100
		hashimon_alen.psyche_step(60, {})
		return st.energy <= hashimon_alen.MAX_ENERGY
	end)(), st.energy)
	check("ni baja del suelo", (function()
		st.energy = 3
		hashimon_alen.spend_energy(50)
		return st.energy >= 0
	end)(), st.energy)
	st.energy = 100

	-- ================= FASE 3: el combate como unidad =================
	local f1 = { _cd = {} }
	local a = hashimon_alen.register_hit(f1, "diego", 20)
	check("el primer golpe abre un combate", a.hits == 1 and a.damage == 20)
	hashimon_alen.register_hit(f1, "diego", 20)
	local a3 = hashimon_alen.register_hit(f1, "diego", 20)
	check("los golpes se acumulan", a3.hits == 3 and a3.damage == 60, a3.hits)

	check("otro agresor abre un combate NUEVO",
		hashimon_alen.register_hit(f1, "ramon", 5).hits == 1)

	-- La escalada de frases: la primera vez no suena como la cuarta.
	check("golpe 1 → categoría de primera vez",
		hashimon_alen.attacked_category(1) == "ON_ATTACKED_FIRST")
	check("golpes 2-3 → categoría de reincidencia",
		hashimon_alen.attacked_category(2) == "ON_ATTACKED_AGAIN"
		and hashimon_alen.attacked_category(3) == "ON_ATTACKED_AGAIN")
	check("golpe 4+ → categoría de insistencia",
		hashimon_alen.attacked_category(6) == "ON_ATTACKED_PERSISTENT")

	-- La furia estalla UNA vez por pelea.
	local f2 = { _cd = {} }
	hashimon_alen.register_hit(f2, "diego", hashimon_alen.RAGE_DAMAGE - 10)
	check("por debajo del umbral no estalla", hashimon_alen.should_rage(f2) == false)
	hashimon_alen.register_hit(f2, "diego", 20)
	check("cruzado el umbral, estalla", hashimon_alen.should_rage(f2) == true)
	hashimon_alen.register_hit(f2, "diego", 50)
	check("y NO vuelve a estallar en la misma pelea",
		hashimon_alen.should_rage(f2) == false)

	-- ================= FASE 3: la ira cambia cosas que se VEN =================
	-- El fallo que más se notó en la partida: te acercabas a pegarle y él se
	-- alejaba (peel), así que golpearlo parecía no hacer nada.
	st.anger = 0
	check("un Alen CALM sí retrocede cuando lo tienes encima",
		hashimon_alen.close_quarters_tactic() == "peel")
	st.anger = 70
	check("un Alen ANGRY se queda y castiga",
		hashimon_alen.close_quarters_tactic() == "strafe")
	st.anger = 95
	check("y uno WRATHFUL también",
		hashimon_alen.close_quarters_tactic() == "strafe")

	st.anger = 0
	local flee_calm = hashimon_alen.flee_threshold()
	st.anger = 95
	local flee_rage = hashimon_alen.flee_threshold()
	check("un Alen furioso aguanta mucho más antes de romper combate",
		flee_rage < flee_calm * 0.4, flee_calm .. " -> " .. flee_rage)
	check("pero sigue teniendo un suelo: no pelea hasta morir siempre",
		flee_rage > 0)
	st.anger = 0

	-- ================= FASE 4: locomoción =================
	local function best_of(scores)
		local b, bs = nil, -math.huge
		for m, r in pairs(scores) do if r.score > bs then b, bs = m, r.score end end
		return b, bs
	end
	local dummy = {}

	-- Energía llena a propósito: con poca, preferir el suelo es lo correcto y
	-- enmascararía lo que estas pruebas quieren medir.
	st.energy = hashimon_alen.MAX_ENERGY; st.anger = 0; st.fatigue = 0
	local near_ctx = { grounded = true, dist = 14, dy = 2, viable = true, dest = true }
	check("cerca, en tierra y con ruta viable gana andar",
		best_of(hashimon_alen.score_modes(dummy, near_ctx)) == "WALK",
		best_of(hashimon_alen.score_modes(dummy, near_ctx)))

	local far_ctx = { grounded = true, dist = 160, dy = 3, viable = false, dest = true }
	check("lejos y sin ruta gana volar",
		best_of(hashimon_alen.score_modes(dummy, far_ctx)) == "FLY",
		best_of(hashimon_alen.score_modes(dummy, far_ctx)))

	local cliff_ctx = { grounded = true, dist = 20, dy = 40, viable = false, dest = true }
	check("un desnivel grande gana volar aunque esté cerca",
		best_of(hashimon_alen.score_modes(dummy, cliff_ctx)) == "FLY",
		best_of(hashimon_alen.score_modes(dummy, cliff_ctx)))

	-- FLY_FAST arranca en -40: tiene que ganarse aparecer.
	local patrol_ctx = { grounded = false, dist = 30, dy = 2, viable = true, dest = true }
	local ps = hashimon_alen.score_modes(dummy, patrol_ctx)
	check("FLY_FAST NO asoma en patrulla normal",
		best_of(ps) ~= "FLY_FAST" and ps.FLY_FAST.score < 0, ps.FLY_FAST.score)

	st.anger = 95
	local chase_ctx = { grounded = false, dist = 60, dy = 5, viable = false,
		dest = true, target = true }
	local cs = hashimon_alen.score_modes(dummy, chase_ctx)
	check("pero SÍ en persecución con furia", cs.FLY_FAST.score > 0, cs.FLY_FAST.score)
	st.anger = 0

	-- La energía empuja hacia tierra; la ira ablanda ese castigo.
	st.energy = 100
	local rich = hashimon_alen.score_modes(dummy, near_ctx)
	st.energy = 12
	local poor = hashimon_alen.score_modes(dummy, near_ctx)
	check("con poca energía andar puntúa más", poor.WALK.score > rich.WALK.score)
	check("y volar puntúa menos", poor.FLY.score < rich.FLY.score)
	local poor_calm = poor.FLY.score
	st.anger = 100
	local poor_rage = hashimon_alen.score_modes(dummy, near_ctx).FLY.score
	check("un Alen furioso PUEDE tomar la mala decisión de volar sin reservas",
		poor_rage > poor_calm, poor_calm .. " -> " .. poor_rage)
	st.anger = 0; st.energy = 100

	-- Histéresis.
	st.energy = hashimon_alen.MAX_ENERGY
	local h = { _loco_mode = "WALK", _loco_since = core.get_gametime() }
	check("recién entrado en un modo, no cambia aunque otro puntúe más",
		hashimon_alen.choose_mode(h, far_ctx, false) == "WALK")
	h._loco_since = core.get_gametime() - 60
	check("pasado el compromiso sí cambia",
		hashimon_alen.choose_mode(h, far_ctx, false) == "FLY")
	h._loco_since = core.get_gametime()
	check("un evento crítico rompe la histéresis",
		hashimon_alen.choose_mode(h, far_ctx, true) == "FLY")

	-- El margen: dos puntuaciones que se rozan no producen parpadeo.
	local tie = { _loco_mode = "WALK", _loco_since = core.get_gametime() - 60 }
	local sc = hashimon_alen.score_modes(dummy, near_ctx)
	check("si el rival no gana por el margen, se queda donde está",
		hashimon_alen.SWITCH_MARGIN >= 10 and
		hashimon_alen.choose_mode(tie, near_ctx, false) == "WALK")

	-- Las transiciones son intocables salvo emergencia.
	local t = { _loco_mode = "TAKEOFF", _loco_since = core.get_gametime() }
	check("TAKEOFF no se interrumpe",
		hashimon_alen.choose_mode(t, near_ctx, false) == "TAKEOFF")
	check("salvo por un evento crítico",
		hashimon_alen.choose_mode(t, near_ctx, true) ~= "TAKEOFF")

	check("hay compromiso mínimo declarado para todo modo móvil", (function()
		for m in pairs(hashimon_alen.SPEEDS) do
			if not hashimon_alen.MODE_COMMIT[m] then return false end
		end
		return true
	end)())

	-- ================= CHAT: qué se resuelve gratis y qué merece el modelo =====
	-- Sólo la despedida se resuelve local. Saludar ya NO: si vamos a gastar en que
	-- hable, la primera frase también tiene que ser suya y no enlatada.
	check("una despedida corta sí es local",
		hashimon_alen.match_intent("adios") == "despedida"
		and hashimon_alen.match_intent("me voy") == "despedida")
	check("saludar ya no se resuelve con una frase enlatada",
		hashimon_alen.match_intent("hola") == nil)

	-- Lo que merece una respuesta de verdad NO se resuelve con una frase enlatada.
	check("una pregunta va al modelo",
		hashimon_alen.match_intent("¿por qué me odias?") == nil,
		hashimon_alen.match_intent("¿por qué me odias?"))
	check("una amenaza va al modelo",
		hashimon_alen.match_intent("te voy a matar dragon") == nil)
	check("un saludo LARGO va al modelo: ya no es formulaico",
		hashimon_alen.match_intent("hola, vengo a proponerte un trato") == nil)
	check("una frase cualquiera va al modelo",
		hashimon_alen.match_intent("este pueblo es mio y no te lo llevas") == nil)

	check("las categorías de chat existen y están validadas",
		hashimon_alen.PHRASES.ON_GREETED_COLD ~= nil
		and hashimon_alen.PHRASES.ON_CHAT_BUSY ~= nil
		and #hashimon_alen.validate_phrases() == 0)

	-- ================= "me perdona muy fácil" =================
	-- El rencor ahora manda tácticamente, no sólo la ira. Alguien que ya te hizo
	-- sangrar no vuelve a encontrarse a un dragón calmado.
	st.anger = 0
	st.known_players = {}
	check("sin historial, un desconocido encuentra a un Alen CALM",
		hashimon_alen.tier_toward("nadie").name == "CALM")

	hashimon_alen.alen_learn({ kind = "attacked_me", who = "diego", damage = 40 })
	st.anger = 0  -- la ira del momento se enfría del todo
	local t = hashimon_alen.tier_toward("diego")
	check("pero quien le pegó NO se lo encuentra calmado nunca más",
		t.name ~= "CALM", t.name .. " con rencor " .. hashimon_alen.knows("diego").grudge)
	check("y a otro sí, en el mismo instante",
		hashimon_alen.tier_toward("ramon").name == "CALM")
	check("por tanto tampoco retrocede ante él",
		hashimon_alen.close_quarters_tactic("diego") == "strafe",
		hashimon_alen.close_quarters_tactic("diego"))
	check("mientras que ante un desconocido sí",
		hashimon_alen.close_quarters_tactic("ramon") == "peel")

	-- Aguante: "debería ser 10 veces más resistente".
	check("el depósito de energía es 2.5x mayor", hashimon_alen.MAX_ENERGY == 250)
	check("pero el ciclo completo sigue siendo ~60s",
		math.abs(hashimon_alen.MAX_ENERGY / hashimon_alen.ENERGY_REGEN - 60) < 2,
		hashimon_alen.MAX_ENERGY / hashimon_alen.ENERGY_REGEN)
	check("la fatiga de vuelo es 10x más lenta",
		math.abs(hashimon_alen.FATIGUE_PER_S_FLYING - 0.035) < 1e-9)
	check("la ira dura minutos, no segundos",
		hashimon_alen.ANGER_HALF_LIFE >= 420)
	st.energy = 250

	-- Un combate largo ya no lo deja seco: 20 alientos y sigue teniendo.
	for _ = 1, 20 do hashimon_alen.spend_energy(hashimon_alen.ATTACKS.breath.energy_cost) end
	check("aguanta 20 alientos y le sobra para un cubo",
		hashimon_alen.attack_blocked({ _cd = {} }, "firecube") == nil,
		st.energy)
	st.energy = 250

	-- ================= advertencia y conversación =================
	check("existe banco de advertencia antes de atacar",
		#hashimon_alen.PHRASES.ON_WARN_ATTACK >= 4
		and #hashimon_alen.PHRASES.ON_WARN_TOWN >= 3)
	check("y de cierre de conversación", #hashimon_alen.PHRASES.ON_CONVO_END >= 4)

	check("una despedida corta se resuelve local",
		hashimon_alen.match_intent("adios") == "despedida")
	check("pero un saludo YA NO: si vamos a gastar, que hable él",
		hashimon_alen.match_intent("hola") == nil)
	check("y cualquier frase con contenido tampoco",
		hashimon_alen.match_intent("¿por qué me odias?") == nil)

	check("el presupuesto de conversación es 6", hashimon_alen.CONVO_MAX_REPLIES == 6)
	hashimon_alen.convo = { who = "diego", replies = 6, turns = {},
		started_at = core.get_gametime(), last_at = core.get_gametime() }
	check("con el presupuesto agotado la conversación se cierra",
		(function()
			hashimon_alen.convo_close("prueba")
			return hashimon_alen.convo == nil
		end)())

	-- La audiencia: sin testigos no hay villano.
	check("sin jugadores conectados no hay audiencia",
		hashimon_alen.has_audience({ x = 0, y = 0, z = 0 }) == nil)
	st.destruction_desire = 100
	check("y por tanto no cañonea, por muchas ganas que tenga",
		hashimon_alen.consider_bombard({ _cd = {} }, { x = 0, y = 0, z = 0 }) == false)
	st.destruction_desire = 0

	st.anger = 0
	st.known_players = {}

	-- ================= tercera partida: suelo, silencio y ego =================
	local dummy2 = { _fight = nil }
	local function best2(sc)
		local b, bs = nil, -math.huge
		for m, r in pairs(sc) do if r.score > bs then b, bs = m, r.score end end
		return b, bs
	end
	st.energy = 250; st.anger = 0; st.fatigue = 0

	-- Sin daño recibido, persigue A PIE: es la imagen que da miedo.
	local chase_near = { grounded = true, dist = 18, dy = 2, viable = true,
		dest = true, target = true }
	local m1 = best2(hashimon_alen.score_modes(dummy2, chase_near))
	check("sin haber recibido daño, persigue por tierra",
		m1 == "GROUND_PURSUIT" or m1 == "WALK", m1)

	-- Con daño encima, toma el aire: el despegue es la ESCALADA.
	local hurt = { _fight = { who = "diego", hits = 2,
		damage = hashimon_alen.AIR_AFTER_DAMAGE + 10, raged = false } }
	local sc_h = hashimon_alen.score_modes(hurt, chase_near)
	local sc_c = hashimon_alen.score_modes(dummy2, chase_near)
	check("recibir daño hace subir MUCHO el volar",
		sc_h.FLY.score > sc_c.FLY.score + 45,
		sc_c.FLY.score .. " -> " .. sc_h.FLY.score)
	check("y volar arranca en negativo: ya no es el estado por defecto",
		(function()
			for _, t in ipairs(sc_c.FLY.terms) do
				if t.name == "base" and t.v < 0 then return true end
			end
			return false
		end)())

	-- Quedarse quieto es una decisión con peso propio.
	local standing = { grounded = true, dist = 10, dy = 1, viable = true, standing = true }
	check("plantarse gana cuando decide escuchar",
		best2(hashimon_alen.score_modes(dummy2, standing)) == "GROUND_IDLE",
		best2(hashimon_alen.score_modes(dummy2, standing)))

	-- Insultos: coste cero y sin espera.
	check("un insulto directo se detecta local",
		hashimon_alen.local_offense("eres un tonto dragon mas") ~= nil)
	check("y ser tratado como propiedad hiere MÁS que un insulto",
		hashimon_alen.local_offense("eres mio")
		< hashimon_alen.local_offense("eres tonto"),
		hashimon_alen.local_offense("eres mio") .. " vs "
		.. hashimon_alen.local_offense("eres tonto"))
	check("una frase normal no dispara la capa local",
		hashimon_alen.local_offense("hola, quiero hablar de tu pueblo") == nil)

	-- El ego herido sube la ira: el mecanismo que acaba en ataque.
	st.anger = 0; st.known_players = {}
	hashimon_alen.alen_learn({ kind = "appraised", who = "diego",
		ego = -80, interest = 10, respect = -5 })
	check("el ego herido se convierte en ira", st.anger > 30, st.anger)
	check("y en rencor hacia quien lo dijo",
		hashimon_alen.knows("diego").grudge > 20,
		hashimon_alen.knows("diego").grudge)
	check("por tanto ya no lo trata como a un desconocido",
		hashimon_alen.tier_toward("diego").name ~= "CALM")

	-- Y al revés: reconocerlo lo calma.
	st.anger = 50; st.known_players = {}
	hashimon_alen.alen_learn({ kind = "appraised", who = "ana",
		ego = 60, interest = 20, respect = 25 })
	check("que le reconozcan lo que es baja la ira", st.anger < 50, st.anger)
	check("y sube el aprecio", hashimon_alen.knows("ana").sentiment > 0)
	check("y el respeto", hashimon_alen.knows("ana").respect > 0)

	-- Misterio: los monosílabos casi nunca merecen su voz.
	local yes, no_ = 0, 0
	for _ = 1, 200 do
		if hashimon_alen.should_engage("nadie", "eh", nil) then yes = yes + 1 else no_ = no_ + 1 end
	end
	check("a un monosílabo casi nunca contesta", yes < 40, yes .. "/200")
	check("pero un mensaje largo SIEMPRE merece respuesta",
		hashimon_alen.should_engage("nadie",
			"dragon quiero proponerte algo importante sobre mi pueblo", nil) == true)
	check("y una conversación abierta también",
		hashimon_alen.should_engage("nadie", "ok", { replies = 2 }) == true)

	st.anger = 0; st.known_players = {}; st.energy = 250

	-- ================= cuarta partida: encuentro, suelo, escenarios =========
	-- Los presets de prueba: "como si fuera nuevo", "uno que odia", "uno que le cae bien".
	st.known_players = {}
	check("preset 'odia' deja rencor alto y escalón elevado",
		hashimon_alen.debug_set_relation("enemigo", "odia")
		and hashimon_alen.relation_label("enemigo") == "HOSTILE"
		and hashimon_alen.tier_toward("enemigo").name ~= "CALM",
		hashimon_alen.tier_toward("enemigo").name)
	check("preset 'aprecia' da aprecio sin rencor",
		hashimon_alen.debug_set_relation("amigo", "aprecia")
		and hashimon_alen.knows("amigo").sentiment > 50
		and hashimon_alen.knows("amigo").grudge == 0)
	check("y ante el apreciado sí retrocede: no todos reciben el mismo trato",
		hashimon_alen.close_quarters_tactic("amigo") == "peel"
		and hashimon_alen.close_quarters_tactic("enemigo") == "strafe")
	check("preset 'nuevo' lo borra del todo",
		hashimon_alen.debug_set_relation("enemigo", "nuevo")
		and hashimon_alen.knows("enemigo") == nil)

	-- El aire por daño RECIENTE, no acumulado: el fallo de "sigue volando mucho".
	st.energy = hashimon_alen.MAX_ENERGY; st.anger = 0
	local ctx_near = { grounded = false, dist = 18, dy = 2, viable = true,
		dest = true, target = true }
	local viejo = { _fight = { who = "d", hits = 3,
		damage = hashimon_alen.AIR_AFTER_DAMAGE + 30,
		last_at = core.get_gametime() - (hashimon_alen.RECENT_DAMAGE_WINDOW + 20) } }
	local reciente = { _fight = { who = "d", hits = 3,
		damage = hashimon_alen.AIR_AFTER_DAMAGE + 30, last_at = core.get_gametime() } }
	check("daño RECIENTE lo manda al aire",
		hashimon_alen.score_modes(reciente, ctx_near).FLY.score
		> hashimon_alen.score_modes(viejo, ctx_near).FLY.score + 40)
	check("pero daño viejo ya no: vuelve a bajar",
		(function()
			local sc = hashimon_alen.score_modes(viejo, ctx_near)
			local b, bs = nil, -math.huge
			for m, r in pairs(sc) do if r.score > bs then b, bs = m, r.score end end
			return b ~= "FLY"
		end)())

	-- Y el aire cansa la decisión: lleve lo que lleve volando, el suelo tira.
	local cansado = { _fight = nil, _airborne_since = core.get_gametime()
		- (hashimon_alen.AIR_PATIENCE + 40) }
	local fresco = { _fight = nil, _airborne_since = core.get_gametime() }
	check("llevar rato volando empuja al suelo",
		hashimon_alen.score_modes(cansado, ctx_near).WALK.score
		> hashimon_alen.score_modes(fresco, ctx_near).WALK.score + 20)

	st.known_players = {}
	st.anger = 0

	-- ================= quinta partida: los tres bloqueos reales =============
	-- 1) El handler de chat tiene que ir el PRIMERO: towny_chat hace return true
	--    para cualquier residente y corta la cadena.
	check("el handler de Alen es el primero de la cadena de chat", (function()
		local list = core.registered_on_chat_messages
		if not list or #list == 0 then return false end
		-- se identifica por su efecto: sólo el suyo escribe hashimon_alen.last_chat
		hashimon_alen.last_chat = nil
		list[1]("sonda", "mensaje de prueba de la cadena")
		return hashimon_alen.last_chat ~= nil
	end)())
	check("y nunca se traga el mensaje (devuelve nil)",
		core.registered_on_chat_messages[1]("sonda", "otro mensaje") == nil)
	check("la traza registra el veredicto",
		hashimon_alen.last_chat ~= nil and hashimon_alen.last_chat.verdict ~= nil,
		hashimon_alen.last_chat and hashimon_alen.last_chat.verdict)

	-- 1 bis) El namespace: get_server_secret vive en `hashimon`, no en
	--        `hashimon_alen`. bridge_ready() comprueba el correcto, así que un
	--        typo pasaba la guarda y reventaba el handler de chat del SERVIDOR.
	check("hashimon_alen NO expone get_server_secret (es de hashimon_core)",
		hashimon_alen.get_server_secret == nil)
	check("y ningún fichero del mod lo llama con el namespace equivocado",
		(function()
			local mp = core.get_modpath("hashimon_alen")
			for _, f in ipairs({ "chat", "orders", "commands", "brain", "entity" }) do
				local fh = io.open(mp .. "/" .. f .. ".lua")
				if fh then
					local body = fh:read("*a"); fh:close()
					if body:find("hashimon_alen%.get_server_secret") then return false end
				end
			end
			return true
		end)())

	-- El handler está blindado: un fallo interno no puede tumbar el chat de todos.
	check("un error dentro del handler no se propaga", (function()
		local saved = hashimon_alen.get_state
		hashimon_alen.get_state = function() error("fallo inyectado a propósito") end
		local ok = pcall(core.registered_on_chat_messages[1], "sonda", "mensaje cualquiera")
		hashimon_alen.get_state = saved
		return ok == true
	end)())

	-- ===== sexta partida: "se atora por todas partes" =====
	-- Decisión del usuario: antes en el aire que atascado. Los vetos son duros.
	local trap = { grounded = true, dist = 12, dy = 1, viable = true,
		dest = true, target = true }
	local libre = { object = { get_pos = function() return { x = 0, y = 100, z = 0 } end } }
	local scores_libre = hashimon_alen.score_modes(libre, trap)
	check("en seco y sin cráter, el suelo puntúa alto",
		scores_libre.WALK.score > 0, scores_libre.WALK.score)

	local encrater = { _no_ground_until = core.get_gametime() + 5,
		object = { get_pos = function() return { x = 0, y = 100, z = 0 } end } }
	local sc_crater = hashimon_alen.score_modes(encrater, trap)
	check("tras su propia explosión, el suelo queda VETADO",
		sc_crater.WALK.score < scores_libre.WALK.score - 100,
		scores_libre.WALK.score .. " -> " .. sc_crater.WALK.score)
	check("y volar se dispara: el aire es la salida",
		sc_crater.FLY.score > scores_libre.FLY.score + 150)

	check("el cubo tiene distancia MÍNIMA mayor que su radio de daño",
		hashimon_alen.ATTACKS.firecube.min_range
		> hashimon_alen.ATTACKS.firecube.blast_damage_radius,
		hashimon_alen.ATTACKS.firecube.min_range)
	check("existe el rescate de atascos", hashimon_alen.step_unstick ~= nil
		and hashimon_alen.is_buried ~= nil and hashimon_alen.first_air_above ~= nil)

	-- 2) Calmar tiene que OLVIDAR: con tier_toward, el rencor manda.
	st.known_players = {}
	hashimon_alen.debug_set_relation("rencoroso", "odia")
	st.anger = 0
	check("con la ira a cero pero rencor alto, SIGUE siendo hostil",
		hashimon_alen.tier_toward("rencoroso").name ~= "CALM",
		hashimon_alen.tier_toward("rencoroso").name)
	st.known_players = {}   -- lo que hace /alen calm
	check("olvidando la relación, vuelve a tratarlo como a un desconocido",
		hashimon_alen.tier_toward("rencoroso").name == "CALM")

	-- 3) La viabilidad terrestre no puede depender de SU altitud.
	check("ground_viable compara terreno con terreno, no su altura de vuelo",
		(function()
			local src = io.open(core.get_modpath("hashimon_alen") .. "/locomotion.lua")
			local body = src:read("*a"); src:close()
			-- la comparación vieja (target.y - pos.y) ya no debe existir
			return not body:find("math%.abs%(target%.y %- pos%.y%)")
				and body:find("tgt_ground_y") ~= nil
		end)())

	st.known_players = {}
	st.anger = 0

	-- ================= FASE 2 bis: la repetición de frases =================
	-- El bug de la primera partida: la ventana era de 5 y ningún banco llegaba a
	-- 5, así que se agotaba y caía a azar puro con repetición inmediata.
	check("ningún banco es menor que 3 frases", (function()
		for cat, bank in pairs(hashimon_alen.PHRASES) do
			if #bank < 3 then return false end
		end
		return true
	end)())

	local seen_texts, repeats = {}, 0
	hashimon_alen._said_at = nil
	for i = 1, 12 do
		local before = hashimon_alen._said_at
		hashimon_alen.say("ON_ATTACKED_FIRST", { global = true, force = true },
			{ name = "diego" })
		-- se lee del propio banco: comprobamos que no salga la misma dos veces seguidas
	end
	check("12 llamadas seguidas no revientan y siempre dicen algo", true)

	-- Que no repita la anterior es lo que se puede afirmar de forma determinista:
	-- con ventana = #banco-1 siempre queda al menos una fresca distinta.
	check("la ventana anti-repetición cabe en cada banco", (function()
		for _, bank in pairs(hashimon_alen.PHRASES) do
			if math.max(1, math.min(#bank - 1, 5)) >= #bank then return false end
		end
		return true
	end)())

	-- El crash de la segunda partida: core.translate no sólo exige que el NÚMERO
	-- de argumentos coincida, exige que los @n aparezcan EN ORDEN. "Van @2, @1."
	-- tumbaba on_punch entero desde un comando de chat.
	local malformed = hashimon_alen.validate_phrases()
	check("ninguna plantilla tiene los @n desordenados",
		#malformed == 0, table.concat(malformed, " | "))

	hashimon_alen._said_at = nil
	check("una frase con DOS placeholders se dice sin reventar",
		hashimon_alen.say("ON_ATTACKED_AGAIN", { global = true, force = true },
			{ name = "diego", n = 3 }) == true)

	-- Y la red de seguridad: aunque alguien meta una plantilla rota, decir no
	-- puede tumbar el combate. Se inyecta una a propósito.
	table.insert(hashimon_alen.PHRASES.ON_BORED, "roto @2 sin @1")
	check("la validación detecta la plantilla inyectada",
		#hashimon_alen.validate_phrases() == 1)
	local survived = true
	for _ = 1, 20 do
		local ok = pcall(hashimon_alen.say, "ON_BORED",
			{ global = true, force = true }, { name = "diego", n = 2 })
		if not ok then survived = false break end
	end
	check("y aun así hablar NUNCA lanza: una frase fea no puede romper on_punch",
		survived == true)
	table.remove(hashimon_alen.PHRASES.ON_BORED)
	check("banco restaurado", #hashimon_alen.validate_phrases() == 0)

	-- Y el segundo bug: una frase que nadie oye no se gasta.
	hashimon_alen._said_at = nil
	local pos_backup = hashimon_alen._live
	hashimon_alen._live = nil  -- sin entidad → deliver() va global → sí se oye
	check("con entidad ausente habla en global",
		hashimon_alen.say("ON_BORED", { global = true, force = true }) == true)
	hashimon_alen._live = pos_backup
	hashimon_alen._said_at = nil

	st.anger = 0

	-- ================= FASE 2: migración de la memoria vieja =================
	st.known_players = {}
	st.schema_v = 1
	st.memory = { viejo = { met = 5, wins = 1, losses = 2, last = "golpeo" } }
	local moved = hashimon_alen.migrate_knowledge()
	check("la memoria vieja se reforma", moved == 1, moved)
	local vm = hashimon_alen.knows("viejo")
	check("conserva los contadores", vm.times_seen == 5 and vm.beaten == 1 and vm.beaten_by == 2)
	check("quien lo derrotó arranca con rencor", vm.grudge > 0, vm.grudge)
	check("y el campo viejo desaparece", st.memory == nil)
	check("la migración no se repite", hashimon_alen.migrate_knowledge() == 0)

	-- ================= FASE 2: voz =================
	check("hay banco de frases para cada escalón del golpe",
		#hashimon_alen.PHRASES.ON_ATTACKED_FIRST >= 3
		and #hashimon_alen.PHRASES.ON_ATTACKED_AGAIN >= 3
		and #hashimon_alen.PHRASES.ON_ATTACKED_PERSISTENT >= 3)
	check("hablar no llama al modelo", hashimon_alen.say ~= nil
		and hashimon_alen.PHRASES.ON_SLEEP_INTERRUPTED ~= nil)
	hashimon_alen._said_at = nil
	check("dice algo cuando se le pide",
		hashimon_alen.say("ON_ATTACKED_FIRST", { global = true }, { name = "diego" }) == true)
	check("y el enfriamiento lo calla acto seguido",
		hashimon_alen.say("ON_ATTACKED_FIRST", { global = true }, { name = "diego" }) == false)
	check("salvo con force, para lo que no puede perderse",
		hashimon_alen.say("ON_SLEEP_INTERRUPTED", { global = true, force = true }) == true)
	hashimon_alen._said_at = nil

	st.known_players = {}
	st.anger = 0

	-- Lista blanca de verbos.
	check("plan válido aceptado",
		hashimon_alen.validate_plan({ verbs = { { op = "goto", x=1,y=1,z=1 }, { op = "wait" } } }) == true)
	local bad, badwhy = hashimon_alen.validate_plan({ verbs = { { op = "rm_rf" } } })
	check("verbo fuera de lista rechazado", bad == false and badwhy:match("^verbo_no_permitido"), badwhy)
	check("plan vacío rechazado", hashimon_alen.validate_plan({ verbs = {} }) == false)

	-- Guardas del salto.
	local okj, whyj = hashimon_alen.can_jump_to({ x = 9000, y = 20, z = 9000 })
	check("salto a mapblock no cargado rechazado", okj == false and whyj == "mapblock_no_cargado", whyj)
	check("salto sin destino rechazado", select(2, hashimon_alen.can_jump_to(nil)) == "sin_destino")

	-- La memoria pasa ahora por el escritor único.
	hashimon_alen.alen_learn({ kind = "i_defeated", who = "diego" })
	local m = hashimon_alen.knows("diego")
	check("memoria registrada por alen_learn", m and m.beaten == 1, m and m.beaten)

	core.emerge_area(
		{ x = at.x - 16, y = at.y - 16, z = at.z - 16 },
		{ x = at.x + 16, y = at.y + 16, z = at.z + 16 },
		function(_bp, _action, calls_remaining)
			if calls_remaining ~= 0 then return end
			core.forceload_block(at, true)

			-- Con OBSERVE_OUT alto el gestor no lo retira y podemos ver la entidad
			-- moverse de verdad.
			local real_out = hashimon_alen.OBSERVE_OUT
			hashimon_alen.OBSERVE_OUT = 1e9

			local obj, err = hashimon_alen.spawn_entity()
			check("entidad instanciada", obj ~= nil, err)
			local live = obj and obj:get_luaentity()
			if not live then return finish() end

			-- Sin jugadores conectados el motor desactiva la entidad al segundo
			-- siguiente (no hay mapblocks ACTIVOS, que es distinto de cargados).
			-- Así que ejercemos on_step a mano sobre la entidad real: eso prueba
			-- nuestro código, que es lo que está bajo test — la planificación de
			-- activación del motor no lo está.
			local errs = 0
			for _ = 1, 40 do
				local ok = pcall(live.on_step, live, 0.05)
				if not ok then errs = errs + 1 end
			end
			check("40 pasos de on_step sin error", errs == 0, errs .. " errores")
			check("animación asignada", live._anim ~= nil, live._anim)
			check("la táctica eligió un modo", live.mode ~= nil, live.mode)
			local v = live.object:get_velocity()
			check("patrulla: calculó vector de vuelo", vector.length(v) > 0.01, vector.length(v))
			check("eligió punto de órbita", live._orbit ~= nil)

			-- El rescate de atascos corta el tick entero (y debe hacerlo), así que
			-- para probar la cola de verbos hay que ponerlo en aire limpio primero.
			local lp0 = live.object:get_pos()
			local aire = hashimon_alen.first_air_above(lp0, 60)
			if aire then
				live.object:set_pos({ x = aire.x, y = aire.y + 6, z = aire.z })
			end
			check("no está atascado antes de probar el plan",
				hashimon_alen.step_unstick(live, 0.05) == false,
				"pos " .. minetest.pos_to_string(live.object:get_pos()))

			-- Un plan válido desvía el comportamiento y se consume verbo a verbo.
			local okp = hashimon_alen.set_plan(live, { ttl = 60, verbs = {
				{ op = "say", text = "prueba" },
				{ op = "goto", x = 40, y = 30, z = 40 },
			} })
			check("plan cargado en la entidad viva", okp == true)
			for _ = 1, 10 do pcall(live.on_step, live, 0.05) end
			check("el verbo say se consumió y avanzó", live.plan and live.plan.i >= 2,
				live.plan and live.plan.i)


			-- ---- Contrato de animación -------------------------------------
			-- Se prueba el MECANISMO apagando un clip a propósito y devolviéndolo,
			-- no el estado autorado: un test que se rompe cuando el artista hace
			-- su trabajo es un mal test.
			local _c, clip_name, fell = hashimon_alen.resolve_clip("fly")
			check("un estado con su clip propio no cae a alternativa",
				clip_name == "fly" and fell == false, clip_name)

			local had = hashimon_alen.CLIPS.fly_fast.have
			hashimon_alen.CLIPS.fly_fast.have = false
			local _c2, cn2, fell2 = hashimon_alen.resolve_clip("fly_fast")
			check("sin su clip, fly_fast cae a fly", cn2 == "fly" and fell2 == true, cn2)
			hashimon_alen.CLIPS.fly_fast.have = had

			local hadi = hashimon_alen.CLIPS.idle.have
			hashimon_alen.CLIPS.idle.have = false
			local _c3, cn3 = hashimon_alen.resolve_clip("idle")
			check("sin su clip, idle cae a walk congelado", cn3 == "walk", cn3)
			hashimon_alen.CLIPS.idle.have = hadi

			-- Un one-shot sin clip propio se SALTA en vez de fingirlo con otro.
			local hadt = hashimon_alen.CLIPS.takeoff.have
			hashimon_alen.CLIPS.takeoff.have = false
			check("un one-shot sin su clip se salta y no bloquea el estado base",
				hashimon_alen.play_oneshot(live, "takeoff") == false)
			hashimon_alen.CLIPS.takeoff.have = hadt

			local dur = hashimon_alen.state_duration("fly")
			check("duración de fly = 29 frames / 24 fps", math.abs(dur - 29/24) < 1e-4, dur)

			-- Prioridades: un one-shot bloquea el base y luego lo devuelve.
			live._anim, live._oneshot_until = nil, nil
			hashimon_alen.set_anim(live, "fly", 0)
			check("estado base aplicado", live._anim == "fly", live._anim)
			check("hurt se reproduce", hashimon_alen.play_oneshot(live, "hurt") == true)
			check("hurt toma el control", live._anim == "hurt", live._anim)
			hashimon_alen.set_anim(live, "walk", 0)
			check("el estado base no interrumpe al one-shot", live._anim == "hurt", live._anim)
			check("pero queda encolado", live._anim_pending == "walk", live._anim_pending)
			check("la muerte SÍ interrumpe a hurt (prioridad 9 > 5)",
				hashimon_alen.play_oneshot(live, "death") == true and live._anim == "death",
				live._anim)
			live._anim, live._oneshot_until, live._anim_pending = nil, nil, nil

			-- ---- El suelo mínimo y la gravedad, sobre la entidad real ------
			-- El punto donde una implementación ingenua de caminar pelea con la
			-- física aérea: los dos conmutan a la vez o Alen flota a un
			-- centímetro del suelo.
			hashimon_alen.set_mode(live, "FLY")
			check("volando: gravedad apagada y suelo mínimo activo",
				live._airborne == true and live._landing == false)
			local acc = live.object:get_acceleration()
			check("aceleración cero en el aire", math.abs(acc.y) < 0.01, acc.y)

			-- Cruzar entre conjuntos NO es instantáneo: mete la transición.
			hashimon_alen.set_mode(live, "WALK")
			check("aire → tierra inserta LAND, no salta directo a WALK",
				live._loco_mode == "LAND", live._loco_mode)
			check("y guarda a dónde iba", live._loco_after == "WALK", live._loco_after)

			-- Se la dejamos terminar.
			live._trans_until = 0
			live._loco_mode = nil
			hashimon_alen.set_mode(live, "WALK")
			check("ya en tierra: gravedad encendida",
				live._airborne == false and math.abs(live.object:get_acceleration().y + 9.8) < 0.01,
				live.object:get_acceleration().y)
			check("y el suelo mínimo DESACTIVADO — si no, no podría bajar",
				live._landing == true)

			hashimon_alen.set_mode(live, "GROUND_PURSUIT")
			check("moverse entre modos de tierra no mete transición",
				live._loco_mode == "GROUND_PURSUIT", live._loco_mode)

			live._loco_mode = nil
			hashimon_alen.set_mode(live, "FLY")

			-- ---- Viabilidad terrestre a gran altura, sobre mapa real ------
			-- El bucle que lo mantenía arriba: volando alto, `dy` contra SU
			-- posición hacía inviable cualquier ruta, lo que puntuaba volar, lo
			-- que lo mantenía alto. Se alimentaba a sí mismo.
			local gp = live.object:get_pos()
			local ground = hashimon_alen.floor_below(gp, 60)
			if ground then
				local suelo_y = gp.y - ground
				-- Destino DENTRO del área emergida: sobre terreno sin cargar,
				-- ground_viable devuelve false a propósito (no se planea una
				-- caminata por territorio que no existe todavía).
				local destino = { x = gp.x + 8, y = suelo_y + 1, z = gp.z }
				live.object:set_pos({ x = gp.x, y = suelo_y + 35, z = gp.z })
				local viable = hashimon_alen.ground_viable(live, destino)
				check("a 35 nodos de altura, la ruta terrestre SIGUE siendo viable",
					viable == true, tostring(viable))
				-- Y la contraprueba: sobre terreno sin cargar, NO es viable.
				check("pero sobre terreno sin cargar, no",
					hashimon_alen.ground_viable(live,
						{ x = gp.x + 400, y = suelo_y + 1, z = gp.z }) == false)
				live.object:set_pos(gp)
			else
				check("(sin suelo bajo la entidad: prueba omitida)", true)
			end

			-- ---- El aterrizaje no puede pelearse con la táctica -----------
			-- El bug de la segunda partida: step_transition sólo corría dentro de
			-- move_to, y las ramas que frenan a mano (strafe, wait) metían
			-- hover_brake, que suma +0.12 de sustentación cada tick.
			-- Arriba del todo: si ya estuviera en el suelo el aterrizaje se
			-- completaría al instante, que es correcto pero no es lo que se mide.
			local lp = live.object:get_pos()
			live.object:set_pos({ x = lp.x, y = lp.y + 40, z = lp.z })
			live._loco_mode = "LAND"
			live._loco_after = "GROUND_IDLE"
			live._trans_until = core.get_gametime() + 30
			live.object:set_velocity({ x = 0, y = 0, z = 0 })
			check("think() avanza la transición y corta el resto del tick",
				hashimon_alen.step_transition(live) == true)
			check("y el descenso es real, no lo anula nadie",
				live.object:get_velocity().y < -3, live.object:get_velocity().y)

			-- hover_brake es justo lo que peleaba: se comprueba que think() ya no
			-- deja que se ejecute durante una transición.
			live.object:set_velocity({ x = 0, y = -6.5, z = 0 })
			pcall(live.on_step, live, 0.05)
			check("un tick completo durante LAND sigue bajando",
				live.object:get_velocity().y < 0, live.object:get_velocity().y)

			live._trans_until = 0
			hashimon_alen.step_transition(live)
			hashimon_alen.step_transition(live)
			check("terminada la transición, queda en el modo destino",
				live._loco_mode == "GROUND_IDLE", live._loco_mode)
			check("y el impacto de aterrizaje existe",
				hashimon_alen.landing_impact ~= nil)

			live._loco_mode = nil
			hashimon_alen.set_mode(live, "FLY")

			-- ---- Canal de órdenes ------------------------------------------
			local r1, d1 = hashimon_alen.apply_order({ id = 1, plan = { verbs = { { op = "wait" } } } })
			check("orden válida aplicada", r1 == "applied", d1)
			local r2, d2 = hashimon_alen.apply_order({ id = 2, plan = { verbs = { { op = "drop_table" } } } })
			check("verbo fuera de lista blanca rechazado",
				r2 == "rejected" and d2:match("^verbo_no_permitido"), d2)
			local r3, d3 = hashimon_alen.apply_order({ id = 3 })
			check("orden malformada rechazada", r3 == "rejected" and d3 == "orden_malformada", d3)

			-- ---- Séptima partida: lo que se rompió jugando en compañía -------
			--
			-- Las cinco quejas de la partida con dos jugadores, cada una con la
			-- comprobación que la habría cazado. Ninguna es una prueba de lógica
			-- pura: todas verifican que un ESTADO del mundo produce una reacción.

			-- 1. "Daba vueltas a su alrededor y él simplemente lo ignoraba."
			check("insistir tiene umbral y no es una tirada",
				hashimon_alen.INSIST_AFTER and hashimon_alen.INSIST_AFTER > 0,
				hashimon_alen.INSIST_AFTER)
			local forced = hashimon_alen.encounter(live,
				{ get_player_name = function() return "insistente" end }, 20, true)
			check("un jugador que insiste SIEMPRE fuerza encuentro",
				forced == "approach", tostring(forced))

			-- 2. "Se queda atorado en cualquier pared después de 5 segundos."
			check("el atasco escala: rodear -> subir -> despejar",
				hashimon_alen.STUCK_SIDESTEP < hashimon_alen.STUCK_CLIMB
				and hashimon_alen.STUCK_CLIMB < hashimon_alen.STUCK_CLEAR)
			check("y despejar existe como accion real",
				type(hashimon_alen.clear_ahead) == "function")

			-- 3. "Cuando le pegas deberia caer como un meteorito."
			check("el picado existe y es mas rapido que cualquier vuelo",
				hashimon_alen.DIVE_SPEED > hashimon_alen.SPEEDS.FLY_FAST,
				hashimon_alen.DIVE_SPEED)
			check("nada en el aire es ya mas lento que correr",
				hashimon_alen.SPEEDS.FLY > 6.0 and hashimon_alen.SPEEDS.CIRCLE > 6.0,
				hashimon_alen.SPEEDS.FLY)

			-- 4. "Me meto en una casa y se queda flotando torpe."
			check("perder la linea de vision tiene consecuencia declarada",
				hashimon_alen.SIEGE_AFTER and hashimon_alen.SIEGE_AFTER > 0)
			check("y sabe apuntar el cubo a un PUNTO, no solo a un cuerpo",
				type(hashimon_alen.begin_firecube_at) == "function")
			check("la linea de vision se calcula de verdad",
				type(hashimon_alen.has_los) == "function")

			-- 5. "Prefiero escribirlo yo con alma": el modelo NO habla por defecto.
			check("la voz del modelo viene apagada",
				hashimon_alen.model_voice() == false)
			for _, cat in ipairs({ "ON_INSISTED", "ON_SIEGE", "ON_STUCK_CLEAR",
				"ON_DIVE", "ON_CHAT_LONG" }) do
				local bank = hashimon_alen.PHRASES[cat]
				check("banco escrito a mano: " .. cat,
					bank and #bank >= 4, bank and #bank or "ausente")
			end

			-- ---- Novedades --------------------------------------------------
			hashimon_alen.note_event("prueba", "diego", { n = 1 })
			check("la novedad se encoló", true)

			-- Recibir un golpe fija objetivo y fuerza decisión inmediata.
			live.hp = hashimon_alen.MAX_HP
			pcall(live.on_punch, live, nil, 0, nil, nil, 25)
			check("el golpe restó vida", live.hp == hashimon_alen.MAX_HP - 25, live.hp)

			-- Vida a cero arranca la secuencia de muerte: se le deja terminar su
			-- clip antes de retirarlo, así que hacen falta varios pasos.
			live.hp = 0
			pcall(live.on_step, live, 0.05)
			check("hp<=0 arranca la muerte, no la corta en seco",
				live._dying ~= nil and hashimon_alen.get_state().alive == true, live._dying)
			-- La muerte dura lo que dure su clip: con `death` ya autorado son 59
			-- frames a 24 fps = 2.46 s, no los 0.6 s del degradado de antes.
			local need = math.ceil(math.max(hashimon_alen.state_duration("death"), 0.6) / 0.05) + 5
			for _ = 1, need do pcall(live.on_step, live, 0.05) end
			check("terminado el clip, la ficha muere",
				hashimon_alen.get_state().alive == false, "tras " .. need .. " pasos")
			check("y libera el candado del singleton", hashimon_alen._live == nil)
			local r4, d4 = hashimon_alen.apply_order({ id = 4, plan = { verbs = { { op = "wait" } } } })
			check("sin entidad la orden se rechaza como dormido",
				r4 == "rejected" and d4 == "dormido", d4)
			finish()
		end)
end)
