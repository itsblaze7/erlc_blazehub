--[[
    =============================================================================
    BLZEYY HUB - Ultimate ERLC & Universal Automation Engine
    Target Game: Emergency Response: Liberty County (PlaceId: 2534724415) & Universal
    Engine: Luau Multi-Executor Compatibility (Delta, Wave, Hydrogen, Macsploit, Solara, etc.)
    Version: 1.0.0
    Authors: BLZEYY Engineering Team
    =============================================================================
--]]

-- Prevent multiple instances
if getgenv and getgenv().BLZEYY_LOADED then
    warn("[BLZEYY HUB] Script is already executing!")
    return
end
if getgenv then getgenv().BLZEYY_LOADED = true end

-- =============================================================================
-- 1. ENVIRONMENT & SERVICES INITIALIZATION
-- =============================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Camera = Workspace.CurrentCamera

local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
    LocalPlayer = Players.LocalPlayer
end

local Mouse = LocalPlayer:GetMouse()
local IsERLC = (game.PlaceId == 2534724415)

-- Compatibility Polyfills
local hookmetamethod = hookmetamethod or (getrawmetatable and function(t, m, f)
    local mt = getrawmetatable(t)
    local old = mt[m]
    setreadonly(mt, false)
    mt[m] = f
    setreadonly(mt, true)
    return old
end)
local newcclosure = newcclosure or function(f) return f end
local checkcaller = checkcaller or function() return false end
local getnamecallmethod = getnamecallmethod or function() return "" end
local Drawing = Drawing or Drawing

-- =============================================================================
-- 2. CONFIGURATION & STATE
-- =============================================================================
local Config = {
    Combat = {
        Enabled = true,
        SilentAim = true,
        Smoothness = 3.5,
        FOV = 130,
        TargetBone = "Head", -- "Head", "HumanoidRootPart", "Closest"
        VisibleCheck = true,
        TeamCheck = true,
        DrawFOV = true,
        FOVColor = Color3.fromRGB(0, 217, 255),
        NoRecoil = true,
        NoSpread = true,
        InstantReload = true
    },
    Visuals = {
        Master = true,
        Boxes = true,
        BoxType = "2D", -- "2D" or "Corner"
        Skeleton = true,
        Distance = true,
        Health = true,
        Tracers = false,
        TracerOrigin = "Bottom",
        PlayerColor = Color3.fromRGB(0, 217, 255),
        CopsColor = Color3.fromRGB(50, 130, 255),
        WantedColor = Color3.fromRGB(255, 60, 60),
        CopsESP = true,
        ATM_ESP = true,
        ATMColor = Color3.fromRGB(50, 230, 140),
        RobberyESP = true,
        VehicleESP = true
    },
    Movement = {
        SpeedEnabled = false,
        SpeedValue = 28,
        FlyEnabled = false,
        FlySpeed = 50,
        Noclip = false,
        InfiniteStamina = true,
        SafeTP = true
    },
    Automation = {
        AutoATM = true,
        AutoGlassCutter = true,
        AutoLockpick = true,
        AutoCashier = false,
        AutoSanitation = false,
        AntiArrest = true,
        AntiTaser = true,
        AntiAFK = true,
        ServerHopOnStaff = false
    }
}

-- =============================================================================
-- 3. ANTI-CHEAT MITIGATION & METAMETHOD HOOKS
-- =============================================================================
local AnticheatHooks = {}

