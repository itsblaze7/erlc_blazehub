--[[
    =============================================================================
    APEX HUB — UNIVERSAL & ERLC EDITION (v2.0)
    =============================================================================
    Target: Universal (All Roblox Games) + Specialized ERLC Modules
    Compatible Executors: Xeno, Delta, Wave, MacSploit, Solara, Codex, Fluxus
    Resilience: Multi-Tier Capability Detection & Safe Fallbacks (Zero Nil Calls)
    =============================================================================
--]]

-- Clean up any existing instance
if _G.ApexHubLoaded then
    pcall(function()
        if typeof(_G.ApexHubUnload) == "function" then
            _G.ApexHubUnload()
        end
    end)
end
_G.ApexHubLoaded = true

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = nil
pcall(function() VirtualUser = game:GetService("VirtualUser") end)

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- Identify current game
local PlaceId = game.PlaceId
local IsERLC = (PlaceId == 2534724415)

-- =============================================================================
-- EXECUTOR CAPABILITY DETECTION & SAFE WRAPPERS
-- =============================================================================
local Capabilities = {
    GetHui = (typeof(gethui) == "function"),
    ProtectGui = (typeof(syn) == "table" and typeof(syn.protect_gui) == "function"),
    Drawing = (typeof(Drawing) == "table" and typeof(Drawing.new) == "function"),
    HookMetamethod = (typeof(hookmetamethod) == "function"),
    GetRawMetatable = (typeof(getrawmetatable) == "function"),
    CheckCaller = (typeof(checkcaller) == "function"),
    GetNamecallMethod = (typeof(getnamecallmethod) == "function"),
    NewCClosure = (typeof(newcclosure) == "function"),
    FireProximityPrompt = (typeof(fireproximityprompt) == "function"),
    GetConnections = (typeof(getconnections) == "function"),
}

-- Safe Caller Check
local function SafeCheckCaller()
    if Capabilities.CheckCaller then
        local s, res = pcall(checkcaller)
        if s then return res end
    end
    return false
end

-- =============================================================================
-- RUNTIME CONSOLE & DIAGNOSTICS ENGINE
-- =============================================================================
local Console = {
    Logs = {},
    MaxLogs = 120,
    OnLogAdded = nil,
}

function Console:Log(level, message)
    local timestamp = os.date("%X")
    local entry = {
        Time = timestamp,
        Level = level or "INFO",
        Message = tostring(message)
    }
    table.insert(self.Logs, entry)
    if #self.Logs > self.MaxLogs then
        table.remove(self.Logs, 1)
    end
    if self.OnLogAdded then
        task.spawn(function()
            pcall(self.OnLogAdded, entry)
        end)
    end
end

Console:Log("INFO", "Initializing Apex Universal Engine...")
Console:Log("INFO", string.format("Detected Game: %s (Place ID: %d)", IsERLC and "ERLC" or "Universal Experience", PlaceId))
Console:Log("INFO", string.format("Environment: Drawing=%s | Metamethods=%s | GetHui=%s",
    tostring(Capabilities.Drawing),
    tostring(Capabilities.HookMetamethod or Capabilities.GetRawMetatable),
    tostring(Capabilities.GetHui)
))

-- =============================================================================
-- CONFIGURATION & STATE REPOSITORY
-- =============================================================================
local Config = {
    -- Combat / Aimbot
    Combat = {
        Aimbot = false,
        SilentAim = false,
        FOV = 120,
        HitPart = "Head", -- "Head", "HumanoidRootPart", "Torso"
        VisibleCheck = false,
        TeamCheck = false,
        HitChance = 100,
        Smoothness = 1, -- 1 = instant, higher = smoother
        ShowFOV = true,
        FOVColor = Color3.fromRGB(0, 200, 255),
        NoRecoil = false,
        NoSpread = false,
        RapidFire = false,
    },
    -- Visuals (Dual-Engine ESP)
    Visuals = {
        Enabled = false,
        Engine = "Highlight", -- "Highlight" (Native Universal) or "Drawing"
        Boxes = true,
        Tracers = false,
        Names = true,
        Distance = true,
        Health = true,
        TeamColor = true,
        MaxDistance = 1500,
        ChamsColor = Color3.fromRGB(255, 60, 60),
        CopsColor = Color3.fromRGB(50, 130, 255),
        CiviliansColor = Color3.fromRGB(80, 220, 100),
        CriminalsColor = Color3.fromRGB(240, 70, 70),
        DefaultColor = Color3.fromRGB(255, 255, 255),
    },
    -- Movement
    Movement = {
        CFrameSpeed = false,
        SpeedValue = 35,
        InfiniteJump = false,
        Noclip = false,
        Fly = false,
        FlySpeed = 50,
        HighJump = false,
        HighJumpPower = 80,
    },
    -- Teleports
    Teleport = {
        SafeMode = true,
        SafeStepDistance = 20,
        SafeStepDelay = 0.03,
        SelectedPlayer = nil,
    },
    -- Universal Utilities
    Universal = {
        Fullbright = false,
        AntiAFK = false,
        CustomFOV = false,
        FOVValue = 90,
        LowDetail = false,
    },
    -- Specialized ERLC Modules
    ERLC = {
        AutoATM = false,
        AutoEquipRFID = true,
        AutoMinigame = true,
        MinigameDelayMin = 0.15,
        MinigameDelayMax = 0.35,
        InfiniteStamina = false,
        NoFallDamage = false,
        NoSpeedTraps = false,
        TargetCopsOnly = false,
        TargetCriminalsOnly = false,
    }
}

-- Garbage Collector & Cleanup Registry
local Cleaners = {
    Connections = {},
    Drawings = {},
    Highlights = {},
    Billboards = {},
    Hooks = {},
    Instances = {},
    LightingRestore = {}
}

local function RegisterConnection(conn)
    if conn then
        table.insert(Cleaners.Connections, conn)
    end
    return conn
end

-- =============================================================================
-- SAFE METATABLE PROTECTION LAYER (ZERO NIL CALLS)
-- =============================================================================
local function InitializeMetatableProtection()
    -- Only hook if the executor supports hookmetamethod or getrawmetatable safely
    if Capabilities.HookMetamethod then
        pcall(function()
            local oldIndex
            oldIndex = hookmetamethod(game, "__index", function(self, key)
                if not SafeCheckCaller() and typeof(self) == "Instance" and self:IsA("Humanoid") then
                    if key == "WalkSpeed" then
                        return 16
                    elseif key == "JumpPower" then
                        return 50
                    elseif key == "HipHeight" then
                        return 0
                    end
                end
                return oldIndex(self, key)
            end)
            Cleaners.Hooks["__index"] = oldIndex
            Console:Log("SECURITY", "Humanoid __index property spoofing active.")
        end)

        pcall(function()
            local oldNamecall
            local blocked = {"Ban", "AntiCheat", "Security", "Telemetry", "Detection", "CheatLog", "ErrorLog", "WalkSpeedCheck", "SpeedViolation"}
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = Capabilities.GetNamecallMethod and getnamecallmethod() or ""
                if not SafeCheckCaller() and (method == "FireServer" or method == "fireServer") then
                    local name = tostring(self.Name):lower()
                    for _, b in ipairs(blocked) do
                        if string.find(name, b:lower()) then
                            Console:Log("SECURITY", "Blocked telemetry remote: " .. self.Name)
                            return nil
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            Cleaners.Hooks["__namecall"] = oldNamecall
            Console:Log("SECURITY", "Remote inspection & filter active.")
        end)
    else
        Console:Log("INFO", "Executor lacks low-level metamethod hooks; running in universal emulation mode.")
    end

    -- Universal ScriptContext Error Suppression
    pcall(function()
        local ScriptContext = game:GetService("ScriptContext")
        RegisterConnection(ScriptContext.Error:Connect(function() end))
    end)
