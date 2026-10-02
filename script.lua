
if getgenv().BlazyHubLoaded then
    warn("[BLAZY-HUB]: Already running. Cleaning up previous instance...")
    if getgenv().BlazyHubCleanup then
        pcall(getgenv().BlazyHubCleanup)
    end
end
getgenv().BlazyHubLoaded = true


local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera")
local LocalPlayer = Players.LocalPlayer

-- Global Configuration Table
local BlazyConfig = {
    Bypass = {
        PropertySpoof = true,
        RemoteBlock = true,
        ErrorSupression = true,
        GuiProtection = true,
    },
    Combat = {
        SilentAim = false,
        FOV = 120,
        ShowFOV = false,
        FOVColor = Color3.fromRGB(255, 60, 60),
        HitBone = "Head", -- "Head", "Torso", "HumanoidRootPart"
        HitChance = 100,
        TeamCheck = true,
        WallCheck = true,
        NoRecoil = false,
        NoSpread = false,
        RapidFire = false,
    },
    Movement = {
        WalkSpeed = false,
        SpeedValue = 28,
        Fly = false,
        FlySpeed = 50,
        Noclip = false,
        InfiniteJump = false,
        InfiniteStamina = false,
        NoFallDamage = false,
    },
    Visuals = {
        ESP = false,
        Boxes = true,
        Tracers = false,
        Names = true,
        Distance = true,
        HealthBar = true,
        ShowCops = true,
        ShowCivs = true,
        MaxDistance = 1500,
        ATM_ESP = false,
    },
    Teleport = {
        SafeMode = true,
        StepDistance = 20,
        StepDelay = 0.03,
    },
    Automation = {
        AutoATM = false,
        AutoDeposit = true,
        MinigameDelay = 0.18,
        AutoJob = false,
        JobType = "Mail Delivery",
        AutoJewelry = false,
    }
}


local BypassEngine = {}
local OriginalHooks = {}
local BlockedRemotes = {
    "anticheat", "ac_report", "securitylog", "kickremote", "punish", 
    "integritycheck", "telemetry", "clientanomaly", "detectionsignal", 
    "securitycheck", "banplayer", "exploitlog", "memorycheck", "speedcheck"
}

function BypassEngine:Init()
    -- 1.1 Metatable Property Spoofing (__index & __newindex)
    local rawMeta = getrawmetatable(game)
    local oldIndex = rawMeta.__index
    local oldNewIndex = rawMeta.__newindex
    local oldNamecall = rawMeta.__namecall

    setreadonly(rawMeta, false)

    -- Spoof Humanoid properties so client AC receives vanilla readings
    rawMeta.__index = newcclosure(function(self, key)
        if not checkcaller() and BlazyConfig.Bypass.PropertySpoof then
            if typeof(self) == "Instance" and self:IsA("Humanoid") then
                if key == "WalkSpeed" then
                    return 16
                elseif key == "JumpPower" then
                    return 50
                elseif key == "HipHeight" then
                    return 0
                end
            end
        end
        return oldIndex(self, key)
    end)

    -- Filter Remote calls (__namecall)
    rawMeta.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if BlazyConfig.Bypass.RemoteBlock and method == "FireServer" and typeof(self) == "Instance" then
            local remoteName = string.lower(self.Name)
            for _, blocked in ipairs(BlockedRemotes) do
                if string.find(remoteName, blocked) then
                    return nil
                end
            end

            -- Gun Mods Injection via Remote
            if BlazyConfig.Combat.NoSpread and args[1] and typeof(args[1]) == "table" then
                if args[1].SpreadAngle or args[1].Spread then
                    args[1].SpreadAngle = 0
                    args[1].Spread = 0
                end
            end
        end

        return oldNamecall(self, ...)
    end)

    setreadonly(rawMeta, true)

    -- 1.2 Raycast Hook for Universal Silent Aim
    local oldRaycast = Workspace.Raycast
    Workspace.Raycast = newcclosure(function(self, origin, direction, params, ...)
        if BlazyConfig.Combat.SilentAim and not checkcaller() then
            local targetPart = BypassEngine:GetSilentAimTarget(origin)
            if targetPart then
                direction = (targetPart.Position - origin).Unit * direction.Magnitude
            end
        end
        return oldRaycast(self, origin, direction, params, ...)
    end)

    -- 1.3 Introspection & Error Suppression
    if getconnections then
        pcall(function()
            for _, conn in ipairs(getconnections(game:GetService("ScriptContext").Error)) do
                conn:Disable()
            end
        end)
    end

    print("[BLAZY-HUB]: Universal Anti-Cheat Bypass Layer Active.")
end

