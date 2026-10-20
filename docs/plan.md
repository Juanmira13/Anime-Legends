# Anime Legends — Plan técnico

Cómo está construido el juego y en qué orden se hace. Las reglas que hay que respetar están en `CLAUDE.md`; los requisitos en `docs/spec.md`; el avance en `docs/tasks.md`.

## Stack

- Roblox Studio + Luau, sincronizado con Rojo 7.7.1 (`default.project.json`, versión fijada en `rokit.toml`).
- Guardado con DataStoreService.
- Pruebas de lógica pura con el CLI de Luau (`python tests/run.py`) y revisión de tipos con `luau-lsp` (ver `CLAUDE.md`, sección 4).

## Arquitectura

### Capas

| Capa | Dónde | Qué hace |
|---|---|---|
| Config y contenido | `src/shared/Config`, `src/shared/Data` | Constantes de balance, rarezas, Raids, boosts; islas y personajes |
| Fórmulas | `src/shared/Formulas.luau` | Todos los valores derivados (daño, vida, Yenes, costos) |
| Lógica pura | `src/server/<Sistema>/<Sistema>Ops.luau` | Reglas de cada sistema sobre los datos del jugador, sin APIs de Roblox; con pruebas |
| Servicios | `src/server/Services` | Conectan la lógica con Roblox: mapa, remotes, DataStore, temporizadores |
| Controladores | `src/client/Controllers` | Interfaz y efectos; solo leen atributos y envían peticiones |

Patrón por sistema: `XOps` (puro y probado) + `XService` (servidor) + `XController` (cliente).

### Servicios y dependencias

```
DataService ── carga/guarda PlayerRecord; Yen y Gems como atributos
  ├── InventoryService (InventoryOps) ── InventoryAction / InventoryChanged; EquippedCharacters
  ├── GachaService (GachaRoll) ── usa InventoryService; GachaResult
  ├── PortalService (PortalOps) ── Unlocked_<Isla>, LastIsland; PortalResult
  ├── BoostService (BoostOps) ── BoostAction; BoostOwned_/BoostTime_
  ├── CombatService (AttackClock) ── usa EnemyService; TargetEnemyId; CharacterHit a todos
  └── RaidService (RaidOps) ── usa EnemyService, InventoryService, BoostService; RaidEvent
EnemyService ── enemigos de isla (EnemySpawn) y de Raid (spawn); Health/MaxHealth
```

Orden de arranque (`src/server/Main.server.luau`): los servicios que escuchan `DataService.Loaded` arrancan antes que `DataService`; `TestArena` antes que `PortalService` para que existan los puntos de llegada.

### Flujo de datos

1. `DataService` carga el `PlayerRecord` con bloqueo de sesión y dispara `Loaded`.
2. Cada servicio replica su parte como **atributos del jugador** (monedas, islas, boosts, Raids, objetivo) o, para el inventario, como snapshot por remote.
3. El cliente pide acciones por `RemoteFunction`/`ProximityPrompt`/`ClickDetector`; el servidor valida con la lógica pura, cambia los datos y vuelve a replicar.
4. `DataService` autoguarda cada 2 minutos y al salir o cerrar el servidor.

### Mapa

El código no depende de posiciones: lee Parts etiquetadas (`IslandSpawn`, `EnemySpawn`, `GachaStand`, `Portal`, `RaidPortal`, `RaidLobbySpawn`, `RaidPad`) y modelos opcionales de `ServerStorage`. El mapa lo construye el plugin Island Builder en `Workspace.Map` (ver Fase 9). En Studio, `Dev/TestArena` construye un mundo de prueba si no hay islas.

## Fases

