-- // MATEN-MOD v9 — Draggable FOV Circles

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local T = {
    Accent      = Color3.fromRGB(165, 85, 245),
    AccentDark  = Color3.fromRGB(90, 35, 150),
    AccentLight = Color3.fromRGB(210, 160, 255),
    BG          = Color3.fromRGB(8, 5, 14),
    Surface     = Color3.fromRGB(18, 10, 30),
    SurfaceHi   = Color3.fromRGB(30, 18, 50),
    Shimmer     = Color3.fromRGB(200, 160, 255),
    Border      = Color3.fromRGB(100, 55, 165),
    BorderDim   = Color3.fromRGB(45, 25, 70),
    Text        = Color3.fromRGB(230, 215, 255),
    TextDim     = Color3.fromRGB(120, 95, 150),
    OnBG        = Color3.fromRGB(70, 25, 120),
    OffBG       = Color3.fromRGB(16, 10, 26),
    Red         = Color3.fromRGB(220, 60, 60),
}

local Config = {
    ESP      = { Enabled=true,  Box=true, Name=true, Distance=true, Health=true, Tracers=true, TeamCheck=false, Color=T.Accent },
    Aimbot   = { Enabled=false, FOV=150,  Smoothness=0.15, AimPart="Head", ShowFOV=false, HoldKey=Enum.UserInputType.MouseButton2, CirclePos=Vector2.new(0,0), CircleRadius=100 },
    SilentAim= { Enabled=true,  FOV=200,  AimPart="Head",  ShowFOV=true,  HoldKey=Enum.UserInputType.MouseButton2, Prediction=true, PredictionStrength=0.12, CirclePos=Vector2.new(0,0), CircleRadius=100 },
}

-- ===================== ESP =====================
local Drawings = {}
local function InitDrawing(player)
    if player == LocalPlayer then return end
    local d = {}
    d.Box       = Drawing.new("Square"); d.Box.Thickness=1.5; d.Box.Filled=false; d.Box.Color=Config.ESP.Color
    d.Name      = Drawing.new("Text");   d.Name.Size=14;  d.Name.Center=true;  d.Name.Outline=true; d.Name.OutlineColor=Color3.new(0,0,0); d.Name.Font=Drawing.Fonts.Plex
    d.Dist      = Drawing.new("Text");   d.Dist.Size=12;  d.Dist.Center=true;  d.Dist.Outline=true; d.Dist.OutlineColor=Color3.new(0,0,0); d.Dist.Color=Color3.fromRGB(200,180,255); d.Dist.Font=Drawing.Fonts.Plex
    d.HealthBar = Drawing.new("Line");   d.HealthBar.Thickness=2
    d.Tracer    = Drawing.new("Line");   d.Tracer.Thickness=1; d.Tracer.Transparency=0.5
    Drawings[player] = d
end
for _,p in ipairs(Players:GetPlayers()) do InitDrawing(p) end
Players.PlayerAdded:Connect(InitDrawing)
Players.PlayerRemoving:Connect(function(p)
    if Drawings[p] then for _,o in pairs(Drawings[p]) do o:Remove() end; Drawings[p]=nil end
end)

local function W2V(pos) local s,on=Camera:WorldToViewportPoint(pos); return Vector2.new(s.X,s.Y),on end
local function IsEnemy(p)
    if not Config.ESP.TeamCheck then return true end
    return p.Team ~= LocalPlayer.Team
end

