--
-- Module.
--
local tools = {}


-- Requires.
local string = require('string')
local childProcess = require ('childprocess')
local os = require ('os')
local table = require ('table')

--
-- Limit a given number x between two boundaries.
-- Either min or max can be nil, to fence on one side only.
--
tools.fence = function(x, min, max)
  return (min and x < min and min) or (max and x > max and max) or x
end

--
-- Encode data in Base64 format.
--
tools.base64 = function(data)
  local _lookup = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  return ((data:gsub('.', function(x)
    local r, b = '', x:byte()
    for i = 8, 1, -1 do
      r = r .. (b % 2 ^ i - b % 2 ^ (i - 1) > 0 and '1' or '0')
    end
    return r
  end) .. '0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
    if #x < 6 then
      return ''
    end
    local c = 0
    for i = 1, 6 do
      c = c + (x:sub(i, i) == '1' and 2 ^ (6 - i) or 0)
    end
    return _lookup:sub(c + 1, c + 1)
  end) .. ({
    '',
    '==',
    '='
  })[#data % 3 + 1])
end


--
-- Split a string into a table
-- 
tools.split = function (inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; local i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

--
-- Cross platform process stats by name pattern
-- it uses `ps` on *nix and `tasklist` on Windows 
-- Configuration parameters:
--   processName: process name pattern ( matching values from `ps -o comm,args` on *nix or command name on Windows)
--   reconcile: reconcile technique if multiple found, can be:
--            "first" : use the first one found, default
--            "parent" : use the one that is parent of others
--            "uptime" : (linux only) use the one that is started first
-- callback result is a table with pid (process id), and optionally ppid (parent process id),
--    time (total cpu time), rss (resident set size), comm (process name), args (command and arguments)
--
local psStat= {}
tools.findProcStat = function (cfg, cb)
  
  local osType = string.lower(os.type())
  local isWindows = osType == 'win32'
  local isLinux   = osType == 'linux'

  cfg = cfg or {}
  cfg.reconcile = cfg.reconcile or "first"

  local cmd     --ps on *nix, tasklist on Windows
  local opts    --command options
  local env     --environment variables
  local sep     --field separator

  if (isWindows) then
    cmd = "tasklist"
    opts = {"/v", "/fo","csv" }
    env = {}
    sep = ","

  else --*nix

    cmd = "ps"
    opts = {"-e", "-o","pid,ppid,time,rss,comm,args" }
    if (isLinux and cfg.reconcile == "uptime") then
      opts[#opts+1] = "--sort=lstart"
    end
    env = { ["COLUMNS"] = 4096 }
    sep = " "

  end

  local psHandler = function ( err, stdout, stderr )
    if (err or #stderr>0) then 
      cb(err or stderr)
      return
    end 

    local parents = {}
    local found = false;
    -- call func with each word in a string
    stdout:gsub("[^\r\n]+", function(line)
      if (found) then return end

      local _proc = tools.split(line,sep)
      local proc

      if (isWindows) then
        --csv format
        proc = {}
        proc.comm = _proc[1]:gsub("^\"*(.-)\"*$", "%1") --trim enclosing "
        proc.pid  = _proc[2]:gsub("^\"*(.-)\"*$", "%1")
        proc.rss  = _proc[5]:gsub("^\"*(%d-)[^%d]?(%d-)[^%d]?(%d-)[^%d]?(%d-) K\"*$", "%1%2%3%4") --remove trailing ' K' and thousands separator
        proc.time = _proc[8]:gsub("^\"*(.-)\"*$", "%1")
        proc.ppid = -1 -- tasklist doesn't support parent pid
        proc.args = ""  --tasklist doesn't show arguments
      else
        proc = {
          ["pid"]  = table.remove(_proc,1),
          ["ppid"] = table.remove(_proc,1),
          ["time"] = table.remove(_proc,1),
          ["rss"]  = table.remove(_proc,1),
          ["comm"] = table.remove(_proc,1),
          ["args"] = table.concat(_proc," "),
        }
      end

      proc.rss=(tonumber(proc.rss) or 0 ) --convert to number

      if (string.match(proc.comm, cfg.processName) ~= nil or string.match(proc.args, cfg.processName) ~= nil) then
        if (cfg.reconcile == "first" or cfg.reconcile == "uptime") then
          found=true
          cb(nil,proc)
          return
        else  --parent
          parents[proc.pid]=proc  --pid hashing, easy navigation
        end
      end
    end)

    if (found) then return end

    if (cfg.reconcile == "parent" and next(parents) ~=nil) then
      local _,proc = next(parents) --get the first matched process
      while (parents[proc.ppid] ~= nil) do --follow parents
        proc=parents[proc.ppid]
      end
      cb(nil,proc)
      return
    end

    cb("Process "..cfg.processName.." not found")
  end

  childProcess.execFile(cmd , opts , env , psHandler ) 

end


--
-- Export.
--
return tools