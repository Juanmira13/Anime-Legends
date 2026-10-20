# Anime Legends — Tareas

Lista de trabajo. Cada tarea hecha indica su commit. Las fases están descritas en `docs/plan.md` y los requisitos (R1…R9) en `docs/spec.md`.

## Hecho

### Fase 0 — Base (`ff8ad4a`)
- [x] Constitución (`CLAUDE.md`), diseño (`docs/game-design.md`) y balance (`docs/balance.md`).
- [x] Rojo 7.7.1 con Rokit, `default.project.json`, `.gitignore`, repositorio en GitHub.

### Fase 1 — Datos y guardado (`332f2ac`) · R1
- [x] Config: Rarities, Balance, Raids, Boosts. Datos: Islands, 42 Characters con nombres provisionales.
- [x] `Formulas` reproduce las tablas de balance (prueba `balance.spec`).
- [x] `PlayerRecord`: datos iniciales, reconciliación, migraciones, bloqueo de sesión (prueba `player-record.spec`).
- [x] `DataService`: carga con reintentos, autoguardado, guardado al salir y al cerrar.
- [x] Probado en Studio: atributos `Yen`/`Gems` = 0.

### Fase 2 — Combate (`829bfe1`) · R2
- [x] `EnemyService` con puntos `EnemySpawn` y modelos opcionales.
- [x] `CombatService` + `AttackClock` (prueba `combat.spec`).
- [x] Barras de vida y resaltado del objetivo.
- [x] `TestArena` en Studio. Probado en Studio.

### Fase 3 — Gacha (`81ba7ff`) · R3
- [x] `GachaRoll` con pity y Suerte (prueba `gacha.spec`).
- [x] `GachaService` con `GachaStand` y ProximityPrompt; aviso del resultado.
- [x] `DevCheats` temporal (Yenes de prueba). Probado en Studio.

### Fase 4 — Inventario (`663c2cf`) · R4, R8
- [x] `InventoryOps` (prueba `inventory.spec`) e `InventoryService`.
- [x] Panel de inventario, HUD de monedas, `UI/Theme`. Probado en Studio.

### Fase 5 — Portales (`288bb92`) · R5
- [x] `PortalOps` (prueba `portal.spec`) y `PortalService`; campo `LastIsland`.
- [x] `UI/Notify` común; mundo de prueba con Nameku y Kono. Probado en Studio.

### Fase 6 — Raids (`2d3c102`) · R6
- [x] `RaidOps` (prueba `raid.spec`) y `RaidService`: lobby, filas, arenas, oleadas, recompensas, logros.
- [x] `EnemyService` generalizado para enemigos de Raid.
- [x] `RaidController`; lobby de prueba; Raids de 3 oleadas en Studio (temporal). Probado en Studio.

### Fase 7 — Boosts (`d1afd9a`) · R7
- [x] `BoostOps` (prueba `boost.spec`) y `BoostService`: activar, comprar, temporizador solo en línea.
- [x] `BoostController`; `DevCheats` da Gemas de prueba.
- [x] Probado en Studio: comprar, activar, acumular y efecto del Boost de Dinero.

### Documentación
- [x] `docs/spec.md`, `docs/plan.md`, `docs/tasks.md` y regla de mantenerlos al día en `CLAUDE.md`.

### Fase 8 — Personajes visibles · R9
- [x] Personajes equipados de todos los jugadores que siguen a su dueño en formación (`FollowerController`).
- [x] Arco alrededor del objetivo y embestida en cada golpe del servidor (`Remotes.CharacterHit`).
- [x] Equipo replicado en el atributo `EquippedCharacters`; `InventoryOps.activeTeam` compartido con el combate.
- [x] Convención `ReplicatedStorage.CharacterModels.<Isla>.<Id>` con bloque provisional si falta el modelo.
- [x] 70 rigs R6 provisionales en `assets/` (42 luchadores, 24 enemigos de isla, 4 de Raid), uno por modelo, generados con `tools/build_rigs.py` y sincronizados por Rojo; listos para exportar a Blender.
- [x] `EnemyService`, `EnemyController` y `FollowerController` aceptan rigs: solo se ancla la raíz, se apoyan por su punto más bajo, el clic vale en cualquier parte del enemigo y las barras y nombres van sobre la cabeza. Formación a 5 studs (los rigs miden 4 de ancho).
- [x] Pruebas: `followers.spec` (formación, arco, embestida, marcha, giro) y `activeTeam` en `inventory.spec`. `tests/run.py` incluye `src/client`.
- [x] Caminan por el suelo en lugar de flotar: misma velocidad para todos (dueño ×1.25), pies sobre el terreno y ciclo de caminar R6 en hombros y caderas.
- [x] Probado en Studio: formación, arco, embestidas, caminar, rigs de luchadores y enemigos.

