ServerPlayerCountStatusEvent = {}
local ServerPlayerCountStatusEvent_mt = Class(ServerPlayerCountStatusEvent, Event)

InitEventClass(ServerPlayerCountStatusEvent, "ServerPlayerCountStatusEvent")

function ServerPlayerCountStatusEvent.emptyNew()
    local self = Event.new(ServerPlayerCountStatusEvent_mt)
    return self
end

function ServerPlayerCountStatusEvent.new(state, isResetRequest)
    local self = ServerPlayerCountStatusEvent.emptyNew()
    self.state = state or 0
    self.isResetRequest = isResetRequest == true
    return self
end

function ServerPlayerCountStatusEvent:readStream(streamId, connection)
    self.state = streamReadUIntN(streamId, 2)
    self.isResetRequest = streamReadBool(streamId)
    self:run(connection)
end

function ServerPlayerCountStatusEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.state or 0, 2)
    streamWriteBool(streamId, self.isResetRequest == true)
end

function ServerPlayerCountStatusEvent:run(connection)
    if self.isResetRequest then
        if g_server ~= nil and not connection:getIsServer() and ServerPlayerCount:getIsConnectionMasterUser(connection) then
            ServerPlayerCount:setServerLogState(0, true)
        end
    elseif connection:getIsServer() then
        ServerPlayerCount:setServerLogState(self.state or 0, false)
    end
end

ServerPlayerCount = {}
ServerPlayerCount.modDirectory = g_currentModDirectory
ServerPlayerCount.modName = g_currentModName

ServerPlayerCount.hudOverlays = nil
ServerPlayerCount.currentPlayers = 1
ServerPlayerCount.maxPlayers = nil
ServerPlayerCount.updateTimer = 0
ServerPlayerCount.syncTimer = 0
ServerPlayerCount.serverLogState = 0
ServerPlayerCount.stateDirty = false
ServerPlayerCount.showWarnings = false
ServerPlayerCount.resetButton = nil
ServerPlayerCount.warningsButton = nil
ServerPlayerCount.settingsHeader = nil
ServerPlayerCount.settingsRow = nil
ServerPlayerCount.warningsRow = nil
ServerPlayerCount.settingsInitialized = false
ServerPlayerCount.textColor = {1, 1, 1, 1}
ServerPlayerCount.okColor = {0.55, 0.85, 0.10, 1}
ServerPlayerCount.warningColor = {0.95, 0.72, 0.05, 1}
ServerPlayerCount.errorColor = {0.9, 0.05, 0.03, 1}

function ServerPlayerCount:loadMap()
    self:initializeSettingsButton()
end

function ServerPlayerCount:update(dt)
    if g_currentMission == nil or not self:isMultiplayerSession() then
        return
    end

    self.updateTimer = self.updateTimer + dt
    self.syncTimer = self.syncTimer + dt

    if self.updateTimer > 1000 then
        self.updateTimer = 0
        self.currentPlayers = self:getActivePlayerCount()
        self.maxPlayers = self:getServerCapacity()
    end

    if g_server ~= nil and self.stateDirty then
        self.stateDirty = false
        self.syncTimer = 0
        self:broadcastServerLogState()
    end

    if g_server ~= nil and self.syncTimer > 5000 then
        self.syncTimer = 0
        self:broadcastServerLogState()
    end
end

function ServerPlayerCount:deleteMap()
    if self.hudOverlays ~= nil then
        for _, overlay in pairs(self.hudOverlays) do
            overlay:delete()
        end
        self.hudOverlays = nil
    end
end

