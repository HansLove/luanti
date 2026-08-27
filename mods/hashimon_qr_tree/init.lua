hashimon_qr_tree = hashimon_qr_tree or {}

local modpath = core.get_modpath("hashimon_qr_tree")

dofile(modpath .. "/nodes.lua")
dofile(modpath .. "/placer.lua")
dofile(modpath .. "/commands.lua")

hashimon_qr_tree.sponsors = dofile(modpath .. "/sponsors.lua")
hashimon_qr_tree.storage = core.get_mod_storage()

core.register_privilege("hashimon_qr_admin", {
	description = "Place and manage hidden QR sponsor groves",
	give_to_singleplayer = true,
})

local function load_placed_state()
	local raw = hashimon_qr_tree.storage:get_string("placed")
	if raw == "" then
		hashimon_qr_tree.placed = {}
		return
	end
	local ok, parsed = pcall(core.deserialize, raw)
	hashimon_qr_tree.placed = (ok and type(parsed) == "table") and parsed or {}
end

local function save_placed_state()
	hashimon_qr_tree.storage:set_string("placed", core.serialize(hashimon_qr_tree.placed))
end

hashimon_qr_tree.save_placed_state = save_placed_state
load_placed_state()

core.register_on_mods_loaded(function()
	hashimon_qr_tree.verify_schematics()
	local auto = core.settings:get_bool("hashimon_qr_tree.auto_place", false)
	if auto then
		core.after(2, function()
			hashimon_qr_tree.place_all(nil, function(ok, msg)
				core.log("action", "[hashimon_qr_tree] auto_place: " .. (msg or tostring(ok)))
			end)
		end)
	end
	core.log("action", "[hashimon_qr_tree] Loaded " .. #hashimon_qr_tree.sponsors .. " sponsor(s)")
end)
