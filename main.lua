--[[
    LunkaraUI
    Original Roblox UI library inspired by classic sidebar/control libraries,
    rebuilt around a modern theme/state/component architecture.

    Single-file ModuleScript / loadstring-compatible library.
    Version: 1.0.0

    Recommended five custom icon slots (all optional):
      Home, Components, Palette, Search, Settings

    LunkaraUI does not depend on external icon packs.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

local LunkaraUI = {
    Version = "1.0.0",
    Flags = {},
}

LunkaraUI.DefaultTheme = {
    Name = "Obsidian Glass",

    Background = Color3.fromRGB(14, 15, 18),
    Glass = Color3.fromRGB(20, 22, 27),
    GlassTransparency = 0.08,
    Sidebar = Color3.fromRGB(17, 19, 23),
    Topbar = Color3.fromRGB(18, 20, 24),
    Surface = Color3.fromRGB(27, 30, 36),
    SurfaceAlt = Color3.fromRGB(23, 26, 31),
    SurfaceHover = Color3.fromRGB(34, 38, 45),
    SurfacePressed = Color3.fromRGB(39, 43, 52),

    Accent = Color3.fromRGB(111, 125, 244),
    AccentSoft = Color3.fromRGB(83, 94, 184),
    AccentText = Color3.fromRGB(247, 248, 255),

    Text = Color3.fromRGB(241, 243, 248),
    TextSecondary = Color3.fromRGB(165, 171, 184),
    TextMuted = Color3.fromRGB(112, 119, 132),

    Stroke = Color3.fromRGB(255, 255, 255),
    StrokeTransparency = 0.92,
    Divider = Color3.fromRGB(255, 255, 255),
    DividerTransparency = 0.94,

    Success = Color3.fromRGB(85, 190, 132),
    Warning = Color3.fromRGB(226, 172, 78),
    Danger = Color3.fromRGB(222, 91, 101),
    Info = Color3.fromRGB(95, 158, 232),

    RadiusWindow = 14,
    RadiusPanel = 11,
    RadiusControl = 9,
    RadiusSmall = 7,

    ControlHeight = 46,
    SectionGap = 12,
    ControlGap = 8,
    WindowWidth = 860,
    WindowHeight = 560,
    SidebarWidth = 198,

    Font = Enum.Font.Gotham,
    FontMedium = Enum.Font.GothamMedium,
    FontBold = Enum.Font.GothamBold,
}

LunkaraUI.DefaultMotion = {
    Enabled = true,
    Fast = 0.14,
    Normal = 0.22,
    Slow = 0.34,
    EasingStyle = Enum.EasingStyle.Quart,
    EasingDirection = Enum.EasingDirection.Out,
    WindowOpenScale = 0.965,
}

LunkaraUI.DefaultSounds = {
    Enabled = true,
    Hover = 0,
    Click = 0,
    Toggle = 0,
    Open = 0,
    Close = 0,
    Volume = 0.35,
}

LunkaraUI.DefaultIcons = {
    Home = 81867978804443,
    Components = 126570555803946,
    Palette = 122671609869735,
    Search = 86567920400897,
    Settings = 86564139855583,
}

local function cloneTable(source)
    local copy = {}
    for key, value in pairs(source or {}) do
        if type(value) == "table" then
            copy[key] = cloneTable(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function mergeTable(base, override)
    local result = cloneTable(base)
    for key, value in pairs(override or {}) do
        if type(value) == "table" and type(result[key]) == "table" then
            result[key] = mergeTable(result[key], value)
        else
            result[key] = value
        end
    end
    return result
end

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function roundToStep(value, step)
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

local function safeCallback(callback, ...)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, ...)
    if not ok then
        warn("[LunkaraUI] Callback error: " .. tostring(err))
    end
end

local function create(className, properties, children)
    local instance = Instance.new(className)
    for property, value in pairs(properties or {}) do
        instance[property] = value
    end
    for _, child in ipairs(children or {}) do
        child.Parent = instance
    end
    return instance
end

local function addCorner(parent, radius)
    return create("UICorner", {
        CornerRadius = UDim.new(0, radius),
        Parent = parent,
    })
end

local function addStroke(parent, color, transparency, thickness)
    return create("UIStroke", {
        Color = color,
        Transparency = transparency,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        Parent = parent,
    })
end

local function addPadding(parent, left, right, top, bottom)
    return create("UIPadding", {
        PaddingLeft = UDim.new(0, left or 0),
        PaddingRight = UDim.new(0, right or left or 0),
        PaddingTop = UDim.new(0, top or 0),
        PaddingBottom = UDim.new(0, bottom or top or 0),
        Parent = parent,
    })
end

local function disconnectAll(list)
    for _, connection in ipairs(list or {}) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(list)
end

local function validSoundId(id)
    if type(id) == "number" then
        return id > 0
    end
    if type(id) == "string" then
        local number = tonumber(id:match("%d+"))
        return number ~= nil and number > 0
    end
    return false
end

local function playSound(settings, key, parent)
    if not settings or settings.Enabled == false then
        return
    end
    local id = settings[key]
    if not validSoundId(id) then
        return
    end

    local sound = Instance.new("Sound")
    sound.SoundId = assetId(id)
    sound.Volume = settings.Volume or 0.35
    sound.Parent = parent
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
    sound:Play()

    task.delay(6, function()
        if sound.Parent then
            sound:Destroy()
        end
    end)
end

local function resolveParent(customParent)
    if customParent and typeof(customParent) == "Instance" then
        return customParent
    end
    if not LocalPlayer then
        error("LunkaraUI must run on the client.")
    end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local Window = {}
Window.__index = Window

local Tab = {}
Tab.__index = Tab

local Section = {}
Section.__index = Section

local Control = {}
Control.__index = Control

function Window:_duration(key)
    if self.Motion.Enabled == false then
        return 0
    end
    return self.Motion[key] or self.Motion.Normal or 0.2
end

function Window:_tween(instance, durationKey, properties, style, direction)
    if not instance or not instance.Parent then
        return nil
    end
    local duration = type(durationKey) == "number" and durationKey or self:_duration(durationKey or "Normal")
    if duration <= 0 then
        for property, value in pairs(properties) do
            instance[property] = value
        end
        return nil
    end

    local tween = TweenService:Create(
        instance,
        TweenInfo.new(
            duration,
            style or self.Motion.EasingStyle,
            direction or self.Motion.EasingDirection
        ),
        properties
    )
    tween:Play()
    return tween
end

function Window:_theme(instance, property, key, override)
    if override ~= nil then
        instance[property] = override
        return
    end

    local value = self.Theme[key]
    if value ~= nil then
        instance[property] = value
    end

    table.insert(self._themeBindings, {
        Instance = instance,
        Property = property,
        Key = key,
    })
end

function Window:_themeStroke(stroke, colorKey, transparencyKey)
    self:_theme(stroke, "Color", colorKey)
    if transparencyKey then
        self:_theme(stroke, "Transparency", transparencyKey)
    end
end

function Window:_registerControl(control)
    table.insert(self._controls, control)
    if control.Flag then
        self._flagControls[control.Flag] = control
    end
    return control
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
                safeCallback(callback, value)
            end
        end
    end
end

function Window:OnFlagChanged(flag, callback)
    self._flagListeners[flag] = self._flagListeners[flag] or {}
    table.insert(self._flagListeners[flag], callback)
    return {
        Disconnect = function()
            local listeners = self._flagListeners[flag]
            if not listeners then
                return
            end
            local index = table.find(listeners, callback)
            if index then
                table.remove(listeners, index)
            end
        end,
    }
end

function Window:GetFlag(flag)
    return self.Flags[flag]
end

function Window:SetFlag(flag, value, silent)
    local control = self._flagControls[flag]
    if control and control.Set then
        control:Set(value, silent)
    else
        self:_setFlag(flag, value, silent)
    end
end

function Window:GetFlags()
    return cloneTable(self.Flags)
end

function Window:ApplyFlags(values, silent)
    for flag, value in pairs(values or {}) do
        self:SetFlag(flag, value, silent)
    end
end

function Window:EncodeFlags()
    local serializable = {}
    for flag, value in pairs(self.Flags) do
        if typeof(value) == "Color3" then
            serializable[flag] = {
                __type = "Color3",
                r = math.floor(value.R * 255 + 0.5),
                g = math.floor(value.G * 255 + 0.5),
                b = math.floor(value.B * 255 + 0.5),
            }
        else
            serializable[flag] = value
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

    for flag, value in pairs(decoded) do
        if type(value) == "table" and value.__type == "Color3" then
            value = Color3.fromRGB(value.r or 255, value.g or 255, value.b or 255)
        end
        self:SetFlag(flag, value, silent)
    end
    return true
end

function Window:SetTheme(theme)
    if type(theme) == "string" then
        local preset = LunkaraUI.Themes and LunkaraUI.Themes[theme]
        if preset then
            theme = preset
        else
            return false
        end
    end

    self.Theme = mergeTable(self.Theme, theme or {})

    for index = #self._themeBindings, 1, -1 do
        local binding = self._themeBindings[index]
        if not binding.Instance or not binding.Instance.Parent then
            table.remove(self._themeBindings, index)
        else
            local value = self.Theme[binding.Key]
            if value ~= nil then
                binding.Instance[binding.Property] = value
            end
        end
    end

    for _, control in ipairs(self._controls) do
        if control.RefreshTheme then
            safeCallback(control.RefreshTheme, control)
        end
    end

    if self._activeTab then
        self._activeTab:_setActive(true)
    end

    self:_updateResponsive()
    return true
end

function Window:_makeIcon(parent, icon, size, colorKey)
    local holder = create("Frame", {
        Name = "Icon",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(size, size),
        Parent = parent,
    })

    local resolved = icon
    if type(icon) == "string" and self.Icons[icon] ~= nil then
        resolved = self.Icons[icon]
    end
    resolved = assetId(resolved)

    if resolved ~= "" then
        local image = create("ImageLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Image = resolved,
            ScaleType = Enum.ScaleType.Fit,
            Parent = holder,
        })
        self:_theme(image, "ImageColor3", colorKey or "TextSecondary")
    else
        local fallback = create("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Font = self.Theme.FontBold,
            Text = "•",
            TextSize = math.max(14, size - 4),
            Parent = holder,
        })
        self:_theme(fallback, "TextColor3", colorKey or "TextSecondary")
    end

    return holder
end

function Window:_bindButtonMotion(button, hoverTarget, options)
    options = options or {}
    local normalColor = options.NormalColor or "Surface"
    local hoverColor = options.HoverColor or "SurfaceHover"
    local pressedColor = options.PressedColor or "SurfacePressed"

    local hovering = false
    table.insert(self._connections, button.MouseEnter:Connect(function()
        hovering = true
        if not options.Disabled then
            playSound(self.Sounds, "Hover", self.Gui)
            local targetColor = self.Theme[hoverColor]
            if targetColor and hoverTarget then
                self:_tween(hoverTarget, "Fast", {BackgroundColor3 = targetColor})
            end
        end
    end))

    table.insert(self._connections, button.MouseLeave:Connect(function()
        hovering = false
        local targetColor = self.Theme[normalColor]
        if targetColor and hoverTarget then
            self:_tween(hoverTarget, "Fast", {BackgroundColor3 = targetColor})
        end
    end))

    table.insert(self._connections, button.MouseButton1Down:Connect(function()
        local targetColor = self.Theme[pressedColor]
        if targetColor and hoverTarget then
            self:_tween(hoverTarget, "Fast", {BackgroundColor3 = targetColor})
        end
    end))

    table.insert(self._connections, button.MouseButton1Up:Connect(function()
        local key = hovering and hoverColor or normalColor
        local targetColor = self.Theme[key]
        if targetColor and hoverTarget then
            self:_tween(hoverTarget, "Fast", {BackgroundColor3 = targetColor})
        end
    end))
