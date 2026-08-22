--!strict
-- +1 FART & FLY -- logika serwera.
--
-- Petla:
--   1. +1 FART co sekunde, zawsze. Strefa pod nogami mnozy to tempo.
--   2. Farty to XP: wbijaja POZIOM, a poziom podnosi SILE SKOKU.
--   3. Coraz mocniejszy skok siega coraz wyzszych pieter rury -- kazde pietro
--      to WIN, raz. Kazdy nowy metr rekordu wysokosci to SLAWA.
--   4. Strefy i DIETA sa zablokowane obiema walutami naraz.
--   5. DIETA kasuje postep za trwaly mnoznik tempa -- petla od nowa, szybciej.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Data)
local World = require(script.World)

type Session = {
	profile: Data.Profile,
	lastSave: number,
	level: number,
	-- Pozycja z poprzedniego ticku. WINY zbieramy jako przeciecie odcinka,
	-- nie jako trafienie w okno wokol pierscienia -- przy sile skoku 1400
	-- studow/s gracz mija cale pietro miedzy dwoma tickami.
	lastPosition: Vector3?,
}

local sessions: { [Player]: Session } = {}

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local rebirthRemote = makeRemote("Rebirth")
local notifyRemote = makeRemote("Notify")

--------------------------------------------------------------------------------
-- Pomocnicze
--------------------------------------------------------------------------------

-- Stan leci do klienta atrybutami: replikuja sie same, wiec HUD nie potrzebuje
-- wlasnego kanalu synchronizacji.
local function pushState(player: Player, session: Session)
	local profile = session.profile
	local level, into, needed = Config.levelFromFarts(profile.farts)
	session.level = level

	player:SetAttribute("Farts", math.floor(profile.farts))
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelProgress", into)
	player:SetAttribute("LevelNeeded", needed)
	player:SetAttribute("JumpPower", Config.jumpPower(level, profile.rebirths))
	player:SetAttribute("Wins", profile.wins)
	player:SetAttribute("TotalWins", profile.totalWins)
	player:SetAttribute("Fame", profile.fame)
	player:SetAttribute("TotalFame", profile.totalFame)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("BestHeight", profile.bestHeight)
	player:SetAttribute("BestFloor", profile.bestFloor)
	player:SetAttribute("Multiplier", Config.rebirthMultiplier(profile.rebirths))
	player:SetAttribute("RebirthWinCost", Config.rebirthWinCost(profile.rebirths))
	player:SetAttribute("RebirthFameCost", Config.rebirthFameCost(profile.rebirths))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local wins = stats:FindFirstChild("WINY") :: IntValue?
		local fame = stats:FindFirstChild("SLAWA") :: IntValue?
		local diet = stats:FindFirstChild("DIETA") :: IntValue?
		if wins then
			wins.Value = math.floor(math.min(profile.wins, 2 ^ 31 - 1))
		end
		if fame then
			fame.Value = math.floor(math.min(profile.fame, 2 ^ 31 - 1))
		end
		if diet then
			diet.Value = profile.rebirths
		end
	end
end

-- Strefa wymaga OBU walut naraz.
local function isZoneUnlocked(profile: Data.Profile, zone: Config.Zone): boolean
	return profile.totalWins >= zone.unlockWins and profile.totalFame >= zone.unlockFame
end

-- Ktora strefa jest pod graczem. Raycast w dol jest pewniejszy niz Touched --
-- nie gubi sie przy staniu w miejscu przez godziny.
local function zoneUnderCharacter(character: Model): Config.Zone?
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local result = workspace:Raycast(root.Position, Vector3.new(0, -Config.ZONE_RAY_LENGTH, 0), params)
	if not result then
		return nil
	end

	if not CollectionService:HasTag(result.Instance, World.ZONE_TAG) then
		return nil
	end

	local zoneId = result.Instance:GetAttribute("ZoneId")
	if typeof(zoneId) ~= "string" then
		return nil
	end
	return Config.zoneById(zoneId)
end

--------------------------------------------------------------------------------
-- Cykl zycia gracza
--------------------------------------------------------------------------------

local function grantOfflineFarts(player: Player, session: Session)
	local profile = session.profile

	local elapsed = math.clamp(os.time() - profile.lastSeen, 0, Config.OFFLINE_CAP_SECONDS)
	if elapsed < 60 then
		return
	end

	-- Offline liczymy po bazowym tempie: strefa dziala tylko gdy gracz na niej stoi.
	local rate = Config.BASE_FART_RATE * Config.rebirthMultiplier(profile.rebirths)
	local earned = math.floor(elapsed * rate)
	if earned <= 0 then
		return
	end

	profile.farts += earned
	notifyRemote:FireClient(player, "offline", earned, elapsed)
end

local function onPlayerAdded(player: Player)
	local profile = Data.load(player.UserId)
	local session: Session = { profile = profile, lastSave = os.clock(), level = 1, lastPosition = nil }
	sessions[player] = session

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	for _, name in { "WINY", "SLAWA", "DIETA" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end

	stats.Parent = player

	grantOfflineFarts(player, session)
	pushState(player, session)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	Data.save(player.UserId, session.profile)
end

--------------------------------------------------------------------------------
-- DIETA
--------------------------------------------------------------------------------

rebirthRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end

	local profile = session.profile
	local winCost = Config.rebirthWinCost(profile.rebirths)
	local fameCost = Config.rebirthFameCost(profile.rebirths)

	if profile.wins < winCost or profile.fame < fameCost then
		notifyRemote:FireClient(player, "rebirthTooPoor", winCost, fameCost)
		return
	end

	profile.wins -= winCost
	profile.fame -= fameCost
	profile.rebirths += 1
	profile.farts = 0
	profile.claimedFloors = {}

	pushState(player, session)
	notifyRemote:FireClient(player, "rebirth", profile.rebirths)

	if player.Character then
		player.Character:PivotTo(CFrame.new(0, 6, 44))
	end
end)

