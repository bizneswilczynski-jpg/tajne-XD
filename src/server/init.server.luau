--!strict
-- +1 FART & FLY -- logika serwera.
--
-- Petla:
--   1. Gracz stoi na stolowce -> je -> +GAZ/s (to jest caly AFK).
--   2. PUK -> wydaje CALY gaz -> wystrzal w gore.
--   3. Wysokosc w apogeum (+ zlapane pierscienie) -> SLAWA.
--   4. SLAWA odblokowuje mocniejsze jedzenie i placi za DIETE (rebirth).
--   5. DIETA kasuje gaz i slawe za trwaly mnoznik -> petla od nowa, szybciej.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Data = require(script.Data)
local World = require(script.World)

type Flight = {
	launchY: number,
	apexY: number,
	rings: { [number]: true },
	startedAt: number,
	-- Czy postac w ogole oderwala sie od ziemi. Bez tego ladowanie wykrywa sie
	-- juz w pierwszej klatce po PUKU (gracz nadal stoi na stolowce) i lot
	-- konczy sie z wynikiem 0 m.
	airborne: boolean,
	-- Pozycja z poprzedniej klatki -- pierscienie liczymy jako przeciecie
	-- odcinka, a nie trafienie w okno +/- kilka studow.
	lastPosition: Vector3,
	velocity: number,
}

type Session = {
	profile: Data.Profile,
	flight: Flight?,
	lastSave: number,
}

local sessions: { [Player]: Session } = {}

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local pukRemote = Instance.new("RemoteEvent")
pukRemote.Name = "Puk"
pukRemote.Parent = remotes

local rebirthRemote = Instance.new("RemoteEvent")
rebirthRemote.Name = "Rebirth"
rebirthRemote.Parent = remotes

local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes

--------------------------------------------------------------------------------
-- Pomocnicze
--------------------------------------------------------------------------------

-- Stan leci do klienta atrybutami: replikuja sie same, wiec HUD nie potrzebuje
-- wlasnego kanalu synchronizacji.
local function pushState(player: Player, session: Session)
	local profile = session.profile
	player:SetAttribute("Gas", profile.gas)
	player:SetAttribute("Fame", profile.fame)
	player:SetAttribute("TotalFame", profile.totalFame)
	player:SetAttribute("Rebirths", profile.rebirths)
	player:SetAttribute("BestHeight", profile.bestHeight)
	player:SetAttribute("Multiplier", Config.rebirthMultiplier(profile.rebirths))
	player:SetAttribute("RebirthCost", Config.rebirthCost(profile.rebirths))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local fame = stats:FindFirstChild("SLAWA") :: IntValue?
		local diet = stats:FindFirstChild("DIETA") :: IntValue?
		if fame then
			fame.Value = math.floor(math.min(profile.fame, 2 ^ 31 - 1))
		end
		if diet then
			diet.Value = profile.rebirths
		end
	end
end

local function isFoodUnlocked(profile: Data.Profile, food: Config.Food): boolean
	return profile.totalFame >= food.unlockAt
end

-- Ktora stolowka jest pod graczem. Raycast w dol jest pewniejszy niz
-- Touched -- nie gubi sie przy staniu w miejscu przez godziny.
local function foodUnderCharacter(character: Model): Config.Food?
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

	local result = workspace:Raycast(root.Position, Vector3.new(0, -Config.FOOD_RAY_LENGTH, 0), params)
	if not result then
		return nil
	end

	local hit = result.Instance
	if not CollectionService:HasTag(hit, World.FOOD_TAG) then
		return nil
	end

	local foodId = hit:GetAttribute("FoodId")
	if typeof(foodId) ~= "string" then
		return nil
	end
	return Config.foodById(foodId)
end

--------------------------------------------------------------------------------
-- Cykl zycia gracza
--------------------------------------------------------------------------------

local function grantOfflineGas(player: Player, session: Session)
	local profile = session.profile
	local foodId = profile.lastFoodId
	if not foodId then
		return
	end

	local food = Config.foodById(foodId)
	if not food then
		return
	end

	local elapsed = math.clamp(os.time() - profile.lastSeen, 0, Config.OFFLINE_CAP_SECONDS)
	if elapsed < 60 then
		return
	end

	local earned = math.floor(elapsed * food.rate * Config.rebirthMultiplier(profile.rebirths))
	if earned <= 0 then
		return
	end

	profile.gas += earned
	notifyRemote:FireClient(player, "offline", earned, elapsed, food.name)