end

function Window:_tooltip(target, text)
    if not text or text == "" then
        return
    end

    local tooltip = create("TextLabel", {
        Name = "Tooltip",
        BackgroundTransparency = 0.03,
        AutomaticSize = Enum.AutomaticSize.XY,
        Font = self.Theme.FontMedium,
        Text = tostring(text),
        TextSize = 12,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Visible = false,
        ZIndex = 200,
        Parent = self.Overlay,
    })
    self:_theme(tooltip, "BackgroundColor3", "Surface")
    self:_theme(tooltip, "TextColor3", "Text")
    addCorner(tooltip, self.Theme.RadiusSmall)
    local stroke = addStroke(tooltip, self.Theme.Stroke, self.Theme.StrokeTransparency, 1)
    self:_themeStroke(stroke, "Stroke", "StrokeTransparency")
    addPadding(tooltip, 10, 10, 7, 7)

    local showToken = 0
    table.insert(self._connections, target.MouseEnter:Connect(function()
        showToken += 1
        local token = showToken
        task.delay(0.35, function()
            if token ~= showToken or not target.Parent then
                return
            end
            local mouse = UserInputService:GetMouseLocation()
            tooltip.Position = UDim2.fromOffset(mouse.X + 12, mouse.Y + 8)
            tooltip.Visible = true
        end)
    end))

    table.insert(self._connections, target.MouseLeave:Connect(function()
        showToken += 1
        tooltip.Visible = false
    end))
end

function Window:_updateResponsive()
    if not self.Main or not self.Main.Parent then
        return
    end

    local camera = workspace.CurrentCamera
    local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
    local isMobileWidth = viewport.X < 720
    self._isCompact = isMobileWidth

    local maxWidth = math.max(320, viewport.X - 24)
    local maxHeight = math.max(360, viewport.Y - 24)
    local width = math.min(self.Theme.WindowWidth or 860, maxWidth)
    local height = math.min(self.Theme.WindowHeight or 560, maxHeight)

    self.Main.Size = UDim2.fromOffset(width, height)

    if isMobileWidth then
        self.Sidebar.Size = UDim2.new(0, math.min(250, width * 0.78), 1, -56)
        self.Sidebar.Position = self._mobileSidebarOpen and UDim2.fromOffset(0, 56) or UDim2.fromOffset(-260, 56)
        self.Sidebar.Visible = true
        self.Content.Position = UDim2.fromOffset(0, 56)
        self.Content.Size = UDim2.new(1, 0, 1, -56)
        self.TopNav.Visible = false
        self.MenuButton.Visible = true
        self.BrandLabel.Position = UDim2.fromOffset(54, 0)
    else
        self._mobileSidebarOpen = false
        self.Sidebar.Position = UDim2.fromOffset(0, 56)
        self.Sidebar.Size = UDim2.new(0, self.Theme.SidebarWidth or 198, 1, -56)
        self.Content.Position = UDim2.fromOffset(self.Theme.SidebarWidth or 198, 56)
        self.Content.Size = UDim2.new(1, -(self.Theme.SidebarWidth or 198), 1, -56)
        self.TopNav.Visible = true
        self.MenuButton.Visible = false
        self.BrandLabel.Position = UDim2.fromOffset(16, 0)
    end
end

function Window:_setMobileSidebar(open)
    self._mobileSidebarOpen = open == true
    if not self._isCompact then
        return
    end
    local x = self._mobileSidebarOpen and 0 or -260
    self:_tween(self.Sidebar, "Normal", {Position = UDim2.fromOffset(x, 56)})
end

function Window:_selectTab(tab)
    if not tab or self._activeTab == tab then
        return
    end

    self._activeTab = tab
    for _, other in ipairs(self._tabs) do
        local active = other == tab
        other.Page.Visible = active
        other:_setActive(active)
    end

    self.PageTitle.Text = tab.Title
    self.PageSubtitle.Text = tab.Subtitle or ""
    self.PageSubtitle.Visible = (tab.Subtitle or "") ~= ""

    if self._isCompact then
        self:_setMobileSidebar(false)
    end
end

function Window:_createTabButton(tab, parent, topMode)
    local button = create("TextButton", {
        Name = topMode and "TopTab" or "SidebarTab",
        BackgroundTransparency = topMode and 1 or 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "",
        Size = topMode and UDim2.fromOffset(122, 32) or UDim2.new(1, 0, 0, 42),
        Selectable = true,
        Parent = parent,
    })

    if not topMode then
        self:_theme(button, "BackgroundColor3", "SurfaceAlt")
        addCorner(button, self.Theme.RadiusControl)
    end

    local icon = self:_makeIcon(button, tab.Icon, topMode and 16 or 18, "TextSecondary")
    icon.AnchorPoint = Vector2.new(0, 0.5)
    icon.Position = UDim2.new(0, topMode and 8 or 10, 0.5, 0)

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontMedium,
        Text = tab.Title,
        TextSize = topMode and 12 or 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.new(0, topMode and 31 or 39, 0, 0),
        Size = UDim2.new(1, -(topMode and 35 or 45), 1, 0),
        Parent = button,
    })
    self:_theme(label, "TextColor3", "TextSecondary")

    local indicator
    if not topMode then
        indicator = create("Frame", {
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 0, 0.5, 0),
            Size = UDim2.fromOffset(3, 0),
            Parent = button,
        })
        self:_theme(indicator, "BackgroundColor3", "Accent")
        addCorner(indicator, 3)
    end

    local underline
    if topMode then
        underline = create("Frame", {
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 1),
            Position = UDim2.new(0.5, 0, 1, 0),
            Size = UDim2.new(0, 0, 0, 2),
            Parent = button,
        })
        self:_theme(underline, "BackgroundColor3", "Accent")
        addCorner(underline, 2)
    end

    local record = {
        Button = button,
        Label = label,
        Icon = icon,
        Indicator = indicator,
        Underline = underline,
    }

    button.Activated:Connect(function()
        playSound(self.Sounds, "Click", self.Gui)
        self:_selectTab(tab)
    end)

    button.MouseEnter:Connect(function()
        playSound(self.Sounds, "Hover", self.Gui)
        if self._activeTab ~= tab then
            self:_tween(label, "Fast", {TextColor3 = self.Theme.Text})
            if not topMode then
                self:_tween(button, "Fast", {BackgroundColor3 = self.Theme.SurfaceHover})
            end
        end
    end)

    button.MouseLeave:Connect(function()
        if self._activeTab ~= tab then
            self:_tween(label, "Fast", {TextColor3 = self.Theme.TextSecondary})
            if not topMode then
                self:_tween(button, "Fast", {BackgroundColor3 = self.Theme.SurfaceAlt})
            end
        end
    end)

    return record
end

function Tab:_setActive(active)
    self.Active = active
    for _, record in ipairs({self.SidebarButton, self.TopButton}) do
        if record then
            local color = active and self.Window.Theme.Text or self.Window.Theme.TextSecondary
            self.Window:_tween(record.Label, "Fast", {TextColor3 = color})
            local iconImage = record.Icon:FindFirstChildWhichIsA("ImageLabel")
            local iconFallback = record.Icon:FindFirstChildWhichIsA("TextLabel")
            if iconImage then
                self.Window:_tween(iconImage, "Fast", {ImageColor3 = active and self.Window.Theme.Accent or self.Window.Theme.TextSecondary})
            elseif iconFallback then
                self.Window:_tween(iconFallback, "Fast", {TextColor3 = active and self.Window.Theme.Accent or self.Window.Theme.TextSecondary})
            end
            if record.Indicator then
                self.Window:_tween(record.Indicator, "Fast", {Size = UDim2.fromOffset(3, active and 22 or 0)})
                self.Window:_tween(record.Button, "Fast", {BackgroundColor3 = active and self.Window.Theme.SurfaceHover or self.Window.Theme.SurfaceAlt})
            end
            if record.Underline then
                self.Window:_tween(record.Underline, "Fast", {Size = UDim2.new(0, active and 42 or 0, 0, 2)})
            end
        end
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
        ScrollBarThickness = 3,
        ScrollBarImageTransparency = 0.4,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Size = UDim2.fromScale(1, 1),
        Visible = false,
        Parent = self.PageContainer,
    })
    self:_theme(page, "ScrollBarImageColor3", "Accent")
    addPadding(page, 14, 14, 10, 18)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, self.Theme.SectionGap),
        Parent = page,
    })

    tab.Page = page
    tab.SidebarButton = self:_createTabButton(tab, self.SidebarList, false)
    tab.TopButton = self:_createTabButton(tab, self.TopNav, true)

    table.insert(self._tabs, tab)

    if not self._activeTab then
        self:_selectTab(tab)
    end

    return tab
end

function Tab:AddSection(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local section = setmetatable({
        Window = self.Window,
        Tab = self,
        Title = options.Title or "",
        Description = options.Description,
        Collapsible = options.Collapsible == true,
        Collapsed = options.Collapsed == true,
        Controls = {},
    }, Section)

    local root = create("Frame", {
        Name = "Section",
        BackgroundTransparency = 1,
        AutomaticSize = Enum.AutomaticSize.Y,
        Size = UDim2.new(1, 0, 0, 0),
        Parent = self.Page,
    })

    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 7),
        Parent = root,
    })

    if section.Title ~= "" then
        local header = create("TextButton", {
            Name = "Header",
            BackgroundTransparency = 1,
            AutoButtonColor = false,
            Text = "",
            Size = UDim2.new(1, 0, 0, section.Description and 44 or 30),
            Selectable = section.Collapsible,
            Parent = root,
        })

        local title = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Window.Theme.FontBold,
            Text = section.Title,
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, -30, 0, 24),
            Parent = header,
        })
        self.Window:_theme(title, "TextColor3", "Text")

        if section.Description then
            local description = create("TextLabel", {
                BackgroundTransparency = 1,
                Font = self.Window.Theme.Font,
                Text = section.Description,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                Position = UDim2.fromOffset(0, 22),
                Size = UDim2.new(1, -30, 0, 18),
                Parent = header,
            })
            self.Window:_theme(description, "TextColor3", "TextMuted")
        end

        if section.Collapsible then
            local chevron = create("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -2, 0.5, 0),
                Size = UDim2.fromOffset(22, 22),
                Font = self.Window.Theme.FontBold,
                Text = section.Collapsed and "+" or "–",
                TextSize = 17,
                Parent = header,
            })
            self.Window:_theme(chevron, "TextColor3", "TextSecondary")
            section.Chevron = chevron

            header.Activated:Connect(function()
                section:SetCollapsed(not section.Collapsed)
            end)
        end
    end

    local body = create("Frame", {
        Name = "Body",
        BackgroundTransparency = 1,
        AutomaticSize = section.Collapsed and Enum.AutomaticSize.None or Enum.AutomaticSize.Y,
        Size = section.Collapsed and UDim2.new(1, 0, 0, 0) or UDim2.new(1, 0, 0, 0),
        ClipsDescendants = true,
        Parent = root,
    })

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, self.Window.Theme.ControlGap),
        Parent = body,
    })

    section.Root = root
    section.Body = body
    section.Layout = layout

    table.insert(self.Sections, section)
    return section
end

function Tab:_defaultSection()
    if self._default then
        return self._default
    end
    self._default = self:AddSection({Title = ""})
    return self._default
end

