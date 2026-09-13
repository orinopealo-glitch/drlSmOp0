--[[
	LunkaraUI
	A single-file, production-grade Roblox UI library.

	Visual identity: premium liquid-glass utility menu. Depth comes from layered
	translucent surfaces, soft shadows and restrained edge highlighting — never
	from UIStroke borders. The library intentionally creates zero UIStroke instances.

	Author: written from scratch for the Lunkara project.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")

local LocalPlayer = Players.LocalPlayer

--============================================================
-- LUNKARA ASSETS
--============================================================
-- These are the real Lunkara assets supplied for the project.
local DEFAULT_ICONS = {
	Home = "rbxassetid://81867978804443",
	Components = "rbxassetid://126570555803946",
	Palette = "rbxassetid://122671609869735",
	Settings = "rbxassetid://86564139855583",
	Search = "rbxassetid://86567920400897",
}

local DEFAULT_SOUNDS = {
	Hover = "rbxassetid://139800881181209",
	Click = "rbxassetid://102702078778790",
	Toggle = "rbxassetid://102702078778790",
	Open = "rbxassetid://130359997277952",
	Close = "rbxassetid://130359997277952",
	Notification = "rbxassetid://130359997277952",
}

--============================================================
-- ROOT GUI
--============================================================
-- Normal Roblox experiences should use PlayerGui. CoreGui is intentionally not
-- used: parenting to CoreGui from a LocalScript is not a supported production path.
local function getGuiParent(customParent)
	if customParent and typeof(customParent) == "Instance" then
		return customParent
	end
	if not LocalPlayer then
		error("LunkaraUI must be required from the client")
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

--============================================================
-- THEME
--============================================================
local Lunkara = {}
Lunkara.__index = Lunkara

Lunkara.Version = "2.0.0-liquid-fixed"

-- Muted desaturated sage/pearl. It reads as Lunkara without becoming a neon
-- or generic purple/blue dashboard accent.
local ACCENT = Color3.fromRGB(166, 193, 184)

local function ctxWithParent(ctx, newParent)
	return {
		theme = ctx.theme,
		sounds = ctx.sounds,
		flags = ctx.flags,
		screenGui = ctx.screenGui,
		parent = newParent,
		registerSearch = ctx.registerSearch,
		tab = ctx.tab,
	}
end

local function deepCopy(t)
	if type(t) ~= "table" then return t end
	local copy = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			copy[k] = deepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

local function deepEqual(a, b)
	if typeof(a) ~= typeof(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in pairs(a) do
		if not deepEqual(v, b[k]) then return false end
	end
	for k in pairs(b) do
		if a[k] == nil then return false end
	end
	return true
end

local function normalizeAssetId(value)
	if value == nil then return "" end
	if type(value) == "number" then
		return value > 0 and ("rbxassetid://" .. tostring(value)) or ""
	end
	if type(value) ~= "string" or value == "" or value == "0" or value == "rbxassetid://0" then
		return ""
	end
	if value:find("rbxassetid://", 1, true) or value:find("http", 1, true) then
		return value
	end
	local numeric = tonumber(value)
	return numeric and numeric > 0 and ("rbxassetid://" .. value) or value
end

local function connectLifetime(owner, signal, callback)
	local connection
	connection = signal:Connect(function(...)
		if not owner or not owner.Parent then
			if connection then connection:Disconnect() end
			return
		end
		callback(...)
	end)
	return connection
end

local DefaultTheme = {
	Name = "Liquid",

	Font = Enum.Font.Gotham,
	FontSemibold = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,

	TextSize = {
		Title = 16,
		Body = 13,
		Small = 12,
		Micro = 11,
	},

	Colors = {
		Accent = ACCENT,
		AccentMuted = Color3.fromRGB(88, 108, 102),
		Base = Color3.fromRGB(10, 11, 13),
		SurfaceLow = Color3.fromRGB(17, 19, 21),
		Surface = Color3.fromRGB(23, 26, 28),
		SurfaceHigh = Color3.fromRGB(31, 35, 37),
		SurfaceRaised = Color3.fromRGB(39, 44, 46),
		Sheen = Color3.fromRGB(255, 255, 255),
		TextPrimary = Color3.fromRGB(241, 243, 242),
		TextSecondary = Color3.fromRGB(174, 181, 178),
		TextTertiary = Color3.fromRGB(113, 122, 118),
		TextOnAccent = Color3.fromRGB(13, 18, 16),
		Success = Color3.fromRGB(113, 186, 143),
		Warning = Color3.fromRGB(208, 172, 105),
		Error = Color3.fromRGB(207, 105, 110),
		Info = Color3.fromRGB(137, 169, 188),
		Divider = Color3.fromRGB(255, 255, 255),
	},

	Transparency = {
		Base = 0.08,
		SurfaceLow = 0.18,
		Surface = 0.22,
		SurfaceHigh = 0.18,
		SurfaceRaised = 0.08,
		Sheen = 0.95,
		Divider = 0.94,
		ShadowMin = 0.55,
		ShadowMax = 0.92,
	},

	Radius = {
		Window = UDim.new(0, 12),
		Large = UDim.new(0, 9),
		Medium = UDim.new(0, 7),
		Small = UDim.new(0, 5),
		Pill = UDim.new(1, 0),
	},

	Spacing = { XS = 4, S = 7, M = 11, L = 15, XL = 22 },

	Animation = {
		Fast = 0.12,
		Base = 0.18,
		Slow = 0.26,
		Window = 0.30,
		EasingStyle = Enum.EasingStyle.Quint,
		EasingStyleSoft = Enum.EasingStyle.Quart,
		EasingDirection = Enum.EasingDirection.Out,
	},

	Icons = deepCopy(DEFAULT_ICONS),
	Sounds = deepCopy(DEFAULT_SOUNDS),
	SoundEnabled = true,
	SoundVolume = 0.28,
	AnimationSpeedScale = 1,
	BlurSize = 12,
	WindowSize = Vector2.new(860, 540),
	WindowMinSize = Vector2.new(400, 330),
	SidebarWidth = 58,
	HeaderHeight = 52,
}

local ThemePresets = {
	Liquid = DefaultTheme,
}

--============================================================
-- SIGNAL (tiny, alloc-light)
--============================================================
local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {}, _nextId = 0 }, Signal)
end

function Signal:Connect(fn)
	assert(type(fn) == "function", "Signal:Connect expects a function")
	self._nextId += 1
	local id = self._nextId
	self._handlers[id] = fn
	local handlers = self._handlers
	local conn = { Connected = true }
	function conn:Disconnect()
		if not self.Connected then return end
		self.Connected = false
		handlers[id] = nil
	end
	return conn
end

function Signal:Fire(...)
	for _, fn in pairs(self._handlers) do
		task.spawn(fn, ...)
	end
end

--============================================================
-- SOUND HELPER (safe: skips invalid/blank ids silently)
--============================================================
local SoundHelper = {}
SoundHelper.__index = SoundHelper

function SoundHelper.new(theme)
	local self = setmetatable({}, SoundHelper)
	self.Theme = theme
	self._folder = Instance.new("Folder")
	self._folder.Name = "LunkaraSounds"
	self._folder.Parent = getGuiParent()
	self._cache = {}
	return self
end

function SoundHelper:_isValidId(id)
	return normalizeAssetId(id) ~= ""
end

function SoundHelper:Play(key)
	if not self.Theme.SoundEnabled then return end
	local id = self.Theme.Sounds and self.Theme.Sounds[key]
	if not self:_isValidId(id) then return end

	local ok = pcall(function()
		local snd = self._cache[id]
		if not snd then
			snd = Instance.new("Sound")
			snd.SoundId = normalizeAssetId(id)
			snd.Volume = self.Theme.SoundVolume or 0.28
			snd.Parent = self._folder
			self._cache[id] = snd
		end
		snd:Play()
	end)
	-- silently ignore failures (missing/invalid asset)
	if not ok then return end
end

function SoundHelper:Destroy()
	if self._folder then
		self._folder:Destroy()
	end
end

--============================================================
-- ICON HELPER (safe: never falls back to letters)
--============================================================
local IconHelper = {}

function IconHelper.isValid(id)
	return normalizeAssetId(id) ~= ""
end

function IconHelper.apply(imageLabel, id, color)
	if IconHelper.isValid(id) then
		imageLabel.Image = normalizeAssetId(id)
		imageLabel.ImageColor3 = color
		imageLabel.Visible = true
	else
		-- No fallback glyph per spec — the icon area stays empty rather than
		-- showing a placeholder letter.
		imageLabel.Image = ""
		imageLabel.Visible = false
	end
end

--============================================================
-- TWEEN HELPER
--============================================================
local function scaledDuration(theme, duration)
	return duration * (theme.AnimationSpeedScale or 1)
end

local function tween(theme, instance, duration, props, styleOverride, dirOverride)
	local info = TweenInfo.new(
		scaledDuration(theme, duration),
		styleOverride or theme.Animation.EasingStyle,
		dirOverride or theme.Animation.EasingDirection
	)
	local t = TweenService:Create(instance, info, props)
	t:Play()
	return t
end

--============================================================
-- LOW-LEVEL PRIMITIVES
--============================================================
local Primitives = {}

function Primitives.createFrame(props)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = props.Color or Color3.new(1, 1, 1)
	f.BackgroundTransparency = props.Transparency or 1
	f.BorderSizePixel = 0
	f.Size = props.Size or UDim2.fromScale(1, 1)
	f.Position = props.Position or UDim2.fromScale(0, 0)
	f.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	f.ClipsDescendants = props.Clip or false
	f.ZIndex = props.ZIndex or 1
	f.Name = props.Name or "Frame"
	if props.Corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = props.Corner
		c.Parent = f
	end
	if props.Parent then
		f.Parent = props.Parent
	end
	return f
end

function Primitives.createText(props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = props.Size or UDim2.fromScale(1, 0)
	t.Position = props.Position or UDim2.fromScale(0, 0)
	t.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	t.Font = props.Font or Enum.Font.Gotham
	t.Text = props.Text or ""
	t.TextSize = props.TextSize or 14
	t.TextColor3 = props.Color or Color3.fromRGB(230, 230, 230)
	t.TextXAlignment = props.AlignX or Enum.TextXAlignment.Left
	t.TextYAlignment = props.AlignY or Enum.TextYAlignment.Center
	t.TextTruncate = props.Truncate or Enum.TextTruncate.AtEnd
	t.TextWrapped = props.Wrap or false
	t.RichText = props.RichText or false
	t.ZIndex = props.ZIndex or 1
	t.Name = props.Name or "Text"
	if props.AutoSize then
		t.AutomaticSize = props.AutoSize
	end
	if props.Parent then
		t.Parent = props.Parent
	end
	return t
end

function Primitives.createIcon(props)
	local i = Instance.new("ImageLabel")
	i.BackgroundTransparency = 1
	i.Size = props.Size or UDim2.fromOffset(16, 16)
	i.Position = props.Position or UDim2.fromScale(0, 0)
	i.AnchorPoint = props.AnchorPoint or Vector2.new(0, 0)
	i.ScaleType = Enum.ScaleType.Fit
	i.ZIndex = props.ZIndex or 1
	i.Name = props.Name or "Icon"
	if props.Parent then
		i.Parent = props.Parent
	end
	IconHelper.apply(i, props.Id, props.Color or Color3.new(1, 1, 1))
	return i
end

-- Layered translucent surface: the core of the "liquid glass" look.
-- Built from 2-3 stacked frames rather than a single flat panel + stroke.
function Primitives.createGlassSurface(theme, props)
	local root = Primitives.createFrame({
		Name = props.Name or "Glass",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or theme.Colors.Surface,
		Transparency = props.Transparency or theme.Transparency.Surface,
		Corner = props.Corner or theme.Radius.Medium,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
		Clip = true,
	})

	-- soft top sheen (a slim gradient-lit band, not a stroke)
	if props.Sheen ~= false then
		local sheen = Primitives.createFrame({
			Name = "Sheen",
			Size = UDim2.new(1, 0, 0, math.clamp((props.SheenHeight or 22), 8, 60)),
			Position = UDim2.fromScale(0, 0),
			Color = theme.Colors.Sheen,
			Transparency = theme.Transparency.Sheen,
			ZIndex = (props.ZIndex or 1) + 1,
			Parent = root,
		})
		local grad = Instance.new("UIGradient")
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Rotation = 90
		grad.Parent = sheen
	end

	return root
end

-- Soft external shadow via 9-slice ImageLabel (standard Roblox soft-shadow asset).
function Primitives.createShadow(props)
	local shadow = Instance.new("ImageLabel")
	shadow.Name = "Shadow"
	shadow.BackgroundTransparency = 1
	shadow.Image = "rbxassetid://5761498316" -- Akali-style 9-slice shadow reference supplied for this project
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = props.Transparency or 0.65
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(17, 17, 283, 283)
	shadow.Size = UDim2.new(1, props.Spread or 26, 1, props.Spread or 26)
	shadow.Position = UDim2.fromScale(0.5, 0.5)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.ZIndex = props.ZIndex or 0
	if props.Parent then
		shadow.Parent = props.Parent
	end
	return shadow
end

-- Standardized hover/press/focus interaction wrapper.
function Primitives.createInteraction(theme, sounds, target, opts)
	opts = opts or {}
	local state = { hovering = false, pressed = false, disabled = false }
	local function setHover(value)
		if state.disabled or state.hovering == value then return end
		state.hovering = value
		if opts.onHover then opts.onHover(value) end
		if value and opts.playSound ~= false then sounds:Play("Hover") end
	end
	if target.MouseEnter then target.MouseEnter:Connect(function() setHover(true) end) end
	if target.MouseLeave then target.MouseLeave:Connect(function() setHover(false) end) end
	target.InputBegan:Connect(function(input)
		if state.disabled then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			state.pressed = true
			if opts.onPress then opts.onPress(true) end
		end
	end)
	target.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.ButtonA then
			state.pressed = false
			if opts.onPress then opts.onPress(false) end
		end
	end)
	if target:IsA("GuiButton") then
		target.Activated:Connect(function()
			if state.disabled then return end
			if opts.playSound ~= false then sounds:Play("Click") end
			if opts.onActivate then opts.onActivate() end
		end)
	end
	function state.setDisabled(v) state.disabled = v == true end
	return state
end

-- Standard list layout + padding helper.
function Primitives.createLayout(parent, props)
	props = props or {}
	local layout = Instance.new(props.Grid and "UIGridLayout" or "UIListLayout")
	if props.Grid then
		layout.CellSize = props.CellSize or UDim2.new(0, 100, 0, 100)
		layout.CellPadding = props.CellPadding or UDim2.new(0, 8, 0, 8)
	else
		layout.FillDirection = props.FillDirection or Enum.FillDirection.Vertical
		layout.Padding = UDim.new(0, props.Gap or 8)
		layout.HorizontalAlignment = props.HAlign or Enum.HorizontalAlignment.Left
		layout.VerticalAlignment = props.VAlign or Enum.VerticalAlignment.Top
	end
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = parent

	local padding = Instance.new("UIPadding")
	local p = props.Padding or {}
	padding.PaddingTop = UDim.new(0, p.Top or 0)
	padding.PaddingBottom = UDim.new(0, p.Bottom or 0)
	padding.PaddingLeft = UDim.new(0, p.Left or 0)
	padding.PaddingRight = UDim.new(0, p.Right or 0)
	padding.Parent = parent

	return layout, padding
end

-- Viewport-aware popup container (dropdowns, color picker, context menus).
-- Handles: clamping inside screen bounds, opening upward if no room below,
-- and correct ZIndex layering above everything else.
function Primitives.createPopup(theme, screenGui, sourceFrame, desiredSize, contentBuilder)
	local dismiss = Instance.new("TextButton")
	dismiss.Name = "PopupDismiss"
	dismiss.Text = ""
	dismiss.BackgroundTransparency = 1
	dismiss.AutoButtonColor = false
	dismiss.Size = UDim2.fromScale(1, 1)
	dismiss.ZIndex = 480
	dismiss.Parent = screenGui

	local host = Instance.new("CanvasGroup")
	host.Name = "PopupHost"
	host.BackgroundTransparency = 1
	host.Size = UDim2.fromOffset(desiredSize.X, desiredSize.Y)
	host.ZIndex = 500
	host.GroupTransparency = 1
	host.Parent = screenGui

	Primitives.createShadow({ Parent = host, ZIndex = 499, Transparency = 0.56, Spread = 28 })
	local popup = Primitives.createGlassSurface(theme, {
		Name = "Popup",
		Size = UDim2.fromScale(1, 1),
		Color = theme.Colors.SurfaceRaised,
		Transparency = theme.Transparency.SurfaceRaised,
		Corner = theme.Radius.Medium,
		ZIndex = 501,
		Parent = host,
	})

	local closed = false
	local viewportConnection
	local function reposition()
		if closed or not sourceFrame.Parent or not host.Parent then return end
		local absPos = sourceFrame.AbsolutePosition
		local absSize = sourceFrame.AbsoluteSize
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local w, h = host.AbsoluteSize.X, host.AbsoluteSize.Y
		local x = absPos.X
		local y = absPos.Y + absSize.Y + 6
		if y + h > viewport.Y - 8 then y = absPos.Y - h - 6 end
		x = math.clamp(x, 8, math.max(8, viewport.X - w - 8))
		y = math.clamp(y, 8, math.max(8, viewport.Y - h - 8))
		host.Position = UDim2.fromOffset(x, y)
	end

	local function close()
		if closed then return end
		closed = true
		if viewportConnection then viewportConnection:Disconnect() end
		if dismiss.Parent then dismiss:Destroy() end
		local t = tween(theme, host, theme.Animation.Fast, { GroupTransparency = 1 })
		t.Completed:Connect(function()
			if host.Parent then host:Destroy() end
		end)
	end

	dismiss.MouseButton1Click:Connect(close)
	if contentBuilder then contentBuilder(popup, host, close, reposition) end
	task.defer(reposition)
	if workspace.CurrentCamera then
		viewportConnection = workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(reposition)
	end
	tween(theme, host, theme.Animation.Fast, { GroupTransparency = 0 })
	return popup, close, reposition, host
end

--============================================================
-- FLAGS / CONFIG SYSTEM
--============================================================
local FlagsAPI = {}
FlagsAPI.__index = FlagsAPI

local function encodeConfigValue(value)
	local kind = typeof(value)
	if kind == "Color3" then
		return { __type = "Color3", r = value.R, g = value.G, b = value.B }
	elseif kind == "Vector2" then
		return { __type = "Vector2", x = value.X, y = value.Y }
	elseif kind == "Vector3" then
		return { __type = "Vector3", x = value.X, y = value.Y, z = value.Z }
	elseif kind == "EnumItem" then
		return { __type = "EnumItem", enum = tostring(value.EnumType), name = value.Name }
	elseif type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do out[k] = encodeConfigValue(v) end
		return out
	end
	return value
end

local function decodeConfigValue(value)
	if type(value) ~= "table" then return value end
	if value.__type == "Color3" then return Color3.new(value.r or 1, value.g or 1, value.b or 1) end
	if value.__type == "Vector2" then return Vector2.new(value.x or 0, value.y or 0) end
	if value.__type == "Vector3" then return Vector3.new(value.x or 0, value.y or 0, value.z or 0) end
	if value.__type == "EnumItem" and type(value.enum) == "string" and type(value.name) == "string" then
		local enumName = value.enum:gsub("^Enum%.", "")
		local enumType = Enum[enumName]
		if enumType then return enumType[value.name] end
	end
	local out = {}
	for k, v in pairs(value) do out[k] = decodeConfigValue(v) end
	return out
end

function FlagsAPI.new()
	return setmetatable({ _flags = {}, _callbacks = {} }, FlagsAPI)
end

function FlagsAPI:Register(flagName, defaultValue, callback)
	if not flagName or flagName == "" then return end
	if self._flags[flagName] == nil then self._flags[flagName] = deepCopy(defaultValue) end
	if type(callback) == "function" then
		self._callbacks[flagName] = self._callbacks[flagName] or {}
		table.insert(self._callbacks[flagName], callback)
	end
end

function FlagsAPI:SetFlag(flagName, value, silent)
	if not flagName or flagName == "" then return false end
	if deepEqual(self._flags[flagName], value) then return false end
	self._flags[flagName] = deepCopy(value)
	if not silent then
		for _, cb in ipairs(self._callbacks[flagName] or {}) do
			task.spawn(function()
				local ok, err = pcall(cb, deepCopy(value))
				if not ok then warn("[LunkaraUI] Flag callback error:", err) end
			end)
		end
	end
	return true
end

function FlagsAPI:GetFlag(flagName) return deepCopy(self._flags[flagName]) end
function FlagsAPI:GetFlags() return deepCopy(self._flags) end

function FlagsAPI:Export()
	local serial = {}
	for k, v in pairs(self._flags) do serial[k] = encodeConfigValue(v) end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, serial)
	return ok and encoded or nil
