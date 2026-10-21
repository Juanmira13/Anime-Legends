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

### Mundo y mar

- Las islas están en el mar, no flotan. Están en fila, separadas 2000 studs; cada una mide unos 780 studs de diámetro, con playas y mesetas de roca que salen del agua.
- El mar es de estilo cartoon: agua del color de cada isla, una textura de líneas de luz que se mueve despacio y una franja de espuma que "respira" a lo largo de cada orilla. Un océano rodea todas las islas hasta el horizonte. La orilla es de arena (agua turquesa) y el fondo del mar abierto es oscuro, del tono del agua de cada isla, para que se vea profundo.
- El lobby de Raids es un templo flotante en el cielo, aparte de las islas.

### Recorrido de cada isla

1. **Plaza de llegada** junto a la costa sur: punto de llegada, máquina de gacha, portales a la isla anterior y a la siguiente (en Nameku, el portal de Raids ocupa el lugar del anterior). Es el escaparate de la isla.
2. **Un camino** recorre las cuatro zonas en orden, con rampas talladas en el relieve (pendiente máxima 0.5): Fácil (8 enemigos) → Media (6) → Difícil (4) → Jefe (1). Cada zona es un área plana con su cartel; los enemigos quedan a 24 studs entre sí, repartidos por casi toda la zona, y sus barras de vida tienen tamaño en el mundo (unos 7 studs de ancho, más en enemigos grandes): se achican con la distancia y no se amontonan. Se ven hasta 150 studs.
3. **El hito del jefe** se ve desde la plaza y marca hacia dónde progresar.
4. El detalle se concentra en caminos, plaza y zonas de combate; el resto es paisaje más simple para cuidar el rendimiento en móvil.

### Dirección de arte (aprobada)

Todo está *inspirado en* cada anime, sin logotipos ni copias exactas.

| Isla | Ambiente | Paleta y luz | Elementos clave | Zonas: Fácil → Media → Difícil → Jefe |
|---|---|---|---|---|
| **Nameku** | Planeta alienígena tranquilo | Cielo verde claro, agua turquesa, hierba azul verdosa; día muy brillante | Árboles de tronco fino con copa redonda, casas-domo blancas con ventanas redondas, mesetas de roca en el mar | Praderas Azules → Aldea Namek → Mesetas Rocosas → Nave del Tirano (nave esférica estrellada) |
| **Kono** | Aldea ninja en el bosque | Verdes intensos, tejados rojos y naranjas; atardecer cálido | Gran portón, casas de tejado curvo, depósito de agua, postes de entrenamiento, árboles gigantes | Campo de Entrenamiento → Calles de la Aldea → Bosque Profundo → Valle de la Cascada (estatuas en Blender) |
| **Clover Kingdom** | Reino medieval mágico | Pradera, piedra clara, toques violeta; día con chispas mágicas | Aldea humilde, castillo blanco de torres azules, cuartel oscuro, bosque con niebla violeta | Aldea Humilde → Camino Real → Bosque Embrujado → Altar del Grimorio |
| **Titan Village** | Ciudad amurallada en peligro | Tonos tierra desaturados, cielo nublado | Muralla gigante en el horizonte, casas de piedra y madera, cañones sobre el muro, árboles altísimos | Campos Exteriores → Ciudad Amurallada → Bosque Gigante → Brecha del Muro |
| **Hero Academy** | Ciudad moderna de héroes | Azul limpio, cristal, blanco y rojo; mediodía con reflejos | Campus con edificio de cristal en forma de H, calles con semáforos, ciudad de simulacro en ruinas | Campus → Avenida Central → Ciudad Simulacro → Gran Estadio |
| **Demon Corps** | Japón tradicional de noche | Azul noche, glicinas moradas, faroles cálidos; luna llena | Glicinas con pétalos cayendo, bambú con niebla, toriis, aldea con faroles | Aldea de Faroles → Bosque de Bambú → Montaña de Toriis → Tren de la Luna |

- **Lobby de Raids:** templo flotante en el cielo, con un altar por dificultad y nubes alrededor.
- **Arena de Raid:** coliseo de piedra con antorchas (pendiente).
- Partículas de ambiente por isla: polen (Nameku), hojas (Kono), chispas mágicas (Clover), polvo (Titan), pétalos (Demon Corps).
### Organización de cada isla

