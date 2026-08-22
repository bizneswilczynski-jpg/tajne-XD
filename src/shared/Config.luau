--!strict
-- Centralne strojenie ekonomii +1 FART & FLY.
-- Wszystkie liczby tutaj -- zero magic numbers w logice gry.
--
-- Petla:
--   1. +1 FART co sekunde. Zawsze, nawet na golej podlodze. Fart to XP -- nie
--      zuzywa sie nigdy. Strefa pod nogami mnozy tylko TEMPO naliczania.
--   2. Farty wbijaja POZIOM, a poziom podnosi SILE SKOKU. Skok jest darmowy;
--      z kazdym poziomem postac odbija sie wyzej i siega dalszych pieter rury.
--   3. Rura w gore ma pietra. Kazde pietro to WIN, raz.
--   4. Kazdy nowy metr rekordu wysokosci to SLAWA.
--   5. Strefy i DIETA sa zablokowane OBIEMA walutami naraz.
--   6. DIETA kasuje farty, waluty do wydania i odebrane pietra za trwaly
--      mnoznik tempa -- petla od nowa, szybciej.

export type Zone = {
	id: string,
	name: string,
	multiplier: number, -- ile razy szybciej kapia farty
	unlockWins: number, -- wymagane WINY (lifetime)
	unlockFame: number, -- wymagana SLAWA (lifetime)
	color: Color3,
}

local Config = {}

--------------------------------------------------------------------------------
-- Farty (XP)
--------------------------------------------------------------------------------

-- Baza gatunku: +1 na sekunde, niezaleznie od tego gdzie gracz stoi.
Config.BASE_FART_RATE = 1

-- Co ile sekund serwer dolicza farty. Nie wplywa na tempo, tylko na plynnosc.
Config.FART_TICK = 0.1

-- Maksymalny czas offline, za ktory naliczamy farty po powrocie (8h).
Config.OFFLINE_CAP_SECONDS = 8 * 60 * 60

-- Jak czesto serwer zapisuje dane graczy w tle.
Config.AUTOSAVE_INTERVAL = 120

--------------------------------------------------------------------------------
-- Poziom i sila skoku
--------------------------------------------------------------------------------

Config.Level = {
	-- Ile fartow kosztuje wbicie poziomu 2. Kazdy nastepny mnozy sie przez growth.
	baseXP = 15,
	growth = 1.08,
	-- Sila skoku postaci na poziomie 1. Domyslna Roblox to 50.
	jumpBase = 50,
	-- Ile sily skoku dorzuca kazdy poziom.
	jumpGain = 7,
	-- Sufit sily z samych poziomow. Bez niego postac po nocy AFK wylatuje poza
	-- rure jednym odbiciem. Sufit dotyczy TYLKO czesci z poziomow -- DIETA
	-- mnozy go dalej, wiec rura nigdy nie przestaje sie oplacac.
	jumpCap = 1_400,
	-- Twardy limit poziomu, zeby petla liczaca nie krecila sie w nieskonczonosc.
	maxLevel = 5_000,
}

-- Ile fartow trzeba miec LACZNIE, zeby wbic dany poziom.
function Config.xpForLevel(level: number): number
	if level <= 1 then
		return 0
	end
	return math.floor(Config.Level.baseXP * Config.Level.growth ^ (level - 2))
end

-- Poziom wyliczany z licznika fartow. Zwraca poziom, nadwyzke i prog nastepnego.
function Config.levelFromFarts(farts: number): (number, number, number)
	local level = 1
	local remaining = farts
	local needed = Config.xpForLevel(level + 1)

	while remaining >= needed and level < Config.Level.maxLevel do
		remaining -= needed
		level += 1
		needed = Config.xpForLevel(level + 1)
	end

	return level, remaining, needed
end

-- Sila skoku = poziom (z sufitem) razy mnoznik z DIETY.
-- Gdyby DIETA nie ruszala sily skoku, gra konczylaby sie na pietrze ~50:
-- po dobiciu sufitu zaden dalszy postep nie otwieralby juz nowych pieter.
function Config.jumpPower(level: number, rebirths: number?): number
	local L = Config.Level
	local fromLevels = math.min(L.jumpBase + (level - 1) * L.jumpGain, L.jumpCap)
	return fromLevels * Config.Rebirth.jumpMultiplier ^ (rebirths or 0)
end

-- Ile studow wzniosu daje dana sila skoku przy naszej grawitacji.
-- Czysto informacyjne -- na HUD i do strojenia rozstawu pieter.
function Config.jumpHeight(power: number): number
	return power * power / (2 * Config.GRAVITY)
end

--------------------------------------------------------------------------------
-- Strefy przyspieszajace
--------------------------------------------------------------------------------
-- Strefa NIE jest zrodlem fartow -- jest mnoznikiem tempa. Stanie na golej
-- podlodze to x1, czyli wciaz +1/s. Kazda strefa wymaga OBU walut naraz.

Config.Zones = {
	{ id = "beans", name = "Fasola", multiplier = 3, unlockWins = 0, unlockFame = 0, color = Color3.fromRGB(196, 132, 74) },
	{ id = "cabbage", name = "Kapusta", multiplier = 10, unlockWins = 2, unlockFame = 400, color = Color3.fromRGB(140, 200, 120) },
	{ id = "egg", name = "Jajko na twardo", multiplier = 40, unlockWins = 6, unlockFame = 3_000, color = Color3.fromRGB(245, 235, 190) },
	{ id = "kebab", name = "Kebab z budki", multiplier = 200, unlockWins = 14, unlockFame = 12_000, color = Color3.fromRGB(200, 90, 50) },
	{ id = "milk", name = "Mleko po terminie", multiplier = 1_200, unlockWins = 26, unlockFame = 120_000, color = Color3.fromRGB(235, 240, 250) },
	{ id = "zurek", name = "Zurek z zeszlego roku", multiplier = 8_000, unlockWins = 42, unlockFame = 800_000, color = Color3.fromRGB(215, 200, 150) },
} :: { Zone }