for _, method in ipairs({
    "AddButton", "AddToggle", "AddCheckbox", "AddSlider", "AddInput", "AddDropdown",
    "AddKeybind", "AddColorPicker", "AddLabel", "AddParagraph", "AddDivider", "AddProgress",
    "AddSegmented", "AddStepper", "AddBadge", "AddImage", "AddSubTabs", "AddRadio",
}) do
    Tab[method] = function(self, ...)
        return self:_defaultSection()[method](self:_defaultSection(), ...)
    end
end

function Section:SetCollapsed(collapsed)
    if not self.Collapsible then
        return
    end
    self.Collapsed = collapsed == true
    if self.Chevron then
        self.Chevron.Text = self.Collapsed and "+" or "–"
    end

    if self.Collapsed then
        self.Body.AutomaticSize = Enum.AutomaticSize.None
        self.Window:_tween(self.Body, "Normal", {Size = UDim2.new(1, 0, 0, 0)})
    else
        self.Body.AutomaticSize = Enum.AutomaticSize.Y
        self.Body.Size = UDim2.new(1, 0, 0, 0)
    end
end

function Section:_baseControl(options, height)
    options = options or {}
    local window = self.Window
    local root = create("Frame", {
        Name = options.Name or "Control",
        BackgroundTransparency = options.BackgroundTransparency or 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, height or window.Theme.ControlHeight),
        ClipsDescendants = false,
        Parent = self.Body,
    })
    window:_theme(root, "BackgroundColor3", "Surface", options.BackgroundColor)
    addCorner(root, options.Radius or window.Theme.RadiusControl)
    local stroke = addStroke(root, window.Theme.Stroke, window.Theme.StrokeTransparency, 1)
    window:_themeStroke(stroke, "Stroke", "StrokeTransparency")

    local control = setmetatable({
        Window = window,
        Section = self,
        Root = root,
        Stroke = stroke,
        Flag = options.Flag,
        Disabled = options.Disabled == true,
        Visible = options.Visible ~= false,
        _connections = {},
    }, Control)

    root.Visible = control.Visible

    if options.Tooltip then
        window:_tooltip(root, options.Tooltip)
    end

    table.insert(self.Controls, control)
    window:_registerControl(control)
    return control
end

function Control:SetVisible(visible)
    self.Visible = visible == true
    self.Root.Visible = self.Visible
    return self
end

function Control:SetDisabled(disabled)
    self.Disabled = disabled == true
    self.Root.Active = not self.Disabled
    self.Root.BackgroundTransparency = self.Disabled and 0.35 or 0
    return self
end

function Control:Destroy()
    disconnectAll(self._connections)
    if self.Root then
        self.Root:Destroy()
    end
end

function Section:_titleBlock(control, options, rightPadding)
    options = options or {}
    local window = self.Window

    local title = create("TextLabel", {
        Name = "Title",
        BackgroundTransparency = 1,
        Font = window.Theme.FontMedium,
        Text = options.Title or options.Text or "Control",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(14, options.Description and 7 or 0),
        Size = UDim2.new(1, -(rightPadding or 60) - 14, 0, options.Description and 20 or control.Root.Size.Y.Offset),
        Parent = control.Root,
    })
    window:_theme(title, "TextColor3", "Text", options.TextColor)

    local description
    if options.Description and options.Description ~= "" then
        description = create("TextLabel", {
            Name = "Description",
            BackgroundTransparency = 1,
            Font = window.Theme.Font,
            Text = options.Description,
            TextSize = 10,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            Position = UDim2.fromOffset(14, 25),
            Size = UDim2.new(1, -(rightPadding or 60) - 14, 0, 15),
            Parent = control.Root,
        })
        window:_theme(description, "TextColor3", "TextMuted")
    end

    control.TitleLabel = title
    control.DescriptionLabel = description
    return title, description
end

function Section:AddButton(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local control = self:_baseControl(options)
    self:_titleBlock(control, options, options.Icon and 86 or 58)

    if options.Icon then
        local icon = self.Window:_makeIcon(control.Root, options.Icon, 18, "TextSecondary")
        icon.AnchorPoint = Vector2.new(1, 0.5)
        icon.Position = UDim2.new(1, -40, 0.5, 0)
        control.Icon = icon
    end

    local arrow = create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(18, 20),
        Font = self.Window.Theme.FontBold,
        Text = "›",
        TextSize = 18,
        Parent = control.Root,
    })
    self.Window:_theme(arrow, "TextColor3", "TextMuted")

    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Selectable = true,
        Parent = control.Root,
    })

    self.Window:_bindButtonMotion(hit, control.Root)
    hit.Activated:Connect(function()
        if control.Disabled then
            return
        end
        playSound(self.Window.Sounds, "Click", self.Window.Gui)
        self.Window:_tween(arrow, "Fast", {Position = UDim2.new(1, -9, 0.5, 0)})
        task.delay(self.Window:_duration("Fast"), function()
            if arrow.Parent then
                self.Window:_tween(arrow, "Fast", {Position = UDim2.new(1, -12, 0.5, 0)})
            end
        end)
        safeCallback(options.Callback)
    end)

    function control:Fire()
        if not self.Disabled then
            safeCallback(options.Callback)
        end
    end

    return control
end

