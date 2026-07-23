local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
while not LocalPlayer do
    task.wait(0.1)
    LocalPlayer = Players.LocalPlayer
end

local Rayfield = loadstring(game:HttpGet("https://raw.githubusercontent.com/nubold/xixixaxa/refs/heads/main/key.lua"))()

local Window = Rayfield:CreateWindow({
    Name = "Witchassault",
    ConfigurationSaving = {
        Enabled = false
    },
    KeySystem = true,
    KeySettings = {
        Title = "Key Verification",
        Subtitle = "Witchassault",
        Note = "If Discord doesn't open: discord.gg/9Pv4cAPzU",
        API = "https://checkkey-3awr.onrender.com/verify.php?key="
    },
    Discord = {
        Enabled = true,
        Invite = "9Pv4cAPzU",
        RememberJoins = false
    }
})

task.wait(0.5)

Rayfield:Destroy()

getgenv().Rayfield = nil
getgenv().RayfieldLibrary = nil
_G.Rayfield = nil
_G.RayfieldLibrary = nil

local goidar = (LocalPlayer.UserId * 17) + (game.PlaceId * 3) + 1024

task.wait(0.5)

local sosal = loadstring(game:HttpGet("https://raw.githubusercontent.com/Nullod/Witchassault/refs/heads/main/criminality.lua"))()
if type(sosal) == "function" then
    sosal(goidar)
end
