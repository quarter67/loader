--[[
    NightFall Loader v6 — PC + mobile auto-detect, key system, keyless builds
    Repo: https://github.com/quarter67/loader

    loadstring(game:HttpGet("https://raw.githubusercontent.com/quarter67/loader/main/loader.lua?t=" .. tostring(os.time()) .. "&v=600"))()
]]

local VERSION = "6.0.0-unified"

local CONFIG = {
    PLACE_ID = 134225461562780,
    API_URL_FALLBACK = "https://tackle-soldiers-miller-niagara.trycloudflare.com",
    API_URL_GITHUB = "https://raw.githubusercontent.com/quarter67/NightFall/main/api-url.txt",
    PC = {
        label = "PC",
        scriptUrls = {
            "https://raw.githubusercontent.com/quarter67/NightFall/main/SurviveHomelanderPC.lua",
        },
        keylessUrls = {
            "https://raw.githubusercontent.com/quarter67/NightFall/main/SurviveHomelanderPCkeyless.lua",
        },
        localPaths = {
            "SurviveHomelanderPC.lua",
            "script/SurviveHomelanderPC.lua",
            "ScriptHub/SurviveHomelanderPC.lua",
            "workspace/SurviveHomelanderPC.lua",
            "nightfall/SurviveHomelanderPC.lua",
            "Downloads/script/SurviveHomelanderPC.lua",
        },
        keylessLocalPaths = {
            "SurviveHomelanderPCkeyless.lua",
            "script/SurviveHomelanderPCkeyless.lua",
            "ScriptHub/SurviveHomelanderPCkeyless.lua",
            "workspace/SurviveHomelanderPCkeyless.lua",
            "nightfall/SurviveHomelanderPCkeyless.lua",
            "Downloads/script/SurviveHomelanderPCkeyless.lua",
        },
        premiumMarker = "SurviveHomelanderPC",
        keylessMarker = "SurviveHomelanderPCkeyless",
        premiumName = "SurviveHomelanderPC",
        keylessName = "SurviveHomelanderPCkeyless",
    },
    MOBILE = {
        label = "Mobile",
        scriptUrls = {
            "https://raw.githubusercontent.com/quarter67/NightFall/main/SurviveHomelanderMobile.lua",
        },
        keylessUrls = {
            "https://raw.githubusercontent.com/quarter67/NightFall/main/SurviveHomelanderMobilekeyless.lua",
        },
        localPaths = {
            "SurviveHomelanderMobile.lua",
            "script/SurviveHomelanderMobile.lua",
            "ScriptHub/SurviveHomelanderMobile.lua",
            "workspace/SurviveHomelanderMobile.lua",
            "nightfall/SurviveHomelanderMobile.lua",
            "Downloads/script/SurviveHomelanderMobile.lua",
        },
        keylessLocalPaths = {
            "SurviveHomelanderMobilekeyless.lua",
            "script/SurviveHomelanderMobilekeyless.lua",
            "ScriptHub/SurviveHomelanderMobilekeyless.lua",
            "workspace/SurviveHomelanderMobilekeyless.lua",
            "nightfall/SurviveHomelanderMobilekeyless.lua",
            "Downloads/script/SurviveHomelanderMobilekeyless.lua",
        },
        premiumMarker = "SurviveHomelanderMobile",
        keylessMarker = "SurviveHomelanderMobilekeyless",
        premiumName = "SurviveHomelanderMobile",
        keylessName = "SurviveHomelanderMobilekeyless",
    },
}