function Section:AddToggle(options)
    options = options or {}
    local control = self:_baseControl(options)
    self:_titleBlock(control, options, 80)

    local track = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(42, 24),
        BorderSizePixel = 0,
        Parent = control.Root,
    })
    self.Window:_theme(track, "BackgroundColor3", "SurfaceHover")
    addCorner(track, 12)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 3, 0.5, 0),
        Size = UDim2.fromOffset(18, 18),
        BorderSizePixel = 0,
        Parent = track,
    })
    self.Window:_theme(knob, "BackgroundColor3", "TextSecondary")
    addCorner(knob, 9)

    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Selectable = true,
        Parent = control.Root,
    })
    self.Window:_bindButtonMotion(hit, control.Root)

    control.Value = options.Default == true

    function control:Set(value, silent)
        self.Value = value == true
        local position = self.Value and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
        self.Window:_tween(knob, "Normal", {
            Position = position,
            BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.TextSecondary,
        })
        self.Window:_tween(track, "Normal", {
            BackgroundColor3 = self.Value and self.Window.Theme.AccentSoft or self.Window.Theme.SurfaceHover,
        })
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCallback(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    function control:RefreshTheme()
        knob.BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.TextSecondary
        track.BackgroundColor3 = self.Value and self.Window.Theme.AccentSoft or self.Window.Theme.SurfaceHover
    end

    hit.Activated:Connect(function()
        if control.Disabled then
            return
        end
        playSound(self.Window.Sounds, "Toggle", self.Window.Gui)
        control:Set(not control.Value)
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddCheckbox(options)
    options = options or {}
    local control = self:_baseControl(options)
    self:_titleBlock(control, options, 62)

    local box = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(22, 22),
        BorderSizePixel = 0,
        Parent = control.Root,
    })
    self.Window:_theme(box, "BackgroundColor3", "SurfaceHover")
    addCorner(box, 6)

    local mark = create("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Font = self.Window.Theme.FontBold,
        Text = "✓",
        TextSize = 14,
        TextTransparency = 1,
        Parent = box,
    })
    self.Window:_theme(mark, "TextColor3", "AccentText")

    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        Selectable = true,
        Parent = control.Root,
    })
    self.Window:_bindButtonMotion(hit, control.Root)

    control.Value = options.Default == true

    function control:Set(value, silent)
        self.Value = value == true
        self.Window:_tween(box, "Fast", {BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.SurfaceHover})
        self.Window:_tween(mark, "Fast", {TextTransparency = self.Value and 0 or 1})
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCallback(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    function control:RefreshTheme()
        box.BackgroundColor3 = self.Value and self.Window.Theme.Accent or self.Window.Theme.SurfaceHover
        mark.TextColor3 = self.Window.Theme.AccentText
    end

    hit.Activated:Connect(function()
        if not control.Disabled then
            playSound(self.Window.Sounds, "Toggle", self.Window.Gui)
            control:Set(not control.Value)
        end
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
    local step = tonumber(options.Step or options.Increment) or 1
    local default = clamp(tonumber(options.Default) or minimum, minimum, maximum)

    local control = self:_baseControl(options, options.Description and 72 or 62)
    self:_titleBlock(control, options, 72)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 9),
        Size = UDim2.fromOffset(58, 20),
        Font = self.Window.Theme.FontMedium,
        Text = "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = control.Root,
    })
    self.Window:_theme(valueLabel, "TextColor3", "TextSecondary")

    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -12),
        Size = UDim2.new(1, -28, 0, 5),
        BorderSizePixel = 0,
        Parent = control.Root,
    })
    self.Window:_theme(bar, "BackgroundColor3", "SurfaceHover")
    addCorner(bar, 3)

    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
        Parent = bar,
    })
    self.Window:_theme(fill, "BackgroundColor3", "Accent", options.AccentColor)
    addCorner(fill, 3)

    local knob = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(15, 15),
        BorderSizePixel = 0,
        Parent = bar,
    })
    self.Window:_theme(knob, "BackgroundColor3", "Accent", options.AccentColor)
    addCorner(knob, 8)

    local hit = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.new(1, 10, 0, 26),
        Selectable = true,
        Parent = bar,
    })

    local dragging = false

    local function setFromX(x, silent)
        local scale = clamp((x - bar.AbsolutePosition.X) / math.max(1, bar.AbsoluteSize.X), 0, 1)
        local value = minimum + (maximum - minimum) * scale
        value = clamp(roundToStep(value, step), minimum, maximum)
        control:Set(value, silent)
    end

    control.Value = default

    function control:Set(value, silent)
        value = clamp(roundToStep(tonumber(value) or minimum, step), minimum, maximum)
        self.Value = value
        local scale = (value - minimum) / (maximum - minimum)
        self.Window:_tween(fill, "Fast", {Size = UDim2.new(scale, 0, 1, 0)})
        self.Window:_tween(knob, "Fast", {Position = UDim2.new(scale, 0, 0.5, 0)})
        valueLabel.Text = (options.Prefix or "") .. formatNumber(value) .. (options.Suffix or "")
        if self.Flag then
            self.Window:_setFlag(self.Flag, self.Value, silent)
        end
        if not silent then
            safeCallback(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    function control:RefreshTheme()
        if options.AccentColor == nil then
            fill.BackgroundColor3 = self.Window.Theme.Accent
            knob.BackgroundColor3 = self.Window.Theme.Accent
        end
        bar.BackgroundColor3 = self.Window.Theme.SurfaceHover
        valueLabel.TextColor3 = self.Window.Theme.TextSecondary
    end

    hit.InputBegan:Connect(function(input)
        if control.Disabled then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
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

function Section:AddInput(options)
    options = options or {}
    local multiline = options.Multiline == true
    local height = multiline and 108 or (options.Description and 76 or 64)
    local control = self:_baseControl(options, height)

    if not multiline then
        self:_titleBlock(control, options, 14)
    else
        local title = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Window.Theme.FontMedium,
            Text = options.Title or "Input",
            TextSize = 13,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(14, 8),
            Size = UDim2.new(1, -28, 0, 18),
            Parent = control.Root,
        })
        self.Window:_theme(title, "TextColor3", "Text")
    end

    local box = create("TextBox", {
        Name = "TextBox",
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClearTextOnFocus = options.ClearOnFocus == true,
        Font = self.Window.Theme.Font,
        PlaceholderText = options.Placeholder or "Enter text...",
        Text = tostring(options.Default or ""),
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = multiline and Enum.TextYAlignment.Top or Enum.TextYAlignment.Center,
        TextWrapped = multiline,
        MultiLine = multiline,
        Size = multiline and UDim2.new(1, -28, 0, 64) or UDim2.new(1, -28, 0, 30),
        Position = multiline and UDim2.fromOffset(14, 34) or UDim2.new(0, 14, 1, -38),
        Parent = control.Root,
    })
    self.Window:_theme(box, "BackgroundColor3", "SurfaceAlt")
    self.Window:_theme(box, "TextColor3", "Text")
    self.Window:_theme(box, "PlaceholderColor3", "TextMuted")
    addCorner(box, self.Window.Theme.RadiusSmall)
    addPadding(box, 10, 10, multiline and 8 or 0, multiline and 8 or 0)

    local stroke = addStroke(box, self.Window.Theme.Stroke, self.Window.Theme.StrokeTransparency, 1)
    self.Window:_themeStroke(stroke, "Stroke", "StrokeTransparency")

    control.Value = box.Text

    function control:Set(value, silent)
        value = tostring(value or "")
        if options.MaxLength and #value > options.MaxLength then
            value = string.sub(value, 1, options.MaxLength)
        end
        if options.Numeric and value ~= "" and not tonumber(value) then
            return self
        end
        self.Value = value
        box.Text = value
        if self.Flag then
            self.Window:_setFlag(self.Flag, value, silent)
        end
        if not silent then
            safeCallback(options.Callback, value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    box.Focused:Connect(function()
        self.Window:_tween(stroke, "Fast", {Color = self.Window.Theme.Accent, Transparency = 0.35})
    end)

    box.FocusLost:Connect(function(enterPressed)
        self.Window:_tween(stroke, "Fast", {Color = self.Window.Theme.Stroke, Transparency = self.Window.Theme.StrokeTransparency})
        control:Set(box.Text)
        safeCallback(options.FocusLost, box.Text, enterPressed)
    end)

    box:GetPropertyChangedSignal("Text"):Connect(function()
        if options.Live then
            control:Set(box.Text)
        elseif options.MaxLength and #box.Text > options.MaxLength then
            box.Text = string.sub(box.Text, 1, options.MaxLength)
        end
    end)

    control:Set(control.Value, true)
    return control
end

function Window:_popupBase(width, height)
    local popup = create("Frame", {
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(width, height),
        Visible = false,
        ZIndex = 120,
        Parent = self.Overlay,
    })
    self:_theme(popup, "BackgroundColor3", "Glass")
    addCorner(popup, self.Theme.RadiusPanel)
    local stroke = addStroke(popup, self.Theme.Stroke, 0.86, 1)
    self:_theme(stroke, "Color", "Stroke")
    return popup
end

function Section:AddDropdown(options)
    options = options or {}
    local values = cloneTable(options.Values or options.Options or {})
    local multi = options.Multi == true
    local searchable = options.Searchable ~= false

    local control = self:_baseControl(options)
    self:_titleBlock(control, options, 220)

    local field = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(190, 30),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Selectable = true,
        Parent = control.Root,
    })
    self.Window:_theme(field, "BackgroundColor3", "SurfaceAlt")
    addCorner(field, self.Window.Theme.RadiusSmall)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.Font,
        Text = "",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        Position = UDim2.fromOffset(9, 0),
        Size = UDim2.new(1, -35, 1, 0),
        Parent = field,
    })
    self.Window:_theme(valueLabel, "TextColor3", "TextSecondary")

    local chevron = create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        Font = self.Window.Theme.FontBold,
        Text = "⌄",
        TextSize = 14,
        Parent = field,
    })
    self.Window:_theme(chevron, "TextColor3", "TextMuted")

    local popup = self.Window:_popupBase(220, math.min(280, 54 + math.max(1, #values) * 34))
    local searchBox
    local listY = 8

    if searchable then
        searchBox = create("TextBox", {
            BackgroundTransparency = 0,
            BorderSizePixel = 0,
            ClearTextOnFocus = false,
            Font = self.Window.Theme.Font,
            PlaceholderText = "Search...",
            Text = "",
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(8, 8),
            Size = UDim2.new(1, -16, 0, 30),
            ZIndex = 122,
            Parent = popup,
        })
        self.Window:_theme(searchBox, "BackgroundColor3", "SurfaceAlt")
        self.Window:_theme(searchBox, "TextColor3", "Text")
        self.Window:_theme(searchBox, "PlaceholderColor3", "TextMuted")
        addCorner(searchBox, self.Window.Theme.RadiusSmall)
        addPadding(searchBox, 9, 9, 0, 0)
        listY = 46
    end

    local list = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(6, listY),
        Size = UDim2.new(1, -12, 1, -(listY + 6)),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ZIndex = 122,
        Parent = popup,
    })
    self.Window:_theme(list, "ScrollBarImageColor3", "Accent")

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = list,
    })

    local itemButtons = {}
    control.Value = multi and {} or options.Default

    local function containsSelection(value)
        if not multi then
            return control.Value == value
        end
        return table.find(control.Value, value) ~= nil
    end

    local function refreshLabel()
        if multi then
            if #control.Value == 0 then
                valueLabel.Text = options.Placeholder or "Select..."
            elseif #control.Value <= 2 then
                local parts = {}
                for _, value in ipairs(control.Value) do
                    table.insert(parts, tostring(value))
                end
                valueLabel.Text = table.concat(parts, ", ")
            else
                valueLabel.Text = tostring(#control.Value) .. " selected"
            end
        else
            valueLabel.Text = control.Value ~= nil and tostring(control.Value) or (options.Placeholder or "Select...")
        end
    end

    local function refreshItems(filter)
        filter = string.lower(filter or "")
        for value, record in pairs(itemButtons) do
            local visible = filter == "" or string.find(string.lower(tostring(value)), filter, 1, true) ~= nil
            record.Button.Visible = visible
            local selected = containsSelection(value)
            record.Mark.Text = selected and (multi and "✓" or "•") or ""
            record.Mark.TextColor3 = self.Window.Theme.Accent
            record.Label.TextColor3 = selected and self.Window.Theme.Text or self.Window.Theme.TextSecondary
        end
    end

    local function closePopup()
        popup.Visible = false
        self.Window:_tween(chevron, "Fast", {Rotation = 0})
        if searchBox then
            searchBox.Text = ""
        end
    end

    local function openPopup()
        if control.Disabled then
            return
        end
        local absolute = field.AbsolutePosition
        local popupHeight = popup.AbsoluteSize.Y
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local y = absolute.Y + field.AbsoluteSize.Y + 6
        if y + popupHeight > viewport.Y - 8 then
            y = absolute.Y - popupHeight - 6
        end
        popup.Position = UDim2.fromOffset(absolute.X, y)
        popup.Visible = true
        popup.Size = UDim2.fromOffset(220, 0)
        self.Window:_tween(popup, "Normal", {Size = UDim2.fromOffset(220, math.min(280, 54 + math.max(1, #values) * 34))})
        self.Window:_tween(chevron, "Fast", {Rotation = 180})
        refreshItems(searchBox and searchBox.Text or "")
    end

    local function buildItems()
        for _, record in pairs(itemButtons) do
            record.Button:Destroy()
        end
        itemButtons = {}

        for _, value in ipairs(values) do
            local item = create("TextButton", {
                BackgroundTransparency = 0,
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                Size = UDim2.new(1, 0, 0, 32),
                ZIndex = 123,
                Selectable = true,
                Parent = list,
            })
            self.Window:_theme(item, "BackgroundColor3", "SurfaceAlt")
            addCorner(item, self.Window.Theme.RadiusSmall)

            local label = create("TextLabel", {
                BackgroundTransparency = 1,
                Font = self.Window.Theme.Font,
                Text = tostring(value),
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left,
                Position = UDim2.fromOffset(10, 0),
                Size = UDim2.new(1, -38, 1, 0),
                ZIndex = 124,
                Parent = item,
            })
            self.Window:_theme(label, "TextColor3", "TextSecondary")

            local mark = create("TextLabel", {
                BackgroundTransparency = 1,
                AnchorPoint = Vector2.new(1, 0.5),
                Position = UDim2.new(1, -9, 0.5, 0),
                Size = UDim2.fromOffset(18, 18),
                Font = self.Window.Theme.FontBold,
                Text = "",
                TextSize = 12,
                ZIndex = 124,
                Parent = item,
            })
            self.Window:_theme(mark, "TextColor3", "Accent")

            item.Activated:Connect(function()
                playSound(self.Window.Sounds, "Click", self.Window.Gui)
                if multi then
                    local index = table.find(control.Value, value)
                    if index then
                        table.remove(control.Value, index)
                    else
                        table.insert(control.Value, value)
                    end
                    control:Set(control.Value)
                    refreshItems(searchBox and searchBox.Text or "")
                else
                    control:Set(value)
                    closePopup()
                end
            end)

            item.MouseEnter:Connect(function()
                self.Window:_tween(item, "Fast", {BackgroundColor3 = self.Window.Theme.SurfaceHover})
            end)
            item.MouseLeave:Connect(function()
                self.Window:_tween(item, "Fast", {BackgroundColor3 = self.Window.Theme.SurfaceAlt})
            end)

            itemButtons[value] = {Button = item, Label = label, Mark = mark}
        end
        refreshItems("")
    end

    function control:Set(value, silent)
        if multi then
            local nextValue = {}
            if type(value) == "table" then
                for _, item in ipairs(value) do
                    if table.find(values, item) and not table.find(nextValue, item) then
                        table.insert(nextValue, item)
                    end
                end
            end
            self.Value = nextValue
        else
            if value ~= nil and not table.find(values, value) then
                value = nil
            end
            self.Value = value
        end
        refreshLabel()
        refreshItems(searchBox and searchBox.Text or "")
        if self.Flag then
            self.Window:_setFlag(self.Flag, cloneTable(self.Value), silent)
        end
        if not silent then
            safeCallback(options.Callback, self.Value)
        end
        return self
    end

    function control:Get()
        return multi and cloneTable(self.Value) or self.Value
    end

    function control:SetValues(newValues, preserve)
        values = cloneTable(newValues or {})
        buildItems()
        if preserve then
            self:Set(self.Value, true)
        else
            self:Set(multi and {} or nil, true)
        end
        return self
    end

    function control:AddValue(value)
        if not table.find(values, value) then
            table.insert(values, value)
            buildItems()
        end
        return self
    end

    function control:RemoveValue(value)
        local index = table.find(values, value)
        if index then
            table.remove(values, index)
            buildItems()
            self:Set(self.Value, true)
        end
        return self
    end

    field.Activated:Connect(function()
        if popup.Visible then
            closePopup()
        else
            openPopup()
        end
    end)

    if searchBox then
        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            refreshItems(searchBox.Text)
        end)
    end

    table.insert(self.Window._connections, UserInputService.InputBegan:Connect(function(input)
        if not popup.Visible then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            local p = popup.AbsolutePosition
            local s = popup.AbsoluteSize
            local f = field.AbsolutePosition
            local fs = field.AbsoluteSize
            local inPopup = pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
            local inField = pos.X >= f.X and pos.X <= f.X + fs.X and pos.Y >= f.Y and pos.Y <= f.Y + fs.Y
            if not inPopup and not inField then
                closePopup()
            end
        end
    end))

    buildItems()
    control:Set(control.Value, true)
    return control
end

function Section:AddKeybind(options)
    options = options or {}
    local control = self:_baseControl(options)
    self:_titleBlock(control, options, 120)

    local bindButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(100, 30),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = self.Window.Theme.FontMedium,
        Text = "",
        TextSize = 11,
        Selectable = true,
        Parent = control.Root,
    })
    self.Window:_theme(bindButton, "BackgroundColor3", "SurfaceAlt")
    self.Window:_theme(bindButton, "TextColor3", "TextSecondary")
    addCorner(bindButton, self.Window.Theme.RadiusSmall)

    control.Value = options.Default or options.Key or Enum.KeyCode.Unknown
    control.Listening = false

    local function displayName(key)
        if typeof(key) == "EnumItem" then
            return key.Name
        end
        return tostring(key or "None")
    end

    function control:Set(value, silent)
        self.Value = value or Enum.KeyCode.Unknown
        bindButton.Text = displayName(self.Value)
        if self.Flag then
            self.Window:_setFlag(self.Flag, displayName(self.Value), silent)
        end
        if not silent then
            safeCallback(options.Callback, self.Value, false)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    bindButton.Activated:Connect(function()
        if control.Disabled then
            return
        end
        control.Listening = true
        bindButton.Text = "Press key..."
        self.Window:_tween(bindButton, "Fast", {BackgroundColor3 = self.Window.Theme.SurfaceHover})
    end)

    table.insert(control._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if control.Listening then
            if input.KeyCode == Enum.KeyCode.Escape then
                control.Listening = false
                bindButton.Text = displayName(control.Value)
                self.Window:_tween(bindButton, "Fast", {BackgroundColor3 = self.Window.Theme.SurfaceAlt})
                return
            end
            local key = input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode or input.UserInputType
            control.Listening = false
            self.Window:_tween(bindButton, "Fast", {BackgroundColor3 = self.Window.Theme.SurfaceAlt})
            control:Set(key)
            return
        end

        if processed or control.Disabled then
            return
        end
        if input.KeyCode == control.Value or input.UserInputType == control.Value then
            safeCallback(options.Callback, control.Value, true)
        end
    end))

    control:Set(control.Value, true)
    return control
end

function Section:AddColorPicker(options)
    options = options or {}
    local default = typeof(options.Default) == "Color3" and options.Default or self.Window.Theme.Accent

    local control = self:_baseControl(options)
    self:_titleBlock(control, options, 74)

    local swatch = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -14, 0.5, 0),
        Size = UDim2.fromOffset(48, 26),
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Selectable = true,
        Parent = control.Root,
    })
    addCorner(swatch, 7)

    local popup = self.Window:_popupBase(250, 238)
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontBold,
        Text = options.Title or "Color",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 9),
        Size = UDim2.new(1, -24, 0, 20),
        ZIndex = 122,
        Parent = popup,
    })
    self.Window:_theme(title, "TextColor3", "Text")

    local sv = create("Frame", {
        BackgroundColor3 = Color3.fromRGB(255, 0, 0),
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 38),
        Size = UDim2.new(1, -24, 0, 125),
        ZIndex = 122,
        Parent = popup,
    })
    addCorner(sv, 7)

    local whiteOverlay = create("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 123,
        Parent = sv,
    })
    addCorner(whiteOverlay, 7)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        }),
        Rotation = 0,
        Parent = whiteOverlay,
    })

    local blackOverlay = create("Frame", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 124,
        Parent = sv,
    })
    addCorner(blackOverlay, 7)
    create("UIGradient", {
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(1, 0),
        }),
        Rotation = 90,
        Parent = blackOverlay,
    })

    local satValInput = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 127,
        Parent = sv,
    })

    local cursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.fromOffset(10, 10),
        BackgroundTransparency = 1,
        ZIndex = 128,
        Parent = sv,
    })
    addCorner(cursor, 5)
    addStroke(cursor, Color3.new(1, 1, 1), 0.05, 2)

    local hue = create("Frame", {
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 173),
        Size = UDim2.new(1, -24, 0, 12),
        ZIndex = 122,
        Parent = popup,
    })
    addCorner(hue, 6)
    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
            ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
            ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
            ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
            ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
            ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
            ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
        }),
        Parent = hue,
    })

    local hueInput = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 126,
        Parent = hue,
    })

    local hueCursor = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(5, 18),
        BackgroundColor3 = Color3.new(1, 1, 1),
        ZIndex = 127,
        Parent = hue,
    })
    addCorner(hueCursor, 3)

    local hexBox = create("TextBox", {
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = self.Window.Theme.FontMedium,
        PlaceholderText = "#FFFFFF",
        Text = "",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 197),
        Size = UDim2.new(1, -24, 0, 29),
        ZIndex = 122,
        Parent = popup,
    })
    self.Window:_theme(hexBox, "BackgroundColor3", "SurfaceAlt")
    self.Window:_theme(hexBox, "TextColor3", "Text")
    self.Window:_theme(hexBox, "PlaceholderColor3", "TextMuted")
    addCorner(hexBox, 7)
    addPadding(hexBox, 9, 9, 0, 0)

    local h, s, v = Color3.toHSV(default)
    local draggingSV = false
    local draggingHue = false

    local function colorToHex(color)
        return string.format("#%02X%02X%02X", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
    end

    local function updateVisuals(silent)
        local color = Color3.fromHSV(h, s, v)
        control.Value = color
        swatch.BackgroundColor3 = color
        sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        cursor.Position = UDim2.new(s, 0, 1 - v, 0)
        hueCursor.Position = UDim2.new(h, 0, 0.5, 0)
        hexBox.Text = colorToHex(color)
        if control.Flag then
            control.Window:_setFlag(control.Flag, color, silent)
        end
        if not silent then
            safeCallback(options.Callback, color)
        end
    end

    local function setSV(x, y)
        s = clamp((x - sv.AbsolutePosition.X) / math.max(1, sv.AbsoluteSize.X), 0, 1)
        v = 1 - clamp((y - sv.AbsolutePosition.Y) / math.max(1, sv.AbsoluteSize.Y), 0, 1)
        updateVisuals(false)
    end

    local function setHue(x)
        h = clamp((x - hue.AbsolutePosition.X) / math.max(1, hue.AbsoluteSize.X), 0, 1)
        updateVisuals(false)
    end

    function control:Set(color, silent)
        if typeof(color) ~= "Color3" then
            return self
        end
        h, s, v = Color3.toHSV(color)
        updateVisuals(silent)
        return self
    end

    function control:Get()
        return self.Value
    end

    local function openPopup()
        local p = swatch.AbsolutePosition
        local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
        local x = math.min(p.X, viewport.X - 258)
        local y = p.Y + 32
        if y + 238 > viewport.Y - 8 then
            y = p.Y - 244
        end
        popup.Position = UDim2.fromOffset(math.max(8, x), math.max(8, y))
        popup.Visible = true
        popup.Size = UDim2.fromOffset(250, 0)
        self.Window:_tween(popup, "Normal", {Size = UDim2.fromOffset(250, 238)})
    end

    swatch.Activated:Connect(function()
        if control.Disabled then
            return
        end
        popup.Visible = not popup.Visible
        if popup.Visible then
            openPopup()
        end
    end)

    satValInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = true
            setSV(input.Position.X, input.Position.Y)
        end
    end)
    hueInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingHue = true
            setHue(input.Position.X)
        end
    end)

    table.insert(control._connections, UserInputService.InputChanged:Connect(function(input)
        if draggingSV and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setSV(input.Position.X, input.Position.Y)
        elseif draggingHue and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setHue(input.Position.X)
        end
    end))

    table.insert(control._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSV = false
            draggingHue = false
        end
    end))

    hexBox.FocusLost:Connect(function()
        local text = hexBox.Text:gsub("#", "")
        if #text == 6 then
            local r = tonumber(text:sub(1, 2), 16)
            local g = tonumber(text:sub(3, 4), 16)
            local b = tonumber(text:sub(5, 6), 16)
            if r and g and b then
                control:Set(Color3.fromRGB(r, g, b))
                return
            end
        end
        hexBox.Text = colorToHex(control.Value)
    end)

    table.insert(self.Window._connections, UserInputService.InputBegan:Connect(function(input)
        if not popup.Visible then
            return
        end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local pos = input.Position
            local p = popup.AbsolutePosition
            local size = popup.AbsoluteSize
            local inPopup = pos.X >= p.X and pos.X <= p.X + size.X and pos.Y >= p.Y and pos.Y <= p.Y + size.Y
            local sp = swatch.AbsolutePosition
            local ss = swatch.AbsoluteSize
            local inSwatch = pos.X >= sp.X and pos.X <= sp.X + ss.X and pos.Y >= sp.Y and pos.Y <= sp.Y + ss.Y
            if not inPopup and not inSwatch then
                popup.Visible = false
            end
        end
    end))

    control:Set(default, true)
    return control