local function UpdateESP()
    for player,d in pairs(Drawings) do
        local char=player.Character
        local hum=char and char:FindFirstChildOfClass("Humanoid")
        local root=char and char:FindFirstChild("HumanoidRootPart")
        local head=char and char:FindFirstChild("Head")
        if not Config.ESP.Enabled or not hum or hum.Health<=0 or not IsEnemy(player) or not root or not head then
            d.Box.Visible=false;d.Name.Visible=false;d.Dist.Visible=false;d.HealthBar.Visible=false;d.Tracer.Visible=false; continue
        end
        local myRoot=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local dist=myRoot and math.floor((myRoot.Position-root.Position).Magnitude) or 0
        local topPos,topOn=W2V(head.Position+Vector3.new(0,1,0))
        local botPos,botOn=W2V(root.Position-Vector3.new(0,2.5,0))
        if topOn and botOn then
            local h=math.abs(topPos.Y-botPos.Y); local w=h*0.65
            local x=(topPos.X+botPos.X)/2-w/2; local y=topPos.Y
            if Config.ESP.Box    then d.Box.Size=Vector2.new(w,h);d.Box.Position=Vector2.new(x,y);d.Box.Visible=true else d.Box.Visible=false end
            if Config.ESP.Name   then d.Name.Text=player.Name;d.Name.Position=Vector2.new(x+w/2,y-18);d.Name.Color=Config.ESP.Color;d.Name.Visible=true else d.Name.Visible=false end
            if Config.ESP.Distance then d.Dist.Text=dist.."m";d.Dist.Position=Vector2.new(x+w/2,y+h+2);d.Dist.Visible=true else d.Dist.Visible=false end
            if Config.ESP.Health then
                local pct=math.clamp(hum.Health/hum.MaxHealth,0,1)
                d.HealthBar.From=Vector2.new(x-6,y+h);d.HealthBar.To=Vector2.new(x-6,y+h-(h*pct))
                d.HealthBar.Color=Color3.fromRGB(255*(1-pct),255*pct,0);d.HealthBar.Visible=true
            else d.HealthBar.Visible=false end
            if Config.ESP.Tracers then
                d.Tracer.From=Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y)
                d.Tracer.To=Vector2.new(x+w/2,y+h);d.Tracer.Color=Config.ESP.Color
                d.Tracer.Transparency=math.clamp(1-(dist/1000),0.1,1);d.Tracer.Visible=true
            else d.Tracer.Visible=false end
        else d.Box.Visible=false;d.Name.Visible=false;d.Dist.Visible=false;d.HealthBar.Visible=false;d.Tracer.Visible=false end
    end
end

-- ===================== AIMBOT =====================
local AimbotFOVCircle=Drawing.new("Circle"); AimbotFOVCircle.Thickness=1.5; AimbotFOVCircle.Color=T.Accent; AimbotFOVCircle.Filled=false
local AimingCam=false
local AimbotPos = Vector2.new(0,0)
local AimbotRadius = 100

local function GetTargetCam()
    local closest,minD=nil,Config.Aimbot.FOV; local center=AimbotPos
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and IsEnemy(p) then
            local char=p.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
            local part=char and char:FindFirstChild(Config.Aimbot.AimPart)
            if part and hum and hum.Health>0 then
                local pos,on=W2V(part.Position)
                if on then local d=(pos-center).Magnitude; if d<minD then minD=d;closest=part end end
            end
        end
    end
    return closest
end

local function UpdateAimbotCam()
    AimbotFOVCircle.Position=AimbotPos; AimbotFOVCircle.Radius=AimbotRadius
    AimbotFOVCircle.Visible=Config.Aimbot.ShowFOV and Config.Aimbot.Enabled
    if Config.Aimbot.Enabled and AimingCam then
        local t=GetTargetCam()
        if t then local c=Camera.CFrame; Camera.CFrame=c:Lerp(CFrame.new(c.Position,t.Position),Config.Aimbot.Smoothness) end
    end
end

-- ===================== SILENT AIM =====================
local SilentFOVCircle=Drawing.new("Circle"); SilentFOVCircle.Thickness=1.5; SilentFOVCircle.Color=T.Accent; SilentFOVCircle.Filled=false
local AimingSilent=false
local SilentPos = Vector2.new(0,0)
local SilentRadius = 100

local function GetTargetSilent()
    local closest,minD=nil,Config.SilentAim.FOV; local center=SilentPos
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LocalPlayer and IsEnemy(p) then
            local char=p.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
            local part=char and char:FindFirstChild(Config.SilentAim.AimPart)
            if part and hum and hum.Health>0 then
                local pos,on=W2V(part.Position)
                if on then local d=(pos-center).Magnitude; if d<minD then minD=d;closest={Part=part,Char=char} end end
            end
        end
    end
    return closest
end

local function GetPredicted(td)
    if not td then return nil end
    local root=td.Char and td.Char:FindFirstChild("HumanoidRootPart")
    if not root or not Config.SilentAim.Prediction then return td.Part.Position end
    local myRoot=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local dist=myRoot and (myRoot.Position-root.Position).Magnitude or 100
    return td.Part.Position+root.Velocity*((dist/500)+Config.SilentAim.PredictionStrength)
end

