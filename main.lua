--!strict
--[[
    LunkaraUI - Liquid Glass Edition
    Fresh implementation. No legacy V1/V2/V3 code.
    Design goals: premium utility density, liquid-glass depth, restrained motion,
    real icon navigation, no card-stack dashboard look, no decorative filler copy.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Lighting = game:GetService("Lighting")
local ContentProvider = game:GetService("ContentProvider")

local LocalPlayer = Players.LocalPlayer

local LunkaraUI = {
    Version = "5.0.0-liquid",
    Flags = {},
}

LunkaraUI.DefaultIcons = {
    Home = 81867978804443,
    Components = 126570555803946,
    Palette = 122671609869735,
    Search = 86567920400897,
    Settings = 86564139855583,
}

LunkaraUI.DefaultSounds = {
    Enabled = true,
    Hover = 139800881181209,
    Click = 102702078778790,
    Toggle = 102702078778790,
    Open = 130359997277952,
    Close = 130359997277952,
    Volume = 0.28,
}

LunkaraUI.Themes = {
    Liquid = {
        Name = "Liquid",

        Backdrop = Color3.fromRGB(9, 11, 12),
        Glass = Color3.fromRGB(18, 21, 22),
        GlassAlt = Color3.fromRGB(21, 24, 25),
        GlassHover = Color3.fromRGB(31, 35, 36),
        GlassPressed = Color3.fromRGB(38, 42, 43),
        Sidebar = Color3.fromRGB(12, 14, 15),
        Search = Color3.fromRGB(24, 27, 28),
        Field = Color3.fromRGB(28, 31, 32),
        FieldHover = Color3.fromRGB(35, 39, 40),
        Divider = Color3.fromRGB(255, 255, 255),

        Accent = Color3.fromRGB(143, 218, 190),
        AccentSoft = Color3.fromRGB(65, 102, 89),
        AccentText = Color3.fromRGB(8, 17, 14),

        Text = Color3.fromRGB(244, 246, 245),
        TextSecondary = Color3.fromRGB(177, 184, 182),
        TextMuted = Color3.fromRGB(117, 125, 123),
        TextDisabled = Color3.fromRGB(74, 80, 79),

        Success = Color3.fromRGB(110, 206, 149),
        Warning = Color3.fromRGB(231, 188, 101),
        Danger = Color3.fromRGB(224, 112, 122),
        Info = Color3.fromRGB(137, 179, 220),

        WindowTransparency = 0.015,
        SectionTransparency = 0.035,
        FieldTransparency = 0.025,
        HoverTransparency = 0.12,

        RadiusWindow = 12,
        RadiusPanel = 8,
        RadiusControl = 5,
        RadiusSmall = 4,

        Width = 920,
        Height = 590,
        SidebarWidth = 190,
        TopbarHeight = 64,

        Font = Enum.Font.Gotham,
        FontMedium = Enum.Font.GothamMedium,
        FontBold = Enum.Font.GothamBold,
    },
}

LunkaraUI.Themes.Graphite = setmetatable({}, {__index = LunkaraUI.Themes.Liquid})
for k, v in pairs(LunkaraUI.Themes.Liquid) do
    LunkaraUI.Themes.Graphite[k] = v
end
LunkaraUI.Themes.Graphite.Name = "Graphite"
LunkaraUI.Themes.Graphite.Accent = Color3.fromRGB(214, 219, 216)
LunkaraUI.Themes.Graphite.AccentSoft = Color3.fromRGB(89, 93, 91)
LunkaraUI.Themes.Graphite.AccentText = Color3.fromRGB(16, 17, 17)

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local Control = {}
Control.__index = Control

local function cloneTable(source)
    local out = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            out[key] = cloneTable(value)
        else
            out[key] = value
        end
    end
    return out
end

local function mergeTable(base, override)
    local out = cloneTable(base)
    for key, value in pairs(override or {}) do
        if type(value) == "table" and type(out[key]) == "table" then
            out[key] = mergeTable(out[key], value)
        else
            out[key] = value
        end
    end
    return out
end

local function safeCall(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[LunkaraUI] Callback error:", err)
    end
end

local function create(className, properties)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        object[property] = value
    end
    return object
end

local function corner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent,
    })
end

local function padding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        Parent = parent,
    })
end

local function list(parent, direction, gap)
    return create("UIListLayout", {
        FillDirection = direction or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 0),
        Parent = parent,
    })
end

local function assetId(value)
    if value == nil then
        return ""
    end
    if type(value) == "number" then
        if value <= 0 then
            return ""
        end
        return "rbxassetid://" .. tostring(value)
    end
    if type(value) == "string" then
        if value == "" or value == "0" then
            return ""
        end
        if string.find(value, "rbxassetid://", 1, true) or string.find(value, "http", 1, true) then
            return value
        end
        if tonumber(value) then
            return "rbxassetid://" .. value
        end
        return value
    end
    return ""
end

local function validSoundId(value)
    if type(value) == "number" then
        return value > 0
    end
    if type(value) == "string" then
        return tonumber(value:match("%d+")) ~= nil
    end
    return false
end

local function roundTo(value, step)
    if not step or step <= 0 then
        return value
    end
    return math.floor((value / step) + 0.5) * step
end

local function formatNumber(value)
    if math.abs(value - math.floor(value)) < 0.0001 then
        return tostring(math.floor(value))
    end
    return string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

local function resolveParent(customParent)
    if customParent and typeof(customParent) == "Instance" then
        return customParent
    end
    if not LocalPlayer then
        error("LunkaraUI must run on the client")
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function disconnectAll(connections)
    for _, connection in ipairs(connections or {}) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
end

function Window:_playSound(name)
    if not self.Sounds.Enabled then
        return
    end
    local id = self.Sounds[name]
    if not validSoundId(id) then
        return
    end

    local sound = Instance.new("Sound")
    sound.SoundId = assetId(id)
    sound.Volume = self.Sounds.Volume or 0.28
    sound.Parent = self.Gui
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
    task.delay(5, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
end

function Window:_tween(object, duration, properties, style, direction)
    if not object or not object.Parent then
        return nil
    end
    local tween = TweenService:Create(
        object,
        TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quart, direction or Enum.EasingDirection.Out),
        properties
    )
    tween:Play()
    return tween
end

function Window:_bindTheme(object, property, key, explicit)
    if explicit ~= nil then
        object[property] = explicit
        return
    end
    object[property] = self.Theme[key]
    table.insert(self._themeBindings, {
        Object = object,
        Property = property,
        Key = key,
    })
end

function Window:_makeShadow(target, sizeOffset, transparency)
    local parent = target.Parent
    if not parent or not target:IsA("GuiObject") then
        return nil
    end
    local extra = sizeOffset or 30
    local shadow = create("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        AnchorPoint = target.AnchorPoint,
        Position = target.Position,
        Size = UDim2.new(target.Size.X.Scale, target.Size.X.Offset + extra, target.Size.Y.Scale, target.Size.Y.Offset + extra),
        Image = "rbxassetid://5761498316",
        ImageColor3 = Color3.new(0, 0, 0),
        ImageTransparency = transparency or 0.48,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(17, 17, 283, 283),
        ZIndex = math.max(0, target.ZIndex - 1),
        Parent = parent,
    })
    return shadow
end

function Window:_glass(parent, options)
    options = options or {}
    local frame = create("Frame", {
        Name = options.Name or "Glass",
        BackgroundColor3 = self.Theme[options.ColorKey or "GlassAlt"],
        BackgroundTransparency = options.Transparency ~= nil and options.Transparency or self.Theme.SectionTransparency,
        BorderSizePixel = 0,
        Size = options.Size or UDim2.fromScale(1, 1),
        Position = options.Position or UDim2.new(),
        AutomaticSize = options.AutomaticSize or Enum.AutomaticSize.None,
        ClipsDescendants = options.ClipsDescendants == true,
        ZIndex = options.ZIndex or parent.ZIndex,
        Parent = parent,
    })
    corner(frame, options.Radius or self.Theme.RadiusPanel)

    -- Thin top refraction band. This is the only decorative highlight on a glass surface.
    local refraction = create("Frame", {
        Name = "Refraction",
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.955,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 0),
        Size = UDim2.new(1, -20, 0, 1),
        ZIndex = frame.ZIndex + 1,
        Parent = frame,
    })

    if options.WashHeight and options.WashHeight > 0 then
        local wash = create("Frame", {
            Name = "GlassLight",
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0.982,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, options.WashHeight),
            ZIndex = frame.ZIndex,
            Parent = frame,
        })
        corner(wash, options.Radius or self.Theme.RadiusPanel)
        local gradient = create("UIGradient", {
            Rotation = 90,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.2),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Parent = wash,
        })
        gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
    end

    return frame
end

function Window:_makeIcon(parent, icon, size, colorKey, zIndex)
    local resolved = icon
    if type(icon) == "string" and self.Icons[icon] ~= nil then
        resolved = self.Icons[icon]
    end
    local image = assetId(resolved)
    if image == "" then
        return nil
    end
    local label = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = image,
        ImageColor3 = self.Theme[colorKey or "TextSecondary"],
        ScaleType = Enum.ScaleType.Fit,
        Size = UDim2.fromOffset(size, size),
        ZIndex = zIndex or parent.ZIndex,
        Parent = parent,
    })
    return label
