-- =============================================
-- VR ARM CONTROLLER WITH RAYFIELD UI
-- Executor Ready Script
-- =============================================

-- Wait for character
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
repeat wait() until character:FindFirstChild("HumanoidRootPart")

-- =============================================
-- RAYFIELD UI LIBRARY
-- =============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "VR Arm Controller",
   LoadingTitle = "VR Arm System",
   LoadingSubtitle = "by Assistant",
   ConfigurationSaving = {
      Enabled = false,
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = false,
})

-- =============================================
-- SERVICES
-- =============================================
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- =============================================
-- SETTINGS
-- =============================================
local Settings = {
    controlMode = "mobile", -- Default to mobile for testing
    sensitivity = 1.2,
    lerpSpeed = 0.12,
    enabled = true
}

-- =============================================
-- ARM REFERENCES
-- =============================================
local function getArmJoints(char, side)
    local upper = char:FindFirstChild(side.."UpperArm")
    local lower = char:FindFirstChild(side.."LowerArm")
    local hand = char:FindFirstChild(side.."Hand")
    
    if not upper or not lower or not hand then
        warn("R15 body parts not found. Make sure you're using R15 avatar.")
        return nil
    end
    
    local shoulder = upper:FindFirstChild(side.."Shoulder")
    local elbow = lower:FindFirstChild(side.."Elbow")
    local wrist = hand:FindFirstChild(side.."Wrist")
    
    if shoulder and elbow and wrist then
        return {
            Upper = shoulder,
            Lower = elbow,
            Hand = wrist
        }
    end
    return nil
end

local rightJoints = getArmJoints(character, "Right")
local leftJoints = getArmJoints(character, "Left")

if not rightJoints or not leftJoints then
    Rayfield:Notify({
       Title = "Error",
       Content = "R15 avatar required! Script may not work properly.",
       Duration = 10,
       Image = 4483362458,
    })
end

-- Store initial C0
local initC0 = {}
if rightJoints then
    initC0.RightShoulder = rightJoints.Upper.C0
    initC0.RightElbow = rightJoints.Lower.C0
    initC0.RightWrist = rightJoints.Hand.C0
end
if leftJoints then
    initC0.LeftShoulder = leftJoints.Upper.C0
    initC0.LeftElbow = leftJoints.Lower.C0
    initC0.LeftWrist = leftJoints.Hand.C0
end

-- =============================================
-- INPUT VARIABLES
-- =============================================
local rightInput = Vector2.zero
local leftInput = Vector2.zero

-- =============================================
-- MOBILE VIRTUAL STICKS
-- =============================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VRArmSticks"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = game:GetService("CoreGui") -- Use CoreGui for executor compatibility

local function createVirtualStick(position, labelText, side)
    -- Container Frame
    local container = Instance.new("Frame")
    container.Size = UDim2.new(0, 150, 0, 150)
    container.Position = position
    container.AnchorPoint = Vector2.new(0.5, 0.5)
    container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    container.BackgroundTransparency = 0.3
    container.BorderSizePixel = 0
    container.Parent = screenGui
    
    local containerCorner = Instance.new("UICorner")
    containerCorner.CornerRadius = UDim.new(1, 0)
    containerCorner.Parent = container
    
    -- Label
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0.25, 0)
    label.Position = UDim2.new(0.5, 0, -0.35, 0)
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextSize = 18
    label.Font = Enum.Font.GothamBold
    label.Parent = container
    
    -- Stick
    local stick = Instance.new("Frame")
    stick.Size = UDim2.new(0, 70, 0, 70)
    stick.Position = UDim2.new(0.5, 0, 0.5, 0)
    stick.AnchorPoint = Vector2.new(0.5, 0.5)
    stick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    stick.BackgroundTransparency = 0.2
    stick.BorderSizePixel = 0
    stick.Parent = container
    
    local stickCorner = Instance.new("UICorner")
    stickCorner.CornerRadius = UDim.new(1, 0)
    stickCorner.Parent = stick
    
    -- Touch detection
    local touching = false
    local centerPos = UDim2.new(0.5, 0, 0.5, 0)
    
    local function resetStick()
        stick.Position = centerPos
        if side == "left" then
            leftInput = Vector2.zero
        else
            rightInput = Vector2.zero
        end
    end
    
    local function updateStick(inputPosition)
        if not touching then return end
        
        -- Calculate offset from center
        local containerCenter = container.AbsolutePosition + container.AbsoluteSize / 2
        local offset = Vector2.new(
            inputPosition.X - containerCenter.X,
            inputPosition.Y - containerCenter.Y
        )
        
        -- Limit to circle
        local maxRadius = container.AbsoluteSize.X / 2 - 35
        local distance = math.min(offset.Magnitude, maxRadius)
        local angle = math.atan2(offset.Y, offset.X)
        
        local finalOffset = Vector2.new(
            math.cos(angle) * distance,
            math.sin(angle) * distance
        )
        
        -- Update stick position
        stick.Position = UDim2.new(0.5, finalOffset.X, 0.5, finalOffset.Y)
        
        -- Update input (normalized -1 to 1)
        local normalizedInput = finalOffset / maxRadius
        if side == "left" then
            leftInput = normalizedInput
        else
            rightInput = normalizedInput
        end
    end
    
    -- Input handling
    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or 
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            touching = true
            updateStick(input.Position)
        end
    end)
    
    container.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or 
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            touching = false
            resetStick()
        end
    end)
    
    container.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            if touching then
                updateStick(input.Position)
            end
        end
    end)
    
    return container
