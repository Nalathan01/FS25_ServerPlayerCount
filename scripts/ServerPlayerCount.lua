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
        if g_server ~= nil then
            ServerPlayerCount:setServerLogState(0, true)
        end
    else
        ServerPlayerCount:setServerLogState(self.state or 0, false)
    end
end

ServerPlayerCount = {}

ServerPlayerCount.hudX = 0.985
ServerPlayerCount.hudY = 0.975
ServerPlayerCount.textSize = 0.012
ServerPlayerCount.boxWidth = 0.048
ServerPlayerCount.boxHeight = 0.020
ServerPlayerCount.iconOffsetX = 0.006
ServerPlayerCount.iconOffsetY = 0.006
ServerPlayerCount.iconSize = 0.005
ServerPlayerCount.textOffsetX = 0.020
ServerPlayerCount.textOffsetY = 0.0045
ServerPlayerCount.currentPlayers = 1
ServerPlayerCount.maxPlayers = nil
ServerPlayerCount.updateTimer = 0
ServerPlayerCount.syncTimer = 0
ServerPlayerCount.serverLogState = 0
ServerPlayerCount.resetButton = nil
ServerPlayerCount.settingsHeader = nil
ServerPlayerCount.settingsRow = nil
ServerPlayerCount.settingsInitialized = false
ServerPlayerCount.backgroundColor = {0.005, 0.005, 0.005, 0.82}
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

    if g_server ~= nil and self.syncTimer > 5000 then
        self.syncTimer = 0
        self:broadcastServerLogState()
    end
end

function ServerPlayerCount:drawOverlay()
    if g_currentMission == nil or not self:isMultiplayerSession() then
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

    local boxX = self.hudX - self.boxWidth
    local boxY = self.hudY

    drawFilledRect(boxX, boxY, self.boxWidth, self.boxHeight, self.backgroundColor[1], self.backgroundColor[2], self.backgroundColor[3], self.backgroundColor[4])
    drawFilledRect(boxX + self.iconOffsetX, boxY + self.iconOffsetY, self.iconSize, self.iconSize, stateColor[1], stateColor[2], stateColor[3], stateColor[4])

    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(true)
    setTextColor(self.textColor[1], self.textColor[2], self.textColor[3], self.textColor[4])
    renderText(boxX + self.textOffsetX, boxY + self.textOffsetY, self.textSize, valueText)
    setTextBold(false)
    setTextAlignment(RenderText.ALIGN_LEFT)
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

function ServerPlayerCount:initializeSettingsButton()
    if self.settingsInitialized or g_inGameMenu == nil or g_inGameMenu.pageSettings == nil then
        return
    end

    local settingsPage = g_inGameMenu.pageSettings
    local scrollPanel = settingsPage.gameSettingsLayout

    if scrollPanel == nil or scrollPanel.elements == nil then
        return
    end

    local sectionHeader = nil
    local buttonElement = nil

    for _, element in pairs(scrollPanel.elements) do
        if element.name == "sectionHeader" and sectionHeader == nil then
            sectionHeader = element
        end

        if element.typeName == "Bitmap" and element.elements ~= nil then
            for _, child in pairs(element.elements) do
                if child.typeName == "Button" and buttonElement == nil then
                    buttonElement = element
                    break
                end
            end
        end

        if sectionHeader ~= nil and buttonElement ~= nil then
            break
        end
    end

    if sectionHeader == nil or buttonElement == nil then
        return
    end

    local header = sectionHeader:clone(scrollPanel)
    header:setText(g_i18n:getText("spc_settings_header"))
    self.settingsHeader = header

    local template = buttonElement:clone(scrollPanel)
    template.id = nil
    self.settingsRow = template

    for _, element in pairs(template.elements) do
        if element.typeName == "Text" then
            element:setText(g_i18n:getText("spc_settings_resetStatus_label"))
            element.id = nil
        elseif element.typeName == "Button" then
            element:setText(g_i18n:getText("spc_settings_resetStatus_button"))
            element.isAlwaysFocusedOnOpen = false
            element.focused = false
            element.id = "spc_resetStatus"
            element.onClickCallback = ServerPlayerCount.onSettingsButtonClick
            self.resetButton = element
        end
    end

    self.settingsInitialized = true
end

function ServerPlayerCount.onSettingsButtonClick(_, state, button)
    if button == nil then
        button = state
    end

    if button == nil or button.id ~= "spc_resetStatus" then
        return
    end

    ServerPlayerCount:resetServerLogState()
end

function ServerPlayerCount:onSettingsFrameOpen()
    local isMultiplayer = self:isMultiplayerSession()

    if self.settingsHeader ~= nil then
        self.settingsHeader:setVisible(isMultiplayer)
    end

    if self.settingsRow ~= nil then
        self.settingsRow:setVisible(isMultiplayer)
    end

    if self.resetButton ~= nil then
        self.resetButton:setDisabled(not isMultiplayer)
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

function ServerPlayerCount:resetServerLogState()
    if g_server ~= nil then
        self:setServerLogState(0, true)
    elseif g_client ~= nil then
        g_client:getServerConnection():sendEvent(ServerPlayerCountStatusEvent.new(0, true))
    else
        self:setServerLogState(0, false)
    end
end

addModEventListener(ServerPlayerCount)


if GameInfoDisplay ~= nil and GameInfoDisplay.draw ~= nil then
    GameInfoDisplay.draw = Utils.appendedFunction(GameInfoDisplay.draw, function(display)
        if display ~= nil and type(display.getVisible) == "function" and display:getVisible() then
            ServerPlayerCount:drawOverlay()
        end
    end)
end


InGameMenuSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuSettingsFrame.onFrameOpen, function()
    ServerPlayerCount:onSettingsFrameOpen()
end)

if Logging ~= nil then
    if Logging.warning ~= nil then
        local serverPlayerCountOriginalWarning = Logging.warning
        Logging.warning = function(...)
            if g_server ~= nil then
                ServerPlayerCount:setServerLogState(1, true)
            end
            return serverPlayerCountOriginalWarning(...)
        end
    end

    if Logging.error ~= nil then
        local serverPlayerCountOriginalError = Logging.error
        Logging.error = function(...)
            if g_server ~= nil then
                ServerPlayerCount:setServerLogState(2, true)
            end
            return serverPlayerCountOriginalError(...)
        end
    end
end
