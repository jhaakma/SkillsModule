--[[
    THIS CLASS IS DEPRECATED
    Use `local SkillsModule = require("OtherSkills")` instead.
]]
--

--Require the new module to ensure any events are triggered
require("OtherSkills")
local common = include("OtherSkills.common")
local config = include("OtherSkills.config")
local Skill = include("OtherSkills.components.Skill")
local util = include("OtherSkills.util")
local logger = util.createLogger("SkillsModule_v1")
local this = {}

this.version = 1.4
function this.updateSkill(id, skillVals)
    local skill = Skill.get(id)
    if skill then
        skill:updateSkill(skillVals)
    else
        logger:error("Skill %s does not exist", id)
    end
end

function this.incrementSkill(id, skillVals)
    skillVals = skillVals or { progress = 10 }
    local skill = Skill.get(id)
    if not skill then
        logger:error("Skill %s does not exist", id)
        return
    end
    if skill.active ~= "active" then
        logger:debug("Skill %s is not active", id)
        return
    end
    if skillVals.value then
        mwse.log("Incrementing by %s", skillVals.value)
        skill:levelUp(skillVals.value)
        mwse.log("New value = %s", skill.value)
    end
    if skillVals.progress then
        skill:exercise(skillVals.progress)
    end
end

---@param id string
---@param owner? tes3reference
function this.getSkill(id, owner)
    return Skill.get(id)
end

---@param id string
---@param skillData SkillsModule.Skill.data
function this.registerSkill(id, skillData)
    if not config.playerData then
        mwse.log("[Skills Module: ERROR] Skills table not loaded - trigger register using event 'OtherSkills:Ready'")
        return
    end
    --exists: set active flag
    local existingSkill = Skill.get(id)
    if existingSkill then
        logger:debug("Skill already exists, setting to active: %s", id)
        existingSkill.active = "active"
        existingSkill.apiVersion = existingSkill.apiVersion or 1
        return existingSkill
    else
        skillData = table.copy(skillData)
        skillData.id = id
        skillData.apiVersion = 1
        local newSkill = Skill:new(skillData)
        logger:debug("Registering skill via legacy API: %s", newSkill)
        return Skill:new(skillData)
    end
end

return this
