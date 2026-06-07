Config = {
    -- Starting balances for a brand-new character.
    startingMoney = { cash = 500, bank = 5000 },
    -- Where new characters (and players with no saved position) spawn.
    defaultSpawn = { x = -1037.0, y = -2737.0, z = 20.2, h = 330.0 },
    -- Autosave schedule (lib.cron, 5-field). Default: every 5 minutes.
    autosaveCron = '*/5 * * * *',
    -- Money accounts the framework manages. Money lives ONLY in s_core.
    accounts = { 'cash', 'bank' },
    -- Multicharacter: how many characters a single license may own.
    maxCharacters = 5,
}