end

function Window:_tooltip(target, text)
    if not text or text == "" then
        return
    end

    local tooltip = self:_glass(self.Overlay, {
        Name = "Tooltip",
        Size = UDim2.fromOffset(220, 34),
        Transparency = 0.04,
        Radius = self.Theme.RadiusSmall,
        ZIndex = 220,
    })
    tooltip.Visible = false
    tooltip.AutomaticSize = Enum.AutomaticSize.Y
    padding(tooltip, 10, 10, 7, 7)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.Font,
        Text = tostring(text),
        TextColor3 = self.Theme.TextSecondary,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        ZIndex = 223,
        Parent = tooltip,
    })

    local token = 0
    table.insert(self._connections, target.MouseEnter:Connect(function()
        token += 1
        local current = token
        task.delay(0.3, function()
            if token ~= current or not target.Parent then
                return
            end
            local mouse = UserInputService:GetMouseLocation()
            local camera = workspace.CurrentCamera
            local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
            local width = math.max(220, tooltip.AbsoluteSize.X)
            local height = math.max(34, tooltip.AbsoluteSize.Y)
            local x = math.clamp(mouse.X + 14, 8, math.max(8, viewport.X - width - 8))
            local y = math.clamp(mouse.Y + 12, 8, math.max(8, viewport.Y - height - 8))
            tooltip.Position = UDim2.fromOffset(x, y)
            tooltip.Visible = true
        end)
    end))
    table.insert(self._connections, target.MouseLeave:Connect(function()
        token += 1
        tooltip.Visible = false
    end))
end

function Window:_hover(button, surface, options)
    options = options or {}
    local normalTransparency = options.NormalTransparency or 1
    local hoverTransparency = options.HoverTransparency or self.Theme.HoverTransparency
    local pressedTransparency = options.PressedTransparency or 0.12
    local normalColor = options.NormalColor or self.Theme.GlassHover
    local hoverColor = options.HoverColor or self.Theme.GlassHover

    surface.BackgroundColor3 = normalColor
    surface.BackgroundTransparency = normalTransparency

    table.insert(self._connections, button.MouseEnter:Connect(function()
        if button:GetAttribute("LunkaraDisabled") then
            return
        end
        self:_playSound("Hover")
        self:_tween(surface, 0.14, {
            BackgroundTransparency = hoverTransparency,
            BackgroundColor3 = hoverColor,
        })
    end))
    table.insert(self._connections, button.MouseLeave:Connect(function()
        self:_tween(surface, 0.14, {
            BackgroundTransparency = normalTransparency,
            BackgroundColor3 = normalColor,
        })
    end))
    table.insert(self._connections, button.MouseButton1Down:Connect(function()
        if button:GetAttribute("LunkaraDisabled") then
            return
        end
        self:_tween(surface, 0.08, {BackgroundTransparency = pressedTransparency})
    end))
    table.insert(self._connections, button.MouseButton1Up:Connect(function()
        if button:GetAttribute("LunkaraDisabled") then
            return
        end
        self:_tween(surface, 0.1, {BackgroundTransparency = hoverTransparency})
    end))
end

function Window:_setFlag(flag, value, silent)
    if not flag or flag == "" then
        return
    end
    self.Flags[flag] = value
    LunkaraUI.Flags[flag] = value
    if not silent then
        local listeners = self._flagListeners[flag]
        if listeners then
            for _, callback in ipairs(listeners) do
                safeCall(callback, value)
            end
        end
    end
end

function Window:GetFlag(flag)
    return self.Flags[flag]
end

function Window:GetFlags()
    return cloneTable(self.Flags)
end

function Window:SetFlag(flag, value, silent)
    local control = self._flagControls[flag]
    if control and control.Set then
        control:Set(value, silent)
    else
        self:_setFlag(flag, value, silent)
    end
end

function Window:OnFlagChanged(flag, callback)
    self._flagListeners[flag] = self._flagListeners[flag] or {}
    table.insert(self._flagListeners[flag], callback)
    return {
        Disconnect = function()
            local items = self._flagListeners[flag]
            if not items then
                return
            end
            local index = table.find(items, callback)
            if index then
                table.remove(items, index)
            end
        end,
    }
end

function Window:EncodeFlags()
    local serializable = {}
    for key, value in pairs(self.Flags) do
        if typeof(value) == "Color3" then
            serializable[key] = {
                __type = "Color3",
                r = math.floor(value.R * 255 + 0.5),
                g = math.floor(value.G * 255 + 0.5),
                b = math.floor(value.B * 255 + 0.5),
            }
        else
            serializable[key] = value
        end
    end
    return HttpService:JSONEncode(serializable)
end

function Window:DecodeFlags(json, silent)
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(json)
    end)
    if not ok or type(decoded) ~= "table" then
        return false
    end
    for key, value in pairs(decoded) do
        if type(value) == "table" and value.__type == "Color3" then
            value = Color3.fromRGB(value.r or 255, value.g or 255, value.b or 255)
        end
        self:SetFlag(key, value, silent)
    end
    return true
end

function Window:SetTheme(theme)
    if type(theme) == "string" then
        theme = LunkaraUI.Themes[theme]
    end
    if type(theme) ~= "table" then
        return false
    end
    self.Theme = mergeTable(self.Theme, theme)

    for index = #self._themeBindings, 1, -1 do
        local binding = self._themeBindings[index]
        if not binding.Object or not binding.Object.Parent then
            table.remove(self._themeBindings, index)
        else
            local value = self.Theme[binding.Key]
            if value ~= nil then
                binding.Object[binding.Property] = value
            end
        end
    end

    for _, control in ipairs(self._controls) do
        if control.RefreshTheme then
            safeCall(control.RefreshTheme, control)
        end
    end
    if self._activeTab then
        self:_selectTab(self._activeTab, true)
    end
    return true
end

function Control:SetVisible(value)
    self.Visible = value == true
    if self.Root then
        self.Root.Visible = self.Visible
    end
    return self
end

function Control:SetDisabled(value)
    self.Disabled = value == true
    if self.Button then
        self.Button:SetAttribute("LunkaraDisabled", self.Disabled)
        self.Button.Selectable = not self.Disabled
    end
    if self.Root then
        self.Root.GroupTransparency = self.Disabled and 0.48 or 0
    end
    return self
end

function Control:Destroy()
    disconnectAll(self._connections)
    if self.Root then
        self.Root:Destroy()
    end
end

function Window:_registerControl(control)
    table.insert(self._controls, control)
    if control.Flag then
        self._flagControls[control.Flag] = control
    end
    return control
end

function Window:_newControl(section, options, height)
    options = options or {}
    local root = create("CanvasGroup", {
        Name = options.Name or "Control",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or 42),
        GroupTransparency = 0,
        Parent = section.Body,
    })

    local hover = create("Frame", {
        Name = "Hover",
        BackgroundColor3 = self.Theme.GlassHover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = root.ZIndex,
        Parent = root,
    })
    corner(hover, self.Theme.RadiusControl)

    local button = create("TextButton", {
        Name = "Hit",
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Selectable = true,
        ZIndex = root.ZIndex + 8,
        Parent = root,
    })

    local control = setmetatable({
        Window = self,
        Section = section,
        Root = root,
        Hover = hover,
        Button = button,
        Flag = options.Flag,
        Disabled = options.Disabled == true,
        Visible = options.Visible ~= false,
        _connections = {},
    }, Control)

    root.Visible = control.Visible
    button:SetAttribute("LunkaraDisabled", control.Disabled)
    self:_hover(button, hover)
    if options.Description then
        self:_tooltip(button, options.Description)
    end
    self:_registerControl(control)
    table.insert(section.Controls, control)
    return control
end

function Window:_controlTitle(control, options, rightSpace, y)
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontMedium,
        Text = options.Title or options.Text or "Control",
        TextColor3 = options.TextColor or self.Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(12, y or 0),
        Size = UDim2.new(1, -(rightSpace or 80) - 12, 1, -(y or 0)),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    control.TitleLabel = title
    return title
end

function Section:AddButton(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 88)

    local action = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = self.Window.Theme.FieldTransparency,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(options.ButtonWidth or 70, 26),
        ZIndex = control.Root.ZIndex + 2,
        Parent = control.Root,
    })
    corner(action, self.Window.Theme.RadiusSmall)

    local actionText = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = options.ButtonText or "Run",
        TextColor3 = self.Window.Theme.TextSecondary,
        TextSize = 12,
        Size = UDim2.fromScale(1, 1),
        ZIndex = action.ZIndex + 1,
        Parent = action,
    })

    control.Button.Activated:Connect(function()
        if control.Disabled then
            return
        end
        self.Window:_playSound("Click")
        self.Window:_tween(action, 0.08, {BackgroundTransparency = 0.02})
        task.delay(0.1, function()
            if action.Parent then
                self.Window:_tween(action, 0.13, {BackgroundTransparency = self.Window.Theme.FieldTransparency})
            end
        end)
        safeCall(options.Callback)
    end)

    function control:Fire()
        if not self.Disabled then
            safeCall(options.Callback)
        end
    end

    return control
