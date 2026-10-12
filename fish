-- Storage Hunters | Auto Fishing Test GUI
-- Standalone test; does not modify your existing hub.

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local misc = RS:WaitForChild("Events"):WaitForChild("Misc")
local inventoryEvents = RS.Events:WaitForChild("Inventory")

local FishingCast = misc:WaitForChild("FishingCast")
local FishingResult = misc:WaitForChild("FishingResult")
local FishingCancel = misc:WaitForChild("FishingCancel")
local FishingState = misc:WaitForChild("FishingState")
local GetInventory = inventoryEvents:WaitForChild("GetPlayerInventory")
local EquipItem = inventoryEvents:WaitForChild("EquipItem")

local WATER = workspace:WaitForChild("BBOW Builder Assets")
    :WaitForChild("Grass and Water")
    :WaitForChild("Model")

local CAST_POSITION = Vector3.new(
    630.135498046875,
    1712.3345947265625,
    -941.6016845703125
)

-- Close any previous test GUI and stop its automation.
if getgenv().SHFishingTestCleanup then
    pcall(getgenv().SHFishingTestCleanup)
end

local running = false
local destroyed = false
local currentCastId = nil
local phase = "idle"
local catchCount = 0
local attempts = 0
local lastRod = nil
local connections = {}

local function disconnectAll()
    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end
    table.clear(connections)
end

local gui = Instance.new("ScreenGui")
gui.Name = "SH_AutoFishing_Test"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(310, 245)
main.Position = UDim2.new(0.5, -155, 0.5, -122)
main.BackgroundColor3 = Color3.fromRGB(29, 24, 27)
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(155, 47, 57)
stroke.Thickness = 1.5
stroke.Parent = main

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -45, 0, 43)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "AUTO FISHING | TEST"
title.TextColor3 = Color3.fromRGB(255, 235, 235)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = main

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 28)
close.Position = UDim2.new(1, -37, 0, 8)
close.Text = "X"
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.TextColor3 = Color3.new(1, 1, 1)
close.BackgroundColor3 = Color3.fromRGB(145, 40, 49)
close.Parent = main
Instance.new("UICorner", close).CornerRadius = UDim.new(0, 6)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -24, 0, 44)
status.Position = UDim2.fromOffset(12, 51)
status.BackgroundTransparency = 1
status.TextColor3 = Color3.fromRGB(210, 210, 210)
status.Font = Enum.Font.Gotham
status.TextSize = 13
status.TextWrapped = true
status.Text = "Status: Ready"
status.Parent = main

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -24, 0, 43)
toggle.Position = UDim2.fromOffset(12, 105)
toggle.BackgroundColor3 = Color3.fromRGB(65, 65, 65)
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Text = "AUTO FISHING: OFF"
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 14
toggle.Parent = main
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 7)

local stats = Instance.new("TextLabel")
stats.Size = UDim2.new(1, -24, 0, 50)
stats.Position = UDim2.fromOffset(12, 155)
stats.BackgroundTransparency = 1
stats.TextColor3 = Color3.fromRGB(225, 225, 225)
stats.Font = Enum.Font.Gotham
stats.TextSize = 13
stats.Text = "Caught: 0 | Casts: 0"
stats.Parent = main

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, -24, 0, 30)
note.Position = UDim2.fromOffset(12, 207)
note.BackgroundTransparency = 1
note.TextColor3 = Color3.fromRGB(150, 150, 150)
note.Font = Enum.Font.Gotham
note.TextSize = 11
note.Text = "Server-state driven | Auto rod replacement"
note.Parent = main

local function setStatus(message)
    if not destroyed then
        status.Text = "Status: " .. message
    end
end

local function updateStats()
    if not destroyed then
        stats.Text = ("Caught: %d | Casts: %d")
            :format(catchCount, attempts)
    end
end

local function updateToggle()
    if destroyed then return end
    toggle.Text = running
        and "AUTO FISHING: ON"
        or "AUTO FISHING: OFF"
    toggle.BackgroundColor3 = running
        and Color3.fromRGB(35, 125, 65)
        or Color3.fromRGB(65, 65, 65)
end

-- Support several possible inventory schemas.
local function isBroken(item)
    if item.Broken == true or item.IsBroken == true then
        return true
    end

    local mutators = item.Mutators or item.mutators
    if type(mutators) == "table" then
        for key, value in pairs(mutators) do
            if tostring(key):lower() == "broken"
                and value ~= false then
                return true
            end

            if type(value) == "string"
                and value:lower() == "broken" then
                return true
            end

            if type(value) == "table" then
                local name = value.Name or value.name
                    or value.Mutator or value.mutator

                if tostring(name):lower() == "broken" then
                    return true
                end
            end
        end
    end

    return false
end

