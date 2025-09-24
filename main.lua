-- =============================================
-- Roblox Universal Arm Controller (Empyrean-based)
-- Author: 修正版
-- =============================================
-- Features:
-- - PermanentDeath ON/OFF
-- - Left stick = movement
-- - Right stick = arm rotate + extend
-- - Arm can grab ANY part (weld)
-- - Works with or without hats (arms always visible)
-- - PC / Mobile compatible (sticks only appear on mobile)
-- =============================================

-- SETTINGS
local PermanentDeathEnabled = false -- true = PermanentDeath ON
local control = "mobile" -- "pc" or "mobile"

-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")

-- ====================================================
-- ARM FIX (always visible, hat or not)
-- ====================================================
local function EnsureArm(name, sideOffset)
    local arm = character:FindFirstChild(name)
    if not arm then
        arm = Instance.new("Part")
        arm.Name = name
        arm.Size = Vector3.new(1,2,1)
        arm.Anchored = false
        arm.CanCollide = false
        arm.Color = Color3.fromRGB(255, 200, 150)
        arm.Parent = character

        local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
        local weld = Instance.new("Motor6D")
        weld.Part0 = torso
        weld.Part1 = arm
        weld.C0 = CFrame.new(sideOffset,0,0)
        weld.Parent = arm
    end
    return arm
end

local leftArm = EnsureArm("Left Arm",-1.5)
local rightArm = EnsureArm("Right Arm",1.5)

-- ====================================================
-- MOBILE STICKS (UI)
-- ====================================================
local screenGui = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))

local function createStick(side)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0,120,0,120)
    frame.AnchorPoint = Vector2.new(0.5,0.5)
    frame.BackgroundColor3 = Color3.fromRGB(50,50,50)
    frame.BackgroundTransparency = 0.3
    frame.Parent = screenGui

    if side == "left" then
        frame.Position = UDim2.new(0.35,0,0.8,0)
    else
        frame.Position = UDim2.new(0.65,0,0.8,0)
    end

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

local leftFrame, leftStick = createStick("left")
local rightFrame, rightStick = createStick("right")

local leftInput = Vector3.zero
local rightInput = Vector2.zero

-- ====================================================
-- STICK HANDLERS
-- ====================================================
local function stickHandler(stick,frame,updateFunc)
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
            local rel = frame.AbsolutePosition + frame.AbsoluteSize/2
            local offset = Vector2.new(input.Position.X-rel.X, input.Position.Y-rel.Y)
            local maxDist = frame.AbsoluteSize.X/2
            if offset.Magnitude > maxDist then
                offset = offset.Unit*maxDist
            end
            stick.Position = UDim2.new(0.5,offset.X,0.5,offset.Y)
            updateFunc(offset/maxDist)
        end
    end)
end

stickHandler(leftStick,leftFrame,function(vec)
    leftInput = Vector3.new(vec.X,0,-vec.Y)
end)
stickHandler(rightStick,rightFrame,function(vec)
    rightInput = vec
end)

-- ====================================================
-- ARM EXTEND + GRAB LOGIC
-- ====================================================
local grabbedPart = nil
local grabWeld = nil

local function tryGrab(arm)
    if grabbedPart then return end
    local ray = Ray.new(arm.Position, arm.CFrame.LookVector*3)
    local part,pos = workspace:FindPartOnRay(ray, character, false, true)
    if part then
        grabbedPart = part
        grabWeld = Instance.new("Weld")
        grabWeld.Part0 = arm
        grabWeld.Part1 = part
        grabWeld.C0 = arm.CFrame:toObjectSpace(part.CFrame)
        grabWeld.Parent = arm
    end
end

local function releaseGrab()
    if grabWeld then grabWeld:Destroy() end
    grabbedPart = nil
    grabWeld = nil
end

-- ====================================================
-- MAIN LOOP
-- ====================================================
RunService.RenderStepped:Connect(function()
    EnsureArm("Left Arm",-1.5)
    EnsureArm("Right Arm",1.5)

    -- 移動
    if leftInput.Magnitude > 0 then
        local moveDir = (workspace.CurrentCamera.CFrame:VectorToWorldSpace(leftInput))
        humanoid:Move(moveDir,true)
    end

    -- 腕操作
    if rightInput.Magnitude > 0 then
        local arm = character:FindFirstChild("Right Arm")
        if arm and arm:FindFirstChildOfClass("Motor6D") then
            local joint = arm:FindFirstChildOfClass("Motor6D")
            -- 角度
            joint.C0 = CFrame.new(1.5,0,0) * CFrame.Angles(-rightInput.Y*1.2, rightInput.X*1.2, 0)
            -- 前方に伸ばす
            arm.CFrame = arm.CFrame + arm.CFrame.LookVector*(rightInput.Magnitude*2)
            -- 掴む
            tryGrab(arm)
        end
    else
        -- 入力がない時は掴んだものを離す
        releaseGrab()
    end
end)

-- ====================================================
-- PermanentDeath
-- ====================================================
if not PermanentDeathEnabled then
    humanoid.HealthChanged:Connect(function(health)
        if health <= 0 then
            humanoid.Health = humanoid.MaxHealth
        end
    end)
end
