Config = Config or {}
Config.BillingCommissions = { -- This is a percentage (0.10) == 10%
    mechanic = 0.10
}
Config.TweetDuration = 12 -- How many hours to load tweets (12 will load the past 12 hours of tweets)
Config.RepeatTimeout = 2000
Config.CallRepeats = 10
Config.OpenPhone = 'M'

-- Set this to true if you wish to use Fivemerr (https://fivemerr.com/) for media uploads. 
-- Ensure to add your API key to server/main.lua 
Config.Fivemerr = false

Config.PhoneApplications = {
    ['phone'] = {
        app = 'phone',
        color = '#04b543',
        icon = 'fa fa-phone-alt',
        tooltipText = 'Phone',
        tooltipPos = 'top',
        job = false,
        blockedjobs = {},
        slot = 1,
        Alerts = 0,
    },
    ['whatsapp'] = {
        app = 'whatsapp',
        color = '#25d366',
        icon = 'fas fa-comment',
        tooltipText = 'Messages',
        tooltipPos = 'top',
        style = 'font-size: 2.8vh',
        job = false,
        blockedjobs = {},
        slot = 2,
        Alerts = 0,
    },
    ['settings'] = {
        app = 'settings',
        color = '#636e72',
        icon = 'fa fa-cogs',
        tooltipText = 'Settings',
        tooltipPos = 'top',
        style = 'padding-right: .08vh; font-size: 2.3vh',
        job = false,
        blockedjobs = {},
        slot = 3,
        Alerts = 0,
    },
    ['twitter'] = {
        app = 'twitter',
        color = '#2f80ed',
        icon = 'fas fa-comments',
        tooltipText = 'Chatterly',
        tooltipPos = 'top',
        job = false,
        blockedjobs = {},
        slot = 4,
        Alerts = 0,
    },
    ['garage'] = {
        app = 'garage',
        color = '#575fcf',
        icon = 'fas fa-car',
        tooltipText = 'Vehicles',
        job = false,
        blockedjobs = {},
        slot = 5,
        Alerts = 0,
    },
    ['mail'] = {
        app = 'mail',
        color = '#ff002f',
        icon = 'fas fa-envelope-open-text',
        tooltipText = 'Mail',
        job = false,
        blockedjobs = {},
        slot = 6,
        Alerts = 0,
    },
    ['advert'] = {
        app = 'advert',
        color = '#ff8f1a',
        icon = 'fas fa-bullhorn',
        tooltipText = 'Advertisements',
        job = false,
        blockedjobs = {},
        slot = 7,
        Alerts = 0,
    },
    ['bank'] = {
        app = 'bank',
        color = '#9c88ff',
        icon = 'fas fa-money-check-alt',
        tooltipText = 'Bank',
        job = false,
        blockedjobs = {},
        slot = 8,
        Alerts = 0,
    },
    ['crypto'] = {
        app = 'crypto',
        color = '#004682',
        icon = 'fas fa-coins',
        tooltipText = 'Crypto',
        job = false,
        blockedjobs = {},
        slot = 9,
        Alerts = 0,
    },
    ['houses'] = {
        app = 'houses',
        color = '#27ae60',
        icon = 'fas fa-home',
        tooltipText = 'Houses',
        job = false,
        blockedjobs = {},
        slot = 11,
        Alerts = 0,
    },
    ['lawyers'] = {
        app = 'lawyers',
        color = '#26d4ce',
        icon = 'fas fa-briefcase',
        tooltipText = 'Services',
        tooltipPos = 'bottom',
        job = false,
        blockedjobs = {},
        slot = 12,
        Alerts = 0,
    },
    ['gallery'] = {
        app = 'gallery',
        color = '#AC1D2C',
        icon = 'fas fa-images',
        tooltipText = 'Photos',
        tooltipPos = 'bottom',
        job = false,
        blockedjobs = {},
        slot = 13,
        Alerts = 0,
    },
    ['camera'] = {
        app = 'camera',
        color = '#AC1D2C',
        icon = 'fas fa-camera',
        tooltipText = 'Camera',
        tooltipPos = 'bottom',
        job = false,
        blockedjobs = {},
        slot = 14,
        Alerts = 0,
    },
    ['meos'] = {
        app = 'meos',
        color = '#004682',
        icon = 'fas fa-ad',
        tooltipText = 'MDT',
        job = 'police',
        blockedjobs = {},
        slot = 15,
        Alerts = 0,
    },
    ['gang'] = {
        app = 'gang',
        color = '#111827',
        icon = 'fas fa-users-cog',
        tooltipText = 'Gang Control',
        tooltipPos = 'bottom',
        job = false,
        blockedjobs = {},
        slot = 16,
        Alerts = 0,
    },
    ['cryptoshop'] = {
        app = 'cryptoshop',
        color = '#0f766e',
        icon = 'fas fa-shopping-bag',
        tooltipText = 'Crypto Shop',
        tooltipPos = 'bottom',
        job = false,
        blockedjobs = {},
        slot = 17,
        Alerts = 0,
    },
    ['calculator'] = {
        app = 'calculator',
        color = '#f59e0b',
        icon = 'fas fa-calculator',
        tooltipText = 'Calculator',
        tooltipPos = 'bottom',
        job = false,
        blockedjobs = {},
        slot = 18,
        Alerts = 0,
    },
}
Config.MaxSlots = 20

Config.SimCards = {
    RequireSim = true,
    NumberPrefix = '04',
    NumberLength = 8,
}

Config.TabletApplications = {
    ['racing'] = {
        label = 'Racing',
        description = 'Crews, tracks, and late-night lines.',
        icon = 'fas fa-flag-checkered',
    },
    ['business'] = {
        label = 'Business',
        description = 'Boss controls from the tablet.',
        icon = 'fas fa-briefcase',
    },
    ['crypto'] = {
        label = 'Crypto Rig',
        description = 'Insert a crypto USB and let it cook.',
        icon = 'fas fa-microchip',
    },
}

Config.TabletCryptoMining = {
    Item = 'crypto_usb',
    FallbackItem = 'cryptostick',
    MinSeconds = 180,
    MaxSeconds = 900,
    MinReward = 0.12,
    MaxReward = 0.85,
}

Config.CryptoShopItems = {
    {
        item = 'radio',
        label = 'Encrypted Radio',
        amount = 1,
        price = 0.25,
    },
    {
        item = 'advancedlockpick',
        label = 'Advanced Lockpick',
        amount = 1,
        price = 0.35,
    },
    {
        item = 'simcard',
        label = 'Fresh SIM Card',
        amount = 1,
        price = 0.15,
    },
}

Config.StoreApps = {
    ['territory'] = {
        app = 'territory',
        color = '#353b48',
        icon = 'fas fa-globe-europe',
        tooltipText = 'Territorium',
        tooltipPos = 'right',
        style = '',
        job = false,
        blockedjobs = {},
        slot = 19,
        Alerts = 0,
        password = true,
        creator = 'QBCore',
        title = 'Territory',
    },
}