| Fase | Contenido | Estado | Commit |
|---|---|---|---|
| 0 | Constitución, diseño, balance, Rojo | ✅ | `ff8ad4a` |
| 1 | Config, datos, Formulas, guardado (DataService) | ✅ | `332f2ac` |
| 2 | Enemigos, combate, barras de vida | ✅ | `829bfe1` |
| 3 | Gacha con pity y Suerte | ✅ | `81ba7ff` |
| 4 | Inventario, HUD de monedas | ✅ | `663c2cf` |
| 5 | Portales e isla de aparición | ✅ | `288bb92` |
| 6 | Raids | ✅ | `2d3c102` |
| 7 | Boosts y tienda de Gemas | ✅ | `d1afd9a` |
| 8 | Personajes visibles (estilo AFS), rigs R6 | ✅ | ver `docs/tasks.md` |
| 9 | Islas de alta calidad, mar, ambientación, modelos | 🟡 en curso (Nameku v1, resto v0) | — |
| 10 | Efectos, números de daño, sonido | ⏳ | — |
| 11 | Preparar publicación | ⏳ | — |

### Fase 8 — Personajes visibles

- `InventoryOps.activeTeam`: equipados en orden y limitados a las ranuras; el índice es la ranura. Lo usan el combate y la replicación.
- Servidor: `InventoryService` replica el equipo como atributo `EquippedCharacters` (ids separados por comas, visible para todos). `CombatService` sigue siendo la única autoridad del daño y, en cada frame con golpes, envía `CharacterHit (dueño, enemyId, {ranura, daño})` a todos los clientes solo para animar.
- Cliente: `Followers/FollowerMotion` (puro, probado en `followers.spec`) calcula formación, arco, embestida, velocidad de marcha, ciclo de caminar y giro; `FollowerController` dibuja los personajes de cada jugador caminando sobre el suelo (raycast hacia abajo que ignora personajes y piezas sin colisión), mueve hombros y caderas con `Motor6D.Transform` en `PreSimulation`, los oculta a más de 300 studs de la cámara y los teletransporta en saltos de más de 100 studs (portales, Raids).
- Modelos en `ReplicatedStorage.CharacterModels.<Isla>.<IdPersonaje>` (rigs R6, ver abajo) con el nombre encima; bloque provisional si falta.
- El evento lleva el daño para que la Fase 10 dibuje los números sin cambiar el servidor.

### Modelos y Blender

Cada luchador y enemigo tiene su modelo en `assets/` y Rojo lo sincroniza (`default.project.json`):

| Carpeta | En Studio | Modelos |
|---|---|---|
| `assets/CharacterModels/<Isla>/<IdPersonaje>` | `ReplicatedStorage.CharacterModels` | 42 luchadores (escala 1, color de su rareza) |
| `assets/EnemyModels/<Isla>/<Rango>` | `ServerStorage.EnemyModels` | 24 enemigos de isla (Fácil 1, Medio 1.25, Difícil 1.5, Jefe 2.5) |
| `assets/EnemyModels/Raid/<Tipo>` | `ServerStorage.EnemyModels.Raid` | 4 enemigos de Raid (Débil 1, Mediano 1.25, Mini jefe 2, Jefe 3) |

`tools/build_rigs.py` genera los provisionales a partir de `Characters`, `Islands`, `Balance` y `Raids`, y nunca sobrescribe un modelo existente.

**Rig R6 (escala 1, pies en y = 0, mirando a −Z):**

| Pieza | Tamaño (studs) | Centro | Unión (Motor6D, en la pieza padre) | Punto de giro |
|---|---|---|---|---|
| `HumanoidRootPart` | 2 × 2 × 1 | (0, 3, 0) | — (invisible, anclada) | — |
| `Torso` | 2 × 2 × 1 | (0, 3, 0) | `RootJoint` en HumanoidRootPart | (0, 3, 0) |
| `Head` | 2 × 1 × 1 | (0, 4.5, 0) | `Neck` en Torso | (0, 4, 0) |
| `Right Arm` / `Left Arm` | 1 × 2 × 1 | (±1.5, 3, 0) | `Right/Left Shoulder` en Torso | (±1, 3.5, 0) |
| `Right Leg` / `Left Leg` | 1 × 2 × 1 | (±0.5, 1, 0) | `Right/Left Hip` en Torso | (±1, 2, 0) |

