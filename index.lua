-- [boundary.com] Windows Performance Counters Lua Plugin
-- [author] Ivano Picco <ivano.picco@pianobit.com>

-- Common requires.
local utils = require('utils')
local timer = require('timer')
local fs = require('fs')
local json = require('json')
local os = require ('os')
local tools = require ('tools')

local success, boundary = pcall(require,'boundary')
if (not success) then
  boundary = nil 
end

-- Business requires.
local childProcess = require ('childprocess')
local table = require ('table')

-- Default parameters.
local pollInterval = 10000
local source       = nil

-- Configuration.
local _parameters = (boundary and boundary.param ) or json.parse(fs.readFileSync('param.json')) or {}

_parameters.pollInterval = 
  (_parameters.pollInterval and tonumber(_parameters.pollInterval)>0  and tonumber(_parameters.pollInterval)) or
  pollInterval;

_parameters.source =
  (type(_parameters.source) == 'string' and _parameters.source:gsub('%s+', '') ~= '' and _parameters.source ~= nil and _parameters.source) or
  os.hostname()

-- print results
function outputs(results,source)
	table.foreach(results, function (_, result)
		utils.print(result.metric, result.value or 0, source)
	end)
end

-- Get current values.
function poll(source)

  childProcess.execFile("powershell", {"-ExecutionPolicy", "Unrestricted", "-File", "tools\\perfcount.ps1" } , {},
    function ( err, stdout, stderr )
      if (err or #stderr>0) then 
        --print errors to stderr
        utils.debug(err or stderr)
        return
      end
	 
	  stdout = stdout:gsub("\r\n", "") --ignore \r\n
	  local success, results = pcall(json.parse,stdout)	  
	  if (success) then 
		outputs(results,source)
	  else
	    utils.debug("json error", results)
	  end
	  
    end
  )
  
end

-- Ready, go.
local source = _parameters.source --default hostname
poll(source)
timer.setInterval(_parameters.pollInterval,poll,source)

