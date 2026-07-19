-- Add these to qb-core/shared/items.lua

mechanic_tablet = {
    name = 'mechanic_tablet',
    label = 'Mechanic Tablet',
    weight = 1000,
    type = 'item',
    image = 'mechanic_tablet.png',
    unique = true,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Controls installed stance, airbag and hydraulic upgrades.'
},

airbags = {
    name = 'airbags',
    label = 'Air Suspension Kit',
    weight = 5000,
    type = 'item',
    image = 'airbags.png',
    unique = false,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Installs or removes permanent air suspension from a vehicle.'
},

stancer = {
    name = 'stancer',
    label = 'Stancer Upgrade Kit',
    weight = 3500,
    type = 'item',
    image = 'stancer.png',
    unique = false,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Unlocks camber, wheel width, track width and stance adjustment.'
},

hydraulics_kit = {
    name = 'hydraulics_kit',
    label = 'Hydraulics Kit',
    weight = 6000,
    type = 'item',
    image = 'hydraulics_kit.png',
    unique = false,
    useable = true,
    shouldClose = true,
    combinable = nil,
    description = 'Installs or removes permanent hydraulic suspension controls.'
},
