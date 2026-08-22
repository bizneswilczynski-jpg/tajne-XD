--!strict
-- HUD budowany z kodu -- zero zaleznosci od recznie klikanych GUI w Studio,
-- wiec caly interfejs jest wersjonowany w gicie razem z logika.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- WaitForChild, a nie bezposrednie indeksowanie: skrypt klienta potrafi ruszyc
-- zanim ReplicatedStorage sie zreplikuje i wtedy caly HUD wywala sie na
-- "Shared is not a valid member of ReplicatedStorage".
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(sharedFolder:WaitForChild("Config"))
local Format = require(sharedFolder:WaitForChild("Format"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local pukRemote = remotes:WaitForChild("Puk") :: RemoteEvent
local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

local BROWN = Color3.fromRGB(150, 110, 60)
local GREEN = Color3.fromRGB(110, 190, 110)
local DARK = Color3.fromRGB(24, 26, 32)

--------------------------------------------------------------------------------
-- Budowa HUD
--------------------------------------------------------------------------------

local function corner(parent: Instance, radius: number)
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local function panel(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = DARK
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = parent
	corner(frame, 12)
	return frame
end

local function text(parent: Instance, name: string, size: UDim2, position: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = parent
	return label
end

local screen = Instance.new("ScreenGui")
screen.Name = "FartFlyHUD"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = player:WaitForChild("PlayerGui")

-- Panel gazu (lewy gorny rog)
local gasPanel = panel(screen, "GasPanel")
gasPanel.Size = UDim2.fromOffset(260, 96)
gasPanel.Position = UDim2.fromOffset(16, 16)

local gasValue = text(gasPanel, "Value", UDim2.new(1, -20, 0, 44), UDim2.fromOffset(12, 8))
gasValue.TextColor3 = BROWN

local gasRate = text(gasPanel, "Rate", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 54))
gasRate.TextColor3 = Color3.fromRGB(180, 180, 190)

local eatingLabel = text(gasPanel, "Eating", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 74))
eatingLabel.TextColor3 = GREEN

-- Panel slawy (prawy gorny rog)
local famePanel = panel(screen, "FamePanel")
famePanel.Size = UDim2.fromOffset(230, 96)
famePanel.Position = UDim2.new(1, -246, 0, 16)

local fameValue = text(famePanel, "Value", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(12, 8))
fameValue.TextColor3 = Color3.fromRGB(250, 210, 90)

local dietLabel = text(famePanel, "Diet", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 50))
local bestLabel = text(famePanel, "Best", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 72))
bestLabel.TextColor3 = Color3.fromRGB(180, 180, 190)

-- Wysokosciomierz -- widoczny tylko w locie
local altPanel = panel(screen, "AltPanel")
altPanel.Size = UDim2.fromOffset(230, 70)
altPanel.Position = UDim2.new(0.5, -115, 0, 16)
altPanel.Visible = false

local altValue = text(altPanel, "Value", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(12, 6))
altValue.TextXAlignment = Enum.TextXAlignment.Center
altValue.Position = UDim2.fromOffset(10, 6)

local altName = text(altPanel, "Name", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 46))
altName.TextXAlignment = Enum.TextXAlignment.Center
altName.TextColor3 = Color3.fromRGB(180, 180, 190)

-- Przycisk PUK
local pukButton = Instance.new("TextButton")
pukButton.Name = "PukButton"
pukButton.Size = UDim2.fromOffset(210, 78)
pukButton.Position = UDim2.new(0.5, -105, 1, -120)
pukButton.BackgroundColor3 = BROWN
pukButton.BorderSizePixel = 0
pukButton.Font = Enum.Font.FredokaOne
pukButton.TextScaled = true
pukButton.TextColor3 = Color3.new(1, 1, 1)
pukButton.Text = "PUK  [F]"
pukButton.Parent = screen
corner(pukButton, 16)

-- Przycisk DIETY
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Size = UDim2.fromOffset(230, 44)
rebirthButton.Position = UDim2.new(1, -246, 0, 122)
rebirthButton.BackgroundColor3 = Color3.fromRGB(90, 70, 140)
rebirthButton.BorderSizePixel = 0
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.new(1, 1, 1)
rebirthButton.Text = "DIETA"
rebirthButton.Parent = screen
corner(rebirthButton, 10)

-- Toasty
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.fromOffset(340, 300)
toastHolder.Position = UDim2.new(0.5, -170, 0, 110)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = screen

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastHolder

local function toast(message: string, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(340, 34)
	label.BackgroundColor3 = DARK
	label.BackgroundTransparency = 0.15
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Text = message
	label.Parent = toastHolder
	corner(label, 8)

	task.delay(3, function()
		local tween = TweenService:Create(label, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tween.Completed:Connect(function()
			label:Destroy()
		end)
		tween:Play()
	end)
end

--------------------------------------------------------------------------------
-- Odswiezanie z atrybutow gracza
--------------------------------------------------------------------------------

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local gas = number("Gas")
	local rate = number("Rate")
	local multiplier = math.max(number("Multiplier"), 1)

	gasValue.Text = `💨 {Format.short(gas)}`
	gasRate.Text = if rate > 0
		then `+{Format.short(rate)} GAZ/s  (x{multiplier})`
		else `stoisz bezczynnie  (x{multiplier})`

	local eating = player:GetAttribute("Eating") == true
	local foodName = player:GetAttribute("EatingFood")
	if eating and typeof(foodName) == "string" then
		eatingLabel.Text = `MNIAM · {foodName}`
		eatingLabel.TextColor3 = GREEN
	elseif typeof(foodName) == "string" and foodName ~= "" then
		eatingLabel.Text = `{foodName} — za malo SLAWY`
		eatingLabel.TextColor3 = Color3.fromRGB(230, 120, 120)
	else
		eatingLabel.Text = "wejdz na stolowke, zeby jesc"
		eatingLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	end

	fameValue.Text = `⭐ {Format.short(number("Fame"))}`
	dietLabel.Text = `DIETA {number("Rebirths")}`
	bestLabel.Text = `rekord: {math.floor(number("BestHeight"))}m`

	local cost = number("RebirthCost")
	local canRebirth = number("Fame") >= cost
	rebirthButton.Text = `DIETA · {Format.short(cost)} ⭐`
	rebirthButton.BackgroundColor3 = if canRebirth
		then Color3.fromRGB(130, 95, 200)
		else Color3.fromRGB(60, 55, 75)

	local flightHeight = number("FlightHeight")
	if flightHeight > 1 then
		altPanel.Visible = true
		altValue.Text = `{math.floor(flightHeight)}m`
		altName.Text = Config.altitudeName(flightHeight)
	else
		altPanel.Visible = false
	end

	pukButton.BackgroundColor3 = if gas >= Config.Launch.minGasToPuk
		then BROWN
		else Color3.fromRGB(80, 70, 55)
end

RunService.RenderStepped:Connect(refresh)

--------------------------------------------------------------------------------
-- Wejscie
--------------------------------------------------------------------------------

local function firePuk()
	pukRemote:FireServer()
end

pukButton.Activated:Connect(firePuk)
rebirthButton.Activated:Connect(function()
	rebirthRemote:FireServer()
end)

ContextActionService:BindAction("Puk", function(_, state)
	if state == Enum.UserInputState.Begin then
		firePuk()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)

--------------------------------------------------------------------------------
-- Wystrzal
--------------------------------------------------------------------------------
-- Impuls MUSI polecieciec stad, nie z serwera: postac ma sieciowego wlasciciela
-- po stronie klienta, wiec AssemblyLinearVelocity ustawione na serwerze jest
-- kasowane przy najblizszej replikacji fizyki. Serwer decyduje o wartosci
-- predkosci i liczy nagrode, klient tylko wykonuje.

local fallConnection: RBXScriptConnection? = nil

local function stopFallBoost()
	if fallConnection then
		fallConnection:Disconnect()
		fallConnection = nil
	end
end

local function applyPuk(velocity: number)
	local character = player.Character
	if not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	-- Humanoid w stanie Running trzyma postac na wysokosci bioder i potrafi
	-- zjesc impuls w tej samej klatce.
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)

	-- Poziomy ped zostaje, zeby dalo sie sterowac lotem w powietrzu.
	local horizontal = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	root.AssemblyLinearVelocity = horizontal + Vector3.new(0, velocity, 0)

	-- Opadanie przyspieszamy, zeby zjazd z apogeum nie byl martwym czasem.
	stopFallBoost()
	local startedAt = os.clock()
	local wasAirborne = false

	fallConnection = RunService.Heartbeat:Connect(function(deltaTime)
		local currentCharacter = player.Character
		local currentRoot = currentCharacter and currentCharacter:FindFirstChild("HumanoidRootPart") :: BasePart?
		local currentHumanoid = currentCharacter and currentCharacter:FindFirstChildOfClass("Humanoid")

		if not currentRoot or not currentHumanoid or os.clock() - startedAt > Config.Flight.maxDuration then
			stopFallBoost()
			return
		end

		local airborne = currentHumanoid.FloorMaterial == Enum.Material.Air
		if airborne then
			wasAirborne = true
		elseif wasAirborne then
			stopFallBoost()
			return
		end

		local linear = currentRoot.AssemblyLinearVelocity
		if wasAirborne and linear.Y < 0 then
			currentRoot.AssemblyLinearVelocity = linear - Vector3.new(0, Config.Flight.fallBoost * deltaTime, 0)
		end
	end)
end

--------------------------------------------------------------------------------
-- Powiadomienia z serwera
--------------------------------------------------------------------------------

notifyRemote.OnClientEvent:Connect(function(kind: string, ...)
	local args = { ... }

	if kind == "offline" then
		local earned, elapsed, foodName = args[1], args[2], args[3]
		toast(`Jadles {foodName} przez {Format.time(elapsed)} → +{Format.short(earned)} GAZ`, BROWN)
	elseif kind == "puk" then
		applyPuk(args[1])
		toast("PUUUUK! 💨", BROWN)
	elseif kind == "landed" then
		local earned, height, rings = args[1], args[2], args[3]
		local ringText = if rings > 0 then ` · {rings} pierscieni` else ""
		toast(`{math.floor(height)}m{ringText} → +{Format.short(earned)} ⭐`, Color3.fromRGB(250, 210, 90))
	elseif kind == "noGas" then
		toast("Pusto w brzuchu — idz cos zjesc", Color3.fromRGB(230, 120, 120))
	elseif kind == "rebirth" then
		toast(`DIETA {args[1]} — mnoznik x{Config.rebirthMultiplier(args[1])}`, Color3.fromRGB(180, 150, 255))
	elseif kind == "rebirthTooPoor" then
		toast(`Potrzebujesz {Format.short(args[1])} ⭐ na diete`, Color3.fromRGB(230, 120, 120))
	end
end)
