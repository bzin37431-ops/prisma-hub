--[[
    PRISMA NEXUS — HYPERION REFINED v13.0
    ─────────────────────────────────────
    • Performance overhaul: Draw API, Highlight, Maid pattern
    • ESP otimizado (sem SelectionBox, sem Beam em massa)
    • Invisibilidade em 10Hz (era 60Hz)
    • updateItems restrito a pastas conhecidas
    • Aimbot com predição por velocity
    • CoreGui via gethui() / PlayerGui randomizado
    • Godmode sem MaxHealth absurdo
    • Nomes de GUI randomizados (anti-detect)
    • CFrame lerp corrigido (FPS-independent)
    • FLING v3, anim packs, godmode 6 camadas, shaders, piano
--]]

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1.2)

local Players              = game:GetService("Players")
local RunService           = game:GetService("RunService")
local UserInputService     = game:GetService("UserInputService")
local TweenService         = game:GetService("TweenService")
local TeleportService      = game:GetService("TeleportService")
local HttpService          = game:GetService("HttpService")
local Lighting             = game:GetService("Lighting")
local SoundService         = game:GetService("SoundService")
local Workspace            = game:GetService("Workspace")
local CoreGui              = game:GetService("CoreGui")
local LogService           = game:GetService("LogService")
local ContextActionService = game:GetService("ContextActionService")
local MarketplaceService   = game:GetService("MarketplaceService")
local LocalPlayer          = Players.LocalPlayer
if not LocalPlayer then return end

local ENV = (getgenv and getgenv()) or _G
if ENV.PrismaHub and ENV.PrismaHub.Destroy then pcall(ENV.PrismaHub.Destroy) end

local App = {
    alive = true, connections = {}, pageConnections = {}, objects = {},
    playerVisuals = {}, itemVisuals = {}, collisions = {}, original = {},
    originalHumanoids = {}, hiddenAccessories = {}, slots = {}, selected = nil,
    toggleHandlers = {}, toggleVisuals = {},
    particles = {}, frameCount = 0, lastFpsUpdate = 0, fps = 0,
    ping = 0, lastPing = 0, panicBind = Enum.KeyCode.Delete,
    parallax = { x = 0, y = 0, tx = 0, ty = 0 },
    currentPage = "Início", lastMusicId = "",
    fireUnsupported = false, fovPreview = false, aimKeyCapture = false,
    lastGroundY = nil, userMovedPanel = false, lastSaveTime = 0,
    freecamAngle = Vector2.new(0, 0),
    invisLoop = nil, tagParticles = {}, tagParticleLoop = nil,
    lastVoidNotify = 0, last3DUpdate = 0, pendingPage = nil,
    autoRejoinConn = nil, currentAnim = nil,
    flyJustStopped = false, flyStopTimer = 0,
    freecamJumpConn = nil, aimTarget = nil,
    godmodeConn = nil, godmodeLoop = nil, godmodeDiedConn = nil,
    godmodeFFConn = nil, godmodeLastForce = 0,
    flingTarget = nil, flingThread = nil, flingParts = {},
    flingDiag = {}, flingStolen = {},
    invisAccum = 0, aimsAccum = 0,
}
ENV.PrismaHub = App

-- ============================================================
-- MAID (cleanup seguro por dono)
-- ============================================================
local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({ _tasks = {} }, Maid) end
function Maid:give(task)
    table.insert(self._tasks, task)
    return task
end
function Maid:cleanup()
    for _, task in ipairs(self._tasks) do
        pcall(function()
            if typeof(task) == "RBXScriptConnection" then task:Disconnect()
            elseif typeof(task) == "Instance" then task:Destroy()
            elseif type(task) == "function" then task()
            elseif type(task) == "thread" then task.cancel(task) end
        end)
    end
    table.clear(self._tasks)
end

local S = {
    accent = Color3.fromRGB(165, 112, 255),
    accent2 = Color3.fromRGB(120, 190, 255),
    rgb = true, glass = 0.12, scale = 1, parallax = true,
    particles = true, tiltStrength = 1, bg3d = true,

    esp = false, espBox = true, espName = true, espHealth = true,
    espDistance = true, espTracer = false, espHeadDot = false,
    espChams = true, espTeamCheck = true, espMaxDist = 1200,
    espFillAlpha = 0.82, espOutlineAlpha = 0, espItems = false, espRainbow = false,
    espNoDistLimit = false,

    aim = false, aimKey = Enum.UserInputType.MouseButton2, aimHold = true,
    aimFov = 160, aimSmooth = 0.18, aimDist = 600, aimPart = "Head",
    aimVisible = false, aimTeam = true, aimSticky = true,
    aimAutoFire = false, aimShowFov = true, aimPrediction = 0.135,

    speed = false, speedValue = 32, jump = false, jumpValue = 85,
    fly = false, flySpeed = 70, noclip = false, infiniteJump = false,
    spin = false, spinSpeed = 120, clickTp = false,
    follow = false, followMode = "Atrás", followSmooth = 0.28,
    freecam = false, freecamSpeed = 50,
    invisible = false, invisHideName = true,
    godmode = false,

    antiAfk = false, antiFling = false, antiRagdoll = false,
    autoRejoin = false, fullbright = false, fpsBoost = false,
    joinLeaveNotify = false,

    shaderPreset = "Desligado", shaderIntensity = 0.7,
    musicVolume = 0.35, musicLoop = true, playlist = {},

    tagEnabled = false, tagName = "PRISMA",
    tagColor = Color3.fromRGB(201, 164, 255), tagRainbow = false,
    tagStyle = "", tagAnimated = true, tagFont = "GothamBlack",
    tagSize = 26, tagExtrude = 3,

    flingMode = "LIMB_RUSH",
    flingPower = 2500,
    flingRate = 0.05,
    flingRips = 16,
    flingLimbSet = "all",

    animPack = "Padrão",

    binds = {}, pianoBpm = 120,
    pianoKeyMap = { C = "Z", D = "X", E = "C", F = "V", G = "B", A = "N", B = "M" },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function connect(sig, fn)
    local c = sig:Connect(fn); table.insert(App.connections, c); return c
end
local function pageConnect(sig, fn)
    local c = sig:Connect(fn); table.insert(App.pageConnections, c); return c
end
local function own(obj) table.insert(App.objects, obj); return obj end
local function rgb(c)
    return string.format("#%02X%02X%02X",
        math.floor(c.R * 255 + .5), math.floor(c.G * 255 + .5), math.floor(c.B * 255 + .5))
end
local function fromHex(t)
    t = tostring(t or ""):gsub("#", "")
    if #t ~= 6 or not t:match("^%x+$") then return nil end
    return Color3.fromRGB(tonumber(t:sub(1, 2), 16), tonumber(t:sub(3, 4), 16), tonumber(t:sub(5, 6), 16))
end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function safeUtf8First(s)
    s = tostring(s or "")
    if s == "" then return "?" end
    local ok, pos = pcall(function() return utf8.offset(s, 2) end)
    if ok and pos then return s:sub(1, pos - 1) end
    return s:sub(1, 1)
end

local function profilePath(name)
    local safe = tostring(name or ""):gsub("[^%w_-]", ""):sub(1, 32)
    if safe == "" then return nil end
    return "PrismaHub/" .. safe .. ".json"
end
local function saveDisk(name, data)
    if type(writefile) ~= "function" then return false end
    local path = profilePath(name); if not path then return false end
    if type(makefolder) == "function" then pcall(makefolder, "PrismaHub") end
    return pcall(writefile, path, HttpService:JSONEncode(data))
end
local function loadDisk(name)
    if type(readfile) ~= "function" then return nil end
    local path = profilePath(name); if not path then return nil end
    local ok, raw = pcall(readfile, path)
    if not ok or type(raw) ~= "string" then return nil end
    local parsed, value = pcall(function() return HttpService:JSONDecode(raw) end)
    return parsed and type(value) == "table" and value or nil
end
local function deleteProfile(name)
    local path = profilePath(name); if not path then return false end
    if type(delfile) ~= "function" then return false end
    return (pcall(delfile, path))
end
local function profileNames()
    local found = {}
    for name in pairs(App.slots) do found[name] = true end
    if type(listfiles) == "function" then
        local ok, files = pcall(listfiles, "PrismaHub")
        if ok and type(files) == "table" then
            for _, path in ipairs(files) do
                local name = tostring(path):gsub("\\", "/"):match("([^/]+)%.json$")
                if name then found[name] = true end
            end
        end
    end
    local r = {}; for n in pairs(found) do table.insert(r, n) end
    table.sort(r); return r
end
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end
local function corner(o, r)
    new("UICorner", { CornerRadius = UDim.new(0, r or 10) }, o); return o
end
local function stroke(o, color, thickness, transparency)
    return new("UIStroke", {
        Color = color or S.accent, Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, o)
end
local function grad(parent, colors, rotation)
    return new("UIGradient", { Color = ColorSequence.new(colors), Rotation = rotation or 0 }, parent)
end
local function tween(obj, info, props)
    local t = TweenService:Create(obj, info, props); t:Play(); return t
end
local function hover(obj, onEnter, onLeave)
    obj.MouseEnter:Connect(onEnter); obj.MouseLeave:Connect(onLeave)
end

local P = {
    bg0 = Color3.fromRGB(4, 5, 12), bg1 = Color3.fromRGB(9, 10, 20),
    bg2 = Color3.fromRGB(14, 15, 28), card = Color3.fromRGB(19, 20, 36),
    card2 = Color3.fromRGB(24, 26, 46), card3 = Color3.fromRGB(30, 32, 54),
    line = Color3.fromRGB(38, 39, 62), line2 = Color3.fromRGB(56, 58, 84),
    line3 = Color3.fromRGB(78, 80, 112), text = Color3.fromRGB(244, 242, 255),
    text2 = Color3.fromRGB(184, 182, 208), text3 = Color3.fromRGB(132, 130, 158),
    accent = Color3.fromRGB(165, 112, 255), accent2 = Color3.fromRGB(120, 190, 255),
    accent3 = Color3.fromRGB(255, 130, 200), danger = Color3.fromRGB(255, 90, 118),
    ok = Color3.fromRGB(90, 220, 150), warn = Color3.fromRGB(240, 200, 90),
}

-- ============================================================
-- GUI PARENT (safe, randomizado)
-- ============================================================
local RANDOM_NAMES = {
    "ChatWindow", "NotificationFrame", "HUD", "UI_Overlay",
    "BackpackUI", "SettingsPanel", "PlayerList",
}
local guiName = RANDOM_NAMES[math.random(1, #RANDOM_NAMES)] .. "_" .. tostring(math.random(1000, 9999))

local function getSafeGuiParent()
    if type(gethui) == "function" then
        local ok, hui = pcall(gethui)
        if ok and typeof(hui) == "Instance" then return hui end
    end
    local pg = LocalPlayer:WaitForChild("PlayerGui")
    local fake = Instance.new("Folder")
    fake.Name = "Settings"
    fake.Parent = pg
    return fake
end

local guiParent = getSafeGuiParent()

local okGui, Gui = pcall(function()
    return new("ScreenGui", {
        Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    }, guiParent)
end)
if not okGui then
    Gui = new("ScreenGui", {
        Name = guiName, ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999,
    }, LocalPlayer:WaitForChild("PlayerGui"))
end
own(Gui)

-- ============================================================
-- DRAW API (se disponível) — tracer super barato
-- ============================================================
local hasDrawing = (type(Drawing) == "table" and Drawing.new) and true or false
local drawLines = {}  -- [player] = DrawingLine

local function ensureDrawLine(p)
    if not hasDrawing then return nil end
    if drawLines[p] then return drawLines[p] end
    local ok, line = pcall(function()
        local l = Drawing.new("Line")
        l.Thickness = 1
        l.Transparency = 0.8
        l.Visible = false
        return l
    end)
    if ok and line then drawLines[p] = line; return line end
    return nil
end

-- ============================================================
-- CURSOR
-- ============================================================
local cursorDot = corner(new("Frame", {
    Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = P.accent, BorderSizePixel = 0, ZIndex = 9999, Visible = false,
}, Gui), 4)
local cursorDotStroke = stroke(cursorDot, P.accent, 2, 0.3)
local cursorRing = corner(new("Frame", {
    Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 9998, Visible = false,
}, Gui), 14)
local cursorRingStroke = stroke(cursorRing, P.accent, 1.5, 0.4)

connect(RunService.RenderStepped, function()
    if not App.alive or not cursorDot.Visible then return end
    if S.freecam then return end
    local m = UserInputService:GetMouseLocation()
    cursorDot.Position = UDim2.fromOffset(m.X, m.Y)
    cursorRing.Position = UDim2.fromOffset(m.X, m.Y)
end)

-- ============================================================
-- MAIN PANEL
-- ============================================================
local main = corner(new("Frame", {
    Name = "Painel", Size = UDim2.fromOffset(920, 620),
    Position = UDim2.new(.5, -460, .5, -310),
    BackgroundColor3 = P.bg0, BackgroundTransparency = S.glass,
    BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 10,
}, Gui), 20)

local function syncCursorVisibility()
    local v = main.Visible
    cursorDot.Visible = v
    cursorRing.Visible = v
end
connect(main:GetPropertyChangedSignal("Visible"), syncCursorVisibility)
syncCursorVisibility()

grad(main, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 18, 46)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(11, 12, 26)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(20, 15, 40)),
}, 118)

local edge = stroke(main, S.accent, 1.8, 0)
local edgeGrad = new("UIGradient", {
    Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, P.accent),
        ColorSequenceKeypoint.new(.35, P.accent2),
        ColorSequenceKeypoint.new(.65, P.accent3),
        ColorSequenceKeypoint.new(1, P.accent),
    }),
}, edge)

-- ============================================================
-- VIEWPORT 3D + PARTÍCULAS
-- ============================================================
local viewport = new("ViewportFrame", {
    Name = "Backdrop3D", Size = UDim2.fromScale(1, 1),
    Position = UDim2.fromScale(0, 0), BackgroundColor3 = P.bg0,
    BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 1,
}, main)
own(viewport)

local vpWorld = new("WorldModel", {}, viewport)
local vpCamera = new("Camera", {
    FieldOfView = 55, CFrame = CFrame.new(Vector3.new(0, 0, 12)),
}, viewport)
viewport.CurrentCamera = vpCamera

local particles3D = {}
for i = 1, 40 do
    local roll = math.random()
    local size
    if roll < 0.55 then size = 0.04 + math.random() * 0.04
    elseif roll < 0.88 then size = 0.09 + math.random() * 0.06
    else size = 0.16 + math.random() * 0.09 end
    local pick = math.random()
    local baseColor
    if pick < 0.45 then baseColor = P.accent
    elseif pick < 0.75 then baseColor = P.accent2
    elseif pick < 0.92 then baseColor = P.accent3
    else baseColor = Color3.fromRGB(255, 255, 255) end

    local p = new("Part", {
        Name = "Dust" .. i, Shape = Enum.PartType.Ball,
        Size = Vector3.new(size, size, size), Material = Enum.Material.Glass,
        Color = baseColor, Transparency = 0.15 + math.random() * 0.35,
        CastShadow = false, CanCollide = false, Anchored = true,
        CFrame = CFrame.new(
            (math.random() - 0.5) * 22,
            (math.random() - 0.5) * 13,
            (math.random() - 0.5) * 14
        ),
    }, vpWorld)

    table.insert(particles3D, {
        part = p, baseColor = baseColor, basePos = p.CFrame.Position, size = size,
        phase = math.random() * math.pi * 2,
        speedX = (math.random() - 0.5) * 0.6,
        speedY = (math.random() - 0.5) * 0.4,
        speedZ = (math.random() - 0.5) * 0.3,
        ampX = 0.4 + math.random() * 1.4,
        ampY = 0.5 + math.random() * 1.8,
        ampZ = 0.3 + math.random() * 1.0,
        pulse = 0.4 + math.random() * 0.8,
    })
end

local veil = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.bg0,
    BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 2,
}, main)
grad(veil, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 8, 22)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(6, 6, 16)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 9, 24)),
}, 118)

-- ============================================================
-- FPS / PING
-- ============================================================
local perfFrame = corner(new("Frame", {
    Size = UDim2.fromOffset(174, 24), Position = UDim2.new(1, -258, 0, 22),
    BackgroundColor3 = P.bg0, BackgroundTransparency = 0.35,
    BorderSizePixel = 0, ZIndex = 40,
}, main), 8)
local perfStroke = stroke(perfFrame, P.accent, 1, 0.5)
local perfLabel = new("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    TextColor3 = P.text, TextSize = 11, Font = Enum.Font.GothamMedium,
    Text = "FPS --  •  PING --", ZIndex = 41,
}, perfFrame)

-- ============================================================
-- TOAST
-- ============================================================
local toastGui = new("ScreenGui", {
    Name = guiName .. "_Toast", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 1000,
}, guiParent)
own(toastGui)

local toastContainer = new("Frame", {
    Size = UDim2.fromOffset(360, 400),
    Position = UDim2.new(0, 16, 1, -420),
    BackgroundTransparency = 1, ZIndex = 60,
}, toastGui)
new("UIListLayout", {
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom,
}, toastContainer)

local MAX_TOASTS = 5
local activeToasts = {}

local function notify(text, kind)
    if not App.alive then return end
    kind = kind or "info"
    local accent = kind == "success" and P.ok
        or kind == "error" and P.danger
        or kind == "warn" and P.warn or S.accent
    local icon = kind == "success" and "✓"
        or kind == "error" and "✕"
        or kind == "warn" and "!" or "◆"

    while #activeToasts >= MAX_TOASTS do
        local old = table.remove(activeToasts, 1)
        if old then pcall(function() old:Destroy() end) end
    end

    local wrap = new("Frame", {
        Size = UDim2.fromOffset(340, 52), BackgroundTransparency = 1,
        LayoutOrder = -tick(), ZIndex = 61,
    }, toastContainer)
    table.insert(activeToasts, wrap)

    local bg = corner(new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = P.card,
        BackgroundTransparency = 0.06, BorderSizePixel = 0, ZIndex = 61,
    }, wrap), 12)
    local bgStroke = stroke(bg, accent, 1.2, 0.35)

    corner(new("Frame", {
        Size = UDim2.new(0, 3, 1, -18), Position = UDim2.new(0, 11, 0, 9),
        BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 62,
    }, bg), 2)
    new("TextLabel", {
        Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(24, 11),
        BackgroundTransparency = 1, Text = icon, TextColor3 = accent,
        TextSize = 17, Font = Enum.Font.GothamBold, ZIndex = 62,
    }, bg)
    new("TextLabel", {
        Size = UDim2.new(1, -72, 1, -14), Position = UDim2.fromOffset(58, 7),
        BackgroundTransparency = 1, Text = tostring(text),
        TextColor3 = P.text, TextSize = 12, Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 62,
    }, bg)

    task.delay(3.6, function()
        if not App.alive then return end
        tween(bg, TweenInfo.new(.3), { BackgroundTransparency = 1 })
        tween(bgStroke, TweenInfo.new(.3), { Transparency = 1 })
        for _, c in ipairs(bg:GetChildren()) do
            if c:IsA("TextLabel") then
                tween(c, TweenInfo.new(.3), { TextTransparency = 1 })
            elseif c:IsA("Frame") then
                tween(c, TweenInfo.new(.3), { BackgroundTransparency = 1 })
            end
        end
        task.delay(.34, function()
            for i, t in ipairs(activeToasts) do
                if t == wrap then table.remove(activeToasts, i); break end
            end
            pcall(function() wrap:Destroy() end)
        end)
    end)
end

-- ============================================================
-- ACCENT
-- ============================================================
local function setAccent(color)
    local old = S.accent
    for _, o in ipairs(Gui:GetDescendants()) do
        if o:IsA("UIStroke") and o.Color == old then o.Color = color
        elseif o:IsA("TextLabel") and o.TextColor3 == old then o.TextColor3 = color
        elseif o:IsA("GuiObject") and o.BackgroundColor3 == old then o.BackgroundColor3 = color end
    end
    S.accent = color
    perfStroke.Color = color
    cursorDot.BackgroundColor3 = color
    cursorDotStroke.Color = color
    cursorRingStroke.Color = color
end

-- ============================================================
-- PARTÍCULAS 2D
-- ============================================================
local particleContainer = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    ClipsDescendants = true, ZIndex = 5,
}, main)

local function spawnParticle()
    if not S.particles or not App.alive then return end
    local size = math.random(2, 4)
    local p = corner(new("Frame", {
        Size = UDim2.fromOffset(size, size),
        Position = UDim2.new(math.random(), 0, 1.05, 0),
        BackgroundColor3 = S.accent, BackgroundTransparency = 0.5,
        BorderSizePixel = 0, ZIndex = 5,
    }, particleContainer), size)
    stroke(p, S.accent2, 1, 0.4)
    local duration = math.random(9, 17)
    local targetY = -0.05 - math.random() * 0.15
    local targetX = p.Position.X.Scale + (math.random() - 0.5) * 0.15
    local t = TweenService:Create(p, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
        Position = UDim2.new(targetX, 0, targetY, 0), BackgroundTransparency = 1,
    })
    t:Play()
    t.Completed:Connect(function() pcall(function() p:Destroy() end) end)
    table.insert(App.particles, p)
