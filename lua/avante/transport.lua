local curl = require("plenary.curl")
local api = vim.api
local fn = vim.fn
local uv = vim.uv
local Utils = require("avante.utils")

---@class avante.Transport
local M = {}

---@class AvanteTransportOptions
---@field url string The URL to send the request to
---@field headers table<string, string> Headers to include in the request
---@field body any The request body (will be encoded as JSON)
---@field proxy string|nil Proxy to use for the request
---@field insecure boolean|nil Whether to allow insecure connections
---@field stream function|nil Function to handle streaming responses
---@field on_error function|nil Function to handle errors
---@field callback function|nil Function to handle the complete response
---@field rawArgs table|nil Additional raw arguments to pass to the transport
---@field transport_type string|nil The type of transport to use ("curl" by default)

---@class AvanteTransportResult
---@field status number HTTP status code
---@field headers table<string, string> Response headers
---@field body string Response body

-- Default transport is curl
M.default_transport = "curl"

-- Registry of available transports
M.transports = {}

-- Register the curl transport
M.transports.curl = {
  ---@param opts AvanteTransportOptions
  ---@return any job handle
  request = function(opts)
    local curl_body_file = fn.tempname() .. ".json"
    local json_content = vim.json.encode(opts.body)
    fn.writefile(vim.split(json_content, "\n"), curl_body_file)

    Utils.debug("curl body file:", curl_body_file)

    local function cleanup()
      if require("avante.config").debug then return end
      vim.schedule(function() fn.delete(curl_body_file) end)
    end

    return curl.post(opts.url, {
      headers = opts.headers,
      proxy = opts.proxy,
      insecure = opts.insecure,
      body = curl_body_file,
      raw = opts.rawArgs,
      stream = opts.stream,
      on_error = function(err)
        cleanup()
        if opts.on_error then opts.on_error(err) end
      end,
      callback = function(result)
        cleanup()
        if opts.callback then opts.callback(result) end
      end,
    })
  end,

  ---@param job any
  shutdown = function(job)
    if job then job:shutdown() end
  end,
}

-- Example of how to register a command line transport
-- M.transports.command = {
--   request = function(opts)
--     -- Implementation using vim.fn.jobstart or similar
--   end,
--   shutdown = function(job)
--     -- Implementation to kill the job
--   end
-- }

---@param opts AvanteTransportOptions
---@return any job handle
function M.request(opts)
  local transport_type = opts.transport_type or M.default_transport
  local transport = M.transports[transport_type]

  if not transport then error("Transport type '" .. transport_type .. "' not registered") end

  return transport.request(opts)
end

---@param job any
---@param transport_type string|nil
function M.shutdown(job, transport_type)
  transport_type = transport_type or M.default_transport
  local transport = M.transports[transport_type]

  if not transport then error("Transport type '" .. transport_type .. "' not registered") end

  transport.shutdown(job)
end

return M
