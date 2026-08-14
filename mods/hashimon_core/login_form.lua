-- Login UI: formspec paste, segmented fields, and token file import.
-- Chat commands cannot reliably accept 64-char tokens (paste / Mac shortcuts).

hashimon = hashimon or {}

local LOGIN_FORM = "hashimon_core:login"
local TOKEN_FILE = "hashimon_token.txt"

local function send(player_name, msg)
	core.chat_send_player(player_name, "[Hashimon] " .. msg)
end

local function label(y, text)
	return "label[0.5," .. y .. ";" .. core.formspec_escape(text) .. "]"
end

local function normalize_token(raw)
	if not raw or raw == "" then
		return nil
	end
	local token = raw:gsub("%s+", ""):lower()
	if #token < 32 or token:find("[^0-9a-f]") then
		return nil
	end
	return token
end

local function token_from_fields(fields)
	if fields.token and fields.token ~= "" then
		return normalize_token(fields.token)
	end
	local parts = {}
	for i = 1, 4 do
		local part = fields["part" .. i]
		if part and part ~= "" then
			parts[#parts + 1] = part
		end
	end
	if #parts == 0 then
		return nil
	end
	return normalize_token(table.concat(parts, ""))
end

function hashimon.world_token_path()
	return core.get_worldpath() .. "/" .. TOKEN_FILE
end

function hashimon.try_login_from_file(player)
	local player_name = player:get_player_name()
	local path = hashimon.world_token_path()
	local f = io.open(path, "r")
	if not f then
		send(player_name, "Token file not found.")
		send(player_name, "Run: ./util/hashimon-3d-login.sh")
		send(player_name, "Or in-game: /hashimon session")
		send(player_name, "Expected file: " .. path)
		return false
	end
	local token = normalize_token(f:read("*a"))
	f:close()
	if not token then
		send(player_name, "Invalid token in " .. TOKEN_FILE)
		return false
	end
	hashimon.set_token(player, token)
	send(player_name, "Token loaded from file. Syncing...")
	hashimon.sync_player(player)
	return true
end

function hashimon.show_login_form(player_name)
	local worldpath = core.formspec_escape(core.get_worldpath())
	core.show_formspec(player_name, LOGIN_FORM, table.concat({
		"formspec_version[6]",
		"size[10,10]",
		label(0.3, "Hashimon Login"),
		label(0.9, "Easiest: /hashimon session — creates account from 3D, no paste."),
		label(1.35, "Or paste a token below. Do not paste in chat."),
		label(1.7, "Paste: click the box, then Ctrl+V. Mac Cmd+V needs Haxel rebuild."),
		label(2.05, "Or use 4 chunks, or load hashimon_token.txt."),
		"field_close_on_enter[token;false]",
		"textarea[0.5,2.5;9,2;token;;]",
		label(4.65, "Or paste 16 characters per box:"),
		"field[0.5,5.05;2.1,0.8;part1;;]",
		"field[2.7,5.05;2.1,0.8;part2;;]",
		"field[4.9,5.05;2.1,0.8;part3;;]",
		"field[7.1,5.05;2.1,0.8;part4;;]",
		label(6.1, "Token file folder:"),
		"label[0.5,6.45;" .. worldpath .. "]",
		"button[0.5,7.2;4.5,1;login;Login]",
		"button[5.2,7.2;4.3,1;file;Load " .. TOKEN_FILE .. "]",
		"button[0.5,8.35;9,1;cancel;Cancel]",
	}, "\n"))
end

core.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= LOGIN_FORM then
		return
	end
	local player_name = player:get_player_name()

	if fields.cancel then
		return
	end

	if fields.file then
		hashimon.try_login_from_file(player)
		return
	end

	if fields.login then
		local token = token_from_fields(fields)
		if not token then
			send(player_name, "No valid token. Try /hashimon session or paste in the form.")
			hashimon.show_login_form(player_name)
			return
		end
		hashimon.set_token(player, token)
		send(player_name, "Token saved. Syncing...")
		hashimon.sync_player(player)
	end
end)
