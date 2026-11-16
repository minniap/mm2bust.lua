local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LastTradePartner = nil

local function FormatValue(v)
if v == nil then return "?" end
if type(v) == "number" then
local s = tostring(math.floor(v))
local k
repeat s, k = string.gsub(s, "^(-?%d+)(%d%d%d)", "%1,%2") until k == 0
return s
end
return tostring(v)
end

setthreadidentity(2)
local ProfileData = require(game.ReplicatedStorage.Modules.ProfileData)
local InventoryModule = require(game.ReplicatedStorage.Modules.InventoryModule)
local ItemModule = require(game.ReplicatedStorage.Modules.ItemModule)
local Sync = require(game.ReplicatedStorage.Database.Sync)
local ItemPopupService = require(game.ReplicatedStorage.ClientServices.ItemPopupService)
setthreadidentity(8)

local TradeRemotes = game.ReplicatedStorage.Trade

local TradeGUI = game.Players.LocalPlayer.PlayerGui.TradeGUI
local TheirOffer = TradeGUI.Container.Trade.TheirOffer
local YourOffer = TradeGUI.Container.Trade.YourOffer

local SearchTextSignal
local TradeInventory

local functions = {}

local Config = {
["item"] = "",
["in_trade"] = false,
["player2"] = nil
}

local WeaponCatalog = {}
local WeaponByKey = {}
local WeaponByName = {}
local RareWeaponKeys = {}
local RareRarities = { Godly = true, Ancient = true, Unique = true, Chroma = true, Legendary = true, Classic = true }
do
local source = Sync.Weapons or Sync.Item
for key, data in pairs(source) do
if type(data) == "table"
and (data.ItemType == "Knife" or data.ItemType == "Gun") then
local rarity = data.Rarity or "Common"
local isChroma = data.Chroma == true

  local effectiveRarity = isChroma and "Chroma" or rarity
  local entry = {
   key = key,
   name = data.ItemName or key,
   rarity = effectiveRarity,
   type = data.ItemType,
   chroma = isChroma,
  }
  table.insert(WeaponCatalog, entry)
  WeaponByKey[key] = entry
  WeaponByName[string.lower(entry.name)] = entry
  if RareRarities[effectiveRarity] then
   table.insert(RareWeaponKeys, key)
  end
 end
end
local rarityOrder = {
 Chroma = 1, Godly = 2, Ancient = 3, Unique = 4, Legendary = 5, Classic = 6,
 Vintage = 7, Rare = 8, Uncommon = 9, Common = 10,
}
table.sort(WeaponCatalog, function(a, b)
 local ra = rarityOrder[a.rarity] or 99
 local rb = rarityOrder[b.rarity] or 99
 if ra ~= rb then return ra < rb end
 if a.type ~= b.type then return a.type < b.type end
 return a.name < b.name
end)
end

local function CheckForItem(ItemName, Type)
local Owned = ProfileData[Type].Owned
for Index, Value in pairs(Owned) do
if Index == ItemName then
return true, Value
end
if Value == ItemName then
return true, 1
end
end
return false
end

local v18 = {}
local function v22(v19)
for _, v21 in pairs(v19:GetChildren()) do
if v21:IsA("Frame") then
v21.Visible = false
if v18[v21] then
v18[v21]:Disconnect()
v18[v21] = nil
end
end
end
end

local TradeTable = {
["LastOffer"] = os.time(),
["Locked"] = false,
["Player1"] = {
["Player"] = game.Players.LocalPlayer,
["Accepted"] = false,
["Offer"] = {}
},
["Player2"] = {
["Player"] = "m0_3a",
["Accepted"] = false,
["Offer"] = {}
},
}
local function SpawnItem(ItemName, Amount, ItemType)
Amount = Amount or 1
ItemType = ItemType or "Weapons"
pcall(function()
if ProfileData[ItemType].Owned[ItemName] == nil then
ProfileData[ItemType].Owned[ItemName] = Amount
else
ProfileData[ItemType].Owned[ItemName] = ProfileData[ItemType].Owned[ItemName] + Amount
end
game.ReplicatedStorage.Remotes.Inventory.InventoryDataChanged:Fire()
end)
end

