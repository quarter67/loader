--[[
    NightFall bootstrap — paste THIS into your executor.
    Fetches the latest loader.lua and bypasses executor HTTP cache.
]]

loadstring(game:HttpGet("https://raw.githubusercontent.com/quarter67/loader/main/loader.lua?t=" .. tostring(os.time()) .. "&v=520"))()
