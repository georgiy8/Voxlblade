--========================================================--
-- Visual Module — Player ESP + Hive exits
--========================================================--

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

return function(Window, meta)

    local Tab = Window:CreateTab({
        Name = "Visual",
        Icon = "👁️",
        Order = (meta and meta.Order) or 45,
    })

    ------------------------------------------------------------
    -- State
    ------------------------------------------------------------

    local State = {
        TextESP = false,
        BoxESP = false,
        TracerESP = false,
        Color = Color3.fromRGB(120, 200, 255),
        -- multi-select: empty = all players
        SelectedPlayers = {},
        ExitESP = false,
    }

    local ESPFolder = Instance.new("Folder")
    ESPFolder.Name = "UMU_PlayerESP"
    ESPFolder.Parent = game:GetService("CoreGui")

    local drawings = {} -- [player] = { highlight, billboard, line }
    local exitConn = nil
    local exitHooked = {}

    local function isTarget(player)
        if player == LocalPlayer then
            return false
        end
        local list = State.SelectedPlayers
        if type(list) ~= "table" or #list == 0 then
            return true -- none selected = all
        end
        for _, name in ipairs(list) do
            if name == player.Name then
                return true
            end
        end
        return false
    end

    local function clearPlayer(player)
        local pack = drawings[player]
        if not pack then
            return
        end
        if pack.highlight then
            pack.highlight:Destroy()
        end
        if pack.billboard then
            pack.billboard:Destroy()
        end
        if pack.line then
            pcall(function()
                pack.line:Remove()
            end)
            pcall(function()
                pack.line:Destroy()
            end)
        end
        drawings[player] = nil
    end

    local function clearAll()
        for player in pairs(drawings) do
            clearPlayer(player)
        end
    end

    local function ensurePack(player, character)
        local pack = drawings[player]
        if pack then
            return pack
        end
        pack = {}

        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then
            return nil
        end

        -- Box = Highlight
        local hl = Instance.new("Highlight")
        hl.Name = "PlayerBoxESP"
        hl.Adornee = character
        hl.FillTransparency = 0.7
        hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.FillColor = State.Color
        hl.OutlineColor = State.Color
        hl.Enabled = State.BoxESP
        hl.Parent = ESPFolder
        pack.highlight = hl

        -- Text over head
        local bb = Instance.new("BillboardGui")
        bb.Name = "PlayerTextESP"
        bb.AlwaysOnTop = true
        bb.Size = UDim2.fromOffset(200, 54)
        bb.StudsOffset = Vector3.new(0, 3.2, 0)
        bb.Adornee = hrp
        bb.Enabled = State.TextESP
        bb.Parent = ESPFolder

        local label = Instance.new("TextLabel")
        label.Name = "Label"
        label.BackgroundTransparency = 1
        label.Size = UDim2.fromScale(1, 1)
        label.Font = Enum.Font.Code
        label.TextSize = 14
        label.TextColor3 = State.Color
        label.TextStrokeTransparency = 0.4
        label.Text = player.Name
        label.Parent = bb
        pack.billboard = bb
        pack.label = label

        -- Tracer (Drawing library if present)
        if Drawing and Drawing.new then
            local line = Drawing.new("Line")
            line.Thickness = 1
            line.Color = State.Color
            line.Visible = false
            pack.line = line
        end

        drawings[player] = pack
        return pack
    end

    local function applyColor()
        for _, pack in pairs(drawings) do
            if pack.highlight then
                pack.highlight.FillColor = State.Color
                pack.highlight.OutlineColor = State.Color
            end
            if pack.label then
                pack.label.TextColor3 = State.Color
            end
            if pack.line then
                pack.line.Color = State.Color
            end
        end
    end

    ------------------------------------------------------------
    -- Player ESP section
    ------------------------------------------------------------

    local PlayerSec = Tab:CreateSection({ Name = "Player ESP" })

    PlayerSec:AddToggle({
        Text = "Name / Health / Distance",
        Default = false,
        ConfigKey = "visual.player.text",
        Callback = function(v)
            State.TextESP = v
            for player, pack in pairs(drawings) do
                if pack.billboard then
                    pack.billboard.Enabled = v and isTarget(player)
                end
            end
        end
    })

    PlayerSec:AddToggle({
        Text = "Box (Highlight)",
        Default = false,
        ConfigKey = "visual.player.box",
        Callback = function(v)
            State.BoxESP = v
            for player, pack in pairs(drawings) do
                if pack.highlight then
                    pack.highlight.Enabled = v and isTarget(player)
                end
            end
        end
    })

    PlayerSec:AddToggle({
        Text = "Tracer (screen center)",
        Default = false,
        ConfigKey = "visual.player.tracer",
        Callback = function(v)
            State.TracerESP = v
            if not v then
                for _, pack in pairs(drawings) do
                    if pack.line then
                        pack.line.Visible = false
                    end
                end
            end
        end
    })

    PlayerSec:AddSlider({
        Text = "Color R",
        Min = 0, Max = 255, Default = 120, Increment = 1,
        ConfigKey = "visual.player.r",
        Callback = function(v)
            State.Color = Color3.fromRGB(v, State.Color.G * 255, State.Color.B * 255)
            applyColor()
        end
    })

    PlayerSec:AddSlider({
        Text = "Color G",
        Min = 0, Max = 255, Default = 200, Increment = 1,
        ConfigKey = "visual.player.g",
        Callback = function(v)
            State.Color = Color3.fromRGB(State.Color.R * 255, v, State.Color.B * 255)
            applyColor()
        end
    })

    PlayerSec:AddSlider({
        Text = "Color B",
        Min = 0, Max = 255, Default = 255, Increment = 1,
        ConfigKey = "visual.player.b",
        Callback = function(v)
            State.Color = Color3.fromRGB(State.Color.R * 255, State.Color.G * 255, v)
            applyColor()
        end
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
            State.SelectedPlayers = list or {}
            -- empty = all
        end
    })

    PlayerSec:AddButton({
        Text = "Refresh player list",
        Callback = function()
            if playerDrop.SetValues then
                playerDrop:SetValues(playerNameList())
            end
        end
    })

    ------------------------------------------------------------
    -- Update loop
    ------------------------------------------------------------

    RunService.RenderStepped:Connect(function()
        local any = State.TextESP or State.BoxESP or State.TracerESP
        if not any then
            for _, pack in pairs(drawings) do
                if pack.line then
                    pack.line.Visible = false
                end
            end
            return
        end

        local myHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local viewport = Camera and Camera.ViewportSize
        local center = viewport and Vector2.new(viewport.X / 2, viewport.Y / 2)

        local seen = {}

        for _, player in ipairs(Players:GetPlayers()) do
            if isTarget(player) then
                local character = player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local hum = character and character:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 then
                    seen[player] = true
                    local pack = ensurePack(player, character)
                    if pack then
                        if pack.highlight then
                            pack.highlight.Enabled = State.BoxESP
                            pack.highlight.Adornee = character
                        end
                        if pack.billboard then
                            pack.billboard.Enabled = State.TextESP
                            pack.billboard.Adornee = hrp
                            if pack.label and State.TextESP then
                                local dist = myHRP and math.floor((myHRP.Position - hrp.Position).Magnitude) or 0
                                pack.label.Text = string.format(
                                    "%s\nHP %.0f/%.0f\n%d studs",
                                    player.Name,
                                    hum.Health,
                                    hum.MaxHealth,
                                    dist
                                )
                                pack.label.TextColor3 = State.Color
                            end
                        end
                        if pack.line and State.TracerESP and center then
                            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                            if onScreen and pos.Z > 0 then
                                pack.line.From = center
                                pack.line.To = Vector2.new(pos.X, pos.Y)
                                pack.line.Color = State.Color
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

        for player in pairs(drawings) do
            if not seen[player] then
                clearPlayer(player)
            end
        end
    end)

    Players.PlayerRemoving:Connect(function(player)
        clearPlayer(player)
    end)

    ------------------------------------------------------------
    -- Hive dungeon exits ESP
    ------------------------------------------------------------

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
            State.ExitESP = v
            if v then
                enableExitEsp()
            else
                clearExitEsp()
            end
        end
    })

end
