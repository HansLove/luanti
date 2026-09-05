local pass, fail = 0, 0
local function check(l, c, d)
	if c then pass=pass+1; core.log("action","E2E OK   "..l)
	else fail=fail+1; core.log("error","E2E FAIL "..l.." :: "..tostring(d)) end
end
local function finish()
	core.log("action", string.format("E2E RESULT pass=%d fail=%d", pass, fail))
	core.request_shutdown("e2e done")
end

core.after(0.5, function()
	check("hashimon_core expone el canal",
		hashimon and hashimon.fetch_alen_orders ~= nil and hashimon.push_alen_state ~= nil)
	check("hay secreto de servidor configurado", hashimon.get_server_secret() ~= "")

	hashimon_alen.reset_state()
	local at = { x = 40, y = 20, z = 40 }
	hashimon_alen.birth(at)

	core.emerge_area({x=at.x-16,y=at.y-16,z=at.z-16}, {x=at.x+16,y=at.y+16,z=at.z+16},
		function(_b,_a,remaining)
			if remaining ~= 0 then return end
			core.forceload_block(at, true)
			hashimon_alen.OBSERVE_OUT = 1e9
			local obj = hashimon_alen.spawn_entity()
			check("entidad viva para recibir órdenes", obj ~= nil)

			hashimon.fetch_alen_orders(hashimon.get_server_secret(), function(ok, err, list)
				check("poll de órdenes contra la API real", ok == true, err)
				if not ok then return finish() end
				check("la API sirvió las 2 órdenes encoladas", #(list or {}) == 2, #(list or {}))

				local seen = {}
				for _, o in ipairs(list or {}) do
					local result, detail = hashimon_alen.apply_order(o)
					seen[o.id] = { result = result, detail = detail }
					core.log("action", string.format("E2E  orden #%d -> %s (%s)", o.id, result, tostring(detail)))
					hashimon.ack_alen_order(hashimon.get_server_secret(), o.id, result, detail)
				end

				check("orden legítima aplicada", seen[1] and seen[1].result == "applied",
					seen[1] and seen[1].detail)
				check("EL VERBO exec_lua FUE RECHAZADO POR EL MUNDO",
					seen[2] and seen[2].result == "rejected"
					and seen[2].detail == "verbo_no_permitido:exec_lua",
					seen[2] and seen[2].detail)

				local live = hashimon_alen._live:get_luaentity()
				check("el plan legítimo quedó cargado en la entidad",
					live.plan ~= nil and #live.plan.verbs == 2, live.plan and #live.plan.verbs)

				-- Y el informe de vuelta, con la novedad dentro.
				hashimon_alen.note_event("prueba_e2e", "diego", { nota = "vengo del mundo" })
				hashimon_alen.REPORT_INTERVAL = 0.1
				core.after(1.5, function()
					core.after(1.5, finish)
				end)
			end)
		end)
end)
