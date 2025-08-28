local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Workspace = cloneref(game:GetService("Workspace"))

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = Workspace.CurrentCamera

local math_abs = math.abs
local math_clamp = math.clamp
local Vector2_new = Vector2.new
local Vector3_new = Vector3.new
local Color3_new = Color3.new
local Color3_fromRGB = Color3.fromRGB

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

local DEFAULT_SETTINGS = {
    Enabled = true,
    BoxEnable = true,
    ChamsEnable = true,
    HealthBar = true,
    Nickname = true,
    Skeleton = false,
    SkeletonCircles = false,
    
    -- Colors
    NicknameColor = Color3_new(1, 1, 1),
    SkeletonColor = Color3_new(1, 1, 1),
    BoxColor = Color3_new(1, 1, 1),
    ChamsColor = Color3_new(1, 1, 1),
    ChamsOutlineColor = Color3_new(1, 1, 1),
    OutlineColor = Color3_fromRGB(0, 0, 0),
    HealthBarColor = Color3_fromRGB(0, 255, 0),
    HealthBarOutlineColor = Color3_fromRGB(0, 0, 0),
    
    -- Dimensions
    BoxThickness = 2,
    LineThickness = 2,
    HealthBarlineThickness = 2,
    HealthBarOutlineThickness = 3,
    TextSize = 19,
    RenderDistance = 600
}

local ESPObjectPool = {
    available = {},
    inUse = {}
}

local function WorldToViewportPoint(position)
    local screenPosition, onScreen = CurrentCamera:WorldToViewportPoint(position)
    return Vector2_new(screenPosition.X, screenPosition.Y), onScreen
end

local function GetDistanceFromCamera(position)
    return (position - CurrentCamera.CFrame.Position).Magnitude
end

local function CreateDrawing(drawingType, properties)
    local drawing = Drawing.new(drawingType)
    for property, value in pairs(properties) do
        drawing[property] = value
    end
    return drawing
end

function ESPObjectPool:GetDrawing(drawingType, properties)
    local poolKey = drawingType
    if not self.available[poolKey] then
        self.available[poolKey] = {}
    end
    
    local drawing = table.remove(self.available[poolKey])
    if not drawing then
        drawing = CreateDrawing(drawingType, properties)
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
    
    table.insert(self.available[poolKey], drawing)
end


function ESPLibrary.new(settings)
    local self = setmetatable({}, ESPLibrary)
    
    self.Settings = {}
    for key, value in pairs(DEFAULT_SETTINGS) do
        self.Settings[key] = (settings and settings[key] ~= nil) and settings[key] or value
    end
    
    self.ESPObjects = {}
    self.UpdateConnection = nil
    self.IsRunning = false
    
    return self
end

