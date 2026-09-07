hl.config({
    input = {
        kb_layout = "us",
    },
})

local mod = "SUPER"

-- Application Binds
hl.bind(mod .. " + Q", hl.dsp.exec_cmd("kitty"))

-- Native Binds
hl.bind(mod .. " + C", hl.dsp.window.kill())
hl.bind(mod .. " + M", hl.dsp.exit())

-- Fullscren Binds
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }))

-- Workspace Binds
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = i, follow = true }))
end