end

function FlagsAPI:Import(jsonString, silent)
	local ok, decoded = pcall(HttpService.JSONDecode, HttpService, jsonString)
	if not ok or type(decoded) ~= "table" then return false end
	for k, v in pairs(decoded) do self:SetFlag(k, decodeConfigValue(v), silent) end
	return true
end

--============================================================
-- NOTIFICATIONS
--============================================================
local NotificationManager = {}
NotificationManager.__index = NotificationManager

function NotificationManager.new(theme, screenGui, sounds)
	local self = setmetatable({}, NotificationManager)
	self.Theme = theme
	self.Sounds = sounds

	self.Container = Primitives.createFrame({
		Name = "Notifications",
		Size = UDim2.new(0, 300, 1, -32),
		Position = UDim2.new(0, 16, 0, 16),
		Parent = screenGui,
		ZIndex = 900,
	})
	Primitives.createLayout(self.Container, {
		Gap = 8,
		VAlign = Enum.VerticalAlignment.Bottom,
		HAlign = Enum.HorizontalAlignment.Left,
	})

	return self
end

local SEMANTIC_COLOR_KEY = {
	Info = "Info",
	Success = "Success",
	Warning = "Warning",
	Error = "Error",
}

function NotificationManager:Notify(opts)
	opts = opts or {}
	local theme = self.Theme
	local kind = opts.Type or "Info"
	local accentColor = theme.Colors[SEMANTIC_COLOR_KEY[kind] or "Info"]
	local card = Instance.new("CanvasGroup")
	card.Name = "Notification"
	card.BackgroundColor3 = theme.Colors.SurfaceHigh
	card.BackgroundTransparency = theme.Transparency.SurfaceHigh
	card.BorderSizePixel = 0
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.GroupTransparency = 1
	card.ZIndex = 901
	card.Parent = self.Container
	local c = Instance.new("UICorner"); c.CornerRadius = theme.Radius.Medium; c.Parent = card
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10); pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12); pad.Parent = card
	local flow = Instance.new("UIListLayout")
	flow.Padding = UDim.new(0, 3); flow.SortOrder = Enum.SortOrder.LayoutOrder; flow.Parent = card
	local titleRow = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 18), Transparency = 1, Parent = card, ZIndex = 902 })
	Primitives.createFrame({ Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(0, 6), Color = accentColor, Corner = UDim.new(1,0), Parent = titleRow, ZIndex = 903 })
	Primitives.createText({ Text = opts.Title or "Notification", Font = theme.FontSemibold, TextSize = theme.TextSize.Body, Color = theme.Colors.TextPrimary, Size = UDim2.new(1,-18,1,0), Position = UDim2.fromOffset(18,0), Parent = titleRow, ZIndex = 903 })
	if opts.Message and opts.Message ~= "" then
		Primitives.createText({ Text = tostring(opts.Message), Font = theme.Font, TextSize = theme.TextSize.Small, Color = theme.Colors.TextSecondary, Size = UDim2.new(1, -18, 0, 0), Position = UDim2.fromOffset(18,0), AutoSize = Enum.AutomaticSize.Y, Wrap = true, Parent = card, ZIndex = 903 })
	end
	self.Sounds:Play("Notification")
	tween(theme, card, theme.Animation.Base, { GroupTransparency = 0 })
	task.delay(opts.Duration or 4, function()
		if not card.Parent then return end
		local t = tween(theme, card, theme.Animation.Base, { GroupTransparency = 1 })
		t.Completed:Connect(function() if card.Parent then card:Destroy() end end)
	end)
end

--============================================================
-- COMPONENT FACTORY
-- Each component has its own visual structure; none inherit a shared
-- "generic control card". Shared bits (row scaffolding, labels) are small
-- helper functions, not a base component class.
--============================================================
local Components = {}

-- shared row scaffold: label on the left, control area on the right.
-- NOT a visual card — purely a layout convenience.
local function controlRow(theme, parent, title, height)
	local row = Primitives.createFrame({
		Name = "Row",
		Size = UDim2.new(1, 0, 0, height or 36),
		Transparency = 1,
		Parent = parent,
	})
	local label = Primitives.createText({
		Name = "Label",
		Text = title or "",
		Font = theme.Font,
		TextSize = theme.TextSize.Body,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(0.55, 0, 1, 0),
		Parent = row,
	})
	return row, label
