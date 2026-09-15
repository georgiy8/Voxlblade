--========================================================--
-- Visual Module
-- Player ESP | Mob ESP | Stand / Stand2 | Hive exits
--========================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

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

-- Per-mob ESP colors
local MOB_COLORS = {
    ["Buni"] = Color3.fromRGB(255, 255, 255),
    ["DireBuni"] = Color3.fromRGB(225, 225, 225),
    ["PlainsWoof"] = Color3.fromRGB(145, 145, 145),
    ["Mageling"] = Color3.fromRGB(70, 130, 255),
    ["Croakernaut"] = Color3.fromRGB(150, 95, 55),
    ["LordFrogg"] = Color3.fromRGB(35, 95, 45),
    ["Bulfrogg"] = Color3.fromRGB(140, 220, 80),
    ["Toadzerker"] = Color3.fromRGB(50, 255, 70),
    ["Dragigator"] = Color3.fromRGB(45, 170, 70),
    ["Lilimonster"] = Color3.fromRGB(170, 125, 90),
    ["Drone"] = Color3.fromRGB(255, 245, 40),
    ["Bumblz"] = Color3.fromRGB(235, 205, 40),
    ["Bomber"] = Color3.fromRGB(255, 145, 40),
    ["QueenBumblz"] = Color3.fromRGB(255, 205, 45),
    ["Puffball"] = Color3.fromRGB(220, 90, 190),
    ["SporeBossMan"] = Color3.fromRGB(255, 105, 170),
    ["Sporeling"] = Color3.fromRGB(35, 175, 255),
    ["Lord Stratos Altolodon"] = Color3.fromRGB(235, 235, 245),
    ["Whirlray"] = Color3.fromRGB(175, 190, 195),
    ["Caci"] = Color3.fromRGB(70, 180, 75),
    ["Slizard"] = Color3.fromRGB(145, 95, 60),
    ["CaciKing"] = Color3.fromRGB(25, 105, 45),
    ["StoneCleric"] = Color3.fromRGB(145, 105, 70),
    ["VoidRoot"] = Color3.fromRGB(125, 105, 145),
    ["Bowldur"] = Color3.fromRGB(145, 105, 75),
    ["BastionGuardian"] = Color3.fromRGB(130, 100, 70),
    ["StoneArcher"] = Color3.fromRGB(155, 115, 80),
    ["StoneKnight"] = Color3.fromRGB(120, 90, 65),
    ["CrazyHare"] = Color3.fromRGB(145, 145, 145),
    ["BaniPrince"] = Color3.fromRGB(155, 105, 70),
    ["RedRockHare"] = Color3.fromRGB(65, 65, 70),
    ["Batty"] = Color3.fromRGB(60, 60, 65),
    ["GlacialSnapper"] = Color3.fromRGB(50, 220, 255),
    ["WinterWoof"] = Color3.fromRGB(255, 255, 255),
    ["Delta-Spider"] = Color3.fromRGB(225, 230, 235),
    ["Stalker"] = Color3.fromRGB(255, 60, 190),
    ["Scow"] = Color3.fromRGB(145, 95, 65),
    ["SteamGolem"] = Color3.fromRGB(190, 105, 55),
    ["Omega-Batty"] = Color3.fromRGB(55, 55, 60),
    ["DeepSpider"] = Color3.fromRGB(225, 215, 240),
    ["BrainBurner"] = Color3.fromRGB(255, 80, 25),
    ["Proto-Mungus"] = Color3.fromRGB(245, 190, 215),
    ["Easter"] = Color3.fromRGB(255, 125, 190),
    ["Grumpkin"] = Color3.fromRGB(220, 125, 35),
    ["THEHALLOWSOUL"] = Color3.fromRGB(70, 45, 25),
}

local MOB_BY_LEN = table.clone(MOB_NAMES)
table.sort(MOB_BY_LEN, function(a, b)
    return #a > #b
end)

local MUTATIONS = { "Legendary", "Magical", "Corrupt", "Bloody" }

