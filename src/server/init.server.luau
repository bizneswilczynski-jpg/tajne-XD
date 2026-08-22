--!strict
-- +1 FART & FLY -- logika serwera.
--
-- Petla:
--   1. SPACJA = jeden pierd, ktory wyrzuca postac w gore. Takze w powietrzu.
--   2. Kazdy pierd to XP, XP wbija poziom, poziom dokłada JEDEN pierd do zapasu.
--   3. Pierdy odnawiaja sie w czasie; strefa pod nogami przyspiesza odnawianie.
--   4. Kreski na linijce daja WINY (raz kazda), rekord wysokosci daje SLAWE.
--   5. DIETA kasuje postep za trwaly mnoznik -- petla od nowa, szybciej.

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
	lastFart: number,
	level: number,
	-- Mnoznik XP zapamietany w chwili startu z ziemi -- obowiazuje do ladowania.
	launchMultiplier: number,
	-- Mnoznik strefy, na ktorej gracz aktualnie stoi (1 poza strefami).
	zoneMultiplier: number,
	-- Pozycja z poprzedniego ticku. Kreski zaliczamy jako przeciecie odcinka:
	-- przy duzej predkosci gracz mija kreske miedzy dwoma tickami.
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

-- Klient prosi o pierd; serwer odsyla zgode wraz z sila.
local fartRemote = makeRemote("Fart")
local blastRemote = makeRemote("Blast")
local rebirthRemote = makeRemote("Rebirth")
local notifyRemote = makeRemote("Notify")

--------------------------------------------------------------------------------
-- Pomocnicze
--------------------------------------------------------------------------------

local function pushState(player: Player, session: Session)
	local profile = session.profile
	local level, into, needed = Config.levelFromXP(profile.xp)
	session.level = level

	player:SetAttribute("Farts", math.floor(profile.farts))
	player:SetAttribute("MaxFarts", Config.maxFarts(level))
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelProgress", into)
	player:SetAttribute("LevelNeeded", needed)
	player:SetAttribute("Wins", profile.wins)
	player:SetAttribute("Fame", profile.fame)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("BestHeight", profile.bestHeight)
	player:SetAttribute("BestMark", profile.bestMark)
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

local function isZoneUnlocked(profile: Data.Profile, zone: Config.Zone): boolean
	return profile.totalWins >= zone.unlockWins and profile.totalFame >= zone.unlockFame
end

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
	if not result or not CollectionService:HasTag(result.Instance, World.ZONE_TAG) then
		return nil
	end

	local zoneId = result.Instance:GetAttribute("ZoneId")
	if typeof(zoneId) ~= "string" then
		return nil
	end
	return Config.zoneById(zoneId)
end

local function isOnGround(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
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

	local level = Config.levelFromXP(profile.xp)
	local maxFarts = Config.maxFarts(level)
	if profile.farts >= maxFarts then
		return
	end

	profile.farts = maxFarts
	notifyRemote:FireClient(player, "offline", elapsed)
end

local function onPlayerAdded(player: Player)
	local profile = Data.load(player.UserId)
	local session: Session = {
		profile = profile,
		lastSave = os.clock(),
		lastFart = 0,
		level = 1,
		launchMultiplier = 1,
		zoneMultiplier = 1,
		lastPosition = nil,
	}
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
-- Pierd
--------------------------------------------------------------------------------
-- Serwer jest sedzia: sprawdza zapas i cooldown, zdejmuje pierd, dolicza XP
-- i odsyla zgode. Sam impuls zadaje KLIENT -- postac ma sieciowego wlasciciela
-- po jego stronie, wiec predkosc ustawiona z serwera jest kasowana przy
-- najblizszej replikacji fizyki (zmierzone: 300 studow/s z serwera daje
-- 4 study wzniosu, te same 300 z klienta daje 374).

local function tryFart(player: Player, session: Session)
	local profile = session.profile

	local now = os.clock()
	if now - session.lastFart < Config.Farts.cooldown then
		return
	end

	if profile.farts < 1 then
		notifyRemote:FireClient(player, "empty")
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	profile.farts -= 1
	session.lastFart = now

	-- Start z ziemi ustala mnoznik XP na caly lot: liczy sie strefa, z ktorej
	-- wystartowales, a nie to, gdzie akurat jestes w powietrzu.
	if isOnGround(character :: Model) then
		session.launchMultiplier = session.zoneMultiplier
	end

	-- Pierd JEST zrodlem XP -- za kazde nacisniecie spacji.
	profile.xp += Config.Level.xpPerFart * session.launchMultiplier

	local levelBefore = session.level
	pushState(player, session)
	if session.level > levelBefore then
		notifyRemote:FireClient(player, "levelUp", session.level, Config.maxFarts(session.level))
	end

	blastRemote:FireClient(player, Config.jumpPower(profile.rebirths))
end

fartRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if session then
		tryFart(player, session)
	end
end)

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
	profile.xp = 0
	profile.farts = Config.maxFarts(1)
	profile.claimedMarks = {}

	pushState(player, session)
	notifyRemote:FireClient(player, "rebirth", profile.rebirths)

	if player.Character then
		player.Character:PivotTo(CFrame.new(0, 6, 40))
	end