end

-- =============================================================================
-- FOV CIRCLE (DRAWING OR NATIVE GUI FALLBACK)
-- =============================================================================
local FOVCircleDrawing = nil
local FOVCircleGui = nil

local function SetupFOVCircle(parentGui)
    if Capabilities.Drawing then
        pcall(function()
            FOVCircleDrawing = Drawing.new("Circle")
            FOVCircleDrawing.Visible = false
            FOVCircleDrawing.Radius = Config.Combat.FOV
            FOVCircleDrawing.Color = Config.Combat.FOVColor
            FOVCircleDrawing.Thickness = 1.5
            FOVCircleDrawing.Transparency = 0.8
            FOVCircleDrawing.Filled = false
            table.insert(Cleaners.Drawings, FOVCircleDrawing)
        end)
    end

    -- Always create a native GUI ring fallback so FOV is visible on ANY executor
    pcall(function()
        local ring = Instance.new("ImageLabel")
        ring.Name = "FOVRingFallback"
        ring.BackgroundTransparency = 1
        ring.Image = "rbxassetid://3570695787" -- Circular ring asset
        ring.ImageColor3 = Config.Combat.FOVColor
        ring.ImageTransparency = 0.3
        ring.AnchorPoint = Vector2.new(0.5, 0.5)
        ring.Size = UDim2.new(0, Config.Combat.FOV * 2, 0, Config.Combat.FOV * 2)
        ring.Visible = false
        ring.Parent = parentGui
        FOVCircleGui = ring
        table.insert(Cleaners.Instances, ring)
    end)
end

local function UpdateFOVCircle()
    local mousePos = UserInputService:GetMouseLocation()
    local shouldShow = Config.Combat.ShowFOV and (Config.Combat.Aimbot or Config.Combat.SilentAim)

    if FOVCircleDrawing then
        FOVCircleDrawing.Visible = shouldShow
        FOVCircleDrawing.Radius = Config.Combat.FOV
        FOVCircleDrawing.Position = mousePos
        FOVCircleDrawing.Color = Config.Combat.FOVColor
    end

    if FOVCircleGui then
        -- If Drawing is active and visible, hide GUI circle to prevent double rendering
        if FOVCircleDrawing and FOVCircleDrawing.Visible then
            FOVCircleGui.Visible = false
        else
            FOVCircleGui.Visible = shouldShow
            FOVCircleGui.Size = UDim2.new(0, Config.Combat.FOV * 2, 0, Config.Combat.FOV * 2)
            FOVCircleGui.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
            FOVCircleGui.ImageColor3 = Config.Combat.FOVColor
        end
    end
end

-- =============================================================================
-- UNIVERSAL TARGET ACQUISITION & AIMBOT
-- =============================================================================
local function GetPlayerFaction(player)
    if not player.Team then return "Neutral" end
    local name = player.Team.Name:lower()
    if string.find(name, "police") or string.find(name, "sheriff") or string.find(name, "trooper") or string.find(name, "cop") then
        return "Police"
    elseif string.find(name, "criminal") or string.find(name, "wanted") or string.find(name, "prisoner") then
        return "Criminal"
    else
        return "Civilian"
    end
end

local function GetTargetPart(character)
    if not character then return nil end
    local partName = Config.Combat.HitPart
    if partName == "Head" then
        return character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    elseif partName == "Torso" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") or character:FindFirstChild("HumanoidRootPart")
    else
        return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
    end
end

local function GetClosestTarget()
    local closestPart = nil
    local minDistance = Config.Combat.FOV
    local mousePos = UserInputService:GetMouseLocation()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hum = char:FindFirstChild("Humanoid")
            local targetPart = GetTargetPart(char)

            if hum and hum.Health > 0 and targetPart then
                local pass = true

                -- Team Filter
                if Config.Combat.TeamCheck and player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team then
                    pass = false
                end

                -- ERLC Specific Faction Filter
                if IsERLC then
                    local faction = GetPlayerFaction(player)
                    if Config.ERLC.TargetCopsOnly and faction ~= "Police" then
                        pass = false
                    end
                    if Config.ERLC.TargetCriminalsOnly and faction ~= "Criminal" then
                        pass = false
                    end
                end

                if pass then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        -- Wall Visibility Check
                        if Config.Combat.VisibleCheck then
                            local rayParams = RaycastParams.new()
                            rayParams.FilterType = Enum.RaycastFilterType.Exclude
                            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                            local hit = Workspace:Raycast(Camera.CFrame.Position, (targetPart.Position - Camera.CFrame.Position), rayParams)
                            if hit and not hit.Instance:IsDescendantOf(char) then
                                pass = false
                            end
                        end

                        if pass then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if dist < minDistance then
                                minDistance = dist
                                closestPart = targetPart
                            end
                        end
                    end
                end
            end
        end
    end

    return closestPart
end

-- Aimbot Loop (Camera Manipulation - 100% Universal on ALL Executors)
local function RunAimbotStep()
    if not Config.Combat.Aimbot then return end
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end

    local targetPart = GetClosestTarget()
    if targetPart then
        local targetPos = targetPart.Position
        if Config.Combat.Smoothness <= 1 then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetPos)
        else
            local currentLook = Camera.CFrame.LookVector
            local targetLook = (targetPos - Camera.CFrame.Position).Unit
            local newLook = currentLook:Lerp(targetLook, 1 / Config.Combat.Smoothness)
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + newLook)
        end
    end
end

-- =============================================================================
-- UNIVERSAL DUAL-ENGINE ESP (NATIVE ROBLOX INSTANCES + DRAWING API)
-- =============================================================================
local ESP = {
    Tracked = {}
}

function ESP:GetColor(player)
    if not Config.Visuals.TeamColor then
        return Config.Visuals.DefaultColor
    end
    if IsERLC then
        local faction = GetPlayerFaction(player)
        if faction == "Police" then
            return Config.Visuals.CopsColor
        elseif faction == "Criminal" then
            return Config.Visuals.CriminalsColor
        else
            return Config.Visuals.CiviliansColor
        end
    else
        if player.TeamColor then
            return player.TeamColor.Color
        end
        return Config.Visuals.DefaultColor
    end
end

