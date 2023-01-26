--[[
	Author: https://github.com/Fernando-A-Rocha

	gui_client.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\


    Changes compared to the normal CEGUI gui_client.lua:
        - Added dgs resource verification on startup
        - Renamed gui functions to dgs functions
        - Renamed onClientGUIClick event to onDgsMouseClickUp
        - Renamed gui element types in getElementChildren to dgs element types
        - Set dgsSetProperty ignoreTitle true on mainWindow
        - Set dgsWindowSetCloseButtonEnabled false on mainWindow
        - Changed buttons dgsSetProperty, see https://wiki.multitheftauto.com/wiki/Dgs-dxbutton
        - Changed code that uses dgsGridListGetRowCount because rows in DGS start at 1 instead of 0
]]

local COLOR_BTN_BG_GREEN = 0xff2b6907
local COLOR_BTN_BG_RED = 0xff690707
local COLOR_BTN_BG_YELLOW = 0xff696907

addEvent("modDownloader:openModPanel", true)
addEvent("modDownloader:reenableModPanel", true)

local SW, SH = guiGetScreenSize()

local mainWindow = nil
local selectedTabName = nil
local selectedRow = nil

local lastGuiSpamEvent = nil

local DGS = nil

addEventHandler("onClientResourceStart", resourceRoot, function()

    local dgsResource = getResourceFromName("dgs")
    dgsResource = dgsResource and getResourceState(dgsResource) == "running"
    if not dgsResource then
        outputDebugString("Mod Downloader: DGS is not running, custom GUI won't work.", 1)
        return
    end
    DGS = exports.dgs

    local WW, WH = 800, 600
    mainWindow = DGS:dgsCreateWindow((SW-WW)/2, (SH-WH)/2, WW, WH, "Placeholder Title", false)
    DGS:dgsSetProperty(mainWindow, "ignoreTitle", true) -- DGS specific
	DGS:dgsWindowSetCloseButtonEnabled(mainWindow, false) -- DGS specific
    DGS:dgsWindowSetSizable(mainWindow, false)
    DGS:dgsSetVisible(mainWindow, false)

    local x, y = 10, 30

    local infoLabel = DGS:dgsCreateLabel(x, y, WW-20, 40, "Placeholder Info", false, mainWindow)
    DGS:dgsLabelSetHorizontalAlign(infoLabel, "center", true)
    DGS:dgsLabelSetVerticalAlign(infoLabel, "center")
    
    y = y + 40 + 10

    local tabPanel = DGS:dgsCreateTabPanel(x, y, WW-20, 400, false, mainWindow)
    
    y = y + 400 + 10

    local enableButton = DGS:dgsCreateButton(x, y, 100, 40, "Enable", false, mainWindow)
    local DEFAULT_BTN_COLOR = DGS:dgsGetProperty(enableButton, "color")
    local GREEN_COLOR = {COLOR_BTN_BG_GREEN, DEFAULT_BTN_COLOR[2], DEFAULT_BTN_COLOR[3]}
    local RED_COLOR = {COLOR_BTN_BG_RED, DEFAULT_BTN_COLOR[2], DEFAULT_BTN_COLOR[3]}
    local YELLOW_COLOR = {COLOR_BTN_BG_YELLOW, DEFAULT_BTN_COLOR[2], DEFAULT_BTN_COLOR[3]}
    DGS:dgsSetProperty(enableButton, "color", GREEN_COLOR)
    DGS:dgsSetEnabled(enableButton, false)
    addEventHandler("onDgsMouseClickUp", enableButton, function()
        local selectedTab = DGS:dgsGetSelectedTab(tabPanel)
        local gridlist = getElementChildren(selectedTab, "dgs-dxgridlist")[1]
        local row, col = DGS:dgsGridListGetSelectedItem(gridlist)
        if row ~= -1 and col ~= -1 then

            local modId = DGS:dgsGridListGetItemData(gridlist, row, 1)
            local modName = DGS:dgsGridListGetItemText(gridlist, row, 1)
            local activated = DGS:dgsGridListGetItemText(gridlist, row, 3)
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
                    DGS:dgsSetEnabled(mainWindow, false)
                    toggleModFromGUI(modId, modName, true, true)
                end
            end
        end
    end, false)

    x = x + 100 + 10

    local disableButton = DGS:dgsCreateButton(x, y, 100, 40, "Disable", false, mainWindow)
    DGS:dgsSetProperty(disableButton, "color", RED_COLOR)
    DGS:dgsSetEnabled(disableButton, false)
    addEventHandler("onDgsMouseClickUp", disableButton, function()
        local selectedTab = DGS:dgsGetSelectedTab(tabPanel)
        local gridlist = getElementChildren(selectedTab, "dgs-dxgridlist")[1]
        local row, col = DGS:dgsGridListGetSelectedItem(gridlist)
        if row ~= -1 and col ~= -1 then
            
            local modId = DGS:dgsGridListGetItemData(gridlist, row, 1)
            local modName = DGS:dgsGridListGetItemText(gridlist, row, 1)
            local activated = DGS:dgsGridListGetItemText(gridlist, row, 3)
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
                    DGS:dgsSetEnabled(mainWindow, false)
                    toggleModFromGUI(modId, modName, false, true)
                end
            end
        end
    end, false)


    y = y + 40 + 10
    x = x - 100 - 10

    local enableAllButton = DGS:dgsCreateButton(x, y, 100, 40, "Enable All", false, mainWindow)
    DGS:dgsSetProperty(enableAllButton, "color", GREEN_COLOR)
    addEventHandler("onDgsMouseClickUp", enableAllButton, function()

        if lastGuiSpamEvent then
            if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                outputCustomMessage(getSetting("msg_too_fast"), "error")
                return
            end
        end
        lastGuiSpamEvent = getTickCount()

        local allTabs = getElementChildren(tabPanel, "dgs-dxtab")
        local toToggle = {}
        for i=1, #allTabs do
            local tab = allTabs[i]
            if tab then
                local gridlist = getElementChildren(tab, "dgs-dxgridlist")[1]
                local total = DGS:dgsGridListGetRowCount(gridlist)
                for row = 1, total do
                    local modId = DGS:dgsGridListGetItemData(gridlist, row, 1)
                    local modName = DGS:dgsGridListGetItemText(gridlist, row, 1)
                    local activated = DGS:dgsGridListGetItemText(gridlist, row, 3)
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
                    if DGS:dgsGetEnabled(mainWindow) then
                        DGS:dgsSetEnabled(mainWindow, false)
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

    local disableAllButton = DGS:dgsCreateButton(x, y, 100, 40, "Disable All", false, mainWindow)
    DGS:dgsSetProperty(disableAllButton, "color", RED_COLOR)
    addEventHandler("onDgsMouseClickUp", disableAllButton, function()

        if lastGuiSpamEvent then
            if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                outputCustomMessage(getSetting("msg_too_fast"), "error")
                return
            end
        end
        lastGuiSpamEvent = getTickCount()
        
        local allTabs = getElementChildren(tabPanel, "dgs-dxtab")
        local toToggle = {}
        for i=1, #allTabs do
            local tab = allTabs[i]
            if tab then
                local gridlist = getElementChildren(tab, "dgs-dxgridlist")[1]
                local total = DGS:dgsGridListGetRowCount(gridlist)
                for row = 1, total do
                    local modId = DGS:dgsGridListGetItemData(gridlist, row, 1)
                    local modName = DGS:dgsGridListGetItemText(gridlist, row, 1)
                    local activated = DGS:dgsGridListGetItemText(gridlist, row, 3)
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
                    if DGS:dgsGetEnabled(mainWindow) then
                        DGS:dgsSetEnabled(mainWindow, false)
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

    local closeButton = DGS:dgsCreateButton(x, y, 100, 40, "Close", false, mainWindow)
    addEventHandler("onDgsMouseClickUp", closeButton, function()
        DGS:dgsSetVisible(mainWindow, false)
        showCursor(false)
    end, false)

    y = y + 40 + 10
       
    local refreshButton = DGS:dgsCreateButton(x, y, 100, 40, "Refresh", false, mainWindow)
    DGS:dgsSetProperty(refreshButton, "color", YELLOW_COLOR)
    addEventHandler("onDgsMouseClickUp", refreshButton, function()
        DGS:dgsSetEnabled(mainWindow, false)
        triggerServerEvent("modDownloader:requestRefreshMods", root, localPlayer)
    end, false)
    DGS:dgsSetVisible(refreshButton, false)

    addEventHandler("onDgsMouseClickUp", mainWindow, function()
        local selectedTab = DGS:dgsGetSelectedTab(tabPanel)
        if selectedTab then
            local gridlist = getElementChildren(selectedTab, "dgs-dxgridlist")[1]
            
            if selectedTabName and selectedTabName ~= DGS:dgsGetText(selectedTab) then
                local selectedTab = DGS:dgsGetSelectedTab(tabPanel)
                DGS:dgsGridListSetSelectedItem(gridlist, -1, -1)
                selectedRow = nil
                DGS:dgsSetEnabled(enableButton, false)
                DGS:dgsSetEnabled(disableButton, false)
            else
                local row, col = DGS:dgsGridListGetSelectedItem(gridlist)
                if row ~= -1 and col ~= -1 then
                    local activated = DGS:dgsGridListGetItemText(gridlist, row, 3)
                    if activated == getSetting("gui_yes") then
                        DGS:dgsSetEnabled(enableButton, false)
                        DGS:dgsSetEnabled(disableButton, true)
                    else
                        DGS:dgsSetEnabled(enableButton, true)
                        DGS:dgsSetEnabled(disableButton, false)
                    end
                    selectedRow = row
                else
                    selectedRow = nil
                    DGS:dgsSetEnabled(enableButton, false)
                    DGS:dgsSetEnabled(disableButton, false)
                end
            end
            selectedTabName = DGS:dgsGetText(selectedTab)
        end
    end)
end)

addEventHandler("modDownloader:reenableModPanel", localPlayer, function()
    if not isElement(mainWindow) then return end
    if DGS:dgsGetVisible(mainWindow) and not DGS:dgsGetEnabled(mainWindow) then
        DGS:dgsSetEnabled(mainWindow, true)
    end
end)

local function populateCategoryTab(tab, category, mod)

    local children = getElementChildren(tab, "dgs-dxgridlist")
    local gridlist
    if children[1] then
        gridlist = children[1]
    else
        gridlist = DGS:dgsCreateGridList(0, 0, 1, 1, true, tab)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_name"), 0.25)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_replaces"), 0.25)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_enabled"), 0.2)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_ready"), 0.2)

        local enableButton = getElementChildren(mainWindow, "dgs-dxbutton")[1]
        local disableButton = getElementChildren(mainWindow, "dgs-dxbutton")[2]
    end


    local row = DGS:dgsGridListAddRow(gridlist)

    DGS:dgsGridListSetItemText(gridlist, row, 1, mod.name, false, false)
    DGS:dgsGridListSetItemData(gridlist, row, 1, mod.id)

    DGS:dgsGridListSetItemText(gridlist, row, 2, mod.replaces, false, false)
    if mod.activated then
        DGS:dgsGridListSetItemText(gridlist, row, 3, getSetting("gui_yes"), false, false)
        DGS:dgsGridListSetItemColor(gridlist, row, 3, 0, 255, 0)
    else
        DGS:dgsGridListSetItemText(gridlist, row, 3, getSetting("gui_no"), false, false)
        DGS:dgsGridListSetItemColor(gridlist, row, 3, 255, 69, 69)
    end
    if not mod.pendingDownloads then
        DGS:dgsGridListSetItemText(gridlist, row, 4, getSetting("gui_yes"), false, false)
        DGS:dgsGridListSetItemColor(gridlist, row, 4, 0, 255, 0)
    else
        DGS:dgsGridListSetItemText(gridlist, row, 4, getSetting("gui_no"), false, false)
        DGS:dgsGridListSetItemColor(gridlist, row, 4, 255, 69, 69)
    end
