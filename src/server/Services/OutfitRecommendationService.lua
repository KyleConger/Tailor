local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RecommendationService = game:GetService("RecommendationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Source = ReplicatedStorage:WaitForChild("Source")
local Knit = require(Packages.Knit)
local Log = require(Source.Log)

local Catalog = require(script.Parent.Parent.Data.OutfitCatalog)

-- Creator Hub recommendation config. Official ranking templates include
-- MaximizeEngagement, MaximizePlays, MaximizeReactions, MaximizeTimespent.
-- Use your experience's configured name if it differs.
local CONFIG_NAME = "Getmoney1"
local LOCATION_ID = "Lobby"
local PAGE_SIZE = 10
local REQUEST_COOLDOWN = 1
local REGISTER_BATCH_SIZE = 8
local REGISTER_BATCH_DELAY = 1.25
local DATASTORE_NAME = "OutfitRecommendationItemIds_v1"
local STUDIO_BLOCKED_MESSAGE =
	"RecommendationService requires a published experience. Studio returns HTTP 403 for RegisterItemAsync."

local IS_STUDIO = RunService:IsStudio()

local GENDER_NAMES = {
	[0] = "unclassified",
	[1] = "masculine",
	[2] = "feminine",
}

local function sanitizeTag(value)
	local text = tostring(value or ""):lower()
	text = text:gsub("[,%s]+", "-")
	text = text:gsub("[^%w%-:]", "")
	return text
end

local function outfitKey(topId, bottomId)
	return string.format("%d:%d", topId, bottomId)
end

local OutfitRecommendationService = Knit.CreateService({
	Name = "OutfitRecommendationService",
	Client = {},
})

function OutfitRecommendationService:KnitInit()
	self._log = Log.ForContext("OutfitRecommendationService")
	self._lastRequest = setmetatable({}, { __mode = "k" })
	self._outfitsByKey = {}
	self._registrationQueue = {}
	self._registeredKeys = {}
	self._registerAttempts = {}
	self._registrationRunning = false
	self._store = nil

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		self._store = store
	else
		self._log:Warn("Recommendation ID DataStore unavailable: {Error}", store)
	end

	for _, rawOutfit in Catalog.outfits do
		local palette = Catalog.palettes[rawOutfit[1]]
		if palette then
			local topId = palette[1]
			local bottomId = rawOutfit[2]
			local key = outfitKey(topId, bottomId)
			local groupTag = "group:" .. sanitizeTag(rawOutfit[7])
			local genderTag = "gender:" .. sanitizeTag(GENDER_NAMES[rawOutfit[5]] or "unclassified")

			self._outfitsByKey[key] = {
				key = key,
				topId = topId,
				topName = palette[2],
				topUrl = palette[3],
				thumbnailUrl = palette[4],
				bottomId = bottomId,
				bottomName = rawOutfit[3],
				bottomUrl = rawOutfit[4],
				gender = GENDER_NAMES[rawOutfit[5]],
				priceTotal = rawOutfit[6],
				groupName = rawOutfit[7],
				customTags = {
					"content:outfit",
					groupTag,
					genderTag,
				},
			}
			table.insert(self._registrationQueue, key)
		end
	end

	self._log:Info("Indexed {Count} outfits for recommendations", #self._registrationQueue)
	if IS_STUDIO then
		self._log:Info(STUDIO_BLOCKED_MESSAGE)
	end
end

function OutfitRecommendationService:KnitStart()
	if IS_STUDIO then
		return
	end

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			self:_ensureRegistration(player)
		end)
	end)

	for _, player in Players:GetPlayers() do
		task.defer(function()
			self:_ensureRegistration(player)
		end)
	end
end

function OutfitRecommendationService:_loadRegisteredKey(key)
	if self._registeredKeys[key] then
		return true
	end
	if not self._store then
		return false
	end

	local success, itemId = pcall(function()
		return self._store:GetAsync(key)
	end)
	if success and type(itemId) == "string" and itemId ~= "" then
		self._registeredKeys[key] = itemId
		return true
	end

	return false
end

function OutfitRecommendationService:_saveRegisteredKey(key, itemId)
	self._registeredKeys[key] = itemId
	if not self._store then
		return
	end

	local success, err = pcall(function()
		self._store:SetAsync(key, itemId)
	end)
	if not success then
		self._log:Warn("Failed to persist recommendation ItemId for {Key}: {Error}", key, err)
	end
end