local safeUnpack=table.unpack or unpack
local ok,mt=pcall(getrawmetatable,game)
if ok and mt and pcall(setreadonly,mt,false) then
    local oldNC=mt.__namecall
    mt.__namecall=newcclosure(function(self,...)
        local m=getnamecallmethod()
        if Config.SilentAim.Enabled and AimingSilent then
            local ok2,td=pcall(GetTargetSilent)
            if ok2 and td then
                local ok3,pred=pcall(GetPredicted,td)
                if ok3 and pred then
                    if m=="Fire" or m=="FireServer" or m=="InvokeServer" then
                        local args={...}
                        for i=1,math.min(#args,5) do if typeof(args[i])=="Vector3" then args[i]=pred;break end end
                        local s,r=pcall(oldNC,self,safeUnpack(args)); return s and r or oldNC(self,...)
                    elseif m=="Hit" then
                        local s,r=pcall(oldNC,self,td.Part,...); return s and r or oldNC(self,...)
                    end
                end
            end
        end
        return oldNC(self,...)
    end)
    setreadonly(mt,true)
end

local function UpdateSilent()
    SilentFOVCircle.Position=SilentPos; SilentFOVCircle.Radius=SilentRadius
    SilentFOVCircle.Visible=Config.SilentAim.ShowFOV and Config.SilentAim.Enabled
end

UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType==Config.Aimbot.HoldKey    then AimingCam=true end
    if i.UserInputType==Config.SilentAim.HoldKey then AimingSilent=true end
end)
UserInputService.InputEnded:Connect(function(i,gp)
    if gp then return end
    if i.UserInputType==Config.Aimbot.HoldKey    then AimingCam=false end
    if i.UserInputType==Config.SilentAim.HoldKey then AimingSilent=false end
end)

-- ===================== UI =====================
local UI={
    W=IsMobile and 310 or 290, H=IsMobile and 390 or 325,
    TH=IsMobile and 50 or 42, TabH=IsMobile and 34 or 26,
    ItemH=IsMobile and 44 or 32, FS=IsMobile and 13 or 11, TFS=IsMobile and 10 or 9,
}

local ScreenGui=Instance.new("ScreenGui")
ScreenGui.Name="MatenGlass"; ScreenGui.ResetOnSpawn=false
ScreenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset=true; ScreenGui.Parent=game:GetService("CoreGui")

-- ===== SHIMMER =====
local function MakeShimmer(parent, zindex)
    local sh=Instance.new("Frame")
    sh.Size=UDim2.new(0.5,0,0,IsMobile and 2 or 1.5)
    sh.Position=UDim2.new(-0.1,0,0,3)
    sh.BackgroundColor3=T.Shimmer
    sh.BackgroundTransparency=0.45
    sh.BorderSizePixel=0
    sh.ZIndex=zindex or 5
    sh.Parent=parent
    Instance.new("UICorner",sh).CornerRadius=UDim.new(1,0)
    local g=Instance.new("UIGradient",sh)
    g.Transparency=NumberSequence.new{
        NumberSequenceKeypoint.new(0,1),
        NumberSequenceKeypoint.new(0.4,0.1),
        NumberSequenceKeypoint.new(0.6,0.1),
        NumberSequenceKeypoint.new(1,1),
    }
    task.spawn(function()
        while sh and sh.Parent do
            sh.Position=UDim2.new(-0.15,0,0,3)
            TweenService:Create(sh,TweenInfo.new(2.6,Enum.EasingStyle.Sine),{Position=UDim2.new(1,0,0,3)}):Play()
            task.wait(2.7)
        end
    end)
    return sh
end

-- ===== MAIN FRAME =====
local MainFrame=Instance.new("Frame")
MainFrame.Size=UDim2.new(0,UI.W,0,0)
MainFrame.Position=UDim2.new(0.5,-UI.W/2,0.5,-UI.H/2)
MainFrame.BackgroundColor3=T.BG
MainFrame.BackgroundTransparency=0.22
MainFrame.BorderSizePixel=0
MainFrame.Active=true; MainFrame.Draggable=not IsMobile
MainFrame.ClipsDescendants=true; MainFrame.Parent=ScreenGui
Instance.new("UICorner",MainFrame).CornerRadius=UDim.new(0,14)
local msk=Instance.new("UIStroke",MainFrame); msk.Color=T.Border; msk.Thickness=1.2; msk.Transparency=0.3
MakeShimmer(MainFrame, 2)

local BGTint=Instance.new("Frame")
BGTint.Size=UDim2.new(1,0,1,0); BGTint.BackgroundColor3=T.Surface
BGTint.BackgroundTransparency=0.6; BGTint.BorderSizePixel=0; BGTint.ZIndex=1; BGTint.Parent=MainFrame
Instance.new("UICorner",BGTint).CornerRadius=UDim.new(0,14)