if game.PlaceId ~= CONFIG.PLACE_ID then
    warn("[NightFall] Wrong game.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local function detectMobileDevice()
    if typeof(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then
            if g.NF_FORCE_MOBILE == true then return true end
            if g.NF_FORCE_MOBILE == false then return false end
        end
    end
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        return true
    end
    if UserInputService.TouchEnabled and UserInputService.GyroscopeEnabled then
        return true
    end
    if UserInputService.TouchEnabled and UserInputService.AccelerometerEnabled then
        return true
    end
    local cam = Workspace.CurrentCamera
    if cam then
        local vp = cam.ViewportSize
        if vp.X > 0 and vp.Y > vp.X and vp.X < 980 then
            return true
        end
    end
    return UserInputService.TouchEnabled == true
end

local IS_MOBILE = detectMobileDevice()
local PLATFORM = IS_MOBILE and CONFIG.MOBILE or CONFIG.PC

print("[NightFall] Loader v" .. VERSION .. " · " .. PLATFORM.label .. " mode")

local function keepMovementOn()
    pcall(function() GuiService.TouchControlsEnabled = true end)
    pcall(function()
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        UserInputService.MouseIconEnabled = true
    end)
end

keepMovementOn()
task.spawn(function()
    while true do
        keepMovementOn()
        task.wait(0.5)
    end
end)

local function getEnv()
    if typeof(getgenv) == "function" then
        local ok, g = pcall(getgenv)
        if ok and type(g) == "table" then return g end
    end
    if typeof(shared) == "table" then return shared end
    return _G
end

local function getRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    return nil
end

local REQ = getRequest()

local function httpGet(url)
    local headers = {
        ["Accept"] = "text/plain, application/json, */*",
        ["User-Agent"] = "NightFallLoader/" .. VERSION,
    }

    if REQ then
        local ok, res = pcall(function()
            return REQ({ Url = url, Method = "GET", Headers = headers })
        end)
        if ok and type(res) == "table" and res.Body and res.Body ~= "" then
            return res.Body
        end
    end

    local ok, body = pcall(function()
        return HttpService:GetAsync(url, true, headers)
    end)
    if ok and body and body ~= "" then return body end

    ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and body and body ~= "" then return body end

    return nil
end

local function httpGetJson(url)
    local body = httpGet(url)
    if not body or body:sub(1, 1) == "<" then return nil, "Bad response from server" end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if ok and type(data) == "table" then return data end
    return nil, "Invalid JSON from server"
end

local function fsRead(path)
    local ok, data = pcall(function()
        if isfile and readfile and isfile(path) then return readfile(path) end
    end)
    return ok and data or nil
end

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function resolveApiBase()
    local body = httpGet(CONFIG.API_URL_GITHUB)
    if body then
        local url = trim(body:match("(https?://[%w%-%.]+[%w%-%.%:/]+)"))
        if url and url ~= "" then
            url = url:gsub("/+$", "")
            print("[NightFall] API: " .. url)
            return url
        end
    end
    print("[NightFall] API fallback: " .. CONFIG.API_URL_FALLBACK)
    return CONFIG.API_URL_FALLBACK:gsub("/+$", "")
end

local API_BASE = resolveApiBase()
local KEY_SITE = API_BASE

local function getHwid()
    local ok, id = pcall(function()
        if typeof(gethwid) == "function" then return gethwid() end
        if typeof(get_hwid) == "function" then return get_hwid() end
        if syn and type(syn.fingerprint) == "function" then return syn.fingerprint() end
    end)
    if ok and id and tostring(id) ~= "" then return tostring(id) end
    local plr = Players.LocalPlayer
    if plr then return "NF-" .. tostring(plr.UserId) end
    return "NF-unknown"
end

local HWID = getHwid()

local function isValidScriptBody(body, mode)
    if not body or #body <= 500 or body:find("<!DOCTYPE") or body:sub(1, 1) == "{" then
        return false
    end
    if mode == "keyless" then
        return body:find(PLATFORM.keylessMarker) or body:find("resolveScriptAccess")
    end
    return body:find(PLATFORM.premiumMarker) or body:find("resolveScriptAccess")
end

local function loadLocalScript(paths, mode)
    for _, path in ipairs(paths) do
        local content = fsRead(path)
        if isValidScriptBody(content, mode) then
            return content, path
        end
    end
    return nil, nil
end

local function downloadFromUrls(urls, mode)
    for i, base in ipairs(urls) do
        local url = base .. "?t=" .. tostring(os.time()) .. "&try=" .. i
        print("[NightFall] Downloading " .. PLATFORM.label .. " script from GitHub...")
        local body = httpGet(url)
        if isValidScriptBody(body, mode) then
            return body, nil
        end
    end
    local label = mode == "keyless" and PLATFORM.keylessName or PLATFORM.premiumName
    return nil, "GitHub download failed — enable HTTP or use local " .. label .. ".lua"
end

local function downloadFromApi(key)
    local url = string.format(
        "%s/api/script?key=%s&hwid=%s",
        API_BASE,
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(HWID)
    )
    print("[NightFall] Fetching script from key server...")
    local body = httpGet(url)
    if isValidScriptBody(body, "premium") then
        return body, nil
    end
    if body and body:sub(1, 1) == "{" then
        local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
        if ok and data and data.error then
            return nil, data.error
        end
    end
    return nil, nil
end

local function acquireScript(key)
    local localSrc, localPath = loadLocalScript(PLATFORM.localPaths, "premium")
    if localSrc then
        print("[NightFall] Using local file: " .. localPath)
        return localSrc, nil
    end

    if key and key ~= "" then
        local fromApi, apiErr = downloadFromApi(key)
        if fromApi then return fromApi, nil end
        if apiErr then
            warn("[NightFall] API script: " .. tostring(apiErr))
        end
    end

    return downloadFromUrls(PLATFORM.scriptUrls, "premium")
end

local function acquireKeylessScript()
    local localSrc, localPath = loadLocalScript(PLATFORM.keylessLocalPaths, "keyless")
    if localSrc then
        print("[NightFall] Using local keyless file: " .. localPath)
        return localSrc, nil
    end

    return downloadFromUrls(PLATFORM.keylessUrls, "keyless")
end

local function patchPremiumKey(source, key)
    local safe = key:gsub("\\", "\\\\"):gsub('"', '\\"')
    return table.concat({
        "pcall(function()",
        '  if typeof(getgenv)=="function" then getgenv().SCRIPT_KEY="' .. safe .. '" end',
        '  shared.SCRIPT_KEY="' .. safe .. '"',
        '  _G.SCRIPT_KEY="' .. safe .. '"',
        "end)",
        source,
    }, "\n")
end

local function compile(source, name)
    local env = getEnv()

    if type(load) == "function" then
        local fn, err = load(source, name or PLATFORM.premiumName, "t", env)
        if type(fn) == "function" then return fn, nil end
        if err then warn("[NightFall] compile: " .. tostring(err)) end
    end

    local ls = loadstring or env.loadstring
    if type(ls) ~= "function" then return nil, "No loadstring" end
    local fn, err = ls(source, name or PLATFORM.premiumName)
    if type(fn) ~= "function" then return nil, err end
    pcall(function() if setfenv then setfenv(fn, env) end end)
    return fn, nil
end

local function getPlayerGui()
    local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
    return plr:FindFirstChild("PlayerGui") or plr:WaitForChild("PlayerGui", 5)
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

local function runSource(source, label)
    local fn, err = compile(source, label)
    if not fn then return false, tostring(err or "compile failed") end

    keepMovementOn()

    task.spawn(function()
        for _ = 1, 50 do
            if hubExists() then
                pcall(function() gui:Destroy() end)
                return
            end
            keepMovementOn()
            task.wait(0.2)
        end
    end)

    local ok, runErr = pcall(fn)
    if hubExists() then
        pcall(function() gui:Destroy() end)
        if not ok then
            warn("[NightFall] Hub loaded with errors: " .. tostring(runErr))
            return true, nil
        end
    elseif not ok then
        return false, tostring(runErr)
    end
    if waitForHub(15) then
        pcall(function() gui:Destroy() end)
        return true, nil
    end
    return false, "Script ran but hub UI not found — check F9 console"
end

local function validateKey(key)
    local url = string.format(
        "%s/api/validate?key=%s&hwid=%s",
        API_BASE,
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(HWID)
    )
    local data, err = httpGetJson(url)
    if not data then return false, err or "Could not reach key server" end
    if data.valid == true then return true, data end
    local msg = data.error or "Invalid key"
    if msg == "KEY_EXPIRED" then msg = "Key expired — get a new one" end
    if msg == "HWID_MISMATCH" then msg = "Key locked to another device" end
    if msg == "KEY_REVOKED" then msg = "Key revoked" end
    return false, msg
end

-- ── GUI ─────────────────────────────────────────────────────────────────────

local pg = getPlayerGui()
if not pg then
    warn("[NightFall] No PlayerGui.")
    return
end

pcall(function()
    for _, name in ipairs({ "NightFallKeyUI", "NightFallLoaderUI", "NightFallPCKeyUI" }) do
        local old = pg:FindFirstChild(name)
        if old then old:Destroy() end
    end
end)

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
    panel.Size = UDim2.new(0.94, 0, 0, 330)
else
    panel.AnchorPoint = Vector2.new(0.5, 0.5)
    panel.Position = UDim2.fromScale(0.5, 0.5)
    panel.Size = UDim2.new(0, 400, 0, 330)
end
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(55, 58, 72)
stroke.Thickness = 1
stroke.Transparency = 0.35

local title = Instance.new("TextLabel", panel)
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 14, 0, 10)
title.Size = UDim2.new(1, -28, 0, 26)
title.Font = Enum.Font.GothamBold
title.TextSize = IS_MOBILE and 20 or 18
title.TextColor3 = Color3.fromRGB(240, 241, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "NightFall " .. PLATFORM.label

local subtitle = Instance.new("TextLabel", panel)
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 14, 0, 36)
subtitle.Size = UDim2.new(1, -28, 0, 36)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextColor3 = Color3.fromRGB(140, 144, 160)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextYAlignment = Enum.TextYAlignment.Top
subtitle.TextWrapped = true
subtitle.Text = PLATFORM.label .. " detected · premium or keyless build"

local status = Instance.new("TextLabel", panel)
status.BackgroundTransparency = 1
status.Position = UDim2.new(0, 14, 0, 76)
status.Size = UDim2.new(1, -28, 0, 40)
status.Font = Enum.Font.GothamMedium
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(52, 211, 153)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "NightFall Ready - Script Loaded"

local box = Instance.new("TextBox", panel)
box.Position = UDim2.new(0, 14, 0, 122)
box.Size = UDim2.new(1, -28, 0, 34)
box.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
box.TextColor3 = Color3.fromRGB(240, 241, 245)
box.PlaceholderText = "NF-XXXX-XXXX-XXXX"
box.PlaceholderColor3 = Color3.fromRGB(120, 124, 140)
box.Font = Enum.Font.Gotham
box.TextSize = 14
box.ClearTextOnFocus = false
Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)

