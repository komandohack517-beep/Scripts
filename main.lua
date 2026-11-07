-- // Roblox ESP + Aimbot Suite
-- // Optimized for Delta Executor (Mobile + PC)
-- // Paste into Delta script executor and run

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- ============================================================
-- // CONFIG
-- ============================================================
getgenv().KanhaConfig = {
    ESP = {
        Enabled = true,
        Boxes = true,
        Names = true,
        Distance = true,
        Tracers = true,
        MaxDistance = 1000,
        BoxColor = Color3.fromRGB(255, 60, 60),
        NameColor = Color3.fromRGB(255, 255, 255),
        TracerColor = Color3.fromRGB(255, 60, 60),
        FriendColor = Color3.fromRGB(60, 255, 100),
        TeamCheck = false,
    },
    Aimbot = {
        Enabled = true,
        FOV = 150,
        Smoothness = 0.18,
        TargetPart = "Head",
        ShowFOV = true,
        Prediction = false,
        PredictionFactor = 0.09,
    },
    UI = {
        Accent     = Color3.fromRGB(220, 50, 50),
        Background = Color3.fromRGB(18, 18, 22),
        Secondary  = Color3.fromRGB(28, 28, 34),
        Text       = Color3.fromRGB(230, 230, 230),
        Muted      = Color3.fromRGB(120, 120, 130),
    }
}

local Cfg = getgenv().KanhaConfig

-- ============================================================
-- // DELTA DRAWING SAFETY WRAPPER
-- // Delta sometimes needs pcall on Drawing.new
-- ============================================================
local function NewDrawing(type)
    local ok, obj = pcall(Drawing.new, type)
    if ok then return obj end
    -- fallback: try again after brief yield
    task.wait(0.05)
    return Drawing.new(type)
end

-- ============================================================
-- // UTILITY
-- ============================================================
local function ToScreen(pos)
    local screen, depth, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screen.X, screen.Y), depth, onScreen
end

local function GetBox(character)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            local sx, sy = part.Size.X/2, part.Size.Y/2
            local sz = part.Size.Z/2
            local offsets = {
                Vector3.new( sx,  sy,  sz), Vector3.new(-sx,  sy,  sz),
                Vector3.new( sx, -sy,  sz), Vector3.new(-sx, -sy,  sz),
                Vector3.new( sx,  sy, -sz), Vector3.new(-sx,  sy, -sz),
                Vector3.new( sx, -sy, -sz), Vector3.new(-sx, -sy, -sz),
            }
            for _, off in ipairs(offsets) do
                local wPos = (part.CFrame * CFrame.new(off)).Position
                local sPos, depth, onScreen = ToScreen(wPos)
                if onScreen and depth > 0 then
                    if sPos.X < minX then minX = sPos.X end
                    if sPos.Y < minY then minY = sPos.Y end
                    if sPos.X > maxX then maxX = sPos.X end
                    if sPos.Y > maxY then maxY = sPos.Y end
                end
            end
        end
    end
    if minX == math.huge then return nil end
    return minX, minY, maxX, maxY
end

local function HideDrawings(drawings)
    for _, obj in pairs(drawings) do
        if type(obj) == "table" then
            for _, l in pairs(obj) do
                if l and l.Visible ~= nil then l.Visible = false end
            end
        else
            if obj and obj.Visible ~= nil then obj.Visible = false end
        end
    end
end

-- ============================================================
-- // ESP
-- ============================================================
local ESPObjects = {}

local function CreateESP(player)
    if player == LocalPlayer then return end

    local d = {}

    -- 4 box lines
    d.box = {}
    for i = 1, 4 do
        local l = NewDrawing("Line")
        l.Thickness = 1.5
        l.Color = Cfg.ESP.BoxColor
        l.Visible = false
        l.ZIndex = 2
        d.box[i] = l
    end

    -- Name
    d.name = NewDrawing("Text")
    d.name.Size = 13
    d.name.Color = Cfg.ESP.NameColor
    d.name.Center = true
    d.name.Outline = true
    d.name.OutlineColor = Color3.new(0, 0, 0)
    d.name.Font = Drawing.Fonts.UI
    d.name.Visible = false

    -- Distance
    d.dist = NewDrawing("Text")
    d.dist.Size = 11
    d.dist.Color = Cfg.ESP.Muted
    d.dist.Center = true
    d.dist.Outline = true
    d.dist.OutlineColor = Color3.new(0, 0, 0)
    d.dist.Font = Drawing.Fonts.UI
    d.dist.Visible = false

    -- Tracer
    d.tracer = NewDrawing("Line")
    d.tracer.Thickness = 1
    d.tracer.Color = Cfg.ESP.TracerColor
    d.tracer.Visible = false
    d.tracer.ZIndex = 1

    ESPObjects[player] = d
