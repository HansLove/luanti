-- A township system for Minetest servers.
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

towny.chat = {
	-- channel enums
	CHANNEL_GLOBAL = 0,
	CHANNEL_TOWN = 1,
	-- 2
	-- 3
	-- 4

	channel_names = {
		[0] = "[Global]", -- unused
		[1] = "[Town Chat]",
	},

	-- key = resident name, value = channel value
	channels = {},
}

local chat = towny.chat

local function chat_send_town(town, message)
	for name, _ in pairs(town.members) do
		core.chat_send_player(name, message)
	end
end

local function chat_message_func(name, message)
	if not name then
		return false
	end

	local res = towny.residents[name]

	if not res then
		return false
	end

	local town_str = ""

	if chat.channels[name] == chat.CHANNEL_GLOBAL then
		if res.town then
			town_str = table.concat({"[", res.town.name, "]"})
		end

		core.chat_send_all(
			table.concat({town_str, " <", res:get_display_name(), "> ", message}))
		return true

	elseif chat.channels[name] == chat.CHANNEL_TOWN then
		chat_send_town(res.town, chat.channel_names[chat.CHANNEL_TOWN] .. " <" .. res:get_display_name() .. "> " .. message)
		return true
	end

	return false
end

chat.chat_message_func = chat_message_func
chat.chat_send_town = chat_send_town

core.register_on_chat_message(chat_message_func)

core.register_on_joinplayer(function(player)
	chat.channels[player:get_player_name()] = chat.CHANNEL_GLOBAL
end)

-- town channel
-- channel messages are intentionally kept simple
core.register_chatcommand("tc", {
	params = "[<message>]",
	description = "Join the town chat channel, or use [<message>] to send a message to the channel.",
	privs = {towny = true},
	func =

function (player_name, params)
	local res = towny.residents[player_name]
	local town = res.town

	if not town then
		return false, "You are not currently in a town."
	end

	if params:len() > 0 then
		chat_send_town(town, chat.channel_names[chat.CHANNEL_TOWN] .. " <" .. res:get_display_name() .. "> " .. params)
		return true
	else
		chat.channels[player_name] = chat.CHANNEL_TOWN
		return true, "You have joined the town channel."
	end
end})

-- global channel
core.register_chatcommand("g", {
	params = "[<message>]",
	description = "Join the global channel, or use [<message>] to send a message to the channel.",
	privs = {towny = true},
	func =

function (player_name, params)
	if params:len() > 0 then
		local old_channel = chat.channels[player_name]
		chat.channels[player_name] = chat.CHANNEL_GLOBAL

		local i
		for i = 1, #core.registered_on_chat_messages do
			if core.registered_on_chat_messages[i](player_name, params) then
				break
			end
		end

		chat.channels[player_name] = old_channel
		return true
	else
		chat.channels[player_name] = chat.CHANNEL_GLOBAL
		return true, "You have joined the global channel."
	end
end})

