# Shout Shockwave

Project Zomboid Build 42 mod. Your shout becomes a weapon: train the new **Shout** skill and a yell staggers, knocks down, dazes and hurts nearby zombies, and shatters nearby building windows.

## Features

- **Shout skill unlocks the effects.** Level 2 stagger, 4 knock down, 6 daze, 8 damage and windows. Each new effect hits the closest zombies; earlier effects reach further. Stronger effects include the weaker ones.
- **Louder shout, bigger blast.** Strength and Shout raise loudness; a megaphone, whistle or harmonica raise it as in vanilla. Strength of the blast = loudness ÷ distance, adjusted for zombie health (tough zombies resist).
- **Windows.** From level 8 the blast breaks nearby building windows (vanilla smash: sound and alarms). Boarded and open windows are spared; vehicle windows are never touched.
- **Endurance, no cooldown.** Each shout costs endurance (less with Fitness); tired shouts are quieter and weaker.
- **XP.** Shouting alone trains Shout to level 2; after that XP comes from affected zombies (capped per shout). Knockdowns give a little Strength XP.
- **Effects.** Ground shockwave ring that grows with level, dust on knocked-down zombies (level 8+), low rumble (level 4+). Ring and dust can be turned off in Mod Options.

Sandbox options: stagger / knockdown / daze / damage / windows on-off, damage multiplier, endurance cost multiplier, window range multiplier.

## Install

- Steam Workshop: (link after upload)
- Manual: copy `Contents/mods/ShoutShockwave` into `%USERPROFILE%\Zomboid\mods\`.

## Compatibility

Lua only, no vanilla files replaced. All Lua shout callers (Q key, emote wheel, vehicle passenger, controller) go through `IsoPlayer:Callout`, which the mod wraps. In multiplayer the server computes the effects and the client that simulates each zombie applies them, so the mod is needed on server and clients. Safe to add to a save. Multiplayer not tested yet.

## Testing

`pzt live` in this folder (PZTestHarness) runs `tests/ShoutShockwave_Test.lua`: hook, skill, vanilla radius rules, formulas, unlock ladder, real knockdown/stagger/daze/damage on spawned zombies, endurance, XP, windows, ring/dust/rumble stages. Single player only.

## Support

If this mod helps you, you can support it via [Ko-fi](https://ko-fi.com/talkinghands2285) or [PayPal](https://www.paypal.com/paypalme/TalkingHands619/3). It's optional; every feature stays free.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/talkinghands2285)
