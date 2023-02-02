--[[
	Author: https://github.com/Fernando-A-Rocha

	config_shared.lua

	General Configuration File
--]]

-- File storage resource name
STORAGE_RES_NAME = "file_storage"

-- Where to scan for mod files
MODS_PATH = "mods_simple/"

-- Insert file nods in meta.xml with download="false"
DEFAULT_FILE_AUTO_DOWNLOAD = false

-- Decide which file name formats are auto-detected by this mod-downloader
-- Disabling scanning that you don't use will result in faster startup server-side
SCAN_MODS = {
	--[[
		ID.dff / ID.txd / ID.col FORMAT
	]]
	["skin_ids"] = true, -- e.g. 7 (male01)
	["vehicle_ids"] = true, -- e.g. 411 (Infernus)
	["object_ids"] = true, -- e.g. 1337 (BinNt07_LA)

	--[[
		dff_name.dff / txd_name.dff / dff_name.col FORMAT
		ALL LOWERCASE
	]]
	["skin_names"] = true, -- e.g. male01 (real gta3.img name)
	["vehicle_names"] = true, -- e.g. landstal (real gta3.img name)
	["vehicle_nice_names"] = true, -- e.g. ambulance (pretty name) and not ambulan (real gta3.img name)
	["object_names"] = true, -- e.g. shovel (real gta3.img name)
}

-- Mod file download feature
SHOW_DOWNLOADING = true -- display the downloading progress dxDraw
KICK_ON_DOWNLOAD_FAILS = true -- kick player if failed to download a file more than X times
DOWNLOAD_MAX_TRIES = 3 -- Kicked if failed to download a file 3 times, won't happen if above setting is false

-- Enable NandoCrypt
NANDO_CRYPT_ENABLED = true

-- NandoCrypt file extension (e.g. results in car.dff.nandocrypt)
NANDO_CRYPT_EXTENSION = ".nandocrypt"

-- Name of the function to decrypt the mod files
-- (located in nando_decrypter.lua)
NANDO_CRYPT_FUNCTION = "ncDecrypt"

--[[
	MTA:SA Async library Settings

	Async:setPriority("low");    -- better fps
	Async:setPriority("normal"); -- medium
	Async:setPriority("high");   -- better perfomance
]]
ASYNC_PRIORITY = "low"
