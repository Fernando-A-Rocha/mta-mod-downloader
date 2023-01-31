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
        - Added dgsSetProperty columnTextColor for the gridlist
]]

local COLOR_COL_TEXT = 0xffc8c8c8
local COLOR_BTN_BG_GREEN = 0xff2b6907
local COLOR_BTN_BG_RED = 0xff690707
local COLOR_BTN_BG_YELLOW = 0xff696907

-- Internal events
addEvent("modDownloader:openModPanel", true)
addEvent("modDownloader:reenableModPanel", true)

-- Constants
local SW, SH = guiGetScreenSize()

-- Variables
local mainWindow = nil
local requestWindow = nil
local selectedTabName = nil
local selectedRow = nil
local lastGuiSpamEvent = nil

local DGS = nil -- DGS specific

--[[
    Mod Downloader Panel GUI
]]

addEventHandler("onClientResourceStart", resourceRoot, function()

    local dgsResource = getResourceFromName("dgs")
    dgsResource = dgsResource and getResourceState(dgsResource) == "running"
    if not dgsResource then
        outputDebugString("DGS is not running, custom GUI won't work.", 1)
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
    DGS:dgsSetVisible(enableButton, false)
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
    DGS:dgsSetVisible(disableButton, false)
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

        -- local allTabs = getElementChildren(tabPanel, "dgs-dxtab")
        local toToggle = {}
        -- for i=1, #allTabs do
            -- local tab = allTabs[i]
            local tab = DGS:dgsGetSelectedTab(tabPanel)
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
        -- end
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
        
        -- local allTabs = getElementChildren(tabPanel, "dgs-dxtab")
        local toToggle = {}
        -- for i=1, #allTabs do
            -- local tab = allTabs[i]
            local tab = DGS:dgsGetSelectedTab(tabPanel)
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
        -- end
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
                DGS:dgsSetVisible(enableButton, false)
                DGS:dgsSetVisible(disableButton, false)
            else
                local row, col = DGS:dgsGridListGetSelectedItem(gridlist)
                if row ~= -1 and col ~= -1 then
                    local categoryGroupMods = DGS:dgsGridListGetItemData(gridlist, row, 2)
                    if categoryGroupMods == true then
                        DGS:dgsSetVisible(enableButton, false)
                        DGS:dgsSetVisible(disableButton, false)
                    else
                        DGS:dgsSetVisible(enableButton, true)
                        DGS:dgsSetVisible(disableButton, true)
                    end
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
                    DGS:dgsSetVisible(enableButton, false)
                    DGS:dgsSetVisible(disableButton, false)
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
        DGS:dgsSetProperty(gridlist, "columnTextColor", COLOR_COL_TEXT) -- DGS specific
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_name"), 0.3)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_replaces"), 0.3)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_enabled"), 0.2)
        DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_ready"), 0.2)

        local enableButton = getElementChildren(mainWindow, "dgs-dxbutton")[1]
        local disableButton = getElementChildren(mainWindow, "dgs-dxbutton")[2]
    end

    local row = DGS:dgsGridListAddRow(gridlist)

    DGS:dgsGridListSetItemText(gridlist, row, 1, mod.name, false, false)
    DGS:dgsGridListSetItemData(gridlist, row, 1, mod.id)

    DGS:dgsGridListSetItemText(gridlist, row, 2, mod.replaces, false, false)
    DGS:dgsGridListSetItemData(gridlist, row, 2, mod.categoryGroupMods)

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
            local k = nil
            for k_ = 1, #modsByCategory do
                local info = modsByCategory[k_]
                if info then
                    if mod.category == info.category then
                        k = k_
                        break
                    end
                end
            end
            if not k then
                k = #modsByCategory+1
                modsByCategory[k] = {category=mod.category, mods={}}
            end
            modsByCategory[k].mods[#(modsByCategory[k].mods) + 1] = mod
        end
    end
    for i=1, #modsByCategory do
        local info = modsByCategory[i]
        if info then
            local category = info.category
            local mods = info.mods
            if #mods > 0 then
                local tab = DGS:dgsCreateTab(category, tabPanel)
                for i=1, #mods do
                    local mod = mods[i]
                    if mod then
                        populateCategoryTab(tab, category, mod)
                    end
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

    -- Don't show the mod loader GUI main window if a request window is open
    if isElement(requestWindow) then
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
    Request/Force Mods
]]
local function closeRequestWindow()
    if isElement(requestWindow) then
        destroyElement(requestWindow)
    end
    requestWindow = nil
    showCursor(false)
end

