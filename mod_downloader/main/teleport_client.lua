--[[
	Author: https://github.com/Fernando-A-Rocha

	teleport_client.lua

	
	Customizable Example:
		Teleport Locations with GUI that depend on one more more mods being activated
--]]

local SW, SH = guiGetScreenSize()

local CMD_TELEPORT = "tpto"
local CMD_TELEPORT_GUI = "tp"
local BIND_TELEPORT_GUI = "f7"

local TP_WINDOW_TITLE = "Locations"
local TP_WINDOW_CLOSE_TEXT = "Close"
local TP_WINDOW_OPEN_MOD_GUI_TEXT = "Mod Downloader"
local TP_WAIT_MSG = {"You need to wait %s seconds to teleport again.", 255, 55, 55, false}

local lastTeleports = {}
local tpWindow = nil

local TP_DESTINATIONS = {
	{
		name = "Grove Street",
		description = [[Home. At least it was before I fucked everything up.]],
		commands = {"grove", "grovestreet", "grovest", "gs"},
		position = {  2323, -1658, 14, 0, 0, 0, 0, 0 }, --x,y,z,rx,ry,rz,interior,dimension
		success_msg = {"Teleported to Grove Street.", 55, 255, 55, false},

		disable_tp_vehicle_moving = true,
		error_veh_moving_msg = {"Stop your vehicle to teleport to Grove Street.", 255, 55, 55, false},

		show_in_gui = true,
		gui_tp_text = "Teleport",

		-- when entering this colsphere, player will receive popup to activate particular mods
		req_col = { col=createColSphere(2323, -1658, 14, 35), hit="enable" }, --leave="disable"
		req_mods = { { id=955, name="Sprunk Vending Machine"} },
	},
	{
		-- Only lets you TP to the Arena if the arena mods are activated
		name = "Kickstart Arena",
		description = [[Your favorite playground.]],
		commands = {"arena"},
		position = {  -1413, 1590, 1053, 0, 0, 0, 14, 69 },
		success_msg = {"Teleported to the Arena.", 255, 255, 55, false},

		protected_radius = 100,
		protected_dimension = 69,

		requireModsActivated = { 13642, 13646 },
		output_for_mod = 13642, -- so that when trying to disable all mods it will only warn for the 1st one and not spam
		prevent_disable_msg = {"You can't disable the Arena mods while inside.", 255, 55, 55, false},
		error_msg = {"You need to activate the Arena mods to teleport there.", 255, 55, 55, false},

		disable_tp_vehicle_moving = true,
		error_veh_moving_msg = {"Stop your vehicle to teleport to the Arena.", 255, 55, 55, false},

		tp_wait_delay = 30000,
		show_wait_msg = true,

		show_in_gui = true,
		gui_tp_text = "Teleport",
	},
	{
		name = "Blueberry",
		commands = {"bb"},
		position = {  3, 3, 3, 0, 0, 0, 0, 0 },
		success_msg = {"Teleported to Blueberry.", 55, 255, 55, false},

		disable_tp_vehicle = true,
		error_veh_msg = {"You can't teleport to Blueberry while in a vehicle.", 255, 55, 55, false},
	},
}