end

-- Create sticks
local leftStickFrame
local rightStickFrame

local function showSticks()
    if leftStickFrame then leftStickFrame:Destroy() end
    if rightStickFrame then rightStickFrame:Destroy() end
    
    leftStickFrame = createVirtualStick(
        UDim2.new(0.15, 0, 0.75, 0),
        "LEFT ARM",
        "left"
    )
    
    rightStickFrame = createVirtualStick(
        UDim2.new(0.85, 0, 0.75, 0),
        "RIGHT ARM",
        "right"
    )
end

local function hideSticks()
    if leftStickFrame then leftStickFrame:Destroy() end
    if rightStickFrame then rightStickFrame:Destroy() end
    leftInput = Vector2.zero
    rightInput = Vector2.zero
end

-- =============================================
-- PC MOUSE CONTROL
-- =============================================
local pcConnection
local function setupPCControl()
    if pcConnection then pcConnection:Disconnect() end
    
    local lastPos = UserInputService:GetMouseLocation()
    pcConnection = RunService.RenderStepped:Connect(function()
        if Settings.controlMode == "pc" and Settings.enabled then
            local mousePos = UserInputService:GetMouseLocation()
            local delta = (mousePos - lastPos) * 0.005
            rightInput = Vector2.new(delta.X, delta.Y)
            leftInput = Vector2.new(delta.X, delta.Y)
            lastPos = mousePos
        end
    end)
end

-- =============================================
-- ARM UPDATE FUNCTION
-- =============================================
local function updateArm(joints, input, init)
    if not joints or not Settings.enabled then return end
    
    local pitch = -input.Y * Settings.sensitivity
    local yaw = input.X * Settings.sensitivity
    
    joints.Upper.C0 = joints.Upper.C0:Lerp(
        init.Upper * CFrame.Angles(pitch, yaw, 0) * CFrame.new(0, 0, -0.2),
        Settings.lerpSpeed
    )
    joints.Lower.C0 = joints.Lower.C0:Lerp(
        init.Lower * CFrame.Angles(pitch / 2, yaw / 2, 0),
        Settings.lerpSpeed
    )
    joints.Hand.C0 = joints.Hand.C0:Lerp(
        init.Hand * CFrame.Angles(pitch / 3, yaw / 3, 0),
        Settings.lerpSpeed
    )
end

-- Main update loop
RunService.RenderStepped:Connect(function()
    if Settings.enabled then
        if rightJoints and initC0.RightShoulder then
            updateArm(rightJoints, rightInput, {
                Upper = initC0.RightShoulder,
                Lower = initC0.RightElbow,
                Hand = initC0.RightWrist
            })
        end
        
        if leftJoints and initC0.LeftShoulder then
            updateArm(leftJoints, leftInput, {
                Upper = initC0.LeftShoulder,
                Lower = initC0.LeftElbow,
                Hand = initC0.LeftWrist
            })
        end
    end
end)

-- =============================================
-- RAYFIELD UI
-- =============================================
local MainTab = Window:CreateTab("🎮 Controls", nil)
local SettingsTab = Window:CreateTab("⚙️ Settings", nil)

-- Enable Toggle
MainTab:CreateToggle({
   Name = "Enable VR Arms",
   CurrentValue = Settings.enabled,
   Callback = function(Value)
      Settings.enabled = Value
      if not Value then
         leftInput = Vector2.zero
         rightInput = Vector2.zero
      end
   end,
})

-- Control Mode
MainTab:CreateDropdown({
   Name = "Control Mode",
   Options = {"mobile", "pc"},
   CurrentOption = Settings.controlMode,
   Callback = function(Option)
      Settings.controlMode = Option:lower()
      
      leftInput = Vector2.zero
      rightInput = Vector2.zero
      
      if Settings.controlMode == "mobile" then
         hideSticks()
         wait(0.1)
         showSticks()
         if pcConnection then pcConnection:Disconnect() end
         Rayfield:Notify({
            Title = "Mobile Mode",
            Content = "Virtual sticks are now visible!",
            Duration = 3,
            Image = 4483362458,
         })
      else
         hideSticks()
         setupPCControl()
         Rayfield:Notify({
            Title = "PC Mode",
            Content = "Move mouse to control arms",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

-- Sensitivity
SettingsTab:CreateSlider({
   Name = "Sensitivity",
   Range = {0.1, 5},
   Increment = 0.1,
   CurrentValue = Settings.sensitivity,
   Callback = function(Value)
      Settings.sensitivity = Value
   end,
})

-- Smoothness
SettingsTab:CreateSlider({
   Name = "Smoothness",
   Range = {0.01, 0.5},
   Increment = 0.01,
   CurrentValue = Settings.lerpSpeed,
   Callback = function(Value)
      Settings.lerpSpeed = Value
   end,
})

-- =============================================
-- INITIALIZE
-- =============================================
if Settings.controlMode == "mobile" then
    showSticks()
else
    setupPCControl()
end

Rayfield:Notify({
   Title = "VR Arm Controller Loaded!",
   Content = "Check the UI to change settings",
   Duration = 5,
   Image = 4483362458,
})

print("VR Arm Controller loaded successfully!")
print("Current mode:", Settings.controlMode)
