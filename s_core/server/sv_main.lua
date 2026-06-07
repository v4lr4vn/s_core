--[[ s_core server — multicharacter lifecycle, money (single source of truth),
     exports. Dogfoods s_lib: lib.class, lib.callback, lib.db, lib.cron, lib.addCommand. ]]
local Storage = Saga.Storage
local players = {}                       -- [source] = SagaPlayer (the ACTIVE character)
local PlayerClass = lib.class('SagaPlayer')

-- ---- Player object -------------------------------------------------------
function PlayerClass:constructor(data)
    self.source = data.source
    self.license = data.license
    self.charid = data.charid
    self.name = data.name or 'Unknown'
    self.money = {
        cash = (data.money and data.money.cash) or 0,
        bank = (data.money and data.money.bank) or 0,
    }
    self.position = data.position or Config.defaultSpawn
    self.metadata = data.metadata or {}
end

function PlayerClass:sync()
    local state = Player(self.source).state
    state:set('saga:loaded', true, true)
    state:set('saga:money', self.money, true)
    state:set('saga:char', { charid = self.charid, name = self.name }, true)
end

function PlayerClass:getMoney(account) return self.money[account] or 0 end

function PlayerClass:addMoney(account, amount)
    amount = tonumber(amount)
    if self.money[account] == nil or not amount or amount <= 0 then return false end
    self.money[account] = self.money[account] + amount
    self:sync(); return true
end

function PlayerClass:removeMoney(account, amount)
    amount = tonumber(amount)
    if self.money[account] == nil or not amount or amount <= 0 then return false end
    if self.money[account] < amount then return false end
    self.money[account] = self.money[account] - amount
    self:sync(); return true
end

function PlayerClass:setMoney(account, amount)
    amount = tonumber(amount)
    if self.money[account] == nil or not amount or amount < 0 then return false end
    self.money[account] = amount
    self:sync(); return true
end

function PlayerClass:getMetadata(key) return self.metadata[key] end
function PlayerClass:setMetadata(key, value) self.metadata[key] = value; return true end

function PlayerClass:toRow()
    return { charid = self.charid, license = self.license, name = self.name,
             money = self.money, position = self.position, metadata = self.metadata }
end

function PlayerClass:save() Storage.save(self:toRow()) end

-- ---- helpers -------------------------------------------------------------
local function licenseOf(src) return GetPlayerIdentifierByType(src, 'license') or ('src:' .. src) end
local function newCharId() return ('CHAR%05d%04d'):format(os.time() % 100000, math.random(1000, 9999)) end

local function summaries(license)
    local chars, list = Storage.listByLicense(license), {}
    for i = 1, #chars do
        local c = chars[i]
        list[i] = { charid = c.charid, name = c.name, cash = c.money.cash, bank = c.money.bank }
    end
    return list
end

local function loadActive(src, row)
    row.source = src
    local plr = PlayerClass(row)
    players[src] = plr
    plr:sync()
    TriggerClientEvent('s_core:playerLoaded', src, {
        charid = plr.charid, name = plr.name, money = plr.money, position = plr.position,
    })
    TriggerEvent('s_core:playerLoaded', src, plr.charid)
    lib.print.info(('loaded %s (%s) cash=%d bank=%d'):format(plr.name, plr.charid, plr.money.cash, plr.money.bank))
    return plr
end

-- ---- multicharacter callbacks --------------------------------------------
lib.callback.register('s_core:getCharacters', function(src)
    return { maxSlots = Config.maxCharacters, characters = summaries(licenseOf(src)) }
end)

lib.callback.register('s_core:selectCharacter', function(src, charid)
    local row = Storage.loadChar(charid)
    if not row or row.license ~= licenseOf(src) then return { ok = false } end
    local plr = loadActive(src, row)
    return { ok = true, name = plr.name, position = plr.position }
end)