## Pendiente

### Fase 9 — Islas · R5, R9 (en curso)
- [x] Dirección de arte por isla en `docs/game-design.md`.
- [x] `Shared/Config/World` (islas en el mar, mar cartoon) y `Shared/Config/Ambience` (look por área).
- [x] Plugin Island Builder: `Gen` (Rng, Shape, Scatter, LayoutCheck), `Kit` (Parts, TerrainWriter, Sea, Gameplay, Nature), `IslandBuilder`, `RaidLobby`, panel con construir, validar y puntos de foto.
- [x] Nameku v1: aldea de domos, árboles de copa redonda, mesetas en el mar, nave esférica del jefe, plaza con cristales.
- [x] Kono, Clover Kingdom, Titan Village, Hero Academy y Demon Corps en v0 (terreno, paleta, árboles, jugabilidad completa, hito provisional).
- [x] Lobby de Raids como templo flotante.
- [x] `MapCheck`/`MapScan` + `Dev/MapValidator`; atributo `CurrentArea`; `AmbienceController` y `SeaController`; precarga del streaming al teletransportar.
- [x] Textura del mar generada (`tools/build_textures.py`).
- [x] Pruebas: `worldgen.spec` (incluye las reglas de trazado de las 6 islas) y `map.spec`.
- [x] Corregido: el plugin fallaba con "Decoration is not a valid member of Terrain" (esa propiedad solo se cambia en Propiedades; ahora el panel avisa). `tools/typecheck.py` añade una pasada que detecta este tipo de error.
- [ ] Subir `assets/Textures/SeaCartoon.png` a Roblox y poner su id en `World.Sea.textureId`.
- [x] Construido y probado en Studio: validador sin errores (142 partes etiquetadas), combate y personajes funcionando en Nameku.
- [x] Ajustes tras la primera ronda de capturas: océano hasta el horizonte, Nameku menos monocromática (tinte más suave, copas variadas, más flores), agua más profunda, menos neblina, noche de Demon Corps más legible, enemigos a 20 studs y barras de vida hasta 90 studs, punto de foto de llegada más alto, cámara del plugin con `Focus`.
- [x] Segunda ronda de capturas: océano, colores, niebla, noche y lobby correctos.
- [x] Ajustes de la segunda ronda: fondo marino oscuro por isla (material `Mud`) para que el mar abierto se vea profundo, cámaras de foto de Nameku sin árboles delante, piezas del mar bloqueadas en Studio (`Locked`).
- [x] Tercera ronda de capturas: fotos de Nameku despejadas; jugando funcionan plaza, combate y jefe.
- [x] Ajustes de la tercera ronda: barras de vida con tamaño en el mundo (no se amontonan; visibles hasta 150 studs), enemigos a 24 studs repartidos por el 85 % de la zona, plaza de Nameku menos brillante, menos reflejo en el agua.
- [x] Estilo de Nameku aprobado.
- [ ] Iterar Nameku con capturas (*Siguiente foto*) hasta aprobar el estilo.
- [ ] Versión detallada de Kono, Clover Kingdom, Titan Village, Hero Academy y Demon Corps (una por commit).
- [ ] Arena de Raid (coliseo).
- [ ] Lista de hitos para Blender (estatuas del valle, etc.).
- [ ] Exportar un rig con *Export Selection* y abrirlo en Blender (primer paso del flujo).
- [ ] Modelos finales de Blender para los 42 luchadores y los 28 enemigos, sustituyendo los rigs de `assets/` (flujo en `docs/plan.md`, Modelos y Blender).

### Fase 10 — Efectos y sonido · R9
- [ ] Números de daño y efectos al golpear.
- [ ] Animación/efectos de tirada de gacha por rareza.
- [ ] Sonidos y música.

### Fase 11 — Publicación
- [ ] Eliminar `src/server/Dev/DevCheats.luau` y su llamada en `Main.server.luau`.
- [ ] Borrar los datos de prueba del DataStore.
- [ ] Probar en un servidor publicado: guardado entre sesiones, bloqueo de sesión, Raids con varios jugadores.
- [ ] Revisar balance con partidas reales y ajustar `docs/balance.md` + pruebas.

### Pendientes de verificar en Studio
- [ ] Guardado entre sesiones con "Enable Studio Access to API Services".
