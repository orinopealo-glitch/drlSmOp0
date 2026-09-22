--[[
    LunkaraUI
    Version 1.1.0
    General-purpose Roblox UI library.

    Design goals:
      - dark, sharp, modern, slightly rounded
      - no decorative UIStroke spam
      - centralized lifecycle/input/overlay/animation/audio
      - object-oriented public API
      - GitHub Raw / single-file friendly
      - PC / keyboard + mouse first

    Entry:
      local LunkaraUI = loadstring(game:HttpGet("RAW_URL"))()
      local UI = LunkaraUI.new({...})
]]

local LunkaraUI = {}
LunkaraUI.__index = LunkaraUI
LunkaraUI.Version = "1.1.0"
LunkaraUI.Build = "polish-pass-1"

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

--// Assets
LunkaraUI.Assets = {
    Home = "rbxassetid://130068439240504",
    Search = "rbxassetid://122573675988962",
    Widgets = "rbxassetid://73608335773077",
    Settings = "rbxassetid://7059346373",
    Info = "rbxassetid://12707252279",

    Minimize = "rbxassetid://77150878131724",
    Maximize = "rbxassetid://74102407871192",
    Close = "rbxassetid://135341415849911",

    DropdownArrow = "rbxassetid://115283585599534",
    Checkmark = "rbxassetid://9754130783",

    Notification = "rbxassetid://115224157672228",
    Warning = "rbxassetid://14863060512",
    Success = "rbxassetid://15828137559",
}

-- Default SFX. Each sound can still be replaced or disabled from LunkaraUI.new().
LunkaraUI.SFX = {
    Hover = "rbxassetid://107511012621133",
    Click = "rbxassetid://133216848606395",
    Open = "rbxassetid://130359997277952",
    Close = "rbxassetid://130359997277952",
    Toggle = "rbxassetid://133216848606395",
    Notification = "rbxassetid://131039887376992",
    Success = "rbxassetid://101176804827210",
    Error = "rbxassetid://128187340772806",
}

-- Asset files have different amounts of transparent padding.
-- These values normalize perceived icon size without forcing every asset
-- into one physical size. Public callers can still pass direct asset IDs.
local ICON_METRICS = {
    Home = {Scale = 0.92, X = 0, Y = 0},
    Search = {Scale = 0.84, X = 0, Y = 0},
    Widgets = {Scale = 0.90, X = 0, Y = 0},
    Settings = {Scale = 0.90, X = 0, Y = 0},
    Info = {Scale = 0.92, X = 0, Y = 0},

    Minimize = {Scale = 0.86, X = 0, Y = 0},
    Maximize = {Scale = 0.84, X = 0, Y = 0},
    Close = {Scale = 0.86, X = 0, Y = 0},

    DropdownArrow = {Scale = 0.78, X = 0, Y = 0},
    Checkmark = {Scale = 0.72, X = 0, Y = 0},

    Notification = {Scale = 0.88, X = 0, Y = 0},
    Warning = {Scale = 0.88, X = 0, Y = 0},
    Success = {Scale = 0.88, X = 0, Y = 0},
}

--// Theme tokens
local DEFAULT_THEME = {
    -- V1.1 graphite palette: dark, but not dead-black.
    Background = Color3.fromRGB(14, 15, 19),
    Window = Color3.fromRGB(20, 21, 26),
    Sidebar = Color3.fromRGB(16, 17, 21),

    Surface = Color3.fromRGB(27, 28, 34),
    SurfaceHover = Color3.fromRGB(33, 34, 42),
    SurfacePressed = Color3.fromRGB(38, 39, 48),
    SurfaceRaised = Color3.fromRGB(32, 33, 40),
    Input = Color3.fromRGB(26, 27, 33),
    Popup = Color3.fromRGB(23, 24, 30),
    Track = Color3.fromRGB(55, 57, 68),

    Text = Color3.fromRGB(248, 248, 251),
    TextSecondary = Color3.fromRGB(204, 207, 216),
    TextMuted = Color3.fromRGB(150, 154, 166),
    DisabledText = Color3.fromRGB(99, 103, 114),

    -- Slightly purple-biased accent. Strong enough to identify state
    -- without turning the whole interface purple.
    Accent = Color3.fromRGB(124, 101, 255),
    AccentHover = Color3.fromRGB(141, 121, 255),
    AccentPressed = Color3.fromRGB(109, 87, 238),

    Danger = Color3.fromRGB(237, 93, 105),
    Warning = Color3.fromRGB(238, 176, 82),
    Success = Color3.fromRGB(79, 202, 132),

    RadiusWindow = 10,
    RadiusPanel = 8,
    RadiusControl = 7,
    RadiusSmall = 6,

    SidebarWidth = 70,
    HeaderHeight = 76,
    ControlHeight = 48,
    SectionGap = 14,
    ContentPadding = 20,

    AnimFast = 0.085,
    AnimStandard = 0.155,
    AnimEmphasized = 0.22,
    AnimWindow = 0.18,

    WindowWidth = 860,
    WindowHeight = 560,
    MinWindowWidth = 610,
    MinWindowHeight = 390,

    NotificationWidth = 344,
    NotificationGap = 9,
    NotificationMax = 5,
}


local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t or {}) do
        out[k] = v
    end
    return out
end

local function merge(base, override)
    local out = shallowCopy(base)
    for k, v in pairs(override or {}) do
        out[k] = v
    end
    return out
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return true
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[LunkaraUI] Callback error: " .. tostring(err))
    end
    return ok, err
end

local function clamp(v, min, max)
    return math.max(min, math.min(max, v))
end

local function roundTo(value, increment)
    increment = increment or 1
    if increment == 0 then
        return value
    end
    return math.floor((value / increment) + 0.5) * increment
end

local function normalizeAsset(asset)
    if asset == nil then return nil, nil end
    if LunkaraUI.Assets[asset] then
        return LunkaraUI.Assets[asset], ICON_METRICS[asset]
    end
    if type(asset) == "number" then
        return "rbxassetid://" .. tostring(asset), nil
    end
    if type(asset) == "string" then
        if asset:match("^%d+$") then
            return "rbxassetid://" .. asset, nil
        end
        return asset, nil
    end
    return nil, nil
end

local function make(className, props, children)
    local instance = Instance.new(className)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then
            instance[k] = v
        end
    end
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    if props and props.Parent then
        instance.Parent = props.Parent
    end
    return instance
end

local function createIcon(parent, asset, baseSize, color, position, anchorPoint, zIndex, scaleMultiplier)
    local source, metrics = normalizeAsset(asset)
    metrics = metrics or {Scale = 1, X = 0, Y = 0}

    local size = math.max(1, math.floor(
        (baseSize or 18) * (metrics.Scale or 1) * (scaleMultiplier or 1) + 0.5
    ))

    local pos = position or UDim2.fromScale(0.5, 0.5)
    local adjusted = UDim2.new(
        pos.X.Scale,
        pos.X.Offset + (metrics.X or 0),
        pos.Y.Scale,
        pos.Y.Offset + (metrics.Y or 0)
    )

    return make("ImageLabel", {
        BackgroundTransparency = 1,
        Image = source or "",
        ImageColor3 = color or Color3.new(1, 1, 1),
        ScaleType = Enum.ScaleType.Fit,
        AnchorPoint = anchorPoint or Vector2.new(0.5, 0.5),
        Position = adjusted,
        Size = UDim2.fromOffset(size, size),
        ZIndex = zIndex or 1,
        Parent = parent,
    })
end


local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius), Parent = parent})
end

local function padding(parent, l, r, t, b)
    return make("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        Parent = parent,
    })
end

local function list(parent, direction, gap)
    return make("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        Parent = parent,
    })
end

local function isAlive(instance)
    return typeof(instance) == "Instance" and instance.Parent ~= nil
end

--// Signal
local Signal = {}
Signal.__index = Signal

function Signal.new()
    return setmetatable({_handlers = {}, _destroyed = false}, Signal)
end

function Signal:Connect(fn)
    assert(type(fn) == "function", "Signal:Connect expected function")
    if self._destroyed then
        return {Disconnect = function() end}
    end

    local token = {}
    self._handlers[token] = fn
    local owner = self

    return {
        Disconnect = function()
            if token and owner and owner._handlers then
                owner._handlers[token] = nil
                token = nil
            end
        end
    }
end

function Signal._disconnect(self, token)
    if self and self._handlers then
        self._handlers[token] = nil
    end
end

-- simpler safe connection wrapper used internally
function Signal:On(fn)
    local token = {}
    self._handlers[token] = fn
    local owner = self
    return {
        Disconnect = function()
            if owner and owner._handlers then
                owner._handlers[token] = nil
            end
        end
    }
end

function Signal:Fire(...)
    if self._destroyed then return end
    local args = table.pack(...)
    for _, fn in pairs(shallowCopy(self._handlers)) do
        task.spawn(function()
            safeCall(fn, table.unpack(args, 1, args.n))
        end)
    end
end

function Signal:Destroy()
    self._destroyed = true
    table.clear(self._handlers)
end

--// Maid / lifecycle
local Maid = {}
Maid.__index = Maid

function Maid.new()
    return setmetatable({_tasks = {}, _cleaning = false}, Maid)
end

function Maid:Give(taskValue)
    if taskValue == nil then return nil end
    table.insert(self._tasks, taskValue)
    return taskValue
end

function Maid:Cleanup()
    if self._cleaning then return end
    self._cleaning = true

    for i = #self._tasks, 1, -1 do
        local taskValue = self._tasks[i]
        self._tasks[i] = nil

        local kind = typeof(taskValue)
        if kind == "RBXScriptConnection" then
            pcall(function() taskValue:Disconnect() end)
        elseif kind == "Instance" then
            pcall(function() taskValue:Destroy() end)
        elseif type(taskValue) == "function" then
            pcall(taskValue)
        elseif type(taskValue) == "table" then
            if type(taskValue.Destroy) == "function" then
                pcall(function() taskValue:Destroy() end)
            elseif type(taskValue.Disconnect) == "function" then
                pcall(function() taskValue:Disconnect() end)
            elseif type(taskValue.Cleanup) == "function" then
                pcall(function() taskValue:Cleanup() end)
            end
        end
    end

    self._cleaning = false
end

function Maid:Destroy()
    self:Cleanup()
end

--// Animation manager
local AnimationManager = {}
AnimationManager.__index = AnimationManager

function AnimationManager.new(ui)
    return setmetatable({
        UI = ui,
        Active = setmetatable({}, {__mode = "k"}),
        Enabled = true,
        Speed = 1,
    }, AnimationManager)
end

function AnimationManager:Tween(instance, duration, props, style, direction)
    if not instance or not instance.Parent then return nil end

    local keyMap = self.Active[instance]
    if not keyMap then
        keyMap = {}
        self.Active[instance] = keyMap
    end

    for property in pairs(props) do
        local old = keyMap[property]
        if old then
            pcall(function() old:Cancel() end)
            keyMap[property] = nil
        end
    end

    if not self.Enabled then
        for k, v in pairs(props) do
            pcall(function() instance[k] = v end)
        end
        return nil
    end

    local tween = TweenService:Create(
        instance,
        TweenInfo.new(
            math.max(0.01, (duration or self.UI.Theme.AnimStandard) / math.max(self.Speed, 0.05)),
            style or Enum.EasingStyle.Quint,
            direction or Enum.EasingDirection.Out
        ),
        props
    )

    for property in pairs(props) do
        keyMap[property] = tween
    end

    local conn
    conn = tween.Completed:Connect(function()
        if conn then conn:Disconnect() end
        for property in pairs(props) do
            if keyMap[property] == tween then
                keyMap[property] = nil
            end
        end
    end)

    tween:Play()
    return tween
end

function AnimationManager:SetEnabled(enabled)
    self.Enabled = enabled ~= false
end

function AnimationManager:SetSpeed(multiplier)
    self.Speed = tonumber(multiplier) or 1
end

--// Audio manager
local AudioManager = {}
AudioManager.__index = AudioManager

function AudioManager.new(ui, config)
    config = config or {}
    local sounds = shallowCopy(LunkaraUI.SFX)

    for kind, value in pairs(config) do
        if sounds[kind] ~= nil then
            sounds[kind] = value
        end
    end

    return setmetatable({
        UI = ui,
        Enabled = config.Enabled ~= false,
        Volume = tonumber(config.Volume) or 0.42,
        Sounds = sounds,
        Instances = {},
        LastPlayed = {},
        MinInterval = {
            Hover = 0.045,
            Click = 0.035,
            Toggle = 0.035,
            Open = 0.08,
            Close = 0.08,
            Notification = 0.10,
            Success = 0.10,
            Error = 0.10,
        },
    }, AudioManager)
end

function AudioManager:_source(kind)
    local id = self.Sounds[kind]
    if id == nil or id == "" or id == false then return nil end

    local source = tostring(id)
    if source:match("^%d+$") then
        source = "rbxassetid://" .. source
    end
    return source
end