--------------------------------------------------------------------------------
-- Odbior WINOW z pieter
--------------------------------------------------------------------------------

local winPads: { Instance } = {}

local function refreshWinPads()
	winPads = CollectionService:GetTagged(World.WIN_TAG)
end

local function claimFloor(player: Player, session: Session, floor: number)
	local profile = session.profile
	local key = tostring(floor)
	if profile.claimedFloors[key] then
		return
	end

	profile.claimedFloors[key] = true

	local earned = math.floor(Config.winsForFloor(floor) * Config.rebirthMultiplier(profile.rebirths))
	profile.wins += earned
	profile.totalWins += earned
	profile.bestFloor = math.max(profile.bestFloor, floor)

	pushState(player, session)
	notifyRemote:FireClient(player, "win", earned, floor)
end

-- Czy odcinek from->to przebija plaszczyzne pierscienia wewnatrz jego promienia.
local function crossesRing(from: Vector3, to: Vector3, centerY: number, radius: number): boolean
	local dy = to.Y - from.Y
	local point: Vector3

	if math.abs(dy) < 1e-4 then
		-- Ruch praktycznie poziomy: wystarczy bliskosc plaszczyzny.
		if math.abs(from.Y - centerY) > Config.Tube.ledgeThickness * 2 then
			return false
		end
		point = to
	else
		local t = (centerY - from.Y) / dy
		if t < 0 or t > 1 then
			return false
		end
		point = from:Lerp(to, t)
	end

	return Vector3.new(point.X, 0, point.Z).Magnitude <= radius
end

local function checkWinPads(player: Player, session: Session, position: Vector3)
	local previous = session.lastPosition or position
	session.lastPosition = position

	for _, ring in winPads do
		if not ring:IsA("BasePart") then
			continue
		end
		local floor = ring:GetAttribute("Floor")
		if typeof(floor) ~= "number" then
			continue
		end
		if session.profile.claimedFloors[tostring(floor)] then
			continue
		end
		if crossesRing(previous, position, ring.Position.Y, Config.Tube.winRadius) then
			claimFloor(player, session, floor)
		end
	end
end

--------------------------------------------------------------------------------
-- SLAWA za rekord wysokosci
--------------------------------------------------------------------------------

local function grantFameForHeight(player: Player, session: Session, height: number)
	local profile = session.profile
	if height <= profile.bestHeight then
		return
	end

	local gained = height - profile.bestHeight
	profile.bestHeight = height

	local earned = math.floor(gained * Config.Fame.perStud * Config.rebirthMultiplier(profile.rebirths))
	if earned <= 0 then
		return
	end

	profile.fame += earned
	profile.totalFame += earned
end

--------------------------------------------------------------------------------
-- Petla glowna
--------------------------------------------------------------------------------

local accumulator = 0

RunService.Heartbeat:Connect(function(deltaTime)
	accumulator += deltaTime
	if accumulator < Config.FART_TICK then
		return
	end
	local step = accumulator
	accumulator = 0

	local now = os.clock()
	local topFloorNeeded = 0

	for player, session in sessions do
		local character = player.Character
		if not character then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end

		local profile = session.profile

		-- Naliczanie fartow. Baza leci zawsze; strefa jest tylko mnoznikiem.
		local zone = zoneUnderCharacter(character)
		local zoneMultiplier = 1
		local zoneName = ""
		local locked = false

		if zone then
			zoneName = zone.name
			if isZoneUnlocked(profile, zone) then
				zoneMultiplier = zone.multiplier
			else
				locked = true
			end
		end

		local rate = Config.BASE_FART_RATE * zoneMultiplier * Config.rebirthMultiplier(profile.rebirths)
		profile.farts += rate * step

		player:SetAttribute("Rate", rate)
		player:SetAttribute("ZoneName", zoneName)
		player:SetAttribute("ZoneLocked", locked)
		player:SetAttribute("ZoneMultiplier", zoneMultiplier)

		-- Wysokosc, SLAWA i pietra.
		local height = root.Position.Y
		player:SetAttribute("Height", height)

		grantFameForHeight(player, session, height)
		checkWinPads(player, session, root.Position)

		-- pushState przelicza poziom, wiec sila skoku aktualizuje sie sama.
		pushState(player, session)

		topFloorNeeded = math.max(topFloorNeeded, World.floorAtHeight(height) + Config.Tube.buildAheadFloors)

		-- Autosave
		if now - session.lastSave > Config.AUTOSAVE_INTERVAL then
			session.lastSave = now
			task.spawn(Data.save, player.UserId, profile)
		end
	end

	-- Rura ma nie miec konca: dobudowujemy pietra, zanim gracz dojdzie do szczytu.
	if topFloorNeeded > World.highestFloor() then
		World.ensureFloors(World.highestFloor() + Config.Tube.buildBatch)
		refreshWinPads()
	end
end)

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

workspace.Gravity = Config.GRAVITY

World.build()
refreshWinPads()
print(
	`[FartFly] swiat gotowy: {World.highestFloor()} pieter (pietro 1 na {Config.floorHeight(1)}, `
		.. `pietro {World.highestFloor()} na {math.floor(Config.floorHeight(World.highestFloor()))}), `
		.. `{#Config.Zones} stref, grawitacja {workspace.Gravity}, `
		.. `skok poziom 1 = {math.floor(Config.jumpHeight(Config.jumpPower(1)))} studow`
)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	for player, session in sessions do
		Data.save(player.UserId, session.profile)
	end
end)