end

local function onPlayerAdded(player: Player)
	local profile = Data.load(player.UserId)
	local session: Session = { profile = profile, flight = nil, lastSave = os.clock() }
	sessions[player] = session

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local fame = Instance.new("IntValue")
	fame.Name = "SLAWA"
	fame.Parent = stats

	local diet = Instance.new("IntValue")
	diet.Name = "DIETA"
	diet.Parent = stats

	stats.Parent = player

	-- Smierc lub respawn w trakcie lotu zostawilby otwarty Flight z nieaktualnym
	-- launchY, wiec przy kazdej nowej postaci czyscimy stan lotu.
	player.CharacterAdded:Connect(function()
		local current = sessions[player]
		if current then
			current.flight = nil
			player:SetAttribute("FlightHeight", 0)
		end
	end)

	grantOfflineGas(player, session)
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
-- PUK
--------------------------------------------------------------------------------

local function startFlight(player: Player, session: Session)
	local profile = session.profile
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	if profile.gas < Config.Launch.minGasToPuk then
		notifyRemote:FireClient(player, "noGas")
		return
	end

	local velocity = Config.launchVelocity(profile.gas)
	profile.gas = 0

	session.flight = {
		launchY = root.Position.Y,
		apexY = root.Position.Y,
		rings = {},
		startedAt = os.clock(),
		airborne = false,
		lastPosition = root.Position,
		velocity = velocity,
	}

	pushState(player, session)

	-- Sam impuls zadaje KLIENT. Postac gracza ma sieciowego wlasciciela po
	-- stronie klienta, wiec predkosc ustawiona z serwera jest kasowana przy
	-- najblizszej replikacji fizyki -- zmierzone: 300 studow/s z serwera daje
	-- 4 study wzniosu, te same 300 z klienta daje 374 study.
	-- Serwer zostaje sedzia: on decyduje ILE, on liczy wysokosc i SLAWE.
	notifyRemote:FireClient(player, "puk", velocity)
end

local function finishFlight(player: Player, session: Session)
	local flight = session.flight
	if not flight then
		return
	end
	session.flight = nil

	local profile = session.profile
	local height = math.max(flight.apexY - flight.launchY, 0)

	-- Impuls zadaje klient, wiec wysokosc trzeba obciac do tego, co przy tej
	-- predkosci w ogole jest fizycznie mozliwe. Bez tego podmieniony klient
	-- moglby zglosic dowolne apogeum.
	local ceiling = flight.velocity ^ 2 / (2 * math.max(workspace.Gravity, 1)) * Config.Flight.heightTolerance
	height = math.min(height, ceiling)

	local ringCount = 0
	for _ in flight.rings do
		ringCount += 1
	end

	local bonus = 1 + ringCount * Config.Rings.bonusPerRing
	local earned = math.floor(height * bonus * Config.rebirthMultiplier(profile.rebirths))

	profile.fame += earned
	profile.totalFame += earned
	profile.bestHeight = math.max(profile.bestHeight, height)

	pushState(player, session)
	notifyRemote:FireClient(player, "landed", earned, height, ringCount)
end

pukRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if session then
		startFlight(player, session)
	end
end)

rebirthRemote.OnServerEvent:Connect(function(player)
	local session = sessions[player]
	if not session then
		return
	end

	local profile = session.profile
	local cost = Config.rebirthCost(profile.rebirths)
	if profile.fame < cost then
		notifyRemote:FireClient(player, "rebirthTooPoor", cost)
		return
	end

	profile.fame -= cost
	profile.rebirths += 1
	profile.gas = 0

	pushState(player, session)
	notifyRemote:FireClient(player, "rebirth", profile.rebirths)
end)

--------------------------------------------------------------------------------
-- Petla glowna
--------------------------------------------------------------------------------

local ringParts: { Instance } = {}

local function refreshRings()
	ringParts = CollectionService:GetTagged(World.RING_TAG)
end