function AudioManager:Play(kind, volumeMultiplier)
    if not self.Enabled then return end

    local source = self:_source(kind)
    if not source then return end

    local now = os.clock()
    local minimum = self.MinInterval[kind] or 0.03
    if self.LastPlayed[kind] and now - self.LastPlayed[kind] < minimum then
        return
    end
    self.LastPlayed[kind] = now

    local sound = self.Instances[kind]
    if not sound or not sound.Parent then
        sound = Instance.new("Sound")
        sound.Name = "LunkaraUI_" .. tostring(kind)
        sound.Parent = self.UI.ScreenGui
        self.Instances[kind] = sound
    end

    sound.SoundId = source
    sound.Volume = clamp(self.Volume * (tonumber(volumeMultiplier) or 1), 0, 10)

    pcall(function()
        if sound.IsPlaying then
            sound:Stop()
        end
        sound.TimePosition = 0
        sound:Play()
    end)
end

function AudioManager:SetEnabled(enabled)
    self.Enabled = enabled ~= false
end

function AudioManager:SetVolume(volume)
    self.Volume = clamp(tonumber(volume) or self.Volume, 0, 10)
end

function AudioManager:SetSound(kind, id)
    self.Sounds[kind] = id
    local sound = self.Instances[kind]
    if sound then
        pcall(function() sound:Stop() end)
        sound:Destroy()
        self.Instances[kind] = nil
    end
end

function AudioManager:Destroy()
    for kind, sound in pairs(self.Instances) do
        if sound then
            pcall(function() sound:Destroy() end)
        end
        self.Instances[kind] = nil
    end
end


--// Central input manager

--// Central input manager
local InputManager = {}
InputManager.__index = InputManager

function InputManager.new(ui)
    local self = setmetatable({
        UI = ui,
        Maid = Maid.new(),
        PointerMove = nil,
        PointerEnd = nil,
        KeyCapture = nil,
        GlobalKeyHandlers = {},
    }, InputManager)

    self.Maid:Give(UserInputService.InputChanged:Connect(function(input)
        if self.PointerMove and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            self.PointerMove(input)
        end
    end))

    self.Maid:Give(UserInputService.InputEnded:Connect(function(input)
        if self.PointerEnd and (
            input.UserInputType == Enum.UserInputType.MouseButton1 or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            local fn = self.PointerEnd
            self.PointerMove = nil
            self.PointerEnd = nil
            fn(input)
        end
    end))

    self.Maid:Give(UserInputService.InputBegan:Connect(function(input, processed)
        if self.KeyCapture and not processed then
            local capture = self.KeyCapture
            local accepted = capture(input)
            if accepted ~= false then
                self.KeyCapture = nil
                return
            end
        end

        if processed or UserInputService:GetFocusedTextBox() then return end

        for _, handler in ipairs(self.GlobalKeyHandlers) do
            safeCall(handler, input)
        end
    end))

    return self
end

function InputManager:BeginPointer(moveFn, endFn)
    self.PointerMove = moveFn
    self.PointerEnd = endFn
end

function InputManager:CaptureKey(fn)
    self.KeyCapture = fn
end

function InputManager:CancelKeyCapture()
    self.KeyCapture = nil
end

function InputManager:AddGlobalKeyHandler(fn)
    table.insert(self.GlobalKeyHandlers, fn)
    local index = #self.GlobalKeyHandlers
    return {
        Disconnect = function()
            self.GlobalKeyHandlers[index] = function() end
        end
    }
end

function InputManager:Destroy()
    self.Maid:Cleanup()
    table.clear(self.GlobalKeyHandlers)
end

--// State
local State = {}
State.__index = State

function State.new(value)
    return setmetatable({
        Value = value,
        Changed = Signal.new(),
    }, State)
end

function State:Get()
    return self.Value
end

function State:Set(value, source)
    if self.Value == value then return false end
    local old = self.Value
    self.Value = value
    self.Changed:Fire(value, old, source or "API")
    return true
end

function State:Destroy()
    self.Changed:Destroy()
end

--// Base component
local Component = {}
Component.__index = Component

function Component:_init(host, kind, root, config)
    self.Host = host
    self.UI = host.UI
    self.Window = host.Window
    self.Page = host.Page
    self.Section = host.Section
    self.Type = kind
    self.Root = root
    self.Config = config or {}
    self.Maid = Maid.new()
    self.Disabled = false
    self.Visible = true
    self.Destroyed = false
    self.Title = self.Config.Title or self.Config.Name or kind
    self.Description = self.Config.Description
    self.Flag = self.Config.Flag
    self.SearchKeywords = self.Config.Keywords or {}
    self._flagRegistered = false

    self.Maid:Give(root)

    self.UI:_registerSearch(self)
    if self.Flag then
        self.UI:_registerFlag(self)
        self._flagRegistered = true
    end

    return self
end

function Component:SetVisible(visible)
    if self.Destroyed then return self end
    self.Visible = visible ~= false
    self.Root.Visible = self.Visible
    return self
end

function Component:SetDisabled(disabled, reason)
    if self.Destroyed then return self end
    self.Disabled = disabled == true
    self.DisabledReason = reason
    self:_refreshDisabled()
    return self
end

function Component:_refreshDisabled()
    if not self.Root then return end

    if self.TitleLabel and self.TitleLabel:IsA("TextLabel") then
        self.TitleLabel.TextColor3 = self.Disabled and self.UI.Theme.DisabledText or self.UI.Theme.Text
    end

    if self.DescriptionLabel and self.DescriptionLabel:IsA("TextLabel") then
        self.DescriptionLabel.TextColor3 = self.Disabled and self.UI.Theme.DisabledText or self.UI.Theme.TextMuted
    end

    if self.Root:IsA("GuiObject") then
        self.Root.Active = not self.Disabled
    end
end

function Component:SetTitle(title)
    self.Title = tostring(title or "")
    if self.TitleLabel then
        self.TitleLabel.Text = self.Title
    end
    self.UI:_refreshSearch(self)
    return self
end

function Component:SetDescription(description)
    self.Description = description
    if self.DescriptionLabel then
        self.DescriptionLabel.Text = description or ""
        self.DescriptionLabel.Visible = description ~= nil and description ~= ""
    end
    self.UI:_refreshSearch(self)
    return self
end

function Component:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    self.UI:_unregisterSearch(self)
    if self._flagRegistered then
        self.UI:_unregisterFlag(self)
    end

    if self.State then
        self.State:Destroy()
    end

    self.Maid:Cleanup()
end

--// Host shared by Page and Section
local ComponentHost = {}
ComponentHost.__index = ComponentHost

function ComponentHost.new(ui, window, page, section, parent)
    return setmetatable({
        UI = ui,
        Window = window,
        Page = page,
        Section = section,
        Parent = parent,
        Components = {},
    }, ComponentHost)
end

function ComponentHost:_track(component)
    table.insert(self.Components, component)
    return component
end

local function addHoverBehavior(component, target, surface)
    local ui = component.UI
    local theme = ui.Theme
    local hovering = false

    component.Maid:Give(target.MouseEnter:Connect(function()
        if component.Disabled then return end
        hovering = true
        ui.Animation:Tween(surface, theme.AnimFast, {BackgroundColor3 = theme.SurfaceHover})
        ui.Audio:Play("Hover", 0.68)
    end))

    component.Maid:Give(target.MouseLeave:Connect(function()
        if component.Disabled then return end
        hovering = false
        ui.Animation:Tween(surface, theme.AnimFast, {BackgroundColor3 = theme.Surface})
    end))

    component.Maid:Give(target.MouseButton1Down:Connect(function()
        if component.Disabled then return end
        ui.Animation:Tween(surface, theme.AnimFast, {BackgroundColor3 = theme.SurfacePressed})
    end))

    component.Maid:Give(target.MouseButton1Up:Connect(function()
        if component.Disabled then return end
        ui.Animation:Tween(surface, theme.AnimFast, {
            BackgroundColor3 = hovering and theme.SurfaceHover or theme.Surface
        })
    end))
end

local function createBaseRow(host, title, description, height)
    local theme = host.UI.Theme
    local row = make("Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or theme.ControlHeight),
        Parent = host.Parent,
    })
    corner(row, theme.RadiusControl)

    local titleLabel = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = title or "",
        Font = Enum.Font.GothamMedium,
        TextSize = 13,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -96, 1, 0),
        Parent = row,
    })

    local descriptionLabel = nil
    if description and description ~= "" then
        titleLabel.Size = UDim2.new(1, -96, 0, 23)
        titleLabel.Position = UDim2.fromOffset(14, 5)
        titleLabel.TextYAlignment = Enum.TextYAlignment.Bottom

        descriptionLabel = make("TextLabel", {
            BackgroundTransparency = 1,
            Text = description,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = theme.TextMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(14, 29),
            Size = UDim2.new(1, -96, 0, 18),
            Parent = row,
        })
    end

    return row, titleLabel, descriptionLabel
end


--// Button

--// Button
function ComponentHost:AddButton(config)
    config = config or {}
    local row, title, description = createBaseRow(self, config.Title or "Button", config.Description, config.Description and 56 or 46)

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local action = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = config.ActionText or "Run",
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = self.UI.Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Right,
        Position = UDim2.new(1, -74, 0, 0),
        Size = UDim2.fromOffset(58, row.Size.Y.Offset),
        Parent = row,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Button", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.ActionLabel = action

    addHoverBehavior(component, hit, row)

    component.Maid:Give(hit.MouseButton1Click:Connect(function()
        if component.Disabled then return end
        self.UI.Audio:Play("Click")
        safeCall(config.Callback, component)
    end))

    function component:Fire()
        if self.Disabled or self.Destroyed then return self end
        safeCall(config.Callback, self)
        return self
    end

    return self:_track(component)
end

--// Toggle
function ComponentHost:AddToggle(config)
    config = config or {}
    local row, title, description = createBaseRow(
        self,
        config.Title or "Toggle",
        config.Description,
        config.Description and 58 or 48
    )
    local theme = self.UI.Theme

    local track = make("Frame", {
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(40, 22),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Parent = row,
    })
    corner(track, 11)

    local knob = make("Frame", {
        BackgroundColor3 = theme.Text,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(18, 18),
        Position = UDim2.fromOffset(2, 2),
        Parent = track,
    })
    corner(knob, 9)

    local knobScale = make("UIScale", {
        Scale = 1,
        Parent = knob,
    })

    local check = createIcon(
        knob,
        "Checkmark",
        12,
        theme.AccentPressed,
        UDim2.fromScale(0.5, 0.5),
        Vector2.new(0.5, 0.5),
        3,
        1
    )
    check.ImageTransparency = 1

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Toggle", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.State = State.new(config.Default == true)

    local function render(value, immediate)
        local bg = value and theme.Accent or theme.Track
        local pos = value and UDim2.fromOffset(20, 2) or UDim2.fromOffset(2, 2)

        if immediate then
            track.BackgroundColor3 = bg
            knob.Position = pos
            check.ImageTransparency = value and 0 or 1
        else
            self.UI.Animation:Tween(track, theme.AnimStandard, {BackgroundColor3 = bg})
            self.UI.Animation:Tween(knob, theme.AnimStandard, {Position = pos})
            self.UI.Animation:Tween(check, theme.AnimFast, {ImageTransparency = value and 0 or 1})

            self.UI.Animation:Tween(knobScale, 0.07, {Scale = 1.08}, Enum.EasingStyle.Quad)
            task.delay(0.075, function()
                if knobScale and knobScale.Parent then
                    self.UI.Animation:Tween(knobScale, 0.11, {Scale = 1}, Enum.EasingStyle.Quint)
                end
            end)
        end
    end

    component.Maid:Give(component.State.Changed:On(function(value, _, source)
        render(value, source == "Init" or source == "Config")
        self.UI:_syncFlag(component, value)

        if source == "User" then
            self.UI.Audio:Play("Toggle")
            safeCall(config.Callback, value, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Callback, value, component)
        end
    end))

    render(component.State:Get(), true)
    self.UI:_syncFlag(component, component.State:Get())

    addHoverBehavior(component, hit, row)

    component.Maid:Give(hit.MouseButton1Click:Connect(function()
        if component.Disabled then return end
        component.State:Set(not component.State:Get(), "User")
    end))

    function component:Get()
        return self.State:Get()
    end

    function component:Set(value)
        self.State:Set(value == true, "API")
        return self
    end

    function component:_setFromConfig(value)
        self.State:Set(value == true, "Config")
        render(self.State:Get(), true)
    end

    return self:_track(component)
end


--// Slider

