--[[ s_core client — multicharacter selection + spawn, own-data accessors.
     Reads the active character's data from the replicated statebag. ]]
local loaded = false
local finishSpawn   -- forward declaration

local function openSelector()
    local data = lib.callback.await('s_core:getCharacters', false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = data })
end

finishSpawn = function(res)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    local ped = PlayerPedId()
    local p = res.position
    if p then
        SetEntityCoordsNoOffset(ped, p.x + 0.0, p.y + 0.0, p.z + 0.0, false, false, false)
        SetEntityHeading(ped, p.h or 0.0)
    end
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(700)
    loaded = true
    lib.notify({ title = 'Saga', description = ('Welcome, %s.'):format(res.name or 'traveller'), type = 'success' })
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(200) end
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeOut(0)
    Wait(800)
    FreezeEntityPosition(PlayerPedId(), true)
    openSelector()
end)

RegisterNUICallback('selectCharacter', function(body, cb)
    local res = lib.callback.await('s_core:selectCharacter', false, body.charid)
    if res.ok then finishSpawn(res) end
    cb(res)
end)

RegisterNUICallback('createCharacter', function(body, cb)
    local res = lib.callback.await('s_core:createCharacter', false, body)
    if res.ok then finishSpawn(res) end
    cb(res)
end)

RegisterNUICallback('deleteCharacter', function(body, cb)
    cb(lib.callback.await('s_core:deleteCharacter', false, body.charid))
end)

-- /cash — read own balance from the statebag, no server round-trip
RegisterCommand('cash', function()
    local m = LocalPlayer.state['saga:money'] or { cash = 0, bank = 0 }
    lib.notify({ title = 'Wallet', description = ('Cash: $%d   Bank: $%d'):format(m.cash or 0, m.bank or 0), type = 'inform' })
end, false)

exports('IsLoaded', function() return loaded end)
exports('GetMoney', function(account) local m = LocalPlayer.state['saga:money'] or {}; return m[account] or 0 end)
exports('GetData', function()
    return { loaded = loaded, money = LocalPlayer.state['saga:money'], char = LocalPlayer.state['saga:char'] }
end)
