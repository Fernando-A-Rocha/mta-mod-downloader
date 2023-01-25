--[[
	Author: https://github.com/Fernando-A-Rocha

	system_client.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

addEvent("modDownloader:receiveMods", true)

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

function getReceivedMods()
    return receivedMods
end

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

function setModStatusSetting(modName, activated)
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

local function unloadMod(id)
    
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
end

function toggleModFromGUI(modId, modName, activate, showMessage)

    -- Disable other mod replacing this id
    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.id == modId and mod.name ~= modName and mod.activated == true then
                unloadMod(mod.id)

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

                        for path, _ in pairs(mod.pendingDownloads) do
                            downloadModFile(modId, mod.name, path, true)
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

                    unloadMod(id)

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

function isModActivated(modId)
    if receivedMods then
        for i=1, #receivedMods do
            local mod = receivedMods[i]
            if mod then
                if mod.id == modId then
                    return mod.activated
                end
            end
        end
    end
    return false
end

function setModFileReady(modId, modName, path, activateMod)
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

	if (not (getSetting("kick_when_too_many_dl_fails"))) then return end

	if not fileDLTries[path] then
		fileDLTries[path] = 0
	end
	fileDLTries[path] = fileDLTries[path] + 1

    local maxTries = getSetting("max_failed_downloads")
	if fileDLTries[path] == maxTries then
		triggerServerEvent("modDownloader:onDownloadManyFails", resourceRoot, true, fileDLTries[path], modId, modName, path)
		return "KICKED"
    else
        triggerServerEvent("modDownloader:onDownloadManyFails", resourceRoot, false, fileDLTries[path], modId, modName, path)
    end
	return fileDLTries[path]
end

local function downloadFirstInQueue()
	local first = fileDLQueue[1]
	if not first then
		outputDebugString("Error getting first in DL queue", 1)
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
		outputDebugString("Error trying to download file: "..tostring(path), 1)

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

function handleDownloadFinish(fileName, success)
	if not currDownloading then return end
	local modId, modName, path, activateWhenDone = currDownloading[1], currDownloading[2], currDownloading[3], currDownloading[4]

	currDownloading = nil

	local waitDelay = 50
	if not success then

		outputDebugString("Failed to download mod file: "..tostring(fileName), 1)
		
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
addEventHandler("onClientFileDownloadComplete", resourceRoot, handleDownloadFinish)

function downloadModFile(modId, modName, path, activateWhenDone)

    local i=1, #fileDLQueue do
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

function applyModInOrder(modId, modName, path, theType, decryptFirst)

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

    if (decryptFirst) then
        local ncEnabled = getSetting("enable_nandocrypt")
        if not ncEnabled then
            outputDebugString("NandoCrypt is not enabled, but you are trying to decrypt a file", 1)
        else
            if not ncDecryptFunction(path,
                function(data)
                    if theType == "txd" then
                        applyTXD(data)
                    elseif theType == "dff" then
                        applyDFF(data)
                    elseif theType == "col" then
                        applyCOL(data)
                    end

                    if theType == "txd" then
                        if mod.dff then
                            applyModInOrder(modId, modName, mod.dff.path, "dff", decryptFirst)
                        elseif mod.col then
                            applyModInOrder(modId, modName, mod.col.path, "col", decryptFirst)
                        end
                    elseif theType == "dff" then
                        if mod.col then
                            applyModInOrder(modId, modName, mod.col.path, "col", decryptFirst)
                        end
                    end
                end
            ) then
                outputDebugString("NC - Failed to decrypt file: "..tostring(path), 1)
            end
        end
    else
        
        if theType == "txd" then
            applyTXD(path)
        elseif theType == "dff" then
            applyDFF(path)
        elseif theType == "col" then
            applyCOL(path)
        end

        if theType == "txd" then
            if mod.dff then
                applyModInOrder(modId, modName, mod.dff.path, "dff", decryptFirst)
            elseif mod.col then
                applyModInOrder(modId, modName, mod.col.path, "col", decryptFirst)
            end
        elseif theType == "dff" then
            if mod.col then
                applyModInOrder(modId, modName, mod.col.path, "col", decryptFirst)
            end
        end
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

    if txd then
        txd = txd.path
    end
    if dff then
        dff = dff.path
    end
    if col then
        col = col.path
    end

    if txd then
        applyModInOrder(modId, modName, txd, "txd", encrypted)
    elseif dff then
        applyModInOrder(modId, modName, dff, "dff", encrypted)
    elseif col then
        applyModInOrder(modId, modName, col, "col", encrypted)
    end
end

local function loadMods()

    local readyMods = {}
    local toDownload = {}
    local activatedIDs = {}

    for i=1, #receivedMods do
        local mod = receivedMods[i]
        if mod then
            if mod.activated == true then
                if activatedIDs[mod.id] then
                    outputDebugString("Mod replacing ID "..tostring(mod.id).." is already activated, deactivating '"..mod.name.."'", 2)
                    receivedMods[i].activated = false
                else
                    activatedIDs[mod.id] = true
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

function handleReceiveMods(mods, settings)

    receivedSettings = settings

    -- Check NandoCrypt
    if getSetting("enable_nandocrypt") then
        local ncDecryptFunctionName = getSetting("nc_decrypt_function")
        local ncDecrypt = _G[ncDecryptFunctionName]
        if type(ncDecrypt) ~= "function" then
            return outputDebugString("FATAL - Decrypt function '"..ncDecryptFunctionName.."' not loaded", 0, 255,0,0)
        end
        ncDecryptFunction = ncDecrypt
    end

    if type(canEnableMod) ~= "function" then
        outputDebugString("Function 'canEnableMod' is missing, assuming allowed permission", 0, 255,255,0)
        canEnableMod = function() return true end
    end

    if type(canDisableMod) ~= "function" then
        outputDebugString("Function 'canDisableMod' is missing, assuming allowed permission", 0, 255,255,0)
        canDisableMod = function() return true end
    end

    if type(receivedMods) == "table" then
        -- receiving updates
        for i=1, #receivedMods do
            local mod = receivedMods[i]
            if mod then
                unloadMod(mod.id)
            end
        end
    end

    if boundKey then
        unbindKey(boundKey, "down", openModPanel)
        boundKey = nil
    end
    local bindPanel = getSetting("bind_panel")
    if bindPanel ~= "" then
        bindKey(bindPanel, "down", openModPanel)
        boundKey = bindPanel
    end
    if cmdHandler then
        removeCommandHandler(cmdHandler, openModPanel)
        cmdHandler = nil
    end
    local cmdName = getSetting("cmd_panel")
    if cmdName ~= "" then
        addCommandHandler(cmdName, openModPanel, false)
        cmdHandler = cmdName
    end

    receivedMods = mods

    loadModStatusSettings()

    loadMods()

    populateModsGUI()
end
addEventHandler("modDownloader:receiveMods", localPlayer, handleReceiveMods)
