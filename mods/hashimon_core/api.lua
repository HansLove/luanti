-- HTTP wrapper for the Hashimon REST API.
-- Requires hashimon_core in secure.http_mods (see README).

hashimon = hashimon or {}

local DEFAULT_API_URL = "http://127.0.0.1:4000"

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
	if not hashimon.http then
		callback({ completed = true, code = 0, data = "", error = "http_unavailable" })
		return
	end
	hashimon.http.fetch(req, callback)
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
