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

-- PCマウス操作
local pcConnection
local function setupPCControl()
    if pcConnection then pcConnection:Disconnect() end
    local lastPos = UserInputService:GetMouseLocation()
    pcConnection = RunService.RenderStepped:Connect(function()
        if Settings.controlMode == "pc" then
            local mousePos = UserInputService:GetMouseLocation()
            local delta = (mousePos - lastPos) * 0.005
            rightInput = Vector2.new(delta.X, delta.Y)
            lastPos = mousePos
        end
    end)
end

-- =============================================
-- MOBILE STICKS
-- =============================================
local screenGui
local function setupMobileControl()
    if screenGui then
        screenGui:Destroy()
    end
    
    if Settings.controlMode ~= "mobile" then return end
    
    screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    screenGui.Name = "VRArmSticks"
    screenGui.ResetOnSpawn = false
    
    local function createStick(side)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 120, 0, 120)
        frame.AnchorPoint = Vector2.new(0.5, 0.5)
        frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel = 0
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
        stick.Parent = frame
        
        local stickCorner = Instance.new("UICorner", stick)
        stickCorner.CornerRadius = UDim.new(1, 0)

        return frame, stick
    end

    local leftFrame, leftStick = createStick("left")
    local rightFrame, rightStick = createStick("right")

    local function stickHandler(stick, frame, updateFunc)
        local dragging = false
        local center = stick.Position
        
        stick.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then 
                dragging = true 
            end
        end)
        
        stick.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
                stick.Position = center
                updateFunc(Vector2.zero)
            end
        end)
        
        stick.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.Touch then
                local rel = frame.AbsolutePosition + frame.AbsoluteSize / 2
                local offset = Vector2.new(input.Position.X - rel.X, input.Position.Y - rel.Y)
                local maxDist = frame.AbsoluteSize.X / 2
                if offset.Magnitude > maxDist then 
                    offset = offset.Unit * maxDist 
                end
                stick.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
                updateFunc(offset / maxDist)
            end
        end)
    end

    stickHandler(leftStick, leftFrame, function(vec) leftInput = vec end)
    stickHandler(rightStick, rightFrame, function(vec) rightInput = vec end)
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

RunService.RenderStepped:Connect(function()
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
      if Value then
         Rayfield:Notify({
            Title = "VR Arms Enabled",
            Content = "Arms are now controllable",
            Duration = 3,
            Image = 4483362458,
         })
      else
         Rayfield:Notify({
            Title = "VR Arms Disabled",
            Content = "Arms reset to normal",
            Duration = 3,
            Image = 4483362458,
         })
      end
   end,
})

local ControlDropdown = MainTab:CreateDropdown({
   Name = "Control Mode",
   Options = {"pc", "mobile"},
   CurrentOption = Settings.controlMode,
   Flag = "ControlMode",
   Callback = function(Option)
      Settings.controlMode = Option:lower()
      if Settings.controlMode == "pc" then
         setupPCControl()
         if screenGui then screenGui:Destroy() end
      else
         setupMobileControl()
         if pcConnection then pcConnection:Disconnect() end
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
