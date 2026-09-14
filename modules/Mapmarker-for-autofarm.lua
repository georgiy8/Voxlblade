--========================================================--
-- Zone Farm Module
-- Google-Maps-style top-down camera to mark farm zones as a
-- sequence of world-space points, saved/loaded as JSON.
--========================================================--

local HttpService       = game:GetService("HttpService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------
-- Zone Store (file IO) — same folder conventions as Config-manager.lua
------------------------------------------------------------

local ZoneStore = {}

local ROOT = "Universal-assets-by-gk/Configs/Profiles/Zones-autofarm"

local function ensureDir(path)

    if makefolder and isfolder and not isfolder(path) then
        makefolder(path)
    end

end

local function ensureTree()

    ensureDir("Universal-assets-by-gk")
    ensureDir("Universal-assets-by-gk/Configs")
    ensureDir("Universal-assets-by-gk/Configs/Profiles")
    ensureDir(ROOT)

end

local function safeName(name)

    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    name = name:gsub("[^%w%-%_ ]", "")
    name = name:gsub("%s+", "_")

    if name == "" then
        return nil
    end

    return name

end

local function zonePath(name)

    return ROOT .. "/" .. name .. ".json"

end

function ZoneStore.List()

    ensureTree()

    local Names = {}

    if listfiles then

        for _, path in ipairs(listfiles(ROOT)) do

            local fileName = path:match("([^/\\]+)%.json$")

            if fileName then
                table.insert(Names, fileName)
            end

        end

    end

    table.sort(Names)

    return Names

end

function ZoneStore.Save(name, points)

    ensureTree()

    local clean = safeName(name)

    if not clean then
        warn("[ZoneStore] Invalid zone name")
        return false
    end

    if not writefile then
        warn("[ZoneStore] writefile missing")
        return false
    end

    local encodedPoints = {}

    for _, p in ipairs(points) do
        table.insert(encodedPoints, { X = p.X, Y = p.Y, Z = p.Z })
    end

    local payload = {
        Name = clean,
        Points = encodedPoints,
    }

    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(payload)
    end)

    if not ok then
        warn("[ZoneStore] encode failed")
        return false
    end

    writefile(zonePath(clean), encoded)

    return true

end

function ZoneStore.Load(name)

    if not isfile or not isfile(zonePath(name)) then
        return nil
    end

    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(zonePath(name)))
    end)

    if not ok or type(data) ~= "table" or type(data.Points) ~= "table" then
        return nil
    end

    local points = {}

    for _, p in ipairs(data.Points) do
        table.insert(points, Vector3.new(p.X, p.Y, p.Z))
    end

    return points

end

function ZoneStore.Delete(name)

    if delfile and isfile and isfile(zonePath(name)) then
        delfile(zonePath(name))
        return true
    end

    return false

end

------------------------------------------------------------
-- Module
------------------------------------------------------------

