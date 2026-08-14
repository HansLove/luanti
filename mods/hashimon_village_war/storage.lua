hashimon_vwar = hashimon_vwar or {}

hashimon_vwar.war_villages = hashimon_vwar.war_villages or {}
hashimon_vwar.war_names = hashimon_vwar.war_names or {}

local function storage_path()
	return core.get_worldpath() .. "/hashimon_vwar/war_villages.json"
end

function hashimon_vwar.is_village_at_war(village_id)
	return hashimon_vwar.war_villages[village_id] == true
end

function hashimon_vwar.village_display_name(village_id)
	if hashimon_vwar.war_names[village_id] then
		return hashimon_vwar.war_names[village_id]
	end
	if mg_villages and mg_villages.all_villages and mg_villages.all_villages[village_id] then
		return mg_villages.all_villages[village_id].name or village_id
	end
	return tostring(village_id)
end

function hashimon_vwar.load_war_villages()
	local path = storage_path()
	local f = io.open(path, "r")
	if not f then
		hashimon_vwar.war_villages = {}
		hashimon_vwar.war_names = {}
		return
	end
	local raw = f:read("*a")
	f:close()
	local ok, data = pcall(core.parse_json, raw)
	if not ok or type(data) ~= "table" then
		core.log("warning", "[hashimon_village_war] Could not parse war_villages.json")
		hashimon_vwar.war_villages = {}
		hashimon_vwar.war_names = {}
		return
	end
	hashimon_vwar.war_villages = {}
	hashimon_vwar.war_names = type(data.names) == "table" and data.names or {}
	if type(data.village_ids) == "table" then
		for _, id in ipairs(data.village_ids) do
			if type(id) == "string" and id ~= "" then
				hashimon_vwar.war_villages[id] = true
			end
		end
	end
end

function hashimon_vwar.save_war_villages()
	local dir = core.get_worldpath() .. "/hashimon_vwar"
	core.mkdir(dir)
	local ids = {}
	for id, _ in pairs(hashimon_vwar.war_villages) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	local payload = core.write_json({
		village_ids = ids,
		names = hashimon_vwar.war_names,
	})
	local f = io.open(storage_path(), "w")
	if not f then
		core.log("error", "[hashimon_village_war] Could not write war_villages.json")
		return false
	end
	f:write(payload)
	f:close()
	return true
end

function hashimon_vwar.declare_war(village_id)
	if not village_id then
		return false, "not_in_village"
	end
	hashimon_vwar.war_villages[village_id] = true
	hashimon_vwar.war_names[village_id] = hashimon_vwar.village_display_name(village_id)
	hashimon_vwar.save_war_villages()
	if hashimon_vwar.sync_war_map_markers then
		hashimon_vwar.sync_war_map_markers()
	end
	return true, hashimon_vwar.war_names[village_id]
end

function hashimon_vwar.end_war(village_id)
	if not village_id then
		return false, "not_in_village"
	end
	if not hashimon_vwar.war_villages[village_id] then
		return false, "not_at_war"
	end
	hashimon_vwar.war_villages[village_id] = nil
	hashimon_vwar.war_names[village_id] = nil
	hashimon_vwar.save_war_villages()
	if hashimon_vwar.sync_war_map_markers then
		hashimon_vwar.sync_war_map_markers()
	end
	return true, village_id
end

function hashimon_vwar.end_all_wars()
	hashimon_vwar.war_villages = {}
	hashimon_vwar.war_names = {}
	hashimon_vwar.save_war_villages()
	if hashimon_vwar.sync_war_map_markers then
		hashimon_vwar.sync_war_map_markers()
	end
end

function hashimon_vwar.list_war_villages()
	local out = {}
	for id, _ in pairs(hashimon_vwar.war_villages) do
		out[#out + 1] = {
			id = id,
			name = hashimon_vwar.village_display_name(id),
		}
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end
