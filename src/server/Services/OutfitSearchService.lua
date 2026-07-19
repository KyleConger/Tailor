local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local Knit = require(Packages.Knit)

local Catalog = require(script.Parent.Parent.Data.OutfitCatalog)

local MIN_RADIUS = 0.025
local MAX_RADIUS = 0.35
local DEFAULT_RADIUS = 0.12
local MAX_RESULTS = 40
local MIN_INCLUDE_COVERAGE = 0.02
local MIN_EXCLUDE_COVERAGE = 0.05
local REQUEST_COOLDOWN = 0.15
local TRY_ON_COOLDOWN = 1

local GENDER_NAMES = {
	[0] = "unclassified",
	[1] = "masculine",
	[2] = "feminine",
}

-- Higher displayPriority sorts first (primary key before color distance).
-- Distances shown to clients stay exact; these values only affect sort order.
local GROUP_PRIORITY = {
	{ match = "parkson", weight = 0.08 },
	{ match = "formalitat", weight = 0.07 },
	{ match = "luckytux", weight = 0.30 },
	{ match = "beneventi", weight = 0.03 },
	{ match = "avrenzi", weight = 0.03 },
	{ match = "obleceni", weight = 0.03 },
	{ match = "henri bendel", weight = 0.03 },
	{ match = "casablanca", weight = 0.03 },
	{ match = "kestrel", weight = 0.02 },
	{ match = "blox channel", weight = 0.02 },
	{ match = "gravelle", weight = 0.01 },
	{ match = "style abby", weight = 0.01 },
}

local function getDisplayPriority(groupName)
	local group = string.lower(groupName or "")
	for _, entry in GROUP_PRIORITY do
		if string.find(group, entry.match, 1, true) then
			return entry.weight
		end
	end

	return 0
end

local function srgbToLinear(value)
	if value <= 0.04045 then
		return value / 12.92
	end
	return ((value + 0.055) / 1.055) ^ 2.4
end

local function rgbToOklab(red, green, blue)
	local r = srgbToLinear(red)
	local g = srgbToLinear(green)
	local b = srgbToLinear(blue)

	local l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
	local m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
	local s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

	local lRoot = l ^ (1 / 3)
	local mRoot = m ^ (1 / 3)
	local sRoot = s ^ (1 / 3)

	return {
		0.2104542553 * lRoot + 0.793617785 * mRoot - 0.0040720468 * sRoot,
		1.9779984951 * lRoot - 2.428592205 * mRoot + 0.4505937099 * sRoot,
		0.0259040371 * lRoot + 0.7827717662 * mRoot - 0.808675766 * sRoot,
	}
end

local function rgb24ToOklab(rgb)
	local red = bit32.extract(rgb, 16, 8) / 255
	local green = bit32.extract(rgb, 8, 8) / 255
	local blue = bit32.extract(rgb, 0, 8) / 255
	return rgbToOklab(red, green, blue)
end

local function color3ToOklab(color)
	return rgbToOklab(color.R, color.G, color.B)
end

local function distance(left, right)
	local dl = left[1] - right[1]
	local da = left[2] - right[2]
	local db = left[3] - right[3]
	return math.sqrt(dl * dl + da * da + db * db)
end

local function rgb24ToHex(rgb)
	return string.format("#%06X", rgb)
end

local function normalizeGender(value)
	if value == nil or value == "all" then
		return nil
	end
	if value == "masculine" then
		return 1
	end
	if value == "feminine" then
		return 2
	end
	if value == "unclassified" then
		return 0
	end
	return false
end

local OutfitSearchService = Knit.CreateService({
	Name = "OutfitSearchService",
	Client = {},
})