end

function Section:AddLabel(options)
    if type(options) == "string" then
        options = {Text = options}
    end
    options = options or {}

    local control = self:_baseControl(options, 34)
    control.Root.BackgroundTransparency = options.Filled == true and 0 or 1
    control.Stroke.Transparency = options.Filled == true and self.Window.Theme.StrokeTransparency or 1

    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = options.Bold and self.Window.Theme.FontBold or self.Window.Theme.Font,
        Text = options.Text or options.Title or "Label",
        TextSize = options.TextSize or 12,
        TextXAlignment = options.Alignment or Enum.TextXAlignment.Left,
        TextWrapped = true,
        Position = UDim2.fromOffset(options.Filled and 12 or 2, 0),
        Size = UDim2.new(1, -(options.Filled and 24 or 4), 1, 0),
        Parent = control.Root,
    })
    self.Window:_theme(label, "TextColor3", options.Muted and "TextSecondary" or "Text", options.TextColor)

    function control:Set(text)
        label.Text = tostring(text or "")
        return self
    end

    return control
end

function Section:AddParagraph(options)
    if type(options) == "string" then
        options = {Text = options}
    end
    options = options or {}

    local control = self:_baseControl(options, 70)
    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontBold,
        Text = options.Title or "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 9),
        Size = UDim2.new(1, -28, 0, options.Title and 18 or 0),
        Visible = options.Title ~= nil,
        Parent = control.Root,
    })
    self.Window:_theme(title, "TextColor3", "Text")

    local bodyY = options.Title and 29 or 8
    local body = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.Font,
        Text = options.Text or options.Description or "",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        TextWrapped = true,
        Position = UDim2.fromOffset(14, bodyY),
        Size = UDim2.new(1, -28, 1, -(bodyY + 8)),
        Parent = control.Root,
    })
    self.Window:_theme(body, "TextColor3", "TextSecondary")

    function control:Set(text)
        body.Text = tostring(text or "")
        return self
    end

    return control
end

function Section:AddDivider(options)
    if type(options) == "string" then
        options = {Text = options}
    end
    options = options or {}

    local control = self:_baseControl(options, options.Text and 24 or 10)
    control.Root.BackgroundTransparency = 1
    control.Stroke.Transparency = 1

    local line = create("Frame", {
        AnchorPoint = Vector2.new(0, 0.5),
        Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.new(1, -4, 0, 1),
        BorderSizePixel = 0,
        Parent = control.Root,
    })
    self.Window:_theme(line, "BackgroundColor3", "Divider")
    line.BackgroundTransparency = self.Window.Theme.DividerTransparency

    if options.Text then
        local label = create("TextLabel", {
            BackgroundTransparency = 0,
            AutomaticSize = Enum.AutomaticSize.X,
            Font = self.Window.Theme.FontMedium,
            Text = "  " .. options.Text .. "  ",
            TextSize = 10,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0, 0, 1, 0),
            Parent = control.Root,
        })
        self.Window:_theme(label, "BackgroundColor3", "Background")
        self.Window:_theme(label, "TextColor3", "TextMuted")
    end

    return control
end