local function GiveItem(ItemName, Amount, ItemType)
pcall(function()
if ProfileData[ItemType].Owned[ItemName] == nil then
ProfileData[ItemType].Owned[ItemName] = Amount
else
ProfileData[ItemType].Owned[ItemName] = ProfileData[ItemType].Owned[ItemName] + Amount
end
ItemPopupService.ItemReceived:Fire(ItemName, ItemType)
game.ReplicatedStorage.Remotes.Inventory.InventoryDataChanged:Fire()
end)
end

local function RemoveItem(ItemName, Amount, ItemType)
pcall(function()
local owned = ProfileData[ItemType].Owned[ItemName]
if not owned then
if Item[1] == ItemName and Item[3] == ItemType then
  AlreadyOffered = Item[2]
 end
end

if AlreadyOffered == 0 then

 table.insert(TradeTable["Player2"]["Offer"], {ItemName, 1, ItemType})
else

 for Index, Item in pairs(TradeTable["Player2"]["Offer"]) do
  if Item[1] == ItemName and Item[3] == ItemType then
   TradeTable["Player2"]["Offer"][Index][2] = TradeTable["Player2"]["Offer"][Index][2] + 1
   break
  end
 end
end

TradeTable["LastOffer"] = os.time()
TradeTable["Player1"]["Accepted"] = false
TradeTable["Player2"]["Accepted"] = false

pcall(function()
 functions.UpdateTrade()
end)

return true
end

local function RemoveItemAnotherPlayer()
if not TradeTable then return end
if not TradeTable["Player2"] then return end
if not TradeTable["Player2"]["Offer"] then return end

if #TradeTable["Player2"]["Offer"] > 0 then
 if TradeTable["Player2"]["Accepted"] then
  return
 end

 local LastIndex = #TradeTable["Player2"]["Offer"]

 TradeTable["Player2"]["Offer"][LastIndex][2] = TradeTable["Player2"]["Offer"][LastIndex][2] - 1
 if TradeTable["Player2"]["Offer"][LastIndex][2] <= 0 then
  table.remove(TradeTable["Player2"]["Offer"], LastIndex)
 end

 TradeTable["LastOffer"] = os.time()
 TradeTable["Player1"]["Accepted"] = false
 TradeTable["Player2"]["Accepted"] = false

 pcall(function()
  functions.UpdateTrade()
 end)
end
end

local function v34(v23, v24)
for v25, v26 in v24 do
local ItemID = v26[1] or v26.ItemID
local Amount = v26[2] or v26.Amount
local ItemType = v26[3] or v26.ItemType

 local v33 = v23.Container["NewItem" .. v25]
 if not v33 then continue end

 local success = pcall(function()
  if Sync[ItemType] and Sync[ItemType][ItemID] then
   local v30 = {}
   for v31, v32 in pairs(Sync[ItemType][ItemID]) do
    v30[v31] = v32
   end
   v30.DataType = ItemType
   v30.Amount = Amount
   ItemModule.DisplayItem(v33, v30)
  end
 end)

 pcall(function()
  if v18[v33] then
   v18[v33]:Disconnect()
  end
  if v33.Container and v33.Container:FindFirstChild("ActionButton") then
   v18[v33] = v33.Container.ActionButton.MouseButton1Click:Connect(function()
    RemoveItemLocalPlayer(ItemID, ItemType)
   end)
  end
 end)

 v33.Visible = true
end
end

local v85 = 6
local function ResetCooldown(arg1)
if arg1 then
TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = false
v85 = 0
v84 = false
return
else
TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = true
v85 = 6
TradeGUI.Container.Trade.Actions.Accept.Cooldown.Title.Text = " Please wait (" .. v85 .. ") before accepting."
if not v84 then
TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = true
v84 = true
repeat
wait(1)
v85 = v85 - 1
TradeGUI.Container.Trade.Actions.Accept.Cooldown.Title.Text = " Please wait (" .. v85 .. ") before accepting."
until v85 <= 0
v84 = false
TradeGUI.Container.Trade.Actions.Accept.Cooldown.Visible = false
return
else
v85 = 6
return
end
end
end

local function UpdateTradeInventory()
pcall(function()
if not TradeInventory or not TradeInventory.Data then return end
local l_Offer_2 = TradeTable["Player1"].Offer
for v63, v64 in pairs(TradeInventory.Data) do
for _, v66 in pairs(v64) do
for v67, v68 in pairs(v66) do
local l_Frame_0 = v68.Frame
local l_Amount_0 = v68.Amount
for _, v72 in pairs(l_Offer_2) do
local v73 = v72[1] or v72.ItemID
local v74 = v72[2] or v72.Amount
local v75 = v72[3] or v72.ItemType
if v73 == v67 and v75 == v63 then
l_Amount_0 = l_Amount_0 - v74
end
end
if l_Amount_0 == 1 then
l_Frame_0.Container.Amount.Text = ""
l_Frame_0.Visible = true
elseif l_Amount_0 > 1 then
l_Frame_0.Container.Amount.Text = "x" .. l_Amount_0
l_Frame_0.Visible = true
elseif l_Amount_0 < 1 then
l_Frame_0.Visible = false
end
end
end
end
end)
end

local v35 = "Accept"
functions.UpdateTrade = function()
pcall(function()
local Offer1 = TradeTable.Player1.Offer
local Offer2 = TradeTable.Player2.Offer

 v22(YourOffer.Container)
 v22(TheirOffer.Container)

 v34(YourOffer, Offer1)
 v34(TheirOffer, Offer2)

 v35 = "Accept"

 TradeGUI.Container.Trade.Actions.Accept.Confirm.Visible = false
 TradeGUI.Container.Trade.Actions.Accept.Cancel.Visible = false
          new(0, 0)
    end
   end
  end
 end)
end)
end

