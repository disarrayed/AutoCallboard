<div align="center">

# AutoCallboard

Automatic Callboard rolling for Project Ebonhold. Pick the quests you want,
open a board, and let AutoCallboard stop when one appears.

[![Downloads](https://img.shields.io/badge/downloads-643-b048f8.svg?style=for-the-badge)](https://github.com/disarrayed/AutoCallboard/releases)
![AutoCallboard 1.0.9](https://img.shields.io/badge/AutoCallboard-1.0.9-4b2e83.svg?style=for-the-badge)
![Project Ebonhold 3.3.5a](https://img.shields.io/badge/Project%20Ebonhold-3.3.5a-d1d1f6.svg?style=for-the-badge)

[**Download**](https://github.com/disarrayed/AutoCallboard/releases/latest) · [**Source**](https://github.com/disarrayed/AutoCallboard)

<img src="screenshots/autocallboard-main.png" alt="AutoCallboard main window" width="420" />

<img src="screenshots/autocallboard-quest-panel.png" alt="AutoCallboard quest panel" width="760" />

</div>

---

## How it works

AutoCallboard watches the Project Ebonhold objective board UI and rolls until
one of your wanted quests appears.

The normal flow:

1. Open `Quests`.
2. Check the quests you want AutoCallboard to pick.
3. Click `Start`. If no wanted quest is selected, confirm the warning first,
   or enable `Auto Current Instance` while inside a dungeon or raid.
4. AutoCallboard checks for board access, then reads Project Ebonhold objective data and rolls.
5. When a wanted or current-instance quest appears, it selects the quest and pauses.
6. AutoCallboard records the accepted quest ID and tries to share that quest
   with your group.
7. Finish the quest, then continue when you are ready.

Use the `Callboard` button when you need to summon a board. At a normal
`Objectives Board`, click the board to open it. `Start` does not summon, and it
will not reroll or select from cached data if no board is open.

Rerolls cost gold. If you pick rare quests, AutoCallboard may roll many times, and the cost can add up fast. The quest panel tracks total spend, current run spend, and the last accepted quest cost, and accepted quest chat output includes the spend for that quest.

---

## Features

**Wanted quests**
- Pick wanted quests from the `Quests` panel
- Wanted picks save per character
- Known quest list grows as quests appear on the Callboard
- Known quests are split by quest type
- Category filters can quickly show only Open World, Dungeon, Raid, Profession, or Other quests
- With no category filter, the list shows selected quests, or all known quests if nothing is selected
- Search by quest name or quest info
- Hover a quest to see the quest details

**Rolling**
- `Start` rolls until a wanted quest appears
- `Auto Current Instance` can roll only for the dungeon or raid instance you are currently inside
- Current-instance matching uses the instance type and name, not party or raid group membership
- While you are inside a dungeon or raid, Auto Current Instance ignores normal checked quest picks
- Auto Current Instance warns that not every dungeon or raid has a Callboard quest
- With no wanted quest selected, `Start` warns first, then rolls only to learn quests if confirmed
- `Start` does not summon the Callboard
- `Start` will not spend a reroll unless board access is detected through UI, board gossip, or the clicked board's `npc` token/object ID
- `Share` retries the last accepted quest from your quest log
- Accepted quest chat output shows how much gold that quest cost
- `Auto Accept Quests` can accept quests shared by party or raid members
- Auto Accept Quests is separate from board quest auto-accept
- Auto Accept Quests does not rely on fixed quest IDs or titles
- `Stop` ends rolling at any time
- AutoCallboard selects a matched quest and pauses
- The board window closes after a quest is selected
- The loop waits while a selected quest is active
- Reroll confirm is handled automatically

**Callboard controls**
- `Callboard` casts Summon Callboard
- If an `Objectives Board` is detected, AutoCallboard uses it before falling back to `Callboard`
- Tracks Callboard active time and cooldown
- Guards reroll and quest selection when board UI/data is missing
- Minimap button opens the addon and toggles the quest panel

**Quest data**
- Learns quests from the Callboard over time
- `Export` and `Import` move known quest data between characters
- Accepted quest IDs are logged so `Share` can retry the latest accepted quest
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
/acb callboard   Open a detected board or summon the Callboard
/acb roll        Start rolling
/acb stop        Stop rolling
/acb autoacceptquests on|off  Turn Auto Accept Quests on or off
/acb autoinstance on|off  Turn Auto Current Instance on or off
/acb export      Export known quest data
/acb import      Import known quest data
/acb clearquests confirm  Clear learned quests and selected quest picks
/acb debug       Open the copyable debug log
/acb cooldown    Add cooldown details to the debug log
/acb sniff on    Record board interaction evidence in the debug log
/acb sniff       Add one interaction snapshot to the debug log
/acb etrace      Open the client event trace when available
/autocallboard   Alias for /acb
```

---

## Notes

- AutoCallboard is built for Project Ebonhold's Callboard and Objectives Board UI.
- Rerolls cost gold. Pick carefully.
- Screenshots and README files are part of the GitHub repo only. They are not included in the release zip.

---

<div align="center">
<sub>Made for the Project Ebonhold community.</sub>
</div>
