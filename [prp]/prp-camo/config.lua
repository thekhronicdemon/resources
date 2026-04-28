Config = {}

Config.DefaultDuration = 5000

Config.Progressbar = {
    useWhileDead = false,
    canCancel = true,
    disableControls = {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    },
    animation = {
        animDict = 'mini@repair',
        anim = 'fixing_a_player',
        flags = 16,
    }
}

Config.WeaponSkins = {
    redcamo_paint = {
        baseWeapon = 'weapon_pistol',
        skinnedWeapon = 'weapon_pistol_redarmy',
        duration = 5000,
        progressLabel = 'Attaching weapon skin...',
        successMessage = 'Red camo skin attached.',
        alreadySkinnedMessage = 'You already have the red camo pistol.',
        missingBaseMessage = 'You need a pistol before applying this skin.',
    },
    -- bluecamo_paint = {
    --     baseWeapon = 'weapon_pistol',
    --     skinnedWeapon = 'weapon_pistol_bluearmy',
    --     duration = 5000,
    --     progressLabel = 'Attaching weapon skin...',
    --     successMessage = 'Blue camo skin attached.',
    --     alreadySkinnedMessage = 'You already have the blue camo pistol.',
    --     missingBaseMessage = 'You need a pistol before applying this skin.',
    -- },
    -- greencamo_paint = {
    --     baseWeapon = 'weapon_pistol',
    --     skinnedWeapon = 'weapon_pistol_greenarmy',
    --     duration = 5000,
    --     progressLabel = 'Attaching weapon skin...',
    --     successMessage = 'Green camo skin attached.',
    --     alreadySkinnedMessage = 'You already have the green camo pistol.',
    --     missingBaseMessage = 'You need a pistol before applying this skin.',
    -- },
}
