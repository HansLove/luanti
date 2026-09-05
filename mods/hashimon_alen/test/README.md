# Tests de Alen

Dos suites, ambas headless y ambas se apagan solas al terminar.

## smoketest.lua — 41 comprobaciones, sin red

Frames y contrato de animación, singleton, lista blanca de verbos, guardas del
salto, memoria, ciclo de vida de la entidad y secuencia de muerte. No necesita ni
API ni Postgres.

```bash
cd 3d-world
B=~/Library/Application\ Support/minetest
mkdir -p "$B/worlds/alentest/worldmods/alen_smoketest"
cp mods/hashimon_alen/test/smoketest.lua "$B/worlds/alentest/worldmods/alen_smoketest/init.lua"
printf 'name = alen_smoketest\ndepends = hashimon_alen\n' > "$B/worlds/alentest/worldmods/alen_smoketest/mod.conf"
printf 'gameid = minetest_game\nbackend = sqlite3\nworld_name = alentest\nload_mod_hashimon_alen = true\n' > "$B/worlds/alentest/world.mt"
./bin/luanti --server --world "$B/worlds/alentest" --gameid minetest_game --port 30099 --logfile /tmp/alen.log
grep SMOKE /tmp/alen.log
```

## e2e_orders.lua — 8 comprobaciones, canal completo

Poll real contra la API, aplicación, rechazo del verbo prohibido, ack e informe.
Necesita Postgres y `pnpm dev` corriendo en `api/`, y encolar antes dos órdenes
(una legítima y una con `op: "exec_lua"`). El mundo se lanza con un `--config`
propio que lleva `secure.http_mods`, `hashimon_api_url` y
`hashimon_server_secret`.

La comprobación que importa es **`EL VERBO exec_lua FUE RECHAZADO POR EL MUNDO`**:
es la que dice que un plan de un modelo no puede ejecutar código en el servidor.

## Lo que NO pueden cubrir

Sin jugadores conectados no hay mapblocks **activos** — distinto de cargados —, así
que el motor desactiva la entidad al segundo de crearla y nunca corre su `on_step`.
`forceload_block` retiene el mapa, no la simulación. Por eso los tests llaman a
`on_step` a mano sobre la entidad real: lo que está bajo prueba es nuestro código,
no la planificación de activación del motor.

Queda fuera, y hay que mirarlo con el cliente puesto: cómo se *siente* el vuelo, si
la evasión de terreno basta en montaña de verdad, si el telegrafiado del rugido da
tiempo suficiente, y si `visual_size` y la caja de colisión están bien a ojo.
