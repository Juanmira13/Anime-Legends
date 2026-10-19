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
  ├── InventoryService (InventoryOps) ── InventoryAction / InventoryChanged
  ├── GachaService (GachaRoll) ── usa InventoryService; GachaResult
  ├── PortalService (PortalOps) ── Unlocked_<Isla>, LastIsland; PortalResult
  ├── BoostService (BoostOps) ── BoostAction; BoostOwned_/BoostTime_
  ├── CombatService (AttackClock) ── usa EnemyService; TargetEnemyId
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

El código no depende de posiciones: lee Parts etiquetadas (`IslandSpawn`, `EnemySpawn`, `GachaStand`, `Portal`, `RaidPortal`, `RaidLobbySpawn`, `RaidPad`) y modelos opcionales de `ServerStorage`. En Studio, `Dev/TestArena` construye un mundo de prueba si no hay islas.

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
| 8 | Personajes visibles (estilo AFS) | ⏳ siguiente | — |
| 9 | Mapas de las 6 islas, modelos | ⏳ | — |
| 10 | Efectos, números de daño, sonido | ⏳ | — |
| 11 | Preparar publicación | ⏳ | — |

### Fase 8 — Personajes visibles (propuesta)

- Cliente: por cada personaje equipado, un modelo que sigue al jugador en formación y, cuando hay objetivo, vuela hasta él y hace una animación de golpe sincronizada con su cooldown.
- Servidor: sigue siendo la única autoridad del daño; envía un evento por golpe (o el cliente sigue los tiempos de `AttackClock`) solo para la animación.
- Modelos por personaje en `ReplicatedStorage` (o placeholder si no existen), con la misma convención de rutas que los enemigos.
- Pruebas: la formación y la sincronización de golpes como lógica pura.

### Fase 11 — Publicación

- Eliminar `Dev/DevCheats` y su llamada.
- Borrar los datos de prueba del DataStore.
- Comprobar en un servidor publicado: guardado, bloqueo de sesión, Raids con varios jugadores.
