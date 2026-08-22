--!strict
-- Buduje mape z kodu, zeby projekt dzialal na pustym placu prosto po `rojo serve`.
-- Nic tutaj nie jest swiete -- docelowo strefy i pietra moga byc recznie
-- postawionymi modelami, logika szuka ich po tagach/atrybutach.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local World = {}

World.ZONE_TAG = "SpeedZone"
World.WIN_TAG = "WinPad"

local SPAWN_SIZE = Vector3.new(120, 4, 120)

local tubeFolder: Folder? = nil
local highestFloor = 0

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
	gui.MaxDistance = 260
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

--------------------------------------------------------------------------------
-- Dol: spawn i strefy przyspieszajace
--------------------------------------------------------------------------------

local function buildSpawn(parent: Folder)
	local pad = makeAnchored("Part", parent) :: Part
	pad.Name = "SpawnPad"
	pad.Size = SPAWN_SIZE
	pad.Position = Vector3.new(0, -2, 0)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(70, 80, 95)
	pad.TopSurface = Enum.SurfaceType.Smooth

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Start"
	spawnLocation.Size = Vector3.new(12, 1, 12)
	spawnLocation.Position = Vector3.new(0, 0.5, 44)
	spawnLocation.Anchored = true
	spawnLocation.Color = Color3.fromRGB(120, 200, 120)
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = parent
end

-- Strefy stoja w luku wokol wlotu rury, zeby zadna nie zaslaniala srodka.
local function buildZone(parent: Folder, zone: Config.Zone, index: number, total: number)
	local spread = math.rad(210)
	local startAngle = math.rad(165)
	local angle = startAngle + (if total > 1 then (index - 1) / (total - 1) * spread else spread / 2)
	local distance = Config.Tube.radius + 22

	local pad = makeAnchored("Part", parent) :: Part
	pad.Name = "Zone_" .. zone.id
	pad.Size = Vector3.new(14, 1, 14)
	pad.Position = Vector3.new(math.cos(angle) * distance, 0.5, math.sin(angle) * distance)
	pad.Material = Enum.Material.Neon
	pad.Color = zone.color
	pad.TopSurface = Enum.SurfaceType.Smooth

	pad:SetAttribute("ZoneId", zone.id)
	CollectionService:AddTag(pad, World.ZONE_TAG)

	local locked = zone.unlockWins > 0 or zone.unlockFame > 0
	local text = if locked
		then string.format(
			"%s\nx%s tempa\nLOCK %s WIN + %s SLAWY",
			zone.name,
			Format.short(zone.multiplier),
			Format.short(zone.unlockWins),
			Format.short(zone.unlockFame)
		)
		else string.format("%s\nx%s tempa", zone.name, Format.short(zone.multiplier))

	label(pad, text, 6).Name = "Info"
end

--------------------------------------------------------------------------------
-- Rura
--------------------------------------------------------------------------------

