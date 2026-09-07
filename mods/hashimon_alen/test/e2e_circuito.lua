local pass, fail = 0, 0
local function check(l,c,d) if c then pass=pass+1;core.log("action","CIRC OK   "..l)
  else fail=fail+1;core.log("error","CIRC FAIL "..l.." :: "..tostring(d)) end end
local function finish()
  core.log("action", string.format("CIRC RESULT pass=%d fail=%d", pass, fail))
  core.request_shutdown("circuito done")
end

core.after(0.5, function()
  hashimon_alen.reset_state()
  local at = { x = 412, y = 74, z = -186 }
  hashimon_alen.birth(at)
  core.emerge_area({x=at.x-16,y=at.y-16,z=at.z-16},{x=at.x+16,y=at.y+16,z=at.z+16},
  function(_b,_a,rem) if rem ~= 0 then return end
    core.forceload_block(at, true)
    hashimon_alen.OBSERVE_OUT = 1e9
    check("entidad viva", hashimon_alen.spawn_entity() ~= nil)

    -- 1. El mundo ve algo nuevo y lo sube. Eso es lo que despierta al planificador.
    hashimon_alen.note_event("nuevo_jugador", "ramon", { dist = 34 })
    hashimon_alen.REPORT_INTERVAL = 0.5
    core.log("action", "CIRC  novedad anotada; subiendo informe...")

    -- 2. Esperamos a que el servidor piense y encole.
    core.after(12, function()
      hashimon.fetch_alen_orders(hashimon.get_server_secret(), function(ok, err, list)
        check("poll tras el informe", ok == true, err)
        check("el planificador encoló una orden", #(list or {}) >= 1,
          "recibidas " .. #(list or {}))
        if #(list or {}) == 0 then return finish() end

        -- Sin jugadores el motor desactiva la entidad mientras esperábamos al
        -- servidor. La ficha sigue viva, así que basta con reproyectarla.
        if not (hashimon_alen._live and hashimon_alen._live:get_luaentity()) then
          hashimon_alen.spawn_entity()
        end

        local o = list[1]
        core.log("action", "CIRC  plan del modelo: " .. core.write_json(o.plan.verbs))
        check("el plan trae origen 'model'", o.source == "model", o.source)
        local result, detail = hashimon_alen.apply_order(o)
        check("EL MUNDO ACEPTÓ EL PLAN DEL MODELO", result == "applied", detail)
        hashimon.ack_alen_order(hashimon.get_server_secret(), o.id, result, detail)

        local live = hashimon_alen._live:get_luaentity()
        check("el plan quedó cargado", live.plan ~= nil, live.plan)
        check("y arrastra el id de la orden para poder puntuarlo",
          live.plan and live.plan.origin_id == o.id, live.plan and live.plan.origin_id)

        -- 3. Lo damos por completado: el mundo emite el veredicto que puntúa la habilidad.
        hashimon_alen.clear_plan(live, "completado")
        core.after(2, function() core.after(2, finish) end)
      end)
    end)
  end)
end)
