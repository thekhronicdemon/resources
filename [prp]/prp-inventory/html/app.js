const InventoryContainer = Vue.createApp({
    data() {
        return {
            equippedItems: {
                phone: null,
                simcard: null,
                backpack: null,
                gadget: null,
                gadget2: null,
                armour: null
            },

            maxWeight: 0,
            totalSlots: 0,
            isInventoryOpen: false,
            characterPreviewActive: false,
            isOtherInventoryEmpty: true,
            errorSlot: null,

            playerInventory: {},
            inventoryLabel: "Inventory",

            otherInventory: {},
            otherInventoryName: "",
            otherInventoryLabel: "Drop",
            otherInventoryMaxWeight: 1000000,
            otherInventorySlots: 100,
            backpackInventory: {},
            backpackInventoryName: "",
            backpackInventoryLabel: "Backpack",
            backpackInventoryMaxWeight: 0,
            backpackInventorySlots: 0,
            isShopInventory: false,
            groundSlots: 20,
            showUtilityPanel: false,
            shopSellBackRate: 0.7,
            shopAmount: 1,

            showContextMenu: false,
            contextMenuPosition: { top: "0px", left: "0px" },
            contextMenuItem: null,
            contextMenuInventory: "player",
            showSubmenu: false,
            activeSubmenu: null,

            showHotbar: false,
            hotbarItems: [],
            quickSlotCount: 4,
            quickSlotAssignments: {},
            quickSlotItems: {},

            showNotification: false,
            notificationText: "",
            notificationImage: "",
            notificationType: "added",
            notificationAmount: 1,

            showRequiredItems: false,
            requiredItems: [],

            selectedWeapon: null,
            showWeaponAttachments: false,
            selectedWeaponAttachments: [],
            selectedWeaponAvailableAttachments: [],
            selectedWeaponModMessage: "",

            selectedDevice: null,
            showDeviceAttachments: false,
            selectedDeviceAttachments: [],
            selectedDeviceAvailableAttachments: [],
            selectedDeviceModMessage: "",

            activeInventoryTab: "items",
            showCraftingPanel: false,
            craftingRecipes: [],
            activeCraftingCategory: "All",
            craftingGrid: Array(9).fill(null),
            craftingStatus: "",
            craftingBusy: false,

            inventorySectionOpen: true,
            backpackSectionOpen: true,
            backpackOpenRequestPending: false,

            currentlyDraggingItem: null,
            currentlyDraggingSlot: null,
            currentlyDraggingQuickSlot: null,
            currentlyDraggingEquipmentSlot: null,
            dragStartX: 0,
            dragStartY: 0,
            ghostElement: null,
            dragStartInventoryType: "player",
            transferAmount: null
        };
    },

    computed: {
        visibleInventorySlots() {
            const slots = [];
            for (let i = 1; i <= this.totalSlots; i++) {
                slots.push(i);
            }
            return slots;
        },

        playerWeight() {
            return Object.values(this.playerInventory).reduce((total, item) => {
                if (item && item.weight !== undefined) {
                    const amount = Number(item.amount) || 1;
                    return total + item.weight * amount;
                }
                return total;
            }, 0);
        },

        otherInventoryWeight() {
            return Object.values(this.otherInventory).reduce((total, item) => {
                if (item && item.weight !== undefined) {
                    const amount = Number(item.amount) || 1;
                    return total + item.weight * amount;
                }
                return total;
            }, 0);
        },

        weightBarClass() {
            const pct = this.maxWeight > 0 ? (this.playerWeight / this.maxWeight) * 100 : 0;
            if (pct < 50) return "low";
            if (pct < 75) return "medium";
            return "high";
        },

        otherWeightBarClass() {
            const pct = this.otherInventoryMaxWeight > 0 ? (this.otherInventoryWeight / this.otherInventoryMaxWeight) * 100 : 0;
            if (pct < 50) return "low";
            if (pct < 75) return "medium";
            return "high";
        },

        usedPlayerSlots() {
            return Object.values(this.playerInventory).filter((item) => item).length;
        },

        usedOtherSlots() {
            return Object.values(this.otherInventory).filter(Boolean).length;
        },

        normalizedShopAmount() {
            const amount = Math.floor(Number(this.shopAmount) || 1);
            return amount > 0 ? amount : 1;
        },

        hasExternalStorageInventory() {
            return !this.isOtherInventoryEmpty;
        },

        canShowUtilityPanel() {
            if (!this.hasExternalStorageInventory || this.isShopInventory) return false;
            const inventoryText = `${this.otherInventoryName || ""} ${this.otherInventoryLabel || ""}`.toLowerCase();
            return /glove\s*box|glovebox|trunk/.test(inventoryText);
        },

        isUtilityViewActive() {
            return this.canShowUtilityPanel && this.showUtilityPanel;
        },

        utilityReturnLabel() {
            const inventoryText = `${this.otherInventoryName || ""} ${this.otherInventoryLabel || ""}`.toLowerCase();
            if (/glove\s*box|glovebox/.test(inventoryText)) return "GLOVEBOX";
            if (inventoryText.includes("trunk")) return "TRUNK";
            return "STORAGE";
        },

        canShowCraftingPanel() {
            return !this.showWeaponAttachments && !this.showDeviceAttachments;
        },

        isCraftingPanelOpen() {
            return this.canShowCraftingPanel && this.showCraftingPanel;
        },

        craftingInventoryItems() {
            return Object.values(this.playerInventory)
                .filter((item) => item)
                .sort((a, b) => (a.label || a.name || "").localeCompare(b.label || b.name || ""));
        },

        isBackpackInventory() {
            const name = String(this.otherInventoryName || "").toLowerCase();
            const label = String(this.otherInventoryLabel || "").toLowerCase();
            return name.startsWith("backpack_") || label.includes("backpack");
        },

        backpackSlots() {
            const backpack = this.getEquipmentPreview("backpack");
            if (!backpack) return 0;
            const backpackInfo = backpack.info || {};
            if (this.backpackInventoryName) return Number(this.backpackInventorySlots) || Number(backpackInfo.slots) || 20;
            return Number(backpackInfo.slots) || 20;
        },

        backpackMaxWeight() {
            const backpack = this.getEquipmentPreview("backpack");
            if (!backpack) return 1;
            const backpackInfo = backpack.info || {};
            if (this.backpackInventoryName) return Number(this.backpackInventoryMaxWeight) || Number(backpackInfo.maxweight) || 50000;
            return Number(backpackInfo.maxweight) || 50000;
        },

        backpackWeight() {
            if (!this.getEquipmentPreview("backpack")) return 0;
            return Object.values(this.backpackInventory || {}).reduce((total, item) => {
                if (item && item.weight !== undefined) {
                    const amount = Number(item.amount) || 1;
                    return total + item.weight * amount;
                }
                return total;
            }, 0);
        },

        usedBackpackSlots() {
            if (!this.getEquipmentPreview("backpack")) return 0;
            return Object.values(this.backpackInventory || {}).filter(Boolean).length;
        },

        visibleBackpackSlots() {
            const slots = [];
            const total = this.backpackSlots || 20;
            for (let i = 1; i <= total; i++) slots.push(i);
            return slots;
        },

        craftingCategories() {
            const categories = ["All"];
            this.craftingRecipes.forEach((recipe) => {
                const category = recipe.category || "General";
                if (!categories.includes(category)) categories.push(category);
            });
            return categories;
        },

        visibleCatalogueRecipes() {
            const category = this.activeCraftingCategory || "All";
            return this.craftingRecipes
                .filter((recipe) => category === "All" || (recipe.category || "General") === category)
                .sort((a, b) => (a.output?.label || a.id || "").localeCompare(b.output?.label || b.id || ""));
        },

        craftableRecipes() {
            return this.visibleCatalogueRecipes;
        },

        craftingMatchedRecipe() {
            return this.craftingRecipes.find((recipe) => this.isRecipeKnown(recipe) && this.doesCraftingGridMatch(recipe)) || null;
        },

        craftingOutput() {
            return this.craftingMatchedRecipe ? this.craftingMatchedRecipe.output : null;
        },

        craftingMaterials() {
            const recipe = this.craftingMatchedRecipe;
            if (!recipe) return [];
            return (recipe.ingredients || []).map((ingredient) => {
                const playerAmount = this.getCraftingItemAmount(ingredient.item);
                return {
                    ...ingredient,
                    playerAmount,
                    hasEnough: playerAmount >= (Number(ingredient.amount) || 1)
                };
            });
        },

        canCraftMatchedRecipe() {
            return !!this.craftingMatchedRecipe && !this.craftingBusy && this.craftingMaterials.every((item) => item.hasEnough);
        }
    },

    watch: {
        transferAmount(newVal) {
            if (newVal !== null && newVal !== "" && Number(newVal) < 1) {
                this.transferAmount = 1;
            }
        },

        shopAmount(newVal) {
            if (newVal !== null && newVal !== "" && Number(newVal) < 1) {
                this.shopAmount = 1;
            }
        }
    },

    methods: {
        notify(message, type = "error") {
            const msg = message || "Action failed";

            try {
                axios.post("https://prp-inventory/Notify", {
                    message: msg,
                    type: type
                }).catch(() => {});
            } catch (e) {}

            try {
                axios.post("https://qb-core/Notify", {
                    text: msg,
                    type: type
                }).catch(() => {});
            } catch (e) {}

            // Fallback for older NUI callbacks handled client-side.
            try {
                fetch(`https://${GetParentResourceName()}/Notify`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json; charset=UTF-8" },
                    body: JSON.stringify({ message: msg, type: type })
                }).catch(() => {});
            } catch (e) {}
        },

        formatRequestError(error) {
            if (!error) return "Unknown error";
            if (typeof error === "string") return error;

            const responseData = error.response && error.response.data;
            if (responseData) {
                if (typeof responseData === "string") return responseData;
                if (responseData.message) return responseData.message;
            }

            if (error.message) return error.message;
            if (error.messageText) return error.messageText;

            try {
                return JSON.stringify(error);
            } catch (e) {
                return String(error);
            }
        },


        toggleInventorySection() {
            this.inventorySectionOpen = !this.inventorySectionOpen;
        },

        toggleBackpackSection() {
            this.backpackSectionOpen = !this.backpackSectionOpen;
            if (this.backpackSectionOpen && this.getEquipmentPreview("backpack")) {
                this.openBackpackStorage();
            }
        },

        getBackpackSlotItem(slot) {
            return this.backpackInventory[slot] || this.backpackInventory[String(slot)] || null;
        },

        getRarity(item) {
            if (!item) return "common";
            return item.rarity || (item.info && item.info.rarity) || "common";
        },
        normalizeItemAmount(item) {
            if (!item) return 0;
            const amt = Number(item.amount);
            return amt > 0 ? amt : 1;
        },

        cloneItem(item) {
            return JSON.parse(JSON.stringify(item));
        },

        cloneInventory(inventory) {
            const cloned = {};
            Object.keys(inventory || {}).forEach((slot) => {
                if (inventory[slot]) cloned[slot] = this.cloneItem(inventory[slot]);
            });
            return cloned;
        },

        getInventoryByType(inventoryType) {
            if (inventoryType === "player") return this.playerInventory;
            if (inventoryType === "backpack") return this.backpackInventory;
            return this.otherInventory;
        },

        setInventoryByType(inventoryType, inventory) {
            if (inventoryType === "player") {
                this.playerInventory = { ...inventory };
            } else if (inventoryType === "backpack") {
                this.backpackInventory = { ...inventory };
            } else {
                this.otherInventory = { ...inventory };
            }
        },

        getItemInSlot(slot, inventoryType) {
            if (inventoryType === "player") {
                return this.playerInventory[slot] || this.playerInventory[String(slot)] || null;
            }
            if (inventoryType === "backpack") return this.backpackInventory[slot] || this.backpackInventory[String(slot)] || null;
            if (inventoryType === "other") return this.otherInventory[slot] || this.otherInventory[String(slot)] || null;
            return null;
        },

        toggleCraftingPanel() {
            this.showCraftingPanel = !this.showCraftingPanel;
            this.showContextMenu = false;
            if (this.showCraftingPanel) {
                this.showWeaponAttachments = false;
                this.showDeviceAttachments = false;
                this.loadCraftingData();
            }
        },

        switchInventoryTab(tab) {
            this.activeInventoryTab = tab;
            this.showContextMenu = false;
            if (tab === "crafting") {
                this.showWeaponAttachments = false;
                this.showDeviceAttachments = false;
                this.loadCraftingData();
            }
        },

        loadCraftingData() {
            axios.post("https://prp-inventory/GetCraftingData", {}).then((response) => {
                const data = response.data || {};
                if (!data.success) {
                    this.notify(data.message || "Crafting is unavailable.", "error");
                    this.craftingRecipes = [];
                    return;
                }

                this.craftingRecipes = Array.isArray(data.recipes) ? data.recipes : [];
                if (!this.craftingCategories.includes(this.activeCraftingCategory)) {
                    this.activeCraftingCategory = "All";
                }
                const gridSize = Number(data.gridSize) || 9;
                if (this.craftingGrid.length !== gridSize) {
                    this.craftingGrid = Array(gridSize).fill(null);
                }
                this.updateCraftingStatus();
            }).catch((error) => {
                console.error("GetCraftingData error:", error);
                this.notify("Crafting data failed to load.", "error");
            });
        },

        addCraftingIngredient(item) {
            if (!item || this.craftingBusy) return;
            const emptyIndex = this.craftingGrid.findIndex((slot) => !slot);
            if (emptyIndex === -1) {
                this.notify("The crafting grid is full.", "error");
                return;
            }

            const copy = {
                name: item.name,
                label: item.label || item.name,
                image: item.image || "default.png",
                slot: item.slot
            };
            this.craftingGrid.splice(emptyIndex, 1, copy);
            this.updateCraftingStatus();
        },

        isRecipeKnown(recipe) {
            return recipe && recipe.known !== false;
        },

        formatRecipeIngredients(recipe) {
            const ingredients = (recipe && recipe.ingredients) || [];
            if (!ingredients.length) return "No ingredients listed";
            return ingredients
                .map((ingredient) => `${ingredient.label || ingredient.item} x${ingredient.amount || 1}`)
                .join(", ");
        },


        setCraftingCategory(category) {
            this.activeCraftingCategory = category || "All";
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
        },

        selectCraftingRecipe(recipe) {
            if (!recipe || this.craftingBusy) return;
            this.craftingStatus = `${recipe.output?.label || recipe.id} selected. Add ingredients to the grid.`;
        },

        clearCraftingSlot(index) {
            if (this.craftingBusy) return;
            this.craftingGrid.splice(index, 1, null);
            this.updateCraftingStatus();
        },

        clearCraftingGrid() {
            if (this.craftingBusy) return;
            this.craftingGrid = this.craftingGrid.map(() => null);
            this.updateCraftingStatus();
        },

        getCraftingGridNames() {
            return this.craftingGrid.map((item) => {
                if (!item || !item.name) return null;
                return {
                    name: item.name,
                    amount: Math.max(1, Math.floor(Number(item.amount) || 1))
                };
            }).filter(Boolean);
        },

        consumeCraftingGridMaterials(recipe) {
            if (!recipe || !Array.isArray(recipe.ingredients)) return;
            const remainingCosts = {};
            recipe.ingredients.forEach((ingredient) => {
                if (!ingredient || !ingredient.item) return;
                remainingCosts[ingredient.item] = (remainingCosts[ingredient.item] || 0) + Math.max(1, Math.floor(Number(ingredient.amount) || 1));
            });

            const nextGrid = this.craftingGrid.map((slotItem) => {
                if (!slotItem || !slotItem.name) return null;
                const costLeft = remainingCosts[slotItem.name] || 0;
                if (costLeft <= 0) return slotItem;

                const slotAmount = Math.max(1, Math.floor(Number(slotItem.amount) || 1));
                const take = Math.min(slotAmount, costLeft);
                remainingCosts[slotItem.name] -= take;
                const newAmount = slotAmount - take;
                if (newAmount <= 0) return null;
                return { ...slotItem, amount: newAmount };
            });

            this.craftingGrid = nextGrid;
        },

        getCraftingItemAmount(itemName) {
            return Object.values(this.playerInventory).reduce((total, item) => {
                if (item && item.name === itemName) return total + this.normalizeItemAmount(item);
                return total;
            }, 0);
        },

        getCraftingRecipeCountMap(recipe) {
            const counts = {};
            (recipe.ingredients || []).forEach((ingredient) => {
                const itemName = ingredient.item;
                if (!itemName) return;
                counts[itemName] = (counts[itemName] || 0) + Math.max(1, Number(ingredient.amount) || 1);
            });
            return counts;
        },

        getCraftingGridCountMap() {
            const counts = {};
            this.craftingGrid.forEach((item) => {
                if (!item || !item.name) return;
                counts[item.name] = (counts[item.name] || 0) + Math.max(1, Number(item.amount) || 1);
            });
            return counts;
        },

        canPlayerCraftRecipe(recipe) {
            if (!recipe || !Array.isArray(recipe.ingredients)) return false;
            return recipe.ingredients.every((ingredient) => this.getCraftingItemAmount(ingredient.item) >= (Number(ingredient.amount) || 1));
        },

        doesCraftingGridMatch(recipe) {
            if (!recipe) return false;
            if (recipe.method === "shaped" && Array.isArray(recipe.pattern)) {
                const namesMatch = recipe.pattern.every((itemName, index) => {
                    const gridItem = this.craftingGrid[index];
                    return (gridItem && gridItem.name || null) === (itemName || null);
                });
                if (!namesMatch) return false;
            }

            const expected = this.getCraftingRecipeCountMap(recipe);
            const actual = this.getCraftingGridCountMap();
            const expectedKeys = Object.keys(expected);
            const actualKeys = Object.keys(actual);
            if (expectedKeys.length === 0) return false;
            if (actualKeys.some((itemName) => !expected[itemName])) return false;
            return expectedKeys.every((itemName) => (actual[itemName] || 0) >= expected[itemName]);
        },

        updateCraftingStatus() {
            this.craftingStatus = "";
        },

        craftMatchedRecipe() {
            const recipe = this.craftingMatchedRecipe;
            if (this.craftingBusy) return;

            if (!recipe) {
                this.notify("No Craft Found", "error");
                return;
            }

            if (!this.canCraftMatchedRecipe) {
                this.notify("Not Enough Materials", "error");
                return;
            }

            this.craftingBusy = true;
            this.craftingStatus = "";
            axios.post("https://prp-inventory/CraftGridRecipe", {
                recipeId: recipe.id,
                grid: this.getCraftingGridNames()
            }).then((response) => {
                const result = response.data || {};
                if (!result.success) { this.notify(result.message || "Crafting Failed", "error"); }
                if (result.success) {
                    if (result.inventory) {
                        this.updateInventory({ inventory: result.inventory });
                    }
                    this.consumeCraftingGridMaterials(recipe);
                    this.updateCraftingStatus();
                }
            }).catch((error) => {
                console.error("CraftGridRecipe error:", error);
                this.notify("Crafting Failed", "error");
            }).finally(() => {
                this.craftingBusy = false;
            });
        },

        getHotbarItemInSlot(slot) {
            return this.quickSlotItems[slot] || null;
        },

        getStandaloneHotbarItem(slot) {
            if (!this.hotbarItems) return null;
            if (Array.isArray(this.hotbarItems)) {
                return this.hotbarItems[slot - 1] || null;
            }

            return this.hotbarItems[String(slot)] || this.hotbarItems[slot] || null;
        },



        autoOpenBackpackIfEquipped() {
            if (!this.getEquipmentPreview("backpack")) return;
            if (this.backpackInventoryName) return;
            setTimeout(() => {
                if (this.getEquipmentPreview("backpack") && !this.backpackInventoryName) {
                    this.openBackpackStorage();
                }
            }, 250);
        },

        openBackpackStorage() {
            if (!this.getEquipmentPreview("backpack")) return;
            if (this.backpackOpenRequestPending) return;

            this.backpackOpenRequestPending = true;
            axios.post("https://prp-inventory/OpenBackpack", {}).then((response) => {
                const result = response.data || {};
                if (result.success === false) {
                    this.notify(result.message || "Could not open backpack", "error");
                }
            }).catch((error) => {
                console.error("OpenBackpack error:", error);
                this.notify("Could not open backpack", "error");
            }).finally(() => {
                this.backpackOpenRequestPending = false;
            });
        },

        getEquipmentPreview(type) {
            return this.equippedItems[type] || null;
        },

        getEquipmentArmorPercent(item) {
            if (!item || !item.info) return 0;
            const armor = Number(item.info.armor);
            return Number.isFinite(armor) ? Math.max(0, Math.min(100, armor)) : 0;
        },

        isArmourItem(item) {
            return item && (item.armor === true || item.name === "armor" || item.name === "heavyarmor");
        },

        isBackpackItem(item) {
            return item && (item.backpack === true || item.name === "backpack");
        },

        isGadgetItem(item) {
            return item && (item.gadget === true || item.name === "parachute");
        },

        isPhoneItem(item) {
            return item && (item.phone === true || ["phone", "iphone", "samsungphone"].includes(item.name));
        },

        isArmorPlateItem(item) {
            return item && (item.name === "armor_plate" || item.name === "armor_plates");
        },

        canEquipItemToSlot(equipmentSlot, item) {
            if (!equipmentSlot || !item || !item.name) return false;

            const itemName = String(item.name).toLowerCase();

            if (itemName === "simcard" || itemName === "sim_card") {
                return equipmentSlot === "simcard";
            }

            if (equipmentSlot === "phone") {
                return item.phone === true || itemName === "phone" || itemName === "iphone" || itemName === "samsungphone";
            }

            if (equipmentSlot === "simcard") {
                return item.simcard === true || itemName === "simcard" || itemName === "sim_card";
            }

            if (equipmentSlot === "backpack") {
                return item.backpack === true || itemName === "backpack";
            }

            if (equipmentSlot === "armour") {
                return item.armor === true || item.armour === true || itemName === "armor" || itemName === "heavyarmor";
            }

            if (equipmentSlot === "gadget" || equipmentSlot === "gadget2") {
                return item.gadget === true || itemName === "parachute";
            }

            return false;
        },

        normalizeQuickSlotAssignments(assignments) {
            const normalized = {};
            if (!assignments || typeof assignments !== "object") return normalized;

            for (let i = 1; i <= this.quickSlotCount; i++) {
                const rawSlot = assignments[i] || assignments[String(i)];
                const itemSlot = Number(rawSlot);
                if (Number.isFinite(itemSlot) && itemSlot > 0) {
                    normalized[i] = itemSlot;
                }
            }

            return normalized;
        },

        isQuickSlotAssignedItemSlot(slot) {
            const itemSlot = Number(slot);
            if (!itemSlot) return false;

            for (let i = 1; i <= this.quickSlotCount; i++) {
                const assigned = Number(this.quickSlotAssignments[i] || this.quickSlotAssignments[String(i)]);
                if (assigned === itemSlot) return true;
            }

            return false;
        },

        refreshQuickSlots() {
            const items = {};
            for (let i = 1; i <= this.quickSlotCount; i++) {
                const itemSlot = this.quickSlotAssignments[i] || this.quickSlotAssignments[String(i)];
                items[i] = itemSlot ? (this.playerInventory[itemSlot] || null) : null;
            }
            this.quickSlotItems = items;
        },

        setLocalQuickSlotAssignment(quickSlot, itemSlot) {
            delete this.quickSlotAssignments[quickSlot];
            delete this.quickSlotAssignments[String(quickSlot)];
            if (itemSlot) {
                this.quickSlotAssignments[quickSlot] = Number(itemSlot);
            }
        },

        syncQuickSlotsAfterLocalMove(fromInventory, toInventory, fromSlot, toSlot, fromAmount, sourceAmount, sourceItem, targetItem) {
            const movingAll = fromAmount >= sourceAmount;
            const sameItemStack = !!(
                sourceItem &&
                targetItem &&
                sourceItem.name === targetItem.name &&
                !sourceItem.unique &&
                !targetItem.unique
            );

            for (let i = 1; i <= this.quickSlotCount; i++) {
                const assigned = Number(this.quickSlotAssignments[i] || this.quickSlotAssignments[String(i)]);
                if (!assigned) continue;

                if (fromInventory === "player" && toInventory === "player") {
                    if (targetItem && sameItemStack) {
                        if (movingAll && assigned === fromSlot) this.setLocalQuickSlotAssignment(i, toSlot);
                    } else if (targetItem) {
                        if (assigned === fromSlot) this.setLocalQuickSlotAssignment(i, toSlot);
                        else if (assigned === toSlot) this.setLocalQuickSlotAssignment(i, fromSlot);
                    } else if (movingAll && assigned === fromSlot) {
                        this.setLocalQuickSlotAssignment(i, toSlot);
                    }
                } else if (fromInventory === "player" && movingAll && assigned === fromSlot) {
                    this.setLocalQuickSlotAssignment(i, null);
                } else if (toInventory === "player" && targetItem && !sameItemStack && assigned === toSlot) {
                    this.setLocalQuickSlotAssignment(i, null);
                }
            }
        },

        applyLocalInventoryMove(fromInventory, toInventory, fromSlot, toSlot, fromAmount) {
            const sourceInventory = this.cloneInventory(this.getInventoryByType(fromInventory));
            const targetInventory = fromInventory === toInventory ? sourceInventory : this.cloneInventory(this.getInventoryByType(toInventory));

            const sourceSlot = Number(fromSlot);
            const targetSlotNum = Number(toSlot);
            const moveAmount = Number(fromAmount) || 1;

            const sourceItem = sourceInventory[sourceSlot];
            if (!sourceItem) return false;

            const sourceAmount = this.normalizeItemAmount(sourceItem);
            const targetItem = targetInventory[targetSlotNum] || null;

            if (fromInventory === toInventory && sourceSlot === targetSlotNum) {
                return false;
            }

            this.syncQuickSlotsAfterLocalMove(
                fromInventory,
                toInventory,
                sourceSlot,
                targetSlotNum,
                moveAmount,
                sourceAmount,
                sourceItem,
                targetItem
            );

            if (!targetItem) {
                const movedItem = this.cloneItem(sourceItem);

                if (moveAmount >= sourceAmount) {
                    delete sourceInventory[sourceSlot];
                    movedItem.slot = targetSlotNum;
                    targetInventory[targetSlotNum] = movedItem;
                } else {
                    sourceInventory[sourceSlot].amount = sourceAmount - moveAmount;
                    movedItem.amount = moveAmount;
                    movedItem.slot = targetSlotNum;
                    targetInventory[targetSlotNum] = movedItem;
                }
                this.setInventoryByType(fromInventory, sourceInventory);
                if (fromInventory !== toInventory) this.setInventoryByType(toInventory, targetInventory);
                return true;
            }

            const targetAmount = this.normalizeItemAmount(targetItem);

            if (
                sourceItem.name === targetItem.name &&
                !sourceItem.unique &&
                !targetItem.unique
            ) {
                targetInventory[targetSlotNum].amount = targetAmount + moveAmount;

                if (moveAmount >= sourceAmount) {
                    delete sourceInventory[sourceSlot];
                } else {
                    sourceInventory[sourceSlot].amount = sourceAmount - moveAmount;
                }
                this.setInventoryByType(fromInventory, sourceInventory);
                if (fromInventory !== toInventory) this.setInventoryByType(toInventory, targetInventory);
                return true;
            }

            const sourceClone = this.cloneItem(sourceItem);
            const targetClone = this.cloneItem(targetItem);

            sourceClone.slot = targetSlotNum;
            targetClone.slot = sourceSlot;

            sourceInventory[sourceSlot] = targetClone;
            targetInventory[targetSlotNum] = sourceClone;
            this.setInventoryByType(fromInventory, sourceInventory);
            if (fromInventory !== toInventory) this.setInventoryByType(toInventory, targetInventory);
            return true;
        },

        openInventory(data) {
            if (this.showHotbar) {
                this.toggleHotbar(false);
            }

            this.isInventoryOpen = true;
            this.characterPreviewActive = !!data.characterPreview;
            this.transferAmount = null;
            this.maxWeight = data.maxweight || 0;
            this.totalSlots = data.slots || 0;
            this.playerInventory = {};
            this.otherInventory = {};
            this.otherInventoryName = "";
            this.otherInventoryLabel = "Drop";
            this.otherInventoryMaxWeight = 1000000;
            this.otherInventorySlots = 100;
            this.clearBackpackInventoryData();
            this.isShopInventory = false;
            this.showUtilityPanel = false;
            this.shopSellBackRate = 0.7;
            this.shopAmount = 1;
            this.isOtherInventoryEmpty = true;
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showWeaponAttachments = false;
            this.showDeviceAttachments = false;
            this.activeInventoryTab = "items";
            this.showCraftingPanel = false;
            this.backpackOpenRequestPending = false;
            this.craftingGrid = this.craftingGrid.map(() => null);
            this.craftingStatus = "";
            this.loadCraftingData();

            this.equippedItems = this.normalizeEquipment(data.equipment);
            this.quickSlotAssignments = this.normalizeQuickSlotAssignments(data.quickslots || {});

            if (data.inventory) {
                if (Array.isArray(data.inventory)) {
                    data.inventory.forEach((item) => {
                        if (item && item.slot) this.playerInventory[item.slot] = item;
                    });
                } else if (typeof data.inventory === "object") {
                    Object.keys(data.inventory).forEach((key) => {
                        const item = data.inventory[key];
                        if (item && item.slot) this.playerInventory[item.slot] = item;
                    });
                }
            }

            if (data.other) {
                this.applyOtherInventoryData(data.other);
                this.shopSellBackRate = Number(data.other.sellBackRate) || 0.7;
            }

            if (data.backpack) {
                this.applyBackpackInventoryData(data.backpack);
            }

            this.refreshQuickSlots();
            if (this.getEquipmentPreview("backpack")) {
                this.autoOpenBackpackIfEquipped();
            }
        },

        normalizeInventory(inventory) {
            const newPlayerInventory = {};

            if (inventory) {
                if (Array.isArray(inventory)) {
                    inventory.forEach((item) => {
                        if (item && item.slot) newPlayerInventory[item.slot] = item;
                    });
                } else if (typeof inventory === "object") {
                    Object.keys(inventory).forEach((key) => {
                        const item = inventory[key];
                        if (item && item.slot) newPlayerInventory[item.slot] = item;
                    });
                }
            }

            return newPlayerInventory;
        },

        applyOtherInventoryData(other) {
            if (other && this.isBackpackPayload(other)) {
                this.applyBackpackInventoryData(other);
                return;
            }

            const normalizedOther = this.normalizeInventory(other && other.inventory);

            this.otherInventory = normalizedOther;
            this.otherInventoryName = (other && other.name) || this.otherInventoryName || "";
            this.otherInventoryLabel = (other && other.label) || this.otherInventoryLabel || "Storage";
            this.otherInventoryMaxWeight = (other && other.maxweight) || this.otherInventoryMaxWeight || 0;
            this.otherInventorySlots = (other && other.slots) || this.otherInventorySlots || 0;
            this.isShopInventory = String(this.otherInventoryName || "").startsWith("shop-");
            this.isOtherInventoryEmpty = false;
        },

        isBackpackPayload(payload) {
            const name = String((payload && payload.name) || "").toLowerCase();
            const label = String((payload && payload.label) || "").toLowerCase();
            return name.startsWith("backpack_") || label.includes("backpack");
        },

        applyBackpackInventoryData(backpack) {
            const normalizedBackpack = this.normalizeInventory(backpack && backpack.inventory);

            this.backpackInventory = normalizedBackpack;
            this.backpackInventoryName = (backpack && backpack.name) || this.backpackInventoryName || "";
            this.backpackInventoryLabel = (backpack && backpack.label) || this.backpackInventoryLabel || "Backpack";
            this.backpackInventoryMaxWeight = (backpack && backpack.maxweight) || this.backpackInventoryMaxWeight || 0;
            this.backpackInventorySlots = (backpack && backpack.slots) || this.backpackInventorySlots || 0;
            this.backpackOpenRequestPending = false;
        },

        clearBackpackInventoryData() {
            this.backpackInventory = {};
            this.backpackInventoryName = "";
            this.backpackInventoryLabel = "Backpack";
            this.backpackInventoryMaxWeight = 0;
            this.backpackInventorySlots = 0;
            this.backpackOpenRequestPending = false;
        },

        normalizeEquipment(equipment) {
            const normalized = {
                phone: null,
                simcard: null,
                backpack: null,
                gadget: null,
                gadget2: null,
                armour: null
            };

            if (equipment && typeof equipment === "object") {
                Object.keys(equipment).forEach((slot) => {
                    if (Object.prototype.hasOwnProperty.call(normalized, slot)) {
                        normalized[slot] = equipment[slot] || null;
                    }
                });
            }

            return normalized;
        },

        updateInventory(data) {
            if (Object.prototype.hasOwnProperty.call(data, "inventory") || Object.prototype.hasOwnProperty.call(data, "Inventory")) {
                this.playerInventory = { ...this.normalizeInventory(data.inventory || data.Inventory) };
            }

            if (data.other) {
                this.applyOtherInventoryData(data.other);
            }

            if (data.backpack) {
                this.applyBackpackInventoryData(data.backpack);
            }

            if (Object.prototype.hasOwnProperty.call(data, "equipment")) {
                this.equippedItems = this.normalizeEquipment(data.equipment);
                if (!this.equippedItems.backpack) {
                    this.clearBackpackInventoryData();
                }
            }
            if (data.quickslots) {
                this.quickSlotAssignments = this.normalizeQuickSlotAssignments(data.quickslots);
            }
            this.refreshQuickSlots();

            if (this.showDeviceAttachments && this.selectedDevice && this.selectedDevice.slot) {
                const liveDevice = this.playerInventory[this.selectedDevice.slot] || this.selectedDevice;
                this.selectedDevice = liveDevice;
                this.selectedDeviceAvailableAttachments = this.buildAvailableDeviceAttachments(liveDevice);
            }

            if (this.activeInventoryTab === "crafting") {
                this.updateCraftingStatus();
            }
        },

        closeInventory() {
            this.clearDragData();

            axios.post("https://prp-inventory/CloseInventory", {
                name: this.otherInventoryName || ""
            }).catch((error) => {
                console.error("Error closing inventory:", error);
            });

            this.isInventoryOpen = false;
            this.characterPreviewActive = false;
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showWeaponAttachments = false;
            this.showDeviceAttachments = false;
            this.showRequiredItems = false;
            this.showNotification = false;
            this.showUtilityPanel = false;
            this.showCraftingPanel = false;
            this.backpackOpenRequestPending = false;
        },

        clearTransferAmount() {
            this.transferAmount = null;
        },

        setUtilityPanel(open) {
            this.clearDragData();
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showUtilityPanel = !!open && this.canShowUtilityPanel;
        },

        containerMouseDownAction(event) {
            if (event.button === 0 && this.showContextMenu) {
                if (event.target.closest && (event.target.closest(".context-menu") || event.target.closest(".submenu"))) return;
                this.showContextMenu = false;
                this.showSubmenu = false;
                this.activeSubmenu = null;
            }
        },

        handleMouseDown(event, slot, inventory) {
            if (event.button === 1) return;
            event.preventDefault();

            const itemInSlot = this.getItemInSlot(slot, inventory);

            if (event.button === 0) {
                if (event.shiftKey && itemInSlot) {
                    this.splitAndPlaceItem(itemInSlot, inventory);
                } else {
                    this.startDrag(event, slot, inventory);
                }
            } else if (event.button === 2 && itemInSlot) {
                this.showContextMenuOptions(event, itemInSlot, inventory);
            }
        },

        moveItemBetweenInventories(item, sourceInventoryType, targetInventoryOverride = null) {
            const targetInventoryType = targetInventoryOverride || (sourceInventoryType === "player" ? "other" : "player");
            const targetInventory = this.getInventoryByType(targetInventoryType);
            const targetSlot = this.findNextAvailableSlot(targetInventory, targetInventoryType);

            if (targetSlot === null) {
                this.inventoryError(item.slot);
                return;
            }

            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = item.slot;
            this.dragStartInventoryType = sourceInventoryType;

            this.handleItemDrop(targetInventoryType, targetSlot);
        },

        startDrag(event, slot, inventoryType) {
            event.preventDefault();
            const item = this.getItemInSlot(slot, inventoryType);
            if (!item) return;

            if (!event.shiftKey) {
                this.transferAmount = null;
            }

            const slotElement = event.target.closest(".item-slot");
            if (!slotElement) return;

            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);

            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;

            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = slot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.dragStartInventoryType = inventoryType;
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
        },

        createGhostElement(slotElement) {
            const ghostElement = slotElement.cloneNode(true);
            const rect = slotElement.getBoundingClientRect();

            ghostElement.classList.add("drag-ghost");

            // Equipment slots have absolute-position classes like .phone/.backpack.
            // Remove the class names that force them back to the equipment layout.
            ghostElement.classList.remove(
                "phone",
                "simcard",
                "backpack",
                "armour",
                "gadget",
                "gadget2",
                "hat",
                "jacket",
                "shirt",
                "pants",
                "shoes"
            );

            ghostElement.style.position = "fixed";
            ghostElement.style.left = `${rect.left}px`;
            ghostElement.style.top = `${rect.top}px`;
            ghostElement.style.width = `${rect.width}px`;
            ghostElement.style.height = `${rect.height}px`;
            ghostElement.style.margin = "0";
            ghostElement.style.pointerEvents = "none";
            ghostElement.style.opacity = "0.86";
            ghostElement.style.zIndex = "999999";
            ghostElement.style.transform = "none";
            ghostElement.style.transition = "none";
            ghostElement.style.animation = "none";
            ghostElement.style.boxSizing = "border-box";

            return ghostElement;
        },

        drag(event) {
            if (!this.currentlyDraggingItem || !this.ghostElement) return;

            const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
            const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;

            this.ghostElement.style.position = "fixed";
            this.ghostElement.style.left = `${centeredX}px`;
            this.ghostElement.style.top = `${centeredY}px`;
            this.ghostElement.style.right = "auto";
            this.ghostElement.style.bottom = "auto";
            this.ghostElement.style.transform = "none";
        },

        endDrag(event) {
            if (!this.currentlyDraggingItem) return;

            const elementsUnderCursor = document.elementsFromPoint(event.clientX, event.clientY);

            const quickSlotElement = elementsUnderCursor
                .map((el) => el.classList.contains("hotbar-slot") ? el : (el.closest && el.closest(".hotbar-slot")))
                .find(Boolean);

            const equipmentSlotElement = elementsUnderCursor
                .map((el) => el.classList.contains("equipment-slot") ? el : (el.closest && el.closest(".equipment-slot")))
                .find(Boolean);

            const backpackSlotElement = elementsUnderCursor
                .map((el) => el.classList && el.classList.contains("item-slot") ? el : (el.closest && el.closest(".item-slot")))
                .find((el) => el && el.hasAttribute("data-slot") && el.closest(".embedded-backpack-grid"));

            const playerSlotElement = elementsUnderCursor
                .map((el) => el.classList && el.classList.contains("item-slot") ? el : (el.closest && el.closest(".item-slot")))
                .find((el) => el && el.hasAttribute("data-slot") && el.closest(".inventory-panel") && !el.closest(".embedded-backpack-grid"));

            const otherSlotElement = elementsUnderCursor
                .map((el) => el.classList && el.classList.contains("item-slot") ? el : (el.closest && el.closest(".item-slot")))
                .find((el) => el && el.hasAttribute("data-slot") && el.closest(".right-grid"));

            const deviceSlotElement = elementsUnderCursor
                .map((el) => el.classList.contains("device-module-slot") ? el : (el.closest && el.closest(".device-module-slot")))
                .find(Boolean);

            const craftingSlotElement = elementsUnderCursor
                .map((el) => el.classList.contains("crafting-grid-slot") ? el : (el.closest && el.closest(".crafting-grid-slot")))
                .find(Boolean);

            const groundSlotElement = elementsUnderCursor
                .map((el) => el.classList && el.classList.contains("ground-slot") ? el : (el.closest && el.closest(".ground-slot")))
                .find(Boolean);

            const overInventoryContainer = elementsUnderCursor.some(
                (el) =>
                    el.closest(".inventory-panel") ||
                    el.closest(".embedded-backpack-panel") ||
                    el.closest(".crafting-panel") ||
                    el.closest(".right-panel") ||
                    el.closest(".mid-controls") ||
                    el.closest(".context-menu") ||
                    el.closest(".prp-hotbar")
            );

            if (quickSlotElement) {
                const quickSlot = Number(quickSlotElement.dataset.slot);
                if (quickSlot && this.dragStartInventoryType === "player") {
                    this.assignQuickSlot(quickSlot, this.currentlyDraggingSlot);
                    this.clearDragData();
                    return;
                }

                if (quickSlot && this.dragStartInventoryType === "quickslot") {
                    if (
                        this.currentlyDraggingQuickSlot &&
                        quickSlot !== this.currentlyDraggingQuickSlot &&
                        this.currentlyDraggingItem &&
                        this.currentlyDraggingItem.slot
                    ) {
                        this.assignQuickSlot(quickSlot, this.currentlyDraggingItem.slot);
                        this.clearQuickSlot(this.currentlyDraggingQuickSlot);
                    }
                    this.clearDragData();
                    return;
                }
            }

            if (deviceSlotElement) {
                const targetDeviceSlot = deviceSlotElement.dataset.deviceSlot;
                if (targetDeviceSlot) {
                    this.handleDropOnDeviceSlot(targetDeviceSlot);
                }
                this.clearDragData();
                return;
            }

            if (craftingSlotElement) {
                const targetCraftingIndex = Number(craftingSlotElement.dataset.craftingIndex);
                if (!Number.isNaN(targetCraftingIndex)) {
                    this.handleDropOnCraftingSlot(targetCraftingIndex);
                }
                this.clearDragData();
                return;
            }

            if (groundSlotElement && this.dragStartInventoryType === "player") {
                this.handleDropOnGroundSlot();
                this.clearDragData();
                return;
            }
            if (backpackSlotElement) {
                const targetSlot = Number(backpackSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "backpack")) {
                    this.handleDropOnBackpackSlot(targetSlot);
                }
                this.clearDragData();
                return;
            }

            if (playerSlotElement) {
                const targetSlot = Number(playerSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "player")) {
                    this.handleDropOnPlayerSlot(targetSlot);
                }
                this.clearDragData();
                return;
            }

            if (this.dragStartInventoryType === "quickslot") {
                if (this.currentlyDraggingQuickSlot) {
                    this.clearQuickSlot(this.currentlyDraggingQuickSlot);
                }
                this.clearDragData();
                return;
            }

            if (otherSlotElement) {
                const targetSlot = Number(otherSlotElement.dataset.slot);
                if (targetSlot && !(targetSlot === this.currentlyDraggingSlot && this.dragStartInventoryType === "other")) {
                    this.handleDropOnOtherSlot(targetSlot);
                }
                this.clearDragData();
                return;
            }

            if (equipmentSlotElement) {
                const equipmentSlot = equipmentSlotElement.dataset.equipmentSlot;
                if (equipmentSlot && this.dragStartInventoryType === "player") {
                    this.handleEquipmentDrop(equipmentSlot);
                }
                this.clearDragData();
                return;
            }

            if (!overInventoryContainer && this.dragStartInventoryType === "equipment") {
                this.unequipEquipmentItem(this.currentlyDraggingEquipmentSlot);
                this.clearDragData();
                return;
            }

            if (!overInventoryContainer && this.dragStartInventoryType === "player" && this.isOtherInventoryEmpty) {
                this.handleDropOutsideInventory();
            }

            this.clearDragData();
        },

        handleDropOnGroundSlot() {
            if (!this.currentlyDraggingItem || this.dragStartInventoryType !== "player") return;
            this.dropItem(this.currentlyDraggingItem, this.transferAmount || "all");
        },

        handleDropOnCraftingSlot(targetIndex) {
            if (!this.currentlyDraggingItem || this.craftingBusy) return;

            if (this.dragStartInventoryType !== "player") {
                this.notify("Drag ingredients from your inventory into the crafting grid.", "error");
                return;
            }

            if (targetIndex < 0 || targetIndex >= this.craftingGrid.length) return;

            const maxAmount = this.normalizeItemAmount(this.currentlyDraggingItem);
            const typedAmount = Math.floor(Number(this.transferAmount));
            const requestedAmount = Number.isFinite(typedAmount) && typedAmount > 0 ? typedAmount : maxAmount;
            const amount = Math.max(1, Math.min(maxAmount, requestedAmount));

            const copy = {
                name: this.currentlyDraggingItem.name,
                label: this.currentlyDraggingItem.label || this.currentlyDraggingItem.name,
                image: this.currentlyDraggingItem.image || "default.png",
                slot: this.currentlyDraggingItem.slot,
                amount
            };

            this.craftingGrid.splice(targetIndex, 1, copy);
            this.updateCraftingStatus();
        },

        handleDropOnPlayerSlot(targetSlot) {
            if (!this.currentlyDraggingItem) return;

            if (this.dragStartInventoryType === "quickslot") {
                this.moveQuickSlotToInventory(this.currentlyDraggingQuickSlot, targetSlot);
                return;
            }

            if (this.dragStartInventoryType === "equipment") {
                this.unequipEquipmentItem(this.currentlyDraggingEquipmentSlot, targetSlot);
                return;
            }

            if (this.dragStartInventoryType === "device") {
                const existing = this.playerInventory[targetSlot];
                if (existing) {
                    this.selectedDeviceModMessage = "Drop installed modules into an empty inventory slot.";
                    this.inventoryError(targetSlot);
                    return;
                }

                this.removeDeviceAttachment(this.currentlyDraggingItem, targetSlot);
                return;
            }

            if (this.isShopInventory && this.dragStartInventoryType === "other") {
                this.handlePurchase(
                    targetSlot,
                    this.currentlyDraggingSlot,
                    this.currentlyDraggingItem,
                    this.getShopAmount(this.currentlyDraggingItem)
                );
                return;
            }

            this.handleItemDrop("player", targetSlot);
        },

        handleDropOnOtherSlot(targetSlot) {
            if (!this.currentlyDraggingItem) return;

            if (this.dragStartInventoryType === "equipment" || this.dragStartInventoryType === "quickslot") {
                return;
            }

            if (this.dragStartInventoryType === "player" && this.isShopInventory) {
                this.sellItem(this.currentlyDraggingItem);
                return;
            }

            this.handleItemDrop("other", targetSlot);
        },

        handleDropOnBackpackSlot(targetSlot) {
            if (!this.currentlyDraggingItem) return;

            if (this.dragStartInventoryType === "equipment" || this.dragStartInventoryType === "quickslot") {
                return;
            }

            this.handleItemDrop("backpack", targetSlot);
        },

        handleDropOnDeviceSlot(slotId) {
            if (!this.currentlyDraggingItem || !this.selectedDevice) return;

            const deviceSlot = this.findDeviceModuleSlot(slotId);
            if (!deviceSlot) return;

            if (this.dragStartInventoryType !== "player") {
                this.selectedDeviceModMessage = "Drag a compatible item from your inventory into the bay.";
                return;
            }

            if (deviceSlot.attachment) {
                this.selectedDeviceModMessage = `${deviceSlot.label} is already occupied.`;
                this.inventoryError(this.currentlyDraggingSlot);
                return;
            }

            if (!this.canInstallIntoDeviceSlot(deviceSlot, this.currentlyDraggingItem)) {
                this.selectedDeviceModMessage = `${this.currentlyDraggingItem.label || this.currentlyDraggingItem.name} does not fit in that bay.`;
                this.inventoryError(this.currentlyDraggingSlot);
                return;
            }

            const attachment = this.deviceAttachmentFromItem(this.currentlyDraggingItem);
            if (!attachment) return;

            this.applyDeviceAttachment(attachment);
        },

        handleDropOutsideInventory() {
            if (!this.currentlyDraggingItem || this.dragStartInventoryType !== "player") return;
            this.dropItem(this.currentlyDraggingItem, "all");
        },

        handleEquipmentDrop(equipmentSlot) {
            if (!this.currentlyDraggingItem || this.dragStartInventoryType !== "player") return;

            if (equipmentSlot === "armour" && this.isArmorPlateItem(this.currentlyDraggingItem)) {
                this.applyArmorPlate(this.currentlyDraggingItem);
                return;
            }

            const draggingName = String((this.currentlyDraggingItem && this.currentlyDraggingItem.name) || "").toLowerCase();
            if ((draggingName === "simcard" || draggingName === "sim_card") && equipmentSlot !== "simcard") {
                this.notify("SIM card can only go into the SIM slot.", "error");
                this.inventoryError(this.currentlyDraggingSlot);
                return;
            }

            if (this.canEquipItemToSlot(equipmentSlot, this.currentlyDraggingItem)) {
                this.equipItemToSlot(equipmentSlot, this.currentlyDraggingItem);
                return;
            }

            this.inventoryError(this.currentlyDraggingSlot);
        },

        handleItemDrop(targetInventoryType, targetSlot) {
            try {
                const isShop = this.otherInventoryName.indexOf("shop-");
                if (this.dragStartInventoryType === "other" && targetInventoryType === "other" && isShop !== -1) {
                    return;
                }

                const targetSlotNumber = parseInt(targetSlot, 10);
                if (isNaN(targetSlotNumber)) {
                    throw new Error("Invalid target slot number");
                }

                const sourceInventory = this.getInventoryByType(this.dragStartInventoryType);
                const targetInventory = this.getInventoryByType(targetInventoryType);

                const sourceItem = sourceInventory[this.currentlyDraggingSlot];
                if (!sourceItem) {
                    throw new Error("No item in the source slot to transfer");
                }

                const sourceAmount = Number(sourceItem.amount) > 0 ? Number(sourceItem.amount) : 1;
                const movingWithinSameInventory = this.dragStartInventoryType === targetInventoryType;

                let amountToTransfer;
                if (movingWithinSameInventory) {
                    amountToTransfer = sourceAmount;
                } else if (
                    this.transferAmount !== null &&
                    this.transferAmount !== "" &&
                    !isNaN(parseInt(this.transferAmount, 10))
                ) {
                    amountToTransfer = parseInt(this.transferAmount, 10);
                } else {
                    amountToTransfer = sourceAmount;
                }

                if (isNaN(amountToTransfer) || amountToTransfer < 1) {
                    amountToTransfer = sourceAmount;
                }

                if (!movingWithinSameInventory) {
                    if (targetInventoryType === "other") {
                        const totalWeightAfterTransfer = this.otherInventoryWeight + ((sourceItem.weight || 0) * amountToTransfer);
                        if (totalWeightAfterTransfer > this.otherInventoryMaxWeight) {
                            throw new Error("Insufficient weight capacity in target inventory");
                        }
                    } else if (targetInventoryType === "backpack") {
                        const totalWeightAfterTransfer = this.backpackWeight + ((sourceItem.weight || 0) * amountToTransfer);
                        if (totalWeightAfterTransfer > this.backpackMaxWeight) {
                            throw new Error("Insufficient weight capacity in backpack");
                        }
                    } else if (targetInventoryType === "player") {
                        const totalWeightAfterTransfer = this.playerWeight + ((sourceItem.weight || 0) * amountToTransfer);
                        if (totalWeightAfterTransfer > this.maxWeight) {
                            throw new Error("Insufficient weight capacity in player inventory");
                        }
                    }
                }

                const targetItem = targetInventory[targetSlotNumber];

                if (targetItem) {
                    const targetAmount = Number(targetItem.amount) > 0 ? Number(targetItem.amount) : 1;

                    if (targetItem.name === sourceItem.name) {
                        this.postInventoryData(
                            this.dragStartInventoryType,
                            targetInventoryType,
                            this.currentlyDraggingSlot,
                            targetSlotNumber,
                            amountToTransfer,
                            targetAmount
                        );
                    } else {
                        this.postInventoryData(
                            this.dragStartInventoryType,
                            targetInventoryType,
                            this.currentlyDraggingSlot,
                            targetSlotNumber,
                            sourceAmount,
                            targetAmount
                        );
                    }
                } else {
                    this.postInventoryData(
                        this.dragStartInventoryType,
                        targetInventoryType,
                        this.currentlyDraggingSlot,
                        targetSlotNumber,
                        amountToTransfer,
                        0
                    );
                }
            } catch (error) {
                console.error("handleItemDrop error:", error);
                this.inventoryError(this.currentlyDraggingSlot);
            }
        },

        clearDragData() {
            if (this.ghostElement) {
                this.ghostElement.remove();
            }

            this.currentlyDraggingItem = null;
            this.currentlyDraggingSlot = null;
            this.dragStartX = 0;
            this.dragStartY = 0;
            this.ghostElement = null;
            this.dragStartInventoryType = "player";
            this.currentlyDraggingQuickSlot = null;
            this.currentlyDraggingEquipmentSlot = null;
        },

        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount, options = {}) {
            const backpackInfo = (this.getEquipmentPreview("backpack") || {}).info || {};
            const backpackInventoryName = this.backpackInventoryName || backpackInfo.storageId || "";
            const resolveInventoryName = (inventoryType) => {
                if (inventoryType === "other") return this.otherInventoryName || "other";
                if (inventoryType === "backpack") return backpackInventoryName || "backpack";
                return inventoryType;
            };
            const fromInventoryName = resolveInventoryName(fromInventory);
            const toInventoryName = resolveInventoryName(toInventory);
            const previousPlayerInventory = this.cloneInventory(this.playerInventory);
            const previousOtherInventory = this.cloneInventory(this.otherInventory);
            const previousBackpackInventory = this.cloneInventory(this.backpackInventory);
            const previousQuickSlotAssignments = { ...this.quickSlotAssignments };
            let appliedLocalMove = false;

            if (!options.skipLocalMove) {
                appliedLocalMove = this.applyLocalInventoryMove(
                    fromInventory,
                    toInventory,
                    fromSlot,
                    toSlot,
                    fromAmount
                );
                if (appliedLocalMove) {
                    this.refreshQuickSlots();
                }
            }

            axios
                .post("https://prp-inventory/SetInventoryData", {
                    fromInventory: fromInventoryName,
                    toInventory: toInventoryName,
                    fromSlot,
                    toSlot,
                    fromAmount,
                    toAmount
                })
                .then(() => {
                    this.refreshQuickSlots();
                    this.clearDragData();
                })
                .catch((error) => {
                    console.error("Error posting inventory data:", error);
                    if (appliedLocalMove) {
                        this.playerInventory = previousPlayerInventory;
                        this.otherInventory = previousOtherInventory;
                        this.backpackInventory = previousBackpackInventory;
                        this.quickSlotAssignments = previousQuickSlotAssignments;
                        this.refreshQuickSlots();
                    }
                    this.inventoryError(Number(fromSlot));
                });
        },

        handleQuickSlotMouseDown(event, slot) {
            event.preventDefault();

            if (event.button === 2) {
                this.clearQuickSlot(slot);
                return;
            }

            if (event.button !== 0) return;
            this.startQuickSlotDrag(event, slot);
        },

        startQuickSlotDrag(event, quickSlot) {
            const item = this.getHotbarItemInSlot(quickSlot);
            if (!item) return;

            const slotElement = event.target.closest(".hotbar-slot");
            if (!slotElement) return;

            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);

            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;

            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = item.slot;
            this.currentlyDraggingQuickSlot = quickSlot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.dragStartInventoryType = "quickslot";
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
        },

        handleEquipmentMouseDown(event, equipmentSlot) {
            if (event.button !== 0) return;
            event.preventDefault();

            const item = this.getEquipmentPreview(equipmentSlot);
            if (!item) return;

            const slotElement = event.target.closest(".equipment-slot");
            if (!slotElement) return;

            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);

            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;

            ghostElement.style.position = "fixed";
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;
            ghostElement.style.right = "auto";
            ghostElement.style.bottom = "auto";
            ghostElement.style.transform = "none";

            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = item;
            this.currentlyDraggingSlot = equipmentSlot;
            this.currentlyDraggingEquipmentSlot = equipmentSlot;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.dragStartInventoryType = "equipment";
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
        },

        assignQuickSlot(quickSlot, itemSlot) {
            const sourceItem = this.playerInventory[itemSlot];
            if (!sourceItem) {
                this.inventoryError(itemSlot);
                return;
            }

            axios.post("https://prp-inventory/SetQuickSlot", {
                quickSlot,
                itemSlot
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.applyInventoryResult(response.data, itemSlot);
                } else {
                    const message = response.data && response.data.message ? response.data.message : "Could not set quick slot";
                    console.warn("SetQuickSlot failed:", message);
                    this.notify(message, "error");
                    this.inventoryError(itemSlot);
                }
            }).catch((error) => {
                console.error("SetQuickSlot error:", this.formatRequestError(error));
                this.inventoryError(itemSlot);
            });
        },

        clearQuickSlot(quickSlot) {
            axios.post("https://prp-inventory/SetQuickSlot", {
                quickSlot,
                itemSlot: null
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.applyInventoryResult(response.data);
                }
            }).catch((error) => {
                console.error("ClearQuickSlot error:", this.formatRequestError(error));
            });
        },

        moveQuickSlotToInventory(quickSlot, targetSlot) {
            const sourceItem = this.currentlyDraggingItem;
            const sourceSlot = sourceItem && Number(sourceItem.slot);
            const targetSlotNumber = Number(targetSlot);

            if (!quickSlot || !sourceSlot || !targetSlotNumber) return;

            if (this.isQuickSlotAssignedItemSlot(targetSlotNumber) && targetSlotNumber !== sourceSlot) {
                this.inventoryError(targetSlotNumber);
                return;
            }

            const sourceAmount = this.normalizeItemAmount(sourceItem);
            const targetItem = this.playerInventory[targetSlotNumber] || null;
            const targetAmount = targetItem ? this.normalizeItemAmount(targetItem) : 0;

            axios.post("https://prp-inventory/SetQuickSlot", {
                quickSlot,
                itemSlot: null
            }).then((response) => {
                if (!response.data || !response.data.success) {
                    this.inventoryError(sourceSlot);
                    return;
                }

                this.applyInventoryResult(response.data);
                if (targetSlotNumber !== sourceSlot) {
                    this.postInventoryData("player", "player", sourceSlot, targetSlotNumber, sourceAmount, targetAmount);
                }
            }).catch((error) => {
                console.error("MoveQuickSlotToInventory error:", this.formatRequestError(error));
                this.inventoryError(sourceSlot);
            });
        },

        removeLocalInventoryAmount(slot, amount = 1, expectedName = null, originalAmount = null) {
            const item = this.playerInventory[slot] || this.playerInventory[String(slot)];
            if (!item) return;
            if (expectedName && item.name !== expectedName) return;

            const currentAmount = this.normalizeItemAmount(item);
            if (originalAmount !== null && currentAmount < originalAmount) return;
            if (currentAmount <= amount) {
                delete this.playerInventory[slot];
                delete this.playerInventory[String(slot)];
            } else {
                item.amount = currentAmount - amount;
            }

            this.playerInventory = { ...this.playerInventory };
        },

        applyInventoryResult(result, fallbackSlot = null) {
            if (result && result.success) {
                if (result.inventory || result.Inventory) {
                    this.playerInventory = { ...this.normalizeInventory(result.inventory || result.Inventory) };
                }
                if (Object.prototype.hasOwnProperty.call(result, "equipment")) {
                    this.equippedItems = this.normalizeEquipment(result.equipment);
                }
                if (result.quickslots) {
                    this.quickSlotAssignments = this.normalizeQuickSlotAssignments(result.quickslots);
                }
                this.refreshQuickSlots();
                return true;
            }

            if (fallbackSlot) {
                this.inventoryError(fallbackSlot);
            }
            return false;
        },

        equipItemToSlot(equipmentSlot, item) {
            const sourceSlot = item && item.slot;
            const sourceName = item && item.name;
            const sourceAmount = this.normalizeItemAmount(item);
            const localEquipmentPreview = item ? {
                ...this.cloneItem(item),
                slot: equipmentSlot,
                amount: 1
            } : null;
            axios.post("https://prp-inventory/EquipItem", {
                equipmentSlot,
                itemSlot: item.slot
            }).then((response) => {
                if (this.applyInventoryResult(response.data, item.slot) && sourceSlot) {
                    if (localEquipmentPreview && !this.equippedItems[equipmentSlot]) {
                        this.equippedItems = this.normalizeEquipment({
                            ...this.equippedItems,
                            [equipmentSlot]: localEquipmentPreview
                        });
                        if (equipmentSlot === "backpack") setTimeout(() => this.openBackpackStorage(), 150);
                    }
                    this.removeLocalInventoryAmount(sourceSlot, 1, sourceName, sourceAmount);
                    this.refreshQuickSlots();
                }
            }).catch((error) => {
                console.error("EquipItem error:", error);
                this.inventoryError(item.slot);
            });
        },

        unequipEquipmentItem(equipmentSlot, targetSlot = null) {
            const equippedItem = this.getEquipmentPreview(equipmentSlot);
            if (!equippedItem) return;

            const targetSlotNumber = Number(targetSlot);
            const hasTargetSlot = Number.isFinite(targetSlotNumber) && targetSlotNumber > 0;

            axios.post("https://prp-inventory/UnequipItem", {
                equipmentSlot,
                targetSlot
            }).then((response) => {
                if (!this.applyInventoryResult(response.data, targetSlot)) return;

                if (hasTargetSlot && !this.playerInventory[targetSlotNumber]) {
                    this.playerInventory = {
                        ...this.playerInventory,
                        [targetSlotNumber]: {
                            ...this.cloneItem(equippedItem),
                            slot: targetSlotNumber,
                            amount: 1
                        }
                    };
                } else {
                    this.playerInventory = { ...this.playerInventory };
                }

                this.equippedItems = this.normalizeEquipment({
                    ...this.equippedItems,
                    [equipmentSlot]: null
                });
                this.refreshQuickSlots();
            }).catch((error) => {
                console.error("UnequipItem error:", error);
                if (targetSlot) this.inventoryError(targetSlot);
            });
        },

        applyArmorPlate(item) {
            const sourceSlot = item && item.slot;
            const sourceName = item && item.name;
            const sourceAmount = this.normalizeItemAmount(item);
            axios.post("https://prp-inventory/ApplyArmorPlate", {
                itemSlot: item.slot
            }).then((response) => {
                if (this.applyInventoryResult(response.data, item.slot) && sourceSlot) {
                    this.removeLocalInventoryAmount(sourceSlot, 1, sourceName, sourceAmount);
                    this.refreshQuickSlots();
                }
            }).catch((error) => {
                console.error("ApplyArmorPlate error:", error);
                this.inventoryError(item.slot);
            });
        },

        useItem(item) {
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.closeInventory();

            axios.post("https://prp-inventory/UseItem", { item }).catch((error) => {
                console.error("UseItem error:", error);
            });
        },

        giveItem(item, amountMode) {
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;

            let amount = 1;
            if (amountMode === "half") amount = Math.floor((Number(item.amount) || 1) / 2);
            if (amountMode === "all") amount = Number(item.amount) || 1;
            if (amount < 1) amount = 1;

            axios.post("https://prp-inventory/GiveItem", {
                item,
                amount,
                slot: item.slot,
                info: item.info || {}
            }).then((response) => {
                if (response.data === true || response.data === "ok") {
                    this.closeInventory();
                } else {
                    this.inventoryError(item.slot);
                }
            }).catch((error) => {
                console.error("GiveItem error:", error);
                this.inventoryError(item.slot);
            });
        },

        dropItem(item, amountMode) {
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;

            let amount = 1;
            if (amountMode === "half") amount = Math.floor((Number(item.amount) || 1) / 2);
            if (amountMode === "all") amount = Number(item.amount) || 1;
            if (amount < 1) amount = 1;

            axios.post("https://prp-inventory/DropItem", {
                item,
                ...item,
                amount,
                slot: item.slot,
                fromSlot: item.slot
            }).then((response) => {
                if (response.data === true || response.data === "ok") {
                    this.closeInventory();
                } else {
                    this.inventoryError(item.slot);
                }
            }).catch((error) => {
                console.error("DropItem error:", error);
                this.inventoryError(item.slot);
            });
        },

        splitAndPlaceItem(item, inventoryType) {
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;

            const sourceAmount = Number(item.amount) > 0 ? Number(item.amount) : 1;
            if (!item || sourceAmount <= 1) return;

            const amount = Math.floor(sourceAmount / 2);
            if (amount < 1) return;

            const targetInventory = this.getInventoryByType(inventoryType);
            const freeSlot = this.findNextAvailableSlot(targetInventory, inventoryType);

            if (freeSlot === null) {
                this.inventoryError(item.slot);
                return;
            }

            this.postInventoryData(
                inventoryType,
                inventoryType,
                item.slot,
                freeSlot,
                amount,
                0
            );
        },

        findNextAvailableSlot(inventory, inventoryType = null) {
            const maxSlots = inventoryType === "player" || inventory === this.playerInventory
                ? this.totalSlots
                : (inventoryType === "backpack" || inventory === this.backpackInventory
                    ? this.backpackSlots
                    : this.otherInventorySlots);
            for (let i = 1; i <= maxSlots; i++) {
                if (!inventory[i]) return i;
            }
            return null;
        },

        inventoryError(slot) {
            this.errorSlot = slot;
            setTimeout(() => {
                this.errorSlot = null;
            }, 150);
        },

        showContextMenuOptions(event, item, inventoryType = "player") {
            this.contextMenuItem = item;
            this.contextMenuInventory = inventoryType;
            this.showContextMenu = true;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.contextMenuPosition = {
                top: `${event.clientY}px`,
                left: `${event.clientX}px`
            };
        },

        generateTooltipContent(item) {
            if (!item) return "";

            const label = item.label || item.name || "Item";
            const amount = Number(item.amount) || 1;
            const weight = (((item.weight || 0) * amount) / 1000).toFixed(2);
            const description = item.description || "";

            let infoHtml = "";
            if (item.info && typeof item.info === "object") {
                Object.entries(item.info).forEach(([key, value]) => {
                    if (typeof value !== "object") {
                        infoHtml += `<div><strong>${key}:</strong> ${value}</div>`;
                    }
                });
            }

            return `
                <div style="min-width:180px">
                    <div style="font-weight:700; margin-bottom:6px;">${label}</div>
                    <div>Amount: ${amount}</div>
                    <div>Weight: ${weight} KG</div>
                    ${description ? `<div style="margin-top:6px;">${description}</div>` : ""}
                    ${infoHtml ? `<div style="margin-top:6px;">${infoHtml}</div>` : ""}
                </div>
            `;
        },

        getShopAmount(item = null) {
            const requestedAmount = this.normalizedShopAmount;
            if (!item) return requestedAmount;
            if (item.unique) return 1;

            const availableAmount = Number(item.amount);
            if (isNaN(availableAmount)) return requestedAmount;
            if (availableAmount <= 0) return 0;

            return Math.max(1, Math.min(requestedAmount, availableAmount));
        },

        findStackOrFreeSlot(item) {
            if (!item) return null;

            if (!item.unique) {
                const stackSlot = Object.values(this.playerInventory).find(
                    (playerItem) => playerItem && playerItem.name === item.name && !playerItem.unique
                );
                if (stackSlot) return stackSlot.slot;
            }

            return this.findNextAvailableSlot(this.playerInventory);
        },

        getShopStockItem(item) {
            if (!item) return null;
            return Object.values(this.otherInventory).find(
                (shopItem) => shopItem && shopItem.name === item.name
            ) || null;
        },

        canSellShopItem(item) {
            return this.getShopSellUnitPrice(item) > 0;
        },

        getShopSellUnitPrice(item) {
            const shopItem = this.getShopStockItem(item);
            if (!shopItem || shopItem.price === undefined) return 0;

            const sellPrice = Math.floor((Number(shopItem.price) || 0) * this.shopSellBackRate);
            return sellPrice > 0 ? sellPrice : 0;
        },

        getShopSellTotal(item) {
            return this.getShopSellUnitPrice(item) * this.getShopAmount(item);
        },

        reduceShopStock(slot, amount) {
            const shopItem = this.otherInventory[slot];
            if (!shopItem || shopItem.amount === undefined) return;

            shopItem.amount = Math.max(0, (Number(shopItem.amount) || 0) - amount);
        },

        increaseShopStock(itemName, amount) {
            const shopItem = Object.values(this.otherInventory).find(
                (item) => item && item.name === itemName
            );
            if (!shopItem || shopItem.amount === undefined) return;

            shopItem.amount = (Number(shopItem.amount) || 0) + amount;
        },

        buyContextItem(item) {
            const targetSlot = this.findStackOrFreeSlot(item);
            if (targetSlot === null) {
                this.inventoryError(item.slot);
                return;
            }

            this.handlePurchase(targetSlot, item.slot, item, this.getShopAmount(item));
        },

        handlePurchase(targetSlot, shopSlot, item, amount) {
            const purchaseAmount = Number(amount) || 1;
            if (purchaseAmount < 1) {
                this.inventoryError(item.slot);
                return;
            }

            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;

            axios.post("https://prp-inventory/AttemptPurchase", {
                shop: this.otherInventoryName,
                item,
                amount: purchaseAmount,
                targetSlot
            }).then((response) => {
                if (response.data === true || (response.data && response.data.success)) {
                    this.reduceShopStock(shopSlot, purchaseAmount);
                    this.shopAmount = 1;
                } else {
                    this.inventoryError(item.slot);
                }
            }).catch((error) => {
                console.error("AttemptPurchase error:", error);
                this.inventoryError(item.slot);
            });
        },

        sellItem(item) {
            if (!item || !this.isShopInventory) return;

            const sellAmount = this.getShopAmount(item);
            if (sellAmount < 1 || !this.canSellShopItem(item)) {
                this.inventoryError(item.slot);
                return;
            }

            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;

            axios.post("https://prp-inventory/SellShopItem", {
                shop: this.otherInventoryName,
                item,
                amount: sellAmount,
                slot: item.slot
            }).then((response) => {
                if (response.data === true || (response.data && response.data.success)) {
                    this.increaseShopStock(item.name, sellAmount);
                    this.shopAmount = 1;
                } else {
                    this.inventoryError(item.slot);
                }
            }).catch((error) => {
                console.error("SellShopItem error:", error);
                this.inventoryError(item.slot);
            });
        },

        toggleHotbar(state = null) {
            this.showHotbar = state !== null ? state : !this.showHotbar;
        },

        updateWeaponModData(data) {
            this.selectedWeaponAttachments = data.Attachments || data.AttachmentData || [];
            this.selectedWeaponAvailableAttachments = data.AvailableAttachments || [];
            this.selectedWeaponModMessage = data.message || "";

            if (data.WeaponData) {
                this.selectedWeapon = data.WeaponData;
                if (data.WeaponData.slot) {
                    this.playerInventory[data.WeaponData.slot] = data.WeaponData;
                }
            }
        },

        isDeviceAttachmentItem(item) {
            return item && item.name === "tablet";
        },

        parseDeviceAttachmentToken(value) {
            const token = String(value || "");
            const divider = token.indexOf("|");

            if (divider === -1) {
                return {
                    itemName: token,
                    identifier: ""
                };
            }

            return {
                itemName: token.slice(0, divider),
                identifier: token.slice(divider + 1)
            };
        },

        normalizeDeviceAttachment(attachment) {
            if (!attachment) return null;

            const parsed = this.parseDeviceAttachmentToken(attachment.attachment);
            return {
                ...attachment,
                itemName: parsed.itemName,
                identifier: parsed.identifier
            };
        },

        buildAvailableDeviceAttachments(device) {
            if (!device || !device.name) return [];

            const info = device.info || {};
            const phoneDevices = { phone: true, iphone: true, samsungphone: true };
            if (phoneDevices[device.name] && info.simNumber) return [];

            const allowed = {
                phone: { simcard: true },
                iphone: { simcard: true },
                samsungphone: { simcard: true },
                tablet: { crypto_usb: true, cryptostick: true, command_usb: true }
            }[device.name] || {};
            const commandInstalled = device.name === "tablet" && !!info.commandUsb;

            return Object.values(this.playerInventory)
                .filter((item) => item && item.name && allowed[item.name] && item.slot !== device.slot)
                .filter((item) => !(commandInstalled && item.name === "command_usb"))
                .map((item) => ({
                    attachment: item.name,
                    label: item.label || item.name,
                    image: item.image || `${item.name}.png`,
                    amount: item.amount || 1,
                    slot: item.slot,
                    detail: item.info && (item.info.simNumber || item.info.serial || item.info.serie)
                }));
        },

        mergeDeviceAttachments(...groups) {
            const merged = [];
            const seen = new Set();

            groups.flat().forEach((attachment) => {
                if (!attachment || !attachment.attachment || !attachment.slot) return;

                const key = `${attachment.attachment}-${attachment.slot}`;
                if (seen.has(key)) return;

                seen.add(key);
                merged.push(attachment);
            });

            return merged;
        },

        getDeviceModuleSlots() {
            if (!this.selectedDevice || !this.selectedDevice.name) return [];

            const installed = (this.selectedDeviceAttachments || [])
                .map((attachment) => this.normalizeDeviceAttachment(attachment))
                .filter(Boolean);

            const phoneDevices = { phone: true, iphone: true, samsungphone: true };
            if (phoneDevices[this.selectedDevice.name]) {
                const sim = installed.find((entry) => entry.itemName === "simcard") || null;

                return [{
                    key: "phone-sim",
                    slotId: "sim",
                    shortLabel: "SIM",
                    label: "SIM Card",
                    accepts: ["simcard"],
                    attachment: sim
                }];
            }

            if (this.selectedDevice.name === "tablet") {
                const command = installed.find((entry) => entry.itemName === "command_usb") || null;
                const drives = installed.filter((entry) => entry.itemName === "crypto_usb" || entry.itemName === "cryptostick");
                const cryptoSlotCount = Math.max(6, drives.length + 1);

                const slots = [{
                    key: "tablet-command",
                    slotId: "command",
                    shortLabel: "CMD",
                    label: "Command USB",
                    accepts: ["command_usb"],
                    attachment: command
                }];

                for (let index = 0; index < cryptoSlotCount; index++) {
                    slots.push({
                        key: `tablet-crypto-${index + 1}`,
                        slotId: `crypto-${index + 1}`,
                        shortLabel: `U${index + 1}`,
                        label: "Crypto USB",
                        accepts: ["crypto_usb", "cryptostick"],
                        attachment: drives[index] || null
                    });
                }

                return slots;
            }

            return [];
        },

        findDeviceModuleSlot(slotId) {
            return this.getDeviceModuleSlots().find((slot) => slot.slotId === slotId) || null;
        },

        canInstallIntoDeviceSlot(slot, item) {
            return !!(slot && item && Array.isArray(slot.accepts) && slot.accepts.includes(item.name));
        },

        deviceAttachmentFromItem(item) {
            if (!item || !item.name || !item.slot) return null;

            return {
                attachment: item.name,
                label: item.label || item.name,
                image: item.image || `${item.name}.png`,
                amount: item.amount || 1,
                slot: item.slot,
                detail: item.info && (item.info.simNumber || item.info.serial || item.info.serie)
            };
        },

        handleDeviceAttachmentMouseDown(event, attachment) {
            if (event.button !== 0) return;
            event.preventDefault();

            const normalized = this.normalizeDeviceAttachment(attachment);
            if (!normalized) return;

            const slotElement = event.target.closest(".device-module-slot");
            if (!slotElement) return;

            const ghostElement = this.createGhostElement(slotElement);
            document.body.appendChild(ghostElement);

            const offsetX = ghostElement.offsetWidth / 2;
            const offsetY = ghostElement.offsetHeight / 2;
            ghostElement.style.left = `${event.clientX - offsetX}px`;
            ghostElement.style.top = `${event.clientY - offsetY}px`;

            this.ghostElement = ghostElement;
            this.currentlyDraggingItem = {
                ...normalized,
                __deviceAttachment: true,
                name: normalized.itemName,
                label: normalized.label,
                image: normalized.image
            };
            this.currentlyDraggingSlot = normalized.attachment;
            this.dragStartX = event.clientX;
            this.dragStartY = event.clientY;
            this.dragStartInventoryType = "device";
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
        },

        updateDeviceModData(data) {
            if (data.Inventory) {
                this.playerInventory = this.normalizeInventory(data.Inventory);
            }

            if (data.AddedItem && data.AddedItem.slot) {
                this.playerInventory[data.AddedItem.slot] = data.AddedItem;
            }

            this.selectedDeviceAttachments = data.Attachments || data.AttachmentData || [];
            this.selectedDeviceAvailableAttachments = data.AvailableAttachments || [];
            this.selectedDeviceModMessage = data.message || "";

            if (data.DeviceData) {
                this.selectedDevice = data.DeviceData;
                if (data.DeviceData.slot) {
                    this.playerInventory[data.DeviceData.slot] = data.DeviceData;
                }
            }

            const returnedAttachments = data.AvailableAttachments || [];
            const addedAttachment = this.deviceAttachmentFromItem(data.AddedItem);
            const liveAttachments = this.buildAvailableDeviceAttachments(this.selectedDevice);
            this.selectedDeviceAvailableAttachments = this.mergeDeviceAttachments(
                returnedAttachments,
                addedAttachment ? [addedAttachment] : [],
                liveAttachments
            );
        },

        openDeviceAttachments(item) {
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showWeaponAttachments = false;
            this.selectedDevice = item;
            this.selectedDeviceAttachments = [];
            this.selectedDeviceAvailableAttachments = [];
            this.selectedDeviceModMessage = "";

            axios.post("https://prp-inventory/GetDeviceData", {
                ItemData: item
            }).then((response) => {
                if (response.data) {
                    this.updateDeviceModData(response.data);
                    this.showDeviceAttachments = true;
                }
            }).catch((error) => {
                console.error("GetDeviceData error:", error);
                this.selectedDeviceModMessage = "Cannot load device attachments";
            });
        },

        closeDeviceAttachments() {
            this.showDeviceAttachments = false;
            this.selectedDevice = null;
            this.selectedDeviceAttachments = [];
            this.selectedDeviceAvailableAttachments = [];
            this.selectedDeviceModMessage = "";
        },

        openWeaponAttachments(item) {
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showDeviceAttachments = false;
            this.selectedWeapon = item;
            this.selectedWeaponAttachments = [];
            this.selectedWeaponAvailableAttachments = [];
            this.selectedWeaponModMessage = "";

            axios.post("https://prp-inventory/GetWeaponData", {
                weapon: item.name,
                ItemData: item
            }).then((response) => {
                if (response.data) {
                    this.updateWeaponModData(response.data);
                    this.showWeaponAttachments = true;
                }
            }).catch((error) => {
                console.error("GetWeaponData error:", error);
            });
        },

        closeWeaponAttachments() {
            this.showWeaponAttachments = false;
            this.selectedWeapon = null;
            this.selectedWeaponAttachments = [];
            this.selectedWeaponAvailableAttachments = [];
            this.selectedWeaponModMessage = "";
        },

        applyAttachment(attachment) {
            if (!this.selectedWeapon || !attachment) return;

            axios.post("https://prp-inventory/ApplyAttachment", {
                AttachmentData: attachment,
                WeaponData: this.selectedWeapon
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.updateWeaponModData(response.data);
                    if (attachment.slot && this.playerInventory[attachment.slot]) {
                        const amount = Number(this.playerInventory[attachment.slot].amount) || 1;
                        if (amount <= 1) {
                            delete this.playerInventory[attachment.slot];
                        } else {
                            this.playerInventory[attachment.slot].amount = amount - 1;
                        }
                    }
                } else if (response.data) {
                    this.selectedWeaponModMessage = response.data.message || "Cannot apply this mod";
                }
            }).catch((error) => {
                console.error("ApplyAttachment error:", error);
                this.selectedWeaponModMessage = "Cannot apply this mod";
            });
        },

        applyDeviceAttachment(attachment) {
            if (!this.selectedDevice || !attachment) return;

            axios.post("https://prp-inventory/ApplyDeviceAttachment", {
                AttachmentData: attachment,
                DeviceData: this.selectedDevice
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.updateDeviceModData(response.data);
                    if (response.data.Inventory) {
                        return;
                    }
                    const removedSlot = response.data.removedSlot || attachment.slot;
                    const removedItem = removedSlot ? (this.playerInventory[removedSlot] || this.playerInventory[String(removedSlot)]) : null;
                    if (removedSlot && removedItem) {
                        const amount = Number(removedItem.amount) || 1;
                        if (amount <= 1) {
                            delete this.playerInventory[removedSlot];
                            delete this.playerInventory[String(removedSlot)];
                        } else {
                            removedItem.amount = amount - 1;
                        }
                    }
                } else if (response.data) {
                    this.selectedDeviceModMessage = response.data.message || "Cannot install this item";
                }
            }).catch((error) => {
                console.error("ApplyDeviceAttachment error:", error);
                this.selectedDeviceModMessage = "Cannot install this item";
            });
        },

        removeDeviceAttachment(attachment, targetSlot = null) {
            if (!this.selectedDevice || !attachment || attachment.removable === false) return;

            axios.post("https://prp-inventory/RemoveDeviceAttachment", {
                AttachmentData: {
                    ...attachment,
                    targetSlot
                },
                DeviceData: this.selectedDevice
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.updateDeviceModData(response.data);
                } else if (response.data) {
                    this.selectedDeviceModMessage = response.data.message || "Cannot remove this item";
                }
            }).catch((error) => {
                console.error("RemoveDeviceAttachment error:", error);
                this.selectedDeviceModMessage = "Cannot remove this item";
            });
        },

        removeAttachment(attachment) {
            if (!this.selectedWeapon) return;

            axios.post("https://prp-inventory/RemoveAttachment", {
                AttachmentData: attachment,
                WeaponData: this.selectedWeapon
            }).then((response) => {
                if (response.data && (response.data.Attachments || response.data.AvailableAttachments)) {
                    this.updateWeaponModData(response.data);
                } else {
                    this.selectedWeaponAttachments = [];
                }
            }).catch((error) => {
                console.error("RemoveAttachment error:", error);
            });
        },

        copySerial(item) {
            const serial = item && item.info ? item.info.serie : "No Serial";
            navigator.clipboard.writeText(serial).catch(() => { });
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
        }
    }
});

