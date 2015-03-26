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
local ffi = require ('ffi')

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
  
--ffi native integrations
ffi.cdef[[
  //Returns the performance object name or counter name corresponding to the specified index. (ASCII version)
  static extern unsigned int PdhLookupPerfNameByIndexA(char* szMachineName, unsigned int dwNameIndex, char* szNameBuffer, unsigned int* pcchNameBufferSize);  
  
  //Validates that the counter is present on the computer specified in the counter path. (ASCII version)
  static extern unsigned int PdhValidatePathA (char* szFullCounterPath);
]]
local pdh = ffi.load("pdh.dll")

--Get local name of a performance counter from a given index
function getPerformanceCounterLocalName(index)
  local pcchNameBufferSize = ffi.new("unsigned int[1]", 0) --uint *
  local ret = pdh.PdhLookupPerfNameByIndexA(nil,index,nil,pcchNameBufferSize)  --perform a null lookup to get the buffer size
  local nameBufferSize = tonumber(pcchNameBufferSize[0]) --convert the size
  if (nameBufferSize == 0 ) then
    return "" --on error, return null
  end
  local szNameBuffer = ffi.new("char[?]",nameBufferSize)  --create a buffer
  local ret = pdh.PdhLookupPerfNameByIndexA(nil,index,szNameBuffer,pcchNameBufferSize) --perform the lookup
  if (ret ~= 0) then
    return "" --on error, return null
  else
    return ffi.string(szNameBuffer,nameBufferSize-1);
  end
end

-- Parse typeperf output, i.e. : 
--[[  

"(PDH-CSV 4.0)","\\localhost\238(_Total)\6"
"03/24/2015 17:58:33.275","16.697718"
 
Esecuzione comando riuscita.

]]
function parseTypePerfCSVLine(source,line)
  if(not line:match('^"')) then --discard invalid line
  return
  end
  line = line:gsub('"','') 
  local t = tools.split(line,',')
  return t
end

-- parse typeperf outputs
function typePerfParser( err, stdout, stderr )
  if (err or #stderr>0) then 
  --print errors to stderr
  utils.debug(err or stderr)
  return
  end

  local values=nil
  local first = true
  stdout:gsub("[^\r\n]+", function(line)
  local t = parseTypePerfCSVLine(source,line)
  if (not t) then --skips empty line
    return
  end
  if (not values) then --gets one parsed line only
    if (first) then  --skips first line
      first = false
      return
    end
    values = t
  end
  end)

  table.remove(values,1) --remove first value (the timestamps)
  return values
end

-- Get current values.
function poll(counters,source)

  local singleOutputCounters = {};
  local singleOutputOptions = {"/SC","1"};
  --OPTIMIZATION: grouping single output counter in a single call
  for _,counter in ipairs(counters) do 
    if (counter ~= 0) then
      if (counter.multiOutput) then
        --multi output counter must be execute alone, but in parallel
        childProcess.execFile("typeperf", {"/SC","1" , counter.localPath }, {}, 
          function(err, stdout, stderr)
            local results = typePerfParser (err, stdout, stderr)
            if (results) then
              utils.print(counter.metric, results[(counter.instance or 0) +1] or 0, source)
            end
          end )
      else
        table.insert(singleOutputCounters,counter)
        table.insert(singleOutputOptions,counter.localPath)
      end
    end
  end
  
  --OPTIMIZATION: grouping single output value in a single call
  local results = childProcess.execFile("typeperf", singleOutputOptions, {}, 
    function(err, stdout, stderr)
      local results = typePerfParser (err, stdout, stderr)
      if (results) then
        table.foreach(results, function (index, result)
          utils.print(singleOutputCounters[index].metric, result or 0, source)
        end)
      end
    end)
end


--counters config
local counters =  json.parse(fs.readFileSync('tools\\counters.json')) or {}  
--counters paths localization
for idx,counter in ipairs(counters) do 
  local hasInstances =  counter.path:match('%*')
  counter.multiOutput = (hasInstances and counter.instance ~= nil) 
  local instance = counter.multiOutput and "*" or "_Total"
  instance = hasInstances and "("..instance..")" or ""
  local path = "\\"..getPerformanceCounterLocalName(counter.setIdx)..instance.."\\"..getPerformanceCounterLocalName(counter.counterIdx)
  --check path validity
  if (pdh.PdhValidatePathA(ffi.cast("char *",path)) == 0) then
    counter.localPath = path
  else
    utils.debug("Can't find a valid localized path for", counter.metric)
    counters[idx] = 0
  end
end

-- Ready, go.
poll(counters, _parameters.source)
timer.setInterval(_parameters.pollInterval,poll,counters,_parameters.source)
  