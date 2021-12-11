isBusy = false
d = script.Parent.Parent.door

function usedoor (hitPart)
  if isBusy then
    return
  end
  isBusy = true
    if d.Transparency <= 0 then
       while d.Transparency < 1 do
       d.Transparency = d.Transparency + 0.05
       wait(0.1)
     end
     d.CanCollide = false
     _G.used = script.Parent
     elseif _G.used ~= scrtipt.Parent then
     wait(0.5)
     d.CanCollide = true
     repeat
       d..Transparency = d.Transparency - 0.05
       wait(0.1)
      until d.Transparency = 0
    end
    isBusy = false
end


script.Parent.Touched:Connect(useDoor)
  