InventoryContainer.use(FloatingVue);

const inventoryApp = InventoryContainer.mount("#app");

window.addEventListener("message", (event) => {
    const data = event.data;

    switch (data.action) {
        case "open":
            inventoryApp.openInventory(data);
            break;
        case "update":
            inventoryApp.updateInventory(data);
            break;
        case "close":
            inventoryApp.isInventoryOpen = false;
            inventoryApp.characterPreviewActive = false;
            inventoryApp.showContextMenu = false;
            inventoryApp.showSubmenu = false;
            inventoryApp.activeSubmenu = null;
            inventoryApp.showWeaponAttachments = false;
            inventoryApp.showDeviceAttachments = false;
            inventoryApp.showRequiredItems = false;
            inventoryApp.showNotification = false;
            inventoryApp.showUtilityPanel = false;
            inventoryApp.clearDragData();
            break;
        case "characterPreview":
            inventoryApp.characterPreviewActive = !!data.active;
            break;
        case "toggleHotbar":
            inventoryApp.hotbarItems = data.items || [];
            inventoryApp.showHotbar = data.open;
            break;
        case "requiredItem":
            inventoryApp.requiredItems = data.items || [];
            inventoryApp.showRequiredItems = data.toggle;
            break;
        case "itemBox":
            inventoryApp.notificationText = (data.item && (data.item.label || data.item.name)) || "Item";
            inventoryApp.notificationImage = `images/${(data.item && data.item.image) || "placeholder.png"}`;
            inventoryApp.notificationType = data.type || "added";
            inventoryApp.notificationAmount = data.amount || 1;
            inventoryApp.showNotification = true;
            setTimeout(() => {
                inventoryApp.showNotification = false;
            }, 2000);
            break;
        case "RobMoney":
            break;
        default:
            break;
    }
});

document.addEventListener("keydown", (event) => {
    if ((event.key === "Escape" || event.key === "Tab") && inventoryApp.isInventoryOpen) {
        event.preventDefault();
        inventoryApp.closeInventory();
    }
});
