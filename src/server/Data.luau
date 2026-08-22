--!strict
-- Minimalna warstwa zapisu. Swiadomie proste: jeden klucz na gracza,
-- pcall wokol kazdego I/O, autosave + BindToClose.
-- Przy wiekszej skali warto to podmienic na ProfileStore.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type Profile = {
	farts: number, -- XP; nie zuzywa sie, tylko rosnie
	wins: number, -- do wydania (dieta)
	totalWins: number, -- lifetime, odblokowuje strefy
	fame: number, -- do wydania (dieta)
	totalFame: number, -- lifetime, odblokowuje strefy
	rebirths: number,
	bestHeight: number,
	bestFloor: number,
	-- Ktore pietra maja juz odebrany WIN. Klucze to numery pietra jako stringi,
	-- bo DataStore nie przenosi tablic z dziurami.
	claimedFloors: { [string]: boolean },
	lastSeen: number,
}

local Data = {}

local STORE_NAME = "FartFly_v1"
local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore(STORE_NAME)

local function defaultProfile(): Profile
	return {
		farts = 0,
		wins = 0,
		totalWins = 0,
		fame = 0,
		totalFame = 0,
		rebirths = 0,
		bestHeight = 0,
		bestFloor = 0,
		claimedFloors = {},
		lastSeen = os.time(),
	}
end

Data.defaultProfile = defaultProfile

function Data.load(userId: number): Profile
	if not store then
		return defaultProfile()
	end

	local ok, result = pcall(function()
		return store:GetAsync("p_" .. userId)
	end)

	if not ok then
		warn(`[FartFly] nie udalo sie wczytac profilu {userId}: {result}`)
		return defaultProfile()
	end

	if typeof(result) ~= "table" then
		return defaultProfile()
	end

	-- Scalamy z domyslnymi, zeby dodanie nowego pola nie wywalilo starych zapisow.
	local profile = defaultProfile()
	for key, value in result :: any do
		if profile[key] ~= nil then
			profile[key] = value
		end
	end

	-- Pusta tabela zapisana w DataStore wraca jako nil albo jako tablica --
	-- pilnujemy, zeby claimedFloors zawsze bylo slownikiem.
	if typeof(profile.claimedFloors) ~= "table" then
		profile.claimedFloors = {}
	end

	return profile
end

function Data.save(userId: number, profile: Profile): boolean
	if not store then
		return true
	end

	profile.lastSeen = os.time()

	local ok, err = pcall(function()
		store:SetAsync("p_" .. userId, profile)
	end)

	if not ok then
		warn(`[FartFly] nie udalo sie zapisac profilu {userId}: {err}`)
	end
	return ok
end

return Data
