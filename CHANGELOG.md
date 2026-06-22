## [0.6.0-beta] - 2026-06-21

### Added
- **Intelligent Objective Filtering:** The UI now reads the WoW Quest Log and automatically filters out map pins and GPS waypoints for objectives that are already fulfilled within a multi-objective quest (e.g. killing 10/10 Razormane Defenders will hide them while leaving Geomancers visible).
- **Smart GPS Targeting:** The GPS waypoint arrow will now calculate the closest individual objective coordinate to your character's current position instead of pointing to the geographic center of all spawns.
- **Dual Localization Support:** System messages (slash commands, errors, chat notifications) are now fully localized and respond to the active language configuration in Settings (English / Spanish).
- **SoD Client Compatibility:** Implemented BackdropTemplateMixin support to ensure UI frames render backgrounds flawlessly on the modern Season of Discovery client while maintaining backwards compatibility.

### Fixed
- **GPS Arrow Rotation Math:** Fixed a critical compass calculation error that caused the GPS arrow to point backwards (180 degrees offset) when using certain tracking tools.
- **Quest Tracking Toggle:** Corrected the UI tracking toggle logic to ensure switching between quests on the exact same map updates the GPS properly without getting stuck.

# Changelog

All notable changes to SKquests will be documented in this file.
This project follows [Semantic Versioning](https://semver.org/) and [Keep a Changelog](https://keepachangelog.com/).

## [0.5.20-SoD] - 2026-06-21

### Added
- **Ocultar misiones manualmente del mapa**: Ahora puedes ocultar pines de misiones indeseadas (como misiones de otras profesiones que el servidor marca como disponibles) haciendo **Shift + Click Derecho** sobre cualquier pin en el Mapa del Mundo o el Minimapa. La misión desaparecerá de ambos mapas al instante y el addon recordará tu preferencia. Puedes restaurar las misiones ocultas usando el nuevo comando `/skq unhide` o `/skq reset`.

### Changed
- **Ordenamiento visual suave del Tracker**: Los botones de flechas (subir/bajar) del panel del Quest Tracker en pantalla han sido reprogramados. En lugar de asignar una prioridad absoluta causando saltos bruscos, ahora el algoritmo intercambia posiciones 1x1 con la misión adyacente, resultando en un reordenamiento fluido y predecible.
- **Mejora en Tooltip de progreso de NPCs/Objetos**: El tooltip que muestra tu progreso de misión al pasar el cursor sobre un NPC u objeto en el mundo ya no se detiene en la primera misión coincidente. Ahora busca sobre *todas* tus misiones activas y muestra de forma combinada el progreso de múltiples misiones que comparten ese mismo objetivo.
- **Filtro estricto de misiones en el mapa**: Los signos de exclamación amarillos en el mapa (Misiones Disponibles) ahora verifican estrictamente los prerrequisitos de nivel (`minLevel`) y las misiones previas requeridas de cadenas (`prevId`) antes de dibujarse, limpiando el mapa de misiones que aún no puedes tomar.
- **Optimización del XP Appraiser (Pestaña Quests)**: Se eliminó la pestaña "Quests" ("Worth It?") de la ventana del Tasador de XP, junto con todo su código interno de seguimiento de textos y tiempos por misión. Esto ahorra memoria RAM y reduce la carga en la CPU. La XP que otorgan las misiones se sigue sumando correctamente de forma ultraligera a las estadísticas de la Sesión.

## [0.5.19-SoD] - 2026-06-20

### Changed
- **Optimizacion de rendimiento (auditoria general)**: se revisaron ambas copias del addon (Season of Discovery/Classic Era y WotLK 3.3.5a) en busca de trabajo repetido en rutas calientes. Se implementaron dos mejoras:
  - **Tooltip de progreso en objetos del mundo (cofres, hierbas, items de quest en el piso)**: `SKQ_FindQuestProgressForObjectName` recorria todas las misiones activas y armaba una tabla temporal de ids en *cada* llamada al hook global `GameTooltip:SetText` — un hook que se dispara en practicamente todos los tooltips del juego (hechizos, botones de accion, items del bolso), no solo los relacionados con misiones. Ahora ese escaneo se hace una sola vez por refresh del Tracker (cuando realmente cambian las misiones activas) y se guarda en una cache; el hook solo hace una busqueda O(1).
  - **Refresh del Tracker agrupado (debounce)**: el quest log dispara varios eventos casi simultaneos por una sola accion (aceptar/entregar una mision suele disparar `QUEST_LOG_UPDATE` y `UNIT_QUEST_LOG_CHANGED` a la vez). Cada uno disparaba un `T:Refresh()` completo, que es O(n) sobre el quest log e incluye expandir/colapsar todos los encabezados. Ahora esas rafagas se agrupan en un unico `Refresh()` ejecutado en el siguiente frame, sin cambiar el comportamiento visible.

## [0.5.18-SoD] - 2026-06-20

### Fixed
- **Misiones que "desaparecian" del Mini-Tracker hasta mover la ventana**: con el filtro "Mostrar solo zona actual" activo, el tracker ocultaba una misión en cuanto `entry.category` (la zona/encabezado del quest log donde se acepto la misión) dejaba de coincidir exactamente con `GetRealZoneText()`/`GetSubZoneText()` (la zona donde esta el jugador en ese momento) — algo que pasa todo el tiempo, porque es normal alejarse de la zona de origen de una misión para cumplir sus objetivos (entrar a una cueva, cruzar a una subzona o zona vecina, etc.). Ahora una misión con progreso real (algún objetivo en X/Y > 0) queda exenta del filtro de zona y se sigue mostrando aunque el jugador se haya movido.
- **El filtro de zona no se reevaluaba al cambiar de zona**: el frame de eventos del tracker solo escuchaba `QUEST_LOG_UPDATE`/`UNIT_QUEST_LOG_CHANGED`/`QUEST_WATCH_UPDATE`/`PLAYER_ENTERING_WORLD`, así que el filtro "zona actual" solo se volvía a calcular cuando cambiaba el quest log, no cuando el jugador simplemente caminaba a otra zona o subzona. Esto hacía que una misión quedara "atascada" oculta o visible hasta que algún evento de quest log no relacionado disparara un refresh tardío — y mover/arrastrar la ventana del tracker fuerza ese redraw, por eso "reaparecían" al moverlo. Se agregaron `ZONE_CHANGED`, `ZONE_CHANGED_NEW_AREA` y `ZONE_CHANGED_INDOORS` para que el tracker se actualice apenas cambia la zona real.
- **Misiones ocultas a la fuerza por un encabezado "Unknown"**: `T:Refresh()` inicializaba `currentHeader = "Unknown"`, así que cualquier misión escaneada antes de detectar su encabezado real quedaba con `category = "Unknown"` — un valor no vacío que el filtro de zona intentaba comparar contra la zona actual y nunca coincidía, ocultando esa misión permanentemente. Cambiado a `nil`, que el filtro ya trataba correctamente como "sin categoría, no filtrar".
- **Lista del Mini-Tracker se veía vacía sin haber misiones nuevas**: si el contenido se encogía (por el filtro de zona o al completar misiones) el scroll podía quedar más abajo que el nuevo contenido, mostrando una lista en blanco hasta hacer scroll manualmente. Se agregó un reajuste del scroll al final de `RefreshMiniTracker` que lo recorta al máximo válido.

## [0.5.17-SoD] - 2026-06-20

### Fixed
- **Nombres de misiones en español en la pestaña Quests ("Worth It?") del Tasador de XP**: `RecordQuestTurnIn` priorizaba `dd.name_loc` (nombre en español) sobre `dd.name` (inglés) al guardar el nombre de la misión, aunque el resto de esa ventana (pestañas, tooltips) se muestra en inglés para este usuario. Resultado: misiones entregadas mostraban su nombre en español de forma inconsistente con el resto de la UI. Corregido el orden de prioridad (`dd.name or dd.name_loc`), igual que en el resto del módulo. Se agregó una migración única que recorre `db.Quests` y corrige los nombres ya guardados usando `SKquests_DetailDB`, incluyendo registros viejos y corruptos heredados del bug de medición anterior a 0.5.16 (ej. "Sergra Espinoscura" en vez de "Crossroads Conscription" — el nombre de un NPC de entrega capturado por error en vez del nombre real de la misión).

## [0.5.16-SoD] - 2026-06-19

### Fixed
- **Crash al abrir el detalle de una misión**: el nuevo resolver de zona del marcador de jugador (`SKQ_ResolveZoneIdFromRealZone`) asumía que toda entrada de `pfDB.zones.<locale>` era un nombre de zona (string), pero algunas son tablas de datos de continente/escala. Llamar `:lower()` sobre esas tablas rompía `SetQuest` cada vez que se abría una misión. Corregido con una verificación de tipo (`type(nm) == "string"`).
- **Pestaña Quests ("Worth It?") del Tasador de XP siempre en 0 XP / sin actualizarse**: la detección de entrega de misión dependía de `QUEST_COMPLETE` + un hook de `GetQuestReward` + medir el delta de XP del jugador unos milisegundos después, pero en este cliente la XP ya se había otorgado para cuando se medía, dando siempre 0. Reemplazado por el evento `QUEST_TURNED_IN(questID, xpReward, moneyReward)`, que entrega el ID de misión exacto y el XP otorgado directamente del servidor — igual que ya usa de forma confiable la pestaña Stats. Se incluye una migración única que limpia los registros de misiones ya corrompidos por el bug anterior (xp=0 con contador > 0); las nuevas entregas se medirán correctamente.

## [0.5.15-SoD] - 2026-06-19

### Added
- **Marcador de "tu posición" en el mapa interactivo**: el visor de mapa de la ficha de misión ahora muestra un punto azul con la posición real del jugador, actualizado en vivo (cada ~1s, y al instante al hacer zoom/pan o cambiar de misión). Solo se muestra cuando estás físicamente en la misma zona que el mapa mostrado.

### Changed
- **Pestañas del Tasador de XP (Session/Zonas/Quests/Historial/Botín/Stats/Tiempo/NPCs/Mobs)**: ahora tienen fondo y borde propios acordes al tema Dark/Light del addon (antes eran botones sin estilo, solo texto sobre el fondo de la ventana). La pestaña activa se resalta con borde dorado.

### Fixed
- **Coordenadas de NPC siempre en "-" en la pestaña NPCs del Tasador de XP**: `PlayerCoords()` dependía de `GetPlayerMapPosition`/`SetMapToCurrentZone`, APIs eliminadas en el cliente moderno de Classic Era/SoD. Corregido en `SKquests_Stats.lua` usando `C_Map.GetBestMapForUnit` + `C_Map.GetPlayerMapPosition` (con fallback al método clásico). Los NPCs ya registrados sin coordenadas se autocompletan la próxima vez que los vuelvas a inspeccionar. El mismo problema afectaba a `CaptureQuestCoord` en `SKquests_UI.lua`; ambos ahora usan la misma función compartida (`SK:GetPlayerMapCoords()`).

## [0.5.14-SoD] - 2026-06-19

### Fixed
- **Pestaña Mobs vacía en el Tasador de XP**: `COMBAT_LOG_EVENT_UNFILTERED` se leía con los argumentos directos del formato clásico, pero este servidor usa la convención moderna (sin payload directo, hay que llamar a `CombatLogGetCurrentEventInfo()`) — igual que su formato de GUID con guiones. Como resultado, ningún kill se registraba nunca en `SKQ_Stats.mobs`. Corregido en `SKquests_Stats.lua`, con fallback al formato clásico si el cliente lo requiere. También se corrigió `NpcIdFromGuid` para soportar ambos formatos de GUID (moderno y clásico).
- **Objetivos de quest superpuestos en el tooltip de NPCs**: al pasar el cursor sobre un NPC, el tooltip podía mostrar objetivos de la misma quest que no correspondían a ese NPC (ej. "Plainstrider Talon" al pasar el cursor sobre "Prairie Wolf Alpha"). La comparación buscaba el nombre completo del NPC dentro del texto del objetivo, lo cual nunca coincide en objetivos de recolección de items (el texto nombra el item, no el mob), y por eso caía en mostrar todos los objetivos de la quest. Corregido en `SKquests_UI.lua` (`SKQ_FindQuestObjectivesForNpc`) usando coincidencia por palabras compartidas en vez de substring completo.

## [0.5.13-beta] - 2026-06-19

### Fixed
- **Filtro de Zona del Tracker / Quest Log con zona "Unknown"**: `GetQuestLogTitle` se leía con las posiciones de retorno de WotLK/ChromieCraft (3.3.5a), que no coinciden con las del cliente real de Classic Era / Season of Discovery. Esto hacía que ningún encabezado de zona se detectara como tal: se contaban como misiones falsas y `category` se quedaba fijo en "Unknown" para todas las misiones reales, mostrando "No active quests" en el Mini-Tracker y agrupando todo bajo "Unknown" en la pestaña Quest Log. Corregido en `SKquests_Tracker.lua`, `SKquests_Collector.lua` y `SKquests_Risk.lua` para usar las posiciones correctas del cliente actual (`isHeader` en la 4ª posición, `questID` en la 8ª).

## [0.5.12-beta] - 2026-06-18

### Added
- **Filtro de Zona Actual en Tracker**: nueva opción en ajustes para que el Mini-Tracker filtre automáticamente las misiones y muestre solo las que pertenecen a tu zona actual.
- **Botón Profesiones/Clases en Zonas**: nuevo botón en la lista de Zonas para filtrar misiones especiales de Clases, Profesiones o Eventos del Mundo.

### Changed
- **Visualización del Quest Log**: se ha reestructurado el panel del Quest Log para agrupar las misiones por zona con encabezados colapsables, imitando el diseño clásico de WoW.
- **Traducción de Zonas Especiales**: las zonas especiales (mazmorras, profesiones, clases) ahora muestran nombres localizados correctos (ej. "Herrería", "Mago") en lugar de su código interno.

### Fixed
- **Filtro de Nivel (UI)**: solucionado el problema visual donde la lista de misiones se solapaba y cortaba las cajas de texto del filtro de nivel.

## [0.5.11-beta] - 2026-06-17

### Added
- **Tiempo estimado al siguiente nivel (F1)**: en la pestaña **Sesión** del Tasador de XP se muestra el porcentaje del nivel actual, la XP que falta y el **tiempo estimado** para subir, calculado con tu **XP/h real** (ritmo en vivo tras 1 min de sesión, o el de la última sesión). No calcula nada si aún no hay XP/h.
- **Estadísticas globales persistentes (F4)**: nueva pestaña **Stats** con totales del personaje que se guardan entre sesiones: tiempo jugado, quests completadas y abandonadas, mobs asesinados, XP obtenida, niveles ganados, oro obtenido y muertes. Incluye botón para **reiniciar** las estadísticas.
- **Análisis de tiempo perdido (F8)**: nueva pestaña **Tiempo** que reparte tu sesión por estado (questing, combate, viaje, vuelo, ciudad, AFK, muerto) con porcentaje y duración, para ver en qué se va el tiempo.
- **Buscador de NPCs (F6)**: nueva pestaña **NPCs**. El addon registra de forma pasiva los NPCs que targeteas o sobre los que pasas el cursor (nombre, zona y coordenadas) y luego puedes **buscarlos por nombre**.
- **Mob Inspector (F9)**: nueva pestaña **Mobs** con los mobs que has matado: número de kills y **XP media** por kill. Al pasar el cursor sobre un mob se muestra su **loot observado** con porcentajes (medido de tus propios saqueos, sin bases externas).
- **"Worth It?" en Quests (F11)**: cada quest de la pestaña **Quests** lleva un **punto de color** según su eficiencia (XP/min) y, al pasar el cursor, un tooltip con XP total, tiempo medio, XP/min y clasificación.

### Notas
- Todas las funciones son **modulares** y se basan solo en la **observación real** del juego (eventos), sin Wowhead/Questie ni dependencias externas. Compatible con WotLK Classic 3.3.5a.

## [0.5.10-beta] - 2026-06-17

### Changed
- **Pestaña Botín** ahora muestra el desglose como en el ejemplo pedido: bajo el nombre del objeto, una lista **Zona → Cantidad** ordenada de mayor a menor (ej: Westfall: 120, Darkshore: 75, Redridge: 43), con encabezados de columna **Zona / Cantidad** y la zona top resaltada arriba.

### Fixed
- **Botón Limpiar** ahora funciona de forma clara: deja de trackear el objeto activo, borra sus datos y vacía el buscador, volviendo al estado inicial.

## [0.5.9-beta] - 2026-06-17

### Added
- **Rastreador de botín (loot) por nombre**: nueva pestaña **Botín** en la ventana del Tasador de XP. Escribe el nombre de un objeto **en inglés** (ej: `Linen Cloth`) en el buscador y pulsa **Trackear**: desde ese momento se cuenta cada vez que lo recoges y se reparte **por zona** para ver dónde lo farmeas más. Muestra el total recogido, la zona donde más cae, y una lista de zonas ordenada de mayor a menor con su porcentaje. Botón **Limpiar** para reiniciar los datos del objeto activo. Es un **buscador por nombre**, no una lista desplegable.

## [0.5.8-beta] - 2026-06-17

### Changed
- **XP/hora ahora es un cálculo real al finalizar la sesión**: se quitó el número de XP/h "en vivo" del centro de la ventana (era irreal: al empezar la sesión, con poco tiempo, daba cifras enormes y volátiles). Ahora la cabecera muestra la **XP total** ganada y el **tiempo**, y el **XP/hora** se muestra como el promedio de la **última sesión terminada** (XP total ÷ tiempo). Cada sesión guarda su XP/h al iniciar una nueva o al **cerrar el juego** (visible también en la pestaña Historial).

## [0.5.7-beta] - 2026-06-17

### Changed
- **Ventana del XP Appraiser ahora compacta por defecto**: al abrirse muestra una **vista reducida y acotada** con lo esencial — **XP/hora, XP total y tiempo** de la sesión (más el estado: Activo/Pausa/OFF). Con el botón **+** se **expande a la pestaña grande** (estilo FonzAppraiser) con todo el detalle: Sesión, Zonas, Quests e Historial. El botón **-** la vuelve a contraer, y recuerda en qué modo quedó.
- **Opacidad ajustable de la ventana del XP**: nuevo **deslizador de opacidad** (20%–100%) en la sección "XP Appraiser" del panel de Ajustes para regular la transparencia de la ventana del medidor de forma independiente a la ventana principal.

## [0.5.6-beta] - 2026-06-17

### Changed
- **Ventana del XP Appraiser ahora con estilo del tracker**: se le añadió un **botón de minimizar** (junto al de cerrar) que contrae la ventana a solo la barra de título, y ahora usa el **fondo y los colores del tema** activo del addon (igual que la ventana principal), recordando si quedó minimizada.
- **Mini-tracker renombrado a "SKQuests"**: el título del seguimiento de misiones ahora dice "SKQuests" en vez de "Quest Tracker".

### Fixed
- **Auto-minimizar del mini-tracker ahora es dinámico**: la opción "Auto-minimizar" de Ajustes ya funciona de verdad. Con ella activada, el seguimiento se contrae solo cuando no hay misiones activas y **se vuelve a expandir automáticamente** al aceptar una nueva misión, sin tener que hacerlo a mano.

## [0.5.5-beta] - 2026-06-17

### Changed
- **XP Appraiser ahora se controla desde Ajustes**: se añadió una sección "XP Appraiser" en el panel de Ajustes (Settings) del addon con casillas para **Activar medidor** y **Auto-pausa al estar AFK**, y botones **Abrir ventana**, **Pausar / Reanudar**, **Nueva** y **Reiniciar**. Ya no hace falta usar los comandos `/skq xp ...` (siguen funcionando como alternativa). Soluciona la confusión de que `/skq xp on` solo activaba el medidor pero no abría la ventana.

## [0.5.4-beta] - 2026-06-17

### Added
- **SKQ Experience Appraiser — medidor de XP/hora (+0.1.0)**: nueva ventana movible estilo FonzAppraiser pero enfocada en experiencia. Muestra en tiempo real tu XP/hora, XP ganada, tiempo jugado y nivel; clasifica de dónde viene la XP (Quest / Mobs / Exploración / Otros) con porcentajes; registra estadísticas por zona (ranking de mejores zonas para levear), por quest (XP/min con valoración Excelente/Buena/Media/Pobre) e historial de sesiones persistente entre partidas. Es **activable/desactivable** y se puede **pausar y reanudar** manualmente, con **auto-pausa cuando entras en AFK** (se reanuda sola al volver). Comandos: `/skq xp` (abrir/cerrar ventana), `/skq xp on|off`, `/skq xp pause`, `/skq xp new`, `/skq xp reset`. Expone una API para futuras guías (`GetZoneXPH`, `GetQuestEfficiency`).

## [0.4.4-beta] - 2026-06-17

### Fixed
- **Los iconos de riesgo ahora se muestran (+0.0.1)**: las texturas usadas para el símbolo de riesgo (Interface\COMMON\Indicator-*) no existen en el cliente 3.3.5a, por lo que no aparecía nada. Se reemplazaron por texturas garantizadas del cliente (check verde = SAFE, reloj amarillo = CAUTION, X roja = DANGEROUS, calavera = EXTREME), que se renderizan correctamente tanto en la lista como en el mini-tracker.

## [0.4.3-beta] - 2026-06-17

### Added
- **Abandonar misiones desde el Quest Log (+0.1.0)**: ahora puedes abandonar una misión directamente desde la pestaña Quest Log del addon haciendo **clic derecho** sobre ella. Aparece un cuadro de confirmación (Sí/No) con el nombre de la misión para evitar abandonos accidentales; al confirmar, la misión se elimina del registro y la lista y el tracker se actualizan al instante. Al pasar el ratón por una misión del Quest Log se muestra la pista "Clic derecho: abandonar misión".

## [0.3.3-beta] - 2026-06-17

### Added
- **Indicador de riesgo en el Mini-Tracker (+0.1.0)**: el seguimiento de misiones en pantalla ahora muestra junto a cada misión activa el mismo símbolo de riesgo Hardcore (verde/amarillo/rojo/calavera) que la lista principal, para ver de un vistazo qué misiones del tracker son peligrosas sin abrir la interfaz.

## [0.2.3-beta] - 2026-06-17

### Changed
- **Nuevo símbolo de riesgo Hardcore (+0.0.1)**: se reemplazó el punto de color "●" (que se veía pobre en el cliente 3.3.5a) por iconos nativos del juego, nítidos a cualquier tamaño: un indicador redondo verde (SAFE), amarillo (CAUTION) o rojo (DANGEROUS) y una calavera para EXTREME.

## [0.2.2-beta] - 2026-06-17

### Fixed
- **Solapamiento de barras de filtro (+0.0.1)**: en la pestaña Misiones, la barra de zona seleccionada y la barra de filtro de nivel anclaban ambas al borde inferior del marco de filtros, montándose una sobre otra cuando había una zona elegida Y un rango de nivel activo. Ahora la barra de nivel se apila automáticamente debajo de la barra de zona y el área de la lista ajusta su margen superior (una o dos barras) para no taparse.

## [0.2.1-beta] - 2026-06-17

### Added
- **Recolector automático de datos de servidor (+0.1.0)**: sistema que captura en vivo el contenido del servidor para facilitar el porteo de misiones custom. Al aceptar una misión guarda id, nombre, nivel, descripción, objetivos, zona/subzona, nivel del jugador y si es custom (no presente en la base de datos del addon). Mide la **XP real** de cada entrega comparando UnitXP antes/después (sin estimaciones ni multiplicadores). Registra los NPC de inicio y fin con su ID, nombre, zona y coordenadas. Todo se almacena en la nueva variable guardada  (quests, rewards, npcs, deaths). Nuevo comando **** que vuelca un resumen y la ubicación del archivo de SavedVariables.

## [0.1.1-beta] - 2026-06-17

### Added
- **Puntuación automática de riesgo Hardcore (+0.1.0)**: cada misión recibe una puntuación de riesgo calculada a partir de la diferencia de nivel (×10), objetivos elite (+50), cuevas/áreas confinadas (+30), cantidad de enemigos a matar (10/20/30) y el historial real de muertes del jugador (×2). El resultado se clasifica en SAFE / CAUTION / DANGEROUS / EXTREME y se muestra como un punto de color (verde/amarillo/naranja/rojo) junto a cada misión en la lista. Al pasar el ratón, un tooltip muestra el desglose detallado de los puntos. Se registran automáticamente las muertes del jugador (evento PLAYER_DEAD) por misión activa.

## [0.0.1-beta] - 2026-06-14

### Added
- **Mensaje temporal en pestaña Guías**: Se implementó una pantalla con el mensaje "Próximamente en futuras actualizaciones" en la pestaña de Guías.
- **Backups automáticos**: Creación de respaldos locales `.zip` de los archivos en funcionamiento.

### Fixed
- **Botón de inicio/fin de mapa superpuesto**: Se solucionó un problema de capas (strata/frame level) donde el botón de alternar mapa inicial/final se renderizaba por debajo de las texturas del mapa, haciéndose invisible. Ahora se asocia a `dChild` (hermano del mapa) y se dibuja correctamente al frente.
- **Rutas de mapas de capitales**: Se corrigieron errores de escritura en los nombres de las carpetas de mapas de capitales (`StormwindCity` -> `Stormwind`, `Ogrimmar` -> `Orgrimmar`, `Darnassis` -> `Darnassus`) en `ZoneMapFolder` que causaban que los mapas salieran en blanco al alternar el destino.
- **Detección de mapa de inicio por NPC Giver**: Se mejoró la lógica de detección del mapa inicial para usar la zona del NPC que entrega la misión en lugar del zoneId general, permitiendo que el botón de alternar mapa se muestre correctamente en misiones que inician y terminan en zonas distintas (ej. inicio en Ventormenta y entrega en Crestagrana).

### Removed
- **Limpieza de archivos innecesarios**: Eliminación de archivos residuales del repositorio (`.bak`, `.bak2`, `*_fixed.lua`, carpetas duplicadas de desarrollo y pruebas) para optimizar el tamaño de carga del Addon.

## [0.12.0-alpha] - 2026-06-13

### Added
- **Atlas de Zonas interactivo**: la pestaña Zonas muestra el mapa del continente (Kalimdor / Eastern Kingdoms) y, al elegir una zona en la lista, abre su mapa con los pines de misión. Los pines distinguen disponible (`!`), activa (`?` gris) y completa (`?` dorado), y al hacer clic saltan a la misión en la pestaña Quests.
- **Capas de detalle revelado en los mapas de zona**: los tiles base de WoW son el pergamino "sin descubrir"; ahora se dibujan encima las texturas de sub-área (desde `SKquests_MapData`) para mostrar el mapa completo, igual que el visor del detalle de misión. Renderizado con aspecto real 1002×668, tiles de borde 234/156 y recorte por `SetTexCoord`.
- **Marco temático pintado (9-slice)**: los temas Pro aplican un marco ornamentado alrededor de la ventana mediante texturas BLP recortadas en 9 segmentos (esquinas + bordes), con el contenido insertado para no tapar pestañas ni el botón de cerrar.
- **Filtros de la pestaña Zonas**: los botones Alianza / Horda / Ambos y las pestañas Kalimdor / Eastern Kingdoms ahora filtran la lista de zonas.

### Fixed
- **El mapa de Zonas no se dibujaba**: `RelayoutZonesMap` usaba `mapPins`/`questPinsPool` antes de su declaración (resolvían a global `nil` → `ipairs(nil)`), abortando el dibujado. Se declaran ahora como upvalues antes de las funciones que los usan.
- **Mapas de zona "sin revelar"**: el atlas dibujaba los 12 tiles estirados y sin recortar; ahora usa el mismo método del detalle de misión, incluyendo las capas de sub-área reveladas.
- **Apertura de zona fiable**: clic en la zona desde la lista abre su mapa de forma determinista (se descartó la detección por cursor, que devolvía la zona desfasada en este cliente).
- **Mazmorras/cuevas y subzonas iniciales sin mapa**: al clickearlas en la lista, redirigen a la pestaña Quests filtrada por la zona, en vez de mostrar una pantalla vacía.



### Added
- **Mejora del tema Blizzard Classic**: se procesó e integró una nueva textura de fondo de pergamino clara, suave y limpia (sin marcas de agua ni ruidos visuales molestos).
- **Tarjetas de selección de guías integradas**: ahora el fondo de las tarjetas de Alianza y Horda se adapta dinámicamente al tema, usando transparencias suaves (15% de opacidad) al usar fondos personalizados y respondiendo al hover dinámicamente.

### Fixed
- **Superposición de paneles en la interfaz**: corregido un error de renderizado donde las tarjetas de selección de guía se superponían con otras pestañas (como Acerca de) al cambiar de pestaña.
- **Sincronización del tema**: corregido un problema donde los cambios del tema no se aplicaban al panel de selección de guías debido a early returns y scripts OnLeave que forzaban colores sólidos.

## [0.11.0-alpha] - 2026-06-13

### Added
- **Base de datos de Experiencia completa**: se reemplazó la base de datos parcial de vanilla por una extracción completa desde los archivos internos de *Questie*. El archivo `SKquests_Rewards.lua` ahora cuenta con más de 9,400 valores exactos de experiencia base para todas las misiones (incluyendo las custom y WotLK).
- **Multiplicadores Dinámicos de XP**: integración nativa con la API de Questie (`QuestXP:GetQuestLogRewardXP`) para calcular en tiempo real los modificadores de experiencia por nivel, reliquias y Joyous Journeys.
- **Auras Custom de Ascension**: escáner automático de buffs del jugador en la interfaz para aplicar los bonos de experiencia propios de Ascension (Aura de Experiencia +50%, Pociones +25%, Aura de Prestigio +200%).
- **Visualización de Multiplicador**: la interfaz ahora desglosa la experiencia si tienes bonos, mostrando el total final junto a la base y el multiplicador exacto (ej. `334 XP (Base: 215 XP, x1.55)`).

### Fixed
- **Crashes por API faltante en 3.3.5**: la llamada nativa a `GetQuestLogRewardXP()` rompía silenciosamente la pestaña del *Quest Log* porque dicha función es de Cataclysm. Ahora se envuelve de forma segura y se calcula desde Questie.
- **Iconos invisibles en el Quest Log**: al ver una recompensa por primera vez, el icono salía como interrogación porque el servidor aún no la cacheaba. Se cambió el uso asíncrono de `GetItemInfo` por la lectura síncrona `GetItemIcon` desde los archivos locales.
- **Eliminación de misiones corruptas**: se borraron del código y la base de datos las misiones de prueba residuales ("The 'Chow' Quest (123)aa COPY").

## [0.10.17-alpha] - 2026-06-12

### Added
- **Menú desplegable de quests en líneas con varias**: al hacer clic en una línea de guía con varias quests, se abre un menú con cada una; al elegir, abre su ficha. Para líneas de una sola quest, el clic abre directamente. Robusto a redimensionar e idioma (no calcula posiciones).

### Fixed
- **Elementos de la guía colándose en el detalle de quest**: al ir de la guía a una quest, el encabezado de circuito ("circuit 4") y el mapa del circuito quedaban visibles detrás del detalle, y los botones de link colgaban interceptando clics. `RefreshDetail` ahora oculta también encabezados de circuito, cajas de mapa y botones de link de la guía.
- **Links de quest que no resolvían (p. ej. "Wanted: Hogger")**: la DB de pfQuest guarda algunos nombres con comillas o espacios dobles (`Wanted:  "Hogger"`), así que el nombre del texto no coincidía. Ahora `GetQuestIdByName` normaliza (minúsculas, sin comillas, espacios colapsados), por lo que el clic en cada quest de su línea (Aceptar/Hacer/Entregar) abre su ficha correctamente.

## [0.10.16-alpha] - 2026-06-12

### Fixed
- **Circuitos de guía ordenados por nivel**: dentro de cada zona los circuitos estaban desordenados (5-10, 5-11, 5-9, 5-8…). Ahora se ordenan por nivel inicial y final, conservando título/texto/imagen de cada uno (los mapas siguen coincidiendo).
- **Comillas mal anidadas (p. ej. "Wanted: Hogger")**: el texto traía comillas dentro de comillas que partían el nombre de la quest ("[Wanted: ]Hogger[]"). Corregido a un nombre limpio y enlazable.
- **Quest falsa "Wabbit Pelts" eliminada** de la guía Alianza.
- **Circuito duplicado de "Kobold Camp Cleanup" (Northshire) eliminado** (su quest ya estaba en el circuito completo).

## [0.10.15-alpha] - 2026-06-12

### Fixed
- **Mapas de quest restaurados**: se revirtió el ocultado de la caja de mapa en quests vanilla. Ahora las quests custom muestran su mapa azerothhub y las vanilla muestran su mapa WorldMap de zona con los pines de pfQuest. La lista blanca de `TryCustomMap` se mantiene para no intentar mapas custom inexistentes.

## [0.10.14-alpha] - 2026-06-12

### Fixed
- **Texto de pasos cortado con "..."**: las líneas largas de la guía se truncaban en vez de envolverse. Ahora el texto baja a la siguiente línea (ancho explícito + word wrap), aprovechando que el panel es scrolleable.
- **Mapa azerothhub en el detalle de quests vanilla**: la lista blanca mostraba el mapa de zona azerothhub (parecía "mapa de guía") en quests normales. Ahora la caja de mapa del detalle solo aparece para quests custom (con `bqCoord`); las vanilla ocultan la caja.
- **Mapas de zonas iniciales (Northshire / Valley of Trials) en negro**: sus mapas base no se descargaban desde la fuente original, dejando esos 5 circuitos sin imagen. Regenerados desde mapas base alternativos con marcadores reducidos.
- **Marcadores de circuito demasiado grandes**: reducido el tamaño de HUB/objetivos/entregas en el render para que no tapen el mapa.
- **Quest Log en blanco**: en WoW 3.3.5a `FauxScrollFrame_Update` oculta el frame del scroll cuando los ítems caben sin barra (p. ej. 1 misión activa); como las filas son hijas de ese frame, desaparecían todas. Se restauró `ListPanel.scroll:Show()` protegido por una guarda anti-recursión (`_inListUpdate`) para no reintroducir el stack overflow que motivó su eliminación en 0.10.5.
- **Mapas de circuito en negro**: las 436 imágenes de circuito estaban en TGA de 32 bits, formato que el cliente 3.3.5a suele renderizar en negro. Reconvertidas a TGA de 24 bits sin canal alfa (las imágenes son opacas), compatibles con el cliente.

- **Enlaces de quest repetidos en la guía**: cada nombre entrecomillado de una línea se resaltaba con el nombre del PRIMERO (ej. "[A Threat Within] and [A Threat Within]..."). Ahora cada quest usa su propio nombre localizado y el enlace apunta a la primera quest válida de la línea.
- **Título de circuito cortado a la izquierda**: el encabezado del circuito se anclaba a -20 px (fuera del borde). Ahora se alinea con "OBJECTIVES".
- **Cuadro negro en cada misión**: el cliente devuelve `true` en `SetTexture()` aunque el archivo no exista, así que la caja de mapa se mostraba en negro para zonas con textura WorldMap inexistente. Ahora se usa una lista blanca determinista de los mapas custom que sí existen (las 6 zonas iniciales); el resto oculta la caja en vez de mostrar un recuadro negro.

### Removed
- **Misión custom "Archmage Xylem"** (Azshara) eliminada de `BronzebeardQuestChains`.

## [0.10.5-alpha] - 2026-06-12

### Added
- **Hipervínculos en la guía**: el texto de misiones en la pestaña Guía detecta el nombre, lo localiza (`GetLocalizedQuestName`), lo resalta en azul y añade un botón invisible que redirige al detalle en Quests.
- **Conversión de assets**: procesamiento de imágenes PNG de circuitos a TGA potencia de 2 (512x512) para los pasos de la guía.

### Fixed
- Stack overflow por recursión en `RefreshList` (eliminado `scroll:Show()` — ver corrección en 0.10.6).
- Cuadros negros en detalles de misión (validación de `TryFolder` en `questImgBox:SetQuest`).
- Iconos `?` en botones de cadena: `◄`/`►` reemplazados por `Prev:`/`(Next)`.
- Traducciones de la guía vía `GetLocalizedQuestName` + filtrado de quests vacías/corruptas en `IsQuestEligible`.

## [0.9.0-alpha] - 2026-06-12

### Added
- Guías de leveo como función Pro: rejilla de tarjetas (autodetectadas desde `SKquests_Guides`) estilo Zonas; al elegir una se abre el panel de capítulos/pasos con imágenes.
- Pantalla de candado en la pestaña Guía hasta introducir un código Pro válido.

### Removed
- Selector de temas y editor de temas eliminados del build (solo paleta oscura).

### Changed
- El gating Pro ahora protege las guías (antes los temas). Stub público de `IsProUnlocked` devuelve `false` por defecto.


## [0.8.5-alpha] - 2026-06-12

### Added
- **Custom quest map support (azerothhub)**: custom quests from `BronzebeardQuestChains` now render their dedicated azerothhub starting-zone maps (Shadowglen, Northshire, Deathknell, Camp Narache, Valley of Trials, Coldridge Valley) with spawn pins placed directly from azerothhub coordinates.
- **Starting-zone pin alignment**: vanilla starting subzones (Shadowglen→Teldrassil, Northshire→Elwynn, Deathknell→Tirisfal, Camp Narache→Mulgore, Valley of Trials→Durotar, Coldridge→Dun Morogh) now project their pins onto the parent map using exact pfQuest coordinates, fixing previously misaligned spawn dots.

### Fixed
- **Duplicate "(Custom)" quests removed**: custom chain quests were being injected twice — once with a `(Custom)` name suffix and once clean — producing duplicate list entries. There is now a single, clean injection (synthetic ids `990000+`, normalized-name dedup against the main quest DB) with no suffix.
- **Event/junk quests hidden**: quests with no real level (`level <= 0`, e.g. event or class-trainer quests) and placeholder/test entries (`<TEST>`, `<UNUSED>`, `<NYI>`, Designer Island zone) are now hidden from the list unless they are custom or currently active in the tracker.

### Changed
- `_G.SKquests_CustomMapOffsets` is now populated from the bundled pfQuest `zones.data` (subzone bounding boxes) instead of hardcoded values, so map projection stays consistent across starting zones.

## [0.8.4-alpha] - 2026-06-11

### Added
- **Full Objective Map Pins System**: Restored and expanded the interactive map pins to show kill (red), interact (yellow), and gather (green) objectives, including clustering for nearby spawns.
- **Dynamic Color Palettes**: Added 6 different hex color variations for each objective category. Users can cycle through colors in real-time by doing `Ctrl + Click` on any pin.

### Fixed
- **Map Rendering Bug**: Fixed a `SetTexture` return value check that is unsupported in WoW 3.3.5a, which was preventing interactive maps from rendering.
- **Map View Reset**: Changing pin colors no longer resets the map zoom and pan state.
- **Missing Starting Zone Quests**: Fixed an issue where quests in starting subzones (like Valley of Trials or Northshire) were unlisted by dynamically merging them under their parent zone (e.g., Durotar, Elwynn Forest).
- **PvP Quests Filter**: PvP quests and Battleground zones are now filtered out from the database to keep the interface focused on PvE.

### Fixed
- **Quest Log map broken**: opening a quest in the Quest Log tab incorrectly displayed the map and coordinates of the last viewed quest in the Explorer tab, due to a stale ID reference. It now correctly identifies the active quest by its localized title and updates the map and details accordingly.
- **Starting Zones missing from Quests list**: missions for Valley of Trials, Northshire, etc., silently aborted the database filtering because `IsQuestEligible` performed string/number comparisons on `q.level` (e.g., `"5" > 60` in Lua 5.1). The filter now correctly uses `tonumber()` so starting zones appear again.
- **Map pins too thick and opaque**: reduced pin size from 10x10 to 6x6, added a glowing blend mode (`ADD`), and adjusted opacities and palettes to create a subtle, aesthetically pleasing glowing effect that makes the exact coordinate clearer when zoomed.
- **Customizable pin colors**: you can now cycle through 6 distinct color presets for map pins (gathering, killing, interacting) by `Ctrl + Left Click` on any pin. The map updates the colors instantly without resetting your zoom or pan position.

## [0.5.0-alpha] - 2026-06-11

### Added
- Two new themes available to everyone: **ElvUI Dark** and **Minimal Dark** (`SKquests_Themes.lua`), selectable from Settings by cycling the theme button (Oscuro → Claro → ElvUI Dark → Minimal Dark).
- **Theme editor gated behind an admin password** (`SKquests_ThemeEditor.lua`): hex input + native WoW color picker for background, accent, borders and text, with live preview and per-theme persistent overrides. Password is set in `SKQUESTS_ADMIN_PASSWORD` (default `SKadmin`); unlock persists per account.
- Spanish zone names from the bundled pfQuest esES zones database — the Zones tab, the zone dropdown and quest metadata now translate (e.g. "Valle de Villanorte") when the language is Spanish.

### Fixed
- **Quest Log always empty / active quests never marked**: the tracker misread `GetQuestLogTitle` return values (3.3.5 returns `isHeader` 5th and `isComplete` 7th; it read positions 4 and 6), so every entry looked like a header and the cache stayed empty. Active-quest dots (●/✔) in the explorer and the whole Quest Log tab now work.
- **Guide chapters not switching**: clicking a chapter changed the selection but never rebuilt the step list nor moved the current step. It now rebuilds chapters and jumps to the chapter's first step.
- **Blank rows when first opening the Quests tab**: the row pool was sized from a stale panel height. The list now recalculates on show and on resize.
- Language switching now also rebuilds zones, quest filters and guide chapters, and resets the zone filter, so no stale names remain after changing language.
- Localized remaining hardcoded strings (active-quest notice, database notices).

## [0.4.0-alpha] - 2026-06-10

### Added
- Interactive POI pins on the quest map, Wowhead-style: quest start ("!") and turn-in ("?") NPC locations from pfQuest spawn data, up to 5 spots per NPC. Pins scale with zoom, show a tooltip with the NPC name and coordinates, and print the location to chat on click.
- Map fallback for quests without a mapped zone (dungeons, missing zoneId): the viewer derives the zone from the quest giver's (or ender's) spawn location, so far fewer quests show a blank image.
- Full Spanish quest texts: title, objectives and description now come from the bundled pfQuest esES database (~4,900 quests) when the language is Spanish, with $B/$N token handling.
- Spanish leveling guide: all 383 steps (Alliance 208, Horde 175) machine-translated to understandable Spanish in `SKquests_Guide_esES.lua`; chapter titles and step text switch with the language. Quest names remain in English for in-game identification.