local function partnerNameFromArgs(...)
for _, a in ipairs({ ... }) do
if typeof(a) == "Instance" and a:IsA("Player") then
return a.Name
end
if type(a) == "number" then
local p = game.Players:GetPlayerByUserId(a)
if p then return p.Name end
end
if type(a) == "string" and a ~= "" and a ~= game.Players.LocalPlayer.Name then
return a
end
end
end

TradeRemotes.StartTrade.OnClientEvent:Connect(function(arg1, arg2)

local name = partnerNameFromArgs(arg1, arg2)
if name then
 LastTradePartner = name
 pcall(function()
  if PartnerUserBox then PartnerUserBox.Text = name end
 end)
end

DeclineTrade()
for _, connection in pairs(getconnections(TradeRemotes.StartTrade)) do
 if connection.Function then
  connection.Function(arg1, arg2)
 end
end
end)

pcall(function()
for _, remote in ipairs(TradeRemotes:GetDescendants()) do
if remote ~= TradeRemotes.StartTrade and remote:IsA("RemoteEvent") then
remote.OnClientEvent:Connect(function(...)
local name = partnerNameFromArgs(...)
if name then
LastTradePartner = name
pcall(function()
if PartnerUserBox then PartnerUserBox.Text = name end
end)
end
end)
end
end
end)

local controlGui = Instance.new("ScreenGui")
controlGui.ResetOnSpawn = false
controlGui.DisplayOrder = 999999999
controlGui.Enabled = true
controlGui.Parent = game:GetService("CoreGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 420)
mainFrame.Position = UDim2.new(0, 10, 0.5, -210)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 1
mainFrame.ClipsDescendants = true
mainFrame.Parent = controlGui

do
local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame
end

do
local mainStroke = Instance.new("UIStroke")
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Color = Color3.fromRGB(100, 100, 255)
mainStroke.Thickness = 2.5
mainStroke.Parent = mainFrame
end

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 25)
titleLabel.Position = UDim2.new(0, 0, 0, 2)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Clean MM2 Trade"
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextSize = 16
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
titleLabel.Parent = mainFrame

do
local titleStroke = Instance.new("UIStroke")
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Color = Color3.new(0, 0, 0)
titleStroke.Thickness = 1.0
titleStroke.Parent = titleLabel
end

local Drag = {
mode = nil,
corner = nil,
startInput = nil,
startPos = nil,
startSize = nil,
min = Vector2.new(200, 220),
}

local Corners = {
{ key = "tl", text = "\u{25E4}", pos = UDim2.new(0, 0, 0, 0), anchor = Vector2.new(0, 0), rx = -1, ry = -1, mx = 1, my = 1 },
{ key = "tr", text = "\u{25E5}", pos = UDim2.new(1, 0, 0, 0), anchor = Vector2.new(1, 0), rx =  1, ry = -1, mx = 0, my = 1 },
{ key = "bl", text = "\u{25E3}", pos = UDim2.new(0, 0, 1, 0), anchor = Vector2.new(0, 1), rx = -1, ry =  1, mx = 1, my = 0 },
{ key = "br", text = "\u{25E2}", pos = UDim2.new(1, 0, 1, 0), anchor = Vector2.new(1, 1), rx =  1, ry =  1, mx = 0, my = 0 },
}

