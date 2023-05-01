# Useful Bots

A lightweight bot overhaul that improves how bots prioritize enemies, lets them help you dominate, lets them attack turrets, improves their civilian intimidation and other small tweaks.  

**Requires HopLib**

## Customizable Features

* Highly customizable target priority settings to tweak which enemies have priority and how priority is calculated
* Option to make bots dominate enemies on their own or assist player domination attempts (normal game rules apply to bots, only works with custom target priority enabled)
* Option to make bots not crouch and always use a standing pose
* Option to make bots not abandon their positions when they are too far from the player
* Option to make bots stop at the player's position when they are told to hold position
* Option to make bots announce when they are low on health, just like player characters do
* Option to disable bots marking special enemies
* Option to disable bot battle cries
* Option to make weapons shots of bots go through tied down enemy hostages
* Option to prevent bots from getting into slow vehicles like forklifts
* Option to disable ammo drops from enemies killed by bots
* Option to make bots avoid using Inspire when they are already within revive range
* Option to make a bots defend a reviving player
* Option to increase revive range for bots reviving other bots

### Target priority

By default, there is some basic setup for improved bot target priority which should already feel a lot better than the vanilla targeting. You can fine tune all priority modifiers to your liking in the mod options. Multipliers you set in the options are applied to the calculated base priority of a target. The base priority settings define the initial priority of an enemy, based on the setting:  
"By weapon stats" prioritizes targets based on the bots weapon stats for the target distance.
"By distance" prioritizes targets only based on their distance to the bot, the bot's weapon stats will not be accounted for.
"No changes" disables the custom target priority code entirely and use the vanilla code. Any multipliers defined will be ignored if this setting is used.

## Improvements

* Improved special spotting code so bots only mark targets they see and are higher priority
* Improved civilian intimidation code so bots will keep civilians down more reliably and not only when civilians are already running away
* Improved distance check to determine which bot is selected to revive a player
* Improved Inspire check to not rely on detected attention objects
* Changed weapon raycast and enemy slot masks so bots can shoot through each other and target SWAT turrets
* Escort targets are now considered for civilian intimidation and bots will shout at stopped escorts to keep them moving
* Bots will use player animations for spotting enemies and intimidating civilians
* Bots will not drop light bags when they are going to revive someone
* Bots will try to kill Cloakers and Tasers before starting to revive
* Bots and Jokers will follow more directly to better keep up with players
* Bots will stop reviving when someone else starts reviving the same person
* Bots will stop immediately when told to stay and will return to their positions after helping up a downed player

## Changes

* Bots will now fully count for game balancing
* Bots will now count for the crew alive bonus
