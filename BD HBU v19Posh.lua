--[[
=====================================================================
    BD HBU v10.4 (Advanced Stealth & Anti-Scan Protection)
=====================================================================
--]]

-- ใช้เงื่อนไขปิดกั้นไม่ให้สคริปต์รันซ้ำและซ่อนตัวจาก Global Table
if _G.BDHBU_Active then return end
_G.BDHBU_Active = true

-- แยกตัวแปรทั้งหมดให้อยู่ในขอบเขต Local เพื่อความปลอดภัยสูงสุด
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local CONFIG = {
    FOV_RADIUS     = 190,
    FOV_COLOR      = Color3.fromRGB(255, 255, 255),
    FOV_THICKNESS  = 2,
    CURVE_ENABLED  = true,
}

-- สร้าง FOV UI แบบซ่อนเร้น
local function initFOV()
    local parentGui
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then parentGui = hui end
    end
    parentGui = parentGui or LocalPlayer:WaitForChild("PlayerGui")

    local fovGui = Instance.new("ScreenGui")
    fovGui.Name = "_" 
    fovGui.IgnoreGuiInset = true
    fovGui.ResetOnSpawn = false
    fovGui.Parent = parentGui

    local fovFrame = Instance.new("Frame")
    fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    fovFrame.Size = UDim2.fromOffset(CONFIG.FOV_RADIUS * 2, CONFIG.FOV_RADIUS * 2)
    fovFrame.BackgroundTransparency = 1
    fovFrame.Parent = fovGui

    local fovCorner = Instance.new("UICorner")
    fovCorner.CornerRadius = UDim.new(1, 0)
    fovCorner.Parent = fovFrame

    local fovStroke = Instance.new("UIStroke")
    fovStroke.Color = CONFIG.FOV_COLOR
    fovStroke.Thickness = CONFIG.FOV_THICKNESS
    fovStroke.Transparency = 0.1
    fovStroke.Parent = fovFrame

    return fovFrame
end

local fovFrame = initFOV()

-- ระบบค้นหาเป้าหมายในวง FOV
local currentTarget = nil
local function getClosestTargetInFOV()
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local radius = CONFIG.FOV_RADIUS

    if currentTarget and currentTarget.Character then
        local hum = currentTarget.Character:FindFirstChildOfClass("Humanoid")
        local hrp = currentTarget.Character:FindFirstChild("HumanoidRootPart")
        if hum and hum.Health > 0 and hrp then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude <= radius then
                return hrp
            end
        end
    end

    currentTarget = nil
    local shortestDist = radius
    local bestHRP = nil

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - screenCenter).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        bestHRP = hrp
                        currentTarget = plr
                    end
                end
            end
        end
    end
    return bestHRP
end

RunService.RenderStepped:Connect(function()
    if fovFrame then
        fovFrame.Size = UDim2.fromOffset(CONFIG.FOV_RADIUS * 2, CONFIG.FOV_RADIUS * 2)
    end
    getClosestTargetInFOV()
end)

-- ดักจับการยิงด้วย newcclosure เพื่อหลบเลี่ยงการตรวจสอบฟังก์ชัน Lua ทั่วไป
if hookmetamethod and getnamecallmethod and newcclosure then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}

        if method == "FireServer" and CONFIG.CURVE_ENABLED then
            local name = tostring(self.Name):lower()
            if name == "shoot" or name == "fire" or name == "bullet" then
                local targetHRP = getClosestTargetInFOV()
                if targetHRP then
                    for i, arg in ipairs(args) do
                        if typeof(arg) == "Vector3" then
                            args[i] = targetHRP.Position
                        elseif typeof(arg) == "CFrame" then
                            args[i] = CFrame.new(arg.Position, targetHRP.Position)
                        end
                    end
                end
            end
        end

        return oldNamecall(self, unpack(args))
    end))
end
