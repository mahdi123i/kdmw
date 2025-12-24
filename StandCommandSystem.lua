-- StandCommandSystem.lua
-- Complete Command System with A-Z Commands
-- Rebuilt from V6.0.txt Structure

local StandCommandSystem = {}
StandCommandSystem.__index = StandCommandSystem

-- Version and Constants
StandCommandSystem.VERSION = "6.0"
StandCommandSystem.AUTHOR = "Mahdirml123i"
StandCommandSystem.CONSTANTS = {
    18939, 4265169242, 1570501719, 2731978471, 744817609,
    3944911081, 1191254327, 197035333, 935409779
}

-- Bit Operations Module
local bit32 = {
    bnot = bit32 and bit32.bnot or function(x) return ~x end,
    bxor = bit32 and bit32.bxor or function(x, y) return x ~ y end,
    band = bit32 and bit32.band or function(x, y) return x & y end,
    bor = bit32 and bit32.bor or function(x, y) return x | y end,
    lshift = bit32 and bit32.lshift or function(x, shift) return x << shift end,
    rshift = bit32 and bit32.rshift or function(x, shift) return x >> shift end,
    lrotate = bit32 and bit32.lrotate or function(x, shift)
        shift = shift % 32
        return (x << shift) | (x >> (32 - shift))
    end,
    rrotate = bit32 and bit32.rrotate or function(x, shift)
        shift = shift % 32
        return (x >> shift) | (x << (32 - shift))
    end,
    countrz = bit32 and bit32.countrz or function(x)
        if x == 0 then return 32 end
        local count = 0
        while (x & 1) == 0 do
            x = x >> 1
            count = count + 1
        end
        return count
    end
}

