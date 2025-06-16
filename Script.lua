local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local soundId = "rbxassetid://PUT_YOUR_SOUND_ID_HERE" -- Zadejte ID zvuku, který chcete přehrát (Call of Duty zásah zvuk)

local REFRESH_INTERVAL = 5
local HEAD_NAME = "Head"
local AIM_SMOOTHNESS = 0          -- Nastaveno na 0 pro okamžité zaměřování
local AIM_RADIUS = 450            -- Zvětšený dosah pro aim assist
local TAG_NAME = "PlayerNameTag"
local SHOW_LOCAL_PLAYER = true
local airJumpEnabled = false
local aiming = false
local isRightMouseButtonPressed = false
local currentTarget = nil         -- Uloží aktuální zaměřený cíl

----------------------------------------
-- GUI Setup pro Air Jump, Aim Assist a (dále) ESP
----------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AirJumpToggleGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local jumpButton = Instance.new("TextButton")
jumpButton.Size = UDim2.new(0, 200, 0, 50)
jumpButton.Position = UDim2.new(0, 20, 0, 20)
jumpButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
jumpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
jumpButton.TextScaled = true
jumpButton.Text = "Air Jump: OFF"
jumpButton.Font = Enum.Font.SourceSansBold
jumpButton.Parent = screenGui

local aimButton = Instance.new("TextButton")
aimButton.Size = UDim2.new(0, 200, 0, 50)
aimButton.Position = UDim2.new(0, 20, 0, 80)
aimButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
aimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
aimButton.TextScaled = true
aimButton.Text = "Aim Assist: OFF"
aimButton.Font = Enum.Font.SourceSansBold
aimButton.Parent = screenGui

-- Tlačítko pro zapnutí VYKRESLOVÁNÍ ESP (jména a boxy)
local espButton = Instance.new("TextButton")
espButton.Size = UDim2.new(0, 200, 0, 50)
espButton.Position = UDim2.new(0, 20, 0, 140)
espButton.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
espButton.TextColor3 = Color3.fromRGB(255, 255, 255)
espButton.TextScaled = true
espButton.Text = "ESP: ON"
espButton.Font = Enum.Font.SourceSansBold
espButton.Parent = screenGui

-- Proměnná pro zapnutí/vypnutí ESP (drawing boxy a tracery)
local espEnabled = true

-- Toggle Air Jump
jumpButton.MouseButton1Click:Connect(function()
    airJumpEnabled = not airJumpEnabled
    jumpButton.Text = airJumpEnabled and "Air Jump: ON" or "Air Jump: OFF"
    jumpButton.BackgroundColor3 = airJumpEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 50)
end)

-- Toggle Aim Assist
aimButton.MouseButton1Click:Connect(function()
    aiming = not aiming
    aimButton.Text = aiming and "Aim Assist: ON" or "Aim Assist: OFF"
    aimButton.BackgroundColor3 = aiming and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 50)
end)

-- Toggle ESP (přepíná zobrazení jmen i 3D boxů)
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espButton.Text = espEnabled and "ESP: ON" or "ESP: OFF"
    espButton.BackgroundColor3 = espEnabled and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(50, 50, 50)
end)

----------------------------------------
-- Air Jump Logic
----------------------------------------
UserInputService.JumpRequest:Connect(function()
    if not airJumpEnabled then return end
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("Humanoid") and character:FindFirstChild("HumanoidRootPart") then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then return end

        -- Provede manuální skok se zvedacím silou
        character.HumanoidRootPart.Velocity = Vector3.new(
            character.HumanoidRootPart.Velocity.X,
            50, -- Síla skoku nahoru
            character.HumanoidRootPart.Velocity.Z
        )
    end
end)

----------------------------------------
-- Utilitární funkce
----------------------------------------
-- Převede 3D pozici na 2D obrazovku
local function worldToScreen(pos)
    local screenPoint, onScreen = Camera:WorldToViewportPoint(pos)
    return Vector2.new(screenPoint.X, screenPoint.Y), onScreen, screenPoint.Z
end

-- Vzdálenost od středu obrazovky
local function getScreenDistance(vec)
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    return (vec - center).Magnitude
end

----------------------------------------
-- Aim Assist Logic
----------------------------------------
local function getClosestTarget()
    local closest = nil
    local closestDist = AIM_RADIUS

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(HEAD_NAME) then
            local head = player.Character[HEAD_NAME]
            local screenPos, onScreen, depth = worldToScreen(head.Position)

            if onScreen and depth > 0 then
                local dist = getScreenDistance(screenPos)
                if dist < closestDist then
                    -- Kontrola pomocí raycastu (aby se neaimovalo skrz zdi)
                    local origin = Camera.CFrame.Position
                    local direction = (head.Position - origin)
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist

                    local result = workspace:Raycast(origin, direction, rayParams)
                    if not result or result.Instance:IsDescendantOf(player.Character) then
                        closest = head
                        closestDist = dist
                    end
                end
            end
        end
    end

    return closest
