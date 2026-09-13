--[[
	LunkaraUI
	A single-file, production-grade Roblox UI library.

	Visual identity: premium liquid-glass utility menu. Depth comes from layered
	translucent surfaces, soft shadows and restrained edge highlighting — never
	from UIStroke borders. See README block at bottom of file for the one place
	UIStroke is used and why.

	Author: written from scratch for the Lunkara project.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--============================================================
-- ASSET IDS (placeholders — replace with your real IDs)
--============================================================
-- Icons must be white PNGs so ImageColor3 recoloring works cleanly.
local DEFAULT_ICONS = {
	Home = "rbxassetid://0",
	Components = "rbxassetid://0",
	Palette = "rbxassetid://0",
	Settings = "rbxassetid://0",
	Search = "rbxassetid://0",
}

-- Blank/zero IDs are treated as "not provided" and safely skipped everywhere.
local DEFAULT_SOUNDS = {
	Hover = "rbxassetid://0",
	Click = "rbxassetid://0",
	Toggle = "rbxassetid://0",
	Open = "rbxassetid://0",
	Close = "rbxassetid://0",
	Notification = "rbxassetid://0",
}

--============================================================
-- ROOT GUI
--============================================================
local function getGuiParent()
	local ok, result = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and result then
		local success = pcall(function()
			return result:IsA("CoreGui")
		end)
		if success then
			return result
		end
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

--============================================================
-- THEME
--============================================================
local Lunkara = {}
Lunkara.__index = Lunkara

Lunkara.Version = "1.0.0"

local ACCENT = Color3.fromRGB(196, 154, 92) -- warm brushed-bronze accent, restrained use only

-- rebuilds a component ctx table pointed at a new parent container (ctx holds
-- live instance references, not plain data, so a deepCopy would be wrong here)
local function ctxWithParent(ctx, newParent)
	return {
		theme = ctx.theme,
		sounds = ctx.sounds,
		flags = ctx.flags,
		screenGui = ctx.screenGui,
		parent = newParent,
	}
end

local function deepCopy(t)
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

local DefaultTheme = {
	Name = "Liquid",

	Font = Enum.Font.Gotham,
	FontSemibold = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,

	TextSize = {
		Title = 16,
		Body = 14,
		Small = 12,
		Micro = 11,
	},

	Colors = {
		Accent = ACCENT,
		AccentMuted = Color3.fromRGB(120, 100, 78),

		-- base glass surfaces (bottom -> top layering)
		Base = Color3.fromRGB(14, 14, 16),
		SurfaceLow = Color3.fromRGB(22, 22, 25),
		Surface = Color3.fromRGB(28, 28, 32),
		SurfaceHigh = Color3.fromRGB(36, 36, 41),
		SurfaceRaised = Color3.fromRGB(44, 44, 50),

		Sheen = Color3.fromRGB(255, 255, 255),

		TextPrimary = Color3.fromRGB(238, 238, 240),
		TextSecondary = Color3.fromRGB(168, 168, 174),
		TextTertiary = Color3.fromRGB(118, 118, 124),
		TextOnAccent = Color3.fromRGB(20, 16, 10),

		Success = Color3.fromRGB(120, 190, 140),
		Warning = Color3.fromRGB(210, 170, 100),
		Error = Color3.fromRGB(210, 110, 105),
		Info = Color3.fromRGB(130, 165, 205),

		Divider = Color3.fromRGB(255, 255, 255), -- used only at very low transparency
	},

	Transparency = {
		Base = 0.06,
		SurfaceLow = 0.10,
		Surface = 0.16,
		SurfaceHigh = 0.22,
		SurfaceRaised = 0.30,
		Sheen = 0.94,
		Divider = 0.94,
		ShadowMin = 0.55,
		ShadowMax = 0.92,
	},

	Radius = {
		Window = UDim.new(0, 14),
		Large = UDim.new(0, 12),
		Medium = UDim.new(0, 9),
		Small = UDim.new(0, 6),
		Pill = UDim.new(1, 0),
	},

	Spacing = {
		XS = 4,
		S = 8,
		M = 12,
		L = 16,
		XL = 24,
	},

	Animation = {
		Fast = 0.12,
		Base = 0.18,
		Slow = 0.28,
		Window = 0.34,
		EasingStyle = Enum.EasingStyle.Quint,
		EasingStyleSoft = Enum.EasingStyle.Quart,
		EasingDirection = Enum.EasingDirection.Out,
	},

	Icons = deepCopy(DEFAULT_ICONS),
	Sounds = deepCopy(DEFAULT_SOUNDS),

	SoundEnabled = true,
	AnimationSpeedScale = 1,

	WindowSize = Vector2.new(720, 480),
	WindowMinSize = Vector2.new(560, 380),
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
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local id = #self._handlers + 1
	self._handlers[id] = fn
	local conn = { Connected = true }
	function conn:Disconnect()
		if self.Connected then
			self.Connected = false
			self._id = nil
		end
	end
	conn._id = id
	conn._handlers = self._handlers
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
	return type(id) == "string" and id ~= "" and id ~= "rbxassetid://0"
end

function SoundHelper:Play(key)
	if not self.Theme.SoundEnabled then return end
	local id = self.Theme.Sounds and self.Theme.Sounds[key]
	if not self:_isValidId(id) then return end

	local ok = pcall(function()
		local snd = self._cache[id]
		if not snd then
			snd = Instance.new("Sound")
			snd.SoundId = id
			snd.Volume = 0.5
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
	return type(id) == "string" and id ~= "" and id ~= "rbxassetid://0"
end

function IconHelper.apply(imageLabel, id, color)
	if IconHelper.isValid(id) then
		imageLabel.Image = id
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
	shadow.Image = "rbxassetid://5028857472" -- widely-used soft shadow, 9-sliced
	shadow.ImageColor3 = Color3.new(0, 0, 0)
	shadow.ImageTransparency = props.Transparency or 0.65
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(24, 24, 276, 276)
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

	local function applyHover(hovering)
		if state.disabled then return end
		state.hovering = hovering
		if hovering and opts.onHover then
			opts.onHover(true)
			if opts.playSound ~= false then
				sounds:Play("Hover")
			end
		elseif not hovering and opts.onHover then
			opts.onHover(false)
		end
	end

	target.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			applyHover(true)
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if state.disabled then return end
			state.pressed = true
			if opts.onPress then opts.onPress(true) end
		end
	end)

	target.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			applyHover(false)
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if state.pressed and opts.onActivate and not state.disabled then
				if opts.playSound ~= false then
					sounds:Play("Click")
				end
				opts.onActivate()
			end
			state.pressed = false
			if opts.onPress then opts.onPress(false) end
		end
	end)

	function state.setDisabled(v)
		state.disabled = v
	end

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
	local popup = Primitives.createGlassSurface(theme, {
		Name = "Popup",
		Size = UDim2.fromOffset(desiredSize.X, desiredSize.Y),
		Color = theme.Colors.SurfaceRaised,
		Transparency = theme.Transparency.SurfaceRaised,
		Corner = theme.Radius.Medium,
		ZIndex = 500,
		Parent = screenGui,
	})
	Primitives.createShadow({ Parent = popup, ZIndex = 499, Transparency = 0.55 })

	local function reposition()
		local absPos = sourceFrame.AbsolutePosition
		local absSize = sourceFrame.AbsoluteSize
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)

		local x = absPos.X
		local y = absPos.Y + absSize.Y + 6

		local w = popup.AbsoluteSize.X
		local h = popup.AbsoluteSize.Y

		if y + h > viewport.Y - 8 then
			-- not enough room below -> open above the source
			y = absPos.Y - h - 6
		end
		if y < 8 then
			y = 8
		end

		if x + w > viewport.X - 8 then
			x = viewport.X - w - 8
		end
		if x < 8 then
			x = 8
		end

		popup.Position = UDim2.fromOffset(x, y)
	end

	popup.Position = UDim2.fromOffset(sourceFrame.AbsolutePosition.X, sourceFrame.AbsolutePosition.Y + sourceFrame.AbsoluteSize.Y + 6)
	task.defer(reposition)

	local resizeConn = workspace.CurrentCamera and workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(reposition)

	if contentBuilder then
		contentBuilder(popup)
	end

	popup.BackgroundTransparency = 1
	for _, child in ipairs(popup:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "Sheen" then
			-- children fade in with the popup
		end
	end
	tween(theme, popup, theme.Animation.Fast, { BackgroundTransparency = theme.Transparency.SurfaceRaised })

	local function close()
		if resizeConn then resizeConn:Disconnect() end
		local t = tween(theme, popup, theme.Animation.Fast, { BackgroundTransparency = 1 })
		t.Completed:Connect(function()
			popup:Destroy()
		end)
	end

	return popup, close, reposition
end

--============================================================
-- FLAGS / CONFIG SYSTEM
--============================================================
local FlagsAPI = {}
FlagsAPI.__index = FlagsAPI

function FlagsAPI.new()
	return setmetatable({
		_flags = {},
		_callbacks = {},
	}, FlagsAPI)
end

function FlagsAPI:Register(flagName, defaultValue, callback)
	if flagName == nil then return end
	if self._flags[flagName] ~= nil then
		warn("[LunkaraUI] Duplicate flag registered: " .. tostring(flagName) .. " (previous value kept)")
	else
		self._flags[flagName] = defaultValue
	end
	if callback then
		self._callbacks[flagName] = self._callbacks[flagName] or {}
		table.insert(self._callbacks[flagName], callback)
	end
end

function FlagsAPI:SetFlag(flagName, value)
	self._flags[flagName] = value
	local cbs = self._callbacks[flagName]
	if cbs then
		for _, cb in ipairs(cbs) do
			task.spawn(cb, value)
		end
	end
end

function FlagsAPI:GetFlag(flagName)
	return self._flags[flagName]
end

function FlagsAPI:GetFlags()
	return deepCopy(self._flags)
end

function FlagsAPI:Export()
	local ok, encoded = pcall(function()
		return HttpService:JSONEncode(self._flags)
	end)
	if ok then return encoded end
	return nil
end

function FlagsAPI:Import(jsonString)
	local ok, decoded = pcall(function()
		return HttpService:JSONDecode(jsonString)
	end)
	if not ok or type(decoded) ~= "table" then
		return false
	end
	for k, v in pairs(decoded) do
		self:SetFlag(k, v)
	end
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
	local colorKey = SEMANTIC_COLOR_KEY[kind] or "Info"
	local accentColor = theme.Colors[colorKey]

	local card = Primitives.createGlassSurface(theme, {
		Name = "Notification",
		Size = UDim2.new(1, 0, 0, 0),
		Color = theme.Colors.SurfaceHigh,
		Transparency = 1,
		Corner = theme.Radius.Medium,
		ZIndex = 901,
		Parent = self.Container,
		SheenHeight = 14,
	})
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = -os.clock() * 1000

	Primitives.createShadow({ Parent = card, ZIndex = 900, Transparency = 0.6 })

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = card

	-- small semantic dot instead of a giant colored strip
	local dot = Primitives.createFrame({
		Name = "Dot",
		Size = UDim2.fromOffset(6, 6),
		Position = UDim2.fromOffset(0, 6),
		Color = accentColor,
		Transparency = 0,
		Corner = UDim.new(1, 0),
		ZIndex = 902,
		Parent = card,
	})

	local title = Primitives.createText({
		Name = "Title",
		Text = opts.Title or "Notification",
		Font = theme.FontSemibold,
		TextSize = theme.TextSize.Body,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(1, -18, 0, 0),
		Position = UDim2.fromOffset(18, 0),
		AutoSize = Enum.AutomaticSize.Y,
		Wrap = true,
		ZIndex = 902,
		Parent = card,
	})

	if opts.Message then
		local msg = Primitives.createText({
			Name = "Message",
			Text = opts.Message,
			Font = theme.Font,
			TextSize = theme.TextSize.Small,
			Color = theme.Colors.TextSecondary,
			Size = UDim2.new(1, -18, 0, 0),
			Position = UDim2.new(0, 18, 0, 20),
			AutoSize = Enum.AutomaticSize.Y,
			Wrap = true,
			ZIndex = 902,
			Parent = card,
		})
	end

	self.Sounds:Play("Notification")

	tween(theme, card, theme.Animation.Base, { BackgroundTransparency = theme.Transparency.SurfaceHigh })

	local duration = opts.Duration or 4
	task.delay(duration, function()
		if not card.Parent then return end
		local t = tween(theme, card, theme.Animation.Base, { BackgroundTransparency = 1 })
		t.Completed:Connect(function()
			if card.Parent then card:Destroy() end
		end)
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
	local theme, sounds = ctx.theme, ctx.sounds
	local min = opts.Min or 0
	local max = opts.Max or 100
	local increment = opts.Increment or 1
	local value = math.clamp(opts.Default or min, min, max)
	local flag = opts.Flag

	local row = Primitives.createFrame({ Name = "Row", Size = UDim2.new(1, 0, 0, 40), Transparency = 1, Parent = ctx.parent })

	local label = Primitives.createText({
		Text = opts.Title or "",
		Font = theme.Font,
		TextSize = theme.TextSize.Body,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(0.7, 0, 0, 16),
		Parent = row,
	})

	local valueLabel = Primitives.createText({
		Text = tostring(value),
		Font = theme.FontSemibold,
		TextSize = theme.TextSize.Small,
		Color = theme.Colors.TextSecondary,
		Size = UDim2.new(0.3, 0, 0, 16),
		Position = UDim2.new(0.7, 0, 0, 0),
		AlignX = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local track = Primitives.createFrame({
		Name = "Track",
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 0, 26),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Pill,
		Parent = row,
	})

	local fill = Primitives.createFrame({
		Name = "Fill",
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
		Color = theme.Colors.Accent,
		Transparency = 0,
		Corner = theme.Radius.Pill,
		Parent = track,
	})

	local handle = Primitives.createFrame({
		Name = "Handle",
		Size = UDim2.fromOffset(11, 11),
		Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Colors.TextPrimary,
		Transparency = 0,
		Corner = UDim.new(1, 0),
		Parent = track,
	})

	local dragging = false

	local function setFromAlpha(alpha, fireCallback)
		alpha = math.clamp(alpha, 0, 1)
		local raw = min + (max - min) * alpha
		local stepped = math.floor((raw / increment) + 0.5) * increment
		stepped = math.clamp(stepped, min, max)
		value = stepped
		local a = (value - min) / (max - min)
		fill.Size = UDim2.new(a, 0, 1, 0)
		handle.Position = UDim2.new(a, 0, 0.5, 0)
		valueLabel.Text = tostring(value)
		if flag then ctx.flags:SetFlag(flag, value) end
		if fireCallback ~= false and opts.Callback then opts.Callback(value) end
	end

	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.new(1, 0, 1, 16)
	hitbox.Position = UDim2.new(0, 0, 0, -8)
	hitbox.Parent = track

	local function beginDrag(input)
		dragging = true
		local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
		setFromAlpha(alpha)
	end

	hitbox.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local alpha = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			setFromAlpha(alpha)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local function setValue(v, fireCallback)
		local a = (math.clamp(v, min, max) - min) / (max - min)
		setFromAlpha(a, fireCallback)
	end

	if flag then
		ctx.flags:Register(flag, value, function(v) setValue(v, false) end)
	end

	return { Instance = row, Set = setValue, Get = function() return value end }
end

-- Dropdown (single-select). Searchable + Multi variants build on this.
local function baseDropdown(ctx, opts, isMulti, isSearchable)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local items = opts.Items or {}
	local selected = {}
	if isMulti then
		for _, v in ipairs(opts.Default or {}) do selected[v] = true end
	else
		selected.single = opts.Default
	end
	local flag = opts.Flag

	local row = Primitives.createFrame({ Name = "Row", Size = UDim2.new(1, 0, 0, 36), Transparency = 1, Parent = ctx.parent })

	local label = Primitives.createText({
		Text = opts.Title or "",
		Font = theme.Font,
		TextSize = theme.TextSize.Body,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(0.4, 0, 1, 0),
		Parent = row,
	})

	local control = Primitives.createGlassSurface(theme, {
		Name = "Control",
		Size = UDim2.new(0.58, 0, 0, 28),
		Position = UDim2.new(0.42, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = row,
		SheenHeight = 8,
	})

	local function summaryText()
		if isMulti then
			local names = {}
			for _, item in ipairs(items) do
				if selected[item] then table.insert(names, item) end
			end
			if #names == 0 then return "None selected" end
			return table.concat(names, ", ")
		else
			return selected.single or "Select..."
		end
	end

	local valueText = Primitives.createText({
		Text = summaryText(),
		Font = theme.Font,
		TextSize = theme.TextSize.Small,
		Color = theme.Colors.TextSecondary,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		Truncate = Enum.TextTruncate.AtEnd,
		Parent = control,
	})

	local chevron = Primitives.createText({
		Text = "⌄",
		Font = theme.Font,
		TextSize = 14,
		Color = theme.Colors.TextTertiary,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -20, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		AlignX = Enum.TextXAlignment.Center,
		Parent = control,
	})

	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.Parent = control

	local isOpen = false
	local closePopup = nil
	local searchTerm = ""

	local function commit(fireCallback)
		valueText.Text = summaryText()
		if flag then
			ctx.flags:SetFlag(flag, isMulti and (function()
				local out = {}
				for _, item in ipairs(items) do if selected[item] then table.insert(out, item) end end
				return out
			end)() or selected.single)
		end
		if fireCallback ~= false and opts.Callback then
			if isMulti then
				local out = {}
				for _, item in ipairs(items) do if selected[item] then table.insert(out, item) end end
				opts.Callback(out)
			else
				opts.Callback(selected.single)
			end
		end
	end

	local function openDropdown()
		if isOpen then return end
		isOpen = true
		sounds:Play("Click")
		tween(theme, chevron, theme.Animation.Fast, { Rotation = 180 })

		local filtered = {}
		for _, item in ipairs(items) do
			if searchTerm == "" or string.find(string.lower(item), string.lower(searchTerm), 1, true) then
				table.insert(filtered, item)
			end
		end

		local rowHeight = 26
		local searchHeight = isSearchable and 30 or 0
		local h = math.clamp(#filtered * rowHeight + searchHeight + 8, searchHeight + rowHeight + 8, 220)
		local w = control.AbsoluteSize.X

		local popup, close = Primitives.createPopup(theme, ctx.screenGui, control, Vector2.new(w, h), function(popupFrame)
			local yOffset = 4
			local searchBox
			if isSearchable then
				searchBox = Instance.new("TextBox")
				searchBox.Size = UDim2.new(1, -16, 0, searchHeight - 8)
				searchBox.Position = UDim2.fromOffset(8, 4)
				searchBox.BackgroundTransparency = 1
				searchBox.Text = searchTerm
				searchBox.PlaceholderText = "Search..."
				searchBox.Font = theme.Font
				searchBox.TextSize = theme.TextSize.Small
				searchBox.TextColor3 = theme.Colors.TextPrimary
				searchBox.TextXAlignment = Enum.TextXAlignment.Left
				searchBox.ClearTextOnFocus = false
				searchBox.ZIndex = 502
				searchBox.Parent = popupFrame
				yOffset = searchHeight
			end

			local scroller = Instance.new("ScrollingFrame")
			scroller.Size = UDim2.new(1, 0, 1, -yOffset)
			scroller.Position = UDim2.fromOffset(0, yOffset)
			scroller.BackgroundTransparency = 1
			scroller.BorderSizePixel = 0
			scroller.ScrollBarThickness = 3
			scroller.ScrollBarImageColor3 = theme.Colors.TextTertiary
			scroller.CanvasSize = UDim2.new(0, 0, 0, #filtered * rowHeight)
			scroller.ZIndex = 502
			scroller.Parent = popupFrame

			for i, item in ipairs(filtered) do
				local optRow = Primitives.createFrame({
					Size = UDim2.new(1, 0, 0, rowHeight),
					Position = UDim2.new(0, 0, 0, (i - 1) * rowHeight),
					Transparency = 1,
					ZIndex = 503,
					Parent = scroller,
				})
				local isSelected = isMulti and selected[item] or (selected.single == item)
				local optText = Primitives.createText({
					Text = item,
					Font = isSelected and theme.FontSemibold or theme.Font,
					TextSize = theme.TextSize.Small,
					Color = isSelected and theme.Colors.Accent or theme.Colors.TextPrimary,
					Size = UDim2.new(1, -16, 1, 0),
					Position = UDim2.fromOffset(10, 0),
					ZIndex = 504,
					Parent = optRow,
				})
				local optBtn = Instance.new("TextButton")
				optBtn.Text = ""
				optBtn.BackgroundTransparency = 1
				optBtn.Size = UDim2.fromScale(1, 1)
				optBtn.ZIndex = 505
				optBtn.Parent = optRow

				optBtn.MouseEnter:Connect(function()
					tween(theme, optRow, theme.Animation.Fast, { BackgroundTransparency = 0.85 })
					optRow.BackgroundColor3 = theme.Colors.SurfaceRaised
				end)
				optBtn.MouseLeave:Connect(function()
					tween(theme, optRow, theme.Animation.Fast, { BackgroundTransparency = 1 })
				end)

				optBtn.MouseButton1Click:Connect(function()
					sounds:Play("Toggle")
					if isMulti then
						selected[item] = not selected[item]
						optText.Color = selected[item] and theme.Colors.Accent or theme.Colors.TextPrimary
						optText.Font = selected[item] and theme.FontSemibold or theme.Font
						commit()
					else
						selected.single = item
						commit()
						if close then close() end
						isOpen = false
						tween(theme, chevron, theme.Animation.Fast, { Rotation = 0 })
					end
				end)
			end

			if searchBox then
				searchBox:GetPropertyChangedSignal("Text"):Connect(function()
					searchTerm = searchBox.Text
					-- reopen with filtered results
					if close then close() end
					isOpen = false
					task.defer(openDropdown)
				end)
				task.defer(function() searchBox:CaptureFocus() end)
			end
		end)

		closePopup = function()
			if close then close() end
			isOpen = false
			tween(theme, chevron, theme.Animation.Fast, { Rotation = 0 })
		end
	end

	hitbox.MouseButton1Click:Connect(function()
		if isOpen then
			if closePopup then closePopup() end
		else
			openDropdown()
		end
	end)

	if flag then
		ctx.flags:Register(flag, isMulti and {} or selected.single, function(v)
			if isMulti then
				selected = {}
				for _, item in ipairs(v or {}) do selected[item] = true end
			else
				selected.single = v
			end
			valueText.Text = summaryText()
		end)
	end

	return {
		Instance = row,
		Set = function(v)
			if isMulti then
				selected = {}
				for _, item in ipairs(v or {}) do selected[item] = true end
			else
				selected.single = v
			end
			commit(false)
		end,
		Get = function()
			if isMulti then
				local out = {}
				for _, item in ipairs(items) do if selected[item] then table.insert(out, item) end end
				return out
			end
			return selected.single
		end,
		Refresh = function(newItems)
			items = newItems
		end,
	}
end

function Components.Dropdown(ctx, opts) return baseDropdown(ctx, opts, false, false) end
function Components.SearchableDropdown(ctx, opts) return baseDropdown(ctx, opts, false, true) end
function Components.MultiDropdown(ctx, opts) return baseDropdown(ctx, opts, true, true) end

function Components.Textbox(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local flag = opts.Flag

	local row, label = controlRow(theme, ctx.parent, opts.Title, 32)

	local field = Primitives.createGlassSurface(theme, {
		Name = "Field",
		Size = UDim2.new(0.5, 0, 0, 26),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = row,
		SheenHeight = 6,
	})

	local textbox = Instance.new("TextBox")
	textbox.BackgroundTransparency = 1
	textbox.Size = UDim2.new(1, -16, 1, 0)
	textbox.Position = UDim2.fromOffset(8, 0)
	textbox.Font = theme.Font
	textbox.TextSize = theme.TextSize.Small
	textbox.TextColor3 = theme.Colors.TextPrimary
	textbox.PlaceholderText = opts.Placeholder or ""
	textbox.Text = opts.Default or ""
	textbox.ClearTextOnFocus = false
	textbox.TextXAlignment = Enum.TextXAlignment.Left
	textbox.Parent = field

	textbox.FocusLost:Connect(function(enterPressed)
		if flag then ctx.flags:SetFlag(flag, textbox.Text) end
		if opts.Callback then opts.Callback(textbox.Text, enterPressed) end
	end)

	if flag then
		ctx.flags:Register(flag, textbox.Text, function(v) textbox.Text = v end)
	end

	return { Instance = row, Set = function(v) textbox.Text = v end, Get = function() return textbox.Text end }
end

function Components.MultilineTextbox(ctx, opts)
	opts = opts or {}
	local theme = ctx.theme
	local flag = opts.Flag

	local wrapper = Primitives.createFrame({ Name = "Wrapper", Size = UDim2.new(1, 0, 0, opts.Height or 90), Transparency = 1, Parent = ctx.parent })

	local label = Primitives.createText({
		Text = opts.Title or "",
		Font = theme.Font,
		TextSize = theme.TextSize.Body,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = wrapper,
	})

	local field = Primitives.createGlassSurface(theme, {
		Name = "Field",
		Size = UDim2.new(1, 0, 1, -22),
		Position = UDim2.new(0, 0, 0, 22),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = wrapper,
	})

	local textbox = Instance.new("TextBox")
	textbox.BackgroundTransparency = 1
	textbox.Size = UDim2.new(1, -16, 1, -12)
	textbox.Position = UDim2.fromOffset(8, 6)
	textbox.Font = theme.Font
	textbox.TextSize = theme.TextSize.Small
	textbox.TextColor3 = theme.Colors.TextPrimary
	textbox.TextXAlignment = Enum.TextXAlignment.Left
	textbox.TextYAlignment = Enum.TextYAlignment.Top
	textbox.TextWrapped = true
	textbox.MultiLine = true
	textbox.ClearTextOnFocus = false
	textbox.Text = opts.Default or ""
	textbox.PlaceholderText = opts.Placeholder or ""
	textbox.Parent = field

	textbox.FocusLost:Connect(function()
		if flag then ctx.flags:SetFlag(flag, textbox.Text) end
		if opts.Callback then opts.Callback(textbox.Text) end
	end)

	if flag then ctx.flags:Register(flag, textbox.Text, function(v) textbox.Text = v end) end

	return { Instance = wrapper, Set = function(v) textbox.Text = v end, Get = function() return textbox.Text end }
end

function Components.Keybind(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local flag = opts.Flag
	local current = opts.Default

	local row, label = controlRow(theme, ctx.parent, opts.Title, 32)

	local field = Primitives.createGlassSurface(theme, {
		Name = "Field",
		Size = UDim2.fromOffset(90, 26),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = row,
	})

	local keyText = Primitives.createText({
		Text = current and current.Name or "...",
		Font = theme.FontSemibold,
		TextSize = theme.TextSize.Small,
		Color = theme.Colors.TextSecondary,
		Size = UDim2.fromScale(1, 1),
		AlignX = Enum.TextXAlignment.Center,
		Parent = field,
	})

	local listening = false
	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.Parent = field

	hitbox.MouseButton1Click:Connect(function()
		listening = true
		keyText.Text = "..."
		sounds:Play("Click")
	end)

	UserInputService.InputBegan:Connect(function(input, gp)
		if listening and input.UserInputType == Enum.UserInputType.Keyboard then
			current = input.KeyCode
			keyText.Text = current.Name
			listening = false
			if flag then ctx.flags:SetFlag(flag, current) end
			if opts.Callback then opts.Callback(current) end
		elseif not listening and not gp and current and input.KeyCode == current then
			if opts.OnPress then opts.OnPress() end
		end
	end)

	if flag then ctx.flags:Register(flag, current) end

	return { Instance = row, Get = function() return current end }
end

function Components.ColorPicker(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local flag = opts.Flag
	local color = opts.Default or Color3.fromRGB(255, 255, 255)

	local row, label = controlRow(theme, ctx.parent, opts.Title, 32)

	local swatch = Primitives.createFrame({
		Name = "Swatch",
		Size = UDim2.fromOffset(26, 20),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = color,
		Corner = theme.Radius.Small,
		Parent = row,
	})

	local hitbox = Instance.new("TextButton")
	hitbox.Text = ""
	hitbox.BackgroundTransparency = 1
	hitbox.Size = UDim2.fromScale(1, 1)
	hitbox.Parent = swatch

	local isOpen = false

	local function commit(h, s, v, fireCallback)
		color = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = color
		if flag then ctx.flags:SetFlag(flag, color) end
		if fireCallback ~= false and opts.Callback then opts.Callback(color) end
	end

	hitbox.MouseButton1Click:Connect(function()
		if isOpen then return end
		isOpen = true
		sounds:Play("Click")

		local h0, s0, v0 = Color3.toHSV(color)

		local popup, close = Primitives.createPopup(theme, ctx.screenGui, swatch, Vector2.new(180, 190), function(popupFrame)
			local svBox = Primitives.createFrame({
				Size = UDim2.new(1, -16, 0, 110),
				Position = UDim2.fromOffset(8, 8),
				Color = Color3.fromHSV(h0, 1, 1),
				Corner = theme.Radius.Small,
				Clip = true,
				ZIndex = 502,
				Parent = popupFrame,
			})
			local whiteGrad = Instance.new("UIGradient")
			whiteGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
			whiteGrad.Transparency = NumberSequence.new(0, 1)
			whiteGrad.Parent = svBox
			local blackOverlay = Primitives.createFrame({
				Size = UDim2.fromScale(1, 1),
				Color = Color3.new(0, 0, 0),
				Transparency = 1,
				ZIndex = 503,
				Parent = svBox,
			})
			local blackGrad = Instance.new("UIGradient")
			blackGrad.Rotation = 90
			blackGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0))
			blackGrad.Transparency = NumberSequence.new(1, 0)
			blackGrad.Parent = blackOverlay

			local svCursor = Primitives.createFrame({
				Size = UDim2.fromOffset(8, 8),
				Position = UDim2.new(s0, 0, 1 - v0, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = Color3.new(1, 1, 1),
				Corner = UDim.new(1, 0),
				ZIndex = 505,
				Parent = svBox,
			})

			local hueBar = Primitives.createFrame({
				Size = UDim2.new(1, -16, 0, 14),
				Position = UDim2.fromOffset(8, 124),
				Corner = theme.Radius.Small,
				Clip = true,
				ZIndex = 502,
				Parent = popupFrame,
			})
			local hueGrad = Instance.new("UIGradient")
			local hueKeypoints = {}
			for i = 0, 6 do
				table.insert(hueKeypoints, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)))
			end
			hueGrad.Color = ColorSequence.new(hueKeypoints)
			hueGrad.Parent = hueBar

			local hueCursor = Primitives.createFrame({
				Size = UDim2.fromOffset(4, 18),
				Position = UDim2.new(h0, 0, 0.5, 0),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = Color3.new(1, 1, 1),
				Corner = UDim.new(1, 0),
				ZIndex = 505,
				Parent = hueBar,
			})

			local h, s, v = h0, s0, v0
			local draggingSV, draggingHue = false, false

			local svInput = Instance.new("TextButton")
			svInput.Text = ""
			svInput.BackgroundTransparency = 1
			svInput.Size = UDim2.fromScale(1, 1)
			svInput.ZIndex = 506
			svInput.Parent = svBox

			local hueInput = Instance.new("TextButton")
			hueInput.Text = ""
			hueInput.BackgroundTransparency = 1
			hueInput.Size = UDim2.fromScale(1, 1)
			hueInput.ZIndex = 506
			hueInput.Parent = hueBar

			svInput.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = true
				end
			end)
			hueInput.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingHue = true
				end
			end)
			UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					draggingSV = false
					draggingHue = false
				end
			end)
			UserInputService.InputChanged:Connect(function(input)
				if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
				if draggingSV then
					local rel = Vector2.new(input.Position.X, input.Position.Y) - svBox.AbsolutePosition
					s = math.clamp(rel.X / svBox.AbsoluteSize.X, 0, 1)
					v = 1 - math.clamp(rel.Y / svBox.AbsoluteSize.Y, 0, 1)
					svCursor.Position = UDim2.new(s, 0, 1 - v, 0)
					commit(h, s, v)
				elseif draggingHue then
					local rel = (input.Position.X - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X
					h = math.clamp(rel, 0, 1)
					hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
					svBox.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
					commit(h, s, v)
				end
			end)
		end)

		local outsideConn
		outsideConn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local pos = UserInputService:GetMouseLocation()
				local absPos, absSize = popup.AbsolutePosition, popup.AbsoluteSize
				if pos.X < absPos.X or pos.X > absPos.X + absSize.X or pos.Y < absPos.Y or pos.Y > absPos.Y + absSize.Y then
					if not (pos.X >= swatch.AbsolutePosition.X and pos.X <= swatch.AbsolutePosition.X + swatch.AbsoluteSize.X
						and pos.Y >= swatch.AbsolutePosition.Y and pos.Y <= swatch.AbsolutePosition.Y + swatch.AbsoluteSize.Y) then
						task.defer(function()
							if popup.Parent then close() end
							isOpen = false
							if outsideConn then outsideConn:Disconnect() end
						end)
					end
				end
			end
		end)
	end)

	if flag then ctx.flags:Register(flag, color, function(v) color = v; swatch.BackgroundColor3 = v end) end

	return { Instance = row, Get = function() return color end, Set = function(v) color = v; swatch.BackgroundColor3 = v end }
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
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local min, max, step = opts.Min or 0, opts.Max or 10, opts.Step or 1
	local value = math.clamp(opts.Default or min, min, max)
	local flag = opts.Flag

	local row, label = controlRow(theme, ctx.parent, opts.Title, 30)

	local wrap = Primitives.createFrame({
		Size = UDim2.fromOffset(96, 24),
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Transparency = 1,
		Parent = row,
	})

	local function makeBtn(text, xOffset)
		local b = Primitives.createGlassSurface(theme, {
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.fromOffset(xOffset, 0),
			Color = theme.Colors.SurfaceHigh,
			Transparency = theme.Transparency.SurfaceHigh,
			Corner = theme.Radius.Small,
			Parent = wrap,
			Sheen = false,
		})
		Primitives.createText({ Text = text, Font = theme.FontBold, TextSize = 14, Color = theme.Colors.TextPrimary, Size = UDim2.fromScale(1, 1), AlignX = Enum.TextXAlignment.Center, Parent = b })
		local hb = Instance.new("TextButton")
		hb.Text = ""; hb.BackgroundTransparency = 1; hb.Size = UDim2.fromScale(1, 1); hb.Parent = b
		return hb
	end

	local minusBtn = makeBtn("−", 0)
	local valueLabel = Primitives.createText({
		Text = tostring(value), Font = theme.FontSemibold, TextSize = theme.TextSize.Small,
		Color = theme.Colors.TextPrimary, Size = UDim2.fromOffset(40, 24), Position = UDim2.fromOffset(28, 0),
		AlignX = Enum.TextXAlignment.Center, Parent = wrap,
	})
	local plusBtn = makeBtn("+", 72)

	local function setValue(v, fireCallback)
		value = math.clamp(v, min, max)
		valueLabel.Text = tostring(value)
		if flag then ctx.flags:SetFlag(flag, value) end
		if fireCallback ~= false and opts.Callback then opts.Callback(value) end
	end

	minusBtn.MouseButton1Click:Connect(function() sounds:Play("Click"); setValue(value - step) end)
	plusBtn.MouseButton1Click:Connect(function() sounds:Play("Click"); setValue(value + step) end)

	if flag then ctx.flags:Register(flag, value, function(v) setValue(v, false) end) end

	return { Instance = row, Set = setValue, Get = function() return value end }
end

function Components.SegmentedControl(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local items = opts.Items or {}
	local selectedIndex = 1
	for i, v in ipairs(items) do if v == opts.Default then selectedIndex = i end end
	local flag = opts.Flag

	local wrap = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 28), Transparency = 1, Parent = ctx.parent })
	if opts.Title then
		Primitives.createText({ Text = opts.Title, Font = theme.Font, TextSize = theme.TextSize.Small, Color = theme.Colors.TextSecondary, Size = UDim2.new(1, 0, 0, 16), Parent = wrap })
	end

	local track = Primitives.createGlassSurface(theme, {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, opts.Title and 18 or 0),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Small,
		Parent = wrap,
		Sheen = false,
	})

	local segWidth = 1 / math.max(#items, 1)
	local highlight = Primitives.createFrame({
		Size = UDim2.new(segWidth, -4, 1, -4),
		Position = UDim2.new(segWidth * (selectedIndex - 1), 2, 0, 2),
		Color = theme.Colors.Accent,
		Transparency = 0.05,
		Corner = theme.Radius.Small,
		Parent = track,
	})

	local labels = {}
	for i, item in ipairs(items) do
		local segBtn = Instance.new("TextButton")
		segBtn.Text = ""
		segBtn.BackgroundTransparency = 1
		segBtn.Size = UDim2.new(segWidth, 0, 1, 0)
		segBtn.Position = UDim2.new(segWidth * (i - 1), 0, 0, 0)
		segBtn.ZIndex = 5
		segBtn.Parent = track

		local t = Primitives.createText({
			Text = item, Font = theme.FontSemibold, TextSize = theme.TextSize.Small,
			Color = i == selectedIndex and theme.Colors.TextOnAccent or theme.Colors.TextSecondary,
			Size = UDim2.fromScale(1, 1), AlignX = Enum.TextXAlignment.Center, ZIndex = 6, Parent = segBtn,
		})
		labels[i] = t

		segBtn.MouseButton1Click:Connect(function()
			if i == selectedIndex then return end
			sounds:Play("Toggle")
			selectedIndex = i
			tween(theme, highlight, theme.Animation.Base, { Position = UDim2.new(segWidth * (i - 1), 2, 0, 2) }, theme.Animation.EasingStyleSoft)
			for idx, lbl in ipairs(labels) do
				lbl.Color = idx == i and theme.Colors.TextOnAccent or theme.Colors.TextSecondary
			end
			if flag then ctx.flags:SetFlag(flag, item) end
			if opts.Callback then opts.Callback(item) end
		end)
	end

	if flag then ctx.flags:Register(flag, items[selectedIndex]) end

	return { Instance = wrap, Get = function() return items[selectedIndex] end }
end

function Components.RadioGroup(ctx, opts)
	opts = opts or {}
	local theme, sounds = ctx.theme, ctx.sounds
	local items = opts.Items or {}
	local selected = opts.Default or items[1]
	local flag = opts.Flag

	local wrap = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 0), Transparency = 1, Parent = ctx.parent })
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	Primitives.createLayout(wrap, { Gap = 6 })

	local dots = {}

	local function refresh()
		for item, dot in pairs(dots) do
			local isSel = (item == selected)
			dot.inner.BackgroundTransparency = isSel and 0 or 1
			dot.outer.BackgroundColor3 = isSel and theme.Colors.Accent or theme.Colors.SurfaceHigh
		end
	end

	for _, item in ipairs(items) do
		local optRow = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 22), Transparency = 1, Parent = wrap })
		local outer = Primitives.createFrame({
			Size = UDim2.fromOffset(16, 16),
			Color = theme.Colors.SurfaceHigh,
			Corner = UDim.new(1, 0),
			Parent = optRow,
		})
		local inner = Primitives.createFrame({
			Size = UDim2.fromOffset(8, 8),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Color = theme.Colors.TextOnAccent,
			Transparency = 1,
			Corner = UDim.new(1, 0),
			Parent = outer,
		})
		Primitives.createText({
			Text = item, Font = theme.Font, TextSize = theme.TextSize.Body, Color = theme.Colors.TextPrimary,
			Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(24, 0), Parent = optRow,
		})
		dots[item] = { outer = outer, inner = inner }

		local hb = Instance.new("TextButton")
		hb.Text = ""; hb.BackgroundTransparency = 1; hb.Size = UDim2.fromScale(1, 1); hb.Parent = optRow
		hb.MouseButton1Click:Connect(function()
			sounds:Play("Toggle")
			selected = item
			refresh()
			if flag then ctx.flags:SetFlag(flag, item) end
			if opts.Callback then opts.Callback(item) end
		end)
	end

	refresh()
	if flag then ctx.flags:Register(flag, selected) end

	return { Instance = wrap, Get = function() return selected end }
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
	local comp = Components[kind](ctx, opts)
	table.insert(section._components, comp)
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
		Size = UDim2.new(1, 0, 0, 0),
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
	opts = opts or {}
	local theme = self._ctx.theme
	local column = opts.Column -- 1, 2, or nil for full width

	local parentContainer = self._page
	if column == 1 then parentContainer = self._col1 end
	if column == 2 then parentContainer = self._col2 end

	local sectionWrap = Primitives.createFrame({
		Name = "Section",
		Size = UDim2.new(1, 0, 0, 0),
		Transparency = 1,
		Parent = parentContainer,
	})
	sectionWrap.AutomaticSize = Enum.AutomaticSize.Y

	-- Subtle surface change instead of a boxed card: only a faint fill,
	-- no border, no heavy corner treatment competing with the workspace glass.
	local surface = Primitives.createFrame({
		Size = UDim2.new(1, 0, 0, 0),
		Color = theme.Colors.SurfaceLow,
		Transparency = 1 - 0.03, -- extremely faint; reads as "slightly raised" not "a card"
		Corner = theme.Radius.Large,
		Parent = sectionWrap,
	})
	surface.AutomaticSize = Enum.AutomaticSize.Y

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, theme.Spacing.M)
	pad.PaddingBottom = UDim.new(0, theme.Spacing.M)
	pad.PaddingLeft = UDim.new(0, theme.Spacing.M)
	pad.PaddingRight = UDim.new(0, theme.Spacing.M)
	pad.Parent = surface

	Primitives.createLayout(surface, { Gap = theme.Spacing.S })

	local collapsed = false
	local header, chevron, body

	if opts.Title then
		header = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 20), Transparency = 1, Parent = surface, LayoutOrder = 0 })
		Primitives.createText({
			Text = opts.Title, Font = theme.FontSemibold, TextSize = theme.TextSize.Body,
			Color = theme.Colors.TextPrimary, Size = UDim2.new(1, -20, 1, 0), Parent = header,
		})
		if opts.Collapsible then
			chevron = Primitives.createText({
				Text = "⌄", Font = theme.Font, TextSize = 14, Color = theme.Colors.TextTertiary,
				Size = UDim2.fromOffset(16, 16), Position = UDim2.new(1, -16, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5), AlignX = Enum.TextXAlignment.Center, Parent = header,
			})
			local hb = Instance.new("TextButton")
			hb.Text = ""; hb.BackgroundTransparency = 1; hb.Size = UDim2.fromScale(1, 1); hb.Parent = header
			hb.MouseButton1Click:Connect(function()
				collapsed = not collapsed
				body.Visible = not collapsed
				tween(theme, chevron, theme.Animation.Fast, { Rotation = collapsed and -90 or 0 })
			end)
		end
	end

	body = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 0), Transparency = 1, Parent = surface, LayoutOrder = 1 })
	body.AutomaticSize = Enum.AutomaticSize.Y
	Primitives.createLayout(body, { Gap = theme.Spacing.S })

	local ctx = {
		theme = self._ctx.theme,
		sounds = self._ctx.sounds,
		flags = self._ctx.flags,
		screenGui = self._ctx.screenGui,
		parent = body,
	}

	return newSection(ctx)
