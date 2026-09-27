-- XYZ developer test panel. Place this single LocalScript in StarterPlayerScripts.
-- Add trusted tester UserIds below to enable the panel outside Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local ALLOWED_USER_IDS = {}

if not RunService:IsStudio() and not table.find(ALLOWED_USER_IDS, player.UserId) then
	return
end

local COLORS = {
	background = Color3.fromRGB(14, 18, 24),
	panel = Color3.fromRGB(21, 27, 35),
	row = Color3.fromRGB(26, 33, 43),
	raised = Color3.fromRGB(34, 43, 54),
	border = Color3.fromRGB(48, 61, 76),
	text = Color3.fromRGB(231, 237, 244),
	muted = Color3.fromRGB(143, 156, 172),
	accent = Color3.fromRGB(74, 196, 153),
	accentDim = Color3.fromRGB(37, 105, 83),
	danger = Color3.fromRGB(229, 91, 91),
}

local DEFAULTS = {
	aimAssist = false, targetLock = false, aimFov = 150, smoothness = 8,
	targetSelection = "Closest to crosshair",
	playerESP = false, espBox = true, espSkeleton = false, espName = true,
	espDistance = true, espHealth = true, espTracer = false,
	recoilTest = false, spreadTest = false, fireRate = 600, ammoTest = 30, damageTest = 25,
	speedTest = false, testSpeed = 24, jumpTest = false, testJumpPower = 60,
	movementDebug = false, noclipTest = false,
	cameraFov = 70, crosshair = true, cameraEffects = false, thirdPerson = false,
	hitboxVisualization = false, hitboxSize = 4, headPriority = true,
	hitboxDebug = false,
	toggleKey = "RightShift", aimKey = "None", lockKey = "None", dashKey = "None",
}

local SETTINGS_ATTRIBUTE = "XYZ_Settings"
local setting = table.clone(DEFAULTS)
local simulatedAmmo = setting.ammoTest
local destroyed = false
local panelOpen = true
local minimized = false
local currentCategory = "AIM"
local capturingKey = nil
local activeSlider = nil
local targetLockPlayer = nil
local savedCameraFov = nil
local savedCameraMode = nil
local savedZoom = nil
local savedLightingEffect = nil
local savedHumanoid = nil
local savedMovement = nil
local savedCollisions = {}
local noclipConnection = nil
local lastAimTime = 0
local renderElapsed = 0
local globalConnections = {}
local espByPlayer = {}
local hitboxByPlayer = {}

local function track(connection)
	table.insert(globalConnections, connection)
	return connection
end

