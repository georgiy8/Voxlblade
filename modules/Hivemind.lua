-- modules/Hivemind.lua  (в UMU base или place-репо)
return function(Window, meta)
    local UIS = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    local HttpService = game:GetService("HttpService")

    local ROOT = "Universal-assets-by-gk/Configs/Hivemind"
    local CONFIG_PATH = ROOT .. "/config.json"
    local STATE_PATH = ROOT .. "/state.json"

    local function ensure()
        if makefolder then
            if isfolder and not isfolder("Universal-assets-by-gk") then makefolder("Universal-assets-by-gk") end
            if isfolder and not isfolder("Universal-assets-by-gk/Configs") then makefolder("Universal-assets-by-gk/Configs") end
            if isfolder and not isfolder(ROOT) then makefolder(ROOT) end
        end
    end

    local function readJson(path)
        if not isfile or not isfile(path) then return nil end
        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)
        return ok and data or nil
    end

    local function writeJson(path, tbl)
        ensure()
        if not writefile then return false end
        writefile(path, HttpService:JSONEncode(tbl))
        return true
    end

    local cfg = readJson(CONFIG_PATH) or {
        leader = "",
        enabled = false,
        syncCamera = true,
        syncCharacter = true,
        syncInput = true,
    }

    local Tab = Window:CreateTab({
        Name = "Hivemind",
        Icon = "🧠",
        Order = (meta and meta.Order) or 25,
    })

    local S = Tab:CreateSection({ Name = "Setup" })

    S:AddTextbox({
        Text = "Leader name",
        Default = cfg.leader,
        Placeholder = "Exact username",
        ConfigKey = "hivemind.leader",
        Callback = function(t) cfg.leader = t or "" end
    })

    S:AddToggle({
        Text = "Enabled",
        Default = cfg.enabled,
        ConfigKey = "hivemind.enabled",
        Callback = function(v) cfg.enabled = v end
    })

    S:AddButton({
        Text = "Save Hivemind Config",
        Callback = function()
            writeJson(CONFIG_PATH, cfg)
            print("[Hivemind] config saved", cfg.leader)
        end
    })

    local function isLeader()
        return cfg.leader ~= "" and LP.Name == cfg.leader
    end

    ------------------------------------------------------------
    -- LEADER: publish state
    ------------------------------------------------------------

    local keysDown = {}

    UIS.InputBegan:Connect(function(input, gp)
        if not cfg.enabled or not isLeader() then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            keysDown[input.KeyCode.Name] = true
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if not cfg.enabled or not isLeader() then return end
        if input.UserInputType == Enum.UserInputType.Keyboard then
            keysDown[input.KeyCode.Name] = nil
        end
    end)

    RunService.Heartbeat:Connect(function()
        if not cfg.enabled or not isLeader() then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local cam = workspace.CurrentCamera
        if not hrp or not hum then return end

        local cf = hrp.CFrame
        local ccf = cam and cam.CFrame

        writeJson(STATE_PATH, {
            t = os.clock(),
            leader = LP.Name,
            pos = { cf.X, cf.Y, cf.Z },
            look = { cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z },
            cam = ccf and { ccf:GetComponents() } or nil,
            walkSpeed = hum.WalkSpeed,
            jumpPower = hum.UseJumpPower and hum.JumpPower or hum.JumpHeight,
            useJumpPower = hum.UseJumpPower,
            keys = keysDown,
            mouse1 = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1),
            mouse2 = UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2),
        })
    end)

    ------------------------------------------------------------
    -- FOLLOWER: apply state
    ------------------------------------------------------------

    local lastKeys = {}

    local function pressKey(name, down)
        -- executor-dependent; examples:
        if VIM then -- placeholder
        end
        if keypress and keyrelease and Enum.KeyCode[name] then
            local code = Enum.KeyCode[name].Value -- often wrong API; many use virtualinput
        end
        -- Best effort: many executors expose:
        -- VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end

    RunService.Heartbeat:Connect(function()
        if not cfg.enabled or isLeader() then return end
        if cfg.leader == "" or LP.Name == cfg.leader then return end

        local st = readJson(STATE_PATH)
        if not st or not st.pos then return end
        -- stale lock
        if st.t and (os.clock() - st.t) > 1.5 then return end

        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end

        if cfg.syncCharacter then
            local p = st.pos
            local look = st.look
            if look then
                local pos = Vector3.new(p[1], p[2], p[3])
                local lv = Vector3.new(look[1], look[2], look[3])
                hrp.CFrame = CFrame.lookAt(pos, pos + lv)
            else
                hrp.CFrame = CFrame.new(p[1], p[2], p[3])
            end
            if st.walkSpeed then hum.WalkSpeed = st.walkSpeed end
            if st.useJumpPower and st.jumpPower then
                hum.JumpPower = st.jumpPower
            elseif st.jumpPower then
                hum.JumpHeight = st.jumpPower
            end
        end

        if cfg.syncCamera and st.cam and workspace.CurrentCamera then
            -- optional: apply components if you pack full CFrame
        end

        if cfg.syncInput and st.keys then
            -- edge-trigger keys vs lastKeys, call virtual input
            for k, v in pairs(st.keys) do
                if v and not lastKeys[k] then
                    -- key down once
                end
            end
            lastKeys = st.keys
        end
    end)
end
