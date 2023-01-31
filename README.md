![Banner](/.github/images/banner.png)

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
- Alternative DGS panel (optional)
- Permissions system (per mod and to use the GUI)
- Teleportation system with GUI (example/demo)

This resource is intended for servers that want to give players the choice of which server replacement mods they can use (e.g. Freeroam/RPG/Drift/Racing servers).

Everything can be customized to your liking. See the sections below for more information.

⭐ **Star the repository if you like the project!**

## Support/Help

MTA forum topic: [Link](https://forum.multitheftauto.com/topic/139565-rel-mod-downloader-with-gui/)

If you need help with anything related to this project, please read the corresponding section on the MTA forum thread linked above.

## Setup

**Installation** is very simple:

- Download the `mod_downloader` folder from the [latest release ZIP](https://github.com/Fernando-A-Rocha/mta-mod-downloader/releases/latest)
- Extract the folder to your MTA server's `resources` folder

There are demo mod files located in `mod_downloader/mods`. You can `start` the resource and type `/mods` to open the GUI!

To **customize** the resource, you can edit the `<settings>` in `meta.xml` manually.

You can also use the default MTA:SA `admin` resource's management panel to edit the settings.

![Admin panel](/.github/images/admin_settings.png)

Mods are defined in `meta.xml` under `<mods>`.

The mod files need to exist in the server. This script is responsible for adding the `<file src='...'>` nodes to the meta.xml automatically, so you don't have to.

Mods are organized in categories (each has a unique name) that will be displayed in the GUI. If a category has `group_mods="true"` then the mods in that category will be activated/deactivated all together, and players won't be able to toggle them individually.

Each mod has the following attributes:

- `name` - The name of the mod (**must be unique**)
- `replace` - The ID that it will replace (e.g. 1 for skin 1), see [ID lists below](#id-lists)
- (optional) `dff` - The DFF file path (e.g. `mods/skin1.dff`)
- (optional) `txd` - The TXD file path (e.g. `mods/skin1.txd`)
- (optional) `col` - The COL file path (e.g. `mods/vendingmachine.col`), this is for objects
- (optional) `lod_distance` - Custom [model LOD distance](https://wiki.multitheftauto.com/wiki/EngineSetModelLODDistance) (e.g. 300)
- (optional) `activated_by_default` - Whether the mod is activated by default (true/false)
- (optional) `encrypted` - Whether the mod is encrypted using [NandoCrypt](#nandocrypt) (true/false)
- (optional) `permission_check` - The name of the serverside permission check function (e.g. `isPlayerAdmin(player)`)

## NandoCrypt

You can use [NandoCrypt (GitHub repository)](https://github.com/Fernando-A-Rocha/mta-nandocrypt) to encrypt your mods, then add the `encrypted` attribute to the mod in `meta.xml` and set it to `true`. This system will automatically decrypt the mod files when loading them. Don't forget that the `nando_decrypter` client script must be running, and you need to define the correct `decryption function name` in the resource settings.

The default setup comes with a few encrypted mods and a ready to use `nando_decrypter` client script.

## Reminders

- After adding one or more mods to the `<mods>` list or changing any of the `<settings>`, you must `restart` the resource for the changes to take effect.
- When deleting a mod from your server's filesystem that you will also remove from the resource's `<mods>` list, you must remove the mod's `<file src='...'>` nodes that can be found at the bottom of the `meta.xml` file. Otherwise, the resource won't load if it references files that don't exist.
- The `admin` settings editor doesn't update the `<settings>` in `meta.xml` when you save the settings. It actually saves the settings in the server's [settings registry](https://wiki.multitheftauto.com/wiki/Settings_system). So don't worry if you don't see the changes in `meta.xml` after saving the settings in the admin panel, MTA is loading the settings from the registry.

## GUI Customization

The GUI is fully customizable. You can change the colors, messages, etc. in the resource's `<settings>` in `meta.xml`.

Ontop of that, you can also use the `dgs` version of the GUI ([gui_client_dgs.lua](/mod_downloader/main/gui_client_dgs.lua)) which was created using [DGS version 3.519](https://github.com/thisdp/dgs/releases/tag/3.519) (a GUI library that uses dxDraw and is mostly compatible with the CEGUI functions). To do this, comment the `gui_client.lua` script node and uncomment the `gui_client_dgs.lua` one in `meta.xml`.

## Usage

Players can access the GUI by typing the command defined (default `/mods`) and/or the key bind defined (default none).

Players will only be able to access the panel if they have permission. This is defined in [permissions_server.lua (canPlayerOpenGUI(player))](/mod_downloader/main/permissions_server.lua).

Additional permissions can be defined in [permissions_server.lua (e.g. isPlayerAdmin(player))](/mod_downloader/main/permissions_server.lua). These functions can be referenced in each mod defined in `meta.xml`, and the player will only receive the mod if they have permission.

## Screenshots

Default GUI:

![Screenshot](/.github/images/demo_gui.png)
![Screenshot](/.github/images/demo_toggle.png)
![Screenshot](/.github/images/demo_request.png)

DGS GUI Version:

![Screenshot](/.github/images/demo_gui_dgs.png)
![Screenshot](/.github/images/demo_request_dgs.png)

Demo TP System:

![Screenshot](/.github/images/demo_tpGUI.png)

## ID Lists

- [MTA:SA Vehicle IDs](https://wiki.multitheftauto.com/wiki/Vehicle_IDs)
- [MTA:SA Skin IDs](https://wiki.multitheftauto.com/wiki/All_Skins_Page)
- [MTA:SA Weapon IDs & Object Models](https://wiki.multitheftauto.com/wiki/Weapons)
- [GTA:SA Object IDs](https://dev.prineside.com/gtasa_samp_model_id/?devtools_locale=en) (ignore the SA-MP IDs)

## Demo & Examples

There is a **teleportation system** included in the resource which allows you to define locations that players can teleport to, and require certain mods to be loaded in order to teleport to them. See [teleportat_client.lua](/mod_downloader/main/teleport_client.lua) for more information.

There are also **testing commands** that can be used to test certain Mod Downloader features. See [testing_server.lua](/mod_downloader/main/testing_server.lua) for more information.

**You can code your own implementations using the functions and custom events available both client and server side.**

## Credits

A version of the Mod Downloader GUI using [dgs by thisdp (GitHub repository)](https://github.com/thisdp/dgs) is present in this resource.

Several mods are also included for testing purposes:

- Bank Robbers - [SlingShot753's Workshop](https://gtaforums.com/topic/917058-slingshot753s-workshop/)
- Desert Eagle .50 - [SlingShot753's Workshop](https://gtaforums.com/topic/917058-slingshot753s-workshop/)

## Final Note

Feel free to contribute to the project by improving the code & documentation via Pull Requests. Thank you!