end

local function RemoveESP(player)
    local d = ESPObjects[player]
    if not d then return end
    for _, obj in pairs(d) do
        if type(obj) == "table" then
            for _, l in pairs(obj) do pcall(function() l:Remove() end) end
        else
            pcall(function() obj:Remove() end)
        end
    end
    ESPObjects[player] = nil
end

local function UpdateESP()
    local localChar = LocalPlayer.Character
    local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")

    for player, d in pairs(ESPObjects) do
        if not Cfg.ESP.Enabled then HideDrawings(d) continue end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChild("Humanoid")

        local dead = not char or not root or not hum or hum.Health <= 0
        local team = Cfg.ESP.TeamCheck and (player.Team == LocalPlayer.Team)
        local dist = localRoot and root
            and (localRoot.Position - root.Position).Magnitude or 9999
        local tooFar = dist > Cfg.ESP.MaxDistance

        if dead or team or tooFar then
            HideDrawings(d)
            continue
        end

        local color = Cfg.ESP.BoxColor
        if player.Team and player.Team == LocalPlayer.Team then
            color = Cfg.ESP.FriendColor
        end

        -- Box + labels
        local minX, minY, maxX, maxY = GetBox(char)
        if minX then
            if Cfg.ESP.Boxes then
                -- Top, Bottom, Left, Right
                d.box[1].From = Vector2.new(minX, minY); d.box[1].To = Vector2.new(maxX, minY)
                d.box[2].From = Vector2.new(minX, maxY); d.box[2].To = Vector2.new(maxX, maxY)
                d.box[3].From = Vector2.new(minX, minY); d.box[3].To = Vector2.new(minX, maxY)
                d.box[4].From = Vector2.new(maxX, minY); d.box[4].To = Vector2.new(maxX, maxY)
                for _, l in ipairs(d.box) do l.Color = color; l.Visible = true end
            else
                for _, l in ipairs(d.box) do l.Visible = false end
            end

            local midX = (minX + maxX) / 2

            if Cfg.ESP.Names then
                d.name.Position = Vector2.new(midX, minY - 16)
                d.name.Text = player.DisplayName
                d.name.Visible = true
            else
                d.name.Visible = false
            end

            if Cfg.ESP.Distance then
                d.dist.Position = Vector2.new(midX, maxY + 2)
                d.dist.Text = math.floor(dist) .. "m"
                d.dist.Visible = true
            else
                d.dist.Visible = false
            end
        else
            for _, l in ipairs(d.box) do l.Visible = false end
            d.name.Visible = false
            d.dist.Visible = false
        end

        -- Tracer
        if Cfg.ESP.Tracers then
            local footPos, _, onScreen = ToScreen(root.Position - Vector3.new(0, 2.5, 0))
            if onScreen then
                local vp = Camera.ViewportSize
                d.tracer.From = Vector2.new(vp.X / 2, vp.Y)
                d.tracer.To   = footPos
                d.tracer.Color = color
                d.tracer.Visible = true
            else
                d.tracer.Visible = false
            end
        else
            d.tracer.Visible = false
        end
    end
end

for _, p in ipairs(Players:GetPlayers()) do CreateESP(p) end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

-- ============================================================
-- // AIMBOT
-- ============================================================
local FOVCircle = NewDrawing("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Color = Color3.fromRGB(255, 255, 255)
FOVCircle.Filled = false
FOVCircle.Radius = Cfg.Aimbot.FOV
FOVCircle.Visible = Cfg.Aimbot.ShowFOV
FOVCircle.ZIndex = 5

local function GetTarget()
    local center = Camera.ViewportSize / 2
    local best, bestDist = nil, Cfg.Aimbot.FOV

    for _, p in ipairs(Players:GetPlayers()) do
        if p == LocalPlayer then continue end
        if Cfg.ESP.TeamCheck and p.Team == LocalPlayer.Team then continue end

        local char = p.Character
        local hum  = char and char:FindFirstChild("Humanoid")
        local part = char and char:FindFirstChild(Cfg.Aimbot.TargetPart)
        if not char or not hum or hum.Health <= 0 or not part then continue end

        local sPos, depth, onScreen = ToScreen(part.Position)
        if not onScreen or depth < 0 then continue end

        local d = (sPos - center).Magnitude
        if d < bestDist then
            bestDist = d
            best = p
        end
    end
    return best
end

-- Delta mobile: use touch hold on button instead of RMB
-- PC: RMB activates aimbot
local AimActive = false

local function UpdateAimbot()
    local vp = Camera.ViewportSize
    FOVCircle.Position = vp / 2
    FOVCircle.Visible = Cfg.Aimbot.Enabled and Cfg.Aimbot.ShowFOV

    if not Cfg.Aimbot.Enabled then return end

    -- Check RMB (PC) or AimActive flag (mobile button)
    local pressing = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
        or AimActive

    if not pressing then return end

    local target = GetTarget()
    if not target then return end

    local char = target.Character
    local part = char and char:FindFirstChild(Cfg.Aimbot.TargetPart)
    if not part then return end

    local aimPos = part.Position
    if Cfg.Aimbot.Prediction then
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            aimPos = aimPos + root.AssemblyLinearVelocity * Cfg.Aimbot.PredictionFactor
        end
    end

    local targetCF = CFrame.lookAt(Camera.CFrame.Position, aimPos)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Cfg.Aimbot.Smoothness)
