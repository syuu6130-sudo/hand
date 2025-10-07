-- =============================================
-- RAYFIELD UI LIBRARY
-- =============================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "VR Arm Controller",
   LoadingTitle = "VR Arm System",
   LoadingSubtitle = "by Assistant",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "VRArmConfig",
      FileName = "VRArm"
   },
   Discord = {
      Enabled = false,
   },
   KeySystem = false,
})

-- =============================================
-- SETTINGS (変更可能)
-- =============================================
local Settings = {
    controlMode = "pc", -- "pc" or "mobile"
    sensitivity = 1.2,
    lerpSpeed = 0.12,
    enabled = true
}

-- =============================================
-- SERVICES
-- =============================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- =============================================
-- ARM REFERENCES
-- =============================================
local function getArmJoints(char, side)
    local upper = char:FindFirstChild(side.."UpperArm")
    local lower = char:FindFirstChild(side.."LowerArm")
    local hand = char:FindFirstChild(side.."Hand")
    if upper and lower and hand then
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
    end
    return nil
end

local rightJoints = getArmJoints(character, "Right")
local leftJoints = getArmJoints(character, "Left")

-- 初期C0保持
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
-- INPUT SETUP
-- =============================================
local rightInput = Vector2.zero
local leftInput = Vector2.zero
local rightInputTarget = Vector2.zero
local leftInputTarget = Vector2.zero

-- PCマウス操作
local pcConnection
local function setupPCControl()
    if pcConnection then pcConnection:Disconnect() end
    
    if Settings.controlMode ~= "pc" then return end
    
    local lastPos = UserInputService:GetMouseLocation()
    pcConnection = RunService.RenderStepped:Connect(function()
        if Settings.controlMode == "pc" and Settings.enabled then
            local mousePos = UserInputService:GetMouseLocation()
            local delta = (mousePos - lastPos) * 0.005
            -- PC mode: both arms follow mouse
            rightInputTarget = Vector2.new(delta.X, delta.Y)
            leftInputTarget = Vector2.new(delta.X, delta.Y)
            lastPos = mousePos
        else
            rightInputTarget = Vector2.zero
            leftInputTarget = Vector2.zero
        end
    end)
end

-- =============================================
-- MOBILE STICKS
-- =============================================
local screenGui
local leftStickActive = false
local rightStickActive = false

local function setupMobileControl()
    -- Clean up previous GUI
    if screenGui then
        screenGui:Destroy()
    end
    
    if Settings.controlMode ~= "mobile" then 
        leftInputTarget = Vector2.zero
        rightInputTarget = Vector2.zero
        return 
    end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "VRArmSticks"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = player:WaitForChild("PlayerGui")
    
    local function createStick(side)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 120, 0, 120)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
        frame.ZIndex = 10
        frame.Parent = screenGui
        frame.Position = side == "left" and UDim2.new(0.15, 0, 0.75, 0) or UDim2.new(0.85, 0, 0.75, 0)
        
        local corner = Instance.new("UICorner", frame)
        corner.CornerRadius = UDim.new(1, 0)

        local stick = Instance.new("ImageButton")
        stick.Size = UDim2.new(0, 60, 0, 60)
        stick.Position = UDim2.new(0.5, 0, 0.5, 0)
        stick.AnchorPoint = Vector2.new(0.5, 0.5)
        stick.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        stick.BackgroundTransparency = 0.3
        stick.BorderSizePixel = 0
        stick.AutoButtonColor = false
        stick.ZIndex = 11
        stick.Parent = frame
        
        local stickCorner = Instance.new("UICorner", stick)
        stickCorner.CornerRadius = UDim.new(1, 0)
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 0.3, 0)
        label.Position = UDim2.new(0.5, 0, -0.4, 0)
        label.AnchorPoint = Vector2.new(0.5, 0.5)
        label.BackgroundTransparency = 1
        label.Text = side == "left" and "Left Arm" or "Right Arm"
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextScaled = true
        label.Font = Enum.Font.GothamBold
        label.ZIndex = 12
        label.Parent = frame

        return frame, stick
    end

    local leftFrame, leftStick = createStick("left")
    local rightFrame, rightStick = createStick("right")

    local function stickHandler(stick, frame, side)
        local dragging = false
        local center = UDim2.new(0.5, 0, 0.5, 0)
        local inputConnection
        
        stick.MouseButton1Down:Connect(function()
            dragging = true
            if side == "left" then
                leftStickActive = true
            else
                rightStickActive = true
            end
        end)
        
        stick.MouseButton1Up:Connect(function()
            dragging = false
            stick.Position = center
            if side == "left" then
                leftStickActive = false
                leftInputTarget = Vector2.zero
            else
                rightStickActive = false
                rightInputTarget = Vector2.zero
            end
        end)
        
        stick.TouchTap:Connect(function()
            -- Touch started
        end)
        
        stick.TouchLongPress:Connect(function()
            -- Long press
        end)
        
        local function updateStickPosition(inputPos)
            if not dragging then return end
            
            local framePos = frame.AbsolutePosition
            local frameSize = frame.AbsoluteSize
            local center = framePos + frameSize / 2
            
            local offset = Vector2.new(inputPos.X - center.X, inputPos.Y - center.Y)
            local maxDist = frameSize.X / 2 - 30
            
            local magnitude = offset.Magnitude
            if magnitude > maxDist then
                offset = offset.Unit * maxDist
            end
            
            stick.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
            
            -- Update input for the specific arm
            local normalizedInput = offset / maxDist
            if side == "left" then
                leftInputTarget = normalizedInput
            else
                rightInputTarget = normalizedInput
            end
        end
        
        -- Mouse support (for testing in Studio)
        UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
                updateStickPosition(Vector2.new(input.Position.X, input.Position.Y))
            end
        end)
        
        -- Touch support
        stick.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                if side == "left" then
                    leftStickActive = true
                else
                    rightStickActive = true
                end
            end
        end)
        
        stick.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                stick.Position = center
                if side == "left" then
                    leftStickActive = false
                    leftInputTarget = Vector2.zero
                else
                    rightStickActive = false
                    rightInputTarget = Vector2.zero
                end
            end
        end)
        
        stick.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch and dragging then
                updateStickPosition(Vector2.new(input.Position.X, input.Position.Y))
            end
        end)
    end

    stickHandler(leftStick, leftFrame, "left")
    stickHandler(rightStick, rightFrame, "right")
