--[[
	Author: https://github.com/Fernando-A-Rocha

	teleport_server.lua

    
	Customizable Example:
        Teleport Locations with GUI that depend on one more more mods being activated
        See teleport_client.lua for more information
--]]

addEvent("modDownloader:teleport", true)

local teleporting = {}

addEventHandler("modDownloader:teleport", resourceRoot, function(position, msg)
    if not client then return end

	local x,y,z,rx,ry,rz,interior,dimension = position[1],position[2],position[3],position[4],position[5],position[6],position[7],position[8]

    local veh = getPedOccupiedVehicle(client)
    if veh then

        if teleporting[veh] then
            return
        end
        teleporting[veh] = true

        setElementFrozen(veh, true)

        setElementPosition(veh, x, y, z)
        setElementRotation(veh, rx, ry, rz)
        setElementInterior(veh, interior)
        setElementDimension(veh, dimension)

        setTimer(function()

            if isElement(veh) then

                for seat, occupant in pairs(getVehicleOccupants(veh) or {}) do
                    setElementInterior(occupant, interior)
                    setElementDimension(occupant, dimension)
                end

                setElementFrozen(veh, false)
            end

            teleporting[veh] = nil

        end, 2000, 1)
    else
        if teleporting[client] then
            return
        end
        teleporting[client] = true

        setElementFrozen(client, true)

        setElementPosition(player, x, y, z)
        setElementRotation(player, rx, ry, rz)
        setElementInterior(player, interior)
        setElementDimension(player, dimension)

        setTimer(function(player)

            if isElement(player) then
                setElementFrozen(player, false)
            end

            teleporting[player] = nil

        end, 2000, 1, client)
    end

    outputChatBox(msg[1], client, msg[2], msg[3], msg[4], msg[5])
end)