end

function Components.Button(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local btn = Primitives.createGlassSurface(theme, {
		Name = "Button",
		Size = opts.Size or UDim2.new(1, 0, 0, 34),
		Color = opts.Primary and theme.Colors.Accent or theme.Colors.SurfaceHigh,
		Transparency = opts.Primary and 0.05 or theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = ctx.parent,
		SheenHeight = 10,
	})

	local label = Primitives.createText({
		Text = opts.Title or "Button",
		Font = theme.FontSemibold,
		TextSize = theme.TextSize.Body,
		Color = opts.Primary and theme.Colors.TextOnAccent or theme.Colors.TextPrimary,
		Size = UDim2.fromScale(1, 1),
		AlignX = Enum.TextXAlignment.Center,
		Parent = btn,
	})

	local hitbox = Instance.new("TextButton")
	hitbox.BackgroundTransparency = 1
	hitbox.Text = ""
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.ZIndex = 5
	hitbox.Parent = btn

	local baseColor = btn.BackgroundColor3
	Primitives.createInteraction(theme, sounds, hitbox, {
		onHover = function(hovering)
			tween(theme, btn, theme.Animation.Fast, {
				BackgroundColor3 = hovering and (opts.Primary and theme.Colors.Accent or theme.Colors.SurfaceRaised) or baseColor,
			})
		end,
		onActivate = function()
			if opts.Callback then opts.Callback() end
		end,
	})

	return { Instance = btn }
end

function Components.Toggle(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local flag = opts.Flag
	local value = opts.Default or false

	local row, label = controlRow(theme, ctx.parent, opts.Title, 32)

	-- compact custom switch, no ON/OFF text — state shown via fill + knob position
	local track = Primitives.createFrame({
		Name = "Track",
		Size = UDim2.fromOffset(34, 18),
		Position = UDim2.new(1, -34, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = value and theme.Colors.Accent or theme.Colors.SurfaceHigh,
		Transparency = value and 0.1 or theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Pill,
		Parent = row,
	})

	local knob = Primitives.createFrame({
		Name = "Knob",
		Size = UDim2.fromOffset(14, 14),
		Position = value and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = theme.Colors.TextPrimary,
		Transparency = 0,
		Corner = UDim.new(1, 0),
		Parent = track,
	})

	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.Parent = track

	local function setValue(v, fireCallback)
		value = v
		tween(theme, track, theme.Animation.Base, {
			BackgroundColor3 = v and theme.Colors.Accent or theme.Colors.SurfaceHigh,
			BackgroundTransparency = v and 0.1 or theme.Transparency.SurfaceHigh,
		})
		tween(theme, knob, theme.Animation.Base, {
			Position = v and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
		}, theme.Animation.EasingStyleSoft)
		if flag then ctx.flags:SetFlag(flag, v) end
		if fireCallback ~= false and opts.Callback then opts.Callback(v) end
	end

	hitbox.MouseButton1Click:Connect(function()
		sounds:Play("Toggle")
		setValue(not value)
	end)

	if flag then
		ctx.flags:Register(flag, value, function(v)
			if v ~= value then setValue(v, false) end
		end)
	end

	return { Instance = row, Set = setValue, Get = function() return value end }
end

function Components.Checkbox(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local value = opts.Default or false
	local flag = opts.Flag

	local row, label = controlRow(theme, ctx.parent, opts.Title, 28)
	label.Size = UDim2.new(1, -26, 1, 0)

	local box = Primitives.createFrame({
		Name = "Box",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = value and theme.Colors.Accent or theme.Colors.SurfaceHigh,
		Transparency = value and 0.05 or theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = row,
	})

	local check = Primitives.createText({
		Text = "✓",
		Font = theme.FontBold,
		TextSize = 12,
		Color = theme.Colors.TextOnAccent,
		Size = UDim2.fromScale(1, 1),
		AlignX = Enum.TextXAlignment.Center,
		Parent = box,
	})
	check.Visible = value

	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.Parent = box

	local function setValue(v, fireCallback)
		value = v
		check.Visible = v
		tween(theme, box, theme.Animation.Fast, {
			BackgroundColor3 = v and theme.Colors.Accent or theme.Colors.SurfaceHigh,
			BackgroundTransparency = v and 0.05 or theme.Transparency.SurfaceHigh,
		})
		if flag then ctx.flags:SetFlag(flag, v) end
		if fireCallback ~= false and opts.Callback then opts.Callback(v) end
	end

	hitbox.MouseButton1Click:Connect(function()
		sounds:Play("Toggle")
		setValue(not value)
	end)

	if flag then
		ctx.flags:Register(flag, value, function(v) if v ~= value then setValue(v, false) end end)
	end

	return { Instance = row, Set = setValue, Get = function() return value end }
end

function Components.Slider(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	local min = tonumber(opts.Min) or 0
	local max = tonumber(opts.Max) or 100
	if max < min then min, max = max, min end
	local increment = math.max(tonumber(opts.Increment or opts.Step) or 1, 0.000001)
	local range = math.max(max - min, 0.000001)
	local value = math.clamp(tonumber(opts.Default) or min, min, max)
	local flag = opts.Flag
	local row = Primitives.createFrame({ Name = "Row", Size = UDim2.new(1,0,0,42), Transparency = 1, Parent = ctx.parent })
	Primitives.createText({ Text = opts.Title or "", Font = theme.Font, TextSize = theme.TextSize.Body, Color = theme.Colors.TextPrimary, Size = UDim2.new(0.72,0,0,16), Parent = row })
	local valueLabel = Primitives.createText({ Text = tostring(value) .. (opts.Suffix or ""), Font = theme.FontSemibold, TextSize = theme.TextSize.Small, Color = theme.Colors.TextSecondary, Size = UDim2.new(0.28,0,0,16), Position = UDim2.new(0.72,0,0,0), AlignX = Enum.TextXAlignment.Right, Parent = row })
	local track = Primitives.createFrame({ Name = "Track", Size = UDim2.new(1,0,0,3), Position = UDim2.fromOffset(0,28), Color = theme.Colors.SurfaceRaised, Transparency = 0.15, Corner = theme.Radius.Pill, Parent = row })
	local fill = Primitives.createFrame({ Name = "Fill", Size = UDim2.new(0,0,1,0), Color = theme.Colors.Accent, Corner = theme.Radius.Pill, Parent = track })
	local handle = Primitives.createFrame({ Name = "Handle", Size = UDim2.fromOffset(10,10), AnchorPoint = Vector2.new(0.5,0.5), Color = theme.Colors.TextPrimary, Corner = UDim.new(1,0), Parent = track })
	local hitbox = Instance.new("TextButton"); hitbox.Text=""; hitbox.BackgroundTransparency=1; hitbox.Size=UDim2.new(1,0,0,22); hitbox.Position=UDim2.fromOffset(0,-9); hitbox.Parent=track
	local dragging = false
	local function quantize(v)
		local stepped = min + math.floor(((v - min) / increment) + 0.5) * increment
		return math.clamp(stepped, min, max)
	end
	local function setValue(v, fireCallback, updateFlag)
		value = quantize(tonumber(v) or min)
		local alpha = (value - min) / range
		fill.Size = UDim2.new(alpha,0,1,0); handle.Position = UDim2.new(alpha,0,0.5,0)
		local shown = math.abs(value - math.floor(value)) < 1e-5 and tostring(math.floor(value)) or string.format("%.2f", value):gsub("0+$",""):gsub("%.$","")
		valueLabel.Text = shown .. (opts.Suffix or "")
		if flag and updateFlag ~= false then ctx.flags:SetFlag(flag, value) end
		if fireCallback ~= false and opts.Callback then opts.Callback(value) end
	end
	local function fromInput(input)
		if track.AbsoluteSize.X <= 0 then return end
		local alpha = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(min + range * alpha)
	end
	hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging=true; fromInput(input) end
	end)
	connectLifetime(row, UserInputService.InputChanged, function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then fromInput(input) end
	end)
	connectLifetime(row, UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging=false end
	end)
	if flag then ctx.flags:Register(flag, value, function(v) setValue(v, false, false) end) end
	setValue(value, false, false)
	return { Instance=row, Set=function(v) setValue(v, true, true) end, Get=function() return value end }
end

-- Dropdown (single-select). Searchable + Multi variants build on this.
local function baseDropdown(ctx, opts, isMulti, isSearchable)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local items = deepCopy(opts.Items or {})
	local flag = opts.Flag
	local selected = {}
	if isMulti then
		for _, v in ipairs(opts.Default or {}) do selected[v] = true end
	else
		selected.single = opts.Default or items[1]
	end
	local row = Primitives.createFrame({ Name="Row", Size=UDim2.new(1,0,0,36), Transparency=1, Parent=ctx.parent })
	Primitives.createText({ Text=opts.Title or "", Font=theme.Font, TextSize=theme.TextSize.Body, Color=theme.Colors.TextPrimary, Size=UDim2.new(0.40,0,1,0), Parent=row })
	local control = Primitives.createGlassSurface(theme, { Name="Control", Size=UDim2.new(0.58,0,0,28), Position=UDim2.new(0.42,0,0.5,0), AnchorPoint=Vector2.new(0,0.5), Color=theme.Colors.SurfaceHigh, Transparency=theme.Transparency.SurfaceHigh, Corner=theme.Radius.Small, Parent=row, SheenHeight=8 })
	local valueText = Primitives.createText({ Font=theme.Font, TextSize=theme.TextSize.Small, Color=theme.Colors.TextSecondary, Size=UDim2.new(1,-28,1,0), Position=UDim2.fromOffset(10,0), Truncate=Enum.TextTruncate.AtEnd, Parent=control })
	local chevron = Primitives.createText({ Text="⌄", Font=theme.Font, TextSize=14, Color=theme.Colors.TextTertiary, Size=UDim2.fromOffset(16,16), Position=UDim2.new(1,-20,0.5,0), AnchorPoint=Vector2.new(0,0.5), AlignX=Enum.TextXAlignment.Center, Parent=control })
	local hitbox = Instance.new("TextButton"); hitbox.Text=""; hitbox.BackgroundTransparency=1; hitbox.AutoButtonColor=false; hitbox.Size=UDim2.fromScale(1,1); hitbox.Selectable=true; hitbox.Parent=control
	local isOpen=false; local closePopup=nil
	local function currentValue()
		if not isMulti then return selected.single end
		local out={}; for _, item in ipairs(items) do if selected[item] then table.insert(out,item) end end; return out
	end
	local function refreshText()
		local value=currentValue()
		if isMulti then valueText.Text = #value>0 and table.concat(value,", ") or "None" else valueText.Text = value or "Select..." end
	end
	local function commit(fireCallback, updateFlag)
		refreshText(); local value=currentValue()
		if flag and updateFlag ~= false then ctx.flags:SetFlag(flag, value) end
		if fireCallback ~= false and opts.Callback then opts.Callback(deepCopy(value)) end
	end
	local function setValue(v, fireCallback, updateFlag)
		if isMulti then selected={}; for _, item in ipairs(v or {}) do selected[item]=true end else selected.single=v end
		commit(fireCallback, updateFlag)
	end
	local function openDropdown()
		if isOpen then return end; isOpen=true; sounds:Play("Click"); tween(theme,chevron,theme.Animation.Fast,{Rotation=180})
		local popup, close, reposition, host
		popup, close, reposition, host = Primitives.createPopup(theme, ctx.screenGui, control, Vector2.new(math.max(180, control.AbsoluteSize.X), 120), function(popupFrame, popupHost, popupClose, popupReposition)
			local searchText=""
			local searchBox
			local listTop = isSearchable and 38 or 8
			if isSearchable then
				local searchSurface=Primitives.createGlassSurface(theme,{Size=UDim2.new(1,-16,0,28),Position=UDim2.fromOffset(8,6),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Small,Parent=popupFrame,Sheen=false,ZIndex=503})
				searchBox=Instance.new("TextBox"); searchBox.BackgroundTransparency=1; searchBox.Size=UDim2.new(1,-16,1,0); searchBox.Position=UDim2.fromOffset(8,0); searchBox.Text=""; searchBox.PlaceholderText="Search"; searchBox.ClearTextOnFocus=false; searchBox.Font=theme.Font; searchBox.TextSize=theme.TextSize.Small; searchBox.TextColor3=theme.Colors.TextPrimary; searchBox.TextXAlignment=Enum.TextXAlignment.Left; searchBox.ZIndex=504; searchBox.Parent=searchSurface
			end
			local scroller=Instance.new("ScrollingFrame"); scroller.BackgroundTransparency=1; scroller.BorderSizePixel=0; scroller.Position=UDim2.fromOffset(6,listTop); scroller.Size=UDim2.new(1,-12,1,-listTop-6); scroller.CanvasSize=UDim2.new(); scroller.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroller.ScrollBarThickness=2; scroller.ScrollBarImageColor3=theme.Colors.TextTertiary; scroller.ZIndex=503; scroller.Parent=popupFrame
			local listLayout=Instance.new("UIListLayout"); listLayout.Padding=UDim.new(0,2); listLayout.SortOrder=Enum.SortOrder.LayoutOrder; listLayout.Parent=scroller
			local function render()
				for _, child in ipairs(scroller:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
				local visibleCount=0
				for _, item in ipairs(items) do
					if searchText=="" or string.find(string.lower(tostring(item)), string.lower(searchText),1,true) then
						visibleCount+=1
						local isSelected = (isMulti and selected[item] == true) or ((not isMulti) and selected.single == item); local option=Instance.new("TextButton"); option.Name="Option"; option.Text=tostring(item); option.Font=isSelected and theme.FontSemibold or theme.Font; option.TextSize=theme.TextSize.Small; option.TextColor3=isSelected and theme.Colors.Accent or theme.Colors.TextPrimary; option.TextXAlignment=Enum.TextXAlignment.Left; option.BackgroundColor3=theme.Colors.SurfaceHigh; option.BackgroundTransparency=1; option.BorderSizePixel=0; option.AutoButtonColor=false; option.Size=UDim2.new(1,-2,0,27); option.ZIndex=504; option.Parent=scroller
						local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,9); p.PaddingRight=UDim.new(0,9); p.Parent=option
						option.MouseEnter:Connect(function() tween(theme,option,theme.Animation.Fast,{BackgroundTransparency=0.55}) end)
						option.MouseLeave:Connect(function() tween(theme,option,theme.Animation.Fast,{BackgroundTransparency=1}) end)
						option.MouseButton1Click:Connect(function()
							sounds:Play("Toggle")
							if isMulti then selected[item]=not selected[item]; commit(true,true); render() else selected.single=item; commit(true,true); isOpen=false; tween(theme,chevron,theme.Animation.Fast,{Rotation=0}); popupClose() end
						end)
					end
				end
				local rows=math.clamp(visibleCount,1,6)
				local height=listTop + rows*29 + 8
				popupHost.Size=UDim2.fromOffset(math.max(180, control.AbsoluteSize.X),height); popupFrame.Size=UDim2.fromScale(1,1); task.defer(popupReposition)
			end
			if searchBox then searchBox:GetPropertyChangedSignal("Text"):Connect(function() searchText=searchBox.Text; render() end); task.defer(function() if searchBox.Parent then searchBox:CaptureFocus() end end) end
			render()
		end)
		closePopup=function() if close then close() end; isOpen=false; tween(theme,chevron,theme.Animation.Fast,{Rotation=0}) end
	end
	hitbox.MouseButton1Click:Connect(function() if isOpen then if closePopup then closePopup() end else openDropdown() end end)
	if flag then ctx.flags:Register(flag,currentValue(),function(v) setValue(v,false,false) end) end
	refreshText()
	return { Instance=row, Set=function(v) setValue(v,true,true) end, Get=function() return deepCopy(currentValue()) end, Refresh=function(newItems) items=deepCopy(newItems or {}); setValue(currentValue(),false,false) end }
end

function Components.Dropdown(ctx, opts) return baseDropdown(ctx, opts, false, false) end
function Components.SearchableDropdown(ctx, opts) return baseDropdown(ctx, opts, false, true) end
function Components.MultiDropdown(ctx, opts) return baseDropdown(ctx, opts, true, true) end

function Components.Textbox(ctx, opts)
	opts=opts or {}; local theme=ctx.theme; local flag=opts.Flag; local value=tostring(opts.Default or "")
	local row=controlRow(theme,ctx.parent,opts.Title,32)
	local field=Primitives.createGlassSurface(theme,{Name="Field",Size=UDim2.new(0.5,0,0,26),Position=UDim2.new(1,0,0.5,0),AnchorPoint=Vector2.new(1,0.5),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Small,Parent=row,SheenHeight=6})
	local box=Instance.new("TextBox"); box.BackgroundTransparency=1; box.Size=UDim2.new(1,-16,1,0); box.Position=UDim2.fromOffset(8,0); box.Font=theme.Font; box.TextSize=theme.TextSize.Small; box.TextColor3=theme.Colors.TextPrimary; box.PlaceholderText=opts.Placeholder or ""; box.Text=value; box.ClearTextOnFocus=false; box.TextXAlignment=Enum.TextXAlignment.Left; box.Parent=field
	local function setValue(v,fire,updateFlag) value=tostring(v or ""); box.Text=value; if flag and updateFlag~=false then ctx.flags:SetFlag(flag,value) end; if fire~=false and opts.Callback then opts.Callback(value) end end
	box.FocusLost:Connect(function(enterPressed) value=box.Text; if flag then ctx.flags:SetFlag(flag,value) end; if opts.Callback then opts.Callback(value,enterPressed) end end)
	if flag then ctx.flags:Register(flag,value,function(v) setValue(v,false,false) end) end
	return {Instance=row,Set=function(v) setValue(v,true,true) end,Get=function() return value end}
end

function Components.MultilineTextbox(ctx, opts)
	opts=opts or {}; local theme=ctx.theme; local flag=opts.Flag; local value=tostring(opts.Default or "")
	local wrapper=Primitives.createFrame({Name="Wrapper",Size=UDim2.new(1,0,0,opts.Height or 90),Transparency=1,Parent=ctx.parent})
	Primitives.createText({Text=opts.Title or "",Font=theme.Font,TextSize=theme.TextSize.Body,Color=theme.Colors.TextPrimary,Size=UDim2.new(1,0,0,18),Parent=wrapper})
	local field=Primitives.createGlassSurface(theme,{Name="Field",Size=UDim2.new(1,0,1,-22),Position=UDim2.fromOffset(0,22),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Small,Parent=wrapper})
	local box=Instance.new("TextBox"); box.BackgroundTransparency=1; box.Size=UDim2.new(1,-16,1,-12); box.Position=UDim2.fromOffset(8,6); box.Font=theme.Font; box.TextSize=theme.TextSize.Small; box.TextColor3=theme.Colors.TextPrimary; box.TextXAlignment=Enum.TextXAlignment.Left; box.TextYAlignment=Enum.TextYAlignment.Top; box.TextWrapped=true; box.MultiLine=true; box.ClearTextOnFocus=false; box.Text=value; box.PlaceholderText=opts.Placeholder or ""; box.Parent=field
	local function setValue(v,fire,updateFlag) value=tostring(v or ""); box.Text=value; if flag and updateFlag~=false then ctx.flags:SetFlag(flag,value) end; if fire~=false and opts.Callback then opts.Callback(value) end end
	box.FocusLost:Connect(function() value=box.Text; if flag then ctx.flags:SetFlag(flag,value) end; if opts.Callback then opts.Callback(value) end end)
	if flag then ctx.flags:Register(flag,value,function(v) setValue(v,false,false) end) end
	return {Instance=wrapper,Set=function(v) setValue(v,true,true) end,Get=function() return value end}
end

function Components.Keybind(ctx, opts)
	opts=opts or {}; local theme,sounds=ctx.theme,ctx.sounds; local flag=opts.Flag; local current=opts.Default or Enum.KeyCode.Unknown
	local row=controlRow(theme,ctx.parent,opts.Title,32)
	local field=Primitives.createGlassSurface(theme,{Name="Field",Size=UDim2.fromOffset(92,26),Position=UDim2.new(1,0,0.5,0),AnchorPoint=Vector2.new(1,0.5),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Small,Parent=row,Sheen=false})
	local keyText=Primitives.createText({Text=current~=Enum.KeyCode.Unknown and current.Name or "Unbound",Font=theme.FontSemibold,TextSize=theme.TextSize.Small,Color=theme.Colors.TextSecondary,Size=UDim2.fromScale(1,1),AlignX=Enum.TextXAlignment.Center,Parent=field})
	local hitbox=Instance.new("TextButton"); hitbox.Text=""; hitbox.BackgroundTransparency=1; hitbox.Size=UDim2.fromScale(1,1); hitbox.Selectable=true; hitbox.Parent=field
	local listening=false
	local function setValue(v,fire,updateFlag)
		if typeof(v)=="EnumItem" and v.EnumType==Enum.KeyCode then current=v else current=Enum.KeyCode.Unknown end
		keyText.Text=current~=Enum.KeyCode.Unknown and current.Name or "Unbound"
		if flag and updateFlag~=false then ctx.flags:SetFlag(flag,current) end
		if fire~=false and opts.Callback then opts.Callback(current) end
	end
	hitbox.MouseButton1Click:Connect(function() listening=true; keyText.Text="Press a key"; sounds:Play("Click") end)
	connectLifetime(row,UserInputService.InputBegan,function(input,gp)
		if listening then
			if input.KeyCode==Enum.KeyCode.Escape then listening=false; keyText.Text=current~=Enum.KeyCode.Unknown and current.Name or "Unbound"; return end
			if input.UserInputType==Enum.UserInputType.Keyboard and input.KeyCode~=Enum.KeyCode.Unknown then listening=false; setValue(input.KeyCode,true,true) end
		elseif not gp and current~=Enum.KeyCode.Unknown and input.KeyCode==current and opts.OnPress then opts.OnPress() end
	end)
	if flag then ctx.flags:Register(flag,current,function(v) setValue(v,false,false) end) end
	return {Instance=row,Set=function(v) setValue(v,true,true) end,Get=function() return current end}
end

function Components.ColorPicker(ctx, opts)
	opts=opts or {}; local theme,sounds=ctx.theme,ctx.sounds; local flag=opts.Flag; local color=opts.Default or Color3.new(1,1,1)
	local row=controlRow(theme,ctx.parent,opts.Title,32)
	local swatch=Primitives.createFrame({Name="Swatch",Size=UDim2.fromOffset(28,20),Position=UDim2.new(1,0,0.5,0),AnchorPoint=Vector2.new(1,0.5),Color=color,Corner=theme.Radius.Small,Parent=row})
	local hitbox=Instance.new("TextButton"); hitbox.Text=""; hitbox.BackgroundTransparency=1; hitbox.Size=UDim2.fromScale(1,1); hitbox.Parent=swatch
	local open=false; local closeCurrent
	local function setColor(v,fire,updateFlag)
		if typeof(v)~="Color3" then return end; color=v; swatch.BackgroundColor3=v; if flag and updateFlag~=false then ctx.flags:SetFlag(flag,v) end; if fire~=false and opts.Callback then opts.Callback(v) end
	end
	hitbox.MouseButton1Click:Connect(function()
		if open then if closeCurrent then closeCurrent() end; open=false; return end
		open=true; sounds:Play("Click")
		local h,s,v=color:ToHSV()
		local popup,close=Primitives.createPopup(theme,ctx.screenGui,swatch,Vector2.new(190,178),function(popupFrame,popupHost,popupClose)
			local sv=Primitives.createFrame({Size=UDim2.new(1,-16,0,110),Position=UDim2.fromOffset(8,8),Color=Color3.fromHSV(h,1,1),Corner=theme.Radius.Small,Clip=true,ZIndex=503,Parent=popupFrame})
			local white=Instance.new("Frame"); white.BackgroundColor3=Color3.new(1,1,1); white.BorderSizePixel=0; white.Size=UDim2.fromScale(1,1); white.ZIndex=504; white.Parent=sv
			local wg=Instance.new("UIGradient"); wg.Color=ColorSequence.new(Color3.new(1,1,1)); wg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); wg.Parent=white
			local black=Instance.new("Frame"); black.BackgroundColor3=Color3.new(0,0,0); black.BorderSizePixel=0; black.Size=UDim2.fromScale(1,1); black.ZIndex=505; black.Parent=sv
			local bg=Instance.new("UIGradient"); bg.Rotation=90; bg.Color=ColorSequence.new(Color3.new(0,0,0)); bg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}); bg.Parent=black
			local svCursor=Primitives.createFrame({Size=UDim2.fromOffset(9,9),Position=UDim2.new(s,0,1-v,0),AnchorPoint=Vector2.new(0.5,0.5),Color=theme.Colors.TextPrimary,Corner=UDim.new(1,0),ZIndex=507,Parent=sv})
			local hue=Primitives.createFrame({Size=UDim2.new(1,-16,0,14),Position=UDim2.fromOffset(8,128),Corner=theme.Radius.Small,Clip=true,ZIndex=503,Parent=popupFrame})
			local hg=Instance.new("UIGradient"); local points={}; for i=0,6 do table.insert(points,ColorSequenceKeypoint.new(i/6,Color3.fromHSV(i/6,1,1))) end; hg.Color=ColorSequence.new(points); hg.Parent=hue
			local hueCursor=Primitives.createFrame({Size=UDim2.fromOffset(4,18),Position=UDim2.new(h,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Color=theme.Colors.TextPrimary,Corner=UDim.new(1,0),ZIndex=507,Parent=hue})
			local preview=Primitives.createFrame({Size=UDim2.new(1,-16,0,20),Position=UDim2.fromOffset(8,150),Color=color,Corner=theme.Radius.Small,ZIndex=503,Parent=popupFrame})
			local draggingSV,draggingHue=false,false
			local svInput=Instance.new("TextButton"); svInput.Text=""; svInput.BackgroundTransparency=1; svInput.Size=UDim2.fromScale(1,1); svInput.ZIndex=508; svInput.Parent=sv
			local hueInput=Instance.new("TextButton"); hueInput.Text=""; hueInput.BackgroundTransparency=1; hueInput.Size=UDim2.fromScale(1,1); hueInput.ZIndex=508; hueInput.Parent=hue
			local function updateFromInput(input)
				if draggingSV then local rel=Vector2.new(input.Position.X,input.Position.Y)-sv.AbsolutePosition; s=math.clamp(rel.X/sv.AbsoluteSize.X,0,1); v=1-math.clamp(rel.Y/sv.AbsoluteSize.Y,0,1); svCursor.Position=UDim2.new(s,0,1-v,0)
				elseif draggingHue then h=math.clamp((input.Position.X-hue.AbsolutePosition.X)/hue.AbsoluteSize.X,0,1); hueCursor.Position=UDim2.new(h,0,0.5,0); sv.BackgroundColor3=Color3.fromHSV(h,1,1) else return end
				local c=Color3.fromHSV(h,s,v); preview.BackgroundColor3=c; setColor(c,true,true)
			end
			svInput.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingSV=true; updateFromInput(input) end end)
			hueInput.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingHue=true; updateFromInput(input) end end)
			connectLifetime(popupHost,UserInputService.InputChanged,function(input) if input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch then updateFromInput(input) end end)
			connectLifetime(popupHost,UserInputService.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then draggingSV=false; draggingHue=false end end)
		end)
		closeCurrent=function() close(); open=false end
	end)
	if flag then ctx.flags:Register(flag,color,function(v) setColor(v,false,false) end) end
	return {Instance=row,Set=function(v) setColor(v,true,true) end,Get=function() return color end}
