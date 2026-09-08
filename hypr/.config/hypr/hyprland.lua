--  _____  _             _           
-- |  __ \| |           (_)          
-- | |__) | |_   _  __ _ _ _ __  ___ 
-- |  ___/| | | | |/ _` | | '_ \/ __|
-- | |    | | |_| | (_| | | | | \__ \
-- |_|    |_|\__,_|\__, |_|_| |_|___/
--                  __/ |            
--                 |___/             

-- ╭───────────────────╮
-- │  HyprWindowShade  │
-- ╰───────────────────╯

local HOME = os.getenv("HOME")
local PLUGIN_PATH = HOME .. "/.local/share/hyprland/plugins/HyprWindowShade.so"
local SHADERS = HOME .. "/.config/hypr/shaders/"

-- Copying the disabled shader to the `active.glsl` (communicates between the two shaders)
hl.on("hyprland.start", function()
    hl.exec_cmd("cp " .. SHADERS .. "tint_off.glsl " .. SHADERS .. "active.glsl")
    hl.exec_cmd("hyprctl plugin load " .. PLUGIN_PATH)
end)

-- Applt `active.glsl` to the active window. Currently tint is off
hl.window_rule({
    match = { class = ".*" },
    tag = "+shader:" .. SHADERS .. "active.glsl",
})

--  _    _ _   _ _      
-- | |  | | | (_) |     
-- | |  | | |_ _| |___  
-- | |  | | __| | / __| 
-- | |__| | |_| | \__ \ 
--  \____/ \__|_|_|___/ 

-- Function to create a local enum 
local function Enum(tbl)
    local enum = {}

    for key, value in pairs(tbl) do
        -- If value is not assigned
        if type(key) == "number" then
            enum[value] = value
        -- If value is assigned
        else
            enum[key] = value
       end
    end

    -- Make enum actually constant
    return setmetatable({}, {
        __index = enum,
        __newindex = function(_, key, _)
            error(string.format("Error: Trying to edit constant Enum on key '%s'", tostring(key)), 2)
        end,
        __metatable = false
     })
end

--   _____                           _ 
--  / ____|                         | |
-- | |  __  ___ _ __   ___ _ __ __ _| |
-- | | |_ |/ _ \ '_ \ / _ \ '__/ _` | |
-- | |__| |  __/ | | |  __/ | | (_| | |
--  \_____|\___|_| |_|\___|_|  \__,_|_|
                                     

hl.config({
    input = {
        kb_layout = "us",
    },
})

--  ____  _           _     
-- |  _ \(_)         | |    
-- | |_) |_ _ __   __| |___ 
-- |  _ <| | '_ \ / _` / __|
-- | |_) | | | | | (_| \__ \
-- |____/|_|_| |_|\__,_|___/                                                                           

local MOD = Enum({
    MAIN = "SUPER",
    "SHIFT",
    CTRL = "CONTROL",
    "ALT",
    LMB = "mouse:272",
    RMB = "mouse:273"
})

local MODE = Enum({
    "NormalMode",
    "WindowMode"
})

local current_state = MODE.NormalMode

-- ╭─────────────────────╮
-- │  Application Binds  │
-- ╰─────────────────────╯

-- Launch Terminal application
hl.bind(MOD.MAIN .. " + Q", hl.dsp.exec_cmd("kitty"))

-- ╭────────────────╮
-- │  Native Binds  │
-- ╰────────────────╯

-- Exit Hyprland session
hl.bind(MOD.MAIN .. " + M", hl.dsp.exit())

-- ╭───────────────────╮
-- │  Workspace Binds  │
-- ╰───────────────────╯

-- Automatically generate binds for moving and focusing workspaces
for i = 1, 9 do
    hl.bind(MOD.MAIN .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(MOD.MAIN .. " + " .. MOD.SHIFT .. " + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
end

-- ╭──────────────────────╮
-- │  Window Close Binds  │
-- ╰──────────────────────╯

hl.bind(MOD.MAIN .. " + C", hl.dsp.window.close())

-- ╭────────────────────╮
-- │  Fullscreen Binds  │
-- ╰────────────────────╯

-- Enter non-full fullscreen mode
hl.bind(MOD.MAIN .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))

-- Enter full fullscreen mode
hl.bind(MOD.MAIN .. " + " .. MOD.SHIFT .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))

-- ╭──────────────────────────────────╮
-- │  Window Movement/Resizing Binds  │
-- ╰──────────────────────────────────╯

-- Constant map for focus move
local GLOBAL_WINDOW_DIRECTIONS = {
    { key = "right", dir = "r" },
    { key = "left",  dir = "l" },
    { key = "up",    dir = "u" },
    { key = "down",  dir = "d" }
}

-- Automatically generate binds for moving window focus. This is allowed outside of `Window Mode`
for _, item in ipairs(GLOBAL_WINDOW_DIRECTIONS) do
    hl.bind(MOD.MAIN .. " + " .. item.key, hl.dsp.focus({ direction = item.dir }))
end

-- A quicker function to directly change the `active.glsl` buffer from Lua, instead of running `cp` commands
local function set_shader(src)
    local inf = io.open(SHADERS .. src, "r")
    if not inf then return end
    local data = inf:read("*a")
    inf:close()
    local outf = io.open(SHADERS .. "active.glsl", "w")
    if not outf then return end
    outf:write(data)
    outf:close()
end

-- Function to enter `Window Mode` state
local function enter_window_mode()
    current_state = MODE.WindowMode

    -- Tint the active window
    set_shader("tint_on.glsl")
    -- Force render reload, so the effect is instant
    hl.dispatch(hl.dsp.force_renderer_reload())

    hl.dispatch(hl.dsp.submap("window_mode"))
end

-- Function to exit `Window Mode` state
local function exit_window_mode()
    current_state = MODE.NormalMode

    -- Disable tint on the active window
    set_shader("tint_off.glsl")

    -- Forcing render reload here doesn't seem to do anything, but it's not the end of the world to leave it here
    hl.dispatch(hl.dsp.force_renderer_reload())

    hl.dispatch(hl.dsp.submap("reset"))
end

-- Initialize the `Window Mode` submap
hl.bind(MOD.MAIN .. " + W", enter_window_mode)

-- `Window Mode` submap implementation
hl.define_submap("window_mode", function()

    -- Window resizing factor in PX
    local RESIZE_PX = 20

    -- Constant map for focus, window move and resizing
    local LOCAL_WINDOW_DIRECTIONS = {
        { keys = {"right", "L"}, dir = "r", x = RESIZE_PX,  y = 0 },
        { keys = {"left",  "H"}, dir = "l", x = -RESIZE_PX, y = 0 },
        { keys = {"up",    "K"}, dir = "u", x = 0,          y = -RESIZE_PX },
        { keys = {"down",  "J"}, dir = "d", x = 0,          y = RESIZE_PX }
    }

    -- Automatically generate binds for focus, window move and resizing 
    for _, item in ipairs(LOCAL_WINDOW_DIRECTIONS) do
        for _, key in ipairs(item.keys) do
            -- Focus move
            hl.bind(key, hl.dsp.focus({ direction = item.dir }))

            -- Window move
            hl.bind(MOD.SHIFT .. " + " .. key, hl.dsp.window.move({ direction = item.dir }))

            -- Window resize. `repeating = true` is a must
            hl.bind(MOD.CTRL .. " + " .. key, hl.dsp.window.resize({ x = item.x, y = item.y, relative = true }), { repeating = true })
        end
     end

     -- Exit `Window Mode`
     hl.bind("escape", exit_window_mode)
     hl.bind("return", exit_window_mode)
end)

-- LMB Drag for window movement
hl.bind(MOD.MAIN .. " + " .. MOD.LMB, hl.dsp.window.drag(), { mouse = true })

-- RMB Drag for window resizing
hl.bind(MOD.MAIN .. " + " .. MOD.RMB, hl.dsp.window.resize(), { mouse = true})

                                                           
--     /\                                                    
--    /  \   _ __  _ __   ___  __ _ _ __ __ _ _ __   ___ ___ 
--   / /\ \ | '_ \| '_ \ / _ \/ _` | '__/ _` | '_ \ / __/ _ \
--  / ____ \| |_) | |_) |  __/ (_| | | | (_| | | | | (_|  __/
-- /_/    \_\ .__/| .__/ \___|\__,_|_|  \__,_|_| |_|\___\___|
--          | |   | |                                        
--          |_|   |_|                                        

-- A test configuration for testing the `Window Mode`
hl.config({
    general = {
        gaps_in = 0,
        gaps_out = 0,
        border_size = 0,
    },
    decoration = {
        rounding = 0,
        shadow = {
            enabled = false,
        },
    },
})
