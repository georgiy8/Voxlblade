-- Zone_redacted.lua
-- Universal Modular Utility / Voxlblade
-- World-space zone editor for autofarm.
-- JSON:
-- {
--   "Name": "...",
--   "Points": [{"X":..., "Y":..., "Z":...}],
--   "Edges": [{"A":1,"B":2}],
--   "FilledZones": [{"Points":[1,2,3,4],"Filled":true}]
-- }

return function(Window, meta)
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")
    local HttpService = game:GetService("HttpService")

    local LocalPlayer = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera

    local ROOT = "Universal-assets-by-gk/Configs/Profiles/Zones-autofarm"

    local MIN_CAMERA_HEIGHT = 15
    local MAX_CAMERA_HEIGHT = 500
    local POINT_PICK_RADIUS = 18
    local MARKER_SIZE = 1.6
    local LINE_THICKNESS = 0.25
    local FILL_HEIGHT = 0.12
    local FILL_TRANSPARENCY = 0.68

    local EditorEnabled = false
    local PreviousCameraType = nil
    local PreviousCameraCFrame = nil

    local CameraCenter = Vector3.zero
    local CameraHeight = 80
    local GroundY = 0

    local Points = {}
    local Edges = {}
    local FilledZones = {}
    local UndoStack = {}

    local DragIndex = nil
    local DragTargetIndex = nil
    local PreviewLine = nil

    local Connections = {}
    local MarkerFolder = nil

    local function connect(signal, callback)
        local c = signal:Connect(callback)
        table.insert(Connections, c)
        return c
    end

    local function ensureFolder()
        if not isfolder(ROOT) then
            makefolder(ROOT)
        end
    end

    local function safeName(name)
        name = tostring(name or "")
        name = name:gsub("[\\/:*?\"<>|]", "_")
        name = name:gsub("%s+$", "")
        name = name:gsub("%.+$", "")
        if name == "" then
            name = "Zone"
        end
        return name
    end

    local function fileNameFromPath(path)
        return tostring(path):match("([^/\\]+)$") or tostring(path)
    end

    local ZoneStore = {}

    function ZoneStore.List()
        ensureFolder()

        local result = {}
        if type(listfiles) ~= "function" then
            return result
        end

        for _, path in ipairs(listfiles(ROOT)) do
            local file = fileNameFromPath(path)
            if file:sub(-5):lower() == ".json" then
                table.insert(result, file:sub(1, -6))
            end
        end

        table.sort(result, function(a, b)
            return a:lower() < b:lower()
        end)

        return result
    end

    function ZoneStore.Save(name)
        ensureFolder()

        local data = {
            Name = name,
            Points = {},
            Edges = {},
            FilledZones = {}
        }

        for _, point in ipairs(Points) do
            table.insert(data.Points, {
                X = point.X,
                Y = point.Y,
                Z = point.Z
            })
        end

        for _, edge in ipairs(Edges) do
            table.insert(data.Edges, {
                A = edge.A,
                B = edge.B
            })
        end

        for _, zone in ipairs(FilledZones) do
            local zonePoints = {}
            for _, index in ipairs(zone.Points) do
                table.insert(zonePoints, index)
            end

            table.insert(data.FilledZones, {
                Points = zonePoints,
                Filled = true
            })
        end

        local path = ROOT .. "/" .. safeName(name) .. ".json"
        writefile(path, HttpService:JSONEncode(data))
        return true
    end

    function ZoneStore.Load(name)
        ensureFolder()

        local path = ROOT .. "/" .. safeName(name) .. ".json"
        if not isfile(path) then
            return false, "Zone file not found"
        end

        local ok, data = pcall(function()
            return HttpService:JSONDecode(readfile(path))
        end)

        if not ok or type(data) ~= "table" then
            return false, "Invalid JSON"
        end

        Points = {}
        Edges = {}
        FilledZones = {}
        UndoStack = {}

        for _, point in ipairs(data.Points or {}) do
            local x = tonumber(point.X)
            local y = tonumber(point.Y)
            local z = tonumber(point.Z)

            if x and y and z then
                table.insert(Points, Vector3.new(x, y, z))
            end
        end

        for _, edge in ipairs(data.Edges or {}) do
            local a = tonumber(edge.A)
            local b = tonumber(edge.B)

            if a and b and Points[a] and Points[b] and a ~= b then
                table.insert(Edges, {
                    A = a,
                    B = b
                })
            end
        end

        for _, zone in ipairs(data.FilledZones or {}) do
            if zone.Filled ~= false and type(zone.Points) == "table" then
                local valid = {}
                for _, index in ipairs(zone.Points) do
                    index = tonumber(index)
                    if index and Points[index] then
                        table.insert(valid, index)
                    end
                end

                if #valid >= 3 then
                    table.insert(FilledZones, {
                        Points = valid,
                        Filled = true
                    })
                end
            end
        end

        return true, data.Name or name
    end

    function ZoneStore.Delete(name)
        ensureFolder()

        local path = ROOT .. "/" .. safeName(name) .. ".json"
        if isfile(path) then
            delfile(path)
            return true
        end

        return false
    end

    local function edgeKey(a, b)
        if a > b then
            a, b = b, a
        end
        return tostring(a) .. ":" .. tostring(b)
    end

    local function edgeExists(a, b)
        local wanted = edgeKey(a, b)

        for _, edge in ipairs(Edges) do
            if edgeKey(edge.A, edge.B) == wanted then
                return true
            end
        end

        return false
    end

    local function addEdge(a, b)
        if not a or not b or a == b or edgeExists(a, b) then
            return false
        end

        table.insert(Edges, {
            A = a,
            B = b
        })

        return true
    end

    local function getNeighbors(index)
        local neighbors = {}

        for _, edge in ipairs(Edges) do
            if edge.A == index then
                table.insert(neighbors, edge.B)
            elseif edge.B == index then
                table.insert(neighbors, edge.A)
            end
        end

        return neighbors
    end

    -- Finds all simple closed polygons in the graph.
    -- Duplicate/reversed cycles are removed by canonicalizing their edge set.
    local function detectFilledZones()
        local found = {}
        local seen = {}

        local function cycleKey(cycle)
            local keys = {}

            for i = 1, #cycle do
                local a = cycle[i]
                local b = cycle[i % #cycle + 1]
                table.insert(keys, edgeKey(a, b))
            end

            table.sort(keys)
            return table.concat(keys, "|")
        end

        local function dfs(start, current, path, used)
            for _, nextIndex in ipairs(getNeighbors(current)) do
                if nextIndex == start and #path >= 3 then
                    local key = cycleKey(path)
                    if not seen[key] then
                        seen[key] = true
                        table.insert(found, {
                            Points = table.clone(path),
                            Filled = true
                        })
                    end
                elseif not used[nextIndex] and nextIndex >= start then
                    used[nextIndex] = true
                    table.insert(path, nextIndex)

                    -- Prevent runaway searches on large graphs.
                    if #path <= math.min(#Points, 40) then
                        dfs(start, nextIndex, path, used)
                    end

                    table.remove(path)
                    used[nextIndex] = nil
                end
            end
        end

        for start = 1, #Points do
            dfs(start, start, {start}, {[start] = true})
        end

        -- Keep only the smallest useful cycles when multiple nested cycles
        -- describe the same connected area. All explicitly detected closed
        -- polygons remain valid zones; this does not alter Points/Edges.
        table.sort(found, function(a, b)
            return #a.Points < #b.Points
        end)

        return found
    end

    local function polygonPoints(zone)
        local result = {}

        for _, index in ipairs(zone.Points) do
            if Points[index] then
                table.insert(result, Points[index])
            end
        end

        return result
    end

    local function polygonCenter(points)
        local center = Vector3.zero

        for _, point in ipairs(points) do
            center += point
        end

        if #points == 0 then
            return Vector3.zero
        end

        return center / #points
    end

    -- Ear clipping triangulation on the X/Z plane.
    -- This lets the editor fill arbitrary simple polygons instead of only
    -- rectangles/triangles.
    local function triangulate(points)
        local vertices = {}

        for i, point in ipairs(points) do
            vertices[i] = {
                point = point,
                index = i,
                x = point.X,
                z = point.Z
            }
        end

        if #vertices < 3 then
            return {}
        end

        local area = 0
        for i = 1, #vertices do
            local a = vertices[i]
            local b = vertices[i % #vertices + 1]
            area += a.x * b.z - b.x * a.z
        end

        local ccw = area > 0
        local triangles = {}

        local function cross(a, b, c)
            return (b.x - a.x) * (c.z - a.z)
                - (b.z - a.z) * (c.x - a.x)
        end

        local function pointInTriangle(p, a, b, c)
            local c1 = cross(p, a, b)
            local c2 = cross(p, b, c)
            local c3 = cross(p, c, a)

            local hasNeg = c1 < 0 or c2 < 0 or c3 < 0
            local hasPos = c1 > 0 or c2 > 0 or c3 > 0

            return not (hasNeg and hasPos)
        end

        local guard = 0

        while #vertices >= 3 and guard < 10000 do
            guard += 1
            local earFound = false

            for i = 1, #vertices do
                local prev = vertices[(i - 2) % #vertices + 1]
                local current = vertices[i]
                local next = vertices[i % #vertices + 1]

                local c = cross(prev, current, next)
                local convex = ccw and c > 0 or (not ccw and c < 0)

                if convex then
                    local blocked = false

                    for j = 1, #vertices do
                        if j ~= i
                            and j ~= ((i - 2) % #vertices + 1)
                            and j ~= (i % #vertices + 1)
                        then
                            if pointInTriangle(vertices[j], prev, current, next) then
                                blocked = true
                                break
                            end
                        end
                    end

                    if not blocked then
                        table.insert(triangles, {
                            prev.point,
                            current.point,
                            next.point
                        })

                        table.remove(vertices, i)
                        earFound = true
                        break
                    end
                end
            end

            if not earFound then
                break
            end
        end

        return triangles
    end

    local function makePart(parent, name)
        local part = Instance.new("Part")
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Material = Enum.Material.Neon
        part.Parent = parent
        return part
    end

    local function drawLine(parent, a, b, name)
        local delta = b - a
        local length = delta.Magnitude

        if length < 0.001 then
            return
        end

        local part = makePart(parent, name)
        part.Size = Vector3.new(LINE_THICKNESS, LINE_THICKNESS, length)
        part.CFrame = CFrame.lookAt((a + b) / 2, b)
        part.Color = Color3.fromRGB(255, 255, 255)

        return part
    end

    local function drawTriangle(parent, a, b, c, name)
        local center = (a + b + c) / 3
        local ab = b - a
        local ac = c - a

        local normal = ab:Cross(ac)
        if normal.Magnitude < 0.001 then
            return
        end

        normal = normal.Unit

        local xAxis = ab.Unit
        local zAxis = xAxis:Cross(normal).Unit

        local xLength = ab.Magnitude
        local zLength = math.abs(ac:Dot(zAxis))

        if xLength < 0.001 or zLength < 0.001 then
            return
        end

        local part = makePart(parent, name)
        part.Material = Enum.Material.ForceField
        part.Transparency = FILL_TRANSPARENCY
        part.Color = Color3.fromRGB(0, 255, 0)
        part.Size = Vector3.new(xLength, FILL_HEIGHT, zLength)

        part.CFrame =
            CFrame.fromMatrix(
                center + Vector3.new(0, FILL_HEIGHT / 2, 0),
                xAxis,
                normal,
                zAxis
            )

        -- A triangle is represented by a thin rectangular surface.
        -- Keep the center part small; the actual polygon shape is determined
        -- by the triangulation and the autofarm uses FilledZones from JSON.
        part:SetAttribute("ZoneTriangle", true)

        return part
    end

    local function rebuildFilledZones()
        FilledZones = detectFilledZones()
    end

    local function redraw()
        if MarkerFolder then
            MarkerFolder:Destroy()
        end

        MarkerFolder = Instance.new("Folder")
        MarkerFolder.Name = "ZoneEditorMarkers"
        MarkerFolder.Parent = Workspace

        for index, point in ipairs(Points) do
            local marker = makePart(MarkerFolder, "Point_" .. index)
            marker.Shape = Enum.PartType.Ball
            marker.Size = Vector3.new(MARKER_SIZE, MARKER_SIZE, MARKER_SIZE)
            marker.Position = point + Vector3.new(0, 0.8, 0)
            marker.Color = Color3.fromRGB(255, 255, 255)
            marker:SetAttribute("ZonePointIndex", index)
        end

        for index, edge in ipairs(Edges) do
            local a = Points[edge.A]
            local b = Points[edge.B]

            if a and b then
                drawLine(
                    MarkerFolder,
                    a + Vector3.new(0, 0.35, 0),
                    b + Vector3.new(0, 0.35, 0),
                    "Edge_" .. index
                )
            end
        end

        for zoneIndex, zone in ipairs(FilledZones) do
            local polygon = polygonPoints(zone)

            if #polygon >= 3 then
                local triangles = triangulate(polygon)

                for triangleIndex, triangle in ipairs(triangles) do
                    drawTriangle(
                        MarkerFolder,
                        triangle[1] + Vector3.new(0, 0.18, 0),
                        triangle[2] + Vector3.new(0, 0.18, 0),
                        triangle[3] + Vector3.new(0, 0.18, 0),
                        "Fill_" .. zoneIndex .. "_" .. triangleIndex
                    )
                end
            end
        end
    end

    local function getMapRay()
        local mouse = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {
            MarkerFolder,
            LocalPlayer.Character
        }

        return Workspace:Raycast(ray.Origin, ray.Direction * 5000, params)
    end

    local function getWorldPoint()
        local result = getMapRay()

        if result then
            return result.Position
        end

        -- Fallback to an infinite horizontal plane at GroundY.
        local mouse = UserInputService:GetMouseLocation()
        local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)

        if math.abs(ray.Direction.Y) > 0.0001 then
            local t = (GroundY - ray.Origin.Y) / ray.Direction.Y
            if t > 0 then
                return ray.Origin + ray.Direction * t
            end
        end

        return nil
    end

    local function screenDistance(worldPoint)
        local screen, visible = Camera:WorldToViewportPoint(worldPoint)

        if not visible then
            return math.huge
        end

        local mouse = UserInputService:GetMouseLocation()
        return (Vector2.new(screen.X, screen.Y) - mouse).Magnitude
    end

    local function getNearestPoint()
        local bestIndex = nil
        local bestDistance = POINT_PICK_RADIUS

        for index, point in ipairs(Points) do
            local distance = screenDistance(point)

            if distance < bestDistance then
                bestDistance = distance
                bestIndex = index
            end
        end

        return bestIndex
    end

    local function createPreviewLine()
        if PreviewLine then
            PreviewLine:Destroy()
            PreviewLine = nil
        end

        PreviewLine = makePart(MarkerFolder, "PreviewLine")
        PreviewLine.Color = Color3.fromRGB(255, 255, 0)
        PreviewLine.Transparency = 0.15
    end

    local function updatePreviewLine(target)
        if not DragIndex or not PreviewLine then
            return
        end

        local startPoint = Points[DragIndex]
        if not startPoint then
            return
        end

        local endPoint = target
        if not endPoint then
            return
        end

        local delta = endPoint - startPoint
        local length = delta.Magnitude

        if length < 0.001 then
            PreviewLine.Transparency = 1
            return
        end

        PreviewLine.Transparency = 0.15
        PreviewLine.Size = Vector3.new(
            LINE_THICKNESS * 1.5,
            LINE_THICKNESS * 1.5,
            length
        )
        PreviewLine.CFrame = CFrame.lookAt(
            (startPoint + endPoint) / 2,
            endPoint
        )
    end

    local function pushUndo(action)
        table.insert(UndoStack, action)

        if #UndoStack > 100 then
            table.remove(UndoStack, 1)
        end
    end

    local function addPoint(point)
        table.insert(Points, point)

        pushUndo({
            Type = "Point",
            Index = #Points
        })

        rebuildFilledZones()
        redraw()
    end

    local function connectPoints(a, b)
        if addEdge(a, b) then
            pushUndo({
                Type = "Edge",
                A = a,
                B = b
            })

            rebuildFilledZones()
            redraw()
        end
    end

    local function undo()
        local action = table.remove(UndoStack)

        if not action then
            return
        end

        if action.Type == "Edge" then
            for i = #Edges, 1, -1 do
                local edge = Edges[i]
                if edgeKey(edge.A, edge.B) == edgeKey(action.A, action.B) then
                    table.remove(Edges, i)
                    break
                end
            end
        elseif action.Type == "Point" then
            local index = action.Index

            for i = #Edges, 1, -1 do
                if Edges[i].A == index or Edges[i].B == index then
                    table.remove(Edges, i)
                end
            end

            if Points[index] then
                table.remove(Points, index)

                -- Re-index all edges after point removal.
                for _, edge in ipairs(Edges) do
                    if edge.A > index then
                        edge.A -= 1
                    end

                    if edge.B > index then
                        edge.B -= 1
                    end
                end
            end
        end

        rebuildFilledZones()
        redraw()
    end

    local function clearAll()
        Points = {}
        Edges = {}
        FilledZones = {}
        UndoStack = {}
        DragIndex = nil
        DragTargetIndex = nil

        if PreviewLine then
            PreviewLine:Destroy()
            PreviewLine = nil
        end

        redraw()
    end

    local function updateCamera()
        Camera.CFrame = CFrame.lookAt(
            Vector3.new(CameraCenter.X, CameraCenter.Y + CameraHeight, CameraCenter.Z),
            Vector3.new(CameraCenter.X, CameraCenter.Y, CameraCenter.Z),
            Vector3.new(0, 0, -1)
        )
    end

    local function enterEditor()
        if EditorEnabled then
            return
        end

        EditorEnabled = true
        PreviousCameraType = Camera.CameraType
        PreviousCameraCFrame = Camera.CFrame

        local character = LocalPlayer.Character
        local root = character and character:FindFirstChild("HumanoidRootPart")

        if root then
            CameraCenter = Vector3.new(root.Position.X, 0, root.Position.Z)
            GroundY = root.Position.Y
            CameraCenter = Vector3.new(CameraCenter.X, GroundY, CameraCenter.Z)
        else
            CameraCenter = Vector3.new(0, GroundY, 0)
        end

        Camera.CameraType = Enum.CameraType.Scriptable
        updateCamera()
        redraw()
    end

    local function exitEditor()
        if not EditorEnabled then
            return
        end

        EditorEnabled = false
        DragIndex = nil
        DragTargetIndex = nil

        if PreviewLine then
            PreviewLine:Destroy()
            PreviewLine = nil
        end

        if PreviousCameraType then
            Camera.CameraType = PreviousCameraType
        else
            Camera.CameraType = Enum.CameraType.Custom
        end

        if PreviousCameraCFrame then
            Camera.CFrame = PreviousCameraCFrame
        end
    end

    -- RMB pan.
    local Panning = false
    local LastMousePosition = nil

    local function panCamera(currentMouse)
        if not LastMousePosition then
            LastMousePosition = currentMouse
            return
        end

        local delta = currentMouse - LastMousePosition
        LastMousePosition = currentMouse

        if delta.Magnitude <= 0 then
            return
        end

        local scale = CameraHeight / math.max(Camera.ViewportSize.Y, 1)

        CameraCenter += Vector3.new(
            -delta.X * scale,
            0,
            delta.Y * scale
        )

        updateCamera()
    end

    connect(UserInputService.InputBegan, function(input, processed)
        if processed or not EditorEnabled then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            Panning = true
            LastMousePosition = UserInputService:GetMouseLocation()
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then
                local point = getWorldPoint()

                if point then
                    GroundY = point.Y
                    addPoint(Vector3.new(point.X, GroundY, point.Z))
                end

                return
            end

            local index = getNearestPoint()

            if index then
                DragIndex = index
                DragTargetIndex = nil
                createPreviewLine()
            end
        end
    end)

    connect(UserInputService.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then
            Panning = false
            LastMousePosition = nil
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if DragIndex then
                if DragTargetIndex and DragTargetIndex ~= DragIndex then
                    connectPoints(DragIndex, DragTargetIndex)
                end
            end

            DragIndex = nil
            DragTargetIndex = nil

            if PreviewLine then
                PreviewLine:Destroy()
                PreviewLine = nil
            end
        end
    end)

    connect(UserInputService.InputChanged, function(input)
        if not EditorEnabled then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseWheel then
            CameraHeight = math.clamp(
                CameraHeight - input.Position.Z * CameraHeight * 0.12,
                MIN_CAMERA_HEIGHT,
                MAX_CAMERA_HEIGHT
            )

            updateCamera()
        end
    end)

    connect(RunService.RenderStepped, function()
        if not EditorEnabled then
            return
        end

        if Panning then
            panCamera(UserInputService:GetMouseLocation())
        end

        if DragIndex then
            local nearest = getNearestPoint()

            if nearest and nearest ~= DragIndex then
                DragTargetIndex = nearest
                updatePreviewLine(Points[nearest])
            else
                DragTargetIndex = nil
                updatePreviewLine(getWorldPoint())
            end
        end
    end)

    local Main = Window:CreateTab({
        Name = "Map",
        Icon = "🗺️",
        Order = meta and meta.Order or 15
    })

    local EditorSection = Main:CreateSection({
        Name = "Editor"
    })

    EditorSection:AddToggle({
        Name = "Map Editor",
        CurrentValue = false,
        Callback = function(value)
            if value then
                enterEditor()
            else
                exitEditor()
            end
        end
    })

    EditorSection:AddButton({
        Name = "Undo",
        Callback = function()
            undo()
        end
    })

    EditorSection:AddButton({
        Name = "Clear",
        Callback = function()
            clearAll()
        end
    })

    local StorageSection = Main:CreateSection({
        Name = "Zone Storage"
    })

    local NameBox = StorageSection:AddTextbox({
        Name = "Zone Name",
        PlaceholderText = "Farm zone name",
        Text = "Zone",
        Callback = function()
        end
    })

    local SavedZones = StorageSection:AddDropdown({
        Name = "Saved Zones",
        Options = ZoneStore.List(),
        CurrentOption = nil,
        Callback = function()
        end
    })

    local function getZoneName()
        local value = NameBox:GetValue()
        if value == nil or tostring(value):match("^%s*$") then
            return "Zone"
        end

        return tostring(value)
    end

    local function refreshZones()
        SavedZones:SetValues(ZoneStore.List())
    end

    StorageSection:AddButton({
        Name = "Save Zone",
        Callback = function()
            local name = getZoneName()

            if #Points < 3 then
                warn("[Zone Editor] Need at least 3 points.")
                return
            end

            rebuildFilledZones()

            if #FilledZones == 0 then
                warn("[Zone Editor] No closed zone found.")
                return
            end

            ZoneStore.Save(name)
            refreshZones()
        end
    })

    StorageSection:AddButton({
        Name = "Load Zone",
        Callback = function()
            local selected = SavedZones:GetValue()

            if type(selected) == "table" then
                selected = selected[1]
            end

            if not selected or tostring(selected) == "" then
                return
            end

            local ok, loadedName = ZoneStore.Load(selected)

            if ok then
                NameBox:SetValue(loadedName or selected)
                rebuildFilledZones()
                redraw()
            else
                warn("[Zone Editor] Failed to load zone:", loadedName)
            end
        end
    })

    StorageSection:AddButton({
        Name = "Refresh List",
        Callback = function()
            refreshZones()
        end
    })

    StorageSection:AddButton({
        Name = "Delete Zone",
        Callback = function()
            local selected = SavedZones:GetValue()

            if type(selected) == "table" then
                selected = selected[1]
            end

            if selected and tostring(selected) ~= "" then
                ZoneStore.Delete(selected)
                refreshZones()
            end
        end
    })

    local InfoSection = Main:CreateSection({
        Name = "Controls"
    })

    InfoSection:AddLabel({
        Text = "RMB + Mouse = Pan"
    })

    InfoSection:AddLabel({
        Text = "Wheel = Zoom"
    })

    InfoSection:AddLabel({
        Text = "E + LMB = Point"
    })

    InfoSection:AddLabel({
        Text = "LMB Point -> Point = Line"
    })

    InfoSection:AddLabel({
        Text = "Closed shapes = Green Fill"
    })

    -- Recalculate fill after loading or when the graph changes.
    rebuildFilledZones()
    redraw()

    local Cleanup = {}

    function Cleanup:Destroy()
        exitEditor()

        if MarkerFolder then
            MarkerFolder:Destroy()
            MarkerFolder = nil
        end

        for _, connection in ipairs(Connections) do
            pcall(function()
                connection:Disconnect()
            end)
        end

        Connections = {}
    end

    -- Expose useful data for an eventual autofarm module without making the
    -- autofarm depend on editor UI objects.
    Window.ZoneEditor = {
        GetPoints = function()
            return Points
        end,

        GetEdges = function()
            return Edges
        end,

        GetFilledZones = function()
            return FilledZones
        end,

        Save = function(name)
            rebuildFilledZones()
            return ZoneStore.Save(name)
        end,

        Load = function(name)
            local ok, result = ZoneStore.Load(name)
            if ok then
                rebuildFilledZones()
                redraw()
            end
            return ok, result
        end,

        Destroy = function()
            Cleanup:Destroy()
        end
    }

    return Cleanup
end

