# Shout Shockwave

Project Zomboid Build 42 mod. Your shout becomes a weapon: train the new **Shout** skill and a yell staggers, knocks down, dazes and hurts nearby zombies, and shatters nearby building windows.

## Features

- **Shout skill unlocks the effects.** Level 2 stagger, 4 knock down, 6 daze, 8 damage and windows. Each new effect hits the closest zombies; earlier effects reach further. Stronger effects include the weaker ones.
- **Louder shout, bigger blast.** Strength and Shout raise loudness; a megaphone, whistle or harmonica raise it as in vanilla. Strength of the blast = loudness ÷ distance, adjusted for zombie health (tough zombies resist). Distance follows vanilla sound: a floor counts as 3 tiles, another room ×1.2 and indoors↔outdoors ×1.68 on the squared distance (walls themselves are not checked, as in vanilla).
- **Windows.** From level 8 the blast breaks nearby building windows (vanilla smash: sound and alarms). Boarded and open windows are spared; vehicle windows are never touched.
- **Endurance, no cooldown.** Each shout costs endurance (less with Fitness and Shout level); tired shouts are quieter and weaker, down to half loudness at zero endurance, where vanilla exhaustion penalties apply. In multiplayer the server spends the endurance and sends the value back (0.1.3; before, the server's once-a-second stats sync refilled it and shouts could be spammed).
- **XP.** Shouting alone trains Shout to level 2; after that XP comes from affected zombies (capped per shout). Knockdowns give a little Strength XP.
- **Effects.** Ground shockwave ring that grows with level, dust on knocked-down zombies (level 8+), low rumble (level 4+). Ring and dust can be turned off in Mod Options.

Sandbox options: stagger / knockdown / daze / damage / windows on-off, damage multiplier, endurance cost multiplier, window range multiplier.

## Install

- Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3841497037
- Manual: copy `Contents/mods/ShoutShockwave` into `%USERPROFILE%\Zomboid\mods\`.

## Compatibility

Lua only, no vanilla files replaced. All Lua shout callers (Q key, emote wheel, vehicle passenger, controller) go through `IsoPlayer:Callout`, which the mod wraps. In multiplayer the server computes the effects and the client that simulates each zombie applies them, so the mod is needed on server and clients. Safe to add to a save. Multiplayer not tested yet.

## Testing

`pzt live` in this folder (PZTestHarness) runs `tests/ShoutShockwave_Test.lua`: hook, skill, vanilla radius rules, formulas, vanilla sound distance on real room squares and floors, unlock ladder, real knockdown/stagger/daze/damage on spawned zombies, endurance (including the server-side spend and that the cost is not refilled faster than vanilla regen), XP, windows, ring/dust/rumble stages. Single player only.

## Support

If this mod helps you, you can support it via [Ko-fi](https://ko-fi.com/talkinghands2285) or [PayPal](https://www.paypal.com/paypalme/TalkingHands619/3). It's optional; every feature stays free.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/talkinghands2285)
