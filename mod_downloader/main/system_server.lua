--[[
	Author: https://github.com/Fernando-A-Rocha

	server.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

addEvent("modDownloader:requestOpenModPanel", true)
addEvent("modDownloader:requestRefreshMods", true)
addEvent("modDownloader:onDownloadManyFails", true)

outputServerLog_ = outputServerLog
function outputServerLog(text)
    outputServerLog_("[Mod Downloader] "..tostring(text))
end

local currentlyLoading = true

local loadedSettings = nil
local loadedMods = nil

local clientsWaiting = {}
local lastSpamLoadMods = {}

-- [Exported]
function getLoadedMods()
    return receivedMods
end

-- [Exported]
function getSetting(name)
    if not loadedSettings then
        return nil
    end
    return loadedSettings[name]
end

local function outputCustomMessage(player, msg, msgType)
    local prefix = getSetting("msg_prefix")
    local color = getSetting("color_"..msgType)
    local color_msg = getSetting("color_msg")

    if prefix and color and color_msg then
        msg = color..prefix..color_msg..msg
    end

    outputChatBox(msg, player, 255, 255, 255, true)
end

-- local missingSettings={} -- TEMP(DEV)
-- local function addMissingSettings()
--     local f = xmlLoadFile("meta.xml")
--     local children = xmlNodeGetChildren(f)
--     for i=1, #children do
--         local child = children[i]
--         if child and xmlNodeGetName(child) == "settings" then
--             for k,v in pairs(missingSettings) do
--                 local setting = xmlCreateChild(child, "setting")
--                 xmlNodeSetAttribute(setting, "name", "*"..k)
--                 xmlNodeSetAttribute(setting, "value", tostring(v))
--                 print("add", k, tostring(v))
--             end
--             break
--         end
--     end
--     xmlSaveFile(f)
--     xmlUnloadFile(f)
-- end

local function loadResSettings()

    local VALID_SETTINGS = {
        -- name, default value, minimum value(if number), maximum value(if number)
        {"enable_nandocrypt", true},
        {"nc_decrypt_function", "ncDecrypt"},

        {"show_download_dialog", true},
        {"max_failed_downloads", 3, 1, 10},
        {"kick_when_too_many_dl_fails", true},

        {"cmd_panel", "mods"},
        {"bind_panel", ""},

        {"anti_spam_delay_load_mods", 1000, 500, 60000},
        {"anti_spam_delay_gui_buttons", 500, 500, 5000},
        {"allow_refresh_mods", false},

        {"color_msg", "#ffffff"},
        {"color_info", "#bdbdbd"},
        {"color_error", "#f24b4b"},
        {"color_success", "#4bf24b"},
        {"color_warning", "#f2f24b"},

        {"msg_prefix", "[Mod Downloader] "},

        {"msg_no_access", "You cannot use the Mod Downloader panel now."},
        {"msg_too_fast", "Please wait before doing this again.."},
        {"msg_mod_download", "You will now download then activate the mod: "},
        {"msg_mod_activated", "You've activated the mod: "},
        {"msg_mod_activated_all", "You've activated multiple mods"},
        {"msg_mod_deactivated", "You've deactivated the mod: "},
        {"msg_mod_deactivated_all", "You've deactivated multiple mods"},

        {"gui_title", "Mod Downloader by Fernando"},
        {"gui_description", "Enjoy!"},
        {"gui_btn_enable", "Activate"},
        {"gui_btn_disable", "Deactivate"},
        {"gui_btn_enableall", "Activate All"},
        {"gui_btn_disableall", "Deactivate All"},
        {"gui_btn_close", "Close"},
        {"gui_btn_refresh", "Refresh"},
        {"gui_grid_col_name", "Mod Name"},
        {"gui_grid_col_replaces", "Replaces"},
        {"gui_grid_col_enabled", "Activated"},
        {"gui_grid_col_ready", "Ready"},
        {"gui_yes", "Yes"},
        {"gui_no", "No"},
    }

    for i=1, #VALID_SETTINGS do
        local v = VALID_SETTINGS[i]
        if type(v)=="table" then
            local name = v[1]
            local defaultValue = v[2]
            local minValue = v[3]
            local maxValue = v[4]

            local value = get(name)
            if not value then
                outputServerLog("Missing setting! Assuming default value for '"..name.."': "..tostring(defaultValue))
                value = defaultValue
                -- missingSettings[name] = value
            else
                if value == "true" then
                    value = true
                elseif value == "false" then
                    value = false
                elseif tonumber(value) then
                    value = tonumber(value)
                end
            end

            if type(value) ~= type(defaultValue) then
                outputServerLog("Invalid value for setting '"..name.."', expected "..type(defaultValue)..", got "..type(value))
                outputServerLog("  Assuming default value: "..tostring(defaultValue))
                value = defaultValue
            end

            if type(value) == "number" then
                if minValue and value < minValue then
                    outputServerLog("Invalid value for setting '"..name.."', expected minimum value of "..tostring(minValue)..", got "..tostring(value))
                    outputServerLog("  Assuming minimum value: "..tostring(minValue))
                    value = minValue
                elseif maxValue and value > maxValue then
                    outputServerLog("Invalid value for setting '"..name.."', expected maximum value of "..tostring(maxValue)..", got "..tostring(value))
                    outputServerLog("  Assuming maximum value: "..tostring(maxValue))
                    value = maxValue
                end
            end

            if not loadedSettings then
                loadedSettings = {}
            end
            loadedSettings[name] = value
        end
    end

    -- addMissingSettings()
end

local WEAPON_OBJECT_IDS = {
    [1] = 331, -- Brassknuckle
    [2] = 333, -- Golfclub
    [3] = 334, -- Nightstick
    [4] = 335, -- Knife
    [5] = 336, -- Bat
    [6] = 337, -- Shovel
    [7] = 338, -- Poolcue
    [8] = 339, -- Katana
    [9] = 341, -- Chainsaw
    [22] = 346, -- Colt 45
    [23] = 347, -- Silenced
    [24] = 348, -- Deagle
    [25] = 349, -- Shotgun
    [26] = 350, -- Sawedoff
    [27] = 351, -- Spas12
    [28] = 352, -- Uzi
    [29] = 353, -- MP5
    [32] = 372, -- Tec9
    [30] = 355, -- AK-47
    [31] = 356, -- M4
    [33] = 357, -- Country Rifle
    [34] = 358, -- Sniper Rifle
    [35] = 359, -- Rocket Launcher
    [36] = 360, -- Heat-Seeking RPG
    [37] = 361, -- Flamethrower
    [38] = 362, -- Minigun
    [16] = 342, -- Grenade
    [17] = 343, -- Teargas
    [18] = 344, -- Molotov
    [39] = 363, -- Satchel
    [41] = 365, -- Spraycan
    [42] = 366, -- Fire Extinguisher
    [43] = 367, -- Camera
    [10] = 321, -- Dildo
    [11] = 322, -- Dildo
    [12] = 323, -- Vibrator
    [14] = 325, -- Flowers
    [15] = 326, -- Cane
    [44] = 368, -- Nightvision Goggles
    [45] = 369, -- Infrared Goggles
    [46] = 371, -- Parachute
    [40] = 364 -- Satchel Detonator
}

local function getNameFromModelID(id)

    local name
    if id >= 400 and id <= 611 then
        name = getVehicleNameFromModel(id)
    
    elseif id >= 321 and id <= 372 then
        for weapID, weapModel in pairs(WEAPON_OBJECT_IDS) do
            if weapModel == id then
                name = getWeaponNameFromID(weapID)
                break
            end
        end
    elseif id > 372 and id <= 18630 then
        name = "Object "..id
    elseif id < 321 then
        name = "Skin "..id
    end

    return name or id
end

local function readModsFromMeta()

    if type(canPlayerOpenGUI) ~= "function" then
        return false, "Access permission check function 'canPlayerOpenGUI' is invalid"
    end

    local f = xmlLoadFile("meta.xml")
    if not f then
        xmlUnloadFile(f)
        return false, "Could not load meta.xml"
    end

    local children = xmlNodeGetChildren(f)
    if not children then
        xmlUnloadFile(f)
        return false, "Could not get children of meta.xml"
    end

    local files = {}

    for i=1, #children do
        local v = children[i]
        if v then
            if xmlNodeGetName(v) == "file" then
                local src = xmlNodeGetAttribute(v, "src")
                if src then
                    if files[src] then
                        xmlUnloadFile(f)
                        return false, "Duplicate entry for file '"..src.."' in meta.xml" 
                    end
                    local download = xmlNodeGetAttribute(v, "download")
                    if download == "false" then
                        download = false
                    else
                        download = true
                    end
                    files[src] = {download = download}
                end
            end
        end
    end

    local insertFiles = {}

    local usedCategories = {}
    local usedModNames = {}

    for i=1, #children do
        local v = children[i]
        if v then
            if xmlNodeGetName(v) == "mods" then
                
                local mods = xmlNodeGetChildren(v)
                if not mods then
                    xmlUnloadFile(f)
                    return false, "Could not get children of 'mods' node"
                end

                for j=1, #mods do
                    local category = mods[j]
                    if category then
                        if xmlNodeGetName(category) ~= "category" then
                            xmlUnloadFile(f)
                            return false, "Invalid node '"..xmlNodeGetName(category).."' inside 'mods' node, expected 'category'"
                        end

                        local categoryName = xmlNodeGetAttribute(category, "name")
                        if not categoryName then
                            xmlUnloadFile(f)
                            return false, "Missing attribute 'name' for category node"
                        end

                        if usedCategories[categoryName] then
                            xmlUnloadFile(f)
                            return false, "Duplicate category name '"..categoryName.."'"
                        end
                        usedCategories[categoryName] = true

                        local categoryMods = xmlNodeGetChildren(category)
                        if not categoryMods then
                            xmlUnloadFile(f)
                            return false, "Could not get children of category '"..categoryName.."'"
                        end

                        for w=1, #categoryMods do
                            local mod = categoryMods[w]
                            if mod then
                                if xmlNodeGetName(mod) ~= "mod" then
                                    xmlUnloadFile(f)
                                    return false, "Invalid node '"..xmlNodeGetName(mod).."' inside category '"..categoryName.."', expected 'mod'"
                                end

                                local replaceID = xmlNodeGetAttribute(mod, "replace")
                                if not replaceID then
                                    xmlUnloadFile(f)
                                    return false, "Missing attribute 'id' for mod node"
                                end
                                if not tonumber(replaceID) then
                                    xmlUnloadFile(f)
                                    return false, "Invalid attribute 'id' for mod node, expected number"
                                else
                                    replaceID = tonumber(replaceID)
                                end

                                local weapObjectModel = WEAPON_OBJECT_IDS[replaceID]
                                if weapObjectModel then
                                    replaceID = weapObjectModel
                                end

                                local modName = xmlNodeGetAttribute(mod, "name")
                                if not modName then
                                    xmlUnloadFile(f)
                                    return false, "Missing attribute 'name' for mod node"
                                end
                                if usedModNames[modName] then
                                    xmlUnloadFile(f)
                                    return false, "Duplicate mod name '"..modName.."'"
                                end
                                usedModNames[modName] = true

                                local activatedByDefault = xmlNodeGetAttribute(mod, "activated_by_default")
                                if not activatedByDefault then
                                    -- Mod is activated by default that parameter is not set
                                    activatedByDefault = true
                                    xmlNodeSetAttribute(mod, "activated_by_default", "true")
                                elseif activatedByDefault == "true" then
                                    activatedByDefault = true
                                else
                                    activatedByDefault = false
                                end

                                local permissionCheck = xmlNodeGetAttribute(mod, "permission_check")
                                local permissionFunction = nil
                                if permissionCheck then
                                    permissionFunction = _G[permissionCheck]
                                    if type(permissionFunction) ~= "function" then
                                        outputServerLog("Invalid serverside permission check function '"..permissionCheck.."' for mod '"..modName.."'")
                                        outputServerLog("  Assuming no permission check")
                                        permissionFunction = nil
                                    end
                                end

                                local encrypted = xmlNodeGetAttribute(mod, "encrypted")
                                if encrypted == "true" then
                                    encrypted = true
                                else
                                    encrypted = false
                                end

                                local dff = xmlNodeGetAttribute(mod, "dff") or nil
                                local txd = xmlNodeGetAttribute(mod, "txd") or nil
                                local col = xmlNodeGetAttribute(mod, "col") or nil

                                local modFiles = {dff, txd, col}
                                for z=1, 3 do
                                    local file = modFiles[z]
                                    if file then
                                        if files[file] == nil then
                                            if not fileExists(file) then
                                                xmlUnloadFile(f)
                                                return false, "Could not find file '"..file.."' for mod '"..modName.."'"
                                            end
                                            insertFiles[file] = true
                                        end
                                    end
                                end

                                if dff then
                                    dff = {path = dff, download = (files[dff] and files[dff].download or false)}
                                else
                                    dff = false
                                end
                                if txd then
                                    txd = {path = txd, download = (files[txd] and files[txd].download or false)}
                                else
                                    txd = false
                                end
                                if col then
                                    col = {path = col, download = (files[col] and files[col].download or false)}
                                else
                                    col = false
                                end

                                if not loadedMods then
                                    loadedMods = {}
                                end

                                loadedMods[#loadedMods+1] = {
                                    category = categoryName,
                                    id = replaceID,
                                    replaces = getNameFromModelID(replaceID),
                                    name = modName,
                                    dff = dff,
                                    txd = txd,
                                    col = col,
                                    activatedByDefault = activatedByDefault,
                                    permissionFunction = permissionFunction,
                                    encrypted = encrypted,
                                }
                            end
                        end
                    end
                end
            end
        end
    end

    local result = "PROCEED"

    for file, _ in pairs(insertFiles) do
        local node = xmlCreateChild(f, "file")
        if not node then
            xmlUnloadFile(f)
            return false, "Could not create 'file' node"
        end
        xmlNodeSetAttribute(node, "src", file)
        xmlNodeSetAttribute(node, "download", "false")

        result = "RESTART"
    end

    xmlSaveFile(f)

    xmlUnloadFile(f)
    return result
end

local function getAllowedMods(player)
    local allowedMods = {}

    for i=1, #loadedMods do
        local mod = loadedMods[i]
        if mod then
            local permissionFunction = mod.permissionFunction
            if (permissionFunction==nil) or (permissionFunction(player)==true) then
                allowedMods[#allowedMods+1] = mod
            end
        end
    end

    return allowedMods
end

-- [Exported]
function sendModsToPlayer(player)
    if not (isElement(player) and getElementType(player)=="player") then return end
    if not loadedMods then
        return
    end

    if lastSpamLoadMods[player] then
        if getTickCount() - lastSpamLoadMods[player] < getSetting("anti_spam_delay_load_mods") then
            triggerClientEvent(player, "modDownloader:reenableModPanel", player)
            outputCustomMessage(player, getSetting("msg_too_fast"), "error")
            return
        end
    end
    lastSpamLoadMods[player] = getTickCount()

    -- Send the player only mods they are allowed to use
    local allowedMods = getAllowedMods(player)

    triggerClientEvent(player, "modDownloader:receiveMods", player, allowedMods, loadedSettings)
end
addEventHandler("modDownloader:requestRefreshMods", root, sendModsToPlayer)

local function requestModPanel(player)
    
    if not canPlayerOpenGUI(player) then
        outputCustomMessage(player, getSetting("msg_no_access"), "error")
        return
    end

    triggerClientEvent(player, "modDownloader:openModPanel", player)
end

local function initialize()

    loadResSettings()

    local result, reason = readModsFromMeta()
    if not result then
        outputServerLog("Error while reading mods from meta.xml:")
        outputServerLog("> "..reason)
        stopResource(resource)
        return
    end

    if result == "RESTART" then
        outputServerLog("Mods were added to meta.xml, restarting resource...")
        restartResource(resource)
        return
    end

    currentlyLoading = nil

    for i=1, #clientsWaiting do
        local player = clientsWaiting[i]
        if player and isElement(player) then
            sendModsToPlayer(player)
        end
    end
    clientsWaiting = nil
    
    addEventHandler("modDownloader:requestOpenModPanel", root, function(player)
        if not (isElement(player) and getElementType(player)=="player") then return end
        requestModPanel(player)
    end)
end

addEventHandler("onResourceStart", resourceRoot, function()

    -- MTA does meta.xml checksum after resource start, so we need to delay updating it so it doesn't check the already updated meta.xml
    setTimer(initialize, 1000, 1)
end)

addEventHandler("onPlayerResourceStart", root, function(res)
    if res == resource then
        if currentlyLoading then
            clientsWaiting[#clientsWaiting+1] = source
        else
            sendModsToPlayer(source)
        end
    end
end)

addEventHandler("modDownloader:onDownloadManyFails", resourceRoot, function(kick, times, modId, modName, path)
    if not client then return end

	outputServerLog(getPlayerName(client).." failed to download '"..path.."' (#"..modId.." - "..modName..") "..times.." times"..(kick and ", kicking." or "."))

    if kick == true then
	    kickPlayer(client, "System", "Failed to download '"..path.."' (#"..modId.." - "..modName..") "..times.." times.")
    end
end)
