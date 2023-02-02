--[[
	Author: https://github.com/Fernando-A-Rocha

	system_client.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

addEvent("modDownloader:receiveMods", true)
addEvent("modDownloader:forceMods", true)
addEvent("modDownloader:onModelReplaced", true)
addEvent("modDownloader:onModelRestored", true)

local MOD_SETTINGS_FILENAME = "@mod_settings.xml"

local receivedSettings = nil
local receivedMods = nil

local fileDLQueue = {}
local fileDLTries = {}
local currDownloading = nil
local busyDownloading = false

local cmdHandler = nil
local boundKey = nil

local modElementCache = {}

local savedModStatuses = {}

local ncDecryptFunction = nil

function getDownloadingInfo()
    return {
        fileDLQueue=fileDLQueue,
        fileDLTries=fileDLTries,
        currDownloading=currDownloading,
        busyDownloading=busyDownloading
    }
end

-- [Exported]
function getReceivedMods()
    return receivedMods
end

-- [Exported]
function getSetting(name)
    if not receivedSettings then
        return nil
    end
    return receivedSettings[name]
end

function outputCustomMessage(msg, msgType)
    local prefix = getSetting("msg_prefix")
    local color = getSetting("color_"..msgType)
    local color_msg = getSetting("color_msg")

    if prefix and color and color_msg then
        msg = color..prefix..color_msg..msg
    end

    outputChatBox(msg, 255, 255, 255, true)
end

local function loadModStatusSettings()
    savedModStatuses = {}

    local f
    if not fileExists(MOD_SETTINGS_FILENAME) then
        f = xmlCreateFile(MOD_SETTINGS_FILENAME, "mod_settings")
    else
        f = xmlLoadFile(MOD_SETTINGS_FILENAME)
    end
    if not f then
        return -- Unexpected error
    end

    local children = xmlNodeGetChildren(f) or {}
    for i=1, #children do
        local mod = children[i]
        if mod then
            local name = xmlNodeGetAttribute(mod, "name")
            if not name then
                break -- Unexpected error
            end
            local activated = xmlNodeGetAttribute(mod, "activated")
            if activated == "true" then
                activated = true
            else
                activated = false
            end
            savedModStatuses[name] = activated
        end
    end

    xmlSaveFile(f)
    xmlUnloadFile(f)

    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            local name = mod.name
            if savedModStatuses[name] ~= nil then
                receivedMods[i].activated = savedModStatuses[name]
            else
                receivedMods[i].activated = mod.activatedByDefault
            end
        end
    end
end

local function setModStatusSetting(modName, activated)
    savedModStatuses[modName] = activated

    local f
    if not fileExists(MOD_SETTINGS_FILENAME) then
        f = xmlCreateFile(MOD_SETTINGS_FILENAME, "mod_settings")
    else
        f = xmlLoadFile(MOD_SETTINGS_FILENAME)
    end
    if not f then
        return -- Unexpected error
    end

    local children = xmlNodeGetChildren(f) or {}
    for i=1, #children do
        local mod = children[i]
        if mod then
            local name = xmlNodeGetAttribute(mod, "name")
            if not name then
                break -- Unexpected error
            end
            if name == modName then
                xmlNodeSetAttribute(mod, "activated", tostring(activated))
                xmlSaveFile(f)
                xmlUnloadFile(f)
                return
            end
        end
    end

    local mod = xmlCreateChild(f, "mod")
    xmlNodeSetAttribute(mod, "name", tostring(modName))
    xmlNodeSetAttribute(mod, "activated", tostring(activated))
    xmlSaveFile(f)
    xmlUnloadFile(f)
end

local function restoreReplacedModel(id, modName)
    
    engineRestoreModel(id)

    if modElementCache[id] then
        if isElement(modElementCache[id].txd) then
            destroyElement(modElementCache[id].txd)
        end
        if isElement(modElementCache[id].dff) then
            destroyElement(modElementCache[id].dff)
        end
        if isElement(modElementCache[id].col) then
            destroyElement(modElementCache[id].col)
        end

        modElementCache[id] = nil
    end

    triggerEvent("modDownloader:onModelRestored", localPlayer, id, modName)
end

function toggleModFromGUI(modId, modName, activate, showMessage)

    -- Disable other mod replacing this id
    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.id == modId and mod.name ~= modName and mod.activated == true then
                restoreReplacedModel(mod.id, mod.name)

                receivedMods[i].activated = false
                setModStatusSetting(mod.name, false)
                break
            end
        end
    end

    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            local id = mod.id
            if id == modId and mod.name == modName then
                if (activate == true) then

                    if mod.pendingDownloads then
                        
                        if (showMessage == true) then
                            outputCustomMessage(getSetting("msg_mod_download")..(mod.name), "warning")
                        end

                        local toDL = {}
                        for path, _ in pairs(mod.pendingDownloads) do
                            toDL[#toDL+1] = path
                        end
                        for j=1, #toDL do
                            local DL = toDL[j]
                            if DL then
                                downloadModFile(modId, mod.name, DL, true)
                            end
                        end
                    else
                        applyReadyMod(modId, modName)

                        receivedMods[i].activated = true
                        setModStatusSetting(mod.name, true)

                        if (showMessage == true) then
                            outputCustomMessage(getSetting("msg_mod_activated")..(mod.name), "success")
                        end
                
                        populateModsGUI()
                    end
                else

                    restoreReplacedModel(id, modName)

                    receivedMods[i].activated = false
                    setModStatusSetting(mod.name, false)

                    if (showMessage == true) then
                        outputCustomMessage(getSetting("msg_mod_deactivated")..(mod.name), "info")
                    end

                    populateModsGUI()
                end
                break
            end
        end
    end
end

-- [Exported]
function isModelReplaced(id)
    if receivedMods then
        for i=1, #receivedMods do
            local mod = receivedMods[i]
            if mod then
                if mod.id == id then
                    return mod.activated
                end
            end
        end
    end
    return false
end

local function setModFileReady(modId, modName, path, activateMod)
    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.id == modId and mod.name == modName then
                receivedMods[i].pendingDownloads[path] = false
                break
            end
        end
    end

    -- check if all mod files are ready
    local allReady = true
    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.id == modId and mod.name == modName then
                for path_, pending in pairs(mod.pendingDownloads) do
                    if pending then
                        allReady = false
                        break
                    end
                end
                break
            end
        end
    end

    if allReady then

        for i=1, #receivedMods do
            local mod = receivedMods[i]
            if mod then
                if mod.id == modId and mod.name == modName then
                    receivedMods[i].pendingDownloads = nil

                    if (activateMod == true) then
                        receivedMods[i].activated = true
                        setModStatusSetting(mod.name, true)
                    end
                    break
                end
            end
        end

        populateModsGUI()

        applyReadyMod(modId, modName)
    end
end

local function onDownloadFailed(modId, modName, path)

	if not fileDLTries[path] then
		fileDLTries[path] = 0
	end
	fileDLTries[path] = fileDLTries[path] + 1

    local maxTries = getSetting("max_failed_downloads")
	if fileDLTries[path] == maxTries then
        if getSetting("kick_when_too_many_dl_fails") then
            triggerServerEvent("modDownloader:onDownloadManyFails", resourceRoot, true, fileDLTries[path], modId, modName, path)
            return "KICKED"
        end
    else
        triggerServerEvent("modDownloader:onDownloadManyFails", resourceRoot, false, fileDLTries[path], modId, modName, path)
    end
	return fileDLTries[path]
end

local function downloadFirstInQueue()
	local first = fileDLQueue[1]
	if not first then
		return
	end

	if (not busyDownloading) then
		busyDownloading = true
        if (getSetting("show_download_dialog")) then
		    addEventHandler("onClientRender", root, drawDownloadingDialog)
        end
	end
    
	local modId, modName, path, activateWhenDone = first[1], first[2], first[3], first[4]

	currDownloading = {modId, modName, path, activateWhenDone}

	table.remove(fileDLQueue, 1)

	if not downloadFile(path) then
		outputDebugString("[MDL] Error trying to download file: "..tostring(path), 1)

        local result = onDownloadFailed(modId, modName, path)
		if result == "KICKED" then
			return
        elseif result < getSetting("max_failed_downloads") then

            -- place back in queue
            table.insert(fileDLQueue, 1, {modId, modName, path, activateWhenDone})
            -- retry after a bit:
            setTimer(function()

                currDownloading = nil

                downloadFirstInQueue() 
            end, 1000, 1)
        end
	end
end

local function handleDownloadFinish(fileName, success, requestResource)
    if requestResource ~= resource then return end
	if not currDownloading then return end
	local modId, modName, path, activateWhenDone = currDownloading[1], currDownloading[2], currDownloading[3], currDownloading[4]

	currDownloading = nil

	local waitDelay = 50
	if not success then

		outputDebugString("[MDL] Failed to download mod file: "..tostring(fileName), 1)
		
        local result = onDownloadFailed(modId, modName, path)
		if result == "KICKED" then
			return
        elseif result < getSetting("max_failed_downloads") then

            -- place back in queue
            table.insert(fileDLQueue, 1, {modId, modName, path, activateWhenDone})
            waitDelay = 1000
        end
	else
		setModFileReady(modId, modName, path, activateWhenDone)
	end

	if #fileDLQueue >= 1 then
		setTimer(downloadFirstInQueue, waitDelay, 1)
	elseif busyDownloading then
        if (getSetting("show_download_dialog")) then
		    removeEventHandler("onClientRender", root, drawDownloadingDialog)
        end
		busyDownloading = false
	end
end
addEventHandler("onClientFileDownloadComplete", root, handleDownloadFinish)

function downloadModFile(modId, modName, path, activateWhenDone)

    for i=1, #fileDLQueue do
        local v = fileDLQueue[i]
		if v and v[1] == modId and v[2] == modName and v[3] == path then
			return
		end
	end

	fileDLQueue[#fileDLQueue+1] = {modId, modName, path, activateWhenDone}

	if busyDownloading then
		return
	end

	if #fileDLQueue >= 1 then
		downloadFirstInQueue()
	end
end

local function applyModInOrder(modId, modName, path, theType, lastType, decryptFirst)

    local mod
    for i=1, #receivedMods do
        local mod_ = receivedMods[i]
        if mod_ then
            if mod_.id == modId and mod_.name == modName then
                mod = mod_
                break
            end
        end
    end

    local function applyTXD(path_)
        local txdElement = engineLoadTXD(path_)
        if txdElement then
            if engineImportTXD(txdElement, modId) then
                if not modElementCache[modId] then
                    modElementCache[modId] = {}
                end
                modElementCache[modId].txd = txdElement
            end
        end
    end

    local function applyDFF(path_)
        local dffElement = engineLoadDFF(path_)
        if dffElement then
            if engineReplaceModel(dffElement, modId) then
                if not modElementCache[modId] then
                    modElementCache[modId] = {}
                end
                modElementCache[modId].dff = dffElement
            end
        end
    end

    local function applyCOL(path_)
        local colElement = engineLoadCOL(path_)
        if colElement then
            if engineReplaceCOL(colElement, modId) then
                if not modElementCache[modId] then
                    modElementCache[modId] = {}
                end
                modElementCache[modId].col = colElement
            end
        end
    end

    local function applyOneMod(pathOrData)
        if theType == "txd" then
            applyTXD(pathOrData)
        elseif theType == "dff" then
            applyDFF(pathOrData)
        elseif theType == "col" then
            applyCOL(pathOrData)
        end

        if theType == "txd" then
            if mod.dff then
                applyModInOrder(modId, modName, mod.dff.path, "dff", lastType, decryptFirst)
            elseif mod.col then
                applyModInOrder(modId, modName, mod.col.path, "col", lastType, decryptFirst)
            end
        elseif theType == "dff" then
            if mod.col then
                applyModInOrder(modId, modName, mod.col.path, "col", lastType, decryptFirst)
            end
        end

        if theType == lastType then

            if mod.lodDistance then
                engineSetModelLODDistance(modId, mod.lodDistance)
            end

            triggerEvent("modDownloader:onModelReplaced", localPlayer, modId, modName)
        end
    end

    if (decryptFirst) then
        local ncEnabled = getSetting("enable_nandocrypt")
        if not ncEnabled then
            outputDebugString("[MDL] NandoCrypt is not enabled, but you are trying to decrypt a file", 1)
        else
            if not ncDecryptFunction(path,
                function(data)
                    applyOneMod(data)
                end
            ) then
                outputDebugString("[MDL] NandoCrypt - Failed to decrypt file: "..tostring(path), 1)
            end
        end
    else
        applyOneMod(path)
    end
end

function applyReadyMod(modId, modName)

    local mod
    for i=1, #receivedMods do
        local mod_ = receivedMods[i]
        if mod_ then
            if mod_.id == modId and mod_.name == modName then
                mod = mod_
                break
            end
        end
    end
    local txd = mod.txd
    local dff = mod.dff
    local col = mod.col

    engineRestoreModel(modId)

    local encrypted = mod.encrypted

    local lastType = nil
    if txd then
        txd = txd.path
        lastType = "txd"
    end
    if dff then
        dff = dff.path
        lastType = "dff"
    end
    if col then
        col = col.path
        lastType= "col"
    end

    if txd then
        applyModInOrder(modId, modName, txd, "txd", lastType, encrypted)
    elseif dff then
        applyModInOrder(modId, modName, dff, "dff", lastType, encrypted)
    elseif col then
        applyModInOrder(modId, modName, col, "col", lastType, encrypted)
    end
end

local function loadMods()

    local readyMods = {}
    local toDownload = {}
    local activatedIDs = {}

    -- Prevent multiple mods with the same ID from being activated
    -- You could achieve this by manually modifying the XML file (cheating), so this is a failsafe
    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.activated == true then
                if activatedIDs[mod.id] then
                    outputDebugString("[MDL] AntiCheat: Mod replacing ID "..tostring(mod.id).." is already activated, deactivating '"..mod.name.."'", 2)
                    receivedMods[i].activated = false
                    setModStatusSetting(mod.name, false)
                else
                    activatedIDs[mod.id] = true
                end
            end
        end
    end

    -- Make all mods in the same category that has categoryGroupMods=true be all enabled or all disabled, not a mix
    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.categoryGroupMods then
                local enabled = mod.activated
                for z=1, #receivedMods do
                    local mod_ = receivedMods[z]
                    if mod_ then
                        if mod_.category == mod.category then
                            if mod_.activated ~= enabled then
                                outputDebugString("[MDL] AntiCheat: Mod '"..mod_.name.."' is in the same category as '"..mod.name.."' and has categoryGroupMods=true, setting activated to "..tostring(enabled), 2)
                                receivedMods[z].activated = enabled
                                setModStatusSetting(mod_.name, enabled)
                            end
                        end
                    end
                end
            end
        end
    end

    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            local id = mod.id

            local modFiles = {mod.dff, mod.txd, mod.col}
            local readyFiles = {}
            local countFiles = 0
            for z=1, 3 do
                local info = modFiles[z]
                if info then
                    local path = info.path
                    local download = info.download
                    if download == false then
                        if not receivedMods[i].pendingDownloads then
                            receivedMods[i].pendingDownloads = {}
                        end
                        receivedMods[i].pendingDownloads[path] = true
                        readyFiles[path] = false
                    else
                        readyFiles[path] = true
                    end
                    countFiles = countFiles + 1
                end
            end
            
            if mod.activated == true then
                local countReady = 0
                for path, ready in pairs(readyFiles) do
                    if ready then
                        countReady = countReady + 1
                    else
                        toDownload[#toDownload+1] = {id, mod.name, path}
                    end
                end
                if countReady == countFiles then
                    readyMods[id] = mod
                end
            end
        end
    end

    for i=1, #toDownload do
        local v = toDownload[i]
        if v then
            downloadModFile(v[1], v[2], v[3])
        end
    end

    for id, mod_ in pairs(readyMods) do
        applyReadyMod(id, mod_.name)
    end
end

addEventHandler("modDownloader:onModelReplaced", localPlayer, function(id, modName)
    -- outputDebugString("Model ID "..id.." successfully replaced with mod: "..modName, 3)
end)

addEventHandler("modDownloader:onModelRestored", localPlayer, function(id, modName)
    -- outputDebugString("Model ID "..id.." has been restored, it had mod: "..modName, 3)
end)

addEventHandler("modDownloader:forceMods", localPlayer,
    function(modList, options)
        
        if type(modList) ~= "table" then return end
        if (not options) then
            options = {}
        elseif (type(options) ~= "table") then
            outputDebugString("[MDL] forceMods - options is not a table, assuming empty", 2)
            options = {}
        end
        
        local mods = getReceivedMods()
        if not mods then
            outputDebugString("[MDL] forceMods - mods not received yet", 1)
            return
        end

        local force = options.force or false
        local enable = options.enable or false

        local requestList = {}
        for i=1, #modList do
            local info = modList[i]
            if info then
        
                local modId = info.id
                local modName = info.name

                local found = nil
                for j=1, #mods do
                    local mod = mods[j]
                    if mod then
                        if mod.id == modId then
                            found = mod
                            break
                        end
                    end
                end
                if not found then
                    outputDebugString("[MDL] forceMods - mod not found, ignoring: "..modId, 2)
                    modList[modId] = nil
                else
                    if not ((enable and found.activated) or ((not enable) and (not found.activated))) then
                        
                        if (force == true) then
                            toggleModFromGUI(modId, modName, enable, false)
                        else
                            requestList[#requestList+1] = {
                                id=modId,
                                replaces=found.replaces,
                                name=modName,
                                activated=found.activated,
                                pendingDownloads=found.pendingDownloads,
                            }
                        end
                    end
                end
            end
        end

        if #requestList == 0 then return end

        openRequestToggleModsDialog(requestList, options)
    end
)

local function handleReceiveMods(mods, settings)

    receivedSettings = settings

    -- Check NandoCrypt
    if getSetting("enable_nandocrypt") then
        local ncDecryptFunctionName = getSetting("nc_decrypt_function")
        local ncDecrypt = _G[ncDecryptFunctionName]
        if type(ncDecrypt) ~= "function" then
            return outputDebugString("[MDL] NandoCrypt: Decrypt function '"..ncDecryptFunctionName.."' not loaded", 1)
        end
        ncDecryptFunction = ncDecrypt
    end

    if type(canEnableMod) ~= "function" then
        outputDebugString("[MDL] Function 'canEnableMod' is missing, assuming allowed permission", 2)
        canEnableMod = function() return true end
    end

    if type(canDisableMod) ~= "function" then
        outputDebugString("[MDL] Function 'canDisableMod' is missing, assuming allowed permission", 2)
        canDisableMod = function() return true end
    end

    if type(receivedMods) == "table" then
        -- receiving updates
        for i=1, #receivedMods do
            local mod = receivedMods[i]
            if mod then
                restoreReplacedModel(mod.id, mod.name)
            end
        end
    end

    if boundKey then
        unbindKey(boundKey, "down", toggleGUIPanel)
        boundKey = nil
    end
    local bindPanel = getSetting("bind_panel")
    if bindPanel ~= "" then
        bindKey(bindPanel, "down", toggleGUIPanel)
        boundKey = bindPanel
    end
    if cmdHandler then
        removeCommandHandler(cmdHandler, toggleGUIPanel)
        cmdHandler = nil
    end
    local cmdName = getSetting("cmd_panel")
    if cmdName ~= "" then
        addCommandHandler(cmdName, toggleGUIPanel, false)
        cmdHandler = cmdName
    end

    receivedMods = mods

    loadModStatusSettings()

    loadMods()

    populateModsGUI()
end
addEventHandler("modDownloader:receiveMods", localPlayer, handleReceiveMods)
