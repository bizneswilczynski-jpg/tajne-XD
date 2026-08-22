--!strict
-- Centralne strojenie ekonomii +1 FART & FLY.
-- Wszystkie liczby tutaj -- zero magic numbers w logice gry.
--
-- Petla:
--   1. SPACJA = jeden pierd. Pierd wyrzuca postac w gore -- takze w powietrzu.
--   2. Kazdy pierd to XP. XP wbija POZIOM.
--   3. Poziom podnosi MAKSYMALNA LICZBE PIERDOW: poziom 12 = 12 pierdow.
--      Wyzej lecisz dlatego, ze masz ich WIECEJ, nie dlatego ze sa mocniejsze.
--   4. Pierdy odnawiaja sie w czasie. Strefa pod nogami przyspiesza odnawianie.
--   5. Mapa to kwadratowy plac i jedna linijka bez konca, mierzaca metry.
--      Kreski na linijce daja WINY (raz kazda), rekord wysokosci daje SLAWE.

export type Zone = {
	id: string,
	name: string,
	multiplier: number, -- mnoznik XP dla lotu startujacego z tej strefy
	unlockWins: number,
	unlockFame: number,
	color: Color3,
}

local Config = {}

--------------------------------------------------------------------------------
-- Pierdy: zapas ladunkow skoku
--------------------------------------------------------------------------------

Config.Farts = {
	-- Ile pierdow ma gracz na 1 poziomie. Kazdy poziom dokłada jeden.
	baseMax = 1,
	perLevel = 1,
	-- Minimalny odstep miedzy pierdnieciami, zeby caly zapas nie zszedl w klatce.
	cooldown = 0.15,
	-- Zapas wraca w calosci w chwili dotkniecia ziemi -- bez czekania.
	-- Lot jest wiec jedna decyzja: wystrzelaj wszystko, wylanduj, powtorz.
	refillOnGround = true,
}

function Config.maxFarts(level: number): number
	return Config.Farts.baseMax + (level - 1) * Config.Farts.perLevel
end

-- Co ile sekund serwer przelicza stan. Nie wplywa na tempo, tylko na plynnosc.
Config.TICK = 0.1

-- Maksymalny czas offline, za ktory nadrabiamy odnawianie po powrocie.
Config.OFFLINE_CAP_SECONDS = 8 * 60 * 60

-- Jak czesto serwer zapisuje dane graczy w tle.
Config.AUTOSAVE_INTERVAL = 120

--------------------------------------------------------------------------------
-- Sila pierda
--------------------------------------------------------------------------------

Config.Jump = {
	-- Predkosc pionowa nadawana jednym pierdem. Pierd USTAWIA predkosc, nie
	-- dodaje jej -- inaczej seria pierdniec kumulowalaby sie w nieskonczonosc.
	power = 120,
}

-- Grawitacja swiata.
Config.GRAVITY = 120

-- Ile metrow daje jeden pierd wypuszczony w apogeum. Czysto informacyjne.
function Config.metersPerFart(): number
	return Config.Jump.power ^ 2 / (2 * Config.GRAVITY)
end

--------------------------------------------------------------------------------
-- Poziom (XP z pierdniec)
--------------------------------------------------------------------------------

Config.Level = {
	-- Ile XP daje jedno pierdniecie.
	xpPerFart = 1,
	-- Koszt wbicia poziomu 2, potem mnozony przez growth.
	baseXP = 5,
	growth = 1.3,
	maxLevel = 5_000,
}

function Config.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(Config.Level.baseXP * Config.Level.growth ^ (level - 2))
end

-- Poziom wyliczany z calkowitego XP. Zwraca poziom, nadwyzke i prog nastepnego.
function Config.levelFromXP(xp: number): (number, number, number)
	local level = 1
	local remaining = xp
	local needed = Config.xpForLevel(level + 1)

	while remaining >= needed and level < Config.Level.maxLevel do
		remaining -= needed
		level += 1
		needed = Config.xpForLevel(level + 1)
	end

	return level, remaining, needed
end

--------------------------------------------------------------------------------
-- Mapa: plac i linijka
--------------------------------------------------------------------------------

Config.Map = {
	-- Kwadratowy plac na dole.
	padSize = 160,
	-- Linijka: pionowy slup z podzialka, stojacy przy krawedzi placu.
	rulerX = 0,
	rulerZ = -70,
	rulerWidth = 100,
	rulerDepth = 4,
	-- Co ile metrow jest kolejna kreska z etykieta i WINEM.
	markEvery = 50,
	-- Ile kresek stoi od razu.
	initialMarks = 20,
	-- Gdy gracz zblizy sie na tyle kresek do szczytu, dobudowujemy kolejne --
	-- stad "linijka bez konca".
	buildAheadMarks = 8,
	buildBatch = 12,
	-- Promien wokol osi placu, w ktorym odbiera sie WIN z kreski.
	claimRadius = 90,
}