function OutfitRecommendationService:_registerOutfit(player, key)
	if self:_loadRegisteredKey(key) then
		return true
	end

	local outfit = self._outfitsByKey[key]
	if not outfit then
		return false
	end

	local request = {
		ContentType = Enum.RecommendationItemContentType.Interactive,
		ReferenceId = key,
		Duration = 1,
		Visibility = Enum.RecommendationItemVisibility.Public,
		CustomTags = outfit.customTags,
		Attributes = {
			{
				AssetId = outfit.topId,
				Text = outfit.topName,
				Description = string.format("%s + %s", outfit.topName, outfit.bottomName),
			},
		},
	}

	local success, response = pcall(function()
		return RecommendationService:RegisterItemAsync(player, request)
	end)

	if success and response and response.ItemId then
		self:_saveRegisteredKey(key, response.ItemId)
		return true
	end

	self._log:Warn("RegisterItemAsync failed for {Key}: {Error}", key, response)
	return false
end

function OutfitRecommendationService:_ensureRegistration(player)
	if self._registrationRunning or not player.Parent then
		return
	end

	self._registrationRunning = true
	task.spawn(function()
		local registered = 0
		local failed = 0

		while player.Parent and #self._registrationQueue > 0 do
			local batch = 0
			local deferred = {}

			while batch < REGISTER_BATCH_SIZE and #self._registrationQueue > 0 do
				local key = table.remove(self._registrationQueue, 1)
				if self:_registerOutfit(player, key) then
					registered += 1
					self._registerAttempts[key] = nil
				else
					failed += 1
					local attempts = (self._registerAttempts[key] or 0) + 1
					self._registerAttempts[key] = attempts
					if attempts < 3 then
						table.insert(deferred, key)
					end
				end
				batch += 1
			end

			for _, key in deferred do
				table.insert(self._registrationQueue, key)
			end

			if #self._registrationQueue == 0 then
				break
			end

			task.wait(REGISTER_BATCH_DELAY)
		end

		self._registrationRunning = false
		if registered > 0 or failed > 0 then
			self._log:Info(
				"Recommendation registration progress registered={Registered} failed={Failed} remaining={Remaining}",
				registered,
				failed,
				#self._registrationQueue
			)
		end
	end)
end

function OutfitRecommendationService:_resolveRecommendationItem(item)
	local referenceId = item and item.ReferenceId
	local outfit = referenceId and self._outfitsByKey[referenceId]
	if not outfit then
		return nil
	end

	return {
		itemId = item.ItemId,
		tracingId = item.TracingId,
		referenceId = referenceId,
		topId = outfit.topId,
		topName = outfit.topName,
		topUrl = outfit.topUrl,
		bottomId = outfit.bottomId,
		bottomName = outfit.bottomName,
		bottomUrl = outfit.bottomUrl,
		gender = outfit.gender,
		priceTotal = outfit.priceTotal,
		groupName = outfit.groupName,
		thumbnailUrl = outfit.thumbnailUrl,
	}
end

function OutfitRecommendationService:GenerateForPlayer(player, pageSize)
	if IS_STUDIO then
		return {
			ok = false,
			error = STUDIO_BLOCKED_MESSAGE,
			results = {},
			configName = CONFIG_NAME,
			locationId = LOCATION_ID,
		}
	end

	local request = {
		ConfigName = CONFIG_NAME,
		LocationId = LOCATION_ID,
		PageSize = math.clamp(math.floor(tonumber(pageSize) or PAGE_SIZE), 1, 25),
		CustomContexts = {
			UserId = tostring(player.UserId),
		},
	}

	local success, pagesOrError = pcall(function()
		return RecommendationService:GenerateItemListAsync(request)
	end)

	if not success then
		return {
			ok = false,
			error = tostring(pagesOrError),
			results = {},
			configName = CONFIG_NAME,
			locationId = LOCATION_ID,
		}
	end

	local pageSuccess, currentPage = pcall(function()
		return pagesOrError:GetCurrentPage()
	end)
	if not pageSuccess then
		return {
			ok = false,
			error = tostring(currentPage),
			results = {},
			configName = CONFIG_NAME,
			locationId = LOCATION_ID,
		}
	end

	local results = {}
	for _, item in currentPage do
		local resolved = self:_resolveRecommendationItem(item)
		if resolved then
			table.insert(results, resolved)
		end
	end

	return {
		ok = true,
		results = results,
		configName = CONFIG_NAME,
		locationId = LOCATION_ID,
		registeredRemaining = #self._registrationQueue,
	}
end

function OutfitRecommendationService.Client:GetRecommendations(player, pageSize)
	if IS_STUDIO then
		return {
			ok = false,
			error = STUDIO_BLOCKED_MESSAGE,
			results = {},
		}
	end

	local now = os.clock()
	local previous = OutfitRecommendationService._lastRequest[player] or 0
	if now - previous < REQUEST_COOLDOWN then
		return {
			ok = false,
			error = "Please wait before refreshing recommendations",
			results = {},
		}
	end
	OutfitRecommendationService._lastRequest[player] = now

	task.defer(function()
		OutfitRecommendationService:_ensureRegistration(player)
	end)

	return OutfitRecommendationService:GenerateForPlayer(player, pageSize)
end

return OutfitRecommendationService
