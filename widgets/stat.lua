
--[[
                                                  
     Licensed under GNU General Public License v2 
      * (c) 2015,      projektile                 
      * (c) 2013,      Luke Bonham                
      * (c) 2010-2012, Peter Hofmann              
                                                  
--]]

local first_line   = require("lain.helpers").first_line
local newtimer     = require("lain.helpers").newtimer
local beautiful    = require("beautiful")
local naughty      = require("naughty")
local wibox        = require("wibox")

local io           = { lines  = io.lines }
local math         = { ceil   = math.ceil,
                       floor  = math.floor }
local string       = { format = string.format,
                       gmatch = string.gmatch,
                       len    = string.len }
local tostring     = tostring
local tonumber     = tonumber

local setmetatable = setmetatable

-- CPU/RAM usage
-- lain.widgets.cpu
local stat = {
    cpu_last_total = 0,
    cpu_last_active = 0
}

local _notification  = nil
fs_notification_preset = { fg = beautiful.fg_normal  }

function stat:hide()
    if _notification ~= nil then
        naughty.destroy(_notification)
        _notification = nil
    end
end

function stat:show(t_out, inc_offset)
    if tonumber(stat.cpu) >= 10 then
        ws = "      "
    else
        ws = "       "
    end
    if tonumber(stat.ram) < 1000 then
        ows = "   "
    else
        ows = "  "
    end
    if _notification ~= nil then
        _notification = naughty.notify ({
        replaces_id = _notification.id,
        title    = "Usage Stats",
        text     = "CPU:" .. ws .. stat.cpu .. "%\n" ..
                   "RAM:" .. ows .. stat.ram .. " MB",
        font_size = "11",
        timeout  = t_out,
        preset   = preset
    })
    else
        _notification = naughty.notify ({
        title    = "Usage Stats",
        text     = "CPU:" .. ws .. stat.cpu .. "%\n" ..
                   "RAM:" .. ows .. stat.ram .. " MB",
        font_size = "11",
        timeout  = t_out,
        preset   = preset
    })
    end
end

local function worker(args)
    local args     = args or {}
    local timeout  = args.timeout or 1
    local settings = args.settings or function() end

    stat.widget = wibox.widget.textbox('')

    function update()
        -- Read the amount of time the CPUs have spent performing
        -- different kinds of work. Read the first line of /proc/stat
        -- which is the sum of all CPUs.
        local times = first_line("/proc/stat")
        local at = 1
        local idle = 0
        local total = 0
        for field in string.gmatch(times, "[%s]+([^%s]+)")
        do
            -- 4 = idle, 5 = ioWait. Essentially, the CPUs have done
            -- nothing during these times.
            if at == 4 or at == 5
            then
                idle = idle + field
            end
            total = total + field
            at = at + 1
        end
        local active = total - idle

        -- Read current data and calculate relative values.
        local dactive = active - stat.cpu_last_active
        local dtotal = total - stat.cpu_last_total

        -- Read the total amount of RAM and subtract
        -- free, buffer and cache

        mem_now = {}
        for line in io.lines("/proc/meminfo")
        do
            for k, v in string.gmatch(line, "([%a]+):[%s]+([%d]+).+")
            do
                if     k == "MemTotal"  then mem_now.total = math.floor(v / 1024)
                elseif k == "MemFree"   then mem_now.free  = math.floor(v / 1024)
                elseif k == "Buffers"   then mem_now.buf   = math.floor(v / 1024)
                elseif k == "Cached"    then mem_now.cache = math.floor(v / 1024)
                elseif k == "SwapTotal" then mem_now.swap  = math.floor(v / 1024)
                elseif k == "SwapFree"  then mem_now.swapf = math.floor(v / 1024)
                end
            end
        end

        cpu_now = {}
        cpu_now.usage = tostring(math.ceil((dactive / dtotal) * 100))
        stat.cpu = cpu_now.usage

        mem_now.used = mem_now.total - (mem_now.free + mem_now.buf + mem_now.cache)
        mem_now.swapused = mem_now.swap - mem_now.swapf
        stat.ram = mem_now.used

        if _notification ~= nil then
            stat:show()
        end

        widget = stat.widget
        settings()

        -- Save current data for the next run.
        stat.cpu_last_active = active
        stat.cpu_last_total = total
    end

    newtimer("stat", timeout, update)

    return stat.widget
end

function stat:attach(widget, args)
    local args = args or {}

    widget:connect_signal("mouse::enter", function () stat:show() end)
    widget:connect_signal("mouse::leave", function () stat:hide() end)
end

return setmetatable(stat, { __call = function(_, ...) return worker(...) end })