lib.callback.register('s_core:createCharacter', function(src, form)
    form = form or {}
    local license = licenseOf(src)
    if #Storage.listByLicense(license) >= Config.maxCharacters then
        return { ok = false, reason = 'No free character slots' }
    end
    local first = tostring(form.firstname or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 24)
    local last  = tostring(form.lastname or ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 24)
    if first == '' or last == '' then return { ok = false, reason = 'First and last name required' } end
    local row = {
        charid = newCharId(), license = license, name = first .. ' ' .. last,
        money = { cash = Config.startingMoney.cash, bank = Config.startingMoney.bank },
        position = Config.defaultSpawn,
        metadata = { firstname = first, lastname = last, dob = form.dob, gender = form.gender },
    }
    Storage.save(row)
    lib.print.info(('created character %s (%s) for %s'):format(row.name, row.charid, license))
    local plr = loadActive(src, row)
    return { ok = true, name = plr.name, position = plr.position }
end)

lib.callback.register('s_core:deleteCharacter', function(src, charid)
    local license = licenseOf(src)
    local row = Storage.loadChar(charid)
    if not row or row.license ~= license then return { ok = false } end
    Storage.deleteChar(charid)
    lib.print.info(('deleted character %s for %s'):format(charid, license))
    return { ok = true, maxSlots = Config.maxCharacters, characters = summaries(license) }
end)

AddEventHandler('playerDropped', function()
    local src = source
    local plr = players[src]
    if not plr then return end
    plr:save()
    players[src] = nil
    TriggerEvent('s_core:playerUnloaded', src)
    lib.print.info(('saved + unloaded %s'):format(plr.charid))
end)

-- ---- exports (flat) ------------------------------------------------------
exports('GetPlayer', function(src)
    local p = players[src]
    if not p then return nil end
    return { source = p.source, charid = p.charid, license = p.license,
             name = p.name, money = p.money, position = p.position, metadata = p.metadata }
end)
exports('GetMoney',    function(src, a)    local p = players[src]; return p and p:getMoney(a) or 0 end)
exports('AddMoney',    function(src, a, n) local p = players[src]; return p ~= nil and p:addMoney(a, n) end)
exports('RemoveMoney', function(src, a, n) local p = players[src]; return p ~= nil and p:removeMoney(a, n) end)
exports('SetMoney',    function(src, a, n) local p = players[src]; return p ~= nil and p:setMoney(a, n) end)
exports('SetMetadata', function(src, k, v) local p = players[src]; if not p then return false end; return p:setMetadata(k, v) end)
exports('GetMetadata', function(src, k)    local p = players[src]; return p and p:getMetadata(k) end)
exports('SavePlayer',  function(src)       local p = players[src]; if not p then return false end; p:save(); return true end)
exports('GetPlayers',  function() local t = {}; for s in pairs(players) do t[#t + 1] = s end; return t end)

-- ---- admin commands (dogfood lib.addCommand) -----------------------------
lib.addCommand('givecash', {
    help = 'Give cash to a player', restricted = 'group.admin',
    params = { { name = 'id', help = 'server id' }, { name = 'amount', help = 'amount' } },
}, function(source, args)
    local target, amount = tonumber(args[1]), tonumber(args[2])
    local p = target and players[target]
    if not p or not amount then return end
    p:addMoney('cash', amount)
    lib.print.info(('admin %d gave $%d cash to %d'):format(source, amount, target))
end)

lib.addCommand('setbank', {
    help = "Set a player's bank balance", restricted = 'group.admin',
    params = { { name = 'id', help = 'server id' }, { name = 'amount', help = 'amount' } },
}, function(source, args)
    local target, amount = tonumber(args[1]), tonumber(args[2])
    local p = target and players[target]
    if not p or not amount then return end
    p:setMoney('bank', amount)
end)

lib.addCommand('saveall', { help = 'Force-save all online players', restricted = 'group.admin' }, function(source)
    local n = 0
    for _, p in pairs(players) do p:save(); n = n + 1 end
    lib.print.info(('admin %d force-saved %d player(s)'):format(source, n))
end)

-- ---- autosave (dogfood lib.cron) -----------------------------------------
lib.cron.new(Config.autosaveCron, function()
    local n = 0
    for _, p in pairs(players) do p:save(); n = n + 1 end
    if n > 0 then lib.print.info(('autosaved %d player(s)'):format(n)) end
end)

CreateThread(function()
    Storage.init()
    lib.print.info('s_core server ready (storage: ' .. Storage.mode() .. ')')
end)
