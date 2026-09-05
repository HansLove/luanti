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

subs.state = function(name, _player, _rest)
	local s = hashimon_alen.get_state()
	local live = hashimon_alen._live and hashimon_alen._live:get_luaentity()
	send(name, string.format("vive=%s  hp=%d/%d  humor=%s  entidad=%s",
		tostring(s.alive), s.hp or 0, hashimon_alen.MAX_HP,
		tostring(s.mood), live and "instanciada" or "dormida (nadie mirando)"))
	if s.pos then
		send(name, string.format("  posición (%.0f, %.0f, %.0f)", s.pos.x, s.pos.y, s.pos.z))
	end
	if s.plan then
		send(name, string.format("  plan: verbo %d de %d", s.plan.i or 1, #s.plan.verbs))
	end
	local known = {}
	for who, m in pairs(s.memory or {}) do
		known[#known + 1] = string.format("%s(x%d,%s)", who, m.met, tostring(m.last))
	end
	if #known > 0 then
		send(name, "  recuerda: " .. table.concat(known, ", "))
	end
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
	params = "<spawn|kill|reset|here|jump|plan|clear|anim|frames|orders|report|size|state>",
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
				"spawn", "kill", "reset", "here", "jump", "plan", "clear", "anim", "frames", "orders", "report", "size", "state",
			}, ", ")
		end
		return fn(name, player, rest or "")
	end,
})