function ESP:CreateForPlayer(player)
    if player == LocalPlayer then return end
    self:RemoveForPlayer(player)

    local data = {
        Player = player,
        Highlight = nil,
        Billboard = nil,
        DrawingBox = nil,
        DrawingTracer = nil,
        DrawingText = nil
    }

    -- 1. Native Universal Engine: Roblox Highlight (Works everywhere)
    pcall(function()
        local hl = Instance.new("Highlight")
        hl.Name = "ApexHighlight"
        hl.FillColor = self:GetColor(player)
        hl.FillTransparency = 0.5
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.OutlineTransparency = 0.1
        hl.Enabled = false
        hl.Parent = CoreGui
        data.Highlight = hl
        table.insert(Cleaners.Highlights, hl)
    end)

    -- 2. Native BillboardGui: Name, Distance & Health Info
    pcall(function()
        local bb = Instance.new("BillboardGui")
        bb.Name = "ApexBillboard"
        bb.Size = UDim2.new(0, 150, 0, 50)
        bb.StudsOffset = Vector3.new(0, 2.8, 0)
        bb.AlwaysOnTop = true
        bb.Enabled = false

        local text = Instance.new("TextLabel")
        text.Name = "Info"
        text.Size = UDim2.new(1, 0, 1, 0)
        text.BackgroundTransparency = 1
        text.Font = Enum.Font.GothamBold
        text.TextSize = 12
        text.TextColor3 = Color3.fromRGB(255, 255, 255)
        text.TextStrokeTransparency = 0.3
        text.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        text.Text = player.DisplayName
        text.Parent = bb

        bb.Parent = CoreGui
        data.Billboard = bb
        table.insert(Cleaners.Billboards, bb)
    end)

    -- 3. Drawing API Engine (Optional, active only if supported)
    if Capabilities.Drawing then
        pcall(function()
            local box = Drawing.new("Square")
            box.Thickness = 1.2
            box.Filled = false
            box.Visible = false
            data.DrawingBox = box
            table.insert(Cleaners.Drawings, box)

            local tracer = Drawing.new("Line")
            tracer.Thickness = 1.2
            tracer.Visible = false
            data.DrawingTracer = tracer
            table.insert(Cleaners.Drawings, tracer)

            local dText = Drawing.new("Text")
            dText.Size = 12
            dText.Center = true
            dText.Outline = true
            dText.Visible = false
            data.DrawingText = dText
            table.insert(Cleaners.Drawings, dText)
        end)
    end

    self.Tracked[player] = data
end

function ESP:RemoveForPlayer(player)
    local data = self.Tracked[player]
    if data then
        if data.Highlight then pcall(function() data.Highlight:Destroy() end) end
        if data.Billboard then pcall(function() data.Billboard:Destroy() end) end
        if data.DrawingBox then pcall(function() data.DrawingBox:Remove() end) end
        if data.DrawingTracer then pcall(function() data.DrawingTracer:Remove() end) end
        if data.DrawingText then pcall(function() data.DrawingText:Remove() end) end
        self.Tracked[player] = nil
    end
end

function ESP:Update()
    if not Config.Visuals.Enabled then
        for _, data in pairs(self.Tracked) do
            if data.Highlight then data.Highlight.Enabled = false end
            if data.Billboard then data.Billboard.Enabled = false end
            if data.DrawingBox then data.DrawingBox.Visible = false end
            if data.DrawingTracer then data.DrawingTracer.Visible = false end
            if data.DrawingText then data.DrawingText.Visible = false end
        end
        return
    end

    for player, data in pairs(self.Tracked) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChild("Humanoid")

        if char and hrp and hum and hum.Health > 0 then
            local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
            local color = self:GetColor(player)

            if dist <= Config.Visuals.MaxDistance then
                -- Native Highlight Update
                if data.Highlight then
                    data.Highlight.Adornee = char
                    data.Highlight.FillColor = color
                    data.Highlight.Enabled = true
                end

                -- Native Billboard Update
                if data.Billboard then
                    data.Billboard.Adornee = hrp
                    local infoLabel = data.Billboard:FindFirstChild("Info")
                    if infoLabel then
                        local content = ""
                        if Config.Visuals.Names then
                            content = (IsERLC and string.format("[%s] ", GetPlayerFaction(player)) or "") .. player.DisplayName
                        end
                        if Config.Visuals.Health then
                            content = content .. string.format(" | %d HP", math.floor(hum.Health))
                        end
                        if Config.Visuals.Distance then
                            content = content .. string.format(" [%dm]", math.floor(dist))
                        end
                        infoLabel.Text = content
                        infoLabel.TextColor3 = color
                    end
                    data.Billboard.Enabled = true
                end

                -- Drawing API Update (if active)
                if data.DrawingBox and data.DrawingTracer and data.DrawingText then
                    local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        local head = char:FindFirstChild("Head")
                        local headPos = head and Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0)) or pos
                        local legPos = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height * 0.65
                        local topLeft = Vector2.new(pos.X - width / 2, headPos.Y)

                        if Config.Visuals.Boxes then
                            data.DrawingBox.Size = Vector2.new(width, height)
                            data.DrawingBox.Position = topLeft
                            data.DrawingBox.Color = color
                            data.DrawingBox.Visible = true
                        else
                            data.DrawingBox.Visible = false
                        end

                        if Config.Visuals.Tracers then
                            data.DrawingTracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            data.DrawingTracer.To = Vector2.new(pos.X, pos.Y)
                            data.DrawingTracer.Color = color
                            data.DrawingTracer.Visible = true
                        else
                            data.DrawingTracer.Visible = false
                        end
                    else
                        data.DrawingBox.Visible = false
                        data.DrawingTracer.Visible = false
                    end
                end
            else
                if data.Highlight then data.Highlight.Enabled = false end
                if data.Billboard then data.Billboard.Enabled = false end
                if data.DrawingBox then data.DrawingBox.Visible = false end
                if data.DrawingTracer then data.DrawingTracer.Visible = false end
                if data.DrawingText then data.DrawingText.Visible = false end
            end
        else
            if data.Highlight then data.Highlight.Enabled = false end
            if data.Billboard then data.Billboard.Enabled = false end
            if data.DrawingBox then data.DrawingBox.Visible = false end
            if data.DrawingTracer then data.DrawingTracer.Visible = false end
            if data.DrawingText then data.DrawingText.Visible = false end
        end
    end
end

-- =============================================================================
-- UNIVERSAL MOVEMENT & PHYSICS ENGINE
-- =============================================================================
local FlyBV = nil
local FlyBG = nil

local function UpdateMovement(dt)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end

    -- 1. Universal CFrame WalkSpeed (Works in ALL games, zero humanoid property changes)
    if Config.Movement.CFrameSpeed and hum.MoveDirection.Magnitude > 0 then
        local extraSpeed = math.max(0, Config.Movement.SpeedValue - 16)
        local offset = hum.MoveDirection.Unit * (extraSpeed * dt)
        hrp.CFrame = hrp.CFrame + offset
    end

    -- 2. Universal Noclip (Works in ALL games)
    if Config.Movement.Noclip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end

    -- 3. Universal Flight Engine (Works in ALL games)
    if Config.Movement.Fly then
        if not FlyBV or not FlyBV.Parent then
            FlyBV = Instance.new("BodyVelocity")
            FlyBV.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            FlyBV.Parent = hrp

            FlyBG = Instance.new("BodyGyro")
            FlyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            FlyBG.CFrame = hrp.CFrame
            FlyBG.Parent = hrp

            table.insert(Cleaners.Instances, FlyBV)
            table.insert(Cleaners.Instances, FlyBG)
        end

        local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            move = move - Vector3.new(0, 1, 0)
        end

        if move.Magnitude > 0 then
            FlyBV.Velocity = move.Unit * Config.Movement.FlySpeed
        else
            FlyBV.Velocity = Vector3.zero
        end
        FlyBG.CFrame = Camera.CFrame
    else
        if FlyBV then pcall(function() FlyBV:Destroy() end) FlyBV = nil end
        if FlyBG then pcall(function() FlyBG:Destroy() end) FlyBG = nil end
    end
end

-- Universal Infinite Jump
RegisterConnection(UserInputService.JumpRequest:Connect(function()
    if Config.Movement.InfiniteJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
            if Config.Movement.HighJump then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Velocity = Vector3.new(hrp.Velocity.X, Config.Movement.HighJumpPower, hrp.Velocity.Z)
                end
            end
        end
    end
end))

-- =============================================================================
-- UNIVERSAL TELEPORTATION ENGINE
-- =============================================================================
local Teleport = {}