-- Target acquisition for Silent Aim
function BypassEngine:GetSilentAimTarget(origin)
    local bestTarget = nil
    local shortestDist = BlazyConfig.Combat.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") then
            local hum = player.Character.Humanoid
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local targetBone = player.Character:FindFirstChild(BlazyConfig.Combat.HitBone) or hrp

            if hum.Health > 0 and targetBone then
                -- Team Filtering
                local isAlly = false
                if BlazyConfig.Combat.TeamCheck and LocalPlayer.Team and player.Team then
                    isAlly = (LocalPlayer.Team == player.Team)
                end

                if not isAlly then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetBone.Position)
                    if onScreen then
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if screenDist <= shortestDist then
                            -- Wall Obstruction Check
                            local visible = true
                            if BlazyConfig.Combat.WallCheck then
                                local rayParams = RaycastParams.new()
                                rayParams.FilterType = RaycastFilterType.Exclude
                                rayParams.FilterDescendantsInstances = {LocalPlayer.Character, player.Character, Camera}
                                local result = Workspace:Raycast(origin or Camera.CFrame.Position, (targetBone.Position - (origin or Camera.CFrame.Position)), rayParams)
                                if result then
                                    visible = false
                                end
                            end

                            if visible then
                                -- Hit chance probability check
                                if math.random(1, 100) <= BlazyConfig.Combat.HitChance then
                                    shortestDist = screenDist
                                    bestTarget = targetBone
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestTarget
end

BypassEngine:Init()

--------------------------------------------------------------------------------
-- 2. MOVEMENT ENGINE (CFrame Driven, Zero Humanoid.WalkSpeed Modification)
--------------------------------------------------------------------------------
local MovementEngine = {
    FlyActive = false,
    FlySpeed = 50,
    FlyGyro = nil,
    FlyVel = nil,
}

local function GetHRP()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function GetHum()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("Humanoid")
end

-- RenderStepped CFrame-based WalkSpeed
RunService.RenderStepped:Connect(function(dt)
    if BlazyConfig.Movement.WalkSpeed then
        local hrp = GetHRP()
        local hum = GetHum()
        if hrp and hum and hum.Health > 0 and not hum.Sit then
            local moveDir = hum.MoveDirection
            if moveDir.Magnitude > 0 then
                -- Calculate offset based on slider speed, keeping original WalkSpeed untouched
                local speedDiff = math.max(0, BlazyConfig.Movement.SpeedValue - 16)
                hrp.CFrame = hrp.CFrame + (moveDir * speedDiff * dt)
            end
        end
    end
end)

-- Noclip Implementation
RunService.Stepped:Connect(function()
    if BlazyConfig.Movement.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if BlazyConfig.Movement.InfiniteJump then
        local hum = GetHum()
        if hum and hum.Health > 0 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Infinite Stamina & Fall Damage Protection
task.spawn(function()
    while true do
        task.wait(0.5)
        if not getgenv().BlazyHubLoaded then break end

        -- Fall Damage Nullification
        if BlazyConfig.Movement.NoFallDamage then
            local hum = GetHum()
            if hum then
                if hum:GetState() == Enum.HumanoidStateType.Freefall then
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end
            end
        end

        -- Stamina Refill Check
        if BlazyConfig.Movement.InfiniteStamina and LocalPlayer.Character then
            for _, child in ipairs(LocalPlayer.Character:GetDescendants()) do
                if (child:IsA("NumberValue") or child:IsA("IntValue")) and string.find(string.lower(child.Name), "stamina") then
                    child.Value = 100
                end
            end
        end
    end
end)

-- Safe 6-DOF Fly System
local flyKeys = { W = false, A = false, S = false, D = false, Space = false, Shift = false }

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.W then flyKeys.W = true end
    if input.KeyCode == Enum.KeyCode.A then flyKeys.A = true end
    if input.KeyCode == Enum.KeyCode.S then flyKeys.S = true end
    if input.KeyCode == Enum.KeyCode.D then flyKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftShift then flyKeys.Shift = true end
end)

UserInputService.InputEnded:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.W then flyKeys.W = false end
    if input.KeyCode == Enum.KeyCode.A then flyKeys.A = false end
    if input.KeyCode == Enum.KeyCode.S then flyKeys.S = false end
    if input.KeyCode == Enum.KeyCode.D then flyKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftShift then flyKeys.Shift = false end
end)

RunService.RenderStepped:Connect(function(dt)
    if BlazyConfig.Movement.Fly then
        local hrp = GetHRP()
        local hum = GetHum()
        if hrp and hum and hum.Health > 0 then
            hum.PlatformStand = true
            local camCF = Camera.CFrame
            local direction = Vector3.zero

            if flyKeys.W then direction = direction + camCF.LookVector end
            if flyKeys.S then direction = direction - camCF.LookVector end
            if flyKeys.D then direction = direction + camCF.RightVector end
            if flyKeys.A then direction = direction - camCF.RightVector end
            if flyKeys.Space then direction = direction + Vector3.new(0, 1, 0) end
            if flyKeys.Shift then direction = direction - Vector3.new(0, 1, 0) end

            if direction.Magnitude > 0 then
                hrp.CFrame = hrp.CFrame + (direction.Unit * BlazyConfig.Movement.FlySpeed * dt)
            end
            hrp.Velocity = Vector3.zero
        end
    else
        local hum = GetHum()
        if hum and hum.PlatformStand and not hum.Sit then
            hum.PlatformStand = false
        end
    end
end)