local OPEN_H=UDim2.new(0,UI.W,0,UI.H)
local function AnimOpen()
    MainFrame.Visible=true; MainFrame.Size=UDim2.new(0,UI.W,0,0)
    TweenService:Create(MainFrame,TweenInfo.new(0.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Size=OPEN_H}):Play()
end
local function AnimClose(cb)
    TweenService:Create(MainFrame,TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Size=UDim2.new(0,UI.W,0,0)}):Play()
    task.delay(0.19,function() MainFrame.Visible=false; if cb then cb() end end)
end

if IsMobile then
    local ds,fs
    MainFrame.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then ds=i.Position;fs=MainFrame.Position end end)
    MainFrame.InputChanged:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.Touch and ds then
            local d=i.Position-ds; MainFrame.Position=UDim2.new(fs.X.Scale,fs.X.Offset+d.X,fs.Y.Scale,fs.Y.Offset+d.Y)
        end
    end)
    MainFrame.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.Touch then ds=nil end end)
end

-- ===== TITLE =====
local TitleBar=Instance.new("Frame")
TitleBar.Size=UDim2.new(1,0,0,UI.TH); TitleBar.Position=UDim2.new(0,0,0,0)
TitleBar.BackgroundColor3=T.Surface; TitleBar.BackgroundTransparency=0.25
TitleBar.BorderSizePixel=0; TitleBar.ZIndex=5; TitleBar.Parent=MainFrame
Instance.new("UICorner",TitleBar).CornerRadius=UDim.new(0,14)
MakeShimmer(TitleBar, 8)

local AL=Instance.new("Frame")
AL.Size=UDim2.new(0.5,0,0,2); AL.Position=UDim2.new(0,0,1,-2)
AL.BackgroundColor3=T.Accent; AL.BackgroundTransparency=0.15
AL.BorderSizePixel=0; AL.ZIndex=6; AL.Parent=TitleBar
Instance.new("UICorner",AL).CornerRadius=UDim.new(1,0)
local alg=Instance.new("UIGradient",AL); alg.Color=ColorSequence.new(T.Accent,T.BG)
alg.Transparency=NumberSequence.new{NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.6,0.2),NumberSequenceKeypoint.new(1,1)}

local TitleLbl=Instance.new("TextLabel")
TitleLbl.Size=UDim2.new(1,-54,0.55,0); TitleLbl.Position=UDim2.new(0,12,0.08,0)
TitleLbl.BackgroundTransparency=1; TitleLbl.Text="MATEN  MOD  V9"
TitleLbl.TextColor3=T.Text; TitleLbl.TextXAlignment=Enum.TextXAlignment.Left
TitleLbl.Font=Enum.Font.GothamBold; TitleLbl.TextSize=IsMobile and 14 or 12
TitleLbl.ZIndex=10; TitleLbl.Parent=TitleBar

local Badge=Instance.new("TextLabel")
Badge.Size=UDim2.new(0,52,0,13); Badge.Position=UDim2.new(0,12,0.65,0)
Badge.BackgroundColor3=T.AccentDark; Badge.BackgroundTransparency=0.4
Badge.Text=IsMobile and "MOBILE" or "PC"
Badge.TextColor3=T.AccentLight; Badge.Font=Enum.Font.GothamBold; Badge.TextSize=8
Badge.ZIndex=10; Badge.Parent=TitleBar
Instance.new("UICorner",Badge).CornerRadius=UDim.new(0,4)

local CBS=UI.TH-16
local CloseBtn=Instance.new("TextButton")
CloseBtn.Size=UDim2.new(0,CBS,0,CBS); CloseBtn.Position=UDim2.new(1,-CBS-7,0,8)
CloseBtn.BackgroundColor3=Color3.fromRGB(50,15,15); CloseBtn.BackgroundTransparency=0.25
CloseBtn.Text="✕"; CloseBtn.TextColor3=T.Red
CloseBtn.Font=Enum.Font.GothamBold; CloseBtn.TextSize=IsMobile and 16 or 13
CloseBtn.ZIndex=15; CloseBtn.Parent=TitleBar
Instance.new("UICorner",CloseBtn).CornerRadius=UDim.new(0,7)
Instance.new("UIStroke",CloseBtn).Color=T.Red

