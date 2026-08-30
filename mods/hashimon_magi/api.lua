-- HTTP client for the MAGI ledger. Reuses hashimon_core's HTTP handle and the
-- shared world secret: the Luanti server is a trusted caller acting on behalf of
-- the player it names, exactly like the auth bridge (see hashimon_core/api.lua).

hashimon_magi = hashimon_magi or {}

local function headers(secret)
	return {
		"X-Luanti-Secret: " .. secret,
		"Content-Type: application/json",
		"Accept: application/json",
	}
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

--- Every failure here is a *transport* failure, never a verdict. Callers must
--- treat it as "could not check", not as "the note is fake".
local function respond(res, callback)
	if not res.completed then
		callback(false, "request_incomplete", nil)
		return
	end
	local body = parse_json_or_nil(res.data)
	if res.code ~= 200 and res.code ~= 201 then
		callback(false, (body and (body.code or body.error)) or ("HTTP " .. tostring(res.code)), body)
		return
	end
	callback(true, nil, body)
end

local function request(path, method, payload, callback)
	local secret = hashimon.get_server_secret()
	if secret == "" then
		callback(false, "no_server_secret", nil)
		return
	end
	hashimon.http_request({
		url = hashimon.get_api_url() .. path,
		method = method,
		timeout = 10,
		extra_headers = headers(secret),
		data = payload and core.write_json(payload) or nil,
	}, function(res)
		respond(res, callback)
	end)
end

--- Batch custody check. `notes` is a list of tokens; the reply pairs each serial
--- with a verdict and, when ok, the rotated token to write back into the item.
function hashimon_magi.api_custody(holder, event, notes, callback)
	request("/internal/magi/custody", "POST", { holder = holder, event = event, notes = notes }, callback)
end

--- Dematerialize: notes in hand become vault balance. Fails custody -> destroyed.
function hashimon_magi.api_deposit(holder, notes, callback)
	request("/internal/magi/deposit", "POST", { holder = holder, notes = notes }, callback)
end

--- Materialize: vault balance becomes items. Returns one token per note.
function hashimon_magi.api_withdraw(holder, count, callback)
	request("/internal/magi/withdraw", "POST", { holder = holder, count = count }, callback)
end

--- Mint into the vault. Refused past the supply cap — no admin can print silently.
function hashimon_magi.api_issue(holder, count, callback)
	request("/internal/magi/issue", "POST", { holder = holder, count = count }, callback)
end

function hashimon_magi.api_holder(holder, callback)
	request("/internal/magi/holder/" .. holder, "GET", nil, callback)
end

--- Public route: no secret needed, but reuse the same plumbing.
function hashimon_magi.api_supply(callback)
	hashimon.http_request({
		url = hashimon.get_api_url() .. "/magi/supply",
		method = "GET",
		timeout = 10,
		extra_headers = { "Accept: application/json" },
	}, function(res)
		respond(res, callback)
	end)
end
