Config = {
    UseTarget = GetConvar('UseTarget', 'false') == 'true',

    MaxWeight = 120000,
    MaxSlots = 40,

    StashSize = {
        maxweight = 2000000,
        slots = 100
    },

    DropSize = {
        maxweight = 1000000,
        slots = 50
    },

    Keybinds = {
        Open = 'TAB',
        Hotbar = 'Z',
    },

    CleanupDropTime = 15,
    CleanupDropInterval = 1,

    ShopSellBackRate = 0.70,

    StackableItems = {
        markedbills = true,
    },

    ItemHealth = {
        Enabled = true,
        MetadataKey = 'quality',
        DefaultHealth = 100,
        RemoveAtZero = true,
        RemoveWeaponsAtZero = true,
        Items = {
            -- Example:
            -- lockpick = { health = 100, degradeOnUse = 25 },
            -- radio = { health = 100 },
            jerry_can = { health = 100, removeAtZero = true },
        },
    },

    ItemDropObject = `bkr_prop_duffel_bag_01a`,
    ItemDropObjectBone = 28422,
    ItemDropObjectOffset = {
        vector3(0.260000, 0.040000, 0.000000),
        vector3(90.000000, 0.000000, -78.989998),
    },

    VendingObjects = {
        'prop_vend_soda_01',
        'prop_vend_soda_02',
        'prop_vend_water_01',
        'prop_vend_coffe_01',
    },

    VendingItems = {
        { name = 'kurkakola', price = 4, amount = 50 },
        { name = 'water_bottle', price = 4, amount = 50 },
    },
}


Config.BackpackStorage = {
    slots = 20,
    maxweight = 50000
}
