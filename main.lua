-- =============================================
-- SETTINGS
-- =============================================
local control = "pc" -- "pc" or "mobile"
local sensitivity = 1.2 -- 腕感度
local lerpSpeed = 0.12 -- 補間速度

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
        return {
            Upper = upper:FindFirstChild(side.."Shoulder"),
            Lower = lower:FindFirstChild(side.."Elbow"),
            Hand = hand:FindFirstChild(side.."Wrist")
        }
    end
end

local rightJoints = getArmJoints(character,"Right")
local leftJoints = getArmJoints(character,"Left")

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
if control == "pc" then
    local lastPos = UserInputService:GetMouseLocation()
    RunService.RenderStepped:Connect(function()
        local mousePos = UserInputService:GetMouseLocation()
        local delta = (mousePos - lastPos) * 0.005
        rightInput = Vector2.new(delta.X, delta.Y)
        lastPos = mousePos
    end)
end

-- =============================================
-- MOBILE STICKS
-- =============================================
if control == "mobile" then
    local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
    local function createStick(side)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0,120,0,120)
        frame.AnchorPoint = Vector2.new(0.5,0.5)
        frame.BackgroundColor3 = Color3.fromRGB(50,50,50)
        frame.BackgroundTransparency = 0.3
        frame.Parent = screenGui
        frame.Position = side=="left" and UDim2.new(0.35,0,0.8,0) or UDim2.new(0.65,0,0.8,0)

        local stick = Instance.new("ImageButton")
        stick.Size = UDim2.new(0,60,0,60)
        stick.Position = UDim2.new(0.5,0,0.5,0)
        stick.AnchorPoint = Vector2.new(0.5,0.5)
        stick.BackgroundColor3 = Color3.fromRGB(200,200,200)
        stick.BackgroundTransparency = 0.2
        stick.AutoButtonColor = false
        stick.Parent = frame

        return frame, stick
    end

    local leftFrame,leftStick = createStick("left")
    local rightFrame,rightStick = createStick("right")

    local function stickHandler(stick, frame, updateFunc)
        local dragging = false
        local center = stick.Position
        stick.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then dragging = true end
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
                local rel = frame.AbsolutePosition + frame.AbsoluteSize/2
                local offset = Vector2.new(input.Position.X-rel.X, input.Position.Y-rel.Y)
                local maxDist = frame.AbsoluteSize.X/2
                if offset.Magnitude > maxDist then offset = offset.Unit*maxDist end
                stick.Position = UDim2.new(0.5,offset.X,0.5,offset.Y)
                updateFunc(offset/maxDist)
            end
        end)
    end

    stickHandler(leftStick,leftFrame,function(vec) leftInput = vec end)
    stickHandler(rightStick,rightFrame,function(vec) rightInput = vec end)
end

-- =============================================
-- UPDATE LOOP (VR風腕 + 他プレイヤー見せかけ同期)
-- =============================================
local function updateArm(joints, input, init)
    if not joints then return end
    local pitch = -input.Y*sensitivity
    local yaw = input.X*sensitivity

    joints.Upper.C0 = joints.Upper.C0:Lerp(init.Upper * CFrame.Angles(pitch, yaw, 0) * CFrame.new(0,0,-0.2), lerpSpeed)
    joints.Lower.C0 = joints.Lower.C0:Lerp(init.Lower * CFrame.Angles(pitch/2, yaw/2,0), lerpSpeed)
    joints.Hand.C0 = joints.Hand.C0:Lerp(init.Hand * CFrame.Angles(pitch/3, yaw/3,0), lerpSpeed)
end

RunService.RenderStepped:Connect(function()
    -- 自分の腕
    updateArm(rightJoints, rightInput, {Upper=initC0.RightShoulder,Lower=initC0.RightElbow,Hand=initC0.RightWrist})
    updateArm(leftJoints, leftInput, {Upper=initC0.LeftShoulder,Lower=initC0.LeftElbow,Hand=initC0.LeftWrist})

    -- 他プレイヤーの腕（自分の画面上だけ）
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local rJ = getArmJoints(plr.Character,"Right")
            local lJ = getArmJoints(plr.Character,"Left")
            if rJ then updateArm(rJ,rightInput,{Upper=initC0.RightShoulder,Lower=initC0.RightElbow,Hand=initC0.RightWrist}) end
            if lJ then updateArm(lJ,leftInput,{Upper=initC0.LeftShoulder,Lower=initC0.LeftElbow,Hand=initC0.LeftWrist}) end
        end
    end
end)

-- =============================================
-- PERMANENT DEATH OFF（任意）
-- =============================================
humanoid.HealthChanged:Connect(function(h)
    if h <= 0 then humanoid.Health = humanoid.MaxHealth end
end)
