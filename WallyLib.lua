local CoreGui = game:GetService('CoreGui')
local UserInputService = game:GetService('UserInputService')
local TextService = game:GetService('TextService')
local TweenService = game:GetService('TweenService')
local HttpService = game:GetService('HttpService')

local library = {
	windowcount = 0;
	running = true;
	connections = {};
	threads = {};
	unloadCallbacks = {};
	elements = {};
	configFolder = 'WallyLib';
	autosave = nil;
	loading = false;
	saveQueued = false;
}

local function canUseFiles()
	return type(writefile) == 'function' and type(readfile) == 'function' and type(isfile) == 'function'
end

function library:_register(key, element)
	self.elements[key] = element
end

function library:_queueSave()
	if not self.autosave or self.loading or self.saveQueued then
		return
	end
	self.saveQueued = true
	task.delay(0.5, function()
		self.saveQueued = false
		if self.running and self.autosave then
			self:SaveConfig(self.autosave)
		end
	end)
end

function library:SaveConfig(name)
	if not canUseFiles() then
		return false
	end
	local data = {}
	for key, element in pairs(self.elements) do
		local ok, value = pcall(element.Get, element)
		local t = type(value)
		if ok and (t == 'boolean' or t == 'number' or t == 'string') then
			data[key] = value
		end
	end
	if type(isfolder) == 'function' and type(makefolder) == 'function' and not isfolder(self.configFolder) then
		pcall(makefolder, self.configFolder)
	end
	local ok, err = pcall(writefile, self.configFolder .. '/' .. name .. '.json', HttpService:JSONEncode(data))
	if not ok then
		warn(err)
	end
	return ok
end

function library:LoadConfig(name)
	if not canUseFiles() then
		return false
	end
	local path = self.configFolder .. '/' .. name .. '.json'
	if not isfile(path) then
		return false
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(path))
	end)
	if not ok or type(data) ~= 'table' then
		return false
	end
	self.loading = true
	for key, value in pairs(data) do
		local element = self.elements[key]
		if element then
			local setOk, err = pcall(element.Set, element, value)
			if not setOk then
				warn(err)
			end
		end
	end
	self.loading = false
	return true
end

function library:AutoSave(name)
	self.autosave = name
	self:LoadConfig(name)
end

function library:Connect(signal, fn)
	local connection = signal:Connect(fn)
	table.insert(self.connections, connection)
	return connection
end

function library:Spawn(fn, ...)
	local thread = task.spawn(fn, ...)
	table.insert(self.threads, thread)
	return thread
end

function library:Loop(interval, fn)
	return self:Spawn(function()
		while self.running do
			local ok, err = pcall(fn)
			if not ok then
				warn(err)
			end
			task.wait(interval)
		end
	end)
end

function library:OnUnload(fn)
	table.insert(self.unloadCallbacks, fn)
end

function library:Unload()
	if not self.running then
		return
	end
	if self.autosave then
		pcall(self.SaveConfig, self, self.autosave)
	end
	self.running = false

	for _, fn in ipairs(self.unloadCallbacks) do
		local ok, err = pcall(fn)
		if not ok then
			warn(err)
		end
	end
	table.clear(self.unloadCallbacks)

	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)

	local current = coroutine.running()
	for _, thread in ipairs(self.threads) do
		if thread ~= current then
			pcall(task.cancel, thread)
		end
	end
	table.clear(self.threads)

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	if self.notifygui then
		self.notifygui:Destroy()
		self.notifygui = nil
	end

	if _G.WallyLib == self then
		_G.WallyLib = nil
	end
end

if type(_G.WallyLib) == 'table' and type(_G.WallyLib.Unload) == 'function' then
	pcall(_G.WallyLib.Unload, _G.WallyLib)
end
for _, name in ipairs({'UILibrary', 'UILibraryNotifications'}) do
	local old = CoreGui:FindFirstChild(name)
	while old do
		old:Destroy()
		old = CoreGui:FindFirstChild(name)
	end
end
_G.WallyLib = library

local dragger = {};
local resizer = {};

