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
	params = "<sync|status|login|file|logout|starter|session|attack|media|dna|worldpath>",
	description = "Hashimon: sync roster (owners), status, debug login, attack, media, dna, worldpath",
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
			local creature = ref:get_luaentity().creature
			if not creature or not creature.dna then
				return false, "That entry has no DNA on record."
			end
			return true, string.format("[%d] %s — DNA: %s", idx, creature.name ~= "" and creature.name or (creature.speciesKey or "?"), creature.dna)
		end

		if cmd == "worldpath" then
			return true, "World path: " .. core.get_worldpath() ..
				"\nDrop custom media in: " .. core.get_worldpath() .. "/hashimon_media/"
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

		return false, "Unknown subcommand. Use: sync, status, login, file, logout, starter, session, attack"
	end,
})
