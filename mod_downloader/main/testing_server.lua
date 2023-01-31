--[[
	Author: https://github.com/Fernando-A-Rocha

	testing_server.lua

    Commands:
        - /testforcemods
--]]

local testModList = {
    {id=955, name="Sprunk Vending Machine"},
    {id=426, name="Schafter"},
}

addCommandHandler("testforcemods", function(player, cmd, enable)
    enable = tonumber(enable)
    if (not enable or not (enable == 1 or enable == 0)) then
        return outputChatBox("USAGE: /"..cmd.." [Enable mods 0/1]", player, 255, 255, 255)
    end
    local options = {
        force = true,
        enable = (enable==1 and true or false),
    }

    local success = requestForceModsPlayer(player, testModList, options)
    if success then
        outputChatBox("Forcing mods for player "..getPlayerName(player), player, 0, 255, 0)
    end
end)
addCommandHandler("testreqmods", function(player, cmd, enable)
    enable = tonumber(enable)
    if (not enable or not (enable == 1 or enable == 0)) then
        return outputChatBox("USAGE: /"..cmd.." [Enable mods 0/1]", player, 255, 255, 255)
    end
    local options = {
        force = false,
        enable = (enable==1 and true or false),
    }

    local success = requestForceModsPlayer(player, testModList, options)
    if success then
        outputChatBox("Requesting mods for player "..getPlayerName(player), player, 0, 255, 0)
    end
end)
