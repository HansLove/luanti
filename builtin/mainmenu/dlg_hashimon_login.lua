-- Luanti
-- SPDX-License-Identifier: LGPL-2.1-or-later
--
-- Hashimon client: single login dialog replacing the generic main menu.

local DEFAULT_ADDRESS = "voxel.hashima.xyz"
local DEFAULT_PORT = 30000
local REGISTER_URL = "https://hashimon.app/register"

local function get_address()
	local address = core.settings:get("address")
	if address and address ~= "" then
		return address
	end
	return DEFAULT_ADDRESS
end

local function get_port()
	return tonumber(core.settings:get("remote_port")) or DEFAULT_PORT
end

local function login_formspec(dialogdata)
	return table.concat({
		"formspec_version[4]",
		"size[8,7.5]",
		"set_focus[", (dialogdata.name ~= "" and "password" or "name"), "]",
		"label[0.375,0.8;Hashimon]",
		"field[0.375,1.575;7.25,0.8;name;Name;",
				core.formspec_escape(dialogdata.name), "]",
		"pwdfield[0.375,2.875;7.25,0.8;password;Password]",
		dialogdata.error and ("box[0.375,3.75;7.25,0.6;darkred]label[0.625,4.05;" ..
				core.formspec_escape(dialogdata.error) .. "]") or "",
		"button[0.375,4.55;3.5,0.8;btn_login;Play]",
		"button[4.125,4.55;3.5,0.8;btn_register;Register]",
		"button[0.375,5.55;3.5,0.8;btn_settings;Settings]",
		"button[4.125,5.55;3.5,0.8;btn_exit;Exit]",
		"label[0.375,6.85;Owner accounts are created at ", REGISTER_URL, "]",
	}, "")
end

local function login_buttonhandler(this, fields)
	this.data.name = fields.name or this.data.name
	this.data.error = nil

	if fields.btn_login or fields.key_enter then
		if this.data.name == "" then
			this.data.error = "Missing name"
			return true
		end

		gamedata.mode = "join"
		gamedata.playername = this.data.name
		gamedata.password = fields.password
		gamedata.address = get_address()
		gamedata.port = get_port()
		gamedata.allow_login_or_register = "login"
		gamedata.selected_world = 0

		core.settings:set("name", this.data.name)
		core.start()
		return true
	end

	if fields.btn_register then
		local dlg = create_register_dialog(get_address(), get_port(), nil)
		dlg:set_parent(this)
		this:hide()
		dlg:show()
		return true
	end

	if fields.btn_settings then
		local dlg = create_settings_dlg()
		dlg:set_parent(this)
		this:hide()
		dlg:show()
		return true
	end

	if fields.btn_exit then
		core.close()
		return true
	end

	return false
end

local function login_eventhandler(event)
	if event == "MenuQuit" then
		core.close()
		return true
	end
	return false
end

function create_hashimon_login_dlg()
	local retval = dialog_create("hashimon_login",
			login_formspec,
			login_buttonhandler,
			login_eventhandler)
	retval.data.name = core.settings:get("name") or ""
	return retval
end