-- Dlugosc promienia szukajacego strefy pod postacia. HumanoidRootPart siedzi
-- ~3 study nad ziemia, wiec 10 lapie i R6, i R15.
Config.ZONE_RAY_LENGTH = 10

--------------------------------------------------------------------------------
-- Swiat
--------------------------------------------------------------------------------

-- Grawitacja swiata. Nizsza niz domyslne 196.2 => skok jest czytelny,
-- a opadanie miedzy pietrami nie jest karzace.
Config.GRAVITY = 120

Config.Tube = {
	-- Promien wewnetrzny. Musi pomiescic postac z zapasem na sterowanie.
	radius = 26,
	-- Rozstaw pieter ROSNIE z wysokoscia. Staly rozstaw nie dziala: sila skoku
	-- idzie z kwadratem poziomu (10 studow na 1 poziomie, 8100 na 194), wiec
	-- przy stalym rozstawie gracz najpierw nie doskakuje nigdzie, a potem
	-- przelatuje setki pieter naraz. Rosnacy rozstaw sprawia, ze kazdy poziom
	-- otwiera kolejne pietro -- po jednym, bez przestoju i bez przeskoku.
	floorSpacingBase = 20,
	floorSpacingGrowth = 6,
	-- Wysokosc, na ktorej stoi pietro numer 1.
	firstFloorHeight = 30,
	-- Promien pierscienia zbierajacego WIN, liczony od osi rury.
	winRadius = 20,
	-- Ile pieter budujemy na starcie.
	initialFloors = 16,
	-- Gdy gracz zblizy sie na tyle pieter do szczytu, dobudowujemy kolejne.
	-- Stad "rura w nieskonczonosc" -- nigdy nie widac konca.
	buildAheadFloors = 6,
	-- Ile pieter dokladamy za jednym razem.
	buildBatch = 8,
	-- Szerokosc obwodki, na ktorej gracz laduje.
	ledgeWidth = 9,
	ledgeThickness = 2,
	-- Sciana rury: pionowe panele, zeby nie dalo sie wypasc na bok.
	wallSegments = 12,
	wallThickness = 2,
	wallTransparency = 0.82,
}

--------------------------------------------------------------------------------
-- WINY -- skokowo, za pietra
--------------------------------------------------------------------------------

Config.Wins = {
	base = 1,
	growth = 1.13,
}

function Config.winsForFloor(floor: number): number
	if floor < 1 then
		return 0
	end
	return math.max(1, math.floor(Config.Wins.base * Config.Wins.growth ^ (floor - 1)))
end

-- Wysokosc pietra przy rosnacym rozstawie: suma ciagu arytmetycznego.
function Config.floorHeight(floor: number): number
	local tube = Config.Tube
	local steps = floor - 1
	return tube.firstFloorHeight
		+ steps * tube.floorSpacingBase
		+ tube.floorSpacingGrowth * steps * (steps - 1) / 2
end

-- Odwrotnosc floorHeight. Rozwiazanie kwadratowe, zeby nie iterowac po
-- tysiacu pieter przy kazdym ticku petli glownej.
function Config.floorAtHeight(height: number): number
	local tube = Config.Tube
	local above = height - tube.firstFloorHeight
	if above < 0 then
		return 0
	end

	local b = tube.floorSpacingBase
	local g = tube.floorSpacingGrowth
	if g <= 0 then
		return math.floor(above / b) + 1
	end

	local linear = b - g / 2
	local steps = (-linear + math.sqrt(linear * linear + 2 * g * above)) / g
	return math.floor(steps) + 1
end

-- Ile studow musi dawac skok, zeby przeskoczyc z danego pietra na nastepne.
-- Sluzy do strojenia -- pokazuje, na ktorym poziomie otwiera sie ktore pietro.
function Config.gapAboveFloor(floor: number): number
	return Config.floorHeight(floor + 1) - Config.floorHeight(floor)
end

--------------------------------------------------------------------------------
-- SLAWA -- plynnie, za rekord wysokosci
--------------------------------------------------------------------------------

Config.Fame = {
	-- SLAWA za kazdy stud POWYZEJ dotychczasowego rekordu. Powtarzanie tej samej
	-- wysokosci nic nie daje -- placimy wylacznie za postep.
	perStud = 4,
}

--------------------------------------------------------------------------------
-- DIETA (rebirth) -- kosztuje OBIE waluty
--------------------------------------------------------------------------------

Config.Rebirth = {
	baseWins = 30,
	baseFame = 1_200,
	costGrowth = 5,
	multiplierPerLevel = 2, -- mnoznik tempa = multiplierPerLevel ^ poziom
	-- Mnoznik sily skoku za kazda DIETE. To on przebija sufit jumpCap
	-- i sprawia, ze rura ma sens dalej niz do pietra ~50.
	jumpMultiplier = 1.5,
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

--------------------------------------------------------------------------------
-- Pulapy wysokosci -- czysto pod feedback na HUD, nie blokuja niczego.
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
