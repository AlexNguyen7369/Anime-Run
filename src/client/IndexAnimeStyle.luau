--!nonstrict
-- Index-only presentation. Artwork is reproducible with assets/build-index-art.ps1.
local Style={}
local ART={
 Body="rbxassetid://105894082013432",
 Header="rbxassetid://89849999905528",
 Tabs={"rbxassetid://110525026310951","rbxassetid://93619241022605","rbxassetid://96700522803536","rbxassetid://125278434531831"},
 Logo="rbxassetid://79149512473529",
 Chrome="rbxassetid://85567379215904",
 Close="rbxassetid://83852954634304",
 Card="rbxassetid://126554881187487",
 Plate="rbxassetid://128657926524494",
}
local INK=Color3.fromRGB(4,6,17)
local FONT=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Heavy,Enum.FontStyle.Italic)
local function make(class,name,parent,props)
 local o=Instance.new(class) o.Name=name
 for k,v in props do o[k]=v end
 o.Parent=parent return o
end
local function image(parent,name,id,pos,size,z)
 return make("ImageLabel",name,parent,{BackgroundTransparency=1,Image=id,Position=pos,Size=size,ZIndex=z,ScaleType=Enum.ScaleType.Stretch})
end
local function transparent(o)
 o.BackgroundTransparency=1
 for _,d in o:GetChildren() do
  if d:IsA("UIStroke") or d:IsA("UIGradient") then d.Enabled=false end
  if d:IsA("GuiObject") and (d.Name=="Shadow" or d.Name=="Lift") then d.Visible=false end
 end
end
local function text(label,max)
 label.FontFace=FONT label.TextColor3=Color3.new(1,1,1)
 label.TextStrokeTransparency=1
 local outline=label:FindFirstChildOfClass("UIStroke") or make("UIStroke","AnimeOutline",label,{})
 outline.Color=INK outline.Thickness=2.5 outline.Enabled=true
 if max then
  label.TextScaled=true
  local limit=label:FindFirstChildOfClass("UITextSizeConstraint") or make("UITextSizeConstraint","AnimeLimit",label,{})
  limit.MinTextSize=10 limit.MaxTextSize=max
 end
