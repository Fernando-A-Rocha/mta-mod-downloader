--[[
	Author: https://github.com/Fernando-A-Rocha

	gui_client.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
--]]

addEvent("modDownloader:openModPanel", true)
addEvent("modDownloader:reenableModPanel", true)

local SW, SH = guiGetScreenSize()

local mainWindow = nil
local selectedTabName = nil
local selectedRow = nil

local lastGuiSpamEvent = nil

addEventHandler("onClientResourceStart", resourceRoot, function()

    local WW, WH = 800, 600
    mainWindow = guiCreateWindow((SW-WW)/2, (SH-WH)/2, WW, WH, "Placeholder Title", false)
    guiWindowSetSizable(mainWindow, false)
    guiSetVisible(mainWindow, false)

    local x, y = 10, 30

    local infoLabel = guiCreateLabel(x, y, WW-20, 40, "Placeholder Info", false, mainWindow)
    guiLabelSetHorizontalAlign(infoLabel, "center", true)
    guiLabelSetVerticalAlign(infoLabel, "center")
    
    y = y + 40 + 10

    local tabPanel = guiCreateTabPanel(x, y, WW-20, 400, false, mainWindow)
    
    y = y + 400 + 10

    local enableButton = guiCreateButton(x, y, 100, 40, "Enable", false, mainWindow)
    guiSetProperty(enableButton, "NormalTextColour", "FF00FF00")
    guiSetEnabled(enableButton, false)
    addEventHandler("onClientGUIClick", enableButton, function()
        local selectedTab = guiGetSelectedTab(tabPanel)
        local gridlist = getElementChildren(selectedTab, "gui-gridlist")[1]
        local row, col = guiGridListGetSelectedItem(gridlist)
        if row ~= -1 and col ~= -1 then

            local modId = guiGridListGetItemData(gridlist, row, 1)
            local modName = guiGridListGetItemText(gridlist, row, 1)
            local activated = guiGridListGetItemText(gridlist, row, 3)
            if activated == getSetting("gui_no") then

                if lastGuiSpamEvent then
                    if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                        outputCustomMessage(getSetting("msg_too_fast"), "error")
                        return
                    end
                end
                lastGuiSpamEvent = getTickCount()

                modId = tonumber(modId)
                if canEnableMod(modId) then
                    guiSetEnabled(mainWindow, false)
                    toggleModFromGUI(modId, modName, true, true)
                end
            end
        end
    end, false)

    x = x + 100 + 10

    local disableButton = guiCreateButton(x, y, 100, 40, "Disable", false, mainWindow)
    guiSetProperty(disableButton, "NormalTextColour", "ffff3c00")
    guiSetEnabled(disableButton, false)
    addEventHandler("onClientGUIClick", disableButton, function()
        local selectedTab = guiGetSelectedTab(tabPanel)
        local gridlist = getElementChildren(selectedTab, "gui-gridlist")[1]
        local row, col = guiGridListGetSelectedItem(gridlist)
        if row ~= -1 and col ~= -1 then
            
            local modId = guiGridListGetItemData(gridlist, row, 1)
            local modName = guiGridListGetItemText(gridlist, row, 1)
            local activated = guiGridListGetItemText(gridlist, row, 3)
            if activated == getSetting("gui_yes") then

                if lastGuiSpamEvent then
                    if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                        outputCustomMessage(getSetting("msg_too_fast"), "error")
                        return
                    end
                end
                lastGuiSpamEvent = getTickCount()
                
                modId = tonumber(modId)
                if canDisableMod(modId) then
                    guiSetEnabled(mainWindow, false)
                    toggleModFromGUI(modId, modName, false, true)
                end
            end
        end
    end, false)


    y = y + 40 + 10
    x = x - 100 - 10

    local enableAllButton = guiCreateButton(x, y, 100, 40, "Enable All", false, mainWindow)
    guiSetProperty(enableAllButton, "NormalTextColour", "FF00FF00")
    addEventHandler("onClientGUIClick", enableAllButton, function()

        if lastGuiSpamEvent then
            if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                outputCustomMessage(getSetting("msg_too_fast"), "error")
                return
            end
        end
        lastGuiSpamEvent = getTickCount()

        local allTabs = getElementChildren(tabPanel, "gui-tab")
        local toToggle = {}
        for i=1, #allTabs do
            local tab = allTabs[i]
            if tab then
                local gridlist = getElementChildren(tab, "gui-gridlist")[1]
                local total = guiGridListGetRowCount(gridlist)
                for row = 0, total-1 do
                    local modId = guiGridListGetItemData(gridlist, row, 1)
                    local modName = guiGridListGetItemText(gridlist, row, 1)
                    local activated = guiGridListGetItemText(gridlist, row, 3)
                    if activated == getSetting("gui_no") then
                        toToggle[#toToggle+1] = {modId, modName}
                    end
                end
            end
        end
        if #toToggle > 0 then
            local affected = 0
            for i=1, #toToggle do
                local modId, modName = tonumber(toToggle[i][1]), toToggle[i][2]
                if canEnableMod(modId) then
                    if guiGetEnabled(mainWindow) then
                        guiSetEnabled(mainWindow, false)
                    end
                    toggleModFromGUI(modId, modName, true)
                    affected = affected + 1
                end
            end
            if affected > 0 then
                outputCustomMessage(getSetting("msg_mod_activated_all").." ("..#toToggle..")", "success")
            end
        end
    end, false)
    
    x = x + 100 + 10

    local disableAllButton = guiCreateButton(x, y, 100, 40, "Disable All", false, mainWindow)
    guiSetProperty(disableAllButton, "NormalTextColour", "ffff3c00")
    addEventHandler("onClientGUIClick", disableAllButton, function()

        if lastGuiSpamEvent then
            if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                outputCustomMessage(getSetting("msg_too_fast"), "error")
                return
            end
        end
        lastGuiSpamEvent = getTickCount()
        
        local allTabs = getElementChildren(tabPanel, "gui-tab")
        local toToggle = {}
        for i=1, #allTabs do
            local tab = allTabs[i]
            if tab then
                local gridlist = getElementChildren(tab, "gui-gridlist")[1]
                local total = guiGridListGetRowCount(gridlist)
                for row = 0, total-1 do
                    local modId = guiGridListGetItemData(gridlist, row, 1)
                    local modName = guiGridListGetItemText(gridlist, row, 1)
                    local activated = guiGridListGetItemText(gridlist, row, 3)
                    if activated == getSetting("gui_yes") then
                        toToggle[#toToggle+1] = {modId, modName}
                    end
                end
            end
        end
        if #toToggle > 0 then
            local affected = 0
            for i=1, #toToggle do
                local modId, modName = tonumber(toToggle[i][1]), toToggle[i][2]
                if canDisableMod(modId) then
                    if guiGetEnabled(mainWindow) then
                        guiSetEnabled(mainWindow, false)
                    end
                    toggleModFromGUI(modId, modName, false)
                    affected = affected + 1
                end
            end
            if affected > 0 then
                outputCustomMessage(getSetting("msg_mod_deactivated_all").." ("..#toToggle..")", "info")
            end
        end
    end, false)

    x = WW - 10 - 100
    y = y - 40 - 10

    local closeButton = guiCreateButton(x, y, 100, 40, "Close", false, mainWindow)
    addEventHandler("onClientGUIClick", closeButton, function()
        guiSetVisible(mainWindow, false)
        showCursor(false)
    end, false)

    y = y + 40 + 10
       
    local refreshButton = guiCreateButton(x, y, 100, 40, "Refresh", false, mainWindow)
    guiSetProperty(refreshButton, "NormalTextColour", "FFFFFF00")
    addEventHandler("onClientGUIClick", refreshButton, function()
        guiSetEnabled(mainWindow, false)
        triggerServerEvent("modDownloader:requestRefreshMods", root, localPlayer)
    end, false)
    guiSetVisible(refreshButton, false)

    addEventHandler("onClientGUIClick", mainWindow, function()
        local selectedTab = guiGetSelectedTab(tabPanel)
        if selectedTab then
            local gridlist = getElementChildren(selectedTab, "gui-gridlist")[1]
            
            if selectedTabName and selectedTabName ~= guiGetText(selectedTab) then
                local selectedTab = guiGetSelectedTab(tabPanel)
                guiGridListSetSelectedItem(gridlist, -1, -1)
                selectedRow = nil
                guiSetEnabled(enableButton, false)
                guiSetEnabled(disableButton, false)
            else
                local row, col = guiGridListGetSelectedItem(gridlist)
                if row ~= -1 and col ~= -1 then
                    local activated = guiGridListGetItemText(gridlist, row, 3)
                    if activated == getSetting("gui_yes") then
                        guiSetEnabled(enableButton, false)
                        guiSetEnabled(disableButton, true)
                    else
                        guiSetEnabled(enableButton, true)
                        guiSetEnabled(disableButton, false)
                    end
                    selectedRow = row
                else
                    selectedRow = nil
                    guiSetEnabled(enableButton, false)
                    guiSetEnabled(disableButton, false)
                end
            end
            selectedTabName = guiGetText(selectedTab)
        end
    end)
end)

addEventHandler("modDownloader:reenableModPanel", localPlayer, function()
    if guiGetVisible(mainWindow) and not guiGetEnabled(mainWindow) then
        guiSetEnabled(mainWindow, true)
    end
end)

local function populateCategoryTab(tab, category, mod)

    local children = getElementChildren(tab, "gui-gridlist")
    local gridlist
    if children[1] then
        gridlist = children[1]
    else
        gridlist = guiCreateGridList(0, 0, 1, 1, true, tab)
        guiGridListAddColumn(gridlist, getSetting("gui_grid_col_name"), 0.25)
        guiGridListAddColumn(gridlist, getSetting("gui_grid_col_replaces"), 0.25)
        guiGridListAddColumn(gridlist, getSetting("gui_grid_col_enabled"), 0.2)
        guiGridListAddColumn(gridlist, getSetting("gui_grid_col_ready"), 0.2)

        local enableButton = getElementChildren(mainWindow, "gui-button")[1]
        local disableButton = getElementChildren(mainWindow, "gui-button")[2]
    end


    local row = guiGridListAddRow(gridlist)

    guiGridListSetItemText(gridlist, row, 1, mod.name, false, false)
    guiGridListSetItemData(gridlist, row, 1, mod.id)

    guiGridListSetItemText(gridlist, row, 2, mod.replaces, false, false)
    if mod.activated then
        guiGridListSetItemText(gridlist, row, 3, getSetting("gui_yes"), false, false)
        guiGridListSetItemColor(gridlist, row, 3, 0, 255, 0)
    else
        guiGridListSetItemText(gridlist, row, 3, getSetting("gui_no"), false, false)
        guiGridListSetItemColor(gridlist, row, 3, 255, 69, 69)
    end
    if not mod.pendingDownloads then
        guiGridListSetItemText(gridlist, row, 4, getSetting("gui_yes"), false, false)
        guiGridListSetItemColor(gridlist, row, 4, 0, 255, 0)
    else
        guiGridListSetItemText(gridlist, row, 4, getSetting("gui_no"), false, false)
        guiGridListSetItemColor(gridlist, row, 4, 255, 69, 69)
    end
end

function populateModsGUI()
    local myMods = getReceivedMods()
    if not myMods then return end
    
    local tabPanel = getElementChildren(mainWindow, "gui-tabpanel")[1]

    local tabs = getElementChildren(tabPanel, "gui-tab")
    for i=1, #tabs do
        local tab = tabs[i]
        if tab then
            guiDeleteTab(tabs[i], tabPanel)
        end
    end
    local modsByCategory = {}
    for i=1, #myMods do
        local mod = myMods[i]
        if mod then
            if not modsByCategory[mod.category] then
                modsByCategory[mod.category] = {}
            end
            modsByCategory[mod.category][#modsByCategory[mod.category]+1] = mod
        end
    end
    for category, mods in pairs(modsByCategory) do
        local count = 0
        for id, mod in pairs(mods) do
            count = count + 1
        end
        if count > 0 then
            local tab = guiCreateTab(category, tabPanel)
            for i=1, #mods do
                local mod = mods[i]
                if mod then
                    populateCategoryTab(tab, category, mod)
                end
            end
        end
    end

    if (selectedTabName ~= nil) then
        tabs = getElementChildren(tabPanel, "gui-tab")
        for i=1, #tabs do
            local tab = tabs[i]
            if tab then
                if guiGetText(tab) == selectedTabName then
                    guiSetSelectedTab(tabPanel, tab)
                    break
                end
            end
        end
    end

    if (selectedRow ~= nil) then
        local tab = guiGetSelectedTab(tabPanel)
        local gridlist = getElementChildren(tab, "gui-gridlist")[1]
        if guiGridListGetRowCount(gridlist) >= selectedRow then
            guiGridListSetSelectedItem(gridlist, selectedRow, 1)
        end
    end

    local buttons = getElementChildren(mainWindow, "gui-button")
    guiSetText(buttons[1], getSetting("gui_btn_enable"))
    guiSetText(buttons[2], getSetting("gui_btn_disable"))
    guiSetText(buttons[3], getSetting("gui_btn_enableall"))
    guiSetText(buttons[4], getSetting("gui_btn_disableall"))
    guiSetText(buttons[5], getSetting("gui_btn_close"))

    if getSetting("allow_refresh_mods") then
        guiSetVisible(buttons[6], true)
        guiSetText(buttons[6], getSetting("gui_btn_refresh"))
    else
        guiSetVisible(buttons[6], false)
    end

    guiSetText(mainWindow, getSetting("gui_title"))
    guiSetText(getElementChildren(mainWindow, "gui-label")[1], getSetting("gui_description"))

    -- Re-enable window
    if not guiGetEnabled(mainWindow) then
        guiSetEnabled(mainWindow, true)
    end
end

function toggleGUIPanel()

    if guiGetVisible(mainWindow) then
        guiSetVisible(mainWindow, false)
        showCursor(false)
        return
    end

    if lastGuiSpamEvent then
        if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
            outputCustomMessage(getSetting("msg_too_fast"), "error")
            return
        end
    end
    lastGuiSpamEvent = getTickCount()

    triggerServerEvent("modDownloader:requestOpenModPanel", root, localPlayer)
end

addEventHandler("modDownloader:openModPanel", localPlayer, function()
    if not guiGetVisible(mainWindow) then
        guiSetVisible(mainWindow, true)
        showCursor(true)
    end
end)

function drawDownloadingDialog()
    local info = getDownloadingInfo()
	local queueSize = #(info.fileDLQueue)
	local text = "Downloading... (".. (queueSize == 1 and "last one" or (queueSize.." left")) ..")\n "
	local curr = (info.currDownloading)
	if curr then
		local modId, path = unpack(curr)
		text = text..""..path.." (ID "..modId..")"
	end
	dxDrawText(text, 0, 0, SW, 45, tocolor(255, 255, 0, 255), 1.00, "default-bold", "right", "center", false, false, false, false, false)
end
