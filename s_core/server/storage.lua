--[[ s_core storage — persistence backend (SERVER).
     oxmysql when present; otherwise an in-memory store (ephemeral) so the
     framework is testable on a bare server. Keyed by charid (multicharacter). ]]
Saga = Saga or {}

local mode = 'memory'
local mem = {}   -- [charid] = row

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS saga_characters (
    charid     VARCHAR(40)  NOT NULL,
    license    VARCHAR(64)  NOT NULL,
    name       VARCHAR(64)  NOT NULL DEFAULT 'Unknown',
    money      LONGTEXT     NOT NULL,
    position   LONGTEXT     NOT NULL,
    metadata   LONGTEXT     NOT NULL,
    updated_at TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (charid),
    INDEX idx_license (license)
);
]]

local function decodeRow(row)
    return {
        charid = row.charid, license = row.license, name = row.name,
        money = json.decode(row.money), position = json.decode(row.position),
        metadata = json.decode(row.metadata),
    }
end

local Storage = {}

function Storage.init()
    if GetResourceState('oxmysql') == 'started' then
        mode = 'db'
        lib.db.query(SCHEMA, {})
        lib.print.info('storage: oxmysql detected — persisting to database')
    else
        mode = 'memory'
        lib.print.warn('storage: oxmysql not found — running IN-MEMORY (data resets on restart)')
    end
end

function Storage.mode() return mode end

function Storage.listByLicense(license)
    if mode == 'db' then
        local rows = lib.db.query('SELECT * FROM saga_characters WHERE license = ?', { license }) or {}
        local out = {}
        for i = 1, #rows do out[i] = decodeRow(rows[i]) end
        return out
    end
    local out = {}
    for _, row in pairs(mem) do if row.license == license then out[#out + 1] = row end end
    return out
end

function Storage.loadChar(charid)
    if mode == 'db' then
        local row = lib.db.single('SELECT * FROM saga_characters WHERE charid = ? LIMIT 1', { charid })
        return row and decodeRow(row) or nil
    end
    return mem[charid]
end

function Storage.save(row)
    if mode == 'db' then
        lib.db.query([[
            INSERT INTO saga_characters (charid, license, name, money, position, metadata)
            VALUES (?, ?, ?, ?, ?, ?)
            ON DUPLICATE KEY UPDATE name=VALUES(name), money=VALUES(money),
                position=VALUES(position), metadata=VALUES(metadata)
        ]], { row.charid, row.license, row.name,
              json.encode(row.money), json.encode(row.position), json.encode(row.metadata) })
    else
        mem[row.charid] = row
    end
end

function Storage.deleteChar(charid)
    if mode == 'db' then
        lib.db.query('DELETE FROM saga_characters WHERE charid = ?', { charid })
    else
        mem[charid] = nil
    end
end

Saga.Storage = Storage