-- Czy odcinek from->to przebija plaszczyzne pierscienia wewnatrz jego promienia.
-- Sprawdzanie samej odleglosci od srodka nie dziala: przy 200+ studach na
-- sekunde postac przeskakuje caly pierscien miedzy dwiema klatkami.
local function crossesRing(from: Vector3, to: Vector3, center: Vector3): boolean
	local dy = to.Y - from.Y
	local point: Vector3

	if math.abs(dy) < 1e-4 then
		-- Lot praktycznie poziomy: liczymy zwykla odleglosc od plaszczyzny.
		if math.abs(from.Y - center.Y) > Config.Rings.planeTolerance then
			return false
		end
		point = to
	else
		local t = (center.Y - from.Y) / dy
		if t < 0 or t > 1 then
			return false
		end
		point = from:Lerp(to, t)
	end

	local flatPoint = Vector3.new(point.X, 0, point.Z)
	local flatCenter = Vector3.new(center.X, 0, center.Z)
	return (flatPoint - flatCenter).Magnitude <= Config.Rings.radius
end

local function trackFlight(session: Session, root: BasePart)
	local flight = session.flight
	if not flight then
		return
	end

	local position = root.Position
	local previous = flight.lastPosition
	flight.lastPosition = position
	flight.apexY = math.max(flight.apexY, position.Y)

	for _, ring in ringParts do
		if not ring:IsA("BasePart") then
			continue
		end
		local index = ring:GetAttribute("RingIndex")
		if typeof(index) ~= "number" or flight.rings[index] then
			continue
		end

		if crossesRing(previous, position, ring.Position) then
			flight.rings[index] = true
			ring.Transparency = 0.75
			task.delay(0.6, function()
				ring.Transparency = 0.35
			end)
		end
	end
end

-- Lot liczymy co klatke; jedzenie wystarczy co Config.EAT_TICK.
local function updateFlight(player: Player, session: Session, root: BasePart, humanoid: Humanoid, now: number)
	local flight = session.flight :: Flight

	trackFlight(session, root)
	player:SetAttribute("FlightHeight", root.Position.Y - flight.launchY)

	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	-- Druga przeslanka poza FloorMaterial: stan Humanoida replikuje sie z
	-- opoznieniem, a realna zmiana wysokosci nie klamie.
	if airborne or root.Position.Y - flight.launchY > Config.Flight.airborneHeight then
		flight.airborne = true
	end

	local linear = root.AssemblyLinearVelocity
	local elapsed = now - flight.startedAt
	local settled = flight.airborne and not airborne and linear.Y <= Config.Flight.settleVelocity
	local launchFailed = not flight.airborne and elapsed > Config.Flight.launchGrace

	if (settled and elapsed > Config.Flight.minAirtime) or launchFailed or elapsed > Config.Flight.maxDuration then
		finishFlight(player, session)
		player:SetAttribute("FlightHeight", 0)
	end
end

local function updateEating(player: Player, session: Session, character: Model, step: number)
	local profile = session.profile
	local food = foodUnderCharacter(character)

	if food and not isFoodUnlocked(profile, food) then
		player:SetAttribute("Eating", false)
		player:SetAttribute("EatingFood", `🔒 {food.name}`)
		player:SetAttribute("Rate", 0)
	elseif food then
		local rate = food.rate * Config.rebirthMultiplier(profile.rebirths)
		profile.gas += rate * step
		profile.lastFoodId = food.id

		player:SetAttribute("Eating", true)
		player:SetAttribute("EatingFood", food.name)
		player:SetAttribute("Rate", rate)
		player:SetAttribute("Gas", profile.gas)
	else
		player:SetAttribute("Eating", false)
		player:SetAttribute("EatingFood", "")
		player:SetAttribute("Rate", 0)
	end
end

local accumulator = 0

RunService.Heartbeat:Connect(function(deltaTime)
	accumulator += deltaTime

	local step = 0
	if accumulator >= Config.EAT_TICK then
		step = accumulator
		accumulator = 0
	end

	local now = os.clock()

	for player, session in sessions do
		local character = player.Character
		if not character then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid then
			continue
		end

		if session.flight then
			updateFlight(player, session, root, humanoid, now)
		end

		if step > 0 then
			updateEating(player, session, character, step)

			if now - session.lastSave > Config.AUTOSAVE_INTERVAL then
				session.lastSave = now
				task.spawn(Data.save, player.UserId, session.profile)
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

workspace.Gravity = Config.GRAVITY

World.build()
refreshRings()
print(`[FartFly] swiat gotowy: {#ringParts} pierscieni, {#Config.Foods} stolowek, grawitacja {workspace.Gravity}`)
CollectionService:GetInstanceAddedSignal(World.RING_TAG):Connect(refreshRings)
CollectionService:GetInstanceRemovedSignal(World.RING_TAG):Connect(refreshRings)

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