function ServerPlayerCount:getHudOverlays()
    if self.hudOverlays ~= nil then
        return self.hudOverlays
    end

    if g_overlayManager == nil or HUD == nil or HUD.COLOR == nil or HUD.COLOR.BACKGROUND == nil then
        return nil
    end

    local overlays = {
        bgLeft = g_overlayManager:createOverlay("gui.gameInfo_left", 0, 0, 0, 0),
        bgScale = g_overlayManager:createOverlay("gui.gameInfo_middle", 0, 0, 0, 0),
        bgRight = g_overlayManager:createOverlay("gui.gameInfo_right", 0, 0, 0, 0),
        icon = g_overlayManager:createOverlay("gui.icon_multiplayer", 0, 0, 0, 0),
        stateDot = g_overlayManager:createOverlay("gui.whiteCircleFilled", 0, 0, 0, 0)
    }

    if overlays.bgLeft == nil or overlays.bgScale == nil or overlays.bgRight == nil or overlays.icon == nil or overlays.stateDot == nil then
        return nil
    end

    local r, g, b, a = unpack(HUD.COLOR.BACKGROUND)
    overlays.bgLeft:setColor(r, g, b, a)
    overlays.bgScale:setColor(r, g, b, a)
    overlays.bgRight:setColor(r, g, b, a)

    self.hudOverlays = overlays
    return overlays
end

function ServerPlayerCount:drawOverlay(display)
    if g_currentMission == nil or not self:isMultiplayerSession() then
        return
    end

    local anchor = display.infoBgLeft
    local overlays = self:getHudOverlays()
    if anchor == nil or overlays == nil then
        return
    end

    local count = self.currentPlayers or 1
    local maxPlayers = self.maxPlayers or 0
    local valueText
    if maxPlayers > 0 then
        valueText = string.format("%d / %d", count, maxPlayers)
    else
        valueText = string.format("%d", count)
    end

    local stateColor = self.okColor
    if self.serverLogState == 1 then
        stateColor = self.warningColor
    elseif self.serverLogState >= 2 then
        stateColor = self.errorColor
    end

    local height = anchor.height
    local posY = anchor.y
    local capWidth = display:scalePixelToScreenWidth(10)
    local boxSpacing = display:scalePixelToScreenWidth(8)
    local spacing = display:scalePixelToScreenWidth(8)
    local iconWidth, iconHeight = display:scalePixelValuesToScreenVector(40, 40)
    local dotWidth, dotHeight = display:scalePixelValuesToScreenVector(12, 12)
    local textSize = display:scalePixelToScreenHeight(17)
    local textOffsetY = display:scalePixelToScreenHeight(27)

    setTextBold(false)
    local textWidth = getTextWidth(textSize, valueText)
    local scaleWidth = iconWidth + spacing + textWidth + spacing + dotWidth
    local posX = anchor.x-boxSpacing-capWidth-scaleWidth-capWidth

    overlays.bgLeft:setPosition(posX, posY)
    overlays.bgLeft:setDimension(capWidth, height)
    overlays.bgLeft:render()

    overlays.bgScale:setPosition(posX + capWidth, posY)
    overlays.bgScale:setDimension(scaleWidth, height)
    overlays.bgScale:render()

    overlays.bgRight:setPosition(posX + capWidth + scaleWidth, posY)
    overlays.bgRight:setDimension(capWidth, height)
    overlays.bgRight:render()

    local iconX = posX + capWidth
    overlays.icon:setPosition(iconX, posY + (height-iconHeight) * 0.5)
    overlays.icon:setDimension(iconWidth, iconHeight)
    overlays.icon:render()

    local textX = iconX + iconWidth + spacing
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4])
    renderText(textX, posY + textOffsetY, textSize, valueText)

    overlays.stateDot:setColor(stateColor[1], stateColor[2], stateColor[3], stateColor[4])
    overlays.stateDot:setPosition(textX + textWidth + spacing, posY + (height-dotHeight) * 0.5)
    overlays.stateDot:setDimension(dotWidth, dotHeight)
    overlays.stateDot:render()

    setTextColor(1, 1, 1, 1)
end


