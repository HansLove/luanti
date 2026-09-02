-- HTTP wrapper for the Hashimon REST API.
-- Requires hashimon_core in secure.http_mods (see README).

hashimon = hashimon or {}

local DEFAULT_API_URL = "http://127.0.0.1:4000"
local http -- set once by init.lua; never exposed as a global (lua_api.md)

function hashimon.set_http(api)
	http = api
end

function hashimon.get_api_url()
	local url = core.settings:get("hashimon_api_url")
	if url == nil or url == "" then
		return DEFAULT_API_URL
	end
	return url:gsub("/$", "")
end

local function parse_json_or_nil(data)
	if not data or data == "" then
		return nil
	end
	local ok, parsed = pcall(core.parse_json, data)
	if ok then
		return parsed
	end
	return nil
end

local function extra_headers(pairs)
	local out = {}
	for i = 1, #pairs do
		out[i] = pairs[i][1] .. ": " .. pairs[i][2]
	end
	return out
end

local function http_failure_code(res)
	if res.code == 0 then
		return res.error or "http_unavailable"
	end
	local body = parse_json_or_nil(res.data)
	return (body and (body.error or body.code)) or ("HTTP " .. tostring(res.code))
end

function hashimon.http_request(req, callback)
	if not http then
		callback({ completed = true, code = 0, data = "", error = "http_unavailable" })
		return
	end
	http.fetch(req, callback)
end

function hashimon.http_error_message(err)
	if err == "http_unavailable" then
		return "HTTP blocked. Quit Luanti, add to minetest.conf: secure.http_mods = hashimon_core"
	end
	return tostring(err)
end

function hashimon.create_session(callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/session",
		method = "POST",
		extra_headers = extra_headers({
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = "{}",
	}, function(res)
		if not res.completed then
			callback(false, "request_incomplete", nil)
			return
		end
		if res.code ~= 200 and res.code ~= 201 then
			callback(false, http_failure_code(res), nil)
			return
		end
		local body = parse_json_or_nil(res.data)
		if not body or type(body.token) ~= "string" or body.token == "" then
			callback(false, "invalid_response", nil)
			return
		end
		callback(true, nil, body)
	end)
end

function hashimon.emit_starter(token, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/hashimons",
		method = "POST",
		extra_headers = extra_headers({
			{ "Authorization", "Bearer " .. token },
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = core.write_json({ speciesKey = "s001", provenance = "starter" }),
	}, function(res)
		if not res.completed then
			callback(false, "request_incomplete", nil)
			return
		end
		if res.code == 409 then
			callback(false, "starter_limit", nil)
			return
		end
		if res.code ~= 200 and res.code ~= 201 then
			callback(false, http_failure_code(res), nil)
			return
		end
		local body = parse_json_or_nil(res.data)
		if not body or not body.id then
			callback(false, "invalid_response", nil)
			return
		end
		callback(true, nil, body)
	end)
end

function hashimon.fetch_hashimons(token, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/hashimons",
		method = "GET",
		extra_headers = extra_headers({
			{ "Authorization", "Bearer " .. token },
			{ "Accept", "application/json" },
		}),
	}, function(res)
		if not res.completed then
			callback(false, "request_incomplete", nil)
			return
		end
		if res.code == 401 then
			callback(false, "unauthorized", nil)
			return
		end
		if res.code ~= 200 then
			callback(false, http_failure_code(res), nil)
			return
		end
		local body = parse_json_or_nil(res.data)
		if not body or type(body.hashimons) ~= "table" then
			callback(false, "invalid_response", nil)
			return
		end
		callback(true, nil, body.hashimons)
	end)
end

function hashimon.fetch_profile(token, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/profile",
		method = "GET",
		extra_headers = extra_headers({
			{ "Authorization", "Bearer " .. token },
			{ "Accept", "application/json" },
		}),
	}, function(res)
		if not res.completed or res.code ~= 200 then
			callback(false, nil)
			return
		end
		callback(true, parse_json_or_nil(res.data))
	end)
end

-- Blocking poll used at startup. Async fetch *callbacks* cannot run until after
-- the host has already authenticated, so a first-join race treats API owners
-- as local SRP guests and rejects the web password.
-- io.popen is nil in the Lua sandbox; poll fetch_async_get instead (HTTP thread
-- can finish while we wait).
function hashimon.fetch_luanti_auth_sync(secret)
	if not http or not http.fetch_async or not http.fetch_async_get then
		return false, "http_unavailable", nil
	end
	local handle = http.fetch_async({
		url = hashimon.get_api_url() .. "/internal/luanti-auth",
		method = "GET",
		timeout = 5,
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Accept", "application/json" },
		}),
	})
	local deadline = os.clock() + 5
	local res
	repeat
		res = http.fetch_async_get(handle)
	until (res and res.completed) or os.clock() >= deadline
	if not res or not res.completed then
		return false, "timeout", nil
	end
	if res.code ~= 200 then
		return false, http_failure_code(res), nil
	end
	local body = parse_json_or_nil(res.data)
	if not body or type(body.accounts) ~= "table" then
		return false, "invalid_response", nil
	end
	return true, nil, body.accounts
