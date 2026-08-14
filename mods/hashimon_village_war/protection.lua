local EXCEPTION_META = "hashimon_vwar:exception"

function hashimon_vwar.player_exception_mode(player_name)
	local player = core.get_player_by_name(player_name)
	if not player then
		return false
	end
	return player:get_meta():get_string(EXCEPTION_META) == "1"
end

function hashimon_vwar.set_player_exception_mode(player_name, enabled)
	local player = core.get_player_by_name(player_name)
	if not player then
		return false
	end
	player:get_meta():set_string(EXCEPTION_META, enabled and "1" or "")
	return true
end

function hashimon_vwar.toggle_player_exception_mode(player_name)
	local enabled = not hashimon_vwar.player_exception_mode(player_name)
	hashimon_vwar.set_player_exception_mode(player_name, enabled)
	return enabled
end

local mg_is_protected = core.is_protected

core.is_protected = function(pos, name)
	if not mg_villages or not mg_villages.ENABLE_PROTECTION then
		return mg_is_protected(pos, name)
	end

	local village_id = mg_villages.get_town_id_at_pos(pos)
	if village_id and hashimon_vwar.is_village_at_war(village_id) then
		return false
	end

	if village_id and hashimon_vwar.player_exception_mode(name) then
		return false
	end

	return mg_is_protected(pos, name)
end
