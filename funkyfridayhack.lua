local client = game:GetService('Players').LocalPlayer;
local set_identity = (type(syn) == 'table' and syn.set_thread_identity) or setidentity or setthreadcontext

local function fail(r) return client:Kick(r) end

-- gracefully handle errors when loading external scripts
local function urlLoad(url)
    local success, result = pcall(game.HttpGet, game, url)
    if (not success) then
        return fail(string.format('Failed to GET url %q for reason: %q', url, tostring(result)))
    end

    local fn, err = loadstring(result)
    if (type(fn) ~= 'function') then
        return fail(string.format('Failed to loadstring url %q for reason: %q', url, tostring(err)))
    end

    local results = { pcall(fn) }
    if (not results[1]) then
        return fail(string.format('Failed to initialize url %q for reason: %q', url, tostring(results[2])))
    end

    return unpack(results, 2)
end

-- attempt to block imcompatible exploits
-- rewrote because old checks literally did not work
if type(set_identity) ~= 'function' then return fail('Unsupported exploit (missing "set_thread_identity")') end
if type(getconnections) ~= 'function' then return fail('Unsupported exploit (missing "getconnections")') end
if type(getloadedmodules) ~= 'function' then return fail('Unsupported exploit (misssing "getloadedmodules")') end
if type(getgc) ~= 'function' then return fail('Unsupported exploit (misssing "getgc")') end

local library = urlLoad("https://raw.githubusercontent.com/wally-rblx/uwuware-ui/main/main.lua")

local framework, scrollHandler
local counter = 0

while true do
    for _, obj in next, getgc(true) do
        if type(obj) == 'table' and rawget(obj, 'GameUI') then
            framework = obj;
            break
        end 
    end

    for _, module in next, getloadedmodules() do
        if module.Name == 'ScrollHandler' then
            scrollHandler = module;
            break;
        end
    end

    if (type(framework) == 'table') and (typeof(scrollHandler) == 'Instance') then
        break
    end

    counter = counter + 1
    if counter > 6 then
        fail(string.format('Failed to load game dependencies. Details: %s, %s', type(framework), typeof(scrollHandler)))
    end
    wait(1)
end

local runService = game:GetService('RunService')
local userInputService = game:GetService('UserInputService')
local random = Random.new()

local task = task or getrenv().task;
local fastWait, fastSpawn = task.wait, task.spawn;

