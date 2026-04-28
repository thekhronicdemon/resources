const InventoryContainer = Vue.createApp({
    data() {
        return {
            equippedItems: {
                hat: null,
                backpack: null,
                armour: null,
                jacket: null,
                shirt: null,
                pants: null,
                shoes: null
            },

            maxWeight: 0,
            totalSlots: 0,
            isInventoryOpen: false,
            isOtherInventoryEmpty: true,
            errorSlot: null,

            playerInventory: {},
            inventoryLabel: "Inventory",

            otherInventory: {},
            otherInventoryName: "",
            otherInventoryLabel: "Drop",
            otherInventoryMaxWeight: 1000000,
            otherInventorySlots: 100,
            isShopInventory: false,
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

            currentlyDraggingItem: null,
            currentlyDraggingSlot: null,
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
            return Object.values(this.playerInventory).filter(Boolean).length;
        },

        usedOtherSlots() {
            return Object.values(this.otherInventory).filter(Boolean).length;
        },

        normalizedShopAmount() {
            const amount = Math.floor(Number(this.shopAmount) || 1);
            return amount > 0 ? amount : 1;
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

        getInventoryByType(inventoryType) {
            return inventoryType === "player" ? this.playerInventory : this.otherInventory;
        },

        getItemInSlot(slot, inventoryType) {
            if (inventoryType === "player") return this.playerInventory[slot] || null;
            if (inventoryType === "other") return this.otherInventory[slot] || null;
            return null;
        },

        getHotbarItemInSlot(slot) {
            return this.quickSlotItems[slot] || null;
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
            return item && (item.name === "armor" || item.name === "heavyarmor");
        },

        isArmorPlateItem(item) {
            return item && (item.name === "armor_plate" || item.name === "armor_plates");
        },

        normalizeQuickSlotAssignments(assignments) {
            const normalized = {};
            if (!assignments || typeof assignments !== "object") return normalized;

            for (let i = 1; i <= 4; i++) {
                const rawSlot = assignments[i] || assignments[String(i)];
                const itemSlot = Number(rawSlot);
                if (Number.isFinite(itemSlot) && itemSlot > 0) {
                    normalized[i] = itemSlot;
                }
            }

            return normalized;
        },

        refreshQuickSlots() {
            const items = {};
            for (let i = 1; i <= 4; i++) {
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

            for (let i = 1; i <= 4; i++) {
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
            const sourceInventory = this.getInventoryByType(fromInventory);
            const targetInventory = this.getInventoryByType(toInventory);

            const sourceSlot = Number(fromSlot);
            const targetSlotNum = Number(toSlot);
            const moveAmount = Number(fromAmount) || 1;

            const sourceItem = sourceInventory[sourceSlot];
            if (!sourceItem) return;

            const sourceAmount = this.normalizeItemAmount(sourceItem);
            const targetItem = targetInventory[targetSlotNum] || null;

            if (fromInventory === toInventory && sourceSlot === targetSlotNum) {
                return;
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
                return;
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
                return;
            }

            const sourceClone = this.cloneItem(sourceItem);
            const targetClone = this.cloneItem(targetItem);

            sourceClone.slot = targetSlotNum;
            targetClone.slot = sourceSlot;

            sourceInventory[sourceSlot] = targetClone;
            targetInventory[targetSlotNum] = sourceClone;
        },

        openInventory(data) {
            if (this.showHotbar) {
                this.toggleHotbar(false);
            }

            this.isInventoryOpen = true;
            this.transferAmount = null;
            this.maxWeight = data.maxweight || 0;
            this.totalSlots = data.slots || 0;
            this.playerInventory = {};
            this.otherInventory = {};
            this.otherInventoryName = "";
            this.otherInventoryLabel = "Drop";
            this.otherInventoryMaxWeight = 1000000;
            this.otherInventorySlots = 100;
            this.isShopInventory = false;
            this.shopSellBackRate = 0.7;
            this.shopAmount = 1;
            this.isOtherInventoryEmpty = true;
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showWeaponAttachments = false;
            this.showDeviceAttachments = false;

            this.equippedItems = data.equipment || {
                hat: null,
                backpack: null,
                armour: null,
                jacket: null,
                shirt: null,
                pants: null,
                shoes: null
            };
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
                if (data.other.inventory) {
                    if (Array.isArray(data.other.inventory)) {
                        data.other.inventory.forEach((item) => {
                            if (item && item.slot) this.otherInventory[item.slot] = item;
                        });
                    } else if (typeof data.other.inventory === "object") {
                        Object.keys(data.other.inventory).forEach((key) => {
                            const item = data.other.inventory[key];
                            if (item && item.slot) this.otherInventory[item.slot] = item;
                        });
                    }
                }

                this.otherInventoryName = data.other.name || "";
                this.otherInventoryLabel = data.other.label || "Storage";
                this.otherInventoryMaxWeight = data.other.maxweight || 0;
                this.otherInventorySlots = data.other.slots || 0;
                this.isShopInventory = this.otherInventoryName.startsWith("shop-");
                this.shopSellBackRate = Number(data.other.sellBackRate) || 0.7;
                this.isOtherInventoryEmpty = false;
            }

            this.refreshQuickSlots();
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

        updateInventory(data) {
            this.playerInventory = this.normalizeInventory(data.inventory || data.Inventory);
            if (data.equipment) {
                this.equippedItems = data.equipment;
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
        },

        closeInventory() {
            this.clearDragData();

            axios.post("https://qb-inventory/CloseInventory", {
                name: this.otherInventoryName || ""
            }).catch((error) => {
                console.error("Error closing inventory:", error);
            });

            this.isInventoryOpen = false;
            this.showContextMenu = false;
            this.showSubmenu = false;
            this.activeSubmenu = null;
            this.showWeaponAttachments = false;
            this.showDeviceAttachments = false;
            this.showRequiredItems = false;
            this.showNotification = false;
        },

        clearTransferAmount() {
            this.transferAmount = null;
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
                if (this.isShopInventory) {
                    this.showContextMenuOptions(event, itemInSlot, inventory);
                    return;
                }

                if (!this.isOtherInventoryEmpty) {
                    this.moveItemBetweenInventories(itemInSlot, inventory);
                } else {
                    this.showContextMenuOptions(event, itemInSlot);
                }
            }
        },

        moveItemBetweenInventories(item, sourceInventoryType) {
            const targetInventoryType = sourceInventoryType === "player" ? "other" : "player";
            const targetInventory = this.getInventoryByType(targetInventoryType);
            const targetSlot = this.findNextAvailableSlot(targetInventory);

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
            ghostElement.style.position = "absolute";
            ghostElement.style.pointerEvents = "none";
            ghostElement.style.opacity = "0.7";
            ghostElement.style.zIndex = "1000";
            ghostElement.style.width = getComputedStyle(slotElement).width;
            ghostElement.style.height = getComputedStyle(slotElement).height;
            ghostElement.style.boxSizing = "border-box";
            return ghostElement;
        },

        drag(event) {
            if (!this.currentlyDraggingItem || !this.ghostElement) return;
            const centeredX = event.clientX - this.ghostElement.offsetWidth / 2;
            const centeredY = event.clientY - this.ghostElement.offsetHeight / 2;
            this.ghostElement.style.left = `${centeredX}px`;
            this.ghostElement.style.top = `${centeredY}px`;
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

            const playerSlotElement = elementsUnderCursor.find(
                (el) =>
                    el.classList.contains("item-slot") &&
                    el.hasAttribute("data-slot") &&
                    el.closest(".inventory-panel")
            );

            const otherSlotElement = elementsUnderCursor.find(
                (el) =>
                    el.classList.contains("item-slot") &&
                    el.hasAttribute("data-slot") &&
                    el.closest(".right-grid")
            );

            const overInventoryContainer = elementsUnderCursor.some(
                (el) =>
                    el.closest(".inventory-panel") ||
                    el.closest(".right-panel") ||
                    el.closest(".mid-controls") ||
                    el.closest(".context-menu") ||
                    el.closest(".prp-hotbar")
            );

            if (quickSlotElement && this.dragStartInventoryType === "player") {
                const quickSlot = Number(quickSlotElement.dataset.slot);
                if (quickSlot) {
                    this.assignQuickSlot(quickSlot, this.currentlyDraggingSlot);
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

            if (!overInventoryContainer && this.dragStartInventoryType === "player" && this.isOtherInventoryEmpty) {
                this.handleDropOutsideInventory();
            }

            this.clearDragData();
        },

        handleDropOnPlayerSlot(targetSlot) {
            if (!this.currentlyDraggingItem) return;

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

            if (this.dragStartInventoryType === "player" && this.isShopInventory) {
                this.sellItem(this.currentlyDraggingItem);
                return;
            }

            this.handleItemDrop("other", targetSlot);
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

            if (equipmentSlot === "armour" && this.isArmourItem(this.currentlyDraggingItem)) {
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

                    if (targetItem.name !== sourceItem.name || targetItem.unique) {
                        this.postInventoryData(
                            this.dragStartInventoryType,
                            targetInventoryType,
                            this.currentlyDraggingSlot,
                            targetSlotNumber,
                            sourceAmount,
                            targetAmount
                        );
                    } else {
                        this.postInventoryData(
                            this.dragStartInventoryType,
                            targetInventoryType,
                            this.currentlyDraggingSlot,
                            targetSlotNumber,
                            amountToTransfer,
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
        },

        postInventoryData(fromInventory, toInventory, fromSlot, toSlot, fromAmount, toAmount) {
            const fromInventoryName = fromInventory === "other" ? this.otherInventoryName : fromInventory;
            const toInventoryName = toInventory === "other" ? this.otherInventoryName : toInventory;

            axios
                .post("https://qb-inventory/SetInventoryData", {
                    fromInventory: fromInventoryName,
                    toInventory: toInventoryName,
                    fromSlot,
                    toSlot,
                    fromAmount,
                    toAmount
                })
                .then(() => {
                    this.applyLocalInventoryMove(
                        fromInventory,
                        toInventory,
                        fromSlot,
                        toSlot,
                        fromAmount
                    );
                    this.refreshQuickSlots();
                    this.clearDragData();
                })
                .catch((error) => {
                    console.error("Error posting inventory data:", error);
                    this.inventoryError(Number(fromSlot));
                });
        },

        handleQuickSlotMouseDown(event, slot) {
            if (event.button !== 2) return;
            event.preventDefault();
            this.clearQuickSlot(slot);
        },

        assignQuickSlot(quickSlot, itemSlot) {
            const sourceItem = this.playerInventory[itemSlot];
            if (!sourceItem) {
                this.inventoryError(itemSlot);
                return;
            }

            axios.post("https://qb-inventory/SetQuickSlot", {
                quickSlot,
                itemSlot
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.quickSlotAssignments = this.normalizeQuickSlotAssignments(response.data.quickslots);
                    this.refreshQuickSlots();
                } else {
                    this.inventoryError(itemSlot);
                }
            }).catch((error) => {
                console.error("SetQuickSlot error:", error);
                this.inventoryError(itemSlot);
            });
        },

        clearQuickSlot(quickSlot) {
            axios.post("https://qb-inventory/SetQuickSlot", {
                quickSlot,
                itemSlot: null
            }).then((response) => {
                if (response.data && response.data.success) {
                    this.quickSlotAssignments = this.normalizeQuickSlotAssignments(response.data.quickslots);
                    this.refreshQuickSlots();
                }
            }).catch((error) => {
                console.error("ClearQuickSlot error:", error);
            });
        },

        applyInventoryResult(result, fallbackSlot = null) {
            if (result && result.success) {
                if (result.inventory || result.Inventory) {
                    this.playerInventory = this.normalizeInventory(result.inventory || result.Inventory);
                }
                if (result.equipment) {
                    this.equippedItems = result.equipment;
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
            axios.post("https://qb-inventory/EquipItem", {
                equipmentSlot,
                itemSlot: item.slot
            }).then((response) => {
                this.applyInventoryResult(response.data, item.slot);
            }).catch((error) => {
                console.error("EquipItem error:", error);
                this.inventoryError(item.slot);
            });
        },

        unequipEquipmentItem(equipmentSlot) {
            if (!this.getEquipmentPreview(equipmentSlot)) return;

            axios.post("https://qb-inventory/UnequipItem", {
                equipmentSlot
            }).then((response) => {
                this.applyInventoryResult(response.data);
            }).catch((error) => {
                console.error("UnequipItem error:", error);
            });
        },

        applyArmorPlate(item) {
            axios.post("https://qb-inventory/ApplyArmorPlate", {
                itemSlot: item.slot
            }).then((response) => {
                this.applyInventoryResult(response.data, item.slot);
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

            axios.post("https://qb-inventory/UseItem", { item }).catch((error) => {
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

            axios.post("https://qb-inventory/GiveItem", {
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

            axios.post("https://qb-inventory/DropItem", {
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

            const targetInventory = inventoryType === "player" ? this.playerInventory : this.otherInventory;
            const freeSlot = this.findNextAvailableSlot(targetInventory);

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

        findNextAvailableSlot(inventory) {
            const maxSlots = inventory === this.playerInventory ? this.totalSlots : this.otherInventorySlots;
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

            axios.post("https://qb-inventory/AttemptPurchase", {
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

            axios.post("https://qb-inventory/SellShopItem", {
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
            return item && (item.name === "phone" || item.name === "tablet");
        },

        buildAvailableDeviceAttachments(device) {
            if (!device || !device.name) return [];

            const info = device.info || {};
            if (device.name === "phone" && info.simNumber) return [];
            if (device.name === "tablet" && info.cryptoDrive) return [];

            const allowed = {
                phone: { simcard: true },
                tablet: { crypto_usb: true, cryptostick: true }
            }[device.name] || {};

            return Object.values(this.playerInventory)
                .filter((item) => item && item.name && allowed[item.name] && item.slot !== device.slot)
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

            axios.post("https://qb-inventory/GetDeviceData", {
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

            axios.post("https://qb-inventory/GetWeaponData", {
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

            axios.post("https://qb-inventory/ApplyAttachment", {
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

            axios.post("https://qb-inventory/ApplyDeviceAttachment", {
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

        removeDeviceAttachment(attachment) {
            if (!this.selectedDevice || !attachment || attachment.removable === false) return;

            axios.post("https://qb-inventory/RemoveDeviceAttachment", {
                AttachmentData: attachment,
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

            axios.post("https://qb-inventory/RemoveAttachment", {
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
            inventoryApp.showContextMenu = false;
            inventoryApp.showSubmenu = false;
            inventoryApp.activeSubmenu = null;
            inventoryApp.showWeaponAttachments = false;
            inventoryApp.showDeviceAttachments = false;
            inventoryApp.showRequiredItems = false;
            inventoryApp.showNotification = false;
            inventoryApp.clearDragData();
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
