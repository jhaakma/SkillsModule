local util = require("OtherSkills.util")
local logger = util.createLogger("config")

---@class SkillsModule.config
---@field playerData table<string, SkillsModule.Skill.data>
local config = {}

setmetatable(config, {
    __index = function(_, k)
        if k == "playerData" then
            if not tes3.player then
                logger:error("Tried to access `tes3.player.data.otherSkills` before player was loaded")
                return
            end
            tes3.player.data.otherSkills = tes3.player.data.otherSkills or {}
            return tes3.player.data.otherSkills
        end
    end
})
return config