end

function Section:AddToggle(options)
    options = options or {}
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 68)

    local track = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = 0.08,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(34, 18),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    corner(track, 9)

    local knob = create("Frame", {
        BackgroundColor3 = self.Window.Theme.TextMuted,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(14, 14),
        ZIndex = track.ZIndex + 1,
        Parent = track,
    })
    corner(knob, 7)

    control.Value = options.Default == true

    function control:Set(value, silent)
        self.Value = value == true
        local x = self.Value and UDim2.new(1, -16, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        self.Window:_tween(knob, 0.19, {
            Position = x,
            BackgroundColor3 = self.Value and self.Window.Theme.Text or self.Window.Theme.TextMuted,
        }, Enum.EasingStyle.Quart)
        self.Window:_tween(track, 0.19, {
            BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.Field,
            BackgroundTransparency = self.Value and 0 or 0.08,
        }, Enum.EasingStyle.Quart)
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCall(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    function control:RefreshTheme()
        track.BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.Field
        knob.BackgroundColor3 = self.Value and self.Window.Theme.Text or self.Window.Theme.TextMuted
    end

    control.Button.Activated:Connect(function()
        if control.Disabled then
            return
        end
        self.Window:_playSound("Toggle")
        control:Set(not control.Value)
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddCheckbox(options)
    options = options or {}
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 54)

    local box = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    corner(box, 5)

    local mark = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontBold,
        Text = "✓",
        TextColor3 = self.Window.Theme.AccentText,
        TextSize = 12,
        TextTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = box.ZIndex + 1,
        Parent = box,
    })

    control.Value = options.Default == true

    function control:Set(value, silent)
        self.Value = value == true
        self.Window:_tween(box, 0.15, {
            BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.Field,
            BackgroundTransparency = self.Value and 0 or 0.06,
        })
        self.Window:_tween(mark, 0.12, {TextTransparency = self.Value and 0 or 1})
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCall(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    function control:RefreshTheme()
        box.BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.Field
        mark.TextColor3 = self.Window.Theme.AccentText
    end

    control.Button.Activated:Connect(function()
        if control.Disabled then
            return
        end
        self.Window:_playSound("Toggle")
        control:Set(not control.Value)
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddSlider(options)
    options = options or {}
    local minimum = tonumber(options.Min) or 0
    local maximum = tonumber(options.Max) or 100
    if maximum <= minimum then
        maximum = minimum + 1
    end
    local step = tonumber(options.Step) or 1
    local default = math.clamp(tonumber(options.Default) or minimum, minimum, maximum)

    local control = self.Window:_newControl(self, options, 52)
    local title = self.Window:_controlTitle(control, options, 76, -6)
    title.Size = UDim2.new(1, -88, 0, 28)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = "",
        TextColor3 = self.Window.Theme.TextSecondary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 6),
        Size = UDim2.fromOffset(60, 20),
        ZIndex = control.Root.ZIndex + 4,
        Parent = control.Root,
    })

    local bar = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = 0.05,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 1, -13),
        Size = UDim2.new(1, -24, 0, 4),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    corner(bar, 2)

    local fill = create("Frame", {
        BackgroundColor3 = options.AccentColor or self.Window.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = bar.ZIndex + 1,
        Parent = bar,
    })
    corner(fill, 2)

    local knob = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Text,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(10, 10),
        ZIndex = fill.ZIndex + 2,
        Parent = bar,
    })
    corner(knob, 5)

    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 10, 0, 26),
        ZIndex = knob.ZIndex + 2,
        Selectable = true,
        Parent = bar,
    })

    local dragging = false
    control.Value = default

    local function setFromX(x)
        local scale = math.clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        local value = minimum + ((maximum - minimum) * scale)
        control:Set(value)
    end

    function control:Set(value, silent)
        value = math.clamp(roundTo(tonumber(value) or minimum, step), minimum, maximum)
        self.Value = value
        local scale = (value - minimum) / (maximum - minimum)
        self.Window:_tween(fill, 0.08, {Size = UDim2.new(scale, 0, 1, 0)}, Enum.EasingStyle.Linear)
        self.Window:_tween(knob, 0.08, {Position = UDim2.new(scale, 0, 0.5, 0)}, Enum.EasingStyle.Linear)
        valueLabel.Text = (options.Prefix or "") .. formatNumber(value) .. (options.Suffix or "")
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCall(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    function control:RefreshTheme()
        if not options.AccentColor then
            fill.BackgroundColor3 = self.Window.Theme.Accent
        end
        bar.BackgroundColor3 = self.Window.Theme.Field
        knob.BackgroundColor3 = self.Window.Theme.Text
        valueLabel.TextColor3 = self.Window.Theme.TextSecondary
    end

    hit.InputBegan:Connect(function(input)
        if control.Disabled then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            self.Window:_playSound("Click")
            setFromX(input.Position.X)
        end
    end)

    hit.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    table.insert(control._connections, UserInputService.InputChanged:Connect(function(input)
        if not dragging then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            setFromX(input.Position.X)
        end
    end))

    control:Set(default, true)
    return control
end

function Window:_popup(width, height)
    local popup = self:_glass(self.Overlay, {
        Size = UDim2.fromOffset(width, height),
        Transparency = 0.03,
        Radius = self.Theme.RadiusPanel,
        ZIndex = 160,
        ClipsDescendants = true,
    })
    popup.Visible = false
    self:_makeShadow(popup, 26, 0.58)
    return popup
end

function Section:AddDropdown(options)
    options = options or {}
    local values = cloneTable(options.Values or options.Options or {})
    local multi = options.Multi == true
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 182)

    local field = create("TextButton", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = self.Window.Theme.FieldTransparency,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(options.Width or 154, 28),
        ZIndex = control.Root.ZIndex + 4,
        Selectable = true,
        Parent = control.Root,
    })
    corner(field, self.Window.Theme.RadiusSmall)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.Font,
        Text = "",
        TextColor3 = self.Window.Theme.TextSecondary,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -28, 1, 0),
        ZIndex = field.ZIndex + 1,
        Parent = field,
    })

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = "⌄",
        TextColor3 = self.Window.Theme.TextMuted,
        TextSize = 13,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -7, 0.5, -1),
        Size = UDim2.fromOffset(16, 16),
        ZIndex = field.ZIndex + 1,
        Parent = field,
    })

    local popupHeight = math.min(236, math.max(44, (#values * 30) + (options.Searchable == false and 12 or 48)))
    local popup = self.Window:_popup(options.Width or 154, popupHeight)
    local listTop = 6
    local searchBox

    if options.Searchable ~= false then
        searchBox = create("TextBox", {
            BackgroundColor3 = self.Window.Theme.Field,
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = self.Window.Theme.Font,
            PlaceholderText = "Search",
            PlaceholderColor3 = self.Window.Theme.TextMuted,
            Text = "",
            TextColor3 = self.Window.Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(6, 6),
            Size = UDim2.new(1, -12, 0, 30),
            ZIndex = 164,
            Parent = popup,
        })
        corner(searchBox, self.Window.Theme.RadiusSmall)
        padding(searchBox, 9, 9, 0, 0)
        listTop = 42
    end

    local scroll = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(4, listTop),
        Size = UDim2.new(1, -8, 1, -listTop - 4),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.Window.Theme.TextMuted,
        ZIndex = 163,
        Parent = popup,
    })
    list(scroll, Enum.FillDirection.Vertical, 2)

    control.Value = multi and cloneTable(options.Default or {}) or (options.Default or values[1])
    local optionButtons = {}

    local function displayValue()
        if multi then
            local text = table.concat(control.Value, ", ")
            valueLabel.Text = text ~= "" and text or "None"
        else
            valueLabel.Text = tostring(control.Value or "None")
        end
    end

    function control:Set(value, silent)
        if multi then
            self.Value = type(value) == "table" and cloneTable(value) or {}
        else
            self.Value = value
        end
        displayValue()
        for option, data in pairs(optionButtons) do
            local selected = multi and table.find(self.Value, option) ~= nil or self.Value == option
            data.Text.TextColor3 = selected and self.Window.Theme.Text or self.Window.Theme.TextSecondary
            data.Dot.BackgroundColor3 = selected and self.Window.Theme.Accent or self.Window.Theme.TextMuted
            data.Dot.BackgroundTransparency = selected and 0 or 0.72
        end
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCall(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    local function rebuild(filter)
        for _, child in ipairs(scroll:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        optionButtons = {}
        local query = string.lower(filter or "")
        for _, option in ipairs(values) do
            local optionString = tostring(option)
            if query == "" or string.find(string.lower(optionString), query, 1, true) then
                local button = create("TextButton", {
                    BackgroundColor3 = self.Window.Theme.GlassHover,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = "",
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 28),
                    ZIndex = 164,
                    Parent = scroll,
                })
                corner(button, self.Window.Theme.RadiusSmall)

                local text = create("TextLabel", {
                    BackgroundTransparency = 1,
                    Font = self.Window.Theme.Font,
                    Text = optionString,
                    TextColor3 = self.Window.Theme.TextSecondary,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    Position = UDim2.fromOffset(9, 0),
                    Size = UDim2.new(1, -28, 1, 0),
                    ZIndex = 165,
                    Parent = button,
                })
                local dot = create("Frame", {
                    BackgroundColor3 = self.Window.Theme.TextMuted,
                    BackgroundTransparency = 0.72,
                    BorderSizePixel = 0,
                    AnchorPoint = Vector2.new(1, 0.5),
                    Position = UDim2.new(1, -9, 0.5, 0),
                    Size = UDim2.fromOffset(6, 6),
                    ZIndex = 165,
                    Parent = button,
                })
                corner(dot, 3)
                optionButtons[option] = {Button = button, Text = text, Dot = dot}
                self.Window:_hover(button, button, {NormalTransparency = 1, HoverTransparency = 0.58})

                button.Activated:Connect(function()
                    if multi then
                        local copy = cloneTable(control.Value)
                        local index = table.find(copy, option)
                        if index then
                            table.remove(copy, index)
                        else
                            table.insert(copy, option)
                        end
                        control:Set(copy)
                    else
                        control:Set(option)
                        popup.Visible = false
                        self.Window._openPopup = nil
                    end
                end)
            end
        end
        control:Set(control.Value, true)
    end

    local function placePopup()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local x = field.AbsolutePosition.X
        local y = field.AbsolutePosition.Y + field.AbsoluteSize.Y + 6
        local width = popup.AbsoluteSize.X > 0 and popup.AbsoluteSize.X or (options.Width or 154)
        local height = popup.AbsoluteSize.Y > 0 and popup.AbsoluteSize.Y or popupHeight
        if y + height > viewport.Y - 8 then
            y = field.AbsolutePosition.Y - height - 6
        end
        x = math.clamp(x, 8, math.max(8, viewport.X - width - 8))
        y = math.clamp(y, 8, math.max(8, viewport.Y - height - 8))
        popup.Position = UDim2.fromOffset(x, y)
    end

    field.Activated:Connect(function()
        if control.Disabled then
            return
        end
        self.Window:_playSound("Click")
        if self.Window._openPopup and self.Window._openPopup ~= popup then
            self.Window._openPopup.Visible = false
        end
        popup.Visible = not popup.Visible
        self.Window._openPopup = popup.Visible and popup or nil
        placePopup()
        arrow.Text = popup.Visible and "⌃" or "⌄"
        if popup.Visible and searchBox then
            searchBox:CaptureFocus()
        end
    end)

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            rebuild(searchBox.Text)
        end)
    end

    rebuild("")
    control:Set(control.Value, true)
    return control
end

function Section:AddInput(options)
    options = options or {}
    local multiline = options.Multiline == true
    local height = multiline and 86 or 42
    local control = self.Window:_newControl(self, options, height)
    if multiline then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Window.Theme.FontMedium,
            Text = options.Title or "Input",
            TextColor3 = options.TextColor or self.Window.Theme.Text,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(12, 5),
            Size = UDim2.new(1, -24, 0, 20),
            ZIndex = control.Root.ZIndex + 3,
            Parent = control.Root,
        })
    else
        self.Window:_controlTitle(control, options, 192)
    end

    local box = create("TextBox", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = self.Window.Theme.FieldTransparency,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearOnFocus == true,
        Font = self.Window.Theme.Font,
        PlaceholderText = options.Placeholder or "Type...",
        PlaceholderColor3 = self.Window.Theme.TextMuted,
        Text = tostring(options.Default or ""),
        TextColor3 = self.Window.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextWrapped = multiline,
        MultiLine = multiline,
        AnchorPoint = multiline and Vector2.new(0, 0) or Vector2.new(1, 0.5),
        Position = multiline and UDim2.fromOffset(12, 32) or UDim2.new(1, -10, 0.5, 0),
        Size = multiline and UDim2.new(1, -24, 0, 44) or UDim2.fromOffset(options.Width or 164, 28),
        ZIndex = control.Root.ZIndex + 4,
        Parent = control.Root,
    })
    corner(box, self.Window.Theme.RadiusSmall)
    padding(box, 9, 9, multiline and 7 or 0, multiline and 7 or 0)

    control.Value = box.Text

    function control:Set(value, silent)
        value = tostring(value or "")
        if options.MaxLength and #value > options.MaxLength then
            value = string.sub(value, 1, options.MaxLength)
        end
        if options.Numeric and value ~= "" and tonumber(value) == nil then
            return self
        end
        self.Value = value
        box.Text = value
        if self.Flag then
            self.Window:_setFlag(self.Flag, value, silent)
        end
        if not silent then
            safeCall(options.Callback, value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    box.Focused:Connect(function()
        self.Window:_tween(box, 0.14, {BackgroundTransparency = 0.03})
    end)
    box.FocusLost:Connect(function(enterPressed)
        self.Window:_tween(box, 0.14, {BackgroundTransparency = self.Window.Theme.FieldTransparency})
        control:Set(box.Text)
        safeCall(options.FocusLost, box.Text, enterPressed)
    end)
    box:GetPropertyChangedSignal("Text"):Connect(function()
        if options.MaxLength and #box.Text > options.MaxLength then
            box.Text = string.sub(box.Text, 1, options.MaxLength)
        end
        if options.Live then
            control:Set(box.Text)
        end
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddKeybind(options)
    options = options or {}
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 126)

    local key = options.Default or Enum.KeyCode.F
    local listening = false

    local field = create("TextButton", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = self.Window.Theme.FieldTransparency,
        BorderSizePixel = 0,
        Text = key.Name,
        TextColor3 = self.Window.Theme.TextSecondary,
        Font = self.Window.Theme.FontMedium,
        TextSize = 11,
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(options.Width or 100, 28),
        ZIndex = control.Root.ZIndex + 5,
        Selectable = true,
        Parent = control.Root,
    })
    corner(field, self.Window.Theme.RadiusSmall)

    control.Value = key

    function control:Set(value, silent)
        if typeof(value) ~= "EnumItem" then
            return self
        end
        self.Value = value
        field.Text = value.Name
        if self.Flag then
            self.Window:_setFlag(self.Flag, value.Name, silent)
        end
        if not silent then
            safeCall(options.Changed, value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    field.Activated:Connect(function()
        if control.Disabled then
            return
        end
        listening = true
        field.Text = "..."
        self.Window:_tween(field, 0.14, {BackgroundTransparency = 0.02})
    end)

    table.insert(control._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if listening then
            if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                listening = false
                control:Set(input.KeyCode)
                self.Window:_tween(field, 0.14, {BackgroundTransparency = self.Window.Theme.FieldTransparency})
            end
            return
        end
        if processed then
            return
        end
        if input.KeyCode == control.Value then
            safeCall(options.Callback, control.Value)
        end
    end))

    control:Set(key, true)
    return control
