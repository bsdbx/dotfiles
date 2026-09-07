hl.config({
    input = {
        kb_layout = "us",
    },
})

local mod = "SUPER"

hl.bind(mod .. " + Q", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + C", hl.dsp.window.kill())
hl.bind(mod .. " + M", hl.dsp.exit())

hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 1 }))
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = 0 }))