-- firesignal implementation
-- hitchance rolling
local fireSignal, rollChance do
    -- updated for script-ware or whatever
    -- attempted to update for krnl

    function fireSignal(target, signal, ...)
        -- getconnections with InputBegan / InputEnded does not work without setting Synapse to the game's context level
        set_identity(2)
        for _, signal in next, getconnections(signal) do
            if type(signal.Function) == 'function' and islclosure(signal.Function) then
                local scr = rawget(getfenv(signal.Function), 'script')
                if scr == target then
                    pcall(signal.Function, ...)
                end
            end
        end
        set_identity(7)
    end

    -- uses a weighted random system
    -- its a bit scuffed rn but it works good enough

    function rollChance()
        if (library.flags.autoPlayerMode == 'Manual') then
            if (library.flags.sickHeld) then return 'Sick' end
            if (library.flags.goodHeld) then return 'Good' end
            if (library.flags.okayHeld) then return 'Ok' end
            if (library.flags.missHeld) then return 'Bad' end

            return 'Bad' -- incase if it cant find one
        end

        local chances = {
            { type = 'Sick', value = library.flags.sickChance },
            { type = 'Good', value = library.flags.goodChance },
            { type = 'Ok', value = library.flags.okChance },
            { type = 'Bad', value = library.flags.badChance },
            { type = 'Miss' , value = library.flags.missChance },
        }

        table.sort(chances, function(a, b)
            return a.value > b.value
        end)

        local sum = 0;
        for i = 1, #chances do
            sum += chances[i].value
        end

        if sum == 0 then
            -- forgot to change this before?
            -- fixed 6/5/21

            return chances[random:NextInteger(1, #chances)].type
        end

        local initialWeight = random:NextInteger(0, sum)
        local weight = 0;

        for i = 1, #chances do
            weight = weight + chances[i].value

            if weight > initialWeight then
                return chances[i].type
            end
        end

        return 'Sick' -- just incase it fails?
    end
end

-- autoplayer
do
    local chanceValues = { 
        Sick = 96,
        Good = 92,
        Ok = 87,
        Bad = 75,
    }

    local keyCodeMap = {}
    for _, enum in next, Enum.KeyCode:GetEnumItems() do
        keyCodeMap[enum.Value] = enum
    end

    if shared._unload then
        pcall(shared._unload)
    end

    function shared._unload()
        if shared._id then
            pcall(runService.UnbindFromRenderStep, runService, shared._id)
        end

        if library.open then
            library:Close()
        end

        library.base:ClearAllChildren()
        library.base:Destroy()
    end

    shared._id = game:GetService('HttpService'):GenerateGUID(false)
    runService:BindToRenderStep(shared._id, 1, function()
        if (not library.flags.autoPlayer) then return end
        if typeof(framework.SongPlayer.CurrentlyPlaying) ~= 'Instance' then return end
        if framework.SongPlayer.CurrentlyPlaying.ClassName ~= 'Sound' then return end

        local arrows = {}
        for _, obj in next, framework.UI.ActiveSections do
            arrows[#arrows + 1] = obj;
        end

        local count = framework.SongPlayer:GetKeyCount()
        local mode = count .. 'Key'

        local arrowData = framework.ArrowData[mode].Arrows

        for idx = 1, #arrows do
            local arrow = arrows[idx]
            if type(arrow) ~= 'table' then
                continue
            end

            if (arrow.Side == framework.UI.CurrentSide) and (not arrow.Marked) and framework.SongPlayer.CurrentlyPlaying.TimePosition > 0 then
                local indice = (arrow.Data.Position % count)
                local position = indice .. ''

                if (position) then
                    local hitboxOffset = 0 do
                        local settings = framework.Settings;
                        local offset = type(settings) == 'table' and settings.HitboxOffset;
                        local value = type(offset) == 'table' and offset.Value;

                        if type(value) == 'number' then
                            hitboxOffset = value;
                        end

                        hitboxOffset = hitboxOffset / 1000
                    end

                    local noteTime = (1 - math.abs(arrow.Data.Time - (framework.SongPlayer.CurrentlyPlaying.TimePosition + hitboxOffset))) * 100;

                    local result = rollChance()
                    arrow._hitChance = arrow._hitChance or result;

                    local hitChance = (library.flags.autoPlayerMode == 'Manual' and result or arrow._hitChance)
                    if hitChance ~= "Miss" and noteTime >= chanceValues[arrow._hitChance] then
                        fastSpawn(function()
                            arrow.Marked = true;
                            local keyCode = keyCodeMap[arrowData[position].Keybinds.Keyboard[1]]

                            fireSignal(scrollHandler, userInputService.InputBegan, { KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard }, false)

                            if arrow.Data.Length > 0 then
                                fastWait(arrow.Data.Length + (library.flags.autoDelay / 1000))
                            else
                                fastWait(library.flags.autoDelay / 1000)
                            end

                            fireSignal(scrollHandler, userInputService.InputEnded, { KeyCode = keyCode, UserInputType = Enum.UserInputType.Keyboard }, false)
                            arrow.Marked = nil;
                        end)
                    end
                end
            end
        end
    end)
end

-- menu
do
    local window = library:CreateWindow('Funky Friday') do
        local folder = window:AddFolder('Autoplayer') do
            local toggle = folder:AddToggle({ text = 'Autoplayer', flag = 'autoPlayer' })

            -- Fixed to use toggle:SetState
            folder:AddBind({ text = 'Autoplayer toggle', flag = 'autoPlayerToggle', key = Enum.KeyCode.End, callback = function()
                toggle:SetState(not toggle.state)
            end })

            folder:AddDivider()
            folder:AddList({ text = 'Autoplayer mode', flag = 'autoPlayerMode', values = { 'Chances', 'Manual'  } })
            folder:AddDivider()
            folder:AddSlider({ text = 'Sick %', flag = 'sickChance', min = 0, max = 100, value = 100 })
            folder:AddSlider({ text = 'Good %', flag = 'goodChance', min = 0, max = 100, value = 0 })
            folder:AddSlider({ text = 'Ok %', flag = 'okChance', min = 0, max = 100, value = 0 })
            folder:AddSlider({ text = 'Bad %', flag = 'badChance', min = 0, max = 100, value = 0 })
            folder:AddSlider({ text = 'Miss %', flag = 'missChance', min = 0, max = 100, value = 0 })
            folder:AddSlider({ text = 'Release delay (ms)', flag = 'autoDelay', min = 0, max = 350, value = 50 })
        end

        local folder = window:AddFolder('Manual keybinds') do
            folder:AddBind({ text = 'Sick', flag = 'sickBind', key = Enum.KeyCode.One, hold = true, callback = function(val) library.flags.sickHeld = (not val) end, })
            folder:AddBind({ text = 'Good', flag = 'goodBind', key = Enum.KeyCode.Two, hold = true, callback = function(val) library.flags.goodHeld = (not val) end, })
            folder:AddBind({ text = 'Ok', flag = 'okBind', key = Enum.KeyCode.Three, hold = true, callback = function(val) library.flags.okayHeld = (not val) end, })
            folder:AddBind({ text = 'Bad', flag = 'badBind', key = Enum.KeyCode.Four, hold = true, callback = function(val) library.flags.missHeld = (not val) end, })
        end

        local folder = window:AddFolder('Credits') do
            folder:AddLabel({ text = 'Jan - UI library' })
            folder:AddLabel({ text = 'wally - Script' })
            folder:AddLabel({ text = 'Sezei - Contributor'})
        end

        window:AddLabel({ text = 'Version 1.7' })
        window:AddLabel({ text = 'Updated 11/9/21' })
        window:AddDivider()
        window:AddButton({ text = 'Unload script', callback = function()
            shared._unload()
        end })
        window:AddButton({ text = 'Copy discord', callback = function()
              setclipboard("https://wally.cool/discord")
        end })
        window:AddDivider()
        window:AddBind({ text = 'Menu toggle', key = Enum.KeyCode.Delete, callback = function() library:Close() end })
    end

    library:Init()
end