end

task.spawn(function()
    while App.alive do
        task.wait(math.random(60, 120) / 100)
        if #App.particles > 20 then
            local oldest = table.remove(App.particles, 1)
            if oldest then pcall(function() oldest:Destroy() end) end
        end
        spawnParticle()
    end
end)

-- ============================================================
-- SIDEBAR
-- ============================================================
local side = new("Frame", {
    Size = UDim2.new(0, 90, 1, 0),
    BackgroundColor3 = Color3.fromRGB(6, 7, 15),
    BackgroundTransparency = .15, BorderSizePixel = 0,
    ClipsDescendants = true, ZIndex = 15,
}, main)
grad(side, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(13, 13, 26)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 7, 15)),
}, 90)
new("Frame", {
    Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = P.line, BackgroundTransparency = .35,
    BorderSizePixel = 0, ZIndex = 16,
}, side)

local logoGlow = corner(new("Frame", {
    Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(13, 12),
    BackgroundColor3 = P.accent, BackgroundTransparency = 0.85,
    BorderSizePixel = 0, ZIndex = 15,
}, side), 16)
local logo = new("TextLabel", {
    Size = UDim2.fromOffset(64, 64), Position = UDim2.fromOffset(13, 12),
    BackgroundTransparency = 1, Text = "◈", TextColor3 = P.accent,
    TextSize = 38, Font = Enum.Font.GothamBold, ZIndex = 16,
}, side)
grad(logo, {
    ColorSequenceKeypoint.new(0, P.accent),
    ColorSequenceKeypoint.new(.5, P.accent2),
    ColorSequenceKeypoint.new(1, P.accent3),
}, 0)

local nav = new("Frame", {
    Size = UDim2.new(1, -16, 1, -110), Position = UDim2.fromOffset(8, 88),
    BackgroundTransparency = 1, ZIndex = 16,
}, side)
new("UIListLayout", {
    Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
}, nav)

local activeIndicator = corner(new("Frame", {
    Size = UDim2.fromOffset(3, 26), Position = UDim2.fromOffset(1, 90),
    BackgroundColor3 = P.accent, BorderSizePixel = 0, Visible = false, ZIndex = 17,
}, side), 2)
stroke(activeIndicator, P.accent, 4, .35)

-- ============================================================
-- HEADER
-- ============================================================
local subtitle = new("TextLabel", {
    Size = UDim2.new(1, -340, 0, 14), Position = UDim2.fromOffset(116, 22),
    BackgroundTransparency = 1, Text = "PRISMA NEXUS  •  HYPERION",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = P.accent, TextSize = 11, Font = Enum.Font.GothamBold, ZIndex = 16,
}, main)
grad(subtitle, {
    ColorSequenceKeypoint.new(0, P.accent),
    ColorSequenceKeypoint.new(1, P.accent3),
}, 0)

local title = new("TextLabel", {
    Size = UDim2.new(1, -300, 0, 36), Position = UDim2.fromOffset(114, 40),
    BackgroundTransparency = 1, Text = "Início",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = P.text, TextSize = 26, Font = Enum.Font.GothamBold, ZIndex = 16,
}, main)

local subtitlePage = new("TextLabel", {
    Size = UDim2.new(1, -340, 0, 18), Position = UDim2.fromOffset(116, 76),
    BackgroundTransparency = 1, Text = "Painel da sessão",
    TextXAlignment = Enum.TextXAlignment.Left,
    TextColor3 = P.text3, TextSize = 11, Font = Enum.Font.Gotham, ZIndex = 16,
}, main)

local statusDot = corner(new("Frame", {
    Size = UDim2.fromOffset(7, 7), Position = UDim2.fromOffset(106, 46),
    BackgroundColor3 = P.ok, BorderSizePixel = 0, ZIndex = 16,
}, main), 4)
local statusGlow = stroke(statusDot, P.ok, 3, .3)

local close = corner(new("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -42, 0, 20),
    BackgroundColor3 = P.card, BackgroundTransparency = .2,
    Text = "×", TextColor3 = P.text2, TextSize = 20,
    Font = Enum.Font.Gotham, AutoButtonColor = false, ZIndex = 42,
}, main), 9)
local closeStroke = stroke(close, P.line2, 1, .3)
hover(close,
    function()
        tween(close, TweenInfo.new(.2), { BackgroundColor3 = P.danger, BackgroundTransparency = .05, TextColor3 = P.text, Rotation = 90 })
        closeStroke.Color = P.danger
    end,
    function()
        tween(close, TweenInfo.new(.25), { BackgroundColor3 = P.card, BackgroundTransparency = .2, TextColor3 = P.text2, Rotation = 0 })
        closeStroke.Color = P.line2
    end)

local minimize = corner(new("TextButton", {
    Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -78, 0, 20),
    BackgroundColor3 = P.card, BackgroundTransparency = .2,
    Text = "−", TextColor3 = P.text2, TextSize = 18,
    Font = Enum.Font.Gotham, AutoButtonColor = false, ZIndex = 42,
}, main), 9)
local minStroke = stroke(minimize, P.line2, 1, .3)
hover(minimize,
    function()
        tween(minimize, TweenInfo.new(.2), { BackgroundColor3 = P.accent, BackgroundTransparency = .05, TextColor3 = P.text })
        minStroke.Color = P.accent
    end,
    function()
        tween(minimize, TweenInfo.new(.25), { BackgroundColor3 = P.card, BackgroundTransparency = .2, TextColor3 = P.text2 })
        minStroke.Color = P.line2
    end)

-- ============================================================
-- CONTENT
-- ============================================================
local content = new("ScrollingFrame", {
    Size = UDim2.new(1, -140, 1, -190), Position = UDim2.fromOffset(114, 130),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 3, ScrollBarImageColor3 = P.line2,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollingDirection = Enum.ScrollingDirection.Y,
    ElasticBehavior = Enum.ElasticBehavior.Never, Active = true, ZIndex = 16,
}, main)
local stack = new("UIListLayout", {
    Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder,
}, content)
new("UIPadding", {
    PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 18),
    PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 24),
}, content)
connect(stack:GetPropertyChangedSignal("AbsoluteContentSize"), function()
    content.CanvasSize = UDim2.fromOffset(0, stack.AbsoluteContentSize.Y + 30)
end)

new("Frame", {
    Size = UDim2.new(1, -140, 0, 1), Position = UDim2.new(0, 114, 1, -44),
    BackgroundColor3 = P.line, BackgroundTransparency = .5,
    BorderSizePixel = 0, ZIndex = 16,
}, main)
new("TextLabel", {
    Size = UDim2.new(1, -140, 0, 24), Position = UDim2.new(0, 114, 1, -36),
    BackgroundTransparency = 1,
    Text = "PRISMA NEXUS  •  " .. LocalPlayer.Name .. "     F3: minimizar  •  Delete: panic  •  Alt+clique: alvo do fling",
    TextColor3 = P.text3, TextSize = 10, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 16,
}, main)

-- ============================================================
-- SCALE
-- ============================================================
local scaleObj = new("UIScale", { Scale = 1 }, main)
local function resize()
    local camera = Workspace.CurrentCamera
    local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
    scaleObj.Scale = math.min(S.scale, math.max(.52, math.min((size.X - 24) / 920, (size.Y - 24) / 620)))
    if not App.userMovedPanel then
        main.Position = UDim2.new(.5, -460 * scaleObj.Scale, .5, -310 * scaleObj.Scale)
    end
end
resize()
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), resize)
if Workspace.CurrentCamera then
    connect(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), resize)
end

-- ============================================================
-- DRAG
-- ============================================================
local dragging, dragStart, startPos
connect(side.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
        App.userMovedPanel = true
    end
end)
connect(UserInputService.InputChanged, function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                  startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- ============================================================
-- PAGE HELPERS
-- ============================================================
local pageMaid = Maid.new()

local function clearContent()
    pageMaid:cleanup()
    pageMaid = Maid.new()
    for _, c in ipairs(App.pageConnections) do pcall(function() c:Disconnect() end) end
    table.clear(App.pageConnections)
    table.clear(App.toggleVisuals)
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end
    content.CanvasPosition = Vector2.zero
end

local function section(text)
    local wrap = new("Frame", {
        Size = UDim2.new(1, -6, 0, 26), BackgroundTransparency = 1, ZIndex = 17,
    }, content)
    local bar = corner(new("Frame", {
        Size = UDim2.fromOffset(3, 14), Position = UDim2.fromOffset(0, 6),
        BackgroundColor3 = S.accent, BorderSizePixel = 0, ZIndex = 17,
    }, wrap), 2)
    grad(bar, {
        ColorSequenceKeypoint.new(0, S.accent),
        ColorSequenceKeypoint.new(1, P.accent2),
    }, 90)
    new("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(16, 0),
        BackgroundTransparency = 1, Text = string.upper(text),
        TextColor3 = P.text2, TextSize = 10, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 17,
    }, wrap)
    return wrap
end

local function card(height)
    local f = corner(new("Frame", {
        Size = UDim2.new(1, -8, 0, height),
        BackgroundColor3 = P.card, BackgroundTransparency = 0.08,
        BorderSizePixel = 0, ZIndex = 17,
    }, content), 14)
    local s = stroke(f, P.line2, 1, .55)
    grad(f, {
        ColorSequenceKeypoint.new(0, P.card2),
        ColorSequenceKeypoint.new(.5, P.card),
        ColorSequenceKeypoint.new(1, P.card2),
    }, 115)

    local innerHighlight = new("Frame", {
        Size = UDim2.new(1, -4, 0, 1), Position = UDim2.fromOffset(2, 1),
        BackgroundColor3 = P.line3, BackgroundTransparency = .55,
        BorderSizePixel = 0, ZIndex = 18,
    }, f)

    pageConnect(f.MouseEnter, function()
        tween(s, TweenInfo.new(.25), { Color = S.accent, Transparency = .3 })
    end)
    pageConnect(f.MouseLeave, function()
        tween(s, TweenInfo.new(.35), { Color = P.line2, Transparency = .55 })
        tween(f, TweenInfo.new(.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 })
    end)
    pageConnect(f.MouseMoved, function(x)
        if not S.tiltStrength or S.tiltStrength <= 0 then return end
        local w = f.AbsoluteSize.X
        if w <= 0 then return end
        local mx = clamp((x - f.AbsolutePosition.X) / w, 0, 1)
        f.Rotation = (mx - .5) * 2 * 1.15 * S.tiltStrength
        tween(innerHighlight, TweenInfo.new(.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(clamp(mx - 0.04, 0, 0.92), 0, 1, 0),
            BackgroundTransparency = .25,
        })
    end)
    return f
end

local function label(parent, text, x, y, w, h, color, size, bold)
    return new("TextLabel", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundTransparency = 1, Text = text,
        TextColor3 = color or P.text, TextSize = size or 13,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 18,
    }, parent)
end

local function button(parent, text, x, y, w, h, fn, primary)
    local b = corner(new("TextButton", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = primary and S.accent or P.bg1,
        TextColor3 = P.text, TextSize = 12, Font = Enum.Font.GothamBold,
        Text = text, AutoButtonColor = false, ZIndex = 18,
    }, parent), 10)
    local s = stroke(b, primary and S.accent or P.line2, 1, primary and .3 or .5)
    if primary then
        grad(b, {
            ColorSequenceKeypoint.new(0, S.accent),
            ColorSequenceKeypoint.new(.5, P.accent2),
            ColorSequenceKeypoint.new(1, S.accent),
        }, 0)
    end

    local scale = new("UIScale", { Scale = 1 }, b)
    local rippleHolder = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        ClipsDescendants = true, ZIndex = 19,
    }, b)

    hover(b,
        function()
            tween(b, TweenInfo.new(.2), { BackgroundColor3 = primary and P.accent2 or P.card2 })
            tween(scale, TweenInfo.new(.2), { Scale = 1.03 })
            if not primary then
                tween(s, TweenInfo.new(.2), { Color = S.accent, Transparency = .3 })
            end
        end,
        function()
            tween(b, TweenInfo.new(.25), { BackgroundColor3 = primary and S.accent or P.bg1 })
            tween(scale, TweenInfo.new(.25), { Scale = 1 })
            if not primary then
                tween(s, TweenInfo.new(.25), { Color = P.line2, Transparency = .5 })
            end
        end)

    pageConnect(b.MouseButton1Down, function()
        local m = UserInputService:GetMouseLocation()
        local rel = b.AbsolutePosition
        local r = corner(new("Frame", {
            AnchorPoint = Vector2.new(.5, .5),
            Position = UDim2.fromOffset(m.X - rel.X, m.Y - rel.Y),
            Size = UDim2.fromOffset(0, 0),
            BackgroundColor3 = P.text, BackgroundTransparency = .55,
            BorderSizePixel = 0, ZIndex = 19,
        }, rippleHolder), 999)
        local maxSize = math.max(w, h) * 2
        tween(r, TweenInfo.new(.6, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.fromOffset(maxSize, maxSize), BackgroundTransparency = 1,
        })
        task.delay(.65, function() pcall(function() r:Destroy() end) end)
        tween(scale, TweenInfo.new(.08), { Scale = .95 })
    end)

    pageConnect(b.MouseButton1Click, function()
        tween(scale, TweenInfo.new(.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
        if App.alive then
            local ok, e = pcall(fn)
            if not ok then notify("Falha: " .. tostring(e):sub(1, 80), "error") end
        end
    end)
    return b
end

local function input(parent, placeholder, x, y, w, h, default)
    local box = corner(new("TextBox", {
        Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
        BackgroundColor3 = P.bg0, TextColor3 = P.text,
        PlaceholderColor3 = P.text3, PlaceholderText = placeholder,
        Text = default or "", TextSize = 12, Font = Enum.Font.Gotham,
        ClearTextOnFocus = false, ZIndex = 18,
    }, parent), 10)
    local s = stroke(box, P.line2, 1, .5)
    pageConnect(box.Focused, function()
        tween(s, TweenInfo.new(.22), { Color = S.accent, Transparency = .15, Thickness = 1.6 })
    end)
    pageConnect(box.FocusLost, function()
        tween(s, TweenInfo.new(.28), { Color = P.line2, Transparency = .5, Thickness = 1 })
    end)
    return box
end

local function toggle(text, key, desc, fn)
    local f = card(desc and 88 or 68)
    label(f, text, 22, 15, 540, 22, P.text, 13, true)
    if desc then label(f, desc, 22, 42, 555, 25, P.text3, 11, false) end

    local pill = corner(new("TextButton", {
        Position = UDim2.new(1, -74, 0, desc and 26 or 17),
        Size = UDim2.fromOffset(58, 30),
        BackgroundColor3 = S[key] and S.accent or P.bg0,
        Text = "", AutoButtonColor = false, ZIndex = 19,
    }, f), 16)
    local pillStroke = stroke(pill, P.line2, 1, .4)
    local dot = corner(new("Frame", {
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(S[key] and 32 or 4, 4),
        BackgroundColor3 = S[key] and P.text or P.text3,
        BorderSizePixel = 0, ZIndex = 20,
    }, pill), 11)

    local bindButton = corner(new("TextButton", {
        Position = UDim2.new(1, -168, 0, desc and 26 or 17),
        Size = UDim2.fromOffset(80, 30),
        BackgroundColor3 = P.bg0, TextColor3 = P.text3,
        Text = S.binds[key] or "Atalho", TextSize = 10,
        Font = Enum.Font.GothamMedium, AutoButtonColor = false, ZIndex = 18,
    }, f), 9)
    local bindStroke = stroke(bindButton, P.line2, 1, .5)

    hover(bindButton,
        function()
            tween(bindStroke, TweenInfo.new(.2), { Color = S.accent, Transparency = .3 })
            tween(bindButton, TweenInfo.new(.2), { TextColor3 = P.text })
        end,
        function()
            tween(bindStroke, TweenInfo.new(.25), { Color = P.line2, Transparency = .5 })
            tween(bindButton, TweenInfo.new(.25), { TextColor3 = P.text3 })
        end)

    App.toggleHandlers[key] = fn
    App.toggleVisuals[key] = function()
        local on = S[key]
        tween(pill, TweenInfo.new(.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            BackgroundColor3 = on and S.accent or P.bg0,
        })
        tween(dot, TweenInfo.new(.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Position = UDim2.fromOffset(on and 32 or 4, 4),
            BackgroundColor3 = on and P.text or P.text3,
        })
        tween(pillStroke, TweenInfo.new(.28), {
            Color = on and S.accent or P.line2,
            Transparency = on and .2 or .4,
        })
        bindButton.Text = S.binds[key] or "Atalho"
    end

    pageConnect(bindButton.MouseButton1Click, function()
        App.bindCapture = key
        bindButton.Text = "Tecla..."
        notify("Pressione uma tecla ou botão do mouse; Esc cancela", "info")
    end)
    pageConnect(pill.MouseButton1Click, function()
        S[key] = not S[key]
        App.toggleVisuals[key]()
        if fn then
            local ok, e = pcall(fn, S[key])
            if not ok then notify("Falha: " .. tostring(e):sub(1, 80), "error") end
        end
    end)
    return f
end

local function slider(text, key, min, max, step, fmt, fn)
    local f = card(90)
    label(f, text, 22, 13, 440, 20, P.text, 12, true)
    local val = input(f, fmt and fmt(S[key]) or tostring(S[key]), 600, 11, 140, 30, tostring(S[key]))
    val.TextColor3 = S.accent
    val.TextXAlignment = Enum.TextXAlignment.Center

    local bar = corner(new("Frame", {
        Position = UDim2.fromOffset(22, 57),
        Size = UDim2.new(1, -46, 0, 10),
        BackgroundColor3 = P.bg0, ZIndex = 18,
    }, f), 5)
    local fill = corner(new("Frame", {
        Size = UDim2.new((S[key] - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = S.accent, ZIndex = 19,
    }, bar), 5)
    grad(fill, {
        ColorSequenceKeypoint.new(0, S.accent),
        ColorSequenceKeypoint.new(1, P.accent2),
    }, 0)

    local thumb = corner(new("Frame", {
        Size = UDim2.fromOffset(18, 18), AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.new((S[key] - min) / (max - min), 0, .5, 0),
        BackgroundColor3 = P.text, BorderSizePixel = 0, ZIndex = 20,
    }, bar), 9)
    stroke(thumb, S.accent, 2, .2)
    local thumbScale = new("UIScale", { Scale = 1 }, thumb)

    local active = false
    local function setValue(n)
        S[key] = clamp(math.floor(n / step + .5) * step, min, max)
        local alpha = (S[key] - min) / (max - min)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        thumb.Position = UDim2.new(alpha, 0, .5, 0)
        val.Text = fmt and fmt(S[key]) or tostring(S[key])
        if fn then fn(S[key]) end
    end
    local function update(px)
        local a = clamp((px - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        setValue(min + a * (max - min))
    end

    pageConnect(val.FocusLost, function()
        local n = tonumber(val.Text)
        if n then setValue(n) else val.Text = fmt and fmt(S[key]) or tostring(S[key]) end
    end)
    pageConnect(bar.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            active = true
            if key == "aimFov" then App.fovPreview = true end
            tween(thumbScale, TweenInfo.new(.18), { Scale = 1.4 })
            update(i.Position.X)
        end
    end)
    pageConnect(UserInputService.InputChanged, function(i)
        if active and (i.UserInputType == Enum.UserInputType.MouseMovement
            or i.UserInputType == Enum.UserInputType.Touch) then
            update(i.Position.X)
        end
    end)
    pageConnect(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1
            or i.UserInputType == Enum.UserInputType.Touch then
            active = false
            if key == "aimFov" then App.fovPreview = false end
            tween(thumbScale, TweenInfo.new(.22), { Scale = 1 })
        end
    end)
    return f
end

local function action(text, desc, fn)
    local f = card(86)
    label(f, text, 22, 13, 510, 23, P.text, 13, true)
    label(f, desc or "", 22, 42, 535, 26, P.text3, 11)
    button(f, "Executar", 630, 24, 118, 36, fn, true)
    return f
end

-- ============================================================
-- CHARACTER HELPERS
-- ============================================================
local function character() return LocalPlayer.Character end
local function humanoid()
    local c = character(); return c and c:FindFirstChildOfClass("Humanoid")
end
local function root()
    local c = character(); return c and c:FindFirstChild("HumanoidRootPart")
end
local function selectedCharacter() return App.selected and App.selected.Character end
local function selectedRoot()
    local c = selectedCharacter(); return c and c:FindFirstChild("HumanoidRootPart")
end

local function teleportNearSelected()
    local target = selectedRoot(); local mine = root(); local c = character()
    if not target or not mine or not c then
        return notify("Selecione um jogador com personagem carregado", "warn")
    end
    task.spawn(function()
        for _ = 1, 5 do
            if not App.alive or not target.Parent or not c.Parent then return end
            local destination = target.Position - target.CFrame.LookVector * 4 + Vector3.new(0, 3, 0)
            c:PivotTo(CFrame.lookAt(destination, target.Position))
            mine.AssemblyLinearVelocity = Vector3.zero
            task.wait(.08)
        end
        if (mine.Position - target.Position).Magnitude > 18 then
            notify("O jogo reposicionou seu personagem; teleporte limitado", "warn")
        else notify("Teleporte concluído", "success") end
    end)
end

-- ============================================================
-- FLING v3
-- ============================================================
local LIMB_NAMES = {
    "HumanoidRootPart", "Head", "Torso", "UpperTorso", "LowerTorso",
    "Left Arm", "Right Arm", "Left Leg", "Right Leg",
    "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
    "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
    "LeftHand", "RightHand", "LeftFoot", "RightFoot",
}

local function getLimbSet(char, set)
    local list = {}
    for _, name in ipairs(LIMB_NAMES) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            local include = false
            if set == "all" then include = true
            elseif set == "torso" then
                include = name == "HumanoidRootPart" or name == "Torso"
                    or name == "UpperTorso" or name == "LowerTorso"
            elseif set == "arms" then
                include = name:find("Arm") or name:find("Hand")
            elseif set == "legs" then
                include = name:find("Leg") or name:find("Foot")
            end
            if include then table.insert(list, p) end
        end
    end
    return list
end

local function tryStealOwner(part)
    if not part or not part.Parent then return false, "no_part" end
    local ok0, owner0 = pcall(function() return part:GetNetworkOwner() end)
    if ok0 and owner0 == LocalPlayer then return true, "already" end

    local ok1, canSet = pcall(function() return part:CanSetNetworkOwnership() end)
    if not ok1 then return false, "check_fail" end
    if canSet == false then
        return false, "locked:" .. ((owner0 and owner0.Name) or "server")
    end

    for _ = 1, 4 do
        pcall(function() part:SetNetworkOwner(LocalPlayer) end)
        local ok2, owner2 = pcall(function() return part:GetNetworkOwner() end)
        if ok2 and owner2 == LocalPlayer then return true, "stolen" end
        task.wait(0.02)
    end
    return false, "denied:" .. ((owner0 and owner0.Name) or "server")
end

local function flingClearParts()
    for _, p in ipairs(App.flingParts) do pcall(function() p:Destroy() end) end
    table.clear(App.flingParts)
end

local function spawnFlingPart(parent, offset, size, velocity, mass)
    local p = Instance.new("Part")
    p.Size = size
    p.CFrame = parent.CFrame * CFrame.new(offset)
    p.CanCollide = true
    p.CanTouch = false
    p.CanQuery = false
    p.Transparency = 1
    p.Massless = false
    p.CustomPhysicalProperties = PhysicalProperties.new(mass, 0.3, 0.5, 1, 1)
    p.Parent = Workspace

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = p
    weld.Part1 = parent
    weld.Parent = p

    if velocity then p.AssemblyLinearVelocity = velocity end
    table.insert(App.flingParts, p)
    return p
end

local function modeLimbRush(limbs)
    local stolen = 0
    for _, limb in ipairs(limbs) do
        local ok = tryStealOwner(limb)
        if ok then
            stolen += 1
            limb.AssemblyLinearVelocity = Vector3.new(
                (math.random() - 0.5) * S.flingPower * 2,
                S.flingPower * (1.2 + math.random() * 0.8),
                (math.random() - 0.5) * S.flingPower * 2
            )
            limb.AssemblyAngularVelocity = Vector3.new(S.flingPower, S.flingPower, S.flingPower)
        end
    end
    App.flingDiag.stolen = stolen
    App.flingDiag.total = #limbs
    return stolen
end

local function modeWeldCage(limbs)
    local hrp = nil
    for _, l in ipairs(limbs) do
        if l.Name == "HumanoidRootPart" then hrp = l break end
    end
    hrp = hrp or limbs[1]
    if not hrp then return 0 end
    local ok = tryStealOwner(hrp)
    App.flingDiag.stolen = ok and 1 or 0
    App.flingDiag.total = 1
    if not ok then return 0 end

    for i = 1, S.flingRips do
        local dir = Vector3.new(
            (i % 2 == 0) and 1 or -1,
            (i % 3 == 0) and 1 or -1,
            (i % 5 == 0) and 1 or -1
        )
        spawnFlingPart(hrp,
            Vector3.new((math.random() - 0.5) * 3, (math.random() - 0.5) * 3, (math.random() - 0.5) * 3),
            Vector3.new(1, 1, 1), dir * S.flingPower, 0.7)
    end
    return 1
end

local function modeTorsoKick(limbs)
    local hrp = nil
    for _, l in ipairs(limbs) do
        if l.Name == "HumanoidRootPart" then hrp = l break end
    end
    hrp = hrp or limbs[1]
    if not hrp then return 0 end
    local ok = tryStealOwner(hrp)
    App.flingDiag.stolen = ok and 1 or 0
    App.flingDiag.total = 1
    if not ok then return 0 end

    hrp.AssemblyLinearVelocity = Vector3.new(
        (math.random() - 0.5) * S.flingPower * 3,
        S.flingPower * 2,
        (math.random() - 0.5) * S.flingPower * 3
    )
    hrp.AssemblyAngularVelocity = Vector3.new(S.flingPower * 3, S.flingPower * 3, S.flingPower * 3)
    return 1
end

local function modeLagSlam(limbs)
    local stolen = 0
    for _, limb in ipairs(limbs) do
        local ok = tryStealOwner(limb)
        if ok then
            stolen += 1
            limb.AssemblyLinearVelocity = Vector3.new(
                (math.random() - 0.5) * S.flingPower * 4,
                S.flingPower * 3,
                (math.random() - 0.5) * S.flingPower * 4
            )
            limb.AssemblyAngularVelocity = Vector3.new(S.flingPower * 2, S.flingPower * 2, S.flingPower * 2)
        end
    end
    App.flingDiag.stolen = stolen
    App.flingDiag.total = #limbs
    return stolen
end

local function modeExecute(limbs)
    local stolen = 0
    for _, limb in ipairs(limbs) do
        local ok = tryStealOwner(limb)
        if ok then
            stolen += 1
            limb.CFrame = limb.CFrame * CFrame.new(
                (math.random() - 0.5) * 40,
                100 + math.random() * 100,
                (math.random() - 0.5) * 40
            )
        end
    end
    App.flingDiag.stolen = stolen
    App.flingDiag.total = #limbs
    return stolen
end

local FLING_MODES = {
    LIMB_RUSH  = { fn = modeLimbRush,  label = "Limb Rush",  desc = "Velocidade em cada limb roubado — replicado" },
    LAGSLAM    = { fn = modeLagSlam,   label = "Lag Slam",   desc = "Todos os limbs com velocidade máxima" },
    TORSO_KICK = { fn = modeTorsoKick, label = "Torso Kick", desc = "Só HRP, velocidade extrema" },
    WELD_CAGE  = { fn = modeWeldCage,  label = "Weld Cage",  desc = "Solda caixas com velocidades opostas" },
    EXECUTE    = { fn = modeExecute,   label = "Execute",    desc = "Teleporta cada limb — visual extremo" },
}

local function flingApplyOnce()
    local plr = App.flingTarget
    if not plr or not plr.Character then return end
    local char = plr.Character
    local limbs = getLimbSet(char, S.flingLimbSet)
    if #limbs == 0 then return end
    local mode = FLING_MODES[S.flingMode] or FLING_MODES.LIMB_RUSH
    pcall(mode.fn, limbs)
end

local function flingStart()
    if App.flingThread then return end
    if not App.flingTarget then return notify("Selecione um alvo (Alt+clique)", "warn") end
    flingClearParts()
    App.flingDiag = { stolen = 0, total = 0, mode = S.flingMode }
    App.flingThread = task.spawn(function()
        while App.alive and App.flingTarget do
            local ok = pcall(flingApplyOnce)
            if not ok then break end
            task.wait(S.flingRate)
        end
        App.flingThread = nil
        flingClearParts()
    end)
end

local function flingStop()
    if App.flingThread then
        pcall(function() task.cancel(App.flingThread) end)
        App.flingThread = nil
    end
    flingClearParts()
end

local function flingClearTarget()
    App.flingTarget = nil
    flingStop()
end

-- ============================================================
-- GODMODE (sem MaxHealth absurdo)
-- ============================================================
local GODMODE_TARGET_HP = 9999

local function clearGodmodeConns()
    if App.godmodeConn then pcall(function() App.godmodeConn:Disconnect() end); App.godmodeConn = nil end
    if App.godmodeDiedConn then pcall(function() App.godmodeDiedConn:Disconnect() end); App.godmodeDiedConn = nil end
    if App.godmodeFFConn then pcall(function() App.godmodeFFConn:Disconnect() end); App.godmodeFFConn = nil end
end

local function applyGodmodeTo(h, c)
    if not h or not c then return end
    pcall(function() h:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
    pcall(function() h.BreakJointsOnDeath = false end)
    pcall(function() h.RequiresNeck = false end)
    -- Não mexe em MaxHealth (evita detecção) — só mantém Health alto
    pcall(function()
        local cap = math.min(h.MaxHealth, GODMODE_TARGET_HP)
        if h.Health < cap then h.Health = cap end
    end)
    if c:FindFirstChildOfClass("ForceField") == nil then
        pcall(function()
            local ff = Instance.new("ForceField")
            ff.Name = "PrismaGodFF"
            ff.Visible = false
            ff.Parent = c
        end)
    end
end

local function startGodmode()
    clearGodmodeConns()
    local c = character()
    local h = humanoid()
    if not h or not c then
        task.spawn(function()
            local cc = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local hh = cc:WaitForChild("Humanoid", 5)
            if hh and S.godmode then applyGodmodeTo(hh, cc) end
        end)
        return
    end

    App.originalHumanoids[h] = App.originalHumanoids[h] or {}
    App.originalHumanoids[h].MaxHealth = h.MaxHealth
    App.originalHumanoids[h].Health = h.Health
    App.originalHumanoids[h].DeadStateEnabled = h:GetStateEnabled(Enum.HumanoidStateType.Dead)

    applyGodmodeTo(h, c)

    App.godmodeLoop = task.spawn(function()
        while App.alive and S.godmode do
            local cc = character()
            local hh = cc and cc:FindFirstChildOfClass("Humanoid")
            if hh then
                pcall(function()
                    local cap = math.min(hh.MaxHealth, GODMODE_TARGET_HP)
                    if hh.Health < cap then hh.Health = cap end
                end)
                if cc and cc:FindFirstChildOfClass("ForceField") == nil then
                    pcall(function()
                        local ff = Instance.new("ForceField")
                        ff.Name = "PrismaGodFF"
                        ff.Visible = false
                        ff.Parent = cc
                    end)
                end
            end
            task.wait(0.1)
        end
    end)

    App.godmodeDiedConn = h.Died:Connect(function()
        if not S.godmode or not App.alive then return end
        task.wait(0.05)
        local cc = character()
        local hh = cc and cc:FindFirstChildOfClass("Humanoid")
        if hh then
            pcall(function()
                hh:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
                local cap = math.min(hh.MaxHealth, GODMODE_TARGET_HP)
                hh.Health = cap
            end)
        end
    end)

    App.godmodeConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
        if not S.godmode or not App.alive then return end
        task.wait(0.5)
        local nh = newChar:WaitForChild("Humanoid", 5)
        if nh then applyGodmodeTo(nh, newChar) end
    end)
end

local function stopGodmode()
    clearGodmodeConns()
    if App.godmodeLoop then
        pcall(function() task.cancel(App.godmodeLoop) end)
        App.godmodeLoop = nil
    end
    local c = character()
    if c then
        local ff = c:FindFirstChild("PrismaGodFF")
        if ff then pcall(function() ff:Destroy() end) end
    end
    local h = humanoid()
    if h and App.originalHumanoids[h] then
        pcall(function()
            h:SetStateEnabled(Enum.HumanoidStateType.Dead, App.originalHumanoids[h].DeadStateEnabled ~= false)
            h.BreakJointsOnDeath = true
            h.RequiresNeck = true
            if App.originalHumanoids[h].MaxHealth then h.MaxHealth = App.originalHumanoids[h].MaxHealth end
            if App.originalHumanoids[h].Health then
                h.Health = math.min(App.originalHumanoids[h].Health, h.MaxHealth)
            end
        end)
        App.originalHumanoids[h] = nil
    end
end

-- ============================================================
-- INVISIBILIDADE (10Hz rate-limited)
-- ============================================================
local function applyInvisibility()
    local c = character()
    if not c then return end
    local h = c:FindFirstChildOfClass("Humanoid")

    for _, v in ipairs(c:GetDescendants()) do
        if v:IsA("BasePart") then
            if App.original[v] == nil then
                App.original[v] = { Transparency = v.Transparency, CanCollide = v.CanCollide }
            end
            if v.Transparency ~= 1 then v.Transparency = 1 end
            if v.LocalTransparencyModifier ~= 1 then v.LocalTransparencyModifier = 1 end
        elseif v:IsA("Decal") or v:IsA("Texture") then
            if App.original[v] == nil then
                App.original[v] = { Transparency = v.Transparency }
            end
            if v.Transparency ~= 1 then v.Transparency = 1 end
        end
    end

    for _, v in ipairs(c:GetChildren()) do
        if v:IsA("Accessory") then
            if App.original[v] == nil then App.original[v] = { Parent = c } end
            v.Parent = nil
            table.insert(App.hiddenAccessories, v)
        end
    end

    if h and S.invisHideName then
        if App.originalHumanoids[h] == nil then App.originalHumanoids[h] = {} end
        if App.originalHumanoids[h].DisplayDistanceType == nil then
            App.originalHumanoids[h].DisplayDistanceType = h.DisplayDistanceType
        end
        pcall(function() h.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end)
    end
end

local function restoreInvisibility()
    local c = character()
    if c then
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") and App.original[v] and App.original[v].Transparency ~= nil then
                v.Transparency = App.original[v].Transparency
                v.LocalTransparencyModifier = 0
                if App.original[v].CanCollide ~= nil then
                    v.CanCollide = App.original[v].CanCollide
                end
                App.original[v] = nil
            elseif (v:IsA("Decal") or v:IsA("Texture")) and App.original[v] and App.original[v].Transparency ~= nil then
                v.Transparency = App.original[v].Transparency
                App.original[v] = nil
            end
        end
        local h = c:FindFirstChildOfClass("Humanoid")
        if h and App.originalHumanoids[h] and App.originalHumanoids[h].DisplayDistanceType then
            pcall(function() h.DisplayDistanceType = App.originalHumanoids[h].DisplayDistanceType end)
            App.originalHumanoids[h].DisplayDistanceType = nil
        end
    end
    for _, v in ipairs(App.hiddenAccessories) do
        pcall(function() if c then v.Parent = c end end)
    end
    table.clear(App.hiddenAccessories)
end

-- aplicado em loop 10Hz, controlado no Heartbeat principal

-- ============================================================
-- NOCLIP (Stepped)
-- ============================================================
connect(RunService.Stepped, function()
    if not App.alive then return end
    if S.noclip then
        local c = character()
        if not c then return end
        for _, v in ipairs(c:GetDescendants()) do
            if v:IsA("BasePart") then
                if App.collisions[v] == nil then App.collisions[v] = v.CanCollide end
                if v.CanCollide then v.CanCollide = false end
            end
        end
    elseif next(App.collisions) then
        for part, orig in pairs(App.collisions) do
            pcall(function() part.CanCollide = orig end)
        end
        table.clear(App.collisions)
    end
end)

-- ============================================================
-- ANIMATION PACKS
-- ============================================================
local BUNDLE_IDS = {
    ["Ninja"]      = 482,
    ["Toy"]        = 483,
    ["Zombie"]     = 484,
    ["Astronaut"]  = 485,
    ["Cartoon"]    = 486,
    ["Werewolf"]   = 487,
    ["Ghost"]      = 488,
    ["Mage"]       = 489,
    ["Vampire"]    = 490,
    ["Elder"]      = 493,
    ["Pirate"]     = 495,
    ["Sneaky"]     = 496,
    ["Confident"]  = 497,
    ["Popstar"]    = 498,
    ["Princess"]   = 499,
    ["Cowboy"]     = 500,
    ["Patrol"]     = 501,
    ["Bubbly"]     = 503,
    ["Stylish"]    = 504,
    ["Robot"]      = 505,
    ["OldSchool"]  = 506,
    ["Knight"]     = 770,
    ["Superhero"]  = 768,
    ["Levitation"] = 808,
    ["Wicked"]     = 809,
}

local FALLBACK_IDS = {
    Ninja    = { idle1=656117218, walk=656121766, run=656118852, jump=656117878, fall=656115606, climb=656114359, swim=656119721, swimidle=656120393 },
    Toy      = { idle1=782841498, walk=782845736, run=782842708, jump=782847574, fall=782846045, climb=782842314, swim=782843889, swimidle=782843150 },
    Zombie   = { idle1=616158631, walk=616160402, run=616160402, jump=616158995, fall=616158877, climb=616159287, swim=616159388, swimidle=616159479 },
    Cartoon  = { idle1=742638842, walk=742639588, run=742638137, jump=742639164, fall=742639164, climb=742638137, swim=742639000, swimidle=742639000 },
    Mage     = { idle1=707766981, walk=707767218, run=707767218, jump=707767086, fall=707767086, climb=707767086, swim=707767086, swimidle=707767086 },
    Bubbly   = { idle1=707767762, walk=707768013, run=707768013, jump=707768013, fall=707768013, climb=707768013, swim=707768013, swimidle=707768013 },
    Stylish  = { idle1=707767526, walk=707767817, run=707767817, jump=707767817, fall=707767817, climb=707767817, swim=707767817, swimidle=707767817 },
    Robot    = { idle1=707769066, walk=707769254, run=707769254, jump=707769254, fall=707769254, climb=707769254, swim=707769254, swimidle=707769254 },
    OldSchool= { idle1=707767337, walk=707767657, run=707767657, jump=707767657, fall=707767657, climb=707767657, swim=707767657, swimidle=707767657 },
    Knight   = { idle1=763188768, walk=763189033, run=763189033, jump=763189033, fall=763189033, climb=763189033, swim=763189033, swimidle=763189033 },
    Pirate   = { idle1=750781134, walk=750781852, run=750781852, jump=750781852, fall=750781852, climb=750781852, swim=750781852, swimidle=750781852 },
    Sneaky   = { idle1=750785693, walk=750786233, run=750786233, jump=750786233, fall=750786233, climb=750786233, swim=750786233, swimidle=750786233 },
    Confident= { idle1=750782230, walk=750782690, run=750782690, jump=750782690, fall=750782690, climb=750782690, swim=750782690, swimidle=750782690 },
    Popstar  = { idle1=750784449, walk=750784842, run=750784842, jump=750784842, fall=750784842, climb=750784842, swim=750784842, swimidle=750784842 },
    Princess = { idle1=750784529, walk=750784920, run=750784920, jump=750784920, fall=750784920, climb=750784920, swim=750784920, swimidle=750784920 },
    Cowboy   = { idle1=750783118, walk=750783695, run=750783695, jump=750783695, fall=750783695, climb=750783695, swim=750783695, swimidle=750783695 },
    Patrol   = { idle1=750784371, walk=750784770, run=750784770, jump=750784770, fall=750784770, climb=750784770, swim=750784770, swimidle=750784770 },
}

local animPackState = {
    current = "Padrão",
    tracks = {},
    cache = {},
    fetchLog = {},
    mix = {
        Idle="None", Walk="None", Run="None",
        Jump="None", Fall="None", Climb="None",
    },
}

local function fetchBundleIds(bundleId)
    local ok, details = pcall(function()
        return MarketplaceService:GetBundleDetailsAsync(bundleId)
    end)
    if not ok or type(details) ~= "table" then
        return nil, "GetBundleDetailsAsync falhou"
    end

    local pack = {}
    for _, item in ipairs(details.Items or {}) do
        local assetId = item.Id
        local lname = tostring(item.Name or ""):lower()
        if item.Type == "Asset" and type(assetId) == "number" then
            if lname:find("swimidle") or lname:find("swim idle") or lname:find("swim_idle") then
                pack.swimidle = assetId
            elseif lname:find("swim") then
                pack.swim = assetId
            elseif lname:find("idle") then
                if not pack.idle1 then pack.idle1 = assetId
                else pack.idle2 = assetId end
            elseif lname:find("walk") then pack.walk = assetId
            elseif lname:find("run") then pack.run = assetId
            elseif lname:find("jump") then pack.jump = assetId
            elseif lname:find("fall") then pack.fall = assetId
            elseif lname:find("climb") then pack.climb = assetId
            end
        end
    end

    if not pack.idle1 or not pack.walk or not pack.run or not pack.jump then
        return nil, "bundle incompleto"
    end

    pack.idle2 = pack.idle2 or pack.idle1
    pack.fall = pack.fall or pack.run
    pack.climb = pack.climb or pack.walk
    pack.swim = pack.swim or pack.walk
    pack.swimidle = pack.swimidle or pack.idle1

    return pack, details.Name
end

local function resolvePack(name)
    if animPackState.cache[name] then
        return animPackState.cache[name], animPackState.fetchLog[name]
    end

    if name == "Padrão" then
        local pack = {
            idle1=507766388, idle2=507766666,
            walk=507777826, run=507767714,
            jump=507765000, fall=507767714,
            climb=507765644, swim=507784897, swimidle=507785072,
        }
        animPackState.cache[name] = pack
        animPackState.fetchLog[name] = "builtin"
        return pack, "builtin"
    end

    local bundleId = BUNDLE_IDS[name]
    if bundleId then
        animPackState.fetchLog[name] = "pending"
        local pack, why = fetchBundleIds(bundleId)
        if pack then
            animPackState.cache[name] = pack
            animPackState.fetchLog[name] = "ok (bundle " .. bundleId .. ")"
            return pack, animPackState.fetchLog[name]
        end
        if FALLBACK_IDS[name] then
            animPackState.cache[name] = FALLBACK_IDS[name]
            animPackState.fetchLog[name] = "fallback (" .. tostring(why) .. ")"
            return FALLBACK_IDS[name], animPackState.fetchLog[name]
        end
        animPackState.fetchLog[name] = "erro: " .. tostring(why)
        return nil, animPackState.fetchLog[name]
    end

    if FALLBACK_IDS[name] then
        animPackState.cache[name] = FALLBACK_IDS[name]
        animPackState.fetchLog[name] = "fallback (sem bundle id)"
        return FALLBACK_IDS[name], animPackState.fetchLog[name]
    end

    animPackState.fetchLog[name] = "não encontrado"
    return nil, "não encontrado"
end

local function getLocalAnimator()
    local c = character()
    if not c then return nil end
    local h = c:FindFirstChildOfClass("Humanoid")
    if not h then return nil end
    return h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator", 2)
end

local function stopLocomotion()
    local animator = getLocalAnimator()
    if not animator then return end
    for _, t in ipairs(animator:GetPlayingAnimationTracks()) do
        pcall(function() t:Stop(0.15) end)
    end
    table.clear(animPackState.tracks)
end

local function playTrack(animator, id, looped)
    if not id or id == 0 then return nil end
    local anim = Instance.new("Animation")
    anim.AnimationId = "rbxassetid://" .. tostring(id)
    local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
    if not ok or not track then return nil end
    track.Priority = Enum.AnimationPriority.Core
    track.Looped = looped ~= false
    track:Play(0.1)
    return track
end

local function applyAnimPack(name)
    local pack, status = resolvePack(name)
    if not pack then
        return notify("Pack '" .. name .. "' falhou: " .. tostring(status), "error")
    end

    local animator = getLocalAnimator()
    if not animator then return notify("Animator indisponível", "warn") end

    stopLocomotion()

    local tracks = {}
    local ordered = {
        { key = "idle1",   looped = true },
        { key = "idle2",   looped = true },
        { key = "walk",    looped = true },
        { key = "run",     looped = true },
        { key = "jump",    looped = false },
        { key = "fall",    looped = true },
        { key = "climb",   looped = true },
        { key = "swim",    looped = true },
        { key = "swimidle",looped = true },
    }
    for _, entry in ipairs(ordered) do
        local t = playTrack(animator, pack[entry.key], entry.looped)
        if t then table.insert(tracks, t) end
    end

    if tracks[2] then pcall(function() tracks[2]:AdjustWeight(0) end) end

    animPackState.tracks = tracks
    animPackState.current = name
    S.animPack = name
    notify("Pack: " .. name .. " • " .. tostring(status), "success")
end

local function applyCustomMix(mix)
    local animator = getLocalAnimator()
    if not animator then return notify("Animator indisponível", "warn") end

    stopLocomotion()

    local roleKey = {
        Idle = "idle1", Walk = "walk", Run = "run",
        Jump = "jump", Fall = "fall", Climb = "climb",
    }

    local applied = 0
    local tracks = {}
    for role, packName in pairs(mix) do
        if packName and packName ~= "None" then
            local pack = resolvePack(packName)
            if pack then
                local id = pack[roleKey[role]]
                local looped = role ~= "Jump"
                local t = playTrack(animator, id, looped)
                if t then
                    table.insert(tracks, t)
                    applied += 1
                end
            end
        end
    end
    animPackState.tracks = tracks
    animPackState.mix = mix
    notify("Mix custom aplicado (" .. applied .. " tracks)", "success")
end

local function resetAnimPack()
    stopLocomotion()
    applyAnimPack("Padrão")
end

connect(LocalPlayer.CharacterAdded, function()
    task.wait(1.5)
    if not App.alive then return end
    if animPackState.current and animPackState.current ~= "Padrão" then
        task.spawn(function() applyAnimPack(animPackState.current) end)
    end
end)

-- ============================================================
-- ESP (Highlight only, sem SelectionBox)
-- ============================================================
local function removePlayerVisual(p)
    local list = App.playerVisuals[p]
    if list then for _, o in ipairs(list) do pcall(function() o:Destroy() end) end end
    App.playerVisuals[p] = nil
    if drawLines[p] then
        pcall(function() drawLines[p]:Remove() end)
        drawLines[p] = nil
    end
end

local function updatePlayerVisual(p)
    removePlayerVisual(p)
    if not S.esp or p == LocalPlayer or not p.Character then return end
    if S.espTeamCheck and p.Team == LocalPlayer.Team and p.Team ~= nil then return end
    local c = p.Character
    local head = c:FindFirstChild("Head"); local hrp = c:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return end
    local list = {}

    -- Chams -> Highlight
    if S.espChams then
        table.insert(list, new("Highlight", {
            Name = "PrismaESP", Adornee = c,
            DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            FillColor = S.accent, OutlineColor = S.accent,
            FillTransparency = S.espFillAlpha, OutlineTransparency = S.espOutlineAlpha,
        }, c))
    end

    -- Box -> Highlight só de outline (sem SelectionBox)
    if S.espBox then
        table.insert(list, new("Highlight", {
            Name = "PrismaBox",
            Adornee = c,
            DepthMode = Enum.HighlightDepthMode.Occluded,
            FillTransparency = 1,
            OutlineTransparency = 0,
            OutlineColor = S.accent,
        }, c))
    end

    -- Tracer -> Drawing API se disponível
    if S.espTracer then
        if hasDrawing then
            ensureDrawLine(p)
        else
            -- fallback: Beam (mais caro, usado só se Drawing indisponível)
            local att0 = new("Attachment", { Name = "PrismaTracer0" }, hrp)
            local att1 = new("Attachment", { Name = "PrismaTracer1" }, head)
            table.insert(list, new("Beam", {
                Name = "PrismaBeam", Attachment0 = att0, Attachment1 = att1,
                Color = ColorSequence.new(S.accent),
                Transparency = NumberSequence.new(0.3),
                Width0 = 0.08, Width1 = 0.08,
                FaceCamera = true, LightEmission = 1,
            }, c))
            table.insert(list, att0); table.insert(list, att1)
        end
    end

    if S.espHeadDot then
        local dot = new("BillboardGui", {
            Name = "PrismaDot", Adornee = head, AlwaysOnTop = true,
            Size = UDim2.fromOffset(12, 12),
            StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0),
        }, head)
        corner(new("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = S.accent, BorderSizePixel = 0,
        }, dot), 6)
        table.insert(list, dot)
    end

    if S.espName or S.espDistance or S.espHealth then
        local bb = new("BillboardGui", {
            Name = "PrismaEtiqueta", Adornee = head, AlwaysOnTop = true,
            Size = UDim2.fromOffset(200, 54),
            StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
        }, head)
        local txt = new("TextLabel", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = P.bg0, BackgroundTransparency = .3,
            TextColor3 = P.text, TextStrokeTransparency = .4,
            TextSize = 12, Font = Enum.Font.GothamBold,
            TextWrapped = true, Text = "",
        }, bb)
        corner(txt, 7)
        table.insert(list, bb)
        list.text = txt
    end
    App.playerVisuals[p] = list
end

local function refreshESP()
    for _, p in ipairs(Players:GetPlayers()) do updatePlayerVisual(p) end
end

local function clearItemVisuals()
    for _, o in ipairs(App.itemVisuals) do pcall(function() o:Destroy() end) end
    table.clear(App.itemVisuals)
end

-- Escaneia apenas pastas conhecidas (evita workspace inteiro)
local SCAN_FOLDERS = { "Items", "Tools", "DroppedItems", "SpawnedItems", "Workspace.Items" }
local function updateItems()
    clearItemVisuals()
    if not S.espItems then return end
    local count = 0
    for _, name in ipairs(SCAN_FOLDERS) do
        local folder = Workspace:FindFirstChild(name)
        if folder then
            for _, o in ipairs(folder:GetChildren()) do
                if count >= 80 then break end
                local isTool = o:IsA("Tool")
                local isPart = o:IsA("BasePart") and o.Name:lower():find("item")
                if isTool or isPart then
                    local part = isTool and o:FindFirstChildWhichIsA("BasePart") or o
                    if part then
                        table.insert(App.itemVisuals, new("Highlight", {
                            Adornee = o, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                            FillColor = Color3.fromRGB(57, 202, 145),
                            OutlineColor = S.accent, FillTransparency = .75,
                        }, o))
                        count += 1
                    end
                end
            end
        end
    end
    if count > 0 then notify(count .. " itens encontrados", "info") end
end

-- ============================================================
-- TAG 3D
-- ============================================================
local FONT_MAP = {
    ["GothamBlack"] = Enum.Font.GothamBlack,
    ["GothamBold"] = Enum.Font.GothamBold,
    ["Sci-Fi"] = Enum.Font.SciFi,
    ["Arcade"] = Enum.Font.Arcade,
    ["Fantasy"] = Enum.Font.Fantasy,
    ["Antique"] = Enum.Font.Antique,
    ["Code"] = Enum.Font.Code,
    ["IndieFlower"] = Enum.Font.IndieFlower,
}

local function clearTagParticles()
    for _, p in ipairs(App.tagParticles) do pcall(function() p:Destroy() end) end
    table.clear(App.tagParticles)
    if App.tagParticleLoop then
        pcall(function() task.cancel(App.tagParticleLoop) end)
        App.tagParticleLoop = nil
    end
end

local function updateTag()
    if App.tagGui then pcall(function() App.tagGui:Destroy() end) end
    App.tagGui = nil; App.tagText = nil; App.tagGrad = nil
    App.tagContainer = nil; App.tagLayers = nil
    App.tagUnderline = nil; App.tagUnderlineGrad = nil
    clearTagParticles()
    if not S.tagEnabled then return end
    local c = character()
    local head = c and c:FindFirstChild("Head")
    if not head then return end

    local bb = new("BillboardGui", {
        Name = "PrismaEtiquetaLocal", Adornee = head, AlwaysOnTop = true,
        Size = UDim2.fromOffset(360, 96),
        StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0),
        MaxDistance = math.huge,
    }, head)

    local container = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, ZIndex = 1,
    }, bb)

    local displayText = S.tagName:sub(1, 40)
    local extrude = clamp(tonumber(S.tagExtrude) or 3, 0, 8)
    local font = FONT_MAP[S.tagFont] or Enum.Font.GothamBlack

    local layers = {}
    for i = extrude, 1, -1 do
        local shade = 0.55 - (i / extrude) * 0.35
        local layer = new("TextLabel", {
            Size = UDim2.fromScale(1, 0.7),
            Position = UDim2.new(0, i, 0, 10 + i),
            BackgroundTransparency = 1,
            Text = displayText,
            TextColor3 = Color3.fromRGB(15, 8, 30):Lerp(S.tagColor, shade),
            TextStrokeTransparency = 0.7,
            TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
            TextSize = S.tagSize, Font = font,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 2 + (extrude - i),
        }, container)
        table.insert(layers, layer)
    end

    local txt = new("TextLabel", {
        Size = UDim2.fromScale(1, 0.7),
        Position = UDim2.new(0, 0, 0, 10),
        BackgroundTransparency = 1,
        Text = displayText,
        TextColor3 = S.tagColor,
        TextStrokeTransparency = 0.25,
        TextStrokeColor3 = Color3.fromRGB(20, 10, 40),
        TextSize = S.tagSize, Font = font,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
        ZIndex = 2 + extrude + 1,
    }, container)
    local txtGrad = grad(txt, {
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(.5, S.tagColor),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 180, 255)),
    }, 0)

    local underline = new("Frame", {
        Size = UDim2.new(0.4, 0, 0, 2),
        Position = UDim2.new(0.3, 0, 1, -8),
        BackgroundColor3 = S.tagColor,
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        ZIndex = 2 + extrude + 2,
    }, container)
    local underlineGrad = grad(underline, {
        ColorSequenceKeypoint.new(0, S.tagColor),
        ColorSequenceKeypoint.new(.5, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, S.tagColor),
    }, 0)

    App.tagGui = bb
    App.tagText = txt
    App.tagGrad = txtGrad
    App.tagContainer = container
    App.tagLayers = layers
    App.tagUnderline = underline
    App.tagUnderlineGrad = underlineGrad

    if S.tagAnimated then
        App.tagParticleLoop = task.spawn(function()
            while App.alive and S.tagEnabled and App.tagGui == bb do
                local ang = math.random() * math.pi * 2
                local r = 150 + math.random() * 20
                local px = math.cos(ang) * r + 180
                local py = math.sin(ang) * 25 + 48
                local dot = corner(new("Frame", {
                    Size = UDim2.fromOffset(3, 3),
                    Position = UDim2.fromOffset(px, py),
                    BackgroundColor3 = S.tagColor,
                    BackgroundTransparency = 0.2,
                    BorderSizePixel = 0, ZIndex = 10,
                }, container), 2)
                table.insert(App.tagParticles, dot)
                tween(dot, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Position = UDim2.fromOffset(px + math.cos(ang) * 30, py - 30),
                    BackgroundTransparency = 1,
                })
                task.delay(2.3, function() pcall(function() dot:Destroy() end) end)
                if #App.tagParticles > 24 then
                    local old = table.remove(App.tagParticles, 1)
                    if old then pcall(function() old:Destroy() end) end
                end
                task.wait(0.1)
            end
        end)
    end
end

-- ============================================================
-- AIMBOT (com predição)
-- ============================================================
local fovGui = corner(new("Frame", {
    Size = UDim2.fromOffset(S.aimFov * 2, S.aimFov * 2),
    AnchorPoint = Vector2.new(.5, .5), Position = UDim2.fromScale(.5, .5),
    BackgroundTransparency = 1, Visible = false, ZIndex = 100,
}, Gui), 999)
local fovStroke = stroke(fovGui, S.accent, 1, .2)

local function predictedPos(part, amount)
    amount = amount or (S.aimPrediction or 0.135)
    if amount <= 0 then return part.Position end
    local parent = part.Parent
    if not parent then return part.Position end
    local rootPart = parent:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart:IsA("BasePart") then
        return part.Position + rootPart.AssemblyLinearVelocity * amount
    end
    return part.Position
end

local function targetScore(p, part, camera, center)
    if not p or p == LocalPlayer or not p.Character or not part then return nil end
    if not part:IsDescendantOf(p.Character) then return nil end
    if S.aimTeam and LocalPlayer.Team ~= nil and p.Team == LocalPlayer.Team then return nil end
    local h = p.Character:FindFirstChildOfClass("Humanoid")
    if not h or h.Health <= 0 then return nil end
    local pos = predictedPos(part)
    if (pos - camera.CFrame.Position).Magnitude > S.aimDist then return nil end
    local screen, onScreen = camera:WorldToViewportPoint(pos)
    if not onScreen then return nil end
    local delta = (Vector2.new(screen.X, screen.Y) - center).Magnitude
    if delta > S.aimFov then return nil end
    if S.aimVisible then
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        local ignored = { camera }
        local ownC = character(); if ownC then table.insert(ignored, ownC) end
        params.FilterDescendantsInstances = ignored
        local hit = Workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
        if not hit or not hit.Instance:IsDescendantOf(p.Character) then return nil end
    end
    return delta
end

local function bestTarget()
    local camera = Workspace.CurrentCamera; if not camera then return nil end
    local center = camera.ViewportSize / 2
    if S.aimSticky and App.aimTarget then
        local owner = Players:GetPlayerFromCharacter(App.aimTarget.Parent)
        if targetScore(owner, App.aimTarget, camera, center) then return App.aimTarget end
    end
    local best, score = nil, S.aimFov
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local part = p.Character:FindFirstChild(S.aimPart)
                or p.Character:FindFirstChild("HumanoidRootPart")
            local delta = targetScore(p, part, camera, center)
            if delta and delta < score then best = part; score = delta end
        end
    end
    App.aimTarget = best
    return best
end

local function fireOnce(camera)
    if type(mouse1click) == "function" then
        if pcall(mouse1click) then return true end
    end
    local ok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if not ok then return false end
    local center = camera.ViewportSize / 2
    return pcall(function()
        vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
        vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
    end)
end

-- ============================================================
-- LIGHTING / SHADER
-- ============================================================
local originalLighting = {
    ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness,
    GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
}
local originalLightingExtra = {}
for _, k in ipairs({ "FogColor", "FogStart", "FogEnd", "OutdoorAmbient" }) do
    originalLightingExtra[k] = Lighting[k]
end

local function restoreLighting()
    for k, v in pairs(originalLighting) do pcall(function() Lighting[k] = v end) end
    for k, v in pairs(originalLightingExtra) do pcall(function() Lighting[k] = v end) end
end

local function applyLighting()
    if S.fullbright then
        Lighting.ClockTime = 14; Lighting.Brightness = 3
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(190, 190, 190)
    else
        for k, v in pairs(originalLighting) do pcall(function() Lighting[k] = v end) end
        if S.fpsBoost then Lighting.GlobalShadows = false end
    end
end

local function clearShader()
    for _, e in ipairs(App.shaderEffects or {}) do pcall(function() e:Destroy() end) end
    App.shaderEffects = {}
end

local function applyShader()
    clearShader()
    if S.shaderPreset == "Desligado" then return end
    local strength = clamp(S.shaderIntensity, 0, 1)
    local presets = {
        ["Cinematico"] = { tint = Color3.fromRGB(225, 215, 255), contrast = .14, saturation = -.07, bloom = .38, sun = .07, clock = 14 },
        ["Vibrante"] = { tint = Color3.fromRGB(255, 244, 241), contrast = .12, saturation = .38, bloom = .30, sun = .05, clock = 14 },
        ["Neon Noturno"] = { tint = Color3.fromRGB(169, 171, 255), contrast = .22, saturation = .24, bloom = .62, sun = 0, clock = 20 },
        ["Suave"] = { tint = Color3.fromRGB(236, 231, 255), contrast = .04, saturation = .08, bloom = .18, sun = .03, clock = 13 },
    }
    local p = presets[S.shaderPreset]; if not p then return end
    if not S.fullbright then
        Lighting.ClockTime = p.clock
        Lighting.Brightness = (originalLighting.Brightness or 2) + strength * .45
    end
    local effectsEnabled = not S.fpsBoost
    local color = new("ColorCorrectionEffect", {
        Name = "PrismaColor",
        TintColor = Color3.new(1, 1, 1):Lerp(p.tint, strength),
        Contrast = p.contrast * strength, Saturation = p.saturation * strength,
        Brightness = .025 * strength, Enabled = effectsEnabled,
    }, Lighting)
    local bloom = new("BloomEffect", {
        Name = "PrismaBloom", Intensity = p.bloom * strength,
        Size = 30 + 20 * strength, Threshold = 1.2, Enabled = effectsEnabled,
    }, Lighting)
    local rays = new("SunRaysEffect", {
        Name = "PrismaRaios", Intensity = p.sun * strength, Spread = .84,
        Enabled = effectsEnabled,
    }, Lighting)
    App.shaderEffects = { color, bloom, rays }
end

local function reapplyVisuals()
    applyLighting(); applyShader()
end

-- ============================================================
-- MUSIC
-- ============================================================
local music = own(new("Sound", {
    Name = "PrismaMusica", Volume = S.musicVolume, Looped = S.musicLoop,
}, SoundService))

local musicPresets = {
    { name = "Lo-fi calmo", id = "1837879082" },
    { name = "Synthwave", id = "1841645824" },
    { name = "Phonk hype", id = "1836406642" },
    { name = "Epic cinematic", id = "1839401244" },
    { name = "Eletrônica", id = "1837166017" },
    { name = "Ambient", id = "1841839017" },
}

local function playMusicId(raw)
    local n = tonumber(tostring(raw or ""):match("%d+"))
    if not n then return notify("Informe um ID numérico de áudio", "warn") end
    App.lastMusicId = tostring(n)
    music:Stop()
    music.SoundId = "rbxassetid://" .. n
    music.Volume = S.musicVolume; music.Looped = S.musicLoop
    task.spawn(function()
        local began = os.clock()
        while App.alive and not music.IsLoaded and os.clock() - began < 6 do task.wait(.15) end
        if not App.alive then return end
        if music.IsLoaded then music:Play(); notify("Áudio carregado", "success")
        else notify("Áudio não carregou: ID privado ou removido", "error") end
    end)
