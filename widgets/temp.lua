
--[[
                                                  
     Licensed under GNU General Public License v2 
      * (c) 2013, Luke Bonham                     
                                                  
--]]

local newtimer     = require("lain.helpers").newtimer
local beautiful    = require("beautiful")
local naughty      = require("naughty")
local wibox        = require("wibox")
local awful        = require("awful")
local io           = io

local setmetatable = setmetatable

-- coretemp
-- lain.widgets.temp
temp = {}

local _notification  = nil
fs_notification_preset = { fg = beautiful.fg_normal  }

function temp:hide()
    if _notification ~= nil then
        naughty.destroy(_notification)
        _notification = nil
    end
end

function temp:show(t_out, inc_offset)
    if _notification ~= nil then
        _notification = naughty.notify ({
        replaces_id = _notification.id,
        title    = "Temps",
        text     = "CPU:    " .. temp.cpu .. "°C\n" ..
                   "GPU:    " .. temp.gpu .. "°C",
        timeout  = t_out,
        preset   = preset
    })
    else
        _notification = naughty.notify ({
        title    = "Temps",
        text     = "CPU:    " .. temp.cpu .. "°C\n" ..
                   "GPU:    " .. temp.gpu .. "°C",
        timeout  = t_out,
        preset   = preset
    })
    end
end

function trim(s)
    return s:find'^%s*$' and '' or s:match'^%s*(.*%S)'
end

local function worker(args)
    local args     = args or {}
    local timeout  = args.timeout or 1
    local tempfile = args.tempfile or "/sys/class/thermal/thermal_zone0/temp"
    local settings = args.settings or function() end

    temp.widget = wibox.widget.textbox('')

    function update()

        temp.cpu = trim(awful.util.pread("sensors | grep 'Physical id 0:' | cut -b 18-19"))
        temp.gpu = trim(awful.util.pread("nvidia-settings -q gpucoretemp -t| sed -n '1p'"))

        if _notification ~= nil then
            temp:show()
        end

        widget = temp.widget
        settings()
    end

    newtimer("coretemp", timeout, update)
    return temp.widget
end

function temp:attach(widget, args)
    local args = args or {}

    widget:connect_signal("mouse::enter", function () temp:show() end)
    widget:connect_signal("mouse::leave", function () temp:hide() end)
end

return setmetatable(temp, { __call = function(_, ...) return worker(...) end })