-- Pietro sklada sie z dwoch rzeczy:
--   * pierscienia WIN na osi rury -- zbieranego W LOCIE, bez ladowania,
--   * polki przy scianie -- opcjonalnego miejsca na odpoczynek i kolejny skok.
-- Srodek rury zostaje przelotowy, wiec mocny skok moze minac wiele pieter naraz
-- i zebrac po drodze wszystkie WINY.
local function buildFloor(parent: Folder, floor: number)
	local tube = Config.Tube
	local height = Config.floorHeight(floor)
	local hue = (floor * 0.11) % 1

	local model = Instance.new("Folder")
	model.Name = "Floor_" .. floor
	model.Parent = parent

	-- Pierscien WIN: plaski dysk na osi, bez kolizji i bez udzialu w raycastach.
	local ring = makeAnchored("Part", model) :: Part
	ring.Name = "Win_" .. floor
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(1, tube.winRadius * 2, tube.winRadius * 2)
	ring.CFrame = CFrame.new(0, height, 0) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(250, 210, 90)
	ring.Transparency = 0.55
	ring.CanCollide = false
	ring.CanQuery = false

	ring:SetAttribute("Floor", floor)
	CollectionService:AddTag(ring, World.WIN_TAG)

	-- Polka do ladowania, co drugie pietro po przeciwnej stronie rury.
	local side = if floor % 2 == 0 then 1 else -1
	local ledge = makeAnchored("Part", model) :: Part
	ledge.Name = "Ledge"
	ledge.Size = Vector3.new(tube.ledgeWidth * 2, tube.ledgeThickness, tube.ledgeWidth * 2)
	ledge.Position = Vector3.new(side * (tube.radius - tube.ledgeWidth), height, 0)
	ledge.Material = Enum.Material.SmoothPlastic
	ledge.Color = Color3.fromHSV(hue, 0.45, 0.9)
	ledge.TopSurface = Enum.SurfaceType.Smooth

	label(ledge, string.format("PIETRO %d · %dm\n+%s WIN", floor, math.floor(height), Format.short(Config.winsForFloor(floor))), 6).Name =
		"Info"
end

-- Sciana rury na odcinku jednego pietra. Przezroczysta, zeby bylo widac swiat,
-- ale kolidujaca, zeby nie dalo sie wypasc bokiem.
local function buildWallSegment(parent: Folder, floor: number)
	local tube = Config.Tube
	local bottom = if floor == 1 then 0 else Config.floorHeight(floor - 1)
	local top = Config.floorHeight(floor)
	local height = top - bottom
	if height <= 0 then
		return
	end

	local model = Instance.new("Folder")
	model.Name = "Wall_" .. floor
	model.Parent = parent

	local wallRadius = tube.radius + tube.wallThickness / 2
	for i = 1, tube.wallSegments do
		local angle = (i - 1) / tube.wallSegments * math.pi * 2
		local segmentLength = 2 * math.pi * wallRadius / tube.wallSegments + 1

		local panel = makeAnchored("Part", model) :: Part
		panel.Name = "Panel"
		panel.Size = Vector3.new(tube.wallThickness, height, segmentLength)
		panel.CFrame = CFrame.new(math.cos(angle) * wallRadius, bottom + height / 2, math.sin(angle) * wallRadius)
			* CFrame.Angles(0, -angle, 0)
		panel.Material = Enum.Material.Glass
		panel.Color = Color3.fromRGB(150, 190, 230)
		panel.Transparency = tube.wallTransparency
		panel.CanQuery = false
		panel.CastShadow = false
	end
end

-- Dobudowuje pietra w gore. Wolane przy starcie i potem w miare wznoszenia sie
-- gracza -- dlatego rura nie ma konca.
function World.ensureFloors(upTo: number): number
	local parent = tubeFolder
	if not parent then
		return highestFloor
	end

	while highestFloor < upTo do
		highestFloor += 1
		buildWallSegment(parent, highestFloor)
		buildFloor(parent, highestFloor)
	end
	return highestFloor
end

function World.highestFloor(): number
	return highestFloor
end

-- Ktore pietro odpowiada danej wysokosci (0 = ponizej pierwszego).
function World.floorAtHeight(height: number): number
	return Config.floorAtHeight(height)
end

--------------------------------------------------------------------------------

function World.build(): Folder
	local existing = Workspace:FindFirstChild("FartWorld")
	if existing then
		existing:Destroy()
	end

	highestFloor = 0

	local root = Instance.new("Folder")
	root.Name = "FartWorld"
	root.Parent = Workspace

	buildSpawn(root)
	for index, zone in Config.Zones do
		buildZone(root, zone, index, #Config.Zones)
	end

	local tube = Instance.new("Folder")
	tube.Name = "Tube"
	tube.Parent = root
	tubeFolder = tube

	World.ensureFloors(Config.Tube.initialFloors)

	return root
end

return World
