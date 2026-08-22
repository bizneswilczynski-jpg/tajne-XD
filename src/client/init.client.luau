--!strict
-- HUD budowany z kodu -- zero zaleznosci od recznie klikanych GUI w Studio,
-- wiec caly interfejs jest wersjonowany w gicie razem z logika.

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
local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

local BROWN = Color3.fromRGB(150, 110, 60)
local GREEN = Color3.fromRGB(110, 190, 110)
local GOLD = Color3.fromRGB(250, 210, 90)
local DARK = Color3.fromRGB(24, 26, 32)

--------------------------------------------------------------------------------
-- Sila skoku
--------------------------------------------------------------------------------
-- Musi byc egzekwowana STAD. Postac ma sieciowego wlasciciela po stronie
-- klienta, wiec JumpPower ustawiony przez serwer bywa po cichu nadpisany
-- lokalna wartoscia i przestaje sie replikowac w dol. Serwer liczy poziom
-- i podaje wynik atrybutem; klient tylko go stosuje.

local function applyJumpPower(humanoid: Humanoid)
	local power = player:GetAttribute("JumpPower")
	if typeof(power) ~= "number" then
		return
	end
	humanoid.UseJumpPower = true
	humanoid.JumpPower = power
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	applyJumpPower(humanoid)

	local connection = player:GetAttributeChangedSignal("JumpPower"):Connect(function()
		if humanoid.Parent then
			applyJumpPower(humanoid)
		end
	end)

	humanoid.Died:Connect(function()
		connection:Disconnect()
	end)
end

if player.Character then
	task.spawn(bindCharacter, player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

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

-- Panel fartow i poziomu (lewy gorny rog)
local fartPanel = panel(screen, "FartPanel")
fartPanel.Size = UDim2.fromOffset(300, 132)
fartPanel.Position = UDim2.fromOffset(16, 16)

local fartValue = text(fartPanel, "Value", UDim2.new(1, -20, 0, 42), UDim2.fromOffset(12, 8))
fartValue.TextColor3 = BROWN

local fartRate = text(fartPanel, "Rate", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 52))
fartRate.TextColor3 = Color3.fromRGB(180, 180, 190)

local zoneLabel = text(fartPanel, "Zone", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 74))
zoneLabel.TextColor3 = GREEN

local levelLabel = text(fartPanel, "Level", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 96))
levelLabel.TextColor3 = Color3.fromRGB(140, 200, 255)

-- Pasek postepu poziomu
local barBg = Instance.new("Frame")
barBg.Name = "LevelBar"
barBg.Size = UDim2.new(1, -24, 0, 8)
barBg.Position = UDim2.fromOffset(12, 118)
barBg.BackgroundColor3 = Color3.fromRGB(50, 54, 64)
barBg.BorderSizePixel = 0
barBg.Parent = fartPanel
corner(barBg, 4)

local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(140, 200, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBg
corner(barFill, 4)

-- Panel walut (prawy gorny rog)
local walletPanel = panel(screen, "WalletPanel")
walletPanel.Size = UDim2.fromOffset(240, 112)
walletPanel.Position = UDim2.new(1, -256, 0, 16)

local winsValue = text(walletPanel, "Wins", UDim2.new(1, -20, 0, 34), UDim2.fromOffset(12, 8))
winsValue.TextColor3 = GOLD

local fameValue = text(walletPanel, "Fame", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(12, 44))
fameValue.TextColor3 = Color3.fromRGB(200, 160, 255)

local dietLabel = text(walletPanel, "Diet", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 78))
dietLabel.TextColor3 = Color3.fromRGB(180, 180, 190)

-- Wysokosciomierz (gora, srodek)
local altPanel = panel(screen, "AltPanel")
altPanel.Size = UDim2.fromOffset(240, 74)
altPanel.Position = UDim2.new(0.5, -120, 0, 16)

local altValue = text(altPanel, "Value", UDim2.new(1, -20, 0, 40), UDim2.fromOffset(10, 6))
altValue.TextXAlignment = Enum.TextXAlignment.Center

local altName = text(altPanel, "Name", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(10, 46))
altName.TextXAlignment = Enum.TextXAlignment.Center
altName.TextColor3 = Color3.fromRGB(180, 180, 190)