end

function Section:AddColorPicker(options)
    options = options or {}
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 60)

    local swatch = create("TextButton", {
        BackgroundColor3 = options.Default or Color3.new(1, 1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(26, 20),
        ZIndex = control.Root.ZIndex + 4,
        Selectable = true,
        Parent = control.Root,
    })
    corner(swatch, 5)

    local popup = self.Window:_popup(190, 206)
    local sv = create("Frame", {
        BackgroundColor3 = Color3.fromHSV(0, 1, 1),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.fromOffset(170, 145),
        ZIndex = 164,
        Parent = popup,
    })
    corner(sv, 6)
    local satGradient = create("UIGradient", {
        Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 0, 0)),
        Parent = sv,
    })
    satGradient.Transparency = NumberSequence.new(0)
    local valueOverlay = create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 165,
        Parent = sv,
    })
    corner(valueOverlay, 6)
    local valueGradient = create("UIGradient", {
        Rotation = 90,
        Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(0, 0, 0)),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Parent = valueOverlay,
    })

    local cursor = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(7, 7),
        ZIndex = 167,
        Parent = sv,
    })
    corner(cursor, 4)

    local hue = create("Frame", {
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 166),
        Size = UDim2.fromOffset(170, 8),
        ZIndex = 164,
        Parent = popup,
    })
    corner(hue, 4)
    create("UIGradient", {
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
    local hueCursor = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(4, 14),
        ZIndex = 166,
        Parent = hue,
    })
    corner(hueCursor, 2)

    local hexLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.Font,
        Text = "#FFFFFF",
        TextColor3 = self.Window.Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 180),
        Size = UDim2.new(1, -20, 0, 18),
        ZIndex = 164,
        Parent = popup,
    })

    control.Value = options.Default or Color3.new(1, 1, 1)
    local h, s, v = control.Value:ToHSV()
    local draggingSV = false
    local draggingHue = false

    function control:Set(value, silent)
        if typeof(value) ~= "Color3" then
            return self
        end
        self.Value = value
        h, s, v = value:ToHSV()
        swatch.BackgroundColor3 = value
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cursor.Position = UDim2.fromScale(s, 1 - v)
        hueCursor.Position = UDim2.fromScale(h, 0.5)
        hexLabel.Text = "#" .. value:ToHex()
        if self.Flag then
            self.Window:_setFlag(self.Flag, value, silent)
        end
        if not silent then
            safeCall(options.Callback, value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    local function updateSV(x, y)
        s = math.clamp((x - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        v = 1 - math.clamp((y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        control:Set(Color3.fromHSV(h, s, v))
    end

    local function updateHue(x)
        h = math.clamp((x - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
        control:Set(Color3.fromHSV(h, s, v))
    end

    local svHit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 168,
        Parent = sv,
    })
    local hueHit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 168,
        Parent = hue,
    })

    svHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = true
            updateSV(input.Position.X, input.Position.Y)
        end
    end)
    hueHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            updateHue(input.Position.X)
        end
    end)
    table.insert(control._connections, UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
            return
        end
        if draggingSV then
            updateSV(input.Position.X, input.Position.Y)
        elseif draggingHue then
            updateHue(input.Position.X)
        end
    end))
    table.insert(control._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = false
            draggingHue = false
        end
    end))

    swatch.Activated:Connect(function()
        if self.Window._openPopup and self.Window._openPopup ~= popup then
            self.Window._openPopup.Visible = false
        end
        popup.Visible = not popup.Visible
        self.Window._openPopup = popup.Visible and popup or nil
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local x = swatch.AbsolutePosition.X - 164
        local y = swatch.AbsolutePosition.Y + 28
        local width = popup.AbsoluteSize.X > 0 and popup.AbsoluteSize.X or 184
        local height = popup.AbsoluteSize.Y > 0 and popup.AbsoluteSize.Y or 214
        if y + height > viewport.Y - 8 then
            y = swatch.AbsolutePosition.Y - height - 8
        end
        x = math.clamp(x, 8, math.max(8, viewport.X - width - 8))
        y = math.clamp(y, 8, math.max(8, viewport.Y - height - 8))
        popup.Position = UDim2.fromOffset(x, y)
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddSegmented(options)
    options = options or {}
    local values = options.Values or options.Options or {"A", "B", "C"}
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 230)

    local holder = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = self.Window.Theme.FieldTransparency,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(options.Width or 205, 28),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    corner(holder, self.Window.Theme.RadiusSmall)
    local layout = list(holder, Enum.FillDirection.Horizontal, 2)
    layout.HorizontalFlex = Enum.UIFlexAlignment.Fill
    padding(holder, 2, 2, 2, 2)

    local buttons = {}
    control.Value = options.Default or values[1]

    for _, value in ipairs(values) do
        local button = create("TextButton", {
            BackgroundColor3 = self.Window.Theme.GlassHover,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = tostring(value),
            TextColor3 = self.Window.Theme.TextMuted,
            Font = self.Window.Theme.FontMedium,
            TextSize = 11,
            AutoButtonColor = false,
            Size = UDim2.new(0, 0, 1, 0),
            ZIndex = holder.ZIndex + 1,
            Selectable = true,
            Parent = holder,
        })
        corner(button, 4)
        buttons[value] = button
        button.Activated:Connect(function()
            if not control.Disabled then
                self.Window:_playSound("Click")
                control:Set(value)
            end
        end)
    end

    function control:Set(value, silent)
        self.Value = value
        for item, button in pairs(buttons) do
            local selected = item == value
            self.Window:_tween(button, 0.14, {
                BackgroundColor3 = selected and self.Window.Theme.AccentSoft or self.Window.Theme.GlassHover,
                BackgroundTransparency = selected and 0.2 or 1,
                TextColor3 = selected and self.Window.Theme.Text or self.Window.Theme.TextMuted,
            })
        end
        if self.Flag then
            self.Window:_setFlag(self.Flag, value, silent)
        end
        if not silent then
            safeCall(options.Callback, value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    control:Set(control.Value, true)
    return control
end

function Section:AddStepper(options)
    options = options or {}
    local min = tonumber(options.Min) or 0
    local max = tonumber(options.Max) or 100
    local step = tonumber(options.Step) or 1
    local control = self.Window:_newControl(self, options, 42)
    self.Window:_controlTitle(control, options, 140)

    local holder = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = self.Window.Theme.FieldTransparency,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(112, 28),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    corner(holder, self.Window.Theme.RadiusSmall)

    local minus = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "−",
        TextColor3 = self.Window.Theme.TextSecondary,
        Font = self.Window.Theme.FontMedium,
        TextSize = 15,
        AutoButtonColor = false,
        Size = UDim2.fromOffset(30, 28),
        ZIndex = holder.ZIndex + 1,
        Selectable = true,
        Parent = holder,
    })
    local plus = minus:Clone()
    plus.Text = "+"
    plus.AnchorPoint = Vector2.new(1, 0)
    plus.Position = UDim2.new(1, 0, 0, 0)
    plus.Parent = holder
    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = "0",
        TextColor3 = self.Window.Theme.Text,
        TextSize = 12,
        Position = UDim2.fromOffset(30, 0),
        Size = UDim2.new(1, -60, 1, 0),
        ZIndex = holder.ZIndex + 1,
        Parent = holder,
    })

    control.Value = math.clamp(tonumber(options.Default) or min, min, max)

    function control:Set(value, silent)
        self.Value = math.clamp(roundTo(tonumber(value) or min, step), min, max)
        valueLabel.Text = formatNumber(self.Value)
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCall(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    minus.Activated:Connect(function()
        if not control.Disabled then
            self.Window:_playSound("Click")
            control:Set(control.Value - step)
        end
    end)
    plus.Activated:Connect(function()
        if not control.Disabled then
            self.Window:_playSound("Click")
            control:Set(control.Value + step)
        end
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddProgress(options)
    options = options or {}
    local control = self.Window:_newControl(self, options, 46)
    self.Window:_controlTitle(control, options, 60, -4)

    local bar = create("Frame", {
        BackgroundColor3 = self.Window.Theme.Field,
        BackgroundTransparency = 0.06,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 12, 1, -12),
        Size = UDim2.new(1, -24, 0, 4),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    corner(bar, 2)
    local fill = create("Frame", {
        BackgroundColor3 = options.AccentColor or self.Window.Theme.Accent,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 0, 1, 0),
        ZIndex = bar.ZIndex + 1,
        Parent = bar,
    })
    corner(fill, 2)

    control.Value = math.clamp(tonumber(options.Default) or 0, 0, 1)
    function control:Set(value)
        self.Value = math.clamp(tonumber(value) or 0, 0, 1)
        self.Window:_tween(fill, 0.18, {Size = UDim2.new(self.Value, 0, 1, 0)})
        return self
    end
    function control:Get()
        return self.Value
    end
    control:Set(control.Value)
    return control
end

function Section:AddLabel(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}
    local control = self.Window:_newControl(self, options, 36)
    control.Hover.Visible = false
    control.Button.Visible = false
    self.Window:_controlTitle(control, options, options.Value and 100 or 8)
    if options.Value ~= nil then
        local value = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Window.Theme.Font,
            Text = tostring(options.Value),
            TextColor3 = self.Window.Theme.TextSecondary,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Right,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 0),
            Size = UDim2.fromOffset(88, 36),
            ZIndex = control.Root.ZIndex + 3,
            Parent = control.Root,
        })
        function control:Set(valueText)
            value.Text = tostring(valueText)
            return self
        end
    end
    return control
