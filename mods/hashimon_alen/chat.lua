-- Hablarle a Alen.
--
-- Regla del usuario: a cincuenta nodos de un dragón de cuatro metros, todo lo que
-- escribas en el chat es para él. No hace falta nombrarlo.
--
-- Y el trato de coste que puso: **hasta seis respuestas por conversación**. Al
-- séptimo intento se aburre y se va. Eso convierte hablar con Alen en un recurso
-- con final, que es mejor diseño que un chatbot infinito y además acota el gasto
-- sin necesidad de racanear frase a frase.
--
-- Por eso las respuestas enlatadas casi desaparecieron de aquí. Si vamos a gastar
-- en que hable, que hable él: el banco local queda para cuando NO hay presupuesto,
-- no como primera opción.

hashimon_alen = hashimon_alen or {}

hashimon_alen.CHAT_RANGE = 50
hashimon_alen.CHAT_PLAYER_COOLDOWN = 3   -- por jugador; corto, es una conversación
hashimon_alen.CONVO_MAX_REPLIES = 6      -- el presupuesto que pediste
hashimon_alen.CONVO_TIMEOUT = 90         -- silencio que cierra la conversación
hashimon_alen.CONVO_HISTORY = 3          -- turnos que se le recuerdan al modelo

local last_by_player = {}
local pending = false

--- Por qué contestó o no. "Me ignora" puede ser cinco cosas distintas y sin esto
--- no hay forma de saber cuál: se registra en el log y se ve en /alen status.
hashimon_alen.last_chat = nil
local function trace(who, msg, verdict, extra)
	hashimon_alen.last_chat = {
		who = who, msg = msg:sub(1, 60), verdict = verdict,
		extra = extra, at = core.get_gametime(),
	}
	core.log("action", string.format("[alen] chat de %s: %s%s | \"%s\"",
		who, verdict, extra and (" (" .. tostring(extra) .. ")") or "", msg:sub(1, 60)))
end

-- --------------------------------------------------------------------------
-- La conversación como unidad, con principio y final.
-- --------------------------------------------------------------------------

hashimon_alen.convo = nil

local function convo_alive()
	local c = hashimon_alen.convo
	if not c then return nil end
	if core.get_gametime() - (c.last_at or 0) > hashimon_alen.CONVO_TIMEOUT then
		hashimon_alen.convo = nil
		return nil
	end
	return c
end

local function convo_open(who)
	hashimon_alen.convo = {
		who = who, replies = 0, turns = {},
		started_at = core.get_gametime(), last_at = core.get_gametime(),
	}
	return hashimon_alen.convo
end

--- Cierra la conversación. `reason` acaba en el evento para que el planificador
--- sepa por qué terminó: aburrimiento, violencia o silencio son cosas distintas.
function hashimon_alen.convo_close(reason)
	local c = hashimon_alen.convo
	if not c then return end
	hashimon_alen.convo = nil
	if hashimon_alen.note_event then
		hashimon_alen.note_event("conversacion_terminada", c.who,
			{ motivo = reason, respuestas = c.replies })
	end
end

