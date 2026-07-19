-- Add these entries inside QBCore.Shared.Items in qb-core/shared/items.lua.
-- Quality-bearing items are unique so qb-inventory keeps each item's metadata.

['fertilizer'] = {
    name = 'fertilizer', label = 'Fertilizer', weight = 500, type = 'item',
    image = 'fertilizer.png', unique = false, useable = false, shouldClose = true,
    combinable = nil, description = 'Plant fertilizer that improves quality and yield.'
},
['empty_weed_bag'] = {
    name = 'empty_weed_bag', label = 'Empty Weed Bag', weight = 5, type = 'item',
    image = 'empty_weed_bag.png', unique = false, useable = false, shouldClose = true,
    combinable = nil, description = 'A small empty bag used to package weed.'
},
['rolling_paper'] = {
    name = 'rolling_paper', label = 'Rolling Paper', weight = 2, type = 'item',
    image = 'rolling_paper.png', unique = false, useable = true, shouldClose = true,
    combinable = nil, description = 'Paper used to roll a joint.'
},
['plant_pot'] = {
    name = 'plant_pot', label = 'Plant Pot', weight = 1000, type = 'item',
    image = 'plant_pot.png', unique = false, useable = true, shouldClose = true,
    combinable = nil, description = 'A pot for growing plants.'
},
['shovel'] = {
    name = 'shovel', label = 'Shovel', weight = 2500, type = 'item',
    image = 'shovel.png', unique = true, useable = true, shouldClose = true,
    combinable = nil, description = 'Used to dig for graded dirt.'
},
['dirt_a'] = {
    name = 'dirt_a', label = 'Class A Dirt', weight = 1000, type = 'item',
    image = 'dirt_a.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'The highest grade growing soil.'
},
['dirt_b'] = {
    name = 'dirt_b', label = 'Class B Dirt', weight = 1000, type = 'item',
    image = 'dirt_b.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'High grade growing soil.'
},
['dirt_c'] = {
    name = 'dirt_c', label = 'Class C Dirt', weight = 1000, type = 'item',
    image = 'dirt_c.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'Average growing soil.'
},
['dirt_d'] = {
    name = 'dirt_d', label = 'Class D Dirt', weight = 1000, type = 'item',
    image = 'dirt_d.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'Low grade and common growing soil.'
},
['weed_seed'] = {
    name = 'weed_seed', label = 'Weed Seed', weight = 5, type = 'item',
    image = 'weed_seed.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'A seed carrying percentage-based genetics.'
},
['weed_bud'] = {
    name = 'weed_bud', label = 'Weed Bud', weight = 20, type = 'item',
    image = 'weed_bud.png', unique = true, useable = true, shouldClose = true,
    combinable = nil, description = 'Loose weed bud. Use it to package the bud.'
},
['weed_baggy'] = {
    name = 'weed_baggy', label = 'Bagged Weed', weight = 25, type = 'item',
    image = 'weed_baggy.png', unique = true, useable = true, shouldClose = true,
    combinable = nil, description = 'Packaged weed ready to sell. Use it to unpack it.'
},
['weed_joint'] = {
    name = 'weed_joint', label = 'Joint', weight = 10, type = 'item',
    image = 'weed_joint.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'A joint with percentage-based potency.'
},
['weed_brick'] = {
    name = 'weed_brick', label = 'Weed Brick', weight = 500, type = 'item',
    image = 'weed_brick.png', unique = true, useable = false, shouldClose = true,
    combinable = nil, description = 'A compressed brick made from loose buds.'
},