end

function hashimon.fetch_luanti_auth(secret, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-auth",
		method = "GET",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Accept", "application/json" },
		}),
	}, function(res)
		if not res.completed then
			callback(false, "request_incomplete", nil)
			return
		end
		if res.code ~= 200 then
			callback(false, http_failure_code(res), nil)
			return
		end
		local body = parse_json_or_nil(res.data)
		if not body or type(body.accounts) ~= "table" then
			callback(false, "invalid_response", nil)
			return
		end
		callback(true, nil, body.accounts)
	end)
end

function hashimon.luanti_bind(secret, name, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-bind",
		method = "POST",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = core.write_json({ name = name }),
	}, function(res)
		if not res.completed then
			callback(false, "request_incomplete", nil)
			return
		end
		if res.code == 403 then
			callback(false, "cannot_own", nil)
			return
		end
		if res.code == 404 then
			callback(false, "not_found", nil)
			return
		end
		if res.code ~= 200 then
			callback(false, http_failure_code(res), nil)
			return
		end
		local body = parse_json_or_nil(res.data)
		if not body or type(body.token) ~= "string" or body.token == "" then
			callback(false, "invalid_response", nil)
			return
		end
		callback(true, nil, body)
	end)
end

-- Push a player's Towny territory summary to the API. This is a projection for
-- display on the website (town name, block/plot counts, mayor flag); it is not a
-- ledger event and carries no ownership consequence. Server-secret authed.
function hashimon.push_territory(secret, payload, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-territory",
		method = "POST",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = core.write_json(payload),
	}, function(res)
		if not res.completed then
			if callback then callback(false, "request_incomplete") end
			return
		end
		if res.code ~= 200 then
			if callback then callback(false, http_failure_code(res)) end
			return
		end
		if callback then callback(true, nil) end
	end)
end

-- Push the WHOLE town snapshot (every town + its claimed mapblocks) to the API so the
-- ranking is complete and the website can draw a cadastral map. Like push_territory,
-- this is a display projection, never a ledger event. Server-secret authed.
function hashimon.push_towns(secret, payload, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-towns",
		method = "POST",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = core.write_json(payload),
	}, function(res)
		if not res.completed then
			if callback then callback(false, "request_incomplete") end
			return
		end
		if res.code ~= 200 then
			if callback then callback(false, http_failure_code(res)) end
			return
		end
		if callback then callback(true, nil) end
	end)
end

-- Poll the API for pending town political actions (co-mayor promote/demote made on
-- the website). callback(ok, err, actions) — actions is a list the world re-validates
-- and applies in Towny. Server-secret authed.
function hashimon.fetch_town_actions(secret, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-town-actions",
		method = "GET",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Accept", "application/json" },
		}),
	}, function(res)
		if not res.completed then callback(false, "request_incomplete", nil); return end
		if res.code ~= 200 then callback(false, http_failure_code(res), nil); return end
		local body = parse_json_or_nil(res.data)
		if not body or type(body.actions) ~= "table" then callback(false, "invalid_response", nil); return end
		callback(true, nil, body.actions)
	end)
end

-- Acknowledge a town action after the world applied or rejected it, so the API can
-- close it out. `result` is "applied" or "rejected". Server-secret authed.
function hashimon.ack_town_action(secret, id, result, detail, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-town-actions/ack",
		method = "POST",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = core.write_json({ id = id, result = result, detail = detail or "" }),
	}, function(res)
		if not res.completed then if callback then callback(false, "request_incomplete") end; return end
		if res.code ~= 200 then if callback then callback(false, http_failure_code(res)) end; return end
		if callback then callback(true, nil) end
	end)
end

-- Push an in-game signup to the API. `entry` is the "#1#salt#verifier" the
-- engine handed to create_auth; the plaintext never reaches this server.
function hashimon.luanti_register(secret, name, entry, callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/internal/luanti-register",
		method = "POST",
		extra_headers = extra_headers({
			{ "X-Luanti-Secret", secret },
			{ "Content-Type", "application/json" },
			{ "Accept", "application/json" },
		}),
		data = core.write_json({ name = name, password = entry }),
	}, function(res)
		if not res.completed then
			callback(false, "request_incomplete", nil)
			return
		end
		if res.code == 409 then
			callback(false, "username_taken", nil)
			return
		end
		if res.code ~= 200 and res.code ~= 201 then
			callback(false, http_failure_code(res), nil)
			return
		end
		callback(true, nil, parse_json_or_nil(res.data))
	end)
end