function ServerPlayerCount:isMultiplayerSession()
    if g_currentMission == nil then
        return false
    end

    if g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.isMultiplayer ~= nil then
        return g_currentMission.missionDynamicInfo.isMultiplayer
    end

    if g_currentMission.missionInfo ~= nil and g_currentMission.missionInfo.isMultiplayer ~= nil then
        return g_currentMission.missionInfo.isMultiplayer
    end

    if g_currentMission.missionDynamicInfo ~= nil and g_currentMission.missionDynamicInfo.serverName ~= nil and g_currentMission.missionDynamicInfo.serverName ~= "" then
        return true
    end

    return g_client ~= nil and g_server == nil
end

local function findSettingsTemplates(element, depth, result)
    if element == nil or depth > 6 then
        return
    end

    if result.sectionHeader == nil and element.name == "sectionHeader" then
        result.sectionHeader = element
    end

    if result.buttonElement == nil and element.typeName == "Bitmap" and element.elements ~= nil then
        for _, child in pairs(element.elements) do
            if child.typeName == "Button" then
                result.buttonElement = element
                break
            end
        end
    end

    if element.elements ~= nil then
        for _, child in pairs(element.elements) do
            findSettingsTemplates(child, depth + 1, result)
        end
    end
end

local function createSettingsButtonRow(scrollPanel, buttonElement, labelText, buttonText, buttonId, onClickCallback)
    local row = buttonElement:clone(scrollPanel)
    row.id = nil

    local buttonInRow = nil

    for _, element in pairs(row.elements) do
        if element.typeName == "Text" then
            element:setText(labelText)
            element.id = nil
        elseif element.typeName == "Button" then
            element:setText(buttonText)
            element.isAlwaysFocusedOnOpen = false
            element.focused = false
            element.id = buttonId
            element.onClickCallback = onClickCallback
            buttonInRow = element
        end
    end

    return row, buttonInRow
end

function ServerPlayerCount:initializeSettingsButton()
    if self.settingsInitialized or g_inGameMenu == nil or g_inGameMenu.pageSettings == nil then
        return
    end

    local settingsPage = g_inGameMenu.pageSettings
    local scrollPanel = settingsPage.gameSettingsLayout

    if scrollPanel == nil or scrollPanel.elements == nil then
        return
    end

    local templates = {}
    findSettingsTemplates(settingsPage, 0, templates)

    if templates.sectionHeader == nil or templates.buttonElement == nil then
        return
    end

    local header = templates.sectionHeader:clone(scrollPanel)
    header:setText(g_i18n:getText("spc_settings_header"))
    self.settingsHeader = header

    self.settingsRow, self.resetButton = createSettingsButtonRow(
        scrollPanel,
        templates.buttonElement,
        g_i18n:getText("spc_settings_resetStatus_label"),
        g_i18n:getText("spc_settings_resetStatus_button"),
        "spc_resetStatus",
        ServerPlayerCount.onSettingsButtonClick
    )

    self.warningsRow, self.warningsButton = createSettingsButtonRow(
        scrollPanel,
        templates.buttonElement,
        g_i18n:getText("spc_settings_showWarnings_label"),
        self:getShowWarningsButtonText(),
        "spc_showWarnings",
        ServerPlayerCount.onSettingsButtonClick
    )

    scrollPanel:invalidateLayout()
    self.settingsInitialized = true
end

function ServerPlayerCount.onSettingsButtonClick(_, state, button)
    if button == nil then
        button = state
    end

    if button == nil then
        return
    end

    if button.id == "spc_resetStatus" then
        ServerPlayerCount:resetServerLogState()
    elseif button.id == "spc_showWarnings" then
        ServerPlayerCount:toggleShowWarnings()
    end
end

function ServerPlayerCount:onSettingsFrameOpen()
    local isMultiplayer = self:isMultiplayerSession()
    local isServer = g_server ~= nil

    if self.settingsHeader ~= nil then
        self.settingsHeader:setVisible(isMultiplayer)
    end

    if self.settingsRow ~= nil then
        self.settingsRow:setVisible(isMultiplayer)
    end

    if self.resetButton ~= nil then
        self.resetButton:setDisabled(not (isMultiplayer and self:getCanResetServerLogState()))
    end

    if self.warningsRow ~= nil then
        self.warningsRow:setVisible(isMultiplayer and isServer)
    end

    if self.warningsButton ~= nil then
        self.warningsButton:setText(self:getShowWarningsButtonText())
        self.warningsButton:setDisabled(not (isMultiplayer and isServer))
    end