function Config.markHeight(mark: number): number
	return mark * Config.Map.markEvery
end

function Config.markAtHeight(height: number): number
	if height < Config.Map.markEvery then
		return 0
	end
	return math.floor(height / Config.Map.markEvery)
end

--------------------------------------------------------------------------------
-- Strefy: mnoznik XP
--------------------------------------------------------------------------------
-- Odkad zapas wraca w calosci po ladowaniu, nie ma juz czego przyspieszac --
-- wiec strefa mnozy XP. Mnoznik zapamietujemy w chwili startu z ziemi i trzyma
-- przez CALY lot: startujesz z lepszej wyrzutni, caly lot punktuje lepiej.
-- Kazda strefa wymaga OBU walut naraz.

Config.Zones = {
	{ id = "beans", name = "Fasola", multiplier = 2, unlockWins = 0, unlockFame = 0, color = Color3.fromRGB(196, 132, 74) },
	{ id = "cabbage", name = "Kapusta", multiplier = 4, unlockWins = 3, unlockFame = 400, color = Color3.fromRGB(140, 200, 120) },
	{ id = "egg", name = "Jajko na twardo", multiplier = 8, unlockWins = 8, unlockFame = 3_000, color = Color3.fromRGB(245, 235, 190) },
	{ id = "kebab", name = "Kebab z budki", multiplier = 16, unlockWins = 18, unlockFame = 12_000, color = Color3.fromRGB(200, 90, 50) },
	{ id = "milk", name = "Mleko po terminie", multiplier = 32, unlockWins = 32, unlockFame = 60_000, color = Color3.fromRGB(235, 240, 250) },
	{ id = "zurek", name = "Zurek z zeszlego roku", multiplier = 64, unlockWins = 50, unlockFame = 300_000, color = Color3.fromRGB(215, 200, 150) },
} :: { Zone }

-- Dlugosc promienia szukajacego strefy pod postacia. HumanoidRootPart siedzi
-- ~3 study nad ziemia, wiec 10 lapie i R6, i R15.
Config.ZONE_RAY_LENGTH = 10

--------------------------------------------------------------------------------
-- WINY -- za kreski na linijce
--------------------------------------------------------------------------------

Config.Wins = {
	base = 1,
	growth = 1.12,
}

function Config.winsForMark(mark: number): number
	if mark < 1 then
		return 0
	end
	return math.max(1, math.floor(Config.Wins.base * Config.Wins.growth ^ (mark - 1)))
end

--------------------------------------------------------------------------------
-- SLAWA -- za kazdy nowy metr rekordu
--------------------------------------------------------------------------------

Config.Fame = {
	perMeter = 4,
}

--------------------------------------------------------------------------------
-- DIETA (rebirth) -- kosztuje obie waluty
--------------------------------------------------------------------------------

Config.Rebirth = {
	baseWins = 30,
	baseFame = 1_200,
	costGrowth = 5,
	-- Mnoznik do tempa odnawiania pierdow.
	multiplierPerLevel = 2,
	-- Mnoznik do sily pojedynczego pierda.
	jumpMultiplier = 1.35,
}

function Config.rebirthWinCost(level: number): number
	return math.floor(Config.Rebirth.baseWins * Config.Rebirth.costGrowth ^ level)
end

function Config.rebirthFameCost(level: number): number
	return math.floor(Config.Rebirth.baseFame * Config.Rebirth.costGrowth ^ level)
end

function Config.rebirthMultiplier(level: number): number
	return Config.Rebirth.multiplierPerLevel ^ level
end

function Config.jumpPower(rebirths: number): number
	return Config.Jump.power * Config.Rebirth.jumpMultiplier ^ rebirths
end

--------------------------------------------------------------------------------
-- Pulapy wysokosci -- feedback na HUD, nic nie blokuja.
--------------------------------------------------------------------------------

Config.Altitudes = {
	{ height = 0, name = "Podloga" },
	{ height = 200, name = "Dach" },
	{ height = 800, name = "Chmury" },
	{ height = 2_000, name = "Stratosfera" },
	{ height = 5_000, name = "Orbita" },
	{ height = 12_000, name = "Kosmos" },
	{ height = 50_000, name = "Nikt nie wie gdzie to jest" },
}

function Config.altitudeName(height: number): string
	local current = Config.Altitudes[1].name
	for _, band in Config.Altitudes do
		if height >= band.height then
			current = band.name
		end
	end
	return current
end

function Config.zoneById(id: string): Zone?
	for _, zone in Config.Zones do
		if zone.id == id then
			return zone
		end
	end
	return nil
end

return Config
