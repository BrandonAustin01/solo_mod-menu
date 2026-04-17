# L4D2 Solo Mod Menu

A lightweight **Left 4 Dead 2 VScript addon** that adds an in-game HUD menu for **solo or local play**.

This project is meant to be a clean starting point for anyone who wants to use it as-is, improve it, or fork it into a bigger single-player mod menu.

## What it does

The mod adds a menu that can be opened in-game and navigated through simple controls.

### Current features
- HUD-based in-game menu
- Root menu with multiple categories
- God Mode toggle
- Heal to full
- Infected team join helper
- Infected class switching
- Basic status output in chat
- Menu open/close through chat command

### Scaffolded / placeholder features
These are present in the menu structure, but still need full implementation:
- Infinite ammo
- No reload
- Speed boost
- Relax director
- Big head mode
- Additional weapon and chaos options

## Controls
The script currently advertises these controls in chat:
- `!mm` or `!menu` = open/close the menu
- `RMB` = next
- `LMB` = select
- `Reload` = back / previous
- `F6` = close (if bound in your local setup)

## Project structure

```text
solo_modmenu/
├─ addoninfo.txt
└─ scripts/
   └─ vscripts/
      ├─ director_base_addon.nut
      └─ solo_modmenu_main.nut
```

## Requirements
- **Left 4 Dead 2**
- **VScript support**
- **VSLib**

This addon calls:

```nut
IncludeScript("VSLib");
```

So VSLib needs to be available in your setup for the menu to work properly.

## Installation

1. Download or clone this repository.
2. Place the addon folder in your Left 4 Dead 2 addons location.
3. Make sure [**VSLib**](https://github.com/L4D2Scripters/vslib) is installed and available.
4. Launch the game.
5. Start a local / solo session.
6. Type `!mm` in chat to open the menu.

## Notes
- This was built around **solo/local play** first.
- Some menu options are intentionally scaffolded so the structure is already there for expansion.
- If you want to continue development, `solo_modmenu_main.nut` is the main file to work in.

## Contributing
Pull requests, fixes, and feature additions are welcome.

A few good next steps for contributors:
- Finish the scaffolded toggles
- Add more weapon and director features
- Improve infected switching reliability
- Add better feedback and state persistence
- Clean up bindings / close behavior across different setups

## Publishing note
Before making this public, double-check `addoninfo.txt` and change the author field if you want a different public name shown in-game.

## License
**MIT**.