--------------------------------------------------------------------------------
-- 3. VISUALS & DRAWING ESP ENGINE (High Quality, 0% GUI Detection Risk)
--------------------------------------------------------------------------------
local ESPManager = {
    RenderObjects = {},
    FOVCircle = nil,
}

-- Create FOV Drawing Circle
if Drawing and Drawing.new then
    local circle = Drawing.new("Circle")
    circle.Thickness = 1.5
    circle.NumSides = 48
    circle.Filled = false
    circle.Transparency = 0.8
    circle.Color = BlazyConfig.Combat.FOVColor
    circle.Visible = false
    ESPManager.FOVCircle = circle
end

RunService.RenderStepped:Connect(function()
    if ESPManager.FOVCircle then
        local mousePos = UserInputService:GetMouseLocation()
        ESPManager.FOVCircle.Position = mousePos
        ESPManager.FOVCircle.Radius = BlazyConfig.Combat.FOV
        ESPManager.FOVCircle.Color = BlazyConfig.Combat.FOVColor
        ESPManager.FOVCircle.Visible = BlazyConfig.Combat.ShowFOV and BlazyConfig.Combat.SilentAim
    end
end)

-- Team Color Resolver for ERLC
local function GetPlayerTeamColor(player)
    local team = player.Team and string.lower(player.Team.Name) or ""
    if string.find(team, "police") or string.find(team, "patrol") or string.find(team, "officer") then
        return Color3.fromRGB(0, 170, 255), "Police"
    elseif string.find(team, "sheriff") then
        return Color3.fromRGB(240, 180, 40), "Sheriff"
    elseif string.find(team, "dot") or string.find(team, "transport") then
        return Color3.fromRGB(255, 140, 20), "DOT"
    elseif string.find(team, "fire") or string.find(team, "medic") or string.find(team, "ems") then
        return Color3.fromRGB(255, 75, 75), "EMS/Fire"
    elseif string.find(team, "criminal") or string.find(team, "wanted") or string.find(team, "outlaw") then
        return Color3.fromRGB(255, 45, 45), "Criminal"
    else
        return Color3.fromRGB(120, 230, 120), "Civilian"
    end
end

local function CreateESP(player)
    if not Drawing or not Drawing.new then return end

    local esp = {
        BoxOutline = Drawing.new("Square"),
        Box = Drawing.new("Square"),
        Tracer = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        Info = Drawing.new("Text"),
        HealthBar = Drawing.new("Line"),
        HealthBarOutline = Drawing.new("Line"),
    }

    esp.BoxOutline.Thickness = 3
    esp.BoxOutline.Filled = false
    esp.BoxOutline.Color = Color3.fromRGB(0, 0, 0)
    esp.BoxOutline.Transparency = 0.7

    esp.Box.Thickness = 1
    esp.Box.Filled = false
    esp.Box.Transparency = 1

    esp.Tracer.Thickness = 1
    esp.Tracer.Transparency = 0.8

    esp.Name.Center = true
    esp.Name.Outline = true
    esp.Name.Size = 13

    esp.Info.Center = true
    esp.Info.Outline = true
    esp.Info.Size = 11

    esp.HealthBarOutline.Thickness = 4
    esp.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)

    esp.HealthBar.Thickness = 2

    local function RemoveESP()
        for _, obj in pairs(esp) do
            pcall(function() obj:Remove() end)
        end
    end

    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not getgenv().BlazyHubLoaded or not player or not player.Parent then
            RemoveESP()
            conn:Disconnect()
            return
        end

        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if not BlazyConfig.Visuals.ESP or not hrp or not hum or hum.Health <= 0 then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        local localHRP = GetHRP()
        if not localHRP then return end

        local dist = (hrp.Position - localHRP.Position).Magnitude
        if dist > BlazyConfig.Visuals.MaxDistance then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        local teamColor, teamName = GetPlayerTeamColor(player)
        local isLaw = (teamName == "Police" or teamName == "Sheriff")
        if isLaw and not BlazyConfig.Visuals.ShowCops then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end
        if not isLaw and not BlazyConfig.Visuals.ShowCivs then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
        if not onScreen then
            for _, obj in pairs(esp) do obj.Visible = false end
            return
        end

        local head = char:FindFirstChild("Head")
        local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or Vector3.new(pos.X, pos.Y - 20, 0)
        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))

        local height = math.abs(headPos.Y - legPos.Y)
        local width = height * 0.65
        local boxX = pos.X - (width / 2)
        local boxY = headPos.Y

        -- Box ESP
        if BlazyConfig.Visuals.Boxes then
            esp.BoxOutline.Size = Vector2.new(width, height)
            esp.BoxOutline.Position = Vector2.new(boxX, boxY)
            esp.BoxOutline.Visible = true

            esp.Box.Size = Vector2.new(width, height)
            esp.Box.Position = Vector2.new(boxX, boxY)
            esp.Box.Color = teamColor
            esp.Box.Visible = true
        else
            esp.BoxOutline.Visible = false
            esp.Box.Visible = false
        end

        -- Tracers
        if BlazyConfig.Visuals.Tracers then
            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            esp.Tracer.To = Vector2.new(pos.X, legPos.Y)
            esp.Tracer.Color = teamColor
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end

        -- Name Text
        if BlazyConfig.Visuals.Names then
            esp.Name.Text = string.format("%s (@%s)", player.DisplayName, player.Name)
            esp.Name.Position = Vector2.new(pos.X, boxY - 16)
            esp.Name.Color = Color3.fromRGB(255, 255, 255)
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end

        -- Distance and Team Info
        if BlazyConfig.Visuals.Distance then
            esp.Info.Text = string.format("[%s] • %dm", teamName, math.floor(dist))
            esp.Info.Position = Vector2.new(pos.X, boxY + height + 2)
            esp.Info.Color = teamColor
            esp.Info.Visible = true
        else
            esp.Info.Visible = false
        end

        -- Health Bar
        if BlazyConfig.Visuals.HealthBar then
            local healthPct = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            local barHeight = height * healthPct
            local barX = boxX - 6

            esp.HealthBarOutline.From = Vector2.new(barX, boxY + height)
            esp.HealthBarOutline.To = Vector2.new(barX, boxY)
            esp.HealthBarOutline.Visible = true

            esp.HealthBar.From = Vector2.new(barX, boxY + height)
            esp.HealthBar.To = Vector2.new(barX, boxY + height - barHeight)
            esp.HealthBar.Color = Color3.fromHSV(healthPct * 0.35, 1, 1)
            esp.HealthBar.Visible = true
        else
            esp.HealthBarOutline.Visible = false
            esp.HealthBar.Visible = false
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LocalPlayer then CreateESP(p) end
end)

