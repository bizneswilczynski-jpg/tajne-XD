--!strict
-- Budowniczy HUD-u. Uzywany w dwoch miejscach:
--   1. jednorazowo, zeby wstawic gotowy ScreenGui do StarterGui -- wtedy da sie
--      go klikac i stroic recznie w Studio,
--   2. jako awaryjne wyjscie w kliencie, gdyby kogos HUD-u zabraklo.
--
-- Klient NIE tworzy tych elementow sam -- on je tylko ZNAJDUJE po nazwach.
-- Dlatego nazwy ponizej sa kontraktem: mozna zmieniac kolory, rozmiary,
-- czcionki i pozycje, ale nie nazwy i nie zagniezdzenie.

local HudBuilder = {}

HudBuilder.GUI_NAME = "FartFlyHUD"

local BROWN = Color3.fromRGB(170, 125, 65)
local GREEN = Color3.fromRGB(110, 190, 110)
local GOLD = Color3.fromRGB(250, 210, 90)
local DARK = Color3.fromRGB(24, 26, 32)

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

function HudBuilder.build(parent: Instance): ScreenGui
	local screen = Instance.new("ScreenGui")
	screen.Name = HudBuilder.GUI_NAME
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Licznik pierdow -- duzy, na srodku dolu.
	local fartCounter = text(screen, "FartCounter", UDim2.fromOffset(560, 66), UDim2.new(0.5, -280, 1, -196))
	fartCounter.TextXAlignment = Enum.TextXAlignment.Center
	fartCounter.TextColor3 = BROWN
	fartCounter.TextStrokeTransparency = 0.2
	fartCounter.Text = "PIERD: 0/1"

	local heightLabel = text(screen, "Height", UDim2.fromOffset(560, 46), UDim2.new(0.5, -280, 1, -134))
	heightLabel.TextXAlignment = Enum.TextXAlignment.Center
	heightLabel.TextStrokeTransparency = 0.3
	heightLabel.Text = "0 m"

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
	levelText.Text = "Poziom 1"

	local levelProgress = text(levelBar, "Progress", UDim2.new(0, 180, 1, 0), UDim2.new(1, -196, 0, 0))
	levelProgress.TextXAlignment = Enum.TextXAlignment.Right
	levelProgress.ZIndex = 3
	levelProgress.Text = "0/5"

	-- Waluty (prawy gorny rog)
	local wallet = panel(screen, "Wallet")
	wallet.Size = UDim2.fromOffset(230, 106)
	wallet.Position = UDim2.new(1, -246, 0, 16)

	local wins = text(wallet, "Wins", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(12, 8))
	wins.TextColor3 = GOLD
	wins.Text = "0"

	local fame = text(wallet, "Fame", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(12, 42))
	fame.TextColor3 = Color3.fromRGB(200, 160, 255)
	fame.Text = "0"

	local record = text(wallet, "Record", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 74))
	record.TextColor3 = Color3.fromRGB(180, 180, 190)
	record.Text = "rekord 0 m"

	-- Strefa (lewy gorny rog)
	local zone = panel(screen, "Zone")
	zone.Size = UDim2.fromOffset(280, 68)
	zone.Position = UDim2.fromOffset(16, 16)

	local zoneTitle = text(zone, "Title", UDim2.new(1, -20, 0, 30), UDim2.fromOffset(12, 8))
	zoneTitle.TextColor3 = GREEN
	zoneTitle.Text = "Plac"

	local zoneRate = text(zone, "Rate", UDim2.new(1, -20, 0, 22), UDim2.fromOffset(12, 38))
	zoneRate.TextColor3 = Color3.fromRGB(180, 180, 190)
	zoneRate.Text = "+1 pierda/s"

	-- Przycisk DIETY
	local rebirth = Instance.new("TextButton")
	rebirth.Name = "Rebirth"
	rebirth.Size = UDim2.fromOffset(230, 48)
	rebirth.Position = UDim2.new(1, -246, 0, 132)
	rebirth.BackgroundColor3 = Color3.fromRGB(90, 70, 140)
	rebirth.BorderSizePixel = 0
	rebirth.Font = Enum.Font.FredokaOne
	rebirth.TextScaled = true
	rebirth.TextColor3 = Color3.new(1, 1, 1)
	rebirth.Text = "DIETA"
	rebirth.Parent = screen
	corner(rebirth, 10)

	-- Miejsce na komunikaty. Klient wklada tu gotowe kopie Toasts.Template.
	local toasts = Instance.new("Frame")
	toasts.Name = "Toasts"
	toasts.Size = UDim2.fromOffset(400, 300)
	toasts.Position = UDim2.new(0.5, -200, 0, 90)
	toasts.BackgroundTransparency = 1
	toasts.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = toasts

	-- Wzorzec pojedynczego komunikatu. Wylaczony; klient go klonuje.
	-- Zmieniaj go smialo -- wyglad kazdego komunikatu idzie stad.
	local template = Instance.new("TextLabel")
	template.Name = "Template"
	template.Size = UDim2.fromOffset(400, 36)
	template.BackgroundColor3 = DARK
	template.BackgroundTransparency = 0.15
	template.BorderSizePixel = 0
	template.Font = Enum.Font.FredokaOne
	template.TextScaled = true
	template.TextColor3 = Color3.new(1, 1, 1)
	template.Text = ""
	template.Visible = false
	template.LayoutOrder = -1
	template.Parent = toasts
	corner(template, 8)

	screen.Parent = parent
	return screen
end

return HudBuilder