Los enemigos escalados multiplican tamaños, centros y puntos de giro por su escala.

**Flujo:**
1. **Exportar:** en Studio, seleccionar el modelo (p. ej. `ReplicatedStorage.CharacterModels.Nameku.Krilin`) → clic derecho → *Export Selection* (`.obj`). Sirve como referencia de proporciones; el `.obj` no lleva las uniones, que se definen con la tabla de arriba.
2. **Modelar en Blender:** una malla por pieza del R6 con el mismo nombre, dentro de la caja de su pieza y con el origen en su centro, para que los puntos de giro coincidan.
3. **Importar:** con el 3D Importer de Studio, sustituir cada `Part` del rig provisional por la `MeshPart` del mismo nombre, conservando `HumanoidRootPart`, los Motor6D (con su `Part0`/`Part1` apuntando a las nuevas piezas), `Humanoid` y `Animator`.
4. **Guardar en el repositorio:** clic derecho en el modelo → *Save to File* como `<Id>.rbxm` en la misma carpeta de `assets/` y borrar el `.rbxmx` provisional. Rojo lo sincroniza y `build_rigs.py` ya no lo toca.

### Fase 9 — Islas

**Plugin Island Builder** (`builder.project.json` → `src/builder` + copia de `src/shared`), solo en modo edición:

1. **Trazado puro** por isla (`Islands/NamekuLayout`, `Islands/GenericLayout`): radio y forma de la costa, colinas, plaza, 4 zonas planas, camino y mesetas. `Gen/LayoutCheck` revisa que plaza y zonas estén en tierra y separadas, que el camino las conecte, que ninguna meseta las invada y que quepan los enemigos (también en `worldgen.spec`).
2. **Terreno y mar** (`Kit/TerrainWriter`): `Gen/Shape` da altura y material en cada punto; se escriben vóxeles de 4 studs por bloques con `WriteVoxelChannels` (tierra y agua comparten vóxel en la orilla) y el mar abierto con `FillBlock`.
3. **Mar cartoon** (`Kit/Sea`): Part transparente con la textura `World.Sea.textureId` (etiqueta `SeaSurface`, la desplaza `SeaController`) y anillos de espuma en cada orilla (etiqueta `SeaFoam`, su transparencia oscila).
4. **Jugabilidad** (`Kit/Gameplay`) a partir del trazado: llegada, gacha, portales con arco y nombre, portal de Raids, puntos de enemigos dispersos con separación de 16 studs y carteles de zona.
5. **Decoración** propia de cada isla con el kit (`Kit/Nature`, `Kit/Parts`): toda anclada y sin `CanQuery`/`CanTouch` (no tapa clics ni rayos); los objetos pequeños no hacen sombra.
6. **Validación** (`Shared/Map/MapCheck` + `MapScan`) al terminar y al arrancar el juego en Studio, con presupuesto de 9000 Parts por área.

**Ambientación:** `Shared/Config/Ambience` por área; `Shared/Map/AmbienceApply` la aplica (plugin y cliente); `CurrentArea` la replica el servidor.

**Ciclo de calidad:** construir → *Siguiente foto* en el panel (cámaras fijas por área) → capturas → ajustes en el código de la isla → reconstruir. Nameku primero; luego una isla detallada por commit.

**Pendiente de la fase:** subir la textura del mar, iterar Nameku con capturas, versión detallada de las otras 5 islas, arena de Raid, lista de piezas para Blender (hitos difíciles con Parts).

### Fase 11 — Publicación

- Eliminar `Dev/DevCheats` y su llamada.
- Borrar los datos de prueba del DataStore.
- Comprobar en un servidor publicado: guardado, bloqueo de sesión, Raids con varios jugadores.
