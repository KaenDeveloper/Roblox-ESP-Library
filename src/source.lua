local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local CameraCache = {
    position = Vector3.new(),
    cframe = CFrame.new(),
    fieldOfView = 70,
    lastUpdate = 0
}

local JOINT_CONFIGS = {
    R15 = {
        {"Head", "UpperTorso"},
        {"UpperTorso", "LowerTorso"},
        {"UpperTorso", "LeftUpperArm"},
        {"LeftUpperArm", "LeftLowerArm"},
        {"LeftLowerArm", "LeftHand"},
        {"UpperTorso", "RightUpperArm"},
        {"RightUpperArm", "RightLowerArm"},
        {"RightLowerArm", "RightHand"},
        {"LowerTorso", "LeftUpperLeg"},
        {"LeftUpperLeg", "LeftLowerLeg"},
        {"LeftLowerLeg", "LeftFoot"},
        {"LowerTorso", "RightUpperLeg"},
        {"RightUpperLeg", "RightLowerLeg"},
        {"RightLowerLeg", "RightFoot"},
    },
    R6 = {
        {"Head", "Torso"},
        {"Torso", "Left Arm"},
        {"Torso", "Right Arm"},
        {"Torso", "Left Leg"},
        {"Torso", "Right Leg"},
    }
}

local LOD_LEVELS = {
    HIGH = {
        distance = 150,
        updateRate = 1,
        features = {
            box = true,
            healthBar = true,
            nickname = true,
            skeleton = true,
            chams = true
        }
    },
    MEDIUM = {
        distance = 250,
        updateRate = 1, 
        features = {
            box = true,
            healthBar = true,
            nickname = true,
            skeleton = false,
            chams = true
        }
    },
    LOW = {
        distance = 400,
        updateRate = 2,
        features = {
            box = true,
            healthBar = false,
            nickname = true,
            skeleton = false,
            chams = false
        }
    }
}

local DEFAULT_SETTINGS = {
    Enabled = true,
    BoxEnable = true,
    HealthBar = true,
    Nickname = true,
    Skeleton = false,
    ChamsEnable = false,
    
    -- Colors
    NicknameColor = Color3.new(1, 1, 1),
    SkeletonColor = Color3.new(1, 1, 1),
    BoxColor = Color3.new(1, 1, 1),
    ChamsColor = Color3.new(1, 1, 1),
    ChamsOutlineColor = Color3.new(1, 1, 1),
    OutlineColor = Color3.fromRGB(0, 0, 0),
    HealthBarColor = Color3.fromRGB(0, 255, 0),
    HealthBarOutlineColor = Color3.fromRGB(0, 0, 0),
    
    -- Dimensions
    BoxThickness = 2,
    LineThickness = 2,
    HealthBarlineThickness = 2,
    HealthBarOutlineThickness = 3,
    TextSize = 19,
    RenderDistance = 650,
    
    -- Performance settings
    MaxCacheSize = 20,           --// Maximum cache
    CleanupInterval = 20,        --// Per 1min cleanup
    MaxSkeletonParts = 20,       --// Maximum skeleton parts per player
    CacheUpdateInterval = 0.016, --// 60fps cache updates
    UseLOD = true,

    DeveloperMode = true
}

local ESPObjectPool = {
    available = {},
    inUse = {},
    lastCleanup = 0,
    creationTimes = {}
}

local PerformanceMetrics = {
    frameCount = 0,
    lastFPSCheck = 0,
    currentFPS = 60,
    adaptiveLOD = false
}

local lastCamCFrame = nil
local function UpdateCameraCache()
    local currentTime = tick()
    local camCFrame = CurrentCamera.CFrame
    if currentTime - CameraCache.lastUpdate >= DEFAULT_SETTINGS.CacheUpdateInterval and camCFrame ~= lastCamCFrame then
        CameraCache.position = CurrentCamera.CFrame.Position
        CameraCache.cframe = camCFrame 
        CameraCache.fieldOfView = CurrentCamera.FieldOfView
        CameraCache.lastUpdate = currentTime
    end
end

local function WorldToViewportPoint(position)
    local screenPosition, onScreen = CurrentCamera:WorldToViewportPoint(position)
    return Vector2.new(screenPosition.X, screenPosition.Y), onScreen
end

local function GetSquaredDistanceFromCamera(position)
    local delta = position - CameraCache.position
    return delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
end

local function CreateDrawing(drawingType, properties)
    local drawing = Drawing.new(drawingType)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