local function make(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function animate(instance, duration, properties)
	local animation = TweenService:Create(
		instance,
		TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		properties
	)
	animation:Play()
	return animation
end

local gui = make("ScreenGui", {
	Name = "XYZDeveloperPanel",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local scale = make("UIScale", { Scale = 1 }, gui)
local main = make("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(740, 490),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 10) }, main)
make("UIStroke", { Color = COLORS.border, Thickness = 1 }, main)

local top = make("Frame", {
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
}, main)
make("TextLabel", {
	Position = UDim2.fromOffset(18, 0),
	Size = UDim2.fromOffset(55, 54),
	BackgroundTransparency = 1,
	Text = "XYZ",
	TextColor3 = COLORS.text,
	TextSize = 22,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, top)
make("TextLabel", {
	Position = UDim2.fromOffset(68, 2),
	Size = UDim2.fromOffset(210, 52),
	BackgroundTransparency = 1,
	Text = "DEVELOPER TEST PANEL",
	TextColor3 = COLORS.muted,
	TextSize = 10,
	Font = Enum.Font.GothamMedium,
	TextXAlignment = Enum.TextXAlignment.Left,
}, top)

local minimizeButton = make("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -16, 0.5, 0),
	Size = UDim2.fromOffset(34, 30),
	BackgroundColor3 = COLORS.raised,
	BorderSizePixel = 0,
	Text = "—",
	TextColor3 = COLORS.text,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
}, top)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, minimizeButton)

local sidebar = make("Frame", {
	Position = UDim2.fromOffset(0, 54),
	Size = UDim2.new(0, 158, 1, -54),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
}, main)
local categoryList = make("Frame", {
	Position = UDim2.fromOffset(10, 12),
	Size = UDim2.new(1, -20, 1, -24),
	BackgroundTransparency = 1,
}, sidebar)
make("UIListLayout", { Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder }, categoryList)

local content = make("Frame", {
	Position = UDim2.fromOffset(158, 54),
	Size = UDim2.new(1, -158, 1, -54),
	BackgroundColor3 = COLORS.background,
	BorderSizePixel = 0,
}, main)
local search = make("TextBox", {
	Position = UDim2.fromOffset(18, 14),
	Size = UDim2.new(1, -36, 0, 36),
	BackgroundColor3 = COLORS.panel,
	BorderSizePixel = 0,
	PlaceholderText = "Search settings...",
	PlaceholderColor3 = COLORS.muted,
	Text = "",
	TextColor3 = COLORS.text,
	TextSize = 13,
	Font = Enum.Font.Gotham,
	ClearTextOnFocus = false,
	TextXAlignment = Enum.TextXAlignment.Left,
}, content)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, search)
make("UIPadding", { PaddingLeft = UDim.new(0, 11), PaddingRight = UDim.new(0, 10) }, search)

local categoryTitle = make("TextLabel", {
	Position = UDim2.fromOffset(18, 59),
	Size = UDim2.new(1, -36, 0, 25),
	BackgroundTransparency = 1,
	Text = currentCategory,
	TextColor3 = COLORS.text,
	TextSize = 16,
	Font = Enum.Font.GothamBold,
	TextXAlignment = Enum.TextXAlignment.Left,
}, content)
local scroll = make("ScrollingFrame", {
	Position = UDim2.fromOffset(18, 91),
	Size = UDim2.new(1, -36, 1, -108),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = COLORS.border,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, content)
local rowLayout = make("UIListLayout", {
	Padding = UDim.new(0, 7),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, scroll)

local toastHolder = make("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -16, 0, 16),
	Size = UDim2.fromOffset(280, 220),
	BackgroundTransparency = 1,
}, gui)
make("UIListLayout", {
	Padding = UDim.new(0, 7),
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
	SortOrder = Enum.SortOrder.LayoutOrder,
}, toastHolder)

local function notify(message)
	local card = make("Frame", {
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
	}, toastHolder)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, card)
	make("UIStroke", { Color = COLORS.border, Thickness = 1 }, card)
	make("Frame", {
		Position = UDim2.fromOffset(7, 6),
		Size = UDim2.new(0, 3, 1, -12),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, card)
	make("TextLabel", {
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -25, 1, 0),
		BackgroundTransparency = 1,
		Text = message,
		TextColor3 = COLORS.text,
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	task.delay(3, function()
		if card.Parent then
			animate(card, 0.18, { BackgroundTransparency = 1, Position = card.Position + UDim2.fromOffset(12, 0) })
			task.wait(0.2)
			if card.Parent then card:Destroy() end
		end
	end)
end

local categories = { "AIM", "ESP", "WEAPON", "PLAYER", "VISUALS", "HITBOX", "CONFIG" }
local controls = {
	AIM = {
		{ name = "Aim Assist", kind = "toggle", key = "aimAssist" },
		{ name = "Target Lock", kind = "toggle", key = "targetLock" },
		{ name = "FOV", kind = "slider", key = "aimFov", min = 50, max = 500, suffix = " px" },
		{ name = "Smoothness", kind = "slider", key = "smoothness", min = 1, max = 20 },
		{ name = "Target Selection", kind = "dropdown", key = "targetSelection",
			options = { "Closest to crosshair", "Closest distance", "Lowest health" } },
		{ name = "Aim Assist Key", kind = "keybind", key = "aimKey" },
		{ name = "Target Lock Key", kind = "keybind", key = "lockKey" },
	},
	ESP = {
		{ name = "Player ESP", kind = "toggle", key = "playerESP" },
		{ name = "Box", kind = "toggle", key = "espBox" },
		{ name = "Skeleton", kind = "toggle", key = "espSkeleton" },
		{ name = "Name", kind = "toggle", key = "espName" },
		{ name = "Distance", kind = "toggle", key = "espDistance" },
		{ name = "Health", kind = "toggle", key = "espHealth" },
		{ name = "Tracer", kind = "toggle", key = "espTracer" },
	},
	WEAPON = {
		{ name = "Recoil Test", kind = "toggle", key = "recoilTest" },
		{ name = "Spread Test", kind = "toggle", key = "spreadTest" },
		{ name = "Fire Rate", kind = "slider", key = "fireRate", min = 60, max = 1200, suffix = " RPM" },
		{ name = "Reload Test", kind = "button", action = "reload" },
		{ name = "Ammo Test", kind = "slider", key = "ammoTest", min = 1, max = 200 },
		{ name = "Damage Test", kind = "slider", key = "damageTest", min = 1, max = 200 },
	},
	PLAYER = {
		{ name = "Speed Test", kind = "toggle", key = "speedTest" },
		{ name = "Test Speed", kind = "slider", key = "testSpeed", min = 8, max = 100 },
		{ name = "Jump Test", kind = "toggle", key = "jumpTest" },
		{ name = "Test Jump Power", kind = "slider", key = "testJumpPower", min = 25, max = 150 },
		{ name = "Dash", kind = "button", action = "dash" },
		{ name = "Movement Debug", kind = "toggle", key = "movementDebug" },
		{ name = "Noclip Test", kind = "toggle", key = "noclipTest" },
		{ name = "Dash Key", kind = "keybind", key = "dashKey" },
	},
	VISUALS = {
		{ name = "Camera FOV", kind = "slider", key = "cameraFov", min = 50, max = 120 },
		{ name = "Crosshair", kind = "toggle", key = "crosshair" },
		{ name = "Hitmarker", kind = "button", action = "hitmarker" },
		{ name = "Camera Effects", kind = "toggle", key = "cameraEffects" },
		{ name = "Third Person", kind = "toggle", key = "thirdPerson" },
	},
	HITBOX = {
		{ name = "Hitbox Visualization", kind = "toggle", key = "hitboxVisualization" },
		{ name = "Hitbox Size", kind = "slider", key = "hitboxSize", min = 1, max = 12 },
		{ name = "Head Priority", kind = "toggle", key = "headPriority" },
		{ name = "Hitbox Debug", kind = "toggle", key = "hitboxDebug" },
	},
	CONFIG = {
		{ name = "Save Settings", kind = "button", action = "save" },
		{ name = "Load Settings", kind = "button", action = "load" },
		{ name = "Reset Settings", kind = "button", action = "reset" },
		{ name = "Panel Toggle Key", kind = "keybind", key = "toggleKey" },
	},
}

local categoriesByButton = {}
local refreshCategory

local crosshair = make("Frame", {
	Name = "XYZCrosshair",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(20, 20),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 20,
}, gui)
make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(2, 14), BackgroundColor3 = COLORS.accent, BorderSizePixel = 0,
}, crosshair)
make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(14, 2), BackgroundColor3 = COLORS.accent, BorderSizePixel = 0,
}, crosshair)

