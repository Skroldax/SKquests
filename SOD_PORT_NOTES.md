# SKquests — Season of Discovery port (from v0.5.12-beta)

## Cómo instalarlo
Esta carpeta (`SKquests_SoD`) está anidada dentro de tu addon WotLK porque solo esa carpeta estaba accesible para crear archivos. Para que WoW la reconozca como addon independiente, **muévela** (cortar/pegar) a:

`Interface\AddOns\SKquests_SoD\` (como hermana de tu `SKquests` actual, no dentro de ella)

Luego puedes renombrarla si prefieres otro nombre de carpeta — el nombre de carpeta no tiene que coincidir con el `## Title` del .toc.

## Qué se portó
Solo las features del changelog v0.5.12-beta (2026-06-18): filtro de Zona Actual en el Mini-Tracker, botón de filtro Profesiones/Clases/Eventos en la lista de Zonas, rediseño del Quest Log agrupado por zona con headers colapsables, nombres localizados para zonas especiales, y el fix de las cajas de filtro de nivel superpuestas.

## Cambios técnicos aplicados
- `## Interface: 30300` → `## Interface: 11508` (build actual de Classic Era/SoD, 1.15.8). Si el cliente reporta otro número, verifícalo en el juego con `/dump select(4, GetBuildInfo())` y ajusta el .toc.
- Título y notas del .toc actualizados para reflejar Season of Discovery en vez de WotLK.
- Texto "Acerca de" (enUS/esES) actualizado: ya no dice "3.3.5a", dice "Season of Discovery".
- 16,575 enlaces de Wowhead reescritos de `wowhead.com/wotlk/quest=` a `wowhead.com/classic/quest=` (la base de datos de WotLK en Wowhead muestra nivel/recompensas incorrectos para estas quests; la sección `/classic/` es la correcta para SoD).
- **No se reescribió ninguna API.** Verifiqué en Warcraft Wiki que todas las funciones legacy del Quest Log que usa el addon (`GetQuestLogTitle`, `GetNumQuestLogEntries`, `SelectQuestLogEntry`, `GetQuestLogQuestText`, `GetQuestLogLeaderBoard`, `GetNumQuestLeaderBoards`, `AbandonQuest`) siguen presentes en el build 1.15.8 de Classic Era — no fue necesario migrar a `C_QuestLog.*` (eso solo aplica a retail/mainline).
- `UIDropDownMenuTemplate` (usado una vez, menú de enlaces) es un template clásico de FrameXML, sigue disponible en Classic Era.

## Limitaciones de contenido (no resueltas, por transparencia)
La base de datos de misiones/zonas que usa el addon (pfQuest, Vanilla+TBC) **no contiene contenido exclusivo de SoD**:
- Misiones de Runas por clase (contenido nuevo de SoD, no existe en ninguna base de datos vanilla).
- Cambios de fases/level cap progresivo (25/40/50/60).
- Reworks de zonas/dungeons específicos de SoD (ej. Gnomeregan, BFD modificadas).

Estos datos no se inventaron ni se adaptaron — fabricarlos sin una fuente confiable habría introducido información incorrecta. El resto de la base de datos (misiones, NPCs, objetos de la era Vanilla 1-60) debería funcionar igual que en Vanilla/Classic Era normal, ya que SoD no cambia el contenido base, solo lo expande.

También quedan, sin tocar (cosméticos, no rompen nada): pestañas de continente "Outland"/"Northrend" en la lista de zonas — no son alcanzables en SoD, simplemente no mostrarán datos relevantes. Comentarios internos del código que mencionan "WotLK"/"3.3.5a" no se limpiaron (no afectan función).

## Verificación hecha
- Copia completa (133 archivos de Media + todos los .lua) verificada byte a byte contra el original.
- Los 3 archivos modificados (`SKquests.toc`, `SKquests_Localization.lua`, `SKquests.lua`, `SKquests_DetailDB.lua`, `SKquests_DetailDB_TDB.lua`) verificados con conteo de líneas y balance de llaves/paréntesis — sin discrepancias.
- No se pudo correr un linter de Lua real (sin acceso a red para instalar uno), así que recomiendo probar en juego y avisarme si algo tira error.
