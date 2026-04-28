Config = Config or {}

Config.OpenCommand = 'tablet'
Config.CloseKey = 'ESC'

Config.Apps = {
    {
        id = 'racing',
        label = 'RacePro',
        description = 'Tracks, hosts, and live race control.',
    },
    {
        id = 'business',
        label = 'HOA',
        description = 'Income, duty, and staff tools.',
    },
    {
        id = 'ads',
        label = 'Advertisements',
        description = 'City promos, business spots, and live posts.',
    },
    {
        id = 'crypto',
        label = 'Crypto Rig',
        description = 'Launch installed crypto drives.',
    },
    {
        id = 'mdt',
        label = 'MDT',
        description = 'Suspects, reports, and warrants.',
        leoOnly = true,
    },
    {
        id = 'admin',
        label = 'City Admin',
        description = 'Delete, moderate, and override live app data.',
        adminOnly = true,
    },
    {
        id = 'crime',
        label = 'Crime',
        description = 'Street intel and live jobs.',
        disabled = true,
    },
    {
        id = 'boosting',
        label = 'Boosting',
        description = 'Crew contracts and VIN work.',
        disabled = true,
    },
    {
        id = 'royale',
        label = 'Runway Royale',
        description = 'Flight sheets and runway action.',
        disabled = true,
    },
}

Config.CryptoMining = {
    Item = 'crypto_usb',
    FallbackItem = 'cryptostick',
    MinSeconds = 180,
    MaxSeconds = 900,
    MinReward = 0.12,
    MaxReward = 0.85,
}

Config.Racing = {
    MaxShown = 20,
    DefaultBuyIn = 0,
    MaxBuyIn = 50000,
    MaxLaps = 20,
    MaxPasswordLength = 24,
}
