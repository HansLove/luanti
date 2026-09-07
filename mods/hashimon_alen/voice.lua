-- La voz de Alen. Banco local, cero llamadas al modelo.
--
-- Reescrito tras la primera partida real. Tres cosas fallaban y las tres hacían
-- que sonara a NPC genérico:
--
-- 1. La ventana anti-repetición era de 5 y NINGÚN banco llegaba a 5 frases, así
--    que se agotaba de inmediato y caía a math.random puro — repetición
--    inmediata incluida. La lógica existía y nunca llegó a ejecutarse.
-- 2. Una frase que nadie oía se marcaba como dicha igualmente, así que el banco
--    se gastaba en silencio y llegaba antes al azar.
-- 3. Las frases no sabían con quién hablaba. "¿Me golpeaste?" es genérico;
--    "¿Me golpeaste, diego?" y "Tres veces ya, diego." son otro personaje, y
--    cuestan exactamente lo mismo: cero.
--
-- Ahora la recencia es POR CATEGORÍA y se dimensiona al banco, así que nunca
-- puede agotarse, y las plantillas llevan @1 (nombre) y @2 (cuenta) resueltos
-- por el traductor del motor.

hashimon_alen = hashimon_alen or {}

local S = core.get_translator("hashimon_alen")

hashimon_alen.SAY_COOLDOWN = 6
hashimon_alen.SAY_RANGE = 64

-- --------------------------------------------------------------------------
-- El banco. Plantillas en español (idioma fuente), traducibles por .tr.
-- @1 = nombre del jugador · @2 = número (golpes, normalmente)
--
-- Registro: antiguo, superior, breve. Alen no explica lo que va a hacer y no
-- hace chistes. Si una frase se puede acortar, se acorta.
-- --------------------------------------------------------------------------