local function GetLODLevel(squaredDistance)
    if squaredDistance <= LOD_LEVELS.HIGH.distance * LOD_LEVELS.HIGH.distance then
        return LOD_LEVELS.HIGH, "HIGH"
    elseif squaredDistance <= LOD_LEVELS.MEDIUM.distance * LOD_LEVELS.MEDIUM.distance then
        return LOD_LEVELS.MEDIUM, "MEDIUM"
    elseif squaredDistance <= LOD_LEVELS.LOW.distance * LOD_LEVELS.LOW.distance then
        return LOD_LEVELS.LOW, "LOW"
    else
        return nil, "OUT_OF_RANGE"
    end
end

local function UpdatePerformanceMetrics()
    PerformanceMetrics.frameCount = PerformanceMetrics.frameCount + 1
    local currentTime = tick()
    
    if currentTime - PerformanceMetrics.lastFPSCheck >= 1.0 then
        PerformanceMetrics.currentFPS = PerformanceMetrics.frameCount / (currentTime - PerformanceMetrics.lastFPSCheck)
        PerformanceMetrics.frameCount = 0
        PerformanceMetrics.lastFPSCheck = currentTime
        
        -- Enable adaptive LOD if FPS drops below 30
        PerformanceMetrics.adaptiveLOD = PerformanceMetrics.currentFPS < 30
    end
end

function ESPObjectPool:Output(input)
   if DEFAULT_SETTINGS.DeveloperMode then warn(input) end
end

function ESPObjectPool:GetDrawing(drawingType, properties, maxCacheSize)
    local poolKey = drawingType
    maxCacheSize = maxCacheSize or DEFAULT_SETTINGS.MaxCacheSize
 
    if not self.available[poolKey] then
        self.available[poolKey] = {}
    end
    
    local drawing = table.remove(self.available[poolKey])
    if not drawing then
        drawing = CreateDrawing(drawingType, properties)
        self.creationTimes[drawing] = tick()
    else
        for property, value in pairs(properties) do
            drawing[property] = value
        end
    end
    
    if not self.inUse[poolKey] then
        self.inUse[poolKey] = {}
    end
    table.insert(self.inUse[poolKey], drawing)
    
    return drawing
end

function ESPObjectPool:ReturnDrawing(drawingType, drawing)
    if not drawing then return end
    
    drawing.Visible = false
    local poolKey = drawingType
    
    if not self.available[poolKey] then
        self.available[poolKey] = {}
    end
    
    if self.inUse[poolKey] then
        for i, obj in ipairs(self.inUse[poolKey]) do
            if obj == drawing then
                table.remove(self.inUse[poolKey], i)
                break
            end
        end
    end
    
    if #self.available[poolKey] >= DEFAULT_SETTINGS.MaxCacheSize then
        if self.creationTimes[drawing] then
            self.creationTimes[drawing] = nil
        end
        drawing:Destroy()
    else
        table.insert(self.available[poolKey], drawing)
    end
end

