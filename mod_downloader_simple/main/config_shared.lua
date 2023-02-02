--[[
	Author: https://github.com/Fernando-A-Rocha

	config_shared.lua

	General Configuration File
--]]

-- Client & Server debug/info messages
DEBUG_ENABLED = true
MSG_PREFIX_COLOR = "#ffb833"
MSG_COLOR = "#ffffff"
MESSAGES_PREFIX = "[SMDL] "

-- File storage resource name
-- Place mod files inside this resource in the folder specificed below
STORAGE_RES_NAME = "file_storage"

-- Where to scan for mod files | Paths must end with '/'
-- The more folders you have the more time it will take to scan for files (it will be more intensive on the server)
SCAN_FOLDERS = {
	"mods_simple/",
}

-- Command to re-scan for mod files
-- Can be executed by logged in admins and in Server Console
COMMAND_RESCAN = "smdlscan"

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
	["object_ids"] = false, -- e.g. 1337 (BinNt07_LA)   [these take longer to scan]

	--[[
		dff_name.dff / txd_name.dff / dff_name.col FORMAT
		ALL LOWERCASE
	]]
	["skin_names"] = true, -- e.g. male01 (real gta3.img name)
	["vehicle_names"] = true, -- e.g. landstal (real gta3.img name)
	["vehicle_nice_names"] = true, -- e.g. ambulance (pretty name) and not ambulan (real gta3.img name)
	["object_names"] = false, -- e.g. shovel (real gta3.img name)   [these take longer to scan]
}

-- Command to extract model files from a XXXX.img container (GTA:SA version supported)
COMMAND_EXTRACT_IMG = "smdlimg"

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
ASYNC_PRIORITY = "normal"