-- Default: shows you a popup to activate the sprunk vending machine mod
-- when approaching the Ten Green Bottles bar
addEventHandler("onClientResourceStart", resourceRoot, function()
	for i=1, #TP_DESTINATIONS do
		local dest = TP_DESTINATIONS[i]
		if dest then
			local req_col = dest.req_col
			local req_mods = dest.req_mods
			if type(req_mods)=="table" and type(req_col)=="table" then
				local col = req_col.col
				if isElement(col) and #req_mods>0 then

					local hit = req_col.hit
					local leave = req_col.leave
					if hit then
						addEventHandler("onClientColShapeHit", col, function(el, md)
							if el == localPlayer and md and getElementInterior(col) == getElementInterior(localPlayer) then
								local enable = (hit == "enable" or false)
								local list = {}
								for j=1, #req_mods do
									local req_mod = req_mods[j]
									if req_mod then
										if (enable and not isModelReplaced(req_mod.id))
										or ((not enable) and isModelReplaced(req_mod.id)) then
											list[#list+1] = {id=req_mod.id, name=req_mod.name}
										end
									end
								end
								if #list > 0 then
									triggerServerEvent("modDownloader:requestForceMods", root, localPlayer, list, {
										enable = enable
									})
								end
							end
						end)
					end
					if leave then
						addEventHandler("onClientColShapeLeave", col, function(el, md)
							if el == localPlayer and md and getElementInterior(col) == getElementInterior(localPlayer) then
								local enable = (hit == "enable" or false)
								local list = {}
								for j=1, #req_mods do
									local req_mod = req_mods[j]
									if req_mod then
										if (enable and not isModelReplaced(req_mod.id))
										or ((not enable) and isModelReplaced(req_mod.id)) then
											list[#list+1] = {id=req_mod.id, name=req_mod.name}
										end
									end
								end
								if #list > 0 then
									triggerServerEvent("modDownloader:requestForceMods", root, localPlayer, list, {
									enable = (leave == "enable" or false)
									})
								end
							end
						end)
					end
				end
			end
		end
	end
end)

-- Used in permissions_client.lua
function isPlayerInTPArea(modIdAffected)
	local x, y, z = getElementPosition(localPlayer)
	local dimension = getElementDimension(localPlayer)
	for i=1, #TP_DESTINATIONS do
		local dest = TP_DESTINATIONS[i]
		if dest then
			
			local requireModsActivated = dest.requireModsActivated
			local modOk = true
			if requireModsActivated and #requireModsActivated > 0 then
				for j=1, #requireModsActivated do
					if requireModsActivated[j] == modIdAffected then
						modOk = false
						break
					end
				end
			end

			local isInArea = false

			local prevent_disable_msg = dest.prevent_disable_msg

			local protected_dimension = dest.protected_dimension
			if protected_dimension and dimension == protected_dimension then
				isInArea = true
			end
			
			if not isInArea then
				local protected_radius = dest.protected_radius
				if protected_radius then
					local px, py, pz = dest.position[1], dest.position[2], dest.position[3]
					if getDistanceBetweenPoints3D(x, y, z, px, py, pz) < protected_radius then
						isInArea = true
					end
				end
			end

			if isInArea and not modOk then
				return true, prevent_disable_msg, dest.output_for_mod
			end
		end
	end
	return false
end

function commandTP(cmd, destination)
	if not destination then
		outputChatBox("USAGE: /" .. cmd .. " [destination]", 255, 255, 255)
		for i=1, #TP_DESTINATIONS do
			local dest = TP_DESTINATIONS[i]
			if dest then
				outputChatBox("  "..(dest.name)..": " .. table.concat(dest.commands, ", "), 200, 200, 200)
			end
		end
		return
	end
	local dest, destid
	for i=1, #TP_DESTINATIONS do
		local d = TP_DESTINATIONS[i]
		if d then
			for j=1, #d.commands do
				if (string.lower(d.commands[j])) == (string.lower(destination)) then
					dest = d
					destid = i
					break
				end
			end
		end
	end
	if not dest then
		return commandTP(cmd)
	end

	local tp_delay = dest.tp_wait_delay
	if type(tp_delay)=="number" and lastTeleports[destid] and ((getTickCount() - lastTeleports[destid]) < tp_delay) then
		local show_wait_msg = dest.show_wait_msg
		if show_wait_msg then
			local wait_msg = TP_WAIT_MSG
			outputChatBox(wait_msg[1]:format(math.ceil((tp_delay - (getTickCount() - lastTeleports[destid])) / 1000)), wait_msg[2], wait_msg[3], wait_msg[4], wait_msg[5])
		end
		return
	end

	local mods = dest.requireModsActivated
	if mods and #mods > 0 then
		for i=1, #mods do
			if not isModelReplaced(mods[i]) then
				if dest.error_msg then
					outputChatBox(dest.error_msg[1], dest.error_msg[2], dest.error_msg[3], dest.error_msg[4], dest.error_msg[5])
				end
				return
			end
		end
	end
	local vehicle = getPedOccupiedVehicle(localPlayer)
	if vehicle then
		local disable_tp_vehicle = dest.disable_tp_vehicle
		if disable_tp_vehicle and disable_tp_vehicle == true then
			if dest.error_veh_msg then
				outputChatBox(dest.error_veh_msg[1], dest.error_veh_msg[2], dest.error_veh_msg[3], dest.error_veh_msg[4], dest.error_veh_msg[5])
			end
			return
		end

		local disable_tp_vehicle_moving = dest.disable_tp_vehicle_moving
		if disable_tp_vehicle_moving and disable_tp_vehicle_moving == true then
			local vx, vy, vz = getElementVelocity(vehicle)
			if vx ~= 0 or vy ~= 0 or vz ~= 0 then
				if dest.error_veh_moving_msg then
					outputChatBox(dest.error_veh_moving_msg[1], dest.error_veh_moving_msg[2], dest.error_veh_moving_msg[3], dest.error_veh_moving_msg[4], dest.error_veh_moving_msg[5])
				end
				return
			end
		end
	end

	lastTeleports[destid] = getTickCount()

	triggerServerEvent("modDownloader:teleport", resourceRoot, dest.position, dest.success_msg)
end
addCommandHandler(CMD_TELEPORT, commandTP, false)

local function closeTPGUI()
	destroyElement(tpWindow)
	tpWindow = nil
	showCursor(false)
end

function openTPGUI()

	if isElement(tpWindow) then
		return closeTPGUI()
	end

	local WW, WH = 600, 400
	tpWindow = guiCreateWindow((SW-WW)/2, (SH-WH)/2, WW, WH, TP_WINDOW_TITLE, false)
	guiWindowSetSizable(tpWindow, false)

	local XOFF = 20
	local x = XOFF
	local y = 30

	local bWidth = 100

	for i=1, #TP_DESTINATIONS do
		local dest = TP_DESTINATIONS[i]
		if dest then
			local show_in_gui = dest.show_in_gui
			if show_in_gui then
				local name = dest.name
				local description = dest.description
				local commands = dest.commands
				
				local labelName = guiCreateLabel(x, y, WW-bWidth-(XOFF*2), 20, name, false, tpWindow)
				guiSetFont(labelName, "default-bold-small")
				guiLabelSetHorizontalAlign(labelName, "left", true)
				guiLabelSetVerticalAlign(labelName, "center")

				local labelDescription = guiCreateLabel(x, y+20, WW-bWidth-(XOFF*2), 20, description, false, tpWindow)
				guiSetFont(labelName, "clear-small")
				guiLabelSetHorizontalAlign(labelDescription, "left", true)
				guiLabelSetVerticalAlign(labelDescription, "center")

				local buttonTeleport = guiCreateButton(WW-bWidth-(XOFF), y, bWidth, 40, dest.gui_tp_text, false, tpWindow)
				addEventHandler("onClientGUIClick", buttonTeleport, function()
					commandTP(CMD_TELEPORT, commands[1])
					closeTPGUI()
				end, false)

				y = y + 40 + 10
			end
		end
	end

	local buttonClose = guiCreateButton(WW-bWidth-(XOFF), WH-40, bWidth, 30, TP_WINDOW_CLOSE_TEXT, false, tpWindow)
	addEventHandler("onClientGUIClick", buttonClose, closeTPGUI, false)

	local buttonOpenModGUI = guiCreateButton(WW-bWidth-(XOFF*2)-(bWidth*2), WH-40, bWidth*2, 30, TP_WINDOW_OPEN_MOD_GUI_TEXT, false, tpWindow)
	guiSetProperty(buttonOpenModGUI, "NormalTextColour", "AA00FF00")
	addEventHandler("onClientGUIClick", buttonOpenModGUI, function()
		closeTPGUI()
		triggerServerEvent("modDownloader:requestOpenModPanel", root, localPlayer)
	end, false)

	showCursor(true)
end
addCommandHandler(CMD_TELEPORT_GUI, openTPGUI, false)

if type(BIND_TELEPORT_GUI)=="string" then
	bindKey(BIND_TELEPORT_GUI, "down", openTPGUI)
end