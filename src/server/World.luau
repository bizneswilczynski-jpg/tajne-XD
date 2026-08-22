--!strict
-- Buduje mape z kodu, zeby projekt dzialal na pustym placu prosto po `rojo serve`.
-- Mapa to kwadratowy plac ze strefami i jedna pionowa LINIJKA bez konca.
-- Linijka ma kreski co Config.Map.markEvery metrow; kazda kreska to WIN.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local World = {}

World.ZONE_TAG = "SpeedZone"
World.MARK_TAG = "RulerMark"

-- true, jesli mape zastano gotowa w Workspace (a nie zbudowano jej z kodu).
World.adopted = false

local rulerFolder: Folder? = nil
local highestMark = 0

local function makeAnchored(className: string, parent: Instance): any
	local part = Instance.new(className)
	part.Anchored = true
	part.Parent = parent
	return part
end

local function label(parent: BasePart, text: string, offsetY: number, size: Vector2?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(if size then size.X else 11, if size then size.Y else 3)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
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
-- Plac
--------------------------------------------------------------------------------

local function buildPad(parent: Folder)
	local size = Config.Map.padSize

	local pad = makeAnchored("Part", parent) :: Part
	pad.Name = "Plac"
	pad.Size = Vector3.new(size, 4, size)
	pad.Position = Vector3.new(0, -2, 0)
	pad.Material = Enum.Material.SmoothPlastic
	pad.Color = Color3.fromRGB(96, 104, 118)
	pad.TopSurface = Enum.SurfaceType.Smooth

	-- Zielona obwodka dookola placu -- czysto po to, zeby bylo widac krawedz.
	local rimWidth = 10
	for i = 1, 4 do
		local horizontal = i <= 2
		local sign = if i % 2 == 0 then 1 else -1
		local rim = makeAnchored("Part", parent) :: Part
		rim.Name = "Krawedz"
		rim.Size = if horizontal
			then Vector3.new(size + rimWidth * 2, 4, rimWidth)
			else Vector3.new(rimWidth, 4, size + rimWidth * 2)
		rim.Position = if horizontal
			then Vector3.new(0, -2, sign * (size + rimWidth) / 2)
			else Vector3.new(sign * (size + rimWidth) / 2, -2, 0)
		rim.Material = Enum.Material.SmoothPlastic
		rim.Color = Color3.fromRGB(88, 200, 72)
		rim.TopSurface = Enum.SurfaceType.Smooth
	end

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "Start"
	spawnLocation.Size = Vector3.new(14, 1, 14)
	spawnLocation.Position = Vector3.new(0, 0.5, 40)
	spawnLocation.Anchored = true
	spawnLocation.Color = Color3.fromRGB(120, 200, 120)
	spawnLocation.TopSurface = Enum.SurfaceType.Smooth
	spawnLocation.Parent = parent
end

local function buildZone(parent: Folder, zone: Config.Zone, index: number, total: number)
	local spacing = 24
	local originX = -((total - 1) * spacing) / 2

	local pad = makeAnchored("Part", parent) :: Part
	pad.Name = "Zone_" .. zone.id
	pad.Size = Vector3.new(18, 1, 18)
	pad.Position = Vector3.new(originX + (index - 1) * spacing, 0.5, 58)
	pad.Material = Enum.Material.Neon
	pad.Color = zone.color
	pad.TopSurface = Enum.SurfaceType.Smooth

	pad:SetAttribute("ZoneId", zone.id)
	CollectionService:AddTag(pad, World.ZONE_TAG)

	local locked = zone.unlockWins > 0 or zone.unlockFame > 0
	local text = if locked
		then string.format(
			"%s\nx%s pierdow/s\nLOCK %s WIN + %s SLAWY",
			zone.name,
			Format.short(zone.multiplier),
			Format.short(zone.unlockWins),
			Format.short(zone.unlockFame)
		)
		else string.format("%s\nx%s pierdow/s", zone.name, Format.short(zone.multiplier))

	label(pad, text, 7).Name = "Info"
end

--------------------------------------------------------------------------------
-- Linijka
--------------------------------------------------------------------------------
-- Jeden segment na kazda kreske: kolorowy blok od poprzedniej kreski do tej,
-- z etykieta metrow i nagroda. Dokladnie jak podzialka na linijce.

local function buildMark(parent: Folder, mark: number)
	local map = Config.Map
	local top = Config.markHeight(mark)
	local bottom = Config.markHeight(mark - 1)
	local height = top - bottom

	local segment = makeAnchored("Part", parent) :: Part
	segment.Name = "Mark_" .. mark
	segment.Size = Vector3.new(map.rulerWidth, height, map.rulerDepth)
	segment.Position = Vector3.new(map.rulerX, bottom + height / 2, map.rulerZ)
	segment.Material = Enum.Material.SmoothPlastic
	-- Tecza w gore, zeby na pierwszy rzut oka bylo widac jak wysoko sie jest.
	segment.Color = Color3.fromHSV((mark * 0.045) % 1, 0.85, 1)
	segment.TopSurface = Enum.SurfaceType.Smooth
	segment.CanCollide = false
	segment.CanQuery = false

	segment:SetAttribute("Mark", mark)
	CollectionService:AddTag(segment, World.MARK_TAG)

	World.paintMark(segment, mark)
end

-- Napis LEZY na scianie bloku (SurfaceGui, nie BillboardGui), duzy i z grubym
-- czarnym obrysem -- ma sie czytac z daleka i z lotu. Malujemy obie strony,
-- zeby dzialalo niezaleznie z ktorej strony linijki gracz leci.
function World.paintMark(segment: BasePart, mark: number)
	local meters = math.floor(Config.markHeight(mark))
	local reward = Format.short(Config.winsForMark(mark))

	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local existing = segment:FindFirstChild("Info_" .. face.Name)
		if existing then
			existing:Destroy()
		end

		local gui = Instance.new("SurfaceGui")
		gui.Name = "Info_" .. face.Name
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		-- Nisko celowo: Roblox tnie skalowany tekst na 100 pikseli, wiec im gestsze
		-- plotno, tym mniejszy napis na scianie. 5 px/stud daje litery na ~20 studow.
		gui.PixelsPerStud = 5
		gui.LightInfluence = 0
		gui.Parent = segment

		local title = Instance.new("TextLabel")
		title.Name = "Meters"
		title.Size = UDim2.fromScale(0.92, 0.44)
		title.Position = UDim2.fromScale(0.04, 0.16)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Text = `{meters} m`
		title.Parent = gui

		local titleStroke = Instance.new("UIStroke")
		titleStroke.Thickness = 6
		titleStroke.Color = Color3.new(0, 0, 0)
		titleStroke.Parent = title

		local reward_label = Instance.new("TextLabel")
		reward_label.Name = "Reward"
		reward_label.Size = UDim2.fromScale(0.92, 0.2)
		reward_label.Position = UDim2.fromScale(0.04, 0.6)
		reward_label.BackgroundTransparency = 1
		reward_label.Font = Enum.Font.FredokaOne
		reward_label.TextScaled = true
		reward_label.TextColor3 = Color3.fromRGB(255, 233, 150)
		reward_label.Text = `+{reward} WIN`
		reward_label.Parent = gui

		local rewardStroke = Instance.new("UIStroke")
		rewardStroke.Thickness = 4
		rewardStroke.Color = Color3.new(0, 0, 0)
		rewardStroke.Parent = reward_label
	end
end

-- Dobudowuje kreski w gore. Wolane przy starcie i w miare wznoszenia sie gracza.
function World.ensureMarks(upTo: number): number
	local parent = rulerFolder
	if not parent then
		return highestMark
	end

	while highestMark < upTo do
		highestMark += 1
		buildMark(parent, highestMark)
	end
	return highestMark
end

function World.highestMark(): number
	return highestMark
end

--------------------------------------------------------------------------------

-- Mapa stoi w Workspace jako zwykle czesci, zeby dalo sie ja przestawiac
-- i malowac recznie w Studio. Ten kod jej NIE nadpisuje: jesli FartWorld juz
-- jest, tylko sie do niego podpina. Buduje od zera wylacznie wtedy, gdy mapy
-- nie ma -- czyli na pustym placu po samym `rojo serve`.
function World.build(): Folder
	local existing = Workspace:FindFirstChild("FartWorld")
	if existing and existing:IsA("Folder") then
		local ruler = existing:FindFirstChild("Linijka")
		if not ruler or not ruler:IsA("Folder") then
			local created = Instance.new("Folder")
			created.Name = "Linijka"
			created.Parent = existing
			ruler = created
		end
		rulerFolder = ruler :: Folder

		-- Odtwarzamy licznik z tego, co faktycznie stoi na mapie, zeby
		-- dobudowywanie ruszylo od wlasciwej kreski.
		highestMark = 0
		for _, child in (ruler :: Folder):GetChildren() do
			local mark = child:GetAttribute("Mark")
			if typeof(mark) == "number" then
				highestMark = math.max(highestMark, mark)
			end
		end

		World.ensureMarks(math.max(highestMark, Config.Map.initialMarks))
		World.adopted = true
		return existing
	end

	highestMark = 0

	local root = Instance.new("Folder")
	root.Name = "FartWorld"
	root.Parent = Workspace

	buildPad(root)
	for index, zone in Config.Zones do
		buildZone(root, zone, index, #Config.Zones)
	end

	local ruler = Instance.new("Folder")
	ruler.Name = "Linijka"
	ruler.Parent = root
	rulerFolder = ruler

	World.ensureMarks(Config.Map.initialMarks)

	World.adopted = false
	return root
end

return World
