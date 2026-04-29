local Translations = {
    menus = {
        header = 'Crafting Menu',
        pickupworkBench = 'Pick up Workbench',
        entercraftAmount = 'Enter Craft Amount:',
        noRecipes = 'No recipes available'
    },
    notifications = {
        pickupBench = 'You picked up the workbench.',
        invalidAmount = 'Invalid amount entered',
        invalidInput = 'Invalid input entered',
        notenoughMaterials = "You don't have enough materials!",
        craftingCancelled = 'You cancelled crafting',
        tablePlace = 'Your crafting table was placed',
        craftMessage = 'You crafted %sx %s',
        xpGain = 'You gained %d XP in %s',
        missingItem = 'Missing shared item: %s',
        noAccess = 'You do not have access to this bench',
        failed = 'Crafting failed, some materials were lost!'
    }
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true
})
