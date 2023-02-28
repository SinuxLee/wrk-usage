--[[
    API:
    wrk.format(method, path, headers, body) --自定义请求
    wrk.lookup(host, service) --获取域名的IP和端口
    wrk.connect(addr) --判断addr是否能连接

    -- thread提供了1个属性，3个方法
    -- thread.addr 设置请求需要打到的ip
    -- thread:get(name) 获取线程全局变量
    -- thread:set(name, value) 设置线程全局变量
    -- thread:stop() 终止线程
--]]

require('functions')
local player = require "player"
local ffi = require("ffi")

ffi.cdef[[
    typedef long time_t;
    typedef int clockid_t;

    typedef struct timespec {
            time_t   tv_sec;        /* seconds */
            long     tv_nsec;       /* nanoseconds */
    } nanotime;
    int clock_gettime(clockid_t clk_id, struct timespec *tp);
]]

-- 进程变量
local THREAD_MAX_RPS = 10000 -- RPS per thread
local counter = 0
local threads = {}

-- 利用 ffi 获取毫秒级实现戳
local function get_current_time_in_ms()
    local pnano = ffi.new("nanotime[?]", 1)
    -- CLOCK_REALTIME  -> 0     -- 系统相对1970年的时间
    -- CLOCK_MONOTONIC -> 6     -- 系统重启到现在的时间
    ffi.C.clock_gettime(6, pnano)
    return pnano[0].tv_sec * 1000 + pnano[0].tv_nsec/1000000
end

-- 每个线程执行一次，可以自定义线程变量,可以访问进程变量
function setup(thread)
    thread:set("max_rps", THREAD_MAX_RPS)
    thread:set("current_rps", 0)
    thread:set("current_time", 0)
    thread:set("id", counter)
    thread:set("index", counter * 1000000 + 1)
    table.insert(threads, thread)
    counter = counter + 1
end

-- 每个线程执行一次，args为命令行参数，可以直接使用setup中定义的变量
function init(args)
    requests = 0 -- 线程变量
    responses = 0
    players = {} -- 玩家数组
    count = 0 -- 每个线程操作过的玩家
    max_count = 10000
    current_time = get_current_time_in_ms()

    local msg = "thread %d created, beginning id: %d"
    print(msg:format(id, index))
end

-- 每个请求调用一次，请求之间的间隔
function delay()
    local now_ms = get_current_time_in_ms()
    local elapsed = now_ms - current_time
    if elapsed > 1000 then
        current_time = now_ms
        current_rps = 1
        return 0
    end

    if current_rps < max_rps then
        current_rps = current_rps + 1
        return 0
    end

    local sleep_time = 1000 - elapsed
    return tonumber(sleep_time)
end

-- 每个请求调用一次，可以自定义请求
function request()
    if count < max_count then
        requests = requests + 1
        local idx = index+count
        local p = players[idx]
        if p == nil then
            p = player:new(1)
            players[idx] = p
        end

        if p:is_end() then
            p:restart()
        end

        local method, path, headers, body = p:get_request(idx)
        local data = wrk.format(method, path, headers, body)

        count = count + 1
        if count >= max_count then
            count = 0
        end

        return data
    end
end

-- 每个请求调用一次
function response(status, headers, body)
    responses = responses + 1
    local index = headers["X-Robot-Index"]
    if status == 200 and index ~= nil then
        local p = players[tonumber(index)]
        p:parse_rsp(body)
    end
end

-- 进程只执行一次
function done(summary, latency, requests)
    for _, thread in ipairs(threads) do
        local id = thread:get("id")
        local requests = thread:get("requests")
        local responses = thread:get("responses")
        local msg = "thread %d made %d requests and got %d responses"
        print(msg:format(id, requests, responses))
    end
end