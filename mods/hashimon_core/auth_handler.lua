-- Hybrid auth: API owners (with key) override local auth.sqlite guests.
-- Guests may still Registrarse in-game; they explore without Hashimon ownership.

hashimon = hashimon or {}

local POLL_INTERVAL = 2
local owner_cache = {} -- lower(name) -> { name = originalCase, password = hash }
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

function hashimon.is_api_owner(name)
	if not name or name == "" then
		return false
	end
	return owner_cache[name:lower()] ~= nil
end

function hashimon.get_cached_owner(name)
	if not name or name == "" then
		return nil
	end
	return owner_cache[name:lower()]
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
				}
			end
		end
	end
	owner_cache = next_cache
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
		core.log("warning", "[hashimon_core] hashimon_server_secret empty; web owner login disabled")
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
	local names = {}
	for _, row in pairs(owner_cache) do
		table.insert(names, row.name)
	end
	table.sort(names)
	core.log("action", "[hashimon_core] luanti-auth sync loaded " .. #names
		.. " owner(s): " .. table.concat(names, ", "))
	return true
end

-- Capture builtin before we replace the handler.
local builtin = core.builtin_auth_handler
if not builtin then
	core.log("error", "[hashimon_core] builtin_auth_handler missing; hybrid auth disabled")
	return
end

local function merge_owner_privs(name, local_auth)
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

core.register_authentication_handler({
	-- Modern Luanti authenticates with SRP. The API stores a legacy SHA1 hash
	-- that this engine rejects (HashiTest1/Hashimon123 proved it). Owners
	-- therefore use a local SRP verifier: first join is FIRST_SRP with the
	-- password they type; later joins use that verifier. Ownership still
	-- binds via /internal/luanti-bind on join (by username).
	get_auth = function(name)
		local local_auth = builtin.get_auth(name)
		if hashimon.is_api_owner(name) then
			if local_auth and type(local_auth.password) == "string"
					and local_auth.password:sub(1, 3) == "#1#" then
				core.log("action", "[hashimon_core] get_auth '" .. name .. "' → owner local SRP")
				return {
					password = local_auth.password,
					privileges = merge_owner_privs(name, local_auth),
					last_login = local_auth.last_login or -1,
				}
			end
			core.log("action", "[hashimon_core] get_auth '" .. name .. "' → owner FIRST_SRP")
			return nil
		end
		core.log("action", "[hashimon_core] get_auth '" .. name .. "' → local guest")
		return local_auth
	end,

	create_auth = function(name, password)
		core.log("action", "[hashimon_core] create_auth '" .. name .. "'")
		if builtin.get_auth(name) then
			return builtin.set_password(name, password)
		end
		return builtin.create_auth(name, password)
	end,

	delete_auth = function(name)
		return builtin.delete_auth(name)
	end,

	set_password = function(name, password)
		return builtin.set_password(name, password)
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

core.log("action", "[hashimon_core] hybrid auth handler registered (API owners override guests)")
