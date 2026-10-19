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

## Pendiente

### Fase 8 — Personajes visibles · R9 (siguiente)
- [ ] Modelos de personajes equipados que siguen al jugador en formación.
- [ ] Vuelo hasta el objetivo y animación de golpe sincronizada con el cooldown.
- [ ] Convención de modelos por personaje con placeholder.
- [ ] Pruebas de la lógica de formación/sincronización.

### Fase 9 — Contenido · R5, R9
- [ ] Construir en Studio los mapas de las 6 islas con las etiquetas de `CLAUDE.md`.
- [ ] Modelos de enemigos (`ServerStorage.EnemyModels`) y arena de Raid (`ServerStorage.RaidArena`).
- [ ] Modelos de los 42 personajes.

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