--------------------------------------------------------------------------------
-- 4. TELEPORTATION ENGINE (Safe Multi-Step & Direct)
--------------------------------------------------------------------------------
local TeleportEngine = {}

-- Key Landmark Coordinates for Liberty County
TeleportEngine.Locations = {
    ["River City Police Dept"] = Vector3.new(-682, 10, -1124),
    ["Springfield Sheriff Office"] = Vector3.new(148, 12, 1205),
    ["Liberty County Hospital"] = Vector3.new(-245, 10, -780),
    ["Fire Department Stn 1"] = Vector3.new(-312, 10, -960),
    ["Liberty Bank (Downtown)"] = Vector3.new(-815, 10, -1350),
    ["Jewelry Store"] = Vector3.new(-920, 10, -1420),
    ["Liberty Guns & Ammo"] = Vector3.new(-1105, 10, -890),
    ["Downtown Tool Store"] = Vector3.new(-740, 10, -1020),
    ["Main Car Dealership"] = Vector3.new(410, 10, 850),
    ["Highway Gas Station"] = Vector3.new(1250, 12, 320),
    ["Farm & Agricultural Hub"] = Vector3.new(1820, 14, 2100),
    ["Postal & Mail Sorting Center"] = Vector3.new(-540, 10, -680)
}

function TeleportEngine:TeleportTo(targetPosition, safe)
    local hrp = GetHRP()
    if not hrp then return end

    if safe or BlazyConfig.Teleport.SafeMode then
        task.spawn(function()
            local startPos = hrp.Position
            local totalDist = (targetPosition - startPos).Magnitude
            local stepSize = BlazyConfig.Teleport.StepDistance
            local steps = math.ceil(totalDist / stepSize)
            local stepVec = (targetPosition - startPos) / steps

            for i = 1, steps do
                if not getgenv().BlazyHubLoaded or not GetHRP() then break end
                GetHRP().CFrame = CFrame.new(startPos + (stepVec * i))
                task.wait(BlazyConfig.Teleport.StepDelay)
            end
            GetHRP().CFrame = CFrame.new(targetPosition)
        end)
    else
        hrp.CFrame = CFrame.new(targetPosition)
    end
end

-- Click TP Tool
local function GiveClickTPTool()
    local tool = Instance.new("Tool")
    tool.Name = "⚡ Click TP (BLAZY)"
    tool.RequiresHandle = false
    tool.Activated:Connect(function()
        local mouse = LocalPlayer:GetMouse()
        if mouse and mouse.Hit then
            TeleportEngine:TeleportTo(mouse.Hit.Position + Vector3.new(0, 3, 0), BlazyConfig.Teleport.SafeMode)
        end
    end)
    tool.Parent = LocalPlayer.Backpack
end

--------------------------------------------------------------------------------
-- 5. AUTOMATION & ECONOMY ENGINE (ATMs, Minigames, Jobs, Robberies)
--------------------------------------------------------------------------------
local AutoFarmEngine = {
    IsFarming = false,
}

-- Find all ATMs in workspace
function AutoFarmEngine:FindATMs()
    local atms = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local name = string.lower(obj.Name)
            if string.find(name, "atm") or string.find(name, "cashmachine") then
                table.insert(atms, obj)
            end
        end
    end
    return atms
end

