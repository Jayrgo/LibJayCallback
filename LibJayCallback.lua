local MAJOR = "LibJayCallback"
local MINOR = 1

assert(LibStub, format("%s requires LibStub.", MAJOR))

local lib = LibStub:NewLibrary(MAJOR, MINOR)

if not lib then return end

local safecall, xsafecall
do -- safecall, xsafecall
    local pcall = pcall
    ---@param func function
    ---@return boolean retOK
    safecall = function(func, ...) return pcall(func, ...) end

    local geterrorhandler = geterrorhandler
    ---@param err string
    ---@return function handler
    local function errorhandler(err) return geterrorhandler()(err) end

    local xpcall = xpcall
    ---@param func function
    ---@return boolean retOK
    xsafecall = function(func, ...) return xpcall(func, errorhandler, ...) end
end

local tnew, tdel
do -- tnew, tdel
    local cache = setmetatable({}, {__mode = "k"})

    local next = next
    local select = select
    ---@return table t
    function tnew(...)
        local t = next(cache)
        if t then
            cache[t] = nil
            local n = select("#", ...)
            for i = 1, n do t[i] = select(i, ...) end
            return t
        end
        return {...}
    end

    local wipe = wipe
    ---@param t table
    function tdel(t) cache[wipe(t)] = true end
end

local packargs
do -- pack2
    local select = select
    ---@return table args
    function packargs(...) return {n = select("#", ...), ...} end
end

local unpackargs
do -- pack2
    local unpack = unpack
    ---@param t table
    function unpackargs(t) return unpack(t, 1, t.n) end
end

local getkey
do -- getkey
    local strhash
    do -- strhash
        local fmod = math.fmod
        local strbyte = strbyte
        local strlen = strlen
        ---@param str string
        ---@return string str
        function strhash(str)
            local counter = 1
            local len = strlen(str)
            for i = 1, len, 3 do
                counter =
                    fmod(counter * 8161, 4294967279) + -- 2^32 - 17: Prime!
                        (strbyte(str, i) * 16776193) +
                        ((strbyte(str, i + 1) or (len - i + 256)) * 8372226) +
                        ((strbyte(str, i + 2) or (len - i + 256)) * 3932164)
            end
            return fmod(counter, 4294967291) -- 2^32 - 5: Prime (and different from the prime in the loop)
        end
    end

    local getstring
    do -- getstring
        local tostring = tostring

        local prefixes = setmetatable({}, {
            __index = function(t, k)
                local v = tostring(function() end) .. "%s"
                t[k] = v
                return v
            end
        })

        local format = format
        local type = type
        ---@param str string
        ---@return string str
        function getstring(arg)
            return format(prefixes[type(arg)], tostring(arg))
        end
    end

    local select = select
    local tconcat = table.concat
    ---@return string key
    function getkey(...)
        local keys = tnew()
        for i = 1, select("#", ...) do
            keys[i] = getstring(select(i, ...))
        end
        local key = strhash(tconcat(keys))
        tdel(keys)
        return key
    end
end

local select = select
---@param func function
---@return function func
local function getFunc(func, ...)
    if select("#", ...) == 0 then
        return func
    else
        local args = packargs(...)
        return function(...)
            local params = {}
            local argCount = args.n
            for i = 1, argCount do params[i] = args[i] end
            for i = 1, select("#", ...) do
                local n = argCount + i
                params[n] = select(i, ...)
                params.n = n
            end
            func(unpackargs(params))
        end
    end
end

local format = format
local error = error
local pairs = pairs
local type = type
local CopyTable = CopyTable
---@param self table
---@param event string
local function TriggerEvent(self, event, ...)
    if type(event) ~= "string" then
        error(format(
                  "Usage: %s:TriggerEvent(event[, ...]): 'event' - string expected got %s",
                  MAJOR, type(event)), 2)
    end

    local events = self.events[event]
    if events then
        -- CopyTable is used, to avoid errors if the table is changed during iter
        for key, callback in pairs(CopyTable(events)) do
            if events[key] == callback then safecall(callback, ...) end
        end
    end
end

local function xTriggerEvent(self, event, ...)
    if type(event) ~= "string" then
        error(format(
                  "Usage: %s:xTriggerEvent(event[, ...]): 'event' - string expected got %s",
                  MAJOR, type(event)), 2)
    end

    local events = self.events[event]
    if events then
        -- CopyTable is used, to avoid errors if the table is changed during iter
        for key, callback in pairs(CopyTable(events)) do
            if events[key] == callback then xsafecall(callback, ...) end
        end
    end
end

