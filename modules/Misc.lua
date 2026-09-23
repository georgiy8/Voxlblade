--========================================================--
-- Misc Module
-- Small one-off world tweaks that don't need their own tab.
-- Ported from chat-command style (addcmd) to GUI widgets.
--========================================================--

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

return function(Window, meta)

    local Tab = Window:CreateTab({
        Name = "Misc",
        Icon = "🧰",
        Order = (meta and meta.Order) or 60,
    })

    ------------------------------------------------------------
    -- Lighting
    ------------------------------------------------------------

    local LightingSection = Tab:CreateSection({
        Name = "Lighting"
    })

    -- was: addcmd('nofog', {}, function(args, speaker) ... end)
    LightingSection:AddButton({
        Text = "Remove Fog",
        Callback = function()

            Lighting.FogEnd = 100000

            for _, v in ipairs(Lighting:GetDescendants()) do
                if v:IsA("Atmosphere") then
                    v:Destroy()
                end
            end

        end
    })

    -- was: addcmd('brightness', {}, function(args, speaker) Lighting.Brightness = args[1] end)
    LightingSection:AddSlider({
        Text = "Brightness",
        Min = 0,
        Max = 10,
        Default = Lighting.Brightness,
        Increment = 0.1,
        Callback = function(Value)
            Lighting.Brightness = Value
        end
    })

    ------------------------------------------------------------
    -- Camera / Character (client-side comfort, nothing sent to the server)
    ------------------------------------------------------------

    local CameraSection = Tab:CreateSection({
        Name = "Camera"
    })

    CameraSection:AddSlider({
        Text = "Field of View",
        Min = 30,
        Max = 120,
        Default = Workspace.CurrentCamera.FieldOfView,
        Increment = 1,
        Callback = function(Value)
            Workspace.CurrentCamera.FieldOfView = Value
        end
    })

    CameraSection:AddSlider({
        Text = "WalkSpeed",
        Min = 16,
        Max = 100,
        Default = 16,
        Increment = 1,
        Callback = function(Value)
            local Character = LocalPlayer.Character
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
            if Humanoid then
                Humanoid.WalkSpeed = Value
            end
        end
    })

    CameraSection:AddSlider({
        Text = "JumpPower",
        Min = 50,
        Max = 200,
        Default = 50,
        Increment = 5,
        Callback = function(Value)
            local Character = LocalPlayer.Character
            local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
            if Humanoid then
                Humanoid.JumpPower = Value
            end
        end
    })

    local NoclipConnection = nil

    CameraSection:AddToggle({
        Text = "Noclip",
        Default = false,
        Callback = function(Value)

            if NoclipConnection then
                NoclipConnection:Disconnect()
                NoclipConnection = nil
            end

            if Value then
                NoclipConnection = game:GetService("RunService").Stepped:Connect(function()
                    local Character = LocalPlayer.Character
                    if Character then
                        for _, Part in ipairs(Character:GetDescendants()) do
                            if Part:IsA("BasePart") then
                                Part.CanCollide = false
                            end
                        end
                    end
                end)
            end

        end
    })

    ------------------------------------------------------------
    -- Exploration (read-only research tools: names, hierarchy, remotes)
    ------------------------------------------------------------

    local ExploreSection = Tab:CreateSection({
        Name = "Exploration"
    })

    local InspectEnabled = false
    local InspectConnection = nil

    ExploreSection:AddToggle({
        Text = "Inspect Mode (click a part)",
        Default = false,
        Callback = function(Value)

            InspectEnabled = Value

            if InspectConnection then
                InspectConnection:Disconnect()
                InspectConnection = nil
            end

            if InspectEnabled then

                InspectConnection = UserInputService.InputBegan:Connect(function(Input, Processed)

                    if Processed or Input.UserInputType ~= Enum.UserInputType.MouseButton1 then
                        return
                    end

                    local Mouse = LocalPlayer:GetMouse()
                    local Target = Mouse.Target

                    if Target then

                        local FullName = Target:GetFullName()

                        print("[Misc] Inspected:", FullName, "(" .. Target.ClassName .. ")")

                        pcall(function()
                            if setclipboard then
                                setclipboard(FullName)
                            end
                        end)

                    end

                end)

            end

        end
    })

    ExploreSection:AddButton({
        Text = "Dump Workspace Tree to Console",
        Callback = function()

            local MaxDepth = 6

            local function Dump(Instance, Depth)

                if Depth > MaxDepth then
                    return
                end

                print(string.rep("  ", Depth) .. Instance.Name .. " (" .. Instance.ClassName .. ")")

                for _, Child in ipairs(Instance:GetChildren()) do
                    Dump(Child, Depth + 1)
                end

            end

            print("---- Workspace Tree ----")
            Dump(Workspace, 0)
            print("---- End ----")

        end
    })

    ExploreSection:AddButton({
        Text = "List Remotes in ReplicatedStorage",
        Callback = function()

            print("---- RemoteEvents / RemoteFunctions ----")

            for _, Instance in ipairs(ReplicatedStorage:GetDescendants()) do
                if Instance:IsA("RemoteEvent") or Instance:IsA("RemoteFunction") then
                    print(Instance.ClassName .. ": " .. Instance:GetFullName())
                end
            end

            print("---- End ----")

        end
    })

end
