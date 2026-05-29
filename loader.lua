--[[
    NightFall Loader v5.2 — mobile-safe GUI + keyless load
    Repo: https://github.com/quarter67/loader

    loadstring(game:HttpGet("https://raw.githubusercontent.com/quarter67/loader/main/loader.lua?t=" .. tostring(os.time()) .. "&v=520"))()
]]

local VERSION = "5.2.1-keyless"

local CONFIG = {
    PLACE_ID = 134225461562780,
    KEYLESS_URLS = {
        "https://raw.githubusercontent.com/quarter67/NightFall/main/homelandertest.lua",
        "https://raw.githubusercontent.com/quarter67/NightFall/main/script/improved_script.lua",
        "https://raw.githubusercontent.com/quarter67/NightFall/main/improved_script.lua",
    },
    LOCAL_PATHS = {
        "homelandertest.lua",
        "ScriptHub/homelandertest.lua",
        "workspace/homelandertest.lua",
    },
}

print("[NightFall] Loader v" .. VERSION)

if game.PlaceId ~= CONFIG.PLACE_ID then
    warn("[NightFall] Wrong game.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local IS_MOBILE = UIS.TouchEnabled == true

-- ── Movement (never block walking) ──────────────────────────────────────────

local function keepMovementOn()
    pcall(function() GuiService.TouchControlsEnabled = true end)
    pcall(function()
        UIS.MouseBehavior = Enum.MouseBehavior.Default
        UIS.MouseIconEnabled = true
    end)
end

keepMovementOn()
task.spawn(function()
    while true do
        keepMovementOn()
        task.wait(0.5)
    end
end)

-- ── PlayerGui ───────────────────────────────────────────────────────────────

local function getPlayerGui()
    local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
    return plr:FindFirstChild("PlayerGui") or plr:WaitForChild("PlayerGui", 5)
end

pcall(function()
    local pg = getPlayerGui()
    if pg then
        local old = pg:FindFirstChild("NightFallKeyUI")
        if old then old:Destroy() end
    end
end)

-- ── HTTP (Delta-friendly) ───────────────────────────────────────────────────

local function getRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local REQ = getRequest()

local function httpGet(url)
    local headers = { ["Accept"] = "text/plain, */*", ["User-Agent"] = "NightFallLoader/" .. VERSION }

    if REQ then
        local ok, res = pcall(function()
            return REQ({ Url = url, Method = "GET", Headers = headers })
        end)
        if ok and type(res) == "table" and res.Body and res.Body ~= "" then return res.Body end
        if ok and type(res) == "string" and res ~= "" then return res end
    end

    local ok, body = pcall(function() return HttpService:GetAsync(url, true, headers) end)
    if ok and body and body ~= "" then return body end

    ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and body and body ~= "" then return body end

    return nil
end

local function fsRead(path)
    local ok, data = pcall(function()
        if isfile and readfile and isfile(path) then return readfile(path) end
    end)
    return ok and data or nil
end

local function loadLocalKeyless()
    for _, path in ipairs(CONFIG.LOCAL_PATHS) do
        local content = fsRead(path)
        if content and #content > 500 then
            return content, path
        end
    end
    return nil, nil
end

local function downloadKeyless()
    local localSrc, localPath = loadLocalKeyless()
    if localSrc then
        print("[NightFall] Using local " .. localPath)
        return localSrc, nil
    end

    for i, base in ipairs(CONFIG.KEYLESS_URLS) do
        local url = base .. "?t=" .. tostring(os.time()) .. "&try=" .. i
        print("[NightFall] Downloading keyless...")
        local body = httpGet(url)
        if body and #body > 500 and not body:find("<!DOCTYPE") and body:sub(1, 1) ~= "{" then
            return body, nil
        end
    end

    return nil, "Download failed — enable HTTP in Delta settings"
end

-- ── Compile / run ───────────────────────────────────────────────────────────

local function getEnv()
    if typeof(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then return g end
    end
    if typeof(shared) == "table" then return shared end
    return _G
end

local function patchKeylessSource(source)
    -- homelandertest dev build: full premium by default — do not inject NF_KEYLESS
    if source:find("resolvePremiumAccess") or source:find("MOBILE%-MOVE%-FIX") then
        return source
    end
    source = source:gsub(
        "local isPremium, allowRun = resolveScriptAccess%(%)",
        "local isPremium, allowRun = false, true",
        1
    )
    return table.concat({
        "_G.NF_KEYLESS = true",
        "shared.NF_KEYLESS = true",
        "pcall(function() if typeof(getgenv)=='function' then getgenv().NF_KEYLESS=true end end)",
        source,
    }, "\n")
end

local function compile(source, name)
    source = patchKeylessSource(source)
    local env = getEnv()

    if type(load) == "function" then
        local fn, err = load(source, name or "NightFallKeyless", "t", env)
        if type(fn) == "function" then return fn, nil end
        if err then warn("[NightFall] compile: " .. tostring(err)) end
    end

    local ls = loadstring or env.loadstring
    if type(ls) ~= "function" then return nil, "No loadstring" end
    local fn, err = ls(source, name or "NightFallKeyless")
    if type(fn) ~= "function" then return nil, err end
    pcall(function() if setfenv then setfenv(fn, env) end end)
    return fn, nil
end

local function hubExists()
    local pg = getPlayerGui()
    if not pg then return false end
    return pg:FindFirstChild("ScriptHubToggle", true) ~= nil
        or pg:FindFirstChild("ScriptHub", true) ~= nil
end

local function waitForHub(sec)
    local t0 = os.clock()
    while os.clock() - t0 < (sec or 15) do
        if hubExists() then return true end
        keepMovementOn()
        task.wait(0.2)
    end
    return false
end

local function runKeyless(source)
    local fn, err = compile(source, "NightFallKeyless")
    if not fn then
        return false, tostring(err or "compile failed")
    end
    keepMovementOn()
    local ok, runErr = pcall(fn)
    if not ok then
        return false, tostring(runErr)
    end
    if waitForHub(15) then
        return true, nil
    end
    return false, "Script ran but hub UI not found — check F9"
end

-- ── GUI (same layout as v5.1) ───────────────────────────────────────────────

local pg = getPlayerGui()
if not pg then
    warn("[NightFall] No PlayerGui.")
    return
end

keepMovementOn()

local gui = Instance.new("ScreenGui")
gui.Name = "NightFallKeyUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = pg

local panel = Instance.new("Frame")
panel.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
panel.BorderSizePixel = 0
panel.Active = false
if IS_MOBILE then
    panel.AnchorPoint = Vector2.new(0.5, 0)
    panel.Position = UDim2.new(0.5, 0, 0, 8)
    panel.Size = UDim2.new(0.94, 0, 0, 280)
else
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0, 380, 0, 320)
end
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(55, 58, 72)
stroke.Thickness = 1
stroke.Transparency = 0.35
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 14, 0, 10)
title.Size = UDim2.new(1, -28, 0, 26)
title.Font = Enum.Font.GothamBold
title.TextSize = IS_MOBILE and 20 or 18
title.TextColor3 = Color3.fromRGB(240, 241, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "NightFall"
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 14, 0, 36)
subtitle.Size = UDim2.new(1, -28, 0, 32)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(140, 144, 160)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.TextWrapped = true
subtitle.Text = "Enter a key for premium, or use keyless below."
subtitle.Parent = panel

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 14, 0, 72)
status.Size = UDim2.new(1, -28, 0, 24)
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(52, 211, 153)
status.TextXAlignment = Enum.TextXAlignment.Left
status.Text = "Menu open — you can still walk and play."
status.Parent = panel

