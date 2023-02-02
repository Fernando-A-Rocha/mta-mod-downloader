--[[
	Author: https://github.com/Fernando-A-Rocha

	system_server.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

local currentlyLoading = true
local clientsWaiting = {}
local loadedMods = {}

local startedAt = nil
local finishedScanning = nil
local insertFiles = nil
local deleteFiles = nil

function getLoadedMods()
	return loadedMods
end

local function outputSystemMsg(msg)
    outputServerLog("[S-MDL] "..tostring(msg))
end

local function stopStorage()
    local sres = getResourceFromName(STORAGE_RES_NAME)
    if sres and getResourceState(sres)=="running" then
        stopResource(sres)
    end
end

local function sendModsToPlayer(player)
	triggerClientEvent(player, "modDownloaderSimple:receiveLoadedMods", player, loadedMods)
end

addEventHandler("onPlayerResourceStart", root, function(res)
    if res == resource then
        if currentlyLoading then
            clientsWaiting[#clientsWaiting+1] = source
        else
            sendModsToPlayer(source)
        end
    end
end)

local function continueInit()
	outputSystemMsg("Init finished, sending mods to clients")

    addEventHandler("onResourceStop", resourceRoot, stopStorage)

    currentlyLoading = nil

	for i=1, #clientsWaiting do
        local player = clientsWaiting[i]
        if player and isElement(player) then
            sendModsToPlayer(player)
        end
    end
    clientsWaiting = nil
end

local function endScan()
	
	local cf = 0
	for k, _ in pairs(loadedMods) do
		cf = cf + 1
	end

	outputSystemMsg("Scanning finished after "..(getTickCount()-startedAt).." ms, found "..cf.." models to replace")

	local sres = getResourceFromName(STORAGE_RES_NAME)
	if not sres then
		outputSystemMsg("Unexpected: File storage resource '"..STORAGE_RES_NAME.."' not found.")
		return
	end
    local sresPath = ":"..STORAGE_RES_NAME.."/"
	local sresMeta = sresPath.."meta.xml"

    local ic = 0
    local dc = 0
    for k, _ in pairs(insertFiles) do
        ic = ic + 1
    end
    for k, _ in pairs(deleteFiles) do
        dc = dc + 1
    end
    if ic > 0 or dc > 0 then

        sf = xmlLoadFile(sresMeta)
        if not sf then
			return outputSystemMsg("Failed to load file "..sresMeta)
        end

        for src, _ in pairs(insertFiles) do
            local node = xmlCreateChild(sf, "file")
            xmlNodeSetAttribute(node, "src", src)
            xmlNodeSetAttribute(node, "download", tostring(DEFAULT_FILE_AUTO_DOWNLOAD))
            xmlNodeSetAttribute(node, "added_by", getResourceName(resource))
        end

        schildren = xmlNodeGetChildren(sf)
        if not schildren then
            xmlUnloadFile(sf)
			return outputSystemMsg("Failed to get children of "..sresMeta)
        end

        for i=1, #schildren do
            local schild = schildren[i]
            if schild then
                local schildName = xmlNodeGetName(schild)
                if schildName == "file" then
                    local schildSrc = xmlNodeGetAttribute(schild, "src")
                    if schildSrc then
                        if deleteFiles[schildSrc] then
                            xmlDestroyNode(schild)
                        end
                    end
                end
            end
        end

        if not xmlSaveFile(sf) then
            xmlUnloadFile(sf)
			return outputSystemMsg("Failed to save file "..sresMeta)
        end
        xmlUnloadFile(sf)

        local sresState = getResourceState(sres)
        if not (sresState == "running" or sresState == "loaded") then
			return outputSystemMsg("Resource '"..sresPath.."' has state '"..sresState.."'")
        end
        if sresState == "running" then
            outputSystemMsg("File "..sresMeta.." has changed, restarting resource...")
            if not restartResource(sres) then
				return outputSystemMsg("Could not restart resource '"..sresPath.."'")
            end
        elseif sresState == "loaded" then
            outputSystemMsg("File "..sresMeta.." has changed, starting resource...")
            if not startResource(sres) then
				return outputSystemMsg("Could not start resource '"..sresPath.."'")
            end
        end
        continueInit()
        return
    end

	if not startResource(sres) then
		return outputSystemMsg("Could not start resource '"..sresPath.."'")
    end

	finishedScanning = nil
	insertFiles = nil
	deleteFiles = nil
	startedAt = nil

	continueInit()
end

local function finishScanning(modType)
	finishedScanning[modType] = true
	outputSystemMsg("Finished scanning for "..modType)

	for theType, _ in pairs({["skins"]=true, ["vehicles"]=true, ["objects"]=true}) do
		if SCAN_MODS[theType] == true and not finishedScanning[theType] then
			return
		end
	end
	endScan()
end

local function scanModFiles(initial)

	startedAt = getTickCount()
	outputSystemMsg("Started scanning for mod files in "..STORAGE_RES_NAME.." (this may take a while)")

	local sres = getResourceFromName(STORAGE_RES_NAME)
	if not sres then
		local thisFolder = getResourceOrganizationalPath(resource)
		if thisFolder == "" then
			thisFolder = nil
		end
		local newRes = createResource(STORAGE_RES_NAME, thisFolder)
		if not newRes then
			outputSystemMessage("Failed to create resource '"..STORAGE_RES_NAME.."'.")
			return
		end
		sres = newRes
	end
	
	if not sres then
		outputSystemMsg("Unexpected: File storage resource '"..STORAGE_RES_NAME.."' not found.")
		return
	end
    local sresPath = ":"..STORAGE_RES_NAME.."/"
	local sresMeta = sresPath.."meta.xml"

    local sf = xmlLoadFile(sresMeta)
    if not sf then
		return outputSystemMsg("Failed to load file "..sresMeta)
    end

    local schildren = xmlNodeGetChildren(sf)
    if not schildren then
        xmlUnloadFile(sf)
        return false, "Could not get children of "..sresMeta
    end

    local files = {}

    for i=1, #schildren do
        local v = schildren[i]
        if v then
            if xmlNodeGetName(v) == "file" then
                local src = xmlNodeGetAttribute(v, "src")
                if src then
                    if files[src] then
                        outputSystemMsg("Deleting duplicate file entry in "..sresMeta..": "..src)
                        xmlDestroyNode(v)
                    else
                        local download = xmlNodeGetAttribute(v, "download")
                        if download == "false" then
                            download = false
                        else
                            download = true
                        end
						if string.sub(src, 1, string.len(MODS_PATH)) == MODS_PATH then
							local id = tonumber(string.sub(src, string.len(MODS_PATH)+1, string.len(src)-4))
							if id then
								files[src] = {download=download}
							else
								id = tonumber(string.sub(src, string.len(MODS_PATH)+1, string.len(src)-4-string.len(NANDO_CRYPT_EXTENSION)))
								if id then
									files[src] = {download=download}
								end
							end
						end
                    end
                end
            end
        end
    end

	xmlUnloadFile(sf)
	
	loadedMods = {}
	finishedScanning = {}

	insertFiles = {}
	deleteFiles = {}
	

	local function findModFile(id, theType)
		local path = MODS_PATH..id.."."..theType
		local pathNc = path..NANDO_CRYPT_EXTENSION
		local exists = fileExists(sresPath..path)
		local encrypted = false
		if not exists and (NANDO_CRYPT_ENABLED) then
			path = pathNc
			exists = fileExists(sresPath..path)
			encrypted = true
		end
		if (not exists) and (files[path]) then
			deleteFiles[path] = true
		elseif (exists) and (not files[path]) then
			insertFiles[path] = true
			if not loadedMods[id] then
				loadedMods[id] = {}
			end
			loadedMods[id][theType] = {path=sresPath..path, encrypted=encrypted, download=DEFAULT_FILE_AUTO_DOWNLOAD}
		elseif (exists) and (files[path]) then
			if not loadedMods[id] then
				loadedMods[id] = {}
			end
			loadedMods[id][theType] = {path=sresPath..path, encrypted=encrypted, download=files[path].download}
		end
	end

	if SCAN_MODS["skins"] == true then
		Async:iterate(0, 312, function(id)
			-- exclude unused
			if not (id == 3 or id == 4 or id == 5 or id == 6 or id == 8 or id == 42 or id == 65 or id == 76
			or id == 86 or id == 119 or id == 149 or id == 208 or id == 273 or id == 289) then
				for theType, _ in pairs({["dff"] = true, ["txd"] = true}) do
					findModFile(id, theType)
				end
				if id == 312 then
					finishScanning("skins")
				end
			end
		end)
	end

	if SCAN_MODS["vehicles"] == true then
		Async:iterate(400, 611, function(id)
			for theType, _ in pairs({["dff"] = true, ["txd"] = true}) do
				findModFile(id, theType)
			end
			if id == 611 then
				finishScanning("vehicles")
			end
		end)
	end

	if SCAN_MODS["objects"] == true then
		Async:iterate(321, 18630, function(id)
			-- exclude unused
			if not ((id >= 18631 and id <= 19999) or (id >= 11682 and id <= 12799) or (id >= 15065 and id <= 15999)) then
				for theType, _ in pairs({["dff"] = true, ["txd"] = true, ["col"] = true}) do
					findModFile(id, theType)
				end
				if id == 18630 then
					finishScanning("objects")
				end
			end
		end)
	end
end

local function init()

	Async:setPriority(ASYNC_PRIORITY)

    setTimer(scanModFiles, 1000, 1, true)
end
addEventHandler("onResourceStart", resourceRoot, init)

addEventHandler("modDownloaderSimple:onDownloadManyFails", resourceRoot, function(kick, times, modId, path)
    if not client then return end

	outputSystemMessage(getPlayerName(client).." failed to download '"..path.."' (#"..modId..") "..times.." times"..(kick and ", kicking." or "."))

    if kick == true then
	    kickPlayer(client, "System", "Failed to download '"..path.."' (#"..modId..") "..times.." times.")
    end
end)
