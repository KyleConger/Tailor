local Log = {}

Log.LogLevel = {
	Verbose = 1,
	Debugging = 2,
	Information = 3,
	Warning = 4,
	Error = 5,
	Fatal = 6,
}

local LEVEL_NAMES = {
	[Log.LogLevel.Verbose] = "VERBOSE",
	[Log.LogLevel.Debugging] = "DEBUG",
	[Log.LogLevel.Information] = "INFO",
	[Log.LogLevel.Warning] = "WARN",
	[Log.LogLevel.Error] = "ERROR",
	[Log.LogLevel.Fatal] = "FATAL",
}

local minLevel = Log.LogLevel.Information

local function formatTemplate(template: string, ...: any): string
	local values = { ... }
	local index = 0

	return template:gsub("{(%w+)}", function(_key)
		index += 1
		local value = values[index]
		if value == nil then
			return "nil"
		end
		return tostring(value)
	end)
end

local function write(level: number, context: string?, template: string, ...: any)
	if level < minLevel then
		return
	end

	local message = formatTemplate(template, ...)
	local prefix = string.format("[%s]", LEVEL_NAMES[level] or "LOG")

	if context then
		prefix ..= string.format(" [%s]", context)
	end

	local line = string.format("%s %s", prefix, message)

	if level >= Log.LogLevel.Warning then
		warn(line)
	else
		print(line)
	end
end

local function createLogger(context: string?)
	return {
		Verbose = function(_, template, ...)
			write(Log.LogLevel.Verbose, context, template, ...)
		end,
		Debug = function(_, template, ...)
			write(Log.LogLevel.Debugging, context, template, ...)
		end,
		Info = function(_, template, ...)
			write(Log.LogLevel.Information, context, template, ...)
		end,
		Warn = function(_, template, ...)
			write(Log.LogLevel.Warning, context, template, ...)
		end,
		Error = function(_, template, ...)
			local message = formatTemplate(template, ...)
			write(Log.LogLevel.Error, context, template, ...)
			return message
		end,
		Fatal = function(_, template, ...)
			local message = formatTemplate(template, ...)
			write(Log.LogLevel.Fatal, context, template, ...)
			return message
		end,
	}
end

function Log.ForContext(context: string)
	return createLogger(context)
end

function Log.SetLogger(_logger)
	-- Compatibility stub for LoggerSetup.
end

function Log.RobloxOutput()
	return {}
end

function Log.Configure()
	local builder = {}

	function builder:WriteTo(_sink)
		return self
	end

	function builder:SetMinLogLevel(level)
		minLevel = level
		return self
	end

	function builder:Create()
		return createLogger(nil)
	end

	return builder
end

return Log