function Teleport:ToCFrame(targetCFrame)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    if not Config.Teleport.SafeMode then
        hrp.CFrame = targetCFrame
        return true
    end

    -- Incremental stepping to avoid server distance disconnects
    local startPos = hrp.Position
    local targetPos = targetCFrame.Position
    local dist = (targetPos - startPos).Magnitude
    local steps = math.max(1, math.ceil(dist / Config.Teleport.SafeStepDistance))

    Console:Log("INFO", string.format("Safe-stepping %d studs in %d increments...", math.floor(dist), steps))

    task.spawn(function()
        for i = 1, steps do
            if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then break end
            local alpha = i / steps
            local currentPos = startPos:Lerp(targetPos, alpha)
            LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(currentPos, currentPos + targetCFrame.LookVector)
            task.wait(Config.Teleport.SafeStepDelay)
        end
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            LocalPlayer.Character.HumanoidRootPart.CFrame = targetCFrame
        end
        Console:Log("INFO", "Teleportation reached target coordinate.")
    end)
    return true
end

function Teleport:ToPlayer(targetPlayer, behindOffset)
    if not targetPlayer or not targetPlayer.Character then
        Console:Log("WARN", "Player is invalid or not in character.")
        return
    end
    local hrp = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dest
    if behindOffset then
        dest = hrp.CFrame - (hrp.CFrame.LookVector * behindOffset)
    else
        dest = hrp.CFrame + Vector3.new(0, 3, 0)
    end
    self:ToCFrame(dest)
end

-- =============================================================================
-- UNIVERSAL UTILITIES (FULLBRIGHT, ANTI-AFK, FOV CHANGER)
-- =============================================================================
local function ApplyFullbright(enable)
    if enable then
        Cleaners.LightingRestore.Ambient = Lighting.Ambient
        Cleaners.LightingRestore.OutdoorAmbient = Lighting.OutdoorAmbient
        Cleaners.LightingRestore.Brightness = Lighting.Brightness
        Cleaners.LightingRestore.FogEnd = Lighting.FogEnd
        Cleaners.LightingRestore.GlobalShadows = Lighting.GlobalShadows

        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd = 9e9
        Lighting.GlobalShadows = false
        Console:Log("INFO", "Fullbright visual illumination active.")
    else
        if Cleaners.LightingRestore.Ambient then
            Lighting.Ambient = Cleaners.LightingRestore.Ambient
            Lighting.OutdoorAmbient = Cleaners.LightingRestore.OutdoorAmbient
            Lighting.Brightness = Cleaners.LightingRestore.Brightness
            Lighting.FogEnd = Cleaners.LightingRestore.FogEnd
            Lighting.GlobalShadows = Cleaners.LightingRestore.GlobalShadows
        end
    end
end

-- Anti-AFK (Prevents 20-minute idle disconnects in any game)
RegisterConnection(LocalPlayer.Idled:Connect(function()
    if Config.Universal.AntiAFK then
        if VirtualUser then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.zero)
            Console:Log("INFO", "Anti-AFK: Captured idle ping and simulated input.")
        end
    end
end))

-- =============================================================================
-- SPECIALIZED ERLC AUTOMATION MODULES
-- =============================================================================
local ERLCManager = {
    IsRobbing = false,
    Locations = {
        ["Police Department"] = Vector3.new(125, 45, -310),
        ["Sheriff Office"] = Vector3.new(-850, 42, 600),
        ["Hospital / EMS"] = Vector3.new(310, 42, 520),
        ["Bank & Vault"] = Vector3.new(20, 42, 110),
        ["Gun Shop / Tool Store"] = Vector3.new(-410, 42, 85),
        ["Car Dealership"] = Vector3.new(50, 42, -500),
        ["Fire Department"] = Vector3.new(210, 42, 230),
        ["Mafia Compound"] = Vector3.new(-1200, 40, -800),
    }
}

function ERLCManager:FindNearestATM()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end

    local closest = nil
    local minDist = math.huge

    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc:IsA("Model") or desc:IsA("BasePart") then
            local name = desc.Name:lower()
            if string.find(name, "atm") or string.find(name, "cashmachine") then
                local part = desc:IsA("BasePart") and desc or desc:FindFirstChildWhichIsA("BasePart")
                if part then
                    local dist = (hrp.Position - part.Position).Magnitude
                    if dist < minDist then
                        minDist = dist
                        closest = {
                            Model = desc,
                            Part = part,
                            Prompt = desc:FindFirstChildWhichIsA("ProximityPrompt", true)
                        }
                    end
                end
            end
        end
    end
    return closest
end

function ERLCManager:EquipRFID()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local char = LocalPlayer.Character
    if not backpack or not char then return false end

    for _, tool in ipairs(backpack:GetChildren()) do
        local name = tool.Name:lower()
        if string.find(name, "rfid") or string.find(name, "disruptor") or string.find(name, "hack") then
            tool.Parent = char
            Console:Log("INFO", "Equipped RFID Disruptor tool: " .. tool.Name)
            return true
        end
    end
    return false
end

function ERLCManager:AutomateATM()
    if self.IsRobbing then return end
    self.IsRobbing = true

    task.spawn(function()
        Console:Log("INFO", "Starting automated ATM extraction...")
        local atm = self:FindNearestATM()
        if not atm then
            Console:Log("WARN", "No ATM model located in immediate workspace partition.")
            self.IsRobbing = false
            return
        end

        if Config.ERLC.AutoEquipRFID then
            self:EquipRFID()
            task.wait(0.4)
        end

        Console:Log("INFO", "Navigating to ATM coordinate...")
        local destCFrame = CFrame.new(atm.Part.Position + Vector3.new(0, 0, 3.5), atm.Part.Position)
        Teleport:ToCFrame(destCFrame)
        task.wait(1)

        if atm.Prompt and Capabilities.FireProximityPrompt then
            Console:Log("INFO", "Triggering ProximityPrompt...")
            fireproximityprompt(atm.Prompt, 1)
        end

        -- Monitor and auto-solve minigame
        if Config.ERLC.AutoMinigame then
            task.wait(1.5)
            local pGui = LocalPlayer:FindFirstChild("PlayerGui")
            if pGui then
                for _, gui in ipairs(pGui:GetChildren()) do
                    if gui:IsA("ScreenGui") and gui.Enabled then
                        local gName = gui.Name:lower()
                        if string.find(gName, "atm") or string.find(gName, "rob") or string.find(gName, "hack") or string.find(gName, "minigame") then
                            for _, btn in ipairs(gui:GetDescendants()) do
                                if btn:IsA("TextButton") or btn:IsA("ImageButton") then
                                    local delay = math.random(Config.ERLC.MinigameDelayMin * 100, Config.ERLC.MinigameDelayMax * 100) / 100
                                    task.wait(delay)
                                    pcall(function()
                                        if Capabilities.GetConnections then
                                            for _, conn in pairs(getconnections(btn.MouseButton1Click)) do conn:Fire() end
                                        end
                                    end)
                                end
                            end
                        end
                    end
                end
            end
        end

        task.wait(3.5)
        Console:Log("INFO", "ATM extraction sequence complete.")
        self.IsRobbing = false
    end)
end

-- =============================================================================
-- PREMIUM HIGH-FIDELITY VECTOR USER INTERFACE
-- =============================================================================
local UI = {
    ScreenGui = nil,
    MainWindow = nil,
    Sidebar = nil,
    ContentArea = nil,
    Tabs = {},
    TabButtons = {},
    ActiveTab = nil,
    IsVisible = true,
}