function OutfitSearchService:KnitInit()
	self._lastRequest = setmetatable({}, { __mode = "k" })
	self._lastTryOn = setmetatable({}, { __mode = "k" })
	self._palettes = table.create(#Catalog.palettes)

	for index, rawPalette in Catalog.palettes do
		local swatches = table.create(#rawPalette[5])
		for swatchIndex, rawSwatch in rawPalette[5] do
			swatches[swatchIndex] = {
				rgb = rawSwatch[1],
				coverage = rawSwatch[2] / 255,
				lab = rgb24ToOklab(rawSwatch[1]),
			}
		end

		self._palettes[index] = {
			topId = rawPalette[1],
			topName = rawPalette[2],
			topUrl = rawPalette[3],
			thumbnailUrl = rawPalette[4],
			swatches = swatches,
		}
	end

	self._allowedOutfits = {}
	for _, rawOutfit in Catalog.outfits do
		local palette = self._palettes[rawOutfit[1]]
		if palette then
			self._allowedOutfits[string.format("%d:%d", palette.topId, rawOutfit[2])] = true
		end
	end
end

function OutfitSearchService:_validateRequest(request)
	if type(request) ~= "table" then
		return nil, "Request must be a table"
	end
	if typeof(request.include1) ~= "Color3" or typeof(request.include2) ~= "Color3" then
		return nil, "Two included colors are required"
	end
	if request.exclude ~= nil and typeof(request.exclude) ~= "Color3" then
		return nil, "Excluded color must be a Color3"
	end

	local gender = normalizeGender(request.gender)
	if gender == false then
		return nil, "Invalid gender filter"
	end

	return {
		include1 = color3ToOklab(request.include1),
		include2 = color3ToOklab(request.include2),
		exclude = if request.exclude then color3ToOklab(request.exclude) else nil,
		radius = math.clamp(tonumber(request.radius) or DEFAULT_RADIUS, MIN_RADIUS, MAX_RADIUS),
		limit = math.clamp(math.floor(tonumber(request.limit) or 24), 1, MAX_RESULTS),
		gender = gender,
	}, nil
end

function OutfitSearchService:_scorePalette(palette, request)
	if request.exclude then
		for _, swatch in palette.swatches do
			if swatch.coverage >= MIN_EXCLUDE_COVERAGE and distance(request.exclude, swatch.lab) <= request.radius then
				return nil
			end
		end
	end

	local best
	for firstIndex, first in palette.swatches do
		local firstDistance = distance(request.include1, first.lab)
		if first.coverage >= MIN_INCLUDE_COVERAGE and firstDistance <= request.radius then
			for secondIndex, second in palette.swatches do
				if firstIndex ~= secondIndex and second.coverage >= MIN_INCLUDE_COVERAGE then
					local secondDistance = distance(request.include2, second.lab)
					if secondDistance <= request.radius then
						local worstDistance = math.max(firstDistance, secondDistance)
						local averageDistance = (firstDistance + secondDistance) / 2
						local representedCoverage = first.coverage + second.coverage

						if
							not best
							or worstDistance < best.worstDistance
							or (
								worstDistance == best.worstDistance
								and (
									averageDistance < best.averageDistance
									or (
										averageDistance == best.averageDistance
										and representedCoverage > best.representedCoverage
									)
								)
							)
						then
							best = {
								worstDistance = worstDistance,
								averageDistance = averageDistance,
								representedCoverage = representedCoverage,
								firstHex = rgb24ToHex(first.rgb),
								secondHex = rgb24ToHex(second.rgb),
								firstDistance = firstDistance,
								secondDistance = secondDistance,
							}
						end
					end
				end
			end
		end
	end

	return best
end

function OutfitSearchService:Search(request)
	local normalized, validationError = self:_validateRequest(request)
	if not normalized then
		return {
			ok = false,
			error = validationError,
			results = {},
		}
	end

	local paletteScores = {}
	for paletteIndex, palette in self._palettes do
		local score = self:_scorePalette(palette, normalized)
		if score then
			paletteScores[paletteIndex] = score
		end
	end

	local matches = {}
	for _, rawOutfit in Catalog.outfits do
		local paletteIndex = rawOutfit[1]
		local score = paletteScores[paletteIndex]
		if score and (normalized.gender == nil or rawOutfit[5] == normalized.gender) then
			local palette = self._palettes[paletteIndex]
			table.insert(matches, {
				paletteIndex = paletteIndex,
				raw = rawOutfit,
				score = score,
				displayPriority = getDisplayPriority(rawOutfit[7]),
			})
		end
	end

	table.sort(matches, function(left, right)
		if left.displayPriority ~= right.displayPriority then
			return left.displayPriority > right.displayPriority
		end
		if left.score.worstDistance ~= right.score.worstDistance then
			return left.score.worstDistance < right.score.worstDistance
		end
		if left.score.averageDistance ~= right.score.averageDistance then
			return left.score.averageDistance < right.score.averageDistance
		end
		if left.score.representedCoverage ~= right.score.representedCoverage then
			return left.score.representedCoverage > right.score.representedCoverage
		end
		if left.paletteIndex ~= right.paletteIndex then
			return left.paletteIndex < right.paletteIndex
		end
		return left.raw[2] < right.raw[2]
	end)

	local results = {}
	for index = 1, math.min(normalized.limit, #matches) do
		local match = matches[index]
		local palette = self._palettes[match.paletteIndex]
		local raw = match.raw
		results[index] = {
			topId = palette.topId,
			topName = palette.topName,
			topUrl = palette.topUrl,
			bottomId = raw[2],
			bottomName = raw[3],
			bottomUrl = raw[4],
			gender = GENDER_NAMES[raw[5]],
			priceTotal = raw[6],
			groupName = raw[7],
			thumbnailUrl = palette.thumbnailUrl,
			firstHex = match.score.firstHex,
			secondHex = match.score.secondHex,
			firstDistance = match.score.firstDistance,
			secondDistance = match.score.secondDistance,
		}
	end

	return {
		ok = true,
		radius = normalized.radius,
		total = #matches,
		results = results,
		note = "Colors are extracted from the top garment.",
	}
end

function OutfitSearchService.Client:Search(player, request)
	local now = os.clock()
	local previous = OutfitSearchService._lastRequest[player] or 0
	if now - previous < REQUEST_COOLDOWN then
		return {
			ok = false,
			error = "Please wait before searching again",
			results = {},
		}
	end
	OutfitSearchService._lastRequest[player] = now
	return OutfitSearchService:Search(request)
end

function OutfitSearchService.Client:TryOn(player, topId, bottomId)
	topId = tonumber(topId)
	bottomId = tonumber(bottomId)
	if
		not topId
		or not bottomId
		or topId <= 0
		or bottomId <= 0
		or topId ~= math.floor(topId)
		or bottomId ~= math.floor(bottomId)
	then
		return {
			ok = false,
			error = "Invalid outfit",
		}
	end

	local outfitKey = string.format("%d:%d", topId, bottomId)
	if not OutfitSearchService._allowedOutfits[outfitKey] then
		return {
			ok = false,
			error = "That outfit is not in the catalog",
		}
	end

	local now = os.clock()
	local previous = OutfitSearchService._lastTryOn[player] or 0
	if now - previous < TRY_ON_COOLDOWN then
		return {
			ok = false,
			error = "Please wait before trying another outfit",
		}
	end
	OutfitSearchService._lastTryOn[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return {
			ok = false,
			error = "Your character is not ready",
		}
	end

	local success, errorMessage = pcall(function()
		local description = humanoid:GetAppliedDescription()
		description.Shirt = topId
		description.Pants = bottomId
		humanoid:ApplyDescription(description)
		description:Destroy()
	end)

	if not success then
		return {
			ok = false,
			error = "Could not apply outfit: " .. tostring(errorMessage),
		}
	end

	return {
		ok = true,
	}
end

return OutfitSearchService
