# Third-Party Notices / Atribuciones

SKquests incorpora datos y/o código de los siguientes proyectos. Se agradece y reconoce a sus autores. Cada componente conserva su licencia original.

## pfQuest
- Proyecto: pfQuest (base de datos de quests, NPCs, objetos y zonas para WoW 1.12/3.3.5).
- Autor: Shagu y colaboradores.
- Repositorio: https://github.com/shagu/pfQuest
- Licencia: GPL-3.0 (la misma que adopta SKquests).
- Uso en SKquests: bases de datos incluidas en `Media/db/` (units, quests, zones, items) y la lógica de origen de quests/coordenadas (`quest_origin_pfquest.lua`). Las quests, coordenadas de spawn y nombres localizados provienen de esta base.

## Cartographer / sistemas de mapas Vanilla
- Inspiración para la proyección de coordenadas de subzonas sobre el mapa padre.
- Las cajas delimitadoras de subzonas (`zones.data`) provienen de la base pfQuest, derivada a su vez de datos de mapas del cliente.

## azerothhub
- Sitio: https://azerothhub.com
- Uso: coordenadas y mapas de referencia de las zonas iniciales para las cadenas de quests custom (`BronzebeardQuestChains`). Las imágenes `.tga` de mapas iniciales se respaldan aparte y no se versionan en este repositorio.

## Fuentes
- Las fuentes empaquetadas (si las hubiera en `Media/`) conservan sus licencias originales de sus respectivos autores. Consulta el archivo de licencia incluido junto a cada fuente.

---

Si eres autor de alguno de estos recursos y deseas un cambio en la atribución o en el uso, abre un issue en https://github.com/Skroldax/SKquests
