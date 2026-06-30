Config.Crafting = Config.Crafting or {}

Config.Crafting.Enabled = true
Config.Crafting.GridSize = 9
Config.Crafting.DefaultMethod = 'shapeless'
Config.Crafting.XPPerLevel = 100
Config.Crafting.PointsPerLevel = 1

-- Recipes every player knows by default.
-- These show in the catalogue from day one.
Config.Crafting.DefaultKnownRecipes = {
    lockpick = true,
    lean = true,
    bandage = true,
    repairkit = true,
}

-- Use these blueprint items to permanently unlock extra recipes.
-- Add the item names to qb-core/shared/items.lua if they do not exist yet.
Config.Crafting.BlueprintItems = {
    advanced_lockpick_blueprint = 'advanced_lockpick',
    firstaid_blueprint = 'firstaid',
    advanced_repairkit_blueprint = 'advanced_repairkit',
}

-- NOTE:
-- Requirements ARE shown in the catalogue UI for known recipes.
-- Blueprint recipes are blocked until learned.
Config.Crafting.Recipes = {
    -- BASIC KNOWN RECIPES
    {
        id = 'lockpick',
        category = 'Tools',
        description = 'Basic utility tool',
        method = 'shapeless',
        output = { item = 'lockpick', amount = 1 },
        ingredients = {
            { item = 'paperclip', amount = 2 },
        },
        xpType = 'craftingrep',
        xpGain = 1,
    },
    {
        id = 'lean',
        category = 'Drugs',
        description = 'Street mixture',
        method = 'shapeless',
        output = { item = 'lean', amount = 1 },
        ingredients = {
            { item = 'cough_syrup', amount = 1 },
            { item = 'cola', amount = 1 },
        },
        xpType = 'craftingrep',
        xpGain = 1,
    },
    {
        id = 'bandage',
        category = 'Medical',
        description = 'Basic medical wrap',
        method = 'shapeless',
        output = { item = 'bandage', amount = 1 },
        ingredients = {
            { item = 'cloth', amount = 1 },
        },
        xpType = 'craftingrep',
        xpGain = 1,
    },
    {
        id = 'repairkit',
        category = 'Mechanic',
        description = 'Basic vehicle repair kit',
        method = 'shapeless',
        output = { item = 'repairkit', amount = 1 },
        ingredients = {
            { item = 'metalscrap', amount = 3 },
            { item = 'plastic', amount = 2 },
        },
        xpType = 'craftingrep',
        xpGain = 1,
    },

    -- BLUEPRINT LOCKED EXAMPLES
    {
        id = 'advanced_lockpick',
        category = 'Tools',
        blueprint = 'advanced_lockpick_blueprint',
        description = 'Blueprint recipe',
        method = 'shapeless',
        output = { item = 'advancedlockpick', amount = 1 },
        ingredients = {
            { item = 'lockpick', amount = 1 },
            { item = 'metalscrap', amount = 4 },
            { item = 'plastic', amount = 2 },
        },
        xpType = 'craftingrep',
        xpGain = 3,
    },
    {
        id = 'firstaid',
        category = 'Medical',
        blueprint = 'firstaid_blueprint',
        description = 'Blueprint recipe',
        method = 'shapeless',
        output = { item = 'firstaid', amount = 1 },
        ingredients = {
            { item = 'bandage', amount = 2 },
            { item = 'painkillers', amount = 1 },
        },
        xpType = 'craftingrep',
        xpGain = 3,
    },
    {
        id = 'advanced_repairkit',
        category = 'Mechanic',
        blueprint = 'advanced_repairkit_blueprint',
        description = 'Blueprint recipe',
        method = 'shapeless',
        output = { item = 'advancedrepairkit', amount = 1 },
        ingredients = {
            { item = 'repairkit', amount = 1 },
            { item = 'steel', amount = 4 },
            { item = 'plastic', amount = 3 },
        },
        xpType = 'craftingrep',
        xpGain = 3,
    },
}