do
	function dragger.new(frame)
		frame.Active = true

		local dragging = false
		local dragInput = nil
		local dragStart = nil
		local startPos = nil

		frame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				dragStart = input.Position
				startPos = frame.Position

				local changed
				changed = input.Changed:Connect(function()
					if input.UserInputState == Enum.UserInputState.End then
						dragging = false
						changed:Disconnect()
					end
				end)
			end
		end)

		frame.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				dragInput = input
			end
		end)

		library:Connect(UserInputService.InputChanged, function(input)
			if input == dragInput and dragging then
				local delta = input.Position - dragStart
				frame.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end
		end)
	end

	function resizer.new(p, s)
		p:GetPropertyChangedSignal('AbsoluteSize'):Connect(function()
			s.Size = UDim2.new(s.Size.X.Scale, s.Size.X.Offset, s.Size.Y.Scale, p.AbsoluteSize.Y);
		end)
	end
end

local defaults = {
	txtcolor = Color3.fromRGB(255, 255, 255),
	underline = Color3.fromRGB(0, 255, 140),
	barcolor = Color3.fromRGB(40, 40, 40),
	bgcolor = Color3.fromRGB(30, 30, 30),
}

function library:Create(class, props)
	local object = Instance.new(class);

	for i, prop in next, props do
		if i ~= 'Parent' then
			object[i] = prop;
		end
	end

	object.Parent = props.Parent;
	return object;
end

