Config = {}

Config.Core = 'qb-core'
Config.Target = 'qb-target'

Config.Command = 'workoutstats'

Config.MaxActivitiesPerHour = 10
Config.ActivityWindowSeconds = 60 * 60

Config.DecayEveryMinutes = 60
Config.DecayAmount = 1

Config.WorkoutDuration = 10000
Config.StatMax = 100

Config.Effects = {
    Enabled = true,
    TickMs = 500,

    Stamina = {
        Enabled = true,
        -- Restored while running/sprinting at 100 stamina stat. Lower values make sprint drain faster.
        RestoreAtMax = 0.12
    },

    Endurance = {
        Enabled = true,
        BaseMaxHealth = 200,
        -- At 100 endurance, players gain this much extra max health.
        MaxBonusHealth = 50
    },

    Strength = {
        Enabled = true,
        BaseMeleeModifier = 1.0,
        -- At 100 strength, melee hits deal 50% more damage.
        MaxBonusMeleeModifier = 0.5
    }
}

Config.PunchingBag = {
    Enabled = true,

    -- You asked to keep this prop.
    Model = `prop_punch_bag_l`,

    -- IMPORTANT:
    -- If the bag is in the ground, raise zOffset.
    -- Try 1.0, 1.3, 1.6 depending on your map floor.
    ZOffset = 1.35,

    ResetEverySeconds = 30,

    -- Fake swing, but reliable. Physics on this prop can be inconsistent.
    SwingAmount = 12.0,
    SwingSpeed = 75
}

Config.Activities = {
    pushups = {
        label = 'Pushups',
        stat = 'endurance',
        gain = 2,
        icon = 'fas fa-person-running',
        coords = vector3(-1202.22, -1565.91, 4.61),
        radius = 1.5,
        scenario = 'world_human_push_ups'
    },

    dumbbells = {
        label = 'Dumbbells',
        stat = 'strength',
        gain = 2,
        icon = 'fas fa-dumbbell',
        coords = vector3(-1209.31, -1559.12, 4.61),
        radius = 1.5,
        scenario = 'world_human_muscle_free_weights'
    },

    boxing = {
        label = 'Boxing Bag',
        stat = 'stamina',
        gain = 2,
        icon = 'fas fa-hand-fist',

        -- Bag base location.
        coords = vector3(-1198.52, -1574.33, 4.61),
        heading = 210.0,
        radius = 1.8,

        -- Player stands here while punching.
        playerCoords = vector4(-1199.06, -1573.59, 4.61, 212.19),

        -- Better punching animation.
        animDict = 'anim@mp_player_intcelebrationmale@shadow_boxing',
        animName = 'shadow_boxing'
    }
}