local Theme = {
    Background = Color3.fromRGB(15, 17, 24),
    Sidebar = Color3.fromRGB(19, 23, 34),
    Header = Color3.fromRGB(24, 28, 42),
    Card = Color3.fromRGB(22, 26, 38),
    CardBorder = Color3.fromRGB(36, 42, 60),
    Accent = Color3.fromRGB(59, 130, 246),
    AccentHover = Color3.fromRGB(96, 165, 250),
    TextPrimary = Color3.fromRGB(245, 247, 250),
    TextSecondary = Color3.fromRGB(156, 163, 175),
    Success = Color3.fromRGB(34, 197, 94),
    Danger = Color3.fromRGB(239, 68, 68),
    Warning = Color3.fromRGB(234, 179, 8)
}

local function GetSafeGuiParent()
    if Capabilities.GetHui then
        local s, res = pcall(gethui)
        if s and res then return res end
    end
    local s, res = pcall(function() return CoreGui end)
    if s and res then return res end
    return LocalPlayer:WaitForChild("PlayerGui")
end

function UI:Init()
    local parent = GetSafeGuiParent()
    local gui = Instance.new("ScreenGui")
    gui.Name = "ApexUniversal_" .. math.random(10000, 99999)
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    if Capabilities.ProtectGui then
        pcall(syn.protect_gui, gui)
    end
    gui.Parent = parent
    self.ScreenGui = gui
    table.insert(Cleaners.Instances, gui)

    -- Setup FOV visual fallback
    SetupFOVCircle(gui)

    -- Main Frame
    local main = Instance.new("Frame")
    main.Name = "MainFrame"
    main.Size = UDim2.new(0, 700, 0, 460)
    main.Position = UDim2.new(0.5, -350, 0.5, -230)
    main.BackgroundColor3 = Theme.Background
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    main.Parent = gui
    self.MainWindow = main

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Theme.CardBorder
    mainStroke.Thickness = 1.2
    mainStroke.Parent = main

    -- Header / Title Bar
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 48)
    header.BackgroundColor3 = Theme.Header
    header.BorderSizePixel = 0
    header.Parent = main

    local title = Instance.new("TextLabel")
    title.Text = "APEX HUB  //  " .. (IsERLC and "ERLC EDITION" or "UNIVERSAL")
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextColor3 = Theme.TextPrimary
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Position = UDim2.new(0, 18, 0, 0)
    title.Size = UDim2.new(0, 260, 1, 0)
    title.BackgroundTransparency = 1
    title.Parent = header

    -- Status Badge
    local badge = Instance.new("Frame")
    badge.Size = UDim2.new(0, 90, 0, 22)
    badge.Position = UDim2.new(0, 280, 0.5, -11)
    badge.BackgroundColor3 = Color3.fromRGB(20, 45, 30)
    badge.BorderSizePixel = 0
    badge.Parent = header

    local badgeCorner = Instance.new("UICorner")
    badgeCorner.CornerRadius = UDim.new(0, 4)
    badgeCorner.Parent = badge

    local badgeText = Instance.new("TextLabel")
    badgeText.Text = "● ACTIVE"
    badgeText.Font = Enum.Font.GothamBold
    badgeText.TextSize = 10
    badgeText.TextColor3 = Theme.Success
    badgeText.Size = UDim2.new(1, 0, 1, 0)
    badgeText.BackgroundTransparency = 1
    badgeText.Parent = badge

    -- Header Controls (Minimize & Clean Unload)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseBtn"
    closeBtn.Text = "✕"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    closeBtn.TextColor3 = Theme.TextSecondary
    closeBtn.Size = UDim2.new(0, 32, 0, 32)
    closeBtn.Position = UDim2.new(1, -42, 0.5, -16)
    closeBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = header

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        _G.ApexHubUnload()
    end)

    local minBtn = Instance.new("TextButton")
    minBtn.Name = "MinBtn"
    minBtn.Text = "—"
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    minBtn.TextColor3 = Theme.TextSecondary
    minBtn.Size = UDim2.new(0, 32, 0, 32)
    minBtn.Position = UDim2.new(1, -80, 0.5, -16)
    minBtn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
    minBtn.BorderSizePixel = 0
    minBtn.Parent = header

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minBtn

    minBtn.MouseButton1Click:Connect(function()
        self.IsVisible = not self.IsVisible
        main.Visible = self.IsVisible
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Name = "Sidebar"
    sidebar.Size = UDim2.new(0, 155, 1, -48)
    sidebar.Position = UDim2.new(0, 0, 0, 48)
    sidebar.BackgroundColor3 = Theme.Sidebar
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main
    self.Sidebar = sidebar

    local sideList = Instance.new("UIListLayout")
    sideList.Padding = UDim.new(0, 5)
    sideList.SortOrder = Enum.SortOrder.LayoutOrder
    sideList.HorizontalAlignment = Enum.HorizontalAlignment.Center
    sideList.Parent = sidebar

    local sidePad = Instance.new("UIPadding")
    sidePad.PaddingTop = UDim.new(0, 10)
    sidePad.Parent = sidebar

    -- Content Area
    local content = Instance.new("Frame")
    content.Name = "ContentArea"
    content.Size = UDim2.new(1, -155, 1, -48)
    content.Position = UDim2.new(0, 155, 0, 48)
    content.BackgroundTransparency = 1
    content.Parent = main
    self.ContentArea = content

    -- Header Dragging
    local dragging, dragInput, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    header.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)

    RegisterConnection(UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end))
end

function UI:CreateTab(name, layoutOrder)
    local tabBtn = Instance.new("TextButton")
    tabBtn.Name = name .. "TabBtn"
    tabBtn.Text = name:upper()
    tabBtn.Font = Enum.Font.GothamSemibold
    tabBtn.TextSize = 12
    tabBtn.TextColor3 = Theme.TextSecondary
    tabBtn.Size = UDim2.new(0.9, 0, 0, 36)
    tabBtn.BackgroundColor3 = Color3.fromRGB(24, 28, 40)
    tabBtn.BackgroundTransparency = 1
    tabBtn.BorderSizePixel = 0
    tabBtn.LayoutOrder = layoutOrder or 1
    tabBtn.Parent = self.Sidebar

    local tabCorner = Instance.new("UICorner")
    tabCorner.CornerRadius = UDim.new(0, 6)
    tabCorner.Parent = tabBtn

    local tabFrame = Instance.new("ScrollingFrame")
    tabFrame.Name = name .. "TabFrame"
    tabFrame.Size = UDim2.new(1, 0, 1, 0)
    tabFrame.BackgroundTransparency = 1
    tabFrame.BorderSizePixel = 0
    tabFrame.ScrollBarThickness = 3
    tabFrame.ScrollBarImageColor3 = Theme.CardBorder
    tabFrame.Visible = false
    tabFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabFrame.Parent = self.ContentArea

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    listLayout.Parent = tabFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)
    pad.Parent = tabFrame

    self.TabButtons[name] = tabBtn
    self.Tabs[name] = tabFrame

    tabBtn.MouseButton1Click:Connect(function()
        self:SelectTab(name)
    end)

    return tabFrame
end

function UI:SelectTab(name)
    for tabName, frame in pairs(self.Tabs) do
        frame.Visible = (tabName == name)
    end
    for tabName, btn in pairs(self.TabButtons) do
        local active = (tabName == name)
        TweenService:Create(btn, TweenInfo.new(0.2), {
            BackgroundTransparency = active and 0 or 1,
            BackgroundColor3 = active and Theme.Card or Color3.fromRGB(24, 28, 40),
            TextColor3 = active and Theme.Accent or Theme.TextSecondary
        }):Play()
    end
    self.ActiveTab = name
end

