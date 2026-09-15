--========================================================--
-- Autofarm Module (Voxlblade)
-- Tween to mob Hitbox + mob multi-select
--========================================================--

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
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

local MobLookup = {}
for _, name in ipairs(MOB_NAMES) do
    MobLookup[name] = true
end

local FarmEnabled = false
local FarmRunning = false
local ActiveTween = nil
local ActiveTarget = nil
local ActiveHitbox = nil
local TweenSpeed = 50
local StopDistance = 2
local SelectedMobs = {}

local TargetSearchDelay = 0.05
local NoTargetDelay = 0.10
local CharacterWaitDelay = 0.20

------------------------------------------------------------
-- Character
------------------------------------------------------------

local function getCharacter()
    return LocalPlayer and LocalPlayer.Character
end

local function getRoot()
    local character = getCharacter()
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
    local character = getCharacter()
    if not character then
        return false
    end
    local root = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not root or not root:IsA("BasePart") then
        return false
    end
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    return true
end

------------------------------------------------------------
-- Mobs: MeshPart "Buni07" -> child Hitbox
------------------------------------------------------------

local function getBaseMobName(instance)
    if not instance then
        return nil
    end
    return tostring(instance.Name):gsub("%d+$", "")
end

local function isMob(instance)
    if not instance or not instance:IsA("BasePart") then
        return false
    end
    local baseName = getBaseMobName(instance)
    return baseName ~= nil and MobLookup[baseName] == true
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

local function isValidMob(mob)
    return mob
        and mob.Parent
        and mob:IsA("BasePart")
        and isMob(mob)
        and getHitbox(mob) ~= nil
end

local function isValidHitbox(hitbox)
    return hitbox and hitbox.Parent and hitbox:IsA("BasePart")
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
-- Find nearest
------------------------------------------------------------

local function findNearestMob()
    if next(SelectedMobs) == nil then
        return nil
    end
    local root = getRoot()
    if not root then
        return nil
    end

    local nearestMob = nil
    local nearestDistance = math.huge

    for _, instance in ipairs(Workspace:GetDescendants()) do
        if isMob(instance) then
            local baseName = getBaseMobName(instance)
            if baseName and SelectedMobs[baseName] then
                local hitbox = getHitbox(instance)
                if hitbox then
                    local distance = (root.Position - hitbox.Position).Magnitude
                    if distance < nearestDistance then
                        nearestDistance = distance
                        nearestMob = instance
                    end
                end
            end
        end
    end

    return nearestMob
end

local function isCurrentTargetValid(mob, hitbox)
    if not FarmEnabled or not isCharacterValid() then
        return false
    end
    if not isValidMob(mob) or not isValidHitbox(hitbox) then
        return false
    end
    if getHitbox(mob) ~= hitbox then
        return false
    end
    local baseName = getBaseMobName(mob)
    if not baseName or not SelectedMobs[baseName] then
        return false
    end
    return true
end

------------------------------------------------------------
-- Tween
------------------------------------------------------------

local function stopTween()
    local tween = ActiveTween
    ActiveTween = nil
    ActiveTarget = nil
    ActiveHitbox = nil
    if tween then
        pcall(function()
            tween:Cancel()
        end)
    end
end

local function createTween(hitbox)
    local root = getRoot()
    if not root or not isValidHitbox(hitbox) then
        return nil
    end

    local distance = (root.Position - hitbox.Position).Magnitude
    if distance <= StopDistance then
        return nil
    end

    local speed = math.max(1, tonumber(TweenSpeed) or 50)
    local duration = math.max(0.01, distance / speed)

    return TweenService:Create(
        root,
        TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
        { CFrame = hitbox.CFrame }
    )
end