--// Slider
function ComponentHost:AddSlider(config)
    config = config or {}
    local theme = self.UI.Theme
    local min = tonumber(config.Min) or 0
    local max = tonumber(config.Max) or 100
    if max <= min then max = min + 1 end
    local increment = tonumber(config.Increment) or 1
    local default = clamp(tonumber(config.Default) or min, min, max)

    local row, title, description = createBaseRow(self, config.Title or "Slider", config.Description, config.Description and 76 or 68)
    title.Size = UDim2.new(1, -100, 0, 24)

    local valueLabel = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -13, 0, 8),
        Size = UDim2.fromOffset(72, 18),
        Parent = row,
    })

    local bar = make("TextButton", {
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Position = UDim2.new(0, 13, 1, -19),
        Size = UDim2.new(1, -26, 0, 6),
        Parent = row,
    })
    corner(bar, 3)

    local fill = make("Frame", {
        BackgroundColor3 = theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0, 1),
        Parent = bar,
    })
    corner(fill, 3)

    local component = setmetatable({}, Component)
    component:_init(self, "Slider", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.Min = min
    component.Max = max
    component.Increment = increment
    component.State = State.new(roundTo(default, increment))

    local function formatValue(v)
        if type(config.Format) == "function" then
            local ok, result = pcall(config.Format, v)
            if ok then return tostring(result) end
        end
        return tostring(v) .. (config.Suffix or "")
    end

    local function render(v, immediate)
        local alpha = (v - min) / (max - min)
        alpha = clamp(alpha, 0, 1)
        valueLabel.Text = formatValue(v)
        local target = UDim2.fromScale(alpha, 1)
        if immediate then
            fill.Size = target
        else
            self.UI.Animation:Tween(fill, theme.AnimFast, {Size = target})
        end
    end

    component.Maid:Give(component.State.Changed:On(function(v, _, source)
        render(v, source == "Init" or source == "Config")
        self.UI:_syncFlag(component, v)
        if source == "User" then
            safeCall(config.Callback, v, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Callback, v, component)
        end
    end))

    local function setFromX(x, source)
        if component.Disabled then return end
        local alpha = clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        local value = roundTo(min + (max - min) * alpha, increment)
        value = clamp(value, min, max)
        component.State:Set(value, source)
    end

    component.Maid:Give(bar.InputBegan:Connect(function(input)
        if component.Disabled then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self.UI.Audio:Play("Click")
            setFromX(input.Position.X, "User")
            self.UI.Input:BeginPointer(function(move)
                setFromX(move.Position.X, "User")
            end, function() end)
        end
    end))

    render(component.State:Get(), true)
    self.UI:_syncFlag(component, component.State:Get())

    function component:Get()
        return self.State:Get()
    end

    function component:Set(value)
        value = clamp(roundTo(tonumber(value) or self.State:Get(), self.Increment), self.Min, self.Max)
        self.State:Set(value, "API")
        return self
    end

    function component:_setFromConfig(value)
        value = clamp(roundTo(tonumber(value) or self.State:Get(), self.Increment), self.Min, self.Max)
        self.State:Set(value, "Config")
        render(self.State:Get(), true)
    end

    return self:_track(component)
end

--// Overlay manager
local OverlayManager = {}
OverlayManager.__index = OverlayManager

function OverlayManager.new(ui)
    local layer = make("Frame", {
        Name = "OverlayLayer",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 10000,
        Active = false,
        Parent = ui.ScreenGui,
    })

    return setmetatable({
        UI = ui,
        Layer = layer,
        Active = nil,
        Maid = Maid.new(),
    }, OverlayManager)
end

function OverlayManager:Close()
    if not self.Active then return end
    local active = self.Active
    self.Active = nil

    if active.OnClose then
        safeCall(active.OnClose)
    end

    if active.Maid then
        active.Maid:Cleanup()
    elseif active.Root then
        active.Root:Destroy()
    end

    self.Layer.Active = false
    self.UI.Audio:Play("Close", 0.72)
end

function OverlayManager:Open(anchor, size, builder, onClose)
    self:Close()

    local maid = Maid.new()
    local root = make("Frame", {
        BackgroundColor3 = self.UI.Theme.Popup,
        BorderSizePixel = 0,
        Size = size,
        ZIndex = 10002,
        Parent = self.Layer,
    })
    corner(root, self.UI.Theme.RadiusPanel)
    maid:Give(root)

    local clickCatcher = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 10001,
        Parent = self.Layer,
    })
    maid:Give(clickCatcher)

    local function position()
        if not anchor or not anchor.Parent then return end
        local ap = anchor.AbsolutePosition
        local as = anchor.AbsoluteSize
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local x = ap.X
        local y = ap.Y + as.Y + 6
        local w = size.X.Offset
        local h = size.Y.Offset

        if x + w > viewport.X - 8 then
            x = math.max(8, viewport.X - w - 8)
        end
        if y + h > viewport.Y - 8 then
            y = math.max(8, ap.Y - h - 6)
        end

        root.Position = UDim2.fromOffset(x, y)
    end

    position()

    maid:Give(clickCatcher.MouseButton1Click:Connect(function()
        self:Close()
    end))

    self.Layer.Active = true
    self.Active = {Root = root, Maid = maid, OnClose = onClose}
    if builder then
        builder(root, maid)
    end

    self.UI.Audio:Play("Open")
    self.UI.Animation:Tween(root, self.UI.Theme.AnimFast, {BackgroundTransparency = 0})
    return root, maid
end

function OverlayManager:Destroy()
    self:Close()
    self.Maid:Cleanup()
    if self.Layer then self.Layer:Destroy() end
end

