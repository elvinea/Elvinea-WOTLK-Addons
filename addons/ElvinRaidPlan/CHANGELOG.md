# ElvinRaidPlan — Changelog

## v0.5
- Added three more raids to the Map picker: **Trial of the Crusader** (Coliseum
  + Anub'arak ice pit), **Ulduar** (all 14 bosses), and **Eye of Eternity**
  (Malygos). Ulduar maps are matched by best guess for now — some boss/map
  pairings may need swapping, and Algalon has no map yet.

## v0.4.3
- Added an **Open** button: browse and load any saved plan from a scrollable
  list (the current plan is marked with a green arrow). Previously you could
  only load a plan by typing its exact name.

## v0.4.2
- Fixed maps not showing after the v0.4.1 resolution bump. 512px textures
  don't load on this client; reverted to 256px (24-bit RGB), which works.

## v0.4.1
- Replaced the low-res boss maps with higher-quality source images and matched
  each image to the correct Icecrown Citadel boss.
- Removed the temporary "Browse rooms" identification tool.

## v0.4
- Bundled the 12 Icecrown Citadel boss-arena maps (from in-game screenshots)
  and wired them into the Map picker: Map... -> Icecrown Citadel -> boss.
- Redrew class icons as emblem-style symbols instead of plain letter discs.
- Root cause of earlier blank maps found: the maps folder had no image files.

## v0.3.3
- Fixed class icons / maps showing as blank: custom texture paths were missing
  the ".tga" extension, so the client couldn't find them.
- Replaced the red-X text-tool icon with a clean "T" icon.

## v0.3.2
- Class icons were showing weapon/spell art (the client's class atlas resolves
  to the wrong texture on this build). Switched to bundled class icons.

## v0.3.1
- Fixed the rotate handle turning the wrong way.
- Removed the generated schematic maps and the zone/continent map browser;
  reworked backgrounds around a boss-arena registry plus flat colors.

## v0.3
- Fixed a crash when dropping an icon (placed objects are now Buttons, which
  is what the click/drag handlers require on 3.3.5).
- Fixed a load crash caused by older saved data (string vs table background).
- Added click-to-select with resize and rotate handles.
- Made the window resizable from the bottom-right grip.

## v0.2
- Added map backgrounds and a resizable window (superseded by later map work).

## v0.1
- First working version: draggable palette (shapes, text, raid markers, class
  icons), a canvas to drop them on, and named save/load plans.