end

-- =============================================
-- UPDATE LOOP
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

-- Smooth input interpolation
RunService.Heartbeat:Connect(function()
    -- Smooth input transitions
    rightInput = rightInput:Lerp(rightInputTarget, 0.3)
    leftInput = leftInput:Lerp(leftInputTarget, 0.3)
end)

RunService.RenderStepped:Connect(function()
    if not Settings.enabled then return end
    
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
end)

-- =============================================
-- RAYFIELD UI TABS
-- =============================================
local MainTab = Window:CreateTab("🎮 Main Controls", nil)
local SettingsTab = Window:CreateTab("⚙️ Settings", nil)

-- Main Controls
local EnableToggle = MainTab:CreateToggle({
   Name = "Enable VR Arms",
   CurrentValue = Settings.enabled,
   Flag = "EnableVR",
   Callback = function(Value)
      Settings.enabled = Value
      if not Value then
         -- Reset arms to default
         rightInputTarget = Vector2.zero
         leftInputTarget = Vector2.zero
      end
      Rayfield:Notify({
         Title = Value and "VR Arms Enabled" or "VR Arms Disabled",
         Content = Value and "Arms are now controllable" or "Arms reset to normal",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

local ControlDropdown = MainTab:CreateDropdown({
   Name = "Control Mode",
   Options = {"pc", "mobile"},
   CurrentOption = Settings.controlMode,
   Flag = "ControlMode",
   Callback = function(Option)
      Settings.controlMode = Option:lower()
      
      -- Reset inputs
      rightInputTarget = Vector2.zero
      leftInputTarget = Vector2.zero
      
      if Settings.controlMode == "pc" then
         setupPCControl()
         if screenGui then screenGui:Destroy() end
      else
         if pcConnection then pcConnection:Disconnect() end
         setupMobileControl()
      end
      
      Rayfield:Notify({
         Title = "Control Mode Changed",
         Content = "Now using " .. Option .. " controls",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

-- Settings Tab
local SensitivitySlider = SettingsTab:CreateSlider({
   Name = "Sensitivity",
   Range = {0.1, 3},
   Increment = 0.1,
   CurrentValue = Settings.sensitivity,
   Flag = "Sensitivity",
   Callback = function(Value)
      Settings.sensitivity = Value
   end,
})

local LerpSpeedSlider = SettingsTab:CreateSlider({
   Name = "Smoothness (Lerp Speed)",
   Range = {0.01, 0.5},
   Increment = 0.01,
   CurrentValue = Settings.lerpSpeed,
   Flag = "LerpSpeed",
   Callback = function(Value)
      Settings.lerpSpeed = Value
   end,
})

local ResetButton = SettingsTab:CreateButton({
   Name = "Reset to Default",
   Callback = function()
      Settings.sensitivity = 1.2
      Settings.lerpSpeed = 0.12
      SensitivitySlider:Set(1.2)
      LerpSpeedSlider:Set(0.12)
      Rayfield:Notify({
         Title = "Settings Reset",
         Content = "All settings restored to default",
         Duration = 3,
         Image = 4483362458,
      })
   end,
})

-- =============================================
-- INITIAL SETUP
-- =============================================
if Settings.controlMode == "pc" then
    setupPCControl()
else
    setupMobileControl()
end

Rayfield:Notify({
   Title = "VR Arm Controller Loaded",
   Content = "Use the UI to configure your settings",
   Duration = 5,
   Image = 4483362458,
})