local function makeBtn(text, x, w, y, color)
    local btn = Instance.new("TextButton", panel)
    btn.Size = UDim2.new(w, 0, 0, 36)
    btn.Position = UDim2.new(x, 0, 0, y)
    btn.BackgroundColor3 = color
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(240, 241, 245)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.AutoButtonColor = true
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    return btn
end

local getKeyBtn = makeBtn("Get Key", 0, 0.48, 168, Color3.fromRGB(28, 30, 38))
local continueBtn = makeBtn("Continue", 0.52, 0.48, 168, Color3.fromRGB(99, 102, 241))
local keylessBtn = makeBtn("Keyless (no premium)", 0, 1, 214, Color3.fromRGB(28, 30, 38))

local hint = Instance.new("TextLabel", panel)
hint.BackgroundTransparency = 1
hint.Position = UDim2.new(0, 14, 0, 260)
hint.Size = UDim2.new(1, -28, 0, 56)
hint.Font = Enum.Font.Gotham
hint.TextSize = 11
hint.TextColor3 = Color3.fromRGB(120, 124, 140)
hint.TextWrapped = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.Text = "v" .. VERSION .. " · " .. PLATFORM.premiumName .. " / " .. PLATFORM.keylessName

local busy = false

local function setStatus(msg, isErr)
    status.Text = msg
    status.TextColor3 = isErr and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(52, 211, 153)
    print("[NightFall] " .. msg)
