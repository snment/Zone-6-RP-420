--        _          _     _            
--  _ __ | |__  _ __(_) __| | __ _  ___ 
-- | '__|| '_ \| '__| |/ _` |/ _` |/ _ \
-- | |   | |_) | |  | | (_| | (_| |  __/
-- |_|___|_.__|_|  |_|\__,_|\__, |\___|
--  |_____|                  |___/      
--
--  Need support? Join our Discord server for help: https://discord.gg/rscripts
--
Cfg = {
    -- Check if the resource is up to date. Recommended to keep it enabled.
    VersionCheck = true,

    Framework = 'esx', -- 'esx', 'qb'
    Inventory = 'ox',  -- 'ox', 'qb', 'esx', 'custom'

    -- Choose the notification system you want to use. 'custom' can be configured in your frameworks bridge.
    Notification = 'ox', -- 'default', 'ox', 'custom'

    -- Choose the carlock system you want to use. 'custom' can be configured in your frameworks bridge.
    CarLock = wasabi, -- 'qb', 'wasabi', 'mrnewb', 'quasar', 'custom', false to disable
} 