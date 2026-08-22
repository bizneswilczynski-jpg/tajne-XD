--!strict
-- Buduje mape z kodu, zeby projekt dzialal na pustym placu prosto po `rojo serve`.
-- Nic tutaj nie jest swiete -- docelowo stolowki i pierscienie moga byc
-- recznie postawionymi modelami, logika szuka ich po tagach/atrybutach.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local World = {}

World.FOOD_TAG = "FoodStation"
World.RING_TAG = "FartRing"

local SPAWN_SIZE = Vector3.new(90, 4, 60)

local function makeAnchored(className: string, parent: Instance): any
	local part = Instance.new(className)
	part.Anchored = true
	part.Parent = parent
	return part
end

local function label(parent: BasePart, text: string, offsetY: number): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(11, 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 220
	gui.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.TextScaled = true
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	textLabel.TextStrokeTransparency = 0.2
	textLabel.Text = text
	textLabel.Parent = gui

	return gui
end

local function buildSpawn(folder: Folder)
	local pad = makeAnchored("Part", folder) :: Part
	pad.Name = "SpawnPad"
	pad.Size = SPAWN_SIZE
	pad.Position = Vector3.new(0, -2, 0)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(70, 80, 95)
	pad.TopSurface = Enum.SurfaceType.Smooth

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 18)
	spawnLocation.Anchored = true
	spawnLocation.Color = Color3.fromRGB(120, 200, 120)
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = folder
end

-- Jedna stolowka: pad, na ktorym gracz stoi i je. To jest caly "AFK".
local function buildFoodStation(folder: Folder, food: Config.Food, index: number)
	local spacing = 16
	local originX = -((#Config.Foods - 1) * spacing) / 2

	local pad = makeAnchored("Part", folder) :: Part
	pad.Name = "Food_" .. food.id
	pad.Size = Vector3.new(12, 1, 12)
	pad.Position = Vector3.new(originX + (index - 1) * spacing, 0.5, -14)
	pad.Material = Enum.Material.Neon
	pad.Color = food.color
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.CanCollide = true

	pad:SetAttribute("FoodId", food.id)
	CollectionService:AddTag(pad, World.FOOD_TAG)

	local text = if food.unlockAt > 0
		then string.format("%s\n+%s GAZ/s\n🔒 %s SLAWY", food.name, Format.short(food.rate), Format.short(food.unlockAt))
		else string.format("%s\n+%s GAZ/s", food.name, Format.short(food.rate))

	local gui = label(pad, text, 6)
	gui.Name = "Info"
end

-- Pierscienie ustawione wykladniczo w gore -- kazdy kolejny wymaga
-- realnie wiekszego lotu, wiec sluza za widoczna miare postepu.
local function buildRings(folder: Folder)
	local height = Config.Rings.firstHeight

	for i = 1, Config.Rings.count do
		local ring = makeAnchored("Part", folder) :: Part
		ring.Name = "Ring_" .. i
		ring.Shape = Enum.PartType.Cylinder
		ring.Size = Vector3.new(1, Config.Rings.radius * 2, Config.Rings.radius * 2)
		ring.CFrame = CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromHSV((i / Config.Rings.count) % 1, 0.7, 1)
		ring.Transparency = 0.35
		ring.CanCollide = false
		ring.CanQuery = false

		ring:SetAttribute("RingIndex", i)
		CollectionService:AddTag(ring, World.RING_TAG)

		height = math.floor(height * Config.Rings.spacing)
	end
end

-- Tabliczki z nazwami pulapow, zeby lot mial punkty odniesienia.
local function buildAltitudeSigns(folder: Folder)
	for _, band in Config.Altitudes do
		if band.height <= 0 then
			continue
		end

		local sign = makeAnchored("Part", folder) :: Part
		sign.Name = "Altitude_" .. band.name
		sign.Size = Vector3.new(1, 1, 1)
		sign.Position = Vector3.new(26, band.height, 0)
		sign.Transparency = 1
		sign.CanCollide = false
		sign.CanQuery = false

		label(sign, string.format("%s  ·  %dm", band.name, band.height), 0)
	end
end

function World.build(): Folder
	local existing = Workspace:FindFirstChild("FartWorld")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "FartWorld"
	folder.Parent = Workspace

	buildSpawn(folder)
	for index, food in Config.Foods do
		buildFoodStation(folder, food, index)
	end
	buildRings(folder)
	buildAltitudeSigns(folder)

	return folder
end

return World
