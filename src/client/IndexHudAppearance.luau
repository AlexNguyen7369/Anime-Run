--!nonstrict
-- Appearance of the Index HUD entry only.
local Appearance={}
function Appearance.Apply(tile)
 tile.Size=UDim2.fromOffset(84,110)
 local icon=tile:WaitForChild("Icon")
 icon.Size=UDim2.fromOffset(96,96)
 icon.Position=UDim2.new(0.5,0,0,-8)
 icon.AnchorPoint=Vector2.new(0.5,0)
 local label=tile:WaitForChild("Label")
 label.AnchorPoint=Vector2.new(0.5,0)
 label.Position=UDim2.new(0.5,0,0,83)
 label.Size=UDim2.new(1,16,0,25)
 label.Text="INDEX"
 label.TextScaled=true
 label.TextXAlignment=Enum.TextXAlignment.Center
 local limit=label:FindFirstChildOfClass("UITextSizeConstraint") or Instance.new("UITextSizeConstraint")
 limit.Name="IndexTextLimit" limit.MaxTextSize=22 limit.MinTextSize=12 limit.Parent=label
 local function font()
  label.FontFace=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Heavy,Enum.FontStyle.Italic)
  label.TextColor3=Color3.new(1,1,1)
 end
 font()
 task.defer(font)
end
return Appearance