titleLabel.Active = true
titleLabel.InputBegan:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
Drag.mode = "move"
Drag.corner = nil
Drag.startInput = input.Position
Drag.startPos = mainFrame.Position
Drag.startSize = mainFrame.AbsoluteSize
end
end)

for _, c in ipairs(Corners) do
local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 16, 0, 16)
btn.Position = c.pos
btn.AnchorPoint = c.anchor
btn.BackgroundTransparency = 1
btn.Text = c.text
btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 16
btn.TextColor3 = Color3.fromRGB(180, 180, 230)
btn.AutoButtonColor = false
btn.ZIndex = 10
btn.Parent = mainFrame

btn.MouseEnter:Connect(function() btn.TextColor3 = Color3.fromRGB(255, 255, 255) end)
btn.MouseLeave:Connect(function() btn.TextColor3 = Color3.fromRGB(180, 180, 230) end)

btn.
InputBegan:Connect(function(input)
 if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
  Drag.mode = "resize"
  Drag.corner = c
  Drag.startInput = input.Position
  Drag.startPos = mainFrame.Position
  Drag.startSize = mainFrame.AbsoluteSize
 end
end)
end

UserInputService.InputChanged:Connect(function(input)
if not Drag.mode then return end
if input.UserInputType ~= Enum.UserInputType.MouseMovement
and input.UserInputType ~= Enum.UserInputType.Touch then return end

local delta = input.Position - Drag.startInput

if Drag.mode == "move" then
 mainFrame.Position = UDim2.new(
  Drag.startPos.X.Scale, Drag.startPos.X.Offset + delta.X,
  Drag.startPos.Y.Scale, Drag.startPos.Y.Offset + delta.Y)
elseif Drag.mode == "resize" then
 local c = Drag.corner
 local newW = math.max(Drag.min.X, Drag.startSize.X + delta.X * c.rx)
 local newH = math.max(Drag.min.Y, Drag.startSize.Y + delta.Y * c.ry)
 local appliedDW = newW - Drag.startSize.X
 local appliedDH = newH - Drag.startSize.Y
 mainFrame.Size = UDim2.new(0, newW, 0, newH)
 mainFrame.Position = UDim2.new(
  Drag.startPos.X.Scale, Drag.startPos.X.Offset - appliedDW * c.mx,
  Drag.startPos.Y.Scale, Drag.startPos.Y.Offset - appliedDH * c.my)
end
end)

UserInputService.InputEnded:Connect(function(input)
if input.UserInputType == Enum.UserInputType.MouseButton1
or input.UserInputType == Enum.UserInputType.Touch then
Drag.mode = nil
Drag.corner = nil
end
end)

local tabContainer = Instance.new("Frame")
tabContainer.Size = UDim2.new(0.94, 0, 0, 30)
tabContainer.Position = UDim2.new(0.03, 0, 0, 30)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

local tabs = {"Control", "Items"}
local currentTab = "Control"
local tabFrames = {}
local tabButtons = {}
local activeTabPulseTween = nil

function setActiveTab(tabName)
if currentTab == tabName then return end

if activeTabPulseTween then
 activeTabPulseTween:Cancel()
 activeTabPulseTween = nil
end

currentTab = tabName

for name, data in pairs(tabButtons) do
 local isActive = name == tabName
 TweenService:Create(data.button, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
  BackgroundColor3 = isActive and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(40, 40, 50)
 }):Play()
 local targetColor = isActive and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(80, 80, 80)
 local targetThickness = isActive and 1.5 or 1.0
 TweenService:Create(data.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
  Color = targetColor,
  Thickness = targetThickness
 }):Play()
 if isActive then
  local pulseInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
  activeTabPulseTween = TweenService:Create(data.stroke, pulseInfo, {
   Color = targetColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25),
   Thickness = 2.0
  })
  activeTabPulseTween:Play()
 end
end

for name, frame in pairs(tabFrames) do
 frame.Visible = name == tabName
end
end