end

function Section:AddParagraph(options)
    options = options or {}
    local control = self.Window:_newControl(self, options, 60)
    control.Hover.Visible = false
    control.Button.Visible = false
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = options.Title or "",
        TextColor3 = self.Window.Theme.Text,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 7),
        Size = UDim2.new(1, -24, 0, 18),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    local body = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.Font,
        Text = options.Text or options.Description or "",
        TextColor3 = self.Window.Theme.TextSecondary,
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(12, 28),
        Size = UDim2.new(1, -24, 0, 26),
        ZIndex = control.Root.ZIndex + 3,
        Parent = control.Root,
    })
    return control
end

function Section:AddDivider()
    local root = create("Frame", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 9),
        Parent = self.Body,
    })
    create("Frame", {
        BackgroundColor3 = self.Window.Theme.Divider,
        BackgroundTransparency = 0.94,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 12, 0.5, 0),
        Size = UDim2.new(1, -24, 0, 1),
        Parent = root,
    })
    return root
end

Section.AddRadio = Section.AddSegmented

function Tab:AddSection(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local column = string.lower(options.Column or options.Side or "left")
    local parent
    if column == "right" then
        parent = self.RightColumn
    elseif column == "full" then
        parent = self.FullStack
    else
        parent = self.LeftColumn
    end

    local root = self.Window:_glass(parent, {
        Name = "Section",
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Transparency = options.Transparency ~= nil and options.Transparency or self.Window.Theme.SectionTransparency,
        Radius = self.Window.Theme.RadiusPanel,
        ClipsDescendants = true,
        WashHeight = 18,
    })
    local flow = create("Frame", {
        Name = "Flow",
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = root,
    })
    list(flow, Enum.FillDirection.Vertical, 0)

    if options.Title and options.Title ~= "" then
        local header = create("Frame", {
            Name = "Header",
            BackgroundColor3 = self.Window.Theme.Glass,
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 36),
            LayoutOrder = 1,
            Parent = flow,
        })
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Window.Theme.FontMedium,
            Text = options.Title,
            TextColor3 = self.Window.Theme.TextSecondary,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(14, 0),
            Size = UDim2.new(1, -28, 1, 0),
            Parent = header,
        })
        create("Frame", {
            BackgroundColor3 = self.Window.Theme.Divider,
            BackgroundTransparency = 0.94,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 14, 1, 0),
            Size = UDim2.new(1, -28, 0, 1),
            Parent = header,
        })
    end

    local body = create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 2,
        Parent = flow,
    })
    list(body, Enum.FillDirection.Vertical, 0)
    padding(body, 6, 6, 5, 7)

    local section = setmetatable({
        Window = self.Window,
        Tab = self,
        Root = root,
        Body = body,
        Controls = {},
    }, Section)

    table.insert(self.Sections, section)
    return section
