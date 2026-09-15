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

local MOB_BY_LEN = table.clone(MOB_NAMES)
table.sort(MOB_BY_LEN, function(a, b)
    return #a > #b
end)

local MUTATIONS = { "Legendary", "Magical", "Corrupt", "Bloody" }

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
    -- Mob ESP state
    -- Buni07 (MeshPart) -> Hitbox (MeshPart)
    -- Mutation: Particle NAME + PointLight NAMEL both Enabled
    -- Mutation multi-select turns ON tracers to matching mobs
    ------------------------------------------------------------

    local MState = {
        Enabled = false,
        TextESP = true,
        BoxESP = true,
        Color = Color3.fromRGB(255, 180, 80),
        SelectedMobs = {},
        SelectedMutations = {},
    }

    local mobDrawings = {} -- [instance] = pack

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

    local function matchMobType(name)
        if type(name) ~= "string" then
            return nil
        end
        for _, kind in ipairs(MOB_BY_LEN) do
            if MState.SelectedMobs[kind] then
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
        local pOk = false
        local lOk = false
        if particle:IsA("ParticleEmitter") or particle:IsA("Beam") or particle:IsA("Trail") then
            pOk = particle.Enabled == true
        else
            pOk = particle.Enabled ~= false
        end
        if light:IsA("PointLight") or light:IsA("SpotLight") or light:IsA("SurfaceLight") then
            lOk = light.Enabled == true
        else
            lOk = light.Enabled ~= false
        end
        return pOk and lOk
    end

    local function activeMutations(root)
        local found = {}
        for mut in pairs(MState.SelectedMutations) do
            if mutationOn(root, mut) then
                table.insert(found, mut)
            end
        end
        return found
    end

    local function clearMob(inst)
        local pack = mobDrawings[inst]
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
        mobDrawings[inst] = nil
    end

    local function clearAllMobs()
        for inst in pairs(mobDrawings) do
            clearMob(inst)
        end
    end

    local function ensureMobPack(inst, hitbox)
        local pack = mobDrawings[inst]
        if pack then
            return pack
        end

        pack = {}

        local hl = Instance.new("Highlight")
        hl.Name = "MobBoxESP"
        hl.Adornee = inst
        hl.FillTransparency = 0.65
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = MState.Color
        hl.OutlineColor = MState.Color
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
        label.TextColor3 = MState.Color
        label.TextStrokeTransparency = 0.4
        label.Text = inst.Name
        label.Parent = bb
        pack.billboard = bb
        pack.label = label

        if hasDrawing() then
            local line = Drawing.new("Line")
            line.Thickness = 1.5
            line.Color = MState.Color
            line.Visible = false
            pack.line = line
        end

        mobDrawings[inst] = pack
        return pack
    end

    ------------------------------------------------------------
    -- Mob ESP UI  (before Hive)
    ------------------------------------------------------------

    local MobSec = Tab:CreateSection({ Name = "Mob ESP" })

    MobSec:AddToggle({
        Text = "Enable Mob ESP",
        Default = false,
        ConfigKey = "visual.mob.enabled",
        Callback = function(v)
            MState.Enabled = v
            if not v then
                clearAllMobs()
            end
        end,
    })

    MobSec:AddToggle({
        Text = "Mob name / distance",
        Default = true,
        ConfigKey = "visual.mob.text",
        Callback = function(v)
            MState.TextESP = v
        end,
    })

    MobSec:AddToggle({
        Text = "Mob box",
        Default = true,
        ConfigKey = "visual.mob.box",
        Callback = function(v)
            MState.BoxESP = v
        end,
    })

    MobSec:AddDropdown({
        Text = "Mobs (multi)",
        MultiSelect = true,
        Options = MOB_NAMES,
        Default = {},
        ConfigKey = "visual.mob.list",
        Callback = function(list)
            MState.SelectedMobs = selectedSet(list)
            if next(MState.SelectedMobs) == nil then
                clearAllMobs()
            end
        end,
    })

    MobSec:AddLabel({
        Text = "Mutations: both NAME + NAMEL Enabled. Selecting one enables tracers to those mobs.",
    })

    MobSec:AddDropdown({
        Text = "Mutations (multi) -> tracers",
        MultiSelect = true,
        Options = MUTATIONS,
        Default = {},
        ConfigKey = "visual.mob.mutations",
        Callback = function(list)
            MState.SelectedMutations = selectedSet(list)
            if next(MState.SelectedMutations) == nil then
                for _, pack in pairs(mobDrawings) do
                    if pack.line then
                        pack.line.Visible = false
                    end
                end
            end
        end,
    })

    ------------------------------------------------------------
    -- Stand / Stand2 ESP (traders)
    ------------------------------------------------------------

    local SState = {
        Enabled = false,
        Tracer = true,
        Color = Color3.fromRGB(255, 220, 80),
    }

    local standDrawings = {} -- [instance] = pack

    local function clearStand(inst)
        local pack = standDrawings[inst]
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
        standDrawings[inst] = nil
    end

    local function clearAllStands()
        for inst in pairs(standDrawings) do
            clearStand(inst)
        end
    end

    local function ensureStandPack(inst)
        local pack = standDrawings[inst]
        if pack then
            return pack
        end

        local adornee = inst
        if inst:IsA("Model") then
            adornee = inst:FindFirstChild("HumanoidRootPart")
                or inst:FindFirstChildWhichIsA("BasePart")
                or inst.PrimaryPart
        elseif not inst:IsA("BasePart") then
            adornee = inst:FindFirstChildWhichIsA("BasePart", true)
        end
        if not adornee then
            return nil
        end

        pack = {}

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
        pack.adornee = adornee

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

    local StandSec = Tab:CreateSection({ Name = "Stand ESP (traders)" })

    StandSec:AddToggle({
        Text = "Enable Stand / Stand2 ESP",
        Default = false,
        ConfigKey = "visual.stand.enabled",
        Callback = function(v)
            SState.Enabled = v
            if not v then
                clearAllStands()
            end
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
                    if pack.line then
                        pack.line.Visible = false
                    end
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
    ------------------------------------------------------------

    RunService.RenderStepped:Connect(function()
        local cam = workspace.CurrentCamera
        Camera = cam
        local viewport = cam and cam.ViewportSize
        local center = viewport and Vector2.new(viewport.X / 2, viewport.Y / 2)
        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")

        --------------------------------------------------------
        -- Players
        --------------------------------------------------------
        do
            local any = PState.TextESP or PState.BoxESP or PState.TracerESP
            local seen = {}

            if any then
                for _, player in ipairs(Players:GetPlayers()) do
                    if playerIsTarget(player) then
                        local character = player.Character
                        local hrp = character and character:FindFirstChild("HumanoidRootPart")
                        local hum = character and character:FindFirstChildOfClass("Humanoid")
                        if hrp and hum and hum.Health > 0 then
                            seen[player] = true
                            local pack = ensurePlayerPack(player, character)
                            if pack then
                                if pack.highlight then
                                    pack.highlight.Enabled = PState.BoxESP
                                    pack.highlight.Adornee = character
                                end
                                if pack.billboard then
                                    pack.billboard.Enabled = PState.TextESP
                                    pack.billboard.Adornee = hrp
                                    if pack.label and PState.TextESP then
                                        local dist = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
                                        pack.label.Text = string.format(
                                            "%s\nHP %.0f/%.0f\n%d studs",
                                            player.Name,
                                            hum.Health,
                                            hum.MaxHealth,
                                            dist
                                        )
                                        pack.label.TextColor3 = PState.Color
                                    end
                                end
                                if pack.line and PState.TracerESP and center and cam then
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
                if not seen[player] then
                    clearPlayer(player)
                end
            end
        end

        --------------------------------------------------------
        -- Mobs
        --------------------------------------------------------
        do
            local seen = {}

            if MState.Enabled and next(MState.SelectedMobs) ~= nil then
                for _, inst in ipairs(workspace:GetDescendants()) do
                    local kind = matchMobType(inst.Name)
                    if kind and inst:IsA("BasePart") then
                        local hitbox = getHitbox(inst)
                        if hitbox then
                            seen[inst] = true
                            local muts = activeMutations(inst)
                            local wantTracer = #muts > 0

                            local pack = ensureMobPack(inst, hitbox)
                            if pack then
                                if pack.highlight then
                                    pack.highlight.Enabled = MState.BoxESP
                                    pack.highlight.Adornee = inst
                                    pack.highlight.FillColor = MState.Color
                                    pack.highlight.OutlineColor = MState.Color
                                end
                                if pack.billboard then
                                    pack.billboard.Enabled = MState.TextESP
                                    pack.billboard.Adornee = hitbox
                                    if pack.label and MState.TextESP then
                                        local dist = myHRP and math.floor((myHRP.Position - hitbox.Position).Magnitude) or 0
                                        local mutText = #muts > 0 and (" [" .. table.concat(muts, ",") .. "]") or ""
                                        pack.label.Text = string.format("%s%s\n%d studs", inst.Name, mutText, dist)
                                        pack.label.TextColor3 = MState.Color
                                    end
                                end
                                if pack.line and wantTracer and center and cam then
                                    local pos, onScreen = cam:WorldToViewportPoint(hitbox.Position)
                                    if onScreen and pos.Z > 0 then
                                        pack.line.From = center
                                        pack.line.To = Vector2.new(pos.X, pos.Y)
                                        pack.line.Color = MState.Color
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

            for inst in pairs(mobDrawings) do
                if not seen[inst] then
                    clearMob(inst)
                end
            end
        end

        --------------------------------------------------------
        -- Stand / Stand2
        --------------------------------------------------------
        do
            local seen = {}

            if SState.Enabled then
                for _, inst in ipairs(workspace:GetDescendants()) do
                    local n = inst.Name
                    if n == "Stand" or n == "Stand2" then
                        if inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("Folder") then
                            seen[inst] = true
                            local pack = ensureStandPack(inst)
                            if pack and pack.adornee and cam then
                                if pack.line and SState.Tracer and center then
                                    local pos, onScreen = cam:WorldToViewportPoint(pack.adornee.Position)
                                    if onScreen and pos.Z > 0 then
                                        pack.line.From = center
                                        pack.line.To = Vector2.new(pos.X, pos.Y)
                                        pack.line.Color = SState.Color
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

            for inst in pairs(standDrawings) do
                if not seen[inst] then
                    clearStand(inst)
                end
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        clearPlayer(player)
    end)

end