return function(Window, meta)

    local Camera = Workspace.CurrentCamera

    local Tab = Window:CreateTab({
        Name = "Zone Farm",
        Icon = "🗺️",
        Order = (meta and meta.Order) or 80,
    })

    local Section = Tab:CreateSection({
        Name = "Farm Zones"
    })

    --------------------------------------------------------
    -- Markers folder (holds the point/line parts in the world)
    --------------------------------------------------------

    local MarkersFolder = Workspace:FindFirstChild("ZoneFarmMarkers")

    if not MarkersFolder then
        MarkersFolder = Instance.new("Folder")
        MarkersFolder.Name = "ZoneFarmMarkers"
        MarkersFolder.Parent = Workspace
    end

    --------------------------------------------------------
    -- State
    --------------------------------------------------------

    local CurrentPoints = {} -- array of Vector3

    local MapModeEnabled = false
    local PreviousCameraType = Camera.CameraType

    local CameraCenter = Vector3.new(0, 0, 0) -- X/Z only
    local BaseElevation = 0                    -- ground/world Y under CameraCenter, set on enable
    local CameraHeight = 60                    -- studs ABOVE BaseElevation, not an absolute world Y
    local MinHeight, MaxHeight = 15, 400

    local RightMouseHeld = false
    local AltHeld = false
    local CtrlHeld = false
    local DraggingIndex = nil

    local Connections = {}

    --------------------------------------------------------
    -- Camera
    --------------------------------------------------------

    local function UpdateCameraCFrame()

        local Position = Vector3.new(CameraCenter.X, BaseElevation + CameraHeight, CameraCenter.Z)
        local LookAt = Position - Vector3.new(0, 1, 0)

        -- straight top-down look: forward is parallel to the default (0,1,0) up
        -- vector, which makes CFrame.new's basis degenerate — give it an
        -- explicit, non-parallel up vector instead.
        Camera.CFrame = CFrame.lookAt(Position, LookAt, Vector3.new(0, 0, -1))

    end

    local function EnableMapMode()

        if MapModeEnabled then
            return
        end

        MapModeEnabled = true
        PreviousCameraType = Camera.CameraType
        Camera.CameraType = Enum.CameraType.Scriptable

        local Character = LocalPlayer.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")

        if Root then
            CameraCenter = Vector3.new(Root.Position.X, 0, Root.Position.Z)
            BaseElevation = Root.Position.Y
        end

        UpdateCameraCFrame()

    end

    local function DisableMapMode()

        if not MapModeEnabled then
            return
        end

        MapModeEnabled = false
        DraggingIndex = nil
        Camera.CameraType = PreviousCameraType or Enum.CameraType.Custom

    end

    --------------------------------------------------------
    -- Raycasting from mouse
    --------------------------------------------------------

    local function RaycastFromMouse()

        local MouseLocation = UserInputService:GetMouseLocation()
        local Ray = Camera:ViewportPointToRay(MouseLocation.X, MouseLocation.Y)

        local Params = RaycastParams.new()
        Params.FilterType = Enum.RaycastFilterType.Exclude
        Params.FilterDescendantsInstances = { MarkersFolder }

        local Result = Workspace:Raycast(Ray.Origin, Ray.Direction * 5000, Params)

        if Result then
            return Result.Position
        end

        return nil

    end

    local function FindNearestPointIndex(ScreenPos, ThresholdPixels)

        local BestIndex, BestDist = nil, ThresholdPixels

        for i, Point in ipairs(CurrentPoints) do

            local ScreenPoint, OnScreen = Camera:WorldToViewportPoint(Point)

            if OnScreen then

                local Dist = (Vector2.new(ScreenPoint.X, ScreenPoint.Y) - ScreenPos).Magnitude

                if Dist <= BestDist then
                    BestDist = Dist
                    BestIndex = i
                end

            end

        end

        return BestIndex

    end

    --------------------------------------------------------
    -- Drawing (points as spheres, connections as thin parts)
    --------------------------------------------------------

    local function CreatePointMarker(Position)

        local Part = Instance.new("Part")

        Part.Shape = Enum.PartType.Ball
        Part.Anchored = true
        Part.CanCollide = false
        Part.CanQuery = false
        Part.Material = Enum.Material.Neon
        Part.Color = Color3.fromRGB(255, 220, 0)
        Part.Size = Vector3.new(1, 1, 1)
        Part.CFrame = CFrame.new(Position)
        Part.Parent = MarkersFolder

        return Part

    end

    local function CreateLinePart(PointA, PointB, Color)

        local Distance = (PointA - PointB).Magnitude

        if Distance <= 0 then
            return nil
        end

        local Part = Instance.new("Part")

        Part.Anchored = true
        Part.CanCollide = false
        Part.CanQuery = false
        Part.Material = Enum.Material.Neon
        Part.Color = Color
        Part.Size = Vector3.new(0.3, 0.3, Distance)
        Part.CFrame = CFrame.new(PointA, PointB) * CFrame.new(0, 0, -Distance / 2)
        Part.Parent = MarkersFolder

        return Part

    end

    local function RedrawZone()

        MarkersFolder:ClearAllChildren()

        for i, Point in ipairs(CurrentPoints) do

            CreatePointMarker(Point)

            local NextPoint = CurrentPoints[i + 1]

            if NextPoint then
                CreateLinePart(Point, NextPoint, Color3.fromRGB(0, 200, 255))
            end

        end

    end

    local function UndoLastPoint()

        table.remove(CurrentPoints)
        RedrawZone()

    end

    --------------------------------------------------------
    -- Input handling
    --------------------------------------------------------

    table.insert(Connections, UserInputService.InputBegan:Connect(function(Input, Processed)

        if Input.KeyCode == Enum.KeyCode.LeftAlt or Input.KeyCode == Enum.KeyCode.RightAlt then
            AltHeld = true
        end

        if Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.RightControl then
            CtrlHeld = true
        end

        if Input.KeyCode == Enum.KeyCode.Z and CtrlHeld and MapModeEnabled then
            UndoLastPoint()
        end

        if not MapModeEnabled then
            return
        end

        if Input.UserInputType == Enum.UserInputType.MouseButton2 then

            -- no "not Processed" check here: Roblox's default camera
            -- controller sinks MouseButton2 for its own rotation even
            -- while CameraType is Scriptable, so Processed is ~always
            -- true for this button — checking it would block panning
            RightMouseHeld = true

        elseif Input.UserInputType == Enum.UserInputType.MouseButton1 and not Processed then

            if AltHeld then

                -- Left Alt + Left Click: grab an existing point to drag it
                local MouseLocation = UserInputService:GetMouseLocation()
                DraggingIndex = FindNearestPointIndex(MouseLocation, 16)

            else

                -- plain Left Click: drop a new point, auto-connected to the previous one
                local HitPosition = RaycastFromMouse()

                if HitPosition then
                    table.insert(CurrentPoints, HitPosition)
                    RedrawZone()
                end

            end

        end

    end))

    table.insert(Connections, UserInputService.InputChanged:Connect(function(Input, Processed)

        if not MapModeEnabled then
            return
        end

        if Input.UserInputType == Enum.UserInputType.MouseMovement then

            -- same reasoning as above: don't gate panning on Processed
            if RightMouseHeld then

                local Delta = Input.Delta
                local PanScale = CameraHeight * 0.0025

                CameraCenter = CameraCenter - Vector3.new(Delta.X, 0, Delta.Y) * PanScale
                UpdateCameraCFrame()

            end

            if DraggingIndex then

                local HitPosition = RaycastFromMouse()

                if HitPosition then
                    CurrentPoints[DraggingIndex] = HitPosition
                    RedrawZone()
                end

            end

        elseif Input.UserInputType == Enum.UserInputType.MouseWheel then

            local ZoomStep = 8

            CameraHeight = math.clamp(CameraHeight - Input.Position.Z * ZoomStep, MinHeight, MaxHeight)
            UpdateCameraCFrame()

        end

    end))

    table.insert(Connections, UserInputService.InputEnded:Connect(function(Input)

        if Input.KeyCode == Enum.KeyCode.LeftAlt or Input.KeyCode == Enum.KeyCode.RightAlt then
            AltHeld = false
        end

        if Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.RightControl then
            CtrlHeld = false
        end

        if Input.UserInputType == Enum.UserInputType.MouseButton2 then
            RightMouseHeld = false
        end

        if Input.UserInputType == Enum.UserInputType.MouseButton1 then
            DraggingIndex = nil
        end

    end))

    --------------------------------------------------------
    -- GUI
    --------------------------------------------------------

    Section:AddToggle({
        Text = "Map Mode",
        Default = false,
        Callback = function(Value)

            if Value then
                EnableMapMode()
            else
                DisableMapMode()
            end

        end
    })

    Section:AddButton({
        Text = "Undo Last Point (Ctrl+Z)",
        Callback = function()
            UndoLastPoint()
        end
    })

    Section:AddButton({
        Text = "Clear Points",
        Callback = function()

            CurrentPoints = {}
            RedrawZone()

        end
    })

    local NameBox

    local ZonesDropdown

    NameBox = Section:AddTextbox({
        Text = "Zone Name",
        Placeholder = "e.g. GoblinCamp",
        Callback = function()

        end
    })

    Section:AddButton({
        Text = "Save Zone",
        Callback = function()

            local Name = NameBox:GetValue()

            if #CurrentPoints < 2 then
                warn("[ZoneFarm] Need at least 2 points to save a zone")
                return
            end

            if ZoneStore.Save(Name, CurrentPoints) then
                ZonesDropdown:SetValues(ZoneStore.List())
            end

        end
    })

    ZonesDropdown = Section:AddDropdown({
        Text = "Saved Zones",
        Options = ZoneStore.List(),
        Callback = function()

        end
    })

    Section:AddButton({
        Text = "Load Zone",
        Callback = function()

            local Name = ZonesDropdown:GetValue()

            if not Name then
                warn("[ZoneFarm] No zone selected")
                return
            end

            local Points = ZoneStore.Load(Name)

            if Points then
                CurrentPoints = Points
                NameBox:SetValue(Name)
                RedrawZone()
            else
                warn("[ZoneFarm] Failed to load zone:", Name)
            end

        end
    })

    Section:AddButton({
        Text = "Refresh List",
        Callback = function()
            ZonesDropdown:SetValues(ZoneStore.List())
        end
    })

    Section:AddButton({
        Text = "Delete Zone",
        Callback = function()

            local Name = ZonesDropdown:GetValue()

            if Name and ZoneStore.Delete(Name) then
                ZonesDropdown:SetValues(ZoneStore.List())
            end

        end
    })

    --------------------------------------------------------
    -- Cleanup: leaving Map Mode / GUI destroy shouldn't leave the
    -- camera stuck in Scriptable mode or input hooks dangling.
    --------------------------------------------------------

    LocalPlayer.CharacterRemoving:Connect(function()

        DraggingIndex = nil

    end)

end
