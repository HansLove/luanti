-- Session token storage and /hashimon chat commands.
-- Owners (web register) auto-bind on join; guests explore without ownership.

hashimon = hashimon or {}

local TOKEN_META_KEY = "hashimon:token"

hashimon.on_roster_synced = hashimon.on_roster_synced or {}

function hashimon.register_roster_callback(fn)
	table.insert(hashimon.on_roster_synced, fn)
end

function hashimon.notify_roster(player_name, roster)
	for _, fn in ipairs(hashimon.on_roster_synced) do
		fn(player_name, roster)
	end
end

function hashimon.get_token(player)
	return player:get_meta():get_string(TOKEN_META_KEY)
end

function hashimon.set_token(player, token)
	player:get_meta():set_string(TOKEN_META_KEY, token or "")
end

function hashimon.clear_token(player)
	hashimon.set_token(player, "")
end

function hashimon.has_token(player)
	local token = hashimon.get_token(player)
	return token ~= nil and token ~= ""
end

local function send(player_name, msg)
	core.chat_send_player(player_name, "[Hashimon] " .. msg)
end

function hashimon.sync_player(player)
	local player_name = player:get_player_name()
	local token = hashimon.get_token(player)
	if token == "" then
		send(player_name, "No owner session. Register at " .. hashimon.get_register_url()
			.. " to own a Hashimon, then log in with the same name/password.")
		return
	end

	send(player_name, "Syncing roster from " .. hashimon.get_api_url() .. " ...")

	hashimon.fetch_hashimons(token, function(ok, err, roster)
		if not ok then
			if err == "unauthorized" then
				send(player_name, "Token expired. Rejoining will re-bind if you are a web owner.")
				hashimon.clear_token(player)
			else
				send(player_name, "Sync failed: " .. hashimon.http_error_message(err))
			end
			return
		end

		send(player_name, "Loaded " .. #roster .. " Hashimon(s).")
		if #roster == 0 then
			send(player_name, "Roster empty — complete web registration to receive your genesis starter.")
		end
		hashimon.notify_roster(player_name, roster)
	end)
end

local function bind_owner_session(player)
	local player_name = player:get_player_name()
	local secret = hashimon.get_server_secret()
	if secret == "" then
		send(player_name, "Server missing hashimon_server_secret — cannot bind owner session.")
		return
	end
	send(player_name, "Binding Hashimon owner session...")
	hashimon.luanti_bind(secret, player_name, function(ok, err, body)
		if not player:is_player() then
			return
		end
		if not ok then
			if err == "cannot_own" or err == "not_found" then
				hashimon.clear_token(player)
				send(player_name, "Guest mode: you can explore, but cannot own Hashimons. Register at "
					.. hashimon.get_register_url())
			else
				send(player_name, "Bind failed: " .. hashimon.http_error_message(err))
			end
			return
		end
		hashimon.set_token(player, body.token)
		local display = (body.player and (body.player.username or body.player.displayName)) or player_name
		send(player_name, "Owner session OK (" .. display .. "). Syncing roster...")
		hashimon.sync_player(player)
	end)
end

local function emit_starter(player)
	local player_name = player:get_player_name()
	if not hashimon.is_api_owner(player_name) then
		send(player_name, "Guests cannot emit Hashimons. Register at " .. hashimon.get_register_url())
		return
	end
	local token = hashimon.get_token(player)
	if token == "" then
		send(player_name, "No session yet — wait for bind, or rejoin.")
		return
	end
	send(player_name, "Your starter is issued at web registration. Use /hashimon sync.")
end

local function begin_session(player)
	local player_name = player:get_player_name()
	send(player_name, "In-world anonymous /hashimon session is deprecated for Hashiworld.")
	send(player_name, "Register at " .. hashimon.get_register_url()
		.. " (same name/password), then join — or use /hashimon login only for debug tokens.")
end

core.register_on_joinplayer(function(player, _last_login)
	core.after(1.5, function()
		if not player:is_player() then
			return
		end
		local player_name = player:get_player_name()
		if hashimon.is_api_owner(player_name) then
			send(player_name, "Welcome, Hashimon owner. Binding API session...")
			bind_owner_session(player)
		else
			hashimon.clear_token(player)
			hashimon.notify_roster(player_name, {})
			send(player_name, "Welcome, guest. You can explore the world.")
			send(player_name, "To own a Hashimon, register at " .. hashimon.get_register_url()
				.. " then log in with that name and password.")
		end
	end)
end)

core.register_chatcommand("hashimon", {
	params = "<sync|status|login|file|logout|starter|session|attack|media|dna|evolve|ritualkit|carry|avatar|mount|mount_element|eyes|eyes3|seat|rot|yeet|worldpath>",
	description = "Hashimon: sync, evolve, carry, avatar bob, mount, yeet, …",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end

		local cmd, rest = param:match("^(%S*)%s*(.*)$")
		cmd = cmd ~= "" and cmd or "status"
		rest = rest or ""

		if cmd == "starter" then
			emit_starter(player)
			return true
		end

		if cmd == "session" then
			begin_session(player)
			return true
		end

		if cmd == "login" then
			hashimon.show_login_form(name)
			return true, "Opening debug token form (prefer web register + same password)."
		end

		if cmd == "file" then
			if hashimon.try_login_from_file(player) then
				return true, "Loaded token from file."
			end
			return true, "See chat for token file path."
		end

		if cmd == "logout" then
			hashimon.clear_token(player)
			hashimon.notify_roster(name, {})
			return true, "Session cleared."
		end

		if cmd == "sync" then
			if hashimon.is_api_owner(name) and not hashimon.has_token(player) then
				bind_owner_session(player)
				return true, "Re-binding owner session..."
			end
			hashimon.sync_player(player)
			return true, "Sync started (see chat for result)."
		end

		if cmd == "status" then
			if hashimon.is_api_owner(name) then
				if not hashimon.has_token(player) then
					return true, "Owner in auth cache but not bound yet. Use /hashimon sync."
				end
			elseif not hashimon.has_token(player) then
				return true, "Guest — no Hashimon ownership. Register at " .. hashimon.get_register_url()
			end
			local token = hashimon.get_token(player)
			hashimon.fetch_profile(token, function(ok, profile)
				if ok and profile then
					send(name, string.format(
						"Logged in as %s — %d Hashimon(s), %d credits, canOwn=%s.",
						profile.username or profile.displayName or "?",
						profile.hashimonCount or 0,
						profile.credits or 0,
						tostring(profile.canOwn)
					))
				else
					send(name, "Token stored but profile check failed. Try /hashimon sync.")
				end
			end)
			return true, "Checking status..."
		end

		if cmd == "media" then
			if not core.check_player_privs(name, { server = true }) then
				return false, "Requires the server privilege."
			end
			local sub = rest:match("^(%S*)") or ""
			if sub == "reload" or sub == "" then
				local n = hashimon.reload_media()
				local total = 0
				for _ in pairs(hashimon.media_registry) do total = total + 1 end
				return true, string.format(
					"Media registry: %d creature(s) known, %d dynamic file(s) (re)pushed.",
					total, n
				)
			end
			if sub == "list" then
				local lines = {}
				for dna, entry in pairs(hashimon.media_registry) do
					table.insert(lines, string.format(
						"%s... -> %s (%s)", dna:sub(1, 8), entry.mesh, entry.source
					))
				end
				if #lines == 0 then
					return true, "Media registry is empty."
				end
				return true, table.concat(lines, "\n")
			end
			return false, "Usage: /hashimon media <reload|list>"
		end

		if cmd == "dna" then
			-- The 3D preview only ever shows a truncated DNA (portal and chat
			-- stats both do). Full DNA is needed to register custom media
			-- (see hashimon_core/media.lua + scripts/register_hashimon_media.py),
			-- so read it straight off the spawned roster entity's own data.
			local roster = hashimon.get_roster_entities and hashimon.get_roster_entities(name) or {}
			if #roster == 0 then
				return false, "No Hashimon spawned. Use /hashimon sync first."
			end
			local idx = tonumber(rest) or 1
			local ref = roster[idx]
			if not ref or not ref:get_luaentity() then
				return false, "Invalid index. Use /hashimon dna 1, 2, ..."
			end
			local creature = hashimon.creature_from_entity
				and hashimon.creature_from_entity(ref:get_luaentity())
				or ref:get_luaentity().creature
			if not creature or not creature.dna then
				return false, "That entry has no DNA on record."
			end
			return true, string.format("[%d] %s — DNA: %s", idx, creature.name ~= "" and creature.name or (creature.speciesKey or "?"), creature.dna)
		end

		if cmd == "worldpath" then
			return true, "World path: " .. core.get_worldpath() ..
				"\nDrop custom media in: " .. core.get_worldpath() .. "/hashimon_media/"
		end

		if cmd == "evolve" then
			local sub = (rest:match("^(%S*)") or ""):lower()
			if sub == "ritual" or sub == "baby" or sub == "titan" or sub == "adult" then
				if not hashimon.evolve_ritual_command then
					return false, "hashimon_entities mod not loaded."
				end
				return hashimon.evolve_ritual_command(name, sub)
			end

			if not core.check_player_privs(name, { server = true }) then
				return false, "Requires the server privilege. (Or: /hashimon evolve titan|baby|ritual)"
			end
			if not hashimon.spawn_roster then
				return false, "hashimon_entities mod not loaded."
			end
			local refs = hashimon.get_roster_entities and hashimon.get_roster_entities(name) or {}
			if #refs == 0 then
				return false, "No Hashimon spawned. Use /hashimon sync first."
			end

			local stars_str, idx_str = rest:match("^(%S*)%s*(%S*)$")
			local stars = tonumber(stars_str) or 10
			local idx = tonumber(idx_str) or 1
			if stars < 1 or stars > 33 then
				return false, "Usage: /hashimon evolve [stars] [index] | titan | baby | ritual"
			end

			local creatures = {}
			for _, ref in ipairs(refs) do
				local ent = ref and ref:get_luaentity()
				local c = hashimon.creature_from_entity and hashimon.creature_from_entity(ent)
				if c then
					table.insert(creatures, c)
				end
			end
			if idx < 1 or idx > #creatures then
				return false, "Invalid index. Use /hashimon evolve 10 1"
			end

			if hashimon.mounts and hashimon.mounts[name] and hashimon.dismount then
				hashimon.dismount(player)
			end

			if hashimon.apply_local_stars then
				hashimon.apply_local_stars(creatures[idx], stars)
			else
				creatures[idx].stars = stars
				creatures[idx].stage = stars
				creatures[idx].tier = stars
			end

			hashimon.spawn_roster(name, creatures)
			return true, string.format(
				"Local evolve: [%d] %s → ★%d (not saved — /hashimon sync reverts).",
				idx,
				creatures[idx].name or creatures[idx].speciesKey or "?",
				stars
			)
		end

		if cmd == "ritualkit" then
			if not hashimon.give_ritual_kit then
				return false, "hashimon_entities mod not loaded."
			end
			local ok, added = hashimon.give_ritual_kit(player)
			if not ok then
				return false, "No se pudo entregar el kit."
			end
			if added == 0 then
				return true, "Ya tienes las herramientas ritual en el inventario."
			end
			return true, "Kit ritual opcional entregado. Beta: preferí Shift+D (Titan) / Shift+A (Baby) 1s."
		end

		if cmd == "avatar" then
			if not hashimon.apply_player_avatar then
				return false, "hashimon_players mod not loaded. Enable it in Content."
			end
			local sub = (rest:match("^(%S*)") or ""):lower()
			if sub == "" or sub == "status" then
				local id = hashimon.get_player_avatar and hashimon.get_player_avatar(player) or "?"
				return true, "Avatar actual: " .. tostring(id)
			end
			local ok, label = hashimon.set_player_avatar(player, sub)
			if ok then
				return true, "Avatar: " .. tostring(label)
			end
			if label == "unknown" then
				return false, "Uso: /hashimon avatar bob"
			elseif label == "missing_mesh" then
				return false, "Falta el modelo del avatar en hashimon_players/models."
			end
			return false, "No se pudo aplicar el avatar (" .. tostring(label) .. ")."
		end

		if cmd == "carry" then
			if not hashimon.carry_command then
				return false, "hashimon_entities mod not loaded."
			end
			return hashimon.carry_command(name, rest)
		end

		if cmd == "mount" then
			if not hashimon.mount_nearest_owned then
				return false, "hashimon_entities mod not loaded."
			end
			local ok, result, stage = hashimon.mount_nearest_owned(player)
			if ok then
				if result == "dismounted" then
					return true, "Desmontado."
				end
				return true, "Montado. Click derecho o /hashimon mount otra vez para bajar."
			end
			if result == "none_nearby" then
				return false, "No hay Hashimon en tu roster. Usa /hashimon sync y /hashimon evolve 10."
			elseif result == "too_far" then
				return false, "Acércate a tu Hashimon (menos de 8 bloques)."
			elseif result == "not_rideable" then
				return false, string.format(
					"Necesita ★%d (ahora ★%d). Usa /hashimon evolve %d",
					hashimon.MOUNT_STAGE_THRESHOLD or 10,
					stage or 0,
					hashimon.MOUNT_STAGE_THRESHOLD or 10
				)
			end
			return false, "No se pudo montar (" .. tostring(result) .. ")."
		end

		if cmd == "mount_element" then
			if not core.check_player_privs(name, { server = true }) then
				return false, "Requires the server privilege."
			end
			if not hashimon.set_mount_element_override then
				return false, "hashimon_entities mod not loaded."
			end

			local elem = (rest:match("^(%S*)") or ""):lower()
			if elem == "" then
				return false, "Usage: /hashimon mount_element <fuego|agua|aire|tierra|electrico|clear>"
			end

			local ent
			local mount_obj = hashimon.mounts and hashimon.mounts[name]
			if mount_obj then
				ent = mount_obj:get_luaentity()
			end
			if not ent then
				local refs = hashimon.get_roster_entities and hashimon.get_roster_entities(name) or {}
				local nearest, nearest_d
				local ppos = player:get_pos()
				for _, ref in ipairs(refs) do
					local e = ref and ref:get_luaentity()
					if e and ref:get_pos() and ppos then
						local rpos = ref:get_pos()
						local dx = rpos.x - ppos.x
						local dy = rpos.y - ppos.y
						local dz = rpos.z - ppos.z
						local d = dx * dx + dy * dy + dz * dz
						if not nearest_d or d < nearest_d then
							nearest_d = d
							nearest = e
						end
					end
				end
				ent = nearest
			end
			if not ent then
				return false, "No mount nearby. Sync, evolve to ★10, then mount or stand next to it."
			end

			local ok, result = hashimon.set_mount_element_override(ent, elem)
			if not ok then
				if result == "invalid_element" then
					return false, "Unknown element. Use: fuego, agua, aire, tierra, electrico, clear"
				end
				return false, "Could not set mount element."
			end
			if elem == "clear" or elem == "reset" then
				return true, "Mount element override cleared — using DNA type again."
			end
			return true, string.format(
				"Mount element override → %s (local only; cleared on dismount).",
				tostring(result)
			)
		end

		-- Live mount camera / seat calibration (must be mounted).
		-- /hashimon eyes <y> [z]   — first-person eye offset; keeps current x
		-- /hashimon eyes3 <y> [z]  — third-person eye offset (engine clamps Y≤15, Z∈[-5,5])
		-- /hashimon seat <x> <y> <z> — set_attach seat (Luanti ×10 units)
		-- /hashimon rot <x> <y> <z>   — set_attach rotation (degrees)
		if cmd == "eyes" then
			if not hashimon.apply_mount_view_patch then
				return false, "hashimon_entities mod not loaded."
			end
			local y_s, z_s = rest:match("^(%S+)%s*(%S*)")
			local y = tonumber(y_s)
			if not y then
				return false, "Usage: /hashimon eyes <y> [z]  (while mounted; first-person offset)"
			end
			local z = tonumber(z_s)
			local mount_obj = hashimon.mounts and hashimon.mounts[name]
			local ent = mount_obj and mount_obj:get_luaentity()
			local cur = ent and ent._mount_view and ent._mount_view.eye_first
			local eye_first = {
				x = (cur and cur.x) or 0,
				y = y,
				z = z or ((cur and cur.z) or 0),
			}
			local ok, result = hashimon.apply_mount_view_patch(player, { eye_first = eye_first })
			if not ok then
				if result == "not_mounted" then
					return false, "Monta primero (/hashimon mount), luego /hashimon eyes <y> [z]."
				end
				return false, "No se pudo aplicar eyes (" .. tostring(result) .. ")."
			end
			local v = result.eye_first
			return true, string.format(
				"eye_first = { x=%.1f, y=%.1f, z=%.1f }  (copia a mount_view del body)",
				v.x, v.y, v.z
			)
		end

		if cmd == "eyes3" then
			if not hashimon.apply_mount_view_patch then
				return false, "hashimon_entities mod not loaded."
			end
			local y_s, z_s = rest:match("^(%S+)%s*(%S*)")
			local y = tonumber(y_s)
			if not y then
				return false, "Usage: /hashimon eyes3 <y> [z]  (while mounted; third-person; Z clamp ±5)"
			end
			local z = tonumber(z_s)
			local mount_obj = hashimon.mounts and hashimon.mounts[name]
			local ent = mount_obj and mount_obj:get_luaentity()
			local cur = ent and ent._mount_view and ent._mount_view.eye_third
			local eye_third = {
				x = (cur and cur.x) or 0,
				y = y,
				z = z or ((cur and cur.z) or -5),
			}
			local ok, result = hashimon.apply_mount_view_patch(player, { eye_third = eye_third })
			if not ok then
				if result == "not_mounted" then
					return false, "Monta primero (/hashimon mount), luego /hashimon eyes3 <y> [z]."
				end
				return false, "No se pudo aplicar eyes3 (" .. tostring(result) .. ")."
			end
			local v = result.eye_third
			return true, string.format(
				"eye_third = { x=%.1f, y=%.1f, z=%.1f }  (motor clamp Y≤15, Z∈[-5,5])",
				v.x, v.y, v.z
			)
		end

		if cmd == "seat" then
			if not hashimon.apply_mount_view_patch then
				return false, "hashimon_entities mod not loaded."
			end
			local x_s, y_s, z_s = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
			local x, y, z = tonumber(x_s), tonumber(y_s), tonumber(z_s)
			if not x or not y or not z then
				return false, "Usage: /hashimon seat <x> <y> <z>  (while mounted; set_attach ×10)"
			end
			local ok, result = hashimon.apply_mount_view_patch(player, {
				seat = { x = x, y = y, z = z },
			})
			if not ok then
				if result == "not_mounted" then
					return false, "Monta primero (/hashimon mount), luego /hashimon seat <x> <y> <z>."
				end
				return false, "No se pudo aplicar seat (" .. tostring(result) .. ")."
			end
			local s = result.seat
			return true, string.format(
				"seat = { x=%.1f, y=%.1f, z=%.1f }  (si Sam flota, mueve Socket.Mount en Blender)",
				s.x, s.y, s.z
			)
		end

		if cmd == "rot" then
			if not hashimon.apply_mount_view_patch then
				return false, "hashimon_entities mod not loaded."
			end
			local x_s, y_s, z_s = rest:match("^(%S+)%s+(%S+)%s+(%S+)$")
			local x, y, z = tonumber(x_s), tonumber(y_s), tonumber(z_s)
			if not x or not y or not z then
				return false, "Usage: /hashimon rot <x> <y> <z>  (while mounted; attach rotation °)"
			end
			local ok, result = hashimon.apply_mount_view_patch(player, {
				rot = { x = x, y = y, z = z },
			})
			if not ok then
				if result == "not_mounted" then
					return false, "Monta primero (/hashimon mount), luego /hashimon rot <x> <y> <z>."
				end
				return false, "No se pudo aplicar rot (" .. tostring(result) .. ")."
			end
			local r = result.rot
			return true, string.format(
				"rot = { x=%.1f, y=%.1f, z=%.1f }  (copia a mount_view.rot del body)",
				r.x, r.y, r.z
			)
		end

		if cmd == "yeet" then
			if not hashimon.impact_yeet_command then
				return false, "hashimon_entities mod not loaded."
			end
			return hashimon.impact_yeet_command(name, rest)
		end

		if cmd == "attack" then
			if not hashimon.attack_nearest_roster then
				return false, "hashimon_entities mod not loaded."
			end

			local target = rest ~= "" and rest or nil
			local direction = player:get_look_dir()

			if target == "all" then
				local ok, result = hashimon.attack_all_roster(name, direction)
				if not ok then
					if result == "empty_roster" then
						return false, "No Hashimon spawned. Use /hashimon sync first."
					end
					return false, "Attack failed."
				end
				return true, "All Hashimon launched blast orbs."
			end

			local ok, err
			if target and target:match("^%d+$") then
				ok, err = hashimon.attack_roster_at_index(name, tonumber(target), direction)
			else
				ok, err = hashimon.attack_nearest_roster(name, direction)
			end

			if not ok then
				if err == "empty_roster" then
					return false, "No Hashimon spawned. Use /hashimon sync first."
				elseif err == "invalid_index" then
					return false, "Invalid roster index. Use /hashimon attack 1, 2, ..."
				elseif err == "cooldown" then
					return false, "That Hashimon is on cooldown (3s)."
				end
				return false, "Attack failed."
			end
			return true, "Blast orb launched."
		end

		return false, "Unknown subcommand. Use: sync, status, login, file, logout, starter, session, attack, evolve, carry, avatar, ritualkit, mount, mount_element, yeet"
	end,
})
