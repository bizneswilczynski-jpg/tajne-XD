--!strict
-- HUD budowany z kodu -- zero zaleznosci od recznie klikanych GUI w Studio,
-- wiec caly interfejs jest wersjonowany w gicie razem z logika.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- WaitForChild, a nie bezposrednie indeksowanie: skrypt klienta potrafi ruszyc
-- zanim ReplicatedStorage sie zreplikuje.
local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(sharedFolder:WaitForChild("Config"))
local Format = require(sharedFolder:WaitForChild("Format"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fartRemote = remotes:WaitForChild("Fart") :: RemoteEvent
local blastRemote = remotes:WaitForChild("Blast") :: RemoteEvent
local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

local BROWN = Color3.fromRGB(170, 125, 65)
local GREEN = Color3.fromRGB(110, 190, 110)
local GOLD = Color3.fromRGB(250, 210, 90)
local DARK = Color3.fromRGB(24, 26, 32)

--------------------------------------------------------------------------------
-- Pierd: wystrzal
--------------------------------------------------------------------------------
-- Impuls MUSI polecieciec stad, nie z serwera: postac ma sieciowego wlasciciela
-- po stronie klienta, wiec AssemblyLinearVelocity ustawione na serwerze jest
-- kasowane przy najblizszej replikacji fizyki. Serwer decyduje CZY i JAK MOCNO,
-- klient tylko wykonuje.

local function applyBlast(power: number)
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

	-- Pierd USTAWIA predkosc pionowa, nie dodaje jej. Poziomy ped zostaje,
	-- zeby dalo sie sterowac lotem.
	local horizontal = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	root.AssemblyLinearVelocity = horizontal + Vector3.new(0, power, 0)
end

blastRemote.OnClientEvent:Connect(applyBlast)

local function requestFart()
	fartRemote:FireServer()
end

-- Spacja zamiast zwyklego skoku. Sink, zeby Humanoid nie dokladal swojego.
ContextActionService:BindAction("Pierd", function(_, state)
	if state == Enum.UserInputState.Begin then
		requestFart()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

-- Zwykly skok Humanoida wylaczony -- caly wznios idzie z pierdow.
local function disableDefaultJump(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
end

if player.Character then
	task.spawn(disableDefaultJump, player.Character)
end
player.CharacterAdded:Connect(disableDefaultJump)

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

-- Licznik pierdow -- duzy, na srodku dolu, jak "Jump: 12/12" w referencji.
local fartCounter = text(screen, "FartCounter", UDim2.fromOffset(560, 66), UDim2.new(0.5, -280, 1, -196))
fartCounter.TextXAlignment = Enum.TextXAlignment.Center
fartCounter.TextColor3 = BROWN
fartCounter.TextStrokeTransparency = 0.2

-- Wysokosc -- pod licznikiem pierdow.
local heightLabel = text(screen, "Height", UDim2.fromOffset(560, 46), UDim2.new(0.5, -280, 1, -134))
heightLabel.TextXAlignment = Enum.TextXAlignment.Center
heightLabel.TextStrokeTransparency = 0.3

-- Pasek poziomu na samym dole.
local levelBar = panel(screen, "LevelBar")
levelBar.Size = UDim2.new(0.62, 0, 0, 40)
levelBar.Position = UDim2.new(0.19, 0, 1, -76)
levelBar.BackgroundColor3 = Color3.fromRGB(40, 44, 52)
levelBar.BackgroundTransparency = 0.15

local levelFill = Instance.new("Frame")
levelFill.Name = "Fill"
levelFill.Size = UDim2.fromScale(0, 1)
levelFill.BackgroundColor3 = Color3.fromRGB(72, 200, 84)
levelFill.BorderSizePixel = 0
levelFill.Parent = levelBar
corner(levelFill, 12)

local levelText = text(levelBar, "Text", UDim2.new(1, -24, 1, 0), UDim2.fromOffset(16, 0))
levelText.ZIndex = 3

local levelProgress = text(levelBar, "Progress", UDim2.new(0, 180, 1, 0), UDim2.new(1, -196, 0, 0))
levelProgress.TextXAlignment = Enum.TextXAlignment.Right
levelProgress.ZIndex = 3

-- Waluty (prawy gorny rog)
local walletPanel = panel(screen, "Wallet")
walletPanel.Size = UDim2.fromOffset(230, 106)
walletPanel.Position = UDim2.new(1, -246, 0, 16)

local winsValue = text(walletPanel, "Wins", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(12, 8))
winsValue.TextColor3 = GOLD

local fameValue = text(walletPanel, "Fame", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(12, 42))
fameValue.TextColor3 = Color3.fromRGB(200, 160, 255)

local recordValue = text(walletPanel, "Record", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 74))
recordValue.TextColor3 = Color3.fromRGB(180, 180, 190)

-- Strefa (lewy gorny rog)
local zonePanel = panel(screen, "Zone")
zonePanel.Size = UDim2.fromOffset(280, 68)
zonePanel.Position = UDim2.fromOffset(16, 16)

local zoneTitle = text(zonePanel, "Title", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(12, 8))
zoneTitle.TextColor3 = GREEN

local zoneRate = text(zonePanel, "Rate", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 38))
zoneRate.TextColor3 = Color3.fromRGB(180, 180, 190)

-- Przycisk DIETY
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "Rebirth"
rebirthButton.Size = UDim2.fromOffset(230, 48)
rebirthButton.Position = UDim2.new(1, -246, 0, 132)
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
toastHolder.Size = UDim2.fromOffset(400, 300)
toastHolder.Position = UDim2.new(0.5, -200, 0, 90)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = screen

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastHolder

local function toast(message: string, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(400, 36)
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
-- Odswiezanie
--------------------------------------------------------------------------------

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local farts = number("Farts")
	local maxFarts = math.max(number("MaxFarts"), 1)

	fartCounter.Text = `PIERD: {farts}/{maxFarts}`
	fartCounter.TextColor3 = if farts > 0 then BROWN else Color3.fromRGB(120, 100, 90)

	heightLabel.Text = `{Format.short(number("Height"))} m  ·  {Config.altitudeName(number("Height"))}`

	local level = number("Level")
	local into = number("LevelProgress")
	local needed = number("LevelNeeded")
	levelText.Text = `Poziom {level}`
	levelProgress.Text = `{math.floor(into)}/{math.floor(needed)}`
	levelFill.Size = UDim2.fromScale(if needed > 0 then math.clamp(into / needed, 0, 1) else 1, 1)

	winsValue.Text = `🏆 {Format.short(number("Wins"))}`
	fameValue.Text = `⭐ {Format.short(number("Fame"))}`
	recordValue.Text = `rekord {Format.short(number("BestHeight"))} m · DIETA {number("Rebirths")}`

	local zoneName = player:GetAttribute("ZoneName")
	local zoneMultiplier = math.max(number("ZoneMultiplier"), 1)
	if typeof(zoneName) == "string" and zoneName ~= "" then
		if player:GetAttribute("ZoneLocked") == true then
			zoneTitle.Text = `🔒 {zoneName}`
			zoneTitle.TextColor3 = Color3.fromRGB(230, 120, 120)
			zoneRate.Text = "brak WINOW albo SLAWY"
		else
			zoneTitle.Text = zoneName
			zoneTitle.TextColor3 = GREEN
			zoneRate.Text = `x{Format.short(zoneMultiplier)} tempa ladowania`
		end
	else
		zoneTitle.Text = "Plac"
		zoneTitle.TextColor3 = Color3.fromRGB(180, 180, 190)
		zoneRate.Text = `+{Format.short(number("Regen"))} pierda/s`
	end

	if player:GetAttribute("Grounded") ~= true then
		zoneRate.Text = "w powietrzu — nie ladujesz"
	end

	local winCost = number("RebirthWinCost")
	local fameCost = number("RebirthFameCost")
	local canRebirth = number("Wins") >= winCost and number("Fame") >= fameCost
	rebirthButton.Text = `DIETA · {Format.short(winCost)}🏆 {Format.short(fameCost)}⭐`
	rebirthButton.BackgroundColor3 = if canRebirth
		then Color3.fromRGB(130, 95, 200)
		else Color3.fromRGB(60, 55, 75)
end

RunService.RenderStepped:Connect(refresh)

rebirthButton.Activated:Connect(function()
	rebirthRemote:FireServer()
end)

--------------------------------------------------------------------------------
-- Powiadomienia z serwera
--------------------------------------------------------------------------------

notifyRemote.OnClientEvent:Connect(function(kind: string, ...)
	local args = { ... }

	if kind == "offline" then
		toast(`Naladowane do pelna po {Format.time(args[1])}`, BROWN)
	elseif kind == "levelUp" then
		toast(`POZIOM {args[1]}! Masz teraz {args[2]} pierdow`, GREEN)
	elseif kind == "mark" then
		toast(`{args[3]} m — nowy rekord kreski → +{Format.short(args[1])} 🏆`, GOLD)
	elseif kind == "empty" then
		toast("Pusto. Wroc na ziemie i sie naladuj.", Color3.fromRGB(230, 120, 120))
	elseif kind == "rebirth" then
		toast(`DIETA {args[1]} — wszystko szybciej i mocniej`, Color3.fromRGB(180, 150, 255))
	elseif kind == "rebirthTooPoor" then
		toast(`Brakuje: {Format.short(args[1])}🏆 i {Format.short(args[2])}⭐`, Color3.fromRGB(230, 120, 120))
	end
end)