function openRequestToggleModsDialog(requestList, options)
    
    if DGS:dgsGetVisible(mainWindow) then
        DGS:dgsSetVisible(mainWindow, false)
    end

    if isElement(requestWindow) then
        destroyElement(requestWindow)
    end

    local enable = options.enable or false

    local WW, WH = 800, 150
    local glHeight = (#requestList * 25)
    WH = WH + glHeight

    requestWindow = DGS:dgsCreateWindow((SW-WW)/2, (SH-WH)/2, WW, WH, getSetting("gui_request_title"), false)
    DGS:dgsSetProperty(requestWindow, "ignoreTitle", true) -- DGS specific
    DGS:dgsWindowSetSizable(requestWindow, false)
    DGS:dgsWindowSetMovable(requestWindow, false)

    local x, y = 20, 30

    local textDesc = getSetting("gui_request_enable")
    if not enable then
        textDesc = getSetting("gui_request_disable")
    end
    local textDescLines = (string.find(textDesc, "\n") or 0) + 1
    local infoLabelHeight = (20 * textDescLines)

    local infoLabel = DGS:dgsCreateLabel(x, y, WW-(x*2), infoLabelHeight, textDesc, false, requestWindow)
    DGS:dgsLabelSetHorizontalAlign(infoLabel, "center", true)
    DGS:dgsLabelSetVerticalAlign(infoLabel, "center")

    y = y + infoLabelHeight + 10

    glHeight = glHeight + 30

    local gridlist = DGS:dgsCreateGridList(x, y, WW-(x*2), glHeight, false, requestWindow)
    DGS:dgsSetProperty(gridlist, "columnTextColor", COLOR_COL_TEXT) -- DGS specific
    
    DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_name"), 0.3)
    DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_replaces"), 0.25)
    DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_enabled"), 0.2)
    DGS:dgsGridListAddColumn(gridlist, getSetting("gui_grid_col_ready"), 0.2)

    for i=1, #requestList do
        local mod = requestList[i]
        if mod then
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
    end

    y = y + glHeight + 10

    local buttons = {}
    local buttonPositions = {}
    
    if enable then
        buttonPositions["enableall"] = {x, y, "FF00FF00"}
    else
        buttonPositions["disableall"] = {x, y, "ffff3c00"}
    end

    local function clickBtn()
        local name
        for k, v in pairs(buttonPositions) do
            if source == buttons[k] then
                name = k
                break
            end
        end
        if name == "enableall" or name == "disableall" then

            if lastGuiSpamEvent then
                if getTickCount() - lastGuiSpamEvent < getSetting("anti_spam_delay_gui_buttons") then
                    outputCustomMessage(getSetting("msg_too_fast"), "error")
                    return
                end
            end
            lastGuiSpamEvent = getTickCount()
    
            local toToggle = {}
            local total = DGS:dgsGridListGetRowCount(gridlist)
            for row = 1, total do
                local modId = DGS:dgsGridListGetItemData(gridlist, row, 1)
                local modName = DGS:dgsGridListGetItemText(gridlist, row, 1)
                local activated = DGS:dgsGridListGetItemText(gridlist, row, 3)
                if activated == (name == "enableall" and getSetting("gui_no") or getSetting("gui_yes")) then
                    toToggle[#toToggle+1] = {modId, modName}
                end
            end
            if #toToggle > 0 then
                local affected = 0
                for i=1, #toToggle do
                    local modId, modName = tonumber(toToggle[i][1]), toToggle[i][2]
                    if (name == "enableall" and canEnableMod(modId) or canDisableMod(modId)) then
                        if DGS:dgsGetEnabled(requestWindow) then
                            DGS:dgsSetEnabled(requestWindow, false)
                        end
                        toggleModFromGUI(modId, modName, (name == "enableall" and true or false), false)
                        affected = affected + 1
                    end
                end
                if affected > 0 then
                    closeRequestWindow()
                    if name == "enableall" then
                        outputCustomMessage(getSetting("msg_mod_activated_all").." ("..#toToggle..")", "success")
                    else
                        outputCustomMessage(getSetting("msg_mod_deactivated_all").." ("..#toToggle..")", "info")
                    end
                end
            end
        end
    end
    
    for name, pos in pairs(buttonPositions) do
        buttons[name] = DGS:dgsCreateButton(pos[1], pos[2], 100, 35, getSetting("gui_btn_"..name), false, requestWindow)
        local DEFAULT_BTN_COLOR = DGS:dgsGetProperty(buttons[name], "color")
        local GREEN_COLOR = {COLOR_BTN_BG_GREEN, DEFAULT_BTN_COLOR[2], DEFAULT_BTN_COLOR[3]}
        local RED_COLOR = {COLOR_BTN_BG_RED, DEFAULT_BTN_COLOR[2], DEFAULT_BTN_COLOR[3]}
        if name == "enableall" then
            DGS:dgsSetProperty(buttons[name], "color", GREEN_COLOR)
        else
            DGS:dgsSetProperty(buttons[name], "color", RED_COLOR)
        end
        addEventHandler("onDgsMouseClickUp", buttons[name], clickBtn, false)
    end

    local closeButton = DGS:dgsCreateButton(WW-120, y, 100, 35, getSetting("gui_btn_close"), false, requestWindow)
    addEventHandler("onDgsMouseClickUp", closeButton, closeRequestWindow, false)
    
    showCursor(true)
end

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
