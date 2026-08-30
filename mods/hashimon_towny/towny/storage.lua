-- A township system for Minetest servers.
-- The MIT License - 2024  Olivia May <oliviamay@tuta.com>

local function update_data(data, class)
	for k, v in pairs(class) do
		if data[k] == nil then
			if type(v) == "table" then
				data[k] = table.copy(v)
			else
				data[k] = v
			end
		end
	end
end

-- resident class constructor for when storage is loaded
function towny.resident.new_from_data(data)
	local class = towny.resident

	setmetatable(data, class)

	update_data(data, class)

	return data
end

-- block class constructor for when storage is loaded
function towny.block.new_from_data(data)
	local class = towny.block

	setmetatable(data, class)

	data.blockpos = vector.new(data.blockpos.x, data.blockpos.y, data.blockpos.z)
	data.pos_min = vector.new(data.pos_min.x, data.pos_min.y, data.pos_min.z)

	update_data(data, class)

	return data
end

-- town class constructor for when storage is loaded
function towny.town.new_from_data(data)
	local class = towny.town

	setmetatable(data, class)

	local pos = data.pos
	data.pos = vector.new(pos.x, pos.y, pos.z)
	for i = 1, #data do
		towny.block.new_from_data(data[i])
	end

	update_data(data, class)

	return data
end

local RESIDENT_DATA = 1
local TOWN_DATA = 2

function towny.storage_save()
	local data = {towny.residents, towny.town_array}
	local data_str = core.serialize(data)
	towny.storage:set_string("data", data_str)
	towny.dirty = false
end

-- called just after initialization
function towny.storage_load()
	local serialized_data = towny.storage:to_table().fields.data
	if serialized_data then
		local data = core.deserialize(serialized_data)
		local residents = data[RESIDENT_DATA]
		local town_array = data[TOWN_DATA]

		if residents then
			towny.residents = residents
			for _, res in pairs(residents) do
				towny.resident.new_from_data(res)
			end
		end
		if town_array then
			towny.town_array = town_array
			for i = 1, #town_array do
				towny.town.new_from_data(town_array[i])
			end
		end
	end
end

-- delete all data
function towny.delete_all_data()

	-- storage
	towny.storage:set_string("data", "")

	-- memory
	local i
	for res_name, _ in pairs(towny.residents) do
		towny.residents[res_name] = nil
	end

	for i = 1, #towny.town_array do
		towny.town_array[i] = nil
	end

	core.request_shutdown("All towny data was deleted by towny admin", false, 0)
end

core.register_on_mods_loaded(function ()

	print("[towny] Loading towny storage.")
	towny.storage_load()
end)

core.register_on_shutdown(function ()

	print("[towny] Saving towny memory to storage.")
	towny.storage_save()
end)

local clock = 0

core.register_globalstep(function (dtime)
	clock = clock + dtime
	if not towny.dirty then
		return
	end
	-- Autosave every x seconds
	if clock > towny.settings.autosave_interval then
		print("[towny] Autosaving towny memory to storage.")
		towny.storage_save()

		clock = 0
	end
end)
