local util = require("OtherSkills.util")
local logger = util.createLogger("SkillModifier")

--- This class handles registering and calculating skill modifiers.
--- Modifiers change the base or fortify/drain effect of a skill
--- depending on different criteria, and can be used to implement
--- effects such as fortify skill spells, racial bonuses etc.
---@class SkillsModule.SkillModifier
local SkillModifier = {
    ---@type table<string, table<string, number>>
    classModifiers = {},
    ---@type table<string, table<string, number>>
    raceModifiers = {},
    ---@type table<string, table<string, fun():number|nil>>
    baseModifiers = {},
    ---@type table<string, table<string, fun():number|nil>>
    fortifyEffects = {}
}

--- A base modifier is a modifier that changes the base value of a skill.
---@class SkillsModule.BaseModifier
---@field id string The unique ID of the modifier
---@field skill string The skill id the modifier applies to
---@field getAmount fun():number|nil A function that returns the modifier amount. Return nil when modifier is inactive

--- A fortify effect is a modifier that changes the fortify/drain effect of a skill.
--- The main difference between a base and fortify effect is that a fortify effect
--- will change the color of the skill in the UI to green or red depending on whether
--- the total effect is positive or negative.
---@class SkillsModule.FortifyEffect
---@field id string The unique ID of the modifier
---@field skill string The skill id the modifier applies to
---@field getAmount fun():number|nil A function that returns the modifier amount. Return nil when modifier is inactive

--- A race modifier is a modifier that changes the base value of a skill
--- if the player is of the provided race.
---@class SkillsModule.RaceModifier
---@field skill string The skill id the modifier applies to
---@field race string The class id the modifier applies to
---@field amount number The amount of the modifier

--- A class modifier is a modifier that changes the base value of a skill
--- if the player is of the provided class.
---@class SkillsModule.ClassModifier
---@field skill string The skill id the modifier applies to
---@field class string The class id the modifier applies to
---@field amount number The amount of the modifier

--- Register a base modifier for a skill. Base modifiers have a `getAmount` function which returns the
--- current amount the modifier should apply to the skill's base value, or returns nil when the modifier
--- is inactive.
---@param e SkillsModule.BaseModifier
function SkillModifier.registerBaseModifier(e)
    logger:assert(type(e.id) == "string", "Must provide a modifier id")
    logger:assert(type(e.skill) == "string", "Must provide a skill id")
    logger:assert(type(e.getAmount) == "function", "Must provide a requirements function")
    SkillModifier.baseModifiers[e.skill] = SkillModifier.baseModifiers[e.skill] or {}
    SkillModifier.baseModifiers[e.skill][e.id] = e.getAmount
end

--- Register a Race modifier for a skill. This will modify the base amount of the skill
--- depending on the player's race.
---@param e SkillsModule.RaceModifier
function SkillModifier.registerRaceModifier(e)
    logger:assert(type(e.skill) == "string", "Must provide a skill id")
    logger:assert(type(e.amount) == "number", "Must provide a modifier amount")
    logger:assert(type(e.race) == "string", "Must provide a race id")
    SkillModifier.raceModifiers[e.skill] = SkillModifier.raceModifiers[e.skill] or {}
    local raceId = e.race:lower()
    SkillModifier.raceModifiers[e.skill][raceId] = e.amount
    logger:debug("Registered base modifier for skill %s: %s for race %s",
        e.skill, e.amount, e.race)
end

--- Register a Class modifier for a skill. This will modify the base amount of the skill
--- depending on the player's class.
---@param e SkillsModule.ClassModifier
function SkillModifier.registerClassModifier(e)
    logger:assert(type(e.skill) == "string", "Must provide a skill id")
    logger:assert(type(e.amount) == "number", "Must provide a modifier amount")
    logger:assert(type(e.class) == "string", "Must provide a class id")
    SkillModifier.classModifiers[e.skill] = SkillModifier.classModifiers[e.skill] or {}
    local classId = e.class:lower()
    SkillModifier.classModifiers[e.skill][classId] = e.amount
    logger:debug("Registered base modifier for skill %s: %s for class %s",
        e.skill, e.amount, e.class)
end

--- Register a fortify effect for a skill. Fortify effects have a `getAmount` function which returns the
--- current amount the modifier should apply to the skill's fortify/drain effect, or returns nil when the modifier
--- is inactive.
---@param e SkillsModule.FortifyEffect
function SkillModifier.registerFortifyEffect(e)
    logger:assert(type(e.id) == "string", "Must provide a modifier id")
    logger:assert(type(e.skill) == "string", "Must provide a skill id")
    logger:assert(type(e.getAmount) == "function", "Must provide a requirements function")
    SkillModifier.fortifyEffects[e.skill] = SkillModifier.fortifyEffects[e.skill] or {}
    SkillModifier.fortifyEffects[e.skill][e.id] = e.getAmount
end

--Returns the total amount of base modification for a skill
---@param skillId string
---@return number
function SkillModifier.calculateBaseModification(skillId)
    local modification = 0
    local raceModifiers = SkillModifier.raceModifiers[skillId]
    if raceModifiers then
        local playerRace = tes3.player.object.race.id:lower()
        if raceModifiers[playerRace] then
            modification = modification + raceModifiers[playerRace]
        end
    end
    local classModifiers = SkillModifier.classModifiers[skillId]
    if classModifiers then
        local playerClass = tes3.player.object.class.id:lower()
        if classModifiers[playerClass] then
            modification = modification + classModifiers[playerClass]
        end
    end
    local baseModifiers = SkillModifier.baseModifiers[skillId]
    if baseModifiers then
        for _, getAmount in pairs(baseModifiers) do
            local amount = getAmount()
            if amount then
                modification = modification + amount
            end
        end
    end
    return modification
end

--Calculates the current amount of fortify/drain effect for a skill
---@param skillId string
---@return number
function SkillModifier.calculateFortifyEffect(skillId)
    local modification = 0
    local fortifyEffects = SkillModifier.fortifyEffects[skillId]
    if fortifyEffects then
        for _, getAmount in pairs(fortifyEffects) do
            local amount = getAmount()
            if amount then
                modification = modification + amount
            end
        end
    end
    return modification
end

return SkillModifier