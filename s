local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Events = ReplicatedStorage:WaitForChild("Events")

local InventoryEvents = Events:WaitForChild("Inventory")
local WashEvents = Events:WaitForChild("Wash")

local GetPlayerInventory =
    InventoryEvents:WaitForChild("GetPlayerInventory")

local GetSlotState =
    WashEvents:WaitForChild("GetSlotState")

local StartWash =
    WashEvents:WaitForChild("StartWash")

--==================================================
-- DIRTY ITEM DETECTION
--==================================================

local function IsDirtyItem(item)

    if typeof(item) ~= "table" then
        return false
    end

    local mutators = item.Mutators

    if typeof(mutators) ~= "table" then
        return false
    end

    for _, mutator in pairs(mutators) do

        if typeof(mutator) == "table" then

            if (mutator.name or mutator.Name) == "Dirty" then
                return true
            end

        end

    end

    return false
end

--==================================================
-- FIND UUID/GUID
--==================================================

local function FindItemGUID(item)

    if typeof(item) ~= "table" then
        return nil
    end

    -- Check common fields first
    local possibleFields = {
        "ItemGUID",
        "ItemGuid",
        "ItemUUID",
        "ItemUuid",
        "GUID",
        "Guid",
        "UUID",
        "Uuid",
        "Id",
        "ID"
    }

    for _, field in ipairs(possibleFields) do

        local value = item[field]

        if typeof(value) == "string" then

            if value:match(
                "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
            ) then

                return value

            end

        end

    end

    -- Fallback: search every direct value
    for key, value in pairs(item) do

        if typeof(value) == "string" then

            if value:match(
                "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
            ) then

                return value

            end

        end

        if typeof(key) == "string" then

            if key:match(
                "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
            ) then

                return key

            end

        end

    end

    return nil
end

--==================================================
-- SCAN INVENTORY
--==================================================

local function ScanInventory(value, path, results, seen)

    if typeof(value) ~= "table" then
        return
    end

    seen = seen or {}
    results = results or {}

    if seen[value] then
        return results
    end

    seen[value] = true

    if IsDirtyItem(value) then

        local guid = FindItemGUID(value)

        print("")
        print("DIRTY ITEM FOUND")
        print("Path:", path)
        print("GUID:", guid)

        if guid then

            table.insert(results, {
                GUID = guid,
                Path = path,
                Data = value
            })

        else

            warn("Dirty item found but GUID was not found!")

        end

    end

    for key, child in pairs(value) do

        if typeof(child) == "table" then

            ScanInventory(
                child,
                path .. "." .. tostring(key),
                results,
                seen
            )

        end

    end

    return results
end

--==================================================
-- GET INVENTORY
--==================================================

print("")
print("==========================================")
print("        AUTO WASH TEST")
print("==========================================")
print("Getting inventory...")

local success, inventory = pcall(function()
    return GetPlayerInventory:InvokeServer()
end)

if not success then
    warn("Inventory failed:", inventory)
    return
end

local dirtyItems =
    ScanInventory(
        inventory,
        "Inventory",
        {}
    )

print("")
print("Dirty items discovered:", #dirtyItems)

if #dirtyItems == 0 then
    warn("No Dirty items found.")
    return
end

--==================================================
-- GET WASH SLOTS
--==================================================

print("")
print("Checking wash slots...")

local slotSuccess, slotState = pcall(function()
    return GetSlotState:InvokeServer()
end)

if not slotSuccess then
    warn("GetSlotState failed:", slotState)
    return
end

print("Slot state received.")

local unlockedCount =
    tonumber(slotState.unlockedCount) or 3

print(
    "Unlocked slots:",
    unlockedCount
)

local slots = slotState.slots

if typeof(slots) ~= "table" then
    warn("Could not find slot table.")
    return
end

--==================================================
-- FIND EMPTY SLOTS
--==================================================

local emptySlots = {}

for slotNumber = 1, math.min(unlockedCount, 3) do

    local slot = slots[slotNumber]

    if slot == nil then

        print(
            "Slot",
            slotNumber,
            "EMPTY"
        )

        table.insert(
            emptySlots,
            slotNumber
        )

    elseif slot.ItemData == nil then

        print(
            "Slot",
            slotNumber,
            "EMPTY"
        )

        table.insert(
            emptySlots,
            slotNumber
        )

    else

        print(
            "Slot",
            slotNumber,
            "OCCUPIED"
        )

    end

end

print("")
print("Empty slots:", #emptySlots)

if #emptySlots == 0 then

    print("All 3 wash slots are occupied.")
    return

end

--==================================================
-- START WASHES
--==================================================

print("")
print("Starting washes...")

local itemIndex = 1

for _, slotNumber in ipairs(emptySlots) do

    local item = dirtyItems[itemIndex]

    if not item then
        break
    end

    print("")
    print("------------------------------------------")
    print("Starting wash")
    print("Slot:", slotNumber)
    print("GUID:", item.GUID)
    print("------------------------------------------")

    local washSuccess, result = pcall(function()

        return StartWash:InvokeServer(
            slotNumber,
            item.GUID,
            "Inventory"
        )

    end)

    if washSuccess then

        print(
            "START WASH CALLED SUCCESSFULLY"
        )

        print(
            "Server result:",
            result
        )

    else

        warn(
            "START WASH ERROR:",
            result
        )

    end

    itemIndex += 1

    task.wait(0.5)

end

print("")
print("==========================================")
print("        AUTO WASH TEST COMPLETE")
print("==========================================")
