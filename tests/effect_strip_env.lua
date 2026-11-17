-- Stub world for the local patch Effect strip tolerates hidden geometry (effect_strip.test.mjs), on
-- top of border_secret_env.lua (frames with anchors, secret numbers that throw on arithmetic and
-- comparison, issecretvalue). Added here: what the effect strip uses (textures, font strings, width
-- setters) and setters that refuse a secret argument from addon code, as SetWidth, SetHeight and
-- SetSize do in the game (SecretArguments = "AllowedWhenUntainted",
-- SimpleScriptRegionResizingAPIDocumentation.lua, WoW Forever build 70938). Every size setter call
-- is logged in CALLS as "<tag>:<method>(<args>)".
local Region = getmetatable(UIParent)

CALLS = {}
local function log(self, method, ...)
	local args = {}
	for i = 1, select("#", ...) do
		local v = select(i, ...)
		args[#args + 1] = type(v) == "number" and string.format("%.4g", v) or tostring(v)
	end
	CALLS[#CALLS + 1] = (self.tag or "?") .. ":" .. method .. "(" .. table.concat(args, ",") .. ")"
end
local function plainNumber(method, v)
	if ISSECRETVALUE(v) then
		error(method .. ": secret value passed from addon code", 3)
	end
	if type(v) ~= "number" then
		error(method .. ": bad argument (number expected, got " .. type(v) .. ")", 3)
	end
end

local setSize = Region.SetSize
function Region:SetSize(w, h)
	plainNumber("SetSize", w)
	plainNumber("SetSize", h)
	log(self, "SetSize", w, h)
	setSize(self, w, h)
end
function Region:SetWidth(w)
	plainNumber("SetWidth", w)
	log(self, "SetWidth", w)
	setSize(self, w, self.h)
end
function Region:SetHeight(h)
	plainNumber("SetHeight", h)
	log(self, "SetHeight", h)
	setSize(self, self.w, h)
end
function Region:SetAllPoints() self.allPoints = true end
function Region:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetFont(font, size, flags) self.font = font end
function Region:SetText(t) self.text = t end
function Region:SetTextColor(r, g, b) self.textColor = { r, g, b } end
function Region:CreateTexture() return CreateFrame("Texture", nil, self) end
function Region:CreateFontString() return CreateFrame("FontString", nil, self) end

NOW = 100
function GetTime() return NOW end

-- lane icon sizes (lane1 36, lane2 40, lane3 44) differ from the icons' real width in the
-- scenarios, so the source of every width can be told apart
CDTL3.db = { profile = { lanes = {
	lane1 = { icons = { size = 36 } },
	lane2 = { icons = { size = 40 } },
	lane3 = { icons = { size = 44 } },
} } }
CDTL3.cooldowns = {}