-- Przycisk DIETY
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.Size = UDim2.fromOffset(240, 52)
rebirthButton.Position = UDim2.new(1, -256, 0, 138)
rebirthButton.BackgroundColor3 = Color3.fromRGB(90, 70, 140)
rebirthButton.BorderSizePixel = 0
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.new(1, 1, 1)
rebirthButton.Text = "DIETA"
rebirthButton.Parent = screen
corner(rebirthButton, 10)

-- Podpowiedz sterowania
local hint = text(screen, "Hint", UDim2.fromOffset(420, 26), UDim2.new(0.5, -210, 1, -46))
hint.TextXAlignment = Enum.TextXAlignment.Center
hint.TextColor3 = Color3.fromRGB(190, 190, 200)
hint.Text = "SPACJA -- skacz. Im wyzszy poziom, tym wyzej."

-- Toasty
local toastHolder = Instance.new("Frame")
toastHolder.Name = "Toasts"
toastHolder.Size = UDim2.fromOffset(360, 300)
toastHolder.Position = UDim2.new(0.5, -180, 0, 104)
toastHolder.BackgroundTransparency = 1
toastHolder.Parent = screen

local toastLayout = Instance.new("UIListLayout")
toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
toastLayout.Padding = UDim.new(0, 6)
toastLayout.Parent = toastHolder

local function toast(message: string, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromOffset(360, 34)
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
	local multiplier = math.max(number("Multiplier"), 1)
	local rate = number("Rate")

	fartValue.Text = `💨 {Format.short(number("Farts"))}`
	fartRate.Text = `+{Format.short(rate)} /s  (dieta x{Format.short(multiplier)})`

	local zoneName = player:GetAttribute("ZoneName")
	local zoneMultiplier = math.max(number("ZoneMultiplier"), 1)
	if typeof(zoneName) == "string" and zoneName ~= "" then
		if player:GetAttribute("ZoneLocked") == true then
			zoneLabel.Text = `🔒 {zoneName} — brak WINOW lub SLAWY`
			zoneLabel.TextColor3 = Color3.fromRGB(230, 120, 120)
		else
			zoneLabel.Text = `{zoneName} · x{Format.short(zoneMultiplier)} tempa`
			zoneLabel.TextColor3 = GREEN
		end
	else
		zoneLabel.Text = "wejdz na strefe, zeby przyspieszyc"
		zoneLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	end

	local level = number("Level")
	local into = number("LevelProgress")
	local needed = number("LevelNeeded")
	levelLabel.Text = `POZIOM {level} · skok {math.floor(number("JumpPower"))}`
	barFill.Size = UDim2.fromScale(if needed > 0 then math.clamp(into / needed, 0, 1) else 1, 1)

	winsValue.Text = `🏆 {Format.short(number("Wins"))} WIN`
	fameValue.Text = `⭐ {Format.short(number("Fame"))} SLAWY`
	dietLabel.Text = `DIETA {number("Rebirths")} · rekord {math.floor(number("BestHeight"))}m`

	local height = number("Height")
	altValue.Text = `{math.floor(height)}m`
	altName.Text = `{Config.altitudeName(height)} · pietro {number("BestFloor")}`

	local winCost = number("RebirthWinCost")
	local fameCost = number("RebirthFameCost")
	local canRebirth = number("Wins") >= winCost and number("Fame") >= fameCost
	rebirthButton.Text = `DIETA · {Format.short(winCost)}🏆 + {Format.short(fameCost)}⭐`
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
		toast(`Pierdziales przez {Format.time(args[2])} → +{Format.short(args[1])} 💨`, BROWN)
	elseif kind == "win" then
		toast(`PIETRO {args[2]} zaliczone → +{Format.short(args[1])} 🏆`, GOLD)
	elseif kind == "rebirth" then
		toast(`DIETA {args[1]} — tempo x{Format.short(Config.rebirthMultiplier(args[1]))}`, Color3.fromRGB(180, 150, 255))
	elseif kind == "rebirthTooPoor" then
		toast(`Brakuje: {Format.short(args[1])}🏆 i {Format.short(args[2])}⭐`, Color3.fromRGB(230, 120, 120))
	end
end)
