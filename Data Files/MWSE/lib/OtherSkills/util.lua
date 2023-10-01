--Provides utility functions for the SkillsModule
---@class SkillsModule.Util
local util = {}

local MWSELogger = require("logging.logger")
---@type table<string, mwseLogger>
util.loggers = {}
function util.createLogger(serviceName)
    local logger = MWSELogger.new{
        name = string.format("Skills Module - %s", serviceName),
        logLevel = "DEBUG",
        includeTimestamp = true,
    }
    util.loggers[serviceName] = logger
    return logger
end
local logger = util.createLogger("common")

return util