end

local function startAimAssist()
    while aiming and isRightMouseButtonPressed do
        local target = getClosestTarget()
        if target then
            currentTarget = target  -- Zapamatuje cílový head
            local camPos = Camera.CFrame.Position
            local direction = (target.Position - camPos).Unit
            local targetCFrame = CFrame.new(camPos, camPos + direction)
            Camera.CFrame = targetCFrame  -- okamžité přenastavení kamery
        end
        wait(0.02)  -- frekvence aktualizace aim assistu
    end
end

-- Detekce střelby a zásahu hráče (přehraje zvuk)
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local rayOrigin = Camera.CFrame.Position
        local rayDirection = Camera.CFrame.LookVector * 500  -- délka střely 500 studů
        local ray = workspace:Raycast(rayOrigin, rayDirection)

        if ray and ray.Instance and ray.Instance.Parent then
            local hitPlayer = Players:GetPlayerFromCharacter(ray.Instance.Parent)
            if hitPlayer then
                playHitSound()  -- přehraje zásahový zvuk
            end
        end
    end
end)

-- Poslech stisku pravého tlačítka myši pro aim assist
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseButtonPressed = true
        startAimAssist()
    end
end)

-- Uvolnění pravého tlačítka myši
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        isRightMouseButtonPressed = false
        currentTarget = nil
    end
end)

----------------------------------------
-- BillboardGui pro zobrazování jmen hráčů (Nametags)
----------------------------------------
local function clearNametags()
    for _, player in Players:GetPlayers() do
        if player.Character and player.Character:FindFirstChild(HEAD_NAME) then
            local head = player.Character[HEAD_NAME]
            local existingTag = head:FindFirstChild(TAG_NAME)
            if existingTag then
                existingTag:Destroy()
            end
        end
    end
end

local function createNametag(player)
    if not player.Character then return end
    local head = player.Character:FindFirstChild(HEAD_NAME)
    if not head or head:FindFirstChild(TAG_NAME) then return end
    if not SHOW_LOCAL_PLAYER and player == LocalPlayer then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = TAG_NAME
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 100, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = head

    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextScaled = true
    textLabel.Text = player.Name
    textLabel.TextColor3 = Color3.new(1, 1, 1)
    textLabel.Font = Enum.Font.SourceSansBold
    textLabel.Parent = billboard
end

local function applyNametags()
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild(HEAD_NAME) then
            createNametag(player)
        end
    end
end

----------------------------------------
-- ESP (Drawing API pro 3D boxy a tracery)
----------------------------------------
-- Nastavení pro boxy a tracery
local Box_Color = Color3.fromRGB(0, 255, 50)
local Box_Thickness = 1.4
local Box_Transparency = 1  -- 1 = viditelné, 0 = neviditelné

local Tracers = true
local Tracer_Color = Color3.fromRGB(0, 255, 50)
local Tracer_Thickness = 1.4
local Tracer_Transparency = 1

local Autothickness = false  -- automatická tloušťka podle vzdálenosti
local Team_Check = false
local red = Color3.fromRGB(227, 52, 52)
local green = Color3.fromRGB(88, 217, 24)

local function NewLine()
    local line = Drawing.new("Line")
    line.Visible = false
    line.From = Vector2.new(0, 0)
    line.To = Vector2.new(1, 1)
    line.Color = Box_Color
    line.Thickness = Box_Thickness
    line.Transparency = Box_Transparency
    return line
end