--// Dropdown
function ComponentHost:AddDropdown(config)
    config = config or {}
    local options = config.Values or config.Options or {}
    local default = config.Default
    if default == nil then default = options[1] end

    local row, title, description = createBaseRow(
        self,
        config.Title or "Dropdown",
        config.Description,
        config.Description and 58 or 48
    )
    local theme = self.UI.Theme

    local selected = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = tostring(default or "None"),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(1, -177, 0, 0),
        Size = UDim2.fromOffset(132, row.Size.Y.Offset),
        Parent = row,
    })

    local arrow = createIcon(
        row,
        "DropdownArrow",
        18,
        theme.TextMuted,
        UDim2.new(1, -24, 0.5, 0),
        Vector2.new(0.5, 0.5),
        2,
        1
    )

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Dropdown", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.Options = shallowCopy(options)
    component.State = State.new(default)
    component.Open = false

    local function render(v)
        selected.Text = v == nil and "None" or tostring(v)
    end

    local function setOpen(open)
        component.Open = open == true
        self.UI.Animation:Tween(
            arrow,
            theme.AnimStandard,
            {
                Rotation = component.Open and 180 or 0,
                ImageColor3 = component.Open and theme.TextSecondary or theme.TextMuted,
            }
        )
    end

    component.Maid:Give(component.State.Changed:On(function(v, _, source)
        render(v)
        self.UI:_syncFlag(component, v)

        if source == "User" then
            self.UI.Audio:Play("Click")
            safeCall(config.Callback, v, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Callback, v, component)
        end
    end))

    local function openDropdown()
        if component.Disabled then return end
        if component.Open then
            self.UI.Overlay:Close()
            return
        end

        setOpen(true)
        local values = component.Options
        local height = math.min(248, 16 + (#values * 35))

        self.UI.Overlay:Open(
            row,
            UDim2.fromOffset(math.max(228, row.AbsoluteSize.X), height),
            function(root, maid)
                root.BackgroundTransparency = 0
                padding(root, 8, 8, 8, 8)

                local scroller = make("ScrollingFrame", {
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.TextMuted,
                    Size = UDim2.fromScale(1, 1),
                    CanvasSize = UDim2.new(),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ZIndex = 10003,
                    Parent = root,
                })
                list(scroller, Enum.FillDirection.Vertical, 4)

                for _, value in ipairs(values) do
                    local active = value == component.State:Get()
                    local btn = make("TextButton", {
                        BackgroundColor3 = active and theme.SurfaceRaised or theme.Popup,
                        BorderSizePixel = 0,
                        Text = tostring(value),
                        Font = Enum.Font.GothamMedium,
                        TextSize = 12,
                        TextColor3 = active and theme.Text or theme.TextSecondary,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Size = UDim2.new(1, 0, 0, 31),
                        ZIndex = 10004,
                        Parent = scroller,
                    })
                    corner(btn, theme.RadiusSmall)
                    padding(btn, 11, 11, 0, 0)

                    maid:Give(btn.MouseEnter:Connect(function()
                        self.UI.Animation:Tween(btn, theme.AnimFast, {
                            BackgroundColor3 = theme.SurfaceHover,
                            TextColor3 = theme.Text,
                        })
                    end))

                    maid:Give(btn.MouseLeave:Connect(function()
                        self.UI.Animation:Tween(btn, theme.AnimFast, {
                            BackgroundColor3 = value == component.State:Get() and theme.SurfaceRaised or theme.Popup,
                            TextColor3 = value == component.State:Get() and theme.Text or theme.TextSecondary,
                        })
                    end))

                    maid:Give(btn.MouseButton1Click:Connect(function()
                        component.State:Set(value, "User")
                        self.UI.Overlay:Close()
                    end))
                end
            end,
            function()
                setOpen(false)
            end
        )
    end

    addHoverBehavior(component, hit, row)
    component.Maid:Give(hit.MouseButton1Click:Connect(openDropdown))

    render(component.State:Get())
    self.UI:_syncFlag(component, component.State:Get())

    function component:Get()
        return self.State:Get()
    end

    function component:Set(value)
        if table.find(self.Options, value) then
            self.State:Set(value, "API")
        end
        return self
    end

    function component:SetOptions(values, keepSelection)
        self.Options = shallowCopy(values or {})
        if not keepSelection or not table.find(self.Options, self.State:Get()) then
            self.State:Set(self.Options[1], "API")
        end
        return self
    end

    function component:Refresh(values, keepSelection)
        return self:SetOptions(values, keepSelection)
    end

    function component:_setFromConfig(value)
        if table.find(self.Options, value) then
            self.State:Set(value, "Config")
            render(value)
        end
    end

    return self:_track(component)
end


--// Multi dropdown
function ComponentHost:AddMultiDropdown(config)
    config = config or {}

    local options = config.Values or config.Options or {}
    local defaults = config.Default or {}
    local theme = self.UI.Theme

    local row, title, description = createBaseRow(
        self,
        config.Title or "Multi Dropdown",
        config.Description,
        config.Description and 58 or 48
    )

    local selected = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = "",
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Right,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(1, -193, 0, 0),
        Size = UDim2.fromOffset(145, row.Size.Y.Offset),
        Parent = row,
    })

    local arrow = createIcon(
        row,
        "DropdownArrow",
        18,
        theme.TextMuted,
        UDim2.new(1, -24, 0.5, 0),
        Vector2.new(0.5, 0.5),
        2,
        1
    )

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local initial = {}
    for _, value in ipairs(defaults) do
        if table.find(options, value) then
            initial[value] = true
        end
    end

    local component = setmetatable({}, Component)
    component:_init(self, "MultiDropdown", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.Options = shallowCopy(options)
    component.State = State.new(initial)
    component.Open = false

    local function snapshot()
        local out = {}
        for _, option in ipairs(component.Options) do
            if component.State:Get()[option] then
                table.insert(out, option)
            end
        end
        return out
    end

    local function render()
        local values = snapshot()

        if #values == 0 then
            selected.Text = "None"
        elseif #values <= 2 then
            selected.Text = table.concat(values, ", ")
        else
            selected.Text = tostring(#values) .. " selected"
        end
    end

    local function emit(source)
        local values = snapshot()
        self.UI:_syncFlag(component, values)

        if source == "User" then
            safeCall(config.Callback, values, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Callback, values, component)
        end
    end

    local function setOpen(open)
        component.Open = open == true
        self.UI.Animation:Tween(arrow, theme.AnimStandard, {
            Rotation = component.Open and 180 or 0,
            ImageColor3 = component.Open and theme.TextSecondary or theme.TextMuted,
        })
    end

    local function open()
        if component.Disabled then return end

        if component.Open then
            self.UI.Overlay:Close()
            return
        end

        setOpen(true)
        local height = math.min(258, 16 + #component.Options * 35)

        self.UI.Overlay:Open(
            row,
            UDim2.fromOffset(math.max(230, row.AbsoluteSize.X), height),
            function(root, maid)
                padding(root, 8, 8, 8, 8)

                local scroller = make("ScrollingFrame", {
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    ScrollBarThickness = 2,
                    ScrollBarImageColor3 = theme.TextMuted,
                    Size = UDim2.fromScale(1, 1),
                    CanvasSize = UDim2.new(),
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    ZIndex = 10003,
                    Parent = root,
                })
                list(scroller, Enum.FillDirection.Vertical, 4)

                for _, option in ipairs(component.Options) do
                    local active = component.State:Get()[option] == true

                    local btn = make("TextButton", {
                        BackgroundColor3 = active and theme.SurfaceRaised or theme.Popup,
                        BorderSizePixel = 0,
                        Text = tostring(option),
                        Font = Enum.Font.GothamMedium,
                        TextSize = 12,
                        TextColor3 = active and theme.Text or theme.TextSecondary,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        AutoButtonColor = false,
                        Size = UDim2.new(1, 0, 0, 31),
                        ZIndex = 10004,
                        Parent = scroller,
                    })
                    corner(btn, theme.RadiusSmall)
                    padding(btn, 11, 34, 0, 0)

                    local check = createIcon(
                        btn,
                        "Checkmark",
                        15,
                        theme.Accent,
                        UDim2.new(1, -13, 0.5, 0),
                        Vector2.new(1, 0.5),
                        10005,
                        1
                    )
                    check.ImageTransparency = active and 0 or 1

                    maid:Give(btn.MouseEnter:Connect(function()
                        self.UI.Animation:Tween(btn, theme.AnimFast, {
                            BackgroundColor3 = theme.SurfaceHover,
                            TextColor3 = theme.Text,
                        })
                    end))

                    maid:Give(btn.MouseLeave:Connect(function()
                        local selectedNow = component.State:Get()[option] == true
                        self.UI.Animation:Tween(btn, theme.AnimFast, {
                            BackgroundColor3 = selectedNow and theme.SurfaceRaised or theme.Popup,
                            TextColor3 = selectedNow and theme.Text or theme.TextSecondary,
                        })
                    end))

                    maid:Give(btn.MouseButton1Click:Connect(function()
                        local current = shallowCopy(component.State:Get())
                        current[option] = not current[option]

                        component.State:Set(current, "User")
                        render()
                        emit("User")
                        self.UI.Audio:Play("Click", 0.82)

                        self.UI.Animation:Tween(btn, theme.AnimFast, {
                            BackgroundColor3 = current[option] and theme.SurfaceRaised or theme.Popup,
                            TextColor3 = current[option] and theme.Text or theme.TextSecondary,
                        })
                        self.UI.Animation:Tween(check, theme.AnimFast, {
                            ImageTransparency = current[option] and 0 or 1,
                        })
                    end))
                end
            end,
            function()
                setOpen(false)
            end
        )
    end

    component.Maid:Give(component.State.Changed:On(function(_, _, source)
        render()
        if source ~= "User" then
            emit(source)
        end
    end))

    addHoverBehavior(component, hit, row)
    component.Maid:Give(hit.MouseButton1Click:Connect(open))

    render()
    emit("Init")

    function component:Get()
        return snapshot()
    end

    function component:Set(values)
        local nextState = {}

        for _, value in ipairs(values or {}) do
            if table.find(self.Options, value) then
                nextState[value] = true
            end
        end

        self.State:Set(nextState, "API")
        return self
    end

    function component:SetOptions(values, keepSelection)
        local previous = self:Get()
        self.Options = shallowCopy(values or {})

        if keepSelection then
            return self:Set(previous)
        end

        return self:Set({})
    end

    function component:_setFromConfig(values)
        local nextState = {}

        for _, value in ipairs(values or {}) do
            if table.find(self.Options, value) then
                nextState[value] = true
            end
        end

        self.State:Set(nextState, "Config")
        render()
    end

    return self:_track(component)
end

--// Textbox
function ComponentHost:AddTextbox(config)
    config = config or {}
    local theme = self.UI.Theme
    local row, title, description = createBaseRow(self, config.Title or "Textbox", config.Description, config.Description and 62 or 50)

    local box = make("TextBox", {
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        Text = tostring(config.Default or ""),
        PlaceholderText = config.Placeholder or "Type...",
        PlaceholderColor3 = theme.TextMuted,
        ClearTextOnFocus = config.ClearOnFocus == true,
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(176, 30),
        Parent = row,
    })
    corner(box, theme.RadiusSmall)
    padding(box, 9, 9, 0, 0)

    title.Size = UDim2.new(1, -220, title.Size.Y.Scale, title.Size.Y.Offset)

    local component = setmetatable({}, Component)
    component:_init(self, "Textbox", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.State = State.new(tostring(config.Default or ""))

    local applying = false

    component.Maid:Give(box.FocusLost:Connect(function(enterPressed)
        if component.Disabled then return end
        if config.RequireEnter and not enterPressed then
            box.Text = component.State:Get()
            return
        end

        local text = box.Text
        if config.MaxLength and #text > config.MaxLength then
            text = text:sub(1, config.MaxLength)
            box.Text = text
        end

        component.State:Set(text, "User")
    end))

    component.Maid:Give(component.State.Changed:On(function(v, _, source)
        if box.Text ~= v then
            applying = true
            box.Text = v
            applying = false
        end
        self.UI:_syncFlag(component, v)
        if source == "User" then
            safeCall(config.Callback, v, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Callback, v, component)
        end
    end))

    self.UI:_syncFlag(component, component.State:Get())

    function component:Get()
        return self.State:Get()
    end

    function component:Set(value)
        self.State:Set(tostring(value or ""), "API")
        return self
    end

    function component:_setFromConfig(value)
        self.State:Set(tostring(value or ""), "Config")
        box.Text = self.State:Get()
    end

    return self:_track(component)
end

ComponentHost.AddInput = ComponentHost.AddTextbox

--// Keybind
function ComponentHost:AddKeybind(config)
    config = config or {}
    local theme = self.UI.Theme
    local row, title, description = createBaseRow(self, config.Title or "Keybind", config.Description, config.Description and 56 or 46)

    local default = config.Default or Enum.KeyCode.Unknown
    local valueLabel = make("TextLabel", {
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        Text = default.Name or tostring(default),
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(92, 28),
        Parent = row,
    })
    corner(valueLabel, theme.RadiusSmall)

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Keybind", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.State = State.new(default)
    component.Binding = false

    local function display(v)
        if typeof(v) == "EnumItem" then return v.Name end
        return tostring(v or "None")
    end

    component.Maid:Give(component.State.Changed:On(function(v, _, source)
        valueLabel.Text = display(v)
        self.UI:_syncFlag(component, v)
        if source == "User" then
            safeCall(config.Changed, v, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Changed, v, component)
        end
    end))

    component.Maid:Give(hit.MouseButton1Click:Connect(function()
        if component.Disabled or component.Binding then return end
        component.Binding = true
        valueLabel.Text = "Press key"

        self.UI.Input:CaptureKey(function(input)
            if input.KeyCode == Enum.KeyCode.Escape then
                component.Binding = false
                valueLabel.Text = display(component.State:Get())
                return true
            end

            local chosen
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                chosen = input.KeyCode
            elseif input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.MouseButton2
                or input.UserInputType == Enum.UserInputType.MouseButton3 then
                chosen = input.UserInputType
            end

            if chosen then
                component.Binding = false
                component.State:Set(chosen, "User")
                return true
            end
            return false
        end)
    end))

    local globalConn = self.UI.Input:AddGlobalKeyHandler(function(input)
        if component.Disabled or component.Binding then return end
        local current = component.State:Get()

        local match = false
        if typeof(current) == "EnumItem" then
            if current.EnumType == Enum.KeyCode then
                match = input.KeyCode == current
            else
                match = input.UserInputType == current
            end
        end

        if match then
            safeCall(config.Callback, current, component)
        end
    end)
    component.Maid:Give(globalConn)

    self.UI:_syncFlag(component, display(component.State:Get()))

    function component:Get()
        return self.State:Get()
    end

    function component:Set(value)
        if typeof(value) == "EnumItem" then
            self.State:Set(value, "API")
        end
        return self
    end

    function component:_setFromConfig(value)
        local enum = nil
        if typeof(value) == "EnumItem" then
            enum = value
        elseif type(value) == "string" then
            enum = Enum.KeyCode[value] or Enum.UserInputType[value]
        end

        if enum then
            self.State:Set(enum, "Config")
            valueLabel.Text = display(enum)
        end
    end

    return self:_track(component)
end

--// Color picker
function ComponentHost:AddColorPicker(config)
    config = config or {}
    local theme = self.UI.Theme
    local default = typeof(config.Default) == "Color3" and config.Default or Color3.new(1, 1, 1)

    local row, title, description = createBaseRow(self, config.Title or "Color", config.Description, config.Description and 56 or 46)

    local swatch = make("Frame", {
        BackgroundColor3 = default,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -13, 0.5, 0),
        Size = UDim2.fromOffset(34, 22),
        Parent = row,
    })
    corner(swatch, theme.RadiusSmall)

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "ColorPicker", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.State = State.new(default)

    local function render(color)
        swatch.BackgroundColor3 = color
    end

    component.Maid:Give(component.State.Changed:On(function(color, _, source)
        render(color)
        self.UI:_syncFlag(component, color)
        if source == "User" then
            safeCall(config.Callback, color, component)
        elseif source == "API" and config.CallbackOnAPI == true then
            safeCall(config.Callback, color, component)
        end
    end))

    local function open()
        if component.Disabled then return end
        self.UI.Overlay:Open(row, UDim2.fromOffset(260, 190), function(root, maid)
            padding(root, 12, 12, 12, 12)

            local h, s, v = Color3.toHSV(component.State:Get())

            local sv = make("ImageButton", {
                BackgroundColor3 = Color3.fromHSV(h, 1, 1),
                BorderSizePixel = 0,
                AutoButtonColor = false,
                Image = "rbxassetid://4155801252",
                Size = UDim2.new(1, -34, 1, -24),
                ZIndex = 10004,
                Parent = root,
            })
            corner(sv, theme.RadiusSmall)

            local hue = make("Frame", {
                BackgroundColor3 = Color3.new(1,1,1),
                BorderSizePixel = 0,
                Position = UDim2.new(1, -22, 0, 0),
                Size = UDim2.new(0, 22, 1, -24),
                ZIndex = 10004,
                Parent = root,
            })
            corner(hue, theme.RadiusSmall)
            local grad = make("UIGradient", {
                Rotation = 90,
                Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
                    ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
                    ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
                    ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
                    ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
                    ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
                    ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1.00, 1, 1)),
                }),
                Parent = hue,
            })

            local hex = make("TextLabel", {
                BackgroundTransparency = 1,
                Text = "",
                Font = Enum.Font.GothamMedium,
                TextSize = 12,
                TextColor3 = theme.TextSecondary,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.new(0, 0, 1, -18),
                Size = UDim2.new(1, 0, 0, 18),
                ZIndex = 10004,
                Parent = root,
            })

            local function toHex(color)
                return string.format("#%02X%02X%02X",
                    math.floor(color.R * 255 + 0.5),
                    math.floor(color.G * 255 + 0.5),
                    math.floor(color.B * 255 + 0.5)
                )
            end

            local function update()
                sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
                local color = Color3.fromHSV(h, s, v)
                component.State:Set(color, "User")
                hex.Text = toHex(color)
            end

            local function fromSV(pos)
                s = clamp((pos.X - sv.AbsolutePosition.X) / math.max(sv.AbsoluteSize.X, 1), 0, 1)
                v = 1 - clamp((pos.Y - sv.AbsolutePosition.Y) / math.max(sv.AbsoluteSize.Y, 1), 0, 1)
                update()
            end

            local function fromHue(pos)
                h = clamp((pos.Y - hue.AbsolutePosition.Y) / math.max(hue.AbsoluteSize.Y, 1), 0, 1)
                update()
            end

            maid:Give(sv.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    fromSV(input.Position)
                    self.UI.Input:BeginPointer(function(move) fromSV(move.Position) end, function() end)
                end
            end))

            maid:Give(hue.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    fromHue(input.Position)
                    self.UI.Input:BeginPointer(function(move) fromHue(move.Position) end, function() end)
                end
            end))

            hex.Text = toHex(component.State:Get())
        end)
    end

    addHoverBehavior(component, hit, row)
    component.Maid:Give(hit.MouseButton1Click:Connect(open))

    render(component.State:Get())
    self.UI:_syncFlag(component, default)

    function component:Get()
        return self.State:Get()
    end

    function component:Set(value)
        if typeof(value) == "Color3" then
            self.State:Set(value, "API")
        end
        return self
    end

    function component:_setFromConfig(value)
        if typeof(value) == "Color3" then
            self.State:Set(value, "Config")
        elseif type(value) == "table" then
            local color = Color3.fromRGB(
                tonumber(value.R) or 255,
                tonumber(value.G) or 255,
                tonumber(value.B) or 255
            )
            self.State:Set(color, "Config")
        end
        render(self.State:Get())
    end

    return self:_track(component)
end

ComponentHost.AddColorpicker = ComponentHost.AddColorPicker

--// Label
function ComponentHost:AddLabel(config)
    if type(config) == "string" then config = {Title = config} end
    config = config or {}
    local theme = self.UI.Theme
    local row = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        Parent = self.Parent,
    })

    local label = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = config.Title or config.Text or "Label",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = config.Color or theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = config.Wrap == true,
        Size = UDim2.fromScale(1, 1),
        Parent = row,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Label", row, config)
    component.TitleLabel = label

    function component:Set(value)
        self:SetTitle(value)
        return self
    end

    return self:_track(component)
end

--// Paragraph
function ComponentHost:AddParagraph(config)
    if type(config) == "string" then config = {Text = config} end
    config = config or {}
    local theme = self.UI.Theme

    local frame = make("Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = self.Parent,
    })
    corner(frame, theme.RadiusControl)
    padding(frame, 13, 13, 11, 11)

    local holder = make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = frame,
    })
    local layout = list(holder, Enum.FillDirection.Vertical, 5)

    local title = nil
    if config.Title then
        title = make("TextLabel", {
            BackgroundTransparency = 1,
            Text = config.Title,
            Font = Enum.Font.GothamMedium,
            TextSize = 13,
            TextColor3 = theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            AutomaticSize = Enum.AutomaticSize.Y,
            Size = UDim2.new(1, 0, 0, 0),
            Parent = holder,
        })
    end

    local body = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = config.Text or config.Content or "",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = holder,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Paragraph", frame, config)
    component.TitleLabel = title
    component.BodyLabel = body

    function component:Set(value)
        self.BodyLabel.Text = tostring(value or "")
        return self
    end

    function component:SetText(value)
        return self:Set(value)
    end

    return self:_track(component)
end

