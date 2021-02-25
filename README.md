# Useful Bots

A lightweight bot overhaul that improves how bots prioritize enemies, lets them help you dominate, lets them attack turrets, improves their civilian intimidation and other small tweaks.  

**Requires HopLib**

## Customizable Features

* Highly customizable target priority settings to tweak which enemies have priority and how priority is calculated
* Ability for bots to dominate enemies on their own or assist your domination attempts (normal game rules apply to bots)
* Option to make bots not crouch and always use a standing pose
* Option to make bots announce when they are low on health, just like player characters do
* Option to disable bots marking special enemies (for when you want to give a high priority to only your own marked targets)

## Improvements

* Improved special spotting code so bots only mark targets they see and are higher priority
* Improved civilian intimidation code so bots will keep civilians down more reliably and not only when civilians are already running away
* Changed weapon raycast and enemy slot masks so bots can shoot through each other and can target SWAT turrets
* Escort targets are now considered for civilian intimidation and bots will shout at stopped escorts to keep them moving
* Bots will use player animations for spotting enemies and intimidating civilians

## Changes

* Bots will now fully count for game balancing, so 4 bots will result in the same enemy spawns as 4 players instead of only 3