end

function TabMT:AddTwoColumnLayout()
	local theme = self._ctx.theme
	local row = Primitives.createFrame({ Size = UDim2.new(1, 0, 0, 0), Transparency = 1, Parent = self._page })
	row.AutomaticSize = Enum.AutomaticSize.Y

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.Padding = UDim.new(0, theme.Spacing.M)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = row

	local col1 = Primitives.createFrame({ Size = UDim2.new(0.5, -theme.Spacing.M / 2, 0, 0), Transparency = 1, Parent = row })
	col1.AutomaticSize = Enum.AutomaticSize.Y
	Primitives.createLayout(col1, { Gap = theme.Spacing.M })

	local col2 = Primitives.createFrame({ Size = UDim2.new(0.5, -theme.Spacing.M / 2, 0, 0), Transparency = 1, Parent = row })
	col2.AutomaticSize = Enum.AutomaticSize.Y
	Primitives.createLayout(col2, { Gap = theme.Spacing.M })

	self._col1 = col1
	self._col2 = col2
end

--============================================================
-- WINDOW
--============================================================
function Lunkara:CreateWindow(opts)
	opts = opts or {}
	local theme = opts.ThemeOverride and (function()
		local base = deepCopy(ThemePresets[opts.Theme] or DefaultTheme)
		for k, v in pairs(opts.ThemeOverride) do
			if type(v) == "table" and type(base[k]) == "table" then
				for kk, vv in pairs(v) do base[k][kk] = vv end
			else
				base[k] = v
			end
		end
		return base
	end)() or deepCopy(ThemePresets[opts.Theme] or DefaultTheme)

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LunkaraUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	screenGui.Parent = getGuiParent()

	local sounds = SoundHelper.new(theme)
	local flags = FlagsAPI.new()

	local windowSize = opts.Size or theme.WindowSize
	local minSize = theme.WindowMinSize

	local shadowHost = Primitives.createFrame({
		Name = "ShadowHost",
		Size = UDim2.fromOffset(windowSize.X, windowSize.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Transparency = 1,
		Parent = screenGui,
	})
	Primitives.createShadow({ Parent = shadowHost, Spread = 50, Transparency = 0.55, ZIndex = 0 })

	local main = Primitives.createGlassSurface(theme, {
		Name = "Main",
		Size = UDim2.fromScale(1, 1),
		Color = theme.Colors.Base,
		Transparency = 1,
		Corner = theme.Radius.Window,
		Parent = shadowHost,
		Clip = true,
		ZIndex = 2,
		SheenHeight = 30,
	})

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = minSize
	sizeConstraint.Parent = shadowHost

	-- ===== HEADER =====
	local header = Primitives.createFrame({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 44),
		Color = theme.Colors.SurfaceLow,
		Transparency = theme.Transparency.SurfaceLow,
		Parent = main,
		ZIndex = 3,
	})

	local titleLabel = Primitives.createText({
		Text = opts.Title or "Lunkara",
		Font = theme.FontBold,
		TextSize = theme.TextSize.Title,
		Color = theme.Colors.TextPrimary,
		Size = UDim2.new(0, 200, 1, 0),
		Position = UDim2.fromOffset(theme.Spacing.L, 0),
		ZIndex = 4,
		Parent = header,
	})

	-- header search
	local searchWrap = Primitives.createGlassSurface(theme, {
		Name = "HeaderSearch",
		Size = UDim2.fromOffset(220, 28),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Colors.SurfaceHigh,
		Transparency = theme.Transparency.SurfaceHigh,
		Corner = theme.Radius.Pill,
		Parent = header,
		ZIndex = 4,
		Sheen = false,
	})

	Primitives.createIcon({
		Id = theme.Icons.Search,
		Color = theme.Colors.TextTertiary,
		Size = UDim2.fromOffset(13, 13),
		Position = UDim2.fromOffset(10, 7.5),
		ZIndex = 5,
		Parent = searchWrap,
	})

	local searchBox = Instance.new("TextBox")
	searchBox.BackgroundTransparency = 1
	searchBox.Size = UDim2.new(1, -34, 1, 0)
	searchBox.Position = UDim2.fromOffset(30, 0)
	searchBox.Font = theme.Font
	searchBox.TextSize = theme.TextSize.Small
	searchBox.TextColor3 = theme.Colors.TextPrimary
	searchBox.PlaceholderText = "Search..."
	searchBox.ClearTextOnFocus = false
	searchBox.TextXAlignment = Enum.TextXAlignment.Left
	searchBox.ZIndex = 5
	searchBox.Parent = searchWrap

	-- window controls
	local function makeWindowBtn(symbol, xOffset, hoverColor)
		local b = Primitives.createFrame({
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, xOffset, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = theme.Colors.SurfaceHigh,
			Transparency = 1,
			Corner = theme.Radius.Small,
			Parent = header,
			ZIndex = 4,
		})
		Primitives.createText({ Text = symbol, Font = theme.FontSemibold, TextSize = 13, Color = theme.Colors.TextSecondary, Size = UDim2.fromScale(1, 1), AlignX = Enum.TextXAlignment.Center, ZIndex = 5, Parent = b })
		local hb = Instance.new("TextButton")
		hb.Text = ""; hb.BackgroundTransparency = 1; hb.Size = UDim2.fromScale(1, 1); hb.ZIndex = 6; hb.Parent = b
		hb.MouseEnter:Connect(function() tween(theme, b, theme.Animation.Fast, { BackgroundTransparency = theme.Transparency.SurfaceHigh, BackgroundColor3 = hoverColor or theme.Colors.SurfaceHigh }) end)
		hb.MouseLeave:Connect(function() tween(theme, b, theme.Animation.Fast, { BackgroundTransparency = 1 }) end)
		return hb
	end

	local closeBtn = makeWindowBtn("✕", -theme.Spacing.L, theme.Colors.Error)
	local minimizeBtn = makeWindowBtn("—", -theme.Spacing.L - 34)

	-- ===== BODY: sidebar + content =====
	local body = Primitives.createFrame({
		Name = "Body",
		Size = UDim2.new(1, 0, 1, -44),
		Position = UDim2.fromOffset(0, 44),
		Transparency = 1,
		Parent = main,
		ZIndex = 2,
	})

	local sidebarWidth = 56
	local sidebar = Primitives.createFrame({
		Name = "Sidebar",
		Size = UDim2.new(0, sidebarWidth, 1, 0),
		Color = theme.Colors.SurfaceLow,
		Transparency = theme.Transparency.SurfaceLow,
		Parent = body,
		ZIndex = 2,
	})

	local navLayout = Instance.new("UIListLayout")
	navLayout.FillDirection = Enum.FillDirection.Vertical
	navLayout.Padding = UDim.new(0, 6)
	navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	navLayout.SortOrder = Enum.SortOrder.LayoutOrder
	navLayout.Parent = sidebar
	local navPad = Instance.new("UIPadding")
	navPad.PaddingTop = UDim.new(0, 12)
	navPad.Parent = sidebar

	local contentArea = Primitives.createFrame({
		Name = "Content",
		Size = UDim2.new(1, -sidebarWidth, 1, 0),
		Position = UDim2.fromOffset(sidebarWidth, 0),
		Transparency = 1,
		Parent = body,
		Clip = true,
		ZIndex = 2,
	})

	local contentPad = Instance.new("UIPadding")
	contentPad.PaddingTop = UDim.new(0, theme.Spacing.L)
	contentPad.PaddingBottom = UDim.new(0, theme.Spacing.L)
	contentPad.PaddingLeft = UDim.new(0, theme.Spacing.L)
	contentPad.PaddingRight = UDim.new(0, theme.Spacing.L)
	contentPad.Parent = contentArea

	local notifications = NotificationManager.new(theme, screenGui, sounds)

	--============================================================
	-- WINDOW DRAG + CLAMP
	--============================================================
	local dragging = false
	local dragStart, startPos

	local function clampToViewport()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local pos = shadowHost.AbsolutePosition
		local size = shadowHost.AbsoluteSize
		local x = math.clamp(pos.X, 0, math.max(0, viewport.X - size.X))
		local y = math.clamp(pos.Y, 0, math.max(0, viewport.Y - size.Y))
		shadowHost.Position = UDim2.fromOffset(x, y)
		shadowHost.AnchorPoint = Vector2.new(0, 0)
	end

	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = shadowHost.Position
			shadowHost.AnchorPoint = Vector2.new(0, 0)
			startPos = UDim2.fromOffset(shadowHost.AbsolutePosition.X, shadowHost.AbsolutePosition.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			shadowHost.Position = UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y)
			clampToViewport()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	--============================================================
	-- OPEN / CLOSE / MINIMIZE ANIMATION
	--============================================================
	main.Size = UDim2.fromScale(0.94, 0.94)
	main.Position = UDim2.fromScale(0.03, 0.03)
	tween(theme, main, theme.Animation.Window, { Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0), BackgroundTransparency = theme.Transparency.Base }, Enum.EasingStyle.Quart)
	sounds:Play("Open")

	local minimized = false
	minimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			tween(theme, shadowHost, theme.Animation.Base, { Size = UDim2.fromOffset(windowSize.X, 44) })
			body.Visible = false
		else
			tween(theme, shadowHost, theme.Animation.Base, { Size = UDim2.fromOffset(windowSize.X, windowSize.Y) })
			task.delay(scaledDuration(theme, theme.Animation.Base), function() body.Visible = true end)
		end
	end)

	local windowObj = { _destroyed = false }

	local function destroyWindow()
		if windowObj._destroyed then return end
		windowObj._destroyed = true
		local t = tween(theme, main, theme.Animation.Base, { BackgroundTransparency = 1 })
		sounds:Play("Close")
		t.Completed:Connect(function()
			sounds:Destroy()
			screenGui:Destroy()
		end)
	end
	closeBtn.MouseButton1Click:Connect(destroyWindow)

	--============================================================
	-- TABS / NAV
	--============================================================
	local tabs = {}
	local activeTab = nil
	local searchIndex = {} -- title(lower) -> {tab, section title}

	local windowMT = {
		Flags = flags,
		Notify = function(_, notifyOpts) notifications:Notify(notifyOpts) end,
		Destroy = destroyWindow,
		SetTheme = function(_, newOverrides)
			for k, v in pairs(newOverrides) do
				if type(v) == "table" and type(theme[k]) == "table" then
					for kk, vv in pairs(v) do theme[k][kk] = vv end
				else
					theme[k] = v
				end
			end
		end,
	}

	function windowMT:AddTab(tabOpts)
		tabOpts = tabOpts or {}
		local index = #tabs + 1

		local navBtn = Primitives.createFrame({
			Size = UDim2.fromOffset(sidebarWidth - 16, sidebarWidth - 16),
			Color = theme.Colors.Accent,
			Transparency = 1,
			Corner = theme.Radius.Medium,
			Parent = sidebar,
			LayoutOrder = index,
		})

		local iconId = tabOpts.Icon and (IconHelper.isValid(tabOpts.Icon) and tabOpts.Icon or theme.Icons[tabOpts.Icon]) or nil
		local icon = Primitives.createIcon({
			Id = iconId,
			Color = theme.Colors.TextSecondary,
			Size = UDim2.fromOffset(20, 20),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
			Parent = navBtn,
		})

		local hb = Instance.new("TextButton")
		hb.Text = ""
		hb.BackgroundTransparency = 1
		hb.Size = UDim2.fromScale(1, 1)
		hb.ZIndex = 4
		hb.Selectable = true
		hb.Parent = navBtn

		local page = Primitives.createFrame({
			Name = "Page_" .. (tabOpts.Title or index),
			Size = UDim2.new(1, 0, 0, 0),
			Transparency = 1,
			Visible = false,
			Parent = contentArea,
		})
		page.AutomaticSize = Enum.AutomaticSize.Y

		local scroller = Instance.new("ScrollingFrame")
		scroller.Size = UDim2.fromScale(1, 1)
		scroller.BackgroundTransparency = 1
		scroller.BorderSizePixel = 0
		scroller.ScrollBarThickness = 3
		scroller.ScrollBarImageColor3 = theme.Colors.TextTertiary
		scroller.CanvasSize = UDim2.new(0, 0, 0, 0)
		scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroller.Parent = contentArea
		scroller.Visible = false
		scroller.Name = "Scroller_" .. (tabOpts.Title or index)

		page.Parent = scroller
		Primitives.createLayout(page, { Gap = theme.Spacing.M })

		local tabCtx = {
			theme = theme, sounds = sounds, flags = flags, screenGui = screenGui, parent = page,
		}

		local tabObj = setmetatable({ _ctx = tabCtx, _page = page, _scroller = scroller, _navBtn = navBtn, _icon = icon }, TabMT)
		tabs[index] = tabObj

		if tabOpts.Title then
			searchIndex[string.lower(tabOpts.Title)] = { tab = tabObj, label = tabOpts.Title }
		end

		local function activate()
			if activeTab == tabObj then return end
			if activeTab then
				activeTab._scroller.Visible = false
				tween(theme, activeTab._icon, theme.Animation.Fast, { ImageColor3 = theme.Colors.TextSecondary })
				activeTab._navBtn.BackgroundTransparency = 1
			end
			activeTab = tabObj
			scroller.Visible = true
			tween(theme, icon, theme.Animation.Fast, { ImageColor3 = theme.Colors.Accent })
			tween(theme, navBtn, theme.Animation.Fast, { BackgroundTransparency = 0.88 })
			sounds:Play("Click")
		end

		hb.MouseButton1Click:Connect(activate)

		if index == 1 then
			task.defer(activate)
		end

		return tabObj
	end

	function windowMT:Search(query)
		local results = {}
		for key, entry in pairs(searchIndex) do
			if string.find(key, string.lower(query), 1, true) then
				table.insert(results, entry)
			end
		end
		return results
	end

	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		if searchBox.Text == "" then return end
		-- results are computed on demand; a full popup UI can be wired by the
		-- developer via Window:Search(query) plus their own tab switch, or the
		-- keybind-driven quick-switch shown in the showcase script.
	end)

	windowMT.__index = windowMT
	return setmetatable(windowMT, { __index = windowMT })
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
	NOTE ON THE ONE PERMITTED UISTROKE-ADJACENT ELEMENT:
	This library uses zero UIStroke instances. Depth and separation are produced
	entirely through layered Frame transparency (Surface -> SurfaceHigh ->
	SurfaceRaised), a top "Sheen" band with a UIGradient transparency ramp, and
	ImageLabel-based soft shadows. No component in this file requires a stroke.
]]
