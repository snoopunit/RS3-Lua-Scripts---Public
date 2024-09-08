--[[
    Author:      Klamor
    Version:     0.9
    Release      Date: 09/08/2024
    Script:      Temple of Aminishi

    Release Notes:
    - Version 0.9   :   Open beta testing

    DESCRIPTION:
        :   Completes the entire 1st floor of Temple of Aminishi (ED1) including all available minibosses
        :   ATTENTION:
            :   This script is currently unfinished. Any/all of the features in this script may not work as intended.
                Please report any bugs/issues or unexpected behaviours to the script's thread in Discord.
                Programming Examples: Temple of Aminishi

    TODO:
        :   fix and synchronize leader/player phasing (combatZones)
        :   fix setupPrayer logic after combat is over (miniboss sets prayer type need nil type or unlock SS lol)
        :   add support for banking? can unlock banking inside dungeon for 750k dg tokens
        :   add support for trading food to leader
        :   add support for familiars?
        :   add toggle for reset until #minibosses > var
        :   add grouping/setup support

    SUPPORTED ABILITIES:
        :   'Eat Food'
        :   'Weapon Special Attack'
        :   'Essence of Finality'
        :   'Rejuvenate' w/shield swap
            :   have any 'shield' in your inventory
            :   Put shield on hotkey '1'
            :   Put weapon on hotkey '2'
        :   [WIP] All 'Protection Prayers'
        :   [WIP] 'Soul Split'

    REQUIREMENTS:
        :   UTILS.lua

    SCRIPT SETUP:
        :   Add the names of up to 3 players
            :   Leave p1,p2 = '' if you wish to run solo
                :   Un-tested
            :   Make sure leader is the actual party leader in-game
        :   Modify values in 'Script Setup'
        :   Make sure all 'feature-supported' items/abilities are on your action bars
        :   Start script outside the dungeon with party already set up

]]

------------------------PARTY  SETUP------------------------
local Leader_Name = ""                                      --Name of party leader
local p1, p2 = "", ""                                       --Names of party members
------------------------PARTY  SETUP------------------------
------------------------SCRIPT SETUP------------------------
local Min_Eat_Percent = 60                                  --min HP% to start eating food
local Min_HP_Percent = 20                                   --min HP% to teleport out
local Use_Prayers_Percent = 20                              --min Pray% to activate prayers
local Min_AFK = 30000                                       --Minimum idle time in ms
local Max_AFK = 180000                                      --Maximum idle time in ms
------------------------END    SETUP------------------------

local PRAYER_TO_USE = nil
local currentTarget = nil
local antibans = 0
local dungeonState = 0
local combatState = 0

local API = require("api")
local UTILS = require("utils")