function UI:CreateToggle(parent, title, defaultState, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 44)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Theme.CardBorder
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = Theme.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(0.7, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Parent = card

    local switch = Instance.new("TextButton")
    switch.Text = ""
    switch.Size = UDim2.new(0, 44, 0, 24)
    switch.Position = UDim2.new(1, -56, 0.5, -12)
    switch.BackgroundColor3 = defaultState and Theme.Accent or Color3.fromRGB(36, 42, 60)
    switch.BorderSizePixel = 0
    switch.Parent = card

    local switchCorner = Instance.new("UICorner")
    switchCorner.CornerRadius = UDim.new(1, 0)
    switchCorner.Parent = switch

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = defaultState and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = switch

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local state = defaultState
    switch.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(switch, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(36, 42, 60)
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.2), {
            Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        }):Play()
        callback(state)
    end)

    return card
end

function UI:CreateSlider(parent, title, minVal, maxVal, defaultVal, suffix, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 60)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Theme.CardBorder
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = Theme.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Position = UDim2.new(0, 14, 0, 8)
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Parent = card

    local valueLabel = Instance.new("TextLabel")
    valueLabel.Text = tostring(defaultVal) .. (suffix or "")
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 12
    valueLabel.TextColor3 = Theme.Accent
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Position = UDim2.new(0.6, 0, 0, 8)
    valueLabel.Size = UDim2.new(0.4, -14, 0, 20)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Parent = card

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -28, 0, 6)
    barBg.Position = UDim2.new(0, 14, 0, 38)
    barBg.BackgroundColor3 = Color3.fromRGB(36, 42, 60)
    barBg.BorderSizePixel = 0
    barBg.Parent = card

    local barBgCorner = Instance.new("UICorner")
    barBgCorner.CornerRadius = UDim.new(1, 0)
    barBgCorner.Parent = barBg

    local defaultPct = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(defaultPct, 0, 1, 0)
    fill.BackgroundColor3 = Theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = barBg

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = fill

    local sliding = false
    local function UpdateSlide(input)
        local posX = math.clamp((input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(posX, 0, 1, 0)
        local computedVal = math.floor(minVal + (maxVal - minVal) * posX)
        valueLabel.Text = tostring(computedVal) .. (suffix or "")
        callback(computedVal)
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
            UpdateSlide(input)
        end
    end)

    RegisterConnection(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end))

    RegisterConnection(UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            UpdateSlide(input)
        end
    end))

    return card
end

function UI:CreateButton(parent, title, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 40)
    button.BackgroundColor3 = Theme.Card
    button.BorderSizePixel = 0
    button.Text = title
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 13
    button.TextColor3 = Theme.TextPrimary
    button.Parent = parent

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button

    local btnStroke = Instance.new("UIStroke")
    btnStroke.Color = Theme.CardBorder
    btnStroke.Thickness = 1
    btnStroke.Parent = button

    button.MouseButton1Click:Connect(function()
        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundColor3 = Theme.Accent}):Play()
        task.wait(0.1)
        TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = Theme.Card}):Play()
        callback()
    end)

    return button
end

