Config = {}

-- Item used to open the crate
Config.CrateItem = 'briefcrate'

-- How many cards are shown in the rolling strip
Config.RollItemCount = 60

-- How long the roll animation lasts in milliseconds
Config.RollDuration = 6500

-- Visual slot width in the NUI (must match CSS)
Config.CardWidth = 170
Config.CardGap = 14

-- Weighted rarity table. Higher = more common.
Config.RarityWeights = {
    common = 55,
    uncommon = 25,
    rare = 12,
    epic = 6,
    legendary = 2
}

-- Optional per-rarity colors for UI badges/glow
Config.RarityColors = {
    common = '#b8c0cc',
    uncommon = '#52d273',
    rare = '#4da3ff',
    epic = '#b667ff',
    legendary = '#ffb347'
}

-- Drop pool.
-- The script pulls image / label / description / rarity from qb-core shared items.
-- Optional overrideWeight lets you make a specific item rarer or more common than its rarity default.
Config.ItemsRolled = {
    { item = 'sandwich', amount = 2 },
    { item = 'water_bottle', amount = 2 },
    { item = 'lockpick', amount = 1, overrideWeight = 14 },
    { item = 'repairkit', amount = 1, overrideWeight = 10 },
    { item = 'phone', amount = 1, overrideWeight = 8 },
    { item = 'radio', amount = 1, overrideWeight = 8 },
    { item = 'weapon_bat', amount = 1 },
    { item = 'weapon_switchblade', amount = 1 },
    { item = 'weapon_snspistol', amount = 1 },
    { item = 'weapon_pistol', amount = 1, overrideWeight = 5 },
    { item = 'weapon_vintagepistol', amount = 1, overrideWeight = 4 },
    { item = 'weapon_heavypistol', amount = 1, overrideWeight = 3 },
    { item = 'weapon_microsmg', amount = 1, overrideWeight = 2 },
    { item = 'weapon_smg', amount = 1, overrideWeight = 1 },
    { item = 'briefcrate', amount = 1, overrideWeight = 1},
}

-- If true, shows exact percentages calculated from weights.
Config.ShowExactPercent = true