local hitmarker = make("TextLabel", {
	Name = "XYZHitmarker",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(46, 46),
	BackgroundTransparency = 1,
	Text = "×",
	TextColor3 = COLORS.danger,
	TextSize = 38,
	Font = Enum.Font.GothamBold,
	TextTransparency = 1,
	Visible = false,
	ZIndex = 21,
}, gui)

local fovCircle = make("Frame", {
	Name = "XYZAimFOV",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(setting.aimFov * 2, setting.aimFov * 2),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 2,
}, gui)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, fovCircle)
make("UIStroke", { Color = COLORS.accent, Transparency = 0.5, Thickness = 1 }, fovCircle)

local debugText = make("TextLabel", {
	Name = "XYZMovementDebug",
	Position = UDim2.new(0, 14, 1, -84),
	Size = UDim2.fromOffset(235, 58),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Text = "",
	TextColor3 = COLORS.text,
	TextSize = 12,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	ZIndex = 10,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, debugText)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, debugText)

local hitboxDebugText = make("TextLabel", {
	Name = "XYZHitboxDebug",
	Position = UDim2.new(0, 14, 1, -150),
	Size = UDim2.fromOffset(235, 54),
	BackgroundColor3 = COLORS.panel,
	BackgroundTransparency = 0.08,
	BorderSizePixel = 0,
	Text = "",
	TextColor3 = COLORS.text,
	TextSize = 12,
	Font = Enum.Font.Code,
	TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false,
	ZIndex = 10,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 6) }, hitboxDebugText)
make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, hitboxDebugText)

local function updateScale()
	local camera = workspace.CurrentCamera
	if camera then
		local viewport = camera.ViewportSize
		scale.Scale = math.clamp(math.min(viewport.X / 770, viewport.Y / 520), 0.48, 1)
	end
end

local function setPanelVisible(visible)
	panelOpen = visible
	main.Visible = visible
end

local function setMinimized(value)
	minimized = value
	sidebar.Visible = not value
	content.Visible = not value
	minimizeButton.Text = value and "+" or "—"
	animate(main, 0.2, { Size = value and UDim2.fromOffset(740, 54) or UDim2.fromOffset(740, 490) })
end

track(minimizeButton.Activated:Connect(function()
	setMinimized(not minimized)
end))

local dragging = false
local dragOrigin
local windowOrigin
track(top.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragOrigin = input.Position
		windowOrigin = main.Position
	end
end))

local function saveCharacterState()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and savedHumanoid ~= humanoid then
		savedHumanoid = humanoid
		savedMovement = {
			walkSpeed = humanoid.WalkSpeed,
			useJumpPower = humanoid.UseJumpPower,
			jumpPower = humanoid.JumpPower,
			jumpHeight = humanoid.JumpHeight,
		}
	end
	return character, humanoid
end