-- String Operations Module
local string_ops = {
    pack = string.pack or function(fmt, ...)
        local result = ""
        local args = {...}
        local argIndex = 1
        
        for i = 1, #fmt do
            local c = fmt:sub(i, i)
            if c == 's' then
                result = result .. tostring(args[argIndex])
                argIndex = argIndex + 1
            elseif c == 'd' or c == 'i' then
                result = result .. string.format("%d", args[argIndex])
                argIndex = argIndex + 1
            elseif c == 'f' then
                result = result .. string.format("%.6f", args[argIndex])
                argIndex = argIndex + 1
            elseif c == 'c' then
                result = result .. string.char(args[argIndex])
                argIndex = argIndex + 1
            elseif c == 'x' then
                result = result .. string.format("%x", args[argIndex])
                argIndex = argIndex + 1
            end
        end
        return result
    end,
    
    unpack = string.unpack or function(fmt, str, pos)
        pos = pos or 1
        local results = {}
        
        for i = 1, #fmt do
            local c = fmt:sub(i, i)
            if c == 's' then
                -- Read until null terminator
                local endPos = str:find('\0', pos) or (#str + 1)
                table.insert(results, str:sub(pos, endPos - 1))
                pos = endPos + 1
            elseif c == 'd' or c == 'i' then
                -- Read integer
                local numStr = ""
                while pos <= #str and str:sub(pos, pos):match('[0-9%-]') do
                    numStr = numStr .. str:sub(pos, pos)
                    pos = pos + 1
                end
                table.insert(results, tonumber(numStr) or 0)
            elseif c == 'f' then
                -- Read float
                local numStr = ""
                while pos <= #str and str:sub(pos, pos):match('[0-9%.%-]') do
                    numStr = numStr .. str:sub(pos, pos)
                    pos = pos + 1
                end
                table.insert(results, tonumber(numStr) or 0)
            elseif c == 'c' then
                -- Read single character
                table.insert(results, str:byte(pos, pos) or 0)
                pos = pos + 1
            elseif c == 'x' then
                -- Read hex
                local hexStr = ""
                while pos <= #str and str:sub(pos, pos):match('[0-9a-fA-F]') do
                    hexStr = hexStr .. str:sub(pos, pos)
                    pos = pos + 1
                end
                table.insert(results, tonumber(hexStr, 16) or 0)
            end
        end
        
        return table.unpack(results)
    end
}

-- Core Storage
local commands = {}
local aliases = {}
local variables = {}
local commandHistory = {}
local MAX_HISTORY = 100

-- Utility Functions
local function parseCommand(input)
    if not input or type(input) ~= "string" then
        return nil, "Invalid input"
    end
    
    input = input:trim()
    if input == "" then
        return nil, "Empty command"
    end
    
    local args = {}
    local current = ""
    local inQuotes = false
    local quoteChar = ""
    local escapeNext = false
    
    for i = 1, #input do
        local char = input:sub(i, i)
        
        if escapeNext then
            current = current .. char
            escapeNext = false
        elseif char == '\\' then
            escapeNext = true
        elseif (char == '"' or char == "'") and not inQuotes then
            inQuotes = true
            quoteChar = char
        elseif char == quoteChar and inQuotes then
            inQuotes = false
            if current ~= "" then
                table.insert(args, current)
                current = ""
            end
        elseif char == ' ' and not inQuotes then
            if current ~= "" then
                table.insert(args, current)
                current = ""
            end
        else
            current = current .. char
        end
    end
    
    if current ~= "" then
        table.insert(args, current)
    end
    
    return args
end

local function expandVariables(arg)
    return arg:gsub("%$(%w+)", function(var)
        return tostring(variables[var] or "")
    end)
end

-- Core System Functions
function StandCommandSystem:registerCommand(name, callback, description, cmdAliases)
    if not name or type(name) ~= "string" or name == "" then
        error("Command name must be a non-empty string")
    end
    
    if not callback or type(callback) ~= "function" then
        error("Command callback must be a function")
    end
    
    local lowerName = name:lower()
    commands[lowerName] = {
        callback = callback,
        description = description or "No description provided",
        name = name,
        usage = nil
    }
    
    if cmdAliases then
        if type(cmdAliases) == "string" then
            cmdAliases = {cmdAliases}
        end
        
        for _, alias in ipairs(cmdAliases) do
            local lowerAlias = alias:lower()
            if not aliases[lowerAlias] then
                aliases[lowerAlias] = lowerName
            end
        end
    end
    
    return true
end

function StandCommandSystem:setCommandUsage(name, usage)
    local cmd = commands[name:lower()] or commands[aliases[name:lower()]]
    if cmd then
        cmd.usage = usage
        return true
    end
    return false
end

function StandCommandSystem:unregisterCommand(name)
    if not name then return false end
    
    local lowerName = name:lower()
    local cmd = commands[lowerName]
    
    if not cmd then
        -- Check aliases
        for alias, cmdName in pairs(aliases) do
            if cmdName == lowerName then
                lowerName = cmdName
                cmd = commands[lowerName]
                break
            end
        end
    end
    
    if not cmd then return false end
    
    -- Remove command
    commands[lowerName] = nil
    
    -- Remove aliases
    for alias, cmdName in pairs(aliases) do
        if cmdName == lowerName then
            aliases[alias] = nil
        end
    end
    
    return true
end

function StandCommandSystem:execute(input)
    -- Add to history
    table.insert(commandHistory, input)
    if #commandHistory > MAX_HISTORY then
        table.remove(commandHistory, 1)
    end
    
    -- Parse command
    local args, err = parseCommand(input)
    if not args then
        return false, err
    end
    
    local cmdName = table.remove(args, 1):lower()
    
    -- Expand variables in arguments
    for i, arg in ipairs(args) do
        args[i] = expandVariables(arg)
    end
    
    -- Find command
    local cmd = commands[cmdName] or commands[aliases[cmdName]]
    if not cmd then
        return false, "Command not found: " .. cmdName
    end
    
    -- Execute command
    local success, result = pcall(cmd.callback, table.unpack(args))
    if not success then
        return false, "Execution error: " .. result
    end
    
    return true, result
end

function StandCommandSystem:getCommands()
    local result = {}
    for name, cmd in pairs(commands) do
        result[name] = {
            name = cmd.name,
            description = cmd.description,
            usage = cmd.usage
        }
    end
    return result
end

function StandCommandSystem:getCommandInfo(name)
    local lowerName = name:lower()
    local cmd = commands[lowerName] or commands[aliases[lowerName]]
    
    if not cmd then return nil end
    
    local cmdAliases = {}
    for alias, cmdName in pairs(aliases) do
        if cmdName == lowerName then
            table.insert(cmdAliases, alias)
        end
    end
    
    return {
        name = cmd.name,
        description = cmd.description,
        usage = cmd.usage,
        aliases = cmdAliases
    }
end

-- A-Z Commands Registration

-- A: Add/Append
StandCommandSystem:registerCommand("add", function(a, b)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local result = a + b
    print(string.format("%.2f + %.2f = %.2f", a, b, result))
    return result
end, "Add two numbers", {"sum", "plus"})

StandCommandSystem:registerCommand("append", function(filename, ...)
    local content = table.concat({...}, " ")
    local file = io.open(filename, "a")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    file:write(content .. "\n")
    file:close()
    print("Content appended to " .. filename)
    return true
end, "Append text to a file")

-- B: Bit operations
StandCommandSystem:registerCommand("bitand", function(a, b)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local result = bit32.band(a, b)
    print(string.format("%d & %d = %d", a, b, result))
    return result
end, "Bitwise AND operation", {"band"})

StandCommandSystem:registerCommand("bitor", function(a, b)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local result = bit32.bor(a, b)
    print(string.format("%d | %d = %d", a, b, result))
    return result
end, "Bitwise OR operation", {"bor"})

-- C: Calculate/Copy
StandCommandSystem:registerCommand("calc", function(...)
    local expr = table.concat({...}, " ")
    local func, err = load("return " .. expr, "calc", "t", {})
    if not func then
        return false, "Invalid expression: " .. err
    end
    local success, result = pcall(func)
    if not success then
        return false, "Calculation error: " .. result
    end
    print(string.format("%s = %s", expr, result))
    return result
end, "Calculate mathematical expression", {"calculate", "math"})

StandCommandSystem:registerCommand("copy", function(source, destination)
    local sourceFile = io.open(source, "r")
    if not sourceFile then
        return false, "Cannot open source file: " .. source
    end
    
    local content = sourceFile:read("*a")
    sourceFile:close()
    
    local destFile = io.open(destination, "w")
    if not destFile then
        return false, "Cannot open destination file: " .. destination
    end
    
    destFile:write(content)
    destFile:close()
    
    print("File copied from " .. source .. " to " .. destination)
    return true
end, "Copy file", {"cp"})

-- D: Delete/Directory
StandCommandSystem:registerCommand("delete", function(filename)
    local success, err = os.remove(filename)
    if not success then
        return false, "Cannot delete file: " .. err
    end
    print("File deleted: " .. filename)
    return true
end, "Delete a file", {"del", "rm"})

StandCommandSystem:registerCommand("directory", function(path)
    path = path or "."
    local files = {}
    
    if package.config:sub(1,1) == "\\" then -- Windows
        local handle = io.popen('dir "' .. path .. '" /b 2>nul')
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    else -- Unix-like
        local handle = io.popen('ls -la "' .. path .. '" 2>/dev/null')
        if handle then
            for file in handle:lines() do
                table.insert(files, file)
            end
            handle:close()
        end
    end
    
    if #files == 0 then
        print("No files found or directory doesn't exist")
    else
        print("Directory contents of " .. path .. ":")
        for i, file in ipairs(files) do
            print("  " .. file)
        end
    end
    
    return files
end, "List directory contents", {"dir", "ls"})

-- E: Echo/Execute
StandCommandSystem:registerCommand("echo", function(...)
    local text = table.concat({...}, " ")
    print(text)
    return text
end, "Display text", {"print"})

StandCommandSystem:registerCommand("execute", function(filename)
    local file = io.open(filename, "r")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    
    local commands = {}
    for line in file:lines() do
        line = line:trim()
        if line ~= "" and not line:match("^#") then
            table.insert(commands, line)
        end
    end
    file:close()
    
    print("Executing batch file: " .. filename)
    local results = {}
    for i, cmd in ipairs(commands) do
        print(string.format("[%d] %s", i, cmd))
        local success, result = StandCommandSystem:execute(cmd)
        results[i] = {command = cmd, success = success, result = result}
    end
    
    print("Batch execution completed")
    return results
end, "Execute commands from file", {"exec", "batch"})

-- F: Find/Format
StandCommandSystem:registerCommand("find", function(pattern, filename)
    if not filename then
        return false, "Filename required"
    end
    
    local file = io.open(filename, "r")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    
    local matches = {}
    local lineNum = 1
    for line in file:lines() do
        if line:find(pattern) then
            table.insert(matches, {line = lineNum, text = line})
        end
        lineNum = lineNum + 1
    end
    file:close()
    
    if #matches == 0 then
        print("No matches found for: " .. pattern)
    else
        print("Found " .. #matches .. " matches for: " .. pattern)
        for _, match in ipairs(matches) do
            print(string.format("  Line %d: %s", match.line, match.text))
        end
    end
    
    return matches
end, "Find text in file", {"grep", "search"})

StandCommandSystem:registerCommand("format", function(str, formatType)
    if formatType == "upper" then
        local result = str:upper()
        print(result)
        return result
    elseif formatType == "lower" then
        local result = str:lower()
        print(result)
        return result
    elseif formatType == "reverse" then
        local result = str:reverse()
        print(result)
        return result
    else
        return false, "Unknown format type. Use: upper, lower, reverse"
    end
end, "Format text (upper/lower/reverse)", {"fmt"})

-- G: Get/GoTo
StandCommandSystem:registerCommand("get", function(url)
    -- Simulate HTTP GET request
    print("GET request to: " .. url)
    print("(This is a simulation - actual HTTP not implemented)")
    return {url = url, status = "simulated", data = "sample response"}
end, "HTTP GET request simulation")

StandCommandSystem:registerCommand("goto", function(label)
    print("Goto functionality not implemented in this version")
    print("Label requested: " .. label)
    return true
end, "Jump to label (simulated)", {"jump"})

-- H: Help/History
StandCommandSystem:registerCommand("help", function(cmd)
    if cmd then
        local info = StandCommandSystem:getCommandInfo(cmd)
        if info then
            print("=" .. string.rep("=", 50))
            print("Command: " .. info.name)
            print("Description: " .. info.description)
            if info.usage then
                print("Usage: " .. info.usage)
            end
            if #info.aliases > 0 then
                print("Aliases: " .. table.concat(info.aliases, ", "))
            end
            print("=" .. string.rep("=", 50))
        else
            print("Command not found: " .. cmd)
        end
    else
        print("Stand Command System v" .. StandCommandSystem.VERSION)
        print("Available commands (type 'help <command>' for details):")
        print("")
        
        local categorized = {}
        for name, cmdInfo in pairs(StandCommandSystem:getCommands()) do
            local firstChar = cmdInfo.name:sub(1, 1):upper()
            if not categorized[firstChar] then
                categorized[firstChar] = {}
            end
            table.insert(categorized[firstChar], cmdInfo.name)
        end
        
        for char = string.byte('A'), string.byte('Z') do
            local charStr = string.char(char)
            if categorized[charStr] then
                print(charStr .. ":")
                table.sort(categorized[charStr])
                for _, cmdName in ipairs(categorized[charStr]) do
                    print("  " .. cmdName)
                end
                print("")
            end
        end
    end
    return true
end, "Show help information", {"h", "?"})

StandCommandSystem:registerCommand("history", function()
    if #commandHistory == 0 then
        print("No command history")
        return {}
    end
    
    print("Command History (last " .. #commandHistory .. " commands):")
    for i = math.max(1, #commandHistory - 9), #commandHistory do
        print(string.format("  %3d: %s", i, commandHistory[i]))
    end
    return commandHistory
end, "Show command history", {"hist"})

-- I: If/Import
StandCommandSystem:registerCommand("if", function(condition, command)
    local func, err = load("return " .. condition, "if", "t", {})
    if not func then
        return false, "Invalid condition: " .. err
    end
    
    local success, result = pcall(func)
    if not success then
        return false, "Condition error: " .. result
    end
    
    if result then
        print("Condition true, executing: " .. command)
        return StandCommandSystem:execute(command)
    else
        print("Condition false, skipping: " .. command)
        return true, "Condition false"
    end
end, "Conditional command execution")

StandCommandSystem:registerCommand("import", function(moduleName)
    print("Importing module: " .. moduleName)
    -- This is a simulation
    return {module = moduleName, status = "simulated"}
end, "Import module (simulated)", {"require"})

-- J: Join/JSON
StandCommandSystem:registerCommand("join", function(sep, ...)
    local args = {...}
    local result = table.concat(args, sep)
    print(result)
    return result
end, "Join strings with separator", {"concat"})

StandCommandSystem:registerCommand("json", function(action, data)
    if action == "parse" then
        print("JSON parsing simulated: " .. data)
        return {parsed = true, data = data}
    elseif action == "stringify" then
        print("JSON stringify simulated")
        return '{"simulated": true}'
    else
        return false, "Unknown JSON action. Use: parse, stringify"
    end
end, "JSON operations (simulated)")

-- K: Kill/Key
StandCommandSystem:registerCommand("kill", function(process)
    print("Kill process simulated: " .. process)
    return {killed = process, status = "simulated"}
end, "Kill process (simulated)", {"stop"})

StandCommandSystem:registerCommand("key", function(key, value)
    if value then
        variables[key] = value
        print("Set variable " .. key .. " = " .. value)
        return true
    else
        local val = variables[key]
        if val then
            print(key .. " = " .. val)
            return val
        else
            print("Variable not found: " .. key)
            return nil
        end
    end
end, "Set or get variables", {"var", "set"})

-- L: List/Loop
StandCommandSystem:registerCommand("list", function()
    local cmds = StandCommandSystem:getCommands()
    print("Registered Commands:")
    for name, cmd in pairs(cmds) do
        print(string.format("  %-15s - %s", cmd.name, cmd.description))
    end
    return cmds
end, "List all commands", {"ls", "cmds"})

StandCommandSystem:registerCommand("loop", function(count, command)
    count = tonumber(count) or 1
    if count <= 0 then
        return false, "Count must be positive"
    end
    
    local results = {}
    for i = 1, count do
        print(string.format("Loop %d/%d: %s", i, count, command))
        local success, result = StandCommandSystem:execute(command)
        results[i] = {iteration = i, success = success, result = result}
    end
    
    print("Loop completed " .. count .. " times")
    return results
end, "Repeat command multiple times", {"repeat"})

-- M: Move/Math
StandCommandSystem:registerCommand("move", function(source, destination)
    -- Copy first
    local success, err = StandCommandSystem:execute("copy " .. source .. " " .. destination)
    if not success then
        return false, "Move failed during copy: " .. err
    end
    
    -- Then delete source
    success, err = StandCommandSystem:execute("delete " .. source)
    if not success then
        print("Warning: Could not delete source file after copy")
    end
    
    print("File moved from " .. source .. " to " .. destination)
    return true
end, "Move file", {"mv"})

StandCommandSystem:registerCommand("math", function(operation, a, b)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    
    local operations = {
        add = function(x, y) return x + y end,
        sub = function(x, y) return x - y end,
        mul = function(x, y) return x * y end,
        div = function(x, y) return y ~= 0 and x / y or "Division by zero" end,
        pow = function(x, y) return x ^ y end,
        mod = function(x, y) return y ~= 0 and x % y or "Modulo by zero" end
    }
    
    local func = operations[operation:lower()]
    if not func then
        return false, "Unknown operation. Use: add, sub, mul, div, pow, mod"
    end
    
    local result = func(a, b)
    print(string.format("%.2f %s %.2f = %s", a, operation, b, tostring(result)))
    return result
end, "Mathematical operations", {"arithmetic"})

-- N: Number/Network
StandCommandSystem:registerCommand("number", function(...)
    local args = {...}
    local numbers = {}
    
    for _, arg in ipairs(args) do
        local num = tonumber(arg)
        if num then
            table.insert(numbers, num)
        end
    end
    
    if #numbers == 0 then
        print("No valid numbers provided")
        return {}
    end
    
    local sum = 0
    local min = math.huge
    local max = -math.huge
    
    for _, num in ipairs(numbers) do
        sum = sum + num
        if num < min then min = num end
        if num > max then max = num end
    end
    
    local avg = sum / #numbers
    
    print("Numbers: " .. table.concat(numbers, ", "))
    print("Count: " .. #numbers)
    print("Sum: " .. sum)
    print("Average: " .. avg)
    print("Min: " .. min)
    print("Max: " .. max)
    
    return {numbers = numbers, sum = sum, average = avg, min = min, max = max}
end, "Number analysis", {"num", "stats"})

StandCommandSystem:registerCommand("network", function(command)
    print("Network command: " .. command)
    print("(Network functionality simulated)")
    return {command = command, status = "simulated"}
end, "Network operations (simulated)", {"net"})

-- O: Output/Open
StandCommandSystem:registerCommand("output", function(filename, ...)
    local content = table.concat({...}, " ")
    if not filename then
        print("Output: " .. content)
        return content
    end
    
    local file = io.open(filename, "w")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    
    file:write(content)
    file:close()
    print("Output written to: " .. filename)
    return true
end, "Output to screen or file", {"out"})

StandCommandSystem:registerCommand("open", function(filename)
    local file = io.open(filename, "r")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    
    local content = file:read("*a")
    file:close()
    
    print("File: " .. filename)
    print("Size: " .. #content .. " bytes")
    print("Content:")
    print(string.rep("-", 50))
    print(content)
    print(string.rep("-", 50))
    
    return content
end, "Open and display file", {"read", "cat"})

-- P: Process/Pause
StandCommandSystem:registerCommand("process", function()
    print("Process list simulation")
    local processes = {
        "system",
        "command_processor",
        "memory_manager",
        "file_system"
    }
    
    for i, proc in ipairs(processes) do
        print(string.format("  %d. %s", i, proc))
    end
    
    return processes
end, "Show process list", {"ps", "tasks"})

StandCommandSystem:registerCommand("pause", function(seconds)
    seconds = tonumber(seconds) or 1
    print("Pausing for " .. seconds .. " seconds...")
    
    -- Simple pause simulation
    local start = os.time()
    while os.time() - start < seconds do
        -- Busy wait (not ideal but works for simulation)
    end
    
    print("Resumed")
    return true
end, "Pause execution", {"sleep", "wait"})

-- Q: Query/Quit
StandCommandSystem:registerCommand("query", function(question)
    print("Query: " .. question)
    print("(Query system simulated)")
    return {question = question, answer = "simulated response"}
end, "Query system (simulated)", {"ask"})

StandCommandSystem:registerCommand("quit", function()
    print("Thank you for using Stand Command System")
    print("Goodbye!")
    os.exit(0)
end, "Exit the program", {"exit", "bye"})

-- R: Run/Remove
StandCommandSystem:registerCommand("run", function(command)
    return StandCommandSystem:execute(command)
end, "Run a command", {"exec"})

StandCommandSystem:registerCommand("remove", function(filename)
    return StandCommandSystem:execute("delete " .. filename)
end, "Remove file (alias for delete)", {"rm"})

-- S: System/Status
StandCommandSystem:registerCommand("system", function()
    local info = {
        "Stand Command System v" .. StandCommandSystem.VERSION,
        "Lua Version: " .. _VERSION,
        "Platform: " .. (jit and jit.version or "Standard Lua"),
        "Commands Registered: " .. #StandCommandSystem:getCommands(),
        "History Size: " .. #commandHistory,
        "Variables Stored: " .. #variables
    }
    
    print("System Information:")
    for _, line in ipairs(info) do
        print("  " .. line)
    end
    
    return info
end, "Show system information", {"sys", "sysinfo"})

StandCommandSystem:registerCommand("status", function()
    local status = {
        running = true,
        version = StandCommandSystem.VERSION,
        commands = #StandCommandSystem:getCommands(),
        uptime = "simulated",
        memory = "simulated"
    }
    
    print("System Status:")
    for key, value in pairs(status) do
        print(string.format("  %-15s: %s", key, tostring(value)))
    end
    
    return status
end, "Show system status", {"stat"})

-- T: Time/Type
StandCommandSystem:registerCommand("time", function()
    local current = os.date("*t")
    local timeStr = string.format("%04d-%02d-%02d %02d:%02d:%02d",
        current.year, current.month, current.day,
        current.hour, current.min, current.sec)
    
    print("Current time: " .. timeStr)
    return current
end, "Show current time", {"date", "now"})

StandCommandSystem:registerCommand("type", function(filename)
    return StandCommandSystem:execute("open " .. filename)
end, "Display file contents (alias for open)", {"show"})

-- U: Update/Undo
StandCommandSystem:registerCommand("update", function()
    print("Checking for updates...")
    print("Current version: " .. StandCommandSystem.VERSION)
    print("Latest version: 6.0")
    print("System is up to date")
    return {current = StandCommandSystem.VERSION, latest = "6.0", update = false}
end, "Check for updates", {"upgrade"})

StandCommandSystem:registerCommand("undo", function()
    if #commandHistory == 0 then
        print("No commands to undo")
        return false
    end
    
    local lastCommand = commandHistory[#commandHistory]
    print("Undoing: " .. lastCommand)
    table.remove(commandHistory)
    print("Undo completed (simulated)")
    return true
end, "Undo last command", {"revert"})

-- V: Version/Verify
StandCommandSystem:registerCommand("version", function()
    print("Stand Command System")
    print("Version: " .. StandCommandSystem.VERSION)
    print("Author: " .. StandCommandSystem.AUTHOR)
    print("Built: " .. os.date("%Y-%m-%d"))
    return StandCommandSystem.VERSION
end, "Show version information", {"ver", "v"})

StandCommandSystem:registerCommand("verify", function(filename)
    if not filename then
        return false, "Filename required"
    end
    
    local file = io.open(filename, "r")
    if not file then
        print("File does not exist: " .. filename)
        return false
    end
    
    local content = file:read("*a")
    file:close()
    
    local size = #content
    local lines = 0
    for _ in content:gmatch("\n") do
        lines = lines + 1
    end
    
    print("File verification:")
    print("  Name: " .. filename)
    print("  Size: " .. size .. " bytes")
    print("  Lines: " .. lines)
    print("  Exists: Yes")
    
    return {filename = filename, size = size, lines = lines, exists = true}
end, "Verify file information", {"check", "validate"})

-- W: Write/Who
StandCommandSystem:registerCommand("write", function(filename, ...)
    local content = table.concat({...}, " ")
    local file = io.open(filename, "w")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    
    file:write(content)
    file:close()
    print("Written to file: " .. filename)
    return true
end, "Write to file", {"save"})

StandCommandSystem:registerCommand("who", function()
    print("Current user: system")
    print("Session: command_line")
    print("Privileges: standard")
    return {user = "system", session = "command_line", privileges = "standard"}
end, "Show current user information", {"user", "whoami"})

-- X: XOR/ExecuteScript
StandCommandSystem:registerCommand("xor", function(a, b)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    local result = bit32.bxor(a, b)
    print(string.format("%d ^ %d = %d", a, b, result))
    return result
end, "Bitwise XOR operation", {"bitxor"})

StandCommandSystem:registerCommand("xscript", function(script)
    print("Executing script: " .. script)
    -- Simulated script execution
    return {script = script, executed = true, output = "simulated"}
end, "Execute script (simulated)", {"execscript"})

-- Y: Yes/Year
StandCommandSystem:registerCommand("yes", function(response)
    if not response then
        response = "y"
    end
    
    print("Auto-response: " .. response)
    return {response = response, confirmed = true}
end, "Automatic yes response", {"confirm"})

StandCommandSystem:registerCommand("year", function()
    local current = os.date("*t")
    print("Current year: " .. current.year)
    
    local isLeap = (current.year % 4 == 0 and current.year % 100 ~= 0) or (current.year % 400 == 0)
    print("Leap year: " .. (isLeap and "Yes" or "No"))
    
    return {year = current.year, leap = isLeap}
end, "Show current year information")

-- Z: Zip/Zoom
StandCommandSystem:registerCommand("zip", function(files, output)
    print("Zipping files: " .. files)
    print("Output: " .. output)
    print("(Zip functionality simulated)")
    return {files = files, output = output, zipped = true}
end, "Zip files (simulated)", {"compress"})

StandCommandSystem:registerCommand("zoom", function(factor)
    factor = tonumber(factor) or 1.0
    print("Zoom factor: " .. factor)
    print("(Zoom functionality simulated)")
    return {zoom = factor, applied = true}
end, "Zoom simulation")

-- Interactive Mode
function StandCommandSystem:interactive(prompt)
    prompt = prompt or "SCS> "
    
    print("=" .. string.rep("=", 60))
    print("Stand Command System v" .. StandCommandSystem.VERSION)
    print("Type 'help' for available commands, 'quit' to exit")
    print("=" .. string.rep("=", 60))
    
    while true do
        io.write(prompt)
        local input = io.read()
        
        if not input then
            print("\nInput terminated")
            break
        end
        
        input = input:trim()
        
        if input == "" then
            -- Do nothing for empty input
        elseif input:lower() == "quit" or input:lower() == "exit" then
            print("Exiting Stand Command System")
            break
        else
            local success, result = self:execute(input)
            if not success then
                print("Error: " .. tostring(result))
            end
        end
    end
end

-- Auto-completion helper
function StandCommandSystem:complete(prefix)
    local matches = {}
    prefix = prefix:lower()
    
    -- Check commands
    for name, _ in pairs(commands) do
        if name:sub(1, #prefix) == prefix then
            table.insert(matches, name)
        end
    end
    
    -- Check aliases
    for alias, _ in pairs(aliases) do
        if alias:sub(1, #prefix) == prefix then
            table.insert(matches, alias)
        end
    end
    
    -- Check variables
    for var, _ in pairs(variables) do
        if var:sub(1, #prefix) == prefix then
            table.insert(matches, "$" .. var)
        end
    end
    
    table.sort(matches)
    return matches
end

-- Batch execution from file
function StandCommandSystem:runScript(filename)
    return self:execute("execute " .. filename)
end

-- Export modules
StandCommandSystem.bit32 = bit32
StandCommandSystem.string = string_ops
StandCommandSystem.variables = variables

return StandCommandSystem
