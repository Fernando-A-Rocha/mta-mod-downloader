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

SCAN_MODS = {
	["vehicles"] = true,
	-- ["skins"] = true,
	-- ["objects"] = true,
}

-- Mod file download feature
SHOW_DOWNLOADING = true -- display the downloading progress dxDraw
KICK_ON_DOWNLOAD_FAILS = true -- kick player if failed to download a file more than X times
DOWNLOAD_MAX_TRIES = 3 -- Kicked if failed to download a file 3 times, won't happen if above setting is false

-- Enable NandoCrypt
NANDO_CRYPT_ENABLED = true

-- Name of the function to decrypt the mod files
-- (located in nando_decrypter.lua)
NANDO_CRYPT_FUNCTION = "ncDecrypt"

NANDO_CRYPT_EXTENSION = ".nandocrypt"

--[[
	MTA:SA Async library Settings

	Async:setPriority("low");    -- better fps
	Async:setPriority("normal"); -- medium
	Async:setPriority("high");   -- better perfomance
]]
ASYNC_PRIORITY = "normal"
