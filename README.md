# Useful Bots

A lightweight bot overhaul that improves how bots prioritize enemies, lets them help you dominate, lets them attack turrets, improves their civilian intimidation and other small tweaks.  

**Requires HopLib**

## Customizable Features

* Highly customizable target priority settings to tweak which enemies have priority and how priority is calculated
* Ability for bots to dominate enemies on their own or assist your domination attempts (normal game rules apply to bots)
* Option to make bots not crouch and always use a standing pose
* Option to make bots not abandon their positions when they are too far from the player
* Option to make bots announce when they are low on health, just like player characters do
* Option to disable bots marking special enemies
* Option to make weapons shots of bots go through tied down enemy hostages

### Target priority

By default, there is some basic setup for improved bot target priority which should already feel a lot better than the vanilla targeting. You can fine tune all priority modifiers to your liking in the mod options. Multipliers you set in the options are applied to the calculated base priority of a target. The base priority settings define the initial priority of an enemy, based on the setting:  
"By weapon stats" means targets are prioritized based on the bots weapon stats at the target's distance.
"By distance" means enemies will just be prioritized based on their distance to the bot, the bot's weapon will not be accounted for.
"No changes" disables the custom target priority code entirely and use the vanilla code. Any multipliers defined will be ignored if this setting is used.

## Improvements

* Improved special spotting code so bots only mark targets they see and are higher priority
* Improved civilian intimidation code so bots will keep civilians down more reliably and not only when civilians are already running away
* Changed weapon raycast and enemy slot masks so players and bots can shoot through each other and bots can target SWAT turrets
* Escort targets are now considered for civilian intimidation and bots will shout at stopped escorts to keep them moving
* Bots will use player animations for spotting enemies and intimidating civilians

## Changes

* Bots will now fully count for game balancing, so 1 player + 3 bots will result in the same enemy spawns as 4 players
