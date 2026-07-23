return function(receivedKey)
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    while not LocalPlayer do
        task.wait(0.1)
        LocalPlayer = Players.LocalPlayer
    end

    local expectedKey = (LocalPlayer.UserId * 17) + (game.PlaceId * 3) + 1024

    if not receivedKey or receivedKey ~= expectedKey then
        task.spawn(function()
            LocalPlayer:Kick("YOU'RE A HORNY BUNNNNNNNY")
        end)
        task.wait(0.5)
        while true do end
        return
    end

    if getgenv().WitchassaultConnection then
        getgenv().WitchassaultConnection:Disconnect()
        getgenv().WitchassaultConnection = nil
    end

    if getgenv().WitchassaultFOV then
        getgenv().WitchassaultFOV:Destroy()
        getgenv().WitchassaultFOV = nil
    end

    if getgenv().WitchassaultSAFOV then
        getgenv().WitchassaultSAFOV:Destroy()
        getgenv().WitchassaultSAFOV = nil
    end

    local oldFolder = game:GetService("CoreGui"):FindFirstChild("ESP_Highlights") or (gethui and gethui():FindFirstChild("ESP_Highlights"))
    if oldFolder then
        oldFolder:Destroy()
    end

    local Rayfield = loadstring(game:HttpGet('https://raw.githubusercontent.com/nubold/xixixaxa/refs/heads/main/main.lua'))()

    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Lighting = game:GetService("Lighting")
    local CollectionService = game:GetService("CollectionService")

    local OriginalAmbient = Lighting.Ambient
    local OriginalBrightness = Lighting.Brightness

    local ESP_CONFIG = {
        TOP_OFFSET = Vector3.new(0, 3, 0),
        DISTANCE_DIVISOR = 3.5
    }
    local MIN_BULLET_SPEED = 1
    local ENTITY_FALL_THRESHOLD = -2

    local S = {
        Aimbot_Enabled = false,
        Aim_KeyHeld = false,
        Aim_Keybind = Enum.KeyCode.Q,
        Aimbot_WallCheck = true,
        Aim_FOV = 150,
        Show_FOV = false,

        ESP_Enabled = false,
        ESP_MaxDistance = math.huge,

        Entity_ESP_Enabled = false,
        Entity_ESP_MaxDistance = 1500,
        Entity_ESP_Safes = true,
        Entity_ESP_Registers = true,
        Entity_ESP_S1 = true,
        Entity_ESP_S2 = true,
        Entity_ESP_S3 = true,

        Fullbright_Enabled = false,
        Prediction_Enabled = false,
        Bullet_Speed = 1500,

        Door_Noclip_Enabled = false,

        FOV_Color = Color3.fromRGB(255, 255, 255),

        Player_Visible_Color = Color3.fromRGB(0, 255, 0),
        Player_Invisible_Color = Color3.fromRGB(255, 255, 255),
        Player_Teammate_Color = Color3.fromRGB(0, 128, 255),

        Entity_Safe_Color = Color3.fromRGB(0, 255, 0),
        Entity_S1_Color = Color3.fromRGB(170, 170, 170),
        Entity_S2_Color = Color3.fromRGB(0, 150, 255),
        Entity_S3_Color = Color3.fromRGB(255, 140, 0),
        Entity_Default_Visible_Color = Color3.fromRGB(255, 220, 0),
        Entity_Default_Invisible_Color = Color3.fromRGB(200, 130, 0)
    }

    local ESP_Cache = {}
    local Visibility_Cache = {}
    local Tracked_Entities = {}
    local Drawn_This_Frame = {}
    local Door_Cache = {}

    local ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "ESP_Highlights"
    ESPFolder.Parent = (gethui and gethui()) or game:GetService("CoreGui")

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    local function refreshRayFilter()
        local list = {}
        local char = LocalPlayer.Character
        local cam = workspace.CurrentCamera
        if char then table.insert(list, char) end
        if cam then table.insert(list, cam) end
        rayParams.FilterDescendantsInstances = list
    end

    refreshRayFilter()
    if LocalPlayer then
        LocalPlayer.CharacterAdded:Connect(function()
            task.spawn(refreshRayFilter)
        end)
    end

    local FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.Color = S.FOV_Color
    FOVCircle.Transparency = 1
    FOVCircle.Filled = false
    FOVCircle.Visible = false

    getgenv().WitchassaultFOV = FOVCircle

    local function ClearEntityESP(id)
        if ESP_Cache[id] then
            ESP_Cache[id].Highlight:Destroy()
            ESP_Cache[id].Text:Remove()
            ESP_Cache[id] = nil
        end
        Visibility_Cache[id] = nil
    end

    Players.PlayerRemoving:Connect(function(player)
        ClearEntityESP(tostring(player.UserId))
    end)

    local function AddEntity(obj)
        Tracked_Entities[obj] = true
    end

    local function RemoveEntity(obj)
        if Tracked_Entities[obj] then
            Tracked_Entities[obj] = nil
            ClearEntityESP(obj)
        end
    end

    local function CheckAndTagEntity(obj)
        if obj:IsA("MeshPart") then
            local isSpawnedPile = false
            local current = obj.Parent
            while current do
                if current.Name == "SpawnedPiles" then
                    isSpawnedPile = true
                    break
                end
                current = current.Parent
            end
            if isSpawnedPile and not CollectionService:HasTag(obj, "ESPEntity") then
                CollectionService:AddTag(obj, "ESPEntity")
            end
        elseif obj:IsA("Model") then
            local name = obj.Name
            if name:match("^Register_") or name:match("^MediumSafe_") or name:match("^SmallSafe_") then
                if not CollectionService:HasTag(obj, "ESPEntity") then
                    CollectionService:AddTag(obj, "ESPEntity")
                end
            end
        end
    end

    local function GetDoorsFolder()
        local map = workspace:FindFirstChild("Map")
        if not map then return nil end
        return map:FindFirstChild("Doors")
    end

    local function UpdateDoorPart(part, data)
        if not part or not part.Parent then return end
        
        local desiredCollide = not S.Door_Noclip_Enabled and data.CanCollide
        pcall(function()
            part.CanCollide = desiredCollide
        end)

        local isHitbox = part.Name == "DoorBase" or part.Name:lower():match("hitbox") or part.Name:lower():match("collider")
        if not isHitbox then
            local desiredTrans = data.Transparency
            if S.Door_Noclip_Enabled and data.Transparency < 0.9 then
                desiredTrans = 0.5
            end
            pcall(function()
                part.Transparency = desiredTrans
            end)
        else
            pcall(function()
                part.Transparency = 1
            end)
        end
    end

    local function UpdateAllDoors()
        for part, data in pairs(Door_Cache) do
            if part and part.Parent then
                UpdateDoorPart(part, data)
            else
                Door_Cache[part] = nil
            end
        end
    end

    local function RegisterDoorModel(doorModel)
        if not doorModel:IsA("Model") then return end
        for _, part in ipairs(doorModel:GetDescendants()) do
            if part:IsA("BasePart") and Door_Cache[part] == nil then
                Door_Cache[part] = {
                    CanCollide = part.CanCollide,
                    Transparency = part.Transparency
                }
                UpdateDoorPart(part, Door_Cache[part])
            end
        end
    end

    local function UnregisterDoorModel(doorModel)
        for _, part in ipairs(doorModel:GetDescendants()) do
            local data = Door_Cache[part]
            if data ~= nil then
                pcall(function()
                    part.CanCollide = data.CanCollide
                    part.Transparency = data.Transparency
                end)
                Door_Cache[part] = nil
            end
        end
    end

    local function GetEntityTier(obj)
        local current = obj
        while current and current.Parent do
            if current.Parent.Name == "SpawnedPiles" then
                return current.Name
            end
            current = current.Parent
        end
        return "Entity"
    end

    local function hideGreenBarriers(part)
        if part:IsA("BasePart") and part.Size.Magnitude > 3 then
            local color = part.Color
            if color.G > 0.7 and color.R < 0.3 and color.B < 0.3 then
                if part.Material == Enum.Material.Neon or part.Material == Enum.Material.ForceField then
                    part.Transparency = 1
                end
            end
        end
    end

    for _, obj in ipairs(CollectionService:GetTagged("ESPEntity")) do
        AddEntity(obj)
    end

    CollectionService:GetInstanceAddedSignal("ESPEntity"):Connect(AddEntity)
    CollectionService:GetInstanceRemovedSignal("ESPEntity"):Connect(RemoveEntity)

    local mapFolder = workspace:FindFirstChild("Map")

    task.spawn(function()
        local count = 0
        if mapFolder then
            for _, obj in ipairs(mapFolder:GetDescendants()) do
                CheckAndTagEntity(obj)
                count = count + 1
                if count % 200 == 0 then task.wait() end
            end
        end
    end)

    if mapFolder then
        mapFolder.DescendantAdded:Connect(function(obj)
            if obj:IsA("MeshPart") or obj:IsA("Model") then
                CheckAndTagEntity(obj)
            end
        end)
        
        mapFolder.DescendantRemoving:Connect(function(obj)
            RemoveEntity(obj)
        end)
    end

    task.spawn(function()
        local doorsFolder = GetDoorsFolder()
        local attempts = 0
        while not doorsFolder and attempts < 100 do
            task.wait(0.2)
            doorsFolder = GetDoorsFolder()
            attempts = attempts + 1
        end

        if not doorsFolder then return end

        for _, doorModel in ipairs(doorsFolder:GetChildren()) do
            RegisterDoorModel(doorModel)
        end

        doorsFolder.ChildAdded:Connect(RegisterDoorModel)
        doorsFolder.ChildRemoved:Connect(UnregisterDoorModel)
    end)

    task.spawn(function()
        local count = 0
        if mapFolder then
            for _, desc in ipairs(mapFolder:GetDescendants()) do
                hideGreenBarriers(desc)
                count = count + 1
                if count % 200 == 0 then task.wait() end
            end
        end
    end)

    if mapFolder then
        mapFolder.DescendantAdded:Connect(function(obj)
            if obj:IsA("BasePart") then
                hideGreenBarriers(obj)
            end
        end)
    end

    local function GetVisibility(targetId, char)
        local currentTime = tick()

        if Visibility_Cache[targetId] and (currentTime - Visibility_Cache[targetId].lastUpdate) < 0.3 then
            return Visibility_Cache[targetId].isVisible
        end

        local cam = workspace.CurrentCamera
        if not cam then return false end

        local head = char:FindFirstChild("Head")
        local origin = cam.CFrame.Position
        local isVisible = false

        if head and head:IsA("BasePart") then
            local result = workspace:Raycast(origin, head.Position - origin, rayParams)
            if result and result.Instance:IsDescendantOf(char) then
                isVisible = true
            end
        end

        Visibility_Cache[targetId] = { isVisible = isVisible, lastUpdate = currentTime }
        return isVisible
    end

    local function DrawESP(id, char, hrp, name, team, kind)
        local isEntity = kind == "entity"

        local showGlow, maxDist
        if kind == "player" then
            showGlow = S.ESP_Enabled
            maxDist = S.ESP_MaxDistance
        elseif kind == "entity" then
            showGlow = S.Entity_ESP_Enabled
            maxDist = S.Entity_ESP_MaxDistance
        else
            return
        end

        if not showGlow then return end

        if isEntity then
            local allowed = false
            if char:IsA("Model") then
                if char.Name:match("^Register_") then
                    allowed = S.Entity_ESP_Registers
                elseif char.Name:match("^MediumSafe_") or char.Name:match("^SmallSafe_") then
                    allowed = S.Entity_ESP_Safes
                end
            else
                local tier = GetEntityTier(char)
                if tier == "S1" then
                    allowed = S.Entity_ESP_S1
                elseif tier == "S2" then
                    allowed = S.Entity_ESP_S2
                elseif tier == "S3" then
                    allowed = S.Entity_ESP_S3
                else
                    allowed = true
                end
            end

            if not allowed then
                if ESP_Cache[id] then
                    if ESP_Cache[id].Highlight.Enabled then
                        pcall(function() ESP_Cache[id].Highlight.Enabled = false end)
                    end
                    if ESP_Cache[id].Text.Visible then
                        pcall(function() ESP_Cache[id].Text.Visible = false end)
                    end
                end
                return
            end
        end

        local cam = workspace.CurrentCamera
        if not cam then return end

        local dist = (cam.CFrame.Position - hrp.Position).Magnitude
        if dist > maxDist or dist == 0 then return end

        local rootScreen, onScreen = cam:WorldToViewportPoint(hrp.Position)
        if not onScreen then return end

        Drawn_This_Frame[id] = true

        if not ESP_Cache[id] then
            local highlight = Instance.new("Highlight")
            highlight.FillTransparency = 0.5
            highlight.OutlineTransparency = 0
            highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            highlight.Adornee = char
            highlight.Parent = ESPFolder

            local text = Drawing.new("Text")
            text.Size = 14; text.Center = true; text.Outline = true; text.Font = 2
            text.OutlineColor = Color3.fromRGB(0, 0, 0)

            ESP_Cache[id] = { Highlight = highlight, Text = text }
        end

        local highlight, text = ESP_Cache[id].Highlight, ESP_Cache[id].Text

        if highlight.Adornee ~= char then
            highlight.Adornee = char
        end

        local topScreenPos = cam:WorldToViewportPoint(hrp.Position + ESP_CONFIG.TOP_OFFSET)

        local visible = GetVisibility(id, char)
        local renderColor

        if isEntity then
            if char:IsA("Model") and (char.Name:match("^Register_") or char.Name:match("^MediumSafe_") or char.Name:match("^SmallSafe_")) then
                renderColor = S.Entity_Safe_Color
            else
                local tier = GetEntityTier(char)
                if tier == "S1" then
                    renderColor = S.Entity_S1_Color
                elseif tier == "S2" then
                    renderColor = S.Entity_S2_Color
                elseif tier == "S3" then
                    renderColor = S.Entity_S3_Color
                else
                    renderColor = visible and S.Entity_Default_Visible_Color or S.Entity_Default_Invisible_Color
                end
            end
        else
            renderColor = S.Player_Invisible_Color
            if team == LocalPlayer.Team and team ~= nil then 
                renderColor = S.Player_Teammate_Color
            elseif visible then 
                renderColor = S.Player_Visible_Color 
            end
        end

        if highlight.FillColor ~= renderColor then
            highlight.FillColor = renderColor
        end
        if highlight.OutlineColor ~= renderColor then
            highlight.OutlineColor = renderColor
        end
        if not highlight.Enabled then
            highlight.Enabled = true
        end

        if not isEntity then
            text.Text = string.format("%s [%dm]", name, math.floor(dist / ESP_CONFIG.DISTANCE_DIVISOR))
            text.Position = Vector2.new(rootScreen.X, topScreenPos.Y - 18)
            text.Color = renderColor
            if not text.Visible then
                text.Visible = true
            end
        else
            if text.Visible then
                text.Visible = false
            end
        end
    end

    local function GetClosestTarget()
        if not S.Aimbot_Enabled then return nil end

        local cam = workspace.CurrentCamera
        if not cam then return nil end

        local target = nil
        local shortestDistance = S.Aim_FOV
        local mousePos = UserInputService:GetMouseLocation()

        local function CheckTarget(entityId, character)
            local aimPart = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
            if not aimPart then return end

            local screenPos, onScreen = cam:WorldToViewportPoint(aimPart.Position)
            if onScreen then
                local distanceToMouse = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                if distanceToMouse < shortestDistance then
                    if S.Aimbot_WallCheck then
                        if GetVisibility(entityId, character) then
                            target = aimPart
                            shortestDistance = distanceToMouse
                        end
                    else
                        target = aimPart
                        shortestDistance = distanceToMouse
                    end
                end
            end
        end

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                if player.Team ~= LocalPlayer.Team or player.Team == nil then
                    CheckTarget(tostring(player.UserId), player.Character)
                end
            end
        end

        return target
    end

    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode == S.Aim_Keybind then
            S.Aim_KeyHeld = true
        end
    end)

    UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if input.KeyCode == S.Aim_Keybind then
            S.Aim_KeyHeld = false
        end
    end)

    local Window = Rayfield:CreateWindow({ Name = "Witchassault", ConfigurationSaving = { Enabled = false } })
    local CombatTab = Window:CreateTab("Combat")
    local VisualsTab = Window:CreateTab("Visuals")
    local ColorTab = Window:CreateTab("Color")

    CombatTab:CreateSection("Aimbot")
    CombatTab:CreateToggle({ Name = "Aimbot Enabled", CurrentValue = false, Callback = function(v) S.Aimbot_Enabled = v end })
    CombatTab:CreateKeybind({ Name = "Aimbot Keybind", CurrentKeybind = "Q", HoldToInteract = false, Callback = function() end })
    CombatTab:CreateToggle({ Name = "Aimbot Wall Check", CurrentValue = true, Callback = function(v) S.Aimbot_WallCheck = v end })
    CombatTab:CreateToggle({ Name = "Aimbot Prediction", CurrentValue = false, Callback = function(v) S.Prediction_Enabled = v end })
    CombatTab:CreateToggle({ Name = "FOV", CurrentValue = false, Callback = function(v) S.Show_FOV = v end })
    CombatTab:CreateSlider({ Name = "FOV Radius", Range = { 50, 800 }, Increment = 10, CurrentValue = 150, Callback = function(v) S.Aim_FOV = v end })

    VisualsTab:CreateSection("ESP Settings")
    VisualsTab:CreateToggle({ Name = "Player ESP", CurrentValue = false, Callback = function(v) S.ESP_Enabled = v end })
    VisualsTab:CreateToggle({ Name = "Entity ESP", CurrentValue = false, Callback = function(v) S.Entity_ESP_Enabled = v end })
    VisualsTab:CreateDropdown({
        Name = "Entity List",
        Options = {"Show Safes", "Show Registers", "Show S1 Items", "Show S2 Items", "Show S3 Items"},
        CurrentOption = {"Show Safes", "Show Registers", "Show S1 Items", "Show S2 Items", "Show S3 Items"},
        MultipleOptions = true,
        Flag = "EntityFiltersDropdown",
        Callback = function(SelectedOptions)
            S.Entity_ESP_Safes = false
            S.Entity_ESP_Registers = false
            S.Entity_ESP_S1 = false
            S.Entity_ESP_S2 = false
            S.Entity_ESP_S3 = false
            for _, option in ipairs(SelectedOptions) do
                if option == "Show Safes" then
                    S.Entity_ESP_Safes = true
                elseif option == "Show Registers" then
                    S.Entity_ESP_Registers = true
                elseif option == "Show S1 Items" then
                    S.Entity_ESP_S1 = true
                elseif option == "Show S2 Items" then
                    S.Entity_ESP_S2 = true
                elseif option == "Show S3 Items" then
                    S.Entity_ESP_S3 = true
                end
            end
        end
    })
    VisualsTab:CreateSlider({ Name = "Entity ESP Distance", Range = { 50, 5000 }, Increment = 50, CurrentValue = 1500, Callback = function(v) S.Entity_ESP_MaxDistance = v end })

    VisualsTab:CreateSection("Other")
    VisualsTab:CreateToggle({ 
        Name = "Fullbright", 
        CurrentValue = false, 
        Callback = function(v) 
            S.Fullbright_Enabled = v 
            if not v then
                Lighting.Ambient = OriginalAmbient
                Lighting.Brightness = OriginalBrightness
            end
        end 
    })
    VisualsTab:CreateToggle({ 
        Name = "Door Noclip", 
        CurrentValue = false, 
        Callback = function(v) 
            S.Door_Noclip_Enabled = v 
            UpdateAllDoors()
        end 
    })

    ColorTab:CreateSection("Player ESP Colors")
    ColorTab:CreateColorPicker({
        Name = "Visible Enemy",
        Color = Color3.fromRGB(0, 255, 0),
        Flag = "PlayerVisibleColorpicker",
        Callback = function(v) S.Player_Visible_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "Invisible Enemy / Default",
        Color = Color3.fromRGB(255, 255, 255),
        Flag = "PlayerInvisibleColorpicker",
        Callback = function(v) S.Player_Invisible_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "Teammate",
        Color = Color3.fromRGB(0, 128, 255),
        Flag = "PlayerTeammateColorpicker",
        Callback = function(v) S.Player_Teammate_Color = v end
    })

    ColorTab:CreateSection("Entity ESP Colors")
    ColorTab:CreateColorPicker({
        Name = "Safes & Registers",
        Color = Color3.fromRGB(0, 255, 0),
        Flag = "EntitySafeColorpicker",
        Callback = function(v) S.Entity_Safe_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "S1 Items",
        Color = Color3.fromRGB(170, 170, 170),
        Flag = "EntityS1Colorpicker",
        Callback = function(v) S.Entity_S1_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "S2 Items",
        Color = Color3.fromRGB(0, 150, 255),
        Flag = "EntityS2Colorpicker",
        Callback = function(v) S.Entity_S2_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "S3 Items",
        Color = Color3.fromRGB(255, 140, 0),
        Flag = "EntityS3Colorpicker",
        Callback = function(v) S.Entity_S3_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "Default (Visible)",
        Color = Color3.fromRGB(255, 220, 0),
        Flag = "EntityDefVisibleColorpicker",
        Callback = function(v) S.Entity_Default_Visible_Color = v end
    })
    ColorTab:CreateColorPicker({
        Name = "Default (Invisible)",
        Color = Color3.fromRGB(200, 130, 0),
        Flag = "EntityDefInvisibleColorpicker",
        Callback = function(v) S.Entity_Default_Invisible_Color = v end
    })

    local WitchassaultConnection = RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
        if not cam then return end

        local mousePos = UserInputService:GetMouseLocation()

        FOVCircle.Visible = S.Show_FOV
        if S.Show_FOV then
            FOVCircle.Position = mousePos
            FOVCircle.Radius = S.Aim_FOV
            FOVCircle.Color = S.FOV_Color
        end

        if S.Fullbright_Enabled then
            if Lighting.Ambient ~= Color3.fromRGB(255, 255, 255) then
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            end
            if Lighting.Brightness ~= 2 then
                Lighting.Brightness = 2
            end
        end

        table.clear(Drawn_This_Frame)

        if S.ESP_Enabled then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        DrawESP(tostring(player.UserId), player.Character, hrp, player.Name, player.Team, "player")
                    end
                end
            end
        end

        if S.Entity_ESP_Enabled then
            for entity in pairs(Tracked_Entities) do
                if entity and entity.Parent then
                    local hrp = (entity:IsA("BasePart") and entity) or entity:FindFirstChild("HumanoidRootPart") or (entity:IsA("Model") and entity.PrimaryPart) or entity:FindFirstChildWhichIsA("BasePart")
                    if hrp then
                        local vel = (hrp:IsA("BasePart") and hrp.AssemblyLinearVelocity) or Vector3.new()
                        if not (vel and vel.Y < ENTITY_FALL_THRESHOLD) then
                            DrawESP(entity, entity, hrp, nil, nil, "entity")
                        end
                    end
                else
                    RemoveEntity(entity)
                end
            end
        end

        for id, cached in pairs(ESP_Cache) do
            if not Drawn_This_Frame[id] then
                if cached.Highlight.Enabled then
                    cached.Highlight.Enabled = false
                end
                if cached.Text.Visible then
                    cached.Text.Visible = false
                end
            end
        end

        if S.Aimbot_Enabled and S.Aim_KeyHeld then
            local aimTarget = GetClosestTarget()
            if aimTarget then
                local aimPos = aimTarget.Position

                if S.Prediction_Enabled then
                    local d = (aimPos - cam.CFrame.Position).Magnitude
                    local speed = math.max(S.Bullet_Speed, MIN_BULLET_SPEED)
                    local vel = aimTarget.AssemblyLinearVelocity or Vector3.new()
                    aimPos = aimPos + vel * (d / speed)
                end

                local currentCFrame = cam.CFrame
                local desiredCFrame = CFrame.new(currentCFrame.Position, aimPos)
                cam.CFrame = desiredCFrame
            end
        end
    end)

    getgenv().WitchassaultConnection = WitchassaultConnection
end
