local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--========================================================--
-- Configuration
--========================================================--

local MOB_NAMES = {
"Buni",
"DireBuni",
"PlainsWoof",
"Mageling",
"Croakernaut",
"LordFrogg",
"Bulfrogg",
"Toadzerker",
"Dragigator",
"Lilimonster",
"Drone",
"Bumblz",
"Bomber",
"QueenBumblz",
"Puffball",
"SporeBossMan",
"Sporeling",
"Lord Stratos Altolodon",
"Whirlray",
"Caci",
"Slizard",
"CaciKing",
"StoneCleric",
"VoidRoot",
"Bowldur",
"BastionGuardian",
"StoneArcher",
"StoneKnight",
"CrazyHare",
"BaniPrince",
"RedRockHare",
"Batty",
"GlacialSnapper",
"WinterWoof",
"Delta-Spider",
"Stalker",
"Scow",
"SteamGolem",
"Omega-Batty",
"DeepSpider",
"BrainBurner",
"Proto-Mungus",
"Easter",
"Grumpkin",
"THEHALLOWSOUL",
}

local MobLookup = {}

for _, name in ipairs(MOB_NAMES) do
MobLookup[name] = true
end

--========================================================--
-- State
--========================================================--

local FarmEnabled = false
local FarmRunning = false

local ActiveTween = nil
local ActiveTarget = nil
local ActiveHitbox = nil

local TweenSpeed = 50
local StopDistance = 2

local SelectedMobs = {}

local TargetScanDelay = 0.10
local NoTargetDelay = 0.15
local CharacterWaitDelay = 0.25

--========================================================--
-- Character
--========================================================--

local function getCharacter()
return LocalPlayer and LocalPlayer.Character
end

local function getRoot()
local character = getCharacter()

```
if not character then
    return nil
end

local root = character:FindFirstChild("HumanoidRootPart")

if root and root:IsA("BasePart") then
    return root
end

return nil
```

end

local function isCharacterValid()
local character = getCharacter()

```
if not character then
    return false
end

local humanoid = character:FindFirstChildOfClass("Humanoid")
local root = character:FindFirstChild("HumanoidRootPart")

if not humanoid or not root then
    return false
end

if humanoid.Health <= 0 then
    return false
end

return true
```

end

--========================================================--
-- Mob name handling
--========================================================--

local function stripTrailingDigits(name)
return tostring(name):gsub("%d+$", "")
end

local function getBaseMobName(instance)
if not instance then
return nil
end

```
return stripTrailingDigits(instance.Name)
```

end

local function isMob(instance)
if not instance then
return false
end

```
if not instance:IsA("BasePart") then
    return false
end

local baseName = getBaseMobName(instance)

return baseName ~= nil and MobLookup[baseName] == true
```

end

--========================================================--
-- Hitbox
--========================================================--

local function getHitbox(mob)
if not mob then
return nil
end

```
if not mob.Parent then
    return nil
end

local hitbox = mob:FindFirstChild("Hitbox")

if hitbox and hitbox:IsA("BasePart") then
    return hitbox
end

return nil
```

end

local function isTargetValid(mob, hitbox)
if not mob or not mob.Parent then
return false
end

```
if not hitbox or not hitbox.Parent then
    return false
end

if not isMob(mob) then
    return false
end

if getHitbox(mob) ~= hitbox then
    return false
end

return true
```

end

--========================================================--
-- Distance
--========================================================--

local function getDistanceFromPlayer(part)
local root = getRoot()

```
if not root then
    return math.huge
end

if not part or not part.Parent then
    return math.huge
end

return (root.Position - part.Position).Magnitude
```

end

--========================================================--
-- Selected mobs
--========================================================--

local function getSelectedLookup(value)
local selected = {}

```
if type(value) ~= "table" then
    return selected
end

for _, name in ipairs(value) do
    if type(name) == "string" then
        selected[name] = true
    end
end

return selected
```

end

--========================================================--
-- Target search
--========================================================--

local function findNearestMob(selected)
if not selected then
return nil
end

```
if next(selected) == nil then
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

        if selected[baseName] then
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
```

end

--========================================================--
-- Tween control
--========================================================--

local function stopTween()
local tween = ActiveTween

```
ActiveTween = nil
ActiveTarget = nil
ActiveHitbox = nil

if tween then
    pcall(function()
        tween:Cancel()
    end)
end
```

end

local function createTargetTween(hitbox)
local root = getRoot()

```
if not root then
    return nil
end

if not hitbox or not hitbox.Parent then
    return nil
end

local distance = (root.Position - hitbox.Position).Magnitude

if distance <= StopDistance then
    return nil
end

local speed = math.max(1, tonumber(TweenSpeed) or 50)
local duration = distance / speed

local tween = TweenService:Create(
    root,
    TweenInfo.new(
        duration,
        Enum.EasingStyle.Linear,
        Enum.EasingDirection.Out
    ),
    {
        CFrame = hitbox.CFrame
    }
)

return tween
```

end

local function tweenToTarget(mob, hitbox)
if not FarmEnabled then
return false
end