end

function Tab:_refreshColumns()
    local left = self.LeftLayout.AbsoluteContentSize.Y
    local right = self.RightLayout.AbsoluteContentSize.Y
    local height = math.max(left, right)
    self.Columns.Size = UDim2.new(1, 0, 0, height)
    self.LeftColumn.Size = UDim2.new(0.5, -7, 0, left)
    self.RightColumn.Size = UDim2.new(0.5, -7, 0, right)
end

function Window:_selectTab(tab, silent)
    if not tab then
        return
    end
    self._activeTab = tab
    for _, item in ipairs(self._tabs) do
        local active = item == tab
        item.Page.Visible = active
        local data = item.Nav
        if data then
            self:_tween(data.Active, 0.18, {BackgroundTransparency = active and 0.42 or 1})
            if data.Icon then
                self:_tween(data.Icon, 0.18, {ImageColor3 = active and self.Theme.Accent or self.Theme.TextMuted})
            end
            self:_tween(data.Label, 0.18, {TextColor3 = active and self.Theme.Text or self.Theme.TextSecondary})
            self:_tween(data.Mark, 0.18, {
                BackgroundTransparency = active and 0 or 1,
                Size = UDim2.fromOffset(2, active and 18 or 4),
            })
        end
    end
    self.PageTitle.Text = tab.Title
    self.PageSubtitle.Text = tab.Subtitle or ""
    self.PageSubtitle.Visible = tab.Subtitle ~= nil and tab.Subtitle ~= ""
    if not silent then
        self:_playSound("Click")
    end
end

function Window:AddTab(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local tab = setmetatable({
        Window = self,
        Title = options.Title or "Tab",
        Subtitle = options.Subtitle,
        Icon = options.Icon,
        Sections = {},
    }, Tab)

    local page = create("ScrollingFrame", {
        Name = "Page_" .. tab.Title,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = self.Theme.TextMuted,
        ScrollBarImageTransparency = 0.35,
        Visible = false,
        Parent = self.PageContainer,
    })
    padding(page, 2, 8, 2, 14)
    list(page, Enum.FillDirection.Vertical, 14)

    local fullStack = create("Frame", {
        Name = "FullStack",
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 1,
        Parent = page,
    })
    list(fullStack, Enum.FillDirection.Vertical, 14)

    local columns = create("Frame", {
        Name = "Columns",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        LayoutOrder = 2,
        Parent = page,
    })

    local leftColumn = create("Frame", {
        Name = "LeftColumn",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(0.5, -7, 0, 0),
        Parent = columns,
    })
    local rightColumn = create("Frame", {
        Name = "RightColumn",
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 7, 0, 0),
        Size = UDim2.new(0.5, -7, 0, 0),
        Parent = columns,
    })

    local leftLayout = list(leftColumn, Enum.FillDirection.Vertical, 14)
    local rightLayout = list(rightColumn, Enum.FillDirection.Vertical, 14)

    tab.Page = page
    tab.FullStack = fullStack
    tab.Columns = columns
    tab.LeftColumn = leftColumn
    tab.RightColumn = rightColumn
    tab.LeftLayout = leftLayout
    tab.RightLayout = rightLayout

    local nav = create("TextButton", {
        Name = "Nav_" .. tab.Title,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(1, 0, 0, 44),
        Selectable = true,
        Parent = self.NavList,
    })

    local active = create("Frame", {
        BackgroundColor3 = self.Theme.GlassHover,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(7, 3),
        Size = UDim2.new(1, -14, 1, -6),
        Parent = nav,
    })
    corner(active, 7)

    local mark = create("Frame", {
        BackgroundColor3 = self.Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 5, 0.5, 0),
        Size = UDim2.fromOffset(2, 5),
        ZIndex = 4,
        Parent = nav,
    })
    corner(mark, 1)

    local icon = self:_makeIcon(nav, tab.Icon, 18, "TextMuted", 4)
    if icon then
        icon.AnchorPoint = Vector2.new(0, 0.5)
        icon.Position = UDim2.new(0, 21, 0.5, 0)
    end

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontMedium,
        Text = tab.Title,
        TextColor3 = self.Theme.TextSecondary,
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(50, 0),
        Size = UDim2.new(1, -64, 1, 0),
        ZIndex = 4,
        Parent = nav,
    })

    tab.Nav = {Button = nav, Active = active, Mark = mark, Icon = icon, Label = label}
    self:_hover(nav, active, {NormalTransparency = 1, HoverTransparency = 0.72})
    nav.Activated:Connect(function()
        self:_selectTab(tab)
    end)

    local function refresh()
        task.defer(function()
            if columns.Parent then
                tab:_refreshColumns()
            end
        end)
    end
    leftLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
    rightLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)

    table.insert(self._tabs, tab)
    if not self._activeTab then
        self:_selectTab(tab, true)
    end
    refresh()
    return tab
end

function Window:_buildSearch()
    local popup = self:_glass(self.Overlay, {
        Name = "SearchResults",
        Size = UDim2.fromOffset(300, 44),
        Transparency = 0.015,
        Radius = self.Theme.RadiusPanel,
        ZIndex = 180,
        ClipsDescendants = true,
        WashHeight = 18,
    })
    popup.Visible = false
    self:_makeShadow(popup, 24, 0.64)
    self.SearchPopup = popup

    local results = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 1, -12),
        Parent = popup,
    })
    local resultsLayout = list(results, Enum.FillDirection.Vertical, 3)
    self.SearchResults = results

    local function placePopup()
        local camera = workspace.CurrentCamera
        local viewport = camera and camera.ViewportSize or Vector2.new(1920, 1080)
        local x = self.SearchField.AbsolutePosition.X
        local y = self.SearchField.AbsolutePosition.Y + self.SearchField.AbsoluteSize.Y + 8
        local width = 300
        local height = popup.AbsoluteSize.Y > 0 and popup.AbsoluteSize.Y or 44
        x = math.clamp(x, 8, math.max(8, viewport.X - width - 8))
        y = math.clamp(y, 8, math.max(8, viewport.Y - height - 8))
        popup.Position = UDim2.fromOffset(x, y)
    end

    local function rebuild()
        for _, child in ipairs(results:GetChildren()) do
            if child:IsA("GuiObject") then
                child:Destroy()
            end
        end
        local query = string.lower(self.SearchBox.Text)
        if query == "" then
            popup.Visible = false
            return
        end

        local count = 0
        for _, control in ipairs(self._controls) do
            if count >= 7 then
                break
            end
            local title = control.TitleLabel and control.TitleLabel.Text or ""
            if title ~= "" and string.find(string.lower(title), query, 1, true) then
                count += 1
                local button = create("TextButton", {
                    BackgroundColor3 = self.Theme.GlassHover,
                    BackgroundTransparency = 1,
                    BorderSizePixel = 0,
                    Text = title,
                    TextColor3 = self.Theme.TextSecondary,
                    Font = self.Theme.Font,
                    TextSize = 12,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AutoButtonColor = false,
                    Size = UDim2.new(1, 0, 0, 32),
                    ZIndex = 184,
                    Parent = results,
                })
                corner(button, 6)
                padding(button, 10, 10, 0, 0)
                self:_hover(button, button, {NormalTransparency = 1, HoverTransparency = 0.56})
                button.Activated:Connect(function()
                    self:_selectTab(control.Section.Tab)
                    popup.Visible = false
                    self.SearchBox.Text = ""
                    task.defer(function()
                        if control.Root and control.Root.Parent then
                            local original = control.Hover.BackgroundTransparency
                            control.Hover.BackgroundColor3 = self.Theme.AccentSoft
                            control.Hover.BackgroundTransparency = 0.42
                            task.delay(0.32, function()
                                if control.Hover and control.Hover.Parent then
                                    self:_tween(control.Hover, 0.22, {
                                        BackgroundColor3 = self.Theme.GlassHover,
                                        BackgroundTransparency = original,
                                    })
                                end
                            end)
                        end
                    end)
                end)
            end
        end

        if count == 0 then
            popup.Visible = false
            return
        end

        popup.Size = UDim2.fromOffset(300, 12 + count * 35)
        popup.Visible = true
        task.defer(placePopup)
    end

    self.SearchBox:GetPropertyChangedSignal("Text"):Connect(rebuild)
