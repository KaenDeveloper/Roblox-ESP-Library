# Roblox ESP Library

This repository contains a custom ESP (Extra Sensory Perception) library for Roblox.  
The library provides optimized and customizable ESP features such as boxes, health bars, nicknames, skeletons, and chams.  
It is designed with performance in mind and uses an object pooling system for efficient rendering.

## Installation & Usage
To load the library, simply execute the following code inside your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/KaenDeveloper/Roblox-ESP-Library/refs/heads/main/example/example.lua"))()
```
---

## Features
- Box ESP – draws boxes around players
- Health Bar – displays player health status
- Nickname – shows player usernames above their character
- Skeleton – draws character skeletons (optional)
- Skeleton Circles – optional joint circles
- Chams – highlights characters through objects
- Optimized Drawing Pool – reduces unnecessary Drawing object creation
- Fully Configurable – customize colors, thickness, text size, and render distance

## Configuration
```lua
ESP:UpdateSettings({
    -- Features
    BoxEnable = true,
    HealthBar = true,
    Nickname = true,
    Skeleton = true,
    SkeletonCircles = false,
    ChamsEnable = true,
    
    -- Colors
    NicknameColor = Color3.new(1, 1, 1),
    SkeletonColor = Color3.new(1, 1, 1),
    BoxColor = Color3.new(1, 1, 1),
    ChamsColor = Color3.new(0.207843, 0.392157, 0.501961),
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
```
All settings can be found and modified in example.lua.

## Preview
![Preview](https://raw.githubusercontent.com/KaenDeveloper/Roblox-ESP-Library/main/example/preview.png)

## License

This project is licensed under the MIT License.
You are free to use, modify, and distribute this code as long as the original license notice is included.