local function restoreMovement()
	if savedHumanoid and savedHumanoid.Parent and savedMovement then
		savedHumanoid.WalkSpeed = savedMovement.walkSpeed
		savedHumanoid.UseJumpPower = savedMovement.useJumpPower
		savedHumanoid.JumpPower = savedMovement.jumpPower
		savedHumanoid.JumpHeight = savedMovement.jumpHeight
	end
	savedHumanoid = nil
	savedMovement = nil
	for part, collision in pairs(savedCollisions) do
		if part.Parent then part.CanCollide = collision end
		savedCollisions[part] = nil
	end
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
end

local function updateMovement()
	local character, humanoid = saveCharacterState()
	if not character or not humanoid then return end

	if setting.speedTest then
		humanoid.WalkSpeed = setting.testSpeed
	elseif savedMovement then
		humanoid.WalkSpeed = savedMovement.walkSpeed
	end

	if setting.jumpTest then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = setting.testJumpPower
	elseif savedMovement then
		humanoid.UseJumpPower = savedMovement.useJumpPower
		humanoid.JumpPower = savedMovement.jumpPower
		humanoid.JumpHeight = savedMovement.jumpHeight
	end

	if setting.noclipTest and not noclipConnection then
		noclipConnection = RunService.Stepped:Connect(function()
			local current = player.Character
			if not current then return end
			for _, part in ipairs(current:GetDescendants()) do
				if part:IsA("BasePart") and savedCollisions[part] == nil then
					savedCollisions[part] = part.CanCollide
					part.CanCollide = false
				end
			end
		end)
	elseif not setting.noclipTest and noclipConnection then
		for part, collision in pairs(savedCollisions) do
			if part.Parent then part.CanCollide = collision end
			savedCollisions[part] = nil
		end
		noclipConnection:Disconnect()
		noclipConnection = nil
	end
end

local function updateCameraEffects()
	if setting.cameraEffects then
		if not savedLightingEffect then
			savedLightingEffect = make("ColorCorrectionEffect", {
				Name = "XYZCameraTestEffect",
				TintColor = Color3.fromRGB(225, 245, 235),
				Saturation = -0.12,
				Contrast = 0.04,
			}, Lighting)
		end
	elseif savedLightingEffect then
		savedLightingEffect:Destroy()
		savedLightingEffect = nil
	end
end

local function updateThirdPerson()
	if setting.thirdPerson then
		if not savedCameraMode then
			savedCameraMode = player.CameraMode
			savedZoom = { min = player.CameraMinZoomDistance, max = player.CameraMaxZoomDistance }
		end
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = 6
		player.CameraMaxZoomDistance = 16
	elseif savedCameraMode then
		player.CameraMode = savedCameraMode
		player.CameraMinZoomDistance = savedZoom.min
		player.CameraMaxZoomDistance = savedZoom.max
		savedCameraMode = nil
		savedZoom = nil
	end
end

local function publishTestSettings()
	-- Local attributes are a bridge for other client scripts in the same game.
	for key, value in pairs(setting) do
		player:SetAttribute("XYZ_" .. key, value)
	end
	player:SetAttribute("XYZ_simulatedAmmo", simulatedAmmo)
end

local function afterSettingChanged(key)
	if key == "speedTest" or key == "testSpeed" or key == "jumpTest"
		or key == "testJumpPower" or key == "noclipTest" then
		updateMovement()
	elseif key == "cameraFov" then
		local camera = workspace.CurrentCamera
		if camera then
			if savedCameraFov == nil then savedCameraFov = camera.FieldOfView end
			camera.FieldOfView = setting.cameraFov
		end
	elseif key == "cameraEffects" then
		updateCameraEffects()
	elseif key == "thirdPerson" then
		updateThirdPerson()
	elseif key == "aimFov" then
		fovCircle.Size = UDim2.fromOffset(setting.aimFov * 2, setting.aimFov * 2)
	elseif key == "ammoTest" then
		simulatedAmmo = setting.ammoTest
	end
	publishTestSettings()
end

local function showHitmarker()
	hitmarker.Visible = true
	hitmarker.TextTransparency = 0
	hitmarker.Rotation = math.random(-12, 12)
	animate(hitmarker, 0.4, { TextTransparency = 1, Rotation = 0 })
	task.delay(0.42, function()
		if hitmarker.Parent then hitmarker.Visible = false end
	end)
end