function library:CreateWindow(options)
	options = options or {};
	assert(options.text, 'no name');
	setmetatable(options, {__index = defaults})

	local window = {
		count = 0;
		toggles = {},
		closed = false;
		openDropdown = nil;
	}

	self.windowcount = self.windowcount + 1;

	if not self.gui then
		self.gui = self:Create('ScreenGui', {
			Name = 'UILibrary',
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
			Parent = CoreGui,
		})
	end

	window.frame = self:Create('Frame', {
		Name = options.text;
		Parent = self.gui,
		Active = true,
		BackgroundTransparency = 0,
		Size = UDim2.new(0, 190, 0, 30),
		Position = UDim2.new(0, (15 + ((200 * self.windowcount) - 200)), 0, 15),
		BackgroundColor3 = options.barcolor,
		BorderSizePixel = 0;
	})

	window.background = self:Create('Frame', {
		Name = 'Background';
		Parent = window.frame,
		BorderSizePixel = 0;
		BackgroundColor3 = options.bgcolor,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 25),
		ClipsDescendants = true;
	})

	window.container = self:Create('Frame', {
		Name = 'Container';
		Parent = window.frame,
		BorderSizePixel = 0;
		BackgroundColor3 = options.bgcolor,
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 25),
		ClipsDescendants = true;
	})

	window.organizer = self:Create('UIListLayout', {
		Name = 'Sorter';
		SortOrder = Enum.SortOrder.LayoutOrder;
		Parent = window.container;
	})

	window.padder = self:Create('UIPadding', {
		Name = 'Padding';
		PaddingLeft = UDim.new(0, 10);
		PaddingTop = UDim.new(0, 5);
		Parent = window.container;
	})

	self:Create('Frame', {
		Name = 'Underline';
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1),
		BorderSizePixel = 0;
		BackgroundColor3 = options.underline;
		Parent = window.frame
	})

	local togglebutton = self:Create('TextButton', {
		Name = 'Toggle';
		ZIndex = 2,
		BackgroundTransparency = 1;
		Position = UDim2.new(1, -25, 0, 0),
		Size = UDim2.new(0, 25, 1, 0),
		Text = '-',
		TextSize = 17,
		TextColor3 = options.txtcolor,
		Font = Enum.Font.FredokaOne;
		Parent = window.frame,
	});

	togglebutton.MouseButton1Click:Connect(function()
		if window.openDropdown then
			window.openDropdown()
		end
		window.closed = not window.closed
		togglebutton.Text = (window.closed and '+' or '-')
		if window.closed then
			window:Resize(true, UDim2.new(1, 0, 0, 0))
		else
			window:Resize(true)
		end
	end)

	local titleText = options.text or 'window'
	local maxHeaderWidth = 155
	local textSize = TextService:GetTextSize(titleText, 15, Enum.Font.FredokaOne, Vector2.new(math.huge, math.huge))
	local scrolling = textSize.X > maxHeaderWidth

	local titleContainer = self:Create('Frame', {
		Name = 'TitleContainer',
		Size = UDim2.new(1, -35, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = window.frame,
	})

	local titleLabel = self:Create('TextLabel', {
		Size = UDim2.new(1, 0, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		TextColor3 = (options.bartextcolor or Color3.fromRGB(255, 255, 255)),
		TextSize = 15,
		Font = Enum.Font.FredokaOne,
		TextXAlignment = scrolling and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		Text = titleText,
		Name = 'Window',
		Parent = titleContainer,
	})

	if scrolling then
		library:Spawn(function()
			local display = titleText .. '        '
			while library.running and titleLabel.Parent do
				task.wait(0.2)
				display = display:sub(2) .. display:sub(1, 1)
				titleLabel.Text = display
			end
		end)
	end

	dragger.new(window.frame)
	resizer.new(window.background, window.container);

	local function getSize()
		local ySize = 0;
		for _, object in next, window.container:GetChildren() do
			if (not object:IsA('UIListLayout')) and (not object:IsA('UIPadding')) then
				ySize = ySize + object.AbsoluteSize.Y
			end
		end
		return UDim2.new(1, 0, 0, ySize + 10)
	end

	function window:Resize(tween, change)
		local size = change or getSize()
		if not self.openDropdown then
			self.container.ClipsDescendants = true;
		end

		if tween then
			self.background:TweenSize(size, 'Out', 'Sine', 0.5, true)
		else
			self.background.Size = size
		end
	end

	function window:AddToggle(text, default, callback)
		self.count = self.count + 1

		if type(default) == 'function' then
			callback = default
			default = false
		end

		default = default and true or false
		callback = callback or function() end
		self.toggles[text] = default

		local label = library:Create('TextLabel', {
			Text = text,
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = 1;
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Left;
			LayoutOrder = self.count;
			TextSize = 14,
			Font = Enum.Font.FredokaOne,
			Parent = self.container;
		})

		local button = library:Create('TextButton', {
			Text = default and 'ON' or 'OFF',
			TextColor3 = default and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 25, 25),
			BackgroundTransparency = 1;
			Position = UDim2.new(1, -25, 0, 0),
			Size = UDim2.new(0, 25, 1, 0),
			TextSize = 17,
			Font = Enum.Font.FredokaOne,
			Parent = label;
		})

		local function setState(state)
			state = state and true or false
			self.toggles[text] = state
			button.TextColor3 = (state and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 25, 25))
			button.Text = (state and 'ON' or 'OFF')
			callback(state)
			library:_queueSave()
		end

		button.MouseButton1Click:Connect(function()
			setState(not self.toggles[text])
		end)

		callback(default)

		local toggle = {
			Button = button,
			Set = function(_, state)
				if (state and true or false) ~= self.toggles[text] then
					setState(state)
				end
			end,
			Get = function()
				return self.toggles[text]
			end,
		}
		library:_register(options.text .. '/' .. text, toggle)

		self:Resize()
		return button, toggle
	end

	function window:AddBox(text, callback)
		self.count = self.count + 1
		callback = callback or function() end

		local box = library:Create('TextBox', {
			PlaceholderText = text,
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = 0.75;
			BackgroundColor3 = options.boxcolor or Color3.fromRGB(40, 40, 40),
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = 14,
			Text = '',
			Font = Enum.Font.FredokaOne,
			LayoutOrder = self.count;
			BorderSizePixel = 0;
			Parent = self.container;
		})

		box.FocusLost:Connect(function(...)
			callback(box, ...)
			library:_queueSave()
		end)

		library:_register(options.text .. '/' .. text, {
			Set = function(_, value)
				value = tostring(value or '')
				if box.Text ~= value then
					box.Text = value
					callback(box, false)
				end
			end,
			Get = function()
				return box.Text
			end,
		})

		self:Resize()
		return box
	end

	function window:AddButton(text, callback)
		self.count = self.count + 1

		callback = callback or function() end
		local button = library:Create('TextButton', {
			Text = text,
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = .75;
			BackgroundColor3 = options.boxcolor or Color3.fromRGB(40, 40, 40);
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = 14,
			Font = Enum.Font.FredokaOne,
			BorderSizePixel = 0;
			LayoutOrder = self.count;
			Parent = self.container;
		})

		button.MouseButton1Click:Connect(callback)
		self:Resize()
		return button
	end

	function window:AddLabel(text)
		self.count = self.count + 1;

		local tSize = TextService:GetTextSize(text, 16, Enum.Font.FredokaOne, Vector2.new(math.huge, math.huge))

		local label = library:Create('TextLabel', {
			Text = text,
			Size = UDim2.new(1, -10, 0, tSize.Y + 5);
			TextScaled = false;
			BackgroundTransparency = 1;
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextSize = 14,
			Font = Enum.Font.FredokaOne,
			LayoutOrder = self.count;
			Parent = self.container;
		})

		self:Resize()
		return label
	end

	function window:AddDropdown(list, default, callback)
		self.count = self.count + 1

		if type(default) == 'function' then
			callback = default
			default = nil
		end

		list = list or {}
		callback = callback or function() end
		local currentSelected = default

		local dropdown = library:Create('TextLabel', {
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = .75;
			BackgroundColor3 = options.boxcolor or Color3.fromRGB(40, 40, 40);
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = 14,
			Text = default ~= nil and tostring(default) or 'Select...',
			Font = Enum.Font.FredokaOne,
			BorderSizePixel = 0;
			LayoutOrder = self.count;
			Parent = self.container;
		})

		local button = library:Create('ImageButton', {
			BackgroundTransparency = 1;
			Image = 'rbxassetid://3234893186';
			Size = UDim2.new(0, 18, 1, 0);
			Position = UDim2.new(1, -20, 0, 0);
			Parent = dropdown;
		})

		local frame;
		local backdrop;

		local function closeDropdown()
			if frame then
				frame:Destroy()
				frame = nil
			end
			if backdrop then
				backdrop:Destroy()
				backdrop = nil
			end
			if window.openDropdown == closeDropdown then
				window.openDropdown = nil
				window.container.ClipsDescendants = true
			end
		end

		local function countItems(t)
			local c = 0;
			for _ in next, t do
				c = c + 1
			end
			return c;
		end

		button.MouseButton1Click:Connect(function()
			if frame then
				closeDropdown()
				return
			end

			local totalCount = countItems(list)
			if totalCount == 0 then
				return
			end

			if window.openDropdown then
				window.openDropdown()
			end
			window.openDropdown = closeDropdown
			window.container.ClipsDescendants = false;

			local itemHeight = 21
			local maxVisibleItems = 6
			local displayItems = math.min(totalCount, maxVisibleItems)
			local frameHeight = displayItems * itemHeight

			backdrop = library:Create('TextButton', {
				Name = 'DropdownBackdrop',
				Size = UDim2.new(1, 0, 1, 0),
				Position = UDim2.new(0, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = '',
				ZIndex = 14,
				Parent = library.gui,
			})

			backdrop.MouseButton1Down:Connect(function()
				closeDropdown()
			end)

			frame = library:Create('ScrollingFrame', {
				Position = UDim2.new(1, 5, 0, 0);
				BackgroundColor3 = Color3.fromRGB(30, 30, 30);
				Size = UDim2.new(0, dropdown.AbsoluteSize.X, 0, frameHeight);
				CanvasSize = UDim2.new(0, 0, 0, (totalCount * itemHeight) + 5);
				ScrollBarThickness = 4;
				ScrollBarImageColor3 = Color3.fromRGB(0, 255, 140);
				BorderSizePixel = 0;
				ScrollingEnabled = true;
				ScrollingDirection = Enum.ScrollingDirection.Y;
				Active = true;
				Selectable = false;
				ElasticBehavior = Enum.ElasticBehavior.WhenScrollable;
				Parent = dropdown;
				ClipsDescendants = true;
				ZIndex = 15;
			})

			library:Create('UIListLayout', {
				Name = 'Layout';
				SortOrder = Enum.SortOrder.LayoutOrder;
				Parent = frame;
			})

			local selectedIndex = nil
			local position = 0

			for _, option in next, list do
				position = position + 1
				if option == currentSelected then
					selectedIndex = position
				end

				local selection = library:Create('TextButton', {
					Text = tostring(option);
					BackgroundColor3 = Color3.fromRGB(40, 40, 40);
					BackgroundTransparency = (option == currentSelected and .25) or .5;
					TextColor3 = (option == currentSelected and Color3.fromRGB(0, 255, 140)) or Color3.fromRGB(255, 255, 255);
					BorderSizePixel = 0;
					TextSize = 14;
					Font = Enum.Font.FredokaOne;
					Size = UDim2.new(1, -5, 0, itemHeight);
					LayoutOrder = position;
					AutoButtonColor = true;
					Parent = frame;
					ZIndex = 16;
				})

				selection.MouseButton1Click:Connect(function()
					currentSelected = option
					dropdown.Text = tostring(option);
					callback(option)
					closeDropdown()
					library:_queueSave()
				end)
			end

			if selectedIndex then
				local maxScroll = math.max(0, (totalCount * itemHeight + 5) - frameHeight)
				local targetY = math.clamp((selectedIndex - 1) * itemHeight, 0, maxScroll)
				frame.CanvasPosition = Vector2.new(0, targetY)
			end
		end);

		if default ~= nil then
			callback(default);
		end

		local dropdownObject = {
			Refresh = function(_, array, newDefault)
				closeDropdown()
				list = array or {}
				if newDefault ~= nil then
					currentSelected = newDefault
					dropdown.Text = tostring(newDefault)
					callback(newDefault)
				else
					currentSelected = nil
					dropdown.Text = 'Select...'
				end
				library:_queueSave()
			end,
			Set = function(_, value)
				if value ~= nil and value ~= currentSelected then
					currentSelected = value
					dropdown.Text = tostring(value)
					callback(value)
					library:_queueSave()
				end
			end,
			Get = function()
				return currentSelected
			end,
		}
		library:_register(options.text .. '/dropdown' .. self.count, dropdownObject)

		self:Resize()
		return dropdownObject
	end

	function window:AddSlider(text, opts, callback)
		self.count = self.count + 1

		opts = opts or {}
		local min = opts.min or 0
		local max = opts.max or 100
		if max < min then
			min, max = max, min
		end
		local range = max - min
		local precise = opts.precise or false
		callback = callback or function() end

		local function round(v)
			if precise then
				return math.floor(v * 100 + 0.5) / 100
			end
			return math.floor(v + 0.5)
		end

		local function clampRound(v)
			return math.clamp(round(math.clamp(v, min, max)), min, max)
		end

		local function toPercent(v)
			if range == 0 then
				return 0
			end
			return (v - min) / range
		end

		local value = clampRound(opts.default or min)

		local sliderContainer = library:Create('Frame', {
			Size = UDim2.new(1, -10, 0, 36);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			LayoutOrder = self.count;
			Parent = self.container;
		})

		library:Create('TextLabel', {
			Size = UDim2.new(1, -50, 0, 16);
			Position = UDim2.new(0, 0, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextSize = 14;
			Font = Enum.Font.FredokaOne;
			Text = text;
			Parent = sliderContainer;
		})

		local valueLabel = library:Create('TextLabel', {
			Size = UDim2.new(0, 50, 0, 16);
			Position = UDim2.new(1, -50, 0, 0);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			TextColor3 = Color3.fromRGB(0, 255, 140);
			TextXAlignment = Enum.TextXAlignment.Right;
			TextSize = 14;
			Font = Enum.Font.FredokaOne;
			Text = tostring(value);
			Parent = sliderContainer;
		})

		local barBack = library:Create('TextButton', {
			Size = UDim2.new(1, 0, 0, 14);
			Position = UDim2.new(0, 0, 0, 18);
			BackgroundColor3 = Color3.fromRGB(40, 40, 40);
			BackgroundTransparency = .75;
			BorderSizePixel = 0;
			AutoButtonColor = false;
			Text = '';
			Parent = sliderContainer;
		})

		local fillBar = library:Create('Frame', {
			Size = UDim2.new(toPercent(value), 0, 1, 0);
			Position = UDim2.new(0, 0, 0, 0);
			BackgroundColor3 = Color3.fromRGB(0, 255, 140);
			BorderSizePixel = 0;
			Parent = barBack;
		})

		local function setValue(v, force)
			v = clampRound(v)
			fillBar.Size = UDim2.new(toPercent(v), 0, 1, 0)
			valueLabel.Text = tostring(v)
			if force or v ~= value then
				value = v
				callback(v)
				library:_queueSave()
			end
		end

		local dragging = false

		local function update(input)
			local barSize = barBack.AbsoluteSize.X
			if barSize <= 0 then
				return
			end
			local percent = math.clamp((input.Position.X - barBack.AbsolutePosition.X) / barSize, 0, 1)
			setValue(min + range * percent)
		end

		barBack.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				update(input)
			end
		end)

		library:Connect(UserInputService.InputChanged, function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				update(input)
			end
		end)

		library:Connect(UserInputService.InputEnded, function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		callback(value)
		self:Resize()

		library:_register(options.text .. '/' .. text, {
			Set = function(_, val)
				if type(val) == 'number' then
					setValue(val)
				end
			end,
			Get = function()
				return value
			end,
		})

		return {
			Set = function(_, val)
				setValue(val, true)
			end,
			Get = function()
				return value
			end,
		}
	end

	return window
end

do
	library.NotifySettings = {
		Width = 250,
		MaxVisible = 5,
		Bar = Color3.fromRGB(40, 40, 40),
		Background = Color3.fromRGB(30, 30, 30),
		TitleColor = Color3.fromRGB(255, 255, 255),
		TextColor = Color3.fromRGB(200, 200, 200),
		Font = Enum.Font.FredokaOne,
		Types = {
			default = Color3.fromRGB(0, 255, 140),
			success = Color3.fromRGB(0, 255, 140),
			info = Color3.fromRGB(70, 160, 255),
			warning = Color3.fromRGB(255, 190, 40),
			error = Color3.fromRGB(255, 25, 25),
		},
	}

	local holder
	local active = {}
	local order = 0

	local function getHolder()
		if holder and library.notifygui and holder.Parent == library.notifygui then
			return holder
		end
		library.notifygui = library:Create('ScreenGui', {
			Name = 'UILibraryNotifications',
			DisplayOrder = 999,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = CoreGui,
		})
		holder = library:Create('Frame', {
			Name = 'Holder',
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -12, 1, -12),
			Size = UDim2.new(0, library.NotifySettings.Width, 1, -24),
			BackgroundTransparency = 1,
			Parent = library.notifygui,
		})
		library:Create('UIListLayout', {
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			Padding = UDim.new(0, 6),
			Parent = holder,
		})
		return holder
	end

	function library:Notify(title, text, duration)
		if not library.running then
			return { Close = function() end }
		end

		local s = library.NotifySettings
		local opts
		if type(title) == 'table' then
			opts = title
		else
			opts = { Title = title, Text = text, Duration = duration }
		end

		local ntype = string.lower(tostring(opts.Type or 'default'))
		local accent = opts.Color or s.Types[ntype] or s.Types.default
		local dur = opts.Duration
		if dur == nil then
			dur = 5
		end
		local persistent = (dur <= 0 or dur == math.huge)
		local buttons = opts.Buttons
		if buttons and #buttons == 0 then
			buttons = nil
		end
		local body = tostring(opts.Text or '')
		local width = s.Width

		local textH = 0
		if body ~= '' then
			textH = TextService:GetTextSize(body, 14, s.Font, Vector2.new(width - 16, 10000)).Y
		end
		local height = 28
		if textH > 0 then
			height = height + 8 + textH
		end
		if buttons then
			height = height + 8 + 24
		end
		height = height + 8
		if not persistent then
			height = height + 2
		end

		order = order + 1
		local parent = getHolder()

		local slot = library:Create('Frame', {
			Name = 'Notification',
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = parent,
		})

		local card = library:Create('Frame', {
			Name = 'Card',
			Size = UDim2.new(1, 0, 0, height),
			Position = UDim2.new(1, 20, 0, 0),
			BackgroundColor3 = s.Background,
			BorderSizePixel = 0,
			Active = true,
			Parent = slot,
		})

		local bar = library:Create('Frame', {
			Name = 'Bar',
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundColor3 = s.Bar,
			BorderSizePixel = 0,
			Parent = card,
		})

		library:Create('TextLabel', {
			Name = 'Title',
			Position = UDim2.new(0, 8, 0, 0),
			Size = UDim2.new(1, -34, 1, 0),
			BackgroundTransparency = 1,
			Text = tostring(opts.Title or 'Notification'),
			TextColor3 = s.TitleColor,
			Font = s.Font,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = bar,
		})

		local closeBtn = library:Create('TextButton', {
			Name = 'Close',
			Position = UDim2.new(1, -26, 0, 0),
			Size = UDim2.new(0, 26, 0, 26),
			BackgroundTransparency = 1,
			Text = 'x',
			TextColor3 = s.TitleColor,
			Font = s.Font,
			TextSize = 17,
			Parent = bar,
		})

		library:Create('Frame', {
			Name = 'Underline',
			Position = UDim2.new(0, 0, 0, 26),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Parent = card,
		})

		local y = 28
		if textH > 0 then
			library:Create('TextLabel', {
				Name = 'Body',
				Position = UDim2.new(0, 8, 0, y + 8),
				Size = UDim2.new(1, -16, 0, textH),
				BackgroundTransparency = 1,
				Text = body,
				TextColor3 = s.TextColor,
				Font = s.Font,
				TextSize = 14,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Parent = card,
			})
			y = y + 8 + textH
		end

		local notif = {}
		local closed = false
		local timer

		function notif:Close()
			if closed then
				return
			end
			closed = true
			if timer then
				timer:Cancel()
			end
			for i, v in ipairs(active) do
				if v == notif then
					table.remove(active, i)
					break
				end
			end
			TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
				Position = UDim2.new(1, 20, 0, 0),
			}):Play()
			task.delay(0.25, function()
				if not slot.Parent then
					return
				end
				TweenService:Create(slot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
					Size = UDim2.new(1, 0, 0, 0),
				}):Play()
				task.delay(0.2, function()
					slot:Destroy()
				end)
			end)
		end

		if buttons then
			local n = #buttons
			local bw = (width - 16 - 6 * (n - 1)) / n
			for i, label in ipairs(buttons) do
				local b = library:Create('TextButton', {
					Name = 'Button_' .. tostring(label),
					Position = UDim2.new(0, 8 + (i - 1) * (bw + 6), 0, y + 8),
					Size = UDim2.new(0, bw, 0, 24),
					BackgroundColor3 = s.Bar,
					BorderSizePixel = 0,
					AutoButtonColor = false,
					Text = tostring(label),
					TextColor3 = s.TitleColor,
					Font = s.Font,
					TextSize = 14,
					Parent = card,
				})
				b.MouseEnter:Connect(function()
					b.TextColor3 = accent
				end)
				b.MouseLeave:Connect(function()
					b.TextColor3 = s.TitleColor
				end)
				b.MouseButton1Click:Connect(function()
					if closed then
						return
					end
					if opts.Callback then
						task.spawn(opts.Callback, label)
					end
					notif:Close()
				end)
			end
		end

		closeBtn.MouseButton1Click:Connect(function()
			notif:Close()
		end)

		if not persistent then
			local progress = library:Create('Frame', {
				Name = 'Progress',
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, 0, 0, 2),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Parent = card,
			})
			timer = TweenService:Create(progress, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
				Size = UDim2.new(0, 0, 0, 2),
			})
			timer.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					notif:Close()
				end
			end)
			card.MouseEnter:Connect(function()
				if not closed then
					timer:Pause()
				end
			end)
			card.MouseLeave:Connect(function()
				if not closed then
					timer:Play()
				end
			end)
		end

		TweenService:Create(slot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
			Size = UDim2.new(1, 0, 0, height),
		}):Play()
		TweenService:Create(card, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, 0, 0, 0),
		}):Play()
		if timer then
			timer:Play()
		end

		table.insert(active, notif)
		while #active > s.MaxVisible do
			active[1]:Close()
		end

		return notif
	end
end

return library
