require "functions"
local json = require "json"

local _M = {}
_M._version = "0.0.1"

local mt = { __index = _M } --元表

function _M.new(self, idx)
    local obj = { user_id = 0, idx = idx , access_token = ""}
    return setmetatable(obj, mt)
end

function _M.get_request(self,robot_id)
    local i = self.idx
    self.idx = i + 1
    return self.fun[i](self,robot_id)
end

function _M.restart(self)
    self.idx = 2
end

function _M.is_end(self)
    return self.idx > #self.fun
end

function login(p,robot_id)
    return "GET", string.format("/auth/v1/inner/access_token?platform=wechat&open_id=robot_%d&app_id=1001", robot_id), { ["X-Robot-Index"] = robot_id, }, nil
end

function login_result(p, data)
    p.user_id = data.userId
    p.access_token = data.accessToken
end

function user_info(p,robot_id)
    return "GET", string.format("/auth/v1/player/info?user_id=%d", p.user_id), { ["X-Robot-Index"] = robot_id, }, nil
end

function user_info_result(p, data)
    -- if data.userId ~= p.user_id then
    -- end
end

function verify_token(p,robot_id)
    return "GET", string.format("/auth/v1/token/authentication?access_token=%s&user_id=%d", p.access_token, p.user_id), { ["X-Robot-Index"] = robot_id, }, nil
end

function verify_token_result(p, data)
    -- if data == nil then
    -- end
end


_M.fun = { [1] = login, [2]=user_info, [3]=verify_token, } -- 发起request
local switch = { [2] = login_result, [3]=user_info_result, [4]=verify_token_result, } -- 处理response

function _M.parse_rsp(self, body)
    local rsp = json.decode(body)
    if rsp.errCode == 0 then
        local fun = switch[self.idx]
        if fun then
            fun(self, rsp.data)
        end
    end
end

return _M