function ESPLibrary:CreateESPObject(player)
    if player == LocalPlayer then return end
    
    local espObject = {
        Player = player,
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
        SkeletonCircles = {},
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
        return success and math_clamp(result, 0, 1) or 0
    end
    
    return math_clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
end

function ESPLibrary:UpdateSkeletonESP(espObject, character, isR15)
    local joints = JOINT_CONFIGS[isR15 and "R15" or "R6"]
    local fixedRadius = 1
    
    -- Clear existing skeleton elements that are no longer valid
    for i = #espObject.Skeleton, 1, -1 do
        if i > #joints then
            if espObject.Skeleton[i] then
                ESPObjectPool:ReturnDrawing("Line", espObject.Skeleton[i])
                espObject.Skeleton[i] = nil
            end
            if espObject.SkeletonCircles[i] then
                ESPObjectPool:ReturnDrawing("Circle", espObject.SkeletonCircles[i])
                espObject.SkeletonCircles[i] = nil
            end
        end
    end
    
    for index, joint in ipairs(joints) do
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
                    })
                end
                
                local skeletonLine = espObject.Skeleton[index]
                skeletonLine.From = posA
                skeletonLine.To = posB
                skeletonLine.Visible = true
                
                if self.Settings.SkeletonCircles then
                    local distance = GetDistanceFromCamera(partA.Position)
                    local adjustedRadius = fixedRadius * (CurrentCamera.FieldOfView / distance + 2)
                
                    if not espObject.SkeletonCircles[index] then
                        espObject.SkeletonCircles[index] = ESPObjectPool:GetDrawing("Circle", {
                            Radius = adjustedRadius,
                            Color = self.Settings.SkeletonColor,
                            Transparency = 1,
                            Filled = true,
                            ZIndex = 4
                        })
                    end
                
                    local skeletonCircle = espObject.SkeletonCircles[index]
                    skeletonCircle.Radius = adjustedRadius
                    skeletonCircle.Position = posA
                    skeletonCircle.Visible = true
                end
            else
                if espObject.Skeleton[index] then
                    espObject.Skeleton[index].Visible = false
                end
                if espObject.SkeletonCircles[index] then
                    espObject.SkeletonCircles[index].Visible = false
                end
            end
        else
            if espObject.Skeleton[index] then
                espObject.Skeleton[index].Visible = false
            end
            if espObject.SkeletonCircles[index] then
                espObject.SkeletonCircles[index].Visible = false
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

    local distance = GetDistanceFromCamera(head.Position)
    if distance > self.Settings.RenderDistance then
         self:RemoveESP(player)
         return 
    end
    
    if not self.ESPObjects[player] then
        self.ESPObjects[player] = self:CreateESPObject(player)
    end
    
    local espObject = self.ESPObjects[player]
    local rootScreenPos, onScreen = WorldToViewportPoint(rootPart.Position)
    
    if onScreen and self.Settings.Enabled then
        local headScreenPos = WorldToViewportPoint(head.Position + Vector3_new(0, 0.5, 0))
        local rootBottomScreenPos = WorldToViewportPoint(rootPart.Position - Vector3_new(0, 3, 0))
        
        local boxHeight = math_abs(headScreenPos.Y - rootBottomScreenPos.Y)
        local boxWidth = boxHeight / 2
        local boxPosition = Vector2_new(rootScreenPos.X - boxWidth / 2, headScreenPos.Y)
        
        if self.Settings.BoxEnable then
            espObject.BoxOutline.Size = Vector2_new(boxWidth, boxHeight)
            espObject.BoxOutline.Position = boxPosition
            espObject.BoxOutline.Visible = true
            
            espObject.Box.Size = Vector2_new(boxWidth, boxHeight)
            espObject.Box.Position = boxPosition
            espObject.Box.Visible = true
        else
            espObject.Box.Visible = false
            espObject.BoxOutline.Visible = false
        end
        
        if self.Settings.HealthBar then
            local healthPercent = self:GetHealthPercent(player, humanoid)
            local healthBarPosition = Vector2_new(rootScreenPos.X - boxWidth / 2 - 8, headScreenPos.Y)
            
            espObject.HealthBarOutline.Size = Vector2_new(5, boxHeight)
            espObject.HealthBarOutline.Position = healthBarPosition
            espObject.HealthBarOutline.Visible = true
            
            espObject.HealthBar.Size = Vector2_new(5, boxHeight * healthPercent)
            espObject.HealthBar.Position = Vector2_new(healthBarPosition.X, headScreenPos.Y + boxHeight * (1 - healthPercent))
            espObject.HealthBar.Color = Color3_fromRGB((1 - healthPercent) * 255, healthPercent * 255, 0)
            espObject.HealthBar.Visible = true
        else
            espObject.HealthBar.Visible = false
            espObject.HealthBarOutline.Visible = false
        end
        
        if self.Settings.Nickname then
            espObject.Nickname.Text = player.Name
            espObject.Nickname.Position = Vector2_new(rootScreenPos.X, headScreenPos.Y - 20)
            espObject.Nickname.Visible = true
        else
            espObject.Nickname.Visible = false
        end
        
        if espObject.Chams and self.Settings.ChamsEnable then
            espObject.Chams.FillTransparency = 0.0
            espObject.Chams.OutlineTransparency = 0.0
        elseif espObject.Chams then
            espObject.Chams.FillTransparency = 1.0
            espObject.Chams.OutlineTransparency = 1.0
        end
        
        if self.Settings.Skeleton then
            local isR15 = humanoid.RigType == Enum.HumanoidRigType.R15
            self:UpdateSkeletonESP(espObject, character, isR15)
        end
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
    
    for _, line in pairs(espObject.Skeleton) do
        if line then line.Visible = false end
    end
    
    for _, circle in pairs(espObject.SkeletonCircles) do
        if circle then circle.Visible = false end
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
    
    for _, circle in pairs(espObject.SkeletonCircles) do
        if circle then ESPObjectPool:ReturnDrawing("Circle", circle) end
    end
    
    if espObject.Chams then
        espObject.Chams:Destroy()
    end
    
    self.ESPObjects[player] = nil
end

function ESPLibrary:UpdateAllESP()
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
    self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(player) self:RemoveESP(player) end)
    self.UpdateConnection = RunService.Heartbeat:Connect(function() self:UpdateAllESP() end)
end

function ESPLibrary:Stop()
    if not self.IsRunning then return end
    
    self.IsRunning = false
    
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end
    
    if self.PlayerRemovingConnection then
        self.PlayerRemovingConnection:Disconnect()
        self.PlayerRemovingConnection = nil
    end
    
    for player, _ in pairs(self.ESPObjects) do
        self:RemoveESP(player)
    end
end

function ESPLibrary:UpdateSettings(newSettings)
    for key, value in pairs(newSettings) do
        if self.Settings[key] ~= nil then
            self.Settings[key] = value
        end
    end
end

return ESPLibrary