function ESPObjectPool:ForceCleanup()
    self:Output("[ESP Periodic Cleanup] ForceCleanup begin!")
    local currentTime = tick()

    for poolKey, availableList in pairs(self.available) do
        if #availableList > DEFAULT_SETTINGS.MaxCacheSize then
            local priorityList = {}
            for i, drawing in ipairs(availableList) do
                local age = currentTime - (self.creationTimes[drawing] or 0)
                local priority = age

                table.insert(priorityList, {
                    drawing = drawing,
                    priority = priority,
                    index = i
                })
            end

            table.sort(priorityList, function(a, b) return a.priority > b.priority end)

            local toRemove = #availableList - DEFAULT_SETTINGS.MaxCacheSize
            for i = 1, math.min(toRemove, #priorityList) do
                local item = priorityList[i]
                local drawing = item.drawing

                self.creationTimes[drawing] = nil

                for j = #availableList, 1, -1 do
                    if availableList[j] == drawing then
                        table.remove(availableList, j)
                        break
                    end
                end

                drawing:Destroy()
            end
        end
    end

    self.lastCleanup = currentTime
end

function ESPObjectPool:PeriodicCleanup()
    local currentTime = tick()
    if currentTime - self.lastCleanup > DEFAULT_SETTINGS.CleanupInterval then
        self:Output("[ESP Periodic Cleanup] Starting scheduled cleanup...")
        self:ForceCleanup()
    end
end

function ESPLibrary.new(settings)
    local self = setmetatable({}, ESPLibrary)
    
    self.Settings = {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        self.Settings[key] = (settings and settings[key] ~= nil) and settings[key] or value
    end
    
    self.ESPObjects = {}
    self.UpdateConnection = nil
    self.CleanupConnection = nil
    self.PlayerRemovingConnection = nil
    self.IsRunning = false
    self.LastPlayerCount = 0
    self.FrameCounter = 0
    
    return self
end

function ESPLibrary:CreateESPObject(player)
    if player == LocalPlayer then return end
    
    local espObject = {
        Player = player,
        LODLevel = "HIGH",
        SquaredDistance = 0,
        Box = ESPObjectPool:GetDrawing("Square", {
            Thickness = self.Settings.BoxThickness,
            Color = self.Settings.BoxColor,
            Transparency = 1,
            Filled = false,
            ZIndex = 2
        }),
        BoxOutline = ESPObjectPool:GetDrawing("Square", {
            Thickness = self.Settings.BoxThickness + 2,
            Color = self.Settings.OutlineColor,
            Transparency = 1,
            Filled = false,
            ZIndex = 1
        }),
        HealthBar = ESPObjectPool:GetDrawing("Square", {
            Thickness = self.Settings.HealthBarlineThickness,
            Color = self.Settings.HealthBarColor,
            Transparency = 1,
            Filled = true,
            ZIndex = 2
        }),
        HealthBarOutline = ESPObjectPool:GetDrawing("Square", {
            Thickness = self.Settings.HealthBarOutlineThickness,
            Color = self.Settings.HealthBarOutlineColor,
            Filled = true,
            Transparency = 1,
            ZIndex = 1
        }),
        Nickname = ESPObjectPool:GetDrawing("Text", {
            Size = self.Settings.TextSize,
            Color = self.Settings.NicknameColor,
            Center = true,
            Outline = true,
            ZIndex = 3
        }),
        Skeleton = {},
        Chams = nil
    }
    
    if self.Settings.ChamsEnable then
        espObject.Chams = self:CreateChams(player)
    end
    
    return espObject
end

function ESPLibrary:CreateChams(player)
    if not self.Settings.ChamsEnable then return nil end

    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 10)
    if not hrp then return nil end

    local teamColor = self.Settings.ChamsColor or (player.TeamColor and player.TeamColor.Color) or Color3.new(1, 1, 1)
    local highlight = Instance.new("Highlight")
    highlight.FillColor = teamColor
    highlight.OutlineColor = self.Settings.ChamsOutlineColor or Color3.new(0, 0, 0)
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character

    return highlight
end

function ESPLibrary:GetHealthPercent(player, humanoid)
    -- Arsenal-specific health calculation
    if game.PlaceId == 286090429 then
        local success, result = pcall(function()
            local healthValue = player.NRPBS.Health.Value
            local maxHealthValue = player.NRPBS.MaxHealth.Value
            return healthValue / maxHealthValue
        end)
        return success and math.clamp(result, 0, 1) or 0
    end
    
    return math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
end

function ESPLibrary:CleanupSkeletonESP(espObject)
    for i = 1, #espObject.Skeleton do
        local line = espObject.Skeleton[i]
        if line then
            line.Visible = false
            line.Transparency = 0
            ESPObjectPool:ReturnDrawing("Line", line)
        end
    end
    
    espObject.Skeleton = {}
end

function ESPLibrary:UpdateSkeletonESP(espObject, character, isR15, lodFeatures)
    if not lodFeatures.skeleton then 
        if #espObject.Skeleton > 0 then
            self:CleanupSkeletonESP(espObject)
        end
        return 
    end
    
    local joints = JOINT_CONFIGS[isR15 and "R15" or "R6"]
    local maxParts = math.min(#joints, self.Settings.MaxSkeletonParts)
    
    for i = maxParts + 1, #espObject.Skeleton do
        if espObject.Skeleton[i] then
            espObject.Skeleton[i].Visible = false
            espObject.Skeleton[i].Transparency = 0
            ESPObjectPool:ReturnDrawing("Line", espObject.Skeleton[i])
            espObject.Skeleton[i] = nil
        end
    end
    
    for index = 1, maxParts do
        local joint = joints[index]
        if not joint then break end
        
        local partA = character:FindFirstChild(joint[1])
        local partB = character:FindFirstChild(joint[2])
        
        if partA and partB then
            local posA, onScreenA = WorldToViewportPoint(partA.Position)
            local posB, onScreenB = WorldToViewportPoint(partB.Position)
            
            if onScreenA and onScreenB then
                if not espObject.Skeleton[index] then
                    espObject.Skeleton[index] = ESPObjectPool:GetDrawing("Line", {
                        Thickness = self.Settings.LineThickness,
                        Color = self.Settings.SkeletonColor,
                        Transparency = 1,
                        Visible = false
                    })
                end
                
                local skeletonLine = espObject.Skeleton[index]
                skeletonLine.From = posA
                skeletonLine.To = posB
                skeletonLine.Color = self.Settings.SkeletonColor
                skeletonLine.Thickness = self.Settings.LineThickness
                skeletonLine.Transparency = 1
                skeletonLine.Visible = true       
            else
                if espObject.Skeleton[index] and espObject.Skeleton[index].Visible then
                    espObject.Skeleton[index].Visible = false
                end
            end
        else
            if espObject.Skeleton[index] and espObject.Skeleton[index].Visible then
                espObject.Skeleton[index].Visible = false
            end
        end
    end
end

function ESPLibrary:UpdatePlayerESP(player)
    local character = player.Character
    if not character then
        self:RemoveESP(player)
        return
    end
    
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local head = character:FindFirstChild("Head")
    
    if not rootPart or not humanoid or not head then
        self:RemoveESP(player)
        return
    end

    local squaredDistance = GetSquaredDistanceFromCamera(head.Position)
    local maxSquaredDistance = self.Settings.RenderDistance * self.Settings.RenderDistance
    
    if squaredDistance > maxSquaredDistance then
         self:RemoveESP(player)
         return 
    end
    
    if not self.ESPObjects[player] then
        self.ESPObjects[player] = self:CreateESPObject(player)
    end
    
    local espObject = self.ESPObjects[player]
    espObject.SquaredDistance = squaredDistance
    
    --// LOD System
    local lodLevel, lodName = nil, "OUT_OF_RANGE"
    if self.Settings.UseLOD then
        lodLevel, lodName = GetLODLevel(squaredDistance)
        if not lodLevel then
            self:RemoveESP(player)
            return
        end
        
        if PerformanceMetrics.adaptiveLOD then --// For really bad pc
            if lodName == "HIGH" then
                lodLevel = LOD_LEVELS.MEDIUM
                lodName = "MEDIUM (ADAPTIVE)"
            elseif lodName == "MEDIUM" then
                lodLevel = LOD_LEVELS.LOW
                lodName = "LOW (ADAPTIVE)"
            end
        end
        
        espObject.LODLevel = lodName
        espObject.UpdateRate = lodLevel.updateRate
    else --// Default
        lodLevel = LOD_LEVELS.HIGH
        lodName = "HIGH"
        espObject.UpdateRate = 1
    end
    
    if self.FrameCounter % espObject.UpdateRate ~= 0 then
        return
    end
    
    local rootScreenPos, onScreen = WorldToViewportPoint(rootPart.Position)
    
    if onScreen and self.Settings.Enabled then
        local headScreenPos = WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local rootBottomScreenPos = WorldToViewportPoint(rootPart.Position - Vector3.new(0, 3, 0))
        
        local boxHeight = math.abs(headScreenPos.Y - rootBottomScreenPos.Y)
        local boxWidth = boxHeight / 2
        local boxPosition = Vector2.new(rootScreenPos.X - boxWidth / 2, headScreenPos.Y)
        
        if self.Settings.BoxEnable and lodLevel.features.box then
            espObject.BoxOutline.Size = Vector2.new(boxWidth, boxHeight)
            espObject.BoxOutline.Position = boxPosition
            espObject.BoxOutline.Visible = true
            
            espObject.Box.Size = Vector2.new(boxWidth, boxHeight)
            espObject.Box.Position = boxPosition
            espObject.Box.Visible = true
        else
            espObject.Box.Visible = false
            espObject.BoxOutline.Visible = false
        end
        
        if self.Settings.HealthBar and lodLevel.features.healthBar then
            local healthPercent = self:GetHealthPercent(player, humanoid)
            local healthBarPosition = Vector2.new(rootScreenPos.X - boxWidth / 2 - 8, headScreenPos.Y)
            
            espObject.HealthBarOutline.Size = Vector2.new(5, boxHeight)
            espObject.HealthBarOutline.Position = healthBarPosition
            espObject.HealthBarOutline.Visible = true
            
            espObject.HealthBar.Size = Vector2.new(5, boxHeight * healthPercent)
            espObject.HealthBar.Position = Vector2.new(healthBarPosition.X, headScreenPos.Y + boxHeight * (1 - healthPercent))
            espObject.HealthBar.Color = Color3.fromHSV(healthPercent * 0.33, 1, 1)
            espObject.HealthBar.Visible = true
        else
            espObject.HealthBar.Visible = false
            espObject.HealthBarOutline.Visible = false
        end
        
        if self.Settings.Nickname and lodLevel.features.nickname then
            espObject.Nickname.Text = player.Name
            espObject.Nickname.Position = Vector2.new(rootScreenPos.X, headScreenPos.Y - 20)
            espObject.Nickname.Visible = true
        else
            espObject.Nickname.Visible = false
        end

        if espObject.Chams and self.Settings.ChamsEnable and lodLevel.features.chams then
            espObject.Chams.FillTransparency = 0.0
            espObject.Chams.OutlineTransparency = 0.0
        elseif espObject.Chams then
            espObject.Chams.FillTransparency = 1.0
            espObject.Chams.OutlineTransparency = 1.0
        end
        
        if self.Settings.Skeleton then
            local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
            self:UpdateSkeletonESP(espObject, character, isR15, lodLevel.features)
        end
        
        espObject.LastUpdate = tick()
    else
        self:HideESPElements(espObject)
    end
end

function ESPLibrary:HideESPElements(espObject)
    espObject.Box.Visible = false
    espObject.BoxOutline.Visible = false
    espObject.HealthBar.Visible = false
    espObject.HealthBarOutline.Visible = false
    espObject.Nickname.Visible = false
    
    for i = 1, #espObject.Skeleton do
        local line = espObject.Skeleton[i]
        if line then 
            line.Visible = false
            line.Transparency = 0
        end
    end
end

function ESPLibrary:RemoveESP(player)
    local espObject = self.ESPObjects[player]
    if not espObject then return end
    
    ESPObjectPool:ReturnDrawing("Square", espObject.Box)
    ESPObjectPool:ReturnDrawing("Square", espObject.BoxOutline)
    ESPObjectPool:ReturnDrawing("Square", espObject.HealthBar)
    ESPObjectPool:ReturnDrawing("Square", espObject.HealthBarOutline)
    ESPObjectPool:ReturnDrawing("Text", espObject.Nickname)
    
    for _, line in pairs(espObject.Skeleton) do
        if line then ESPObjectPool:ReturnDrawing("Line", line) end
    end
    
    if espObject.Chams then
        espObject.Chams:Destroy()
    end
    
    self.ESPObjects[player] = nil
end

function ESPLibrary:UpdateAllESP()
    UpdateCameraCache()
    UpdatePerformanceMetrics()
    
    self.FrameCounter += 1
    ESPObjectPool:PeriodicCleanup()
    local currentPlayerCount = #Players:GetPlayers()

    -- Force cleanup if player count changed significantly
   if math.abs(currentPlayerCount - self.LastPlayerCount) > 5 then
        ESPObjectPool:Output(string.format(
            "[ESP Player Count Change] Player count changed from %d to %d, triggering cleanup...",
            self.LastPlayerCount,
            currentPlayerCount
        ))
        ESPObjectPool:ForceCleanup()
        self.LastPlayerCount = currentPlayerCount
    end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            self:UpdatePlayerESP(player)
        else
            self:RemoveESP(player)
        end
    end
end

function ESPLibrary:Start()
    if self.IsRunning then return end    

    self.IsRunning = true    
    self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player) 
        self:RemoveESP(player) 
    end)
    
    self.UpdateConnection = RunService.Heartbeat:Connect(function() 
        self:UpdateAllESP() 
    end)
    
    self.CleanupConnection = RunService.Heartbeat:Connect(function()
        if tick() - ESPObjectPool.lastCleanup > 30 then 
            ESPObjectPool:ForceCleanup()
        end
    end)
end

function ESPLibrary:Stop()
    if not self.IsRunning then return end
    
    self.IsRunning = false
    
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
    
    if self.CleanupConnection then
        self.CleanupConnection:Disconnect()
        self.CleanupConnection = nil
    end
    
    if self.PlayerRemovingConnection then
        self.PlayerRemovingConnection:Disconnect()
        self.PlayerRemovingConnection = nil
    end
    
    for player, _ in pairs(self.ESPObjects) do
        self:RemoveESP(player)
    end
    
    ESPObjectPool:ForceCleanup()
end

function ESPLibrary:UpdateSettings(newSettings)
    for key, value in pairs(newSettings) do
        if self.Settings[key] ~= nil then
            self.Settings[key] = value
        end
    end
end

function ESPLibrary:ForceCleanup()
    ESPObjectPool:ForceCleanup()
end

return ESPLibrary