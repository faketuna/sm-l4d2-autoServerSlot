# Auto server slot

## Caution

Any similar plugins that automate the survivor spawn, like [LEFT12DEAD](https://forums.alliedmods.net/showthread.php?t=126857) will conflict with this plugin. please remove it.

## Feature

* Dynamically adjust the survivors count.
* Dynamically adjust the server slot.
* Add survivor bot when player joined to the game.
* Kick survivor bot when player disconnected by self. (optional)
* When [Medkit density](https://forums.alliedmods.net/showpost.php?p=2745397&postcount=5) installed, it will adjust medkit count dynamically based from in game survivor count.

## Dependency

* [l4dtoolz](https://github.com/Accelerator74/l4dtoolz/releases)

## Optional dependency

* [Medkit density](https://forums.alliedmods.net/showpost.php?p=2745397&postcount=5)

## ConVar

* `sm_aslot_version` - Plugin version
* `sm_aslot_debug` - `0/1` - Toggles debug message
* `sm_aslot_kick` - `0/1` - Toggles auto kick. When set to 1 and player disconnected by self, survivor bot will be kicked if survivor counts higher than 5.
* `sm_aslot_fixed_survivor_limit` - `-1~32` - Fix survivor_limit with this number. or if set to -1 **(not recommended)** it will adjust survivor_limit dynamically based from in game player count.
* `sm_aslot_fixed_server_slot` - `-1~32` - Fix sv_maxplayers with this number. If set to -1 It will adjust sv_maxplayers dynamically based from in game player count + 1  