-- 3.1 Hook __namecall to intercept detection remotes and silent aim vectoring
if hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if not checkcaller() then
            -- A: Anti-Cheat & Telemetry Interception
            local name = tostring(self.Name)
            if method == "FireServer" or method == "InvokeServer" then
                -- Intercept and suppress ERLC speed/walk checks, crashers, and ban triggers
                if name:match("Detection") or name:match("Suspicious") or name:match("Ban") or name:match("Cheat") then
                    return nil
                end
                
                -- Stamina consumption suppression
                if Config.Movement.InfiniteStamina and (name:match("Stamina") or name:match("SprintDrain")) then
                    return nil
                end

                -- Gun mods: Silent aim bullet redirection
                if Config.Combat.Enabled and Config.Combat.SilentAim and (name:match("Shoot") or name:match("Fire") or name:match("Hit") or name:match("Bullet")) then
                    local target = AnticheatHooks.GetBestTarget()
                    if target and target.Character and target.Character:FindFirstChild(Config.Combat.TargetBone) then
                        local hitPart = target.Character[Config.Combat.TargetBone]
                        -- Override hit position in remote arguments
                        for i, arg in ipairs(args) do
                            if typeof(arg) == "Vector3" then
                                args[i] = hitPart.Position
                            elseif typeof(arg) == "CFrame" then
                                args[i] = hitPart.CFrame
                            elseif typeof(arg) == "Instance" and (arg:IsA("BasePart") or arg:IsA("Model")) then
                                args[i] = hitPart
                            end
                        end
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
        end

        return oldNamecall(self, ...)
    end))

    -- 3.2 Hook __index to spoof walkspeed & humanoid states against client-side checkers
    local oldIndex
    oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if not checkcaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
            if key == "WalkSpeed" and Config.Movement.SpeedEnabled then
                return 16 -- Return default walkspeed to any anti-cheat scripts querying the property
            elseif key == "JumpPower" then
                return 50
            end
        end
        return oldIndex(self, key)
    end))
end

-- =============================================================================
-- 4. COMBAT & SILENT AIM ENGINE
-- =============================================================================
local FOVCircle = nil
if Drawing then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1.5
    FOVCircle.NumSides = 64
    FOVCircle.Radius = Config.Combat.FOV
    FOVCircle.Filled = false
    FOVCircle.Visible = Config.Combat.DrawFOV
    FOVCircle.Color = Config.Combat.FOVColor
    FOVCircle.Transparency = 0.8
end

function AnticheatHooks.IsVisible(part)
    if not Config.Combat.VisibleCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = part.Position - origin
    local rayParams = RaycastParams.new()
    rayParams.FilterType = RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = { LocalPlayer.Character, Camera }
    local result = Workspace:Raycast(origin, dir, rayParams)
    return (result == nil or (result.Instance and result.Instance:IsDescendantOf(part.Parent)))
end

function AnticheatHooks.GetBestTarget()
    local bestTarget = nil
    local shortestDist = Config.Combat.FOV
    local mousePos = Vector2.new(Mouse.X, Mouse.Y)

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            -- Team check
            if Config.Combat.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                continue
            end

            local hitPart = player.Character:FindFirstChild(Config.Combat.TargetBone) or player.Character:FindFirstChild("Head")
            if hitPart then
                local screenPos, onScreen = Camera:WorldToViewportPoint(hitPart.Position)
                if onScreen then
                    local screenVec2 = Vector2.new(screenPos.X, screenPos.Y)
                    local dist = (mousePos - screenVec2).Magnitude
                    if dist <= shortestDist and AnticheatHooks.IsVisible(hitPart) then
                        shortestDist = dist
                        bestTarget = player
                    end
                end
            end
        end
    end
    return bestTarget
end

-- Weapon recoil & spread negation
RunService.RenderStepped:Connect(function()
    -- Keep FOV circle centered on mouse cursor
    if FOVCircle then
        FOVCircle.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
        FOVCircle.Radius = Config.Combat.FOV
        FOVCircle.Visible = Config.Combat.DrawFOV and Config.Combat.Enabled
        FOVCircle.Color = Config.Combat.FOVColor
    end

    -- Recoil compensation
    if Config.Combat.NoRecoil and LocalPlayer.Character then
        local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        if tool then
            -- Hook weapon recoil attributes or camera shake modules if present
            local recoilVal = tool:FindFirstChild("Recoil") or tool:FindFirstChild("Kickback")
            if recoilVal and recoilVal:IsA("NumberValue") then
                recoilVal.Value = 0
            end
        end
    end
end)

-- =============================================================================
-- 5. VISUALS & ESP (PLAYERS, COPS, ATMS, OBJECTIVES)
-- =============================================================================
local ESPCache = {}