-- Funkce, která vykreslí ESP boxy a tracery pro daného hráče
local function setupESPForPlayer(v)
    local lines = {
        line1 = NewLine(),
        line2 = NewLine(),
        line3 = NewLine(),
        line4 = NewLine(),
        line5 = NewLine(),
        line6 = NewLine(),
        line7 = NewLine(),
        line8 = NewLine(),
        line9 = NewLine(),
        line10 = NewLine(),
        line11 = NewLine(),
        line12 = NewLine(),
        Tracer = NewLine()
    }

    lines.Tracer.Color = Tracer_Color
    lines.Tracer.Thickness = Tracer_Thickness
    lines.Tracer.Transparency = Tracer_Transparency

    local function ESP()
        local connection
        connection = RunService.RenderStepped:Connect(function()
            if espEnabled and v.Character and v.Character:FindFirstChild("Humanoid") and 
               v.Character:FindFirstChild("HumanoidRootPart") and v.Name ~= LocalPlayer.Name and 
               v.Character.Humanoid.Health > 0 and v.Character:FindFirstChild(HEAD_NAME) then

                local pos, vis = Camera:WorldToViewportPoint(v.Character.HumanoidRootPart.Position)
                if vis then
                    local Scale = v.Character.Head.Size.Y/2
                    local Size = Vector3.new(2,3,1.5) * (Scale * 2)  -- upravit pro správnou velikost boxu

                    local Top1 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(-Size.X, Size.Y, -Size.Z)).p)
                    local Top2 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(-Size.X, Size.Y, Size.Z)).p)
                    local Top3 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(Size.X, Size.Y, Size.Z)).p)
                    local Top4 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(Size.X, Size.Y, -Size.Z)).p)

                    local Bottom1 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(-Size.X, -Size.Y, -Size.Z)).p)
                    local Bottom2 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(-Size.X, -Size.Y, Size.Z)).p)
                    local Bottom3 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(Size.X, -Size.Y, Size.Z)).p)
                    local Bottom4 = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(Size.X, -Size.Y, -Size.Z)).p)

                    -- Horní část:
                    lines.line1.From = Vector2.new(Top1.X, Top1.Y)
                    lines.line1.To = Vector2.new(Top2.X, Top2.Y)
                    lines.line2.From = Vector2.new(Top2.X, Top2.Y)
                    lines.line2.To = Vector2.new(Top3.X, Top3.Y)
                    lines.line3.From = Vector2.new(Top3.X, Top3.Y)
                    lines.line3.To = Vector2.new(Top4.X, Top4.Y)
                    lines.line4.From = Vector2.new(Top4.X, Top4.Y)
                    lines.line4.To = Vector2.new(Top1.X, Top1.Y)

                    -- Spodní část:
                    lines.line5.From = Vector2.new(Bottom1.X, Bottom1.Y)
                    lines.line5.To = Vector2.new(Bottom2.X, Bottom2.Y)
                    lines.line6.From = Vector2.new(Bottom2.X, Bottom2.Y)
                    lines.line6.To = Vector2.new(Bottom3.X, Bottom3.Y)
                    lines.line7.From = Vector2.new(Bottom3.X, Bottom3.Y)
                    lines.line7.To = Vector2.new(Bottom4.X, Bottom4.Y)
                    lines.line8.From = Vector2.new(Bottom4.X, Bottom4.Y)
                    lines.line8.To = Vector2.new(Bottom1.X, Bottom1.Y)

                    -- Spojovací čáry:
                    lines.line9.From = Vector2.new(Bottom1.X, Bottom1.Y)
                    lines.line9.To = Vector2.new(Top1.X, Top1.Y)
                    lines.line10.From = Vector2.new(Bottom2.X, Bottom2.Y)
                    lines.line10.To = Vector2.new(Top2.X, Top2.Y)
                    lines.line11.From = Vector2.new(Bottom3.X, Bottom3.Y)
                    lines.line11.To = Vector2.new(Top3.X, Top3.Y)
                    lines.line12.From = Vector2.new(Bottom4.X, Bottom4.Y)
                    lines.line12.To = Vector2.new(Top4.X, Top4.Y)

                    -- Tracer:
                    if Tracers then
                        local trace = Camera:WorldToViewportPoint((v.Character.HumanoidRootPart.CFrame * CFrame.new(0, -Size.Y, 0)).p)
                        lines.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                        lines.Tracer.To = Vector2.new(trace.X, trace.Y)
                    end

                    -- Team Check:
                    if Team_Check then
                        if v.TeamColor == LocalPlayer.TeamColor then
                            for _, line in pairs(lines) do
                                line.Color = green
                            end
                        else
                            for _, line in pairs(lines) do
                                line.Color = red
                            end
                        end
                    end

                    -- Autothickness:
                    if Autothickness then
                        local distance = (LocalPlayer.Character.HumanoidRootPart.Position - v.Character.HumanoidRootPart.Position).Magnitude
                        local value = math.clamp(1/distance*100, 0.1, 4)
                        for _, line in pairs(lines) do
                            line.Thickness = value
                        end
                    else
                        for _, line in pairs(lines) do
                            line.Thickness = Box_Thickness
                        end
                    end

                    for _, line in pairs(lines) do
                        if line ~= lines.Tracer then
                            line.Visible = true
                        end
                    end
                    if Tracers then lines.Tracer.Visible = true end
                else
                    for _, line in pairs(lines) do
                        line.Visible = false
                    end
                end
            else
                for _, line in pairs(lines) do
                    line.Visible = false
                end
                if not game.Players:FindFirstChild(v.Name) then
                    connection:Disconnect()
                end
            end
        end)
    end

    coroutine.wrap(ESP)()
end

-- Nastavit ESP pro všechny existující hráče
for i, v in pairs(game.Players:GetChildren()) do
    if v ~= LocalPlayer then
        setupESPForPlayer(v)
    end
end

-- Nastavit ESP pro nové hráče
Players.PlayerAdded:Connect(function(newplr)
    newplr.CharacterAdded:Connect(function(character)
        wait(1)
        setupESPForPlayer(newplr)
    end)
end)

----------------------------------------
-- Hlavní smyčka pro aktualizaci nametagů
----------------------------------------
while true do
    clearNametags()
    applyNametags()
    task.wait(REFRESH_INTERVAL)
end
