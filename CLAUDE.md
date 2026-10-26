# Resource Patch Organizer — working notes

Factorio 2.x mod. A selection tool that cuts and pastes resource patches: drag to vacuum up a
patch, shift-drag elsewhere to re-print it. Conserves the total resource amount across the move.

This repo is a **fork** (`OrePatchOrganizer-forked`, author `daz96050`) of
[PiggyWhiskey/OrePatchOrganizer](https://github.com/PiggyWhiskey/OrePatchOrganizer), which is the
`upstream` remote. `info.json` `name` is the *forked* name, so deployed zips/folders are named
`OrePatchOrganizer-forked_<version>` — renaming `name` changes the mod identity for save games.

## Layout

| File | Stage | Purpose |
|---|---|---|
| [data.lua](data.lua) → [prototypes/planner.lua](prototypes/planner.lua) | data | The `selection-tool` item + shortcut button. Both named `ore-patch-organizer` |
| [settings.lua](settings.lua) | settings | All mod settings (`runtime-global`, except Debug which is `runtime-per-user`) |
| [control.lua](control.lua) | control | Requires `lib.functions`, wires the two selection events. Nothing else |
| [lib/functions.lua](lib/functions.lua) | control | All runtime logic: collect, print, both placement handlers |
| [lib/resourceData.lua](lib/resourceData.lua) | control | The mod-compatibility table — the file you edit for new mod support |
| [locale/en/locale.cfg](locale/en/locale.cfg) | — | Item + setting names/descriptions |

## How it works

Two events, wired in [control.lua](control.lua):

- **Collect** — `on_player_selected_area` (left-drag) → `On_Player_Selected_Area`.
  Sums `resource.amount` into `Resource_Organizer.Count` and destroys the entities. The first
  matching resource in the selection locks in the name/category/handler for the whole operation
  (via `SetResourceOrganizer`); anything not matching `Resource_Organizer.Name` is left alone.
  The tool's `select` filter is `entity_type_filters = {"resource"}` so only resources highlight.
- **Print** — `on_player_alt_selected_area` (shift-left-drag) → `On_Player_Alt_Selected_Area`.
  Re-creates the resource in the new area, then resets state via `ResetResourceOrganizer`.

`Resource_Organizer` (top of [lib/functions.lua](lib/functions.lua)) is the clipboard + the
live copy of settings. `UpdateStoredSettings` re-reads every setting at the start of both events,
so settings changes take effect immediately without a reload.

### Two placement handlers

Set per resource category in [lib/resourceData.lua](lib/resourceData.lua).

**`spread`** — ore-like. One entity per tile across the whole selection, `Count / validCells` each.
Afterwards it calls `update_connections()` on every mining drill in the area so existing drills pick
up the new ore. Has two modes:
- default: fills the selection as a solid rectangle.
- **Natural (noise) placement** (setting, off by default): fills an inscribed ellipse whose outline
  is warped by three sine harmonics of the angle, seeded from the patch centre. Deliberately *not*
  RNG — it's star-convex (one radius per angle) so the patch is always a single connected body with
  no gaps, and it stays multiplayer-deterministic. `NoiseFalloff` controls the centre→edge yield
  gradient (capped so edges never fade to zero), `NoiseWaviness` how lumpy the outline is.
  Two passes: collect weighted tiles, then distribute ore proportionally with the last tile
  absorbing the rounding remainder so the total is conserved exactly.

**`spaced`** — oil-like. One deposit per grid cell, for resources where a single node feeds one
building. Pitch is `tileGrid = Grid_Spacing (setting) + MachineSize`, and each deposit is centred
at `left_top + n*tileGrid + ceil(MachineSize/2)`.
Requires the *entire* selection to be placeable (`invalidCells ~= 0` → refuses with a message) —
a deliberate shortcut to avoid collision maths. Since deposits can be up to 11x11, leave clear
margin around water/cliffs/buildings. If the selection is too small for even one cell, it drops
the whole amount as a single deposit at the top-left corner.

## Adding mod compatibility

Everything is keyed on the resource prototype's **`resource_category`** (not the entity name), via
`AddToTable(Mod, ResourceCategory, ResourceType, ResourceHandler, ResourceSpace)`:

- `Mod` — documentation only, never read at runtime.
- `ResourceType` — `solid`/`fluid`, gates on the Allow Solids / Allow Fluids settings. Judge by
  what the deposit *yields*: pY's `geothermal-crack` and `tar-patch` are `fluid` because their
  `minable.results` are fluids, even though they look like rocks.
- `ResourceHandler` — `spread` (many small tiles) or `spaced` (discrete large deposits).
- `ResourceSpace` — a **minimum** machine size. `SetResourceOrganizer` takes
  `math.max(ResourceSpace, prototype.tile_width, prototype.tile_height)`, so one category entry
  can serve several deposit sizes. Use it to encode the *building* footprint when the deposit
  itself is small (vanilla `crude-oil` is 1x1 but needs 3 for the pumpjack); the prototype size
  takes over when the deposit is the bigger of the two.

One entry per category — duplicates are silently overwritten (see the warning in the file).
A category that isn't in the table is silently ignored: `SetResourceOrganizer` returns early on
`nil`, so the tool just won't pick that resource up. That's the symptom to look for when a
resource "does nothing".

**Other mods can rewrite a resource's category in `data-final-fixes`**, so the category in a
resource's own prototype file isn't necessarily the one it has at runtime. Paracelsin moves the
Vulcanus/Aquilo vents and several other planet mods' geysers from `basic-fluid` into its own
`gas-vents`: with Paracelsin installed, those resources were silently ignored while crude oil
still worked. When one mod's resource "does nothing", grep the *whole modpack* for
`.category =`, not just the mod that defines it.

### Working out the numbers for a new mod

Read the prototypes out of the mod zip rather than guessing:

```bash
unzip -l "$APPDATA/Factorio/mods/<mod>_<ver>.zip" | grep -i ores
unzip -p "$APPDATA/Factorio/mods/<mod>_<ver>.zip" "<mod>/prototypes/ores/<res>.lua"
```

- Tile footprint = `ceil(collision_box width)`, e.g. `{{-5.3,-5.3},{5.3,5.3}}` → 10.6 → **11x11**.
- Find the mining building by grepping the mod for `resource_categories` — that lists which
  categories each drill accepts. Its `collision_box` gives the space the player needs.
- `resource_searching_radius = 0.49` on the building means it must sit dead-centre on the deposit,
  i.e. one-node-per-building → `spaced`. A radius covering several tiles implies ore-like `spread`.
- Vanilla `crude-oil` declares **no** `collision_box`, so it's 1x1 — that's why `basic-fluid`
  carries `ResourceSpace = 3` (the pumpjack) rather than a deposit size.

Reference values dug out for the Pyanodon chain (all `fluid`/`spaced`):

| Category | Prototypes | Deposit | Building | Entry |
|---|---|---|---|---|
| `bitumen-seep` | `bitumen-seep` | 11x11 | oil derrick / tar extractor / gas derrick | 11 |
| `oil-derrick` | `oil-mk01`–`mk04` | 5,7,9,11 | `oil-derrick-mk01`–`mk04` (same sizes) | 5, grown per deposit |
| `natural-gas` | `natural-gas-mk01`–`mk04` | 1x1 (deepcopy of `crude-oil`) | `natural-gas-derrick-*` 7x7 | 7 |
| `tar-patch` | `tar-patch` | 9x9 | `tar-extractor-*` 9x9 | 9 |
| `geothermal-crack` | `geothermal-crack` | 11x11 | `geothermal-plant-mk01` 11x11 | 11 |
| `sulfur-patch` | `sulfur-patch` | 7x7 | `sulfur-mine` 7x7 | 7 (`solid`) |

A bitumen seep converts into one of `oil-derrick` / `natural-gas` / `tar-patch` when prospected,
so all four categories need entries for the chain to be fully supported.

## Known quirks (pre-existing, left alone)

- **State is not persisted.** `Resource_Organizer` is a plain Lua global, not `storage` — there's a
  `--TODO: Save Data` at the end of the collect handler. Collected-but-not-yet-printed resources are
  lost on save/load, and the clipboard is shared by all players rather than being per-player.
- `SnapArea` is effectively dead: steps 2 and 4 assign from `area` instead of `newArea`, discarding
  the rounding and the snap, and its one caller (`local newArea = SnapArea(event.area, 1)` in the
  `spaced` branch) never uses the result.
- `Resource_Organizer.count == 0` in the print handler is a lowercase typo for `Count`, so that
  early-return never fires.
- `CountAreaTiles` and `PrintArea` are defined but unused.
- `locale.cfg` has leftover keys for settings that no longer exist
  (`...-fluid-grid`, `...-special-ore-grid`).
- `flib >= 0.7.0` is a hard dependency in `info.json` but nothing requires it.
- `gvv` is hooked at the top of `control.lua` but isn't declared as an optional dependency.
- Optional dependencies only cover some of the supported mods — harmless, since compatibility is
  keyed on category *strings* and never touches prototypes at the data stage, so no load order
  is needed.

## Deploy / release

`.\deploy.ps1` packages and installs the mod:

- **Bumps the patch version in `info.json` on every run** unless `-NoBump`. Expect `info.json` to
  show up as modified after deploying.
- Zips with forward slashes (needed for cross-platform), naming from `info.json` `name`+`version`.
- Copies to `%APPDATA%\Factorio\mods` by default, or a non-Steam install with
  `-Local` (path is remembered in the `FACTORIO_LOCAL_INSTALL` user env var).
- Enables the mod in `mod-list.json`, and `-Start` launches Factorio afterwards.
- Excludes `temp_*`, `*.zip`, `.github`, `.idea`, `.vscode`, `*.ps1` — note **this file is not
  excluded**, so it currently ships inside the released zip.

### Gotcha: the fork does not replace upstream

Because the fork is named `OrePatchOrganizer-forked`, Factorio treats it as a *separate mod* from
upstream `OrePatchOrganizer`, and `deploy.ps1` only ever enables the name in `info.json`. If both
are enabled:

- Both define the same `ore-patch-organizer` prototypes — the later-loading one (the fork, since
  it sorts after) wins in `data.raw`, so the tool *looks* fine.
- But **both control scripts register the same two event handlers** and both gate on
  `event.item == "ore-patch-organizer"`, so every drag is processed twice — once by each version.

Symptom: changes appear to have no effect, because the old version's placement logic still runs.
This is what "the geothermal fix didn't work" turned out to be — the fork placed correctly while
upstream 0.2.4 simultaneously spread-stamped an 11x11 deposit onto every tile.

Check with `mod-list.json` in the mods folder, or the in-game mod manager, and keep only one
enabled. Note Factorio rewrites `mod-list.json` on exit, so edit it with the game closed.

Related: asset paths are resolved by **mod name**, so anything written as `__OrePatchOrganizer__/…`
silently loads out of the upstream mod's folder while both are installed, then fails with
*"does not match any enabled mod"* the moment upstream is disabled. The fork's paths live in the
`modPath` local at the top of [prototypes/planner.lua](prototypes/planner.lua) — keep it equal to
`info.json` `name`. Locale keys are keyed on prototype names (unchanged), so they aren't affected.

`changelog.txt` is Factorio's strict format: 99 dashes as separators, `Version:` / `Date:` then an
indented category (`Changes:` / `Bugfixes:`) with `    - ` items. Written by hand at release time.

## Testing

No automated tests. Practical loop:

- `luac -p lib/*.lua` for a syntax check (Factorio runs **Lua 5.2.1** — hence the `math.atan2`
  compatibility fallback in the noise code).
- Enable the per-player **Debug Mode** setting; both handlers then print the locked-in name, count,
  grid spacing, machine size, selection bounds, and every computed placement position to chat.
- Verify placement in-game per handler: `spread` should tile the selection, `spaced` should leave
  the configured gap and never overlap deposits.
