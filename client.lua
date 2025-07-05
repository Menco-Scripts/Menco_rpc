local function fstring(template, variables)
    return (template:gsub("{(.-)}", function(key)
        return tostring(variables[key] or "nil")
    end))
end

local function lang(path)
    local parts = {}
    for part in string.gmatch(path, "[^.]+") do
        table.insert(parts, part)
    end

    local tbl = Config.Localization[Config.Locale]
    for _, key in ipairs(parts) do
        if type(tbl) == "table" and tbl[key] then
            tbl = tbl[key]
        else
            return nil
        end
    end

    return tbl
end

local function get_player_info()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local playerId = GetPlayerServerId(PlayerId())

    local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = "Unknown Location"
    if streetHash ~= 0 then
        streetName = GetStreetNameFromHashKey(streetHash)
    else
        local unknownText = lang("status.unknown")
        if unknownText then
            streetName = unknownText
        end
    end

    local isInVehicle = IsPedInAnyVehicle(ped, false)
    local vehicleName = nil
    if isInVehicle then
        local vehicle = GetVehiclePedIsIn(ped, false)
        local vehicleModel = GetEntityModel(vehicle)
        vehicleName = GetDisplayNameFromVehicleModel(vehicleModel)
    end

    local movementState = "exploring"
    if not isInVehicle then
        if IsPedRunning(ped) then
            movementState = "running"
        elseif IsPedWalking(ped) then
            movementState = "walking"
        elseif IsPedStill(ped) then
            movementState = "stopped"
        end
    end

    return {
        playerId = playerId,
        streetName = streetName,
        isInVehicle = isInVehicle,
        vehicleName = vehicleName,
        movementState = movementState
    }
end

local function buildStatusMessage(playerInfo)
    if playerInfo.isInVehicle and playerInfo.vehicleName then
        local template = lang("status.driving") or "Driving a {vehicle} on {street}"
        return fstring(template, {
            vehicle = playerInfo.vehicleName,
            street = playerInfo.streetName
        })
    else
        local template = lang("status." .. playerInfo.movementState) or "{state} on {street}"
        local stateName = playerInfo.movementState:gsub("^%l", string.upper)
        return fstring(template, {
            state = stateName,
            street = playerInfo.streetName
        })
    end
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.UpdateInterval)
        local playerInfo = get_player_info()
        local statusMessage = buildStatusMessage(playerInfo)
        local playerIdText = fstring(lang("actions.playerId") or "Player ID: {id}", {
            id = playerInfo.playerId
        })
    
        SetDiscordAppId(Config.DiscordAppId)
        SetDiscordRichPresenceAsset(Config.Assets.LargeImage)
        SetDiscordRichPresenceAssetText(Config.Assets.LargeImageText)
        SetDiscordRichPresenceAssetSmall(Config.Assets.SmallImage)
        SetDiscordRichPresenceAssetSmallText(Config.Assets.SmallImageText)
        SetDiscordRichPresenceAction(0, playerIdText, "")
        SetDiscordRichPresenceAction(1, statusMessage, "")
        SetRichPresence(("ID %d | %s"):format(playerInfo.playerId, statusMessage))
    end
end)

RegisterCommand('discord', function()
    local discord_link = Config.DiscordLink or "https://discord.gg/unknown"
    local template = lang("commands.discordMessage") or "Join our Discord server: {discord}"
    local msg = fstring(template, { discord = discordLink })

    TriggerEvent('chat:addMessage', {
        color = {0, 123, 255},
        multiline = true,
        args = {"Menco", msg}
    })
end)
