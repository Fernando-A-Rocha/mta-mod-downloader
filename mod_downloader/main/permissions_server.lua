--[[
	Author: https://github.com/Fernando-A-Rocha

	permissions_server.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\

    For developers: you can customize permission checking functions here!
--]]

--[[ Mod GUI panel access permission checking function ]]
function canPlayerOpenGUI(player)
    -- You may change this to your liking
    return true
end

--[[ Other permissions checking functions ]]--

-- ........ Example (feel free to customize) ........

-- Check if player is logged in and has admin rights in ACL
function isPlayerAdmin(player)
    if isElement(player) then
        local acc = getPlayerAccount(player)
        if not isGuestAccount(acc) then
            return isObjectInACLGroup("user."..getAccountName(acc), aclGetGroup("Admin"))
        end
    end
    return false
end

-- Handle permission changed => re-send the player's mods
function handlePlayerLoginLogout(prevAcc, newAcc)
    triggerEvent("modDownloader:requestRefreshMods", root, source)
end
addEventHandler("onPlayerLogin", root, handlePlayerLoginLogout)
addEventHandler("onPlayerLogout", root, handlePlayerLoginLogout)

-- You can add as many function & handle as many events as you want!