end
function Style.Apply(gui)
 if gui:GetAttribute("AnimeIndexApplied") then return end
 gui:SetAttribute("AnimeIndexApplied",true)
 gui:SetAttribute("IndexCustomLayout",true)
 local panel=gui:WaitForChild("Panel")
 local face=panel:WaitForChild("Face")
 local header=face:WaitForChild("Header")
 local band=header:WaitForChild("Face")
 local host=face:WaitForChild("GridHost")
 for _,name in {"AnimeChrome","AnimeBanner","ProgressPlate","GridPlate"} do
  local old=face:FindFirstChild(name) if old then old:Destroy() end
 end
 for _,name in {"IndexTitle","IndexIcon"} do local old=band:FindFirstChild(name) if old then old:Destroy() end end
 transparent(face) transparent(band)
 panel.Shadow.Visible=false header.Shadow.Visible=false header.ZIndex=8
 local chrome=make("Frame","AnimeChrome",face,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1})
 image(chrome,"Body",ART.Chrome,UDim2.fromOffset(-40,-70),UDim2.new(1,80,1,100),1)
 local banner=make("Frame","AnimeBanner",face,{BackgroundTransparency=1,Position=UDim2.fromOffset(-34,-18),Size=UDim2.new(1,68,0,86),ZIndex=6})
 -- Header artwork is part of the imported skin.
 image(banner,"Logo",ART.Logo,UDim2.fromOffset(15,-54),UDim2.fromOffset(188,186),9).ScaleType=Enum.ScaleType.Fit
 -- Raised title plate is part of the imported skin.
 banner.Logo.Position=UDim2.fromOffset(15,-54)
 banner.Logo.ZIndex=11
 local title=make("TextLabel","Title",banner,{BackgroundTransparency=1,Position=UDim2.fromOffset(202,-5),Size=UDim2.fromOffset(250,76),Rotation=-2,Text="INDEX",TextSize=58,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=10})
 local tabs={"CharactersTab","EnemiesTab","SidekicksTab","RelicsTab"}
 local captions={}
 for i,name in tabs do
  local tab=band:FindFirstChild(name)
  if tab then
   tab.Rotation=0 tab.ZIndex=8
   transparent(tab.Face)
   if tab:FindFirstChild("Shadow") then tab.Shadow.Visible=false end
   for _,name in {"AnimeTab","TabColor","Shine","AnimeTabArt"} do
    for _,old in tab.Face:GetChildren() do if old.Name==name then old:Destroy() end end
   end
   local art=image(tab.Face,"AnimeTabArt",ART.Tabs[i],UDim2.fromOffset(-7,-5),UDim2.new(1,14,1,10),2)
   for _,d in tab.Face:GetChildren() do if d:IsA("TextLabel") then
    d.ZIndex=4 d.Position=UDim2.fromOffset(8,0) d.Size=UDim2.new(1,-16,1,0)
    table.insert(captions,d)
   end end
   local function mark()
    tab.Face.BackgroundTransparency=1
    art.ImageColor3=tab.Face:GetAttribute("TabLit") and Color3.new(1,1,1) or Color3.fromRGB(225,225,235)
    for _,d in tab.Face:GetChildren() do if d:IsA("TextLabel") then text(d,22) end end
   end
   tab.Face:GetAttributeChangedSignal("TabLit"):Connect(function() task.defer(mark) end)
   task.defer(mark)
  end
 end
 local close=band.Close
 close.Rotation=0 close.ZIndex=10
 for _,d in close:GetDescendants() do
  if d:IsA("UICorner") then d.CornerRadius=UDim.new(0,8) end
 end
 local closeCaption=close.Face:FindFirstChildWhichIsA("TextLabel")
 transparent(close.Face)
 if close:FindFirstChild("Shadow") then close.Shadow.Visible=false end
 close.Face.Text=""
 if closeCaption then closeCaption.Visible=false end
 local oldClose=close.Face:FindFirstChild("AnimeCloseArt")
 if oldClose then oldClose:Destroy() end
 image(close.Face,"AnimeCloseArt",ART.Close,UDim2.fromOffset(-8,-10),UDim2.new(1,16,1,20),5).ScaleType=Enum.ScaleType.Fit
 local progress=face.IndexProgress
 local track=make("Frame","ProgressPlate",face,{BackgroundTransparency=1,Size=UDim2.fromOffset(1,1),ZIndex=2})
 local gridPlate=make("Frame","GridPlate",face,{BackgroundColor3=Color3.fromRGB(6,9,22),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=2})
 make("UICorner","Corner",gridPlate,{CornerRadius=UDim.new(0,10)})
 local function layout()
  local viewport=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1366,768)
  local phone=viewport.Y<=500
  local target=phone and UDim2.fromOffset(500,420) or UDim2.fromOffset(920,620)
  if panel.Size~=target then panel.Size=target end
  local w,h=panel.Size.X.Offset,panel.Size.Y.Offset
  if w<1 then w=780 end if h<1 then h=524 end
  header.Position=UDim2.fromOffset(56,phone and 90 or 98) header.Size=UDim2.fromOffset(w-112,44)
  transparent(band)
  header.Shadow.Visible=false
  local width=(w-136)/4
  for i,name in tabs do local tab=band:FindFirstChild(name) if tab then
   tab.Position=UDim2.fromOffset((i-1)*(width+8),0) tab.Size=UDim2.fromOffset(width,40)
   tab.Face.Position=UDim2.fromOffset(0,0)
   tab.Face.AnchorPoint=Vector2.zero
   tab.Face.Size=UDim2.fromScale(1,1)
  end end
  close.Position=UDim2.fromOffset(w-130,-94) close.Size=UDim2.fromOffset(58,54)
  local top=phone and 144 or 164
  host.Position=UDim2.fromOffset(56,top) host.Size=UDim2.fromOffset(w-112,h-top-82) host.ZIndex=3
  gridPlate.Position=UDim2.fromOffset(48,top-6) gridPlate.Size=UDim2.fromOffset(w-96,h-top-74)
  progress.Position=UDim2.fromOffset(w*303/920,h-60) progress.Size=UDim2.fromOffset(w*312/920,28) progress.Rotation=0 progress.ZIndex=4
  track.Position=UDim2.fromOffset(18,h-48) track.Size=UDim2.fromOffset(w-36,42)
 end
 local queued=false
 local function queue()
  if queued then return end queued=true
  task.defer(function() queued=false layout() end)
 end
 panel:GetPropertyChangedSignal("Size"):Connect(queue)
 -- Generated fits can run after startup or a window resize. Reconcile once after that pass.
 for _,object in {header,host,close} do
  object:GetPropertyChangedSignal("Position"):Connect(queue)
  object:GetPropertyChangedSignal("Size"):Connect(queue)
 end
 for _,name in tabs do
  local tab=band:FindFirstChild(name)
  if tab then
   tab:GetPropertyChangedSignal("Position"):Connect(queue)
   tab:GetPropertyChangedSignal("Size"):Connect(queue)
  end
 end
 band:GetPropertyChangedSignal("BackgroundTransparency"):Connect(queue)
 gui:GetAttributeChangedSignal("InventoryTab"):Connect(queue)
 if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function() task.delay(0.15,queue) end) end
 layout()
 local styled={}
 local function restyleTile(tile)
  if styled[tile] or not tile:IsA("Frame") or not tile:FindFirstChild("Art") or not tile:FindFirstChild("CharacterName") then return end
  styled[tile]=true
  tile.BackgroundTransparency=1
  local rim=tile:FindFirstChild("Rim")
  local rarity=rim and rim:FindFirstChildOfClass("UIStroke")
  if rim then rim.Visible=false end
  local border=tile:FindFirstChild("Stroke")
  if border then border.Enabled=false end
  local oldGlow=tile:FindFirstChild("IndexOutlineGlow") if oldGlow then oldGlow:Destroy() end
  local shade=tile:FindFirstChild("Shade") if shade then shade.Visible=false end
  local halo=image(tile,"AngularOutlineGlow","rbxassetid://84593396974140",UDim2.fromScale(0.5,0.5),UDim2.new(1.2,7.2,1.190476,7.142856),5)
  halo.AnchorPoint=Vector2.new(0.5,0.5)
  halo.ImageTransparency=0
  local frame=image(tile,"AngularCard",ART.Card,UDim2.fromOffset(-3,-3),UDim2.new(1,6,1,6),3)
  local plate=image(tile,"AngularName",ART.Plate,UDim2.new(0,3,1,-52),UDim2.new(1,-6,0,25),6)
  local function tint()
   local color=rarity and rarity.Color or Color3.fromRGB(70,205,255)
   local hue,saturation,value=color:ToHSV()
   local vivid=if saturation>0.05 then Color3.fromHSV(hue,math.max(0.95,saturation),1) else Color3.fromHSV(hue,saturation,math.min(1,value+0.12))
   -- Green gets a softer saturation and halo; other rarity colors stay vivid.
   if saturation>0.05 and hue>=0.22 and hue<=0.43 then
    vivid=Color3.fromHSV(hue,0.72,0.88)
    halo.ImageTransparency=0.3
   else
    halo.ImageTransparency=0
   end
   frame.ImageColor3=vivid
   halo.ImageColor3=vivid
   plate.ImageColor3=vivid:Lerp(Color3.new(1,1,1),0.12)
  end
  tint()
  if rarity then rarity:GetPropertyChangedSignal("Color"):Connect(tint) end
  local art=tile.Art
  art.AnchorPoint=Vector2.new(0.5,0)
  art.Position=UDim2.fromScale(0.5,0.04) art.Size=UDim2.fromScale(0.86,0.67)
  local name=tile.CharacterName
  name.Position=UDim2.new(0,9,1,-50) name.Size=UDim2.new(1,-18,0,20)
  name.TextXAlignment=Enum.TextXAlignment.Center text(name,16)
  local info=tile:FindFirstChild("Info")
  if info then info.Position=UDim2.new(0,7,1,-69) info.Size=UDim2.new(1,-14,0,16) info.TextSize=11 end
  local odds=tile:FindFirstChild("Odds") if odds then odds.TextSize=11 odds.Position=UDim2.fromOffset(8,6) end
  local category=tile:FindFirstChild("Category") if category then category.Rotation=-12 category.Size=UDim2.fromOffset(19,19) category.TextSize=13 category.Position=UDim2.new(1,-27,0,7) end
  local equip=tile:FindFirstChild("Equip")
  if equip then
   equip.Position=UDim2.new(0,8,1,-28) equip.Size=UDim2.new(1,-16,0,22)
   for _,c in equip:GetChildren() do if c:IsA("UICorner") then c.CornerRadius=UDim.new(0,3) end
    if c:IsA("TextLabel") then text(c,11) end
   end
  end
 end
 local gallery=host:FindFirstChild("Gallery")
 if gallery then
  local grid=gallery:FindFirstChildOfClass("UIGridLayout")
  if grid then
   local function fitGallery()
    local phone=workspace.CurrentCamera.ViewportSize.Y<=500
    local cols=phone and 2 or 4
    local width=host.Size.X.Offset-14
    local cell=UDim2.fromOffset(math.min(178,math.floor((width-(cols-1)*16)/cols)),phone and 150 or 176)
    if grid.CellSize~=cell then grid.CellSize=cell end
    grid.CellPadding=UDim2.fromOffset(16,16)
   end
   grid:GetPropertyChangedSignal("CellSize"):Connect(function() task.defer(fitGallery) end)
   host:GetPropertyChangedSignal("Size"):Connect(function() task.defer(fitGallery) end)
   fitGallery()
  end
  for _,tile in gallery:GetChildren() do restyleTile(tile) end
  gallery.ChildAdded:Connect(function(tile) task.defer(restyleTile,tile) end)
 end
 local function styleCard(d)
  if d:IsA("UICorner") then d.CornerRadius=UDim.new(0,6) end
  if d:IsA("TextLabel") and d.Name=="CharacterName" then text(d) end
 end
 for _,d in host:GetDescendants() do styleCard(d) end
 host.DescendantAdded:Connect(function(d) task.defer(styleCard,d) end)
 task.defer(function()
  text(title,72)
  title.FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Heavy,Enum.FontStyle.Italic)
  text(progress,20)
  progress.TextXAlignment=Enum.TextXAlignment.Center
  local footerOutline=progress:FindFirstChildOfClass("UIStroke")
  if footerOutline then footerOutline.Thickness=1.5 end
  for _,label in captions do text(label,22) end
  if closeCaption then text(closeCaption,34) end
 end)
end
-- Shared with Client/QuestAnimeStyle (design doc 4.42): one set of art and one text treatment.
Style.Art,Style.Ink,Style.Image,Style.Text=ART,INK,image,text
return Style