end)

--------------------------------------------------------------------------------
-- Kreski na linijce
--------------------------------------------------------------------------------

local function claimMark(player: Player, session: Session, mark: number)
	local profile = session.profile
	local key = tostring(mark)
	if profile.claimedMarks[key] then
		return
	end
	profile.claimedMarks[key] = true

	local earned = math.floor(Config.winsForMark(mark) * Config.rebirthMultiplier(profile.rebirths))
	profile.wins += earned
	profile.totalWins += earned
	profile.bestMark = math.max(profile.bestMark, mark)

	notifyRemote:FireClient(player, "mark", earned, mark, Config.markHeight(mark))
end

-- Zamiast sprawdzac odleglosc od kreski, sprawdzamy czy odcinek przebyty w tym
-- ticku przecial jej wysokosc. Inaczej szybki lot mijalby kreski niezauwazony.
local function checkMarks(player: Player, session: Session, position: Vector3)
	local previous = session.lastPosition or position
	session.lastPosition = position

	local from = math.min(previous.Y, position.Y)
	local to = math.max(previous.Y, position.Y)
	if to < Config.Map.markEvery then
		return
	end

	-- Kreska liczy sie tylko nad placem, zeby nie dalo sie jej zebrac z boku.
	if Vector3.new(position.X, 0, position.Z).Magnitude > Config.Map.claimRadius then
		return
	end

	local firstMark = math.max(Config.markAtHeight(from) + (if from % Config.Map.markEvery == 0 then 0 else 1), 1)
	local lastMark = Config.markAtHeight(to)

	for mark = firstMark, lastMark do
		claimMark(player, session, mark)
	end
end

local function grantFameForHeight(player: Player, session: Session, height: number)
	local profile = session.profile
	if height <= profile.bestHeight then
		return
	end

	local gained = height - profile.bestHeight
	profile.bestHeight = height

	local earned = math.floor(gained * Config.Fame.perMeter * Config.rebirthMultiplier(profile.rebirths))
	if earned > 0 then
		profile.fame += earned
		profile.totalFame += earned
	end
end

--------------------------------------------------------------------------------
-- Petla glowna
--------------------------------------------------------------------------------

local accumulator = 0

RunService.Heartbeat:Connect(function(deltaTime)
	accumulator += deltaTime
	if accumulator < Config.TICK then
		return
	end
	local step = accumulator
	accumulator = 0

	local now = os.clock()
	local topMarkNeeded = 0

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
		local maxFarts = Config.maxFarts(session.level)

		-- Odnawianie pierdow.
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

		session.zoneMultiplier = zoneMultiplier

		-- Dotknales ziemi -- masz z powrotem caly zapas. Bez czekania.
		local grounded = isOnGround(character)
		if grounded and Config.Farts.refillOnGround then
			profile.farts = maxFarts
			session.launchMultiplier = zoneMultiplier
		end

		-- Baczki: samo stanie na odblokowanej strefie sypie XP.
		local idleXp = 0
		if grounded and zone and not locked then
			idleXp = Config.Idle.xpPerSecond * zoneMultiplier * Config.rebirthMultiplier(profile.rebirths)
			profile.xp += idleXp * step
		end

		player:SetAttribute("IdleXp", idleXp)
		player:SetAttribute("Idling", idleXp > 0)
		player:SetAttribute("LaunchMultiplier", session.launchMultiplier)
		player:SetAttribute("ZoneName", zoneName)
		player:SetAttribute("ZoneLocked", locked)
		player:SetAttribute("ZoneMultiplier", zoneMultiplier)
		player:SetAttribute("Grounded", grounded)

		local height = root.Position.Y
		player:SetAttribute("Height", height)

		grantFameForHeight(player, session, height)
		checkMarks(player, session, root.Position)

		-- Poziom moze wskoczyc takze z samych baczkow, wiec sprawdzamy go tutaj,
		-- nie tylko przy pierdnieciu.
		local levelBefore = session.level
		pushState(player, session)
		if session.level > levelBefore then
			notifyRemote:FireClient(player, "levelUp", session.level, Config.maxFarts(session.level))
		end

		topMarkNeeded = math.max(topMarkNeeded, Config.markAtHeight(height) + Config.Map.buildAheadMarks)

		if now - session.lastSave > Config.AUTOSAVE_INTERVAL then
			session.lastSave = now
			task.spawn(Data.save, player.UserId, profile)
		end
	end

	-- Linijka ma nie miec konca.
	if topMarkNeeded > World.highestMark() then
		World.ensureMarks(World.highestMark() + Config.Map.buildBatch)
	end
end)

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

workspace.Gravity = Config.GRAVITY

World.build()
print(
	`[FartFly] gotowe: mapa {if World.adopted then "z Workspace (recznie edytowalna)" else "zbudowana z kodu"}, `
		.. `linijka do {Config.markHeight(World.highestMark())} m `
		.. `(kreska co {Config.Map.markEvery} m), {#Config.Zones} stref, `
		.. `1 pierd = {math.floor(Config.metersPerFart())} m, grawitacja {workspace.Gravity}`
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