local LogoBtn=Instance.new("TextButton")
LogoBtn.Size=UDim2.new(0,45,0,45); LogoBtn.Position=UDim2.new(0,10,0,10)
LogoBtn.BackgroundColor3=T.AccentDark; LogoBtn.Text="M"
LogoBtn.TextColor3=Color3.new(1,1,1)
LogoBtn.Font=Enum.Font.GothamBlack; LogoBtn.TextSize=26
LogoBtn.Visible=false; LogoBtn.ZIndex=50; LogoBtn.Parent=ScreenGui
Instance.new("UICorner",LogoBtn).CornerRadius=UDim.new(1,0)
local LStroke = Instance.new("UIStroke", LogoBtn); LStroke.Color=T.Accent; LStroke.Thickness=2

CloseBtn.MouseButton1Click:Connect(function() 
    AnimClose(function() LogoBtn.Visible=true end) 
end)
LogoBtn.MouseButton1Click:Connect(function() 
    LogoBtn.Visible=false; AnimOpen() 
end)

-- ===== TABS =====
local CO=UI.TH+5
local TabBar=Instance.new("Frame")
TabBar.Size=UDim2.new(1,-14,0,UI.TabH); TabBar.Position=UDim2.new(0,7,0,CO)
TabBar.BackgroundTransparency=1; TabBar.ZIndex=5; TabBar.Parent=MainFrame
local tbl=Instance.new("UIListLayout",TabBar)
tbl.FillDirection=Enum.FillDirection.Horizontal; tbl.Padding=UDim.new(0,4)

local Pages={}
local function SetTab(name)
    for n,p in pairs(Pages) do
        local a=(n==name)
        TweenService:Create(p.Button,TweenInfo.new(0.13),{
            BackgroundColor3=a and T.OnBG or T.OffBG,
            BackgroundTransparency=a and 0.05 or 0.6,
            TextColor3=a and T.AccentLight or T.TextDim,
        }):Play()
        local sk=p.Button:FindFirstChildOfClass("UIStroke")
        if sk then sk.Color=a and T.Accent or T.BorderDim end
        p.Frame.Visible=a
    end
end

local function CreatePage(name)
    local tw=(UI.W-14-12)/4
    local btn=Instance.new("TextButton")
    btn.Size=UDim2.new(0,tw,0,UI.TabH)
    btn.BackgroundColor3=T.OffBG; btn.BackgroundTransparency=0.6
    btn.TextColor3=T.TextDim; btn.Font=Enum.Font.GothamBold
    btn.TextSize=UI.TFS; btn.Text=name; btn.ZIndex=8; btn.Parent=TabBar
    Instance.new("UICorner",btn).CornerRadius=UDim.new(0,8)
    local sk=Instance.new("UIStroke",btn); sk.Color=T.BorderDim; sk.Thickness=1

    local yo=CO+UI.TabH+5
    local page=Instance.new("ScrollingFrame")
    page.Size=UDim2.new(1,-14,1,-yo-4); page.Position=UDim2.new(0,7,0,yo)
    page.BackgroundTransparency=1; page.ScrollBarThickness=2
    page.ScrollBarImageColor3=T.Accent; page.CanvasSize=UDim2.new(0,0,0,500)
    page.Visible=false; page.ZIndex=8; page.Parent=MainFrame
    local ul=Instance.new("UIListLayout"); ul.Padding=UDim.new(0,5); ul.Parent=page

    Pages[name]={Button=btn,Frame=page}
    btn.MouseButton1Click:Connect(function() SetTab(name) end)
    return page
end

local EspPage    = CreatePage("ESP")
local AimbotPage = CreatePage("AIMBOT")
local SilentPage = CreatePage("SILENT")
local InfoPage   = CreatePage("INFO")

-- ===== ITEM BUILDER =====
local function GlassCard(parent, h)
    local f=Instance.new("Frame")
    f.Size=UDim2.new(1,0,0,h); f.BackgroundColor3=T.Surface
    f.BackgroundTransparency=0.35; f.BorderSizePixel=0; f.ZIndex=10; f.Parent=parent
    Instance.new("UICorner",f).CornerRadius=UDim.new(0,9)
    local sk=Instance.new("UIStroke",f); sk.Color=T.BorderDim; sk.Thickness=1; sk.Transparency=0.4
    local hl=Instance.new("Frame")
    hl.Size=UDim2.new(0.6,0,0,1); hl.Position=UDim2.new(0.1,0,0,2)
    hl.BackgroundColor3=T.Shimmer; hl.BackgroundTransparency=0.6
    hl.BorderSizePixel=0; hl.ZIndex=11; hl.Parent=f
    Instance.new("UICorner",hl).CornerRadius=UDim.new(1,0)
    local hlg=Instance.new("UIGradient",hl)
    hlg.Transparency=NumberSequence.new{
        NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.3),NumberSequenceKeypoint.new(1,1)
    }
    return f