Cada isla tiene su propia silueta, relieve y recorrido; ninguna reutiliza el terreno de otra.

| Isla | Silueta y relieve | Recorrido (Fácil → Media → Difícil → Jefe) | Piezas propias |
|---|---|---|---|
| **Nameku** | Redonda e irregular, colinas suaves, 9 mesetas en el mar y 3 en tierra | Praderas → aldea de domos → zona rocosa → nave (subiendo de 8 a 22) | Casas-domo, árboles de copa redonda, nave esférica, cristales |
| **Kono** | Alargada de este a oeste; cordillera de hasta 110 al norte que cae al mar; terraza boscosa a 26 al este | Campo de entrenamiento al oeste → aldea en el centro → terraza de árboles gigantes → valle de la cascada al pie de la cordillera | Casas japonesas con depósitos de agua y farolillos, gran portón, depósito de agua, mercado, postes eléctricos, cascada en un desfiladero con lago y río hasta la costa oeste, dos estatuas guardianas (provisionales para Blender) |
| **Clover Kingdom** | Dos lóbulos unidos por una cintura; colina del castillo a 48 en el centro; acantilado del altar a 34 | Aldea humilde (lóbulo oeste) → camino real junto al castillo → bosque embrujado (lóbulo este) → altar en el acantilado | Cabañas con entramado, molino, campos de trigo, río con puente de piedra, castillo blanco de torres azules, faroles, hongos luminosos, niebla violeta, grimorio flotante con trébol de luz |
| **Titan Village** | Redonda con una cala al noroeste; colinas costeras; meseta a 24 al este | Campos exteriores → ciudad dentro de la muralla (puerta sur) → bosque gigante (puerta este) → brecha de la muralla al norte | Muralla en anillo de 70 de alto con almenas, cañones, puertas y brecha con escombros y polvo; casas de piedra y entramado, iglesia con campanario, granjas, árboles de casi 90 |
| **Hero Academy** | Casi cuadrada con malecón (costa baja de acantilados); terraza del campus a 18; colina-parque a 50 | Campus → avenida central → ciudad simulacro → gran estadio | Cuadrícula de calles de asfalto, rascacielos de cristal, oficinas y apartamentos, edificio H del campus, semáforos, farolas, coches, ruinas en llamas, estadio con torres de luz, antena de radio, faro |
| **Demon Corps** | Tres lóbulos; montaña central de más de 170 y una segunda al sureste; estanque al pie | Aldea de faroles → terraza de bambú (22) → santuario en la montaña (58) → vía del tren (30), en espiral alrededor del pico | Casas de madera oscura con farolillos, pagoda de tres pisos, glicinas, puente rojo arqueado, bambú, túnel de toriis, linternas de piedra, santuario, tren con ventanas iluminadas, torii en el mar |

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

Cómo se tira:
- Cada isla tiene una máquina de gacha. El jugador se acerca y la activa (tecla E, o tocarla en móvil).
- Cada tirada cuesta Yenes según la isla (ver `docs/balance.md`). Solo se puede tirar en islas desbloqueadas y con espacio libre en el inventario.
- El resultado se muestra en pantalla con el nombre del personaje y el color de su rareza.

Con el Boost de Suerte activo, las probabilidades de Legendario, Mítico y Secreto se duplican (4%, 2% y 0.2%) y la diferencia se resta de Común (queda en 46.9%), para que el total siga siendo 100%.

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

### Personajes visibles (estilo AFS)

- Todos los jugadores ven los personajes equipados de todos.
- Caminan por el suelo, nunca flotan. Todos van a la misma velocidad: la del dueño ×1.25, un poco más rápido para alcanzarlo cuando se detiene. Mientras caminan balancean brazos y piernas (un ciclo cada 6 studs) y miran hacia donde van; al llegar se quedan quietos.
- Sin objetivo, caminan detrás de su dueño en filas de 3 (la primera a 6 studs, 5 studs entre personajes y entre filas) y miran hacia donde mira él.
- Con objetivo, caminan hasta un arco de 150° alrededor del enemigo, del lado del dueño, a 3 studs de su superficie.
- Cada golpe que calcula el servidor dispara una embestida hacia el enemigo (0.12 s de ida y 0.3 s de vuelta), más corta que el cooldown más rápido (1 s), así que cada golpe se ve completo.
- Son solo visuales: no chocan, no tapan los clics sobre enemigos y no influyen en el daño.

