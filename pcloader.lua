--[[
    NightFall PC Loader — test SurviveHomelanderPC.lua (keeps loader.lua separate)

    Local test (executor with readfile):
        loadstring(readfile("pcloader.lua"))()

    Put SurviveHomelanderPC.lua in workspace/ or nightfall/ for offline load.
]]

local VERSION = "1.1.0-pc"

local CONFIG = {
    PLACE_ID = 134225461562780,
    API_URL_FALLBACK = "https://tackle-soldiers-miller-niagara.trycloudflare.com",
    API_URL_GITHUB = "https://raw.githubusercontent.com/quarter67/loader/main/api-url.txt",
    SCRIPT_URLS = {
        "https://raw.githubusercontent.com/quarter67/NightFall/main/SurviveHomelanderPC.lua",
    },
    LOCAL_PATHS = {
        "SurviveHomelanderPC.lua",
        "script/SurviveHomelanderPC.lua",
        "ScriptHub/SurviveHomelanderPC.lua",
        "workspace/SurviveHomelanderPC.lua",
        "nightfall/SurviveHomelanderPC.lua",
        "Downloads/script/SurviveHomelanderPC.lua",
    },
}

print("[NightFall PC] Loader v" .. VERSION)

if game.PlaceId ~= CONFIG.PLACE_ID then
    warn("[NightFall PC] Wrong game.")
    return
end

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

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
        ["User-Agent"] = "NightFallPCLoader/" .. VERSION,
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
            print("[NightFall PC] API: " .. url)
            return url
        end
    end
    print("[NightFall PC] API fallback: " .. CONFIG.API_URL_FALLBACK)
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

local function isValidScriptBody(body)
    return body
        and #body > 500
        and not body:find("<!DOCTYPE")
        and body:sub(1, 1) ~= "{"
        and (body:find("resolveScriptAccess") or body:find("SurviveHomelanderPC"))
end

local function loadLocalScript()
    for _, path in ipairs(CONFIG.LOCAL_PATHS) do
        local content = fsRead(path)
        if isValidScriptBody(content) then
            return content, path
        end
    end
    return nil, nil
end

local function downloadFromUrls()
    for i, base in ipairs(CONFIG.SCRIPT_URLS) do
        local url = base .. "?t=" .. tostring(os.time()) .. "&try=" .. i
        print("[NightFall PC] Downloading from GitHub...")
        local body = httpGet(url)
        if isValidScriptBody(body) then
            return body, nil
        end
    end
    return nil, "GitHub download failed — enable HTTP or use local SurviveHomelanderPC.lua"
end

local function downloadFromApi(key)
    local url = string.format(
        "%s/api/script?key=%s&hwid=%s",
        API_BASE,
        HttpService:UrlEncode(key),
        HttpService:UrlEncode(HWID)
    )
    print("[NightFall PC] Fetching script from key server...")
    local body = httpGet(url)
    if isValidScriptBody(body) then
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
    local localSrc, localPath = loadLocalScript()
    if localSrc then
        print("[NightFall PC] Using local file: " .. localPath)
        return localSrc, nil
    end

    if key and key ~= "" then
        local fromApi, apiErr = downloadFromApi(key)
        if fromApi then return fromApi, nil end
        if apiErr then
            warn("[NightFall PC] API script: " .. tostring(apiErr))
        end
    end

    return downloadFromUrls()
end

local function patchKeyless(source)
    return table.concat({
        "_G.NF_KEYLESS = true",
        "shared.NF_KEYLESS = true",
        "pcall(function() if typeof(getgenv)=='function' then getgenv().NF_KEYLESS=true end end)",
        source,
    }, "\n")
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
        local fn, err = load(source, name or "SurviveHomelanderPC", "t", env)
        if type(fn) == "function" then return fn, nil end
        if err then warn("[NightFall PC] compile: " .. tostring(err)) end
    end

    local ls = loadstring or env.loadstring
    if type(ls) ~= "function" then return nil, "No loadstring" end
    local fn, err = ls(source, name or "SurviveHomelanderPC")
    if type(fn) ~= "function" then return nil, err end
    pcall(function() if setfenv then setfenv(fn, env) end end)
    return fn, nil
end

