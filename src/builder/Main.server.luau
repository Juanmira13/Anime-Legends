--!strict
-- Island Builder plugin. A panel to build the whole world or one area at a
-- time (terrain, sea, gameplay pieces and decoration), validate the map and
-- jump the camera through the screenshot spots of each area.
-- Install: rojo build builder.project.json --plugin AnimeLegendsBuilder.rbxm

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

if RunService:IsRunning() then
	return -- edit mode only
end

local Root = script.Parent
local Islands = require(Root.Shared.Data.Islands)
local AmbienceApply = require(Root.Shared.Map.AmbienceApply)
local MapScan = require(Root.Shared.Map.MapScan)
local IslandBuilder = require(Root.IslandBuilder)
local Registry = require(Root.Islands.Registry)
local RaidLobby = require(Root.RaidLobby)
local Sea = require(Root.Kit.Sea)

local busy = false
local photoIndex = 0

local toolbar = plugin:CreateToolbar("Anime Legends")
local toggle = toolbar:CreateButton("Island Builder", "Construir las islas, el mar y el lobby de Raids", "")
local widget = plugin:CreateDockWidgetPluginGuiAsync(
	"AnimeLegendsIslandBuilder",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Right, false, false, 260, 420, 220, 300)
)
widget.Title = "Island Builder"
toggle.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.fromScale(1, 1)
list.BackgroundColor3 = Color3.fromRGB(37, 37, 42)
list.BorderSizePixel = 0
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.ScrollBarThickness = 6
list.Parent = widget
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list
local padding = Instance.new("UIPadding")
padding.PaddingTop, padding.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
padding.Parent = list

local order = 0
local function addLabel(text: string): TextLabel
	order += 1
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, 36)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(200, 200, 210)
	label.Text = text
	label.Parent = list
	return label
end

local status = addLabel("Listo.")

local function setStatus(text: string)
	status.Text = text
	print(`[IslandBuilder] {text}`)
end

-- Runs a build step as one undoable change, one at a time.
local function run(name: string, action: () -> ())
	if busy then
		setStatus("Espera a que termine la construcción actual.")
		return
	end
	busy = true
	task.spawn(function()
		local recording = ChangeHistoryService:TryBeginRecording(name)
		local ok, message = pcall(action :: () -> any)
		if recording then
			ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
		end
		if not ok then
			setStatus(`Error: {message}`)
		end
		busy = false
	end)
end

-- Place-wide settings the islands rely on.
local function prepareWorld()
	-- Animated grass (Terrain.Decoration) can only be turned on in the Properties window.
	local decorationOk, decoration = pcall(function()
		return (workspace.Terrain :: any).Decoration
	end)
	if not decorationOk or decoration ~= true then
		print("[IslandBuilder] Para la hierba animada: Workspace → Terrain → Propiedades → activa Decoration.")
	end
	local ok = pcall(function()
		(Lighting :: any).Technology = Enum.Technology.Future
	end)
	if not ok then
		warn("[IslandBuilder] Activa a mano Lighting.Technology = Future (Studio no deja que el plugin lo cambie).")
	end
	-- The old test baseplate would cut through the sea.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate:Destroy()
		print("[IslandBuilder] Baseplate eliminado (el mar ocupa su lugar).")
	end
end

-- New players appear at the spawn location before the server moves them to
-- their island; keep it at the first island's arrival, invisible, so nobody
-- appears inside the terrain.
local function placeSpawnLocations()
	local map = workspace:FindFirstChild("Map")
	local first = map and map:FindFirstChild(Islands.List[1].id)
	local gameplay = first and first:FindFirstChild("Gameplay")
	local arrival = gameplay and gameplay:FindFirstChild("Arrival")
	if arrival == nil or not arrival:IsA("BasePart") then
		return
	end
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("SpawnLocation") then
			instance.CFrame = arrival.CFrame * CFrame.new(0, arrival.Size.Y / 2 + 0.5, 0)
			instance.Transparency = 1
			instance.CanCollide = false
			for _, decal in instance:GetChildren() do
				if decal:IsA("Decal") then
					decal.Transparency = 1
				end
			end
		end
	end
end

local function buildIsland(islandId: string)
	local definition = Registry[islandId]
	assert(definition, `No builder for {islandId}`)
	IslandBuilder.build(islandId, definition, setStatus)
	if islandId == Islands.List[1].id then
		placeSpawnLocations()
	end
end

local function addButton(text: string, color: Color3, onClick: () -> ())
	order += 1
	local button = Instance.new("TextButton")
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 32)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text
	button.Parent = list
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	button.MouseButton1Click:Connect(onClick)
end

local BUILD = Color3.fromRGB(60, 120, 200)
local ACTION = Color3.fromRGB(80, 80, 95)

addButton("Construir todo el mundo", Color3.fromRGB(40, 160, 110), function()
	run("Construir mundo", function()
		prepareWorld()
		Sea.buildOcean(IslandBuilder.areaFolder("Ocean"), setStatus)
		for _, island in Islands.List do
			buildIsland(island.id)
		end
		RaidLobby.build(setStatus)
		AmbienceApply.apply(Islands.List[1].id)
		MapScan.validate("[IslandBuilder]")
		setStatus("Mundo construido. Revisa la salida para el informe del validador.")
	end)
end)

for _, island in Islands.List do
	addButton(`Isla: {island.displayName}`, BUILD, function()
		run(`Construir {island.displayName}`, function()
			prepareWorld()
			buildIsland(island.id)
			AmbienceApply.apply(island.id)
		end)
	end)
end

addButton("Océano", BUILD, function()
	run("Construir océano", function()
		Sea.buildOcean(IslandBuilder.areaFolder("Ocean"), setStatus)
		setStatus("Océano listo.")
	end)
end)

addButton("Lobby de Raids", BUILD, function()
	run("Construir lobby de Raids", function()
		RaidLobby.build(setStatus)
		AmbienceApply.apply("RaidLobby")
	end)
end)

addButton("Validar mapa", ACTION, function()
	local ok = MapScan.validate("[IslandBuilder]")
	setStatus(if ok then "Mapa válido (ver salida)." else "El mapa tiene errores (ver salida).")
end)

-- Cycles the camera through every saved photo spot and applies its area's look.
addButton("Siguiente foto", ACTION, function()
	local spots: { CFrameValue } = {}
	local root = ServerStorage:FindFirstChild("PhotoSpots")
	if root then
		for _, area in root:GetChildren() do
			for _, value in area:GetChildren() do
				if value:IsA("CFrameValue") then
					table.insert(spots, value)
				end
			end
		end
	end
	if #spots == 0 then
		setStatus("No hay puntos de foto: construye una isla primero.")
		return
	end
	table.sort(spots, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)
	photoIndex = photoIndex % #spots + 1
	local spot = spots[photoIndex]
	local areaId = (spot.Parent :: Instance).Name
	AmbienceApply.apply(areaId)
	-- Studio's camera orbits its Focus; set both so the view stays as saved.
	local camera = workspace.CurrentCamera
	camera.CFrame = spot.Value
	camera.Focus = spot.Value * CFrame.new(0, 0, -40)
	setStatus(`Foto {photoIndex}/{#spots}: {areaId} {spot.Name}`)
end)

addLabel("Lo que pongas en Map.<Área>.Manual no se borra al reconstruir.")