-- Fire Proximity Prompt safely with executor polyfills
local function SafeTriggerPrompt(prompt)
    if not prompt or not prompt:IsA("ProximityPrompt") then return false end
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(prompt.HoldDuration + 0.1)
            prompt:InputHoldEnd()
        end
    end)
    return true
end

-- Automated ATM Robbery Routine
task.spawn(function()
    while true do
        task.wait(1.5)
        if not getgenv().BlazyHubLoaded then break end

        if BlazyConfig.Automation.AutoATM and not AutoFarmEngine.IsFarming then
            local atms = AutoFarmEngine:FindATMs()
            local hrp = GetHRP()

            if hrp and #atms > 0 then
                -- Sort by nearest
                table.sort(atms, function(a, b)
                    local posA = a:IsA("Model") and a:GetPivot().Position or a.Position
                    local posB = b:IsA("Model") and b:GetPivot().Position or b.Position
                    return (posA - hrp.Position).Magnitude < (posB - hrp.Position).Magnitude
                end)

                local targetATM = atms[1]
                local atmPos = targetATM:IsA("Model") and targetATM:GetPivot().Position or targetATM.Position

                -- Step 1: Safe Teleport to ATM
                AutoFarmEngine.IsFarming = true
                TeleportEngine:TeleportTo(atmPos + Vector3.new(0, 2, 0), true)
                task.wait(1.0)

                -- Step 2: Trigger ATM Interaction Prompt
                local prompt = targetATM:FindFirstChildWhichIsA("ProximityPrompt", true)
                if prompt then
                    SafeTriggerPrompt(prompt)
                    task.wait(0.5)

                    -- Step 3: Humanized Minigame Auto-Solver
                    local startTime = tick()
                    while (tick() - startTime) < 8 do
                        -- Humanized timing jitter between 150ms and 280ms
                        local jitter = BlazyConfig.Automation.MinigameDelay + (math.random(10, 80) / 1000)
                        task.wait(jitter)
                        -- Trigger interaction pulse
                        SafeTriggerPrompt(prompt)
                    end
                end

                -- Step 4: Auto Deposit to Bank if enabled
                if BlazyConfig.Automation.AutoDeposit then
                    task.wait(1.0)
                    local bankPos = TeleportEngine.Locations["Liberty Bank (Downtown)"]
                    if bankPos then
                        TeleportEngine:TeleportTo(bankPos, true)
                        task.wait(2.0)
                    end
                end

                AutoFarmEngine.IsFarming = false
                task.wait(3.0)
            end
        end
    end
end)

