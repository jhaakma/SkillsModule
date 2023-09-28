local SkillModifier = require("OtherSkills.components.SkillModifier")
local util = require("OtherSkills.util")
local config = require("OtherSkills.config")
local logger = util.createLogger("Skill")

---@class SkillsModule.Skill.constructorParams
---@field id string The unique ID of the skill
---@field name string The name of the skill
---@field lvlCap? number `Default: 100` The maximum value of the skill
---@field icon? string `Default: "Icons/OtherSkills/default.dds"` The path to the icon of the skill
---@field description? string The description of the skill
---@field specialization? tes3.specialization The specialization of the skill
---@field value? number `Default: 5` The starting value of the skill
---@field active? SkillsModule.Skill.active Whether the skill is active or not
---@field apiVersion? number `Default: 1` The API version of the skill

---@alias SkillsModule.Skill.active
---| "'active'" The skill is active
---| "'inactive'" The skill is inactive

local SPECIALIZATION_MULTI = 1.25
local ALIASES = {
    base = "value"
}
--Keys of values that are stored on player.data
local PERSISTENT_KEYS = {
    value = true,
    progress = true,
    active = true,
}

---@class SkillsModule.Skill.data
---@field value number (Deprecated, use current) The current value of the skill
---@field progress number The current progress of the skill
---@field active SkillsModule.Skill.active Whether the skill is active or not
---@field attribute? tes3.attribute (Deprecated) The attribute of the skill
---@field apiVersion number The API version of the skill

---@class SkillsModule.Skill : SkillsModule.Skill.data
---@field id string The unique ID of the skill
---@field name string The name of the skill
---@field lvlCap number The maximum value of the skill
---@field icon string The path to the icon of the skill
---@field description string The description of the skill
---@field specialization tes3.specialization The specialization of the skill
---@field apiVersion number The API version of the skill
---@field persistentDefaults SkillsModule.Skill.data Data to be added to player.data.otherSkills
---@field private owner? tes3reference The NPC the skill is attached to. Defaults to the player
local Skill = {
    DEFAULT_VALUES = {
        value = 5,
        progress = 0,
        active = "active",
        lvlCap = 100,
        icon = "Icons/OtherSkills/default.dds",
        description = "",
        apiVersion = 1
    },
}

local registeredSkills = {}

---@param e SkillsModule.Skill.constructorParams
---@return SkillsModule.Skill|nil
function Skill:new(e)
    local params = table.copy(e)
    --Fill in defaults
    table.copymissing(params, Skill.DEFAULT_VALUES)
    --Validate params
    logger:assert(type(params) == "table", "Skill:new: data must be a table")
    logger:assert(type(params.id) == "string", "Skill:new: data.id is required")
    logger:assert(type(params.name) == "string", "Skill:new: data.name is required")

    --Data to be added to player.data.otherSkills
    params.persistentDefaults = {}
    for k, v in pairs(params) do
        if PERSISTENT_KEYS[k] then
            params.persistentDefaults[k] = v
        end
    end
    ---@type SkillsModule.Skill
    local skill = setmetatable({}, {
        ---@param tSkill SkillsModule.Skill
        __index = function(tSkill, key)
            --Handle aliases, like using "value" or "base" to get the current value
            if ALIASES[key] then
                key = ALIASES[key]
            end
            if key == "current" then
                return tSkill:getCurrent()
            end
            --Get from class
            if Skill[key] ~= nil then
                return Skill[key]
            end
            --Get from player ref
            if PERSISTENT_KEYS[key] then
                tSkill:initialiseData()
                local v = config.playerData[params.id][key]
                if v ~= nil then return v end
            end
            --get from table
            return params[key]
        end,
        __newindex = function(tSkill, key, val)
            if ALIASES[key] then
                key = ALIASES[key]
            end
            --if "current", then modify base by difference between current and new current
            if key == "current" then
                local current = tSkill:getCurrent()
                local diff = val - current
                tSkill.value = tSkill.value + diff
                return
            end
            if PERSISTENT_KEYS[key] then
                tSkill:initialiseData()
                local skillData = config.playerData[params.id]
                skillData[key] = val
            end
            params[key] = val
            event.trigger("SkillsModule:UpdateSkillsList")
        end,
        __tostring = function (t)
            mwse.log("tostring")
            return string.format("Skill: %s (%s) v%d", t.name, t.id, t.apiVersion)
        end
    })
    registeredSkills[params.id] = skill
    logger:debug("Registered %s", string.format("Skill: %s (%s) v%d", params.name, params.id, params.apiVersion))
    return skill
end

---Get a skill by its ID
---@param id string The unique ID of the skill
---@param owner? tes3reference The owner of the skill, defaults to the player
---@return SkillsModule.Skill|nil
function Skill.get(id, owner)
    local skill = registeredSkills[id]
    Skill.owner = owner
    return skill
end

