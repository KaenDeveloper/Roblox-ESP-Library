local ESPLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/KaenDeveloper/Roblox-ESP-Library/refs/heads/main/src/source.lua"))()

local ESP = ESPLibrary.new()
ESP:UpdateSettings({
    --//[Default Settings]\\--

    -- Features
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
    RenderDistance = 650
})
ESP:Start()