---@param self table
---@param event string
local function Wipe(self, event)
    if type(event) ~= "string" and type(event) ~= "nil" then
        error(format(
                  "Usage: %s:Wipe(event): 'event' - string or nil expected got %s",
                  MAJOR, type(event)), 2)
    end
    if event then
        if not self.events[event] then return end
        self.events[event] = nil
        safecall(self.OnEventUnregistered, self, event)
    else
        for event in pairs(self.events) do self:Wipe(event) end -- luacheck: ignore 422
    end
end

local next = next
---@param target table
---@param RegisterCallback string
---@param UnregisterCallback string
---@return table callbacks
function lib:New(target, RegisterCallback, UnregisterCallback)
    if type(target) ~= "table" then
        error(format(
                  "Usage: %s:New(target[, RegisterCallback[, UnregisterCallback]]): 'target' - table expected got %s",
                  MAJOR, type(target)), 2)
    end
    RegisterCallback = RegisterCallback and RegisterCallback or
                           "RegisterCallback"
    if type(RegisterCallback) ~= "string" then
        error(format(
                  "Usage: %s:New(target[, RegisterCallback[, UnregisterCallback]]): 'RegisterCallback' - string expected got %s",
                  MAJOR, type(RegisterCallback)), 2)
    end
    UnregisterCallback = UnregisterCallback and UnregisterCallback or
                             "UnregisterCallback"
    if type(UnregisterCallback) ~= "string" then
        error(format(
                  "Usage: %s:New(target[, RegisterCallback[, UnregisterCallback]]): 'UnregisterCallback' - string expected got %s",
                  MAJOR, type(UnregisterCallback)), 2)
    end

    local callbacks = {
        events = {},
        TriggerEvent = TriggerEvent,
        xTriggerEvent = xTriggerEvent,
        Wipe = Wipe
    }

    ---@param self table
    ---@param event string
    ---@param callback function
    ---@vararg any
    target[RegisterCallback] = function(self, event, callback, ...) -- luacheck: ignore 432
        if type(event) ~= "string" then
            error(format(
                      "Usage: %s:%s(event[, object], callback[, ...]): 'event' - string expected got %s",
                      MAJOR, RegisterCallback, type(event)), 2)
        end

        local regKey, regFunc
        if type(callback) == "table" then
            local object, callback = callback, select(1, ...) -- luacheck: ignore 422
            if type(callback) == "function" then
                regKey = getkey(object, callback, ...)
                regFunc = select("#", ...) > 1 and
                              getFunc(callback, select(2, ...)) or
                              getFunc(callback)
            elseif type(callback) == "string" then
                regKey = getkey(object, object[callback], ...)
                regFunc = select("#", ...) > 1 and
                              getFunc(object[callback], object, select(2, ...)) or
                              getFunc(object[callback], object)
            else
                error(format(
                          "Usage: %s:%s(event, object, callback[, ...]): 'callback' - function or string expected got %s",
                          MAJOR, RegisterCallback, type(callback)), 2)
            end
        elseif type(callback) == "function" then
            regKey = getkey(callback, ...)
            regFunc = getFunc(callback, ...)
        else
            error(format(
                      "Usage: %s:%s(event[, object], callback[, ...]): 'callback' - function or string expected got %s",
                      MAJOR, RegisterCallback, type(callback)), 2)
        end

        local isFirst
        if not callbacks.events[event] then
            callbacks.events[event] = {}
            isFirst = true
        end
        callbacks.events[event][regKey] = regFunc
        if isFirst then
            safecall(callbacks.OnEventRegistered, self, event)
        end
    end

    ---@param self table
    ---@param event string
    ---@param object table | function
    ---@param callback function | string
    target[UnregisterCallback] = function(self, event, callback, ...) -- luacheck: ignore 432
        if type(event) ~= "string" then
            error(format(
                      "Usage: %s:%s(event[, object], callback): 'event' - string expected got %s",
                      MAJOR, UnregisterCallback, type(event)), 2)
        end

        local regKey
        if type(callback) == "table" then
            local object, callback = callback, select(1, ...) -- luacheck: ignore 422
            if type(callback) == "function" then
                regKey = getkey(object, callback, ...)
            elseif type(callback) == "string" then
                regKey = getkey(object, object[callback], ...)
            else
                error(format(
                          "Usage: %s:%s(event, object, callback[, ...]): 'callback' - function or string expected got %s",
                          MAJOR, UnregisterCallback, type(callback)), 2)
            end
        elseif type(callback) == "function" then
            regKey = getkey(callback, ...)
        else
            error(format(
                      "Usage: %s:%s(event[, object], callback[, ...]): 'callback' - function or string expected got %s",
                      MAJOR, UnregisterCallback, type(callback)), 2)
        end

        if callbacks.events[event] then
            callbacks.events[event][regKey] = nil
            if not next(callbacks.events[event]) then
                callbacks.events[event] = nil
                safecall(callbacks.OnEventUnregistered, self, event)
            end
        end
    end

    return callbacks
end
setmetatable(lib, {__call = lib.New})
