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

### Documentación (`99e743f`)
- [x] `docs/spec.md`, `docs/plan.md`, `docs/tasks.md` y regla de mantenerlos al día en `CLAUDE.md`.

### Fase 8 — Personajes visibles (`32d5076`) · R9
- [x] Personajes equipados de todos los jugadores que siguen a su dueño en formación (`FollowerController`).
- [x] Arco alrededor del objetivo y embestida en cada golpe del servidor (`Remotes.CharacterHit`).
- [x] Equipo replicado en el atributo `EquippedCharacters`; `InventoryOps.activeTeam` compartido con el combate.
- [x] Convención `ReplicatedStorage.CharacterModels.<Isla>.<Id>` con bloque provisional si falta el modelo.
- [x] 70 rigs R6 provisionales en `assets/` (42 luchadores, 24 enemigos de isla, 4 de Raid; el 5.º de Raid, `Strong`, llegó en `90e577c`), uno por modelo, generados con `tools/build_rigs.py` y sincronizados por Rojo; listos para exportar a Blender.
- [x] `EnemyService`, `EnemyController` y `FollowerController` aceptan rigs: solo se ancla la raíz, se apoyan por su punto más bajo, el clic vale en cualquier parte del enemigo y las barras y nombres van sobre la cabeza. Formación a 5 studs (los rigs miden 4 de ancho).
- [x] Pruebas: `followers.spec` (formación, arco, embestida, marcha, giro) y `activeTeam` en `inventory.spec`. `tests/run.py` incluye `src/client`.
- [x] Caminan por el suelo en lugar de flotar: misma velocidad para todos (dueño ×1.25), pies sobre el terreno y ciclo de caminar R6 en hombros y caderas.
- [x] Probado en Studio: formación, arco, embestidas, caminar, rigs de luchadores y enemigos.

### Fase 9 — Islas, mar, ambientación y arena de Raid (`7d85911`, `a582cd1`, `74b3aec`, `b5a0b0e`) · R5, R9
- [x] Dirección de arte por isla en `docs/game-design.md`.
- [x] `Shared/Config/World` (islas en el mar, mar cartoon) y `Shared/Config/Ambience` (look por área).
- [x] Plugin Island Builder: `Gen` (Rng, Shape, Scatter, LayoutCheck), `Kit` (Parts, TerrainWriter, Sea, Gameplay, Nature), `IslandBuilder`, `RaidLobby`, panel con construir, validar y puntos de foto.
- [x] Nameku v1: aldea de domos, árboles de copa redonda, mesetas en el mar, nave esférica del jefe, plaza con cristales.
- [x] Lobby de Raids como templo flotante.
- [x] `MapCheck`/`MapScan` + `Dev/MapValidator`; atributo `CurrentArea`; `AmbienceController` y `SeaController`; precarga del streaming al teletransportar.
- [x] Textura del mar generada (`tools/build_textures.py`), subida a Roblox y puesta en `World.Sea.textureId` (`rbxassetid://133815183624535`).
- [x] Pruebas: `worldgen.spec` (incluye las reglas de trazado de las 6 islas) y `map.spec`.
- [x] Corregido: el plugin fallaba con "Decoration is not a valid member of Terrain" (esa propiedad solo se cambia en Propiedades; ahora el panel avisa). `tools/typecheck.py` añade una pasada que detecta este tipo de error.
- [x] Construido y probado en Studio: validador sin errores (142 partes etiquetadas), combate y personajes funcionando en Nameku.
- [x] Tres rondas de capturas de Nameku: océano hasta el horizonte, colores menos monocromáticos, agua más profunda, menos neblina, fondo marino oscuro (`Mud`), noche de Demon Corps más legible, barras de vida con tamaño en el mundo (hasta 150 studs), enemigos a 24 studs, piezas del mar bloqueadas (`Locked`). Estilo de Nameku aprobado.
- [x] Relieve en el generador: siluetas de costa (alargada, lóbulos, bahías), montañas, terrazas, ríos con cascadas y lagos con nivel de agua propio, caminos con rampas; reglas nuevas en `LayoutCheck` y pruebas.
- [x] Kono, Clover Kingdom, Titan Village, Hero Academy y Demon Corps con trazado, terreno y decoración propios (`Islands/<Isla>Layout` + `Islands/<Isla>`); `Kit/Buildings`, `Gen/PathWalk` y árboles gigantes; se elimina `Generic`.
- [x] Dos rondas de capturas de las 5 islas nuevas: títulos con tamaño en studs, cámaras de foto despejadas, ciudad de Hero pavimentada y más oscura con menos farolas, ruinas con ventanas, muralla de Titan nivelada y con detalle, ciudad de Titan en anillos, glicinas y noche más clara en Demon Corps, cascada de Kono orientada a lo largo de la caída, casas de Clover solo en terreno suave. Las 6 islas aprobadas tal cual.
- [x] Arena de Raid (coliseo flotante): `RaidArena` en el plugin guarda la plantilla `ServerStorage.RaidArena` y una vista previa para fotos que el servidor borra; `RaidArenaLayout` con pruebas en `map.spec`. Una ronda de capturas (piedra y arena neutras, luz del Raid menos naranja, antorchas suaves, suelo sin caras). Arena aprobada.