local function tweenToHitbox(mob, hitbox)
    if not FarmEnabled or not isCurrentTargetValid(mob, hitbox) then
        return false
    end

    local root = getRoot()
    if not root then
        return false
    end

    if (root.Position - hitbox.Position).Magnitude <= StopDistance then
        return true
    end

    stopTween()

    local tween = createTween(hitbox)
    if not tween then
        return true
    end

    ActiveTween = tween
    ActiveTarget = mob
    ActiveHitbox = hitbox

    local completed = false
    local connection
    connection = tween.Completed:Connect(function()
        completed = true
        if connection then
            connection:Disconnect()
            connection = nil
        end
    end)

    tween:Play()

    while FarmEnabled and not completed do
        if not isCharacterValid() or not isCurrentTargetValid(mob, hitbox) then
            break
        end
        if ActiveTween ~= tween then
            break
        end
        local currentRoot = getRoot()
        if not currentRoot then
            break
        end
        if (currentRoot.Position - hitbox.Position).Magnitude <= StopDistance then
            break
        end
        task.wait()
    end

    if connection then
        connection:Disconnect()
    end

    pcall(function()
        tween:Cancel()
    end)

    if ActiveTween == tween then
        ActiveTween = nil
        ActiveTarget = nil
        ActiveHitbox = nil
    end

    return completed
end

------------------------------------------------------------
-- Farm loop
------------------------------------------------------------

local function stopFarm()
    FarmEnabled = false
    stopTween()
end

local function startFarm()
    if FarmRunning then
        FarmEnabled = true
        return
    end

    FarmEnabled = true
    FarmRunning = true

    task.spawn(function()
        while FarmEnabled do
            if not isCharacterValid() then
                stopTween()
                task.wait(CharacterWaitDelay)
                continue
            end

            if next(SelectedMobs) == nil then
                stopTween()
                task.wait(NoTargetDelay)
                continue
            end

            local mob = findNearestMob()
            if not mob then
                stopTween()
                task.wait(NoTargetDelay)
                continue
            end

            local hitbox = getHitbox(mob)
            if not hitbox then
                task.wait(TargetSearchDelay)
                continue
            end

            ActiveTarget = mob
            ActiveHitbox = hitbox
            tweenToHitbox(mob, hitbox)

            if FarmEnabled then
                task.wait(TargetSearchDelay)
            end
        end

        stopTween()
        FarmRunning = false
    end)
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------

return function(Window, meta)
    local Tab = Window:CreateTab({
        Name = "BuniFarm",
        Icon = "🐰",
        Order = (meta and meta.Order) or 15,
    })

    local FarmSection = Tab:CreateSection({ Name = "Farm" })

    FarmSection:AddToggle({
        Text = "Enable Farm",
        Default = false,
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

    local SpeedSection = Tab:CreateSection({ Name = "Tween" })

    SpeedSection:AddSlider({
        Text = "Tween Speed",
        Min = 1,
        Max = 500,
        Default = 50,
        Increment = 1,
        Callback = function(Value)
            TweenSpeed = math.max(1, tonumber(Value) or 50)
            if ActiveTween then
                stopTween()
            end
        end,
    })

    SpeedSection:AddSlider({
        Text = "Stop Distance",
        Min = 0,
        Max = 10,
        Default = 2,
        Increment = 0.5,
        Callback = function(Value)
            StopDistance = math.max(0, tonumber(Value) or 2)
        end,
    })

    local MobSection = Tab:CreateSection({ Name = "Mob Types" })

    SelectedMobs = getSelectedLookup(MOB_NAMES)

    MobSection:AddDropdown({
        Text = "Select Mobs",
        Options = MOB_NAMES,
        MultiSelect = true,
        Default = MOB_NAMES,
        Callback = function(Value)
            SelectedMobs = getSelectedLookup(Value)
            if next(SelectedMobs) == nil then
                stopTween()
            end
        end,
    })

    local KeybindSection = Tab:CreateSection({ Name = "Keybind" })

    KeybindSection:AddKeybind({
        Text = "Toggle Farm",
        Default = Enum.KeyCode.F,
        Callback = function()
            if FarmEnabled then
                stopFarm()
            else
                startFarm()
            end
        end,
    })
end
