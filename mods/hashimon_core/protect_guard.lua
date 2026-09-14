-- Outermost guard for core.is_protected.
--
-- Mobs (mobs_redo, animalia, …) call is_protected(pos, "") to ask "may I grief?".
-- mg_villages (and anything that check_player_privs's that name) then hits our
-- auth mirror with an empty player → log flood / main-thread stall when many
-- towns/villages/ABMs are live. Returning true (= protected) for anonymous
-- names is the safe default: no grief, no priv lookup, no get_auth('').
--
-- Wrapped in core.after(0) so we sit OUTSIDE every other mod's monkey-patch
-- (advtrains, leads, mg_villages, vwar) registered during load / on_mods_loaded.

core.register_on_mods_loaded(function()
	core.after(0, function()
		local prev = core.is_protected
		core.is_protected = function(pos, name)
			if type(name) ~= "string" or name == "" then
				return true
			end
			return prev(pos, name)
		end
		core.log("action",
			"[hashimon_core] is_protected guard active: empty name → protected (no priv/auth)")
	end)
end)