## Inventario

- Capacidad inicial: 50 personajes.
- Se amplía comprando espacio con Yenes, con un costo que sube proporcionalmente.
- Se abre con el botón "Inventario". Muestra los personajes ordenados: equipados primero, luego por rareza y daño.
- Tocar un personaje lo equipa o desequipa. "Equipar mejores" equipa los de más daño por segundo en todas las ranuras.
- Se pueden tener copias repetidas del mismo personaje, y también equiparlas a la vez.
- **Eliminar:** botón de papelera con confirmación (pulsar dos veces). No se puede eliminar un personaje equipado ni el último que queda. Por ahora no da recompensa.
- Con el inventario lleno no se puede tirar en el gacha.

## Economía

- **Yenes (principal):** se obtienen derrotando enemigos. Se gastan en gacha, portales y espacio de inventario.
- **Gemas (secundaria):** se obtienen en Raids. Se gastan en boosts en la tienda; otros usos: pendiente.
- **Boosts:** Suerte, Dinero y Gemas, de 15 minutos. Se obtienen como drop de enemigos en los Raids o comprándolos con Gemas en la tienda.
  - Se gestionan desde el botón "Boosts": muestra cuántos tienes de cada uno, el tiempo activo, y los botones Activar y Comprar.
  - Los boosts activos aparecen con su tiempo restante debajo de los Yenes y Gemas.
  - Activar un boost que ya está activo suma 15 minutos más.

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

Funcionamiento:
- **Lobby:** el portal de Raids de Nameku lleva al lobby, con una plataforma por dificultad y un portal de vuelta a Nameku.
- **Fila:** usar una plataforma pone al jugador en la fila de esa dificultad (usarla otra vez lo saca). El Raid empieza 15 segundos después de que entra el primero, con todos los de la fila (máximo 20). La espera de la dificultad empieza a contar en ese momento.
- **Arena:** cada grupo juega en su propia arena, así que varios grupos pueden hacer Raids a la vez.
- **Oleadas:** la siguiente aparece 3 segundos después de derrotar a todos los enemigos de la actual.
- **Recompensa en grupo:** cada jugador del Raid recibe la recompensa completa de cada enemigo que muere, sin repartirla, y tira su propio drop de boost.
- **Fallo:** si se acaba el tiempo, los jugadores conservan lo ganado con los enemigos derrotados, pero el Raid no cuenta como completado.
- **Salir:** desconectarse o reaparecer (por ejemplo, reiniciar el personaje) saca al jugador del Raid. Si no queda nadie, el Raid termina.
- Al terminar (completado o fallido), los jugadores vuelven al lobby.

Pendiente de definir:
- Valores numéricos de vida de enemigos y recompensas por dificultad.

## Portales

- Rayos de luz que transportan entre islas.
- Se desbloquean con Yenes. Cada portal cuesta más según la dificultad de la isla de destino.
- Las islas se desbloquean en orden: para desbloquear una hay que tener la anterior.
- Al acercarse, el portal muestra "Desbloquear (costo ¥)" o "Viajar". Hay que mantener la tecla medio segundo para evitar pagar por accidente.
- Al desbloquear una isla, el jugador viaja a ella directamente. Volver a islas anteriores es gratis.
- Al entrar al juego o reaparecer, el jugador aparece en la última isla que visitó.

## Guardado

- Persistencia con DataStore: monedas, inventario, personajes equipados, islas desbloqueadas, contadores de pity, mejoras de inventario, boosts y progreso de Raids.
- **Jugador nuevo:** empieza con 0 Yenes, 0 Gemas y Kurilin (Común de Nameku) equipado, para poder atacar desde el primer momento.
- **Boosts activos:** su tiempo solo corre mientras el jugador está conectado.
- **Esperas de Raid:** corren en tiempo real, también con el jugador desconectado.
- **Bloqueo de sesión:** si los datos de un jugador están abiertos en otro servidor, se reintenta la carga; si no se consigue, se expulsa al jugador con un mensaje para evitar pérdida de datos. En Studio sin acceso a la API se juega con datos temporales que no se guardan.