end

function Components.Label(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	return { Instance = Primitives.createText({
		Text = opts.Title or "",
		Font = theme.FontSemibold,
		TextSize = theme.TextSize.Body,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(1, 0, 0, 20),
		Parent = ctx.parent,
	}) }
end

function Components.Paragraph(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	local wrap = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 0), Transparency = 1, Parent = ctx.parent })
	wrap.AutomaticSize = Enum.AutomaticSize.Y

	if opts.Title then
		Primitives.createText({
			Text = opts.Title,
			Font = theme.FontSemibold,
			TextSize = theme.TextSize.Body,
			Color = theme.Colors.TextPrimary,
			Size = UDim2.new(1, 0, 0, 18),
			Parent = wrap,
		})
	end

	Primitives.createText({
		Text = opts.Text or "",
		Font = theme.Font,
		TextSize = theme.TextSize.Small,
		Color = theme.Colors.TextSecondary,
		Size = UDim2.new(1, 0, 0, 0),
		Position = UDim2.new(0, 0, 0, opts.Title and 20 or 0),
		Wrap = true,
		AutoSize = Enum.AutomaticSize.Y,
		Parent = wrap,
	})

	return { Instance = wrap }
end

function Components.Divider(ctx)
	local theme = ctx.theme
	return { Instance = Primitives.createFrame({
		Size = UDim2.new(1, 0, 0, 1),
		Color = theme.Colors.Divider,
		Transparency = theme.Transparency.Divider,
		Parent = ctx.parent,
	}) }