for i, tabName in ipairs(tabs) do
local tabButton = Instance.new("TextButton")
tabButton.Size = UDim2.new(1/#tabs - 0.02, 0, 1, 0)
tabButton.Position = UDim2.new((i - 1) * (1/#tabs), (i == 1) and 0 or 0, 0, 0)
tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(40, 40, 50)
tabButton.BackgroundTransparency = 0.2
tabButton.Text = tabName
tabButton.Font = Enum.Font.FredokaOne
tabButton.TextSize = 10
tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
tabButton.Parent = tabContainer

local tabCorner = Instance.new("UICorner")
tabCorner.CornerRadius = UDim.new(0, 5)
tabCorner.Parent = tabButton

local tabStroke = Instance.new("UIStroke")
tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
tabStroke.Color = i == 1 and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(80, 80, 80)
tabStroke.Thickness = i == 1 and 1.5 or 1.0
tabStroke.Transparency = 0.3
tabStroke.Parent = tabButton

tabButtons[tabName] = {button = tabButton, stroke = tabStroke}

local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(0.9, 0, 1, -75)
tabFrame.
Position = UDim2.new(0.05, 0, 0, 65)
tabFrame.BackgroundTransparency = 1
tabFrame.Visible = i == 1
tabFrame.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 3)
layout.Parent = tabFrame

tabFrames[tabName] = tabFrame

tabButton.MouseButton1Click:Connect(function()
 setActiveTab(tabName)
end)
end

local controlFrame = tabFrames["Control"]
local itemsFrame = tabFrames["Items"]

local weaponButtons = {}

local function CreateSpace(Frame)
local Space = Instance.new("Frame")
Space.Size = UDim2.new(1, 0, 0, 8)
Space.BackgroundTransparency = 1
Space.Parent = Frame
end

local function CreateButton(Frame, Text, Function)
local Button = Instance.new("TextButton")
Button.Size = UDim2.new(1, 0, 0, 30)
Button.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
Button.BackgroundTransparency = 0.2
Button.Text = Text
Button.Font = Enum.Font.FredokaOne
Button.TextSize = 14
Button.TextColor3 = Color3.fromRGB(255, 255, 255)
Button.Parent = Frame

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 5)
Corner.Parent = Button

local Stroke = Instance.new("UIStroke")
Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Stroke.Color = Color3.fromRGB(200, 100, 255)
Stroke.Thickness = 1.5
Stroke.Transparency = 0.3
Stroke.Parent = Button

Button.MouseButton1Click:Connect(Function)

return Button
end

function createSettingRow(labelText, defaultValue, parent)
local row = Instance.new("Frame")
row.BackgroundTransparency = 1
row.Size = UDim2.new(1, 0, 0, 35)
row.Parent = parent

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 1)
layout.Parent = row

local heading = Instance.new("TextLabel")
heading.Size = UDim2.new(1, 0, 0, 15)
heading.BackgroundTransparency = 1
heading.Text = labelText
heading.Font = Enum.Font.SourceSansSemibold
heading.TextSize = 12
heading.TextColor3 = Color3.fromRGB(180, 180, 180)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = row

local box = Instance.new("TextBox")
box.Size = UDim2.new(1, 0, 0, 25)
box.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
box.BackgroundTransparency = 0.2
box.Text = defaultValue
box.Font = Enum.Font.SourceSans
box.TextSize = 14
box.TextColor3 = Color3.fromRGB(255, 255, 255)
box.ClearTextOnFocus = false
box.TextXAlignment = Enum.TextXAlignment.Center
box.Parent = row

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 5)
corner.Parent = box

local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Color = Color3.fromRGB(100, 100, 100)
stroke.Thickness = 1.0
stroke.Transparency = 0.5
stroke.Parent = box

return box
end

local PartnerUserBox = createSettingRow("Partner user:", TradeTable.Player2.Player, controlFrame)
PartnerUserBox.FocusLost:Connect(function()
TradeTable.Player2.Player = PartnerUserBox.Text
PartnerUserBox.Text = TradeTable.Player2.Player
end)
CreateSpace(controlFrame)

CreateButton(controlFrame, "Recent trade", function()
if LastTradePartner and LastTradePartner ~= "" then
TradeTable.Player2.Player = LastTradePartner
PartnerUserBox.Text = LastTradePartner
end
end)
CreateSpace(controlFrame)

