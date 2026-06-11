# SKquests

Addon de guía de leveo y explorador de misiones para **World of Warcraft 3.3.5a** (WotLK), desarrollado para [Project Ascension](https://ascension.gg/) y compatible con cualquier servidor 3.3.5a.

![Versión](https://img.shields.io/badge/versi%C3%B3n-0.3.0--alpha-orange)
![Interfaz](https://img.shields.io/badge/interfaz-30300-blue)

## Características

- **Guía de leveo 1–60** paso a paso para Alianza y Horda, con objetivos detallados, coordenadas y mapa por paso.
- **Explorador de misiones** con más de 5.000 quests: búsqueda por nombre, NPC o zona, filtros por nivel y zona.
- **Visor de mapa interactivo** en el detalle de cada quest: zoom con la rueda (1x–3x), arrastre para desplazarse y clic para restablecer, sin desplazar el resto de la información.
- **Pestaña de Zonas** con etiqueta de expansión (Vanilla/Custom), rango de niveles y conteo de quests por zona.
- **Quest Log integrado** con seguimiento de objetivos en tiempo real.
- **Recompensas** fijas y a elección por quest, con datos integrados también en la base de datos pfQuest incluida (`["rew"]` / `["rewc"]`).
- **Cadenas de quests** (anterior/siguiente) y enlace directo a Wowhead.
- **Interfaz bilingüe** español/inglés con cambio en vivo desde Ajustes.
- **Temas** oscuro y claro (pergamino), ventana redimensionable y bloqueable.

## Instalación

1. Descarga la última versión desde [Releases](../../releases).
2. Extrae la carpeta `SKquests` en `Interface\AddOns\` de tu cliente 3.3.5a.
3. Reinicia el cliente o ejecuta `/reload`.

## Uso

| Comando | Acción |
|---|---|
| `/skq` | Abrir/cerrar la ventana |
| `/skq show` / `hide` | Mostrar / ocultar |
| `/skq next` / `prev` | Paso siguiente / anterior de la guía |
| `/skq step N` | Ir al paso N |
| `/skq guide Alliance\|Horde` | Cambiar facción de la guía |
| `/skq lang enUS\|esES` | Cambiar idioma |
| `/skq export` | Exportar progreso |
| `/skq help` | Ayuda |

Los ajustes (tema, opacidad, idioma, tamaño de ventana) están en la pestaña **Ajustes** de la propia interfaz.

## Estructura del proyecto

```
SKquests/
├── SKquests.lua              # Núcleo: eventos, slash commands, estado
├── SKquests_UI.lua           # Interfaz principal (ventana, tabs, visor de mapa)
├── SKquests_Tracker.lua      # Seguimiento de quests activas
├── SKquests_Config.lua       # Panel de configuración legado
├── SKquests_Localization.lua # Textos EN/ES
├── SKquests_DetailDB.lua     # Base de datos de quests (autogenerada)
├── Alliance_1_60.lua         # Guía de leveo Alianza
├── Horde_1_60.lua            # Guía de leveo Horda
├── quest_origin_pfquest.lua  # Origen de cada quest (classic/tbc)
└── Media/                    # Imágenes, logos y DB pfQuest
```

## Fuentes de datos

Los datos de misiones, NPCs y recompensas se construyen a partir de:

- [pfQuest](https://github.com/shagu/pfQuest) — base de datos de quests para clientes clásicos (incluida en `Media/db/`)
- [AzerothCore](https://www.azerothcore.org/) — `quest_template` y datos del mundo 3.3.5a
- [Wowhead](https://www.wowhead.com/wotlk/) — verificación de cadenas, niveles y recompensas (versión WotLK Classic)
- [Ascension Database](https://db.ascension.gg/) — quests e items custom de Project Ascension

## Changelog

Ver [CHANGELOG.md](CHANGELOG.md). El proyecto sigue [Semantic Versioning](https://semver.org/lang/es/).

## Autoría y créditos

SKquests es obra original de **Skroldax** (Bronzebeard, Warcraft Reborn — Project Ascension): el código del addon, la base de datos de quests procesada, las rutas de leveo 1–60 de ambas facciones, las traducciones y el diseño de la interfaz.

El historial de commits y los tags de este repositorio constituyen el registro público y fechado de la autoría. Si redistribuyes o derivas este proyecto, la licencia exige conservar el aviso de copyright.

Los componentes de terceros incluidos (base de datos pfQuest, datos de overlays de Cartographer Foglight, fuentes y texturas) **no son de mi autoría** y se atribuyen en detalle en [THIRD_PARTY.md](THIRD_PARTY.md).

## Licencia

[GPL-3.0](LICENSE) — Copyright (c) 2026 Skroldax. Igual que Questie, WeakAuras o DBM: puedes usar, modificar y redistribuir este proyecto, pero cualquier derivado debe mantenerse open source bajo GPL, conservar el aviso de copyright y declarar sus cambios. Los componentes de terceros conservan sus licencias originales (ver [THIRD_PARTY.md](THIRD_PARTY.md)).