---Get all registered skills
---@param owner nil|tes3reference
---@return table<string, SkillsModule.Skill>
function Skill.getAll(owner)
    if owner then
        Skill.owner = owner
    end
    return registeredSkills
end


----------------------------------------------
-- Instance methods
----------------------------------------------

-- Getters for private fields

---@return tes3reference
function Skill:getOwner()
    return Skill.owner or tes3.player
end

---@return table<string, SkillsModule.Skill.data>|nil
function Skill:getOwnerData()
    local owner = self:getOwner()
    if not owner then
        logger:error("Tried to access `tes3.player.data.otherSkills` before tes3.player was loaded")
        return
    end
    owner.data.otherSkills = owner.data.otherSkills or {}
    return owner.data.otherSkills
end

function Skill:initialiseData()
    local ownerData = self:getOwnerData()
    if not ownerData then
        return
    end
    if ownerData[self.id] == nil then
        ownerData[self.id] = table.copy(self.persistentDefaults)
    else
        --If a v1 self is upgraded to a v1, scale the progress to the new progress requirements
        local currentApiVersion = ownerData[self.id].apiVersion or 1
        local newApiVersion = self.apiVersion or 1
        if newApiVersion > 1 and currentApiVersion == 1 then
            local currentProgress = ownerData[self.id].progress or 0
            local currentRatio = currentProgress / 100
            local currentSkillLevel = ownerData[self.id].value
            local progressRequirement = (1 + currentSkillLevel) * tes3.findGMST("fMiscSkillBonus").value
            local newProgress = math.floor(progressRequirement * currentRatio)
            ownerData[self.id].progress = newProgress
            ownerData[self.id].apiVersion = newApiVersion
            logger:warn("%s skill has been updated to API version %s, progress has been scaled to %s",
                self.name, newApiVersion, newProgress)
        end
    end
end

--- Calculates the current value of the skill
--- This can also be accessed directly with `skill.current`
function Skill:getCurrent()
    logger:debug("Getting current value of %s skill", self.name)
    --Calculate modifiers and add to base value
    local value = self.value
    logger:debug("base value: %s", value)
    local baseModification = SkillModifier.calculateBaseModification(self.id)
    logger:debug("modification: %s", baseModification)
    local fortifyEffect = SkillModifier.calculateFortifyEffect(self.id)
    logger:debug("fortifyEffect: %s", fortifyEffect)
    local current = value + baseModification + fortifyEffect
    logger:debug("Current: %s", current)
    return math.max(current, 0)
end


---Exercise the skill and level up if applicable
---@param progressAmount number The amount of progress to add to the skill
function Skill:exercise(progressAmount)
    --Add specialization bonus
    if self.specialization == tes3.player.object.class.specialization then
        progressAmount = progressAmount * SPECIALIZATION_MULTI
    end
    --Add progress
    self.progress = self.progress + progressAmount
    --Level up if needed
    if self.progress >= self:getProgressRequirement() then
        self:levelUp()
    end
end

---Level up the skill
---@param numLevels number|nil `Default: 1` The number of levels to level up the skill
function Skill:levelUp(numLevels)
    numLevels = numLevels or 1
    if self.base >= self.lvlCap then
        self.base = self.lvlCap
        self.progress = 0
        return
    end
    self.base = self.base + numLevels
    self.progress = 0
    tes3.playSound{ reference = tes3.player, sound = "skillraise" }
    local message = string.format( tes3.findGMST(tes3.gmst.sNotifyMessage39).value, self.name, self.base )
    tes3.messageBox( message )--"Your %s skill increased to %d."
end

function Skill:setLevel(level)
    self.base = level
end

function Skill:getProgressRequirement()
    if self.apiVersion == 1 then
        -- Legacy calculation had a flat progression rate
        return 100
    end
    if self.apiVersion >= 2 then
        --[[
            New calculation based on vanilla skills,
            progress needed to level up is
            1 + the current skill level
        ]]
        local progressRequirement = (1 + self.base) * tes3.findGMST("fMiscSkillBonus").value
        return math.floor(progressRequirement)
    end
    logger:error("no api version set")
end

function Skill:getProgressAsPercentage()
    local progress = self.progress
    local progressRequirement = self:getProgressRequirement()
    return math.floor((progress / progressRequirement) * 100)
end

-------------------------------------
-- Legacy functions
-------------------------------------

function Skill:levelUpSkill(value)
    self:levelUp(value)
end

function Skill:progressSkill(value)
    self:exercise(value)
end

function Skill:updateSkill(skillVals)
    local validUpdateFields = {
        name = "string",
        lvlCap = "number",
        icon = "string",
        description = "string",
        specialization = "number",
        active = "string",
    }
    for k, v in pairs(skillVals) do
        if validUpdateFields[k] then
            if type(v) == validUpdateFields[k] then
                self[k] = v
            else
                logger:error("Skill:updateSkill: %s must be a %s", k, validUpdateFields[k])
            end
        end
    end
end

return Skill