--// Image
function ComponentHost:AddImage(config)
    config = config or {}
    local theme = self.UI.Theme
    local frame = make("Frame", {
        BackgroundColor3 = theme.Surface,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, tonumber(config.Height) or 160),
        ClipsDescendants = true,
        Parent = self.Parent,
    })
    corner(frame, theme.RadiusControl)

    local image = make("ImageLabel", {
        BackgroundTransparency = 1,
        Image = normalizeAsset(config.Image or config.Asset or "") or "",
        ScaleType = config.ScaleType or Enum.ScaleType.Crop,
        Size = UDim2.fromScale(1, 1),
        Parent = frame,
    })

    local component = setmetatable({}, Component)
    component:_init(self, "Image", frame, config)
    component.Image = image

    function component:Set(value)
        local asset = normalizeAsset(value)
        if asset then self.Image.Image = asset end
        return self
    end

    return self:_track(component)
end

--// Progress
function ComponentHost:AddProgress(config)
    config = config or {}
    local theme = self.UI.Theme
    local min = tonumber(config.Min) or 0
    local max = tonumber(config.Max) or 100
    local default = clamp(tonumber(config.Default) or min, min, max)

    local row, title, description = createBaseRow(self, config.Title or "Progress", config.Description, config.Description and 70 or 62)
    local bar = make("Frame", {
        BackgroundColor3 = theme.Track,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 13, 1, -17),
        Size = UDim2.new(1, -26, 0, 5),
        Parent = row,
    })
    corner(bar, 3)

    local fill = make("Frame", {
        BackgroundColor3 = config.Color or theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(0,1),
        Parent = bar,
    })
    corner(fill, 3)

    local component = setmetatable({}, Component)
    component:_init(self, "Progress", row, config)
    component.TitleLabel = title
    component.DescriptionLabel = description
    component.State = State.new(default)
    component.Min = min
    component.Max = max

    local function render(v, immediate)
        local alpha = clamp((v-min)/(max-min),0,1)
        local size = UDim2.fromScale(alpha,1)
        if immediate then fill.Size = size else
            self.UI.Animation:Tween(fill, theme.AnimStandard, {Size=size})
        end
    end

    component.Maid:Give(component.State.Changed:On(function(v,_,source)
        render(v, source=="Config")
        self.UI:_syncFlag(component, v)
    end))

    render(default, true)
    self.UI:_syncFlag(component, default)

    function component:Get() return self.State:Get() end
    function component:Set(value)
        self.State:Set(clamp(tonumber(value) or self.State:Get(), self.Min, self.Max), "API")
        return self
    end
    function component:_setFromConfig(value)
        self.State:Set(clamp(tonumber(value) or self.State:Get(), self.Min, self.Max), "Config")
        render(self.State:Get(), true)
    end

    return self:_track(component)
end

ComponentHost.AddProgressBar = ComponentHost.AddProgress

--// Section
local Section = {}
Section.__index = Section

function Section.new(page, config)
    config = config or {}
    local self = setmetatable({}, Section)
    self.UI = page.UI
    self.Window = page.Window
    self.Page = page
    self.Config = config
    self.Maid = Maid.new()
    self.Collapsed = false

    local columnName = tostring(config.Column or "Left"):lower()
    local parent = columnName == "right" and page.RightColumn or page.LeftColumn

    local root = make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = parent,
    })
    self.Root = root

    local header = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 30),
        Parent = root,
    })

    local title = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = config.Title or "Section",
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextColor3 = self.UI.Theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        Size = UDim2.new(1, -30, 1, 0),
        Parent = header,
    })
    self.TitleLabel = title

    local collapse = nil
    if config.Collapsible then
        collapse = createIcon(
            header,
            "DropdownArrow",
            16,
            self.UI.Theme.TextMuted,
            UDim2.new(1, -10, 0.5, 0),
            Vector2.new(1, 0.5),
            2,
            1
        )
        self.CollapseIcon = collapse
    end

    local holder = make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Position = UDim2.fromOffset(0, 30),
        Size = UDim2.new(1, 0, 0, 0),
        Parent = root,
    })
    list(holder, Enum.FillDirection.Vertical, 8)

    self.Holder = holder
    self.Host = ComponentHost.new(self.UI, self.Window, self.Page, self, holder)

    if config.Collapsible then
        self.Maid:Give(header.MouseEnter:Connect(function()
            self.UI.Animation:Tween(title, self.UI.Theme.AnimFast, {TextColor3 = self.UI.Theme.Text})
        end))
        self.Maid:Give(header.MouseLeave:Connect(function()
            self.UI.Animation:Tween(title, self.UI.Theme.AnimFast, {TextColor3 = self.UI.Theme.TextSecondary})
        end))
        self.Maid:Give(header.MouseButton1Click:Connect(function()
            self:SetCollapsed(not self.Collapsed)
        end))
    end

    return self
end



function Section:SetCollapsed(collapsed)
    self.Collapsed = collapsed == true

    if self.CollapseIcon then
        self.UI.Animation:Tween(self.CollapseIcon, self.UI.Theme.AnimStandard, {
            Rotation = self.Collapsed and -90 or 0
        })
    end

    if self.Collapsed then
        self.Holder.Visible = false
        self.Root.AutomaticSize = Enum.AutomaticSize.None
        self.Root.Size = UDim2.new(1, 0, 0, 30)
    else
        self.Holder.Visible = true
        self.Root.AutomaticSize = Enum.AutomaticSize.Y
        self.Root.Size = UDim2.new(1, 0, 0, 0)
    end

    return self
end

function Section:SetTitle(title)
    self.TitleLabel.Text = tostring(title or "")
    return self
end

function Section:Destroy()
    for _, component in ipairs(self.Host.Components) do
        component:Destroy()
    end
    self.Maid:Cleanup()
    if self.Root then self.Root:Destroy() end
end

for _, name in ipairs({
    "AddButton","AddToggle","AddSlider","AddDropdown","AddMultiDropdown","AddTextbox","AddInput",
    "AddKeybind","AddColorPicker","AddColorpicker","AddLabel","AddParagraph","AddImage","AddProgress","AddProgressBar"
}) do
    Section[name] = function(self, ...)
        return self.Host[name](self.Host, ...)
    end
end

--// Page
local Page = {}
Page.__index = Page

function Page.new(window, config)
    config = config or {}
    local self = setmetatable({}, Page)
    self.UI = window.UI
    self.Window = window
    self.Config = config
    self.Title = config.Title or "Page"
    self.Description = config.Description
    self.Sections = {}
    self.Maid = Maid.new()

    local root = make("ScrollingFrame", {
        Name = "Page_" .. self.Title,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = self.UI.Theme.TextMuted,
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        Visible = false,
        Position = UDim2.fromOffset(0, self.UI.Theme.HeaderHeight),
        Size = UDim2.new(1, 0, 1, -self.UI.Theme.HeaderHeight),
        Parent = window.Content,
    })
    self.Root = root
    padding(root, self.UI.Theme.ContentPadding, self.UI.Theme.ContentPadding, 4, self.UI.Theme.ContentPadding)

    local columns = make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = root,
    })
    self.Columns = columns

    local columnsLayout = list(columns, Enum.FillDirection.Horizontal, self.UI.Theme.SectionGap)
    columnsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    columnsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    self.ColumnsLayout = columnsLayout

    local left = make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(0.5, -self.UI.Theme.SectionGap/2, 0, 0),
        Parent = columns,
    })
    list(left, Enum.FillDirection.Vertical, self.UI.Theme.SectionGap)

    local right = make("Frame", {
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(0.5, -self.UI.Theme.SectionGap/2, 0, 0),
        Parent = columns,
    })
    list(right, Enum.FillDirection.Vertical, self.UI.Theme.SectionGap)

    self.LeftColumn = left
    self.RightColumn = right
    self.Host = ComponentHost.new(self.UI, window, self, nil, left)

    self.Maid:Give(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local width = root.AbsoluteSize.X
        if width < 620 then
            columnsLayout.FillDirection = Enum.FillDirection.Vertical
            left.Size = UDim2.new(1, 0, 0, 0)
            right.Size = UDim2.new(1, 0, 0, 0)
        else
            columnsLayout.FillDirection = Enum.FillDirection.Horizontal
            left.Size = UDim2.new(0.5, -self.UI.Theme.SectionGap/2, 0, 0)
            right.Size = UDim2.new(0.5, -self.UI.Theme.SectionGap/2, 0, 0)
        end
    end))

    self:_buildNavButton(config)
    return self
end

function Page:_buildNavButton(config)
    local theme = self.UI.Theme

    local nav = make("TextButton", {
        BackgroundColor3 = theme.Surface,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromOffset(46, 44),
        Parent = self.Window.NavList,
    })
    corner(nav, theme.RadiusControl)
    self.NavButton = nav

    local icon = createIcon(
        nav,
        config.Icon or "Home",
        21,
        theme.TextMuted,
        UDim2.fromScale(0.5, 0.5),
        Vector2.new(0.5, 0.5),
        2,
        1
    )
    self.NavIcon = icon

    self.Maid:Give(nav.MouseEnter:Connect(function()
        if self.Window.ActivePage ~= self then
            self.UI.Animation:Tween(nav, theme.AnimFast, {
                BackgroundTransparency = 0,
                BackgroundColor3 = theme.Surface,
            })
            self.UI.Animation:Tween(icon, theme.AnimFast, {
                ImageColor3 = theme.TextSecondary,
            })
        end

        self.UI.Audio:Play("Hover", 0.65)
        self.Window:_showTooltip(nav, self.Title)
    end))

    self.Maid:Give(nav.MouseLeave:Connect(function()
        self.Window:_hideTooltip()

        if self.Window.ActivePage ~= self then
            self.UI.Animation:Tween(nav, theme.AnimFast, {BackgroundTransparency = 1})
            self.UI.Animation:Tween(icon, theme.AnimFast, {ImageColor3 = theme.TextMuted})
        end
    end))

    self.Maid:Give(nav.MouseButton1Click:Connect(function()
        self.Window:SetPage(self)
    end))
end



function Page:AddSection(config)
    local section = Section.new(self, config)
    table.insert(self.Sections, section)
    return section
end

function Page:AddSpacer(height)
    local spacer = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,0, tonumber(height) or 8),
        Parent = self.LeftColumn,
    })
    return spacer
end

function Page:Destroy()
    for _, section in ipairs(self.Sections) do
        section:Destroy()
    end
    for _, component in ipairs(self.Host.Components) do
        component:Destroy()
    end
    self.Maid:Cleanup()
    if self.Root then self.Root:Destroy() end
    if self.NavButton then self.NavButton:Destroy() end
end

for _, name in ipairs({
    "AddButton","AddToggle","AddSlider","AddDropdown","AddMultiDropdown","AddTextbox","AddInput",
    "AddKeybind","AddColorPicker","AddColorpicker","AddLabel","AddParagraph","AddImage","AddProgress","AddProgressBar"
}) do
    Page[name] = function(self, ...)
        return self.Host[name](self.Host, ...)
    end
end

--// Window
local Window = {}
Window.__index = Window