end

function Window:OpenSearch()
    self.SearchBox:CaptureFocus()
end

function Window:CloseSearch()
    self.SearchBox.Text = ""
    self.SearchPopup.Visible = false
end

function Window:Notify(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local titleText = tostring(options.Title or "Notification")
    local descText = options.Description and tostring(options.Description) or nil
    local width = options.Width or 300
    local descHeight = 0
    if descText then
        descHeight = TextService:GetTextSize(descText, 12, self.Theme.Font, Vector2.new(width - 34, 500)).Y
    end
    local height = descText and math.max(58, 37 + descHeight) or 48

    local slot = create("Frame", {
        Name = "NotificationSlot",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(width, height),
        Parent = self.ToastHolder,
    })
    local toast = self:_glass(slot, {
        Name = "Notification",
        Size = UDim2.fromOffset(width, height),
        Transparency = 0.035,
        Radius = 8,
        ZIndex = 190,
        ClipsDescendants = true,
    })
    toast.BackgroundTransparency = 1
    self:_makeShadow(toast, 24, 0.65)

    local dotColor = self.Theme.Accent
    if options.Kind == "Success" then
        dotColor = self.Theme.Success
    elseif options.Kind == "Warning" then
        dotColor = self.Theme.Warning
    elseif options.Kind == "Danger" or options.Kind == "Error" then
        dotColor = self.Theme.Danger
    elseif options.Kind == "Info" then
        dotColor = self.Theme.Info
    end

    local dot = create("Frame", {
        BackgroundColor3 = dotColor,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 15),
        Size = UDim2.fromOffset(6, 6),
        ZIndex = 194,
        Parent = toast,
    })
    corner(dot, 3)

    create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontMedium,
        Text = titleText,
        TextColor3 = self.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(28, 8),
        Size = UDim2.new(1, -40, 0, 22),
        ZIndex = 194,
        Parent = toast,
    })

    if descText then
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Theme.Font,
            Text = descText,
            TextColor3 = self.Theme.TextSecondary,
            TextSize = 12,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(28, 29),
            Size = UDim2.new(1, -40, 0, descHeight + 2),
            ZIndex = 194,
            Parent = toast,
        })
    end

    local scale = create("UIScale", {Scale = 0.985, Parent = toast})
    toast.Position = UDim2.new(0, -330, 0, 0)
    task.defer(function()
        toast.BackgroundTransparency = 0.035
        self:_tween(toast, 0.28, {Position = UDim2.new(0, 0, 0, 0)}, Enum.EasingStyle.Quart)
        self:_tween(scale, 0.24, {Scale = 1})
    end)
    self:_playSound("Open")

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        self:_tween(toast, 0.2, {
            Position = UDim2.new(0, -330, 0, 0),
            BackgroundTransparency = 1,
        }, Enum.EasingStyle.Quart)
        self:_tween(scale, 0.2, {Scale = 0.985})
        task.delay(0.23, function()
            if slot.Parent then
                slot:Destroy()
            end
        end)
    end

    task.delay(options.Duration or 4, close)
    return {Close = close, Instance = toast}
end

function Window:SetOpen(open)
    open = open == true
    if self.Open == open then
        return
    end
    self.Open = open
    if open then
        self.Gui.Enabled = true
        self.Main.Visible = true
        self.MainGroup.GroupTransparency = 1
        self.MainScale.Scale = 0.975
        self:_tween(self.MainGroup, 0.25, {GroupTransparency = 0}, Enum.EasingStyle.Quart)
        self:_tween(self.MainScale, 0.28, {Scale = 1}, Enum.EasingStyle.Quart)
        if self.Blur then
            self:_tween(self.Blur, 0.24, {Size = self.Options.BlurSize or 10}, Enum.EasingStyle.Quart)
        end
        self:_playSound("Open")
    else
        self:_tween(self.MainGroup, 0.18, {GroupTransparency = 1}, Enum.EasingStyle.Quart)
        self:_tween(self.MainScale, 0.18, {Scale = 0.985}, Enum.EasingStyle.Quart)
        if self.Blur then
            self:_tween(self.Blur, 0.18, {Size = 0}, Enum.EasingStyle.Quart)
        end
        self:_playSound("Close")
        task.delay(0.2, function()
            if not self.Open and self.Gui.Parent then
                self.Gui.Enabled = false
            end
        end)
    end
end

function Window:Toggle()
    self:SetOpen(not self.Open)
end

function Window:Destroy()
    disconnectAll(self._connections)
    for _, control in ipairs(self._controls) do
        disconnectAll(control._connections)
    end
    if self.Blur then
        self.Blur:Destroy()
        self.Blur = nil
    end
    if self.Gui then
        self.Gui:Destroy()
    end
end

function Window:_updateScale()
    local camera = workspace.CurrentCamera
    if not camera then
        return
    end
    local viewport = camera.ViewportSize
    local baseWidth = self.Theme.Width
    local baseHeight = self.Theme.Height
    local availableWidth = math.max(260, viewport.X - 24)
    local availableHeight = math.max(220, viewport.Y - 24)
    local scale = math.min(1, availableWidth / baseWidth, availableHeight / baseHeight)
    self.ResponsiveScale.Scale = scale
    self._isCompact = viewport.X < 720
end