### Fixed
- Reward item icons stuck as "?" until hovered: uncached items are now requested from the server automatically and icons refresh as the data arrives (retry loop, up to ~5s).

## [0.3.0-alpha] - 2026-06-10

### Added
- Interactive quest map viewer replacing the static quest image: shows the quest's zone map (client WorldMap tiles), with mouse-wheel zoom (1x-3x), drag to pan, and click to reset. Zoom happens inside a clipped box, so the detail panel layout never shifts when zooming.
- Full EN/ES localization of the UI chrome (tabs, section headers, titles, counters, settings labels) via an extended `SKquests_Localization` with a live-refresh registry (`ApplyLanguage`).
- Language toggle button (Español/English) in the in-UI Settings panel; choice persists in `SKquestsDB.profile.language`.
- Quest titles now respect the active language: Spanish shows "Nombre (English)", English shows the original name only.

### Changed
- Zones tab now lists Vanilla (and Custom) zones only — TBC and WotLK zones removed per design.
- Default language set to Spanish (esES), matching the original UI.
- Reverted the per-zone guide-image fallback from 0.2.0 (guide images don't correspond to quests); the map viewer covers quest visuals now.

### Removed
- `/skq config` command and its help entry — settings live inside the main interface.

## [0.2.0-alpha] - 2026-06-10

### Added
- Expansion label next to each zone in the Zones tab, color-coded: Vanilla (gray), TBC (green), WotLK (blue), Custom (light blue).
- `ZoneExpansion` table mapping every zoneId to its expansion; Designer Island and Darkspear Strand flagged as Custom.
- Deterministic per-zone quest images: quests with a placeholder image now display an image from `Media/Images Ally|Horde` selected by zoneId and active guide faction.
- Quest rewards merged into the bundled pfQuest database (`Media/db/quests.lua`, `Media/db/quests-tbc.lua`): 2,953 entries with `["rew"]` (fixed rewards) and `["rewc"]` (choice rewards) in `{itemId, quantity}` format, sourced from SKquests_DetailDB. Backups kept as `.bak`.

### Fixed
- Sidenav tab buttons not switching tabs: `ApplyTheme` read `btn.txt` while buttons stored the FontString as `btn.text`, aborting `SwitchTab` mid-click (errors at SKquests_UI.lua:317/320).
- `attempt to call global 'SafePrint' (a nil value)` when changing language in Settings — replaced undefined `SafePrint` with a standard `print` call.
- "Frame SKquestsMainFrame is not movable" error when dragging a locked frame — `OnDragStart` now checks `IsMovable()` first.
- Zone filter dropdown in the Quest Explorer rendered empty: it referenced an out-of-scope variable and only populated on scroll. It now reads `uniqueZones` and populates on show.
- Zones appearing with no quests (Howling Fjord, Strand of the Ancients, Isle of Conquest, Eye of the Storm): the Zones tab and the quest list used different level filters. Both now share a single `IsQuestEligible()` predicate, so empty zones can no longer appear.
- Unnamed zones "Zona 24" and "Zona 35" removed from the zone list (zoneIds without a ZoneMap entry are skipped).
- `ZoneMap[9]` mislabeled as "Mulgore" — corrected to "Northshire Valley" (real Mulgore is zoneId 215). Human starting quests no longer appear under Mulgore.

### Changed
- Removed debug `print()` spam from `BuildZonesList` and `BuildFilteredQuestIds` (fired on every filter change).

## [0.1.x-alpha] - pre-release development record

Comprehensive rebuild after integrating the full server database (`quest_template`), focused on stability, performance and a clean user experience.

### Added
- **Database migration & optimization**: parsed the full `quest_template` dump (7,100+ quests) and converted it into a native, heavily optimized Lua table (`SKquests_DetailDB.lua`) that the WoW engine loads instantly without excessive memory use.
- **Smart filtering engine (Vanilla purity)**: new `BuildFilteredQuestIds` sanitizes the list — junk/test/unimplemented quests (`<UNUSED>`, `<NYI>`, `<TXT>`) are hidden, and a strict expansion block filters out all TBC/WotLK quests and anything above level 60. The raw list went from 7,119 chaotic entries to a clean, playable 4,695 quests.
- **Dynamic zone resolution (ZoneMap)**: the database only provided raw numeric IDs (e.g. 1581). A scraper extracted all 105 unique zone IDs and a full translation dictionary was injected into the UI, covering open-world zones, capitals, dungeons and raids — actual names ("The Deadmines", "Kharanos") instead of "Zone 1581".
- **UI & performance**: perfected the `FauxScrollFrame` system (4,695 quests scrolling at 60 FPS with zero lag) and repaired button layouts so long guide texts no longer word-wrap over other UI elements.

### Fixed
- **Rendering crash**: silent `btn.text`/`btn.txt` typo destroying the UI rendering cycle and leaving the main list blank.
- **Zone filter crash**: `zonesData` variable scoping issue that made the zone dropdown fail silently and render as a black box.
- **Tab freezing**: reconnected the Sidenav logic — clicking "Quest Log" or "Zones" did not refresh the central list.
- **Sorting protection**: wrapped `table.sort` in `pcall` so minor database inconsistencies can't halt the entire addon.