end

function ServerPlayerCount:getShowWarningsButtonText()
    if self.showWarnings then
        return g_i18n:getText("spc_settings_showWarnings_on")
    end
    return g_i18n:getText("spc_settings_showWarnings_off")
end

function ServerPlayerCount:toggleShowWarnings()
    if g_server == nil then
        return
    end

    self.showWarnings = not self.showWarnings
    if not self.showWarnings and self.serverLogState == 1 then
        self:setServerLogState(0, true)
    end

    if self.warningsButton ~= nil then
        self.warningsButton:setText(self:getShowWarningsButtonText())
    end
end

function ServerPlayerCount:getActivePlayerCount()
    local count = 0
    local seen = {}
    local serverUserIds = self:getServerUserIds()

    if g_currentMission ~= nil and g_currentMission.playerSystem ~= nil and g_currentMission.playerSystem.players ~= nil then
        for _, player in pairs(g_currentMission.playerSystem.players) do
            if player ~= nil and not self:isServerPlayerEntry(player, serverUserIds) then
                local key = player.userId or player.uniqueUserId or player.playerId or player.rootNode or player
                if key ~= nil and not seen[key] then
                    seen[key] = true
                    count = count + 1
                end
            end
        end
    end

    if count > 0 then
        return count
    end

    if g_currentMission ~= nil and g_currentMission.player ~= nil and not self:isServerPlayerEntry(g_currentMission.player, serverUserIds) then
        return 1
    end

    return 0
end

function ServerPlayerCount:getServerUserIds()
    local serverUserIds = {}

    if g_currentMission ~= nil and g_currentMission.userManager ~= nil and g_currentMission.userManager.users ~= nil then
        for _, user in pairs(g_currentMission.userManager.users) do
            if user ~= nil and user.nickname == "Server" and user.uniqueUserId ~= nil then
                serverUserIds[user.uniqueUserId] = true
            end
        end
    end

    return serverUserIds
end

function ServerPlayerCount:isServerPlayerEntry(player, serverUserIds)
    if player == nil then
        return true
    end

    if player.uniqueUserId ~= nil and serverUserIds ~= nil and serverUserIds[player.uniqueUserId] then
        return true
    end

    if player.farmId ~= nil and player.farmId == 0 and g_server ~= nil and g_client ~= nil then
        return true
    end

    return false
end

function ServerPlayerCount:getServerCapacity()
    if g_currentMission ~= nil and g_currentMission.missionDynamicInfo ~= nil then
        local capacity = g_currentMission.missionDynamicInfo.capacity
        if type(capacity) == "number" and capacity > 0 then
            return capacity
        end
    end

    if g_server ~= nil and g_server.maxNumClients ~= nil then
        local maxNumClients = g_server.maxNumClients
        if type(maxNumClients) == "number" and maxNumClients > 0 then
            return maxNumClients
        end
    end

    return nil
end

function ServerPlayerCount:setServerLogState(state, broadcast)
    state = state or 0
    if state > self.serverLogState or state == 0 then
        self.serverLogState = state
        if broadcast then
            self:broadcastServerLogState()
        end
    end
end

function ServerPlayerCount:broadcastServerLogState()
    if g_server ~= nil then
        g_server:broadcastEvent(ServerPlayerCountStatusEvent.new(self.serverLogState, false))
    end
end

function ServerPlayerCount:getIsConnectionMasterUser(connection)
    local userManager = g_currentMission ~= nil and g_currentMission.userManager or nil
    if userManager == nil then
        return false
    end

    local user = userManager:getUserByConnection(connection)
    return user ~= nil and user:getIsMasterUser()
end

