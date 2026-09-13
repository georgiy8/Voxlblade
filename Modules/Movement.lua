--========================================================--
-- Movement Module
-- TP Walk: Toggle + Keybind (both drive the same state) + Speed slider.
-- Ported from chat-command style (addcmd tpwalk/untpwalk) to GUI widgets.
--========================================================--

local RunService = game:GetService("RunService")
local Players    = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

return function(Window, meta)

    local Tab = Window:CreateTab({
        Name = "Movement",
        Icon = "🏃",
        Order = (meta and meta.Order) or 70,
    })

    local Section = Tab:CreateSection({
        Name = "TP Walk"
    })

    ------------------------------------------------------------
    -- State
    ------------------------------------------------------------

    local Enabled = false
    local Speed = 1
    local Connection = nil

    local ToggleWidget -- set below, referenced by the keybind

    local function Stop()

        if Connection then
            Connection:Disconnect()
            Connection = nil
        end

    end

    local function Start()

        Stop()

        Connection = RunService.Heartbeat:Connect(function(Delta)

            local Character = LocalPlayer.Character
            local Humanoid = Character and Character:FindFirstChildWhichIsA("Humanoid")

            if not (Character and Humanoid and Humanoid.Parent) then
                Stop()
                return
            end

            if Humanoid.MoveDirection.Magnitude > 0 then
                Character:TranslateBy(Humanoid.MoveDirection * Speed * Delta * 10)
            end

        end)

    end

    -- single entry point: used by both the Toggle and the Keybind
    -- so the two controls can never fall out of sync
    local function SetEnabled(State)

        Enabled = State

        if Enabled then
            Start()
        else
            Stop()
        end

        if ToggleWidget then
            ToggleWidget:SetValue(Enabled) -- SetValue does not fire Callback, so no loop
        end

    end

    ------------------------------------------------------------
    -- Widgets
    ------------------------------------------------------------

    ToggleWidget = Section:AddToggle({
        Text = "TP Walk",
        Default = false,
        Callback = function(Value)
            SetEnabled(Value)
        end
    })

    -- was: addcmd("teleportwalk", {"tpwalk"}, ...) / addcmd("unteleportwalk", {"untpwalk"}, ...)
    Section:AddKeybind({
        Text = "TP Walk Hotkey",
        Default = Enum.KeyCode.T,
        Callback = function()
            SetEnabled(not Enabled)
        end
    })

    Section:AddSlider({
        Text = "TP Walk Speed",
        Min = 1,
        Max = 50,
        Default = Speed,
        Increment = 1,
        Callback = function(Value)
            Speed = Value -- takes effect immediately, even while Enabled
        end
    })

    -- kill the connection on respawn/death, otherwise Heartbeat keeps
    -- firing TranslateBy on a stale Character reference for a frame
    LocalPlayer.CharacterRemoving:Connect(Stop)

end
