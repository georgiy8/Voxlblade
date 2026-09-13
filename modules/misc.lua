--========================================================--
-- Misc Module
-- Small one-off world tweaks that don't need their own tab.
-- Ported from chat-command style (addcmd) to GUI widgets.
--========================================================--

local Lighting = game:GetService("Lighting")

return function(Window, meta)

    local Tab = Window:CreateTab({
        Name = "Misc",
        Icon = "🧰",
        Order = (meta and meta.Order) or 40,
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

end
