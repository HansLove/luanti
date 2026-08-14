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

-- Capture builtin before we replace the handler.
local builtin = core.builtin_auth_handler
if not builtin then
	core.log("error", "[hashimon_core] builtin_auth_handler missing; hybrid auth disabled")
	return
end

core.register_authentication_handler({
	get_auth = function(name)
		local owner = hashimon.get_cached_owner(name)
		if owner then
			local privs = default_privs()
			-- Merge any locally stored privs if the guest row existed before claim.
			local local_auth = builtin.get_auth(name)
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
			return {
				password = owner.password,
				privileges = privs,
				last_login = local_auth and local_auth.last_login or nil,
			}
		end
		return builtin.get_auth(name)
	end,

	create_auth = function(name, password)
		if hashimon.is_api_owner(name) then
			core.log("action", "[hashimon_core] refusing local create_auth for API owner '" .. name .. "'")
			-- Still ensure builtin has a stub so privileges tools don't break;
			-- password is ignored for login because get_auth serves API hash.
			if not builtin.get_auth(name) then
				return builtin.create_auth(name, password)
			end
			return true
		end
		return builtin.create_auth(name, password)
	end,

	delete_auth = function(name)
		return builtin.delete_auth(name)
	end,

	set_password = function(name, password)
		if hashimon.is_api_owner(name) then
			core.log("action", "[hashimon_core] set_password ignored for API owner '" .. name .. "' (change via web)")
			return true
		end
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
		return builtin.record_login(name)
	end,

	iterate = function()
		return builtin.iterate()
	end,
})

core.register_on_mods_loaded(function()
	hashimon.poll_luanti_auth()
	core.after(POLL_INTERVAL, function poll()
		hashimon.poll_luanti_auth()
		core.after(POLL_INTERVAL, poll)
	end)
end)

core.log("action", "[hashimon_core] hybrid auth handler registered (API owners override guests)")