function LunkaraUI:CreateWindow(options)
    options = options or {}
    local requestedTheme = options.Theme
    if type(requestedTheme) == "string" then
        requestedTheme = self.Themes[requestedTheme]
    end

    local window = setmetatable({
        Theme = mergeTable(self.Themes.Liquid, requestedTheme or {}),
        Icons = mergeTable(self.DefaultIcons, options.Icons or {}),
        Sounds = mergeTable(self.DefaultSounds, options.Sounds or {}),
        Options = options,
        Flags = {},
        Open = true,
        _tabs = {},
        _controls = {},
        _flagControls = {},
        _flagListeners = {},
        _themeBindings = {},
        _connections = {},
        _activeTab = nil,
        _openPopup = nil,
    }, Window)

    local gui = create("ScreenGui", {
        Name = options.Name or "LunkaraUI",
        ResetOnSpawn = options.ResetOnSpawn == true,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
        DisplayOrder = options.DisplayOrder or 40,
        Parent = resolveParent(options.Parent),
    })
    window.Gui = gui

    -- Actual 3D background blur makes the glass readable. It never blurs GUI text.
    if options.BackgroundBlur ~= false then
        local blur = create("BlurEffect", {
            Name = "LunkaraUI_BackdropBlur",
            Size = 0,
            Parent = Lighting,
        })
        window.Blur = blur
        window:_tween(blur, 0.28, {Size = options.BlurSize or 10}, Enum.EasingStyle.Quart)
    end

    -- Preload custom icon assets so the navigation does not appear text-only while Roblox fetches them.
    task.spawn(function()
        local assets = {}
        for _, value in pairs(window.Icons) do
            local id = assetId(value)
            if id ~= "" then
                table.insert(assets, id)
            end
        end
        if #assets > 0 then
            pcall(function()
                ContentProvider:PreloadAsync(assets)
            end)
        end
    end)

    local overlay = create("Frame", {
        Name = "Overlay",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 100,
        Parent = gui,
    })
    window.Overlay = overlay

    local mainGroup = create("Frame", {
        Name = "WindowAnchor",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(window.Theme.Width, window.Theme.Height),
        Parent = gui,
    })
    window.Root = mainGroup

    local responsiveScale = create("UIScale", {Scale = 1, Parent = mainGroup})
    window.ResponsiveScale = responsiveScale

    local openHost = create("CanvasGroup", {
        Name = "WindowMotion",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        GroupTransparency = 0,
        Parent = mainGroup,
    })
    window.MainGroup = openHost

    local mainScale = create("UIScale", {Scale = 1, Parent = openHost})
    window.MainScale = mainScale

    local main = window:_glass(openHost, {
        Name = "Main",
        Size = UDim2.fromScale(1, 1),
        Transparency = window.Theme.WindowTransparency,
        ColorKey = "Backdrop",
        Radius = window.Theme.RadiusWindow,
        ClipsDescendants = true,
        ZIndex = 2,
        WashHeight = 56,
    })
    main.BackgroundColor3 = window.Theme.Backdrop
    window.Main = main
    window:_makeShadow(main, 42, 0.5)

    -- Sidebar
    local sidebar = create("Frame", {
        Name = "Sidebar",
        BackgroundColor3 = window.Theme.Sidebar,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.new(0, window.Theme.SidebarWidth, 1, 0),
        ZIndex = 4,
        Parent = main,
    })
    window.Sidebar = sidebar

    local brand = create("Frame", {
        Name = "Brand",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 14),
        Size = UDim2.new(1, -36, 0, 34),
        ZIndex = 6,
        Parent = sidebar,
    })
    local brandText = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.FontBold,
        Text = options.Brand or "Lunkara",
        TextColor3 = window.Theme.Text,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.fromOffset(76, 34),
        AutomaticSize = Enum.AutomaticSize.X,
        ZIndex = 7,
        Parent = brand,
    })
    local suffix = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.FontBold,
        Text = options.BrandSuffix or "UI",
        TextColor3 = window.Theme.Accent,
        TextSize = 16,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.new(0, 82, 0, 0),
        Size = UDim2.fromOffset(30, 34),
        ZIndex = 7,
        Parent = brand,
    })

    local navList = create("Frame", {
        Name = "Navigation",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 66),
        Size = UDim2.new(1, -16, 1, -158),
        ZIndex = 5,
        Parent = sidebar,
    })
    list(navList, Enum.FillDirection.Vertical, 2)
    window.NavList = navList

    if options.ShowProfile ~= false and LocalPlayer then
        local profile = create("Frame", {
            Name = "Profile",
            BackgroundColor3 = window.Theme.Glass,
            BackgroundTransparency = 0.48,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.new(0, 10, 1, -10),
            Size = UDim2.new(1, -20, 0, 58),
            ZIndex = 6,
            Parent = sidebar,
        })
        corner(profile, 8)
        local avatar = create("ImageLabel", {
            BackgroundColor3 = window.Theme.Field,
            BackgroundTransparency = 0.02,
            BorderSizePixel = 0,
            Position = UDim2.fromOffset(8, 11),
            Size = UDim2.fromOffset(36, 36),
            ZIndex = 7,
            Parent = profile,
        })
        corner(avatar, 18)
        task.spawn(function()
            local ok, image = pcall(function()
                return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
            end)
            if ok and avatar.Parent then
                avatar.Image = image
            end
        end)
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = window.Theme.FontMedium,
            Text = options.ProfileName or LocalPlayer.DisplayName,
            TextColor3 = window.Theme.Text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(54, 10),
            Size = UDim2.new(1, -62, 0, 19),
            ZIndex = 7,
            Parent = profile,
        })
        create("TextLabel", {
            BackgroundTransparency = 1,
            Font = window.Theme.Font,
            Text = options.ProfileSubtitle or ("@" .. LocalPlayer.Name),
            TextColor3 = window.Theme.TextMuted,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(54, 29),
            Size = UDim2.new(1, -62, 0, 16),
            ZIndex = 7,
            Parent = profile,
        })
    end

    -- Main content frame
    local content = create("Frame", {
        Name = "Content",
        BackgroundColor3 = window.Theme.Glass,
        BackgroundTransparency = 0.76,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(window.Theme.SidebarWidth, 0),
        Size = UDim2.new(1, -window.Theme.SidebarWidth, 1, 0),
        ZIndex = 4,
        Parent = main,
    })
    window.Content = content

    local topbar = create("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, window.Theme.TopbarHeight),
        ZIndex = 6,
        Parent = content,
    })
    window.Topbar = topbar

    -- Right-aligned topbar controls live in a single measured host; no overlapping positions.
    local topRight = create("Frame", {
        Name = "TopRight",
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -16, 0.5, 0),
        Size = UDim2.fromOffset(322, 34),
        ZIndex = 7,
        Parent = topbar,
    })

    local searchField = create("Frame", {
        Name = "SearchField",
        BackgroundColor3 = window.Theme.Search,
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 1),
        Size = UDim2.fromOffset(240, 32),
        ZIndex = 7,
        Parent = topRight,
    })
    corner(searchField, 7)
    window.SearchField = searchField

    local searchIcon = window:_makeIcon(searchField, "Search", 15, "TextMuted", 8)
    if searchIcon then
        searchIcon.AnchorPoint = Vector2.new(0, 0.5)
        searchIcon.Position = UDim2.new(0, 10, 0.5, 0)
    end

    local searchBox = create("TextBox", {
        BackgroundTransparency = 1,
        ClearTextOnFocus = false,
        Font = window.Theme.Font,
        PlaceholderText = "Search",
        PlaceholderColor3 = window.Theme.TextMuted,
        Text = "",
        TextColor3 = window.Theme.Text,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(searchIcon and 34 or 11, 0),
        Size = UDim2.new(1, -(searchIcon and 44 or 22), 1, 0),
        ZIndex = 8,
        Parent = searchField,
    })
    window.SearchBox = searchBox

    local minimize = create("TextButton", {
        BackgroundColor3 = window.Theme.Field,
        BackgroundTransparency = 1,
        Text = "−",
        TextColor3 = window.Theme.TextSecondary,
        Font = window.Theme.FontMedium,
        TextSize = 16,
        AutoButtonColor = false,
        Position = UDim2.fromOffset(250, 1),
        Size = UDim2.fromOffset(30, 32),
        Selectable = true,
        ZIndex = 8,
        Parent = topRight,
    })
    corner(minimize, 6)
    local close = create("TextButton", {
        BackgroundColor3 = window.Theme.Field,
        BackgroundTransparency = 1,
        Text = "×",
        TextColor3 = window.Theme.TextSecondary,
        Font = window.Theme.FontMedium,
        TextSize = 17,
        AutoButtonColor = false,
        Position = UDim2.fromOffset(286, 1),
        Size = UDim2.fromOffset(30, 32),
        Selectable = true,
        ZIndex = 8,
        Parent = topRight,
    })
    corner(close, 6)
    window:_hover(minimize, minimize, {NormalTransparency = 1, HoverTransparency = 0.28})
    window:_hover(close, close, {NormalTransparency = 1, HoverTransparency = 0.20, HoverColor = window.Theme.Danger})

    close.Activated:Connect(function()
        window:SetOpen(false)
    end)
    minimize.Activated:Connect(function()
        window:Toggle()
    end)

    local pageHeader = create("Frame", {
        Name = "PageHeader",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 62),
        Size = UDim2.new(1, -48, 0, 52),
        ZIndex = 5,
        Parent = content,
    })
    local pageTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.FontBold,
        Text = "",
        TextColor3 = window.Theme.Text,
        TextSize = 21,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 28),
        ZIndex = 6,
        Parent = pageHeader,
    })
    local pageSubtitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.Font,
        Text = "",
        TextColor3 = window.Theme.TextSecondary,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(0, 28),
        Size = UDim2.new(1, 0, 0, 18),
        Visible = false,
        ZIndex = 6,
        Parent = pageHeader,
    })
    window.PageTitle = pageTitle
    window.PageSubtitle = pageSubtitle

    local pageContainer = create("Frame", {
        Name = "Pages",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(24, 116),
        Size = UDim2.new(1, -48, 1, -136),
        ZIndex = 5,
        Parent = content,
    })
    window.PageContainer = pageContainer

    local toastHolder = create("Frame", {
        Name = "Notifications",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(18, 70),
        Size = UDim2.fromOffset(310, 460),
        ZIndex = 185,
        Parent = overlay,
    })
    list(toastHolder, Enum.FillDirection.Vertical, 8)
    window.ToastHolder = toastHolder

    window:_buildSearch()

    -- Drag with viewport clamp.
    local dragging = false
    local dragInput
    local dragStart
    local startPosition

    local function clampWindowPosition(position)
        local camera = workspace.CurrentCamera
        if not camera then
            return position
        end
        local viewport = camera.ViewportSize
        local scale = window.ResponsiveScale.Scale
        local halfW = (window.Theme.Width * scale) * 0.5
        local halfH = (window.Theme.Height * scale) * 0.5
        local centerX = viewport.X * position.X.Scale + position.X.Offset
        local centerY = viewport.Y * position.Y.Scale + position.Y.Offset
        centerX = math.clamp(centerX, halfW + 8, math.max(halfW + 8, viewport.X - halfW - 8))
        centerY = math.clamp(centerY, halfH + 8, math.max(halfH + 8, viewport.Y - halfH - 8))
        return UDim2.fromOffset(centerX, centerY)
    end

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local mouseX = input.Position.X
            if mouseX >= topRight.AbsolutePosition.X - 8 then
                return
            end
            dragging = true
            dragStart = input.Position
            local absolute = mainGroup.AbsolutePosition + (mainGroup.AbsoluteSize * 0.5)
            startPosition = UDim2.fromOffset(absolute.X, absolute.Y)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    table.insert(window._connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            local nextPos = UDim2.fromOffset(startPosition.X.Offset + delta.X, startPosition.Y.Offset + delta.Y)
            mainGroup.Position = clampWindowPosition(nextPos)
        end
    end))

    local toggleKey = options.ToggleKey or Enum.KeyCode.RightControl
    local searchKey = options.SearchKey or Enum.KeyCode.K
    table.insert(window._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == toggleKey then
            window:Toggle()
        elseif input.KeyCode == searchKey and (UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)) then
            window:OpenSearch()
        elseif input.KeyCode == Enum.KeyCode.Escape then
            window:CloseSearch()
            if window._openPopup then
                window._openPopup.Visible = false
                window._openPopup = nil
            end
        end
    end))

    local camera = workspace.CurrentCamera
    if camera then
        table.insert(window._connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            window:_updateScale()
        end))
    end
    window:_updateScale()

    return window
end

return LunkaraUI
