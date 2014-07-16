local escape_pattern, parse_content_disposition, build_url
do
  local _obj_0 = require("lapis.util")
  escape_pattern, parse_content_disposition, build_url = _obj_0.escape_pattern, _obj_0.parse_content_disposition, _obj_0.build_url
end

local flatten_params
flatten_params = function(t)
  local _tbl_0 = { }
  for k, v in pairs(t) do
    _tbl_0[k] = type(v) == "table" and v[#v] or v
  end
  return _tbl_0
end

local parse_url, parse_query
do
  pcall( function() 
      local client = require("leda.client")
      parse_url = client.parseUrl
      parse_query = client.parseQuery
 end)
end

local request = {
  headers = function()
    return __leda.httpRequestGetHeaders(__leda.httpRequest) 
  end,
  cmd_mth = function()
    return __leda.httpRequestGetMethod(__leda.httpRequest) 
  end,
  cmd_url = function()
    return __leda.httpRequestGetUrl(__leda.httpRequest) 
  end,
  body = function()
    return __leda.httpRequestGetBody(__leda.httpRequest) 
  end,
  relpath = function(t)
    return t.parsed_url.path
  end,
  scheme = function(t)
    return t.parsed_url.scheme
  end,
  port = function(t)
    return t.parsed_url.port 
  end,
  srv = function()
    return t.parsed_url.host 
  end,
  remote_addr = function()
    return __leda.httpRequestGetAddress(__leda.httpRequest) 
  end,
  referer = function()
    return  ""
  end,
  parsed_url = function(t)
    local host = t.headers.host
    local parsed =  parse_url(t.cmd_url)
    if host then 
        local parsed_host = parse_url(host)
        parsed.host = parsed_host.host
        parsed.port = parsed_host.port
    end
    return parsed
  end,
  built_url = function(t)
    return build_url(t.parsed_url)
  end,
 
  params_post = function(t) 
    if (t.headers["content-type"] or ""):match(escape_pattern("application/x-www-form-urlencoded")) then
        return flatten_params(parse_query(t.body or ""))
    end
    
    return {}
  end,
  
  params_get = function(t)
    return flatten_params(t.parsed_url.params)
  end
}
local lazy_tbl
lazy_tbl = function(tbl, index)
  return setmetatable(tbl, {
    __index = function(self, key)
      local fn = index[key]
      if fn then
        do
          local res = fn(self)
          self[key] = res
          return res
        end
      end
    end
  })
end
local build_request
build_request = function(unlazy)
  if unlazy == nil then
    unlazy = false
  end
  do
    local t = lazy_tbl({ }, request)
    if unlazy then
      for k in pairs(request) do
        local _ = t[k]
      end
    end
    return t
  end
end
local build_response
build_response = function()
  return {
    req = build_request(),
    add_header = function(self, k, v)
      local old = self.headers[k]
      local _exp_0 = type(old)
      if "nil" == _exp_0 then
        self.headers[k] = v
      elseif "table" == _exp_0 then
        old[#old + 1] = v
        self.headers[k] = old
      else
        self.headers[k] = {
          old,
          v
        }
      end
    end,
    headers = {}
  }
end
local dispatch
dispatch = function(app)
  if __leda.init then
      local config = require("lapis.config")
      
      -- start the leda server
      __api.serverCreate({
          type = 'http',
          port = config.get().port,
          host = config.get().host or 'localhost',
          threads = __api.processorCount()
          })
      return
  else
      -- set request callback
      if not __leda.onHttpRequest then
          __leda.onHttpRequest = function()  dispatch(app) end
          return      
      end
  end    
    
  local res = build_response()
  
  app:dispatch(res.req, res)
  if res.status then
    __leda.httpResponseSetStatus(__leda.httpResponse, tonumber(res.status))
  end
  
  if next(res.headers) then
     __leda.httpResponseSetHeaders(__leda.httpResponse, res.headers)
  end
  
  if res.content then
    __leda.httpResponseSetBody(__leda.httpResponse, res.content)
  end
 
  return res
end
return {
  build_request = build_request,
  build_response = build_response,
  dispatch = dispatch
}