-- Stub world for the local patch Border frames tolerate hidden geometry (border_secret.test.mjs):
-- frames with anchors, secret numbers and a backdrop mixin that does what Blizzard's does with the
-- size (BackdropTemplateMixin in Blizzard_SharedXML/Backdrop.lua, WoW Forever build 70938):
-- OnSizeChanged -> OnBackdropSizeChanged -> self:SetupTextureCoordinates() while a backdrop is set,
-- SetBackdrop -> ApplyBackdrop -> self:SetupTextureCoordinates(), and SetupTextureCoordinates
-- divides the width and height by the edge size. Not Blizzard's code: only that behaviour.

-- SECRET NUMBERS: a value that can be passed on and tested with issecretvalue, but any arithmetic
-- or comparison on it throws, as in the game for addon code
local SECRET_MSG = "attempt to perform arithmetic on a secret number value"
local secretMeta = {}
for _, m in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__lt", "__le", "__concat" }) do
	secretMeta[m] = function() error(SECRET_MSG, 2) end
end
secretMeta.__tostring = function() return "<secret number>" end
function Secret()
	return setmetatable({}, secretMeta)
end
function issecretvalue(v)
	return getmetatable(v) == secretMeta
end
ISSECRETVALUE = issecretvalue

-- FRAMES: points relative to other regions; a region is secretly anchored when it is marked
-- (a StatusBar fill with a hidden value) or any of its points is relative to such a region
local Region = {}
Region.__index = Region
local REGIONS = {}
local function newRegion(name, parent)
	local r = setmetatable({ name = name, parent = parent, points = {}, scripts = {}, w = 0, h = 0, shown = true }, Region)
	if name then _G[name] = r end
	REGIONS[#REGIONS + 1] = r
	return r
end
-- the engine after a change of anchors or sizes: every region whose size or secrecy changed gets
-- OnSizeChanged (errors from the scripts go up to the caller, as they would reach the error handler)
local function relayout()
	for _, r in ipairs(REGIONS) do
		local key
		if r:AnchoringSecret() then
			key = "secret"
		else
			local w, h = r:Size()
			key = w .. "x" .. h
		end
		if r.layoutKey ~= key then
			r.layoutKey = key
			r:FireSizeChanged()
		end
	end
end
function Region:GetName() return self.name end
function Region:GetParent() return self.parent end
function Region:SetParent(p) self.parent = p end
function Region:SetSize(w, h) self.w, self.h = w, h; relayout() end
function Region:ClearAllPoints() self.points = {}; relayout() end
function Region:SetPoint(point, rel, relPoint, x, y)
	if type(rel) ~= "table" then rel = self.parent end
	-- setting a point again replaces it, as in the game
	for i = #self.points, 1, -1 do
		if self.points[i].point == point then table.remove(self.points, i) end
	end
	self.points[#self.points + 1] = { point = point, rel = rel }
	relayout()
end
function Region:AnchoringSecret()
	if self.secretMark then return true end
	for _, p in ipairs(self.points) do
		if p.rel and p.rel:AnchoringSecret() then return true end
	end
	return false
end
-- two points (TOPLEFT and BOTTOMRIGHT) take the size of what they are relative to, plus the padding
function Region:Size()
	if #self.points >= 2 and self.points[1].rel then
		local w, h = self.points[1].rel:Size()
		return w + 2 * (self.pad or 0), h + 2 * (self.pad or 0)
	end
	return self.w, self.h
end
function Region:GetWidth()
	if self:AnchoringSecret() then return Secret() end
	return (self:Size())
end
function Region:GetHeight()
	if self:AnchoringSecret() then return Secret() end
	return select(2, self:Size())
end
function Region:GetEffectiveScale() return 0.65 end
function Region:SetScript(k, fn) self.scripts[k] = fn end
function Region:GetScript(k) return self.scripts[k] end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:SetFrameLevel() end
function Region:GetFrameLevel() return 1 end
-- the engine: the size changed (or became secret); scripts run like the game's, errors go up
function Region:FireSizeChanged()
	local s = self.scripts.OnSizeChanged
	if s then s(self) end
end
-- the engine: one frame passes
function Region:Tick()
	local s = self.scripts.OnUpdate
	if s and self.shown then s(self, 0.016) end
end

-- BACKDROP MIXIN (what Blizzard's does with the size; counts and records each computation)
COORDS_RUNS = 0
BackdropTemplateMixin = {}
function BackdropTemplateMixin:OnBackdropSizeChanged()
	if self.backdropInfo then
		self:SetupTextureCoordinates()
	end
end
function BackdropTemplateMixin:GetEdgeSize()
	if self.backdropInfo.edgeSize and self.backdropInfo.edgeSize > 0 then
		return self.backdropInfo.edgeSize
	end
	return 39
end
function BackdropTemplateMixin:SetupTextureCoordinates()
	local width = self:GetWidth()
	local height = self:GetHeight()
	local effectiveScale = self:GetEffectiveScale()
	local edgeSize = self:GetEdgeSize()
	local edgeRepeatX = math.max(0, (width / edgeSize) * effectiveScale - 2 - 0.0625)
	local edgeRepeatY = math.max(0, (height / edgeSize) * effectiveScale - 2 - 0.0625)
	COORDS_RUNS = COORDS_RUNS + 1
	self.coords = { x = edgeRepeatX, y = edgeRepeatY, w = width, h = height }
end
function BackdropTemplateMixin:ApplyBackdrop()
	self:SetupTextureCoordinates()
end
function BackdropTemplateMixin:SetBackdrop(info)
	if info then
		if self.backdropInfo == info then return end
		if not info.edgeFile and not info.bgFile then
			self.backdropInfo = nil
			return
		end
		self.backdropInfo = info
		self:ApplyBackdrop()
	else
		self.backdropInfo = nil
	end
end
function BackdropTemplateMixin:ClearBackdrop() self.backdropInfo = nil end
function BackdropTemplateMixin:SetBackdropBorderColor(r, g, b, a) self.borderColor = { r, g, b, a } end

-- CreateFrame: the template's mixin is copied onto the frame (as Mixin does) and its
-- OnSizeChanged calls the frame's OnBackdropSizeChanged
function CreateFrame(kind, name, parent, template)
	local f = newRegion(name, parent)
	if template == "BackdropTemplate" then
		for k, v in pairs(BackdropTemplateMixin) do f[k] = v end
		f.scripts.OnSizeChanged = function(self) self:OnBackdropSizeChanged() end
	end
	return f
end
UIParent = newRegion("UIParent")
UIParent.w, UIParent.h = 1920, 1080

CDTL3 = { LSM = { Fetch = function(_, kind, name) return name ~= "None" and ("Media\\" .. kind .. "\\" .. name) or nil end } }