local function isRod(item)
    local name = tostring(
        item.Name or item.name
        or item.ItemName or item.itemName
        or item.DisplayName or item.displayName
        or ""
    ):lower()

    local category = tostring(
        item.Category or item.category
        or item.Type or item.type
        or ""
    ):lower()

    return name:find("fishing rod", 1, true) ~= nil
        or category:find("fishing rod", 1, true) ~= nil
        or category == "fishingrod"
end

local function findRod()
    local ok, inventory = pcall(function()
        return GetInventory:InvokeServer()
    end)

    if not ok or type(inventory) ~= "table" then
        return nil, "Inventory unavailable"
    end

    -- Some inventory responses wrap the items.
    local items = inventory.Items or inventory.items
        or inventory.Inventory or inventory.inventory
        or inventory

    if type(items) ~= "table" then
        return nil, "Unknown inventory format"
    end

    for key, item in pairs(items) do
        if type(item) == "table"
            and isRod(item)
            and not isBroken(item) then

            local guid = item.UUID or item.uuid
                or item.Guid or item.guid
                or item.Id or item.id

            if not guid and type(key) == "string" then
                guid = key
            end

            if type(guid) == "string" and guid ~= "" then
                return guid
            end
        end
    end

    return nil, "No usable fishing rods found"
end

local function equipRod()
    local guid, err = findRod()
    if not guid then
        return false, err
    end

    if guid ~= lastRod then
        setStatus("Equipping fishing rod...")
        local ok = pcall(function()
            EquipItem:FireServer(guid)
        end)

        if not ok then
            return false, "Rod equip failed"
        end

        lastRod = guid
        task.wait(0.35)
    end

    return true
end

local function stopFishing(cancel)
    running = false
    phase = "idle"
    currentCastId = nil
    updateToggle()

    if cancel then
        pcall(function()
            FishingCancel:FireServer()
        end)
    end
end

-- Server fishing events
table.insert(connections, FishingState.OnClientEvent:Connect(
    function(state, data)
        if not running or destroyed then return end
        if type(data) ~= "table" then data = {} end

        if state == "cast" then
            currentCastId = data.castId
            phase = "waiting"
            setStatus(("Waiting for bite (%.1fs)...")
                :format(tonumber(data.biteIn) or 0))

        elseif state == "reel" then
            if currentCastId ~= nil
                and data.castId ~= nil
                and data.castId ~= currentCastId then
                return
            end

            phase = "reeling"
            setStatus("Reeling: " ..
                tostring(data.itemName or "Fish"))

            -- Test whether the server accepts a catch result
            -- immediately after entering the reel state.
            local ok = pcall(function()
                FishingResult:FireServer("caught")
            end)

            if not ok then
                setStatus("Failed to submit catch result")
            else
                phase = "result_sent"
            end

        elseif state == "done" then
            if phase == "idle" then return end

            local reason = tostring(data.reason or "")
            if reason == "caught" then
                catchCount += 1
                setStatus("Caught: " ..
                    tostring(data.itemName or "Unknown"))
            else
                setStatus("Fishing ended: " .. reason)
            end

            phase = "done"
            currentCastId = nil
            updateStats()
        end
    end
))

-- Main automation loop
task.spawn(function()
    while not destroyed do
        if not running then
            task.wait(0.15)
        elseif phase == "idle" or phase == "done" then
            phase = "preparing"

            local equipped, err = equipRod()
            if not equipped then
                setStatus(err or "Cannot equip rod")
                stopFishing(false)
            elseif running then
                local water = WATER:GetChildren()[6]

                if not water then
                    setStatus("Water target missing")
                    stopFishing(false)
                else
                    phase = "casting"
                    setStatus("Casting...")
                    attempts += 1
                    updateStats()

                    local ok = pcall(function()
                        FishingCast:FireServer(
                            water,
                            CAST_POSITION
                        )
                    end)

                    if not ok then
                        setStatus("Cast failed")
                        phase = "done"
                        task.wait(1)
                    else
                        -- Wait for server confirmation, not a
                        -- fixed bite/reel delay.
                        local start = os.clock()
                        while running
                            and phase == "casting"
                            and os.clock() - start < 8 do
                            task.wait(0.1)
                        end

                        if running and phase == "casting" then
                            setStatus("Cast timeout; retrying")
                            phase = "done"
                        end
                    end
                end
            end
        else
            task.wait(0.1)
        end
    end
end)

toggle.MouseButton1Click:Connect(function()
    if running then
        stopFishing(true)
        setStatus("Stopped")
    else
        running = true
        phase = "idle"
        lastRod = nil
        updateToggle()
        setStatus("Starting...")
    end
end)

-- Draggable GUI
local dragging = false
local dragStart
local startPos

table.insert(connections, title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end))

table.insert(connections, UIS.InputChanged:Connect(function(input)
    if dragging and (
        input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
    ) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end))

table.insert(connections, UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInput
