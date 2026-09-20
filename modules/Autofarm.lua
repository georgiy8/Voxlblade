--========================================================--
-- Autofarm Module (Voxlblade)
-- Fly to Hitbox -> stick while alive -> next target
-- Offset X/Y/Z + optimized mob cache
--========================================================--

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

local MOB_NAMES = {
    "Buni", "DireBuni", "PlainsWoof", "Mageling", "Croakernaut",
    "LordFrogg", "Bulfrogg", "Toadzerker", "Dragigator", "Lilimonster",
    "Drone", "Bumblz", "Bomber", "QueenBumblz", "Puffball",
    "SporeBossMan", "Sporeling", "Lord Stratos Altolodon", "Whirlray",
    "Caci", "Slizard", "CaciKing", "StoneCleric", "VoidRoot",
    "Bowldur", "BastionGuardian", "StoneArcher", "StoneKnight",
    "CrazyHare", "BaniPrince", "RedRockHare", "Batty", "GlacialSnapper",
    "WinterWoof", "Delta-Spider", "Stalker", "Scow", "SteamGolem",
    "Omega-Batty", "DeepSpider", "BrainBurner", "Proto-Mungus",
    "Easter", "Grumpkin", "THEHALLOWSOUL",
}

local MOB_BY_LEN = table.clone(MOB_NAMES)
table.sort(MOB_BY_LEN, function(a, b)
    return #a > #b
end)

local MobLookup = {}
for _, name in ipairs(MOB_NAMES) do
    MobLookup[name] = true
end

------------------------------------------------------------
-- State
------------------------------------------------------------

local FarmEnabled = false
local FarmRunning = false

local AutoLeftClick = false
local AutoRightClick = false
local AutoQ = false
local AutoR = false

local AUTOCLICK_DELAY = 3

local ActiveTween = nil
local ActiveMob = nil
local ActiveHitbox = nil
local Stuck = false

local TweenSpeed = 50
local StickDistance = 4

local OffsetX = 0
local OffsetY = 3
local OffsetZ = 0

local SelectedMobs = {}

-- cache: [mob BasePart] = hitbox BasePart
local MobCache = {}
local CacheDirty = true
local LastCacheRebuild = 0
local CACHE_INTERVAL = 0.75

local HeartbeatConn = nil

------------------------------------------------------------
-- Character
------------------------------------------------------------

local function getRoot()
    local character = LocalPlayer.Character
    if not character then
        return nil
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    if root and root:IsA("BasePart") then
        return root
    end
    return nil
end

local function isCharacterValid()
    local character = LocalPlayer.Character
    if not character then
        return false
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return root
        and root:IsA("BasePart")
        and humanoid
        and humanoid.Health > 0
end

------------------------------------------------------------
-- Mob helpers
------------------------------------------------------------

local function matchMobType(name)
    if type(name) ~= "string" then
        return nil
    end
    for _, kind in ipairs(MOB_BY_LEN) do
        if SelectedMobs[kind] then
            if name == kind then
                return kind
            end
            if name:sub(1, #kind) == kind then
                local rest = name:sub(#kind + 1)
                if rest == "" or rest:match("^%d") or rest:match("^[%s%-%_]") then
                    return kind
                end
            end
        end
    end
    return nil
end

local function getHitbox(mob)
    if not mob or not mob.Parent then
        return nil
    end
    local hitbox = mob:FindFirstChild("Hitbox")
    if hitbox and hitbox:IsA("BasePart") then
        return hitbox
    end
    return nil
end

local function isHitboxAlive(hitbox)
    return hitbox
        and hitbox.Parent
        and hitbox:IsA("BasePart")
end

local function isTargetReady()
    return FarmRunning
        and ActiveMob
        and ActiveHitbox
        and isHitboxAlive(ActiveHitbox)
end

local function startLeftClicker()
    task.spawn(function()
        while AutoLeftClick do
            if isTargetReady() and isrbxactive() then
                mouse1click()
            end
            task.wait(AUTOCLICK_DELAY)
        end
    end)
end

local function startRightClicker()
    task.spawn(function()
        while AutoRightClick do
            if isTargetReady() and isrbxactive() then
                mouse2click()
            end
            task.wait(AUTOCLICK_DELAY)
        end
    end)
end

local function startQClicker()
    task.spawn(function()
        while AutoQ do
            if isTargetReady() and isrbxactive() then
                keyclick(0x51)
            end
            task.wait(AUTOCLICK_DELAY)
        end
    end)
end

local function startRClicker()
    task.spawn(function()
        while AutoR do
            if isTargetReady() and isrbxactive() then
                keyclick(0x52)
            end
            task.wait(AUTOCLICK_DELAY)
        end
    end)
end

local function isMobAlive(mob, hitbox)
    if not mob or not mob.Parent then
        return false
    end
    if not mob:IsA("BasePart") then
        return false
    end
    return isHitboxAlive(hitbox) and getHitbox(mob) == hitbox
end

local function getSelectedLookup(value)
    local selected = {}
    if type(value) ~= "table" then
        return selected
    end
    for _, name in ipairs(value) do
        if type(name) == "string" then
            selected[name] = true
        end
    end
    return selected
end

------------------------------------------------------------
-- Optimized cache (no GetDescendants every frame)
------------------------------------------------------------

local function tryRegister(inst)
    if not inst or not inst:IsA("BasePart") then
        return
    end
    if not matchMobType(inst.Name) then
        -- still allow cache by full lookup for rebuild
        local base = tostring(inst.Name):gsub("%d+$", "")
        if not MobLookup[base] then
            return
        end
    end
    local hitbox = getHitbox(inst)
    if hitbox then
        MobCache[inst] = hitbox
    end
end

local function rebuildCache()
    table.clear(MobCache)
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("BasePart") then
            local base = tostring(inst.Name):gsub("%d+$", "")
            if MobLookup[base] then
                local hitbox = getHitbox(inst)
                if hitbox then
                    MobCache[inst] = hitbox
                end
            end
        end
    end
    LastCacheRebuild = os.clock()
    CacheDirty = false
end

local function ensureCache()
    local now = os.clock()
    if CacheDirty or (now - LastCacheRebuild) >= CACHE_INTERVAL then
        rebuildCache()
    end
end

Workspace.DescendantAdded:Connect(function(inst)
    task.defer(function()
        tryRegister(inst)
        if inst.Name == "Hitbox" and inst.Parent then
            tryRegister(inst.Parent)
        end
    end)
end)

Workspace.DescendantRemoving:Connect(function(inst)
    if MobCache[inst] then
        MobCache[inst] = nil
    end
    if ActiveMob == inst then
        ActiveMob = nil
        ActiveHitbox = nil
        Stuck = false
    end
end)

------------------------------------------------------------
-- Target pick
------------------------------------------------------------

local function findNearestMob()
    if next(SelectedMobs) == nil then
        return nil, nil
    end

    local root = getRoot()
    if not root then
        return nil, nil
    end

    ensureCache()

    local bestMob, bestHitbox = nil, nil
    local bestDist = math.huge
    local origin = root.Position

    for mob, hitbox in pairs(MobCache) do
        if isMobAlive(mob, hitbox) and matchMobType(mob.Name) then
            local d = (origin - hitbox.Position).Magnitude
            if d < bestDist then
                bestDist = d
                bestMob = mob
                bestHitbox = hitbox
            end
        else
            MobCache[mob] = nil
        end
    end

    return bestMob, bestHitbox
end

------------------------------------------------------------
-- Offset CFrame on hitbox
------------------------------------------------------------

local function targetCFrame(hitbox)
    local off = Vector3.new(OffsetX, OffsetY, OffsetZ)
    -- offset in world space relative to hitbox position, face hitbox center
    local pos = hitbox.Position + off
    return CFrame.lookAt(pos, hitbox.Position)
end

------------------------------------------------------------
-- Tween / stick
------------------------------------------------------------

local function stopTween()
    local tw = ActiveTween
    ActiveTween = nil
    if tw then
        pcall(function()
            tw:Cancel()
        end)
    end
end

local function unstick()
    Stuck = false
    stopTween()
    ActiveMob = nil
    ActiveHitbox = nil
end

local function stickTo(hitbox)
    local root = getRoot()
    if not root or not isHitboxAlive(hitbox) then
        return
    end
    root.CFrame = targetCFrame(hitbox)
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
end

local function flyToHitbox(hitbox)
    local root = getRoot()
    if not root or not isHitboxAlive(hitbox) then
        return false
    end

    local goal = targetCFrame(hitbox)
    local dist = (root.Position - goal.Position).Magnitude

    if dist <= StickDistance then
        return true
    end

    stopTween()

    local speed = math.max(1, TweenSpeed)
    local duration = math.max(0.05, dist / speed)

    local tw = TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = goal }
    )
    ActiveTween = tw
    tw:Play()

    local done = false
    local conn
    conn = tw.Completed:Connect(function()
        done = true
        if conn then
            conn:Disconnect()
        end
    end)

    while FarmEnabled and not done do
        if not isCharacterValid() or not isHitboxAlive(hitbox) then
            break
        end
        if ActiveTween ~= tw then
            break
        end
        -- early stick if already close (target moved toward us)
        local r = getRoot()
        if r and (r.Position - targetCFrame(hitbox).Position).Magnitude <= StickDistance then
            done = true
            break
        end
        task.wait()
    end

    if conn then
        conn:Disconnect()
    end
    if ActiveTween == tw then
        stopTween()
    end

    return isHitboxAlive(hitbox)
end

------------------------------------------------------------
-- Heartbeat: while Stuck, glue to hitbox every frame
------------------------------------------------------------

local function bindHeartbeat()
    if HeartbeatConn then
        return
    end
    HeartbeatConn = RunService.Heartbeat:Connect(function()
        if not FarmEnabled or not Stuck then
            return
        end
        if not isCharacterValid() then
            unstick()
            return
        end
        if not isMobAlive(ActiveMob, ActiveHitbox) then
            unstick()
            return
        end
        stickTo(ActiveHitbox)
    end)
end

local function unbindHeartbeat()
    if HeartbeatConn then
        HeartbeatConn:Disconnect()
        HeartbeatConn = nil
    end
end

------------------------------------------------------------
-- Farm loop
------------------------------------------------------------

local function stopFarm()
    FarmEnabled = false
    unstick()
end

local function startFarm()
    if FarmRunning then
        FarmEnabled = true
        bindHeartbeat()
        return
    end

    FarmEnabled = true
    FarmRunning = true
    bindHeartbeat()
    CacheDirty = true

    task.spawn(function()
        while FarmEnabled do
            if not isCharacterValid() then
                unstick()
                task.wait(0.2)
                continue
            end

            if next(SelectedMobs) == nil then
                unstick()
                task.wait(0.15)
                continue
            end

            -- already stuck on living target
            if Stuck and isMobAlive(ActiveMob, ActiveHitbox) then
                task.wait(0.05)
                continue
            end

            -- target gone -> free
            if Stuck then
                unstick()
            end

            local mob, hitbox = findNearestMob()
            if not mob or not hitbox then
                unstick()
                task.wait(0.12)
                continue
            end

            ActiveMob = mob
            ActiveHitbox = hitbox
            Stuck = false

            local ok = flyToHitbox(hitbox)
            if not FarmEnabled then
                break
            end

            if ok and isMobAlive(mob, hitbox) then
                -- glue
                Stuck = true
                ActiveMob = mob
                ActiveHitbox = hitbox
                stickTo(hitbox)
            else
                unstick()
                task.wait(0.05)
            end
        end

        unstick()
        unbindHeartbeat()
        FarmRunning = false
    end)
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------

return function(Window, meta)
    local Tab = Window:CreateTab({
        Name = "BuniFarm",
        Icon = "AF",
        Order = (meta and meta.Order) or 15,
    })

    local FarmSection = Tab:CreateSection({ Name = "Farm" })

    FarmSection:AddToggle({
        Text = "Enable Farm",
        Default = false,
        ConfigKey = "autofarm.enabled",
        Callback = function(Value)
            if Value then
                startFarm()
            else
                stopFarm()
            end
        end,
    })

    FarmSection:AddButton({
        Text = "Start Farm",
        Callback = function()
            startFarm()
        end,
    })

    FarmSection:AddButton({
        Text = "Stop Farm",
        Callback = function()
            stopFarm()
        end,
    })

    ------------------------------------------------------------
    -- Movement
    ------------------------------------------------------------

    local MoveSection = Tab:CreateSection({ Name = "Movement" })

    MoveSection:AddSlider({
        Text = "Tween Speed",
        Min = 1,
        Max = 500,
        Default = 50,
        Increment = 1,
        ConfigKey = "autofarm.tweenSpeed",
        Callback = function(Value)
            TweenSpeed = math.max(1, tonumber(Value) or 50)
            if ActiveTween then
                stopTween()
            end
        end,
    })

    MoveSection:AddSlider({
        Text = "Stick Distance",
        Min = 0.5,
        Max = 15,
        Default = 4,
        Increment = 0.5,
        ConfigKey = "autofarm.stickDistance",
        Callback = function(Value)
            StickDistance = math.max(0.5, tonumber(Value) or 4)
        end,
    })

    ------------------------------------------------------------
    -- Offset (hero relative to Hitbox)
    ------------------------------------------------------------

    local OffSection = Tab:CreateSection({ Name = "Offset (X Y Z)" })

    OffSection:AddLabel({
        Text = "Position of character relative to Hitbox while stuck / flying in.",
    })

    OffSection:AddSlider({
        Text = "Offset X",
        Min = -20,
        Max = 20,
        Default = 0,
        Increment = 0.5,
        ConfigKey = "autofarm.offsetX",
        Callback = function(Value)
            OffsetX = tonumber(Value) or 0
        end,
    })

    OffSection:AddSlider({
        Text = "Offset Y",
        Min = -20,
        Max = 20,
        Default = 3,
        Increment = 0.5,
        ConfigKey = "autofarm.offsetY",
        Callback = function(Value)
            OffsetY = tonumber(Value) or 3
        end,
    })

    OffSection:AddSlider({
        Text = "Offset Z",
        Min = -20,
        Max = 20,
        Default = 0,
        Increment = 0.5,
        ConfigKey = "autofarm.offsetZ",
        Callback = function(Value)
            OffsetZ = tonumber(Value) or 0
        end,
    })

    ------------------------------------------------------------
    -- Mobs
    ------------------------------------------------------------

    local MobSection = Tab:CreateSection({ Name = "Mob Types" })

    SelectedMobs = {}

    MobSection:AddDropdown({
        Text = "Select Mobs",
        Options = MOB_NAMES,
        MultiSelect = true,
        Default = {},
        ConfigKey = "autofarm.mobs",
        Callback = function(Value)
            SelectedMobs = getSelectedLookup(Value)
            CacheDirty = true
            if next(SelectedMobs) == nil then
                unstick()
            end
        end,
    })

    ------------------------------------------------------------
-- Auto Clicker
------------------------------------------------------------

local AutoClickSection = Tab:CreateSection({
    Name = "Auto Clicker"
})

AutoClickSection:AddToggle({
    Text = "Left Click",
    Default = false,
    ConfigKey = "autofarm.autoClick.left",
    Callback = function(Value)
        AutoLeftClick = Value

        if Value then
            startLeftClicker()
        end
    end,
})

AutoClickSection:AddToggle({
    Text = "Right Click",
    Default = false,
    ConfigKey = "autofarm.autoClick.right",
    Callback = function(Value)
        AutoRightClick = Value

        if Value then
            startRightClicker()
        end
    end,
})

AutoClickSection:AddToggle({
    Text = "Q",
    Default = false,
    ConfigKey = "autofarm.autoClick.q",
    Callback = function(Value)
        AutoQ = Value

        if Value then
            startQClicker()
        end
    end,
})

AutoClickSection:AddToggle({
    Text = "R",
    Default = false,
    ConfigKey = "autofarm.autoClick.r",
    Callback = function(Value)
        AutoR = Value

        if Value then
            startRClicker()
        end
    end,
})

    ------------------------------------------------------------
    -- Keybind
    ------------------------------------------------------------

    local KeybindSection = Tab:CreateSection({ Name = "Keybind" })

    KeybindSection:AddKeybind({
        Text = "Toggle Farm",
        Default = Enum.KeyCode.Unknown,
        ConfigKey = "autofarm.toggleKey",
        Callback = function()
            if FarmEnabled then
                stopFarm()
            else
                startFarm()
            end
        end,
    })
end
