-- Town Desk — friendly formspec hub for founding, expanding, inviting, and ranks.
-- Opened by bare `/town` (and `/pueblo`). Chat subcommands stay as fallback.
-- MIT — Hashimon, 2026.

core.log("action", "[towny] loading desk.lua from " .. tostring(core.get_modpath(core.get_current_modname())))

local F = core.formspec_escape

towny.desk = towny.desk or {}
towny.desk.last_msg = towny.desk.last_msg or {}
towny.desk.pending_mayor = towny.desk.pending_mayor or {} -- [name] = target for confirm

local function is_officer(res)
	return res and res.has_flag
		and (res:has_flag(towny.RESIDENT_MAYOR) or res:has_flag(towny.RESIDENT_COMAYOR))
		and true or false
end

local function is_mayor(res)
	return res and res.has_flag and res:has_flag(towny.RESIDENT_MAYOR) and true or false
end

local function set_msg(name, msg)
	towny.desk.last_msg[name] = msg
end

local function pending_invites_for(player_name)
	local list = {}
	for i = 1, #(towny.town_array or {}) do
		local town = towny.town_array[i]
		if town.invites and town.invites[player_name] then
			list[#list + 1] = town.name
		end
	end
	return list
end

local function checklist(town)
	local blocks = #town
	local members = 0
	local has_comayor = false
	for _, res in pairs(town.members or {}) do
		members = members + 1
		if res.has_flag and towny.RESIDENT_COMAYOR and res:has_flag(towny.RESIDENT_COMAYOR)
			and not (res.has_flag and towny.RESIDENT_MAYOR and res:has_flag(towny.RESIDENT_MAYOR)) then
			has_comayor = true
		end
	end
	return {
		{ done = true, label = "Fundar el pueblo" },
		{ done = blocks >= 2, label = "Expandir 1 bloque (botón Expandir)" },
		{ done = members >= 2, label = "Invitar a un jugador (y que acepte)" },
		{ done = has_comayor, label = "Nombrar un co-alcalde (opcional)" },
	}
end

local function online_townless()
	local out = {}
	for _, player in ipairs(core.get_connected_players()) do
		local n = player:get_player_name()
		local res = towny.residents[n]
		if res and not res.town then
			out[#out + 1] = n
		end
	end
	table.sort(out)
	return out
end

--- Public: show the Town Desk formspec for a player.
function towny.desk.show(name, page)
	page = page or "main"
	local res = towny.residents[name]
	if not res then
		core.chat_send_player(name, "Cargando residente… reintenta /town en un momento.")
		return
	end

	local fs = { "formspec_version[4]", "size[11,9.2]" }
	local msg = towny.desk.last_msg[name]
	local y = 0.35

	local function label(text)
		fs[#fs + 1] = string.format("label[0.4,%.2f;%s]", y, F(text))
		y = y + 0.4
	end

	-- Confirm mayor transfer (dedicated page)
	if page == "confirm_mayor" then
		local target = towny.desk.pending_mayor[name]
		local town = res.town
		if not target or not town or not is_mayor(res) then
			towny.desk.pending_mayor[name] = nil
			return towny.desk.show(name, "main")
		end
		fs[#fs + 1] = string.format("label[0.4,0.4;%s]", F("Transferir alcaldía"))
		fs[#fs + 1] = string.format(
			"label[0.4,1.0;%s]",
			F(string.format("Vas a hacer alcalde a '%s'. Tú quedarás como co-alcalde.", target))
		)
		fs[#fs + 1] = string.format(
			"label[0.4,1.6;%s]",
			F(string.format("Escribe el nombre exacto del pueblo (%s) para confirmar:", town.name))
		)
		fs[#fs + 1] = "field[0.4,2.2;6.5,0.7;confirm_name;;]"
		fs[#fs + 1] = "field_close_on_enter[confirm_name;false]"
		fs[#fs + 1] = "button[0.4,3.2;3.2,0.7;do_transfer;Confirmar]"
		fs[#fs + 1] = "button[3.8,3.2;2.4,0.7;cancel_transfer;Cancelar]"
		if msg then
			fs[#fs + 1] = string.format("label[0.4,4.2;%s]", F(msg))
		end
		core.show_formspec(name, "towny:desk", table.concat(fs))
		return
	end

	-- No town: foundation + incoming invites
	if not res.town then
		fs[#fs + 1] = "label[0.4,0.4;Pueblo — Escritorio]"
		fs[#fs + 1] = "label[0.4,0.95;Aún no perteneces a un pueblo.]"
		fs[#fs + 1] = "label[0.4,1.45;Fundar (de pie en tierra libre, lejos de otros pueblos):]"
		fs[#fs + 1] = "field[0.4,1.9;5.5,0.7;town_name;;]"
		fs[#fs + 1] = "field_close_on_enter[town_name;false]"
		fs[#fs + 1] = "button[6.1,1.9;2.8,0.7;found;Fundar]"

		local invs = pending_invites_for(name)
		y = 3.0
		label("Invitaciones recibidas:")
		if #invs == 0 then
			label("(ninguna — pide a un alcalde que te invite)")
		else
			for i, tname in ipairs(invs) do
				local row = 3.4 + (i - 1) * 0.75
				fs[#fs + 1] = string.format("label[0.6,%.2f;%s]", row + 0.2, F(tname))
				fs[#fs + 1] = string.format("button[5.5,%.2f;2.2,0.65;accept_%d;Aceptar]", row, i)
				fs[#fs + 1] = string.format("button[7.9,%.2f;2.2,0.65;deny_%d;Rechazar]", row, i)
			end
			towny.desk._invite_list = towny.desk._invite_list or {}
			towny.desk._invite_list[name] = invs
		end
		if msg then
			fs[#fs + 1] = string.format("label[0.4,8.2;%s]", F(msg))
		end
		fs[#fs + 1] = "button_exit[8.5,8.5;2.0,0.55;close;Cerrar]"
		core.show_formspec(name, "towny:desk", table.concat(fs))
		return
	end

	-- Has town
	local town = res.town
	local officer = is_officer(res)
	local mayor = is_mayor(res)

	fs[#fs + 1] = string.format("label[0.4,0.35;%s]", F("Pueblo — " .. town.name))
	fs[#fs + 1] = string.format(
		"label[0.4,0.85;%s]",
		F(string.format("%d bloques · alcalde/co pueden expandir e invitar", #town))
	)

	-- Checklist
	local steps = checklist(town)
	fs[#fs + 1] = "label[0.4,1.3;Objetivos del pueblo:]"
	for i, step in ipairs(steps) do
		local mark = step.done and "[x]" or "[ ]"
		fs[#fs + 1] = string.format(
			"label[0.55,%.2f;%s]",
			1.65 + (i - 1) * 0.32,
			F(mark .. " " .. step.label)
		)
	end

	-- Officer actions
	local ay = 3.1
	if officer then
		fs[#fs + 1] = string.format("button[0.4,%.2f;2.6,0.65;expand;Expandir]", ay)
		fs[#fs + 1] = string.format("button[3.15,%.2f;2.6,0.65;borders;Bordes]", ay)
		fs[#fs + 1] = string.format("button[5.9,%.2f;2.6,0.65;capital;Capital]", ay)
		ay = ay + 0.85
		fs[#fs + 1] = string.format("label[0.4,%.2f;Invitar jugador (sin pueblo):]", ay)
		ay = ay + 0.4
		fs[#fs + 1] = string.format("field[0.4,%.2f;4.5,0.65;invite_name;;]", ay)
		fs[#fs + 1] = "field_close_on_enter[invite_name;false]"
		fs[#fs + 1] = string.format("button[5.1,%.2f;2.4,0.65;invite;Invitar]", ay)
		ay = ay + 0.75
		local near = online_townless()
		if #near > 0 then
			fs[#fs + 1] = string.format(
				"label[0.4,%.2f;%s]",
				ay,
				F("Online sin pueblo: " .. table.concat(near, ", "))
			)
			ay = ay + 0.4
		end
	else
		fs[#fs + 1] = string.format("button[0.4,%.2f;2.6,0.65;borders;Bordes]", ay)
		fs[#fs + 1] = string.format("button[3.15,%.2f;2.6,0.65;capital;Capital]", ay)
		ay = ay + 0.85
		fs[#fs + 1] = string.format(
			"label[0.4,%.2f;%s]",
			ay,
			F("Solo alcalde/co-alcalde expanden e invitan.")
		)
		ay = ay + 0.45
	end

	-- Roster
	fs[#fs + 1] = string.format("label[0.4,%.2f;Miembros:]", ay)
	ay = ay + 0.35
	local roster = {}
	for mname, mres in pairs(town.members or {}) do
		local rank = "residente"
		if mres.has_flag and towny.RESIDENT_MAYOR and mres:has_flag(towny.RESIDENT_MAYOR) then
			rank = "alcalde"
		elseif mres.has_flag and towny.RESIDENT_COMAYOR and mres:has_flag(towny.RESIDENT_COMAYOR) then
			rank = "co-alcalde"
		end
		roster[#roster + 1] = { name = mname, rank = rank, res = mres }
	end
	table.sort(roster, function(a, b) return a.name:lower() < b.name:lower() end)
	towny.desk._roster = towny.desk._roster or {}
	towny.desk._roster[name] = roster

	local list_h = math.min(2.8, 0.55 * math.max(#roster, 1))
	fs[#fs + 1] = string.format("scroll_container[0.3,%.2f;10.4,%.2f;roster_scroll;vertical;0.1]", ay, list_h)
	local ry = 0.05
	for i, m in ipairs(roster) do
		fs[#fs + 1] = string.format("label[0.1,%.2f;%s]", ry + 0.15, F(m.name .. " — " .. m.rank))
		if mayor and m.rank ~= "alcalde" then
			if m.rank == "co-alcalde" then
				fs[#fs + 1] = string.format("button[5.2,%.2f;2.3,0.5;demote_%d;Quitar co]", ry, i)
			else
				fs[#fs + 1] = string.format("button[5.2,%.2f;2.3,0.5;promote_%d;Co-alcalde]", ry, i)
			end
			fs[#fs + 1] = string.format("button[7.6,%.2f;1.4,0.5;kick_%d;Echar]", ry, i)
			fs[#fs + 1] = string.format("button[9.1,%.2f;1.1,0.5;mayor_%d;Alcalde]", ry, i)
		elseif officer and not mayor and m.rank == "residente" then
			fs[#fs + 1] = string.format("button[7.6,%.2f;1.4,0.5;kick_%d;Echar]", ry, i)
		end
		ry = ry + 0.55
	end
	fs[#fs + 1] = "scroll_container_end[]"
	ay = ay + list_h + 0.25

	-- Sent invites
	if officer then
		local sent = {}
		for iname in pairs(town.invites or {}) do
			sent[#sent + 1] = iname
		end
		table.sort(sent)
		towny.desk._sent = towny.desk._sent or {}
		towny.desk._sent[name] = sent
		if #sent > 0 then
			fs[#fs + 1] = string.format(
				"label[0.4,%.2f;%s]",
				ay,
				F("Invitaciones enviadas: " .. table.concat(sent, ", "))
			)
			ay = ay + 0.35
			fs[#fs + 1] = string.format("button[0.4,%.2f;3.0,0.55;revoke_all;Revocar todas]", ay)
			ay = ay + 0.65
		end
	end

	if not mayor then
		fs[#fs + 1] = string.format("button[0.4,%.2f;2.4,0.55;leave;Salir del pueblo]", ay)
	end

	if msg then
		fs[#fs + 1] = string.format("label[0.4,8.35;%s]", F(msg))
	end
	fs[#fs + 1] = "button_exit[8.5,8.55;2.0,0.5;close;Cerrar]"
	core.show_formspec(name, "towny:desk", table.concat(fs))
end

local function do_found(name, town_name)
	town_name = (town_name or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if town_name == "" then
		set_msg(name, "Escribe un nombre para el pueblo.")
		return
	end
	-- Reuse chat command path for distance / claim checks
	local ok, err = core.registered_chatcommands["town"].func(name, "new " .. town_name)
	if ok then
		set_msg(name, err or "Pueblo fundado.")
	else
		set_msg(name, err or "No se pudo fundar.")
	end
end

local function do_expand(name)
	local cmd = core.registered_chatcommands["expand"]
	if not cmd then
		set_msg(name, "Mod expand no cargado.")
		return
	end
	local ok, err = cmd.func(name, "")
	set_msg(name, err or (ok and "Expandido." or "Falló expandir."))
end

local function do_invite(name, target)
	target = (target or ""):gsub("^%s+", ""):gsub("%s+$", "")
	if target == "" then
		set_msg(name, "Escribe el nombre del jugador.")
		return
	end
	local ok, err = core.registered_chatcommands["town"].func(name, "invite " .. target)
	set_msg(name, err or (ok and ("Invitación enviada a " .. target) or "Falló invitar."))
end

local function transfer_mayor(actor_name, target_name)
	local actor = towny.residents[actor_name]
	local town = actor and actor.town
	if not town or not is_mayor(actor) then
		return false, "Solo el alcalde puede transferir la alcaldía."
	end
	local target = town.members[target_name]
	if not target then
		return false, "Ese jugador no está en tu pueblo."
	end
	if target_name == actor_name then
		return false, "Ya eres el alcalde."
	end
	actor:remove_flag(towny.RESIDENT_MAYOR)
	actor:add_flag(towny.RESIDENT_COMAYOR)
	if target.has_flag and towny.RESIDENT_COMAYOR then
		target:remove_flag(towny.RESIDENT_COMAYOR)
	end
	target:add_flag(towny.RESIDENT_MAYOR)
	towny.dirty = true
	towny.chat_send_town(town, actor_name .. " transfirió la alcaldía a " .. target_name .. ".")
	return true, "Alcaldía transferida. Ahora eres co-alcalde."
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "towny:desk" then
		return
	end
	local name = player:get_player_name()
	if fields.close or fields.quit then
		return
	end

	towny.dirty = true

	if fields.cancel_transfer then
		towny.desk.pending_mayor[name] = nil
		set_msg(name, "Transferencia cancelada.")
		towny.desk.show(name, "main")
		return
	end

	if fields.do_transfer then
		local pending = towny.desk.pending_mayor[name]
		local res = towny.residents[name]
		local town = res and res.town
		local typed = (fields.confirm_name or ""):gsub("^%s+", ""):gsub("%s+$", "")
		if not pending or not town then
			set_msg(name, "Nada que confirmar.")
			towny.desk.show(name, "main")
			return
		end
		if typed ~= town.name then
			set_msg(name, "El nombre del pueblo no coincide.")
			towny.desk.show(name, "confirm_mayor")
			return
		end
		local ok, err = transfer_mayor(name, pending)
		towny.desk.pending_mayor[name] = nil
		set_msg(name, err)
		towny.desk.show(name, "main")
		return
	end

	if fields.found then
		do_found(name, fields.town_name)
		towny.desk.show(name, "main")
		return
	end

	if fields.expand then
		do_expand(name)
		towny.desk.show(name, "main")
		return
	end

	if fields.borders then
		local cmd = core.registered_chatcommands["border"]
		if cmd then
			local ok, err = cmd.func(name, "")
			set_msg(name, err or "Bordes.")
		else
			set_msg(name, "Mod border no cargado.")
		end
		towny.desk.show(name, "main")
		return
	end

	if fields.capital then
		local cmd = core.registered_chatcommands["nation"]
		if cmd then
			local ok, err = cmd.func(name, "home")
			set_msg(name, err or "Capital.")
		else
			-- Fallback: town spawn
			local ok, err = core.registered_chatcommands["town"].func(name, "spawn")
			set_msg(name, err or "Spawn del pueblo.")
		end
		towny.desk.show(name, "main")
		return
	end

	if fields.invite then
		do_invite(name, fields.invite_name)
		towny.desk.show(name, "main")
		return
	end

	if fields.revoke_all then
		local ok, err = core.registered_chatcommands["town"].func(name, "invite revoke all")
		set_msg(name, err or "Invitaciones revocadas.")
		towny.desk.show(name, "main")
		return
	end

	if fields.leave then
		local ok, err = core.registered_chatcommands["town"].func(name, "leave")
		set_msg(name, err or "Saliste del pueblo.")
		towny.desk.show(name, "main")
		return
	end

	-- Accept / deny incoming invites
	local invs = towny.desk._invite_list and towny.desk._invite_list[name]
	if invs then
		for i, tname in ipairs(invs) do
			if fields["accept_" .. i] then
				local ok, err = core.registered_chatcommands["resident"].func(
					name, "invite accept " .. tname)
				set_msg(name, err or ("Te uniste a " .. tname))
				towny.desk.show(name, "main")
				return
			end
			if fields["deny_" .. i] then
				local ok, err = core.registered_chatcommands["resident"].func(
					name, "invite deny " .. tname)
				set_msg(name, err or "Invitación rechazada.")
				towny.desk.show(name, "main")
				return
			end
		end
	end

	-- Roster actions
	local roster = towny.desk._roster and towny.desk._roster[name]
	if roster then
		for i, m in ipairs(roster) do
			if fields["promote_" .. i] then
				local ok, err = core.registered_chatcommands["town"].func(
					name, "rank add " .. m.name .. " comayor")
				set_msg(name, err or (m.name .. " es co-alcalde."))
				towny.desk.show(name, "main")
				return
			end
			if fields["demote_" .. i] then
				local ok, err = core.registered_chatcommands["town"].func(
					name, "rank remove " .. m.name .. " comayor")
				set_msg(name, err or (m.name .. " ya no es co-alcalde."))
				towny.desk.show(name, "main")
				return
			end
			if fields["kick_" .. i] then
				local ok, err = core.registered_chatcommands["town"].func(name, "kick " .. m.name)
				set_msg(name, err or ("Expulsado: " .. m.name))
				towny.desk.show(name, "main")
				return
			end
			if fields["mayor_" .. i] then
				towny.desk.pending_mayor[name] = m.name
				set_msg(name, nil)
				towny.desk.show(name, "confirm_mayor")
				return
			end
		end
	end
end)

------------------------------------------------------------------------
-- Keybind: Space+Z (jump+zoom). No Shift (sneak) and no E (aux1) —
-- those are taken by powers / sprint / baby pose. Luanti server mods
-- cannot bind arbitrary letters (P, T, …); only control bits exist.
------------------------------------------------------------------------
towny.desk.keybind_enabled = true
towny.desk._key_held = towny.desk._key_held or {}
towny.desk._key_cd = towny.desk._key_cd or {} -- [name] = last open time

local KEY_COOLDOWN = 0.8

core.register_globalstep(function(_dtime)
	if not towny.desk.keybind_enabled then
		return
	end
	local now = core.get_us_time() / 1e6
	for _, player in ipairs(core.get_connected_players()) do
		local name = player:get_player_name()
		local ctrl = player:get_player_control()
		-- Jump + Zoom only. Explicitly NOT sneak, NOT aux1.
		local combo = ctrl.jump and ctrl.zoom
			and not ctrl.sneak and not ctrl.aux1
			and not ctrl.dig and not ctrl.place
		local was = towny.desk._key_held[name]
		towny.desk._key_held[name] = combo
		if not combo or was then
			-- need rising edge
		elseif hashimon and hashimon.mounts and hashimon.mounts[name] then
			-- mounted jump/zoom can be mobility — don't steal it
		else
			local last = towny.desk._key_cd[name] or 0
			if now - last >= KEY_COOLDOWN then
				towny.desk._key_cd[name] = now
				towny.desk.show(name, "main")
			end
		end
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player:get_player_name()
	towny.desk._key_held[name] = nil
	towny.desk._key_cd[name] = nil
end)

core.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	core.after(4, function()
		if core.get_player_by_name(name) then
			core.chat_send_player(name,
				"[Pueblo] Espacio+Z abre el Escritorio del pueblo (sin Shift ni E). También /town.")
		end
	end)
end)

core.log("action", "[towny] Town Desk loaded — Space+Z / /town / /pueblo open the panel.")
