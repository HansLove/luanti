-- /alen — herramientas de desarrollo. No hay ninguna ruta de spawn automática
-- todavía: mientras experimentamos, Alen nace y muere por mano de admin.

local function send(name, msg)
	core.chat_send_player(name, core.colorize("#F97316", "[Alen] ") .. msg)
end

core.register_privilege("alen", {
	description = "Controlar a Alen Gregory",
	give_to_singleplayer = true,
})

local function allowed(name)
	return core.check_player_privs(name, { alen = true })
		or core.check_player_privs(name, { server = true })
end

local subs = {}

subs.spawn = function(name, player, _rest)
	local pos = player:get_pos()
	local look = player:get_look_dir()
	local at = { x = pos.x + look.x * 20, y = pos.y + 16, z = pos.z + look.z * 20 }
	local ok, why = hashimon_alen.birth(at)
	if not ok then
		return false, "Ya existe un Alen (" .. why .. "). Sólo puede haber uno: /alen kill primero."
	end
	local obj, err = hashimon_alen.spawn_entity()
	if not obj then
		return false, "Ficha creada pero la entidad no: " .. tostring(err)
	end
	send(name, "Alen Gregory ha nacido.")
	return true
end

subs.kill = function(name, _player, _rest)
	hashimon_alen.despawn_entity()
	hashimon_alen.death("borrado por admin")
	send(name, "Alen retirado del mundo. La ficha queda muerta.")
	return true
end

subs.reset = function(name, _player, _rest)
	hashimon_alen.despawn_entity()
	hashimon_alen.reset_state()
	send(name, "Alen borrado a cero: ficha, memoria y plan.")
	return true
end

subs.here = function(name, player, _rest)
	local s = hashimon_alen.get_state()
	if not s.alive then
		return false, "Alen no vive. /alen spawn"
	end
	local pos = player:get_pos()
	s.pos = { x = pos.x, y = pos.y + 18, z = pos.z + 12 }
	hashimon_alen.save_state()
	hashimon_alen.despawn_entity()
	hashimon_alen.spawn_entity()
	send(name, "Traído a tu posición.")
	return true
end

subs.jump = function(name, _player, rest)
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then
		return false, "No hay entidad viva ahora mismo."
	end
	local x, y, z = rest:match("^(-?%d+)%s+(-?%d+)%s+(-?%d+)")
	local dest
	if x then
		dest = { x = tonumber(x), y = tonumber(y), z = tonumber(z) }
	else
		local why
		dest, why = hashimon_alen.find_jump_target(live.object:get_pos(), 60, 140, 16)
		if not dest then
			return false, "No encontré destino legal: " .. tostring(why)
		end
	end
	local ok, why = hashimon_alen.do_jump(live, dest, true)
	if not ok then
		return false, "Salto rechazado: " .. why
	end
	send(name, string.format("Saltó a (%.0f, %.0f, %.0f).", dest.x, dest.y, dest.z))
	return true
end

subs.size = function(name, _player, rest)
	local n = tonumber(rest:match("^([%d%.]+)"))
	if not n then
		return false, "Uso: /alen size <número>. Actual: " .. hashimon_alen.VISUAL_SIZE
	end
	hashimon_alen.VISUAL_SIZE = n
	local live = hashimon_alen._live
	if live and live:get_luaentity() then
		live:set_properties({ visual_size = { x = n, y = n, z = n } })
	end
	send(name, "visual_size = " .. n .. " (en caliente; escríbelo en body.lua si convence)")
	return true
end

