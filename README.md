# Ascension Helper

Plan each hero's weapons and training once; the mod equips the weapons and spends the training points by your plan as the hero levels up, including while you ascend.

<!-- drh:show -->
Plan each hero's weapons and training once. As the hero levels up, the mod equips the planned weapons and spends new training points by your plan, in Town or in a dungeon.

- **Weapon plan:** open Storage > Loot, select an owned hero and press **ASCENSION** beside Add Storage. Pick a slot (J, K or L) and choose one weapon for each required level. Filter by type, rarity and level; **Auto Select** fills the slot from the filtered list, preferring rarity, mana and estimated combat value. **None** clears the slot's plan. **Save** keeps it, **Cancel** discards your changes, and switching hero or closing Storage saves too.
- **Automatic equipment:** after a confirmed level-up, the latest planned weapon at or below the hero's level is equipped with the game's normal equip request, one at a time. Manual changes at the same level are kept, missing weapons are reported, and nothing is equipped until a plan exists.
- **Training plan:** open Training and press **ASCENSION**. Each stat row gets **-1 +1 -10 +10**: the plan is an ordered list of up to 300 points (75 per stat). Adding goes to the end of the list; removing takes that stat's last points, so the order is kept. **RESET** empties the plan, **SAVE** keeps it, **CANCEL** discards it, and switching hero saves.
- **Automatic training:** whenever a hero has unspent training points, they are spent in plan order with the game's own training request, even in a dungeon right after a level-up. Points you already spent count toward the plan, and stats are never lowered. A message such as "3 skill points added to Melee Power" confirms each spend; if a loading screen hides it, it is shown again after loading.
- **Inventory extras:** modifier icons show their star level, the selected slot is marked in cyan, and the planner works with a controller (D-pad to move, A to press or toggle a weapon).

**Settings > Mods:** **Automatic equipment** and **Automatic training** (both on by default) turn the automatic parts off while keeping your plans.

**With Weapon Modifiers in Inventory Preview:** both mods can run together. While that mod is turned on, it draws the weapon levels and modifier icons on inventory cards, and Ascension Helper's own levels and star-level modifier icons are not shown. To get Ascension Helper's inventory look, turn Weapon Modifiers in Inventory Preview off.

Plans are stored only in this mod's local data folder, per account and hero. Nothing is uploaded. Game artwork and fonts are loaded from the installed game and are not included.
<!-- /drh:show -->

## Screenshots

Weapon plan for one slot, with filters and the selected-slot counts:

![Weapon planner](docs/screenshots/weapon-planner.webp)

Training plan on the Training screen:

![Training planner](docs/screenshots/training-planner.webp)

Training points spent automatically at the start of a dungeon:

![Skill points message](docs/screenshots/skill-points-message.webp)

## Notes

- Requires DRH 18 and API 1.5 (`extends`). Restart the game after installing.
- Equipment and training requests can be sent during a dungeon. The account is updated at once; whether the current run uses the change right away is decided by the game server.
- Auto Select scores are a selection aid, not measured DPS. Manual choices always win.
- The mod never sells items, opens chests, buys storage, moves weapons off another hero or lowers stats.

## Changes since 0.1.52

- Controller navigation in the planner works again: rebuilding the links no longer tried to set a weapon card's highlight handler a second time, which the game refuses ("already has a selected interaction").

## Changes since 0.1.49 (0.1.50 did not load and was replaced by 0.1.51)

- Saved plans always match your account. On login, every 2 seconds (also with Automatic equipment off) and right before the planner opens, every hero's plan and unsaved draft is checked: weapons you no longer own (sold, salvaged, traded) are removed, with a short notice.
- A weapon can be planned for one hero only, since two heroes cannot equip it at the same time. When two heroes have the same weapon planned, the hero currently holding it keeps it, otherwise the hero that planned it first. The planner and Auto Select no longer offer weapons planned for another hero.
- The planner opens even if a single weapon card or saved plan row cannot be drawn: that card is skipped and reported in the game log with its weapon id and the exact step.
- Safety: if none of several planned weapons can be found at all, plans are left unchanged instead of being wiped.

## Changes since 0.1.48

- Fixed "Could not open the weapon planner: Null Object Reference" after selling an equipped, planned weapon. After a sale the game rebuilds its own inventory cards; cleaning up the overlays on the old, destroyed cards failed and stopped the planner from opening. That cleanup can no longer block it, and the sold weapon is removed from the plan first.
- If the planner still cannot open, the message names the step that failed.

## Changes since 0.1.47

- Selling (or otherwise losing) a weapon that was in a plan no longer breaks the planner. As soon as Ascension Helper sees the weapon is gone, it removes it from the saved plan and any unsaved draft, shows a short notice, and never tries to equip it.
- If the planner ever fails to open, a message now says why instead of nothing happening.

## Changes since 0.1.46

- No longer incompatible with Weapon Modifiers in Inventory Preview: while that mod runs, Ascension Helper leaves the levels and modifier icons on inventory cards to it and keeps everything else.
- Errors the mod recovers from, such as an unreadable plan file or a failed controller link, are now written to the game log (at most three times each) instead of being ignored.

## Development

Run `python tests/run.py --haxe PATH_TO_HAXE` for the offline tests. They use test doubles for the game and do not run the native game.

## Credits

Thanks to [XξИӦĜεй三尺Šĭ乌](https://github.com/Xenogenersis/) for the idea.

## License

Code is GPL-3.0; see [LICENSE](LICENSE).