local function CreateESPElement(player)
    local esp = {
        Player = player,
        Box = Drawing and Drawing.new("Square"),
        Name = Drawing and Drawing.new("Text"),
        Distance = Drawing and Drawing.new("Text"),
        HealthBarBg = Drawing and Drawing.new("Square"),
        HealthBar = Drawing and Drawing.new("Square"),
        Tracer = Drawing and Drawing.new("Line")
    }

    if esp.Box then
        esp.Box.Thickness = 1.5
        esp.Box.Filled = false
        esp.Box.Visible = false

        esp.Name.Size = 13
        esp.Name.Center = true
        esp.Name.Outline = true
        esp.Name.Visible = false

        esp.Distance.Size = 12
        esp.Distance.Center = true
        esp.Distance.Outline = true
        esp.Distance.Visible = false

        esp.HealthBarBg.Filled = true
        esp.HealthBarBg.Color = Color3.fromRGB(20, 20, 20)
        esp.HealthBarBg.Visible = false

        esp.HealthBar.Filled = true
        esp.HealthBar.Color = Color3.fromRGB(40, 220, 80)
        esp.HealthBar.Visible = false

        esp.Tracer.Thickness = 1.0
        esp.Tracer.Visible = false
    end

    ESPCache[player] = esp
    return esp
end

local function RemoveESPElement(player)
    local esp = ESPCache[player]
    if esp then
        for _, elem in pairs(esp) do
            if typeof(elem) == "table" and elem.Remove then
                elem:Remove()
            end
        end
        ESPCache[player] = nil
    end
end

for _, p in ipairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESPElement(p) end
end
Players.PlayerAdded:Connect(CreateESPElement)
Players.PlayerRemoving:Connect(RemoveESPElement)

-- ERLC Objective & ATM ESP Items
local WorldESPMarkers = {}

local function ScanWorldObjectives()
    if not IsERLC or not Drawing then return end

    -- Scan for ATMs
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name:match("ATM") and (obj:IsA("Model") or obj:IsA("BasePart")) then
            if not WorldESPMarkers[obj] then
                local text = Drawing.new("Text")
                text.Text = "[ATM]"
                text.Size = 13
                text.Center = true
                text.Outline = true
                text.Color = Config.Visuals.ATMColor
                text.Visible = false
                WorldESPMarkers[obj] = { Type = "ATM", Drawing = text, Object = obj }
            end
        elseif (obj.Name:match("Jewelry") or obj.Name:match("GlassCase") or obj.Name:match("BankVault")) and not WorldESPMarkers[obj] then
            local text = Drawing.new("Text")
            text.Text = "[" .. obj.Name .. "]"
            text.Size = 12
            text.Center = true
            text.Outline = true
            text.Color = Color3.fromRGB(255, 200, 50)
            text.Visible = false
            WorldESPMarkers[obj] = { Type = "Robbery", Drawing = text, Object = obj }
        end
    end
end

if IsERLC then
    task.spawn(function()
        while task.wait(5) do
            ScanWorldObjectives()
        end
    end)
end

