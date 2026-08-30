# Towny

This is a [Luanti](https://luanti.org/) modpack based on the popular
[Minecraft server mod](https://github.com/TownyAdvanced/Towny) of the same name.

At it's current state, it's a fixed-grid protection mod
based on claims and plots. This mod is a work in progress, There are missing features and possibly some bugs. There will be a lot of changes until a stable release is made.

**[Forum Post](https://forum.minetest.net/viewtopic.php?f=9&t=21912)**

## Residents
A resident is a player in a towny server. They can join or make a town.
They can own plots, be a comayor for their town, be trusted in a town or get kicked out of a town.

## Claim Blocks
A claim block is 16x16x16 nodes (or one mapblock) in size. By default, nobody
in town except for the mayor and comayors can build in an unplotted claim block. A claim block can be turned into a plot with the */plot claim* command.

### Permissions and Toggles
Blocks have permissions and toggles, so you can fine tune the protection in a block.
There are 5 groups; trusted, resident, nation, ally, outsider,
and there are 5 types; place, dig, switch (open chests, doors, levers, etc.), itemuse (screwdriver etc.), and buy (buy a plot).
There are 4 toggles, explosions, pvp, firespread, and mobspawns.
If you want outsiders to open chests and doors but don't want them to do anything else? You can do that.
If you want tnt to destroy nodes in a part of your town, but disallow everything else? You can do that.

## Towns
A town is made up of residents and claim blocks. Towns can invite residents, and expand their territory. Towns have a mayor and can have comayors. You can set the permissions and toggles for every block in your town at once.

## Plots
Plots are town claim blocks that can be owned by a town resident. Plots can have multiple members.

## TODO
* [ ] Implement nations
* [ ] Implement economy
* [ ] Implement more ranks
* [ ] Implement more townyadmin commands
