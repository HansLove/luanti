-- El canal de órdenes: cómo Alen se vuelve actualizable desde el servidor.
--
-- Es el patrón de hashimon_towny_sync, literalmente: poll → REVALIDAR → aplicar →
-- acusar. La API pide; el mundo decide. Un plan que llega con un verbo que no
-- está en la lista blanca, o un salto encima de un jugador, se rechaza aquí y el
-- motivo exacto viaja de vuelta en el ack. Sin ese motivo el planificador del
-- otro lado nunca aprende.
--
-- Y el reparto de relojes, que es lo que abarata todo:
--   ~20 Hz  el tick de la entidad          — jamás toca la red
--   30 s    este poll                      — una petición para todo el mundo
--   minutos el planificador del servidor   — despertado por novedades, no por reloj

hashimon_alen = hashimon_alen or {}

hashimon_alen.ORDERS_INTERVAL = 30.0
hashimon_alen.REPORT_INTERVAL = 30.0

local orders_acc, orders_busy = 0, false
local report_acc, report_busy = 0, false

-- Cola local de novedades. Se llena desde el comportamiento y se vacía en cada
-- informe. Está acotada a propósito: si algo genera eventos en bucle, preferimos
-- perder los viejos a mandar mil y pagarlos.
local pending_events = {}
local MAX_EVENTS = 20

function hashimon_alen.note_event(kind, actor, payload)
	if #pending_events >= MAX_EVENTS then
		table.remove(pending_events, 1)
	end
	pending_events[#pending_events + 1] = {
		kind = kind,
		actor = actor,
		payload = payload,
	}
end

local function bridge_ready()
	return hashimon
		and hashimon.fetch_alen_orders
		and hashimon.get_server_secret
		and hashimon.get_server_secret() ~= nil
end

-- ---------------------------------------------------------------------------
-- Aplicar una orden: la revalidación contra el mundo real.
-- ---------------------------------------------------------------------------

--- Devuelve "applied"|"rejected", detalle.
function hashimon_alen.apply_order(o)
	if type(o) ~= "table" or type(o.plan) ~= "table" then
		return "rejected", "orden_malformada"
	end

	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then
		-- Sin observadores Alen no es una entidad, sólo una coordenada. Una orden
		-- de comportamiento no tiene dónde aplicarse. Se rechaza en vez de
		-- encolarse para que el planificador lo sepa: el informe ya le dice
		-- `observed: false`, así que mandarla fue su error, no una carrera.
		return "rejected", "dormido"
	end

	if live._jump_at then
		return "rejected", "cargando_salto"
	end

	-- La lista blanca de verbos vive en Lua y es la que manda. La API valida
	-- también, pero por cortesía: aquí es donde se decide.
	local ok, why = hashimon_alen.set_plan(live, o.plan)
	if not ok then
		return "rejected", why
	end

	return "applied", string.format("%d verbos, ttl %ds",
		#o.plan.verbs, o.plan.ttl or 300)
end

core.register_globalstep(function(dtime)
	if not bridge_ready() then
		return
	end
	orders_acc = orders_acc + dtime
	if orders_acc < hashimon_alen.ORDERS_INTERVAL then
		return
	end
	orders_acc = 0
	if orders_busy then
		return
	end

	-- Sin entidad viva no hay a quién dar órdenes, y no gastamos ni la petición.
	if not (hashimon_alen._live and hashimon_alen._live:get_luaentity()) then
		return
	end

	orders_busy = true
	hashimon.fetch_alen_orders(hashimon.get_server_secret(), function(ok, _err, list)
		orders_busy = false
		if not ok then
			return
		end
		for _, o in ipairs(list or {}) do
			local result, detail = hashimon_alen.apply_order(o)
			hashimon.ack_alen_order(hashimon.get_server_secret(), o.id, result, detail)
			core.log("action", string.format("[alen] orden %s: %s (%s)",
				tostring(o.id), result, tostring(detail)))
			if result == "applied" then
				break -- un plan a la vez; el resto espera al siguiente poll
			end
		end
	end)
end)

-- ---------------------------------------------------------------------------
-- El informe: estado comprimido + novedades.
--
-- Comprimido a propósito. Al planificador no le sirve el estado bruto del mundo,
-- le sirven ~200 tokens de números: banda de vida, hora, quién está delante y si
-- lo conoce, qué plan lleva y por qué falló. Prosa aquí es dinero tirado.
-- ---------------------------------------------------------------------------

local function hp_band(hp)
	local f = hp / hashimon_alen.MAX_HP
	if f > 0.66 then return "alto" elseif f > 0.33 then return "medio" else return "bajo" end
end

local function build_digest(live, s)
	local d = {
		hp = hp_band(s.hp or 0),
		modo = live and (live.mode or "?") or "dormido",
		hora = math.floor((core.get_timeofday() or 0) * 24),
	}
	if live then
		local pos = live.object:get_pos()
		local cerca = {}
		for _, player in ipairs(core.get_connected_players()) do
			local pp = player:get_pos()
			if pp then
				local dist = hashimon_alen.dist(pos, pp)
				if dist <= hashimon_alen.SIGHT then
					local name = player:get_player_name()
					local m = hashimon_alen.knows(name)
					cerca[#cerca + 1] = {
						nombre = name,
						dist = math.floor(dist),
						conocido = m ~= nil,
						ultima = m and m.last or nil,
					}
				end
			end
		end
		-- Un array vacío de Lua serializa como null, no como []. El planificador
		-- necesita un número que siempre esté ahí para saber si hay público.
		d.n_jugadores = #cerca
		d.jugadores = #cerca > 0 and cerca or nil
		if live.plan then
			d.plan = { verbo = live.plan.i, de = #live.plan.verbs }
		end
	end
	return d
end

core.register_globalstep(function(dtime)
	if not bridge_ready() or not hashimon.push_alen_state then
		return
	end
	report_acc = report_acc + dtime
	if report_acc < hashimon_alen.REPORT_INTERVAL then
		return
	end
	report_acc = 0
	if report_busy then
		return
	end

	local s = hashimon_alen.get_state()
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()

	-- Nada que contar y nada nuevo: no se manda la petición. Un mundo vacío con
	-- Alen dormido no genera tráfico ni coste.
	if not s.alive and #pending_events == 0 then
		return
	end

	local events = pending_events
	pending_events = {}

	report_busy = true
	hashimon.push_alen_state(hashimon.get_server_secret(), {
		alive = s.alive and true or false,
		pos = s.pos,
		hp = math.floor(s.hp or 0),
		maxHp = hashimon_alen.MAX_HP,
		mood = s.mood,
		observed = live ~= nil,
		digest = build_digest(live, s),
		events = events,
	}, function(ok, _err)
		report_busy = false
		if not ok then
			-- Se devuelven a la cola: una novedad perdida es una decisión que el
			-- planificador nunca llega a tomar.
			for i = #events, 1, -1 do
				table.insert(pending_events, 1, events[i])
			end
		end
	end)
end)

core.log("action", "[hashimon_alen] canal de órdenes activo (poll "
	.. hashimon_alen.ORDERS_INTERVAL .. "s, informe " .. hashimon_alen.REPORT_INTERVAL .. "s)")
