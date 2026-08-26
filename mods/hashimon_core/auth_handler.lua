-- The API database is the only password store. This handler mirrors every
-- account (name, SRP entry "#1#salt#verifier", can_own) from
-- GET /internal/luanti-auth and answers get_auth from that mirror. In-game
-- signups are pushed back through POST /internal/luanti-register. Privileges
-- and last_login stay in the local auth.sqlite via the builtin handler.

hashimon = hashimon or {}

local POLL_INTERVAL = 2
local account_cache = {} -- lower(name) -> { name = originalCase, password = "#1#...", can_own = bool }
local poll_busy = false

local function default_privs()
	return core.string_to_privs(core.settings:get("default_privs") or "interact,shout")
end

function hashimon.get_server_secret()
	return core.settings:get("hashimon_server_secret") or ""
end

function hashimon.get_register_url()
	local url = core.settings:get("hashimon_register_url")
	if url == nil or url == "" then
		return "https://hashimon.app/register"
	end
	return url
end

local function cached(name)
	if not name or name == "" then
		return nil
	end
	return account_cache[name:lower()]
end

function hashimon.is_api_account(name)
	return cached(name) ~= nil
end

function hashimon.is_api_owner(name)
	local entry = cached(name)
	return entry ~= nil and entry.can_own == true
end

local function apply_auth_list(accounts)
	local next_cache = {}
	if type(accounts) == "table" then
		for _, row in ipairs(accounts) do
			if type(row) == "table" and type(row.name) == "string" and type(row.password) == "string"
					and row.name ~= "" and row.password ~= "" then
				next_cache[row.name:lower()] = {
					name = row.name,
					password = row.password,
					can_own = row.can_own == true,
				}
			end
		end
	end
	account_cache = next_cache
end

function hashimon.poll_luanti_auth()
	if poll_busy then
		return
	end
	local secret = hashimon.get_server_secret()
	if secret == "" then
		return
	end
	if not hashimon.fetch_luanti_auth then
		return
	end
	poll_busy = true
	hashimon.fetch_luanti_auth(secret, function(ok, err, accounts)
		poll_busy = false
		if ok then
			apply_auth_list(accounts)
		else
			core.log("warning", "[hashimon_core] luanti-auth poll failed: " .. tostring(err))
		end
	end)
end

function hashimon.poll_luanti_auth_sync()
	local secret = hashimon.get_server_secret()
	if secret == "" then
		core.log("warning", "[hashimon_core] hashimon_server_secret empty; API auth mirror disabled")
		return false
	end
	if not hashimon.fetch_luanti_auth_sync then
		return false
	end
	local ok, err, accounts = hashimon.fetch_luanti_auth_sync(secret)
	if not ok then
		core.log("warning", "[hashimon_core] luanti-auth sync failed: " .. tostring(err))
		return false
	end
	apply_auth_list(accounts)
	local count = 0
	for _ in pairs(account_cache) do
		count = count + 1
	end
	core.log("action", "[hashimon_core] luanti-auth sync loaded " .. count .. " account(s)")
	return true
end

-- Capture builtin before we replace the handler.
local builtin = core.builtin_auth_handler
if not builtin then
	core.log("error", "[hashimon_core] builtin_auth_handler missing; API auth disabled")
	return
end

local function merge_privs(name, local_auth)
	local privs = default_privs()
	if local_auth and local_auth.privileges then
		for priv, val in pairs(local_auth.privileges) do
			if val then
				privs[priv] = true
			end
		end
	end
	if core.is_singleplayer() then
		for priv, def in pairs(core.registered_privileges) do
			if def.give_to_singleplayer then
				privs[priv] = true
			end
		end
	elseif name == core.settings:get("name") then
		for priv, def in pairs(core.registered_privileges) do
			if def.give_to_admin then
				privs[priv] = true
			end
		end
	end
	return privs
end

local function reject_signup(name, err)
	account_cache[name:lower()] = nil
	core.log("warning", "[hashimon_core] luanti-register '" .. name .. "' failed: " .. tostring(err))
	-- The callback may land mid-handshake; defer the kick to the next step.
	core.after(0, function()
		local reason = err == "username_taken"
			and "That name is already registered. Pick another one."
			or "Could not register your account with the Hashimon API. Try again later."
		core.kick_player(name, reason)
	end)
end

core.register_authentication_handler({
	get_auth = function(name)
		local entry = cached(name)
		if not entry then
			-- Unknown to the API: FIRST_SRP, the engine will call create_auth.
			core.log("action", "[hashimon_core] get_auth '" .. name .. "' → not in API, FIRST_SRP")
			return nil
		end
		local local_auth = builtin.get_auth(name)
		return {
			password = entry.password,
			privileges = merge_privs(name, local_auth),
			last_login = local_auth and local_auth.last_login or -1,
		}
	end,

	create_auth = function(name, password)
		core.log("action", "[hashimon_core] create_auth '" .. name .. "'")
		-- The engine reads back right after this call and the next join cannot
		-- wait for the poll: mirror first, then push to the API.
		account_cache[name:lower()] = { name = name, password = password, can_own = false }
		if not builtin.get_auth(name) then
			builtin.create_auth(name, password) -- local row for privileges/last_login only
		end
		hashimon.luanti_register(hashimon.get_server_secret(), name, password, function(ok, err)
			if not ok then
				reject_signup(name, err)
			end
		end)
		return true
	end,

	delete_auth = function(name)
		return builtin.delete_auth(name)
	end,

	-- The web is the only place a password changes.
	set_password = function(name, _password)
		core.log("action", "[hashimon_core] set_password '" .. name .. "' refused")
		core.chat_send_player(name, "Passwords are managed on the web: " .. hashimon.get_register_url())
		return false
	end,

	set_privileges = function(name, privileges)
		return builtin.set_privileges(name, privileges)
	end,

	reload = function()
		hashimon.poll_luanti_auth()
		return builtin.reload()
	end,

	record_login = function(name)
		if builtin.get_auth(name) then
			return builtin.record_login(name)
		end
		return true
	end,

	iterate = function()
		return builtin.iterate()
	end,
})

-- A custom auth handler disables the engine's case-insensitive duplicate name
-- guard (builtin/game/auth.lua); replicate it against the mirror.
core.register_on_prejoinplayer(function(name)
	local entry = cached(name)
	if entry and entry.name ~= name then
		return "\nCannot create new player called '" .. name .. "'. "
			.. "Another account called '" .. entry.name .. "' is already registered. "
			.. "Please check the spelling if it's your account or use a different name."
	end
end)

-- Must run before the host authenticates. Async HTTP is too late: the join
-- packet is handled in the same tick as listen, before fetch callbacks.
hashimon.poll_luanti_auth_sync()

core.register_on_mods_loaded(function()
	hashimon.poll_luanti_auth()

	local poll
	poll = function()
		hashimon.poll_luanti_auth()
		core.after(POLL_INTERVAL, poll)
	end
	core.after(POLL_INTERVAL, poll)
end)

core.log("action", "[hashimon_core] API auth mirror registered (DB is the only password store)")
