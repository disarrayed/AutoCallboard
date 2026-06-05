<div align="center">

# AutoCallboard

Automatic Callboard rolling for Project Ebonhold. Pick wanted quests, start the roll, and let AutoCallboard stop when one appears.

[![Latest release](https://img.shields.io/github/v/release/disarrayed/AutoCallboard.svg?style=for-the-badge&color=4b2e83)](https://github.com/disarrayed/AutoCallboard/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/disarrayed/AutoCallboard/total.svg?label=downloads&style=for-the-badge&color=b048f8)](https://github.com/disarrayed/AutoCallboard/releases)
![Project Ebonhold 3.3.5a](https://img.shields.io/badge/Project%20Ebonhold-3.3.5a-d1d1f6.svg?style=for-the-badge)

[**Download**](https://github.com/disarrayed/AutoCallboard/releases/latest) · [**Source**](https://github.com/disarrayed/AutoCallboard)

<img src="screenshots/autocallboard-main.png" alt="AutoCallboard main window" width="420" />

<img src="screenshots/autocallboard-quest-panel.png" alt="AutoCallboard quest panel" width="760" />

</div>

---

## How it works

AutoCallboard watches the Project Ebonhold Callboard and rolls until one of your wanted quests appears.

The normal flow:

1. Open `Quests`.
2. Check the quests you want AutoCallboard to pick.
3. Click `Start`.
4. AutoCallboard rolls the Callboard.
5. When a wanted quest appears, it selects the quest and pauses.
6. Finish the quest, then continue when you are ready.

Rerolls cost gold. If you pick rare quests, AutoCallboard may roll many times, and the cost can add up fast.

---

## Features

**Wanted quests**
- Pick wanted quests from the `Quests` panel
- Wanted picks save per character
- Known quest list grows as quests appear on the Callboard
- Search by quest name or quest info
- Hover a quest to see the quest details

**Rolling**
- `Start` rolls until a wanted quest appears
- `Stop` ends rolling at any time
- AutoCallboard selects a matched quest and pauses
- The loop waits while a selected quest is active
- Reroll confirm is handled automatically

**Callboard controls**
- `Callboard` casts Summon Callboard
- Tracks Callboard active time and cooldown
- Guards reroll and quest selection when the Callboard is missing
- Minimap button opens the addon and toggles the quest panel

**Quest data**
- Learns quests from the Callboard over time
- `Export` and `Import` move known quest data between characters
- Copyable debug log for troubleshooting

---

## Install

1. Download the latest zip from [Releases](https://github.com/disarrayed/AutoCallboard/releases)
2. Extract to `WoW\Interface\AddOns`
3. Folder must be named `AutoCallboard`
4. Restart WoW. A `/reload` is not enough on first install.

---

## Slash commands

```text
/acb             Show the main AutoCallboard window
/acb quests      Open the quest panel
/acb roll        Start rolling
/acb stop        Stop rolling
/acb export      Export known quest data
/acb import      Import known quest data
/acb debug       Open the copyable debug log
/acb cooldown    Add cooldown details to the debug log
/autocallboard   Alias for /acb
```

---

## Notes

- AutoCallboard is built for Project Ebonhold's Callboard UI.
- Rerolls cost gold. Pick carefully.
- Screenshots and README files are part of the GitHub repo only. They are not included in the release zip.

---

## Credits

Built for the Project Ebonhold community.

Feature direction, testing, and debug feedback from Disarray.
