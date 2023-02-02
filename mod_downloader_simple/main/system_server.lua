--[[
	Author: https://github.com/Fernando-A-Rocha

	system_server.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

local currentlyLoading = true
local clientsWaiting = {} -- for initial startup

local loadedMods = {}

function getLoadedMods()
	return loadedMods
end

local function canExecuteRescan(executor)
	local acc = getPlayerAccount(executor)
	if not acc then return false end
	if getAccountName(acc) == "Console" then return true end
	if isObjectInACLGroup("user."..getAccountName(acc), aclGetGroup("Admin")) then return true end
	return false
end

local function outputSystemMsg(msg)
    if (not DEBUG_ENABLED) then return end
    outputServerLog(MESSAGES_PREFIX..msg)
	local playersTable = getElementsByType("player")
	for i=1, #playersTable do
		local player = playersTable[i]
		if player and canExecuteRescan(player) then
    		outputChatBox(MSG_PREFIX_COLOR..MESSAGES_PREFIX..MSG_COLOR..msg, player, 255, 255, 255, true)
		end
	end
end

local function stopStorage()
    local sres = getResourceFromName(STORAGE_RES_NAME)
    if sres and getResourceState(sres)=="running" then
        stopResource(sres)
    end
end
addEventHandler("onResourceStop", resourceRoot, stopStorage)

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

--[[
	This function will scan the given folder for files that match certain patterns.
	It uses the Async library to make the fileExists calls happen in parallel.
	This prevents freezing the server while scanning.
]]
local function scanModFiles()

	currentlyLoading = true

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
	
    local sresPath = ":"..STORAGE_RES_NAME.."/"
	local sresMeta = sresPath.."meta.xml"

    local sf = xmlLoadFile(sresMeta)
    if not sf then
		outputSystemMsg("Failed to load file "..sresMeta)
		return
    end

    local schildren = xmlNodeGetChildren(sf)
    if not schildren then
        xmlUnloadFile(sf)
		outputSystemMsg("Could not get children of "..sresMeta)
		return
    end

	local files = {}

	local deleted = 0

    for i=1, #schildren do
        local v = schildren[i]
        if v then
            if xmlNodeGetName(v) == "file" then
                local src = xmlNodeGetAttribute(v, "src")
                if src then
                    if files[src] then
                        outputSystemMsg("Deleting duplicate file entry in "..sresMeta..": "..src)
                        xmlDestroyNode(v)
						deleted = deleted + 1
                    else
                        local path = sresPath..src
						if not fileExists(path) then
							outputSystemMsg("Deleting missing file entry in "..sresMeta..": "..src)
							xmlDestroyNode(v)
							deleted = deleted + 1
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

	if deleted > 0 then
		if not refreshResources(false, sres) then
			outputSystemMsg("Failed to refresh resource "..STORAGE_RES_NAME)
			return
		end
		outputSystemMsg("Resource "..STORAGE_RES_NAME.." was refreshed, restarting current resource...")
		return restartResource(resource)
	end

	if getResourceState(sres)=="failed to load" then
		outputSystemMsg("Resource '"..STORAGE_RES_NAME.."' failed to load: "..getResourceLoadFailureReason(sres))
		return
	end

	if not sres then
		outputSystemMsg("Unexpected: File storage resource '"..STORAGE_RES_NAME.."' not found.")
		return
	end

    sf = xmlLoadFile(sresMeta)
    if not sf then
		return outputSystemMsg("Failed to load file "..sresMeta)
    end

    schildren = xmlNodeGetChildren(sf)
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
	
	local insertFiles = {}
	
	local startedAt = getTickCount()

	outputSystemMsg("Started scanning for mod files in "..STORAGE_RES_NAME.." (this may take a while)")

	local function findModFile(id, theType, value)
		for i=1, #SCAN_FOLDERS do
			local folder = SCAN_FOLDERS[i]
			if folder then
				local path = folder..value.."."..theType
				local exists = fileExists(sresPath..path)
				if (exists) then
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
					if (exists) then
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
		
		local cf = 0
		for id, _ in pairs(loadedMods) do
			cf = cf + 1
		end

		local elapsedMs = (getTickCount()-startedAt)
		local elapsed = elapsedMs.." ms"
		if elapsedMs > 1000 then
			elapsed = math.floor(elapsedMs/1000).." s"
		end
		outputSystemMsg("Scanning finished after "..elapsed..", found "..cf.." models to replace")

		sres = getResourceFromName(STORAGE_RES_NAME)
		if not sres then
			outputSystemMsg("Unexpected: File storage resource '"..STORAGE_RES_NAME.."' not found.")
			return
		end
		local sresState = getResourceState(sres)

		local ic = 0
		for k, _ in pairs(insertFiles) do
			ic = ic + 1
		end

		if ic > 0 then
			outputSystemMsg("Inserting "..ic.." file nodes in "..sresMeta)

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

			if not xmlSaveFile(sf) then
				xmlUnloadFile(sf)
				return outputSystemMsg("Failed to save file "..sresMeta)
			end
			xmlUnloadFile(sf)
		end

		if not (sresState == "running" or sresState == "loaded") then
			return outputSystemMsg("Resource '"..sresPath.."' has state '"..sresState.."'")
		end
		if sresState == "running" and (ic > 0) then
			outputSystemMsg("File "..sresMeta.." has changed, restarting resource...")
			if not restartResource(sres) then
				return outputSystemMsg("Could not restart resource '"..sresPath.."'")
			end
		elseif sresState == "loaded" then
			if not startResource(sres) then
				return outputSystemMsg("Could not start resource '"..sresPath.."'")
			end
		end
		
		if type(clientsWaiting)=="table" then
			if (#clientsWaiting) > 0 then
				outputSystemMsg("Sending mods to "..(#clientsWaiting).." clients ...")
				for i=1, #clientsWaiting do
					local player = clientsWaiting[i]
					if isElement(player) then
						sendModsToPlayer(player)
					end
				end
			end
			clientsWaiting = nil
		else
			local playersTable = getElementsByType("player")
			if #playersTable > 0 then
				outputSystemMsg("Sending mods to "..(#playersTable).." clients ...")
				for i=1, #playersTable do
					local player = playersTable[i]
					sendModsToPlayer(player)
				end
			end
		end

		currentlyLoading = nil
	end)
end

local function init()
	Async:setPriority(ASYNC_PRIORITY)
    setTimer(scanModFiles, 1000, 1)
end
addEventHandler("onResourceStart", resourceRoot, init)

addCommandHandler(COMMAND_RESCAN, function(executor, cmd)
	if not canExecuteRescan(executor) then
		return
	end
	scanModFiles()
end, false, false)

addCommandHandler(COMMAND_EXTRACT_IMG, function(executor, cmd, targetRes, imgPath)
	if not canExecuteRescan(executor) then
		return
	end
	if not (imgPath and targetRes) then
		outputSystemMsg("Usage: /"..cmd.." [resource where it's located] [img path] ")
		outputSystemMsg("   e.g. /"..cmd.." file_storage containers/gta3.img")
		return
	end
	if not getResourceFromName(targetRes) then
		return outputSystemMsg("Resource '"..targetRes.."' does not exist.")
	end
	local pathRes = ""
	local fn = imgPath
	if targetRes ~= getResourceName(resource) then
		pathRes = ":"..targetRes.."/"
	end
	local path = pathRes..fn
	if not fileExists(path) then
		fn = fn..".img"
		path = pathRes..fn
		if not fileExists(path) then
			return outputSystemMsg("File '"..path.."' does not exist.")
		end
	end
	local outDirectory = pathRes..fn.."_files/"
	local function parseOneImgFile(imgContainer, name)
		local extension = string.sub(name, -4)
		if string.sub(extension, 1, 1) == "." then
			local theType = string.sub(extension, 2)
			local nameNoExtension = string.sub(name, 1, -5)
			if nameNoExtension then
				nameNoExtension = string.lower(nameNoExtension)
				local content = imgContainer:getFile(name)
				if content then
					local theTypeForModel = "dff"
					if theType == "txd" then
						theTypeForModel = "txd"
					end
					local pfpath = outDirectory..nameNoExtension.."%s."..theType
					local id = getIdFromModelName(nameNoExtension, theTypeForModel)
					if id then
						pfpath = string.format(pfpath, "_"..id)
					else
						pfpath = string.format(pfpath, "")
					end
					local file = fileCreate(pfpath)
					if file then
						fileWrite(file, content)
						fileClose(file)
						outputSystemMsg("Created: "..pfpath)
					end
				end
			end
		end
	end
	local imgContainer = engineLoadIMGContainer(path)
	if not (imgContainer) then
		outputSystemMsg("Failed to parse IMG container: "..path)
		return
	end
	if imgContainer.version ~= "VER2" then
		outputSystemMsg("Unsupported IMG container version: '"..imgContainer.version.."' in "..fn.." (expected VER2)")
		return
	end
	local imgFiles = imgContainer:listFiles()
	if #imgFiles > 0 then
		outputSystemMsg("Parsing "..#imgFiles.." files in container: "..fn.." ...")
		Async:foreach(imgFiles, function(name)
			parseOneImgFile(imgContainer, name)
		end)
	else
		outputSystemMsg("Container is empty: "..fn)
	end
end, false, false)

addEventHandler("modDownloaderSimple:onDownloadManyFails", resourceRoot, function(kick, times, modId, path)
    if not client then return end

	outputSystemMsg(getPlayerName(client).." failed to download '"..path.."' (#"..modId..") "..times.." times"..(kick and ", kicking." or "."))

    if kick == true then
	    kickPlayer(client, "System", "Failed to download '"..path.."' (#"..modId..") "..times.." times.")
    end
end)