end

local function onTap(btn, fn)
    if IS_MOBILE then
        btn.Activated:Connect(fn)
    else
        btn.MouseButton1Click:Connect(fn)
    end
end

local function lockBtns(locked)
    getKeyBtn.Active = not locked
    continueBtn.Active = not locked
    keylessBtn.Active = not locked
end

onTap(getKeyBtn, function()
    keepMovementOn()
    pcall(function()
        if setclipboard then setclipboard(KEY_SITE) end
    end)
    setStatus("Key site: " .. KEY_SITE .. (setclipboard and " (copied)" or ""), false)
end)

onTap(continueBtn, function()
    if busy then return end
    keepMovementOn()
    local key = trim(box.Text)
    if key == "" then
        setStatus("Enter a key first.", true)
        return
    end

    busy = true
    lockBtns(true)
    continueBtn.Text = "Checking..."
    setStatus("Validating key...")

    task.spawn(function()
        local valid, info = validateKey(key)
        if not valid then
            busy = false
            lockBtns(false)
            continueBtn.Text = "Continue"
            setStatus(tostring(info), true)
            return
        end

        setStatus("Key valid — loading " .. PLATFORM.premiumName .. "...")
        local source, err = acquireScript(key)
        if not source then
            busy = false
            lockBtns(false)
            continueBtn.Text = "Continue"
            setStatus(tostring(err), true)
            return
        end

        source = patchPremiumKey(source, key)
        local ok, runErr = runSource(source, PLATFORM.premiumName)
        if ok then
            pcall(function() gui:Destroy() end)
            print("[NightFall] Premium load complete (" .. PLATFORM.label .. ").")
            return
        end

        busy = false
        lockBtns(false)
        continueBtn.Text = "Continue"
        setStatus(tostring(runErr), true)
    end)
end)

onTap(keylessBtn, function()
    if busy then return end
    busy = true
    lockBtns(true)
    keylessBtn.Text = "Loading..."
    setStatus("Loading keyless " .. PLATFORM.label .. " build...")
    keepMovementOn()

    task.spawn(function()
        local source, err = acquireKeylessScript()
        if not source then
            busy = false
            lockBtns(false)
            keylessBtn.Text = "Keyless (no premium)"
            setStatus(tostring(err), true)
            return
        end

        local ok, runErr = runSource(source, PLATFORM.keylessName)
        if ok then
            pcall(function() gui:Destroy() end)
            print("[NightFall] Keyless load complete (" .. PLATFORM.label .. ").")
            return
        end

        busy = false
        lockBtns(false)
        keylessBtn.Text = "Keyless (no premium)"
        setStatus(tostring(runErr), true)
    end)
end)

keepMovementOn()
print("[NightFall] Loader GUI ready (" .. PLATFORM.label .. ").")