function Section:AddProgress(options)
    options = options or {}
    local control = self:_baseControl(options, options.Description and 70 or 60)
    self:_titleBlock(control, options, 66)

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -14, 0, 9),
        Size = UDim2.fromOffset(52, 18),
        Font = self.Window.Theme.FontMedium,
        Text = "0%",
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Right,
        Parent = control.Root,
    })
    self.Window:_theme(valueLabel, "TextColor3", "TextSecondary")

    local bar = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -10),
        Size = UDim2.new(1, -28, 0, 6),
        BorderSizePixel = 0,
        Parent = control.Root,
    })
    self.Window:_theme(bar, "BackgroundColor3", "SurfaceHover")
    addCorner(bar, 3)

    local fill = create("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BorderSizePixel = 0,
        Parent = bar,
    })
    self.Window:_theme(fill, "BackgroundColor3", "Accent", options.Color)
    addCorner(fill, 3)

    control.Value = 0

    function control:Set(value)
        value = clamp(tonumber(value) or 0, 0, 1)
        self.Value = value
        self.Window:_tween(fill, "Normal", {Size = UDim2.new(value, 0, 1, 0)})
        valueLabel.Text = tostring(math.floor(value * 100 + 0.5)) .. "%"
        return self
    end

    function control:Get()
        return self.Value
    end

    control:Set(options.Default or 0)
    return control
end

function Section:AddSegmented(options)
    options = options or {}
    local values = cloneTable(options.Values or options.Options or {"One", "Two"})
    local height = options.Description and 82 or 72
    local control = self:_baseControl(options, height)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = options.Title or "Segmented",
        TextSize = 13,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(14, 6),
        Size = UDim2.new(1, -28, 0, 20),
        Parent = control.Root,
    })
    self.Window:_theme(title, "TextColor3", "Text")

    local holder = create("Frame", {
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(12, 34),
        Size = UDim2.new(1, -24, 0, 28),
        Parent = control.Root,
    })
    self.Window:_theme(holder, "BackgroundColor3", "SurfaceAlt")
    addCorner(holder, 7)

    local layout = create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = holder,
    })

    local buttons = {}
    control.Value = options.Default or values[1]

    local function refresh()
        for value, button in pairs(buttons) do
            local active = control.Value == value
            button.BackgroundTransparency = active and 0 or 1
            button.BackgroundColor3 = self.Window.Theme.SurfaceHover
            button.TextColor3 = active and self.Window.Theme.Text or self.Window.Theme.TextSecondary
        end
    end

    for _, value in ipairs(values) do
        local button = create("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = self.Window.Theme.FontMedium,
            Text = tostring(value),
            TextSize = 11,
            TextColor3 = self.Window.Theme.TextSecondary,
            Size = UDim2.new(1 / math.max(1, #values), 0, 1, 0),
            Selectable = true,
            Parent = holder,
        })
        addCorner(button, 6)
        button.Activated:Connect(function()
            if not control.Disabled then
                playSound(self.Window.Sounds, "Click", self.Window.Gui)
                control:Set(value)
            end
        end)
        buttons[value] = button
    end

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() end)

    function control:Set(value, silent)
        if not table.find(values, value) then
            return self
        end
        self.Value = value
        refresh()
        if self.Flag then
            self.Window:_setFlag(self.Flag, value, silent)
        end
        if not silent then
            safeCallback(options.Callback, value)
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
    local control = self:_baseControl(options)
    self:_titleBlock(control, options, 152)

    local holder = create("Frame", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -12, 0.5, 0),
        Size = UDim2.fromOffset(132, 30),
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Parent = control.Root,
    })
    self.Window:_theme(holder, "BackgroundColor3", "SurfaceAlt")
    addCorner(holder, 7)

    local minus = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "−",
        Font = self.Window.Theme.FontBold,
        TextSize = 16,
        Size = UDim2.fromOffset(36, 30),
        Selectable = true,
        Parent = holder,
    })
    self.Window:_theme(minus, "TextColor3", "TextSecondary")

    local valueLabel = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = "0",
        TextSize = 11,
        Position = UDim2.fromOffset(36, 0),
        Size = UDim2.fromOffset(60, 30),
        Parent = holder,
    })
    self.Window:_theme(valueLabel, "TextColor3", "Text")

    local plus = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "+",
        Font = self.Window.Theme.FontBold,
        TextSize = 16,
        Position = UDim2.fromOffset(96, 0),
        Size = UDim2.fromOffset(36, 30),
        Selectable = true,
        Parent = holder,
    })
    self.Window:_theme(plus, "TextColor3", "TextSecondary")

    control.Value = clamp(tonumber(options.Default) or min, min, max)

    function control:Set(value, silent)
        value = clamp(roundToStep(tonumber(value) or min, step), min, max)
        self.Value = value
        valueLabel.Text = formatNumber(value)
        if self.Flag then
            self.Window:_setFlag(self.Flag, value, silent)
        end
        if not silent then
            safeCallback(options.Callback, value)
        end
        return self
    end

    function control:Get()
        return self.Value
    end

    minus.Activated:Connect(function()
        if not control.Disabled then
            playSound(self.Window.Sounds, "Click", self.Window.Gui)
            control:Set(control.Value - step)
        end
    end)
    plus.Activated:Connect(function()
        if not control.Disabled then
            playSound(self.Window.Sounds, "Click", self.Window.Gui)
            control:Set(control.Value + step)
        end
    end)

    control:Set(control.Value, true)
    return control
end

function Section:AddBadge(options)
    if type(options) == "string" then
        options = {Text = options}
    end
    options = options or {}

    local control = self:_baseControl(options, 36)
    local label = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Window.Theme.FontMedium,
        Text = options.Title or "Status",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -120, 1, 0),
        Parent = control.Root,
    })
    self.Window:_theme(label, "TextColor3", "TextSecondary")

    local badge = create("TextLabel", {
        BackgroundTransparency = 0,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        AutomaticSize = Enum.AutomaticSize.X,
        Size = UDim2.new(0, 0, 0, 22),
        Font = self.Window.Theme.FontMedium,
        Text = "  " .. tostring(options.Text or options.Value or "Ready") .. "  ",
        TextSize = 10,
        Parent = control.Root,
    })
    local colorKey = options.Kind == "Success" and "Success" or options.Kind == "Warning" and "Warning" or options.Kind == "Danger" and "Danger" or options.Kind == "Info" and "Info" or "Accent"
    self.Window:_theme(badge, "BackgroundColor3", colorKey, options.Color)
    self.Window:_theme(badge, "TextColor3", "AccentText")
    addCorner(badge, 11)

    function control:Set(text, kind)
        badge.Text = "  " .. tostring(text or "") .. "  "
        if kind then
            local key = kind == "Success" and "Success" or kind == "Warning" and "Warning" or kind == "Danger" and "Danger" or kind == "Info" and "Info" or "Accent"
            badge.BackgroundColor3 = self.Window.Theme[key]
        end
        return self
    end

    return control
end

function Section:AddImage(options)
    options = options or {}
    local height = tonumber(options.Height) or 150
    local control = self:_baseControl(options, height)
    control.Root.ClipsDescendants = true

    local image = create("ImageLabel", {
        BackgroundTransparency = 1,
        Image = assetId(options.Image),
        ImageColor3 = options.Color or Color3.new(1, 1, 1),
        ImageTransparency = options.Transparency or 0,
        ScaleType = options.ScaleType or Enum.ScaleType.Crop,
        Size = UDim2.fromScale(1, 1),
        Parent = control.Root,
    })

    if options.Caption then
        local scrim = create("Frame", {
            AnchorPoint = Vector2.new(0, 1),
            Position = UDim2.fromScale(0, 1),
            Size = UDim2.new(1, 0, 0, 42),
            BackgroundTransparency = 0.2,
            Parent = control.Root,
        })
        self.Window:_theme(scrim, "BackgroundColor3", "Background")

        local caption = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Window.Theme.FontMedium,
            Text = options.Caption,
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(1, -24, 1, 0),
            Parent = scrim,
        })
        self.Window:_theme(caption, "TextColor3", "Text")
    end

    function control:SetImage(id)
        image.Image = assetId(id)
        return self
    end

    return control
end

function Section:AddSubTabs(options)
    options = options or {}
    local tabs = cloneTable(options.Tabs or options.Values or {"Overview", "Details"})
    local control = self:_baseControl(options, tonumber(options.Height) or 220)

    local tabBar = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 8),
        Size = UDim2.new(1, -20, 0, 30),
        Parent = control.Root,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = tabBar,
    })

    local content = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(10, 46),
        Size = UDim2.new(1, -20, 1, -56),
        Parent = control.Root,
    })

    control.Pages = {}
    control.Active = nil

    function control:Select(name)
        if not self.Pages[name] then
            return self
        end
        self.Active = name
        for tabName, record in pairs(self.Pages) do
            local active = tabName == name
            record.Page.Visible = active
            record.Button.BackgroundTransparency = active and 0 or 1
            record.Button.BackgroundColor3 = self.Window.Theme.SurfaceHover
            record.Button.TextColor3 = active and self.Window.Theme.Text or self.Window.Theme.TextSecondary
        end
        safeCallback(options.Callback, name)
        return self
    end

    for _, name in ipairs(tabs) do
        local button = create("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = self.Window.Theme.FontMedium,
            Text = tostring(name),
            TextSize = 11,
            TextColor3 = self.Window.Theme.TextSecondary,
            AutomaticSize = Enum.AutomaticSize.X,
            Size = UDim2.new(0, 0, 1, 0),
            Selectable = true,
            Parent = tabBar,
        })
        addPadding(button, 10, 10, 0, 0)
        addCorner(button, 7)

        local page = create("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.fromScale(1, 1),
            Visible = false,
            Parent = content,
        })
        control.Pages[name] = {Button = button, Page = page}
        button.Activated:Connect(function()
            control:Select(name)
        end)
    end

    control:Select(options.Default or tabs[1])
    return control
end

function Section:AddRadio(options)
    options = options or {}
    options.Values = options.Values or options.Options or {}
    return self:AddSegmented(options)
end

function Window:_createSearch()
    local searchPopup = self:_popupBase(360, 330)
    searchPopup.AnchorPoint = Vector2.new(0.5, 0)
    searchPopup.Position = UDim2.new(0.5, 0, 0, 64)

    local searchBox = create("TextBox", {
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        ClearTextOnFocus = false,
        Font = self.Theme.Font,
        PlaceholderText = "Search controls...",
        Text = "",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(10, 10),
        Size = UDim2.new(1, -20, 0, 34),
        ZIndex = 122,
        Parent = searchPopup,
    })
    self:_theme(searchBox, "BackgroundColor3", "SurfaceAlt")
    self:_theme(searchBox, "TextColor3", "Text")
    self:_theme(searchBox, "PlaceholderColor3", "TextMuted")
    addCorner(searchBox, 8)
    addPadding(searchBox, 10, 10, 0, 0)

    local results = create("ScrollingFrame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(8, 52),
        Size = UDim2.new(1, -16, 1, -60),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 2,
        ZIndex = 122,
        Parent = searchPopup,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = results,
    })

    local function rebuild()
        for _, child in ipairs(results:GetChildren()) do
            if child:IsA("GuiButton") then
                child:Destroy()
            end
        end

        local query = string.lower(searchBox.Text)
        if query == "" then
            return
        end

        local count = 0
        for _, tab in ipairs(self._tabs) do
            for _, section in ipairs(tab.Sections) do
                for _, control in ipairs(section.Controls) do
                    local label = control.TitleLabel and control.TitleLabel.Text or control.Root.Name
                    if label and string.find(string.lower(label), query, 1, true) then
                        count += 1
                        if count > 30 then
                            return
                        end
                        local button = create("TextButton", {
                            BackgroundTransparency = 0,
                            BorderSizePixel = 0,
                            AutoButtonColor = false,
                            Font = self.Theme.FontMedium,
                            Text = "  " .. tab.Title .. "  /  " .. label,
                            TextSize = 11,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            Size = UDim2.new(1, 0, 0, 34),
                            ZIndex = 123,
                            Selectable = true,
                            Parent = results,
                        })
                        self:_theme(button, "BackgroundColor3", "SurfaceAlt")
                        self:_theme(button, "TextColor3", "TextSecondary")
                        addCorner(button, 7)
                        button.Activated:Connect(function()
                            self:_selectTab(tab)
                            searchPopup.Visible = false
                            searchBox.Text = ""
                            task.defer(function()
                                if control.Root.Parent then
                                    local page = tab.Page
                                    page.CanvasPosition = Vector2.new(0, math.max(0, control.Root.AbsolutePosition.Y - page.AbsolutePosition.Y - 20 + page.CanvasPosition.Y))
                                    local original = control.Root.BackgroundColor3
                                    control.Root.BackgroundColor3 = self.Theme.SurfaceHover
                                    task.delay(0.35, function()
                                        if control.Root.Parent then
                                            self:_tween(control.Root, "Normal", {BackgroundColor3 = original})
                                        end
                                    end)
                                end
                            end)
                        end)
                    end
                end
            end
        end
    end

    searchBox:GetPropertyChangedSignal("Text"):Connect(rebuild)
    self.SearchPopup = searchPopup
    self.SearchBox = searchBox