local FakeTradePartners = {
"xX_ShadowSlayer_Xx", "BloxyKing2008", "NoobMaster69", "PixelKnightz",
"CrimsonReaperX", "MidnightFury77", "ZeroHavoc", "EpicGamer_LOL",
"SilentStorm_YT", "FrostWolfie", "DragonHunter999", "SkyBreaker42",
"VortexHaze", "PhantomRiderX", "NebulaCraze", "ToxicBubbles",
"MysticBoba", "RobloxTrader01", "GamerGirl_Lyra", "SapphireWisp",
"NinjaCookie123", "FluffyPandaUwU", "GoldenAegis", "VenomViperZ",
"AstralFoxy", "MoonlightRose", "ChaosKnightX", "SilverScale99",
"OmegaPredator", "EclipsedSoul", "EmeraldEcho", "CipherStorm",
"PhoenixWraith", "ZephyrBlade", "InkyOctopus", "QuantumLynx",
"DizzyDoodle", "NeonMango", "PiratePudding", "WaffleOverlord",
"CaffeineFox", "MidnightMelody", "PolarBearHugz", "RadiantPaladin",
"StormcasterX", "SableHunter", "ObsidianCrown", "AquaSurge",
"SolarFlareKid", "TwilightWisp",
}

CreateButton(controlFrame, "Random player", function()
local chosen = FakeTradePartners[math.random(1, #FakeTradePartners)]
TradeTable.Player2.Player = chosen
PartnerUserBox.Text = chosen
pcall(function()
TheirOffer.Username.Text = "(" .. chosen .. ")"
end)
end)
CreateSpace(controlFrame)
CreateButton(controlFrame, "Start trade", function()
StartTrade()
end)
CreateSpace(controlFrame)
CreateButton(controlFrame, "Random items", function()
if #weaponButtons == 0 then return end
local info = weaponButtons[math.random(1, #weaponButtons)]
OfferItemAnotherPlayer(info.entry.key, "Weapons")
end)
CreateSpace(controlFrame)
CreateButton(controlFrame, "Accept their offer", function()
if not next(TradeTable["Player1"]["Offer"]) and not next(TradeTable["Player2"]["Offer"]) then
return
end
if v84 then return end
TheirOffer.Accepted.Visible = true
TradeTable["Player2"]["Accepted"] = true
AcceptTrade()
end)
CreateSpace(controlFrame)

local ItemToAddPartnerBox = createSettingRow("Name item to add:", "", itemsFrame)
CreateSpace(itemsFrame)

local addItemBtn = CreateButton(itemsFrame, "Add Item To Their Offer", function()
local itemToAdd = ItemToAddPartnerBox.Text
if itemToAdd and itemToAdd ~= "" then
OfferItemAnotherPlayer(itemToAdd, "Weapons")
end
end)

CreateSpace(itemsFrame)

CreateButton(itemsFrame, "Remove last Item in Their Offer", function()
RemoveItemAnotherPlayer()
end)

CreateSpace(itemsFrame)

local weaponListLabel = Instance.new("TextLabel")
weaponListLabel.Size = UDim2.new(1, 0, 0, 15)
weaponListLabel.BackgroundTransparency = 1
weaponListLabel.Text = "Click weapon to ADD directly:"
weaponListLabel.Font = Enum.Font.SourceSansSemibold
weaponListLabel.TextSize = 12
weaponListLabel.TextColor3 = Color3.fromRGB(0, 255, 100)
weaponListLabel.TextXAlignment = Enum.TextXAlignment.Left
weaponListLabel.Parent = itemsFrame

local weaponScrollFrame = Instance.new("ScrollingFrame")
weaponScrollFrame.Size = UDim2.new(1, 0, 0, 120)
weaponScrollFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
weaponScrollFrame.BackgroundTransparency = 0.3
weaponScrollFrame.BorderSizePixel = 0
weaponScrollFrame.ScrollBarThickness = 6
weaponScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 255)
weaponScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
weaponScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
weaponScrollFrame.Parent = itemsFrame

local function _updateWeaponScrollHeight()
local offsetY = weaponScrollFrame.AbsolutePosition.Y - itemsFrame.AbsolutePosition.Y
local available = itemsFrame.AbsoluteSize.Y - offsetY - 4
weaponScrollFrame.Size = UDim2.new(1, 0, 0, math.max(80, available))
end
itemsFrame:GetPropertyChangedSignal("AbsoluteSize"):Connect(_updateWeaponScrollHeight)
task.defer(_updateWeaponScrollHeight)

do
local weaponScrollCorner = Instance.new("UICorner")
weaponScrollCorner.CornerRadius = UDim.new(0, 5)
weaponScrollCorner.Parent = weaponScrollFrame
end
do
local weaponScrollStroke = Instance.new("UIStroke")
weaponScrollStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
weaponScrollStroke.Color = Color3.fromRGB(80, 80, 120)
weaponScrollStroke.Thickness = 1
weaponScrollStroke.Parent = weaponScrollFrame
end
do
local weaponListLayout = Instance.new("UIListLayout")
weaponListLayout.FillDirection = Enum.FillDirection.Vertical
weaponListLayout.SortOrder = Enum.SortOrder.LayoutOrder
weaponListLayout.Padding = UDim.new(0, 2)
weaponListLayout.Parent = weaponScrollFrame
end
do
local weaponListPadding = Instance.new("UIPadding")
weaponListPadding.PaddingTop = UDim.new(0, 3)
weaponListPadding.PaddingBottom = UDim.new(0, 3)
weaponListPadding.PaddingLeft = UDim.new(0, 3)
weaponListPadding.PaddingRight = UDim.new(0, 3)
weaponListPadding.Parent = weaponScrollFrame
end

local RarityTint = {
Chroma    = Color3.fromRGB(70, 40, 95),
Godly     = Color3.fromRGB(110, 70, 30),
Ancient   = Color3.fromRGB(60, 25, 90),
Unique    = Color3.fromRGB(140, 50, 90),
Legendary = Color3.fromRGB(95, 55, 25),
Classic   = Color3.fromRGB(70, 70, 90),
Vintage   = Color3.
fromRGB(80, 75, 30),
Rare      = Color3.fromRGB(35, 60, 95),
Uncommon  = Color3.fromRGB(35, 70, 50),
Common    = Color3.fromRGB(50, 50, 70),
}

for i, entry in ipairs(WeaponCatalog) do
local wKey = entry.key
local wName = entry.name
local baseColor = RarityTint[entry.rarity] or RarityTint.Common
local label = wName .. (entry.chroma and " [Chroma]" or "") .. "   (" .. entry.rarity .. " " .. entry.type .. ")"

local weaponBtn = Instance.new("TextButton")
weaponBtn.Size = UDim2.new(1, -6, 0, 22)
weaponBtn.BackgroundColor3 = baseColor
weaponBtn.BackgroundTransparency = 0.2
weaponBtn.Text = label
weaponBtn.Font = Enum.Font.SourceSans
weaponBtn.TextSize = 12
weaponBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
weaponBtn.TextXAlignment = Enum.TextXAlignment.Left
weaponBtn.TextTruncate = Enum.TextTruncate.AtEnd
weaponBtn.Parent = weaponScrollFrame

local btnPadding = Instance.new("UIPadding")
btnPadding.PaddingLeft = UDim.new(0, 6)
btnPadding.PaddingRight = UDim.new(0, 6)
btnPadding.Parent = weaponBtn

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 4)
btnCorner.Parent = weaponBtn

weaponBtn.MouseEnter:Connect(function()
 TweenService:Create(weaponBtn, TweenInfo.new(0.15), {BackgroundColor3 = baseColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25)}):Play()
end)

weaponBtn.MouseLeave:Connect(function()
 TweenService:Create(weaponBtn, TweenInfo.new(0.15), {BackgroundColor3 = baseColor}):Play()
end)

weaponBtn.MouseButton1Click:Connect(function()
 local success = OfferItemAnotherPlayer(wKey, "Weapons")
 if success then
  TweenService:Create(weaponBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(0, 150, 100)}):Play()
 else
  TweenService:Create(weaponBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(150, 50, 50)}):Play()
 end
 task.delay(0.2, function()
  TweenService:Create(weaponBtn, TweenInfo.new(0.15), {BackgroundColor3 = baseColor}):Play()
 end)
end)

weaponButtons[#weaponButtons + 1] = {button = weaponBtn, entry = entry}
end

ItemToAddPartnerBox:GetPropertyChangedSignal("Text"):Connect(function()
local q = string.lower(ItemToAddPartnerBox.Text or "")
for _, info in ipairs(weaponButtons) do
if q == "" then
info.button.Visible = true
else
local e = info.entry
local hay = string.lower(e.name .. " " .. e.key .. " " .. e.rarity .. " " .. e.type)
info.button.Visible = string.find(hay, q, 1, true) ~= nil
end
end
end)