end

function Components.Progress(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	local value = math.clamp(opts.Default or 0, 0, 1)

	local wrap = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 28), Transparency = 1, Parent = ctx.parent })

	if opts.Title then
		Primitives.createText({
			Text = opts.Title,
			Font = theme.Font,
			TextSize = theme.TextSize.Small,
			Color = theme.Colors.TextSecondary,
			Size = UDim2.new(1, 0, 0, 14),
			Parent = wrap,
		})
	end

	local track = Primitives.createFrame({
		Size = UDim2.new(1, 0, 0, 6),
		Position = UDim2.new(0, 0, 0, opts.Title and 18 or 4),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Pill,
		Parent = wrap,
	})

	local fill = Primitives.createFrame({
		Size = UDim2.new(value, 0, 1, 0),
		Color = theme.Colors.Accent,
		Corner = theme.Radius.Pill,
		Parent = track,
	})

	local function set(v)
		value = math.clamp(v, 0, 1)
		tween(theme, fill, theme.Animation.Base, { Size = UDim2.new(value, 0, 1, 0) })
	end

	return { Instance = wrap, Set = set, Get = function() return value end }
end

function Components.Stepper(ctx, opts)
	opts=opts or {}; local theme,sounds=ctx.theme,ctx.sounds; local min,max,step=tonumber(opts.Min) or 0,tonumber(opts.Max) or 10,math.max(tonumber(opts.Step) or 1,0.000001); if max<min then min,max=max,min end; local value=math.clamp(tonumber(opts.Default) or min,min,max); local flag=opts.Flag
	local row=controlRow(theme,ctx.parent,opts.Title,30); local wrap=Primitives.createFrame({Size=UDim2.fromOffset(100,24),Position=UDim2.new(1,0,0.5,0),AnchorPoint=Vector2.new(1,0.5),Transparency=1,Parent=row})
	local function makeBtn(text,x) local b=Primitives.createGlassSurface(theme,{Size=UDim2.fromOffset(24,24),Position=UDim2.fromOffset(x,0),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Small,Parent=wrap,Sheen=false}); Primitives.createText({Text=text,Font=theme.FontBold,TextSize=14,Color=theme.Colors.TextPrimary,Size=UDim2.fromScale(1,1),AlignX=Enum.TextXAlignment.Center,Parent=b}); local h=Instance.new("TextButton"); h.Text=""; h.BackgroundTransparency=1; h.Size=UDim2.fromScale(1,1); h.Parent=b; return h end
	local minus=makeBtn("−",0); local valueLabel=Primitives.createText({Text="",Font=theme.FontSemibold,TextSize=theme.TextSize.Small,Color=theme.Colors.TextPrimary,Size=UDim2.fromOffset(44,24),Position=UDim2.fromOffset(28,0),AlignX=Enum.TextXAlignment.Center,Parent=wrap}); local plus=makeBtn("+",76)
	local function setValue(v,fire,updateFlag) local raw=math.clamp(tonumber(v) or min,min,max); value=math.clamp(min+math.floor(((raw-min)/step)+0.5)*step,min,max); valueLabel.Text=tostring(value); if flag and updateFlag~=false then ctx.flags:SetFlag(flag,value) end; if fire~=false and opts.Callback then opts.Callback(value) end end
	minus.MouseButton1Click:Connect(function() sounds:Play("Click"); setValue(value-step,true,true) end); plus.MouseButton1Click:Connect(function() sounds:Play("Click"); setValue(value+step,true,true) end)
	if flag then ctx.flags:Register(flag,value,function(v) setValue(v,false,false) end) end; setValue(value,false,false)
	return {Instance=row,Set=function(v) setValue(v,true,true) end,Get=function() return value end}
end

