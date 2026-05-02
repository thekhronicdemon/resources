Config = {}

Config.CoreName = 'qb-core'

Config.PickaxeItem = 'pickaxe'
Config.PickaxeProp = 'prop_tool_pickaxe'

-- Mining spots. Players stand inside the ground circle and press E.
Config.MiningSpots = {
    vector3(3027.33, 3016.37, 83.36),
    vector3(3035.50, 3012.49, 83.56),
    vector3(3043.57, 3005.30, 83.47),
}

Config.Marker = {
    drawDistance = 25.0,
    interactDistance = 1.6,
    type = 1,
    scale = vector3(2.2, 2.2, 0.22),
    colour = { r = 255, g = 190, b = 60, a = 130 }
}

Config.MiningTime = 10000 -- 10 seconds
Config.CooldownPerSpot = 6 -- seconds after each successful/cancelled attempt

-- New pickaxes start with this health if no metadata exists.
Config.DefaultPickaxeHealth = 100
Config.PickaxeDamage = { min = 8, max = 18 }
Config.DestroyPickaxeAtZero = true

-- Rewards. Chance is weighted, not percentage. Higher = more common.
Config.Rewards = {
    { item = 'coal_ore',    min = 1, max = 4, chance = 40 },
    { item = 'copper_ore',  min = 1, max = 3, chance = 30 },
    { item = 'iron_ore',    min = 1, max = 3, chance = 25 },
    { item = 'gold_ore',    min = 1, max = 2, chance = 8  },
    { item = 'diamond_ore', min = 1, max = 1, chance = 2  },
}

Config.Notify = function(srcOrText, text, nType)
    -- Server side passes player id first. Client side passes text first.
    if type(srcOrText) == 'number' then
        TriggerClientEvent('QBCore:Notify', srcOrText, text, nType or 'primary')
    else
        QBCore.Functions.Notify(srcOrText, text or 'primary')
    end
end