function Window.new(ui, config)
    config = config or {}

    local self = setmetatable({}, Window)
    self.UI = ui
    self.Config = config
    self.Title = config.Title or "LunkaraUI"
    self.Subtitle = config.Subtitle or ""
    self.Pages = {}
    self.Maid = Maid.new()
    self.Minimized = false
    self.Maximized = false
    self.Hidden = false
    self.ActivePage = nil
    self.Restore = nil

    local theme = ui.Theme
    local camera = workspace.CurrentCamera

    local function viewportSize()
        local current = workspace.CurrentCamera
        return current and current.ViewportSize or Vector2.new(1440, 900)
    end

    local viewport = viewportSize()
    local maxWidth = math.max(460, viewport.X - 48)
    local maxHeight = math.max(330, viewport.Y - 48)

    local width = math.min(tonumber(config.Width) or theme.WindowWidth, maxWidth)
    local height = math.min(tonumber(config.Height) or theme.WindowHeight, maxHeight)

    local root = make("Frame", {
        Name = "LunkaraWindow",
        BackgroundColor3 = theme.Window,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = config.Position or UDim2.new(0.5, #ui.Windows * 22, 0.5, #ui.Windows * 18),
        Size = UDim2.fromOffset(width, height),
        ClipsDescendants = true,
        Active = true,
        Parent = ui.ScreenGui,
    })
    corner(root, theme.RadiusWindow)

    local rootScale = make("UIScale", {
        Scale = 0.975,
        Parent = root,
    })

    self.Root = root
    self.RootScale = rootScale
    self.Maid:Give(root)

    local sizeConstraint = make("UISizeConstraint", {
        MinSize = Vector2.new(
            math.min(theme.MinWindowWidth, maxWidth),
            math.min(theme.MinWindowHeight, maxHeight)
        ),
        MaxSize = Vector2.new(maxWidth, maxHeight),
        Parent = root,
    })
    self.SizeConstraint = sizeConstraint

    local sidebar = make("Frame", {
        BackgroundColor3 = theme.Sidebar,
        BorderSizePixel = 0,
        Size = UDim2.new(0, theme.SidebarWidth, 1, 0),
        Parent = root,
    })
    self.Sidebar = sidebar

    local dragZone = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Position = UDim2.fromOffset(theme.SidebarWidth, 0),
        Size = UDim2.new(1, -theme.SidebarWidth, 0, theme.HeaderHeight),
        Parent = root,
    })
    self.DragZone = dragZone

    local navList = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 20),
        Size = UDim2.new(1, -24, 1, -94),
        Parent = sidebar,
    })
    local navLayout = list(navList, Enum.FillDirection.Vertical, 6)
    navLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    self.NavList = navList

    local brand = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = "LunkaraUI",
        Font = Enum.Font.GothamMedium,
        TextSize = 10,
        TextColor3 = theme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Center,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -14),
        Size = UDim2.new(1, -10, 0, 18),
        Parent = sidebar,
    })
    self.Brand = brand

    local content = make("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(theme.SidebarWidth, 0),
        Size = UDim2.new(1, -theme.SidebarWidth, 1, 0),
        Parent = root,
    })
    self.Content = content

    local pageTitle = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = self.Title,
        Font = Enum.Font.GothamSemibold,
        TextSize = 19,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(theme.ContentPadding, 15),
        Size = UDim2.new(1, -360, 0, 25),
        Parent = content,
    })
    self.PageTitle = pageTitle

    local pageSubtitle = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = self.Subtitle,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.TextMuted,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(theme.ContentPadding, 42),
        Size = UDim2.new(1, -360, 0, 17),
        Parent = content,
    })
    self.PageSubtitle = pageSubtitle

    local searchWrap = make("Frame", {
        BackgroundColor3 = theme.Input,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -116, 0, 18),
        Size = UDim2.fromOffset(205, 34),
        Parent = content,
    })
    corner(searchWrap, theme.RadiusSmall)

    local searchIcon = createIcon(
        searchWrap,
        "Search",
        17,
        theme.TextMuted,
        UDim2.fromOffset(17, 17),
        Vector2.new(0.5, 0.5),
        2,
        0.92
    )

    local search = make("TextBox", {
        BackgroundTransparency = 1,
        Text = "",
        PlaceholderText = "Search",
        PlaceholderColor3 = theme.TextMuted,
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(33, 0),
        Size = UDim2.new(1, -41, 1, 0),
        Parent = searchWrap,
    })
    self.SearchBox = search

    local controls = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 18),
        Size = UDim2.fromOffset(94, 34),
        Parent = content,
    })
    local controlsLayout = list(controls, Enum.FillDirection.Horizontal, 3)
    controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local function controlButton(iconName, danger)
        local btn = make("TextButton", {
            BackgroundTransparency = 1,
            BackgroundColor3 = theme.Surface,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.fromOffset(28, 28),
            Parent = controls,
        })
        corner(btn, theme.RadiusSmall)

        local icon = createIcon(
            btn,
            iconName,
            15,
            danger and theme.TextMuted or theme.TextMuted,
            UDim2.fromScale(0.5, 0.5),
            Vector2.new(0.5, 0.5),
            2,
            1
        )

        self.Maid:Give(btn.MouseEnter:Connect(function()
            ui.Audio:Play("Hover", 0.62)
            ui.Animation:Tween(btn, theme.AnimFast, {
                BackgroundTransparency = 0,
                BackgroundColor3 = danger and Color3.fromRGB(58, 31, 37) or theme.Surface,
            })
            ui.Animation:Tween(icon, theme.AnimFast, {
                ImageColor3 = danger and theme.Danger or theme.Text,
            })
        end))

        self.Maid:Give(btn.MouseLeave:Connect(function()
            ui.Animation:Tween(btn, theme.AnimFast, {BackgroundTransparency = 1})
            ui.Animation:Tween(icon, theme.AnimFast, {ImageColor3 = theme.TextMuted})
        end))

        return btn, icon
    end

    local minimize = controlButton("Minimize", false)
    local maximize = controlButton("Maximize", false)
    local close = controlButton("Close", true)

    local resizeGrip = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.fromScale(1, 1),
        Size = UDim2.fromOffset(22, 22),
        Parent = root,
    })
    self.ResizeGrip = resizeGrip

    -- Proper minimized surface. V1 hid the header controls and could not be restored.
    local minimizedBar = make("Frame", {
        BackgroundTransparency = 1,
        Visible = false,
        Size = UDim2.fromScale(1, 1),
        Parent = root,
    })
    self.MinimizedBar = minimizedBar

    local minimizedTitle = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = self.Title,
        Font = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(15, 0),
        Size = UDim2.new(1, -82, 1, 0),
        Parent = minimizedBar,
    })
    self.MinimizedTitle = minimizedTitle

    local miniDrag = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, -72, 1, 0),
        Parent = minimizedBar,
    })

    local miniRestore = make("TextButton", {
        BackgroundTransparency = 1,
        BackgroundColor3 = theme.Surface,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -38, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        Parent = minimizedBar,
    })
    corner(miniRestore, theme.RadiusSmall)
    createIcon(miniRestore, "Maximize", 15, theme.TextMuted, UDim2.fromScale(0.5,0.5), Vector2.new(0.5,0.5), 2, 1)

    local miniClose = make("TextButton", {
        BackgroundTransparency = 1,
        BackgroundColor3 = theme.Surface,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, 0),
        Size = UDim2.fromOffset(28, 28),
        Parent = minimizedBar,
    })
    corner(miniClose, theme.RadiusSmall)
    createIcon(miniClose, "Close", 15, theme.TextMuted, UDim2.fromScale(0.5,0.5), Vector2.new(0.5,0.5), 2, 1)

    local tooltip = make("TextLabel", {
        BackgroundColor3 = theme.Popup,
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        Font = Enum.Font.GothamMedium,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false,
        ZIndex = 200,
        Parent = root,
    })
    corner(tooltip, theme.RadiusSmall)
    padding(tooltip, 9, 9, 6, 6)
    self.Tooltip = tooltip

    -- Search results panel.
    local searchPanel = make("Frame", {
        BackgroundColor3 = theme.Popup,
        BorderSizePixel = 0,
        Visible = false,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -116, 0, 58),
        Size = UDim2.fromOffset(322, 270),
        ZIndex = 150,
        Parent = content,
    })
    corner(searchPanel, theme.RadiusPanel)
    padding(searchPanel, 8, 8, 8, 8)

    local searchResults = make("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = theme.TextMuted,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 151,
        Parent = searchPanel,
    })
    list(searchResults, Enum.FillDirection.Vertical, 4)
    self.SearchPanel = searchPanel
    self.SearchResults = searchResults

    local function clampWindowToViewport()
        if not root.Parent or self.Maximized or self.Minimized then return end

        local vp = viewportSize()
        local availableW = math.max(460, vp.X - 48)
        local availableH = math.max(330, vp.Y - 48)

        sizeConstraint.MinSize = Vector2.new(
            math.min(theme.MinWindowWidth, availableW),
            math.min(theme.MinWindowHeight, availableH)
        )
        sizeConstraint.MaxSize = Vector2.new(availableW, availableH)

        local current = root.AbsoluteSize
        local newW = math.min(current.X, availableW)
        local newH = math.min(current.Y, availableH)

        if newW ~= current.X or newH ~= current.Y then
            root.Size = UDim2.fromOffset(newW, newH)
        end

        local center = root.AbsolutePosition + root.AbsoluteSize / 2
        local half = root.AbsoluteSize / 2
        local x = clamp(center.X, half.X + 8, vp.X - half.X - 8)
        local y = clamp(center.Y, half.Y + 8, vp.Y - half.Y - 8)

        if math.abs(x - center.X) > 1 or math.abs(y - center.Y) > 1 then
            root.Position = UDim2.fromOffset(x, y)
        end
    end

    local function beginDrag(input)
        if self.Maximized then return end

        ui.WindowManager:Focus(self)
        local startMouse = input.Position
        local startCenter = root.AbsolutePosition + root.AbsoluteSize / 2

        ui.Input:BeginPointer(function(move)
            local vp = viewportSize()
            local delta = move.Position - startMouse
            local half = root.AbsoluteSize / 2
            local center = startCenter + delta

            local x = clamp(center.X, half.X + 8, vp.X - half.X - 8)
            local y = clamp(center.Y, half.Y + 8, vp.Y - half.Y - 8)

            root.Position = UDim2.fromOffset(x, y)
        end, function() end)
    end

    self.Maid:Give(dragZone.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            beginDrag(input)
        end
    end))

    self.Maid:Give(miniDrag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            beginDrag(input)
        end
    end))

    self.Maid:Give(resizeGrip.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 or self.Maximized then return end

        ui.WindowManager:Focus(self)
        local startMouse = input.Position
        local startSize = root.AbsoluteSize

        ui.Input:BeginPointer(function(move)
            local vp = viewportSize()
            local delta = move.Position - startMouse
            local maxW = math.max(460, vp.X - 48)
            local maxH = math.max(330, vp.Y - 48)

            local minW = math.min(theme.MinWindowWidth, maxW)
            local minH = math.min(theme.MinWindowHeight, maxH)

            local w = clamp(startSize.X + delta.X, minW, maxW)
            local h = clamp(startSize.Y + delta.Y, minH, maxH)
            root.Size = UDim2.fromOffset(w, h)
        end, function()
            clampWindowToViewport()
        end)
    end))

    self.Maid:Give(root.InputBegan:Connect(function()
        ui.WindowManager:Focus(self)
    end))

    self.Maid:Give(minimize.MouseButton1Click:Connect(function()
        ui.Audio:Play("Click")
        self:Minimize()
    end))

    self.Maid:Give(maximize.MouseButton1Click:Connect(function()
        ui.Audio:Play("Click")
        self:ToggleMaximize()
    end))

    self.Maid:Give(close.MouseButton1Click:Connect(function()
        ui.Audio:Play("Click")
        self:Close()
    end))

    self.Maid:Give(miniRestore.MouseButton1Click:Connect(function()
        ui.Audio:Play("Click")
        self:RestoreWindow()
    end))

    self.Maid:Give(miniClose.MouseButton1Click:Connect(function()
        ui.Audio:Play("Click")
        self:Close()
    end))

    self.Maid:Give(search.Focused:Connect(function()
        ui.Animation:Tween(searchWrap, theme.AnimFast, {BackgroundColor3 = theme.SurfaceRaised})
        ui.Animation:Tween(searchIcon, theme.AnimFast, {ImageColor3 = theme.TextSecondary})
    end))

    self.Maid:Give(search.FocusLost:Connect(function()
        ui.Animation:Tween(searchWrap, theme.AnimFast, {BackgroundColor3 = theme.Input})
        ui.Animation:Tween(searchIcon, theme.AnimFast, {ImageColor3 = theme.TextMuted})

        task.delay(0.12, function()
            if search.Text == "" then
                searchPanel.Visible = false
            end
        end)
    end))

    self.Maid:Give(search:GetPropertyChangedSignal("Text"):Connect(function()
        self:_runSearch(search.Text)
    end))

    local toggleKey = config.ToggleKey
    if toggleKey then
        self.Maid:Give(ui.Input:AddGlobalKeyHandler(function(input)
            if input.KeyCode == toggleKey then
                self:Toggle()
            end
        end))
    end

    if camera then
        self.Maid:Give(camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            task.defer(clampWindowToViewport)
        end))
    end

    task.defer(clampWindowToViewport)
    ui.WindowManager:Focus(self)

    ui.Animation:Tween(rootScale, theme.AnimWindow, {Scale = 1}, Enum.EasingStyle.Quint)
    ui.Audio:Play("Open", 0.72)

    return self
end



function Window:_showTooltip(anchor, text)
    if not text or text == "" then return end
    local tooltip = self.Tooltip
    tooltip.Text = text
    tooltip.Visible = true
    tooltip.BackgroundTransparency = 0
    tooltip.Position = UDim2.fromOffset(
        self.UI.Theme.SidebarWidth + 6,
        anchor.AbsolutePosition.Y - self.Root.AbsolutePosition.Y + math.floor(anchor.AbsoluteSize.Y/2) - 13
    )
end

function Window:_hideTooltip()
    self.Tooltip.Visible = false
end

