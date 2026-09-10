 local library = {
	windowcount = 0;
}

local dragger = {};
local resizer = {};

do
	local mouse = game:GetService('Players').LocalPlayer:GetMouse();
	local inputService = game:GetService('UserInputService');
	local heartbeat = game:GetService('RunService').Heartbeat;
	function dragger.new(frame)
		local s, event = pcall(function()
			return frame.MouseEnter
		end)

		if s then
			frame.Active = true;

			event:connect(function()
				local input = frame.InputBegan:connect(function(key)
					if key.UserInputType == Enum.UserInputType.MouseButton1 or key.UserInputType == Enum.UserInputType.Touch then
						local objectPosition = Vector2.new(mouse.X - frame.AbsolutePosition.X, mouse.Y - frame.AbsolutePosition.Y);
						while heartbeat:wait() and inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) do
							frame:TweenPosition(UDim2.new(0, mouse.X - objectPosition.X + (frame.Size.X.Offset * frame.AnchorPoint.X), 0, mouse.Y - objectPosition.Y + (frame.Size.Y.Offset * frame.AnchorPoint.Y)), 'Out', 'Quad', 0.1, true);
						end
					end
				end)

				local leave;
				leave = frame.MouseLeave:connect(function()
					input:disconnect();
					leave:disconnect();
				end)
			end)
		end
	end
   
	function resizer.new(p, s)
		p:GetPropertyChangedSignal('AbsoluteSize'):connect(function()
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
	assert(options.text, 'no name');
	local window = {
		count = 0;
		toggles = {},
		closed = false;
	}

	local options = options or {};
	setmetatable(options, {__index = defaults})

	self.windowcount = self.windowcount + 1;

	library.gui = library.gui or self:Create('ScreenGui', {Name = 'UILibrary', Parent = game:GetService('CoreGui')})
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
		--Padding = UDim.new(0, 0);
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
	togglebutton.MouseButton1Click:connect(function()
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
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = titleText,
		Name = 'Window',
		Parent = titleContainer,
	})

	local textSize = game:GetService('TextService'):GetTextSize(titleText, 15, Enum.Font.FredokaOne, Vector2.new(math.huge, math.huge))

	if textSize.X > maxHeaderWidth then
		task.spawn(function()
			local display = titleText..'        '
			while task.wait(.2) and titleLabel and titleLabel.Parent do
				display = display:sub(2)..display:sub(1, 1)
				titleLabel.Text = display
			end
		end)
	end

	do
		dragger.new(window.frame)
		resizer.new(window.background, window.container);
	end

	local function getSize()
		local ySize = 0;
		for i, object in next, window.container:GetChildren() do
			if (not object:IsA('UIListLayout')) and (not object:IsA('UIPadding')) then
				ySize = ySize + object.AbsoluteSize.Y
			end
		end
		return UDim2.new(1, 0, 0, ySize + 10)
	end

	function window:Resize(tween, change)
		local size = change or getSize()
		self.container.ClipsDescendants = true;
	   
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

		callback = callback or function() end
		self.toggles[text] = default

		local label = library:Create('TextLabel', {
			Text =  text,
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = 1;
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Left;
			LayoutOrder = self.Count;
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

		button.MouseButton1Click:connect(function()
			self.toggles[text] = (not self.toggles[text])
			button.TextColor3 = (self.toggles[text] and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 25, 25))
			button.Text =(self.toggles[text] and 'ON' or 'OFF')

			callback(self.toggles[text])
		end)

		callback(default)

		self:Resize()
		return button
	end

	function window:AddBox(text, callback)
		self.count = self.count + 1
		callback = callback or function() end

		local box = library:Create('TextBox', {
			PlaceholderText = text,
			Size = UDim2.new(1, -10, 0, 20);
			--Position = UDim2.new(0, 5, 0, ((20 * self.count) - 20) + 5),
			BackgroundTransparency = 0.75;
			BackgroundColor3 = options.boxcolor,
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = 14,
			Text = '',
			Font = Enum.Font.FredokaOne,
			LayoutOrder = self.Count;
			BorderSizePixel = 0;
			Parent = self.container;
		})

		box.FocusLost:connect(function(...)
			callback(box, ...)
		end)

		self:Resize()
		return box
	end

	function window:AddButton(text, callback)
		self.count = self.count + 1

		callback = callback or function() end
		local button = library:Create('TextButton', {
			Text =  text,
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = .75;
			BackgroundColor3 = options.boxcolor or Color3.fromRGB(40, 40, 40);
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = 14,
			Font = Enum.Font.FredokaOne,
			BorderSizePixel = 0;
			LayoutOrder = self.Count;
			Parent = self.container;
		})

		button.MouseButton1Click:connect(callback)
		self:Resize()
		return button
	end
   
	function window:AddLabel(text)
		self.count = self.count + 1;
	   
		local tSize = game:GetService('TextService'):GetTextSize(text, 16, Enum.Font.FredokaOne, Vector2.new(math.huge, math.huge))

		local button = library:Create('TextLabel', {
			Text =  text,
			Size = UDim2.new(1, -10, 0, tSize.Y + 5);
			TextScaled = false;
			BackgroundTransparency = 1;
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Left;
			TextSize = 14,
			Font = Enum.Font.FredokaOne,
			LayoutOrder = self.Count;
			Parent = self.container;
		})

		self:Resize()
		return button
	end

	function window:AddDropdown(options, default, callback)
		self.count = self.count + 1

		if type(default) == 'function' then
			callback = default
			default = nil
		end

		callback = callback or function() end

		local dropdown = library:Create('TextLabel', {
			Size = UDim2.new(1, -10, 0, 20);
			BackgroundTransparency = .75;
			BackgroundColor3 = options.boxcolor or Color3.fromRGB(40, 40, 40);
			TextColor3 = Color3.fromRGB(255, 255, 255);
			TextXAlignment = Enum.TextXAlignment.Center;
			TextSize = 14,
			Text = default or 'Select...',
			Font = Enum.Font.FredokaOne,
			BorderSizePixel = 0;
			LayoutOrder = self.Count;
			Parent = self.container;
		})
		
		local button = library:Create('ImageButton',{
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
		end

		local function count(t)
			local c = 0;
			for i, v in next, t do
				c = c + 1
			end
			return c;
		end
		
		button.MouseButton1Click:connect(function()
			local totalCount = count(options)
			if totalCount == 0 then
				return
			end

			if frame then
				closeDropdown()
				return
			end
			
			self.container.ClipsDescendants = false;

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

			backdrop.MouseButton1Down:connect(function()
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

			for i, option in next, options do
				local selection = library:Create('TextButton', {
					Text = option;
					BackgroundColor3 = Color3.fromRGB(40, 40, 40);
					BackgroundTransparency = .5;
					TextColor3 = Color3.fromRGB(255, 255, 255);
					BorderSizePixel = 0;
					TextSize = 14;
					Font = Enum.Font.FredokaOne;
					Size = UDim2.new(1, -5, 0, itemHeight);
					LayoutOrder = i;
					AutoButtonColor = true;
					Parent = frame;
					ZIndex = 16;
				})
				
				selection.MouseButton1Click:connect(function()
					dropdown.Text = option;
					callback(option)
					closeDropdown()
				end)
			end
		end);
		
		if default ~= nil then
			callback(default);
		end

		self:Resize()
		return {
			Refresh = function(self, array, newDefault)
				closeDropdown()
				options = array
				if newDefault ~= nil then
					dropdown.Text = newDefault
					callback(newDefault)
				else
					dropdown.Text = 'Select...'
				end
			end
		}
	end
   
   function window:AddSlider(text, options, callback)
		self.count = self.count + 1

		local min = options.min or 0
		local max = options.max or 100
		local default = math.clamp(options.default or min, min, max)
		local precise = options.precise or false
		callback = callback or function() end

		local sliderContainer = library:Create('Frame', {
			Size = UDim2.new(1, -10, 0, 36);
			BackgroundTransparency = 1;
			BorderSizePixel = 0;
			LayoutOrder = self.Count;
			Parent = self.container;
		})

		local titleLabel = library:Create('TextLabel', {
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
			Text = tostring(default);
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
			Size = UDim2.new((default - min) / (max - min), 0, 1, 0);
			Position = UDim2.new(0, 0, 0, 0);
			BackgroundColor3 = Color3.fromRGB(0, 255, 140);
			BorderSizePixel = 0;
			Parent = barBack;
		})

		local dragging = false
		local UserInputService = game:GetService('UserInputService')

		local function update(input)
			local barPos = barBack.AbsolutePosition.X
			local barSize = barBack.AbsoluteSize.X
			local mouseX = input.Position.X
			local percent = math.clamp((mouseX - barPos) / barSize, 0, 1)

			local value = min + ((max - min) * percent)
			if not precise then
				value = math.floor(value + .5)
			else
				value = math.floor(value * 100) / 100
			end

			fillBar.Size = UDim2.new(percent, 0, 1, 0)
			valueLabel.Text = tostring(value)
			callback(value)
		end

		barBack.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				update(input)
			end
		end)

		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				update(input)
			end
		end)

		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = false
			end
		end)

		callback(default)
		self:Resize()

		return {
			Set = function(self, val)
				local clamped = math.clamp(val, min, max)
				local percent = (clamped - min) / (max - min)
				fillBar.Size = UDim2.new(percent, 0, 1, 0)
				valueLabel.Text = tostring(clamped)
				callback(clamped)
			end
		}
	end
	
	return window
end

return library
