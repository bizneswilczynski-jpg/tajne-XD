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

	local result = workspace:Raycast(root.Position, Vector3.new(0, -8, 0), params)
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

	-- Zachowujemy poziomy ped, zeby dalo sie sterowac lotem w powietrzu.
	local horizontal = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	root.AssemblyLinearVelocity = horizontal + Vector3.new(0, velocity, 0)

	session.flight = {
		launchY = root.Position.Y,
		apexY = root.Position.Y,
		rings = {},
		startedAt = os.clock(),
	}

	pushState(player, session)
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

local ringParts = {}

local function refreshRings()
	ringParts = CollectionService:GetTagged(World.RING_TAG)
end

local function trackFlight(session: Session, root: BasePart)
	local flight = session.flight
	if not flight then
		return
	end

	local position = root.Position
	flight.apexY = math.max(flight.apexY, position.Y)

	for _, ring in ringParts do
		if not ring:IsA("BasePart") then
			continue
		end
		local index = ring:GetAttribute("RingIndex")
		if typeof(index) ~= "number" or flight.rings[index] then
			continue
		end

		local center = ring.Position
		local verticalGap = math.abs(position.Y - center.Y)
		local horizontalGap = (Vector3.new(position.X, 0, position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude

		if verticalGap <= 4 and horizontalGap <= Config.Rings.radius then
			flight.rings[index] = true
			ring.Transparency = 0.75
			task.delay(0.6, function()
				ring.Transparency = 0.35
			end)
		end
	end
end

local accumulator = 0

RunService.Heartbeat:Connect(function(deltaTime)
	accumulator += deltaTime
	if accumulator < 0.1 then
		return
	end
	local step = accumulator
	accumulator = 0

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

		local profile = session.profile

		-- Jedzenie
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

		-- Lot
		if session.flight then
			trackFlight(session, root)

			local flight = session.flight :: Flight
			player:SetAttribute("FlightHeight", root.Position.Y - flight.launchY)

			local airborne = humanoid.FloorMaterial == Enum.Material.Air
			local settled = not airborne and root.AssemblyLinearVelocity.Y <= 1
			if (settled and now - flight.startedAt > 0.75) or now - flight.startedAt > 120 then
				finishFlight(player, session)
				player:SetAttribute("FlightHeight", 0)
			end
		end

		-- Autosave
		if now - session.lastSave > Config.AUTOSAVE_INTERVAL then
			session.lastSave = now
			task.spawn(Data.save, player.UserId, profile)
		end
	end
end)

--------------------------------------------------------------------------------
-- Start
--------------------------------------------------------------------------------

World.build()
refreshRings()
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