end

function Window:OpenSearch()
    self.SearchPopup.Visible = true
    self.SearchBox:CaptureFocus()
end

function Window:CloseSearch()
    self.SearchPopup.Visible = false
    self.SearchBox.Text = ""
end

function Window:Notify(options)
    if type(options) == "string" then
        options = {Title = options}
    end
    options = options or {}

    local toast = create("CanvasGroup", {
        BackgroundTransparency = 0.02,
        GroupTransparency = 1,
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(310, options.Description and 82 or 62),
        ZIndex = 150,
        Parent = self.ToastHolder,
    })
    local toastScale = create("UIScale", {
        Scale = 0.96,
        Parent = toast,
    })
    self:_theme(toast, "BackgroundColor3", "Glass")
    addCorner(toast, self.Theme.RadiusPanel)
    local stroke = addStroke(toast, self.Theme.Stroke, 0.88, 1)
    self:_theme(stroke, "Color", "Stroke")

    local kindKey = options.Kind == "Success" and "Success" or options.Kind == "Warning" and "Warning" or options.Kind == "Danger" and "Danger" or options.Kind == "Info" and "Info" or "Accent"
    local accent = create("Frame", {
        BorderSizePixel = 0,
        Size = UDim2.fromOffset(3, toast.Size.Y.Offset - 18),
        Position = UDim2.fromOffset(8, 9),
        ZIndex = 151,
        Parent = toast,
    })
    self:_theme(accent, "BackgroundColor3", kindKey)
    addCorner(accent, 3)

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontBold,
        Text = options.Title or "Notification",
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(20, 10),
        Size = UDim2.new(1, -34, 0, 18),
        ZIndex = 151,
        Parent = toast,
    })
    self:_theme(title, "TextColor3", "Text")

    if options.Description then
        local desc = create("TextLabel", {
            BackgroundTransparency = 1,
            Font = self.Theme.Font,
            Text = options.Description,
            TextSize = 10,
            TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top,
            Position = UDim2.fromOffset(20, 31),
            Size = UDim2.new(1, -32, 0, 40),
            ZIndex = 151,
            Parent = toast,
        })
        self:_theme(desc, "TextColor3", "TextSecondary")
    end

    local function close()
        self:_tween(toastScale, "Fast", {Scale = 0.96})
        self:_tween(toast, "Fast", {GroupTransparency = 1})
        task.delay(self:_duration("Fast") + 0.04, function()
            if toast.Parent then
                toast:Destroy()
            end
        end)
    end

    self:_tween(toastScale, "Normal", {Scale = 1})
    self:_tween(toast, "Normal", {GroupTransparency = 0})
    playSound(self.Sounds, "Open", self.Gui)
    task.delay(options.Duration or 4, close)

    return {Close = close, Instance = toast}
end

function Window:Modal(options)
    options = options or {}

    local shade = create("TextButton", {
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 170,
        Parent = self.Overlay,
    })

    local modal = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0),
        BackgroundTransparency = 0.02,
        BorderSizePixel = 0,
        ZIndex = 171,
        Parent = shade,
    })
    self:_theme(modal, "BackgroundColor3", "Glass")
    addCorner(modal, self.Theme.RadiusWindow)
    local stroke = addStroke(modal, self.Theme.Stroke, 0.86, 1)
    self:_theme(stroke, "Color", "Stroke")

    local title = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.FontBold,
        Text = options.Title or "Confirm",
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(18, 16),
        Size = UDim2.new(1, -36, 0, 24),
        ZIndex = 172,
        Parent = modal,
    })
    self:_theme(title, "TextColor3", "Text")

    local body = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = self.Theme.Font,
        Text = options.Description or options.Text or "",
        TextSize = 11,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Position = UDim2.fromOffset(18, 48),
        Size = UDim2.new(1, -36, 0, 62),
        ZIndex = 172,
        Parent = modal,
    })
    self:_theme(body, "TextColor3", "TextSecondary")

    local cancel = create("TextButton", {
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = self.Theme.FontMedium,
        Text = options.CancelText or "Cancel",
        TextSize = 11,
        Position = UDim2.new(0, 18, 1, -48),
        Size = UDim2.new(0.5, -23, 0, 34),
        ZIndex = 172,
        Selectable = true,
        Parent = modal,
    })
    self:_theme(cancel, "BackgroundColor3", "SurfaceAlt")
    self:_theme(cancel, "TextColor3", "TextSecondary")
    addCorner(cancel, 8)

    local confirm = create("TextButton", {
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Font = self.Theme.FontMedium,
        Text = options.ConfirmText or "Confirm",
        TextSize = 11,
        Position = UDim2.new(0.5, 5, 1, -48),
        Size = UDim2.new(0.5, -23, 0, 34),
        ZIndex = 172,
        Selectable = true,
        Parent = modal,
    })
    self:_theme(confirm, "BackgroundColor3", options.Danger and "Danger" or "Accent")
    self:_theme(confirm, "TextColor3", "AccentText")
    addCorner(confirm, 8)

    local closed = false
    local function close(result)
        if closed then
            return
        end
        closed = true
        self:_tween(modal, "Fast", {Size = UDim2.fromOffset(360, 0)})
        self:_tween(shade, "Fast", {BackgroundTransparency = 1})
        task.delay(self:_duration("Fast"), function()
            if shade.Parent then
                shade:Destroy()
            end
        end)
        safeCallback(options.Callback, result)
    end

    cancel.Activated:Connect(function()
        close(false)
    end)
    confirm.Activated:Connect(function()
        close(true)
    end)
    shade.Activated:Connect(function()
        if options.CloseOnBackdrop ~= false then
            close(false)
        end
    end)

    self:_tween(modal, "Normal", {Size = UDim2.fromOffset(360, 170)})
    return {Close = close}
end