function Window:_runSearch(query)
    query = string.lower((query or ""):gsub("^%s+",""):gsub("%s+$",""))
    for _, child in ipairs(self.SearchResults:GetChildren()) do
        if child:IsA("GuiObject") then child:Destroy() end
    end

    if query == "" then
        self.SearchPanel.Visible = false
        return
    end

    local matches = self.UI:_search(query, self)
    self.SearchPanel.Visible = true

    if #matches == 0 then
        local empty = make("TextLabel", {
            BackgroundTransparency = 1,
            Text = "No results",
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = self.UI.Theme.TextMuted,
            Size = UDim2.new(1,0,0,34),
            ZIndex = 152,
            Parent = self.SearchResults,
        })
        return
    end

    for i = 1, math.min(#matches, 20) do
        local item = matches[i]
        local component = item.Component
        local button = make("TextButton", {
            BackgroundColor3 = self.UI.Theme.Popup,
            BorderSizePixel = 0,
            Text = "",
            AutoButtonColor = false,
            Size = UDim2.new(1,0,0,44),
            ZIndex = 152,
            Parent = self.SearchResults,
        })
        corner(button, self.UI.Theme.RadiusSmall)

        local title = make("TextLabel", {
            BackgroundTransparency = 1,
            Text = component.Title,
            Font = Enum.Font.GothamSemibold,
            TextSize = 12,
            TextColor3 = self.UI.Theme.Text,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(10,5),
            Size = UDim2.new(1,-20,0,17),
            ZIndex = 153,
            Parent = button,
        })

        local meta = make("TextLabel", {
            BackgroundTransparency = 1,
            Text = (component.Page and component.Page.Title or "Page") .. "  ·  " .. component.Type,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = self.UI.Theme.TextMuted,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(10,23),
            Size = UDim2.new(1,-20,0,14),
            ZIndex = 153,
            Parent = button,
        })

        self.Maid:Give(button.MouseButton1Click:Connect(function()
            self.SearchPanel.Visible = false
            self.SearchBox.Text = ""
            if component.Page then
                self:SetPage(component.Page)
                task.defer(function()
                    if component.Root and component.Root.Parent then
                        local pageRoot = component.Page.Root
                        local offset = component.Root.AbsolutePosition.Y - pageRoot.AbsolutePosition.Y + pageRoot.CanvasPosition.Y
                        pageRoot.CanvasPosition = Vector2.new(0, math.max(0, offset - 30))
                        local original = component.Root.BackgroundColor3
                        self.UI.Animation:Tween(component.Root, 0.09, {BackgroundColor3 = self.UI.Theme.Accent})
                        task.delay(0.12, function()
                            if component.Root and component.Root.Parent then
                                self.UI.Animation:Tween(component.Root, 0.24, {BackgroundColor3 = original})
                            end
                        end)
                    end
                end)
            end
        end))
    end
end

function Window:AddPage(config)
    local page = Page.new(self, config)
    table.insert(self.Pages, page)
    if not self.ActivePage then
        self:SetPage(page, true)
    end
    return page
end

Window.AddTab = Window.AddPage

function Window:SetPage(page, immediate)
    if self.ActivePage == page then return self end

    local theme = self.UI.Theme
    local oldPage = self.ActivePage

    if oldPage then
        oldPage.Root.Visible = false
        self.UI.Animation:Tween(oldPage.NavButton, theme.AnimFast, {
            BackgroundTransparency = 1,
        })
        self.UI.Animation:Tween(oldPage.NavIcon, theme.AnimFast, {
            ImageColor3 = theme.TextMuted,
        })
    end

    self.ActivePage = page
    page.Root.Visible = true

    page.Root.Position = UDim2.fromOffset(immediate and 0 or 9, theme.HeaderHeight)

    self.UI.Animation:Tween(page.NavButton, theme.AnimFast, {
        BackgroundTransparency = 0,
        BackgroundColor3 = theme.Surface,
    })
    self.UI.Animation:Tween(page.NavIcon, theme.AnimFast, {
        ImageColor3 = theme.Accent,
    })

    self.PageTitle.Text = page.Title
    self.PageSubtitle.Text = page.Description or self.Subtitle

    if not immediate then
        self.PageTitle.TextTransparency = 0.18
        self.PageSubtitle.TextTransparency = 0.35

        self.UI.Animation:Tween(page.Root, theme.AnimStandard, {
            Position = UDim2.fromOffset(0, theme.HeaderHeight),
        })
        self.UI.Animation:Tween(self.PageTitle, theme.AnimStandard, {TextTransparency = 0})
        self.UI.Animation:Tween(self.PageSubtitle, theme.AnimStandard, {TextTransparency = 0})
        self.UI.Audio:Play("Click", 0.78)
    else
        page.Root.Position = UDim2.fromOffset(0, theme.HeaderHeight)
        self.PageTitle.TextTransparency = 0
        self.PageSubtitle.TextTransparency = 0
    end

    return self
end



function Window:SetTitle(title)
    self.Title = tostring(title or "")
    if not self.ActivePage then
        self.PageTitle.Text = self.Title
    end
    return self
end

function Window:SetSubtitle(subtitle)
    self.Subtitle = tostring(subtitle or "")
    if not self.ActivePage or not self.ActivePage.Description then
        self.PageSubtitle.Text = self.Subtitle
    end
    return self
end

function Window:Minimize()
    if self.Minimized then
        return self:RestoreWindow()
    end

    self.Minimized = true
    self.Restore = {
        Size = self.Root.Size,
        Position = self.Root.Position,
    }

    self.MinimizedTitle.Text = self.ActivePage and self.ActivePage.Title or self.Title

    self.Sidebar.Visible = false
    self.Content.Visible = false
    self.ResizeGrip.Visible = false
    self.DragZone.Visible = false
    self.MinimizedBar.Visible = true

    self.Root.ClipsDescendants = true

    self.UI.Animation:Tween(self.Root, self.UI.Theme.AnimWindow, {
        Size = UDim2.fromOffset(290, 48),
    })

    self.UI.Audio:Play("Close", 0.76)
    return self
end

function Window:RestoreWindow()
    if not self.Minimized then return self end
    self.Minimized = false

    local restore = self.Restore or {
        Size = UDim2.fromOffset(self.UI.Theme.WindowWidth, self.UI.Theme.WindowHeight),
        Position = UDim2.fromScale(0.5, 0.5),
    }

    self.UI.Animation:Tween(self.Root, self.UI.Theme.AnimWindow, {
        Size = restore.Size,
        Position = restore.Position,
    })

    task.delay(self.UI.Theme.AnimWindow * 0.75, function()
        if self.Root and self.Root.Parent and not self.Minimized then
            self.MinimizedBar.Visible = false
            self.Sidebar.Visible = true
            self.Content.Visible = true
            self.DragZone.Visible = true
            self.ResizeGrip.Visible = not self.Maximized
        end
    end)

    self.UI.Audio:Play("Open", 0.76)
    return self
end

function Window:ToggleMaximize()
    if self.Minimized then
        self:RestoreWindow()
    end

    if not self.Maximized then
        self.Restore = {
            Size = self.Root.Size,
            Position = self.Root.Position,
        }

        self.Maximized = true
        self.ResizeGrip.Visible = false

        self.UI.Animation:Tween(self.Root, self.UI.Theme.AnimWindow, {
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.new(1, -28, 1, -28),
        })
    else
        self.Maximized = false
        self.ResizeGrip.Visible = true

        self.UI.Animation:Tween(self.Root, self.UI.Theme.AnimWindow, {
            Position = self.Restore.Position,
            Size = self.Restore.Size,
        })
    end

    return self
end


function Window:Hide()
    if self.Hidden or not self.Root.Visible then return self end

    self.Hidden = true
    self.UI.Overlay:Close()
    self.UI.Audio:Play("Close", 0.74)

    self.UI.Animation:Tween(
        self.RootScale,
        self.UI.Theme.AnimWindow,
        {Scale = 0.972},
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.In
    )

    task.delay(self.UI.Theme.AnimWindow * 0.82, function()
        if self.Root and self.Root.Parent and self.Hidden then
            self.Root.Visible = false
        end
    end)

    return self
end

function Window:Show()
    if not self.Root or not self.Root.Parent then return self end

    self.Hidden = false
    self.Root.Visible = true
    self.RootScale.Scale = 0.972
    self.UI.WindowManager:Focus(self)

    self.UI.Animation:Tween(
        self.RootScale,
        self.UI.Theme.AnimWindow,
        {Scale = 1},
        Enum.EasingStyle.Quint,
        Enum.EasingDirection.Out
    )

    self.UI.Audio:Play("Open", 0.74)
    return self
end

function Window:Toggle()
    if self.Hidden or not self.Root.Visible then
        return self:Show()
    end
    return self:Hide()
end


function Window:Center()

function Window:Center()
    self.Root.Position = UDim2.fromScale(0.5,0.5)
    return self
end

function Window:Close()
    if self.Config.CloseBehavior == "Destroy" then
        self:Destroy()
    else
        self:Hide()
    end
    safeCall(self.Config.CloseCallback, self)
    return self
end

function Window:Destroy()
    self.UI.Overlay:Close()

    for _, page in ipairs(self.Pages) do
        page:Destroy()
    end

    self.Maid:Cleanup()

    for i, window in ipairs(self.UI.Windows) do
        if window == self then
            table.remove(self.UI.Windows, i)
            break
        end
    end
end

--// Window manager
local WindowManager = {}
WindowManager.__index = WindowManager

function WindowManager.new(ui)
    return setmetatable({
        UI = ui,
        Counter = 5,
    }, WindowManager)
end

function WindowManager:Focus(window)
    self.Counter += 1
    if self.Counter > 5000 then
        self.Counter = 10
        for i, w in ipairs(self.UI.Windows) do
            if w.Root then w.Root.ZIndex = i * 2 end
        end
    end
    if window and window.Root then
        window.Root.ZIndex = self.Counter
    end
end

--// UI instance
local UIInstance = {}
UIInstance.__index = UIInstance

local function resolveGuiParent()
    local parent = nil

    local ok, result = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
    end)
    if ok and result then
        parent = result
    end

    if not parent and LocalPlayer then
        parent = LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end

    if not parent then
        parent = game:GetService("CoreGui")
    end

    return parent
end

function LunkaraUI.new(config)
    config = config or {}
    local self = setmetatable({}, UIInstance)
    self.Config = config
    self.Theme = merge(DEFAULT_THEME, config.Theme)
    self.Maid = Maid.new()
    self.Windows = {}
    self.Flags = {}
    self.FlagControls = {}
    self.SearchIndex = {}
    self.SearchByComponent = setmetatable({}, {__mode = "k"})
    self.Destroyed = false

    local screen = make("ScreenGui", {
        Name = config.Name or "LunkaraUI",
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = tonumber(config.DisplayOrder) or 70,
    })

    local protected = false
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(screen)
            protected = true
        end
    end)

    screen.Parent = config.Parent or resolveGuiParent()
    self.ScreenGui = screen
    self.Maid:Give(screen)

    self.Animation = AnimationManager.new(self)
    self.Audio = AudioManager.new(self, config.Sounds)
    self.Input = InputManager.new(self)
    self.WindowManager = WindowManager.new(self)
    self.Overlay = OverlayManager.new(self)

    self.Maid:Give(self.Audio)
    self.Maid:Give(self.Input)
    self.Maid:Give(self.Overlay)

    -- Warm the supplied visual/audio assets in the background to reduce first-use pop-in.
    task.spawn(function()
        local preload = {}
        for _, asset in pairs(LunkaraUI.Assets) do
            table.insert(preload, asset)
        end
        for _, asset in pairs(LunkaraUI.SFX) do
            table.insert(preload, asset)
        end
        pcall(function()
            ContentProvider:PreloadAsync(preload)
        end)
    end)

    return self
end

function UIInstance:CreateWindow(config)
    local window = Window.new(self, config)
    table.insert(self.Windows, window)
    self.WindowManager:Focus(window)
    return window
end

function UIInstance:_registerFlag(component)
    local flag = component.Flag
    if not flag or flag == "" then return end

    if self.FlagControls[flag] and self.FlagControls[flag] ~= component then
        warn(string.format("[LunkaraUI] Duplicate flag '%s'. The latest component now owns it.", tostring(flag)))
    end

    self.FlagControls[flag] = component
end

function UIInstance:_unregisterFlag(component)
    if component.Flag and self.FlagControls[component.Flag] == component then
        self.FlagControls[component.Flag] = nil
        self.Flags[component.Flag] = nil
    end
end

function UIInstance:_syncFlag(component, value)
    if component.Flag and component.Flag ~= "" then
        self.Flags[component.Flag] = value
    end
end

function UIInstance:GetFlag(flag)
    return self.Flags[flag]
end

function UIInstance:SetFlag(flag, value)
    local component = self.FlagControls[flag]
    if not component then
        return false, "Unknown flag"
    end
    if type(component.Set) ~= "function" then
        return false, "Component is not settable"
    end
    component:Set(value)
    return true
end

function UIInstance:_registerSearch(component)
    local entry = {
        Component = component,
    }
    self.SearchByComponent[component] = entry
    table.insert(self.SearchIndex, entry)
    self:_refreshSearch(component)
end

function UIInstance:_refreshSearch(component)
    local entry = self.SearchByComponent[component]
    if not entry then return end

    local words = {
        component.Title or "",
        component.Description or "",
        component.Type or "",
        component.Page and component.Page.Title or "",
        component.Section and component.Section.Config and component.Section.Config.Title or "",
    }

    for _, keyword in ipairs(component.SearchKeywords or {}) do
        table.insert(words, tostring(keyword))
    end

    entry.Haystack = string.lower(table.concat(words, " "))
end

function UIInstance:_unregisterSearch(component)
    local entry = self.SearchByComponent[component]
    if not entry then return end
    self.SearchByComponent[component] = nil
    for i = #self.SearchIndex, 1, -1 do
        if self.SearchIndex[i] == entry then
            table.remove(self.SearchIndex, i)
            break
        end
    end
end

