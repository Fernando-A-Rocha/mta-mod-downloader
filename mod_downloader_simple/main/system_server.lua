--[[
	Author: https://github.com/Fernando-A-Rocha

	system_server.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

local currentlyLoading = true
local clientsWaiting = {}
local loadedMods = {}

local startedAt = nil
local files = nil
local finishedParsing = nil
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

	local elapsedMs = (getTickCount()-startedAt)
	local elapsed = elapsedMs.." ms"
	if elapsedMs > 1000 then
		elapsed = math.floor(elapsedMs/1000).." s"
	end
	outputSystemMsg("Scanning finished after "..elapsed..", found "..cf.." models to replace")

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

	outputSystemMsg("Inserting "..ic.." file nodes in "..sresMeta)
	outputSystemMsg("Deleting "..dc.." file nodes in "..sresMeta)

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

	finishedParsing = nil
	files = nil
	insertFiles = nil
	deleteFiles = nil
	startedAt = nil

	continueInit()
end

local function startScanning()

    local sresPath = ":"..STORAGE_RES_NAME.."/"
	local sresMeta = sresPath.."meta.xml"
	
	startedAt = getTickCount()
	outputSystemMsg("Started scanning for mod files in "..STORAGE_RES_NAME.." (this may take a while)")

	local function findModFile(id, theType, value)
		for i=1, #SCAN_FOLDERS do
			local folder = SCAN_FOLDERS[i]
			if folder then
				local path = folder..value.."."..theType
				local exists = fileExists(sresPath..path)
				if (not exists) and (files[path]) then
					deleteFiles[path] = true
				elseif (exists) then
					local dl = DEFAULT_FILE_AUTO_DOWNLOAD
					if (not files[path]) then
						insertFiles[path] = true
					else
						dl = files[path].download
					end
					if not loadedMods[id] then
						loadedMods[id] = {}
					end
					loadedMods[id][theType] = {path=sresPath..path, encrypted=false, download=dl}
				end
				if not (exists) and (NANDO_CRYPT_ENABLED == true) then
					path = path ..NANDO_CRYPT_EXTENSION
					exists = fileExists(sresPath..path)
					if (not exists) and (files[path]) then
						deleteFiles[path] = true
					elseif (exists) then
						local dl = DEFAULT_FILE_AUTO_DOWNLOAD
						if (not files[path]) then
							insertFiles[path] = true
						else
							dl = files[path].download
						end
						if not loadedMods[id] then
							loadedMods[id] = {}
						end
						loadedMods[id][theType] = {path=sresPath..path, encrypted=true, download=dl}
					end
				end
			end
		end
	end

	local skinModelNames
	if SCAN_MODS["skin_names"] then
		skinModelNames = getSkinModelNames()
	end
	local vehicleModelNames
	if SCAN_MODS["vehicle_names"] then
		vehicleModelNames = getVehicleModelNames()
	end
	local vehicleModelNamesNice
	if SCAN_MODS["vehicle_nice_names"] then
		vehicleModelNamesNice = getVehicleNiceNames()
	end
	local objectModelNames
	if SCAN_MODS["object_names"] then
		objectModelNames = getObjectModelNames()
	end

	Async:iterate(0, 18630, function(id)
		if id <= 312 then
			-- Skins
			if SCAN_MODS["skin_ids"] then
				findModFile(id, "dff", tostring(id))
				findModFile(id, "txd", tostring(id))
			end
			if skinModelNames then
				local v = skinModelNames[id]
				if v then
					for theType, name in pairs(v) do
						findModFile(id, theType, name)
					end
				end
			end

		elseif id >= 400 and id <= 611 then
			-- Vehicles
			if SCAN_MODS["vehicle_ids"] then
				findModFile(id, "dff", tostring(id))
				findModFile(id, "txd", tostring(id))
			end
			if vehicleModelNames then
				local v = vehicleModelNames[id]
				if v then
					for theType, name in pairs(v) do
						findModFile(id, theType, name)
					end
				end
			end
			if vehicleModelNamesNice then
				local name = vehicleModelNamesNice[id]
				if name then
					findModFile(id, "dff", name)
					findModFile(id, "txd", name)
				end
			end

		elseif id >= 321 then
			-- Objects
			 -- exclude unused/reserved for other purposes IDs
			if not ((id>=374 and id<=614) or (id>=11682 and id<=12799) or (id>=15065 and id<=15999)) then
				if SCAN_MODS["object_ids"] then
					findModFile(id, "dff", tostring(id))
					findModFile(id, "txd", tostring(id))
					findModFile(id, "col", tostring(id))
				end
				if objectModelNames then
					local v = objectModelNames[id]
					if v then
						for theType, name in pairs(v) do
							findModFile(id, theType, name)
						end
					end
				end
			end
		end
	end, function()
		endScan()
	end)
end

local function finishParsingIMG(fn, imgc)
	finishedParsing[fn] = true
	
	collectgarbage("collect")

	local c = 0
	for fn2, _ in pairs(finishedParsing) do
		c = c + 1
	end
	if c == imgc then
		outputSystemMsg("Finished parsing IMG files")
		startScanning()
	end
end

local function tryToFixResource(sres)
	
    local sresPath = ":"..STORAGE_RES_NAME.."/"
	local sresMeta = sresPath.."meta.xml"

    local sf = xmlLoadFile(sresMeta)
    if not sf then
		return outputSystemMsg("Failed to load file "..sresMeta)
    end

    local schildren = xmlNodeGetChildren(sf)
    if not schildren then
        xmlUnloadFile(sf)
		return outputSystemMsg("Could not get children of "..sresMeta)
    end

	files = {}

	local changed = false

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
                        local path = sresPath..src
						if not fileExists(path) then
							outputSystemMsg("Deleting missing file entry in "..sresMeta..": "..src)
							xmlDestroyNode(v)
							if not changed then
								changed = true
							end
						else
							files[src] = true
						end
                    end
                end
            end
        end
    end

	if not xmlSaveFile(sf) then
		outputSystemMsg("Failed to save "..sresMeta)
	end

	xmlUnloadFile(sf)

	if changed then
		if not refreshResources(false, sres) then
			return outputSystemMsg("Failed to refresh resource "..STORAGE_RES_NAME)
		end
		outputSystemMsg("Resource "..STORAGE_RES_NAME.." was refreshed, restarting...")
		return restartResource(resource)
	end

	outputSystemMsg("No files were deleted from "..sresMeta.."; the problem is likely something else.")
end

--[[
	This function will scan the given folder for files that match certain patterns.
	It uses the Async library to make the fileExists calls happen in parallel.
	This prevents freezing the server while scanning.
]]
local function scanModFiles(initial)

	local sres = getResourceFromName(STORAGE_RES_NAME)
	if not sres then
		local thisFolder = getResourceOrganizationalPath(resource)
		if thisFolder == "" then
			thisFolder = nil
		end
		local newRes = createResource(STORAGE_RES_NAME, thisFolder)
		if not newRes then
			outputSystemMsg("Failed to create resource '"..STORAGE_RES_NAME.."'.")
			return
		end
		sres = newRes
	end

	if getResourceState(sres)=="failed to load" then
		outputSystemMsg("Resource '"..STORAGE_RES_NAME.."' failed to load: "..getResourceLoadFailureReason(sres))
		tryToFixResource(sres)
		return
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
		return outputSystemMsg("Could not get children of "..sresMeta)
    end

	files = {}

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
						files[src] = {download=download}
                    end
                end
            end
        end
    end

	xmlUnloadFile(sf)
	
	loadedMods = {}

	insertFiles = {}
	deleteFiles = {}

	if not SCAN_MODS["img_files"] then
		return startScanning()
	end

	local imgContainerFiles = {}

	for i=1, #SCAN_FOLDERS do
		local folder = SCAN_FOLDERS[i]
		if folder then
			for j=1, #IMG_FILE_NAMES do
				local imgFn = IMG_FILE_NAMES[j]
				if imgFn then
					local path = folder..imgFn..".img"
					local exists = fileExists(sresPath..path)
					if (exists) then
						imgContainerFiles[imgFn] = path
					end
				end
			end
		end
	end

	local imgc = 0
	for fn, _ in pairs(imgContainerFiles) do
		imgc = imgc + 1
	end


	local function parseOneImgFile(imgContainer, fn, path, name)
		local extension = string.sub(name, -4)
		if (extension == ".dff" or extension == ".txd" or extension == ".col") then
			local theType = "txd"
			if extension == ".dff" then
				theType = "dff"
			elseif extension == ".col" then
				theType = "col"
			end
			local nameNoExtension = string.sub(name, 1, -5)
			if nameNoExtension then
				nameNoExtension = string.lower(nameNoExtension)
				local id = getIdFromModelName(nameNoExtension, theType=="col" and "dff" or theType)
				if id then
					path = path.."_files/"..name
					local exists = fileExists(sresPath..path)
					
					local dl = DEFAULT_FILE_AUTO_DOWNLOAD
					if (not files[path]) then
						insertFiles[path] = true
					else
						dl = files[path].download
					end
					if not (exists) then

						local f = fileCreate(sresPath..path)
						if not f then
							outputSystemMsg("      Failed to create file: "..sresPath..path)
							return
						end
						local content = imgContainer:getFile(name)
						fileWrite(f, content)
						fileClose(f)
					-- else
						-- TODO: checksum
					end

					if not loadedMods[id] then
						loadedMods[id] = {}
					end
					loadedMods[id][theType] = {path=sresPath..path, encrypted=false, download=dl}
				end
			end
		end
	end

	local function parseOneImgContainer(fn, path)
		local imgContainer = engineLoadIMGContainer(sresPath..path)
		if not (imgContainer) then
			outputSystemMsg("   Failed to parse IMG container: "..sresMeta)
			return false
		end
		if imgContainer.version ~= "VER2" then
			outputSystemMsg("   Unsupported IMG container version: '"..imgContainer.version.."' in "..fn..".img (expected VER2)")
			return false
		end
		local imgFiles = imgContainer:listFiles()
		if #imgFiles > 0 then
			
			outputSystemMsg("   Reading "..#imgFiles.." files from container: "..fn..".img ...")

			Async:foreach(imgFiles, function(name)
				parseOneImgFile(imgContainer, fn, path, name)
			end, function()
				outputSystemMsg("   Extracted "..#imgFiles.." files from container: "..fn..".img")
				finishParsingIMG(fn, imgc)
			end)
		else
			outputSystemMsg("   Container is empty: "..fn..".img")
			finishParsingIMG(fn, imgc)
		end

		return true
	end

	if imgc > 0 then

		outputSystemMsg("Parsing "..imgc.." IMG containers in "..STORAGE_RES_NAME.." (this may take a while)")
		
		finishedParsing = {}

		for fn, path in pairs(imgContainerFiles) do
			if not parseOneImgContainer(fn, path) then
				finishParsingIMG(fn, imgc)
			end
		end
	else
		outputSystemMsg("No IMG containers found in "..STORAGE_RES_NAME)
		startScanning()
	end
end

local function init()

	Async:setPriority(ASYNC_PRIORITY)

    setTimer(scanModFiles, 1000, 1, true)
end
addEventHandler("onResourceStart", resourceRoot, init)

addEventHandler("modDownloaderSimple:onDownloadManyFails", resourceRoot, function(kick, times, modId, path)
    if not client then return end

	outputSystemMsg(getPlayerName(client).." failed to download '"..path.."' (#"..modId..") "..times.." times"..(kick and ", kicking." or "."))

    if kick == true then
	    kickPlayer(client, "System", "Failed to download '"..path.."' (#"..modId..") "..times.." times.")
    end
end)