function ServerPlayerCount:getCanResetServerLogState()
    if g_server ~= nil then
        return true
    end

    return g_currentMission ~= nil and g_currentMission.isMasterUser == true
end

function ServerPlayerCount:resetServerLogState()
    if g_server ~= nil then
        self:setServerLogState(0, true)
    elseif g_client ~= nil then
        if self:getCanResetServerLogState() then
            g_client:getServerConnection():sendEvent(ServerPlayerCountStatusEvent.new(0, true))
        end
    else
        self:setServerLogState(0, false)
    end
end

function ServerPlayerCount:reportLogMessage(state)
    if g_server == nil then
        return
    end

    if state == 1 and not self.showWarnings then
        return
    end

    if state > self.serverLogState then
        self.serverLogState = state
        self.stateDirty = true
    end
end

local function getSettingsFilePath()
    if g_currentMission == nil or g_currentMission.missionInfo == nil then
        return nil
    end

    local savegameDir = g_currentMission.missionInfo.savegameDirectory
    if savegameDir == nil then
        return nil
    end

    return savegameDir .. "/serverPlayerCount.xml"
end

function ServerPlayerCount:loadSettings()
    self.showWarnings = false

    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    local path = getSettingsFilePath()
    if path == nil or not fileExists(path) then
        return
    end

    local xmlFile = XMLFile.load("spcSettingsXML", path)
    if xmlFile == nil then
        return
    end

    self.showWarnings = xmlFile:getBool("serverPlayerCount.settings#showWarnings", false)
    xmlFile:delete()
end

function ServerPlayerCount:saveSettings()
    if g_currentMission == nil or not g_currentMission:getIsServer() then
        return
    end

    local path = getSettingsFilePath()
    if path == nil then
        return
    end

    local xmlFile = XMLFile.create("spcSettingsXML", path, "serverPlayerCount")
    if xmlFile == nil then
        return
    end

    xmlFile:setBool("serverPlayerCount.settings#showWarnings", self.showWarnings)
    xmlFile:save()
    xmlFile:delete()
end

addModEventListener(ServerPlayerCount)

FSBaseMission.loadMapFinished = Utils.appendedFunction(FSBaseMission.loadMapFinished, function()
    ServerPlayerCount:loadSettings()
end)

FSCareerMissionInfo.saveToXMLFile = Utils.appendedFunction(FSCareerMissionInfo.saveToXMLFile, function()
    ServerPlayerCount:saveSettings()
end)


if GameInfoDisplay ~= nil and GameInfoDisplay.draw ~= nil then
    GameInfoDisplay.draw = Utils.appendedFunction(GameInfoDisplay.draw, function(display)
        if display ~= nil and type(display.getVisible) == "function" and display:getVisible() then
            ServerPlayerCount:drawOverlay(display)
        end
    end)
end


InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    ServerPlayerCount:onSettingsFrameOpen()
end)

local function wrapLogFunction(owner, name, state)
    local original = owner[name]
    if type(original) ~= "function" then
        return
    end

    owner[name] = function(...)
        ServerPlayerCount:reportLogMessage(state)
        return original(...)
    end
end

if Logging ~= nil then
    wrapLogFunction(Logging, "warning", 1)
    wrapLogFunction(Logging, "xmlWarning", 1)
    wrapLogFunction(Logging, "error", 2)
    wrapLogFunction(Logging, "xmlError", 2)
end

local function getGlobalEnvironment()
    local environment = getfenv(0)
    local metatable = getmetatable(environment)
    if metatable ~= nil and type(metatable.__index) == "table" then
        return metatable.__index
    end
    return environment
end

local globalEnvironment = getGlobalEnvironment()
wrapLogFunction(globalEnvironment, "printWarning", 1)
wrapLogFunction(globalEnvironment, "printError", 2)

if setLuaErrorHandler ~= nil then
    setLuaErrorHandler(function(message)
        ServerPlayerCount:reportLogMessage(2)
        return message
    end)
end