end

-- ============================================================
-- // UI (Delta compatible -- no CoreGui dependency issues)
-- ============================================================
local gui = Instance.new("ScreenGui")
gui.Name = "KanhaDelta"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

-- Delta: try CoreGui first, PlayerGui fallback
local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
if not ok then gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- Drag
local function Draggable(frame, handle)
    local drag, dStart, dPos = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = true
            dStart = i.Position
            dPos = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch
        or i.UserInputType == Enum.UserInputType.MouseButton1 then
            drag = false
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if drag and (i.UserInputType == Enum.UserInputType.MouseMoved
        or i.UserInputType == Enum.UserInputType.Touch) then
            local delta = i.Position - dStart
            frame.Position = UDim2.new(
                dPos.X.Scale, dPos.X.Offset + delta.X,
                dPos.Y.Scale, dPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- Window
local Win = Instance.new("Frame")
Win.Size = UDim2.new(0, 270, 0, 400)
Win.Position = UDim2.new(0, 20, 0, 60)
Win.BackgroundColor3 = Cfg.UI.Background
Win.BorderSizePixel = 0
Win.Active = true
Win.Parent = gui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 10)

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Cfg.UI.Accent
UIStroke.Thickness = 1.2
UIStroke.Transparency = 0.6
UIStroke.Parent = Win

-- Titlebar
local Title = Instance.new("Frame")
Title.Size = UDim2.new(1, 0, 0, 38)
Title.BackgroundColor3 = Cfg.UI.Secondary
Title.BorderSizePixel = 0
Title.Parent = Win
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 10)

local TitleFix = Instance.new("Frame")
TitleFix.Size = UDim2.new(1, 0, 0, 10)
TitleFix.Position = UDim2.new(0, 0, 1, -10)
TitleFix.BackgroundColor3 = Cfg.UI.Secondary
TitleFix.BorderSizePixel = 0
TitleFix.Parent = Title

local TitleTxt = Instance.new("TextLabel")
TitleTxt.Text = "⬡  KANHA SUITE"
TitleTxt.Size = UDim2.new(1, -50, 1, 0)
TitleTxt.Position = UDim2.new(0, 12, 0, 0)
TitleTxt.BackgroundTransparency = 1
TitleTxt.TextColor3 = Cfg.UI.Text
TitleTxt.TextXAlignment = Enum.TextXAlignment.Left
TitleTxt.Font = Enum.Font.GothamBold
TitleTxt.TextSize = 13
TitleTxt.Parent = Title

local AccentBar = Instance.new("Frame")
AccentBar.Size = UDim2.new(0, 3, 0.7, 0)
AccentBar.Position = UDim2.new(0, 6, 0.15, 0)
AccentBar.BackgroundColor3 = Cfg.UI.Accent
AccentBar.BorderSizePixel = 0
AccentBar.Parent = Title
Instance.new("UICorner", AccentBar).CornerRadius = UDim.new(1, 0)

Draggable(Win, Title)

-- Content scroll
local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, 0, 1, -38)
Scroll.Position = UDim2.new(0, 0, 0, 38)
Scroll.BackgroundTransparency = 1
Scroll.ScrollBarThickness = 3
Scroll.ScrollBarImageColor3 = Cfg.UI.Accent
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.BorderSizePixel = 0
Scroll.Parent = Win

local ScrollLayout = Instance.new("UIListLayout")
ScrollLayout.Padding = UDim.new(0, 2)
ScrollLayout.Parent = Scroll

