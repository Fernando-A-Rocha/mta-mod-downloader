![Banner](https://i.imgur.com/Hoz8KAn.png)

Mod Downloader (with GUI) for Multi Theft Auto: San Andreas:

- Highly customizable
- Translatable
- Robust
- Optimized
- Up to date

This system allows your players to control which replacement mods (skins, vehicles, objects/weapons) they want to download and use.

The following features are available:

- Resource settings to control everything
- Minimalistic CEGUI panel
- Permissions system (per mod and to use the GUI)
- Teleportation system with GUI (example/demo)

Everything can be customized to your liking. See the [Setup](#setup) and [Use](#use) sections for more information.

MTA forum topic: *COMING SOON*

Contact (author): Nando#7736 (**Discord**)

⭐ **Star the repository if you like the project!**

## Setup

**Installation** is very simple:

- Download the `mod_downloader` folder from the [latest release ZIP](https://github.com/Fernando-A-Rocha/mta-mod-downloader/releases/latest)
- Extract the folder to your MTA server's `resources` folder

There are demo mod files located in `mod_downloader/mods`. You can `start` the resource and type `/mods` to open the GUI!

To **customize** the resource, you can edit the `<settings>` in `meta.xml` manually.

You can also use the default MTA:SA `admin` resource's management panel to edit the settings.

![Admin panel](https://i.imgur.com/HXH6tVF.png)

Mods are defined in `meta.xml` under `<mods>`. Mods are organized in categories (each has a unique name) that will be displayed in the GUI.

The mod files need to exist in the server. This script is responsible for adding the file nodes to the meta.xml automatically, so you don't have to.

Each mod has the following attributes:

- `name` - The name of the mod (must be unique)
- `replace` - The ID that it will replace (e.g. 1 for skin 1)
- (optional) `dff` - The DFF file path (e.g. `mods/skin1.dff`)
- (optional) `txd` - The TXD file path (e.g. `mods/skin1.txd`)
- (optional) `col` - The COL file path (e.g. `mods/vendingmachine.col`), this is for objects
- (optional) `activated_by_default` - Whether the mod is activated by default (true/false)
- (optional) `encrypted` - Whether the mod is encrypted using NandoCrypt (true/false)
- (optional) `permission_check` - The name of the serverside permission check function (e.g. `isPlayerAdmin(player)`)

There is a [demo teleportation system](/mod_downloader/teleport_client.lua) included in the resource. It could be useful for Freeroam/Drift servers.

## Reminders

- When deleting a mod from your server's filesystem that you will also remove from the resource's `<mods>` list, you must remove the mod's `<file>` nodes that can be found at the bottom of the `meta.xml` file. Otherwise, the resource won't load if it references files that don't exist.

## Use

Players can access the GUI by typing the command defined (default `/mods`) and/or the key bind defined (default none).

Players will only be able to access the panel if they have permission. This is defined in [permissions_server.lua (canPlayerOpenGUI(player))](/mod_downloader/permissions_server.lua).

Additional permissions can be defined in [permissions_server.lua (e.g. isPlayerAdmin(player))](/mod_downloader/permissions_server.lua). These functions can be referenced in each mod defined in `meta.xml`, and the player will only receive the mod if they have permission.

## Screenshots

![Screenshot 1](https://i.imgur.com/C2v7yCU.png)
![Screenshot 2](https://i.imgur.com/vLsGi92.png)

## Credits

A few mods are included in the main resource (for testing purposes):

- Bank Robbers - [SlingShot753's Workshop](https://gtaforums.com/topic/917058-slingshot753s-workshop/)
- Desert Eagle .50 - [SlingShot753's Workshop](https://gtaforums.com/topic/917058-slingshot753s-workshop/)

## Final Note

Feel free to contribute to the project by improving the code & documentation via Pull Requests. Thank you!
