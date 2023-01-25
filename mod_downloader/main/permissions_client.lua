--[[
	Author: https://github.com/Fernando-A-Rocha

	permissions_server.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\

    For developers: you can customize permission checking functions here!
--]]


--[[
    Mod GUI panel Enable mod permission checking
        Default version
]]

function canEnableMod(modID)
    -- You may change this to your liking
    return true
end


--[[
    Mod GUI panel Disable mod permission checking
]]

-- Default version
--[[function canDisableMod(modId)
    -- You may change this to your liking
    return true
end]]

-- Custom: works with the code in teleport_client.lua
function canDisableMod(modId)
    local inArea, msg = isPlayerInTPArea(modId)
    if inArea then
        if msg then
            outputCustomMessage(msg[1], msg[2], msg[3], msg[4], msg[5])
        end
        return false
    end
    return true
end