end

local function Toggle(parent,label,default,cb)
    local f=GlassCard(parent,UI.ItemH)
    local dot=Instance.new("Frame")
    dot.Size=UDim2.new(0,UI.ItemH-20,0,UI.ItemH-20)
    dot.Position=UDim2.new(1,-(UI.ItemH-8),0.5,-(UI.ItemH-20)/2)
    dot.BackgroundColor3=default and T.Accent or T.BorderDim
    dot.BorderSizePixel=0; dot.ZIndex=14; dot.Parent=f
    Instance.new("UICorner",dot).CornerRadius=UDim.new(0,5)

    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-(UI.ItemH+2),1,0); lbl.Position=UDim2.new(0,9,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label
    lbl.TextColor3=default and T.Text or T.TextDim
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=UI.FS
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=14; lbl.Parent=f

    local vl=Instance.new("TextLabel")
    vl.Size=UDim2.new(0,UI.ItemH-20,1,0)
    vl.Position=UDim2.new(1,-(UI.ItemH-8),0,0)
    vl.BackgroundTransparency=1; vl.Text=default and "ON" or "OFF"
    vl.TextColor3=default and T.AccentLight or T.TextDim
    vl.Font=Enum.Font.GothamBold; vl.TextSize=8
    vl.ZIndex=15; vl.Parent=f

    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
    btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=18; btn.Parent=f
    local s=default
    btn.MouseButton1Click:Connect(function()
        s=not s
        TweenService:Create(dot,TweenInfo.new(0.13),{BackgroundColor3=s and T.Accent or T.BorderDim}):Play()
        lbl.TextColor3=s and T.Text or T.TextDim
        vl.Text=s and "ON" or "OFF"; vl.TextColor3=s and T.AccentLight or T.TextDim
        cb(s)
    end)
end

local function Slider(parent,label,min,max,default,cb)
    local f=GlassCard(parent,UI.ItemH+13)
    local lbl=Instance.new("TextLabel")
    lbl.Size=UDim2.new(1,-10,0,18); lbl.Position=UDim2.new(0,9,0,4)
    lbl.BackgroundTransparency=1; lbl.Text=label.."   "..default
    lbl.TextColor3=T.Text; lbl.Font=Enum.Font.Gotham; lbl.TextSize=UI.FS
    lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=14; lbl.Parent=f

    local track=Instance.new("Frame")
    track.Size=UDim2.new(1,-18,0,IsMobile and 7 or 4); track.Position=UDim2.new(0,9,0,27)
    track.BackgroundColor3=T.SurfaceHi; track.BorderSizePixel=0; track.ZIndex=14; track.Parent=f
    Instance.new("UICorner",track).CornerRadius=UDim.new(1,0)

    local fill=Instance.new("Frame"); fill.Size=UDim2.new((default-min)/(max-min),0,1,0)
    fill.BackgroundColor3=T.Accent; fill.ZIndex=15; fill.Parent=track
    Instance.new("UICorner",fill).CornerRadius=UDim.new(1,0)
    local fg=Instance.new("UIGradient",fill); fg.Color=ColorSequence.new(T.AccentDark,T.AccentLight)

    local thumb=Instance.new("Frame")
    thumb.Size=UDim2.new(0,IsMobile and 14 or 9,0,IsMobile and 14 or 9)
    thumb.AnchorPoint=Vector2.new(0.5,0.5)
    thumb.Position=UDim2.new((default-min)/(max-min),0,0.5,0)
    thumb.BackgroundColor3=Color3.new(1,1,1); thumb.BackgroundTransparency=0.05
    thumb.ZIndex=16; thumb.Parent=track
    Instance.new("UICorner",thumb).CornerRadius=UDim.new(1,0)
    Instance.new("UIStroke",thumb).Color=T.Accent

    fill:GetPropertyChangedSignal("Size"):Connect(function()
        thumb.Position=UDim2.new(fill.Size.X.Scale,0,0.5,0)
    end)
    local drag=false
    local function Upd(i)
        local p=math.clamp((i.Position.X-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        fill.Size=UDim2.new(p,0,1,0); local v=math.floor(min+(max-min)*p)
        lbl.Text=label.."   "..v; cb(v)
    end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true;Upd(i) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
    UserInputService.InputChanged:Connect(function(i) if drag and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then Upd(i) end end)
end

local function Cycle(parent,label,opts,cb)
    local f=GlassCard(parent,UI.ItemH); local idx=1
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,1,0); lbl.Position=UDim2.new(0,9,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=T.TextDim
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=UI.FS; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=14; lbl.Parent=f
    local val=Instance.new("TextLabel"); val.Size=UDim2.new(0.42,0,1,0); val.Position=UDim2.new(0.56,0,0,0)
    val.BackgroundTransparency=1; val.Text="‹ "..opts[idx].." ›"; val.TextColor3=T.Accent
    val.Font=Enum.Font.GothamBold; val.TextSize=UI.FS-1; val.TextXAlignment=Enum.TextXAlignment.Right; val.ZIndex=14; val.Parent=f
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
    btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=18; btn.Parent=f
    btn.MouseButton1Click:Connect(function() idx=(idx%#opts)+1; val.Text="‹ "..opts[idx].." ›"; cb(opts[idx]) end)
end

local function KeyBind(parent,label,cb)
    local f=GlassCard(parent,UI.ItemH); local listening=false
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.new(0.55,0,1,0); lbl.Position=UDim2.new(0,9,0,0)
    lbl.BackgroundTransparency=1; lbl.Text=label; lbl.TextColor3=T.TextDim
    lbl.Font=Enum.Font.Gotham; lbl.TextSize=UI.FS; lbl.TextXAlignment=Enum.TextXAlignment.Left; lbl.ZIndex=14; lbl.Parent=f
    local val=Instance.new("TextLabel"); val.Size=UDim2.new(0.42,0,1,0); val.Position=UDim2.new(0.56,0,0,0)
    val.BackgroundTransparency=1; val.Text="[ RMB ]"; val.TextColor3=T.AccentLight
    val.Font=Enum.Font.GothamBold; val.TextSize=UI.FS-1; val.TextXAlignment=Enum.TextXAlignment.Right; val.ZIndex=14; val.Parent=f
    local btn=Instance.new("TextButton"); btn.Size=UDim2.new(1,0,1,0)
    btn.BackgroundTransparency=1; btn.Text=""; btn.ZIndex=18; btn.Parent=f
    btn.MouseButton1Click:Connect(function()
        if listening then return end; listening=true; val.Text="[ ... ]"; val.TextColor3=Color3.fromRGB(255,220,80)
        local conn; conn=UserInputService.InputBegan:Connect(function(i,gp)
            if gp then return end; listening=false; conn:Disconnect()
            local n
            if i.UserInputType==Enum.UserInputType.MouseButton1 then n="LMB"
            elseif i.UserInputType==Enum.UserInputType.MouseButton2 then n="RMB"
            elseif i.KeyCode~=Enum.KeyCode.Unknown then n=tostring(i.KeyCode):gsub("Enum.KeyCode.","")
            else n="?" end
            val.Text="[ "..n.." ]"; val.TextColor3=T.AccentLight
            cb(i.UserInputType,i.KeyCode)
        end)
    end)
end

-- ===== CONTENT =====
Toggle(EspPage,"ESP Master",Config.ESP.Enabled,function(v) Config.ESP.Enabled=v end)
Toggle(EspPage,"Box",Config.ESP.Box,function(v) Config.ESP.Box=v end)
Toggle(EspPage,"Name",Config.ESP.Name,function(v) Config.ESP.Name=v end)
Toggle(EspPage,"Distance",Config.ESP.Distance,function(v) Config.ESP.Distance=v end)
Toggle(EspPage,"Health Bar",Config.ESP.Health,function(v) Config.ESP.Health=v end)
Toggle(EspPage,"Tracers",Config.ESP.Tracers,function(v) Config.ESP.Tracers=v end)
Toggle(EspPage,"Team Check",Config.ESP.TeamCheck,function(v) Config.ESP.TeamCheck=v end)

Toggle(AimbotPage,"Aimbot",Config.Aimbot.Enabled,function(v) Config.Aimbot.Enabled=v end)
Toggle(AimbotPage,"Show FOV",Config.Aimbot.ShowFOV,function(v) Config.Aimbot.ShowFOV=v end)
Slider(AimbotPage,"FOV",50,800,Config.Aimbot.FOV,function(v) Config.Aimbot.FOV=v; AimbotRadius = v end)
Slider(AimbotPage,"Smoothness",1,20,2,function(v) Config.Aimbot.Smoothness=v/10 end)
Cycle(AimbotPage,"Aim Part",{"Head","HumanoidRootPart","Torso"},function(v) Config.Aimbot.AimPart=v end)
KeyBind(AimbotPage,"Hold Key",function(ut,kc)
    Config.Aimbot.HoldKey=(ut==Enum.UserInputType.MouseButton1 or ut==Enum.UserInputType.MouseButton2) and ut or kc
end)

Toggle(SilentPage,"Silent Aim",Config.SilentAim.Enabled,function(v) Config.SilentAim.Enabled=v end)
Toggle(SilentPage,"Show FOV",Config.SilentAim.ShowFOV,function(v) Config.SilentAim.ShowFOV=v end)
Toggle(SilentPage,"Prediction",Config.SilentAim.Prediction,function(v) Config.SilentAim.Prediction=v end)
Slider(SilentPage,"Silent FOV",50,800,Config.SilentAim.FOV,function(v) Config.SilentAim.FOV=v; SilentRadius = v end)
Slider(SilentPage,"Predict Str",1,30,12,function(v) Config.SilentAim.PredictionStrength=v/100 end)
Cycle(SilentPage,"Target Part",{"Head","HumanoidRootPart","Torso"},function(v) Config.SilentAim.AimPart=v end)
KeyBind(SilentPage,"Hold Key",function(ut,kc)
    Config.SilentAim.HoldKey=(ut==Enum.UserInputType.MouseButton1 or ut==Enum.UserInputType.MouseButton2) and ut or kc
end)

local infoLines={
    {"MATEN  MOD  V9",true},{IsMobile and "Mobile" or "PC Mode",false},
    {"Liquid Glass UI",false},{"",false},
    {"Drag FOV Circle to move",false},
    {"Tap M → reopen",false},{"",false},{"by MATEN",true},
}
for _,r in ipairs(infoLines) do
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,0,0,r[1]=="" and 7 or 20)
    l.BackgroundTransparency=1; l.Text="  "..r[1]
    l.TextColor3=r[2] and T.Accent or T.TextDim
    l.Font=r[2] and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize=r[2] and 13 or 11; l.TextXAlignment=Enum.TextXAlignment.Left
    l.ZIndex=10; l.Parent=InfoPage
end

-- ===== START =====
AimbotPos = Camera.ViewportSize / 2
SilentPos = Camera.ViewportSize / 2
AimbotRadius = Config.Aimbot.FOV
SilentRadius = Config.SilentAim.FOV

SetTab("ESP")
AnimOpen()

RunService.RenderStepped:Connect(function()
    pcall(UpdateESP); pcall(UpdateAimbotCam); pcall(UpdateSilent)
end)

-- Mobile Drag Support for FOV Circles
if IsMobile then
    local function CreateDraggableCircle(color, posVar, radiusVar, configVar)
        local circle = Instance.new("Frame")
        circle.Size = UDim2.new(0, radiusVar * 2, 0, radiusVar * 2)
        circle.Position = UDim2.new(0, posVar.X - radiusVar, 0, posVar.Y - radiusVar)
        circle.BackgroundTransparency = 1
        circle.BorderSizePixel = 0
        circle.ZIndex = 2
        circle.Parent = ScreenGui
        
        local stroke = Instance.new("UIStroke", circle)
        stroke.Color = color
        stroke.Thickness = 1.5
        
        local corner = Instance.new("UICorner", circle)
        corner.CornerRadius = UDim.new(1, 0)
        
        local dragging = false
        local dragStart = Vector2.new(0,0)
        
        circle.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.Touch then
                local delta = input.Position - dragStart
                posVar = posVar + delta
                circle.Position = UDim2.new(0, posVar.X - radiusVar, 0, posVar.Y - radiusVar)
                dragStart = input.Position
                
                if configVar == "Aimbot" then
                    Config.Aimbot.CirclePos = posVar
                else
                    Config.SilentAim.CirclePos = posVar
                end
            end
        end)
    end
    
    CreateDraggableCircle(T.Accent, AimbotPos, AimbotRadius, "Aimbot")
    CreateDraggableCircle(Color3.fromRGB(0, 255, 150), SilentPos, SilentRadius, "Silent")
end

print("[MATEN-MOD v9] Draggable FOV Circles Loaded!")