function UI:CreateDropdown(parent, title, options, defaultOption, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 44)
    card.BackgroundColor3 = Theme.Card
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Parent = parent

    local cardCorner = Instance.new("UICorner")
    cardCorner.CornerRadius = UDim.new(0, 6)
    cardCorner.Parent = card

    local cardStroke = Instance.new("UIStroke")
    cardStroke.Color = Theme.CardBorder
    cardStroke.Thickness = 1
    cardStroke.Parent = card

    local label = Instance.new("TextLabel")
    label.Text = title
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 13
    label.TextColor3 = Theme.TextPrimary
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Position = UDim2.new(0, 14, 0, 0)
    label.Size = UDim2.new(0.45, 0, 0, 44)
    label.BackgroundTransparency = 1
    label.Parent = card

    local selectBtn = Instance.new("TextButton")
    selectBtn.Text = (defaultOption or "Select...") .. "  ▼"
    selectBtn.Font = Enum.Font.GothamSemibold
    selectBtn.TextSize = 12
    selectBtn.TextColor3 = Theme.Accent
    selectBtn.BackgroundColor3 = Color3.fromRGB(28, 33, 48)
    selectBtn.Size = UDim2.new(0.5, -14, 0, 28)
    selectBtn.Position = UDim2.new(0.5, 0, 0, 8)
    selectBtn.BorderSizePixel = 0
    selectBtn.Parent = card

    local selCorner = Instance.new("UICorner")
    selCorner.CornerRadius = UDim.new(0, 4)
    selCorner.Parent = selectBtn

    local optionsList = Instance.new("Frame")
    optionsList.Size = UDim2.new(1, -28, 0, 0)
    optionsList.Position = UDim2.new(0, 14, 0, 48)
    optionsList.BackgroundTransparency = 1
    optionsList.Parent = card

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = optionsList

    local isExpanded = false
    local function ToggleExpand()
        isExpanded = not isExpanded
        local targetHeight = isExpanded and (48 + #options * 32 + 8) or 44
        selectBtn.Text = (card:GetAttribute("Selected") or defaultOption or "Select...") .. (isExpanded and "  ▲" or "  ▼")
        TweenService:Create(card, TweenInfo.new(0.25), {Size = UDim2.new(1, 0, 0, targetHeight)}):Play()
    end

    local function PopulateOptions(newOptions)
        for _, child in ipairs(optionsList:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        for _, opt in ipairs(newOptions) do
            local optBtn = Instance.new("TextButton")
            optBtn.Size = UDim2.new(1, 0, 0, 28)
            optBtn.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
            optBtn.Text = tostring(opt)
            optBtn.Font = Enum.Font.Gotham
            optBtn.TextSize = 12
            optBtn.TextColor3 = Theme.TextPrimary
            optBtn.BorderSizePixel = 0
            optBtn.Parent = optionsList

            local optCorner = Instance.new("UICorner")
            optCorner.CornerRadius = UDim.new(0, 4)
            optCorner.Parent = optBtn

            optBtn.MouseButton1Click:Connect(function()
                card:SetAttribute("Selected", tostring(opt))
                selectBtn.Text = tostring(opt) .. "  ▼"
                ToggleExpand()
                callback(opt)
            end)
        end
    end

    PopulateOptions(options)
    selectBtn.MouseButton1Click:Connect(ToggleExpand)

    card:SetAttribute("Refresh", function(updatedOptions)
        options = updatedOptions
        PopulateOptions(updatedOptions)
    end)

    return card
end

-- =============================================================================
-- INTERFACE POPULATION (ALL TABS & CATEGORIES)
-- =============================================================================
local function BuildHubUI()
    UI:Init()

    -- 1. COMBAT TAB
    local combatTab = UI:CreateTab("Combat", 1)
    UI:CreateToggle(combatTab, "Camera Aimbot (Hold Right Mouse)", Config.Combat.Aimbot, function(s)
        Config.Combat.Aimbot = s
        Console:Log("INFO", "Camera Aimbot state: " .. tostring(s))
    end)

    UI:CreateToggle(combatTab, "Silent Aim (Direct Raycast Intercept)", Config.Combat.SilentAim, function(s)
        Config.Combat.SilentAim = s
        Console:Log("INFO", "Silent Aim state: " .. tostring(s))
    end)

    UI:CreateToggle(combatTab, "Show FOV Circle", Config.Combat.ShowFOV, function(s)
        Config.Combat.ShowFOV = s
    end)

    UI:CreateSlider(combatTab, "FOV Circle Radius", 30, 400, Config.Combat.FOV, " px", function(v)
        Config.Combat.FOV = v
    end)

    UI:CreateSlider(combatTab, "Aimbot Smoothness Factor", 1, 15, Config.Combat.Smoothness, "x", function(v)
        Config.Combat.Smoothness = v
    end)

    UI:CreateDropdown(combatTab, "Target Hitbox Part", {"Head", "HumanoidRootPart", "Torso"}, Config.Combat.HitPart, function(v)
        Config.Combat.HitPart = v
        Console:Log("INFO", "Aimbot Hitbox updated: " .. v)
    end)

    UI:CreateToggle(combatTab, "Line of Sight Wall Check", Config.Combat.VisibleCheck, function(s)
        Config.Combat.VisibleCheck = s
    end)

    UI:CreateToggle(combatTab, "Team Check (Ignore Allies)", Config.Combat.TeamCheck, function(s)
        Config.Combat.TeamCheck = s
    end)

    -- 2. VISUALS (ESP) TAB
    local visualsTab = UI:CreateTab("Visuals", 2)
    UI:CreateToggle(visualsTab, "Master ESP Engine (Universal Highlights)", Config.Visuals.Enabled, function(s)
        Config.Visuals.Enabled = s
        Console:Log("INFO", "Master ESP: " .. tostring(s))
    end)

    UI:CreateToggle(visualsTab, "Player Nametags", Config.Visuals.Names, function(s)
        Config.Visuals.Names = s
    end)

    UI:CreateToggle(visualsTab, "Player Distance Readings", Config.Visuals.Distance, function(s)
        Config.Visuals.Distance = s
    end)

    UI:CreateToggle(visualsTab, "Dynamic Health Values", Config.Visuals.Health, function(s)
        Config.Visuals.Health = s
    end)

    UI:CreateToggle(visualsTab, "Faction / Team Coloring", Config.Visuals.TeamColor, function(s)
        Config.Visuals.TeamColor = s
    end)

    if Capabilities.Drawing then
        UI:CreateToggle(visualsTab, "Drawing 2D Boxes (PC/Executor)", Config.Visuals.Boxes, function(s)
            Config.Visuals.Boxes = s
        end)

        UI:CreateToggle(visualsTab, "Drawing Snapline Tracers", Config.Visuals.Tracers, function(s)
            Config.Visuals.Tracers = s
        end)
    end

    UI:CreateSlider(visualsTab, "ESP Render Distance", 200, 4000, Config.Visuals.MaxDistance, " studs", function(v)
        Config.Visuals.MaxDistance = v
    end)

    -- 3. MOVEMENT TAB
    local movementTab = UI:CreateTab("Movement", 3)
    UI:CreateToggle(movementTab, "CFrame Speed Booster (Anti-Cheat Proof)", Config.Movement.CFrameSpeed, function(s)
        Config.Movement.CFrameSpeed = s
        Console:Log("INFO", "CFrame WalkSpeed Booster: " .. tostring(s))
    end)

    UI:CreateSlider(movementTab, "WalkSpeed Velocity", 16, 90, Config.Movement.SpeedValue, " studs/s", function(v)
        Config.Movement.SpeedValue = v
    end)

    UI:CreateToggle(movementTab, "Universal Flight Controller (WASD+Space)", Config.Movement.Fly, function(s)
        Config.Movement.Fly = s
        Console:Log("INFO", "Flight mode: " .. tostring(s))
    end)

    UI:CreateSlider(movementTab, "Flight Speed", 20, 150, Config.Movement.FlySpeed, " studs/s", function(v)
        Config.Movement.FlySpeed = v
    end)

    UI:CreateToggle(movementTab, "Infinite Jump State", Config.Movement.InfiniteJump, function(s)
        Config.Movement.InfiniteJump = s
    end)

    UI:CreateToggle(movementTab, "Super High Jump", Config.Movement.HighJump, function(s)
        Config.Movement.HighJump = s
    end)

    UI:CreateSlider(movementTab, "Jump Power Impulse", 50, 200, Config.Movement.HighJumpPower, " pow", function(v)
        Config.Movement.HighJumpPower = v
    end)

    UI:CreateToggle(movementTab, "Noclip (World Collision Bypass)", Config.Movement.Noclip, function(s)
        Config.Movement.Noclip = s
        Console:Log("INFO", "Noclip collision state: " .. tostring(s))
    end)

    -- 4. TELEPORT TAB
    local teleportTab = UI:CreateTab("Teleport", 4)
    UI:CreateToggle(teleportTab, "Anti-Rubberband Stepping (Safe Mode)", Config.Teleport.SafeMode, function(s)
        Config.Teleport.SafeMode = s
    end)

    -- Dynamic Player Dropdown
    local playerNames = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(playerNames, p.DisplayName) end
    end
    local playerDropdown = UI:CreateDropdown(teleportTab, "Select Target Player", playerNames, playerNames[1] or "No players", function(chosen)
        for _, p in ipairs(Players:GetPlayers()) do
            if p.DisplayName == chosen or p.Name == chosen then
                Config.Teleport.SelectedPlayer = p
                break
            end
        end
    end)

    UI:CreateButton(teleportTab, "Refresh Server Player List", function()
        local updated = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then table.insert(updated, p.DisplayName) end
        end
        local refreshFn = playerDropdown:GetAttribute("Refresh")
        if refreshFn then refreshFn(updated) end
        Console:Log("INFO", string.format("Player list updated (%d players).", #updated))
    end)

    UI:CreateButton(teleportTab, "Teleport to Selected Player", function()
        if Config.Teleport.SelectedPlayer then
            Teleport:ToPlayer(Config.Teleport.SelectedPlayer)
        else
            Console:Log("WARN", "Please select a player first.")
        end
    end)

    UI:CreateButton(teleportTab, "Teleport Behind Selected Player", function()
        if Config.Teleport.SelectedPlayer then
            Teleport:ToPlayer(Config.Teleport.SelectedPlayer, 5)
        else
            Console:Log("WARN", "Please select a player first.")
        end
    end)

    UI:CreateButton(teleportTab, "Click TP (Press Ctrl + Click in Game)", function()
        Console:Log("INFO", "Hold LeftControl and Click anywhere in the world to teleport.")
    end)

    -- 5. UNIVERSAL TAB
    local univTab = UI:CreateTab("Universal", 5)
    UI:CreateToggle(univTab, "Fullbright (Max Ambient & Visibility)", Config.Universal.Fullbright, function(s)
        Config.Universal.Fullbright = s
        ApplyFullbright(s)
    end)

    UI:CreateToggle(univTab, "Anti-AFK (Prevent 20m Idle Kick)", Config.Universal.AntiAFK, function(s)
        Config.Universal.AntiAFK = s
        Console:Log("INFO", "Anti-AFK system: " .. tostring(s))
    end)

    UI:CreateSlider(univTab, "Custom Camera FOV", 70, 120, 70, "°", function(v)
        Camera.FieldOfView = v
    end)

    UI:CreateButton(univTab, "Rejoin Same Server", function()
        Console:Log("INFO", "Rejoining server...")
        TeleportService:TeleportToPlaceInstance(PlaceId, game.JobId, LocalPlayer)
    end)

    UI:CreateButton(univTab, "Server Hop (New Instance)", function()
        Console:Log("INFO", "Hopping to alternative server...")
        pcall(function()
            local sfUrl = string.format("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Desc&limit=25", PlaceId)
            local res = game:HttpGet(sfUrl)
            local data = HttpService:JSONDecode(res)
            for _, s in ipairs(data.data) do
                if s.playing < s.maxPlayers and s.id ~= game.JobId then
                    TeleportService:TeleportToPlaceInstance(PlaceId, s.id, LocalPlayer)
                    break
                end
            end
        end)
    end)

    -- 6. ERLC SPECIAL TAB
    local erlcTab = UI:CreateTab("ERLC", 6)
    UI:CreateButton(erlcTab, "Auto Rob Nearest ATM (One-Click)", function()
        ERLCManager:AutomateATM()
    end)

    UI:CreateToggle(erlcTab, "Auto-Equip RFID Disruptor", Config.ERLC.AutoEquipRFID, function(s)
        Config.ERLC.AutoEquipRFID = s
    end)

    UI:CreateToggle(erlcTab, "Auto-Solve Minigame Helper", Config.ERLC.AutoMinigame, function(s)
        Config.ERLC.AutoMinigame = s
    end)

    UI:CreateToggle(erlcTab, "Prioritize Cops (Aimbot & Visuals)", Config.ERLC.TargetCopsOnly, function(s)
        Config.ERLC.TargetCopsOnly = s
    end)

    UI:CreateToggle(erlcTab, "Prioritize Criminals (Aimbot & Visuals)", Config.ERLC.TargetCriminalsOnly, function(s)
        Config.ERLC.TargetCriminalsOnly = s
    end)

    for locName, coords in pairs(ERLCManager.Locations) do
        UI:CreateButton(erlcTab, "Teleport: " .. locName, function()
            Teleport:ToCFrame(CFrame.new(coords + Vector3.new(0, 3, 0)))
        end)
    end

    -- 7. RUNTIME CONSOLE TAB
    local consoleTab = UI:CreateTab("Console", 7)
    local consoleBox = Instance.new("ScrollingFrame")
    consoleBox.Size = UDim2.new(1, 0, 0, 330)
    consoleBox.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
    consoleBox.BorderSizePixel = 0
    consoleBox.ScrollBarThickness = 4
    consoleBox.ScrollBarImageColor3 = Theme.CardBorder
    consoleBox.CanvasSize = UDim2.new(0, 0, 0, 0)
    consoleBox.AutomaticCanvasSize = Enum.AutomaticSize.Y
    consoleBox.Parent = consoleTab

    local consoleCorner = Instance.new("UICorner")
    consoleCorner.CornerRadius = UDim.new(0, 6)
    consoleCorner.Parent = consoleBox

    local logListLayout = Instance.new("UIListLayout")
    logListLayout.Padding = UDim.new(0, 2)
    logListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    logListLayout.Parent = consoleBox

    local logPad = Instance.new("UIPadding")
    logPad.PaddingLeft = UDim.new(0, 8)
    logPad.PaddingRight = UDim.new(0, 8)
    logPad.PaddingTop = UDim.new(0, 8)
    logPad.PaddingBottom = UDim.new(0, 8)
    logPad.Parent = consoleBox

    local function AppendLogEntry(entry)
        local line = Instance.new("TextLabel")
        line.Size = UDim2.new(1, 0, 0, 18)
        line.BackgroundTransparency = 1
        line.Font = Enum.Font.Code
        line.TextSize = 11
        line.TextXAlignment = Enum.TextXAlignment.Left

        local levelColor = Theme.TextSecondary
        if entry.Level == "SECURITY" then
            levelColor = Theme.Warning
        elseif entry.Level == "WARN" then
            levelColor = Theme.Warning
        elseif entry.Level == "ERROR" then
            levelColor = Theme.Danger
        elseif entry.Level == "INFO" then
            levelColor = Color3.fromRGB(56, 189, 248)
        end

        line.TextColor3 = levelColor
        line.Text = string.format("[%s] [%s] %s", entry.Time, entry.Level, entry.Message)
        line.Parent = consoleBox

        consoleBox.CanvasPosition = Vector2.new(0, consoleBox.AbsoluteCanvasSize.Y)
    end

    Console.OnLogAdded = AppendLogEntry
    for _, log in ipairs(Console.Logs) do
        AppendLogEntry(log)
    end

    UI:CreateButton(consoleTab, "Clear Console Buffer", function()
        for _, child in ipairs(consoleBox:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        Console.Logs = {}
        Console:Log("INFO", "Console buffer purged.")
    end)

    UI:SelectTab("Combat")
end

-- =============================================================================
-- RUNTIME LIFECYCLE & EVENT LOOPS
-- =============================================================================
local function SetupRuntimeLoops()
    -- Initialize ESP for current players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            ESP:CreateForPlayer(player)
        end
    end

    RegisterConnection(Players.PlayerAdded:Connect(function(player)
        ESP:CreateForPlayer(player)
    end))

    RegisterConnection(Players.PlayerRemoving:Connect(function(player)
        ESP:RemoveForPlayer(player)
    end))

    -- Main Render Loop
    RegisterConnection(RunService.RenderStepped:Connect(function(dt)
        UpdateFOVCircle()
        RunAimbotStep()
        ESP:Update()
    end))

    -- Movement and Physics Loop
    RegisterConnection(RunService.Heartbeat:Connect(function(dt)
        UpdateMovement(dt)
    end))

    -- Toggle UI visibility with RightControl / RightShift
    RegisterConnection(UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed then
            if input.KeyCode == Enum.KeyCode.RightControl or input.KeyCode == Enum.KeyCode.RightShift then
                UI.IsVisible = not UI.IsVisible
                if UI.MainWindow then
                    UI.MainWindow.Visible = UI.IsVisible
                end
            end

            -- Click TP handler (Ctrl + Click)
            if input.UserInputType == Enum.UserInputType.MouseButton1 and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
                if Mouse.Hit then
                    Teleport:ToCFrame(CFrame.new(Mouse.Hit.Position + Vector3.new(0, 3, 0)))
                    Console:Log("INFO", "Click-Teleported to " .. tostring(Mouse.Hit.Position))
                end
            end
        end
    end))
end

-- =============================================================================
-- UNLOAD HANDLER & DESTRUCTION HOOK
-- =============================================================================
_G.ApexHubUnload = function()
    Console:Log("INFO", "Unloading Apex Hub...")

    -- Disconnect all events
    for _, conn in ipairs(Cleaners.Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Cleaners.Connections = {}

    -- Clean ESP
    for player, _ in pairs(ESP.Tracked) do
        ESP:RemoveForPlayer(player)
    end

    -- Clean Drawings
    for _, drawing in ipairs(Cleaners.Drawings) do
        pcall(function()
            drawing.Visible = false
            drawing:Remove()
        end)
    end
    Cleaners.Drawings = {}

    -- Revert metatables
    for method, oldFunc in pairs(Cleaners.Hooks) do
        pcall(function()
            if Capabilities.HookMetamethod then
                hookmetamethod(game, method, oldFunc)
            end
        end)
    end
    Cleaners.Hooks = {}

    -- Restore Lighting
    ApplyFullbright(false)

    -- Destroy UI instances
    for _, inst in ipairs(Cleaners.Instances) do
        pcall(function() inst:Destroy() end)
    end
    Cleaners.Instances = {}

    _G.ApexHubLoaded = false
    Console:Log("INFO", "Unload complete. All traces purged from runtime.")
end

-- =============================================================================
-- BOOTSTRAP INITIALIZATION
-- =============================================================================
local success, err = pcall(function()
    InitializeMetatableProtection()
    BuildHubUI()
    SetupRuntimeLoops()
    Console:Log("INFO", "Apex Hub loaded successfully! Press RightControl to toggle menu.")
end)

if not success then
    warn("[Apex Hub Failure]: " .. tostring(err))
    pcall(function()
        Console:Log("ERROR", "Boot Failure: " .. tostring(err))
    end)
end