function Window:ContextMenu(items, position)
    items = items or {}
    local menu = self:_popupBase(190, math.max(10, #items * 34 + 12))
    menu.Visible = true
    local pos = position or UserInputService:GetMouseLocation()
    menu.Position = UDim2.fromOffset(pos.X, pos.Y)

    local list = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(6, 6),
        Size = UDim2.new(1, -12, 1, -12),
        ZIndex = 122,
        Parent = menu,
    })
    create("UIListLayout", {
        Padding = UDim.new(0, 3),
        Parent = list,
    })

    local closed = false
    local function close()
        if closed then
            return
        end
        closed = true
        menu:Destroy()
    end

    for _, item in ipairs(items) do
        local button = create("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            Font = self.Theme.FontMedium,
            Text = "  " .. tostring(item.Title or item.Text or "Item"),
            TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left,
            Size = UDim2.new(1, 0, 0, 31),
            ZIndex = 123,
            Selectable = true,
            Parent = list,
        })
        self:_theme(button, "TextColor3", item.Danger and "Danger" or "TextSecondary")
        addCorner(button, 7)
        button.MouseEnter:Connect(function()
            button.BackgroundTransparency = 0
            button.BackgroundColor3 = self.Theme.SurfaceHover
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundTransparency = 1
        end)
        button.Activated:Connect(function()
            safeCallback(item.Callback)
            close()
        end)
    end

    task.delay(0.05, function()
        local connection
        connection = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                connection:Disconnect()
                close()
            end
        end)
    end)

    return {Close = close}
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
        self.MainScale.Scale = self.Motion.WindowOpenScale or 0.965
        self.Main.BackgroundTransparency = 1
        self:_tween(self.MainScale, "Normal", {Scale = 1}, Enum.EasingStyle.Quart)
        self:_tween(self.Main, "Normal", {BackgroundTransparency = self.Theme.GlassTransparency})
        playSound(self.Sounds, "Open", self.Gui)
    else
        self:_tween(self.MainScale, "Fast", {Scale = self.Motion.WindowOpenScale or 0.965})
        self:_tween(self.Main, "Fast", {BackgroundTransparency = 1})
        playSound(self.Sounds, "Close", self.Gui)
        task.delay(self:_duration("Fast") + 0.02, function()
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
    if self.Gui then
        self.Gui:Destroy()
    end
end

function LunkaraUI:CreateWindow(options)
    options = options or {}

    local requestedTheme = options.Theme
    if type(requestedTheme) == "string" then
        requestedTheme = self.Themes and self.Themes[requestedTheme] or nil
    end

    local window = setmetatable({
        Theme = mergeTable(self.DefaultTheme, requestedTheme or {}),
        Motion = mergeTable(self.DefaultMotion, options.Motion or {}),
        Sounds = mergeTable(self.DefaultSounds, options.Sounds or {}),
        Icons = mergeTable(self.DefaultIcons, options.Icons or {}),
        Options = options,
        Flags = {},
        Open = true,
        _tabs = {},
        _controls = {},
        _flagControls = {},
        _flagListeners = {},
        _themeBindings = {},
        _connections = {},
        _mobileSidebarOpen = false,
    }, Window)

    local gui = create("ScreenGui", {
        Name = options.Name or "LunkaraUI",
        ResetOnSpawn = options.ResetOnSpawn == true,
        IgnoreGuiInset = options.IgnoreGuiInset ~= false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = options.DisplayOrder or 25,
        Parent = resolveParent(options.Parent),
    })
    window.Gui = gui

    local overlay = create("Frame", {
        Name = "Overlay",
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        ZIndex = 100,
        Parent = gui,
    })
    window.Overlay = overlay

    local main = create("Frame", {
        Name = "Main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = options.Position or UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(window.Theme.WindowWidth, window.Theme.WindowHeight),
        BackgroundTransparency = window.Theme.GlassTransparency,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        Parent = gui,
    })
    window:_theme(main, "BackgroundColor3", "Glass")
    addCorner(main, window.Theme.RadiusWindow)
    local mainStroke = addStroke(main, window.Theme.Stroke, window.Theme.StrokeTransparency, 1)
    window:_themeStroke(mainStroke, "Stroke", "StrokeTransparency")
    window.Main = main

    local mainScale = create("UIScale", {
        Scale = 1,
        Parent = main,
    })
    window.MainScale = mainScale

    local topbar = create("Frame", {
        Name = "Topbar",
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 56),
        Parent = main,
    })
    window:_theme(topbar, "BackgroundColor3", "Topbar")
    window.Topbar = topbar

    local topDivider = create("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 1),
        BorderSizePixel = 0,
        Parent = topbar,
    })
    window:_theme(topDivider, "BackgroundColor3", "Divider")
    topDivider.BackgroundTransparency = window.Theme.DividerTransparency

    local menuButton = create("TextButton", {
        BackgroundTransparency = 1,
        Text = "≡",
        Font = window.Theme.FontBold,
        TextSize = 20,
        Position = UDim2.fromOffset(8, 8),
        Size = UDim2.fromOffset(38, 38),
        Visible = false,
        Selectable = true,
        Parent = topbar,
    })
    window:_theme(menuButton, "TextColor3", "TextSecondary")
    window.MenuButton = menuButton
    menuButton.Activated:Connect(function()
        window:_setMobileSidebar(not window._mobileSidebarOpen)
    end)

    local brand = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.FontBold,
        Text = options.Title or "LunkaraUI",
        TextSize = 15,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(16, 0),
        Size = UDim2.fromOffset(175, 56),
        Parent = topbar,
    })
    window:_theme(brand, "TextColor3", "Text")
    window.BrandLabel = brand

    local topNav = create("Frame", {
        Name = "TopNavigation",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(198, 12),
        Size = UDim2.new(1, -360, 0, 34),
        ClipsDescendants = true,
        Parent = topbar,
    })
    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 4),
        Parent = topNav,
    })
    window.TopNav = topNav

    local searchButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -52, 0.5, 0),
        Size = UDim2.fromOffset(36, 36),
        BackgroundTransparency = 1,
        Text = "",
        Selectable = true,
        Parent = topbar,
    })
    local searchIcon = window:_makeIcon(searchButton, "Search", 18, "TextSecondary")
    searchIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    searchIcon.Position = UDim2.fromScale(0.5, 0.5)
    searchButton.Activated:Connect(function()
        playSound(window.Sounds, "Click", window.Gui)
        window:OpenSearch()
    end)
    searchButton.MouseEnter:Connect(function()
        playSound(window.Sounds, "Hover", window.Gui)
    end)

    local closeButton = create("TextButton", {
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(32, 32),
        BackgroundTransparency = 1,
        Text = "×",
        Font = window.Theme.FontMedium,
        TextSize = 18,
        Selectable = true,
        Parent = topbar,
    })
    window:_theme(closeButton, "TextColor3", "TextSecondary")
    closeButton.Activated:Connect(function()
        playSound(window.Sounds, "Click", window.Gui)
        window:SetOpen(false)
    end)
    closeButton.MouseEnter:Connect(function()
        playSound(window.Sounds, "Hover", window.Gui)
    end)

    local sidebar = create("Frame", {
        Name = "Sidebar",
        BackgroundTransparency = 0,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(0, 56),
        Size = UDim2.new(0, window.Theme.SidebarWidth, 1, -56),
        ZIndex = 4,
        Parent = main,
    })
    window:_theme(sidebar, "BackgroundColor3", "Sidebar")
    window.Sidebar = sidebar

    local sidebarList = create("ScrollingFrame", {
        Name = "SidebarList",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.fromOffset(10, 12),
        Size = UDim2.new(1, -20, 1, -24),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollBarThickness = 0,
        Parent = sidebar,
    })
    addPadding(sidebarList, 0, 0, 0, 8)
    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        Parent = sidebarList,
    })
    window.SidebarList = sidebarList

    local content = create("Frame", {
        Name = "Content",
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(window.Theme.SidebarWidth, 56),
        Size = UDim2.new(1, -window.Theme.SidebarWidth, 1, -56),
        Parent = main,
    })
    window.Content = content

    local pageHeader = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(16, 10),
        Size = UDim2.new(1, -32, 0, 46),
        Parent = content,
    })

    local pageTitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.FontBold,
        Text = "",
        TextSize = 18,
        TextXAlignment = Enum.TextXAlignment.Left,
        Size = UDim2.new(1, 0, 0, 24),
        Parent = pageHeader,
    })
    window:_theme(pageTitle, "TextColor3", "Text")
    window.PageTitle = pageTitle

    local pageSubtitle = create("TextLabel", {
        BackgroundTransparency = 1,
        Font = window.Theme.Font,
        Text = "",
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        Position = UDim2.fromOffset(0, 25),
        Size = UDim2.new(1, 0, 0, 16),
        Parent = pageHeader,
    })
    window:_theme(pageSubtitle, "TextColor3", "TextMuted")
    window.PageSubtitle = pageSubtitle

    local pageContainer = create("Frame", {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(0, 58),
        Size = UDim2.new(1, 0, 1, -58),
        ClipsDescendants = true,
        Parent = content,
    })
    window.PageContainer = pageContainer

    local toastHolder = create("Frame", {
        BackgroundTransparency = 1,
        AnchorPoint = Vector2.new(1, 1),
        Position = UDim2.new(1, -12, 1, -12),
        Size = UDim2.fromOffset(320, 420),
        ZIndex = 145,
        Parent = overlay,
    })
    create("UIListLayout", {
        VerticalAlignment = Enum.VerticalAlignment.Bottom,
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        Parent = toastHolder,
    })
    window.ToastHolder = toastHolder

    window:_createSearch()

    -- Dragging: topbar only on pointer devices.
    local dragging = false
    local dragStart
    local startPosition
    local dragInput

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            local target = UserInputService:GetFocusedTextBox()
            if target then
                return
            end
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
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
            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end))

    table.insert(window._connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    -- Keyboard / controller shortcuts.
    local toggleKey = options.ToggleKey or Enum.KeyCode.RightControl
    local searchKey = options.SearchKey or Enum.KeyCode.K

    table.insert(window._connections, UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end
        if input.KeyCode == toggleKey then
            window:Toggle()
            return
        end
        if input.KeyCode == searchKey and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            window:OpenSearch()
            return
        end
        if input.KeyCode == Enum.KeyCode.Escape and window.SearchPopup.Visible then
            window:CloseSearch()
            return
        end
        if input.UserInputType == Enum.UserInputType.Gamepad1 and window.Open and not GuiService.SelectedObject then
            local first = window._tabs[1]
            if first and first.SidebarButton then
                GuiService.SelectedObject = first.SidebarButton.Button
            end
        end
    end))

    local camera = workspace.CurrentCamera
    if camera then
        table.insert(window._connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
            window:_updateResponsive()
        end))
    end

    window:_updateResponsive()

    if options.Open == false then
        window.Open = false
        gui.Enabled = false
    else
        mainScale.Scale = window.Motion.WindowOpenScale or 0.965
        main.BackgroundTransparency = 1
        task.defer(function()
            if main.Parent then
                window:_tween(mainScale, "Normal", {Scale = 1})
                window:_tween(main, "Normal", {BackgroundTransparency = window.Theme.GlassTransparency})
            end
        end)
    end

    return window
end

LunkaraUI.Themes = {
    Obsidian = cloneTable(LunkaraUI.DefaultTheme),
    Slate = mergeTable(LunkaraUI.DefaultTheme, {
        Name = "Slate Glass",
        Background = Color3.fromRGB(19, 21, 25),
        Glass = Color3.fromRGB(24, 27, 32),
        Sidebar = Color3.fromRGB(21, 23, 28),
        Topbar = Color3.fromRGB(22, 25, 30),
        Surface = Color3.fromRGB(31, 35, 41),
        SurfaceAlt = Color3.fromRGB(27, 30, 36),
        Accent = Color3.fromRGB(101, 148, 222),
        AccentSoft = Color3.fromRGB(75, 109, 165),
    }),
    Pearl = mergeTable(LunkaraUI.DefaultTheme, {
        Name = "Pearl Glass",
        Background = Color3.fromRGB(235, 237, 241),
        Glass = Color3.fromRGB(245, 246, 249),
        GlassTransparency = 0.03,
        Sidebar = Color3.fromRGB(239, 241, 245),
        Topbar = Color3.fromRGB(244, 246, 249),
        Surface = Color3.fromRGB(228, 231, 236),
        SurfaceAlt = Color3.fromRGB(233, 235, 240),
        SurfaceHover = Color3.fromRGB(218, 222, 229),
        SurfacePressed = Color3.fromRGB(209, 214, 222),
        Accent = Color3.fromRGB(79, 100, 221),
        AccentSoft = Color3.fromRGB(178, 186, 235),
        AccentText = Color3.fromRGB(255, 255, 255),
        Text = Color3.fromRGB(28, 31, 38),
        TextSecondary = Color3.fromRGB(75, 81, 94),
        TextMuted = Color3.fromRGB(118, 124, 136),
        Stroke = Color3.fromRGB(26, 31, 40),
        StrokeTransparency = 0.90,
        Divider = Color3.fromRGB(25, 29, 36),
        DividerTransparency = 0.92,
    }),
}

--[[
    QUICK START

    local Lunkara = loadstring(game:HttpGet("YOUR_RAW_GITHUB_URL"))()

    local Window = Lunkara:CreateWindow({
        Title = "LunkaraUI",
        Theme = Lunkara.Themes.Obsidian,
        ToggleKey = Enum.KeyCode.RightControl,
        Icons = {
            Home = 0,
            Components = 0,
            Palette = 0,
            Search = 0,
            Settings = 0,
        },
        Sounds = {
            Enabled = true,
            Hover = 0,
            Click = 0,
            Toggle = 0,
            Open = 0,
            Close = 0,
            Volume = 0.35,
        },
    })

    local Main = Window:AddTab({
        Title = "Home",
        Subtitle = "LunkaraUI component showcase",
        Icon = "Home",
    })

    local General = Main:AddSection({
        Title = "General",
        Description = "Core controls",
    })

    General:AddButton({
        Title = "Run Action",
        Description = "A clean action row",
        Callback = function()
            Window:Notify({Title = "Done", Description = "Action completed.", Kind = "Success"})
        end,
    })

    General:AddToggle({
        Title = "Enabled",
        Description = "Example toggle",
        Default = true,
        Flag = "Enabled",
        Callback = function(value)
            print("Toggle:", value)
        end,
    })

    General:AddSlider({
        Title = "Intensity",
        Min = 0,
        Max = 100,
        Step = 1,
        Default = 45,
        Flag = "Intensity",
    })

    General:AddDropdown({
        Title = "Mode",
        Values = {"Classic", "Balanced", "Advanced"},
        Default = "Balanced",
        Searchable = true,
        Flag = "Mode",
    })

    General:AddDropdown({
        Title = "Features",
        Values = {"A", "B", "C", "D"},
        Multi = true,
        Default = {"A", "C"},
        Flag = "Features",
    })

    General:AddInput({
        Title = "Display name",
        Placeholder = "Type here...",
        Flag = "DisplayName",
    })

    General:AddKeybind({
        Title = "Quick action",
        Default = Enum.KeyCode.F,
        Flag = "QuickKey",
    })

    General:AddColorPicker({
        Title = "Accent override",
        Default = Color3.fromRGB(111, 125, 244),
        Flag = "AccentColor",
    })

    General:AddSegmented({
        Title = "Quality",
        Values = {"Low", "Medium", "High"},
        Default = "High",
        Flag = "Quality",
    })

    General:AddStepper({
        Title = "Amount",
        Min = 0,
        Max = 20,
        Step = 1,
        Default = 3,
        Flag = "Amount",
    })

    General:AddProgress({
        Title = "Progress",
        Default = 0.72,
    })

    General:AddBadge({Title = "System", Text = "Online", Kind = "Success"})
    General:AddDivider("Information")
    General:AddParagraph({Title = "About", Text = "LunkaraUI is fully theme-driven and single-file."})

    -- Runtime theming:
    -- Window:SetTheme({Accent = Color3.fromRGB(220, 105, 125)})
    -- Window:SetTheme(Lunkara.Themes.Pearl)
    -- print(Window:EncodeFlags())
]]

return LunkaraUI