### Herramientas (`304f8fb`)
- [x] Constitución revisada: plan aprobado, Check-UI como estilo oficial, StyLua y selene.
- [x] luau, luau-lsp, StyLua y selene fijados en `rokit.toml` e instalados con `rokit install` (excepciones de GitHub en AVG); `LUAU_DEFINITIONS` de usuario. `tools/typecheck.py` falla si no encuentra los tipos de Roblox.
- [x] `stylua.toml` (tabs, 120 columnas) y todo el código formateado.
- [x] selene con `std = "roblox+tests"`: `tools/selene_std.py` genera la std de Roblox (la descarga de selene se rinde con la red lenta), `tests.yml` declara los globales de las pruebas. 0 errores y 0 avisos.

### Revisión general y arreglos de Raids y Yenes (`90e577c`)
- [x] Revisados `CLAUDE.md`, `docs/spec.md`, `docs/plan.md` y `docs/tasks.md`, y el código de los servicios del servidor contra R1 a R7 (validación, límites contra spam, cobros, recompensas y logros).
- [x] `tests/acceptance.spec.luau`: criterios de aceptación numéricos de R1 a R7 en una sola prueba.
- [x] Corregido: un jugador en la fila de un Raid que volvía a una isla seguía en la fila; ahora salir del lobby (portal o reaparecer) lo saca.
- [x] Corregido: los Raids no pasaban de la primera oleada. `EnemyService.Died` era un `BindableEvent`, que entrega una copia del enemigo; ahora los eventos entre servicios usan `Server.Signal` (`signal.spec`).
- [x] Portal de salida dentro del coliseo (`Gameplay.raidExit`, Part `RaidExit`): mantenerlo 0.5 s lleva al lobby de Raids con "Abandonaste el Raid".
- [x] Raids de 20 oleadas siempre (`DevCheats` ya no los acorta). Tipo nuevo "Fuerte" (`Strong`, rig generado); cada oleada trae 4 débiles + 2 medianos + 1 fuerte con ×1.03 de vida y Yenes por oleada; mini jefe en la 10 y jefe final en la 20, en el centro del coliseo (`RaidOps.waveSpots`); el resto en puntos aleatorios de la pista. Balance recalculado (Raid solo ~24 min; Gemas totales 370 / 920 / 2,240).
- [x] Yenes como monedas flotantes: `CoinService`, `CoinOps` (`coins.spec`), `CoinController`, `DataService.Releasing` para pagar lo pendiente antes del guardado; también en los Raids (las Gemas siguen directas).
- [x] Personajes y enemigos intangibles (`Shared/Intangible`, grupos `Intangible` y `Players`). Corregido: al principio no se podía atacar porque el grupo no chocaba con `Default` y los clics lo ignoraban.

## Pendiente

### Fase 10 — Efectos y sonido · R9 (en curso)
- [x] Números de daño y efectos al golpear (`7806edd`): `HitEffectController` y `Effects/HitStyle` (`effects.spec`). El daño sale al conectar la embestida, del color de la rareza del personaje; propios grandes, de otros pequeños y solo cerca; destello y chispas al golpear y humo al morir.
- [ ] **Animación de la tirada del gacha por rareza.** Sin cambios en el servidor (`GachaResult` ya trae personaje y rareza):
  - [ ] Lógica pura de la animación (`Effects/GachaReveal`: fases, duración por rareza, colores y si se puede saltar) con pruebas.
  - [ ] Secuencia sobre la máquina: el orbe tiembla y brilla, estalla en el color de la rareza y aparece el modelo del personaje girando con su nombre y su rareza.
  - [ ] Más larga y vistosa cuanto más rara: Común y Poco común cortas; Legendario y Mítico con rayos de luz; Secreto con destello en pantalla y colores arcoíris.
  - [ ] Se puede saltar con un clic o toque, y las tiradas seguidas no se pisan (cola).
  - [ ] Probar en Studio con cada rareza (atajo temporal en `DevCheats` para forzar una rareza, que se quita con él).
- [ ] **Sonidos.**
  - [ ] Elegir o subir los audios (biblioteca de Roblox o propios) y guardar sus ids en un `Shared/Config/Sounds`.
  - [ ] `SoundController` (cliente): golpes (por rareza), muerte de enemigo, recoger monedas (tono que sube en cadena), tirada y revelado del gacha por rareza, portales (viajar y desbloquear), Raid (empieza, oleada, mini jefe, jefe, completado, fallido), boost activado, clic y hover de la UI.
  - [ ] Sonido 3D en el mundo (golpes, monedas, portales) y 2D en la UI; volumen limitado cuando suenan muchos a la vez.
- [ ] **Música por área.**
  - [ ] Una pista por isla, por el lobby de Raids y por el Raid (con otra para el jefe final), en `Config/Ambience` o `Config/Sounds`.
  - [ ] Cambio con fundido al cambiar el atributo `CurrentArea`.
