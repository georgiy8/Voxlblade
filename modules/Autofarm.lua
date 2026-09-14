local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

--========================================================--
-- MOB LIST
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

for _, mobName in ipairs(MOB_NAMES) do
MobLookup[mobName] = true
end

--========================================================--
-- STATE
--========================================================--

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

--========================================================--
-- CHARACTER
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

local function getHumanoid()
local character = getCharacter()

```
if not character then
    return nil
end

return character:FindFirstChildOfClass("Humanoid")
```

end

local function isCharacterValid()
local character = getCharacter()

```
if not character then
    return false
end

local root = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")

if not root or not root:IsA("BasePart") then
    return false
end

if not humanoid then
    return false
end

if humanoid.Health <= 0 then
    return false
end

return true
```

end

--========================================================--
-- MOB NAME
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

--========================================================--
-- MOB DETECTION
----------------

## -- Mob structure:

-- Buni07        <- MeshPart
-- └── Hitbox    <- MeshPart
----------------------------

-- Same structure applies to other mobs.
--========================================================--

local function isMob(instance)
if not instance then
return false
end

```
-- The actual mob body is a MeshPart/BasePart.
if not instance:IsA("BasePart") then
    return false
end

local baseName = getBaseMobName(instance)

if not baseName then
    return false
end

if not MobLookup[baseName] then
    return false
end

return true
```

end

local function getHitbox(mob)
if not mob then
return nil
end

```
if not mob.Parent then
    return nil
end

-- Hitbox is a MeshPart and is a direct child.
local hitbox = mob:FindFirstChild("Hitbox")

if hitbox and hitbox:IsA("BasePart") then
    return hitbox
end

return nil
```

end

local function isValidMob(mob)
if not mob then
return false
end

```
if not mob.Parent then
    return false
end

if not mob:IsA("BasePart") then
    return false
end

if not isMob(mob) then
    return false
end

return getHitbox(mob) ~= nil
```

end

local function isValidHitbox(hitbox)
if not hitbox then
return false
end

```
if not hitbox.Parent then
    return false
end

if not hitbox:IsA("BasePart") then
    return false
end

return true
```

end

--========================================================--
-- SELECTED MOBS
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
-- DISTANCE
--========================================================--

local function getDistanceFromPlayer(part)
local root = getRoot()

```
if not root then
    return math.huge
end

if not isValidHitbox(part) then
    return math.huge
end

return (root.Position - part.Position).Magnitude
```

end

--========================================================--
-- FIND NEAREST MOB
--========================================================--

local function findNearestMob()
if next(SelectedMobs) == nil then
return nil
end

```
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

                local distance =
                    (root.Position - hitbox.Position).Magnitude

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
-- CURRENT TARGET VALIDATION
--========================================================--

local function isCurrentTargetValid(mob, hitbox)
if not FarmEnabled then
return false
end

```
if not isCharacterValid() then
    return false
end

if not isValidMob(mob) then
    return false
end

if not isValidHitbox(hitbox) then
    return false
end

local currentHitbox = getHitbox(mob)

if currentHitbox ~= hitbox then
    return false
end

local baseName = getBaseMobName(mob)

if not baseName then
    return false
end

if not SelectedMobs[baseName] then
    return false
end

return true
```

end

--========================================================--
-- TWEEN CONTROL
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

local function createTween(hitbox)
local root = getRoot()

```
if not root then
    return nil
end

if not isValidHitbox(hitbox) then
    return nil
end

local distance =
    (root.Position - hitbox.Position).Magnitude

if distance <= StopDistance then
    return nil
end

local speed = tonumber(TweenSpeed) or 50

if speed < 1 then
    speed = 1
end

local duration = distance / speed

if duration < 0.01 then
    duration = 0.01
end

return TweenService:Create(
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
```

end

local function tweenToHitbox(mob, hitbox)
if not FarmEnabled then
return false
end

```
if not isCurrentTargetValid(mob, hitbox) then
    return false
end

local root = getRoot()

if not root then
    return false
end

local distance =
    (root.Position - hitbox.Position).Magnitude

if distance <= StopDistance then
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
local cancelled = false

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

    if not isCharacterValid() then
        cancelled = true
        break
    end

    if not isCurrentTargetValid(mob, hitbox) then
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
-- FARM LOOP
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

        -- Character check
        if not isCharacterValid() then
            stopTween()
            task.wait(CharacterWaitDelay)
            continue
        end

        -- Mob selection check
        if next(SelectedMobs) == nil then
            stopTween()
            task.wait(NoTargetDelay)
            continue
        end

        -- Find nearest selected mob
        local mob = findNearestMob()

        if not mob then
            stopTween()
            task.wait(NoTargetDelay)
            continue
        end

        -- Get MeshPart Hitbox
        local hitbox = getHitbox(mob)

        if not hitbox then
            task.wait(TargetSearchDelay)
            continue
        end

        -- Save target
        ActiveTarget = mob
        ActiveHitbox = hitbox

        -- Tween to the Hitbox
        tweenToHitbox(mob, hitbox)

        -- If target disappeared / died / changed,
        -- immediately search for another one.
        if FarmEnabled then
            task.wait(TargetSearchDelay)
        end
    end

    stopTween()

    FarmRunning = false
end)
```

end

--========================================================--
-- GUI MODULE
--========================================================--

return function(Window, meta)

```
local Tab = Window:CreateTab({
    Name = "BuniFarm",
    Icon = "🐰",
    Order = (meta and meta.Order) or 15,
})

--====================================================--
-- FARM
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
-- TWEEN
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
        TweenSpeed = math.max(
            1,
            tonumber(Value) or 50
        )

        -- Restart movement using the new speed.
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
        StopDistance = math.max(
            0,
            tonumber(Value) or 2
        )
    end
})

--====================================================--
-- MOB TYPES
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

        -- Nothing selected:
        -- stop the current movement but keep
        -- the farm system ready.
        if next(SelectedMobs) == nil then
            stopTween()
        end
    end
})

--====================================================--
-- KEYBIND
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
-- DEFAULT MOB SELECTION
--====================================================--

SelectedMobs = getSelectedLookup(MOB_NAMES)
```

end