function UIInstance:_search(query, window)
    local out = {}
    query = string.lower(query or "")

    for _, entry in ipairs(self.SearchIndex) do
        local component = entry.Component
        if not component.Destroyed
            and component.Visible
            and component.Window == window
            and entry.Haystack
            and string.find(entry.Haystack, query, 1, true)
        then
            local score = 10
            local title = string.lower(component.Title or "")
            if title == query then
                score = 100
            elseif string.sub(title, 1, #query) == query then
                score = 70
            elseif string.find(title, query, 1, true) then
                score = 45
            end
            table.insert(out, {Component = component, Score = score})
        end
    end

    table.sort(out, function(a,b) return a.Score > b.Score end)
    return out
end

--// Config serialization
local function encodeValue(value)
    if typeof(value) == "Color3" then
        return {
            __type = "Color3",
            R = math.floor(value.R*255+.5),
            G = math.floor(value.G*255+.5),
            B = math.floor(value.B*255+.5),
        }
    elseif typeof(value) == "EnumItem" then
        return {
            __type = "Enum",
            Enum = tostring(value.EnumType),
            Name = value.Name,
        }
    elseif type(value) == "table" then
        local out = {}
        for k,v in pairs(value) do out[k] = encodeValue(v) end
        return out
    end
    return value
end

local function decodeValue(value)
    if type(value) ~= "table" then return value end
    if value.__type == "Color3" then
        return Color3.fromRGB(value.R or 255, value.G or 255, value.B or 255)
    end
    if value.__type == "Enum" then
        local enumName = tostring(value.Enum or ""):gsub("^Enum%.","")
        local enumType = Enum[enumName]
        if enumType then return enumType[value.Name] end
        return value.Name
    end
    local out = {}
    for k,v in pairs(value) do out[k] = decodeValue(v) end
    return out
end

function UIInstance:ExportConfig()
    local data = {
        Schema = 1,
        Library = LunkaraUI.Version,
        Values = {},
    }

    for flag, component in pairs(self.FlagControls) do
        if not component.Destroyed and type(component.Get) == "function" and component.Config.IgnoreConfig ~= true then
            data.Values[flag] = {
                Type = component.Type,
                Value = encodeValue(component:Get()),
            }
        end
    end

    local ok, json = pcall(function()
        return HttpService:JSONEncode(data)
    end)
    if not ok then
        return nil, json
    end
    return json
end

function UIInstance:ImportConfig(json)
    local ok, data = pcall(function()
        if type(json) == "table" then return json end
        return HttpService:JSONDecode(json)
    end)
    if not ok then
        return false, data
    end

    if type(data) ~= "table" or type(data.Values) ~= "table" then
        return false, "Invalid config format"
    end

    for flag, payload in pairs(data.Values) do
        local component = self.FlagControls[flag]
        if component and not component.Destroyed then
            local value = decodeValue(payload.Value)
            if type(component._setFromConfig) == "function" then
                pcall(function() component:_setFromConfig(value) end)
            elseif type(component.Set) == "function" then
                pcall(function() component:Set(value) end)
            end
        end
    end

    return true
end

function UIInstance:SaveConfig(name, folder)
    if type(writefile) ~= "function" then
        return false, "writefile is unavailable in this environment"
    end

    folder = folder or "LunkaraUI"
    name = tostring(name or "default")

    if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(folder) then
        pcall(makefolder, folder)
    end

    local json, err = self:ExportConfig()
    if not json then return false, err end

    local path = folder .. "/" .. name .. ".json"
    local ok, writeErr = pcall(writefile, path, json)
    if not ok then return false, writeErr end
    return true, path
end

function UIInstance:LoadConfig(name, folder)
    if type(readfile) ~= "function" or type(isfile) ~= "function" then
        return false, "readfile/isfile is unavailable in this environment"
    end

    folder = folder or "LunkaraUI"
    name = tostring(name or "default")
    local path = folder .. "/" .. name .. ".json"

    if not isfile(path) then return false, "Config file not found" end

    local ok, data = pcall(readfile, path)
    if not ok then return false, data end
    return self:ImportConfig(data)
end

--// Notifications
function UIInstance:Notify(config)
    if type(config) == "string" then
        config = {Title = config}
    end

    config = config or {}
    local theme = self.Theme

    if not self.NotificationHolder then
        self.NotificationHolder = make("Frame", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 1),
            Position = UDim2.new(1, -18, 1, -18),
            Size = UDim2.fromOffset(theme.NotificationWidth, 560),
            ZIndex = 20000,
            Parent = self.ScreenGui,
        })

        local layout = list(
            self.NotificationHolder,
            Enum.FillDirection.Vertical,
            theme.NotificationGap
        )
        layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

        self.Notifications = {}
    end

    local kind = string.lower(tostring(config.Type or "Notification"))
    local typeMap = {
        notification = {
            Icon = "Notification",
            Accent = theme.Accent,
            Sound = "Notification",
        },
        info = {
            Icon = "Info",
            Accent = theme.Accent,
            Sound = "Notification",
        },
        success = {
            Icon = "Success",
            Accent = theme.Success,
            Sound = "Success",
        },
        warning = {
            Icon = "Warning",
            Accent = theme.Warning,
            Sound = "Notification",
        },
        error = {
            Icon = "Warning",
            Accent = theme.Danger,
            Sound = "Error",
        },
    }

    local style = typeMap[kind] or typeMap.notification
    local titleText = tostring(config.Title or "Notification")
    local bodyText = config.Description or config.Content
    bodyText = bodyText and tostring(bodyText) or nil

    local bodyHeight = 0
    if bodyText and bodyText ~= "" then
        local bounds = TextService:GetTextSize(
            bodyText,
            12,
            Enum.Font.GothamMedium,
            Vector2.new(theme.NotificationWidth - 86, 1000)
        )
        bodyHeight = math.max(17, bounds.Y)
    end

    local cardHeight = bodyText and math.max(70, 35 + bodyHeight + 15) or 60
    local slot = make("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, cardHeight),
        ZIndex = 20001,
        Parent = self.NotificationHolder,
    })

    local card = make("Frame", {
        BackgroundColor3 = theme.Popup,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(28, 0),
        Size = UDim2.fromScale(1, 1),
        ZIndex = 20002,
        Parent = slot,
    })
    corner(card, theme.RadiusPanel)

    local cardScale = make("UIScale", {
        Scale = 0.985,
        Parent = card,
    })

    local iconBox = make("Frame", {
        BackgroundColor3 = style.Accent,
        BackgroundTransparency = 0.82,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(13, 13),
        Size = UDim2.fromOffset(36, 36),
        ZIndex = 20003,
        Parent = card,
    })
    corner(iconBox, 8)

    createIcon(
        iconBox,
        style.Icon,
        20,
        style.Accent,
        UDim2.fromScale(0.5, 0.5),
        Vector2.new(0.5, 0.5),
        20004,
        1
    )

    local title = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = titleText,
        Font = Enum.Font.GothamSemibold,
        TextSize = 13,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(61, bodyText and 10 or 0),
        Size = UDim2.new(1, -74, 0, bodyText and 21 or cardHeight),
        ZIndex = 20003,
        Parent = card,
    })

    local body = nil
    if bodyText and bodyText ~= "" then
        body = make("TextLabel", {
            BackgroundTransparency = 1,
            Text = bodyText,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = theme.TextSecondary,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            TextWrapped = true,
            Position = UDim2.fromOffset(61, 33),
            Size = UDim2.new(1, -74, 0, bodyHeight),
            ZIndex = 20003,
            Parent = card,
        })
    end

    local hit = make("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 20005,
        Parent = card,
    })

    local dismissed = false
    local hovering = false
    local handle = {}

    local function removeFromRegistry()
        if not self.Notifications then return end
        for i = #self.Notifications, 1, -1 do
            if self.Notifications[i] == handle then
                table.remove(self.Notifications, i)
                break
            end
        end
    end

    local function dismiss()
        if dismissed then return end
        dismissed = true
        removeFromRegistry()

        self.Animation:Tween(cardScale, 0.13, {Scale = 0.975}, Enum.EasingStyle.Quad)
        self.Animation:Tween(card, theme.AnimEmphasized, {
            Position = UDim2.fromOffset(34, 0),
            BackgroundTransparency = 0.18,
        })

        task.delay(theme.AnimEmphasized * 0.72, function()
            if slot and slot.Parent then
                self.Animation:Tween(slot, 0.14, {Size = UDim2.new(1, 0, 0, 0)})
                task.delay(0.15, function()
                    if slot then
                        slot:Destroy()
                    end
                end)
            end
        end)
    end

    handle.Dismiss = dismiss
    handle.Root = card
    table.insert(self.Notifications, handle)

    while #self.Notifications > theme.NotificationMax do
        local oldest = self.Notifications[1]
        if oldest and oldest.Dismiss then
            oldest.Dismiss()
        else
            table.remove(self.Notifications, 1)
        end
    end

    hit.MouseEnter:Connect(function()
        hovering = true
        self.Animation:Tween(card, theme.AnimFast, {BackgroundColor3 = theme.SurfaceRaised})
    end)

    hit.MouseLeave:Connect(function()
        hovering = false
        self.Animation:Tween(card, theme.AnimFast, {BackgroundColor3 = theme.Popup})
    end)

    hit.MouseButton1Click:Connect(function()
        self.Audio:Play("Click", 0.72)
        if config.Action then
            safeCall(config.Action)
        else
            dismiss()
        end
    end)

    self.Animation:Tween(card, theme.AnimEmphasized, {Position = UDim2.fromOffset(0, 0)})
    self.Animation:Tween(cardScale, theme.AnimEmphasized, {Scale = 1})
    self.Audio:Play(style.Sound)

    local duration = tonumber(config.Duration) or 4
    task.spawn(function()
        local elapsed = 0
        while not dismissed and slot.Parent and elapsed < duration do
            task.wait(0.08)
            if not hovering then
                elapsed += 0.08
            end
        end
        dismiss()
    end)

    return handle
end


--// Dialog / confirmation

--// Dialog / confirmation
function UIInstance:Dialog(config)
    config = config or {}
    self.Overlay:Close()

    local theme = self.Theme
    local shade = make("TextButton", {
        BackgroundColor3 = Color3.new(0,0,0),
        BackgroundTransparency = 0.35,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1,1),
        ZIndex = 30000,
        Parent = self.ScreenGui,
    })

    local modal = make("Frame", {
        BackgroundColor3 = theme.Popup,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5,0.5),
        Position = UDim2.fromScale(0.5,0.5),
        Size = UDim2.fromOffset(390, 190),
        ZIndex = 30001,
        Parent = shade,
    })
    corner(modal, theme.RadiusWindow)
    padding(modal, 18,18,16,16)

    local title = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = config.Title or "Confirm",
        Font = Enum.Font.GothamMedium,
        TextSize = 15,
        TextColor3 = theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1,0,0,24),
        ZIndex = 30002,
        Parent = modal,
    })

    local body = make("TextLabel", {
        BackgroundTransparency = 1,
        Text = config.Description or config.Content or "",
        Font = Enum.Font.Gotham,
        TextSize = 12,
        TextColor3 = theme.TextSecondary,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.fromOffset(0,34),
        Size = UDim2.new(1,0,1,-86),
        ZIndex = 30002,
        Parent = modal,
    })

    local buttons = make("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1,1),
        Position = UDim2.fromScale(1,1),
        Size = UDim2.fromOffset(250,36),
        ZIndex = 30002,
        Parent = modal,
    })
    local layout = list(buttons, Enum.FillDirection.Horizontal, 8)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local function mkButton(text, primary)
        local btn = make("TextButton", {
            BackgroundColor3 = primary and theme.Accent or theme.SurfaceRaised,
            BorderSizePixel = 0,
            Text = text,
            Font = Enum.Font.GothamMedium,
            TextSize = 12,
            TextColor3 = theme.Text,
            AutoButtonColor = false,
            Size = UDim2.fromOffset(112,34),
            ZIndex = 30003,
            Parent = buttons,
        })
        corner(btn, theme.RadiusSmall)
        return btn
    end

    local cancel = mkButton(config.CancelText or "Cancel", false)
    local confirm = mkButton(config.ConfirmText or "Confirm", true)

    local closed = false
    local function close(result)
        if closed then return end
        closed = true
        shade:Destroy()
        if result then
            safeCall(config.Callback, true)
        else
            safeCall(config.CancelCallback, false)
        end
    end

    cancel.MouseButton1Click:Connect(function() close(false) end)
    confirm.MouseButton1Click:Connect(function() close(true) end)

    self.Audio:Play("Open")
    return {
        Close = close,
        Root = shade,
    }
end

UIInstance.Confirm = UIInstance.Dialog

function UIInstance:SetTheme(values)
    -- V1 intentionally keeps public theming constrained.
    -- Runtime accent updates are supported; full live token rebinding is reserved for later builds.
    if type(values) == "table" then
        if values.Accent then
            self.Theme.Accent = values.Accent
        end
    end
    return self
end

function UIInstance:SetSoundsEnabled(enabled)
    self.Audio:SetEnabled(enabled)
    return self
end

function UIInstance:SetSoundVolume(volume)
    self.Audio:SetVolume(volume)
    return self
end

function UIInstance:SetAnimationsEnabled(enabled)
    self.Animation:SetEnabled(enabled)
    return self
end

function UIInstance:SetAnimationSpeed(multiplier)
    self.Animation:SetSpeed(multiplier)
    return self
end

function UIInstance:Destroy()
    if self.Destroyed then return end
    self.Destroyed = true

    self.Overlay:Close()

    for i = #self.Windows, 1, -1 do
        pcall(function() self.Windows[i]:Destroy() end)
    end

    self.Maid:Cleanup()
    table.clear(self.Flags)
    table.clear(self.FlagControls)
    table.clear(self.SearchIndex)
end

-- legacy-friendly alias
LunkaraUI.Create = LunkaraUI.new

return LunkaraUI
