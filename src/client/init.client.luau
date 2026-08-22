--!strict
-- Klient NIE buduje HUD-u. HUD stoi w StarterGui jako zwykly ScreenGui, wiec
-- da sie go klikac i stroic recznie w Studio. Ten skrypt tylko go ZNAJDUJE
-- i wpisuje w niego liczby.
--
-- Kontrakt nazw jest w HudBuilder. Kolory, rozmiary, czcionki i pozycje mozna
-- zmieniac dowolnie; nazwy i zagniezdzenie musza zostac.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local sharedFolder = ReplicatedStorage:WaitForChild("Shared")
local Config = require(sharedFolder:WaitForChild("Config"))
local Format = require(sharedFolder:WaitForChild("Format"))
local HudBuilder = require(sharedFolder:WaitForChild("HudBuilder"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local fartRemote = remotes:WaitForChild("Fart") :: RemoteEvent
local blastRemote = remotes:WaitForChild("Blast") :: RemoteEvent
local rebirthRemote = remotes:WaitForChild("Rebirth") :: RemoteEvent
local notifyRemote = remotes:WaitForChild("Notify") :: RemoteEvent

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

ContextActionService:BindAction("Pierd", function(_, state)
	if state == Enum.UserInputState.Begin then
		fartRemote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)

--------------------------------------------------------------------------------
-- Baczki: widoczny oblok, gdy postac zarabia stojac na strefie
--------------------------------------------------------------------------------

local function attachPuff(character: Model)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart

	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Baczki"
	-- Wbudowana tekstura Roblox -- zero zewnetrznych assetow do wgrywania.
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 190, 110), Color3.fromRGB(190, 200, 140))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(2.2, 5)
	emitter.Lifetime = NumberRange.new(0.8, 1.3)
	emitter.Rate = 14
	emitter.Speed = NumberRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.Acceleration = Vector3.new(0, 3, 0)
	emitter.EmissionDirection = Enum.NormalId.Back
	emitter.Enabled = false
	emitter.Parent = root

	return emitter
end

local puff: ParticleEmitter? = nil

-- Zwykly skok Humanoida wylaczony -- caly wznios idzie z pierdow.
local function setupCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	puff = attachPuff(character)
end

if player.Character then
	task.spawn(setupCharacter, player.Character)
end
player.CharacterAdded:Connect(setupCharacter)

player:GetAttributeChangedSignal("Idling"):Connect(function()
	if puff and puff.Parent then
		puff.Enabled = player:GetAttribute("Idling") == true
	end
end)

--------------------------------------------------------------------------------
-- Znalezienie HUD-u
--------------------------------------------------------------------------------

-- HUD przychodzi ze StarterGui. Gdyby go tam nie bylo (np. ktos go skasowal),
-- stawiamy awaryjna kopie, zeby gra dalej dzialala.
local screen = playerGui:FindFirstChild(HudBuilder.GUI_NAME) :: ScreenGui?
if not screen then
	screen = playerGui:WaitForChild(HudBuilder.GUI_NAME, 5) :: ScreenGui?
end
if not screen then
	warn(`[FartFly] brak {HudBuilder.GUI_NAME} w StarterGui -- stawiam awaryjny HUD`)
	screen = HudBuilder.build(playerGui)
end
local hud = screen :: ScreenGui

-- Brakujacy element nie moze wywalic calego skryptu: jesli ktos cos skasuje
-- w Studio, reszta HUD-u ma dzialac dalej.
local missing: { [string]: boolean } = {}
local function find(path: string): any
	local current: Instance? = hud
	for name in string.gmatch(path, "[^%.]+") do
		if not current then
			break
		end
		current = current:FindFirstChild(name)
	end
	if not current and not missing[path] then
		missing[path] = true
		warn(`[FartFly] w HUD brakuje elementu "{path}" -- ta czesc interfejsu nie bedzie sie aktualizowac`)
	end
	return current
end

local fartCounter = find("FartCounter")
local heightLabel = find("Height")
local levelFill = find("LevelBar.Fill")
local levelText = find("LevelBar.Text")
local levelProgress = find("LevelBar.Progress")
local winsValue = find("Wallet.Wins")
local fameValue = find("Wallet.Fame")
local recordValue = find("Wallet.Record")
local zoneTitle = find("Zone.Title")
local zoneRate = find("Zone.Rate")
local rebirthButton = find("Rebirth")
local toastHolder = find("Toasts")
local toastTemplate = find("Toasts.Template")

--------------------------------------------------------------------------------
-- Komunikaty
--------------------------------------------------------------------------------