--- Una tabla Lua vacía se serializa como {} (objeto), NO como [] (array), y del
--- otro lado zod espera un array y rechaza la petición ENTERA. Es una trampa
--- permanente de este puente, así que los arrays vacíos se omiten.
local function or_nil(t)
	return (t and #t > 0) and t or nil
end

--- Sólo las últimas idas y venidas. Sin esto cada respuesta es una isla y por eso
--- se sentía tonta: contestaba sin recordar lo que acababa de decir.
local function history_for(c)
	local out, n = {}, #c.turns
	for i = math.max(1, n - hashimon_alen.CONVO_HISTORY * 2 + 1), n do
		out[#out + 1] = c.turns[i]
	end
	return out
end

-- --------------------------------------------------------------------------
-- Capa local, coste cero.
--
-- Un insulto directo no necesita que un modelo lo interprete, y sobre todo no
-- debe hacerle esperar dos segundos: ofenderse tarde no es ofenderse. Lo obvio se
-- resuelve aquí y al instante; lo ambiguo —que es donde de verdad hace falta
-- criterio— va al modelo, que además devuelve cuánto le tocó el ego.
-- --------------------------------------------------------------------------

local FAREWELL = { "^adi[oó]s", "^hasta luego", "^me voy", "^chao$", "^bye$", "^nos vemos" }

-- `ego` es cuánto hiere. Ser tratado como propiedad o recibir órdenes es peor que
-- un insulto a secas: lo primero le niega lo que es.
local OFFENSES = {
	{ pat = "eres m[ií]o", ego = -85 },
	{ pat = "me pertenec", ego = -85 },
	{ pat = "mascota", ego = -75 },
	{ pat = "obedece", ego = -70 },
	{ pat = "lagartija", ego = -70 },
	{ pat = "gusano", ego = -65 },
	{ pat = "tonto", ego = -60 },
	{ pat = "est[uú]pid", ego = -60 },
	{ pat = "idiota", ego = -60 },
	{ pat = "basura", ego = -60 },
	{ pat = "in[uú]til", ego = -55 },
	{ pat = "cobarde", ego = -55 },
	{ pat = "te voy a matar", ego = -45 },
	{ pat = "te matar[eé]", ego = -45 },
}

--- ¿Hay un insulto evidente? Devuelve el daño al ego, o nil.
function hashimon_alen.local_offense(msg)
	local low = msg:lower()
	local worst = nil
	for _, o in ipairs(OFFENSES) do
		if low:find(o.pat) then
			if not worst or o.ego < worst then worst = o.ego end
		end
	end
	return worst
end

function hashimon_alen.match_intent(msg)
	local low = msg:lower()
	local words = 0
	for _ in low:gmatch("%S+") do words = words + 1 end
	if words > 3 then return nil end
	for _, pat in ipairs(FAREWELL) do
		if low:find(pat) then return "despedida" end
	end
	return nil
end

-- --------------------------------------------------------------------------

--- ¿Se digna a contestar?
---
--- Del feedback de la tercera partida: "no siempre responde, algo de misterio
--- también es sexy... responde muy reactivo y eso lo hace lucir tonto". Un mensaje
--- largo siempre merece respuesta; un "eh" a un dragón de cuatro metros, no.
function hashimon_alen.should_engage(who, message, c)
	local words = 0
	for _ in message:gmatch("%S+") do words = words + 1 end

	if words >= 6 then return true end            -- se ha molestado en escribir
	if c and c.replies > 0 then return true end   -- conversación ya abierta
	if words <= 2 then
		-- Monosílabos a un dios: casi nunca.
		return math.random() < 0.12 * hashimon_alen.traits().vanity
	end
	local r = hashimon_alen.knows(who)
	local base = 0.3 + (r and (r.interest or 0) / 250 or 0)
	return math.random() < base * (0.6 + hashimon_alen.traits().vanity)
end

--- ¿Habla con modelo, o con lo que está escrito a mano?
---
--- Por defecto, escrito a mano. La decisión es de la sexta partida y es del
--- usuario, con sus palabras: "los argumentos de Alen son muy estúpidos, te dice
--- cosas muy artificiales... prefiero hacerlo yo con alma, con espíritu, y mejor
--- enfocarnos en su actuar lógico". El modelo seguía siendo correcto en las
--- MÉTRICAS y flojo en la VOZ, así que se separa lo uno de lo otro: el banco de
--- frases habla, y el modelo —cuando se enciende— sólo juzga.
---
--- Se enciende con `hashimon_alen_model_voice = true` en minetest.conf.
local function model_voice()
	return core.settings:get_bool("hashimon_alen_model_voice", false)
end
hashimon_alen.model_voice = model_voice

--- Respuesta escrita, sin red y sin tokens. Elige el banco por lo que ya sabe de
--- ti, que es información que el mod tiene entera y no necesita preguntarle a
--- nadie.
local function reply_offline(live, who, message)
	local r = hashimon_alen.knows(who)
	local grudge = r and r.grudge or 0
	local sentiment = r and r.sentiment or 0
	local tier = hashimon_alen.tier_toward(who)

	local cat
	if grudge >= 35 or tier.name == "WRATHFUL" then
		cat = "ON_ENRAGED"
	elseif tier.name == "ANGRY" then
		cat = "ON_WARN_ATTACK"
	elseif sentiment > 30 then
		cat = "ON_PLAYER_LIKED"
	elseif #message >= 40 then
		cat = "ON_CHAT_LONG"
	else
		cat = "ON_GREETED_COLD"
	end
	hashimon_alen.say(cat, { force = true }, { name = who })

	local pos = live.object:get_pos()
	local player = core.get_player_by_name(who)
	local pp = player and player:get_pos()
	if pos and pp then
		live.object:set_yaw(-math.atan2(pp.x - pos.x, pp.z - pos.z))
	end
end

local function bridge_ready()
	return hashimon and hashimon.alen_chat and hashimon.get_server_secret
		and hashimon.get_server_secret() ~= ""
end

local function ask_model(self, who, msg, dist, c)
	local player = core.get_player_by_name(who)
	local pos = self.object:get_pos()

	-- Encararlo mientras piensa. Son uno o dos segundos, y un dragón que gira la
	-- cabeza y luego habla se lee como que te escucha; uno inmóvil, como un fallo.
	if player and pos then
		local pp = player:get_pos()
		if pp then
			self.object:set_yaw(-math.atan2(pp.x - pos.x, pp.z - pos.z))
		end
	end

	pending = true
	local s = hashimon_alen.get_state()
	local r = hashimon_alen.knows(who) or {}
	-- OJO con el namespace: get_server_secret vive en `hashimon` (hashimon_core),
	-- no en `hashimon_alen`. bridge_ready() comprueba el correcto, así que un
	-- typo aquí pasaba la guarda y reventaba dos líneas después.
	hashimon.alen_chat(hashimon.get_server_secret(), {
		player = who,
		message = msg,
		distance = dist,
		mood = hashimon_alen.mood_label(),
		anger = math.floor(s.anger or 0),
		hp = math.floor(s.hp or 0),
		maxHp = hashimon_alen.MAX_HP,
		history = or_nil(history_for(c)),
		exchangesLeft = hashimon_alen.CONVO_MAX_REPLIES - c.replies,
		relation = {
			label = hashimon_alen.relation_label(who),
			grudge = math.floor(r.grudge or 0),
			respect = math.floor(r.respect or 0),
			sentiment = math.floor(r.sentiment or 0),
			interest = math.floor(r.interest or 0),
			timesSeen = r.times_seen or 0,
			lastEvent = r.last_event,
		},
	}, function(ok, err, reply, ap)
		pending = false
		local cc = hashimon_alen.convo
		local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
		if not ok then
			core.log("action", "[alen] chat sin respuesta: " .. tostring(err))
			hashimon_alen.say("ON_CHAT_BUSY", { force = true }, { name = who })
			return
		end

		-- Lo que el modelo JUZGÓ, aplicado al estado real. Aquí es donde una frase
		-- que no sonaba agresiva puede acabar en un ataque: el modelo decide que le
		-- hirió el ego, la métrica sube y la táctica hace el resto.
		if ap then
			hashimon_alen.alen_learn({
				kind = "appraised", who = who,
				ego = tonumber(ap.ego) or 0,
				interest = tonumber(ap.interest) or 0,
				respect = tonumber(ap.respect) or 0,
			})
		end

		-- Silencio deliberado: reply vacío con intent "ignore" no es un fallo, es
		-- una respuesta. Pero tiene que NOTARSE que te oyó: gira la cabeza hacia
		-- ti y calla. Ignorar sin ni siquiera mirar se lee como un bug.
		if reply and reply ~= "" then
			hashimon_alen.say_text(reply, { force = true })
		elseif live then
			local p2 = live.object:get_pos()
			local pl = core.get_player_by_name(who)
			local pp2 = pl and pl:get_pos()
			if p2 and pp2 then
				live.object:set_yaw(-math.atan2(pp2.x - p2.x, pp2.z - p2.z))
			end
		end

		local intent = ap and ap.intent or "speak"
		trace(who, msg, "respondió", string.format("intent=%s ego=%s%s",
			intent, ap and ap.ego or "?", (reply == "") and " SILENCIO" or ""))
		if live then
			if intent == "attack" then
				hashimon_alen.convo_close("ofendido")
				local target = core.get_player_by_name(who)
				if target then
					live._target = target
					live._tactic_acc = 99
					live._watch_until = nil
					-- Siempre avisa antes: la sentencia va delante del cubo.
					hashimon_alen.declare(live, "ON_WARN_ATTACK", { name = who })
					core.after(2.0, function()
						local l2 = hashimon_alen._live and hashimon_alen._live:get_luaentity()
						if l2 and target:get_pos() then
							hashimon_alen.begin_firecube(l2, target)
						end
					end)
				end
				if hashimon_alen.note_event then
					hashimon_alen.note_event("ofendido_por_conversacion", who,
						{ ego = ap and ap.ego or 0 })
				end
				return
			elseif intent == "leave" then
				hashimon_alen.convo_close("desinteres")
				live._depart_until = core.get_gametime() + 20
				return
			end
		end
		if cc and cc.who == who then
			cc.replies = cc.replies + 1
			cc.turns[#cc.turns + 1] = { role = "alen", text = reply }
			cc.last_at = core.get_gametime()
			-- Gastado el presupuesto, se despide y se va. Que la conversación
			-- tenga final es parte del personaje, no sólo del ahorro.
			if cc.replies >= hashimon_alen.CONVO_MAX_REPLIES then
				core.after(2.5, function()
					local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
					if not live then return end
					hashimon_alen.say("ON_CONVO_END", { force = true }, { name = who })
					live._depart_until = core.get_gametime() + 20
					hashimon_alen.convo_close("aburrimiento")
				end)
			end
		end
	end)
end

-- --------------------------------------------------------------------------

local function on_chat_body(name, message)
	-- Traza lo PRIMERO de todo. Antes había cuatro retornos silenciosos por
	-- delante y "no pasa nada" era indistinguible de "el handler ni se llamó".
	trace(name, message, "recibido")

	-- Nunca se traga el mensaje: siempre devuelve nil para que siga su curso.
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then
		trace(name, message, "sin entidad viva (Alen no está materializado)")
		return
	end
	if type(message) ~= "string" or #message < 2 or #message > 300 then
		trace(name, tostring(message), "mensaje descartado por longitud")
		return
	end

	local player = core.get_player_by_name(name)
	local pos = live.object:get_pos()
	if not player or not pos then
		trace(name, message, "sin jugador o sin posición")
		return
	end
	local pp = player:get_pos()
	if not pp then return end
	local dist = hashimon_alen.dist(pos, pp)
	if dist > hashimon_alen.CHAT_RANGE then
		trace(name, message, "fuera de rango", math.floor(dist) .. " > " .. hashimon_alen.CHAT_RANGE)
		return
	end

	local now = core.get_gametime()
	if now - (last_by_player[name] or -999) < hashimon_alen.CHAT_PLAYER_COOLDOWN then
		trace(name, message, "enfriamiento por jugador")
		return
	end
	last_by_player[name] = now

	if not hashimon_alen.get_state().awake then
		trace(name, message, "dormido")
		return
	end

	-- Hablarle cuenta como acercamiento pacífico: se puede llegar a caerle bien
	-- sólo conversando, y eso abre la vía pseudo-pacífica.
	hashimon_alen.alen_learn({ kind = "peaceful_approach", who = name })

	-- Un insulto evidente se resuelve AQUÍ y al instante: cero tokens y cero
	-- espera. Ofenderse dos segundos tarde no es ofenderse.
	local ego = hashimon_alen.local_offense(message)
	if ego then
		hashimon_alen.alen_learn({ kind = "appraised", who = name, ego = ego,
			interest = 5, respect = -10 })
		hashimon_alen.convo_close("insultado")
		live._target = player
		live._tactic_acc = 99
		hashimon_alen.declare(live, ego <= -70 and "ON_RAGE" or "ON_WARN_ATTACK",
			{ name = name })
		if hashimon_alen.note_event then
			hashimon_alen.note_event("insultado", name, { ego = ego })
		end
		trace(name, message, "OFENSA LOCAL", "ego " .. ego)
		return
	end

	local intent = hashimon_alen.match_intent(message)
	if intent == "despedida" then
		hashimon_alen.say("ON_FAREWELL", { force = true }, { name = name })
		hashimon_alen.convo_close("despedida")
		return
	end

	local c = convo_alive()
	if c and c.who ~= name then
		-- Está hablando con otro. No se atienden dos conversaciones a la vez.
		hashimon_alen.say("ON_CHAT_BUSY", { force = true }, { name = name })
		return
	end
	if not c then c = convo_open(name) end

	c.turns[#c.turns + 1] = { role = "player", text = message }
	c.last_at = now

	if c.replies >= hashimon_alen.CONVO_MAX_REPLIES then
		hashimon_alen.say("ON_CONVO_END", { force = true }, { name = name })
		hashimon_alen.convo_close("agotada")
		return
	end
	-- El misterio: no todo merece su voz. Si no se digna, te mira y ya.
	if not hashimon_alen.should_engage(name, message, c) then
		local pos2 = live.object:get_pos()
		if pos2 then
			live.object:set_yaw(-math.atan2(pp.x - pos2.x, pp.z - pos2.z))
		end
		trace(name, message, "no se digna (should_engage)")
		return
	end

	-- En mitad de una pelea no se conversa. Mecánicamente no cabe —no hay tiempo
	-- de escribir mientras te llueve fuego— y el resultado era una conversación
	-- lenta que parecía un bug. Si te está atacando, lo que recibes es una
	-- sentencia, no una charla.
	if live._fight or live._charging or live._dive_until then
		hashimon_alen.say("ON_WARN_ATTACK", { force = true }, { name = name })
		trace(name, message, "en combate: no conversa")
		return
	end

	if not model_voice() then
		reply_offline(live, name, message)
		trace(name, message, "voz local (modelo desactivado)")
		return
	end

	if pending then
		hashimon_alen.say("ON_CHAT_BUSY", { force = true }, { name = name })
		trace(name, message, "otra petición en vuelo")
		return
	end
	if not bridge_ready() then
		hashimon_alen.say("ON_CHAT_BUSY", { force = true }, { name = name })
		trace(name, message, "SIN PUENTE HTTP",
			"falta secure.http_mods / hashimon_api_url / hashimon_server_secret")
		return
	end

	trace(name, message, "al modelo")
	ask_model(live, name, message, dist, c)
end

--- El handler real, blindado.
---
--- Este callback está en la cadena de chat de TODO el servidor y va el primero,
--- así que un error aquí no rompe a Alen: rompe el chat de todo el mundo. Ya pasó
--- una vez (un namespace equivocado que la guarda no podía detectar), y por eso
--- el fallo se registra y se traga en vez de propagarse. Devuelve siempre nil.
local function on_chat(name, message)
	local ok, err = pcall(on_chat_body, name, message)
	if not ok then
		core.log("error", "[alen] fallo en el handler de chat (el mensaje sigue su curso): "
			.. tostring(err))
		trace(name, tostring(message), "ERROR INTERNO", tostring(err):sub(1, 120))
	end
	return nil
end

-- --------------------------------------------------------------------------
-- EL HANDLER VA EL PRIMERO DE LA CADENA, a propósito.
--
-- `towny_chat` (towny/towny_chat/init.lua) hace `return true` para cualquier
-- jugador que sea residente de un pueblo, y el motor corta la cadena de
-- on_chat_message en el primer `true`. Con Towny cargado, Alen no llegaba a
-- enterarse de que alguien le había hablado — y como los cuatro primeros
-- retornos eran silenciosos, parecía que simplemente te ignoraba.
--
-- Registrarse y luego moverse al frente es la única forma robusta: depender del
-- orden de carga de mods para esto es una bomba de relojería.
-- --------------------------------------------------------------------------
core.register_on_chat_message(on_chat)

core.register_on_mods_loaded(function()
	local list = core.registered_on_chat_messages
	for i, fn in ipairs(list) do
		if fn == on_chat then
			table.remove(list, i)
			table.insert(list, 1, on_chat)
			core.log("action", "[hashimon_alen] handler de chat movido al frente de la cadena"
				.. " (era el " .. i .. " de " .. #list + 1 .. ")")
			break
		end
	end
end)

core.log("action", "[hashimon_alen] chat activo (radio " .. hashimon_alen.CHAT_RANGE
	.. " nodos, " .. hashimon_alen.CONVO_MAX_REPLIES .. " respuestas por conversación)")
