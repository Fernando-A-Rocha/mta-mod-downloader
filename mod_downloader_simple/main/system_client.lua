--[[
	Author: https://github.com/Fernando-A-Rocha

	system_client.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

addEvent("modDownloaderSimple:onModelReplaced", true)
addEvent("modDownloaderSimple:onModelRestored", true)
addEvent("modDownloaderSimple:receiveLoadedMods", true)

local receivedMods = {}

local modElementCache = {}
local ncDecryptFunction = nil

local fileDLQueue = {}
local fileDLTries = {}
local currDownloading = nil
local busyDownloading = false

function getReceivedMods()
	return receivedMods
end

local function outputDebugMsg(msg, theType)
    if (not DEBUG_ENABLED) then return end
	msg = MESSAGES_PREFIX..msg
    local r,g,b = 255, 255, 255
    if theType == "ERROR" then
        r,g,b = 255, 25, 25
    elseif theType == "WARNING" then
        r,g,b = 255, 255, 25
    end
    outputDebugString(msg, 4, r,g,b)
end

local function applyModInOrder(id, files, theType, lastType)
	local path = files[theType].path
	local encrypted = files[theType].encrypted

    local function applyTXD(path_)
        local txdElement = engineLoadTXD(path_)
        if txdElement then
            if engineImportTXD(txdElement, id) then
                if not modElementCache[id] then
                    modElementCache[id] = {}
                end
                modElementCache[id].txd = txdElement
            end
        end
    end

    local function applyDFF(path_)
        local dffElement = engineLoadDFF(path_)
        if dffElement then
            if engineReplaceModel(dffElement, id) then
                if not modElementCache[id] then
                    modElementCache[id] = {}
                end
                modElementCache[id].dff = dffElement
            end
        end
    end

    local function applyCOL(path_)
        local colElement = engineLoadCOL(path_)
        if colElement then
            if engineReplaceCOL(colElement, id) then
                if not modElementCache[id] then
                    modElementCache[id] = {}
                end
                modElementCache[id].col = colElement
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
            if files["dff"] then
                applyModInOrder(id, files, "dff", lastType)
            elseif files["col"] then
                applyModInOrder(id, files, "col", lastType)
            end
        elseif theType == "dff" then
            if files["col"] then
                applyModInOrder(id, files, "col", lastType)
            end
        end

        if theType == lastType then
            triggerEvent("modDownloaderSimple:onModelReplaced", localPlayer, id)
        end
    end

    if (encrypted) then
        if not NANDO_CRYPT_ENABLED then
            outputDebugMsg("NandoCrypt is not enabled, but you are trying to decrypt a file", "ERROR")
        else
            if not ncDecryptFunction(path,
                function(data)
                    applyOneMod(data)
                end
            ) then
                outputDebugMsg("NandoCrypt - Failed to decrypt file: "..tostring(path), "ERROR")
            end
        end
    else
        applyOneMod(path)
    end
end

local function loadOneMod(id, files)

    engineRestoreModel(id)

    local lastType = nil
    if files.txd then
        lastType = "txd"
    end
    if files.dff then
        lastType = "dff"
    end
    if files.col then
        lastType= "col"
    end

    if files.txd then
        applyModInOrder(id, files, "txd", lastType)
    elseif files.dff then
        applyModInOrder(id, files, "dff", lastType)
    elseif files.col then
        applyModInOrder(id, files, "col", lastType)
    end
end

local function restoreReplacedModel(id)
    
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

    triggerEvent("modDownloaderSimple:onModelRestored", localPlayer, id)
end

local function setModFileReady(id, file)
	if not receivedMods[id] then
		return
	end
	for id2, files in pairs(receivedMods) do
		if id == id2 then
			for theType, file2 in pairs(files) do
				if file.path == file2.path then
					receivedMods[id][theType].ready = true
					break
				end
			end
		end
	end

	-- Check all files ready
	local allReady = true
	local files = nil
	for id2, files2 in pairs(receivedMods) do
		if id == id2 then
			for theType, file2 in pairs(files2) do
				if not file2.ready then
					allReady = false
				end
			end
			files = files2
		end
	end

	if allReady then
		loadOneMod(id, files)
	end
end

local function onDownloadFailed(id, path)

	if not fileDLTries[path] then
		fileDLTries[path] = 0
	end
	fileDLTries[path] = fileDLTries[path] + 1

    local maxTries = DOWNLOAD_MAX_TRIES
	if fileDLTries[path] == maxTries then
		if KICK_ON_DOWNLOAD_FAILS then
			triggerServerEvent("modDownloaderSimple:onDownloadManyFails", resourceRoot, true, fileDLTries[path], id, path)
			return "KICKED"
		end
    else
        triggerServerEvent("modDownloaderSimple:onDownloadManyFails", resourceRoot, false, fileDLTries[path], id, path)
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
	end
    
	local id, file = first[1], first[2]

	currDownloading = {id, file}

	table.remove(fileDLQueue, 1)

	local path = file.path
	if not downloadFile(path) then
		outputDebugMsg("Error trying to download file: "..tostring(path), "ERROR")

        local result = onDownloadFailed(id, path)
		if result == "KICKED" then
			return
        elseif result < DOWNLOAD_MAX_TRIES then

            -- place back in queue
            table.insert(fileDLQueue, 1, {id, file})
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
	local id, file = currDownloading[1], currDownloading[2]
	local path = file.path

	currDownloading = nil

	local waitDelay = 50
	if not success then

		outputDebugMsg("Failed to download mod file: "..tostring(fileName), "ERROR")
		
        local result = onDownloadFailed(id, path)
		if result == "KICKED" then
			return
        elseif result < DOWNLOAD_MAX_TRIES then

            -- place back in queue
            table.insert(fileDLQueue, 1, {id, file})
            waitDelay = 1000
        end
	else
		setModFileReady(id, file)
	end

	if #fileDLQueue >= 1 then
		setTimer(downloadFirstInQueue, waitDelay, 1)
	elseif busyDownloading then
		busyDownloading = false
	end
end
addEventHandler("onClientFileDownloadComplete", root, handleDownloadFinish)

function downloadModFile(id, file)

    for i=1, #fileDLQueue do
        local v = fileDLQueue[i]
		if v and v[1] == id then
			if v[2].path == file.path then
				return
			end
		end
	end

	fileDLQueue[#fileDLQueue+1] = {id, file}

	if busyDownloading then
		return
	end

	if #fileDLQueue >= 1 then
		downloadFirstInQueue()
	end
end

local function loadMods()
	for id, files in pairs(receivedMods) do
		local toDL = {}
		for theType, file in pairs(files) do
			if file.download == false then
				toDL[#toDL+1] = file
			end
		end
		local ready = true
		for j=1, #toDL do
			local DL = toDL[j]
			if DL then
				downloadModFile(id, DL)
				ready = false
			end
		end
		if ready then
			loadOneMod(id, files)
		end
	end
end

local function receiveLoadedMods(modList)

	-- Check NandoCrypt
    if NANDO_CRYPT_ENABLED then
        local ncDecryptFunctionName = NANDO_CRYPT_FUNCTION
        local ncDecrypt = _G[ncDecryptFunctionName]
        if type(ncDecrypt) ~= "function" then
            return outputDebugMsg("NandoCrypt: Decrypt function '"..ncDecryptFunctionName.."' not loaded", "ERROR")
        end
        ncDecryptFunction = ncDecrypt
    end

    for id, files in pairs(receivedMods) do
        restoreReplacedModel(id)
    end

	receivedMods = modList

	loadMods()
end
addEventHandler("modDownloaderSimple:receiveLoadedMods", localPlayer, receiveLoadedMods)

addEventHandler("modDownloaderSimple:onModelReplaced", localPlayer, function(id)
    outputDebugMsg("Model ID "..id.." successfully replaced")
end)
addEventHandler("modDownloaderSimple:onModelRestored", localPlayer, function(id)
    outputDebugMsg("Model ID "..id.." has been restored")
end)