-- Render loop for Visuals
RunService.RenderStepped:Connect(function()
    if not Drawing then return end

    -- Render Player ESP
    for player, esp in pairs(ESPCache) do
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        local hrp = char and char:FindFirstChild("HumanoidRootPart")

        if Config.Visuals.Master and char and hum and hrp and hum.Health > 0 then
            local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local head = char:FindFirstChild("Head")
                local topY = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.6, 0)).Y or (rootPos.Y - 20)
                local bottomY = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.8, 0)).Y
                local height = math.abs(bottomY - topY)
                local width = height * 0.65

                local boxColor = Config.Visuals.PlayerColor
                if IsERLC and player.Team then
                    local tName = player.Team.Name:lower()
                    if tName:match("police") or tName:match("sheriff") or tName:match("officer") then
                        boxColor = Config.Visuals.CopsColor
                    elseif tName:match("wanted") or tName:match("criminal") then
                        boxColor = Config.Visuals.WantedColor
                    end
                end

                -- Box
                if Config.Visuals.Boxes and esp.Box then
                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(rootPos.X - width * 0.5, topY)
                    esp.Box.Color = boxColor
                    esp.Box.Visible = true
                else
                    esp.Box.Visible = false
                end

                -- Name
                if esp.Name then
                    esp.Name.Text = player.DisplayName .. " (@" .. player.Name .. ")"
                    esp.Name.Position = Vector2.new(rootPos.X, topY - 16)
                    esp.Name.Color = boxColor
                    esp.Name.Visible = true
                end

                -- Distance
                if Config.Visuals.Distance and esp.Distance then
                    local dist = math.floor((Camera.CFrame.Position - hrp.Position).Magnitude)
                    esp.Distance.Text = tostring(dist) .. "m"
                    esp.Distance.Position = Vector2.new(rootPos.X, bottomY + 2)
                    esp.Distance.Color = Color3.fromRGB(200, 200, 200)
                    esp.Distance.Visible = true
                else
                    esp.Distance.Visible = false
                end

                -- Health Bar
                if Config.Visuals.Health and esp.HealthBar and esp.HealthBarBg then
                    local barWidth = 3
                    local barHeight = height * (hum.Health / math.max(hum.MaxHealth, 1))
                    esp.HealthBarBg.Size = Vector2.new(barWidth, height)
                    esp.HealthBarBg.Position = Vector2.new(rootPos.X - width * 0.5 - 6, topY)
                    esp.HealthBarBg.Visible = true

                    esp.HealthBar.Size = Vector2.new(barWidth, barHeight)
                    esp.HealthBar.Position = Vector2.new(rootPos.X - width * 0.5 - 6, bottomY - barHeight)
                    esp.HealthBar.Color = Color3.fromHSV((hum.Health / hum.MaxHealth) * 0.33, 1, 1)
                    esp.HealthBar.Visible = true
                else
                    esp.HealthBar.Visible = false
                    esp.HealthBarBg.Visible = false
                end

                -- Tracer
                if Config.Visuals.Tracers and esp.Tracer then
                    esp.Tracer.From = Vector2.new(Camera.ViewportSize.X * 0.5, Camera.ViewportSize.Y)
                    esp.Tracer.To = Vector2.new(rootPos.X, bottomY)
                    esp.Tracer.Color = boxColor
                    esp.Tracer.Visible = true
                else
                    esp.Tracer.Visible = false
                end
            else
                esp.Box.Visible = false
                esp.Name.Visible = false
                esp.Distance.Visible = false
                esp.HealthBar.Visible = false
                esp.HealthBarBg.Visible = false
                esp.Tracer.Visible = false
            end
        else
            if esp.Box then esp.Box.Visible = false end
            if esp.Name then esp.Name.Visible = false end
            if esp.Distance then esp.Distance.Visible = false end
            if esp.HealthBar then esp.HealthBar.Visible = false end
            if esp.HealthBarBg then esp.HealthBarBg.Visible = false end
            if esp.Tracer then esp.Tracer.Visible = false end
        end
    end

    -- Render Objective ESP
    for obj, item in pairs(WorldESPMarkers) do
        if obj and obj.Parent then
            local pos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position) or obj.Position
            local sPos, onScreen = Camera:WorldToViewportPoint(pos)
            if onScreen then
                local dist = math.floor((Camera.CFrame.Position - pos).Magnitude)
                item.Drawing.Text = string.format("%s [%dm]", item.Type == "ATM" and "ATM Machine" or obj.Name, dist)
                item.Drawing.Position = Vector2.new(sPos.X, sPos.Y)
                item.Drawing.Visible = (item.Type == "ATM" and Config.Visuals.ATM_ESP) or (item.Type == "Robbery" and Config.Visuals.RobberyESP)
            else
                item.Drawing.Visible = false
            end
        else
            item.Drawing:Remove()
            WorldESPMarkers[obj] = nil
        end
    end
end)

-- =============================================================================
-- 6. MOVEMENT ENGINE (PHYSICS-SAFE SPEEDHACK, FLY, NOCLIP, SAFE TP)
-- =============================================================================

-- 6.1 Physics-Safe Speedhack (Bypasses Humanoid.WalkSpeed AC detections)
RunService.Heartbeat:Connect(function()
    if Config.Movement.SpeedEnabled and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
        if hrp and hum and hum.MoveDirection.Magnitude > 0 then
            local moveVel = hum.MoveDirection.Unit * Config.Movement.SpeedValue
            hrp.AssemblyLinearVelocity = Vector3.new(moveVel.X, hrp.AssemblyLinearVelocity.Y, moveVel.Z)
        end
    end
end)

-- 6.2 Noclip Engine
RunService.Stepped:Connect(function()
    if Config.Movement.Noclip and LocalPlayer.Character then
        for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
end)