hashimon_alen.PHRASES = {
	-- Escalada de agresión. Que un golpe sea un ACONTECIMIENTO empieza aquí.
	-- Registro: complejo de dios. Habla en absolutos, mide el tiempo en eras, y lo
	-- que le ofende no es el daño sino la insolencia de haber sido tocado.
	ON_ATTACKED_FIRST = {
		"¿Me has tocado?",
		"Nada me había tocado en trescientos años. Y eres tú.",
		"@1. Acabas de escribir tu nombre en un sitio del que no se borra.",
		"Vuelve a hacerlo. Quiero estar seguro de lo que he sentido.",
		"Sabes lo que soy y aun así has levantado la mano.",
		"Los de tu especie me construyen altares. Tú eliges esto.",
		"Curioso. Dolió menos que tu atrevimiento.",
	},
	ON_ATTACKED_AGAIN = {
		"@1, van @2.",
		"Dos veces. Ya no es un error, es una decisión.",
		"Sigue. Estoy contando, y yo no olvido cuentas.",
		"@1. Empiezo a creer que quieres ser recordado.",
		"Cada golpe tuyo es una deuda, y yo cobro con intereses de siglos.",
		"No me haces daño. Me haces atención, que es mucho peor para ti.",
		"@1, esto ya no lo arregla una disculpa.",
	},
	ON_ATTACKED_PERSISTENT = {
		"@1, @2 golpes. Los he contado todos.",
		"Ya no hay nada que puedas decir.",
		"Has gastado lo poco que te quedaba de mi paciencia.",
		"Insistes como insiste el agua contra la piedra. Y acabas igual.",
		"Muy bien, @1. Ahora escucha lo que viene.",
		"Te has ganado algo que casi nadie se gana: mi esfuerzo.",
	},
	-- La advertencia. Alen SIEMPRE avisa antes de actuar: un dios anuncia sus
	-- castigos, no los suelta a traición.
	ON_WARN_ATTACK = {
		"Apártate, @1. No lo repetiré.",
		"Lo que viene ahora no es un golpe. Es una sentencia.",
		"Te concedo el tiempo de correr. Úsalo.",
		"Voy a borrarte, @1. Te aviso porque puedo permitírmelo.",
		"Mira bien el cielo. Va a cambiar de color.",
		"Tres segundos, @1. Es más de lo que doy normalmente.",
	},
	ON_WARN_TOWN = {
		"Esto que habéis levantado no debería existir.",
		"Voy a enseñaros de quién era esta tierra antes que vuestra.",
		"Salid de ahí. No lo diré otra vez.",
		"Vuestras casas me molestan la vista.",
	},
	ON_RAGE = {
		"SUFICIENTE.",
		"Se acabó la parte en la que hablo.",
		"Has despertado algo que llevaba siglos dormido, @1.",
		"Que arda, entonces. Todo.",
		"Mírame bien. Es lo último que ves gratis.",
		"Ahora vas a entender la diferencia entre nosotros.",
	},
	ON_ENRAGED = {
		"Corre.",
		"Ya no hay conversación.",
		"No vas a llegar al agua, @1.",
		"Ahora entiendes.",
		"Eras nada. Ahora eres nada que me molestó.",
	},
	ON_SLEEP_INTERRUPTED = {
		"Estaba durmiendo.",
		"De todo lo que podías haber hecho hoy, elegiste esto.",
		"Me despertaste, @1. Nadie hace eso dos veces.",
		"Dormía. Llevaba dormido más tiempo del que tiene tu pueblo.",
		"Ese sueño era lo único que te protegía.",
	},
	ON_PLAYER_ESCAPE = {
		"Sobreviviste. Interesante.",
		"Vuelve cuando seas más, @1.",
		"Corres bien. Lo tendré en cuenta.",
		"Te dejo ir. Recuérdalo cuando te preguntes por qué sigues vivo.",
		"@1 huye. Que se sepa.",
	},
	ON_KILL = {
		"Ya está.",
		"Descansa, @1. Es más de lo que merecías.",
		"Te lo advertí. Siempre advierto.",
		"Uno menos que recordar.",
		"No queda nada tuyo que me interese.",
	},
	ON_DISENGAGE = {
		"No confundas mi partida con misericordia.",
		"Hoy no.",
		"Tengo eras, @1. Tú tienes una tarde.",
		"Volveré cuando lo hayas olvidado. Yo no lo olvidaré.",
		"Esto no ha terminado. Sólo he perdido el interés.",
	},
	-- Conversación. Alen puede hablar, pero se aburre: seis idas y venidas y se va.
	ON_CONVO_END = {
		"Ya te he dedicado demasiado.",
		"Se acabó tu audiencia, @1.",
		"Hablar contigo era una novedad. Ya no lo es.",
		"Vuelve cuando tengas algo que yo no sepa.",
		"Basta. Tengo un cielo que vigilar.",
	},
	ON_LOW_ENERGY = {
		"Suficiente por ahora.",
		"Guardaré el resto para algo que lo merezca.",
		"No mereces lo que me queda.",
		"Otro día, @1.",
	},
	ON_CITY_ATTACK = {
		"Este lugar me desagrada.",
		"Levantasteis esto sobre mi sombra.",
		"Nadie os dio permiso.",
		"Vuestras paredes son papel y vuestra memoria más fina todavía.",
	},
	ON_CITY_SATISFIED = {
		"Ya he quemado suficiente.",
		"Con esto basta para que se entienda.",
		"Reconstruid. Me divierte veros intentarlo.",
		"Ahora sabéis de quién es el cielo.",
	},
	ON_SLEEP = {
		"Este sitio servirá.",
		"Que nadie me busque.",
		"Basta de vosotros por hoy.",
	},
	ON_WAKE = {
		"El mundo sigue donde lo dejé.",
		"Todavía estáis aquí.",
		"Qué breve ha sido.",
	},
	ON_GREETED_COLD = {
		"No me hables.",
		"@1.",
		"¿Qué quieres?",
		"Ahórratelo.",
		"Sé quién eres, @1. No es a tu favor.",
		"Hablas como si esto fuera una conversación.",
	},
	ON_GREETED_WARM = {
		"@1. Sigues aquí.",
		"Te escucho. Que sea breve.",
		"Habla, entonces.",
		"Vaya. Tú.",
		"@1. Dime.",
		"Pocos me dirigen la palabra dos veces.",
	},
	ON_FAREWELL = {
		"Vete.",
		"Sí. Vete.",
		"Hasta que vuelvas a molestarme.",
		"Corre mientras puedas, @1.",
	},
	ON_CHAT_BUSY = {
		"Ahora no.",
		"Estoy ocupado, @1.",
		"Más tarde.",
		"No malgastes mi atención.",
	},
	ON_PLAYER_LIKED = {
		"Tú no eres como los otros, @1.",
		"@1. Bien.",
		"Sigues vivo. Me alegra, y eso me sorprende.",
		"De todos ellos, tú.",
	},
	ON_PLAYER_RESPECTED = {
		"Me diviertes, @1.",
		"Recuerdo lo que hiciste. No fue poco.",
		"Pocos vuelven. Tú vuelves.",
		"@1. Tú y yo tenemos historia.",
		"Hay algo en ti que casi merece un nombre.",
	},
	ON_BORED = {
		"Nada aquí merece mi atención.",
		"Qué mundo tan pequeño.",
		"Ni siquiera valéis el vuelo.",
		"Hubo eras más interesantes que esta tarde.",
	},
	ON_DEPARTURE = {
		"Ya me habéis visto. Es suficiente.",
		"Recordad esto.",
		"Volveré. Siempre vuelvo.",
	},
}

