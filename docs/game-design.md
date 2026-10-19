# Anime Legends — Diseño de juego

Fuente de verdad del diseño. Los valores numéricos finales se trasladan a `src/shared/Config/` y `src/shared/Data/`.

## Islas

Orden de progresión (de menor a mayor dificultad y costo de portal):

| # | Isla | Anime |
|---|------|-------|
| 1 | Nameku | Dragon Ball |
| 2 | Kono | Naruto |
| 3 | Clover Kingdom | Black Clover |
| 4 | Titan Village | Attack on Titan |
| 5 | Hero Academy | My Hero Academia |
| 6 | Demon Corps | Demon Slayer |

- La dificultad de cada isla (vida de enemigos y jefe) es proporcional al daño de los personajes de esa misma isla, para que el grinding se sienta bien.
- Cada isla tiene zonas de spawn de enemigos y un jefe final.
- Los enemigos tienen cuatro rangos: Fácil, Medio, Difícil y Jefe. Valores en `docs/balance.md`.
- Los enemigos normales reaparecen 20 segundos después de ser derrotados.
- Los jefes reaparecen 1 minuto después de ser derrotados.

## Personajes por isla

Cada isla tiene un personaje por rareza. Los nombres finales del juego llevarán una pequeña variación.

| Rareza | Nameku | Kono | Clover Kingdom | Titan Village | Hero Academy | Demon Corps |
|---|---|---|---|---|---|---|
| Común | Krilin | Sakura | Noelle | Connie | Mineta | Zenitsu |
| Poco común | Yamcha | Yamato | Magna | Armin | Uraraka | Inosuke |
| Raro | Piccolo | Shikamaru | Charmy | Hanje | Shoto | Nezuko |
| Épico | Freezer | Sasuke | Fuegoleon | Zeke | Deku | Tanjiro |
| Legendario | Gohan | Kakashi | Yami | Mikasa | Hawks | Tomioka |
| Mítico | Vegeta | Itachi | Julius | Levi | Shigaraki | Akaza |
| Secreto | Goku SSJ1 | Naruto 4 Tails | Asta Devil Union | Eren | All Might | Rengoku |

### Nombres en el juego (provisionales)

Variaciones usadas en `src/shared/Data/Characters.luau`. Se pueden cambiar libremente: el `id` interno usa el nombre original.

| Rareza | Nameku | Kono | Clover Kingdom | Titan Village | Hero Academy | Demon Corps |
|---|---|---|---|---|---|---|
| Común | Kurilin | Sakara | Noella | Conny | Mineto | Zenitzu |
| Poco común | Yamucha | Yamado | Magno | Armen | Urarako | Inozuke |
| Raro | Pikkolo | Shikamarou | Charmi | Hanjie | Shotto | Nezuco |
| Épico | Freezor | Sazuke | Fuegolion | Zeek | Dekku | Tanjiru |
| Legendario | Gohen | Kakashy | Yamy | Mikaza | Hawkz | Tomiokka |
| Mítico | Vejita | Itashi | Julios | Levy | Shigaraky | Akazza |
| Secreto | Gokuh SSJ1 | Narutto 4 Tails | Azta Devil Union | Erem | All Mighty | Rengokku |

## Gacha

Probabilidades (suman 100%):

| Rareza | Probabilidad |
|---|---|
| Común | 50% |
| Poco común | 25% |
| Raro | 13.9% |
| Épico | 8% |
| Legendario | 2% |
| Mítico | 1% |
| Secreto | 0.1% |

### Pity (obtención garantizada)

| Rareza | Tiradas hasta garantía |
|---|---|
| Legendario | 500 |
| Mítico | 5,000 |
| Secreto | 1,000,000 |

El pity de Secreto es intencionalmente alto: con 0.1% de probabilidad un Secreto sale en promedio cada 1,000 tiradas, así que la garantía casi nunca se activa. Es una decisión de diseño confirmada.

Reglas del pity:
- Hay un contador por isla y por rareza (Legendario, Mítico y Secreto), independientes entre sí.
- Cada tirada en el gacha de una isla suma 1 a los tres contadores de esa isla.
- Un contador vuelve a 0 cuando se obtiene esa rareza en esa isla, ya sea por suerte o por pity.
- Obtener una rareza no reinicia los contadores de las otras (sacar un Mítico no reinicia el pity de Legendario).

## Combate

- El jugador elige el objetivo haciendo clic en un enemigo. Sus personajes equipados lo atacan automáticamente mientras esté a menos de 60 studs; si se aleja más, pierde el objetivo.
- El primer golpe de cada personaje es inmediato; después golpea cada vez que termina su cooldown. Desequipar y volver a equipar no reinicia el cooldown.
- Todos los jugadores que golpearon a un enemigo reciben la recompensa completa de Yenes cuando muere.
- Solo se puede atacar a enemigos de islas desbloqueadas.
- Cada personaje tiene daño (según su rareza) y un cooldown entre golpes. Valores: pendientes.
- Personajes equipados: 3 al inicio, hasta 6 con las ranuras extra de los logros de Raid (ver sección Raids).