-- 6.3 Smooth Physics Fly Engine
local FlyBodyGyro, FlyBodyVel
local function UpdateFly(enabled)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if enabled then
        FlyBodyGyro = Instance.new("BodyGyro")
        FlyBodyGyro.P = 9e4
        FlyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        FlyBodyGyro.CFrame = hrp.CFrame
        FlyBodyGyro.Parent = hrp

        FlyBodyVel = Instance.new("BodyVelocity")
        FlyBodyVel.Velocity = Vector3.new(0, 0, 0)
        FlyBodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        FlyBodyVel.Parent = hrp

        task.spawn(function()
            while Config.Movement.FlyEnabled and hrp and FlyBodyVel and FlyBodyGyro do
                local camCF = Camera.CFrame
                local dir = Vector3.new()
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - camCF.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + camCF.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.new(0, 1, 0) end

                FlyBodyGyro.CFrame = camCF
                FlyBodyVel.Velocity = (dir.Magnitude > 0) and (dir.Unit * Config.Movement.FlySpeed) or Vector3.new(0, 0, 0)
                RunService.RenderStepped:Wait()
            end
            if FlyBodyGyro then FlyBodyGyro:Destroy() end
            if FlyBodyVel then FlyBodyVel:Destroy() end
        end)
    else
        if FlyBodyGyro then FlyBodyGyro:Destroy() end
        if FlyBodyVel then FlyBodyVel:Destroy() end
    end
end

-- 6.4 Safe Teleportation (Anti-Rubberband Chunk Interpolation)
function AnticheatHooks.SafeTeleport(targetPos)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if not Config.Movement.SafeTP then
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
        return
    end

    -- Progressive micro-stepping to bypass server position delta sanity checks
    local startPos = hrp.Position
    local distance = (targetPos - startPos).Magnitude
    local steps = math.clamp(math.ceil(distance / 25), 1, 30)

    task.spawn(function()
        for i = 1, steps do
            local currentPos = startPos:Lerp(targetPos, i / steps)
            hrp.CFrame = CFrame.new(currentPos + Vector3.new(0, 2, 0))
            task.wait(0.04)
        end
        hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    end)
end

-- Predefined ERLC Waypoints
local ERLCWaypoints = {
    ["Bank Vault"]        = Vector3.new(840, 24, 450),
    ["Jewelry Store"]     = Vector3.new(-120, 24, 860),
    ["Police Department"] = Vector3.new(350, 25, -200),
    ["Sheriff Office"]    = Vector3.new(-920, 30, -410),
    ["Tool & Hardware"]   = Vector3.new(120, 24, 620),
    ["Car Dealership"]    = Vector3.new(-450, 24, 180),
    ["Hospital"]          = Vector3.new(620, 24, -80),
    ["Fire Station"]      = Vector3.new(410, 24, 150)
}

-- =============================================================================
-- 7. ERLC AUTO-FARM & AUTOMATION (ATM, ROBBERIES, JOBS)
-- =============================================================================

-- 7.1 Auto ATM Robbery & Minigame Solver
task.spawn(function()
    while task.wait(1.5) do
        if IsERLC and Config.Automation.AutoATM and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                -- Locate nearest ATM
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if obj.Name:match("ATM") and (obj:IsA("Model") or obj:IsA("BasePart")) then
                        local pos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position) or obj.Position
                        local dist = (hrp.Position - pos).Magnitude
                        if dist <= 12 then
                            -- Auto-trigger interaction prompt
                            local prompt = obj:FindFirstChildOfClass("ProximityPrompt", true)
                            if prompt and prompt.Enabled then
                                fireproximityprompt(prompt)
                            end

                            -- Auto-solve ATM minigame UI if open
                            local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
                            if playerGui then
                                local atmGui = playerGui:FindFirstChild("ATMGui") or playerGui:FindFirstChild("Minigame")
                                if atmGui and atmGui.Enabled then
                                    -- Signal completion to ATM server remotes
                                    for _, remote in ipairs(ReplicatedStorage:GetDescendants()) do
                                        if remote:IsA("RemoteEvent") and (remote.Name:match("ATM") or remote.Name:match("Hack")) then
                                            remote:FireServer(obj, true)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- 7.2 Auto Glass Cutter (Jewelry Store)