```
if not isCharacterValid() then
    return false
end

if not isTargetValid(mob, hitbox) then
    return false
end

local root = getRoot()

if not root then
    return false
end

local distance = (root.Position - hitbox.Position).Magnitude

if distance <= StopDistance then
    return true
end

stopTween()

local tween = createTargetTween(hitbox)

if not tween then
    return true
end

ActiveTween = tween
ActiveTarget = mob
ActiveHitbox = hitbox

local finished = false
local cancelled = false

local connection

connection = tween.Completed:Connect(function()
    finished = true

    if connection then
        connection:Disconnect()
        connection = nil
    end
end)

tween:Play()

while FarmEnabled and not finished do
    if not isCharacterValid() then
        cancelled = true
        break
    end

    if not isTargetValid(mob, hitbox) then
        cancelled = true
        break
    end

    if ActiveTween ~= tween then
        cancelled = true
        break
    end

    local currentRoot = getRoot()

    if not currentRoot then
        cancelled = true
        break
    end

    local currentDistance =
        (currentRoot.Position - hitbox.Position).Magnitude

    if currentDistance <= StopDistance then
        cancelled = true
        break
    end

    task.wait()
end

if connection then
    connection:Disconnect()
    connection = nil
end

if cancelled or not FarmEnabled then
    pcall(function()
        tween:Cancel()
    end)

    if ActiveTween == tween then
        ActiveTween = nil
        ActiveTarget = nil
        ActiveHitbox = nil
    end

    return false
end

if ActiveTween == tween then
    ActiveTween = nil
    ActiveTarget = nil
    ActiveHitbox = nil
end

return true
```

end

--========================================================--
-- Farm control
--========================================================--

local function stopFarm()
FarmEnabled = false

```
stopTween()
```

end

local function startFarm()
if FarmRunning then
FarmEnabled = true
return
end

```
FarmEnabled = true
FarmRunning = true

task.spawn(function()
    while FarmEnabled do

        -- Character not ready / dead
        if not isCharacterValid() then
            stopTween()
            task.wait(CharacterWaitDelay)
            continue
        end

        -- No selected mobs
        if next(SelectedMobs) == nil then
            stopTween()
            task.wait(NoTargetDelay)
            continue
        end

        -- Find nearest selected mob
        local mob = findNearestMob(SelectedMobs)

        if not mob then
            stopTween()
            task.wait(NoTargetDelay)
            continue
        end

        -- Get current hitbox
        local hitbox = getHitbox(mob)

        if not hitbox then
            task.wait(TargetScanDelay)
            continue
        end

        -- Save current target
        ActiveTarget = mob
        ActiveHitbox = hitbox

        -- Move toward target
        tweenToTarget(mob, hitbox)

        -- Target may have disappeared during tween.
        -- Loop immediately searches for another one.
        if FarmEnabled then
            task.wait(TargetScanDelay)
        end
    end

    stopTween()

    FarmRunning = false
end)
```

end

--========================================================--
-- GUI
--========================================================--

return function(Window, meta)

```
local Tab = Window:CreateTab({
    Name = "BuniFarm",
    Icon = "🐰",
    Order = (meta and meta.Order) or 30,
})

--====================================================--
-- Farm section
--====================================================--

local FarmSection = Tab:CreateSection({
    Name = "Farm"
})

FarmSection:AddToggle({
    Text = "Enable Farm",
    Default = false,
    Callback = function(Value)
        if Value then
            startFarm()
        else
            stopFarm()
        end
    end
})

FarmSection:AddButton({
    Text = "Start Farm",
    Callback = function()
        startFarm()
    end
})

FarmSection:AddButton({
    Text = "Stop Farm",
    Callback = function()
        stopFarm()
    end
})

--====================================================--
-- Tween section
--====================================================--

local SpeedSection = Tab:CreateSection({
    Name = "Tween"
})

SpeedSection:AddSlider({
    Text = "Tween Speed",
    Min = 1,
    Max = 500,
    Default = 50,
    Increment = 1,
    Callback = function(Value)
        TweenSpeed = math.max(1, tonumber(Value) or 50)

        -- Restart movement with the new speed.
        if ActiveTween then
            stopTween()
        end
    end
})

SpeedSection:AddSlider({
    Text = "Stop Distance",
    Min = 0,
    Max = 10,
    Default = 2,
    Increment = 0.5,
    Callback = function(Value)
        StopDistance = math.max(0, tonumber(Value) or 2)
    end
})

--====================================================--
-- Mob selection
--====================================================--

local MobSection = Tab:CreateSection({
    Name = "Mob Types"
})

MobSection:AddDropdown({
    Text = "Select Mobs",
    Options = MOB_NAMES,
    MultiSelect = true,
    Default = MOB_NAMES,
    Callback = function(Value)

        SelectedMobs = getSelectedLookup(Value)

        -- If everything was deselected,
        -- immediately stop the current movement.
        if next(SelectedMobs) == nil then
            stopTween()
        end
    end
})

--====================================================--
-- Keybind
--====================================================--

local KeybindSection = Tab:CreateSection({
    Name = "Keybind"
})

KeybindSection:AddKeybind({
    Text = "Toggle Farm",
    Default = Enum.KeyCode.F,
    Callback = function()
        if FarmEnabled then
            stopFarm()
        else
            startFarm()
        end
    end
})

--====================================================--
-- Initial selection
--====================================================--

SelectedMobs = getSelectedLookup(MOB_NAMES)
```

end