local MUTATION_COLORS = {
    Legendary = Color3.fromRGB(255, 215, 0),
    Magical = Color3.fromRGB(0, 140, 255),
    Corrupt = Color3.fromRGB(175, 70, 255),
    Bloody = Color3.fromRGB(190, 20, 25),
}

local STAND_NAMES = { "Stand", "Stand2" }

local function hasDrawing()
    return type(Drawing) == "table" and type(Drawing.new) == "function"
end

local function destroyLine(line)
    if not line then
        return
    end
    pcall(function()
        line:Remove()
    end)
    pcall(function()
        line:Destroy()
    end)
end

return function(Window, meta)

    local Tab = Window:CreateTab({
        Name = "Visual",
        Icon = "V",
        Order = (meta and meta.Order) or 45,
    })

    ------------------------------------------------------------
    -- Shared folders
    ------------------------------------------------------------

    local PlayerFolder = Instance.new("Folder")
    PlayerFolder.Name = "UMU_PlayerESP"
    PlayerFolder.Parent = CoreGui

    local MobFolder = Instance.new("Folder")
    MobFolder.Name = "UMU_MobESP"
    MobFolder.Parent = CoreGui

    local StandFolder = Instance.new("Folder")
    StandFolder.Name = "UMU_StandESP"
    StandFolder.Parent = CoreGui

    ------------------------------------------------------------
    -- Player ESP state
    ------------------------------------------------------------

    local PState = {
        TextESP = false,
        BoxESP = false,
        TracerESP = false,
        Color = Color3.fromRGB(120, 200, 255),
        SelectedPlayers = {},
    }

    local playerDrawings = {}

    local function playerIsTarget(player)
        if player == LocalPlayer then
            return false
        end
        local list = PState.SelectedPlayers
        if type(list) ~= "table" or #list == 0 then
            return true
        end
        for _, name in ipairs(list) do
            if name == player.Name then
                return true
            end
        end
        return false
    end

    local function clearPlayer(player)
        local pack = playerDrawings[player]
        if not pack then
            return
        end
        if pack.highlight then
            pack.highlight:Destroy()
        end
        if pack.billboard then
            pack.billboard:Destroy()
        end
        destroyLine(pack.line)
        playerDrawings[player] = nil
    end

    local function ensurePlayerPack(player, character)
        local pack = playerDrawings[player]
        if pack then
            return pack
        end

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return nil
        end

        pack = {}

        local hl = Instance.new("Highlight")
        hl.Name = "PlayerBoxESP"
        hl.Adornee = character
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = PState.Color
        hl.OutlineColor = PState.Color
        hl.Enabled = PState.BoxESP
        hl.Parent = PlayerFolder
        pack.highlight = hl

        local bb = Instance.new("BillboardGui")
        bb.Name = "PlayerTextESP"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(200, 54)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.Adornee = hrp
        bb.Enabled = PState.TextESP
        bb.Parent = PlayerFolder

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextColor3 = PState.Color
        label.TextStrokeTransparency = 0.4
        label.Text = player.Name
        label.Parent = bb
        pack.billboard = bb
        pack.label = label

        if hasDrawing() then
            local line = Drawing.new("Line")
            line.Thickness = 1
            line.Color = PState.Color
            line.Visible = false
            pack.line = line
        end

        playerDrawings[player] = pack
        return pack
    end

    local function applyPlayerColor()
        for _, pack in pairs(playerDrawings) do
            if pack.highlight then
                pack.highlight.FillColor = PState.Color
                pack.highlight.OutlineColor = PState.Color
            end
            if pack.label then
                pack.label.TextColor3 = PState.Color
            end
            if pack.line then
                pack.line.Color = PState.Color
            end
        end
    end

    ------------------------------------------------------------
    -- Player ESP UI
    ------------------------------------------------------------

    local PlayerSec = Tab:CreateSection({ Name = "Player ESP" })

    PlayerSec:AddToggle({
        Text = "Name / Health / Distance",
        Default = false,
        ConfigKey = "visual.player.text",
        Callback = function(v)
            PState.TextESP = v
        end,
    })

    PlayerSec:AddToggle({
        Text = "Box (Highlight)",
        Default = false,
        ConfigKey = "visual.player.box",
        Callback = function(v)
            PState.BoxESP = v
        end,
    })

    PlayerSec:AddToggle({
        Text = "Tracer (screen center)",
        Default = false,
        ConfigKey = "visual.player.tracer",
        Callback = function(v)
            PState.TracerESP = v
            if not v then
                for _, pack in pairs(playerDrawings) do
                    if pack.line then
                        pack.line.Visible = false
                    end
                end
            end
        end,
    })

    PlayerSec:AddSlider({
        Text = "Color R",
        Min = 0,
        Max = 255,
        Default = 120,
        Increment = 1,
        ConfigKey = "visual.player.r",
        Callback = function(v)
            PState.Color = Color3.fromRGB(v, PState.Color.G * 255, PState.Color.B * 255)
            applyPlayerColor()
        end,
    })

    PlayerSec:AddSlider({
        Text = "Color G",
        Min = 0,
        Max = 255,
        Default = 200,
        Increment = 1,
        ConfigKey = "visual.player.g",
        Callback = function(v)
            PState.Color = Color3.fromRGB(PState.Color.R * 255, v, PState.Color.B * 255)
            applyPlayerColor()
        end,
    })

    PlayerSec:AddSlider({
        Text = "Color B",
        Min = 0,
        Max = 255,
        Default = 255,
        Increment = 1,
        ConfigKey = "visual.player.b",
        Callback = function(v)
            PState.Color = Color3.fromRGB(PState.Color.R * 255, PState.Color.G * 255, v)
            applyPlayerColor()
        end,
    })

    local function playerNameList()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(names, p.Name)
            end
        end
        table.sort(names)
        return names
    end

    local playerDrop = PlayerSec:AddDropdown({
        Text = "Players (multi)",
        MultiSelect = true,
        Options = playerNameList(),
        Default = {},
        ConfigKey = "visual.player.filter",
        Callback = function(list)
            PState.SelectedPlayers = list or {}
        end,
    })

    PlayerSec:AddButton({
        Text = "Refresh player list",
        Callback = function()
            if playerDrop and playerDrop.SetValues then
                playerDrop:SetValues(playerNameList())
            end
        end,
    })

    ------------------------------------------------------------
    -- Mob ESP + Mutations
    -- Mob ESP and mutation ESP are independent.
    -- Mob cache is event-driven; no workspace:GetDescendants() every frame.
    ------------------------------------------------------------

    local MState = {
        Enabled = false,
        TextESP = true,
        BoxESP = true,
        MutationEnabled = false,
        Color = Color3.fromRGB(255, 180, 80),
        MutationColor = Color3.fromRGB(255, 90, 90),
        SelectedMobs = {},
        SelectedMutations = {},
    }

    local mobDrawings = {}
    local mutationDrawings = {}
    local mobCache = {}
    local mobConnections = {}

    local function selectedSet(list)
        local set = {}
        if type(list) ~= "table" then
            return set
        end
        for _, name in ipairs(list) do
            if type(name) == "string" then
                set[name] = true
            end
        end
        return set
    end

    local MOB_SET = {}
    for _, name in ipairs(MOB_NAMES) do
        MOB_SET[name] = true
    end

    local function matchMobType(name)
        if type(name) ~= "string" then
            return nil
        end

        if MOB_SET[name] then
            return name
        end

        -- Handles Buni07 / Omega-Batty05 / etc. without scanning the
        -- entire mob list on every RenderStepped.
        local base = name:match("^(.-)%d+$")
        if base and MOB_SET[base] then
            return base
        end

        for _, kind in ipairs(MOB_BY_LEN) do
            if name:sub(1, #kind) == kind then
                local rest = name:sub(#kind + 1)
                if rest ~= "" and (rest:match("^%d") or rest:match("^[%s%-%_]")) then
                    return kind
                end
            end
        end
        return nil
    end

    local function getHitbox(root)
        if not root then
            return nil
        end
        if root:IsA("BasePart") and root.Name == "Hitbox" then
            return root
        end
        local h = root:FindFirstChild("Hitbox")
        if h and h:IsA("BasePart") then
            return h
        end
        return nil
    end

    local function mutationOn(root, mut)
        if not root then
            return false
        end
        local particle = root:FindFirstChild(mut, true)
        local light = root:FindFirstChild(mut .. "L", true)
        if not particle or not light then
            return false
        end

        local pOk = not (particle:IsA("ParticleEmitter") or particle:IsA("Beam") or particle:IsA("Trail")) or particle.Enabled
        local lOk = not (light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight")) or light.Enabled
        return pOk and lOk
    end

    local function activeMutations(root)
        local found = {}
        if not MState.MutationEnabled then
            return found
        end
        for mut in pairs(MState.SelectedMutations) do
            if mutationOn(root, mut) then
                found[#found + 1] = mut
            end
        end
        return found
    end

    local function getMobColor(kind)
        return MOB_COLORS[kind] or MState.Color
    end

    local function getMutationColor(active)
        for _, mut in ipairs(MUTATIONS) do
            if active[mut] then
                return MUTATION_COLORS[mut] or MState.MutationColor
            end
        end
        return MState.MutationColor
    end

    local function activeMutationSet(root)
        local found = {}
        if not MState.MutationEnabled then
            return found
        end
        for _, mut in ipairs(MUTATIONS) do
            if MState.SelectedMutations[mut] and mutationOn(root, mut) then
                found[mut] = true
            end
        end
        return found
    end

    local function clearMob(inst)
        local pack = mobDrawings[inst]
        if not pack then return end
        if pack.highlight then pack.highlight:Destroy() end
        if pack.billboard then pack.billboard:Destroy() end
        destroyLine(pack.line)
        mobDrawings[inst] = nil
    end

    local function clearMutation(inst)
        local pack = mutationDrawings[inst]
        if not pack then return end
        destroyLine(pack.line)
        if pack.highlight then pack.highlight:Destroy() end
        if pack.billboard then pack.billboard:Destroy() end
        mutationDrawings[inst] = nil
    end

    local function clearAllMobs()
        for inst in pairs(mobDrawings) do clearMob(inst) end
        for inst in pairs(mutationDrawings) do clearMutation(inst) end
    end

    local function ensureMobPack(inst, hitbox, kind)
        local pack = mobDrawings[inst]
        if pack then return pack end

        pack = {}
        local hl = Instance.new("Highlight")
        hl.Name = "MobBoxESP"
        hl.Adornee = inst
        hl.FillTransparency = 0.65
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        local mobColor = getMobColor(kind)
        hl.FillColor = mobColor
        hl.OutlineColor = mobColor
        hl.Enabled = MState.BoxESP
        hl.Parent = MobFolder
        pack.highlight = hl

        local bb = Instance.new("BillboardGui")
        bb.Name = "MobTextESP"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(220, 48)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.Adornee = hitbox
        bb.Enabled = MState.TextESP
        bb.Parent = MobFolder

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 13
        label.TextColor3 = mobColor
        label.TextStrokeTransparency = 0.4
        label.Text = inst.Name
        label.Parent = bb
        pack.billboard = bb
        pack.label = label

        mobDrawings[inst] = pack
        return pack
    end

    local function ensureMutationPack(inst, hitbox)
        local pack = mutationDrawings[inst]
        if pack then return pack end

        pack = {}
        local hl = Instance.new("Highlight")
        hl.Name = "MobMutationESP"
        hl.Adornee = inst
        hl.FillTransparency = 0.85
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = MState.MutationColor
        hl.OutlineColor = MState.MutationColor
        hl.Parent = MobFolder
        pack.highlight = hl

        local bb = Instance.new("BillboardGui")
        bb.Name = "MobMutationText"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(220, 30)
        bb.StudsOffset = Vector3.new(0, 3.8, 0)
        bb.Adornee = hitbox
        bb.Parent = MobFolder

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 13
        label.TextColor3 = MState.MutationColor
        label.TextStrokeTransparency = 0.35
        label.Text = ""
        label.Parent = bb
        pack.billboard = bb
        pack.label = label

        if hasDrawing() then
            local line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Color = MState.MutationColor
            line.Visible = false
            pack.line = line
        end

        mutationDrawings[inst] = pack
        return pack
    end

    local function isValidMob(inst)
        if not inst or not inst.Parent or not inst:IsA("BasePart") then return false end
        local kind = matchMobType(inst.Name)
        if not kind then return false end

        -- Empty mob selection means "all mobs" for mutation ESP.
        -- This keeps Mutations completely independent from Mob ESP.
        local hasMobFilter = next(MState.SelectedMobs) ~= nil
        if hasMobFilter and not MState.SelectedMobs[kind] then
            return false
        end

        return getHitbox(inst) ~= nil
    end

    local function unregisterMob(inst)
        mobCache[inst] = nil
        clearMob(inst)
        clearMutation(inst)
    end

    local function registerMob(inst)
        if not inst:IsA("BasePart") then return end
        local kind = matchMobType(inst.Name)
        if not kind then return end
        local hitbox = getHitbox(inst)
        if not hitbox then return end
        mobCache[inst] = { kind = kind, hitbox = hitbox }
    end

    local function scanMobsOnce()
        for _, inst in ipairs(workspace:GetDescendants()) do
            registerMob(inst)
        end
    end

    local function rebuildMobConnections()
        for _, c in ipairs(mobConnections) do c:Disconnect() end
        table.clear(mobConnections)
        mobConnections[#mobConnections + 1] = workspace.DescendantAdded:Connect(function(inst)
            registerMob(inst)
            -- A Hitbox can be added after the mob itself.
            local parent = inst.Parent
            if parent and parent:IsA("BasePart") and inst.Name == "Hitbox" then
                registerMob(parent)
            end
        end)
        mobConnections[#mobConnections + 1] = workspace.DescendantRemoving:Connect(function(inst)
            unregisterMob(inst)
        end)
    end

    scanMobsOnce()
    rebuildMobConnections()

    local MobSec = Tab:CreateSection({ Name = "Mob ESP" })

    MobSec:AddToggle({
        Text = "Enable Mob ESP",
        Default = false,
        ConfigKey = "visual.mob.enabled",
        Callback = function(v)
            MState.Enabled = v
            if not v then
                for inst in pairs(mobDrawings) do clearMob(inst) end
            end
        end,
    })

    MobSec:AddToggle({
        Text = "Mob name / distance",
        Default = true,
        ConfigKey = "visual.mob.text",
        Callback = function(v) MState.TextESP = v end,
    })

    MobSec:AddToggle({
        Text = "Mob box",
        Default = true,
        ConfigKey = "visual.mob.box",
        Callback = function(v) MState.BoxESP = v end,
    })

    MobSec:AddDropdown({
        Text = "Mobs (multi)",
        MultiSelect = true,
        Options = MOB_NAMES,
        Default = {},
        ConfigKey = "visual.mob.list",
        Callback = function(list)
            MState.SelectedMobs = selectedSet(list)
            for inst in pairs(mobCache) do
                if not isValidMob(inst) then
                    clearMob(inst)
                    clearMutation(inst)
                end
            end
        end,
    })

    MobSec:AddToggle({
        Text = "Enable Mutations",
        Default = false,
        ConfigKey = "visual.mob.mutations.enabled",
        Callback = function(v)
            MState.MutationEnabled = v
            if not v then
                for inst in pairs(mutationDrawings) do clearMutation(inst) end
            end
        end,
    })

    MobSec:AddDropdown({
        Text = "Mutations (multi)",
        MultiSelect = true,
        Options = MUTATIONS,
        Default = {},
        ConfigKey = "visual.mob.mutations",
        Callback = function(list)
            MState.SelectedMutations = selectedSet(list)
            if next(MState.SelectedMutations) == nil then
                for inst in pairs(mutationDrawings) do clearMutation(inst) end
            end
        end,
    })

    ------------------------------------------------------------
    -- Stand / Stand2 ESP (traders)
    -- Cached once; RenderStepped only updates screen-space tracers.
    ------------------------------------------------------------

    local SState = {
        Enabled = false,
        Tracer = true,
        Color = Color3.fromRGB(255, 220, 80),
    }

    local standDrawings = {}
    local standCache = {}
    local standConnections = {}
    local STAND_SET = { Stand = true, Stand2 = true }

    local function getStandAdornee(inst)
        if not inst or not inst.Parent then return nil end
        if inst:IsA("Model") then
            return inst:FindFirstChild("HumanoidRootPart")
                or inst.PrimaryPart
                or inst:FindFirstChildWhichIsA("BasePart", true)
        elseif inst:IsA("BasePart") then
            return inst
        elseif inst:IsA("Folder") then
            return inst:FindFirstChildWhichIsA("BasePart", true)
        end
        return nil
    end

    local function clearStand(inst)
        local pack = standDrawings[inst]
        if not pack then return end
        if pack.highlight then pack.highlight:Destroy() end
        if pack.billboard then pack.billboard:Destroy() end
        destroyLine(pack.line)
        standDrawings[inst] = nil
    end

    local function clearAllStands()
        for inst in pairs(standDrawings) do clearStand(inst) end
    end

    local function registerStand(inst)
        if not STAND_SET[inst.Name] then return end
        if not (inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Folder")) then return end
        local adornee = getStandAdornee(inst)
        if adornee then
            standCache[inst] = adornee
        end
    end

    local function unregisterStand(inst)
        standCache[inst] = nil
        clearStand(inst)
    end

    local function scanStandsOnce()
        for _, inst in ipairs(workspace:GetDescendants()) do
            registerStand(inst)
        end
    end

    local function rebuildStandConnections()
        for _, c in ipairs(standConnections) do c:Disconnect() end
        table.clear(standConnections)
        standConnections[#standConnections + 1] = workspace.DescendantAdded:Connect(registerStand)
        standConnections[#standConnections + 1] = workspace.DescendantRemoving:Connect(unregisterStand)
    end

    local function ensureStandPack(inst, adornee)
        local pack = standDrawings[inst]
        if pack then
            if pack.adornee ~= adornee then
                pack.adornee = adornee
                if pack.billboard then pack.billboard.Adornee = adornee end
            end
            return pack
        end

        pack = { adornee = adornee }
        local hl = Instance.new("Highlight")
        hl.Name = "StandESP"
        hl.Adornee = inst:IsA("Model") and inst or adornee
        hl.FillTransparency = 0.55
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = SState.Color
        hl.OutlineColor = SState.Color
        hl.Parent = StandFolder
        pack.highlight = hl

        local bb = Instance.new("BillboardGui")
        bb.Name = "StandText"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(160, 28)
        bb.StudsOffset = Vector3.new(0, 3, 0)
        bb.Adornee = adornee
        bb.Parent = StandFolder

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextColor3 = SState.Color
        label.TextStrokeTransparency = 0.3
        label.Text = inst.Name
        label.Parent = bb
        pack.billboard = bb

        if hasDrawing() then
            local line = Drawing.new("Line")
            line.Thickness = 2
            line.Color = SState.Color
            line.Visible = false
            pack.line = line
        end

        standDrawings[inst] = pack
        return pack
    end

    scanStandsOnce()
    rebuildStandConnections()

    local StandSec = Tab:CreateSection({ Name = "Stand ESP (traders)" })

    StandSec:AddToggle({
        Text = "Enable Stand / Stand2 ESP",
        Default = false,
        ConfigKey = "visual.stand.enabled",
        Callback = function(v)
            SState.Enabled = v
            if not v then clearAllStands() end
        end,
    })

    StandSec:AddToggle({
        Text = "Tracer to Stand",
        Default = true,
        ConfigKey = "visual.stand.tracer",
        Callback = function(v)
            SState.Tracer = v
            if not v then
                for _, pack in pairs(standDrawings) do
                    if pack.line then pack.line.Visible = false end
                end
            end
        end,
    })

    ------------------------------------------------------------
    -- Hive dungeon exits ESP
    ------------------------------------------------------------

    local StateExit = false
    local exitConn = nil

    local HiveSec = Tab:CreateSection({ Name = "Hive dungeon exits ESP" })

    local function exitEsp(v)
        if v:IsA("BasePart") and v.Name == "End" then
            if v:FindFirstChild("EndESP") then
                return
            end
            local h = Instance.new("Highlight")
            h.Name = "EndESP"
            h.Adornee = v
            h.FillTransparency = 0.5
            h.OutlineTransparency = 0
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillColor = Color3.fromRGB(80, 255, 120)
            h.OutlineColor = Color3.fromRGB(80, 255, 120)
            h.Parent = v
        end
    end

    local function clearExitEsp()
        for _, v in ipairs(workspace:GetDescendants()) do
            if v:IsA("Highlight") and v.Name == "EndESP" then
                v:Destroy()
            end
        end
        if exitConn then
            exitConn:Disconnect()
            exitConn = nil
        end
    end

    local function enableExitEsp()
        clearExitEsp()
        for _, v in ipairs(workspace:GetDescendants()) do
            exitEsp(v)
        end
        exitConn = workspace.DescendantAdded:Connect(exitEsp)
    end

    HiveSec:AddToggle({
        Text = "Highlight End exits",
        Default = false,
        ConfigKey = "visual.hive.exits",
        Callback = function(v)
            StateExit = v
            if v then
                enableExitEsp()
            else
                clearExitEsp()
            end
        end,
    })

    ------------------------------------------------------------
    -- Render loop
    -- Only cached objects are processed here.
    ------------------------------------------------------------

    RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        Camera = cam
        if not cam then return end

        local viewport = cam.ViewportSize
        local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
        local character = LocalPlayer.Character
        local myHRP = character and character:FindFirstChild("HumanoidRootPart")

        --------------------------------------------------------
        -- Players
        --------------------------------------------------------
        do
            local any = PState.TextESP or PState.BoxESP or PState.TracerESP
            local seen = {}

            if any then
                for _, player in ipairs(Players:GetPlayers()) do
                    if playerIsTarget(player) then
                        local char = player.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        local hum = char and char:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then
                            seen[player] = true
                            local pack = ensurePlayerPack(player, char)
                            if pack then
                                if pack.highlight then
                                    pack.highlight.Enabled = PState.BoxESP
                                    pack.highlight.Adornee = char
                                end
                                if pack.billboard then
                                    pack.billboard.Enabled = PState.TextESP
                                    pack.billboard.Adornee = hrp
                                    if pack.label and PState.TextESP then
                                        local dist = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
                                        pack.label.Text = string.format("%s\nHP %.0f/%.0f\n%d studs", player.Name, hum.Health, hum.MaxHealth, dist)
                                        pack.label.TextColor3 = PState.Color
                                    end
                                end
                                if pack.line and PState.TracerESP then
                                    local pos, onScreen = cam:WorldToViewportPoint(hrp.Position)
                                    if onScreen and pos.Z > 0 then
                                        pack.line.From = center
                                        pack.line.To = Vector2.new(pos.X, pos.Y)
                                        pack.line.Color = PState.Color
                                        pack.line.Visible = true
                                    else
                                        pack.line.Visible = false
                                    end
                                elseif pack.line then
                                    pack.line.Visible = false
                                end
                            end
                        end
                    end
                end
            end

            for player in pairs(playerDrawings) do
                if not seen[player] then clearPlayer(player) end
            end
        end

        --------------------------------------------------------
        -- Mobs + independent mutations
        --------------------------------------------------------
        do
            local seenMob = {}
            local seenMutation = {}
            local wantMob = MState.Enabled and next(MState.SelectedMobs) ~= nil
            local wantMutation = MState.MutationEnabled and next(MState.SelectedMutations) ~= nil

            if wantMob or wantMutation then
                for inst, data in pairs(mobCache) do
                    if inst.Parent and isValidMob(inst) then
                        local hitbox = data.hitbox
                        if not hitbox or not hitbox.Parent then
                            hitbox = getHitbox(inst)
                            data.hitbox = hitbox
                        end

                        if hitbox then
                            local mutationSet = wantMutation and activeMutationSet(inst) or nil
                            local hasMutation = mutationSet and next(mutationSet) ~= nil

                            if wantMob then
                                seenMob[inst] = true
                                local mobColor = getMobColor(data.kind)
                                local pack = ensureMobPack(inst, hitbox, data.kind)
                                if pack.highlight then
                                    pack.highlight.Enabled = MState.BoxESP
                                    pack.highlight.Adornee = inst
                                    pack.highlight.FillColor = mobColor
                                    pack.highlight.OutlineColor = mobColor
                                end
                                if pack.billboard then
                                    pack.billboard.Enabled = MState.TextESP
                                    pack.billboard.Adornee = hitbox
                                    if pack.label and MState.TextESP then
                                        local dist = myHRP and math.floor((myHRP.Position - hitbox.Position).Magnitude) or 0
                                        local mutText = hasMutation and (" [" .. table.concat((function()
                                            local t = {}
                                            for _, mut in ipairs(MUTATIONS) do
                                                if mutationSet[mut] then t[#t + 1] = mut end
                                            end
                                            return t
                                        end)(), ",") .. "]") or ""
                                        pack.label.Text = string.format("%s%s\n%d studs", inst.Name, mutText, dist)
                                        pack.label.TextColor3 = mobColor
                                    end
                                end
                            end

                            if wantMutation and hasMutation then
                                seenMutation[inst] = true
                                local mutationColor = getMutationColor(mutationSet)
                                local pack = ensureMutationPack(inst, hitbox)
                                pack.highlight.Enabled = true
                                pack.highlight.Adornee = inst
                                pack.highlight.FillColor = mutationColor
                                pack.highlight.OutlineColor = mutationColor
                                pack.label.TextColor3 = mutationColor
                                pack.billboard.Adornee = hitbox
                                local names = {}
                                for _, mut in ipairs(MUTATIONS) do
                                    if mutationSet[mut] then names[#names + 1] = mut end
                                end
                                pack.label.Text = table.concat(names, ", ")

                                if pack.line then
                                    local pos, onScreen = cam:WorldToViewportPoint(hitbox.Position)
                                    if onScreen and pos.Z > 0 then
                                        pack.line.From = center
                                        pack.line.To = Vector2.new(pos.X, pos.Y)
                                        pack.line.Color = mutationColor
                                        pack.line.Visible = true
                                    else
                                        pack.line.Visible = false
                                    end
                                end
                            end
                        end
                    end
                end
            end

            for inst in pairs(mobDrawings) do
                if not seenMob[inst] then clearMob(inst) end
            end
            for inst in pairs(mutationDrawings) do
                if not seenMutation[inst] then clearMutation(inst) end
            end
        end

        --------------------------------------------------------
        -- Stand / Stand2
        --------------------------------------------------------
        do
            local seen = {}
            if SState.Enabled then
                for inst, cachedAdornee in pairs(standCache) do
                    if inst.Parent then
                        local adornee = cachedAdornee
                        if not adornee or not adornee.Parent then
                            adornee = getStandAdornee(inst)
                            standCache[inst] = adornee
                        end
                        if adornee then
                            seen[inst] = true
                            local pack = ensureStandPack(inst, adornee)
                            if pack and pack.line and SState.Tracer then
                                local pos, onScreen = cam:WorldToViewportPoint(adornee.Position)
                                if onScreen and pos.Z > 0 then
                                    pack.line.From = center
                                    pack.line.To = Vector2.new(pos.X, pos.Y)
                                    pack.line.Color = SState.Color
                                    pack.line.Visible = true
                                else
                                    pack.line.Visible = false
                                end
                            elseif pack and pack.line then
                                pack.line.Visible = false
                            end
                        end
                    end
                end
            end

            for inst in pairs(standDrawings) do
                if not seen[inst] then clearStand(inst) end
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        clearPlayer(player)
    end)

end