local function action(name)
	if name == "hitmarker" then
		showHitmarker()
		notify("Hitmarker preview")
	elseif name == "dash" then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local direction = root.CFrame.LookVector
			root.AssemblyLinearVelocity = Vector3.new(direction.X * 65, root.AssemblyLinearVelocity.Y, direction.Z * 65)
			notify("Local dash test")
		else
			notify("Character is not available")
		end
	elseif name == "reload" then
		simulatedAmmo = 0
		publishTestSettings()
		notify("Reload test started")
		task.delay(1.2, function()
			if not destroyed then
				simulatedAmmo = setting.ammoTest
				publishTestSettings()
				notify("Reload test complete: " .. simulatedAmmo .. " rounds")
			end
		end)
	elseif name == "save" then
		local ok, encoded = pcall(function() return HttpService:JSONEncode(setting) end)
		if not ok then
			warn("[XYZ] Failed to encode settings:", encoded)
			notify("Could not save settings")
			return
		end
		player:SetAttribute(SETTINGS_ATTRIBUTE, encoded)
		notify("Settings saved for this session")
	elseif name == "load" then
		local encoded = player:GetAttribute(SETTINGS_ATTRIBUTE)
		if type(encoded) ~= "string" then
			notify("No saved settings in this session")
			return
		end
		local ok, decoded = pcall(function() return HttpService:JSONDecode(encoded) end)
		if not ok or type(decoded) ~= "table" then
			warn("[XYZ] Saved settings are invalid:", decoded)
			notify("Saved settings could not be loaded")
			return
		end
		for key, default in pairs(DEFAULTS) do
			local value = decoded[key]
			if typeof(value) == typeof(default) then setting[key] = value end
		end
		updateMovement()
		updateCameraEffects()
		updateThirdPerson()
		afterSettingChanged("cameraFov")
		afterSettingChanged("aimFov")
		refreshCategory()
		notify("Settings loaded")
	elseif name == "reset" then
		restoreMovement()
		for key, value in pairs(DEFAULTS) do setting[key] = value end
		simulatedAmmo = setting.ammoTest
		if savedLightingEffect then
			savedLightingEffect:Destroy()
			savedLightingEffect = nil
		end
		updateThirdPerson()
		if savedCameraFov ~= nil and workspace.CurrentCamera then
			workspace.CurrentCamera.FieldOfView = savedCameraFov
			savedCameraFov = nil
		end
		player:SetAttribute(SETTINGS_ATTRIBUTE, nil)
		publishTestSettings()
		refreshCategory()
		notify("Settings reset")
	end
end

local function createRow(height)
	local row = make("Frame", {
		Size = UDim2.new(1, -2, 0, height),
		BackgroundColor3 = COLORS.row,
		BorderSizePixel = 0,
	}, scroll)
	make("UICorner", { CornerRadius = UDim.new(0, 7) }, row)
	make("UIStroke", { Color = COLORS.border, Thickness = 1 }, row)
	return row
end

local function addControl(def)
	local row = createRow(def.kind == "slider" and 66 or 48)
	make("TextLabel", {
		Position = UDim2.fromOffset(13, 0),
		Size = UDim2.new(0.52, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = def.name,
		TextColor3 = COLORS.text,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, row)

	if def.kind == "toggle" then
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(42, 23),
			BackgroundColor3 = setting[def.key] and COLORS.accentDim or COLORS.raised,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, button)
		local knob = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = setting[def.key] and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			Size = UDim2.fromOffset(17, 17),
			BackgroundColor3 = COLORS.text,
			BorderSizePixel = 0,
		}, button)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, knob)
		button.Activated:Connect(function()
			setting[def.key] = not setting[def.key]
			animate(button, 0.14, { BackgroundColor3 = setting[def.key] and COLORS.accentDim or COLORS.raised })
			animate(knob, 0.14, {
				Position = setting[def.key] and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			})
			afterSettingChanged(def.key)
		end)
	elseif def.kind == "slider" then
		local valueLabel = make("TextLabel", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -13, 0, 7),
			Size = UDim2.fromOffset(110, 20),
			BackgroundTransparency = 1,
			TextColor3 = COLORS.muted,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
		local trackFrame = make("Frame", {
			Position = UDim2.new(0, 13, 0, 42),
			Size = UDim2.new(1, -26, 0, 8),
			BackgroundColor3 = COLORS.raised,
			BorderSizePixel = 0,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, trackFrame)
		local fill = make("Frame", {
			Size = UDim2.new(0, 0, 1, 0),
			BackgroundColor3 = COLORS.accent,
			BorderSizePixel = 0,
		}, trackFrame)
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
		local function displayValue()
			local ratio = (setting[def.key] - def.min) / (def.max - def.min)
			fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
			valueLabel.Text = tostring(setting[def.key]) .. (def.suffix or "")
		end
		displayValue()
		trackFrame.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				activeSlider = { frame = trackFrame, definition = def, fill = fill, label = valueLabel }
			end
		end)
	elseif def.kind == "dropdown" then
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(205, 30),
			BackgroundColor3 = COLORS.raised,
			BorderSizePixel = 0,
			Text = "",
			AutoButtonColor = false,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, button)
		local label = make("TextLabel", {
			Position = UDim2.fromOffset(9, 0),
			Size = UDim2.new(1, -24, 1, 0),
			BackgroundTransparency = 1,
			Text = setting[def.key],
			TextColor3 = COLORS.text,
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, button)
		button.Activated:Connect(function()
			local index = (table.find(def.options, setting[def.key]) or 0) % #def.options + 1
			setting[def.key] = def.options[index]
			label.Text = setting[def.key]
			afterSettingChanged(def.key)
		end)
	elseif def.kind == "button" then
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(140, 30),
			BackgroundColor3 = COLORS.accentDim,
			BorderSizePixel = 0,
			Text = def.name,
			TextColor3 = COLORS.text,
			TextSize = 11,
			Font = Enum.Font.GothamBold,
			AutoButtonColor = false,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, button)
		button.Activated:Connect(function() action(def.action) end)
	elseif def.kind == "keybind" then
		local button = make("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -13, 0.5, 0),
			Size = UDim2.fromOffset(130, 30),
			BackgroundColor3 = COLORS.raised,
			BorderSizePixel = 0,
			Text = setting[def.key],
			TextColor3 = COLORS.text,
			TextSize = 12,
			Font = Enum.Font.GothamMedium,
			AutoButtonColor = false,
		}, row)
		make("UICorner", { CornerRadius = UDim.new(0, 5) }, button)
		button.Activated:Connect(function()
			capturingKey = { key = def.key, button = button }
			button.Text = "Press a key..."
		end)
		if capturingKey and capturingKey.key == def.key then
			capturingKey.button = button
		end
	end