-- --------------------------------------------------------------------------
-- Recencia POR CATEGORÍA, dimensionada al banco.
--
-- La ventana es #banco − 1: siempre queda al menos una frase fresca, así que la
-- lógica nunca se agota y nunca hay que caer al azar. Con un banco de 6, se
-- recuerdan 5 y la sexta es la única elegible — nunca se repite la anterior, y
-- se recorren todas antes de volver a empezar.
-- --------------------------------------------------------------------------

local recent = {}   -- [categoría] = { frases dichas, más reciente al final }

local function window_for(bank)
	return math.max(1, math.min(#bank - 1, 5))
end

local function in_recent(cat, text)
	local r = recent[cat]
	if not r then return false end
	for i = 1, #r do
		if r[i] == text then return true end
	end
	return false
end

local function pick(cat)
	local bank = hashimon_alen.PHRASES[cat]
	if not bank or #bank == 0 then return nil end
	if #bank == 1 then return bank[1] end

	local fresh, n = {}, 0
	for i = 1, #bank do
		if not in_recent(cat, bank[i]) then
			n = n + 1
			fresh[n] = bank[i]
		end
	end
	-- Por construcción n >= 1, pero si alguien encoge un banco en caliente esto
	-- evita el nil en vez de repetir a ciegas.
	if n == 0 then
		recent[cat] = nil
		return bank[math.random(1, #bank)]
	end
	return fresh[math.random(1, n)]
end

local function mark_said(cat, text)
	local bank = hashimon_alen.PHRASES[cat]
	recent[cat] = recent[cat] or {}
	table.insert(recent[cat], text)
	while #recent[cat] > window_for(bank) do
		table.remove(recent[cat], 1)
	end
end

-- --------------------------------------------------------------------------
-- LA PUERTA ÚNICA. Todo lo que Alen dice sale por aquí: eventos, planes y
-- comandos. El enfriamiento vive en un solo sitio porque sólo hay un sitio.
-- --------------------------------------------------------------------------

local function deliver(line, global)
	local pos = hashimon_alen._live and hashimon_alen._live:get_pos()
	if global or not pos then
		core.chat_send_all(line)
		return 1
	end
	local heard = 0
	for _, player in ipairs(core.get_connected_players()) do
		local pp = player:get_pos()
		if pp and hashimon_alen.dist(pos, pp) <= hashimon_alen.SAY_RANGE then
			core.chat_send_player(player:get_player_name(), line)
			heard = heard + 1
		end
	end
	return heard
end

--- Dice un texto ya resuelto. `opts.force` salta el enfriamiento y se reserva
--- para lo que no puede perderse: despertarlo a golpes, el umbral de furia.
function hashimon_alen.say_text(text, opts)
	opts = opts or {}
	if not text or text == "" then return false end

	local now = core.get_gametime()
	if not opts.force and hashimon_alen._said_at
		and now - hashimon_alen._said_at < hashimon_alen.SAY_COOLDOWN then
		return false
	end

	local line = core.colorize("#F97316", "<Alen Gregory> ") .. tostring(text)
	if deliver(line, opts.global) == 0 then
		return false -- nadie cerca: no gasta enfriamiento y no gasta frase
	end
	hashimon_alen._said_at = now
	return true
end

--- Valida el orden de los @n. `core.translate` no sólo exige que el NÚMERO de
--- argumentos coincida: exige que las secuencias aparezcan EN ORDEN — "@2 ... @1"
--- es un error, no una reordenación. Se comprueba al cargar el mod para que una
--- plantilla mal escrita salte en el arranque y no en mitad de una pelea.
--- Devuelve la lista de plantillas defectuosas.
function hashimon_alen.validate_phrases()
	local bad = {}
	for cat, bank in pairs(hashimon_alen.PHRASES) do
		for _, t in ipairs(bank) do
			local seen, expect = {}, 1
			for d in t:gmatch("@(%d)") do
				local i = tonumber(d)
				if not seen[i] then
					if i ~= expect then
						bad[#bad + 1] = cat .. ": " .. t
						break
					end
					seen[i] = true
					expect = expect + 1
				end
			end
		end
	end
	return bad
end

--- Cuántos argumentos espera una plantilla. `core.translate` exige que el número
--- coincida EXACTAMENTE con los @n que aparecen — pasarle dos a una frase sin
--- placeholders es un error, no un argumento ignorado.
local function arity(template)
	local max = 0
	for d in template:gmatch("@(%d)") do
		local i = tonumber(d)
		if i > max then max = i end
	end
	return max
end

--- Habla por categoría, con contexto. `ctx.name` y `ctx.n` rellenan @1 y @2.
function hashimon_alen.say(cat, opts, ctx)
	local template = pick(cat)
	if not template then return false end
	ctx = ctx or {}

	local name = tostring(ctx.name or "alguien")
	local count = tostring(ctx.n or "?")
	local n = arity(template)

	-- pcall a propósito: esto se llama desde on_punch. Una frase mal escrita debe
	-- salir fea, no tumbar el combate — que es exactamente lo que pasó la primera
	-- vez que alguien golpeó a Alen con una plantilla defectuosa en el banco.
	local ok, text
	if n == 0 then
		ok, text = pcall(S, template)
	elseif n == 1 then
		ok, text = pcall(S, template, name)
	else
		ok, text = pcall(S, template, name, count)
	end
	if not ok then
		core.log("error", "[alen] plantilla defectuosa, se dice sin traducir: " .. template)
		text = template:gsub("@1", name):gsub("@2", count)
	end
	if not hashimon_alen.say_text(text, opts) then
		return false -- NO se marca: una frase que nadie oyó no se ha gastado
	end
	mark_said(cat, template)
	return true
end

--- La escalada: qué categoría toca según cuántas veces te ha aguantado ya.
--- Es la diferencia entre un dragón que reacciona y uno que responde igual
--- siempre.
function hashimon_alen.attacked_category(hits)
	if hits <= 1 then return "ON_ATTACKED_FIRST" end
	if hits <= 3 then return "ON_ATTACKED_AGAIN" end
	return "ON_ATTACKED_PERSISTENT"
end

--- Saludo según la relación. Devuelve nil casi siempre, que es lo correcto:
--- un villano que comenta cada avistamiento deja de dar miedo.
function hashimon_alen.greeting_for(name)
	local label = hashimon_alen.relation_label(name)
	local tr = hashimon_alen.traits()
	if math.random() > tr.vanity * 0.5 then
		return nil
	end
	if label == "RESPECTED" or label == "AMUSED" then return "ON_PLAYER_RESPECTED" end
	if label == "LIKED" then return "ON_PLAYER_LIKED" end
	if label == "HOSTILE" then return "ON_ENRAGED" end
	return nil
end

-- Al cargar, no al usar: si alguien añade una plantilla con los @n desordenados,
-- se entera en el arranque del servidor.
do
	local bad = hashimon_alen.validate_phrases()
	for _, entry in ipairs(bad) do
		core.log("error", "[alen] PLANTILLA MAL FORMADA (los @n deben ir en orden): " .. entry)
	end
	if #bad == 0 then
		core.log("action", "[hashimon_alen] banco de frases validado")
	end
end