end
local function playRandomMusic()
    local pick = musicPresets[math.random(1, #musicPresets)]
    playMusicId(pick.id)
    notify("Tocando: " .. pick.name, "info")
end

-- ============================================================
-- PIANO
-- ============================================================
local pianoSongs = {
    { name = "Escala luminosa", notes = "C D E F G A B A G F E D C" },
    { name = "Brilho", notes = "C E G E F A G F E D C" },
    { name = "Passeio", notes = "E E F G G F E D C C D E E D D" },
    { name = "Aurora", notes = "C G A G E F G E D C" },
    { name = "Megalovania", notes = "D D D2 D D D2 D D D2 D D D2" },
    { name = "Harry Potter", notes = "B A G E F G A B A G E E F G F E D" },
    { name = "Star Wars", notes = "G G G E B B B G E B B G" },
    { name = "Für Elise", notes = "E D2 E D2 E B D C A" },
    { name = "Naruto", notes = "C E G E C E G E F A C A F A C A" },
    { name = "Titanic", notes = "E D C D E E E D D D E G G" },
}

local function sendPianoKey(keyName, holdTime)
    holdTime = holdTime or 0.08
    if type(keypress) == "function" and type(keyrelease) == "function" then
        local code = string.byte(keyName)
        if pcall(function() keypress(code); task.wait(holdTime); keyrelease(code) end) then
            return true
        end
    end
    local sok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if sok and vim then
        local enum = Enum.KeyCode[keyName]
        if enum then
            if pcall(function()
                vim:SendKeyEvent(true, enum, false, game)
                task.wait(holdTime)
                vim:SendKeyEvent(false, enum, false, game)
            end) then return true end
        end
    end
    return false
end

local function startPiano(notes, bpm)
    App.pianoToken = (App.pianoToken or 0) + 1
    local token = App.pianoToken
    main.Visible = false
    task.spawn(function()
        task.wait(.5)
        local count = 0
        local beat = 60 / clamp(tonumber(bpm) or 120, 40, 300)
        for token_str in tostring(notes):upper():gmatch("[A-G]%d?") do
            if not App.alive or token ~= App.pianoToken then return end
            local note = token_str:sub(1, 1)
            local mapped = S.pianoKeyMap[note] or note
            if not sendPianoKey(mapped, math.min(beat * 0.6, 0.12)) then
                notify("Piano: envio de teclas indisponível", "error"); return
            end
            count += 1
            task.wait(beat)
        end
        notify("Piano concluído: " .. count .. " notas", "success")
    end)
    notify("Piano iniciado; F3 reabre o menu", "info")
end

-- ============================================================
-- FLY / FREECAM
-- ============================================================
local okVirtual, virtualUser = pcall(function() return game:GetService("VirtualUser") end)

local function stopFly()
    if App.flyVelocity then pcall(function() App.flyVelocity:Destroy() end); App.flyVelocity = nil end
    if App.flyGyro then pcall(function() App.flyGyro:Destroy() end); App.flyGyro = nil end
    App.flyRoot = nil
    local h = humanoid()
    if h then
        h.PlatformStand = false
        h.AutoRotate = App.original.autoRotate ~= false
    end
    App.flyJustStopped = true
    App.flyStopTimer = 0.8
end

local function ensureFly(r, h)
    if App.flyRoot == r and App.flyVelocity and App.flyGyro then return end
    stopFly()
    App.original.autoRotate = h.AutoRotate
    App.flyRoot = r
    App.flyVelocity = new("BodyVelocity", {
        Name = "PrismaVoo", MaxForce = Vector3.new(1e9, 1e9, 1e9),
        P = 25000, Velocity = Vector3.zero,
    }, r)
    App.flyGyro = new("BodyGyro", {
        Name = "PrismaDirecao", MaxTorque = Vector3.new(1e9, 1e9, 1e9),
        P = 25000, D = 1000, CFrame = r.CFrame,
    }, r)
end

local freecamSink = false
local function enableFreecamSink()
    if freecamSink then return end
    pcall(function()
        ContextActionService:BindActionAtPriority("PrismaFreecamSink",
            function() return Enum.ContextActionResult.Sink end,
            false, 3000,
            Enum.PlayerActions.CharacterForward,
            Enum.PlayerActions.CharacterBackward,
            Enum.PlayerActions.CharacterLeft,
            Enum.PlayerActions.CharacterRight)
    end)
    freecamSink = true
end
local function disableFreecamSink()
    if not freecamSink then return end
    pcall(function() ContextActionService:UnbindAction("PrismaFreecamSink") end)
    freecamSink = false
end

local freecamJumpBlock = false
local function enableFreecamJumpBlock()
    if freecamJumpBlock then return end
    freecamJumpBlock = true
    local h = humanoid()
    if h then h.Jump = false end
    App.freecamJumpConn = connect(UserInputService.InputBegan, function(input)
        if S.freecam and input.KeyCode == Enum.KeyCode.Space then
            local hh = humanoid()
            if hh then hh.Jump = false end
        end
    end)
end
local function disableFreecamJumpBlock()
    if not freecamJumpBlock then return end
    freecamJumpBlock = false
    if App.freecamJumpConn then
        pcall(function() App.freecamJumpConn:Disconnect() end)
        App.freecamJumpConn = nil
    end
end

-- ============================================================
-- AUTO-REJOIN
-- ============================================================
local function tryAutoRejoin()
    if not App.alive or not S.autoRejoin then return end
    task.delay(2, function()
        if not App.alive or not S.autoRejoin then return end
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)
end

local function ensureAutoRejoinConn()
    if S.autoRejoin and not App.autoRejoinConn then
        App.autoRejoinConn = connect(LogService.MessageOut, function(msg)
            if not App.alive or not S.autoRejoin then return end
            local lower = tostring(msg or ""):lower()
            if lower:find("disconnected") or lower:find("kicked")
                or lower:find("removed from") or lower:find("you have been") then
                tryAutoRejoin()
            end
        end)
        connect(LocalPlayer.AncestryChanged, function(_, parent)
            if not parent and App.alive and S.autoRejoin then tryAutoRejoin() end
        end)
    elseif not S.autoRejoin and App.autoRejoinConn then
        pcall(function() App.autoRejoinConn:Disconnect() end)
        App.autoRejoinConn = nil
    end
end

-- ============================================================
-- DESTROY
-- ============================================================
function App.Destroy()
    if not App.alive then return end
    App.alive = false
    App.pianoToken = (App.pianoToken or 0) + 1
    S.fly = false; S.noclip = false; S.follow = false
    flingStop()
    if S.invisible then S.invisible = false; restoreInvisibility() end
    if S.godmode then S.godmode = false; stopGodmode() end
    stopLocomotion()
    stopFly()
    disableFreecamSink()
    disableFreecamJumpBlock()
    for part, v in pairs(App.collisions) do pcall(function() part.CanCollide = v end) end
    table.clear(App.collisions)
    local h = humanoid()
    if h then
        if App.original.speed then h.WalkSpeed = App.original.speed end
        if App.original.jump then h.JumpPower = App.original.jump end
        if App.original.jumpHeight then h.JumpHeight = App.original.jumpHeight end
        if App.original.useJumpPower ~= nil then h.UseJumpPower = App.original.useJumpPower end
        h.PlatformStand = false
    end
    if Workspace.CurrentCamera then Workspace.CurrentCamera.CameraSubject = h end
    if Workspace.CurrentCamera and App.original.cameraType then
        Workspace.CurrentCamera.CameraType = App.original.cameraType
    end
    for _, p in ipairs(Players:GetPlayers()) do removePlayerVisual(p) end
    for p, line in pairs(drawLines) do
        pcall(function() line:Remove() end)
    end
    table.clear(drawLines)
    clearItemVisuals()
    clearTagParticles()
    if App.tagGui then pcall(function() App.tagGui:Destroy() end); App.tagGui = nil end
    for _, c in ipairs(App.connections) do pcall(function() c:Disconnect() end) end
    for _, c in ipairs(App.pageConnections) do pcall(function() c:Disconnect() end) end
    pageMaid:cleanup()
    if App.renderBinding then
        pcall(function() RunService:UnbindFromRenderStep(App.renderBinding) end)
    end
    clearShader()
    for _, o in ipairs(App.objects) do pcall(function() o:Destroy() end) end
    for v, data in pairs(App.original) do
        if typeof(v) == "Instance" and v.Parent and type(data) == "table" then
            if data.Transparency ~= nil and v:IsA("BasePart") then v.Transparency = data.Transparency end
            if data.Parent ~= nil and v:IsA("Accessory") then v.Parent = data.Parent end
        end
    end
    for h2, data in pairs(App.originalHumanoids) do
        if typeof(h2) == "Instance" and h2.Parent then
            pcall(function()
                if data.DeadStateEnabled ~= nil then
                    h2:SetStateEnabled(Enum.HumanoidStateType.Dead, data.DeadStateEnabled)
                end
                if data.MaxHealth then h2.MaxHealth = data.MaxHealth end
                if data.Health then h2.Health = math.min(data.Health, h2.MaxHealth) end
                if data.DisplayDistanceType then h2.DisplayDistanceType = data.DisplayDistanceType end
            end)
        end
    end
    restoreLighting()
    pcall(function() Gui:Destroy() end)
    pcall(function() toastGui:Destroy() end)
    if ENV.PrismaHub == App then ENV.PrismaHub = nil end
end

connect(close.MouseButton1Click, function() App.Destroy() end)
connect(minimize.MouseButton1Click, function() main.Visible = false end)

-- ============================================================
-- PAGES
-- ============================================================
local pages = {}
local activePageSubtitle = "Painel da sessão"
local navButtons = {}

local function render(page)
    App.currentPage = page
    clearContent()
    title.Text = page
    for name, b in pairs(navButtons) do
        local isActive = name == page
        b.BackgroundColor3 = isActive and P.card3 or P.bg1
        b.BackgroundTransparency = isActive and .05 or .6
        b.TextColor3 = isActive and P.text or P.text3
        if isActive then
            activeIndicator.Visible = true
            local idx = b.LayoutOrder
            local y = 90 + (idx - 1) * 34 + 2
            tween(activeIndicator, TweenInfo.new(.24, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
                Position = UDim2.fromOffset(1, y),
                BackgroundColor3 = S.accent,
            })
        end
    end
    pages[page]()
    activePageSubtitle = subtitlePage.Text
    for _, child in ipairs(content:GetChildren()) do
        if child:IsA("GuiObject") then
            local target = child.BackgroundTransparency
            if target and target < 1 then
                child.BackgroundTransparency = 1
                tween(child, TweenInfo.new(.35), { BackgroundTransparency = target })
            end
        end
    end
end
App.render = render

-- ============================================================
-- INÍCIO
-- ============================================================
pages["Início"] = function()
    subtitlePage.Text = "Visão geral • sessão atual"
    section("SESSÃO")
    local welcome = card(200)
    local topBar = corner(new("Frame", {
        Size = UDim2.new(1, -32, 0, 3),
        Position = UDim2.fromOffset(16, 14),
        BackgroundColor3 = P.accent, BorderSizePixel = 0, ZIndex = 19,
    }, welcome), 2)
    grad(topBar, {
        ColorSequenceKeypoint.new(0, P.accent),
        ColorSequenceKeypoint.new(.5, P.accent2),
        ColorSequenceKeypoint.new(1, P.accent3),
    }, 0)

    local avatar = corner(new("Frame", {
        Size = UDim2.fromOffset(70, 70),
        Position = UDim2.fromOffset(22, 34),
        BackgroundColor3 = P.card2, BorderSizePixel = 0, ZIndex = 19,
    }, welcome), 35)
    stroke(avatar, S.accent, 2, 0.3)
    new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = string.upper(safeUtf8First(LocalPlayer.DisplayName)),
        TextColor3 = S.accent, TextSize = 32,
        Font = Enum.Font.GothamBold, ZIndex = 20,
    }, avatar)

    label(welcome, "Bem-vindo, " .. LocalPlayer.DisplayName, 108, 34, 500, 30, P.text, 20, true)
    label(welcome, "Prisma Nexus • Hyperion Refined v13.0", 108, 68, 560, 18, P.text3, 12)
    label(welcome, "Sessão ativa desde o boot", 108, 90, 560, 18, P.text3, 11)

    local badges = card(70)
    local function badge(text, color, x)
        local b = corner(new("Frame", {
            Size = UDim2.fromOffset(180, 40),
            Position = UDim2.fromOffset(x, 15),
            BackgroundColor3 = P.bg0, BackgroundTransparency = .3,
            BorderSizePixel = 0, ZIndex = 19,
        }, badges), 10)
        stroke(b, color, 1, .3)
        local dot = corner(new("Frame", {
            Size = UDim2.fromOffset(8, 8),
            Position = UDim2.fromOffset(14, 16),
            BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 20,
        }, b), 4)
        stroke(dot, color, 3, .3)
        label(b, text, 32, 10, 140, 20, P.text, 12, true)
    end
    badge("Status: ONLINE", P.ok, 20)
    badge("Jogadores: " .. #Players:GetPlayers(), P.accent, 220)
    local fpsBadge = badge("FPS: --", P.warn, 420)
    badge("Ping: " .. App.ping .. "ms", P.accent2, 620)
    pageConnect(RunService.Heartbeat, function()
        if fpsBadge and fpsBadge.Parent then
            local lbl = fpsBadge:FindFirstChildOfClass("TextLabel")
            if lbl then lbl.Text = "FPS: " .. App.fps end
        end
    end)

    section("INFORMAÇÕES")
    local info = card(150)
    label(info, "Lugar atual", 22, 14, 200, 18, P.text3, 11, true)
    label(info, tostring(game.PlaceId), 22, 34, 400, 22, P.text, 14, true)
    label(info, "Job ID", 22, 66, 200, 18, P.text3, 11, true)
    label(info, (game.JobId ~= "" and game.JobId or "indisponível"), 22, 86, 620, 22, P.text2, 12)
    label(info, "Servidor", 22, 114, 200, 18, P.text3, 11, true)
    label(info, (game.JobId ~= "" and "Privado / público detectado" or "Sem informações"), 22, 132, 620, 18, P.text2, 12)

    section("ACESSO RÁPIDO")
    action("Minimizar painel", "Use F3 para ocultar ou reabrir; arraste pela lateral.", function()
        main.Visible = false
    end)
    action("Reentrar no jogo", "Solicita uma nova sessão neste lugar.", function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
    action("Reiniciar personagem", "Mata e respawna o personagem local.", function()
        local h = humanoid(); if h then h.Health = 0 end
    end)
    action("Encerrar Prisma Nexus", "Desliga funções, remove visuais e libera conexões.", function()
        App.Destroy()
    end)
end

-- ============================================================
-- JOGADORES
-- ============================================================
local followModes = {
    { name = "Atrás", offset = CFrame.new(0, 3, 5) },
    { name = "Em cima", offset = CFrame.new(0, 6, 0) },
    { name = "Embaixo", offset = CFrame.new(0, -4, 0) },
    { name = "Na frente", offset = CFrame.new(0, 3, -5) },
    { name = "Ao lado", offset = CFrame.new(5, 3, 0) },
    { name = "Longe", offset = CFrame.new(0, 6, 12) },
    { name = "Colado", offset = CFrame.new(0, 2, 1) },
    { name = "Sobrevoando", offset = CFrame.new(0, 10, 0) },
}

pages["Jogadores"] = function()
    subtitlePage.Text = "Seleção, teleporte e câmera"
    section("JOGADORES E AÇÕES")
    local panel = card(430)
    local left = corner(new("Frame", {
        Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(316, 398),
        BackgroundColor3 = P.bg0, BackgroundTransparency = .15,
    }, panel), 12)
    stroke(left, P.line2, 1, .6)
    label(left, "JOGADORES", 16, 12, 230, 22, S.accent, 11, true)

    local search = input(left, "Buscar...", 16, 38, 284, 28)

    local list = new("ScrollingFrame", {
        Position = UDim2.fromOffset(12, 74), Size = UDim2.new(1, -24, 1, -88),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = P.line2,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, left)
    local listLayout = new("UIListLayout", { Padding = UDim.new(0, 6) }, list)
    pageConnect(listLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
        list.CanvasSize = UDim2.fromOffset(0, listLayout.AbsoluteContentSize.Y + 10)
    end)

    local rows = {}
    local selectedText
    local filter = ""

    local function buildRows()
        for _, c in ipairs(list:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        table.clear(rows)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                local name = p.Name:lower()
                if filter == "" or name:find(filter, 1, true) or p.DisplayName:lower():find(filter, 1, true) then
                    local row = corner(new("TextButton", {
                        Size = UDim2.new(1, -7, 0, 52),
                        BackgroundColor3 = p == App.selected and Color3.fromRGB(50, 39, 77) or P.card,
                        Text = "", AutoButtonColor = false,
                    }, list), 9)
                    stroke(row, p == App.selected and S.accent or P.line2, 1, p == App.selected and .3 or .6)
                    label(row, p.DisplayName, 15, 8, 240, 19, P.text, 12, true)
                    label(row, "@" .. p.Name, 15, 28, 240, 17, P.text3, 10)
                    rows[p] = row
                    pageConnect(row.MouseEnter, function()
                        if App.selected ~= p then tween(row, TweenInfo.new(.2), { BackgroundColor3 = P.card2 }) end
                    end)
                    pageConnect(row.MouseLeave, function()
                        if App.selected ~= p then tween(row, TweenInfo.new(.2), { BackgroundColor3 = P.card }) end
                    end)
                    pageConnect(row.MouseButton1Click, function()
                        App.selected = p
                        for q, r in pairs(rows) do
                            r.BackgroundColor3 = q == p and Color3.fromRGB(50, 39, 77) or P.card
                            local s = r:FindFirstChildOfClass("UIStroke")
                            if s then s.Color = q == p and S.accent or P.line2 end
                        end
                        if selectedText then selectedText.Text = "Selecionado: " .. p.DisplayName end
                    end)
                end
            end
        end
    end
    buildRows()

    pageConnect(search:GetPropertyChangedSignal("Text"), function()
        filter = search.Text:lower()
        buildRows()
    end)

    local right = corner(new("Frame", {
        Position = UDim2.fromOffset(344, 16), Size = UDim2.new(1, -360, 0, 398),
        BackgroundColor3 = P.bg0, BackgroundTransparency = .15,
    }, panel), 12)
    stroke(right, P.line2, 1, .6)
    label(right, "CONTROLES", 16, 12, 330, 22, S.accent, 11, true)
    selectedText = label(right,
        App.selected and ("Selecionado: " .. App.selected.DisplayName) or "Selecione um jogador à esquerda",
        16, 36, 350, 23, P.text, 12, true)

    button(right, "Ir até", 16, 72, 178, 36, teleportNearSelected, true)
    button(right, "Observar", 200, 72, 178, 36, function()
        local c = selectedCharacter()
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if not h then return notify("Selecione um jogador disponível", "warn") end
        Workspace.CurrentCamera.CameraSubject = h
    end)
    button(right, "Minha câmera", 16, 116, 178, 36, function()
        Workspace.CurrentCamera.CameraSubject = humanoid()
    end)
    local freeButton
    freeButton = button(right, S.freecam and "Câmera livre: ON" or "Câmera livre", 200, 116, 178, 36, function()
        S.freecam = not S.freecam
        local cam = Workspace.CurrentCamera
        if not cam then return end
        if S.freecam then
            App.original.cameraType = cam.CameraType
            cam.CameraType = Enum.CameraType.Scriptable
            App.freecamAngle = Vector2.new(math.rad(-30), math.rad(-15))
            enableFreecamSink()
            enableFreecamJumpBlock()
        else
            cam.CameraType = App.original.cameraType or Enum.CameraType.Custom
            cam.CameraSubject = humanoid()
            disableFreecamSink()
            disableFreecamJumpBlock()
        end
        freeButton.Text = S.freecam and "Câmera livre: ON" or "Câmera livre"
    end)
    local followButton
    followButton = button(right, S.follow and "Seguir: ON" or "Seguir jogador", 16, 160, 178, 36, function()
        if not App.selected then return notify("Selecione um jogador", "warn") end
        S.follow = not S.follow
        followButton.Text = S.follow and "Seguir: ON" or "Seguir jogador"
        if not S.follow then
            local h = humanoid(); if h then h.PlatformStand = false end
        end
    end)
    button(right, "Copiar nome", 200, 160, 178, 36, function()
        if not App.selected then return notify("Selecione um jogador", "warn") end
        if type(setclipboard) == "function" then
            setclipboard(App.selected.Name); notify("Nome copiado", "success")
        else notify(App.selected.Name, "info") end
    end)
    button(right, "Atualizar lista", 16, 204, 178, 36, function() buildRows() end)
    label(right, "Modo de seguir: " .. S.followMode, 16, 250, 362, 22, P.text2, 11, true)
    label(right, "A lista atualiza sozinha quando alguém entra ou sai.",
        16, 274, 362, 22, P.text3, 10)

    section("MODO DE SEGUIR")
    local modeGrid = card(250)
    for i, mode in ipairs(followModes) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local isActive = S.followMode == mode.name
        button(modeGrid, mode.name, 20 + col * 200, 20 + row * 55, 185, 42, function()
            S.followMode = mode.name
            render("Jogadores")
            notify("Modo de seguir: " .. mode.name, "success")
        end, isActive)
    end

    section("SUAVIDADE")
    slider("Suavização do seguir", "followSmooth", .05, 1, .01, function(n)
        return math.floor(n * 100) .. "%"
    end)

    section("CÂMERA LIVRE")
    slider("Velocidade da câmera", "freecamSpeed", 12, 150, 2, function(n) return n .. " studs/s" end)
end

-- ============================================================
-- VISUAIS
-- ============================================================
pages["Visuais"] = function()
    subtitlePage.Text = "Destaques e informações no mundo"
    section("ESP DE JOGADORES")
    toggle("Ativar ESP", "esp", "Destaque visual para jogadores carregados.", refreshESP)
    toggle("Contorno (Chams)", "espChams", nil, refreshESP)
    toggle("Caixa 3D", "espBox", nil, refreshESP)
    toggle("Nome", "espName", nil, refreshESP)
    toggle("Vida", "espHealth", nil, refreshESP)
    toggle("Distância", "espDistance", nil, refreshESP)
    toggle("Tracer (linha)", "espTracer", "Linha até o alvo.", refreshESP)
    toggle("Head Dot", "espHeadDot", "Ponto acima da cabeça.", refreshESP)
    toggle("Ignorar equipe", "espTeamCheck", nil, refreshESP)
    toggle("Ignorar limite de distância", "espNoDistLimit",
        "Mantém o contorno ativo mesmo longe.", refreshESP)
    toggle("Contorno RGB", "espRainbow", "Anima as cores dos destaques ativos.")
    slider("Distância máxima", "espMaxDist", 50, 3000, 50, function(n) return n .. " studs" end)
    slider("Transparência do preenchimento", "espFillAlpha", 0, 1, 0.05, function(n)
        return math.floor(n * 100) .. "%"
    end, refreshESP)

    section("OBJETOS")
    toggle("Marcar itens no mundo", "espItems", "Varredura local limitada a 80 itens.", updateItems)
    action("Atualizar marcações", "Refaz a varredura de jogadores e itens.", function()
        refreshESP(); updateItems()
    end)

    section("SHADERS")
    action("Cinematico", "Contraste discreto, luz suave e brilho lavanda.", function()
        S.shaderPreset = "Cinematico"; reapplyVisuals(); notify("Shader Cinematico ativado", "success")
    end)
    action("Vibrante", "Cores mais fortes e brilho moderado.", function()
        S.shaderPreset = "Vibrante"; reapplyVisuals(); notify("Shader Vibrante ativado", "success")
    end)
    action("Neon Noturno", "Noite azul com realce luminoso.", function()
        S.shaderPreset = "Neon Noturno"; reapplyVisuals(); notify("Shader Neon Noturno ativado", "success")
    end)
    action("Suave", "Cores claras com efeitos leves.", function()
        S.shaderPreset = "Suave"; reapplyVisuals(); notify("Shader Suave ativado", "success")
    end)
    slider("Intensidade do shader", "shaderIntensity", 0, 1, .05, function(n)
        return math.floor(n * 100) .. "%"
    end, applyShader)
    action("Desligar shader", "Remove os efeitos criados pelo Prisma Nexus.", function()
        S.shaderPreset = "Desligado"; applyShader(); notify("Shader desligado", "info")
    end)
end

-- ============================================================
-- MOVIMENTO
-- ============================================================
pages["Movimento"] = function()
    subtitlePage.Text = "Mobilidade do personagem"
    section("VELOCIDADE E SALTO")
    toggle("Velocidade personalizada", "speed", "Ajusta WalkSpeed continuamente.")
    slider("Velocidade (16 a 1000)", "speedValue", 16, 1000, 1, function(n) return tostring(n) end)
    toggle("Altura do salto", "jump", "Usa JumpHeight em vez de JumpPower.")
    slider("Altura (0 a 5000)", "jumpValue", 0, 5000, 5, function(n) return tostring(n) end)
    toggle("Salto infinito", "infiniteJump", "Pressione Espaço para saltar no ar.")

    section("VOO (CONTROLE MANUAL)")
    toggle("Voar", "fly",
        "WASD move na direção da câmera, Space sobe, Ctrl desce. Sem movimento automático.",
        function(on)
            if not on then
                stopFly()
                App.flyJustStopped = true
                App.flyStopTimer = 0.8
            end
        end)
    slider("Velocidade de voo (20 a 5000)", "flySpeed", 20, 5000, 5, function(n) return n .. " studs/s" end)

    section("ATRAVESSAR E INVISIBILIDADE")
    toggle("Noclip", "noclip", "Atravessa paredes, tetos e chão. Anti-void corrigido.")
    toggle("Ficar invisível", "invisible",
        "Esconde seu personagem para outros jogadores. Cabelo preservado.",
        function(on)
            if on then
                applyInvisibility()
                notify("Invisibilidade ativada", "success")
            else
                restoreInvisibility()
                notify("Invisibilidade desativada", "info")
            end
        end)
    toggle("Esconder nome", "invisHideName", "Esconde o display de nome acima do personagem.", function(on)
        local c = character()
        if c and c:FindFirstChildOfClass("Humanoid") then
            pcall(function()
                c.Humanoid.DisplayDistanceType = on and Enum.HumanoidDisplayDistanceType.None
                    or Enum.HumanoidDisplayDistanceType.Viewer
            end)
        end
    end)

    section("EXTRAS")
    toggle("Girar personagem", "spin", nil)
    slider("Velocidade de giro", "spinSpeed", 30, 10000, 10, function(n) return n .. " deg/s" end)
    toggle("Teleporte por clique", "clickTp", "Segure Ctrl e clique no chão.")

    action("Restaurar movimento", "Desliga movimento e restaura velocidade e colisões.", function()
        S.speed = false; S.jump = false; S.fly = false; S.noclip = false
        S.infiniteJump = false; S.spin = false; S.clickTp = false
        if S.invisible then S.invisible = false; restoreInvisibility() end
        stopFly()
        for part, v in pairs(App.collisions) do pcall(function() part.CanCollide = v end) end
        table.clear(App.collisions)
        local h = humanoid()
        if h then
            h.PlatformStand = false
            h.WalkSpeed = App.original.speed or 16
            h.JumpPower = App.original.jump or 50
            h.JumpHeight = App.original.jumpHeight or h.JumpHeight
            h.UseJumpPower = App.original.useJumpPower ~= false
        end
        render("Movimento")
    end)
end

-- ============================================================
-- MIRA
-- ============================================================
pages["Mira"] = function()
    subtitlePage.Text = "Ajuste da câmera por alvo"
    section("ASSISTÊNCIA DE MIRA")
    toggle("Ativar assistência", "aim", "Move a câmera para o alvo dentro do círculo.")
    toggle("Segurar botão direito", "aimHold", "Desligado: assistência sempre ativa.")
    toggle("Mostrar círculo FOV", "aimShowFov", nil)

    local keyCard = card(86)
    label(keyCard, "Tecla do aim", 22, 13, 400, 23, P.text, 13, true)
    label(keyCard, (S.aimKey and S.aimKey.Name) or "MouseButton2",
        22, 42, 400, 26, P.text3, 11)
    local keyBtn
    keyBtn = button(keyCard, "Alterar", 630, 24, 118, 36, function()
        App.aimKeyCapture = true
        keyBtn.Text = "Pressione..."
        notify("Pressione a tecla/botão que deseja usar; Esc cancela", "info")
    end, true)

    slider("Campo de visão", "aimFov", 40, 350, 5, function(n) return n .. " px" end)
    slider("Suavização", "aimSmooth", .03, .95, .01, function(n)
        return math.floor(n * 100) .. "%"
    end)
    slider("Alcance máximo", "aimDist", 50, 2000, 25, function(n) return n .. " studs" end)
    slider("Predição (0 desliga)", "aimPrediction", 0, 0.4, 0.005, function(n)
        return string.format("%.3f s", n)
    end)
    toggle("Somente visíveis", "aimVisible", "Usa raycast para descartar alvos cobertos.")
    toggle("Ignorar minha equipe", "aimTeam", "Descarta jogadores na mesma equipe.")
    toggle("Manter o mesmo alvo", "aimSticky", "Evita trocar de alvo a cada quadro.")
    toggle("Disparo automático", "aimAutoFire", "Dispara somente com alvo válido e menu minimizado.",
        function(on)
            if on then App.fireUnsupported = false end
        end)
    action("Alternar cabeça / corpo", "Parte do alvo: " .. S.aimPart, function()
        S.aimPart = S.aimPart == "Head" and "HumanoidRootPart" or "Head"
        render("Mira")
    end)
end

-- ============================================================
-- FLING
-- ============================================================
local flingModeOptions = {
    { key = "LIMB_RUSH",  label = "Limb Rush",  desc = "Velocidade em cada limb roubado — replicado" },
    { key = "LAGSLAM",    label = "Lag Slam",   desc = "Todos os limbs com velocidade máxima" },
    { key = "TORSO_KICK", label = "Torso Kick", desc = "Só HRP, velocidade extrema" },
    { key = "WELD_CAGE",  label = "Weld Cage",  desc = "Solda caixas com velocidades opostas" },
    { key = "EXECUTE",    label = "Execute",    desc = "Teleporta cada limb — visual extremo" },
}

local flingLimbOptions = {
    { key = "all",   label = "Todos" },
    { key = "torso", label = "Torso" },
    { key = "arms",  label = "Braços" },
    { key = "legs",  label = "Pernas" },
}

pages["Fling"] = function()
    subtitlePage.Text = "Forçar deslocamento server-side em outro jogador"

    section("ALVO")
    local tCard = card(96)
    label(tCard,
        App.flingTarget and ("Alvo: " .. App.flingTarget.DisplayName) or "Nenhum alvo selecionado",
        22, 14, 480, 22, App.flingTarget and P.text or P.text3, 13, true)
    label(tCard, "Segure Alt e clique esquerdo em um jogador no mundo.",
        22, 42, 570, 22, P.text3, 11)
    button(tCard, "Limpar", 630, 30, 118, 34, function()
        flingClearTarget()
        render("Fling")
    end)

    section("DIAGNÓSTICO EM TEMPO REAL")
    local dCard = card(108)
    local ownLbl = label(dCard, "stolen: —",
        22, 14, 400, 22, P.text3, 12, true)
    local statLbl = label(dCard, "parado",
        22, 40, 400, 22, P.text3, 12, true)
    label(dCard, "Se 'stolen' for 0, esse jogo bloqueia SetNetworkOwner do cliente.",
        22, 66, 640, 22, P.text3, 10)
    label(dCard, "Nesse caso o fling NÃO replica pra outros jogadores nesse jogo.",
        22, 84, 640, 22, P.warn, 10)
    pageConnect(RunService.Heartbeat, function()
        if not ownLbl or not ownLbl.Parent then return end
        local d = App.flingDiag or {}
        ownLbl.Text = "stolen: " .. tostring(d.stolen or 0) .. " / " .. tostring(d.total or 0)
        ownLbl.TextColor3 = (d.stolen or 0) > 0 and P.ok or P.danger
        statLbl.Text = App.flingThread and ("rodando • " .. tostring(S.flingMode)) or "parado"
        statLbl.TextColor3 = App.flingThread and P.ok or P.text3
    end)

    section("MODO")
    for _, m in ipairs(flingModeOptions) do
        local row = card(72)
        local isActive = S.flingMode == m.key
        label(row, m.label, 22, 14, 400, 22, P.text, 13, true)
        label(row, m.desc, 22, 40, 530, 20, P.text3, 11)
        button(row, isActive and "Ativo" or "Usar", 630, 18, 118, 34, function()
            S.flingMode = m.key
            render("Fling")
            notify("Modo: " .. m.label, "success")
        end, isActive)
    end

    section("PARTES DO CORPO")
    local limbCard = card(78)
    for i, opt in ipairs(flingLimbOptions) do
        local col = i - 1
        local isActive = S.flingLimbSet == opt.key
        button(limbCard, opt.label, 20 + col * 152, 22, 140, 34, function()
            S.flingLimbSet = opt.key
            render("Fling")
            notify("Limbs: " .. opt.label, "success")
        end, isActive)
    end

    section("AJUSTES")
    slider("Potência", "flingPower", 500, 50000, 500, function(n) return tostring(n) end)
    slider("Ritmo de reaplicação", "flingRate", 0.01, 0.5, 0.01, function(n)
        return string.format("%.2fs", n)
    end)
    slider("Caixas no Weld Cage", "flingRips", 4, 32, 1, function(n) return tostring(n) end)

    section("AÇÃO")
    action("Iniciar", "Começa a aplicar no alvo. Observa o campo 'stolen' acima.", function()
        if not App.flingTarget then return notify("Selecione um alvo (Alt+clique)", "warn") end
        if not App.flingTarget.Character then return notify("Alvo sem personagem carregado", "warn") end
        flingStart()
        notify("Fling iniciado • " .. S.flingMode, "success")
    end)
    action("Parar", "Interrompe e limpa partes.", function()
        flingStop()
        notify("Fling parado", "info")
    end)
end

-- ============================================================
-- PROTEÇÃO
-- ============================================================
pages["Protecao"] = function()
    subtitlePage.Text = "Ferramentas locais da sessão"
    section("PERSONAGEM")
    toggle("Godmode (imortal)", "godmode",
        "Imunidade multi-camadas: bloqueia estado Dead, loop de Health, ForceField.",
        function(on)
            if on then
                startGodmode()
                notify("Godmode ativado (multi-camadas)", "success")
            else
                stopGodmode()
                notify("Godmode desativado", "info")
            end
        end)
    toggle("Anti AFK", "antiAfk", "Usa VirtualUser ao detectar inatividade.", function(on)
        if on and not okVirtual then
            S.antiAfk = false
            notify("VirtualUser indisponível", "error")
            render("Protecao")
        end
    end)
    toggle("Anti arremesso", "antiFling", "Limita picos de velocidade no personagem local.")
    toggle("Anti ragdoll", "antiRagdoll", "Tenta levantar o personagem se cair em ragdoll.")
    action("Reiniciar personagem", "Reinicia o personagem atual.", function()
        local h = humanoid(); if h then h.Health = 0 end
    end)
    action("Restaurar vida", "Desliga godmode e devolve a vida original.", function()
        if S.godmode then
            S.godmode = false
            stopGodmode()
            if App.toggleVisuals.godmode then App.toggleVisuals.godmode() end
        end
        local h = humanoid()
        if h then h.MaxHealth = 100; h.Health = 100 end
        notify("Vida restaurada", "success")
    end)
    action("Remover ferramentas locais", "Guarda ferramentas equipadas na mochila.", function()
        local h = humanoid(); if h then h:UnequipTools() end
    end)

    section("DESEMPENHO")
    toggle("Iluminação clara", "fullbright", "Ajuste visual local de Lighting.", reapplyVisuals)
    toggle("FPS leve", "fpsBoost", "Desativa sombras e pós-processamento local.", function(on)
        if on then
            for _, v in ipairs(Lighting:GetChildren()) do
                if v:IsA("PostEffect") then
                    App.original[v] = v.Enabled
                    v.Enabled = false
                end
            end
        else
            for v, enabled in pairs(App.original) do
                if typeof(v) == "Instance" and v.Parent and type(enabled) == "boolean" then
                    pcall(function() v.Enabled = enabled end)
                end
            end
        end
        reapplyVisuals()
    end)
    action("Definir dia", "Altera apenas a iluminação do cliente.", function() Lighting.ClockTime = 14 end)
    action("Definir noite", "Altera apenas a iluminação do cliente.", function() Lighting.ClockTime = 0 end)

    section("SESSÃO")
    toggle("Auto Rejoin on Kick", "autoRejoin", "Reinjeta ao ser kickado do servidor.",
        function(on) ensureAutoRejoinConn() end)
    toggle("Notificar entradas/saídas", "joinLeaveNotify", "Aviso local quando alguém entra ou sai.")
    action("Reentrar agora", "Força uma nova sessão neste lugar.", function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

-- ============================================================
-- SERVIDORES
-- ============================================================
pages["Servidores"] = function()
    subtitlePage.Text = "Entrar, reentrar e consultar sessões"
    section("SERVIDOR ATUAL")
    local f = card(116)
    label(f, "Jogadores: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers, 20, 15, 500, 20, P.text, 13, true)
    label(f, "ID: " .. (game.JobId ~= "" and game.JobId or "indisponível"), 20, 47, 580, 20, P.text3, 10)
    button(f, "Copiar ID", 20, 76, 130, 28, function()
        if type(setclipboard) == "function" then
            setclipboard(game.JobId); notify("ID copiado", "success")
        else notify("Área de transferência indisponível", "warn") end
    end)
    button(f, "Reentrar", 160, 76, 130, 28, function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end, true)

    section("ENTRAR POR ID")
    local boxCard = card(110)
    local job = input(boxCard, "Cole o ID do servidor", 20, 18, 430, 34)
    button(boxCard, "Entrar", 462, 18, 170, 34, function()
        local id = job.Text:gsub("%s+", "")
        if #id < 32 or not id:match("^[%w%-]+$") then
            return notify("ID de servidor inválido", "warn")
        end
        local ok = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, id, LocalPlayer)
        end)
        if not ok then notify("Teleporte recusado", "error")
        else notify("Tentando entrar...", "info") end
    end, true)
    label(boxCard, "O destino precisa aceitar entrada neste lugar.", 20, 66, 570, 20, P.text3, 10)

    section("LISTA PÚBLICA")
    local list = card(84)
    label(list, "Consulta usando request/http_request quando disponível.", 20, 15, 460, 18, P.text3, 11)
    button(list, "Server hop", 492, 24, 132, 36, function()
        local req = (type(request) == "function" and request)
            or (type(http_request) == "function" and http_request)
            or (type(syn) == "table" and type(syn.request) == "function" and syn.request)
        if not req then return notify("HTTP externo não disponível", "warn") end
        local ok, response = pcall(req, {
            Url = "https://games.roblox.com/v1/games/" .. game.PlaceId
                .. "/servers/Public?sortOrder=Asc&limit=50",
            Method = "GET",
        })
        if not ok or type(response) ~= "table" or type(response.Body) ~= "string" then
            return notify("Consulta de servidores falhou", "error")
        end
        local decoded = HttpService:JSONDecode(response.Body)
        local candidates = {}
        for _, v in ipairs(decoded.data or {}) do
            if type(v.id) == "string" and v.id ~= game.JobId
                and v.playing and v.maxPlayers and v.playing < v.maxPlayers then
                table.insert(candidates, v.id)
            end
        end
        if #candidates == 0 then
            return notify("Nenhum servidor com vaga encontrado", "warn")
        end
        task.spawn(function()
            for i = 1, math.min(3, #candidates) do
                local target = candidates[math.random(1, #candidates)]
                local ok2 = pcall(function()
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, target, LocalPlayer)
                end)
                if ok2 then
                    notify("Server hop: tentativa " .. i, "info")
                    return
                end
                task.wait(1)
            end
            notify("Todas as tentativas falharam", "error")
        end)
    end, true)
end

-- ============================================================
-- MÚSICA
-- ============================================================
pages["Musica"] = function()
    subtitlePage.Text = "Áudio local por ID de asset"
    section("REPRODUÇÃO")
    local f = card(200)
    label(f, "ID do áudio Roblox", 20, 15, 420, 22, P.text, 13, true)
    local id = input(f, "Ex.: 1843529609", 20, 44, 395, 34, App.lastMusicId)
    button(f, "Tocar", 431, 44, 97, 34, function() playMusicId(id.Text) end, true)
    button(f, "Parar", 538, 44, 90, 34, function() music:Stop() end)
    button(f, "Aleatório", 20, 90, 155, 32, playRandomMusic)
    button(f, "Pausar / retomar", 185, 90, 155, 32, function()
        if music.IsPlaying then music:Pause() else music:Resume() end
    end)
    label(f, "Assets privados podem ser bloqueados. Use os presets abaixo.",
        350, 95, 400, 40, P.text3, 11)
    slider("Volume", "musicVolume", 0, 1, .01, function(n)
        return math.floor(n * 100) .. "%"
    end, function(n) music.Volume = n end)
    toggle("Repetir", "musicLoop", nil, function(v) music.Looped = v end)

    section("PRESETS")
    local presetCard = card(180)
    for i, preset in ipairs(musicPresets) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        button(presetCard, preset.name, 20 + col * 400, 20 + row * 45, 380, 36, function()
            playMusicId(preset.id)
        end, i == 1)
    end

    section("MINHA PLAYLIST")
    local editor = card(120)
    local musicName = input(editor, "Nome da música", 20, 17, 268, 32)
    local musicId = input(editor, "ID do áudio", 302, 17, 277, 32, App.lastMusicId)
    button(editor, "Adicionar", 594, 17, 144, 32, function()
        local n = tonumber(musicId.Text:match("%d+"))
        if not n then return notify("ID inválido", "warn") end
        table.insert(S.playlist, {
            name = musicName.Text ~= "" and musicName.Text:sub(1, 28) or ("Áudio " .. n),
            id = tostring(n),
        })
        render("Musica")
        notify("Música adicionada à playlist", "success")
    end, true)
    label(editor, "Salve em um perfil para manter a playlist entre sessões.",
        20, 66, 670, 26, P.text3, 11)
    if #S.playlist == 0 then
        local empty = card(70)
        label(empty, "Sua playlist está vazia.", 22, 20, 600, 26, P.text3, 12)
    else
        for index, item in ipairs(S.playlist) do
            if type(item) == "table" then
                local row = card(68)
                label(row, tostring(item.name or ("Áudio " .. index)), 22, 18, 415, 24, P.text, 12, true)
                button(row, "Tocar", 527, 15, 95, 33, function() playMusicId(item.id) end, true)
                button(row, "Remover", 630, 15, 107, 33, function()
                    table.remove(S.playlist, index)
                    render("Musica")
                end)
            end
        end
    end
end

-- ============================================================
-- PIANO
-- ============================================================
pages["Piano"] = function()
    subtitlePage.Text = "Sequenciador de teclas para pianos do jogo"
    section("AUTO PIANO")
    local info = card(130)
    label(info, "Use em um piano que aceite as teclas mapeadas abaixo.",
        20, 15, 690, 28, P.text, 12, true)
    label(info, "Mapeamento atual: C=Z  D=X  E=C  F=V  G=B  A=N  B=M",
        20, 42, 690, 22, P.text2, 12)
    label(info, "O jogo precisa estar com o piano ativo. O menu se oculta durante a música.",
        20, 70, 690, 22, P.text3, 11)
    slider("Tempo do piano", "pianoBpm", 40, 300, 5, function(n) return n .. " BPM" end)

    section("MELODIAS")
    for _, song in ipairs(pianoSongs) do
        local row = card(84)
        label(row, song.name, 22, 12, 390, 22, P.text, 13, true)
        label(row, song.notes, 22, 42, 520, 21, P.text3, 11)
        button(row, "Tocar", 632, 24, 116, 36, function() startPiano(song.notes, S.pianoBpm) end, true)
    end

    section("SEQUÊNCIA PERSONALIZADA")
    local custom = card(200)
    label(custom, "Mapeamento das teclas (nota → tecla do jogo)", 20, 12, 500, 22, P.text, 12, true)
    local keyFields = {}
    local notesList = { "C", "D", "E", "F", "G", "A", "B" }
    for i, n in ipairs(notesList) do
        local col = (i - 1) % 7
        local kb = input(custom, n, 20 + col * 92, 40, 86, 30, S.pianoKeyMap[n])
        keyFields[n] = kb
    end
    button(custom, "Aplicar mapeamento", 20, 78, 200, 30, function()
        for n, box in pairs(keyFields) do
            local v = box.Text:upper():sub(1, 1)
            if v:match("[A-Z]") then S.pianoKeyMap[n] = v end
        end
        notify("Mapeamento salvo", "success")
    end)
    label(custom, "Cole a sequência abaixo (notas separadas por espaço):", 20, 115, 500, 22, P.text3, 11)
    local notesBox = input(custom, "C D E F G A B", 20, 138, 565, 34)
    button(custom, "Tocar", 600, 138, 123, 34, function()
        if notesBox.Text == "" then return notify("Digite uma sequência de notas", "warn") end
        startPiano(notesBox.Text, S.pianoBpm)
    end, true)
    button(custom, "Parar", 20, 176, 144, 20, function()
        App.pianoToken = (App.pianoToken or 0) + 1
        notify("Piano parado", "info")
    end)
end

-- ============================================================
-- APARÊNCIA
-- ============================================================
pages["Aparencia"] = function()
    subtitlePage.Text = "Avatar e etiqueta local"
    section("ETIQUETA LOCAL")
    toggle("Mostrar etiqueta", "tagEnabled",
        "Texto acima do seu avatar; visível apenas para você.", updateTag)
    local tagCard = card(160)
    local tagInput = input(tagCard, "Texto da etiqueta", 20, 18, 285, 33, S.tagName)
    local tagColor = input(tagCard, "#C9A4FF", 317, 18, 160, 33, rgb(S.tagColor))
    button(tagCard, "Aplicar texto/cor", 490, 18, 132, 33, function()
        local color = fromHex(tagColor.Text)
        if not color then return notify("Cor inválida", "warn") end
        S.tagName = tagInput.Text:sub(1, 24)
        S.tagColor = color
        updateTag()
        notify("Etiqueta atualizada", "success")
    end, true)
    label(tagCard, "Fonte", 20, 62, 100, 20, P.text2, 11, true)
    local fontNames = {}
    for name in pairs(FONT_MAP) do table.insert(fontNames, name) end
    table.sort(fontNames)
    for i, name in ipairs(fontNames) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        button(tagCard, name, 20 + col * 168, 82 + row * 34, 158, 28, function()
            S.tagFont = name
            updateTag()
            render("Aparencia")
            notify("Fonte: " .. name, "success")
        end, S.tagFont == name)
    end

    section("TAMANHO E EXTRUSÃO")
    slider("Tamanho do texto", "tagSize", 12, 52, 1, function(n) return n .. "px" end, updateTag)
    slider("Profundidade 3D", "tagExtrude", 0, 8, 1, function(n) return tostring(n) end, updateTag)
    toggle("Animar etiqueta", "tagAnimated",
        "Ativa partículas orbitando e glow pulsante.", updateTag)
    toggle("Etiqueta arco-íris", "tagRainbow",
        "Anima a cor da etiqueta acima da sua cabeça.", updateTag)
end

-- ============================================================
-- ANIMAÇÕES
-- ============================================================
pages["Animacoes"] = function()
    subtitlePage.Text = "Packs de locomoção • fetch dinâmico • replicados"

    section("PACK ATUAL")
    local infoCard = card(120)
    label(infoCard, "Pack ativo: " .. animPackState.current,
        22, 14, 500, 22, P.text, 13, true)
    label(infoCard,
        "status: " .. (animPackState.fetchLog[animPackState.current] or "—"),
        22, 40, 620, 22, P.text3, 11)
    label(infoCard, "Idle / Walk / Run / Jump / Fall / Climb / Swim substituídos e replicados.",
        22, 62, 620, 22, P.text3, 11)
    button(infoCard, "Resetar", 630, 20, 118, 36, function()
        resetAnimPack()
        render("Animacoes")
    end, true)
    button(infoCard, "Limpar cache", 520, 84, 228, 24, function()
        table.clear(animPackState.cache)
        table.clear(animPackState.fetchLog)
        notify("Cache limpo", "info")
        render("Animacoes")
    end)

    section("PACKS DISPONÍVEIS")
    local packNames = { "Padrão" }
    for n in pairs(BUNDLE_IDS) do table.insert(packNames, n) end
    for n in pairs(FALLBACK_IDS) do
        local already = false
        for _, existing in ipairs(packNames) do
            if existing == n then already = true break end
        end
        if not already then table.insert(packNames, n) end
    end
    table.sort(packNames)

    local rows = math.ceil(#packNames / 4)
    local grid = card(rows * 48 + 30)
    for i, name in ipairs(packNames) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local isActive = animPackState.current == name
        local b = button(grid, name, 18 + col * 168, 15 + row * 48, 158, 36, function()
            applyAnimPack(name)
            render("Animacoes")
        end, isActive)
        local st = animPackState.fetchLog[name]
        if st and st:find("erro") then
            local s = b:FindFirstChildOfClass("UIStroke")
            if s then s.Color = P.danger end
        elseif st and st:find("fallback") then
            local s = b:FindFirstChildOfClass("UIStroke")
            if s then s.Color = P.warn end
        end
    end

    section("MIX CUSTOM • um pack por movimento")
    local roles = { "Idle", "Walk", "Run", "Jump", "Fall", "Climb" }
    local mixCard = card(#roles * 48 + 60)
    local cycleNames = { "None" }
    for _, n in ipairs(packNames) do table.insert(cycleNames, n) end

    for i, role in ipairs(roles) do
        local y = 15 + (i - 1) * 48
        label(mixCard, role, 22, y + 8, 120, 22, P.text, 12, true)
        local current = animPackState.mix[role] or "None"
        button(mixCard, current, 150, y, 400, 36, function()
            local idx = 1
            for k, v in ipairs(cycleNames) do
                if v == animPackState.mix[role] then idx = k break end
            end
            idx = (idx % #cycleNames) + 1
            animPackState.mix[role] = cycleNames[idx]
            render("Animacoes")
        end)
    end

    button(mixCard, "Aplicar mix", 580, 15, 168, 36, function()
        applyCustomMix(animPackState.mix)
    end, true)
    button(mixCard, "Limpar mix", 580, 63, 168, 36, function()
        animPackState.mix = { Idle="None", Walk="None", Run="None", Jump="None", Fall="None", Climb="None" }
        render("Animacoes")
    end)

    section("BUNDLE ID CUSTOM")
    local customCard = card(150)
    label(customCard, "Adicione um pack informando o bundle ID do Roblox.",
        22, 14, 640, 20, P.text, 12, true)
    label(customCard, "Descubra o ID na URL: roblox.com/bundles/[ID]/...",
        22, 36, 640, 20, P.text3, 11)

    local nameBox = input(customCard, "Nome do pack", 22, 66, 220, 32)
    local bundleBox = input(customCard, "Bundle ID", 250, 66, 180, 32)
    button(customCard, "Adicionar", 438, 66, 140, 32, function()
        local n = nameBox.Text:gsub("%s+", "")
        local bid = tonumber(bundleBox.Text)
        if n == "" or not bid then return notify("Nome e ID obrigatórios", "warn") end
        BUNDLE_IDS[n] = bid
        table.clear(animPackState.cache)
        notify("Bundle " .. n .. " adicionado (" .. bid .. ")", "success")
        render("Animacoes")
    end, true)
    button(customCard, "Testar", 586, 66, 140, 32, function()
        local bid = tonumber(bundleBox.Text)
        if not bid then return notify("ID inválido", "warn") end
        local pack, why = fetchBundleIds(bid)
        if pack then
            notify("Bundle OK: " .. tostring(why), "success")
        else
            notify("Falhou: " .. tostring(why), "error")
        end
    end)

    section("LEGENDA")
    local legend = card(140)
    label(legend, "verde: fetch ok do marketplace", 22, 14, 300, 20, P.ok, 11)
    label(legend, "amarelo: fallback (ids hardcoded)", 22, 36, 300, 20, P.warn, 11)
    label(legend, "vermelho: falhou — bundle inválido", 22, 58, 300, 20, P.danger, 11)
    label(legend, "Todos usam Core priority — replica pra todos os clientes.",
        22, 88, 640, 20, P.text2, 11)
    label(legend, "Se o fetch falhar (sem conexão), ele usa os IDs fallback automaticamente.",
        22, 110, 640, 20, P.text3, 10)
end

-- ============================================================
-- CONFIGURAÇÕES
-- ============================================================
local function snapshotState()
    local data = {}
    for k, v in pairs(S) do
        if typeof(v) == "Color3" then data[k] = rgb(v)
        elseif typeof(v) == "EnumItem" then data[k] = v.Name
        else data[k] = v end
    end
    data._version = 13.0
    data.lastMusicId = App.lastMusicId
    data.currentPage = App.currentPage
    data.animPack = animPackState.current
    data.panelPosition = {
        main.Position.X.Scale, main.Position.X.Offset,
        main.Position.Y.Scale, main.Position.Y.Offset,
    }
    return data
end

local function applyProfile(data)
    if type(data) ~= "table" then return false end
    local limits = {
        speedValue = { 16, 1000 }, jumpValue = { 0, 5000 }, flySpeed = { 20, 5000 },
        spinSpeed = { 30, 10000 }, aimFov = { 40, 350 }, aimSmooth = { .03, .95 },
        aimDist = { 50, 2000 }, espMaxDist = { 50, 3000 }, scale = { .6, 1.25 },
        glass = { 0, .5 }, musicVolume = { 0, 1 }, shaderIntensity = { 0, 1 },
        pianoBpm = { 40, 300 }, tiltStrength = { 0, 2 }, freecamSpeed = { 12, 150 },
        followSmooth = { .05, 1 }, tagSize = { 12, 52 }, tagExtrude = { 0, 8 },
        flingPower = { 500, 50000 }, flingRate = { 0.01, 0.5 }, flingRips = { 4, 32 },
        aimPrediction = { 0, 0.4 },
    }
    local pendingToggles = {}
    local pendingPack = nil
    for k, v in pairs(data) do
        if k == "_version" then
        elseif k == "animPack" and type(v) == "string" then
            pendingPack = v
        elseif k == "accent" and type(v) == "string" then
            setAccent(fromHex(v) or S.accent)
        elseif k == "tagColor" and type(v) == "string" then
            S.tagColor = fromHex(v) or S.tagColor
        elseif k == "aimKey" and type(v) == "string" and Enum.UserInputType[v] then
            S.aimKey = Enum.UserInputType[v]
        elseif k == "lastMusicId" and type(v) == "string" then
            App.lastMusicId = v
        elseif k == "panelPosition" and type(v) == "table"
            and type(v[1]) == "number" and type(v[2]) == "number"
            and type(v[3]) == "number" and type(v[4]) == "number" then
            main.Position = UDim2.new(v[1], v[2], v[3], v[4])
            App.userMovedPanel = true
        elseif k == "currentPage" and type(v) == "string" and pages[v] then
            App.pendingPage = v
        elseif k == "binds" and type(v) == "table" then
            S.binds = {}
            for feature, key in pairs(v) do
                if type(feature) == "string" and type(key) == "string" then
                    S.binds[feature] = key
                end
            end
        elseif k == "playlist" and type(v) == "table" then
            S.playlist = {}
            for _, item in ipairs(v) do
                if type(item) == "table" and tonumber(item.id) and #S.playlist < 50 then
                    table.insert(S.playlist, {
                        name = tostring(item.name or "Áudio"):sub(1, 28),
                        id = tostring(item.id),
                    })
                end
            end
        elseif k == "pianoKeyMap" and type(v) == "table" then
            S.pianoKeyMap = S.pianoKeyMap or {}
            for note, key in pairs(v) do
                if type(note) == "string" and type(key) == "string" then
                    S.pianoKeyMap[note] = key
                end
            end
        elseif S[k] ~= nil and typeof(S[k]) == typeof(v) then
            if type(v) == "number" and limits[k] then
                S[k] = clamp(v, limits[k][1], limits[k][2])
            elseif type(v) ~= "table" then
                if type(S[k]) == "boolean" then
                    pendingToggles[k] = v
                end
                S[k] = v
            end
        end
    end

    if pendingToggles.godmode then
        if S.godmode then startGodmode() else stopGodmode() end
    end
    if pendingToggles.invisible then
        if S.invisible then applyInvisibility() else restoreInvisibility() end
    end
    if pendingToggles.fly and not S.fly then stopFly() end
    if pendingToggles.freecam ~= nil then
        local cam = Workspace.CurrentCamera
        if cam then
            if S.freecam then
                App.original.cameraType = App.original.cameraType or cam.CameraType
                cam.CameraType = Enum.CameraType.Scriptable
                enableFreecamSink()
                enableFreecamJumpBlock()
            else
                cam.CameraType = App.original.cameraType or Enum.CameraType.Custom
                cam.CameraSubject = humanoid()
                disableFreecamSink()
                disableFreecamJumpBlock()
            end
        end
    end
    if pendingToggles.autoRejoin ~= nil then ensureAutoRejoinConn() end
    if pendingPack and pendingPack ~= animPackState.current then
        task.spawn(function() applyAnimPack(pendingPack) end)
    end

    resize()
    main.BackgroundTransparency = S.glass
    reapplyVisuals()
    refreshESP()
    updateItems()
    updateTag()
    music.Volume = S.musicVolume
    music.Looped = S.musicLoop
    App.aimTarget = nil
    return true
end

pages["Configuracoes"] = function()
    subtitlePage.Text = "Cores, escala, tilt e perfis"
    section("TEMA 3D")
    toggle("Borda RGB animada", "rgb", "Ciclo de cores; o resto do tema usa a cor principal.")
    toggle("Parallax em camadas", "parallax", "Move elementos com o mouse em profundidades diferentes.")
    toggle("Fundo 3D animado", "bg3d", "Partículas flutuantes no fundo do painel.")
    slider("Força do tilt 3D nos cards", "tiltStrength", 0, 2, .1, function(n)
        return math.floor(n * 100) .. "%"
    end)
    local colors = card(112)
    label(colors, "Cor principal em hexadecimal", 20, 15, 410, 22, P.text, 13, true)
    local hex = input(colors, "#A570FF", 20, 44, 386, 33, rgb(S.accent))
    button(colors, "Aplicar cor", 427, 44, 199, 33, function()
        local c = fromHex(hex.Text)
        if not c then return notify("Use o formato #RRGGBB", "warn") end
        setAccent(c)
        S.rgb = false
        render("Configuracoes")
        notify("Cor aplicada", "success")
    end, true)
    slider("Escala da interface", "scale", .6, 1.25, .05, function(n)
        return math.floor(n * 100) .. "%"
    end, resize)
    slider("Transparência da janela", "glass", 0, .5, .05, function(n)
        return math.floor(n * 100) .. "%"
    end, function(n) main.BackgroundTransparency = n end)

    section("PERFIS")
    local p = card(180)
    local profile = input(p, "Nome do perfil", 20, 17, 386, 33, "Padrao")
    button(p, "Salvar", 427, 17, 95, 33, function()
        local name = profile.Text:gsub("%s+", ""):sub(1, 32)
        if name == "" then return notify("Nome vazio", "warn") end
        local data = snapshotState()
        App.slots[name] = data
        local disk = saveDisk(name, data)
        render("Configuracoes")
        notify(disk and "Perfil '" .. name .. "' salvo no disco" or "Perfil '" .. name .. "' salvo na sessão", "success")
    end, true)
    button(p, "Carregar", 531, 17, 95, 33, function()
        local data = App.slots[profile.Text] or loadDisk(profile.Text)
        if not data then return notify("Perfil não encontrado", "warn") end
        applyProfile(data)
        render("Configuracoes")
        notify("Perfil carregado", "success")
    end)
    button(p, "Exportar JSON", 20, 66, 177, 31, function()
        local encoded = HttpService:JSONEncode(snapshotState())
        if type(setclipboard) == "function" then
            setclipboard(encoded); notify("Perfil copiado", "success")
        else notify("Clipboard indisponível", "warn") end
    end)
    local import = input(p, "Cole o JSON do perfil", 20, 111, 386, 33)
    button(p, "Importar", 427, 111, 199, 33, function()
        local ok, data = pcall(function() return HttpService:JSONDecode(import.Text) end)
        if not ok or type(data) ~= "table" then return notify("JSON inválido", "warn") end
        applyProfile(data)
        render("Configuracoes")
        notify("Perfil importado", "success")
    end, true)

    local saved = profileNames()
    section("PERFIS SALVOS  •  CLIQUE PARA USAR")
    local savedCard = card(math.max(76, math.min(#saved, 5) * 52 + 22))
    if #saved == 0 then
        label(savedCard, "Nenhum perfil salvo ainda.", 21, 21, 500, 28, P.text3, 12)
    else
        local list = new("ScrollingFrame", {
            Position = UDim2.fromOffset(12, 11), Size = UDim2.new(1, -24, 1, -22),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3, ScrollBarImageColor3 = P.line2,
            CanvasSize = UDim2.fromOffset(0, #saved * 52),
        }, savedCard)
        for i, name in ipairs(saved) do
            local row = corner(new("Frame", {
                Position = UDim2.fromOffset(2, (i - 1) * 52),
                Size = UDim2.new(1, -10, 0, 46),
                BackgroundColor3 = P.bg0, BackgroundTransparency = .15,
            }, list), 9)
            label(row, name, 15, 11, 390, 26, P.text, 12, true)
            button(row, "Usar", 502, 9, 102, 30, function()
                local data = App.slots[name] or loadDisk(name)
                if not data then return notify("Perfil indisponível", "warn") end
                applyProfile(data)
                render("Configuracoes")
                notify("Perfil " .. name .. " aplicado", "success")
            end, true)
            button(row, "Excluir", 612, 9, 103, 30, function()
                App.slots[name] = nil
                local ok = deleteProfile(name)
                render("Configuracoes")
                notify(ok and "Perfil excluído" or "Falha ao excluir do disco", ok and "info" or "warn")
            end)
        end
    end

    section("SESSÃO")
    action("Descarregar menu", "Remove interface, conexões e efeitos locais.", function()
        App.Destroy()
    end)
end

-- ============================================================
-- NAV BUILD
-- ============================================================
local names = {
    "Início", "Jogadores", "Visuais", "Movimento", "Mira", "Fling",
    "Protecao", "Servidores", "Musica", "Piano", "Aparencia", "Animacoes", "Configuracoes",
}
local icons = { "INI", "JOG", "VIS", "MOV", "MIR", "FLG", "PRT", "SRV", "MUS", "PIA", "APR", "ANM", "CFG" }

for i, name in ipairs(names) do
    local b = corner(new("TextButton", {
        Size = UDim2.fromOffset(58, 30),
        BackgroundColor3 = P.bg1, BackgroundTransparency = .6,
        TextColor3 = P.text3, Text = icons[i], TextSize = 11,
        Font = Enum.Font.GothamBold, LayoutOrder = i,
        AutoButtonColor = false, ZIndex = 17,
    }, nav), 11)
    local s = stroke(b, P.line2, 1, .7)
    navButtons[name] = b
    connect(b.MouseButton1Click, function() render(name) end)
    connect(b.MouseEnter, function()
        if App.currentPage == name then return end
        tween(b, TweenInfo.new(.22), { BackgroundColor3 = P.card3, BackgroundTransparency = .1, TextColor3 = P.text })
        tween(s, TweenInfo.new(.22), { Color = S.accent, Transparency = .4 })
        subtitlePage.Text = name
    end)
    connect(b.MouseLeave, function()
        if App.currentPage == name then return end
        tween(b, TweenInfo.new(.28), { BackgroundColor3 = P.bg1, BackgroundTransparency = .6, TextColor3 = P.text3 })
        tween(s, TweenInfo.new(.28), { Color = P.line2, Transparency = .7 })
        subtitlePage.Text = activePageSubtitle
    end)
end

-- ============================================================
-- PLAYER EVENTS
-- ============================================================
local function bindPlayerEvents(p)
    if p == LocalPlayer then return end
    connect(p.CharacterAdded, function()
        task.wait(.4)
        if App.alive then updatePlayerVisual(p) end
    end)
    connect(p:GetPropertyChangedSignal("Team"), function()
        if App.alive then updatePlayerVisual(p) end
    end)
end

connect(Players.PlayerAdded, function(p)
    bindPlayerEvents(p)
    if S.joinLeaveNotify and App.alive then
        notify(p.DisplayName .. " entrou", "success")
    end
    if App.currentPage == "Jogadores" and App.render then
        task.defer(function() if App.alive and App.currentPage == "Jogadores" then App.render("Jogadores") end end)
    end
end)

connect(Players.PlayerRemoving, function(p)
    removePlayerVisual(p)
    if App.selected == p then App.selected = nil end
    if App.flingTarget == p then flingClearTarget() end
    if S.joinLeaveNotify and App.alive then
        notify(p.DisplayName .. " saiu", "info")
    end
    if App.currentPage == "Jogadores" and App.render then
        task.defer(function() if App.alive and App.currentPage == "Jogadores" then App.render("Jogadores") end end)
    end
end)

for _, p in ipairs(Players:GetPlayers()) do bindPlayerEvents(p) end

connect(LocalPlayer:GetPropertyChangedSignal("Team"), function()
    if App.alive then refreshESP(); App.aimTarget = nil end
end)

connect(LocalPlayer.CharacterAdded, function(c)
    App.original.speed = nil; App.original.jump = nil
    table.clear(App.collisions); stopFly()
    App.lastGroundY = nil
    App.currentAnim = nil
    App.aimTarget = nil
    task.wait(.5)
    if not App.alive then return end
    if S.invisible then applyInvisibility() end
    if S.godmode then startGodmode() end
    local h = c:WaitForChild("Humanoid", 5)
    if h then
        App.original.speed = h.WalkSpeed
        App.original.jump = h.JumpPower
        App.original.jumpHeight = h.JumpHeight
        App.original.useJumpPower = h.UseJumpPower
    end
    task.defer(function() if App.alive then updateTag() end end)
end)

if humanoid() then
    App.original.speed = humanoid().WalkSpeed
    App.original.jump = humanoid().JumpPower
    App.original.jumpHeight = humanoid().JumpHeight
    App.original.useJumpPower = humanoid().UseJumpPower
end

connect(LocalPlayer.Idled, function()
    if not S.antiAfk or not okVirtual then return end
    local ok = pcall(function()
        virtualUser:CaptureController()
        virtualUser:ClickButton2(Vector2.zero)
    end)
    if not ok then
        S.antiAfk = false
        notify("Anti AFK indisponível neste cliente", "error")
    end
end)

-- ============================================================
-- INPUT
-- ============================================================
local BLOCKED_BINDS = { F3 = true, MouseButton1 = true, Unknown = true }

connect(UserInputService.InputBegan, function(i, processed)
    if i.KeyCode == S.panicBind then App.Destroy(); return end

    if App.aimKeyCapture then
        if i.KeyCode == Enum.KeyCode.Escape then
            App.aimKeyCapture = false
            render("Mira")
            return
        end
        S.aimKey = i.UserInputType
        App.aimKeyCapture = false
        notify("Tecla do aim: " .. i.UserInputType.Name, "success")
        render("Mira")
        return
    end

    if App.bindCapture then
        local key = App.bindCapture
        if i.KeyCode == Enum.KeyCode.Escape then
            App.bindCapture = nil
            if App.toggleVisuals[key] then App.toggleVisuals[key]() end
            return
        end
        local name = i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name or i.UserInputType.Name
        if BLOCKED_BINDS[name] then
            return notify("Escolha outra tecla", "warn")
        end
        for k, v in pairs(S.binds) do
            if v == name then S.binds[k] = nil end
        end
        S.binds[key] = name
        App.bindCapture = nil
        if App.toggleVisuals[key] then App.toggleVisuals[key]() end
        notify("Atalho definido: " .. name, "success")
        return
    end

    if i.KeyCode == Enum.KeyCode.F3 then
        main.Visible = not main.Visible
        return
    end

    if i.UserInputType == Enum.UserInputType.MouseButton1
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
        local cam = Workspace.CurrentCamera
        if cam then
            local mouseLoc = UserInputService:GetMouseLocation()
            local ray = cam:ViewportPointToRay(mouseLoc.X, mouseLoc.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            local ignored = {}
            local ownC = character(); if ownC then table.insert(ignored, ownC) end
            params.FilterDescendantsInstances = ignored
            local hit = Workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
            if hit and hit.Instance then
                local model = hit.Instance:FindFirstAncestorOfClass("Model")
                if model then
                    local plr = Players:GetPlayerFromCharacter(model)
                    if plr and plr ~= LocalPlayer then
                        App.flingTarget = plr
                        notify("Alvo do fling: " .. plr.DisplayName, "success")
                        if App.currentPage == "Fling" then render("Fling") end
                        return
                    end
                end
            end
        end
    end

    if processed then return end
    local name = i.KeyCode ~= Enum.KeyCode.Unknown and i.KeyCode.Name or i.UserInputType.Name

    if i.UserInputType ~= Enum.UserInputType.MouseButton1 then
        for key, binding in pairs(S.binds) do
            if binding == name and S[key] ~= nil then
                S[key] = not S[key]
                local handler = App.toggleHandlers[key]
                if handler then
                    local ok, e = pcall(handler, S[key])
                    if not ok then notify("Falha: " .. tostring(e):sub(1, 70), "error") end
                end
                if App.toggleVisuals[key] then App.toggleVisuals[key]() end
            end
        end
    end

    if S.infiniteJump and i.KeyCode == Enum.KeyCode.Space then
        local h = humanoid()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end

    if S.clickTp and i.UserInputType == Enum.UserInputType.MouseButton1
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local cam = Workspace.CurrentCamera
        local r = root()
        if cam and r then
            local mouse = UserInputService:GetMouseLocation()
            local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = { character() }
            local hit = Workspace:Raycast(ray.Origin, ray.Direction * 1200, params)
            if hit then r.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0)) end
        end
    end
end)

-- ============================================================
-- HEARTBEAT (lógica)
-- ============================================================
local elapsed = 0
local antiFlingCooldown = 0

connect(RunService.Heartbeat, function(dt)
    if not App.alive then return end
    local h = humanoid()
    local r = root()
    local cam = Workspace.CurrentCamera

    if App.flyJustStopped then
        App.flyStopTimer = math.max(0, App.flyStopTimer - dt)
        if App.flyStopTimer <= 0 then
            App.flyJustStopped = false
        end
    end

    -- invisibilidade: rate-limit 10Hz
    if S.invisible then
        App.invisAccum += dt
        if App.invisAccum >= 0.1 then
            App.invisAccum = 0
            applyInvisibility()
        end
    end

    if h then
        if S.speed then
            if h.WalkSpeed ~= S.speedValue then h.WalkSpeed = S.speedValue end
        elseif App.original.speed and h.WalkSpeed == S.speedValue then
            h.WalkSpeed = App.original.speed
        end
        if S.jump then
            h.UseJumpPower = false
            if h.JumpHeight ~= S.jumpValue then h.JumpHeight = S.jumpValue end
        elseif App.original.jumpHeight and h.JumpHeight == S.jumpValue then
            h.JumpHeight = App.original.jumpHeight
            h.UseJumpPower = App.original.useJumpPower ~= false
        end

        if S.fly and r and cam then
            ensureFly(r, h)
            h.PlatformStand = true
            h.AutoRotate = false

            local camLook = cam.CFrame.LookVector
            local camRight = cam.CFrame.RightVector
            local flatRight = Vector3.new(camRight.X, 0, camRight.Z)
            if flatRight.Magnitude > 0 then flatRight = flatRight.Unit end

            local moveVec = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += camLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= camLook end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveVec -= Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveVec -= flatRight end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then moveVec += flatRight end

            if moveVec.Magnitude > 0 then
                App.flyVelocity.Velocity = moveVec.Unit * S.flySpeed
            else
                App.flyVelocity.Velocity = Vector3.zero
            end
            local yaw = math.atan2(-camLook.X, -camLook.Z)
            App.flyGyro.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, yaw, 0)
        elseif App.flyVelocity then
            stopFly()
        end

        if S.antiRagdoll then
            local state = h:GetState()
            if state == Enum.HumanoidStateType.Ragdoll
                or state == Enum.HumanoidStateType.FallingDown then
                h:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
        end
    end

    antiFlingCooldown = math.max(0, antiFlingCooldown - dt)
    if S.antiFling and r and not S.fly
        and r.AssemblyLinearVelocity.Magnitude > 260
        and antiFlingCooldown <= 0 then
        r.AssemblyLinearVelocity = Vector3.zero
        r.AssemblyAngularVelocity = Vector3.zero
        antiFlingCooldown = .25
    end

    if S.noclip and character() and r then
        local grounded = h and h.FloorMaterial ~= Enum.Material.Air
        if grounded then App.lastGroundY = r.Position.Y end

        if App.lastGroundY and not S.fly and not App.flyJustStopped then
            if r.Position.Y < App.lastGroundY - 20 then
                local px, pz = r.Position.X, r.Position.Z
                r.CFrame = CFrame.new(px, App.lastGroundY + 4, pz)
                r.AssemblyLinearVelocity = Vector3.zero
                r.AssemblyAngularVelocity = Vector3.zero
                local now = os.clock()
                if now - App.lastVoidNotify > 3 then
                    App.lastVoidNotify = now
                    notify("Anti-void ativado", "warn")
                end
            end
        end
    end

    if S.spin and r then
        r.CFrame *= CFrame.Angles(0, math.rad(S.spinSpeed) * dt, 0)
    end

    if S.follow and r and App.selected then
        local target = selectedRoot()
        if target then
            local mode = S.followMode or "Atrás"
            local offset = CFrame.new(0, 3, 5)
            for _, m in ipairs(followModes) do
                if m.name == mode then offset = m.offset; break end
            end
            local goal = target.CFrame * offset
            -- CFrame lerp FPS-independent (sem *60)
            local smoothAlpha = 1 - math.pow(S.followSmooth or .28, dt)
            r.CFrame = r.CFrame:Lerp(goal, smoothAlpha)
            r.AssemblyLinearVelocity = Vector3.zero
            r.AssemblyAngularVelocity = Vector3.zero
            if h then h.PlatformStand = true end
        end
    end

    elapsed += dt
    if elapsed > .25 then
        elapsed = 0
        if S.esp and r then
            for p, list in pairs(App.playerVisuals) do
                local tr = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                local th = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
                local d = tr and (tr.Position - r.Position).Magnitude or math.huge
                local inRange = S.espNoDistLimit or (d <= S.espMaxDist)
                for _, obj in ipairs(list) do
                    if obj and obj.Parent then
                        if obj:IsA("Highlight") or obj:IsA("BillboardGui") then
                            obj.Enabled = inRange
                        end
                    end
                end
                if list.text and list.text.Parent then
                    local bits = {}
                    if S.espName then table.insert(bits, p.DisplayName) end
                    if S.espDistance then table.insert(bits, math.floor(d) .. " studs") end
                    if S.espHealth and th then
                        table.insert(bits, math.floor(th.Health) .. " / " .. math.floor(th.MaxHealth) .. " HP")
                    end
                    list.text.Text = table.concat(bits, "  •  ")
                end
            end
        end
    end
end)

-- ============================================================
-- RENDER STEP (visual)
-- ============================================================
App.renderBinding = "PrismaNexus_Render_" .. LocalPlayer.UserId
RunService:BindToRenderStep(App.renderBinding, Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not App.alive then return end

    App.frameCount += 1
    local now = tick()
    if now - App.lastFpsUpdate >= 0.5 then
        App.fps = math.floor(App.frameCount / (now - App.lastFpsUpdate))
        App.frameCount = 0; App.lastFpsUpdate = now
    end
    if now - App.lastPing >= 1 then
        App.lastPing = now
        pcall(function() App.ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
    end
    perfLabel.Text = "FPS " .. App.fps .. "  •  PING " .. App.ping .. "ms"

    edgeGrad.Rotation = (os.clock() * 18) % 360
    local hue = (os.clock() * .12) % 1
    if S.rgb then
        edgeGrad.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, .85, 1)),
            ColorSequenceKeypoint.new(.35, Color3.fromHSV((hue + .15) % 1, .85, 1)),
            ColorSequenceKeypoint.new(.65, Color3.fromHSV((hue + .35) % 1, .85, 1)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV((hue + .55) % 1, .85, 1)),
        })
        logoGlow.BackgroundColor3 = Color3.fromHSV((hue + .3) % 1, .85, 1)
    else
        logoGlow.BackgroundColor3 = S.accent
    end
    logoGlow.BackgroundTransparency = .85 + math.sin(os.clock() * 2) * .08

    if App.tagText and App.tagText.Parent then
        if S.tagRainbow then
            local hc = Color3.fromHSV((os.clock() * .19) % 1, .82, 1)
            App.tagText.TextColor3 = hc
            if App.tagLayers then
                for _, l in ipairs(App.tagLayers) do
                    l.TextColor3 = l.TextColor3:Lerp(hc, 0.15)
                end
            end
            if App.tagUnderline then App.tagUnderline.BackgroundColor3 = hc end
        end
        if S.tagAnimated then
            if App.tagUnderlineGrad then App.tagUnderlineGrad.Rotation = (os.clock() * 80) % 360 end
            if App.tagGrad then App.tagGrad.Rotation = (os.clock() * 45) % 360 end
        end
    end

    subtitle.TextColor3 = S.accent
    statusDot.BackgroundColor3 = S.rgb and Color3.fromHSV(hue, .85, 1) or S.accent
    statusGlow.Color = statusDot.BackgroundColor3
    fovStroke.Color = S.accent

    if S.parallax then
        local m = UserInputService:GetMouseLocation()
        local vpSize = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local cx, cy = vpSize.X / 2, vpSize.Y / 2
        App.parallax.tx = clamp((m.X - cx) / cx, -1, 1)
        App.parallax.ty = clamp((m.Y - cy) / cy, -1, 1)
    else
        App.parallax.tx = 0; App.parallax.ty = 0
    end
    App.parallax.x = App.parallax.x + (App.parallax.tx - App.parallax.x) * math.min(1, dt * 6)
    App.parallax.y = App.parallax.y + (App.parallax.ty - App.parallax.y) * math.min(1, dt * 6)
    local px, py = App.parallax.x, App.parallax.y

    local t = os.clock()
    if S.bg3d and main.Visible and t - App.last3DUpdate >= (1 / 30) then
        App.last3DUpdate = t
        vpCamera.CFrame = CFrame.new(Vector3.new(px * 1.4, -py * 1.0 + 0.2, 12))
            * CFrame.Angles(math.rad(-py * 6), math.rad(px * 8), 0)

        for _, d in ipairs(particles3D) do
            if d.part.Parent then
                local wx = d.basePos.X + math.sin(t * d.speedX + d.phase) * d.ampX
                local wy = d.basePos.Y + math.cos(t * d.speedY + d.phase * 1.3) * d.ampY
                local wz = d.basePos.Z + math.sin(t * d.speedZ + d.phase * 0.7) * d.ampZ
                d.part.CFrame = CFrame.new(wx, wy, wz)
                d.part.Transparency = clamp(0.15 + math.sin(t * d.pulse + d.phase) * 0.25, 0.05, 0.55)
                if S.rgb then
                    local hueShift = (d.phase / (math.pi * 2)) * 0.15
                    d.part.Color = Color3.fromHSV((hue + hueShift) % 1, 0.7, 1)
                else
                    d.part.Color = d.baseColor
                end
            end
        end
    end

    local cam = Workspace.CurrentCamera
    if cam then
        fovGui.Size = UDim2.fromOffset(S.aimFov * 2, S.aimFov * 2)
        fovGui.Visible = (S.aim and S.aimShowFov) or App.fovPreview

        if S.freecam then
            cam.CameraType = Enum.CameraType.Scriptable

            if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                local delta = UserInputService:GetMouseDelta()
                App.freecamAngle = Vector2.new(
                    App.freecamAngle.X - delta.X * 0.005,
                    clamp(App.freecamAngle.Y - delta.Y * 0.005, -math.pi/2 + 0.05, math.pi/2 - 0.05)
                )
            end

            local move = Vector3.zero
            local fwd = Vector3.new(math.sin(App.freecamAngle.X), 0, math.cos(App.freecamAngle.X))
            local right = Vector3.new(fwd.Z, 0, -fwd.X)
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += fwd end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= fwd end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += right end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= right end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
            if move.Magnitude > 0 then
                cam.CFrame = cam.CFrame + move.Unit * S.freecamSpeed * dt
            end

            local pos = cam.CFrame.Position
            local rot = CFrame.fromEulerAnglesYXZ(App.freecamAngle.Y, App.freecamAngle.X, 0)
            cam.CFrame = CFrame.new(pos) * rot

        elseif S.aim and (not S.aimHold or UserInputService:IsMouseButtonPressed(S.aimKey)) then
            local target = bestTarget()
            if target then
                local pos = predictedPos(target)
                local goal = CFrame.lookAt(cam.CFrame.Position, pos)
                local alpha
                if S.aimSmooth <= .03 then
                    alpha = 1
                else
                    -- correção: sem *60
                    alpha = 1 - math.pow(S.aimSmooth, dt)
                end
                cam.CFrame = cam.CFrame:Lerp(goal, clamp(alpha, .01, 1))
                if S.aimAutoFire and not main.Visible
                    and not UserInputService:GetFocusedTextBox()
                    and os.clock() - (App.lastFire or 0) > .18 then
                    App.lastFire = os.clock()
                    local fired = fireOnce(cam)
                    if not fired and not App.fireUnsupported then
                        App.fireUnsupported = true
                        S.aimAutoFire = false
                        notify("Disparo automático indisponível neste executor", "warn")
                    end
                end
            end
        end
    end

    if S.espRainbow then
        local color = Color3.fromHSV(hue, .85, 1)
        for _, list in pairs(App.playerVisuals) do
            for _, obj in ipairs(list) do
                if obj and obj.Parent then
                    if obj:IsA("Highlight") then
                        obj.OutlineColor = color
                        if obj.FillTransparency < 1 then obj.FillColor = color end
                    end
                end
            end
        end
    end

    -- tracer via Drawing API
    if S.espTracer and hasDrawing and cam then
        local vpSize = cam.ViewportSize
        for p, line in pairs(drawLines) do
            if not S.esp or p == LocalPlayer or not p.Character then
                if line.Visible then line.Visible = false end
            else
                local head = p.Character:FindFirstChild("Head")
                local hrp = p.Character:FindFirstChild("HumanoidRootPart")
                if head and hrp then
                    local screen, onScreen = cam:WorldToViewportPoint(hrp.Position)
                    if onScreen then
                        line.From = Vector2.new(vpSize.X / 2, vpSize.Y)
                        line.To = Vector2.new(screen.X, screen.Y)
                        line.Color = S.accent
                        line.Visible = true
                    else
                        line.Visible = false
                    end
                else
                    line.Visible = false
                end
            end
        end
    end
end)

-- ============================================================
-- BOOT
-- ============================================================
render("Início")
if App.pendingPage then
    render(App.pendingPage)
    App.pendingPage = nil
end
notify("Prisma Nexus • Hyperion Refined v13.0 carregado", "success")