end

refreshCategory = function()
	for _, child in ipairs(scroll:GetChildren()) do
		if child ~= rowLayout then child:Destroy() end
	end
	categoryTitle.Text = currentCategory
	local query = string.lower(search.Text)
	for _, def in ipairs(controls[currentCategory]) do
		if query == "" or string.find(string.lower(def.name), query, 1, true) then
			addControl(def)
		end
	end
	for name, button in pairs(categoriesByButton) do
		local active = name == currentCategory
		button.BackgroundColor3 = active and COLORS.accentDim or COLORS.panel
		button.TextColor3 = active and COLORS.text or COLORS.muted
	end
end

for index, name in ipairs(categories) do
	local button = make("TextButton", {
		LayoutOrder = index,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Text = "   " .. name,
		TextColor3 = COLORS.muted,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	}, categoryList)
	make("UICorner", { CornerRadius = UDim.new(0, 6) }, button)
	categoriesByButton[name] = button
	button.Activated:Connect(function()
		currentCategory = name
		refreshCategory()
	end)
end

track(search:GetPropertyChangedSignal("Text"):Connect(refreshCategory))

local function removePlayerVisuals(target)
	local entry = espByPlayer[target]
	if entry then
		entry.gui:Destroy()
		espByPlayer[target] = nil
	end
	local adornment = hitboxByPlayer[target]
	if adornment then
		adornment:Destroy()
		hitboxByPlayer[target] = nil
	end
end

local skeletonPairs = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" },
	{ "LeftLowerArm", "LeftHand" }, { "UpperTorso", "RightUpperArm" },
	{ "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftLowerLeg", "LeftFoot" }, { "LowerTorso", "RightUpperLeg" },
	{ "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}

local function setLine(frame, from, to)
	local delta = to - from
	frame.Position = UDim2.fromOffset(from.X, from.Y)
	frame.Size = UDim2.fromOffset(delta.Magnitude, 1)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	frame.Visible = true
end

local function createEsp(target)
	local overlay = make("ScreenGui", {
		Name = "XYZESP_" .. target.UserId,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)
	local box = make("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = false,
	}, overlay)
	make("UIStroke", { Color = COLORS.accent, Thickness = 1 }, box)
	local label = make("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(200, 22),
		Text = "",
		TextColor3 = COLORS.text,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextStrokeTransparency = 0.35,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	}, overlay)
	local tracer = make("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
		Visible = false,
	}, overlay)
	local bones = {}
	for i = 1, #skeletonPairs do
		bones[i] = make("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = COLORS.accent,
			BorderSizePixel = 0,
			Visible = false,
		}, overlay)
	end
	local entry = { gui = overlay, box = box, label = label, tracer = tracer, bones = bones }
	espByPlayer[target] = entry
	return entry
end

