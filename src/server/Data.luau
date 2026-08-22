--!strict
-- Minimalna warstwa zapisu. Swiadomie proste: jeden klucz na gracza,
-- pcall wokol kazdego I/O, autosave + BindToClose.
-- Przy wiekszej skali warto to podmienic na ProfileStore.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

export type Profile = {
	gas: number,
	fame: number, -- do wydania (dieta)
	totalFame: number, -- lifetime, odblokowuje jedzenie
	rebirths: number,
	bestHeight: number,
	lastFoodId: string?,
	lastSeen: number,
}

local Data = {}

local STORE_NAME = "FartFly_v1"
local store = if RunService:IsStudio() then nil else DataStoreService:GetDataStore(STORE_NAME)

local function defaultProfile(): Profile
	return {
		gas = 0,
		fame = 0,
		totalFame = 0,
		rebirths = 0,
		bestHeight = 0,
		lastFoodId = nil,
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
		if profile[key] ~= nil or key == "lastFoodId" then
			profile[key] = value
		end
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