- [ ] Opciones de sonido: activar o desactivar música y efectos (se guardan en los datos del jugador). La ventana de Ajustes con Check-UI va en la Fase 11.
- [ ] Probar en Studio los números de daño, los efectos, el gacha y el sonido (con varios jugadores si es posible).
- [ ] Documentos al día (constitución, spec, plan, diseño) y commit.

### Fase 11 — UI Check-UI · R8
- [ ] Cargar la skill `check-ui-clean-roblox` y pasar sus constantes a `UI/Theme`: lienzo `#3B5866`, GothamBlack con contorno, cabeceras por tipo de menú con divisor de dos líneas, damero con degradado, colores de la tríada de botones.
- [ ] Constructores en `UI/Theme` (o `UI/Components`): ventana, cabecera, botón de cerrar `[X]` con relieve, botón estándar sin icono, botón con estados (Reclamar, Reclamado, Bloqueado), barra de progreso, tarjeta de personaje.
- [ ] Escalado por pantalla (`UIScale` según `ViewportSize`, base 1050 × 620, entre 0.52 y 1.18) e interacciones desde el centro (salto al pasar y al pulsar).
- [ ] Rehacer el HUD: Yenes y Gemas, boosts activos con su tiempo, botones laterales (no tapan el joystick en móvil).
- [ ] Rehacer el inventario: tarjetas por rareza, equipar y desequipar, "Equipar mejores", eliminar con confirmación, ampliar espacio.
- [ ] Rehacer el resultado del gacha junto con la animación de la Fase 10.
- [ ] Rehacer la tienda de boosts, el estado del Raid (oleada, tiempo, fila) y los avisos (`Notify`).
- [ ] Ventana de Ajustes (música y efectos) con el arquetipo Settings de Check-UI.
- [ ] Iconos de `CheckUIIcons` donde aporten (Yenes, Gemas, boosts, Raids) con `ScaleType.Fit`; comprobar que los ids siguen disponibles.
- [ ] Probar en Studio en PC, en el emulador de móvil y tableta, y con mando.
- [ ] Documentos al día y commit.

### Fase 12 — Prueba temprana en servidor publicado
- [ ] Publicar la experiencia en privado (Configuración del juego: acceso a la API, streaming activado).
- [ ] Guardado entre sesiones: salir y volver con monedas, personajes, equipados, islas, pity, boosts y progreso de Raids.
- [ ] Bloqueo de sesión: entrar en un segundo servidor mientras el primero guarda.
- [ ] Raid con 2 o más jugadores: fila, oleadas, recompensas y monedas para cada uno, portal de salida, logros.
- [ ] Varios jugadores en una isla: personajes visibles y números de daño de los demás, rendimiento con muchos golpes.
- [ ] Probar en un móvil real: controles, UI y rendimiento.
- [ ] Anotar y corregir lo que falle antes de la publicación.

### Fase 13 — Publicación
- [ ] Eliminar `src/server/Dev/DevCheats.luau` y su llamada en `Main.server.luau`.
- [ ] Borrar los datos de prueba del DataStore (o empezar con un DataStore nuevo).
- [ ] Revisar el balance con partidas reales (primera tirada, coste de portales, duración de los Raids, Gemas por hora) y ajustar `docs/balance.md` y las pruebas.
- [ ] Página de la experiencia: nombre, descripción, icono y miniaturas (con los puntos de foto del plugin), clasificación de edad, dispositivos (PC, móvil, consola).
- [ ] Revisión final en un servidor publicado y paso de privado a público.

### En paralelo — Modelos finales de Blender
- [ ] Exportar un rig con *Export Selection* y abrirlo en Blender (primer paso del flujo).
- [ ] Modelos finales para los 42 luchadores y los 29 enemigos (24 de isla y 5 de Raid), sustituyendo los rigs de `assets/` con el mismo nombre y ruta (flujo en `docs/plan.md`, Modelos y Blender).

### Pendientes de verificar en Studio
- [ ] Reconstruir el mundo y comprobar que la textura del mar se ve y se desplaza.
- [ ] Raid completo: las 20 oleadas con enemigos de los tres tipos en sitios distintos, el mini jefe y el jefe en el círculo dorado, el portal de salida lleva al lobby.
- [ ] Monedas: caen al derrotar un enemigo, vuelan al acercarse y suben los Yenes del HUD en el momento; las no recogidas se pagan solas a los 30 s.
- [ ] El jugador atraviesa enemigos y luchadores, y sigue pudiendo seleccionar enemigos con clic.
- [ ] Números de daño, destellos y humo al morir.
- [ ] Ponerse en la fila de un Raid, volver a Nameku por el portal y comprobar que sale de la fila.
- [ ] Guardado entre sesiones con "Enable Studio Access to API Services".
- [ ] Línea naranja fina sobre el mar entre Kono y Clover Kingdom en la vista aérea de Kono: comprobar si es una pieza o un reflejo del agua lejana.
