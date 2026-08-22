--!strict
-- Centralne strojenie ekonomii +1 FART & FLY.
-- Wszystkie liczby tutaj -- zero magic numbers w logice gry.

export type Food = {
	id: string,
	name: string,
	rate: number, -- GAZ na sekunde
	unlockAt: number, -- wymagana SLAWA (lifetime)
	color: Color3,
}

local Config = {}

-- Ile GAZU na sekunde daje samo stanie na stolowce, zanim wejda mnozniki.
Config.BASE_RATE = 1

-- Maksymalny czas offline, za ktory naliczamy GAZ po powrocie (8h).
Config.OFFLINE_CAP_SECONDS = 8 * 60 * 60

-- Jak czesto serwer zapisuje dane graczy w tle.
Config.AUTOSAVE_INTERVAL = 120

Config.Foods = {
	{ id = "beans", name = "Fasola", rate = 1, unlockAt = 0, color = Color3.fromRGB(196, 132, 74) },
	{ id = "cabbage", name = "Kapusta", rate = 5, unlockAt = 400, color = Color3.fromRGB(140, 200, 120) },
	{ id = "egg", name = "Jajko na twardo", rate = 25, unlockAt = 8_000, color = Color3.fromRGB(245, 235, 190) },
	{ id = "kebab", name = "Kebab z budki", rate = 120, unlockAt = 120_000, color = Color3.fromRGB(200, 90, 50) },
	{ id = "milk", name = "Mleko po terminie", rate = 600, unlockAt = 2_000_000, color = Color3.fromRGB(235, 240, 250) },
	{ id = "zurek", name = "Zurek z zeszlego roku", rate = 3_000, unlockAt = 40_000_000, color = Color3.fromRGB(215, 200, 150) },
} :: { Food }

-- Pulapy wysokosci -- czysto pod feedback na HUD, nie blokuja niczego.
Config.Altitudes = {
	{ height = 0, name = "Podloga" },
	{ height = 60, name = "Dach" },
	{ height = 250, name = "Chmury" },
	{ height = 900, name = "Stratosfera" },
	{ height = 3_000, name = "Orbita" },
	{ height = 12_000, name = "Kosmos" },
	{ height = 50_000, name = "Nikt nie wie gdzie to jest" },
}

-- PUK: predkosc startowa liczona logarytmicznie, zeby 1000x wiecej gazu
-- nie znaczylo 1000x wyzej (inaczej po godzinie gracz wylatuje poza mape).
Config.Launch = {
	baseVelocity = 60,
	logScale = 58,
	maxVelocity = 4_000,
	minGasToPuk = 5,
}

-- Pierscienie w powietrzu: kazdy zlapany dorzuca procent do SLAWY z lotu.
Config.Rings = {
	count = 14,
	firstHeight = 40,
	spacing = 1.55, -- kazdy kolejny pierscien jest 1.55x wyzej
	radius = 11,
	bonusPerRing = 0.10,
}

-- DIETA (rebirth): kasujemy GAZ i SLAWE za trwaly mnoznik do calego zarobku.
Config.Rebirth = {
	baseCost = 25_000,
	costGrowth = 5,
	multiplierPerLevel = 2, -- mnoznik = multiplierPerLevel ^ poziom
}

function Config.rebirthCost(level: number): number
	return math.floor(Config.Rebirth.baseCost * Config.Rebirth.costGrowth ^ level)
end

function Config.rebirthMultiplier(level: number): number
	return Config.Rebirth.multiplierPerLevel ^ level
end

function Config.launchVelocity(gas: number): number
	local L = Config.Launch
	local v = L.baseVelocity + L.logScale * math.log(1 + math.max(gas, 0), 2)
	return math.min(v, L.maxVelocity)
end

function Config.altitudeName(height: number): string
	local current = Config.Altitudes[1].name
	for _, band in Config.Altitudes do
		if height >= band.height then
			current = band.name
		end
	end
	return current
end

function Config.foodById(id: string): Food?
	for _, food in Config.Foods do
		if food.id == id then
			return food
		end
	end
	return nil
end

return Config