local function updateEsp()
	local camera = workspace.CurrentCamera
	if not camera then return end
	for _, target in ipairs(Players:GetPlayers()) do
		if target == player or not setting.playerESP then
			removePlayerVisuals(target)
			continue
		end
		local character = target.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local head = character and character:FindFirstChild("Head")
		local entry = espByPlayer[target] or createEsp(target)
		local valid = humanoid and humanoid.Health > 0 and root and head
		if not valid then
			entry.box.Visible = false
			entry.label.Visible = false
			entry.tracer.Visible = false
			for _, bone in ipairs(entry.bones) do bone.Visible = false end
			if hitboxByPlayer[target] then
				hitboxByPlayer[target]:Destroy()
				hitboxByPlayer[target] = nil
			end
			continue
		end
		local topPoint, topOnScreen = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
		local bottomPoint, bottomOnScreen = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.5, 0))
		local inFront = topPoint.Z > 0 and bottomPoint.Z > 0
		local show = inFront and (topOnScreen or bottomOnScreen)
		local height = math.max(math.abs(bottomPoint.Y - topPoint.Y), 8)
		local width = math.max(height * 0.48, 14)
		entry.box.Visible = show and setting.espBox
		if entry.box.Visible then
			entry.box.Position = UDim2.fromOffset(topPoint.X - width / 2, topPoint.Y)
			entry.box.Size = UDim2.fromOffset(width, height)
		end
		local info = {}
		if setting.espName then table.insert(info, target.DisplayName) end
		if setting.espDistance then
			table.insert(info, string.format("%d studs", math.floor((camera.CFrame.Position - root.Position).Magnitude + 0.5)))
		end
		if setting.espHealth then
			table.insert(info, string.format("HP %d", math.floor(humanoid.Health + 0.5)))
		end
		entry.label.Text = table.concat(info, " | ")
		entry.label.Visible = show and #info > 0
		entry.label.Position = UDim2.fromOffset(topPoint.X - 100, topPoint.Y - 21)
		entry.tracer.Visible = show and setting.espTracer
		if entry.tracer.Visible then
			setLine(entry.tracer,
				Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y - 3),
				Vector2.new(bottomPoint.X, bottomPoint.Y))
		end
		for index, pair in ipairs(skeletonPairs) do
			local bone = entry.bones[index]
			bone.Visible = false
			local partA = character:FindFirstChild(pair[1])
			local partB = character:FindFirstChild(pair[2])
			if setting.espSkeleton and partA and partB then
				local a, aVisible = camera:WorldToViewportPoint(partA.Position)
				local b, bVisible = camera:WorldToViewportPoint(partB.Position)
				if aVisible and bVisible then
					setLine(bone, Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y))
				end
			end
		end
		if setting.hitboxVisualization then
			local adornment = hitboxByPlayer[target]
			if not adornment or adornment.Adornee ~= root then
				if adornment then adornment:Destroy() end
				adornment = make("BoxHandleAdornment", {
					Name = "XYZHitboxVisualization",
					Adornee = root,
					AlwaysOnTop = true,
					ZIndex = 5,
					Transparency = 0.72,
					Color3 = COLORS.accent,
					Size = Vector3.new(setting.hitboxSize, setting.hitboxSize, setting.hitboxSize),
				}, root)
				hitboxByPlayer[target] = adornment
			end
			adornment.Size = Vector3.new(setting.hitboxSize, setting.hitboxSize, setting.hitboxSize)
		elseif hitboxByPlayer[target] then
			hitboxByPlayer[target]:Destroy()
			hitboxByPlayer[target] = nil
		end
	end
end

local function findTarget()
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local best, bestScore = nil, math.huge
	for _, candidate in ipairs(Players:GetPlayers()) do
		if candidate ~= player then
			local character = candidate.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local head = character and character:FindFirstChild("Head")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local part = setting.headPriority and head or root
			if humanoid and humanoid.Health > 0 and part then
				local point, onScreen = camera:WorldToViewportPoint(part.Position)
				local offset = (Vector2.new(point.X, point.Y) - center).Magnitude
				if onScreen and point.Z > 0 and offset <= setting.aimFov then
					local score = offset
					if setting.targetSelection == "Closest distance" then
						score = (camera.CFrame.Position - part.Position).Magnitude
					elseif setting.targetSelection == "Lowest health" then
						score = humanoid.Health
					end
					if score < bestScore then best, bestScore = candidate, score end
				end
			end
		end
	end
	return best
end

local function aimAt(target, deltaTime)
	local camera = workspace.CurrentCamera
	local character = target and target.Character
	local part = character and ((setting.headPriority and character:FindFirstChild("Head"))
		or character:FindFirstChild("HumanoidRootPart"))
	if not camera or not part then return end
	local desired = CFrame.lookAt(camera.CFrame.Position, part.Position)
	local alpha = math.clamp(deltaTime * (21 - setting.smoothness), 0, 1)
	camera.CFrame = camera.CFrame:Lerp(desired, alpha)
end

track(UserInputService.InputChanged:Connect(function(input)
	if dragging and dragOrigin and windowOrigin
		and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
		local delta = input.Position - dragOrigin
		main.Position = UDim2.new(windowOrigin.X.Scale, windowOrigin.X.Offset + delta.X,
			windowOrigin.Y.Scale, windowOrigin.Y.Offset + delta.Y)
	end
	if activeSlider and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local frame = activeSlider.frame
		local def = activeSlider.definition
		local ratio = math.clamp((input.Position.X - frame.AbsolutePosition.X) / frame.AbsoluteSize.X, 0, 1)
		setting[def.key] = math.floor(def.min + (def.max - def.min) * ratio + 0.5)
		activeSlider.fill.Size = UDim2.new(ratio, 0, 1, 0)
		activeSlider.label.Text = tostring(setting[def.key]) .. (def.suffix or "")
		afterSettingChanged(def.key)
	end
end))

