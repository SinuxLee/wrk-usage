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

-- 进程变量
local counter = 0
local threads = {}

-- 每个线程执行一次，可以自定义线程变量
function setup(thread)
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

    local msg = "thread %d created, beginning id: %d"
    print(msg:format(id, index))
end

-- 每个请求调用一次，请求之间的间隔
function delay()
    return 0
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
    for index, thread in ipairs(threads) do
        local id = thread:get("id")
        local requests = thread:get("requests")
        local responses = thread:get("responses")
        local msg = "thread %d made %d requests and got %d responses"
        print(msg:format(id, requests, responses))
    end
end