local START = WPOINT:new(0, 0, 0)
local ZONES = {
    FIRST_CHECKPOINT = WPOINT:new(),
    CATHEDRAL_LEADER_CHECKPOINT = WPOINT.new(),
    CATHEDRAL_FOLLOWER_CHECKPOINT = WPOINT.new(),
    FIRST_STAIRS_FIGHT = {
        NAME = "First Stairwell",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    RIGHT_SIDE_FIGHT = {
        NAME = "Right Side",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    LEFT_SIDE_FIGHT = {
        NAME = "Left Side",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    SECOND_STAIRS_FIGHT = {
        NAME = "Bottom Stairwell",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    CATHEDRAL_OUTSIDE = {
        NAME = "Cathedral Outside",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    CATHEDRAL_INSIDE = {             
        NAME = "Cathedral Inside",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    SARKHAN_MINIBOSS = {
        NAME = "Sarkhan Miniboss",
        TOP_LEFT = WPOINT.new(),
        BOT_RIGHT = WPOINT.new()
    },
    XIANG_MINIBOSS = {
        NAME = "Xiang Miniboss",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    OLIVIA_MINIBOSS = {
        NAME = "Olivia Miniboss",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    TRAINING_GROUP = {
        NAME = "Training Group",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    CATHEDRAL_OUTSIDE_TWO = {
        NAME = "Cathedral Outside Back",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    OYU_MINIBOSS = {
        NAME = "Oyu Miniboss",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    KITCHEN_OUTSIDE = {
        NAME = "Outside Kitchen",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    AHOEITU_MINIBOSS = {
        NAME = "Ahoeitu Miniboss",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    KITCHEN_OUTSIDE_TWO = {
        NAME = "Outside Kitchen Far",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    },
    LAST_GROUP = {
        NAME = "Bottom Stairwell Last",
        TOP_LEFT = WPOINT:new(),
        BOT_RIGHT = WPOINT:new()
    }
}
local ENEMIES = {
    Elite_Sotapanna = "Elite Sotapanna",
    Ahoeitu = "Ahoeitu the Chef",
    Olivia = "Olivia the Chronicler",
    Xiang = "Xiang the Water-shaper",
    Sarkhan = "Sarkhan the Serpentspeaker",
    Oyu = "Oyu the Quietest"
}
local TIMERS = {
    Script_Timer = API.SystemTime(),
    AFK_Timer = API.SystemTime()
}
local ITEMS = {
    CHARMS = {
        blue_charm = 12163,
        gold_charm = 12158,
        crimson_charm = 12160,
        green_charm = 12159
    },
    BONES = {
        bones = 17670,
        big_bones = 17674,
        dbones = 17676,
        frost_dbones = 18832,
        hardened_dbones = 35008,
        reinforced_dbones = 35010,
    },
    RUNES = {
        fire_rune = 554,
        water_rune = 555,
        air_rune = 556,
        earth_rune = 557,
        mind_rune = 558,
        body_rune = 559,
        death_rune = 560,
        nature_rune = 561,
        chaos_rune = 562,
        law_rune = 563,
        cosmic_rune = 564,
        blood_rune = 565,
        soul_rune = 566,
        pure_ess = 7936
    },
    RARES = {
        hard_clue_scroll = 42008,
    },
    AMMUNITION = {
        dragon_bolts = 9341,
        royal_bolts = 24336
    },
    MISC = {
        feather = 314,
        blue_dhide = 1751,
        black_dhide = 1747,
        gold = 995
    }
}
local BUFFS = {
    Powder_Of_Burials = 52805,
    Grace_Of_The_Elves = 51490,
    Super_Antifire = 30093,
    Overload = 26093
}
local DEBUFFS = {
    Poison = 14691,
    Elven_Shard = 43358,
    Enh_Excalibur = 14632
}
local PROTECT_MAGIC = {
    names = {"Olivia the Chronicler", "Oyu the Quietest"},
    BUFF_ID = 25959,
    SPELL_NAME = "Protect from Magic"
}
local PROTECT_MELEE = {
    names = {"Ahoeitu the Chef", "Xiang the Water-shaper", "Sarkhan the Serpentspeaker"},
    BUFF_ID = 25961,
    SPELL_NAME = "Protect from Melee"
}
local PROTECT_RANGED = {
    names = {},
    BUFF_ID = 25960,
    SPELL_NAME = "Protect from Ranged"
}
local PROTECT_NECRO = {
    names = {},
    BUFF_ID = nil, -- add this ID or it wont work
    SPELL_NAME = "Protect from Necromancy"
}
local SOUL_SPLIT = {
    names = {},
    BUFF_ID = nil, -- add this ID or it wont work
    SPELL_NAME = "Soul split"
}   

--UTILITIES
function terminate()
    print("Shutting down...")
    API.Write_LoopyLoop(false)
end
function Check_Timer(int)
    return (API.SystemTime() - int)
end
function antiban()
    local elapsedTime = Check_Timer(TIMERS.AFK_Timer)
    local afkThreshold = math.random(Min_AFK, Max_AFK)
    if elapsedTime > afkThreshold then
        antibans = antibans + 1
        local eTime = tostring(math.floor(Check_Timer(TIMERS.AFK_Timer)/1000).."s")       
        local action = math.random(1, 7)
        if action == 1 then API.PIdle1()
        elseif action == 2 then API.PIdle2()
        elseif action == 3 then API.PIdle22()
        elseif action == 4 then API.KeyboardPress('w', 50, 250)
        elseif action == 5 then API.KeyboardPress('a', 50, 250)
        elseif action == 6 then API.KeyboardPress('s', 50, 250)
        elseif action == 7 then API.KeyboardPress('d', 50, 250)
        end
        TIMERS.AFK_Timer = API.SystemTime()
    end
end
function hasBuff(buff)
    if API.Buffbar_GetIDstatus(buff, false).id == 0 then
        return false
    else
        return true
    end
end
function hasDeBuff(debuff)
    if API.DeBuffbar_GetIDstatus(debuff, false).id == 0 then
        return false
    else
        return true
    end
end
function hasItem(item, count)
    invitems = API.InvItemcount_String()
    if count then return invitems end
    if invitems > 0 then
        return true
    else
        return false
    end
end
function getEnemies(names, size)
    local NPCs = {}
    if names then
        NPCs = API.ReadAllObjectsArray({1}, {-1}, names)
    else
        NPCs = API.ReadAllObjectsArray({1}, {-1}, {})
    end
    if size then
        return #NPCs    
    else
        return NPCs
    end
end
function findLeader(return_obj)
    local obj = API.ReadAllObjectsArray({2}, {1}, {Leader_Name})
    if obj == nil then
        return false
    end
    if #obj == 1 then
        if return_obj then
            return obj[1]
        end
        return true
    else
        return false
    end
end
function PartyInRange(maxDistance)
    local players = API.ReadAllObjectsArray({2}, {1}, {}) 
    local playersToFind = 0
    if p1 ~= "" then
        playersToFind = playersToFind + 1
    end
    if p2 ~= "" then
        playersToFind = playersToFind + 1
    end
    if playersToFind == 0 then
        return true
    end
    if #players > 0 then
        for _, player in ipairs(players) do
            if player.Name == p1 or player.Name == p2 or player.Name == Leader_Name then
                if player.Distance > maxDistance then
                    return false
                end
            end
        end
    end
    return true
end
function EnemiesWithinLocation(enemy, location, return_table)
    print("Searching for enemies: "..location.NAME)
    local topLeft = location.TOP_LEFT
    local botRight = location.BOT_RIGHT
    local NPCs = getEnemies({enemy})
    local enemies = {}
    if #NPCs > 0 then
        for i = 1, #NPCs do
            local objectPosition = NPCs[i].Tile_XYZ
            if objectPosition.x >= topLeft.x and objectPosition.x <= botRight.x and
            objectPosition.y <= topLeft.y and objectPosition.y >= botRight.y then
                table.insert(enemies, NPCs[i])
            end
        end
    end
    table.sort(enemies, function(a, b)
        return a.Distance < b.Distance
    end)
    if return_table then
        return enemies
    else
        if #enemies > 0 then
            print("Found Enemies: "..tostring(#enemies))
        end
        return #enemies
    end
end
function findEnemyNearLeader()
    local leader = findLeader(true)
    local leaderX, leaderY = leader.Tile_XYZ.x, leader.Tile_XYZ.y
    
    local minDistanceSquared = math.huge
    local closestNPC = nil

    local validNames = {
        "Elite Sotapanna",
        "Ahoeitu the Chef",
        "Olivia the Chronicler",
        "Xiang the Water-shaper",
        "Sarkhan the Serpentspeaker",
        "Oyu the Quietest"
    }

    local NPCs = getEnemies(validNames)

    for i = 1, #NPCs do
        local npc = NPCs[i]
        local action = npc.Action
        local life = npc.Life
        local lifeToCheck = 15000
        if not currentTarget == ENEMIES.Elite_Sotapanna then
            lifeToCheck = 100000
        end
        local dx = leaderX - npc.Tile_XYZ.x
        local dy = leaderY - npc.Tile_XYZ.y
        local distanceSquared = dx * dx + dy * dy
        if action == "Attack" and life < lifeToCheck then 
            if distanceSquared < minDistanceSquared then
                minDistanceSquared = distanceSquared
                if distanceSquared <= 100 then
                    closestNPC = npc
                end
            end
        end
    end


    if closestNPC then
        API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, closestNPC)
    end

    API.RandomSleep2(600, 50, 600)

    if API.IsTargeting() then      
        return true
    else
        return false
    end 

end
function dialogText()
    local dialogInterface = API.ScanForInterfaceTest2Get(false, { { 1188, 5, -1, -1, 0 }, { 1188, 3, -1, 5, 0 }, { 1188, 3, 14, 3, 0 } })

    if #dialogInterface > 0 and #dialogInterface[1].textids > 0 then
        return dialogInterface[1].textids
    end

    return false
end
--UTILITIES

--ABILITIES
function activateAbility(name)
    ---MUST BE ON ACTIONBARS 
    API.DoAction_Ability(name, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(600, 50, 300)
end
function specialAttack()
    if UTILS.canUseSkill("Weapon Special Attack") then
        activateAbility("Weapon Special Attack")
        API.RandomSleep2(600, 0, 600)    
    end
end
function essenceOfFinality()
    if UTILS.canUseSkill("Essence of Finality") then
        activateAbility("Essence of Finality")
        API.RandomSleep2(600, 0, 600)    
    end
end
function rejuvenate()
    if  (API.GetAddreline_() < 94) or (API.GetHPrecent() > 80) or not (hasItem("shield", true) >= 1) or hasDeBuff(DEBUFFS.Enh_Excalibur) then
        return
    end
    local startHP = API.GetHPrecent()
    API.KeyboardPress('1', 50, 250)
    API.RandomSleep2(600, 0, 600)  
    if UTILS.canUseSkill("Rejuvenate") then
        activateAbility("Rejuvenate")
        API.RandomSleep2(600, 0, 600)
    end
    local skillTimer = API.SystemTime()
    while Check_Timer(skillTimer) < 10000 do
        API.RandomSleep2(600, 0, 600)
    end
    API.KeyboardPress('2', 50, 250)
    API.RandomSleep2(600, 0, 600)
end
--ABILITIES

--PLAYERCHECKS
function buffCheck()    
    if API.InvItemcount_String("Ancient elven ritual shard") > 0 then
        if not hasDeBuff(DEBUFFS.Elven_Shard) and (API.GetPrayPrecent() <= 63) then
            --API.DoAction_Interface(0x2e,0xa95e,1,1670,110,-1,API.OFF_ACT_GeneralInterface_route)
            activateAbility("Ancient elven ritual shard")
            API.RandomSleep2(600, 50, 300)
        end 
    end
    if API.InvItemcount_String("Enhanced Excalibur") > 0 then
        if not hasDeBuff(DEBUFFS.Enh_Excalibur) and (API.GetHPrecent() <= 80) then
            activateAbility("Enhanced Excalibur")
            API.RandomSleep2(600, 50, 300)
        end 
    end
    if API.InvItemcount_String("Overload") > 0 then
        if not hasBuff(BUFFS.Overload) then
            print("Using Overloads")
            activateAbility("Overload potion")
            API.RandomSleep2(600, 50, 300)
        end
    end 
end
function setupPrayers()
    if currentTarget == nil then
        return false
    else
        if UTILS.canUseSkill(PROTECT_MAGIC.SPELL_NAME) then
            for _, name in ipairs(PROTECT_MAGIC.names) do
                if name == currentTarget then
                    PRAYER_TO_USE = PROTECT_MAGIC
                    print("Using prayers: "..PROTECT_MAGIC.SPELL_NAME)
                    return true
                end
            end
        else 
        end
        if UTILS.canUseSkill(PROTECT_MELEE.SPELL_NAME) then
            for _, name in ipairs(PROTECT_MELEE.names) do
                if name == currentTarget then
                    PRAYER_TO_USE = PROTECT_MELEE
                    print("Using prayers: "..PROTECT_MELEE.SPELL_NAME)
                    return true
                end
            end
        else
        end
        if UTILS.canUseSkill(PROTECT_RANGED.SPELL_NAME) then
            for _, name in ipairs(PROTECT_RANGED.names) do
                if name == currentTarget then
                    PRAYER_TO_USE = PROTECT_RANGED
                    print("Using prayers: "..PROTECT_RANGED.SPELL_NAME)
                    return true
                end
            end
        else
        end
        if UTILS.canUseSkill(PROTECT_NECRO.SPELL_NAME) then
            for _, name in ipairs(PROTECT_NECRO.names) do
                if name == currentTarget then
                    PRAYER_TO_USE = PROTECT_NECRO
                    print("Using prayers: "..PROTECT_NECRO.SPELL_NAME)
                    return true
                end
            end
        else
        end
        if UTILS.canUseSkill(SOUL_SPLIT.SPELL_NAME) then
            PRAYER_TO_USE = SOUL_SPLIT
            print("Using prayers: "..SOUL_SPLIT.SPELL_NAME)
            return true
        else
        end
    end
    PRAYER_TO_USE = nil
    return false
end
function prayerCheck()
    if PRAYER_TO_USE == nil then
        if hasBuff(PROTECT_MAGIC.BUFF_ID) then
            activateAbility(PROTECT_MAGIC.SPELL_NAME)
            API.RandomSleep2(800, 50, 300)    
        elseif hasBuff(PROTECT_MELEE.BUFF_ID) then
            activateAbility(PROTECT_MELEE.SPELL_NAME)
            API.RandomSleep2(800, 50, 300)
        elseif hasBuff(PROTECT_RANGED.BUFF_ID) then
            activateAbility(PROTECT_RANGED.SPELL_NAME)
            API.RandomSleep2(800, 50, 300)
        elseif hasBuff(PROTECT_NECRO.BUFF_ID) then
            activateAbility(PROTECT_NECRO.SPELL_NAME)
            API.RandomSleep2(800, 50, 300)
        elseif hasBuff(SOUL_SPLIT.BUFF_ID) then
            activateAbility(SOUL_SPLIT.SPELL_NAME)
            API.RandomSleep2(800, 50, 300)  
        end
        return
    end
    if API.IsTargeting() and not hasBuff(PRAYER_TO_USE.BUFF_ID) and (API.GetPrayPrecent() > Use_Prayers_Percent) then
        print("In combat! Enabling protection prayers")
        activateAbility(PRAYER_TO_USE.SPELL_NAME)
        API.RandomSleep2(800, 50, 300)
    elseif (API.LocalPlayer_IsInCombat_() and  not API.IsTargeting()) and hasBuff(PRAYER_TO_USE.BUFF_ID) then
        print("In combat w/o target! Disabling protection prayers")
        activateAbility(PRAYER_TO_USE.SPELL_NAME)
        API.RandomSleep2(800, 50, 300)
    elseif not API.LocalPlayer_IsInCombat_() and hasBuff(PRAYER_TO_USE.BUFF_ID) then
        print("Out of Combat! Disabling protection prayers")
        activateAbility(PRAYER_TO_USE.SPELL_NAME)
        API.RandomSleep2(800, 50, 300)    
    end
end
function healthCheck()
    if API.GetHPrecent() < Min_Eat_Percent then
        if UTILS.canUseSkill("Eat Food") then
            print("Low HP! Eating Food!")
            activateAbility("Eat Food")
            API.RandomSleep2(600, 50, 300)
            if API.GetHPrecent() > Min_Eat_Percent then
                return true
            end
        else
            print("Can't use 'Eat Food' ability")
        end
    end
end
function chargePackCheck()
    local chatTexts = API.GatherEvents_chat_check()
    for _, v in ipairs(chatTexts) do
        if (string.find(v.text, "Your charge pack has run out of power")) then
            print("Charge pack is empty!")
            emergencyTele()
            terminate()
            return false
        end
    end
    return true
end
function preCombatChecks()
    setupPrayers()
    chargePackCheck()
end
function combatChecks()
    buffCheck()
    prayerCheck()
    healthCheck()
    specialAttack()
    essenceOfFinality()
    rejuvenate()
end
function doCombat()
    while API.IsTargeting() do
        combatChecks()
        antiban()
        API.RandomSleep2(600, 0, 250)
    end    
end
--PLAYERCHECKS

--ZONE LOGIC
function inOrOut()
    local doorID = 111710
    local templeDoorID = 103952

    local door = API.ReadAllObjectsArray({12}, {doorID}, {})
    if #door > 0 then
        print("inside")
        return "inside"
    end
    local templeDoor = API.ReadAllObjectsArray({12}, {templeDoorID}, {"Temple of Aminishi"})
    if #templeDoor > 0 then
        print("outside")
        return "outside"
    end
end
function resetMenu()
    local key = ''
    while API.Check_Dialog_Open() do
        if dialogText() == "Discard the progress you made with your last group?" then
            key = tostring(tonumber(API.Dialog_Option("Yes.")))  
        end
        if dialogText() == "Do you want to continue from where you left off?" then
            key = tostring(tonumber(API.Dialog_Option("No.")))  
        end
        if dialogText() == "Would you like to enter The Temple of Aminishi?" then
            key = tostring(tonumber(API.Dialog_Option("Normal mode")))  
        end
        API.KeyboardPress(key, 50, 250)
        API.RandomSleep2(600, 0, 250) 
    end    
end
function waitForParty()
    local exitTimer = API.SystemTime()
    while not PartyInRange(0) do
        if Check_Timer(exitTimer) > 30000 then
            print("Didn't find party after 30s!")
            terminate()
            return
        end
        if API.GetLocalPlayerName() == p1 or API.GetLocalPlayerName() == p2 then
            local leader = findLeader(true)
            if leader.Distance > 0 then
                print("Moving to leader")
                API.DoAction_WalkerF(leader.Tile_XYZ)
                API.RandomSleep2(650, 0, 250)
            end
        end
        antiban()
        API.RandomSleep2(600, 0, 250)
    end
end
function enterDungeon()
    while not PartyInRange(5) do
        API.RandomSleep2(600, 0, 600)
    end
    if API.GetLocalPlayerName() == Leader_Name then
        API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ templeDoorID },50)
        while not API.Check_Dialog_Open() do API.RandomSleep2(50, 0, 50) end
        resetMenu()
    else 
        while findLeader() do API.RandomSleep2(600, 0, 600) end
        API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ templeDoorID },50)
        API.RandomSleep2(600, 0, 600)
    end   
end
function setupCoordOffset()
    API.RandomSleep2(1800, 0, 250)
    local coords = API.PlayerCoord()  

    START.x = coords.x
    START.y = coords.y 
   
    ZONES.FIRST_CHECKPOINT = WPOINT.new(START.x + 20, START.y + 4, 0)
    ZONES.FIRST_STAIRS_FIGHT.TOP_LEFT = WPOINT:new(START.x + 24, START.y + 8, 0)
    ZONES.FIRST_STAIRS_FIGHT.BOT_RIGHT = WPOINT:new(START.x + 30, START.y, 0)
    ZONES.RIGHT_SIDE_FIGHT.TOP_LEFT = WPOINT:new(START.x + 25, START.y - 0, 0)
    ZONES.RIGHT_SIDE_FIGHT.BOT_RIGHT = WPOINT:new(START.x + 40, START.y - 11, 0)
    ZONES.LEFT_SIDE_FIGHT.TOP_LEFT = WPOINT:new(START.x + 26, START.y + 19, 0)
    ZONES.LEFT_SIDE_FIGHT.BOT_RIGHT = WPOINT:new(START.x + 40, START.y + 12, 0)
    ZONES.SECOND_STAIRS_FIGHT.TOP_LEFT = WPOINT:new(START.x + 48, START.y + 14, 0)
    ZONES.SECOND_STAIRS_FIGHT.BOT_RIGHT = WPOINT:new(START.x + 57, START.y + 2, 0)
    ZONES.CATHEDRAL_OUTSIDE.TOP_LEFT = WPOINT:new(START.x + 62, START.y + 19, 0)
    ZONES.CATHEDRAL_OUTSIDE.BOT_RIGHT = WPOINT:new(START.x + 76, START.y + 11, 0)
    ZONES.CATHEDRAL_LEADER_CHECKPOINT = WPOINT.new(START.x + 63, START.y + 26, 0)
    ZONES.CATHEDRAL_FOLLOWER_CHECKPOINT = WPOINT.new(START.x + 60, START.y + 26, 0)
    ZONES.CATHEDRAL_INSIDE.TOP_LEFT = WPOINT.new(START.x + 58, START.y + 36, 0)
    ZONES.CATHEDRAL_INSIDE.BOT_RIGHT = WPOINT.new(START.x + 75, START.y + 24, 0)
    ZONES.SARKHAN_MINIBOSS.TOP_LEFT = WPOINT.new(START.x + 63, START.y + 43, 0)
    ZONES.SARKHAN_MINIBOSS.BOT_RIGHT = WPOINT.new(START.x +70, START.y + 39, 0)
    ZONES.XIANG_MINIBOSS.TOP_LEFT = WPOINT:new(START.x + 81, START.y + 10, 0)
    ZONES.XIANG_MINIBOSS.BOT_RIGHT = WPOINT:new(START.x + 85, START.y + 7, 0)
    ZONES.OLIVIA_MINIBOSS.TOP_LEFT = WPOINT:new(START.x + 94, START.y + 9, 0)
    ZONES.OLIVIA_MINIBOSS.BOT_RIGHT = WPOINT:new(START.x + 101, START.y - 1, 0)
    ZONES.TRAINING_GROUP.TOP_LEFT = WPOINT:new(START.x + 80, START.y + 27, 0)
    ZONES.TRAINING_GROUP.BOT_RIGHT = WPOINT:new(START.x + 98, START.y + 8, 0)
    ZONES.CATHEDRAL_OUTSIDE_TWO.TOP_LEFT = WPOINT:new(START.x + 77, START.y + 35, 0)
    ZONES.CATHEDRAL_OUTSIDE_TWO.BOT_RIGHT = WPOINT:new(START.x + 89, START.y + 25, 0)
    ZONES.OYU_MINIBOSS.TOP_LEFT = WPOINT:new(START.x + 90, START.y + 37, 0)
    ZONES.OYU_MINIBOSS.BOT_RIGHT = WPOINT:new(START.x + 97, START.y + 33, 0)
    ZONES.KITCHEN_OUTSIDE.TOP_LEFT = WPOINT:new(START.x + 69, START.y, 0)
    ZONES.KITCHEN_OUTSIDE.BOT_RIGHT = WPOINT:new(START.x + 93, START.y - 11, 0)
    ZONES.AHOEITU_MINIBOSS.TOP_LEFT = WPOINT:new(START.x + 92, START.y - 16, 0)
    ZONES.AHOEITU_MINIBOSS.BOT_RIGHT = WPOINT:new(START.x + 104, START.y - 24, 0)
    ZONES.KITCHEN_OUTSIDE_TWO.TOP_LEFT = WPOINT:new(START.x + 63, START.y - 11, 0)
    ZONES.KITCHEN_OUTSIDE_TWO.BOT_RIGHT = WPOINT:new(START.x + 69, START.y - 16, 0)
    ZONES.LAST_GROUP.TOP_LEFT = WPOINT:new(START.x + 48, START.y + 1, 0)
    ZONES.LAST_GROUP.BOT_RIGHT = WPOINT:new(START.x + 61, START.y - 5, 0)

end
function dungeonStart()
    API.DoAction_WalkerW(ZONES.FIRST_CHECKPOINT)
    API.RandomSleep2(1200, 0, 250)
    while API.ReadPlayerMovin2() do
        antiban()
        API.RandomSleep2(600, 0, 250)
    end
    waitForParty()
    local exitTimer = API.SystemTime()
    while EnemiesWithinLocation({}, ZONES.FIRST_STAIRS_FIGHT, false) < 3 do
        if Check_Timer(exitTimer) > 45000 then
            print("Didn't find the enemies in 45s!")
            terminate()
            return
        end
        antiban()
        API.RandomSleep2(600, 0, 250)
    end
end
function movetoCathedral()
    if API.GetLocalPlayerName() == Leader_Name then
        API.DoAction_WalkerW(ZONES.CATHEDRAL_LEADER_CHECKPOINT)  
    else
        API.DoAction_WalkerW(ZONES.CATHEDRAL_FOLLOWER_CHECKPOINT)
    end
    API.RandomSleep2(1200, 0, 250)
    while API.ReadPlayerMovin2() do
        antiban()
        API.RandomSleep2(600, 0, 250)
    end
end
function combatZone(enemy, zone)
    print("Starting zone: "..zone.NAME)
    currentTarget = enemy
    currentZone = zone.NAME
    preCombatChecks()
    if API.GetLocalPlayerName() == Leader_Name then
        while EnemiesWithinLocation(currentTarget, zone) > 0 do
            local npcsToFight = EnemiesWithinLocation(currentTarget, zone, true)
            print("Enemies to fight: "..tostring(#npcsToFight))
            for x = 1, #npcsToFight do
                if npcsToFight[x].Life > 0 then
                    API.DoAction_NPC__Direct(0x2a, API.OFF_ACT_AttackNPC_route, npcsToFight[x])
                    API.RandomSleep2(600, 0, 250)
                    doCombat()
                end  
            end
        end
        while API.LocalPlayer_IsInCombat_() do
            doCombat()
        end
    else
        local combatTimer = API.SystemTime()
        
        while not API.IsInCombat_(Leader_Name) do
            if API.IsInCombat_(Leader_Name) then 
                break
            end
            print("Waiting for leader to enter combat...")
            local elapsedTime = Check_Timer(combatTimer)
            if (elapsedTime > 30000) then
                print("Couldn't find leader in combat!")
                terminate()
                return    
            end
            local leader = findLeader(true)
            if leader.Distance > 5 then
                print("Moving to leader")
                API.DoAction_WalkerF(leader.Tile_XYZ)
                API.RandomSleep2(650, 0, 250)
            end
        end   
        while API.IsInCombat_(Leader_Name) do
            print(Leader_Name.." in combat!")
            
            if findEnemyNearLeader() then
                print("Fighting: "..currentTarget)
                doCombat()
            end
            local leader = findLeader(true)
            if leader.Distance > 5 then
                print("Moving to leader")
                API.DoAction_WalkerF(leader.Tile_XYZ)
                API.RandomSleep2(650, 0, 250)
            end
            print("Couldn't find any injured enemies with 10 tiles of leader!")
            API.RandomSleep2(600, 0, 250)
            if EnemiesWithinLocation(currentTarget, zone) == 0 then
                break
            end
        end
    end

    waitForParty()

    if EnemiesWithinLocation(currentTarget, zone) == 0 then
        combatState = combatState + 1
    end
end
function exitDungeon()
    local offset = math.random(-2.2)
    local randomCoords = WPOINT:new(START.x + offset, START.y + offset,0)
    API.DoAction_WalkerW(randomCoords)
    waitForParty()
    local door = API.ReadAllObjectsArray({12}, {doorID}, {})
    while door.Distance > 1 do
        if door.Distance < 10 and PartyInRange(4) then break end
        antiban()
        API.RandomSleep2(600, 0, 250)
    end
    API.DoAction_Object1(0x39,API.OFF_ACT_GeneralObject_route0,{ doorID },50)
    while not inOrOut() == "outside" do
        API.RandomSleep2(600, 0, 250)
    end  
end
function doDungeon()
    if combatState == 0 then
        if dungeonState == 0 then
            if not inOrOut() == "outside" then
                print("Move to the dungeon entrance before starting the script!")
                terminate()
                return
            end
            enterDungeon()
            API.RandomSleep2(1800, 0, 250)
            dungeonState = 1   
        elseif dungeonState == 1 then 
            if not inOrOut() == "inside" then
                print("Something's wrong. We're not inside the dungeon after enterDungeon()")
                terminate()
                return
            else
                setupCoordOffset()
                dungeonState = 2
            end
        elseif dungeonState == 2 then
            dungeonStart()
            combatState = 1
            dungeonState = 3
        end    
    elseif combatState == 1 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.FIRST_STAIRS_FIGHT)
    elseif combatState == 2 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.RIGHT_SIDE_FIGHT)
    elseif combatState == 3 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.LEFT_SIDE_FIGHT)
    elseif combatState == 4 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.SECOND_STAIRS_FIGHT)
    elseif combatState == 5 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.CATHEDRAL_OUTSIDE)
    elseif combatState == 6 then
        movetoCathedral()
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.CATHEDRAL_INSIDE)
    elseif combatState == 7 then
        combatZone(ENEMIES.Sarkhan, ZONES.SARKHAN_MINIBOSS)
    elseif combatState == 8 then
        combatZone(ENEMIES.Xiang, ZONES.XIANG_MINIBOSS)
    elseif combatState == 9 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.TRAINING_GROUP)
    elseif combatState == 10 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.CATHEDRAL_OUTSIDE_TWO)
    elseif combatState == 11 then
        combatZone(ENEMIES.Oyu, ZONES.OYU_MINIBOSS)
    elseif combatState == 12 then
        combatZone(ENEMIES.Olivia, ZONES.OLIVIA_MINIBOSS)
    elseif combatState == 13 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.KITCHEN_OUTSIDE)
    elseif combatState == 14 then
        combatZone(ENEMIES.Ahoeitu, ZONES.AHOEITU_MINIBOSS)
    elseif combatState == 15 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.KITCHEN_OUTSIDE_TWO)
    elseif combatState == 16 then
        combatZone(ENEMIES.Elite_Sotapanna, ZONES.LAST_GROUP)
    elseif combatState == 17 then
        exitDungeon()
        combatState = 0
        dungeonState = 0
    end    
end
--ZONE LOGIC

--WORKSPACE--
function miniBossCount()
    local miniBoss_Names = {
        "Ahoeitu the Chef",
        "Olivia the Chronicler",
        "Xiang the Water-shaper",
        "Sarkhan the Serpentspeaker",
        "Oyu the Quietest"
    }
    local miniBosses = getEnemies(miniBoss_Names)
    if #miniBosses > 0 then
        print("Mini Bosses:"..tostring(#miniBosses))
        for k, v in pairs(miniBosses) do
            print("Name:"..v.Name.." ID:"..v.Id)
            end
        return #miniBosses
    end
end

--WORKSPACE--

--main loop
API.Write_LoopyLoop(true)
API.SetDrawLogs(true)
API.SetDrawTrackedSkills(true)

while(API.Read_LoopyLoop())
do-----------------------------------------------------------------------------------
   
    ----DEBUG----
    local debug = {
        {"Script","Debug"},
        {"Dungeon_State:", tostring(dungeonState)},
        {"Combat_State:", tostring(combatState)},
        {"Prayer_To_Use:", PRAYER_TO_USE.SPELL_NAME},
        {"Current_Target:", currentTarget}
        }
        API.DrawTable(debug)
    ----DEBUG----
   doDungeon() 

end----------------------------------------------------------------------------------
