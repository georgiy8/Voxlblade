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

function ZoneStore.Save(name, points, edges)

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

    local encodedEdges = {}

    for _, e in ipairs(edges or {}) do
        table.insert(encodedEdges, { A = e.A, B = e.B })
    end

    local payload = {
        Name = clean,
        Points = encodedPoints,
        Edges = encodedEdges,
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

    local edges = {}

    for _, e in ipairs(data.Edges or {}) do
        table.insert(edges, { A = e.A, B = e.B })
    end

    return points, edges

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
    local Edges = {}          -- array of { A = pointIndex, B = pointIndex }
    local History = {}        -- undo stack: { Type = "Point" } or { Type = "Edge" }
    local SelectedIndex = nil -- point picked with E+Click, waiting for its pair

    local MapModeEnabled = false
    local PreviousCameraType = Camera.CameraType

    local CameraCenter = Vector3.new(0, 0, 0) -- X/Z only
    local BaseElevation = 0                    -- ground/world Y under CameraCenter, set on enable
    local CameraHeight = 60                    -- studs ABOVE BaseElevation, not an absolute world Y
    local MinHeight, MaxHeight = 15, 400

    local RightMouseHeld = false
    local PanStartMouse = nil
    local PanStartCameraCenter = nil
    local EHeld = false
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

    local function CreatePointMarker(Position, IsSelected)

        local Part = Instance.new("Part")

        Part.Shape = Enum.PartType.Ball
        Part.Anchored = true
        Part.CanCollide = false
        Part.CanQuery = false
        Part.Material = Enum.Material.Neon
        Part.Color = IsSelected and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 220, 0)
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

    -- classic "two wedges make a triangle" technique, used for the
    -- flat fill shown once a zone is fully closed
    local function CreateFillTriangle(A, B, C, Color)

        local AB, AC, BC = B - A, C - A, C - B

        local ABLenSq, ACLenSq, BCLenSq = AB:Dot(AB), AC:Dot(AC), BC:Dot(BC)

        if ABLenSq > ACLenSq and ABLenSq > BCLenSq then
            A, C = C, A
        elseif ACLenSq > BCLenSq and ACLenSq > ABLenSq then
            A, B = B, A
        end

        AB, AC, BC = B - A, C - A, C - B

        local Right = AC:Cross(AB)

        if Right.Magnitude <= 0.001 then
            return -- degenerate (collinear) triangle, skip
        end

        Right = Right.Unit

        local Up = BC:Cross(Right).Unit
        local Back = BC.Unit

        local Height = math.abs(AB:Dot(Up))

        local function MakeWedge(P1, P2, Length)

            if Length <= 0.001 then
                return
            end

            local Wedge = Instance.new("WedgePart")

            Wedge.Anchored = true
            Wedge.CanCollide = false
            Wedge.CanQuery = false
            Wedge.Material = Enum.Material.Neon
            Wedge.Color = Color
            Wedge.Transparency = 0.5
            Wedge.Size = Vector3.new(0.05, Height, Length)
            Wedge.CFrame = CFrame.fromMatrix((P1 + P2) / 2, Right, Up, Back) * CFrame.new(0, 0, Length / 2)
            Wedge.Parent = MarkersFolder

        end

        MakeWedge(A, B, math.abs(AB:Dot(Back)))
        MakeWedge(A, C, math.abs(AC:Dot(Back)))

    end

    -- true only if Edges form a single simple cycle touching every point
    -- (every point has exactly 2 connections, and the graph is one piece)
    local function IsZoneClosed()

        local N = #CurrentPoints

        if N < 3 or #Edges ~= N then
            return false
        end

        local Degree = {}
        local Adjacency = {}

        for i = 1, N do
            Degree[i] = 0
            Adjacency[i] = {}
        end

        for _, Edge in ipairs(Edges) do
            Degree[Edge.A] = Degree[Edge.A] + 1
            Degree[Edge.B] = Degree[Edge.B] + 1
            table.insert(Adjacency[Edge.A], Edge.B)
            table.insert(Adjacency[Edge.B], Edge.A)
        end

        for i = 1, N do
            if Degree[i] ~= 2 then
                return false
            end
        end

        local Visited = { [1] = true }
        local Stack = { 1 }
        local VisitedCount = 1

        while #Stack > 0 do

            local Current = table.remove(Stack)

            for _, Neighbor in ipairs(Adjacency[Current]) do

                if not Visited[Neighbor] then
                    Visited[Neighbor] = true
                    VisitedCount = VisitedCount + 1
                    table.insert(Stack, Neighbor)
                end

            end

        end

        return VisitedCount == N

    end

    local function RedrawZone()

        MarkersFolder:ClearAllChildren()

        for i, Point in ipairs(CurrentPoints) do
            CreatePointMarker(Point, i == SelectedIndex)
        end

        for _, Edge in ipairs(Edges) do
            CreateLinePart(CurrentPoints[Edge.A], CurrentPoints[Edge.B], Color3.fromRGB(0, 200, 255))
        end

        if IsZoneClosed() then

            -- fan-triangulate from the centroid; works cleanly for convex
            -- zones and most simple concave ones, may look rough on very
            -- irregular star-shaped concave zones
            local Centroid = Vector3.new(0, 0, 0)

            for _, Point in ipairs(CurrentPoints) do
                Centroid = Centroid + Point
            end

            Centroid = Centroid / #CurrentPoints

            local FillColor = Color3.fromRGB(0, 255, 100)

            for _, Edge in ipairs(Edges) do
                CreateFillTriangle(Centroid, CurrentPoints[Edge.A], CurrentPoints[Edge.B], FillColor)
            end

        end

    end

    local function AddPoint(Position)

        table.insert(CurrentPoints, Position)
        table.insert(History, { Type = "Point" })
        RedrawZone()

    end

    local function EdgeExists(A, B)

        for _, Edge in ipairs(Edges) do
            if (Edge.A == A and Edge.B == B) or (Edge.A == B and Edge.B == A) then
                return true
            end
        end

        return false

    end

    local function ConnectPoints(A, B)

        if A == B or EdgeExists(A, B) then
            return
        end

        table.insert(Edges, { A = A, B = B })
        table.insert(History, { Type = "Edge" })
        RedrawZone()

    end

    local function Undo()

        local Last = table.remove(History)

        if not Last then
            return
        end

        if Last.Type == "Edge" then

            table.remove(Edges)

        elseif Last.Type == "Point" then

            local Index = #CurrentPoints

            -- guard: strip any edges still pointing at this point
            -- (shouldn't normally happen if undo order is respected)
            for i = #Edges, 1, -1 do
                if Edges[i].A == Index or Edges[i].B == Index then
                    table.remove(Edges, i)
                end
            end

            if SelectedIndex == Index then
                SelectedIndex = nil
            end

            table.remove(CurrentPoints)

        end

        RedrawZone()

    end

    --------------------------------------------------------
    -- Input handling
    --------------------------------------------------------

table.insert(Connections, UserInputService.InputBegan:Connect(function(Input, Processed)

    if Input.KeyCode == Enum.KeyCode.E then
        EHeld = true
    end

    if Input.KeyCode == Enum.KeyCode.LeftAlt or Input.KeyCode == Enum.KeyCode.RightAlt then
        AltHeld = true
    end

    if Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.RightControl then
        CtrlHeld = true
    end

    if Input.KeyCode == Enum.KeyCode.Z and CtrlHeld and MapModeEnabled then
        Undo()
    end

    if not MapModeEnabled then
        return
    end

    if Input.UserInputType == Enum.UserInputType.MouseButton1 then

        -- Alt + Left Click = move existing point
        if AltHeld then
            local MouseLocation = UserInputService:GetMouseLocation()
            DraggingIndex = FindNearestPointIndex(MouseLocation, 16)
            return
        end

        -- E + Left Click = select/connect points
        if EHeld then
            if Processed then
                return
            end

            local MouseLocation = UserInputService:GetMouseLocation()
            local Index = FindNearestPointIndex(MouseLocation, 16)

            if Index then
                if not SelectedIndex then
                    SelectedIndex = Index
                    RedrawZone()

                elseif SelectedIndex == Index then
                    SelectedIndex = nil
                    RedrawZone()

                else
                    ConnectPoints(SelectedIndex, Index)
                    SelectedIndex = nil
                    RedrawZone()
                end
            end

            return
        end

        -- Normal Left Click = add a point immediately.
        if not Processed then
            local HitPosition = RaycastFromMouse()

            if HitPosition then
                AddPoint(HitPosition)
            end
        end

    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then

        -- Right Mouse Button = pan the map.
        RightMouseHeld = true
        PanStartMouse = UserInputService:GetMouseLocation()
        PanStartCameraCenter = CameraCenter
    end

end))

    table.insert(Connections, UserInputService.InputChanged:Connect(function(Input, Processed)

    if not MapModeEnabled then
        return
    end

    if Input.UserInputType == Enum.UserInputType.MouseMovement then

        if RightMouseHeld and PanStartMouse and PanStartCameraCenter then
            local MouseLocation = UserInputService:GetMouseLocation()
            local Delta = MouseLocation - PanStartMouse

            local PanScale = CameraHeight * 0.0025

            CameraCenter =
                PanStartCameraCenter
                - Vector3.new(Delta.X, 0, Delta.Y) * PanScale

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

        CameraHeight = math.clamp(
            CameraHeight - Input.Position.Z * ZoomStep,
            MinHeight,
            MaxHeight
        )

        UpdateCameraCFrame()
    end

end))
    --------------------------------------------------------
    table.insert(Connections, UserInputService.InputEnded:Connect(function(Input)

        if Input.KeyCode == Enum.KeyCode.E then
            EHeld = false
        end

        if Input.KeyCode == Enum.KeyCode.LeftAlt or Input.KeyCode == Enum.KeyCode.RightAlt then
            AltHeld = false
        end

        if Input.KeyCode == Enum.KeyCode.LeftControl or Input.KeyCode == Enum.KeyCode.RightControl then
            CtrlHeld = false
        end

        if Input.UserInputType == Enum.UserInputType.MouseButton2 then
            RightMouseHeld = false
            PanStartMouse = nil
            PanStartCameraCenter = nil
        elseif Input.UserInputType == Enum.UserInputType.MouseButton1 then
            DraggingIndex = nil
        end

    end))

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
        Text = "Undo (Ctrl+Z)",
        Callback = function()
            Undo()
        end
    })

    Section:AddButton({
        Text = "Clear Points",
        Callback = function()

            CurrentPoints = {}
            Edges = {}
            History = {}
            SelectedIndex = nil
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

            if ZoneStore.Save(Name, CurrentPoints, Edges) then
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

            local Points, LoadedEdges = ZoneStore.Load(Name)

            if Points then
                CurrentPoints = Points
                Edges = LoadedEdges or {}
                History = {}
                SelectedIndex = nil
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