end

function populateModsGUI()
    if not isElement(mainWindow) then return end

    local myMods = getReceivedMods()
    if not myMods then return end
    
    local tabPanel = getElementChildren(mainWindow, "dgs-dxtabpanel")[1]

    local tabs = getElementChildren(tabPanel, "dgs-dxtab")
    for i=1, #tabs do
        local tab = tabs[i]
        if tab then
            DGS:dgsDeleteTab(tabs[i], tabPanel)
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
            local tab = DGS:dgsCreateTab(category, tabPanel)
            for i=1, #mods do
                local mod = mods[i]
                if mod then
                    populateCategoryTab(tab, category, mod)
                end
            end
        end
    end

    if (selectedTabName ~= nil) then
        tabs = getElementChildren(tabPanel, "dgs-dxtab")
        for i=1, #tabs do
            local tab = tabs[i]
            if tab then
                if DGS:dgsGetText(tab) == selectedTabName then
                    DGS:dgsSetSelectedTab(tabPanel, tab)
                    break
                end
            end
        end
    end

    if (selectedRow ~= nil) then
        local tab = DGS:dgsGetSelectedTab(tabPanel)
        local gridlist = getElementChildren(tab, "dgs-dxgridlist")[1]
        if DGS:dgsGridListGetRowCount(gridlist) >= selectedRow then
            DGS:dgsGridListSetSelectedItem(gridlist, selectedRow, 1)
        end
    end

    local buttons = getElementChildren(mainWindow, "dgs-dxbutton")
    DGS:dgsSetText(buttons[1], getSetting("gui_btn_enable"))
    DGS:dgsSetText(buttons[2], getSetting("gui_btn_disable"))
    DGS:dgsSetText(buttons[3], getSetting("gui_btn_enableall"))
    DGS:dgsSetText(buttons[4], getSetting("gui_btn_disableall"))
    DGS:dgsSetText(buttons[5], getSetting("gui_btn_close"))

    if getSetting("allow_refresh_mods") then
        DGS:dgsSetVisible(buttons[6], true)
        DGS:dgsSetText(buttons[6], getSetting("gui_btn_refresh"))
    else
        DGS:dgsSetVisible(buttons[6], false)
    end

    DGS:dgsSetText(mainWindow, getSetting("gui_title"))
    DGS:dgsSetText(getElementChildren(mainWindow, "dgs-dxlabel")[1], getSetting("gui_description"))

    -- Re-enable window
    if not DGS:dgsGetEnabled(mainWindow) then
        DGS:dgsSetEnabled(mainWindow, true)
    end
end

function toggleGUIPanel()
    if not isElement(mainWindow) then return end

    if DGS:dgsGetVisible(mainWindow) then
        DGS:dgsSetVisible(mainWindow, false)
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
    if not isElement(mainWindow) then return end
    if not DGS:dgsGetVisible(mainWindow) then
        DGS:dgsSetVisible(mainWindow, true)
        showCursor(true)
    end
end)

--[[
    Downloading dialog triggered by system_client.lua
]]
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
