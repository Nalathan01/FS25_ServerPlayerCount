# Server Player Count

Adds a small player counter to the HUD on multiplayer servers, so you can see at a glance how many people are on without opening the player list.

## What it does

Shows a compact player count with a status dot in the game's own HUD style, right next to the time and weather box. Green means no server-side error has been seen, red means one did, including script errors from the game or any mod. Warnings are ignored by default because nearly every modded server logs harmless ones, the host can switch them on in the game settings to get a yellow dot for them.

The host or an admin can reset the dot from the game settings once a flagged message has been checked and isn't worth worrying about.

The display follows the game HUD's own visibility, and hides itself automatically in singleplayer in case the mod ends up active there by mistake.

## Feedback

Something not showing up right? Open a GitHub issue with your mod/game version and whether it was singleplayer or a server, `log.txt` helps if it looks like a script error.

## Links

- Forbidden Mods: https://forbidden-mods.de/filebase/file/77314-spieleranzahl-auf-servern/
- ModHub: https://www.farming-simulator.com/mod.php?mod_id=364299
- Website: https://www.nalathan.de/
- YouTube: https://www.youtube.com/@nalathangaming
- Issues: https://github.com/Nalathan01/FS25_ServerPlayerCount/issues