subs.anim = function(name, _player, rest)
	local which = rest:match("^(%S+)")
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then
		return false, "No hay entidad viva."
	end
	if not which or not hashimon_alen.STATES[which] then
		local names = {}
		for k in pairs(hashimon_alen.STATES) do
			names[#names + 1] = k
		end
		table.sort(names)
		return false, "Uso: /alen anim <" .. table.concat(names, "|") .. ">"
	end
	local st = hashimon_alen.STATES[which]
	live._anim = nil
	live._oneshot_until = nil
	if st.once then
		hashimon_alen.play_oneshot(live, which, 0.1)
	else
		hashimon_alen.set_anim(live, which, 0.3)
	end
	local _clip, clip_name = hashimon_alen.resolve_clip(which)
	send(name, string.format("Estado %s -> clip %s%s", which, tostring(clip_name),
		clip_name ~= st.chain[1] and "  (alternativa: falta " .. st.chain[1] .. ")" or ""))
	return true
end

--- Preparar el escenario: probar a Alen "como si fuera nuevo", o con alguien a
--- quien odia, o a quien aprecia. Sin esto, cada prueba depende de lo que pasara
--- en la partida anterior.
subs.rel = function(name, _player, rest)
	local who, preset = rest:match("^(%S+)%s+(%S+)$")
	if not who then
		preset = rest:match("^(%S+)$")
		who = preset and name or nil
	end
	local presets = {}
	for k in pairs(hashimon_alen.DEBUG_RELATIONS) do presets[#presets + 1] = k end
	table.sort(presets)
	if not who or not hashimon_alen.DEBUG_RELATIONS[preset] then
		return false, "Uso: /alen rel [jugador] <" .. table.concat(presets, "|") .. ">"
	end
	hashimon_alen.debug_set_relation(who, preset)
	hashimon_alen.get_state().anger = (preset == "odia") and 70 or 0
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if live then
		live._fight, live._watch_until, live._depart_until = nil, nil, nil
		live._known_near = {}   -- fuerza un ENCUENTRO nuevo al siguiente tick
	end
	send(name, string.format("%s ahora es '%s' para Alen (%s) · escalón: %s",
		who, preset, hashimon_alen.relation_label(who),
		hashimon_alen.tier_toward(who).name))
	return true
end

subs.calm = function(name, _player, _rest)
	local s = hashimon_alen.get_state()
	-- Limpiar la IRA no basta: desde que el rencor manda tácticamente
	-- (tier_toward), alguien con rencor 80 sigue encontrándose a un Alen furioso
	-- por mucho que el humor esté a cero. Calmar de verdad es olvidar.
	local forgotten = 0
	for who in pairs(s.known_players or {}) do
		forgotten = forgotten + 1
	end
	s.known_players = {}
	s.last_attacker, s.last_damage_at = nil, nil
	s.anger, s.boredom, s.destruction_desire = 0, 0, 0
	s.energy = hashimon_alen.MAX_ENERGY
	s.hp = hashimon_alen.MAX_HP
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if live then
		live.hp = hashimon_alen.MAX_HP
		live._fight, live._depart_until, live._charging = nil, nil, nil
	end
	if live then live._known_near = {} end -- fuerza un encuentro nuevo
	send(name, string.format(
		"Alen calmado y a pleno: ira 0, energía y vida al máximo, %d relaciones olvidadas.",
		forgotten))
	return true
end

subs.locomotion = function(name, _player, _rest)
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then return false, "No hay entidad viva." end
	local out = function(l) core.chat_send_player(name, l) end

	out(core.colorize("#F97316", "── LOCOMOCIÓN ──"))
	out(string.format("  modo %s desde hace %.1fs · %s · compromiso %.1fs",
		tostring(live._loco_mode), core.get_gametime() - (live._loco_since or 0),
		live._airborne and "EN EL AIRE" or "EN TIERRA",
		hashimon_alen.MODE_COMMIT[live._loco_mode or ""] or 0))
	out(string.format("  suelo mínimo de vuelo: %s · ruta A* %s",
		live._landing and "DESACTIVADO (en tierra)" or "activo (5 nodos)",
		live._path and (#live._path .. " waypoints, en el " .. (live._path_i or 1)) or "ninguna"))

	local sc = live._loco_scores
	if not sc then
		out("  (todavía no ha puntuado: espera a que se mueva)")
		return true
	end
	local order = {}
	for m, r in pairs(sc) do order[#order + 1] = { m = m, s = r.score, t = r.terms } end
	table.sort(order, function(a, b) return a.s > b.s end)
	out(core.colorize("#F97316", "── UTILIDAD ──"))
	for i = 1, #order do
		out(string.format("  %-15s %6.1f", order[i].m, order[i].s))
	end
	-- El WHY: los términos del ganador SON el cálculo, no un registro aparte.
	local w = order[1]
	out(core.colorize("#F97316", "── WHY " .. w.m .. " ──"))
	local parts = {}
	table.sort(w.t, function(a, b) return math.abs(a.v) > math.abs(b.v) end)
	for i = 1, math.min(6, #w.t) do
		parts[#parts + 1] = string.format("%s %+.0f", w.t[i].name, w.t[i].v)
	end
	out("  " .. table.concat(parts, " · "))
	if order[2] then
		out(string.format("  gana a %s por %.1f (margen para cambiar: %d)",
			order[2].m, w.s - order[2].s, hashimon_alen.SWITCH_MARGIN))
	end
	return true
end

subs.loco = function(name, _player, rest)
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then return false, "No hay entidad viva." end
	local m = rest:match("^(%S+)")
	if not m or not hashimon_alen.SPEEDS[m] and m ~= "GROUND_IDLE" then
		return false, "Uso: /alen loco <WALK|GROUND_PURSUIT|FLY|FLY_FAST|CIRCLE|GROUND_IDLE>"
	end
	hashimon_alen.set_mode(live, m)
	send(name, "Modo forzado: " .. m .. " (la utilidad lo cambiará en cuanto pueda)")
	return true
end

subs.cube = function(name, player, _rest)
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then return false, "No hay entidad viva." end
	local ok, why = hashimon_alen.begin_firecube(live, player)
	if not ok then return false, "No salió: " .. tostring(why) end
	send(name, "Cargando el cubo contra ti. Apártate.")
	return true
end

subs.hit = function(name, _player, rest)
	-- Simula golpes para ver la escalada sin tener que pelear de verdad.
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then return false, "No hay entidad viva." end
	local n = tonumber(rest:match("^(%d+)")) or 1
	for _ = 1, n do
		live.on_punch(live, core.get_player_by_name(name), 1, nil, nil, 15)
	end
	send(name, n .. " golpe(s) simulado(s) de 15 de daño.")
	return true
end

subs.say = function(name, _player, rest)
	local cat = rest:match("^(%S+)")
	if not cat or not hashimon_alen.PHRASES[cat] then
		local ks = {}
		for k in pairs(hashimon_alen.PHRASES) do ks[#ks + 1] = k end
		table.sort(ks)
		send(name, "Categorías: " .. table.concat(ks, ", "))
		return true
	end
	if not hashimon_alen.say(cat, { force = true, global = true }) then
		return false, "No salió nada (¿categoría vacía?)."
	end
	return true
end

subs.frames = function(name, _player, _rest)
	local lines, missing = hashimon_alen.frame_report()
	send(name, missing == 0 and "Todos los estados tienen clip propio."
		or ("Faltan " .. missing .. " clips por autorar en Blender:"))
	for _, l in ipairs(lines) do
		core.chat_send_player(name, l)
	end
	return true
end

subs.orders = function(name, _player, _rest)
	if not (hashimon and hashimon.fetch_alen_orders) then
		return false, "hashimon_core no está cargado: no hay canal."
	end
	hashimon.fetch_alen_orders(hashimon.get_server_secret(), function(ok, err, list)
		if not ok then
			send(name, "Poll falló: " .. tostring(err))
			return
		end
		send(name, "Órdenes pendientes: " .. #(list or {}))
		for _, o in ipairs(list or {}) do
			local result, detail = hashimon_alen.apply_order(o)
			hashimon.ack_alen_order(hashimon.get_server_secret(), o.id, result, detail)
			send(name, string.format("  #%s -> %s (%s)", tostring(o.id), result, tostring(detail)))
		end
	end)
	return true
end

subs.report = function(name, _player, _rest)
	if not (hashimon and hashimon.push_alen_state) then
		return false, "hashimon_core no está cargado: no hay canal."
	end
	hashimon_alen.note_event("manual", name, { nota = "informe forzado" })
	send(name, "Informe forzado; llegará en el próximo ciclo (<= "
		.. hashimon_alen.REPORT_INTERVAL .. "s).")
	return true
end

--- El informe completo. Es la mitad del valor de esta fase: un Alen impredecible
--- que no se puede inspeccionar es un Alen que no se puede depurar.
subs.status = function(name, _player, _rest)
	local s = hashimon_alen.get_state()
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	local tr = hashimon_alen.traits()
	local tier = hashimon_alen.tier()
	local out = function(l) core.chat_send_player(name, l) end

	out(core.colorize("#F97316", "── ESTADO ──"))
	out(string.format("  vive %s · %s · entidad %s",
		tostring(s.alive), hashimon_alen.mood_label(),
		live and "instanciada" or "dormida (nadie mirando)"))
	if s.pos then
		out(string.format("  posición %.0f, %.0f, %.0f", s.pos.x, s.pos.y, s.pos.z))
	end
	out(string.format("  táctica %s · objetivo %s",
		live and (live.mode or "?") or "-",
		live and live._target and live._target:get_player_name() or "ninguno"))

	out(core.colorize("#F97316", "── FISIOLOGÍA ──"))
	out(string.format("  hp %d%%  energía %.0f/%d  fatiga %.0f  sueño %.0f (derivado)  %s",
		math.floor((s.hp or 0) / hashimon_alen.MAX_HP * 100),
		s.energy or 0, hashimon_alen.MAX_ENERGY, s.fatigue or 0,
		hashimon_alen.sleep_desire(), s.awake and "despierto" or "DORMIDO"))

	out(core.colorize("#F97316", "── EMOCIÓN ──"))
	out(string.format("  ira %.0f %s (vista %d · persecución %d · fuego %s)",
		s.anger or 0, tier.name, tier.sight, tier.pursuit, tier.fire))
	out(string.format("  aburrimiento %.0f · deseo de destruir %.0f",
		s.boredom or 0, s.destruction_desire or 0))

	-- El combate en curso: cuántos golpes lleva aguantados y cuánto le falta para
	-- el cubo. Es el WHY de la escalada.
	local f = live and live._fight
	out(core.colorize("#F97316", "── COMBATE ──"))
	if f then
		out(string.format("  contra %s · %d golpes · %d de daño acumulado",
			f.who, f.hits, math.floor(f.damage)))
		out(string.format("  furia: %d/%d %s", math.floor(f.damage),
			hashimon_alen.RAGE_DAMAGE,
			f.raged and "(YA ESTALLÓ en esta pelea)"
			or ("— faltan " .. math.max(0, math.ceil(hashimon_alen.RAGE_DAMAGE - f.damage)))))
		out(string.format("  siguiente frase: %s",
			hashimon_alen.attacked_category(f.hits + 1)))
	else
		out("  sin combate activo")
	end
	out(string.format("  energía: %s", hashimon_alen.energy_tier()))
	for _, an in ipairs({ "breath", "firecube" }) do
		local why = live and hashimon_alen.attack_blocked(live, an)
		out(string.format("  %-9s %s  (coste %d · mín %d · enfr %.1fs con esta ira)",
			an, why and ("BLOQUEADO: " .. why) or "disponible",
			hashimon_alen.ATTACKS[an].energy_cost,
			hashimon_alen.ATTACKS[an].min_energy,
			hashimon_alen.cooldown_for(an)))
	end
	if live and live._charging then
		out(core.colorize("#EF4444", "  ▸ CARGANDO EL CUBO"))
	end

	out(core.colorize("#F97316", "── RASGOS ──") .. " (constantes, derivados de la semilla)")
	out(string.format("  wrath %.2f  patience %.2f  vanity %.2f  curiosity %.2f  cruelty %.2f  pride %.2f",
		tr.wrath, tr.patience, tr.vanity, tr.curiosity, tr.cruelty, tr.pride))
	out(string.format("  vida media de la ira: %.0fs · del rencor: %.1fh · golpes ×%.2f",
		hashimon_alen.ANGER_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4),
		hashimon_alen.GRUDGE_HALF_LIFE * hashimon_alen.trait_mult("patience", 0.4) / 3600,
		hashimon_alen.trait_mult("wrath", 0.35)))

	-- Relaciones: sólo las que importan ahora mismo, ordenadas por rencor.
	local rels, n = {}, 0
	for who, r in pairs(s.known_players or {}) do
		n = n + 1
		rels[n] = { who = who, r = r }
	end
	table.sort(rels, function(a, b) return (a.r.grudge or 0) > (b.r.grudge or 0) end)
	out(core.colorize("#F97316", "── RELACIONES ──") .. string.format(" (%d conocidos, techo %d)",
		n, hashimon_alen.MAX_KNOWN_PLAYERS))
	for i = 1, math.min(4, n) do
		local who, r = rels[i].who, rels[i].r
		out(string.format("  %s [%s]  sentimiento %d · rencor %.0f%s · respeto %.0f · miedo %.0f · interés %.0f",
			who, hashimon_alen.relation_label(who),
			math.floor(r.sentiment or 0), r.grudge or 0,
			r.grudge_marked and " (cicatriz)" or "",
			r.respect or 0, r.fear or 0, r.interest or 0))
		out(string.format("     visto hace %ds · último: %s",
			os.time() - (r.last_seen or os.time()), tostring(r.last_event)))
	end
	if n == 0 then out("  no conoce a nadie todavía") end

	-- El WHY. Hoy explica la ira; con la fase 5 explicará la elección de objetivo
	-- con los términos de la utilidad y el contrafactual.
	out(core.colorize("#F97316", "── WHY ──"))
	if s.last_attacker and s.last_damage_at then
		local ago = os.time() - s.last_damage_at
		local rel = hashimon_alen.knows(s.last_attacker)
		out(string.format("  \"%s me golpeó hace %ds. Ira %.0f (%s), rencor %.0f.\"",
			s.last_attacker, ago, s.anger or 0, tier.name, rel and rel.grudge or 0))
	elseif (s.boredom or 0) > 50 then
		out("  \"Nada ha pasado en un rato: aburrimiento " .. math.floor(s.boredom) .. ".\"")
	else
		out("  \"Sin incidentes. Ira " .. math.floor(s.anger or 0) .. ", en calma.\"")
	end
	out("  (la explicación de objetivos llega con la utilidad, fase 5)")

	local lc = hashimon_alen.last_chat
	out(core.colorize("#F97316", "── ÚLTIMO MENSAJE RECIBIDO ──"))
	if lc then
		out(string.format("  %s hace %ds: \"%s\"", lc.who,
			core.get_gametime() - (lc.at or 0), lc.msg))
		out(string.format("  veredicto: %s%s", lc.verdict,
			lc.extra and ("  ·  " .. tostring(lc.extra)) or ""))
	else
		out("  nadie le ha hablado todavía")
	end
	local c2 = hashimon_alen.convo
	out(string.format("  conversación: %s", c2 and
		string.format("con %s · %d/%d respuestas", c2.who, c2.replies,
			hashimon_alen.CONVO_MAX_REPLIES) or "ninguna"))

	out(core.colorize("#F97316", "── MODELO ──"))
	out(string.format("  última puesta al día hace %ds · frases dichas localmente, sin coste",
		os.time() - (s.last_state_update_at or os.time())))
	return true
end

subs.state = function(name, _player, _rest)
	-- Resumen de una línea; /alen status es el informe completo.
	local s = hashimon_alen.get_state()
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	send(name, string.format("vive=%s  hp=%d/%d  %s  ira=%.0f %s  energía=%.0f  entidad=%s",
		tostring(s.alive), s.hp or 0, hashimon_alen.MAX_HP,
		hashimon_alen.mood_label(), s.anger or 0, hashimon_alen.tier().name,
		s.energy or 0, live and "instanciada" or "dormida (nadie mirando)"))
	if s.pos then
		send(name, string.format("  posición (%.0f, %.0f, %.0f)", s.pos.x, s.pos.y, s.pos.z))
	end
	if s.plan then
		send(name, string.format("  plan: verbo %d de %d", s.plan.i or 1, #s.plan.verbs))
	end
	send(name, "  /alen status para el informe completo")
	return true
end

--- Un plan escrito a mano, con la MISMA forma que traerá el servidor. Sirve para
--- probar el ejecutor de verbos antes de que exista el canal HTTP.
subs.plan = function(name, player, rest)
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if not live then
		return false, "No hay entidad viva."
	end
	if rest == "" or rest == "demo" then
		local p = player:get_pos()
		local ok, why = hashimon_alen.set_plan(live, {
			ttl = 240,
			verbs = {
				{ op = "say", text = "Te he encontrado." },
				{ op = "patrol_area", x = p.x, y = p.y + 20, z = p.z, radius = 35, minutes = 1 },
				{ op = "hunt", target = name, seconds = 45 },
				{ op = "say", text = "Suficiente. Por ahora." },
				{ op = "blockjump" },
			},
		})
		if not ok then
			return false, "Plan rechazado: " .. why
		end
		send(name, "Plan de demostración cargado (5 verbos).")
		return true
	end
	local ok, parsed = pcall(core.parse_json, rest)
	if not ok or type(parsed) ~= "table" then
		return false, "JSON inválido. Prueba /alen plan demo"
	end
	local good, why = hashimon_alen.set_plan(live, parsed)
	if not good then
		return false, "Plan rechazado: " .. why
	end
	send(name, "Plan aceptado.")
	return true
end

subs.clear = function(name, _player, _rest)
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	if live then
		hashimon_alen.clear_plan(live, "borrado por admin")
	end
	send(name, "Plan borrado; vuelve a comportamiento autónomo.")
	return true
end

core.register_chatcommand("alen", {
	params = "<status|locomotion|rel|calm|spawn|kill|reset|here|jump|cube|hit|loco|plan|clear|anim|frames|orders|report|say|size|state>",
	description = "Alen Gregory — control de desarrollo",
	func = function(name, param)
		if not allowed(name) then
			return false, "Requiere privilegio alen o server."
		end
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Jugador no encontrado."
		end
		local cmd, rest = param:match("^(%S*)%s*(.*)$")
		cmd = (cmd ~= "" and cmd) or "state"
		local fn = subs[cmd]
		if not fn then
			return false, "Subcomandos: " .. table.concat({
				"spawn", "kill", "reset", "here", "jump", "plan", "clear", "anim", "frames", "orders", "report", "size", "state", "status", "say",
			}, ", ")
		end
		return fn(name, player, rest or "")
	end,
})