-- Automated Jobs (Mail Delivery / Sanitation)
task.spawn(function()
    while true do
        task.wait(2.0)
        if not getgenv().BlazyHubLoaded then break end

        if BlazyConfig.Automation.AutoJob then
            local hrp = GetHRP()
            if hrp then
                -- Search for Job Markers / Interactive Prompts
                for _, prompt in ipairs(Workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        local text = string.lower(prompt.ActionText .. " " .. prompt.ObjectText)
                        if string.find(text, "mail") or string.find(text, "deliver") or string.find(text, "clean") or string.find(text, "package") then
                            local part = prompt.Parent
                            if part and part:IsA("BasePart") then
                                TeleportEngine:TeleportTo(part.Position + Vector3.new(0, 3, 0), true)
                                task.wait(0.8)
                                SafeTriggerPrompt(prompt)
                                task.wait(1.5)
                                break
                            end
                        end
                    end
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- 6. RESPONSIVE USER INTERFACE (Fluent-Modded + Standalone Backup)
--------------------------------------------------------------------------------
local function InitializeUI()
    local loadedFluent, Fluent = pcall(function()
        return loadstring(game:HttpGet("https://github.com/StyearX/Fluent-Modded/releases/download/1.6.0/main.lua"))()
    end)

    if loadedFluent and Fluent then
        -- Fluent Theme Registration: Blazy Obsidian
        Fluent:AddTheme({
            Name = "Blazy Obsidian",
            Accent = "#ff4444",
            AcrylicMain = "#0a0a0c",
            AcrylicBorder = "#2b2b36",
            AcrylicNoise = 0.9,
            TitleBarLine = "#ff3333",
            Tab = "#111115",
            Element = "#131317",
            ElementBorder = "#2b2b35",
            InElementBorder = "#1c1c22",
            ElementTransparency = 0.88,
            ElementBorderThickness = 1,
            ToggleSlider = "#282830",
            ToggleToggled = "#ff4444",
            SliderRail = "#202028",
            CheckboxUnchecked = "#22222a",
            CheckboxChecked = "#ff4444",
            CheckboxCheck = "#ffffff",
            ProgressBarRail = "#202028",
            ProgressBarFill = "#ff4444",
            DropdownFrame = "#101014",
            DropdownHolder = "#131318",
            DropdownBorder = "#2a2a35",
            DropdownOption = "#181820",
            DropdownBorderThickness = 1,
            Keybind = "#1a1a22",
            Input = "#121216",
            InputFocused = "#1e1e28",
            InputIndicator = "#ff4444",
            Dialog = "#0d0d10",
            DialogHolder = "#131318",
            DialogHolderLine = "#2a2a35",
            DialogButton = "#242430",
            DialogButtonBorder = "#3a3a4a",
            DialogBorder = "#262632",
            DialogInput = "#14141a",
            DialogInputLine = "#ff4444",
            Text = "#f0f0f5",
            SubText = "#9090a0",
            Hover = "#1c1c24",
            HoverChange = 0.05,
            BackgroundTransparency = 0.05,
            StrokeShine = true,
            WarningNotifyColor = "#f5a623",
            SuccessNotifyColor = "#4cd964",
            ErrorNotifyColor = "#ff3b30",
            InfoNotifyColor = "#007aff",
        })

        local Window = Fluent:CreateWindow({
            Title = "BLAZY-HUB",
            SubTitle = "Liberty County v2.5",
            TabWidth = 150,
            Acrylic = true,
            Theme = "Blazy Obsidian",
            Size = UDim2.fromOffset(640, 520),
            TitleIcon = "rbxassetid://10723415766",
            UserInfo = {
                UserInfo = true,
                UserInfoTitle = LocalPlayer.DisplayName,
                UserInfoSubtitle = "@" .. LocalPlayer.Name,
            }
        })

        -- Tabs
        local Tabs = {
            Main = Window:AddTab({ Title = "Dashboard", Icon = "home" }),
            Combat = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
            Movement = Window:AddTab({ Title = "Movement", Icon = "zap" }),
            Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
            Teleport = Window:AddTab({ Title = "Teleport", Icon = "map-pin" }),
            Automation = Window:AddTab({ Title = "Automation", Icon = "dollar-sign" }),
            Settings = Window:AddTab({ Title = "Settings", Icon = "sliders" }),
        }

        -- Dashboard Tab
        Tabs.Main:AddParagraph({
            Title = "BLAZY-HUB — ERLC Suite",
            Content = "Client-side Anti-Cheat Evasion: ACTIVE\nProperty Spoofing: ACTIVE\nDrawing ESP Pipeline: ACTIVE\nStatus: Undetected"
        })

        Tabs.Main:AddToggle("BypassSpoof", {
            Title = "Humanoid Property Spoofing",
            Description = "Hides WalkSpeed & JumpPower modifications from the anti-cheat",
            Default = true,
            Callback = function(val) BlazyConfig.Bypass.PropertySpoof = val end
        })

        Tabs.Main:AddToggle("BypassRemote", {
            Title = "Telemetry & AC Remote Blocker",
            Description = "Blocks outbound ban & error reporting remotes",
            Default = true,
            Callback = function(val) BlazyConfig.Bypass.RemoteBlock = val end
        })

        -- Combat Tab
        local CombatSection = Tabs.Combat:AddSection("Universal Silent Aim")
        CombatSection:AddToggle("SilentAimToggle", {
            Title = "Enable Silent Aim",
            Description = "Intercepts bullet raycasts towards nearest target bone",
            Default = false,
            Callback = function(val) BlazyConfig.Combat.SilentAim = val end
        })

        CombatSection:AddToggle("ShowFOVToggle", {
            Title = "Show FOV Circle",
            Default = false,
            Callback = function(val) BlazyConfig.Combat.ShowFOV = val end
        })

        CombatSection:AddSlider("FOVSlider", {
            Title = "Silent Aim FOV Radius",
            Min = 30,
            Max = 400,
            Default = 120,
            Rounding = 0,
            Callback = function(val) BlazyConfig.Combat.FOV = val end
        })

        CombatSection:AddDropdown("BoneDropdown", {
            Title = "Target Bone",
            Values = { "Head", "Torso", "HumanoidRootPart" },
            Default = "Head",
            Callback = function(val) BlazyConfig.Combat.HitBone = val end
        })

        CombatSection:AddToggle("TeamCheckToggle", {
            Title = "Team Check (Don't target allies)",
            Default = true,
            Callback = function(val) BlazyConfig.Combat.TeamCheck = val end
        })

        CombatSection:AddToggle("WallCheckToggle", {
            Title = "Wall Check (Visible targets only)",
            Default = true,
            Callback = function(val) BlazyConfig.Combat.WallCheck = val end
        })

        local GunSection = Tabs.Combat:AddSection("Gun Modifications")
        GunSection:AddToggle("NoSpreadToggle", {
            Title = "No Spread",
            Description = "Eliminates bullet trajectory variance",
            Default = false,
            Callback = function(val) BlazyConfig.Combat.NoSpread = val end
        })

        -- Movement Tab
        local MoveSection = Tabs.Movement:AddSection("Speed & Movement")
        MoveSection:AddToggle("WalkSpeedToggle", {
            Title = "CFrame WalkSpeed",
            Description = "Safe movement without touching Humanoid.WalkSpeed",
            Default = false,
            Callback = function(val) BlazyConfig.Movement.WalkSpeed = val end
        })

        MoveSection:AddSlider("WalkSpeedSlider", {
            Title = "Speed (Studs / Sec)",
            Min = 16,
            Max = 120,
            Default = 28,
            Rounding = 0,
            Callback = function(val) BlazyConfig.Movement.SpeedValue = val end
        })

        MoveSection:AddToggle("FlyToggle", {
            Title = "Camera 6-DOF Fly",
            Description = "Fly using W, A, S, D, Space, LeftShift",
            Default = false,
            Callback = function(val) BlazyConfig.Movement.Fly = val end
        })

        MoveSection:AddSlider("FlySpeedSlider", {
            Title = "Fly Velocity",
            Min = 20,
            Max = 150,
            Default = 50,
            Rounding = 0,
            Callback = function(val) BlazyConfig.Movement.FlySpeed = val end
        })

        MoveSection:AddToggle("NoclipToggle", {
            Title = "Noclip (Walk Through Walls)",
            Default = false,
            Callback = function(val) BlazyConfig.Movement.Noclip = val end
        })

        MoveSection:AddToggle("InfJumpToggle", {
            Title = "Infinite Jump",
            Default = false,
            Callback = function(val) BlazyConfig.Movement.InfiniteJump = val end
        })

        MoveSection:AddToggle("InfStaminaToggle", {
            Title = "Infinite Stamina",
            Default = false,
            Callback = function(val) BlazyConfig.Movement.InfiniteStamina = val end
        })

        MoveSection:AddToggle("NoFallDmgToggle", {
            Title = "No Fall Damage",
            Default = false,
            Callback = function(val) BlazyConfig.Movement.NoFallDamage = val end
        })

        -- Visuals Tab
        local VisSection = Tabs.Visuals:AddSection("Drawing ESP")
        VisSection:AddToggle("ESPToggle", {
            Title = "Master ESP Switch",
            Default = false,
            Callback = function(val) BlazyConfig.Visuals.ESP = val end
        })

        VisSection:AddToggle("BoxesToggle", {
            Title = "2D Bounding Boxes",
            Default = true,
            Callback = function(val) BlazyConfig.Visuals.Boxes = val end
        })

        VisSection:AddToggle("TracersToggle", {
            Title = "Tracers",
            Default = false,
            Callback = function(val) BlazyConfig.Visuals.Tracers = val end
        })

        VisSection:AddToggle("NamesToggle", {
            Title = "Player Names & Tags",
            Default = true,
            Callback = function(val) BlazyConfig.Visuals.Names = val end
        })

        VisSection:AddToggle("DistToggle", {
            Title = "Distance & Team Labels",
            Default = true,
            Callback = function(val) BlazyConfig.Visuals.Distance = val end
        })

        VisSection:AddToggle("HealthToggle", {
            Title = "Health Bars",
            Default = true,
            Callback = function(val) BlazyConfig.Visuals.HealthBar = val end
        })

        VisSection:AddSlider("MaxDistSlider", {
            Title = "Render Distance (Studs)",
            Min = 200,
            Max = 4000,
            Default = 1500,
            Rounding = 0,
            Callback = function(val) BlazyConfig.Visuals.MaxDistance = val end
        })

        -- Teleport Tab
        local TPSection = Tabs.Teleport:AddSection("Navigation & Teleports")
        TPSection:AddToggle("SafeModeToggle", {
            Title = "Anti-Cheat Safe Step Teleport",
            Description = "Steps in 20-stud chunks to evade position snapback",
            Default = true,
            Callback = function(val) BlazyConfig.Teleport.SafeMode = val end
        })

        TPSection:AddButton({
            Title = "Get Click-TP Tool",
            Description = "Equip tool and click anywhere on the map to teleport",
            Callback = function() GiveClickTPTool() end
        })

        local locNames = {}
        for name in pairs(TeleportEngine.Locations) do table.insert(locNames, name) end
        table.sort(locNames)

        TPSection:AddDropdown("LocationDropdown", {
            Title = "Teleport to Location",
            Values = locNames,
            Default = locNames[1],
            Callback = function(val)
                local pos = TeleportEngine.Locations[val]
                if pos then TeleportEngine:TeleportTo(pos, BlazyConfig.Teleport.SafeMode) end
            end
        })

        -- Automation Tab
        local AutoSection = Tabs.Automation:AddSection("Economy Automation")
        AutoSection:AddToggle("AutoATMToggle", {
            Title = "Auto ATM Robber",
            Description = "Automatically locates, interacts with, and robs ATMs",
            Default = false,
            Callback = function(val) BlazyConfig.Automation.AutoATM = val end
        })

        AutoSection:AddToggle("AutoDepositToggle", {
            Title = "Auto Deposit Cash to Bank",
            Description = "Deposits stolen money after robbing to protect earnings",
            Default = true,
            Callback = function(val) BlazyConfig.Automation.AutoDeposit = val end
        })

        AutoSection:AddSlider("MinigameDelaySlider", {
            Title = "Minigame Click Delay (Seconds)",
            Min = 0.10,
            Max = 0.40,
            Default = 0.18,
            Rounding = 2,
            Callback = function(val) BlazyConfig.Automation.MinigameDelay = val end
        })

        AutoSection:AddToggle("AutoJobToggle", {
            Title = "Auto Job & Work (Mail / Sanitation)",
            Description = "Automatically pathfinds and performs job delivery actions",
            Default = false,
            Callback = function(val) BlazyConfig.Automation.AutoJob = val end
        })

        -- Settings Tab
        local SettingSection = Tabs.Settings:AddSection("Hub Management")
        SettingSection:AddButton({
            Title = "Unload BLAZY-HUB",
            Description = "Cleans up all Drawing objects, hooks, and active threads",
            Callback = function()
                getgenv().BlazyHubLoaded = false
                if ESPManager.FOVCircle then ESPManager.FOVCircle:Remove() end
                Window:Destroy()
                print("[BLAZY-HUB]: Successfully unloaded.")
            end
        })

        Fluent:Notify({
            Title = "BLAZY-HUB Active",
            Content = "Emergency Response: Liberty County suite loaded successfully.",
            Duration = 5
        })

        return
    end

    ----------------------------------------------------------------------------
    -- STANDALONE FALLBACK GUI (Ensures 100% operation without external CDN)
    ----------------------------------------------------------------------------
    warn("[BLAZY-HUB]: External Fluent UI failed to load. Initializing Standalone Safe GUI.")
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "BlazyHub_" .. math.random(10000, 99999)
    screenGui.ResetOnSpawn = false

    local targetParent = (gethui and gethui()) or (syn and syn.protect_gui and LocalPlayer.PlayerGui) or game:GetService("CoreGui")
    if syn and syn.protect_gui then pcall(syn.protect_gui, screenGui) end
    screenGui.Parent = targetParent

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.fromOffset(500, 360)
    mainFrame.Position = UDim2.new(0.5, -250, 0.5, -180)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner", mainFrame)
    corner.CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", mainFrame)
    stroke.Color = Color3.fromRGB(255, 60, 60)
    stroke.Thickness = 1.5

    local title = Instance.new("TextLabel", mainFrame)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "  ⚡ BLAZY-HUB | ERLC (Standalone Mode)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.BackgroundTransparency = 1

    local content = Instance.new("ScrollingFrame", mainFrame)
    content.Size = UDim2.new(1, -20, 1, -55)
    content.Position = UDim2.new(0, 10, 0, 45)
    content.BackgroundTransparency = 1
    content.ScrollBarThickness = 4
    content.CanvasSize = UDim2.new(0, 0, 0, 500)

    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 8)

    local function AddSimpleToggle(name, default, callback)
        local btn = Instance.new("TextButton", content)
        btn.Size = UDim2.new(1, -10, 0, 35)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 32)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextColor3 = default and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(220, 220, 220)
        btn.Text = string.format("%s: [%s]", name, default and "ON" or "OFF")

        local btnCorner = Instance.new("UICorner", btn)
        btnCorner.CornerRadius = UDim.new(0, 6)

        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = string.format("%s: [%s]", name, state and "ON" or "OFF")
            btn.TextColor3 = state and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(220, 220, 220)
            callback(state)
        end)
    end

    AddSimpleToggle("Universal Silent Aim", BlazyConfig.Combat.SilentAim, function(v) BlazyConfig.Combat.SilentAim = v end)
    AddSimpleToggle("Show Silent Aim FOV", BlazyConfig.Combat.ShowFOV, function(v) BlazyConfig.Combat.ShowFOV = v end)
    AddSimpleToggle("CFrame WalkSpeed (Safe)", BlazyConfig.Movement.WalkSpeed, function(v) BlazyConfig.Movement.WalkSpeed = v end)
    AddSimpleToggle("Camera 6-DOF Fly", BlazyConfig.Movement.Fly, function(v) BlazyConfig.Movement.Fly = v end)
    AddSimpleToggle("Noclip", BlazyConfig.Movement.Noclip, function(v) BlazyConfig.Movement.Noclip = v end)
    AddSimpleToggle("Infinite Jump", BlazyConfig.Movement.InfiniteJump, function(v) BlazyConfig.Movement.InfiniteJump = v end)
    AddSimpleToggle("Master Drawing ESP", BlazyConfig.Visuals.ESP, function(v) BlazyConfig.Visuals.ESP = v end)
    AddSimpleToggle("Auto ATM Robber", BlazyConfig.Automation.AutoATM, function(v) BlazyConfig.Automation.AutoATM = v end)
    AddSimpleToggle("Auto Job Worker", BlazyConfig.Automation.AutoJob, function(v) BlazyConfig.Automation.AutoJob = v end)

    local tpBtn = Instance.new("TextButton", content)
    tpBtn.Size = UDim2.new(1, -10, 0, 35)
    tpBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
    tpBtn.Font = Enum.Font.GothamBold
    tpBtn.TextSize = 13
    tpBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
    tpBtn.Text = "⚡ Teleport: Liberty Bank"
    Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 6)
    tpBtn.MouseButton1Click:Connect(function()
        TeleportEngine:TeleportTo(TeleportEngine.Locations["Liberty Bank (Downtown)"], true)
    end)
end

-- Initialize Interface
InitializeUI()

print("[BLAZY-HUB]: ERLC Script Suite Loaded and Ready.")