track(UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		activeSlider = nil
	end
end))

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
	if capturingKey then
		local keyCode = input.KeyCode
		if keyCode ~= Enum.KeyCode.Unknown then
			setting[capturingKey.key] = keyCode.Name
			capturingKey.button.Text = keyCode.Name
			capturingKey = nil
			publishTestSettings()
		end
		return
	end
	if gameProcessed then return end
	local key = input.KeyCode.Name
	if key == setting.toggleKey then
		setPanelVisible(not panelOpen)
	elseif setting.aimKey ~= "None" and key == setting.aimKey then
		setting.aimAssist = not setting.aimAssist
		publishTestSettings()
		if refreshCategory then refreshCategory() end
	elseif setting.lockKey ~= "None" and key == setting.lockKey then
		setting.targetLock = not setting.targetLock
		targetLockPlayer = setting.targetLock and findTarget() or nil
		publishTestSettings()
		if refreshCategory then refreshCategory() end
	elseif setting.dashKey ~= "None" and key == setting.dashKey then
		action("dash")
	end
end))

track(Players.PlayerRemoving:Connect(function(leaving)
	removePlayerVisuals(leaving)
	if targetLockPlayer == leaving then targetLockPlayer = nil end
end))

track(player.CharacterAdded:Connect(function()
	savedHumanoid = nil
	savedMovement = nil
	task.defer(updateMovement)
end))

local function shutdown()
	if destroyed then return end
	destroyed = true
	restoreMovement()
	for _, connection in ipairs(globalConnections) do connection:Disconnect() end
	table.clear(globalConnections)
	for target in pairs(espByPlayer) do removePlayerVisuals(target) end
	if savedLightingEffect then savedLightingEffect:Destroy() end
	if savedCameraMode then
		player.CameraMode = savedCameraMode
		if savedZoom then
			player.CameraMinZoomDistance = savedZoom.min
			player.CameraMaxZoomDistance = savedZoom.max
		end
	end
	if savedCameraFov and workspace.CurrentCamera then
		workspace.CurrentCamera.FieldOfView = savedCameraFov
	end
end

track(script.Destroying:Connect(shutdown))

local currentCamera = workspace.CurrentCamera
if currentCamera then savedCameraFov = currentCamera.FieldOfView end
publishTestSettings()
refreshCategory()
updateScale()
notify("XYZ test panel ready")

track(RunService.RenderStepped:Connect(function(deltaTime)
	if destroyed then return end
	updateScale()
	crosshair.Visible = setting.crosshair
	fovCircle.Visible = setting.aimAssist or setting.targetLock
	debugText.Visible = setting.movementDebug
	hitboxDebugText.Visible = setting.hitboxDebug

	local camera = workspace.CurrentCamera
	if camera then
		if setting.targetLock then
			local lockedCharacter = targetLockPlayer and targetLockPlayer.Character
			local lockedHumanoid = lockedCharacter and lockedCharacter:FindFirstChildOfClass("Humanoid")
			if not targetLockPlayer or not targetLockPlayer.Parent
				or not lockedHumanoid or lockedHumanoid.Health <= 0 then
				targetLockPlayer = findTarget()
			end
			if targetLockPlayer then aimAt(targetLockPlayer, deltaTime) end
		elseif setting.aimAssist and os.clock() - lastAimTime >= 1 / 30 then
			aimAt(findTarget(), deltaTime)
			lastAimTime = os.clock()
		else
			targetLockPlayer = nil
		end
		if setting.movementDebug then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if root and humanoid then
				debugText.Text = string.format(" XYZ MOVEMENT\n Speed: %.1f\n State: %s",
					root.AssemblyLinearVelocity.Magnitude, humanoid:GetState().Name)
			end
		end
		if setting.hitboxDebug then
			local target = targetLockPlayer or findTarget()
			local character = target and target.Character
			local partName = setting.headPriority and "Head" or "HumanoidRootPart"
			local part = character and character:FindFirstChild(partName)
			hitboxDebugText.Text = string.format(
				" HITBOX DEBUG\n Target: %s\n Part: %s | Size: %.1f",
				target and target.Name or "None",
				part and part.Name or "Unavailable",
				setting.hitboxSize
			)
		end
	end

	renderElapsed += deltaTime
	if renderElapsed >= 1 / 20 then
		renderElapsed = 0
		updateEsp()
	end
end))