local function hubExists()
    local plr = Players.LocalPlayer
    if not plr then return false end
    local pg = plr:FindFirstChild("PlayerGui")
    if not pg then return false end
    return pg:FindFirstChild("ScriptHubToggle", true) ~= nil
        or pg:FindFirstChild("ScriptHub", true) ~= nil
end

local function waitForHub(sec)
    local t0 = os.clock()
    while os.clock() - t0 < (sec or 15) do
        if hubExists() then return true end
        task.wait(0.2)
    end
    return false
end

local function runSource(source, label)
    local fn, err = compile(source, label)
    if not fn then return false, tostring(err or "compile failed") end

    task.spawn(function()
        for _ = 1, 50 do
            if hubExists() then
                pcall(function() gui:Destroy() end)
                return
            end
            task.wait(0.2)
        end
    end)

    local ok, runErr = pcall(fn)
    if hubExists() then
        pcall(function() gui:Destroy() end)
        if not ok then
            warn("[NightFall PC] Hub loaded with errors: " .. tostring(runErr))
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

local plr = Players.LocalPlayer or Players.PlayerAdded:Wait()
local pg = plr:FindFirstChild("PlayerGui") or plr:WaitForChild("PlayerGui", 5)
if not pg then
    warn("[NightFall PC] No PlayerGui.")
    return
end

pcall(function()
    local old = pg:FindFirstChild("NightFallPCKeyUI")
    if old then old:Destroy() end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "NightFallPCKeyUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = pg

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.new(0, 400, 0, 330)
panel.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
panel.BorderSizePixel = 0
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
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(240, 241, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "NightFall PC"

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
subtitle.Text = "PC test loader · SurviveHomelanderPC.lua · loader.lua stays separate"

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
status.Text = "Ready — local file used first if found in workspace."

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
hint.Text = "v" .. VERSION .. " · local SurviveHomelanderPC.lua → GitHub → key server"

local busy = false

local function setStatus(msg, isErr)
    status.Text = msg
    status.TextColor3 = isErr and Color3.fromRGB(239, 68, 68) or Color3.fromRGB(52, 211, 153)
    print("[NightFall PC] " .. msg)
end

local function lockBtns(locked)
    getKeyBtn.Active = not locked
    continueBtn.Active = not locked
    keylessBtn.Active = not locked
end

continueBtn.MouseButton1Click:Connect(function()
    if busy then return end
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

        setStatus("Key valid — loading SurviveHomelanderPC...")
        local source, err = acquireScript(key)
        if not source then
            busy = false
            lockBtns(false)
            continueBtn.Text = "Continue"
            setStatus(tostring(err), true)
            return
        end

        source = patchPremiumKey(source, key)
        local ok, runErr = runSource(source, "SurviveHomelanderPC")
        if ok then
            pcall(function() gui:Destroy() end)
            print("[NightFall PC] Premium load complete.")
            return
        end

        busy = false
        lockBtns(false)
        continueBtn.Text = "Continue"
        setStatus(tostring(runErr), true)
    end)
end)

getKeyBtn.MouseButton1Click:Connect(function()
    pcall(function()
        if setclipboard then setclipboard(KEY_SITE) end
    end)
    setStatus("Key site: " .. KEY_SITE .. (setclipboard and " (copied)" or ""), false)
end)

keylessBtn.MouseButton1Click:Connect(function()
    if busy then return end
    busy = true
    lockBtns(true)
    keylessBtn.Text = "Loading..."
    setStatus("Loading keyless SurviveHomelanderPC...")

    task.spawn(function()
        local source, err = acquireScript(nil)
        if not source then
            busy = false
            lockBtns(false)
            keylessBtn.Text = "Keyless (no premium)"
            setStatus(tostring(err), true)
            return
        end

        source = patchKeyless(source)
        local ok, runErr = runSource(source, "SurviveHomelanderPCKeyless")
        if ok then
            pcall(function() gui:Destroy() end)
            print("[NightFall PC] Keyless load complete (premium locked).")
            return
        end

        busy = false
        lockBtns(false)
        keylessBtn.Text = "Keyless (no premium)"
        setStatus(tostring(runErr), true)
    end)
end)

print("[NightFall PC] Loader GUI ready.")