local ScrollPad = Instance.new("UIPadding")
ScrollPad.PaddingLeft = UDim.new(0, 10)
ScrollPad.PaddingRight = UDim.new(0, 10)
ScrollPad.PaddingTop = UDim.new(0, 8)
ScrollPad.PaddingBottom = UDim.new(0, 8)
ScrollPad.Parent = Scroll

-- Section header builder
local function Section(text)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 30)
    f.BackgroundTransparency = 1
    f.Parent = Scroll

    local lbl = Instance.new("TextLabel")
    lbl.Text = text
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Cfg.UI.Accent
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    lbl.Parent = f

    local div = Instance.new("Frame")
    div.Size = UDim2.new(1, 0, 0, 1)
    div.Position = UDim2.new(0, 0, 1, -1)
    div.BackgroundColor3 = Cfg.UI.Accent
    div.BackgroundTransparency = 0.65
    div.BorderSizePixel = 0
    div.Parent = f
end

-- Toggle builder
local function Toggle(label, default, cb)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 38)
    row.BackgroundColor3 = Cfg.UI.Secondary
    row.BorderSizePixel = 0
    row.Parent = Scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Text = label
    lbl.Size = UDim2.new(1, -54, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Cfg.UI.Text
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.Parent = row

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 42, 0, 24)
    bg.Position = UDim2.new(1, -50, 0.5, -12)
    bg.BackgroundColor3 = default and Cfg.UI.Accent or Color3.fromRGB(50, 50, 62)
    bg.BorderSizePixel = 0
    bg.Parent = row
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = default and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = bg
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.Parent = row

    local state = default
    btn.MouseButton1Click:Connect(function()
        state = not state
        bg.BackgroundColor3 = state and Cfg.UI.Accent or Color3.fromRGB(50, 50, 62)
        knob.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        cb(state)
    end)
    -- Mobile touch support
    btn.TouchTap:Connect(function()
        state = not state
        bg.BackgroundColor3 = state and Cfg.UI.Accent or Color3.fromRGB(50, 50, 62)
        knob.Position = state and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        cb(state)
    end)
end

-- Aimbot mobile activate button
local AimBtn = Instance.new("TextButton")
AimBtn.Text = "🎯 HOLD AIM"
AimBtn.Size = UDim2.new(0, 100, 0, 44)
AimBtn.Position = UDim2.new(1, -115, 1, -55)
AimBtn.BackgroundColor3 = Cfg.UI.Accent
AimBtn.TextColor3 = Color3.new(1, 1, 1)
AimBtn.Font = Enum.Font.GothamBold
AimBtn.TextSize = 12
AimBtn.BorderSizePixel = 0
AimBtn.Parent = gui
Instance.new("UICorner", AimBtn).CornerRadius = UDim.new(0, 8)

AimBtn.MouseButton1Down:Connect(function() AimActive = true end)
AimBtn.MouseButton1Up:Connect(function() AimActive = false end)
AimBtn.TouchLongPress:Connect(function(_, state)
    AimActive = (state == Enum.UserInputState.Begin)
end)

-- Build UI
Section("▸ ESP")
Toggle("ESP Enabled",  Cfg.ESP.Enabled,    function(v) Cfg.ESP.Enabled    = v end)
Toggle("Boxes",        Cfg.ESP.Boxes,      function(v) Cfg.ESP.Boxes      = v end)
Toggle("Names",        Cfg.ESP.Names,      function(v) Cfg.ESP.Names      = v end)
Toggle("Distance",     Cfg.ESP.Distance,   function(v) Cfg.ESP.Distance   = v end)
Toggle("Tracers",      Cfg.ESP.Tracers,    function(v) Cfg.ESP.Tracers    = v end)
Toggle("Team Check",   Cfg.ESP.TeamCheck,  function(v) Cfg.ESP.TeamCheck  = v end)

Section("▸ AIMBOT")
Toggle("Aimbot",       Cfg.Aimbot.Enabled,    function(v) Cfg.Aimbot.Enabled    = v end)
Toggle("Show FOV",     Cfg.Aimbot.ShowFOV,    function(v)
    Cfg.Aimbot.ShowFOV = v
    FOVCircle.Visible = v and Cfg.Aimbot.Enabled
end)
Toggle("Prediction",   Cfg.Aimbot.Prediction, function(v) Cfg.Aimbot.Prediction = v end)

-- ============================================================
-- // MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function()
    UpdateESP()
    UpdateAimbot()
end)

print("[KanhaDelta] loaded. Hold AIM button or RMB for aimbot.")