task.spawn(function()
    while task.wait(1.0) do
        if IsERLC and Config.Automation.AutoGlassCutter and LocalPlayer.Character then
            local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, obj in ipairs(Workspace:GetDescendants()) do
                    if (obj.Name:match("GlassCase") or obj.Name:match("JewelryCase")) and (obj:IsA("Model") or obj:IsA("BasePart")) then
                        local pos = obj:IsA("Model") and (obj.PrimaryPart and obj.PrimaryPart.Position or obj:GetPivot().Position) or obj.Position
                        if (hrp.Position - pos).Magnitude <= 10 then
                            local prompt = obj:FindFirstChildOfClass("ProximityPrompt", true)
                            if prompt and prompt.Enabled then
                                fireproximityprompt(prompt)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- 7.3 Anti-Arrest & Anti-Taser Evasion
RunService.Heartbeat:Connect(function()
    if IsERLC and Config.Automation.AntiArrest and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, player in ipairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Team and player.Team.Name:lower():match("police") then
                    local copChar = player.Character
                    local copHrp = copChar and copChar:FindFirstChild("HumanoidRootPart")
                    if copHrp and (hrp.Position - copHrp.Position).Magnitude < 14 then
                        -- Check if officer has handcuffs or taser equipped
                        local tool = copChar:FindFirstChildOfClass("Tool")
                        if tool and (tool.Name:lower():match("cuff") or tool.Name:lower():match("taser")) then
                            -- Safe evasion jump boost
                            hrp.AssemblyLinearVelocity = Vector3.new(hrp.AssemblyLinearVelocity.X, 45, hrp.AssemblyLinearVelocity.Z)
                        end
                    end
                end
            end
        end
    end
end)

-- 7.4 Anti-AFK Disconnector Protection
LocalPlayer.Idled:Connect(function()
    if Config.Automation.AntiAFK then
        local virtualUser = game:GetService("VirtualUser")
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.new(0, 0))
    end
end)

-- =============================================================================
-- 8. SLEEK IN-GAME WATERMARK
-- =============================================================================
if Drawing then
    local WatermarkBg = Drawing.new("Square")
    WatermarkBg.Size = Vector2.new(340, 28)
    WatermarkBg.Position = Vector2.new(20, 20)
    WatermarkBg.Color = Color3.fromRGB(12, 12, 18)
    WatermarkBg.Filled = true
    WatermarkBg.Transparency = 0.9
    WatermarkBg.Visible = true

    local WatermarkBorder = Drawing.new("Square")
    WatermarkBorder.Size = Vector2.new(340, 28)
    WatermarkBorder.Position = Vector2.new(20, 20)
    WatermarkBorder.Color = Color3.fromRGB(0, 217, 255)
    WatermarkBorder.Thickness = 1.0
    WatermarkBorder.Filled = false
    WatermarkBorder.Visible = true

    local WatermarkText = Drawing.new("Text")
    WatermarkText.Text = "BLZEYY HUB | " .. (IsERLC and "ERLC v1.0" or "Universal") .. " | [FPS: 60] | INSERT to toggle"
    WatermarkText.Size = 13
    WatermarkText.Position = Vector2.new(28, 26)
    WatermarkText.Color = Color3.fromRGB(255, 255, 255)
    WatermarkText.Outline = true
    WatermarkText.Visible = true

    -- Update FPS
    local lastTime = tick()
    local frameCount = 0
    RunService.RenderStepped:Connect(function()
        frameCount = frameCount + 1
        local now = tick()
        if now - lastTime >= 1.0 then
            local fps = math.floor(frameCount / (now - lastTime))
            WatermarkText.Text = string.format("BLZEYY HUB | %s | [FPS: %d] | INSERT to toggle", IsERLC and "ERLC v1.0" or "Universal", fps)
            frameCount = 0
            lastTime = now
        end
    end)
end

-- =============================================================================
-- 9. USER INTERFACE HOTKEY INTEGRATION (INSERT)
-- =============================================================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.Insert then
        Config.Visuals.Master = not Config.Visuals.Master
        if FOVCircle then FOVCircle.Visible = Config.Combat.DrawFOV and Config.Visuals.Master end
    end
end)

print("[BLZEYY HUB] Engine successfully initialized!")
if IsERLC then
    print("[BLZEYY HUB] ERLC Mode active: ATM auto-solver, Safe TP, Cops ESP, and bypasses loaded.")
else
    print("[BLZEYY HUB] Universal Mode active: Silent Aim, ESP, and locomotion engine loaded.")
end
