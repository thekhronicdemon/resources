Config = {}

Config.Debug = false
Config.Inventory = 'prp-inventory'
Config.InventoryFallback = 'qb-inventory'
Config.ItemBoxEvent = 'qb-inventory:client:ItemBox'
Config.Target = 'qb-target'
Config.MoneyType = 'cash'
Config.NotifyLength = 5000

-- A full crop is ready five minutes after the seed is planted.
Config.GrowTimeSeconds = 5 * 60
Config.MinimumWaters = 3
Config.IdealWaters = 4
Config.WaterCooldownSeconds = 45
Config.PlantInteractionDistance = 2.0
Config.ServerPlantDistance = 4.0
Config.MaxPlantsPerPlayer = 8
Config.PlantSaveIntervalSeconds = 30
Config.PlantDecaySeconds = 20 * 60
Config.RequireOwnerToHarvest = false
Config.PoliceJobName = 'police'
Config.MinimumPoliceForSelling = 0

Config.Models = {
    EmptyPot = `bkr_prop_weed_01_small_01c`,
    Growing = `bkr_prop_weed_med_01a`,
    Ready = `bkr_prop_weed_lrg_01a`,
    Press = `prop_tool_bench02`,
}

Config.Items = {
    Fertilizer = 'fertilizer',
    EmptyBag = 'empty_weed_bag',
    RollingPaper = 'rolling_paper',
    PlantPot = 'plant_pot',
    Shovel = 'shovel',
    Water = 'water_bottle',

    DirtA = 'dirt_a',
    DirtB = 'dirt_b',
    DirtC = 'dirt_c',
    DirtD = 'dirt_d',

    Seed = 'weed_seed',
    Bud = 'weed_bud',
    Bagged = 'weed_baggy',
    Joint = 'weed_joint',
    Brick = 'weed_brick',
}

Config.DirtGrades = {
    A = { item = Config.Items.DirtA, minQuality = 94, maxQuality = 100, yieldMultiplier = 1.35 },
    B = { item = Config.Items.DirtB, minQuality = 86, maxQuality = 95, yieldMultiplier = 1.15 },
    C = { item = Config.Items.DirtC, minQuality = 76, maxQuality = 88, yieldMultiplier = 1.00 },
    D = { item = Config.Items.DirtD, minQuality = 55, maxQuality = 80, yieldMultiplier = 0.75 },
}

-- Chance of receiving each dirt grade while digging.
Config.Digging = {
    CooldownSeconds = 20,
    ProgressTimeMs = 8000,
    MaxDistanceFromLastDig = 3.0,
    Grades = {
        { grade = 'A', chance = 5 },
        { grade = 'B', chance = 15 },
        { grade = 'C', chance = 30 },
        { grade = 'D', chance = 50 },
    }
}

Config.Shop = {
    enabled = true,
    model = `a_m_m_farmer_01`,
    coords = vector4(2224.08, 5577.14, 53.84, 180.0),
    scenario = 'WORLD_HUMAN_GARDENER_PLANT',
    items = {
        { item = Config.Items.Fertilizer, price = 45, amount = 1 },
        { item = Config.Items.EmptyBag, price = 8, amount = 5 },
        { item = Config.Items.RollingPaper, price = 5, amount = 5 },
        { item = Config.Items.PlantPot, price = 75, amount = 1 },
        { item = Config.Items.Shovel, price = 250, amount = 1 },
        { item = Config.Items.Water, price = 4, amount = 1 },
    }
}

Config.Press = {
    enabled = true,
    coords = vector4(1391.38, 3604.73, 38.94, 20.0),
    model = Config.Models.Press,
    BudsRequired = 25,
    ProgressTimeMs = 15000,
}

Config.Processing = {
    BudsPerBag = 1,
    BudsPerJoint = 1,
    ProgressTimeMs = 3500,
}

Config.Harvest = {
    MinimumBuds = 5,
    MaximumBuds = 15,
    SeedChance = 35,
    FertilizerQualityBonus = 3,
    FertilizerYieldBonus = 0.12,
    PerfectWaterBonus = 0.10,
    UnderWaterPenaltyPerMissingWater = 0.18,
}

Config.Selling = {
    enabled = true,
    cooldownSeconds = 10,
    npcRejectChance = 15,
    policeAlertChance = 12,
    distance = 2.0,
    maxNpcSpeed = 1.5,
    blacklistedPedModels = {
        [`s_m_y_cop_01`] = true,
        [`s_f_y_cop_01`] = true,
        [`s_m_y_sheriff_01`] = true,
        [`s_f_y_sheriff_01`] = true,
        [`s_m_y_hwaycop_01`] = true,
        [`s_m_m_paramedic_01`] = true,
    },
    prices = {
        weed_baggy = { min = 55, max = 110 },
        weed_joint = { min = 35, max = 75 },
        weed_brick = { min = 1150, max = 2200 },
    }
}

Config.Dispatch = function(coords)
    TriggerServerEvent('police:server:policeAlert', 'Suspicious hand-to-hand sale')
end