function Components.SegmentedControl(ctx, opts)
	opts=opts or {}; local theme,sounds=ctx.theme,ctx.sounds; local items=opts.Items or {}; local selected=opts.Default or items[1]; local flag=opts.Flag
	local wrap=Primitives.createFrame({Size=UDim2.new(1,0,0,opts.Title and 48 or 28),Transparency=1,Parent=ctx.parent}); if opts.Title then Primitives.createText({Text=opts.Title,Font=theme.Font,TextSize=theme.TextSize.Small,Color=theme.Colors.TextSecondary,Size=UDim2.new(1,0,0,16),Parent=wrap}) end
	local track=Primitives.createGlassSurface(theme,{Size=UDim2.new(1,0,0,26),Position=UDim2.fromOffset(0,opts.Title and 20 or 0),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Small,Parent=wrap,Sheen=false})
	local buttons={}; local highlight=Primitives.createFrame({Size=UDim2.new(0,0,1,-4),Position=UDim2.fromOffset(2,2),Color=theme.Colors.Accent,Transparency=0.08,Corner=theme.Radius.Small,Parent=track,ZIndex=2})
	local function setValue(v,fire,updateFlag)
		local idx=table.find(items,v) or 1; selected=items[idx]; local width=1/math.max(#items,1); highlight.Size=UDim2.new(width,-4,1,-4); tween(theme,highlight,theme.Animation.Base,{Position=UDim2.new(width*(idx-1),2,0,2)},theme.Animation.EasingStyleSoft)
		for i,entry in ipairs(buttons) do entry.Label.TextColor3=i==idx and theme.Colors.TextOnAccent or theme.Colors.TextSecondary end
		if flag and updateFlag~=false then ctx.flags:SetFlag(flag,selected) end; if fire~=false and opts.Callback then opts.Callback(selected) end
	end
	local width=1/math.max(#items,1)
	for i,item in ipairs(items) do local btn=Instance.new("TextButton"); btn.Text=""; btn.BackgroundTransparency=1; btn.Size=UDim2.new(width,0,1,0); btn.Position=UDim2.new(width*(i-1),0,0,0); btn.ZIndex=4; btn.Selectable=true; btn.Parent=track; local lbl=Primitives.createText({Text=tostring(item),Font=theme.FontSemibold,TextSize=theme.TextSize.Small,Color=theme.Colors.TextSecondary,Size=UDim2.fromScale(1,1),AlignX=Enum.TextXAlignment.Center,ZIndex=5,Parent=btn}); buttons[i]={Button=btn,Label=lbl}; btn.MouseButton1Click:Connect(function() sounds:Play("Toggle"); setValue(item,true,true) end) end
	if flag then ctx.flags:Register(flag,selected,function(v) setValue(v,false,false) end) end; setValue(selected,false,false)
	return {Instance=wrap,Set=function(v) setValue(v,true,true) end,Get=function() return selected end}
end

function Components.RadioGroup(ctx, opts)
	opts=opts or {}; local theme,sounds=ctx.theme,ctx.sounds; local items=opts.Items or {}; local selected=opts.Default or items[1]; local flag=opts.Flag
	local wrap=Primitives.createFrame({Size=UDim2.new(1,0,0,0),Transparency=1,Parent=ctx.parent}); wrap.AutomaticSize=Enum.AutomaticSize.Y; Primitives.createLayout(wrap,{Gap=5}); local dots={}
	for _,item in ipairs(items) do local r=Primitives.createFrame({Size=UDim2.new(1,0,0,23),Transparency=1,Parent=wrap}); local outer=Primitives.createFrame({Size=UDim2.fromOffset(16,16),Position=UDim2.fromOffset(0,3),Color=theme.Colors.SurfaceHigh,Corner=UDim.new(1,0),Parent=r}); local inner=Primitives.createFrame({Size=UDim2.fromOffset(8,8),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Color=theme.Colors.TextOnAccent,Transparency=1,Corner=UDim.new(1,0),Parent=outer}); Primitives.createText({Text=tostring(item),Font=theme.Font,TextSize=theme.TextSize.Body,Color=theme.Colors.TextPrimary,Size=UDim2.new(1,-25,1,0),Position=UDim2.fromOffset(25,0),Parent=r}); local hb=Instance.new("TextButton"); hb.Text=""; hb.BackgroundTransparency=1; hb.Size=UDim2.fromScale(1,1); hb.Parent=r; dots[item]={outer=outer,inner=inner}; hb.MouseButton1Click:Connect(function() sounds:Play("Toggle"); selected=item; for k,d in pairs(dots) do local on=k==selected; d.outer.BackgroundColor3=on and theme.Colors.Accent or theme.Colors.SurfaceHigh; d.inner.BackgroundTransparency=on and 0 or 1 end; if flag then ctx.flags:SetFlag(flag,selected) end; if opts.Callback then opts.Callback(selected) end end) end
	local function setValue(v,fire,updateFlag) if table.find(items,v) then selected=v end; for k,d in pairs(dots) do local on=k==selected; d.outer.BackgroundColor3=on and theme.Colors.Accent or theme.Colors.SurfaceHigh; d.inner.BackgroundTransparency=on and 0 or 1 end; if flag and updateFlag~=false then ctx.flags:SetFlag(flag,selected) end; if fire~=false and opts.Callback then opts.Callback(selected) end end
	if flag then ctx.flags:Register(flag,selected,function(v) setValue(v,false,false) end) end; setValue(selected,false,false)
	return {Instance=wrap,Set=function(v) setValue(v,true,true) end,Get=function() return selected end}
end

function Components.Badge(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	local kind = opts.Type or "Info"
	local color = theme.Colors[kind] or theme.Colors.Info

	local badge = Primitives.createFrame({
		Size = UDim2.fromOffset(0, 18),
		Color = color,
		Transparency = 0.85,
		Corner = theme.Radius.Pill,
		Parent = ctx.parent,
	})
	badge.AutomaticSize = Enum.AutomaticSize.X
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = badge

	Primitives.createText({
		Text = opts.Title or kind, Font = theme.FontSemibold, TextSize = theme.TextSize.Micro,
		Color = color, Size = UDim2.new(1, 0, 1, 0), AlignX = Enum.TextXAlignment.Center, Parent = badge,
	})

	return { Instance = badge }
end

function Components.Image(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Image = opts.Id or ""
	img.Size = opts.Size or UDim2.new(1, 0, 0, 120)
	img.ScaleType = opts.ScaleType or Enum.ScaleType.Fit
	img.Parent = ctx.parent
	if opts.Corner then
		local c = Instance.new("UICorner")
		c.CornerRadius = opts.Corner
		c.Parent = img
	end
	return { Instance = img }
end

--============================================================
-- SECTION / TAB / WINDOW OBJECT MODEL
--============================================================
local SectionMT = {}
SectionMT.__index = SectionMT

local function newSection(ctx)
	return setmetatable({ _ctx = ctx, _components = {} }, SectionMT)
end

local function addComponent(section, kind, opts)
	local ctx = section._ctx
	opts = opts or {}
	local comp = Components[kind](ctx, opts)
	table.insert(section._components, comp)
	if ctx.registerSearch and opts.Title and opts.Title ~= "" then
		ctx.registerSearch(opts.Title, comp.Instance, ctx.tab)
	end
	return comp
end

function SectionMT:AddButton(o) return addComponent(self, "Button", o) end
function SectionMT:AddToggle(o) return addComponent(self, "Toggle", o) end
function SectionMT:AddCheckbox(o) return addComponent(self, "Checkbox", o) end
function SectionMT:AddSlider(o) return addComponent(self, "Slider", o) end
function SectionMT:AddDropdown(o) return addComponent(self, "Dropdown", o) end
function SectionMT:AddSearchableDropdown(o) return addComponent(self, "SearchableDropdown", o) end
function SectionMT:AddMultiDropdown(o) return addComponent(self, "MultiDropdown", o) end
function SectionMT:AddTextbox(o) return addComponent(self, "Textbox", o) end
function SectionMT:AddMultilineTextbox(o) return addComponent(self, "MultilineTextbox", o) end
function SectionMT:AddKeybind(o) return addComponent(self, "Keybind", o) end
function SectionMT:AddColorPicker(o) return addComponent(self, "ColorPicker", o) end
function SectionMT:AddLabel(o) return addComponent(self, "Label", o) end
function SectionMT:AddParagraph(o) return addComponent(self, "Paragraph", o) end
function SectionMT:AddDivider(o) return addComponent(self, "Divider", o) end
function SectionMT:AddProgress(o) return addComponent(self, "Progress", o) end
function SectionMT:AddStepper(o) return addComponent(self, "Stepper", o) end
function SectionMT:AddSegmentedControl(o) return addComponent(self, "SegmentedControl", o) end
function SectionMT:AddRadioGroup(o) return addComponent(self, "RadioGroup", o) end
function SectionMT:AddBadge(o) return addComponent(self, "Badge", o) end
function SectionMT:AddImage(o) return addComponent(self, "Image", o) end

function SectionMT:AddSubSection(opts)
	opts = opts or {}
	local theme = self._ctx.theme
	local sub = Primitives.createFrame({
		Size = UDim2.new(1, -12, 0, 0),
		Position = UDim2.new(0, 12, 0, 0),
		Transparency = 1,
		Parent = self._ctx.parent,
	})
	sub.AutomaticSize = Enum.AutomaticSize.Y
	Primitives.createLayout(sub, { Gap = theme.Spacing.S })
	if opts.Title then
		Primitives.createText({
			Text = opts.Title, Font = theme.FontSemibold, TextSize = theme.TextSize.Small,
			Color = theme.Colors.TextSecondary, Size = UDim2.new(1, 0, 0, 16), Parent = sub,
		})
	end
	local newCtx = ctxWithParent(self._ctx, sub)
	return newSection(newCtx)
end

--============================================================
-- TAB (page content area)
--============================================================
local TabMT = {}
TabMT.__index = TabMT

function TabMT:AddSection(opts)
	opts=opts or {}; local theme=self._ctx.theme; local column=opts.Column
	local parentContainer=self._page
	if column==1 and self._col1 then parentContainer=self._col1 end
	if column==2 and self._col2 then parentContainer=self._col2 end
	local sectionWrap=Primitives.createFrame({Name="Section",Size=UDim2.new(1,0,0,0),Transparency=1,Parent=parentContainer}); sectionWrap.AutomaticSize=Enum.AutomaticSize.Y
	local surface=Primitives.createGlassSurface(theme,{Name="SectionSurface",Size=UDim2.new(1,0,0,0),Color=theme.Colors.SurfaceLow,Transparency=0.28,Corner=theme.Radius.Large,Parent=sectionWrap,SheenHeight=12}); surface.AutomaticSize=Enum.AutomaticSize.Y
	local pad=Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,theme.Spacing.M); pad.PaddingBottom=UDim.new(0,theme.Spacing.M); pad.PaddingLeft=UDim.new(0,theme.Spacing.M); pad.PaddingRight=UDim.new(0,theme.Spacing.M); pad.Parent=surface
	Primitives.createLayout(surface,{Gap=theme.Spacing.S})
	local collapsed=false; local body; local header
	if opts.Title and opts.Title~="" then
		header=Primitives.createFrame({Size=UDim2.new(1,0,0,20),Transparency=1,Parent=surface,LayoutOrder=0})
		Primitives.createText({Text=opts.Title,Font=theme.FontSemibold,TextSize=theme.TextSize.Body,Color=theme.Colors.TextPrimary,Size=UDim2.new(1,-22,1,0),Parent=header})
		if opts.Collapsible then local chev=Primitives.createText({Text="⌄",Font=theme.Font,TextSize=14,Color=theme.Colors.TextTertiary,Size=UDim2.fromOffset(16,16),Position=UDim2.new(1,-16,0.5,0),AnchorPoint=Vector2.new(0,0.5),AlignX=Enum.TextXAlignment.Center,Parent=header}); local hb=Instance.new("TextButton"); hb.Text=""; hb.BackgroundTransparency=1; hb.Size=UDim2.fromScale(1,1); hb.Parent=header; hb.MouseButton1Click:Connect(function() collapsed=not collapsed; body.Visible=not collapsed; tween(theme,chev,theme.Animation.Fast,{Rotation=collapsed and -90 or 0}) end) end
	end
	body=Primitives.createFrame({Size=UDim2.new(1,0,0,0),Transparency=1,Parent=surface,LayoutOrder=1}); body.AutomaticSize=Enum.AutomaticSize.Y; Primitives.createLayout(body,{Gap=theme.Spacing.S})
	local ctx={theme=self._ctx.theme,sounds=self._ctx.sounds,flags=self._ctx.flags,screenGui=self._ctx.screenGui,parent=body,registerSearch=self._ctx.registerSearch,tab=self}
	if self._ctx.registerSearch and opts.Title then self._ctx.registerSearch(opts.Title,sectionWrap,self) end
	return newSection(ctx)
end

function TabMT:AddTwoColumnLayout()
	if self._twoColumnRow then return self end
	local theme=self._ctx.theme
	local row=Primitives.createFrame({Name="TwoColumnRow",Size=UDim2.new(1,0,0,0),Transparency=1,Parent=self._page})
	local col1=Primitives.createFrame({Name="Column1",Size=UDim2.new(0.5,-theme.Spacing.M/2,0,0),Transparency=1,Parent=row}); local l1=Primitives.createLayout(col1,{Gap=theme.Spacing.M}); col1.AutomaticSize=Enum.AutomaticSize.Y
	local col2=Primitives.createFrame({Name="Column2",Size=UDim2.new(0.5,-theme.Spacing.M/2,0,0),Position=UDim2.new(0.5,theme.Spacing.M/2,0,0),Transparency=1,Parent=row}); local l2=Primitives.createLayout(col2,{Gap=theme.Spacing.M}); col2.AutomaticSize=Enum.AutomaticSize.Y
	local function update()
		local compact = row.AbsoluteSize.X > 0 and row.AbsoluteSize.X < 620
		local h1=l1.AbsoluteContentSize.Y; local h2=l2.AbsoluteContentSize.Y
		if compact then col1.Size=UDim2.new(1,0,0,h1); col1.Position=UDim2.new(); col2.Size=UDim2.new(1,0,0,h2); col2.Position=UDim2.fromOffset(0,h1+theme.Spacing.M); row.Size=UDim2.new(1,0,0,h1+theme.Spacing.M+h2)
		else col1.Size=UDim2.new(0.5,-theme.Spacing.M/2,0,h1); col1.Position=UDim2.new(); col2.Size=UDim2.new(0.5,-theme.Spacing.M/2,0,h2); col2.Position=UDim2.new(0.5,theme.Spacing.M/2,0,0); row.Size=UDim2.new(1,0,0,math.max(h1,h2)) end
	end
	l1:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update); l2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(update); row:GetPropertyChangedSignal("AbsoluteSize"):Connect(update); task.defer(update)
	self._col1=col1; self._col2=col2; self._twoColumnRow=row; return self
end

--============================================================
-- WINDOW
--============================================================
function Lunkara:CreateWindow(opts)
	opts=opts or {}
	local theme=deepCopy(ThemePresets[opts.Theme] or DefaultTheme)
	for k,v in pairs(opts.ThemeOverride or {}) do if type(v)=="table" and type(theme[k])=="table" then for kk,vv in pairs(v) do theme[k][kk]=vv end else theme[k]=v end end
	local parent=getGuiParent(opts.Parent)
	local screenGui=Instance.new("ScreenGui"); screenGui.Name=opts.GuiName or "LunkaraUI"; screenGui.ResetOnSpawn=false; screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Global; screenGui.IgnoreGuiInset=true; screenGui.DisplayOrder=opts.DisplayOrder or 100; screenGui.Parent=parent
	local sounds=SoundHelper.new(theme); local flags=FlagsAPI.new(); local connections={}; local destroyed=false
	-- asset preload is best-effort and never blocks UI startup on failure
	task.spawn(function() local preload={}; for _,id in pairs(theme.Icons or {}) do local image=normalizeAssetId(id); if image~="" then local img=Instance.new("ImageLabel"); img.Image=image; table.insert(preload,img) end end; if #preload>0 then pcall(ContentProvider.PreloadAsync,ContentProvider,preload) end; for _,obj in ipairs(preload) do obj:Destroy() end end)
	local blur
	if opts.BackgroundBlur ~= false then blur=Instance.new("BlurEffect"); blur.Name="LunkaraBlur_"..HttpService:GenerateGUID(false); blur.Size=0; blur.Parent=Lighting; tween(theme,blur,theme.Animation.Window,{Size=opts.BlurSize or theme.BlurSize or 12}) end
	local baseSize=opts.Size or theme.WindowSize
	local shadowHost=Primitives.createFrame({Name="ShadowHost",Size=UDim2.fromOffset(baseSize.X,baseSize.Y),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),Transparency=1,Parent=screenGui})
	Primitives.createShadow({Parent=shadowHost,Spread=50,Transparency=0.58,ZIndex=0})
	local main=Primitives.createGlassSurface(theme,{Name="Main",Size=UDim2.fromScale(1,1),Color=theme.Colors.Base,Transparency=1,Corner=theme.Radius.Window,Parent=shadowHost,Clip=true,ZIndex=2,SheenHeight=26})
	local headerHeight=theme.HeaderHeight or 52; local sidebarWidth=theme.SidebarWidth or 58
	local header=Primitives.createFrame({Name="Header",Size=UDim2.new(1,0,0,headerHeight),Color=theme.Colors.SurfaceLow,Transparency=theme.Transparency.SurfaceLow,Parent=main,ZIndex=3})
	local titleLabel=Primitives.createText({Text=opts.Title or "LunkaraUI",Font=theme.FontBold,TextSize=theme.TextSize.Title,Color=theme.Colors.TextPrimary,Size=UDim2.new(0,200,1,0),Position=UDim2.fromOffset(theme.Spacing.L,0),ZIndex=4,Parent=header})
	local searchWrap=Primitives.createGlassSurface(theme,{Name="HeaderSearch",Size=UDim2.fromOffset(220,30),Position=UDim2.new(0.5,0,0.5,0),AnchorPoint=Vector2.new(0.5,0.5),Color=theme.Colors.SurfaceHigh,Transparency=theme.Transparency.SurfaceHigh,Corner=theme.Radius.Pill,Parent=header,ZIndex=4,Sheen=false})
	Primitives.createIcon({Id=theme.Icons.Search,Color=theme.Colors.TextTertiary,Size=UDim2.fromOffset(13,13),Position=UDim2.fromOffset(10,8.5),ZIndex=5,Parent=searchWrap})
	local searchBox=Instance.new("TextBox"); searchBox.BackgroundTransparency=1; searchBox.Size=UDim2.new(1,-34,1,0); searchBox.Position=UDim2.fromOffset(30,0); searchBox.Font=theme.Font; searchBox.TextSize=theme.TextSize.Small; searchBox.TextColor3=theme.Colors.TextPrimary; searchBox.PlaceholderText="Search"; searchBox.ClearTextOnFocus=false; searchBox.TextXAlignment=Enum.TextXAlignment.Left; searchBox.ZIndex=5; searchBox.Parent=searchWrap
	local function makeWindowBtn(symbol,xOffset,hoverColor) local b=Primitives.createFrame({Size=UDim2.fromOffset(28,28),Position=UDim2.new(1,xOffset,0.5,0),AnchorPoint=Vector2.new(1,0.5),Color=theme.Colors.SurfaceHigh,Transparency=1,Corner=theme.Radius.Small,Parent=header,ZIndex=4}); Primitives.createText({Text=symbol,Font=theme.FontSemibold,TextSize=13,Color=theme.Colors.TextSecondary,Size=UDim2.fromScale(1,1),AlignX=Enum.TextXAlignment.Center,ZIndex=5,Parent=b}); local hb=Instance.new("TextButton"); hb.Text=""; hb.BackgroundTransparency=1; hb.AutoButtonColor=false; hb.Size=UDim2.fromScale(1,1); hb.ZIndex=6; hb.Parent=b; hb.MouseEnter:Connect(function() tween(theme,b,theme.Animation.Fast,{BackgroundTransparency=theme.Transparency.SurfaceHigh,BackgroundColor3=hoverColor or theme.Colors.SurfaceHigh}) end); hb.MouseLeave:Connect(function() tween(theme,b,theme.Animation.Fast,{BackgroundTransparency=1}) end); return hb end
	local closeBtn=makeWindowBtn("×",-theme.Spacing.L,theme.Colors.Error); local minimizeBtn=makeWindowBtn("—",-theme.Spacing.L-34)
	local body=Primitives.createFrame({Name="Body",Size=UDim2.new(1,0,1,-headerHeight),Position=UDim2.fromOffset(0,headerHeight),Transparency=1,Parent=main,ZIndex=2})
	local sidebar=Primitives.createFrame({Name="Sidebar",Size=UDim2.new(0,sidebarWidth,1,0),Color=theme.Colors.SurfaceLow,Transparency=theme.Transparency.SurfaceLow,Parent=body,ZIndex=3})
	local navHolder=Primitives.createFrame({Name="Nav",Size=UDim2.new(1,0,1,opts.ShowProfile==false and 0 or -58),Transparency=1,Parent=sidebar,ZIndex=3}); local navLayout=Instance.new("UIListLayout"); navLayout.Padding=UDim.new(0,6); navLayout.HorizontalAlignment=Enum.HorizontalAlignment.Center; navLayout.SortOrder=Enum.SortOrder.LayoutOrder; navLayout.Parent=navHolder; local navPad=Instance.new("UIPadding"); navPad.PaddingTop=UDim.new(0,10); navPad.Parent=navHolder
	if opts.ShowProfile~=false then local profile=Primitives.createFrame({Name="Profile",Size=UDim2.new(1,0,0,52),Position=UDim2.new(0,0,1,-52),Transparency=1,Parent=sidebar,ZIndex=4}); local avatar=Instance.new("ImageLabel"); avatar.BackgroundTransparency=1; avatar.Size=UDim2.fromOffset(30,30); avatar.Position=UDim2.fromScale(0.5,0.5); avatar.AnchorPoint=Vector2.new(0.5,0.5); avatar.ZIndex=5; avatar.Parent=profile; local ac=Instance.new("UICorner"); ac.CornerRadius=UDim.new(1,0); ac.Parent=avatar; task.spawn(function() local ok,img=pcall(Players.GetUserThumbnailAsync,Players,LocalPlayer.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size100x100); if ok and avatar.Parent then avatar.Image=img end end) end
	local contentArea=Primitives.createFrame({Name="Content",Size=UDim2.new(1,-sidebarWidth,1,0),Position=UDim2.fromOffset(sidebarWidth,0),Transparency=1,Parent=body,Clip=true,ZIndex=2}); local contentPad=Instance.new("UIPadding"); contentPad.PaddingTop=UDim.new(0,theme.Spacing.L); contentPad.PaddingBottom=UDim.new(0,theme.Spacing.L); contentPad.PaddingLeft=UDim.new(0,theme.Spacing.L); contentPad.PaddingRight=UDim.new(0,theme.Spacing.L); contentPad.Parent=contentArea
	local notifications=NotificationManager.new(theme,screenGui,sounds)
	local tabs={}; local activeTab; local searchEntries={}; local searchPopupClose
	local function registerSearch(label,instance,tab) if type(label)~="string" or label=="" then return end; table.insert(searchEntries,{key=string.lower(label),label=label,instance=instance,tab=tab}) end
	local windowObj={Flags=flags}
	local function activateTab(tabObj,fromSearch)
		if activeTab==tabObj then return end
		if activeTab then activeTab._scroller.Visible=false; if activeTab._icon then tween(theme,activeTab._icon,theme.Animation.Fast,{ImageColor3=theme.Colors.TextSecondary}) end; activeTab._navBtn.BackgroundTransparency=1 end
		activeTab=tabObj; tabObj._scroller.Visible=true; if tabObj._icon then tween(theme,tabObj._icon,theme.Animation.Fast,{ImageColor3=theme.Colors.Accent}) end; tween(theme,tabObj._navBtn,theme.Animation.Fast,{BackgroundTransparency=0.82}); if not fromSearch then sounds:Play("Click") end
	end
	function windowObj:AddTab(tabOpts)
		tabOpts=tabOpts or {}; local index=#tabs+1; local navBtn=Primitives.createFrame({Name="TabButton",Size=UDim2.fromOffset(sidebarWidth-16,sidebarWidth-16),Color=theme.Colors.Accent,Transparency=1,Corner=theme.Radius.Medium,Parent=navHolder,LayoutOrder=index,ZIndex=4}); local iconId=tabOpts.Icon and (IconHelper.isValid(tabOpts.Icon) and tabOpts.Icon or theme.Icons[tabOpts.Icon]) or nil; local icon=Primitives.createIcon({Id=iconId,Color=theme.Colors.TextSecondary,Size=UDim2.fromOffset(20,20),Position=UDim2.fromScale(0.5,0.5),AnchorPoint=Vector2.new(0.5,0.5),ZIndex=5,Parent=navBtn}); local hb=Instance.new("TextButton"); hb.Text=""; hb.BackgroundTransparency=1; hb.AutoButtonColor=false; hb.Size=UDim2.fromScale(1,1); hb.Selectable=true; hb.ZIndex=6; hb.Parent=navBtn
		local scroller=Instance.new("ScrollingFrame"); scroller.Name="Scroller_"..(tabOpts.Title or tostring(index)); scroller.Size=UDim2.fromScale(1,1); scroller.BackgroundTransparency=1; scroller.BorderSizePixel=0; scroller.ScrollBarThickness=2; scroller.ScrollBarImageColor3=theme.Colors.TextTertiary; scroller.CanvasSize=UDim2.new(); scroller.AutomaticCanvasSize=Enum.AutomaticSize.Y; scroller.Visible=false; scroller.Parent=contentArea
		local page=Primitives.createFrame({Name="Page",Size=UDim2.new(1,0,0,0),Transparency=1,Parent=scroller}); page.AutomaticSize=Enum.AutomaticSize.Y; Primitives.createLayout(page,{Gap=theme.Spacing.M})
		local tabObj=setmetatable({_ctx={theme=theme,sounds=sounds,flags=flags,screenGui=screenGui,parent=page,registerSearch=registerSearch},_page=page,_scroller=scroller,_navBtn=navBtn,_navHitbox=hb,_icon=icon},TabMT); tabObj._ctx.tab=tabObj; tabs[index]=tabObj
		registerSearch(tabOpts.Title or ("Tab "..index),navBtn,tabObj); hb.MouseButton1Click:Connect(function() activateTab(tabObj,false) end); if tabOpts.Title then local tip; hb.MouseEnter:Connect(function() if not tip then tip=Primitives.createText({Text=tabOpts.Title,Font=theme.FontSemibold,TextSize=theme.TextSize.Small,Color=theme.Colors.TextPrimary,Size=UDim2.fromOffset(120,28),Position=UDim2.fromOffset(navBtn.AbsolutePosition.X + navBtn.AbsoluteSize.X + 8, navBtn.AbsolutePosition.Y + 6),Parent=screenGui,ZIndex=700}); tip.BackgroundTransparency=0.15; tip.BackgroundColor3=theme.Colors.SurfaceRaised; local cc=Instance.new("UICorner"); cc.CornerRadius=theme.Radius.Small; cc.Parent=tip end end); hb.MouseLeave:Connect(function() if tip then tip:Destroy(); tip=nil end end) end
		if index==1 then task.defer(function() activateTab(tabObj,true) end) end; return tabObj
	end
	function windowObj:Search(query) local q=string.lower(tostring(query or "")); local results={}; if q=="" then return results end; for _,e in ipairs(searchEntries) do if string.find(e.key,q,1,true) then table.insert(results,e) end end; return results end
	local function closeSearch() if searchPopupClose then searchPopupClose(); searchPopupClose=nil end end
	local function renderSearch()
		closeSearch(); local q=searchBox.Text; if q=="" then return end; local results=windowObj:Search(q); local rows=math.clamp(#results,1,6); local popup,close=Primitives.createPopup(theme,screenGui,searchWrap,Vector2.new(searchWrap.AbsoluteSize.X,rows*30+8),function(frame)
			local layout=Instance.new("UIListLayout"); layout.Padding=UDim.new(0,2); layout.SortOrder=Enum.SortOrder.LayoutOrder; layout.Parent=frame; local pad=Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,4); pad.PaddingLeft=UDim.new(0,4); pad.PaddingRight=UDim.new(0,4); pad.Parent=frame
			if #results==0 then Primitives.createText({Text="No results",Font=theme.Font,TextSize=theme.TextSize.Small,Color=theme.Colors.TextTertiary,Size=UDim2.new(1,0,0,28),Parent=frame,ZIndex=503}) else for _,entry in ipairs(results) do local b=Instance.new("TextButton"); b.Text=entry.label; b.Font=theme.Font; b.TextSize=theme.TextSize.Small; b.TextColor3=theme.Colors.TextPrimary; b.TextXAlignment=Enum.TextXAlignment.Left; b.BackgroundColor3=theme.Colors.SurfaceHigh; b.BackgroundTransparency=1; b.BorderSizePixel=0; b.AutoButtonColor=false; b.Size=UDim2.new(1,0,0,28); b.ZIndex=503; b.Parent=frame; local pp=Instance.new("UIPadding"); pp.PaddingLeft=UDim.new(0,9); pp.Parent=b; b.MouseButton1Click:Connect(function() activateTab(entry.tab,true); closeSearch(); searchBox.Text=""; if entry.instance and entry.instance.Parent and entry.tab and entry.tab._scroller then entry.tab._scroller.CanvasPosition=Vector2.new(0,math.max(0,entry.instance.AbsolutePosition.Y-entry.tab._scroller.AbsolutePosition.Y-20)) end end) end end
		end); searchPopupClose=close
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(renderSearch)
	local dragging=false; local dragStart; local startAbs
	header.InputBegan:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=true; dragStart=input.Position; startAbs=shadowHost.AbsolutePosition; shadowHost.AnchorPoint=Vector2.new(0,0); shadowHost.Position=UDim2.fromOffset(startAbs.X,startAbs.Y) end end)
	local function clampWindow() local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720); local size=shadowHost.AbsoluteSize; local pos=shadowHost.AbsolutePosition; shadowHost.Position=UDim2.fromOffset(math.clamp(pos.X,8,math.max(8,viewport.X-size.X-8)),math.clamp(pos.Y,8,math.max(8,viewport.Y-size.Y-8))) end
	table.insert(connections,UserInputService.InputChanged:Connect(function(input) if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input.UserInputType==Enum.UserInputType.Touch) then local d=input.Position-dragStart; shadowHost.Position=UDim2.fromOffset(startAbs.X+d.X,startAbs.Y+d.Y); clampWindow() end end)); table.insert(connections,UserInputService.InputEnded:Connect(function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=false end end))
	local function applyResponsive()
		local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720); local margin=UserInputService.TouchEnabled and 12 or 24; local w=math.min(baseSize.X,viewport.X-margin*2); local h=math.min(baseSize.Y,viewport.Y-margin*2); shadowHost.Size=UDim2.fromOffset(math.max(280,w),math.max(280,h)); local compact=w<680; searchWrap.Size=UDim2.fromOffset(compact and 160 or 220,30); titleLabel.Visible=not compact; if compact then searchWrap.Position=UDim2.new(0,theme.Spacing.L,0.5,0); searchWrap.AnchorPoint=Vector2.new(0,0.5) else searchWrap.Position=UDim2.new(0.5,0,0.5,0); searchWrap.AnchorPoint=Vector2.new(0.5,0.5) end; if shadowHost.AnchorPoint==Vector2.new(0.5,0.5) then shadowHost.Position=UDim2.fromScale(0.5,0.5) else clampWindow() end
	end
	applyResponsive(); if workspace.CurrentCamera then table.insert(connections,workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(applyResponsive)) end
	local minimized=false; minimizeBtn.MouseButton1Click:Connect(function() minimized=not minimized; if minimized then body.Visible=false; tween(theme,shadowHost,theme.Animation.Base,{Size=UDim2.fromOffset(shadowHost.AbsoluteSize.X,headerHeight)}) else applyResponsive(); task.delay(scaledDuration(theme,theme.Animation.Base),function() if body.Parent then body.Visible=true end end) end end)
	function windowObj:SetTheme(newOverrides)
		local oldColors = deepCopy(theme.Colors)
		for k, v in pairs(newOverrides or {}) do
			if type(v) == "table" and type(theme[k]) == "table" then
				for kk, vv in pairs(v) do theme[k][kk] = vv end
			else
				theme[k] = v
			end
		end
		-- Refresh existing objects whose colors still match a theme token. Custom
		-- per-component colors are left untouched.
		for _, obj in ipairs(screenGui:GetDescendants()) do
			if obj:IsA("GuiObject") then
				for key, oldColor in pairs(oldColors) do
					local newColor = theme.Colors[key]
					if newColor then
						if obj.BackgroundColor3 == oldColor then obj.BackgroundColor3 = newColor end
						if (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) and obj.TextColor3 == oldColor then obj.TextColor3 = newColor end
						if (obj:IsA("ImageLabel") or obj:IsA("ImageButton")) and obj.ImageColor3 == oldColor then obj.ImageColor3 = newColor end
					end
				end
			end
		end
		return true
	end
	function windowObj:Notify(o) notifications:Notify(o) end
	function windowObj:Toggle()
		screenGui.Enabled = not screenGui.Enabled
		if blur then
			if screenGui.Enabled then blur.Enabled = true; tween(theme, blur, theme.Animation.Fast, {Size = opts.BlurSize or theme.BlurSize or 12})
			else tween(theme, blur, theme.Animation.Fast, {Size = 0}).Completed:Connect(function() if blur then blur.Enabled = false end end) end
		end
		if screenGui.Enabled then sounds:Play("Open") else sounds:Play("Close") end
	end
	function windowObj:AttachTooltip(target, text)
		if not target or not target:IsA("GuiObject") or not text or text == "" then return nil end
		local tooltip
		local token = 0
		local function hide() token += 1; if tooltip then tooltip:Destroy(); tooltip = nil end end
		target.MouseEnter:Connect(function()
			token += 1; local mine = token
			task.delay(0.28, function()
				if mine ~= token or not target.Parent or tooltip then return end
				tooltip = Instance.new("CanvasGroup"); tooltip.BackgroundColor3 = theme.Colors.SurfaceRaised; tooltip.BackgroundTransparency = theme.Transparency.SurfaceRaised; tooltip.BorderSizePixel = 0; tooltip.AutomaticSize = Enum.AutomaticSize.XY; tooltip.GroupTransparency = 1; tooltip.ZIndex = 760; tooltip.Parent = screenGui
				local cc = Instance.new("UICorner"); cc.CornerRadius = theme.Radius.Small; cc.Parent = tooltip
				local pp = Instance.new("UIPadding"); pp.PaddingLeft = UDim.new(0,9); pp.PaddingRight = UDim.new(0,9); pp.PaddingTop = UDim.new(0,6); pp.PaddingBottom = UDim.new(0,6); pp.Parent = tooltip
				local lbl = Primitives.createText({Text=tostring(text),Font=theme.Font,TextSize=theme.TextSize.Small,Color=theme.Colors.TextSecondary,Size=UDim2.fromOffset(220,0),AutoSize=Enum.AutomaticSize.Y,Wrap=true,Parent=tooltip,ZIndex=761})
				local mouse = UserInputService:GetMouseLocation(); local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720); task.defer(function() if not tooltip then return end; local sz=tooltip.AbsoluteSize; tooltip.Position=UDim2.fromOffset(math.clamp(mouse.X+12,8,math.max(8,viewport.X-sz.X-8)),math.clamp(mouse.Y+12,8,math.max(8,viewport.Y-sz.Y-8))); tween(theme,tooltip,theme.Animation.Fast,{GroupTransparency=0}) end)
			end)
		end)
		target.MouseLeave:Connect(hide)
		return {Destroy=hide}
	end
	function windowObj:ShowContextMenu(anchor, items)
		if not anchor or not anchor:IsA("GuiObject") then return nil end
		items = items or {}
		local popup, close = Primitives.createPopup(theme, screenGui, anchor, Vector2.new(190, math.max(36, #items * 30 + 8)), function(frame)
			local layout = Instance.new("UIListLayout"); layout.Padding = UDim.new(0,2); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = frame
			local pad = Instance.new("UIPadding"); pad.PaddingTop=UDim.new(0,4); pad.PaddingBottom=UDim.new(0,4); pad.PaddingLeft=UDim.new(0,4); pad.PaddingRight=UDim.new(0,4); pad.Parent=frame
			for _, item in ipairs(items) do
				local b = Instance.new("TextButton"); b.Text = tostring(item.Title or item.Text or "Action"); b.Font = theme.Font; b.TextSize = theme.TextSize.Small; b.TextColor3 = item.Danger and theme.Colors.Error or theme.Colors.TextPrimary; b.TextXAlignment=Enum.TextXAlignment.Left; b.BackgroundColor3=theme.Colors.SurfaceHigh; b.BackgroundTransparency=1; b.BorderSizePixel=0; b.AutoButtonColor=false; b.Size=UDim2.new(1,0,0,28); b.ZIndex=503; b.Parent=frame
				local pad2=Instance.new("UIPadding"); pad2.PaddingLeft=UDim.new(0,9); pad2.Parent=b
				b.MouseButton1Click:Connect(function() close(); if item.Callback then item.Callback() end end)
			end
		end)
		return {Close=close,Frame=popup}
	end
	function windowObj:ShowModal(modalOpts)
		modalOpts=modalOpts or {}; local dim=Instance.new("TextButton"); dim.Text=""; dim.AutoButtonColor=false; dim.BackgroundColor3=Color3.new(0,0,0); dim.BackgroundTransparency=0.45; dim.Size=UDim2.fromScale(1,1); dim.ZIndex=800; dim.Parent=screenGui; local host=Instance.new("CanvasGroup"); host.BackgroundTransparency=1; host.Size=UDim2.fromOffset(math.min(420,shadowHost.AbsoluteSize.X-40),modalOpts.Height or 180); host.Position=UDim2.fromScale(0.5,0.5); host.AnchorPoint=Vector2.new(0.5,0.5); host.ZIndex=810; host.GroupTransparency=1; host.Parent=screenGui; Primitives.createShadow({Parent=host,Spread=34,Transparency=0.58,ZIndex=809}); local panel=Primitives.createGlassSurface(theme,{Size=UDim2.fromScale(1,1),Color=theme.Colors.SurfaceRaised,Transparency=theme.Transparency.SurfaceRaised,Corner=theme.Radius.Large,Parent=host,ZIndex=811}); local p=Instance.new("UIPadding"); p.PaddingTop=UDim.new(0,16); p.PaddingBottom=UDim.new(0,16); p.PaddingLeft=UDim.new(0,16); p.PaddingRight=UDim.new(0,16); p.Parent=panel; local lay=Instance.new("UIListLayout"); lay.Padding=UDim.new(0,8); lay.Parent=panel; Primitives.createText({Text=modalOpts.Title or "Dialog",Font=theme.FontBold,TextSize=theme.TextSize.Title,Color=theme.Colors.TextPrimary,Size=UDim2.new(1,0,0,22),Parent=panel,ZIndex=812}); if modalOpts.Message then Primitives.createText({Text=modalOpts.Message,Font=theme.Font,TextSize=theme.TextSize.Small,Color=theme.Colors.TextSecondary,Size=UDim2.new(1,0,0,0),AutoSize=Enum.AutomaticSize.Y,Wrap=true,Parent=panel,ZIndex=812}) end; local close=function() local t=tween(theme,host,theme.Animation.Fast,{GroupTransparency=1}); t.Completed:Connect(function() if dim.Parent then dim:Destroy() end; if host.Parent then host:Destroy() end end) end; dim.MouseButton1Click:Connect(close); tween(theme,host,theme.Animation.Base,{GroupTransparency=0}); return {Close=close,Frame=panel}
	end
	function windowObj:Destroy()
		if destroyed then return end; destroyed=true; closeSearch(); for _,c in ipairs(connections) do pcall(function() c:Disconnect() end) end; if blur then tween(theme,blur,theme.Animation.Fast,{Size=0}).Completed:Connect(function() if blur.Parent then blur:Destroy() end end) end; sounds:Play("Close"); local t=tween(theme,main,theme.Animation.Base,{BackgroundTransparency=1}); t.Completed:Connect(function() sounds:Destroy(); if screenGui.Parent then screenGui:Destroy() end end)
	end
	closeBtn.MouseButton1Click:Connect(function() windowObj:Destroy() end)
	local toggleKey=opts.ToggleKey or Enum.KeyCode.RightControl; local searchKey=opts.SearchKey or Enum.KeyCode.K
	table.insert(connections,UserInputService.InputBegan:Connect(function(input,gp) if gp then return end; if input.KeyCode==toggleKey then windowObj:Toggle() elseif input.KeyCode==searchKey and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then screenGui.Enabled=true; searchBox:CaptureFocus() end end))
	main.Size=UDim2.fromScale(0.97,0.97); main.Position=UDim2.fromScale(0.015,0.015); tween(theme,main,theme.Animation.Window,{Size=UDim2.fromScale(1,1),Position=UDim2.fromScale(0,0),BackgroundTransparency=theme.Transparency.Base},Enum.EasingStyle.Quart); sounds:Play("Open")
	return setmetatable(windowObj,{__index=windowObj})
end

--============================================================
-- STATIC HELPERS
--============================================================
function Lunkara.RegisterTheme(name, themeTable)
	ThemePresets[name] = themeTable
end

function Lunkara.GetDefaultTheme()
	return deepCopy(DefaultTheme)
end

return Lunkara

--[[
	UISTROKE POLICY:
	This library uses zero UIStroke instances. Depth and separation are produced
	entirely through layered Frame transparency (Surface -> SurfaceHigh ->
	SurfaceRaised), a top "Sheen" band with a UIGradient transparency ramp, and
	ImageLabel-based soft shadows. No component in this file requires a stroke.
]]
