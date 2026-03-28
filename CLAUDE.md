# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DragonUI is a World of Warcraft addon (targeting WotLK 3.3.5a / Interface 70300) that brings Dragonflight-era UI aesthetics to the classic client. It is a Lua addon using the Ace3 framework, with no build step or test suite.

## Development

- **No build system**: This is a pure Lua addon loaded by WoW's addon system. Edit files directly.
- **No tests**: There is no test framework or test runner.
- **Load order**: Files load in the order defined by [DragonUI.toc](DragonUI.toc) → [DragonUI.xml](DragonUI.xml) → [modules/modules.xml](modules/modules.xml) and [utils/utils.xml](utils/utils.xml).
- **In-game testing**: Reload the UI with `/reload` after changes. Open config with `/dragonui` or `/pi`.
- **Debug commands**: `/dragondebug report`, `/dragondebug errors`, `/dragondebug stats`.

## Architecture

### Addon Object & Namespace

All code uses `local addon = select(2, ...)` to get the addon table from the TOC file-scoped args. Key shared state lives on this table:

- `addon.db` — AceDB-3.0 profile database (initialized in [database.lua](database.lua), replaced with real AceDB in [core.lua](core.lua))
- `addon.config` — Metatable-based config proxy in [config.lua](config.lua) that delegates to `addon.db.profile`
- `addon.defaults` — Default profile values defined in [database.lua](database.lua)
- `addon.core` — The AceAddon-3.0 object created in [core.lua](core.lua) (mixes in AceConsole, AceEvent, AceTimer)
- `addon.EditableFrames` — Registry of all drag-repositionable UI frames (used by editor mode)
- `addon.SetAtlas` — Custom polyfill for the modern WoW `SetAtlas` API (texture atlas with UV coordinates)

### Load Sequence

1. **Atlas.lua** — Texture atlas data for bag/gryphon sprites
2. **Ace3 libraries** (libs/) — LibStub, CallbackHandler, LibKeyBound, full Ace3 suite
3. **debug.lua** — Debug/error capture system, hooks into WoW error handler
4. **config.lua** — Config proxy with nested metatables
5. **database.lua** — Default values, temporary `addon.db` placeholder
6. **core.lua** — AceAddon creation, SetAtlas polyfill, frame registry (`CreateUIFrame`, `SaveUIFramePosition`, `RegisterEditableFrame`), `RefreshConfig()` dispatches to all module refresh functions
7. **utils/** — Shared utilities: atlas helpers, core utils, event helpers, formatting, NineSlice templates
8. **modules/** — All UI modules loaded in dependency order
9. **options.lua** — Ace3 options panel (must load last, after all modules register their options)

### Module Pattern

Each module is a self-contained Lua file that:
- Reads config via `addon:GetConfigValue(section, key)` or `addon.config.section.key`
- Registers itself via `addon:RegisterEditableFrame(...)` if it has draggable elements
- Exports a `Refresh*` function (e.g., `addon.RefreshMainbars`) called by `addon:RefreshConfig()`
- Uses `pcall` wrapping in core for fault tolerance during config refreshes

### Key Module Categories

- **Action bars**: noop.lua (hides Blizzard frames), buttons.lua, mainbars.lua, cooldowns.lua, stance.lua, vehicle.lua, petbar.lua, multicast.lua
- **Unit frames**: modules/unitframes/ — player, target, focus, party, pet, ToT, ToF (each a separate file)
- **Other UI**: micromenu.lua, minimap.lua, castbar.lua, auras.lua, BuffFrame.lua, questtracker.lua, gamemenu.lua
- **Systems**: editor_mode.lua (drag-and-drop repositioning), keybinding.lua (LibKeyBound integration), compatibility.lua (addon conflict detection)

### Configuration System

Config values flow: `database.lua` (defaults) → AceDB `addon.db.profile` → `config.lua` (metatable proxy) → modules. The `config.lua` proxy provides static fallback values (fonts, positions) when the DB key is missing. Widget positions are stored under `addon.db.profile.widgets[name]` with `anchor`, `posX`, `posY` fields.

### Texture Atlas System

WoW 3.3.5a lacks the modern `SetAtlas` API. DragonUI polyfills it by storing atlas definitions as `{texture_path, width, height, left, right, top, bottom, horizTile, vertTile}` tuples and applying them via `SetTexCoord` + `SetTexture`. Atlas data is split between [Atlas.lua](Atlas.lua) (bag sprites) and the `DRAGON_ATLAS` table in [core.lua](core.lua) (gryphon sprites).

## Conventions

- **Language**: Code is in English; comments are mixed English, Spanish, and Chinese
- **Frame naming**: Custom frames use `DragonUI_` prefix (e.g., `DragonUI_PlayerFrame`)
- **Parent frame**: All custom frames are children of `UIParent`
- **SavedVariables**: `DragonUIDB` (settings), `DragonUIDebugLog` (debug data)
- **Optional deps**: Blizzard_TimeManager, Blizzard_PartyUI