local function toast(message: string, color: Color3?)
	if not toastHolder or not toastTemplate then
		return
	end

	local label = toastTemplate:Clone()
	label.Name = "Toast"
	label.Visible = true
	label.LayoutOrder = 0
	label.Text = message
	if color then
		label.TextColor3 = color
	end
	label.Parent = toastHolder

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

local BROWN = Color3.fromRGB(170, 125, 65)
local GREEN = Color3.fromRGB(110, 190, 110)
local GOLD = Color3.fromRGB(250, 210, 90)

local function number(name: string): number
	local value = player:GetAttribute(name)
	return if typeof(value) == "number" then value else 0
end

local function refresh()
	local farts = number("Farts")
	local maxFarts = math.max(number("MaxFarts"), 1)

	if fartCounter then
		fartCounter.Text = `PIERD: {farts}/{maxFarts}`
		fartCounter.TextColor3 = if farts > 0 then BROWN else Color3.fromRGB(120, 100, 90)
	end

	if heightLabel then
		heightLabel.Text = `{Format.short(number("Height"))} m  ·  {Config.altitudeName(number("Height"))}`
	end

	local into = number("LevelProgress")
	local needed = number("LevelNeeded")
	if levelText then
		levelText.Text = `Poziom {number("Level")}`
	end
	if levelProgress then
		levelProgress.Text = `{math.floor(into)}/{math.floor(needed)}`
	end
	if levelFill then
		levelFill.Size = UDim2.fromScale(if needed > 0 then math.clamp(into / needed, 0, 1) else 1, 1)
	end

	if winsValue then
		winsValue.Text = `🏆 {Format.short(number("Wins"))}`
	end
	if fameValue then
		fameValue.Text = `⭐ {Format.short(number("Fame"))}`
	end
	if recordValue then
		recordValue.Text = `rekord {Format.short(number("BestHeight"))} m · DIETA {number("Rebirths")}`
	end

	local zoneName = player:GetAttribute("ZoneName")
	local zoneMultiplier = math.max(number("ZoneMultiplier"), 1)
	if zoneTitle and zoneRate then
		if typeof(zoneName) == "string" and zoneName ~= "" then
			if player:GetAttribute("ZoneLocked") == true then
				zoneTitle.Text = `🔒 {zoneName}`
				zoneTitle.TextColor3 = Color3.fromRGB(230, 120, 120)
				zoneRate.Text = "brak WINOW albo SLAWY"
			else
				zoneTitle.Text = zoneName
				zoneTitle.TextColor3 = GREEN
				zoneRate.Text = `baczki +{Format.short(number("IdleXp"))} XP/s`
			end
		else
			zoneTitle.Text = "Plac"
			zoneTitle.TextColor3 = Color3.fromRGB(180, 180, 190)
			zoneRate.Text = "stan na strefie, zeby zbierac XP"
		end

		-- W locie liczy sie mnoznik z chwili startu, nie to co jest pod nogami.
		if player:GetAttribute("Grounded") ~= true then
			zoneTitle.Text = "W POWIETRZU"
			zoneTitle.TextColor3 = Color3.fromRGB(140, 200, 255)
			zoneRate.Text = `lot za x{Format.short(math.max(number("LaunchMultiplier"), 1))} XP`
		end
	end

	if rebirthButton then
		local winCost = number("RebirthWinCost")
		local fameCost = number("RebirthFameCost")
		local canRebirth = number("Wins") >= winCost and number("Fame") >= fameCost
		rebirthButton.Text = `DIETA · {Format.short(winCost)}🏆 {Format.short(fameCost)}⭐`
		rebirthButton.BackgroundColor3 = if canRebirth
			then Color3.fromRGB(130, 95, 200)
			else Color3.fromRGB(60, 55, 75)
	end
end

RunService.RenderStepped:Connect(refresh)

if rebirthButton then
	rebirthButton.Activated:Connect(function()
		rebirthRemote:FireServer()
	end)
end

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
		toast(`{args[3]} m — nowa kreska → +{Format.short(args[1])} 🏆`, GOLD)
	elseif kind == "empty" then
		toast("Pusto. Wroc na ziemie i sie naladuj.", Color3.fromRGB(230, 120, 120))
	elseif kind == "rebirth" then
		toast(`DIETA {args[1]} — wszystko szybciej i mocniej`, Color3.fromRGB(180, 150, 255))
	elseif kind == "rebirthTooPoor" then
		toast(`Brakuje: {Format.short(args[1])}🏆 i {Format.short(args[2])}⭐`, Color3.fromRGB(230, 120, 120))
	end
end)