local box = Instance.new("TextBox")
box.Position = UDim2.new(0, 14, 0, 104)
box.Size = UDim2.new(1, -28, 0, 34)
box.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
box.TextColor3 = Color3.fromRGB(240, 241, 245)
box.PlaceholderText = "NF-XXXX-XXXX-XXXX"
box.PlaceholderColor3 = Color3.fromRGB(120, 124, 140)
box.Font = Enum.Font.Gotham
box.TextSize = 14
box.ClearTextOnFocus = false
box.Parent = panel

Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
local boxPad = Instance.new("UIPadding", box)
boxPad.PaddingLeft = UDim.new(0, 10)
boxPad.PaddingRight = UDim.new(0, 10)

local function makeBtn(name, text, xScale, wScale, y, color)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Size = UDim2.new(wScale, 0, 0, 36)
    btn.Position = UDim2.new(xScale, 0, 0, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 241, 245)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.AutoButtonColor = true
    btn.Parent = panel
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local getKeyBtn = makeBtn("GetKey", "Get Key", 0, 0.48, 150, Color3.fromRGB(28, 30, 38))
local continueBtn = makeBtn("Continue", "Continue", 0.52, 0.48, 150, Color3.fromRGB(99, 102, 241))
local keylessBtn = makeBtn("Keyless", "Continue with keyless version", 0, 1, 196, Color3.fromRGB(28, 30, 38))

local hint = Instance.new("TextLabel")
hint.BackgroundTransparency = 1
hint.Position = UDim2.new(0, 14, 0, 242)
hint.Size = UDim2.new(1, -28, 0, 28)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(120, 124, 140)
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Text = "v" .. VERSION .. " · keyless → homelandertest.lua (full premium)"
hint.Parent = panel

-- ── Buttons ─────────────────────────────────────────────────────────────────

local busy = false

local function setStatus(msg, isErr)
    status.Text = msg
    status.TextColor3 = isErr and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(52, 211, 153)
    print("[NightFall] " .. msg)
end

local function onTap(btn, fn)
    if IS_MOBILE then btn.Activated:Connect(fn) else btn.MouseButton1Click:Connect(fn) end
end

local function lockBtns(locked)
    getKeyBtn.Active = not locked
    continueBtn.Active = not locked
    keylessBtn.Active = not locked
end

onTap(getKeyBtn, function()
    setStatus("Get Key — premium flow coming soon.", true)
end)

onTap(continueBtn, function()
    local key = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if key == "" then
        setStatus("Enter a key first.", true)
        return
    end
    setStatus("Premium key flow — coming soon.", true)
end)

onTap(keylessBtn, function()
    if busy then return end
    busy = true
    lockBtns(true)
    keylessBtn.Text = "Downloading..."
    setStatus("Downloading keyless script...")

    task.spawn(function()
        keepMovementOn()
        local source, err = downloadKeyless()
        if not source then
            busy = false
            lockBtns(false)
            keylessBtn.Text = "Continue with keyless version"
            setStatus(tostring(err), true)
            return
        end

        setStatus("Starting NightFall...")
        keepMovementOn()
        local ok, runErr = runKeyless(source)
        if ok then
            pcall(function() gui:Destroy() end)
            print("[NightFall] Keyless load complete.")
            return
        end

        busy = false
        lockBtns(false)
        keylessBtn.Text = "Continue with keyless version"
        setStatus(tostring(runErr), true)
    end)
end)

keepMovementOn()
print("[NightFall] Loader GUI shown.")