## Inventario

- Capacidad inicial: 50 personajes.
- Se amplía comprando espacio con Yenes, con un costo que sube proporcionalmente.

## Economía

- **Yenes (principal):** se obtienen derrotando enemigos. Se gastan en gacha, portales y espacio de inventario.
- **Gemas (secundaria):** se obtienen en Raids. Se gastan en boosts en la tienda; otros usos: pendiente.
- **Boosts:** Suerte, Dinero y Gemas, de 15 minutos. Se obtienen como drop de enemigos en los Raids o comprándolos con Gemas en la tienda.

## Raids (MVP)

- Única fuente de Gemas en el MVP.
- Recompensan mejoras que aumentan el límite de personajes equipados (empieza en 3).
- Las Mazmorras quedan fuera del MVP.

### Acceso
- Lugar común para todos los Raids, al que se llega por un portal ubicado en la primera isla (Nameku).
- Las 3 dificultades están desbloqueadas desde el inicio.
- Tiempo de espera por jugador, independiente para cada dificultad (ver tabla de Dificultades).

### Jugadores
- Se puede jugar solo o en grupo: los jugadores que entran al Raid al mismo tiempo juegan juntos.
- Máximo 20 jugadores por Raid.
- La dificultad no cambia según el número de jugadores.

### Dificultades
Hay 3 Raids. Cada dificultad cambia la vida de los enemigos y mejora las recompensas.

| Dificultad | Vida de enemigos | Recompensas | Espera |
|---|---|---|---|
| Fácil | Baja | Base | 1 hora |
| Medio | Media | Mejores | 1 hora y media |
| Difícil | Alta | Las mejores | 2 horas |

### Ranuras extra de personajes equipados (logros de Raid)
Empieza en 3 personajes equipados. Cada logro se obtiene una sola vez y da +1 ranura:

| Logro | Ranura extra | Total equipados |
|---|---|---|
| Completar el Raid Fácil 15 veces | +1 | 4 |
| Completar el Raid Medio 25 veces | +1 | 5 |
| Completar el Raid Difícil 50 veces | +1 | 6 |

Los logros son independientes: se pueden conseguir en cualquier orden. Este sistema reemplaza la tabla anterior de Raids acumulados (10, 50, 100, 175 y 250).

### Formato
- 20 oleadas de enemigos.
- Mini jefe en la oleada 10.
- Jefe final en la oleada 20.
- Límite de tiempo: 30 minutos.

### Recompensas
Cada enemigo del Raid da Gemas y Yenes. La cantidad sube según el tipo:

| Tipo de enemigo | Recompensa |
|---|---|
| Débil | Baja |
| Mediano | Mayor que los débiles |
| Mini jefe (oleada 10) | Mayor, en proporción a los anteriores |
| Jefe final (oleada 20) | Suma grande por derrotarlo y completar el Raid |

Los enemigos del Raid también pueden soltar boosts (Suerte, Dinero o Gemas, 15 minutos). También se compran con Gemas en la tienda. Probabilidades y precios en `docs/balance.md`.

Supuestos (a confirmar):
- **Fallo:** si se acaba el tiempo, los jugadores conservan lo ganado con los enemigos derrotados, pero no reciben la recompensa del jefe final.
- **Entrada en grupo:** al entrar, el jugador espera unos segundos en una sala para que otros se unan antes de empezar.
- **Recompensa en grupo:** cada jugador recibe la recompensa completa de cada enemigo, sin repartirla.

Pendiente de definir:
- Valores numéricos de vida de enemigos y recompensas por dificultad.

## Portales

- Rayos de luz que transportan entre islas.
- Se desbloquean con Yenes. Cada portal cuesta más según la dificultad de la isla de destino.

## Guardado

- Persistencia con DataStore: monedas, inventario, personajes equipados, islas desbloqueadas, contadores de pity, mejoras de inventario, boosts y progreso de Raids.
- **Jugador nuevo:** empieza con 0 Yenes, 0 Gemas y Kurilin (Común de Nameku) equipado, para poder atacar desde el primer momento.
- **Boosts activos:** su tiempo solo corre mientras el jugador está conectado.
- **Esperas de Raid:** corren en tiempo real, también con el jugador desconectado.
- **Bloqueo de sesión:** si los datos de un jugador están abiertos en otro servidor, se reintenta la carga; si no se consigue, se expulsa al jugador con un mensaje para evitar pérdida de datos. En Studio sin acceso a la API se juega con datos temporales que no se guardan.
