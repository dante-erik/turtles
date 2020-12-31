-- == Movement Constants ==
local FORWARD = 1
local BACK = 2
local UP = 4
local DOWN = 8
local TURN_RIGHT = 16
local TURN_LEFT = 32
-- == Data ==
-- Constants
local SLOT_COUNT = 16
local LABEL = os.getComputerLabel()
local WIRELESS = false
local SERVER_CHANNEL = 65534
local ERROR_SERVER_CHANNEL = 65535
local CHANNEL = nil
-- Mutable Data
local moves = {}
local dt = "right" -- Direction Tangent (right, left)
local dv = "up" -- Direction Vertical (up, down)
local refill_lava = false -- Consume picked up lava
local width, depth, height = 10, 10, 2
-- == Peripherals ==
local modem = nil
local peripherals = peripheral.getNames()
for name = 1, #peripherals, 1 do
    if(peripheral.getType(peripherals[name]) == "modem") then
        modem = peripheral.wrap(peripherals[name])
        WIRELESS = true
        break
    end
end

if(WIRELESS) then
    if(LABEL == "white") then CHANNEL = 0
    elseif(LABEL == "orange") then CHANNEL = 1
    elseif(LABEL == "magenta") then CHANNEL = 2
    elseif(LABEL == "light_blue") then CHANNEL = 3
    elseif(LABEL == "yellow") then CHANNEL = 4
    elseif(LABEL == "lime") then CHANNEL = 5
    elseif(LABEL == "pink") then CHANNEL = 6
    elseif(LABEL == "gray" or LABEL == "grey") then CHANNEL = 7
    elseif(LABEL == "light_gray" or LABEL == "light_grey") then CHANNEL = 8
    elseif(LABEL == "cyan") then CHANNEL = 9
    elseif(LABEL == "purple") then CHANNEL = 10
    elseif(LABEL == "blue") then CHANNEL = 11
    elseif(LABEL == "brown") then CHANNEL = 12
    elseif(LABEL == "green") then CHANNEL = 13
    elseif(LABEL == "red") then CHANNEL = 14
    elseif(LABEL == "black") then CHANNEL = 15
    end

    if(CHANNEL == nil) then
        c = term.getTextColor()
        term.setTextColor(colors.red)
        print("Modem without a label. This robot has no channel!")
        term.setTextColor(c)
        WIRELESS = false
    else
        modem.open(CHANNEL)
    end
end

function transmit(message)
    if(WIRELESS) then
        modem.transmit(SERVER_CHANNEL, CHANNEL, message)
    end
end

function transmitError(message, forward)
    if(WIRELESS) then
        modem.transmit(ERROR_SERVER_CHANNEL, CHANNEL, message)
        if(forward) then
            transmit(message)
        end
    end
end

function get_file_name(file)
    file = file or debug.getinfo(1,'S').source
    return file:match("^@(.+)$")
end

HOLD_ITEMS = {
    "minecraft:coal",
    "minecraft:coal_block",
    "minecraft:bucket"
}

DROPPED_ITEMS = {
    "minecraft:stone",
    "minecraft:dirt",
    "minecraft:cobblestone",
    "minecraft:sand",
    "minecraft:gravel",
    "minecraft:redstone",
    "minecraft:flint",
    "minecraft:clay_ball",
    "railcraft:ore_metal",
    "railcraft:ore_metal_poor",
    "extrautils2:ingredients",
    "chisel:marble2",
    "chisel:limestone2",
    "chisel:basalt2",
--    "minecraft:dye", -- Lapis Lazuli
    "thaumcraft:nugget",
    "thaumcraft:crystal_essence",
    "thermalfoundation:material",
    "projectred-core:resource_item",
    "thaumcraft:ore_cinnabar",
    "deepresonance:resonating_ore",
    "forestry:apatite"
}

function dropItems()
    print("Purging Inventory...")
    for slot = 1, SLOT_COUNT, 1 do
        local item = turtle.getItemDetail(slot)
        if(item ~= nil) then
            for filterIndex = 1, #DROPPED_ITEMS, 1 do
                if(item["name"] == DROPPED_ITEMS[filterIndex]) then
                    print("Dropping - " .. item["name"])
                    turtle.select(slot)
                    turtle.dropDown()
                end
            end
        end
    end
end

function getItemIndex(find_item)
    if(type(find_item) ~= "string") then
        error("Expected string but got " .. type(find_item))
    end
    for slot = 1, SLOT_COUNT, 1 do
        local item = turtle.getItemDetail(slot)
        if(item ~= nil) then
            if(item["name"] == find_item) then
                return slot
            end
        end
    end
    return nil
end

function countAllOf(search_item)
    if(type(search_item) ~= "string") then
        error("Expected string but got " .. type(search_item))
    end
    count = 0
    for slot = 1, SLOT_COUNT, 1 do
        local item = turtle.getItemDetail(slot)
        if(item ~= nil) then
            if(item["name"] == search_item) then
                count += turtle.getItemCount()
            end
        end
    end
    return count
end

function countStoredFuel()
    return countAllOf("minecraft:coal") * 80 + countAllOf("minecraft:coal_block") * 720 + countAllOf("minecraft:lava_bucket") * 1000
end

function coalesce()
    for slot = 1, SLOT_COUNT - 1, 1 do
        local base_item = turtle.getItemDetail(slot)
        if(base_item ~= nil) then
            for i = slot + 1, SLOT_COUNT, 1 do
                local item = turtle.getItemDetail(slot)
                if(item ~= nil and base_item["name"] == item["name"]) then
                    turtle.select(i)
                    turtle.transferTo(slot)
                end
            end
        end
    end
end

function getNumberFreeSlots()
    local freeSlots = 0
    for slot = 1, SLOT_COUNT, 1 do
        local item = turtle.getItemDetail(slot)
        if(item == nil) then
            freeSlots = freeSlots + 1
        end
    end
    return freeSlots
end

function shouldReturnItem(item)
    if(refill_lava and item["name"] == "minecraft:lava_bucket") then
        return false
    end
    for filterIndex = 1, #HOLD_ITEMS, 1 do
        if(item["name"] == HOLD_ITEMS[filterIndex]) then
            return false
        end
    end
    return true
end

function manageInventory(dumpAll)
    transmit("Managing Inventory")
    index = turtle.getSelectedSlot()
    while(index ~= nil) do
        index = getItemIndex("enderstorage:ender_storage")
        if(index == nil) then break end
        digUp()
        dropItems()
        turtle.select(index)
        if(turtle.placeUp()) then
            break
        else
            print("Chest not placed correctly... Trying again")
        end
    end
    local success, data = turtle.inspectUp()
    if(index == nil or (success and data.name ~= "enderstorage:ender_storage")) then
        transmitError("Ender Storage Missing")
        return false
    end
    -- Chest is now deployed
    coalesce()
    for slot = 1, SLOT_COUNT, 1 do
        local item = turtle.getItemDetail(slot)
        if(item ~= nil) then
            if(dumpAll or shouldReturnItem(item)) then
                turtle.select(slot)
                turtle.dropUp()
            elseif not shouldReturnItem(item) and turtle.getItemSpace(slot) <= 0 then
                for i = slot + 1, SLOT_COUNT, 1 do
                    local dump = turtle.getItemDetail(i)
                    if(dump ~= nil and item["name"] == dump["name"]) then
                        turtle.select(i)
                        turtle.dropUp()
                    end
                end
            end
        end
    end
    -- Items are now stored
    turtle.select(1)
    if(getNumberFreeSlots() >= 1) then
        digUp()
    else
        transmitError("Cannot Pick Up Ender Storage, Full Inventory")
        print("Cannot pick up Ender Storage, full inventory")
        return false
    end
    return true
end

function checkFuel()
    if(turtle.getFuelLevel() < 25) then
        -- transmit("Attempting Refuel...")
        print("Attempting Refuel...")
        for slot = 1, SLOT_COUNT, 1 do
            turtle.select(slot)
            if(turtle.refuel(1)) then
                -- transmit("Refuel Success!   Fuel: " .. turtle.getFuelLevel())
                return true
            end
        end
        return false
    else
        return true
    end
end

function digUp()
    local success, data = turtle.inspectUp()
    if(success and data.name == "minecraft:lava" and bucket_index ~= nil and getNumberFreeSlots() > 1) then
        -- transmit("Bucketing Lava Up...")
        turtle.select(bucket_index)
        turtle.placeUp()
        lava_index = getItemIndex("minecraft:lava_bucket")
        if(refill_lava and lava_index and turtle.getFuelLevel() + 1000 < turtle.getFuelLimit()) then
            -- transmit("Consumed newly bucketed lava.   Fuel: " .. turtle.getFuelLevel())
            turtle.select(getItemIndex("minecraft:lava_bucket"))
            turtle.refuel()
            turtle.transferTo(bucket_index)
        end
        bucket_index = getItemIndex("minecraft:bucket")
    end
    local block_above = data.name
    while(turtle.detectUp()) do
        local success, data = turtle.inspectUp()
        if(success) then
            block_above = data.name
        end
        if(block_above == "minecraft:gravel" or block_above == "minecraft:sand") then
            turtle.digUp()
            os.sleep(0.75)
        else
            turtle.digUp()
        end
    end
end

function detectAndDig()
    slot = turtle.getSelectedSlot()
    bucket_index = getItemIndex("minecraft:bucket")
    local success, data = turtle.inspect()
    if(success and data.name == "minecraft:lava" and bucket_index ~= nil and getNumberFreeSlots() > 1) then
        -- transmit("Bucketing Lava...")
        turtle.select(bucket_index)
        turtle.place()
        lava_index = getItemIndex("minecraft:lava_bucket")
        if(refill_lava and lava_index and turtle.getFuelLevel() + 1000 < turtle.getFuelLimit()) then
            -- transmit("Consumed newly bucketed lava.   Fuel: " .. turtle.getFuelLevel())
            turtle.select(lava_index)
            turtle.refuel()
            turtle.transferTo(bucket_index)
        end
        bucket_index = getItemIndex("minecraft:bucket")
    end
    while(turtle.detect()) do
        turtle.dig()
    end
    digUp()
    local success, data = turtle.inspectDown()
    if(success and data.name == "minecraft:lava" and bucket_index ~= nil and getNumberFreeSlots() > 1) then
        -- transmit("Bucketing Lava Down...")
        turtle.select(bucket_index)
        turtle.placeDown()
        lava_index = getItemIndex("minecraft:lava_bucket")
        if(refill_lava and lava_index and turtle.getFuelLevel() + 1000 < turtle.getFuelLimit()) then
            -- transmit("Consumed newly bucketed lava.   Fuel: " .. turtle.getFuelLevel())
            turtle.select(getItemIndex("minecraft:lava_bucket"))
            turtle.refuel()
            turtle.transferTo(bucket_index)
        end
        bucket_index = getItemIndex("minecraft:bucket")
    end
    if(turtle.detectDown()) then
        turtle.digDown()
    end
    turtle.select(slot)
end

function invertMove(move)
    if move == FORWARD or move == UP or move == TURN_RIGHT then
        return move * 2
    elseif move == BACK or move == DOWN or move == TURN_LEFT then
        return move / 2
    end
    return move
end

function stackSmash()
    local i = 1
    while i <= #moves do
        if(moves[i] == invertMove(moves[i + 1])) then
            for j = 1, 2, 1 do
                table.remove(moves, i)
            end
            i = i - (2 - 1)
        end
        if(moves[i] == moves[i+1] and moves[i] == moves[i+2] and moves[i] == moves[i+3] and (moves[i] == TURN_LEFT or moves[i] == TURN_RIGHT)) then
            for j = 1, 4, 1 do
                table.remove(moves, i)
            end
            i = i - (4 - 1)
        end
        i = i + 1
    end
end

function forward(times)
    times = times or 1
    for i = 1, times, 1 do
        if(not checkFuel()) then
            transmitError("Turtle is out of fuel, Powering Down...")
            error("Turtle is out of fuel, Powering Down...")
        end
        if(turtle.forward()) then
            table.insert(moves, FORWARD)
            stackSmash()
        else
            return false
        end
    end
    return true
end

function back(times)
    times = times or 1
    for i = 1, times, 1 do
        if(not checkFuel()) then
            transmitError("Turtle is out of fuel, Powering Down...")
            error("Turtle is out of fuel, Powering Down...")
        end
        if(turtle.back()) then
            table.insert(moves, BACK)
            stackSmash()
        else
            return false
        end
    end
    return true
end

function up(times)
    times = times or 1
    for i = 1, times, 1 do
        if(not checkFuel()) then
            transmitError("Turtle is out of fuel, Powering Down...")
            error("Turtle is out of fuel, Powering Down...")
        end
        if(turtle.up()) then
            table.insert(moves, UP)
            stackSmash()
        else
            return false
        end
    end
    return true
end

function down(times)
    times = times or 1
    for i = 1, times, 1 do
        if(not checkFuel()) then
            transmitError("Turtle is out of fuel, Powering Down...")
            error("Turtle is out of fuel, Powering Down...")
        end
        if(turtle.down()) then
            table.insert(moves, DOWN)
            stackSmash()
        else
            return false
        end
    end
    return true
end

function turnLeft(times)
    times = times or 1
    for i = 1, times, 1 do
        if(not checkFuel()) then
            transmitError("Turtle is out of fuel, Powering Down...")
            error("Turtle is out of fuel, Powering Down...")
        end
        if(turtle.turnLeft()) then
            table.insert(moves, TURN_LEFT)
            stackSmash()
        else
            return false
        end
    end
    return true
end

function turnRight(times)
    times = times or 1
    for i = 1, times, 1 do
        if(not checkFuel()) then
            transmitError("Turtle is out of fuel, Powering Down...")
            error("Turtle is out of fuel, Powering Down...")
        end
        if(turtle.turnRight()) then
            table.insert(moves, TURN_RIGHT)
            stackSmash()
        else
            return false
        end
    end
    return true
end

function leftTurn()
    turnLeft()
    detectAndDig()
    forward()
    turnLeft()
    detectAndDig()
end


function rightTurn()
    turnRight()
    detectAndDig()
    forward()
    turnRight()
    detectAndDig()
end

function flipDirection(logging)
    if(logging == nil) then logging = true end
    if(logging) then
        turnLeft(2)
    else
        turtle.turnLeft()
        turtle.turnLeft()
    end
end

function flipDirectionTangent()
    if(dt == "right") then
        dt = "left"
    elseif(dt == "left") then
        dt = "right"
    end
end

function flipDirectionVertical()
    if(dv == "up") then
        dv = "down"
    elseif(dv == "down") then
        dv = "up"
    end
end

function turnAround()
    if(dt == "right") then
        rightTurn()
    elseif(dt == "left") then
        leftTurn()
    end
    flipDirectionTangent()
end

function riseTier(delta)
    flipDirection()
    delta = delta or 1 -- Default delta is 1
    for step = 1, delta, 1 do
		digUp()
		turtle.digDown()
        if(dv == "up") then
            up()
        elseif(dv == "down") then
            down()
        end
    end
end

function returnToStart()
    flipDirection(false)
    for i = #moves, 1, -1 do
        move = moves[i]
        if move == UP or move == DOWN or move == TURN_LEFT or move == TURN_RIGHT then
            move = invertMove(move)
        end
        if move == FORWARD then
            detectAndDig()
            forward()
        elseif move == BACK then back()
        elseif move == UP then up()
        elseif move == DOWN then down()
        elseif move == TURN_LEFT then turnLeft()
        elseif move == TURN_RIGHT then turnRight()
        end
    end
	flipDirection(false)
end

function start()
    transmit("Begin " .. depth .. "x" .. width .. "x" .. height .. " " .. dv .. " and " .. dt)
    print("Volume: D x W x H = " .. depth .. " x " .. width .. " x " .. height)
    print("Direction: " .. dv .. " and to the " .. dt)
    if(WIRELESS) then
        print("Wireless is Enabled")
    end
    height = math.max(height - 1, 1)
	tier = math.min(height, 2)
	while tier <= height do
        for col = 1, width, 1 do
            for row = 1, depth - 1, 1 do
                if(not checkFuel()) then
                    transmitError("Turtle is out of fuel, Powering Down...")
                    error("Turtle is out of fuel, Powering Down...")
                    return
                end
                if(getNumberFreeSlots() < 1) then
                    -- transmit("Inventory Full, Dropping Items...")
                    coalesce()
                    dropItems()
                    if(getNumberFreeSlots() < 1) then
                        if(not manageInventory()) then
                            transmitError("Turtle cannot find ender chest... Returning to Start")
                            print("Turtle cannot find ender chest...")
                            returnToStart()
                            return
                        end
                    end
                end
                detectAndDig()
                while not forward() do
                    checkFuel()
                    if turtle.detect() then
                        turtle.dig()
                    else
                        turtle.attack()
                    end
                end
                print(string.format("Row: %d   Col: %d   Tier: %d   Fuel: %d", row, col, tier, turtle.getFuelLevel()))
            end
            if(col ~= width) then
                turnAround()
            end
            transmit("Completed Column #" .. col .. "   Fuel: " .. turtle.getFuelLevel() .. "   Completion: " .. 100*col*tier/*width*height .. "%")
        end
        transmit("Completed Layer #" .. tier .. "   Fuel: " .. turtle.getFuelLevel() .. "   Completion: " .. 100*tier/height .. "%")
        if(tier < height) then
            if(tier + 2 < height) then
                tier = tier + 2
                riseTier(3)
			elseif(tier + 1 < height) then
				tier = tier + 1
				riseTier(2)
            else
                riseTier()
            end
        end
        tier = tier + 1
    end
    transmit("Completed All Layers, Returning to Start" .. "   Fuel: " .. turtle.getFuelLevel())
    returnToStart()
    transmit("At Start" .. "   Fuel: " .. turtle.getFuelLevel())
	if(not manageInventory(true)) then
        transmit("Turtle cannot find ender chest, This is a serious issue...")
        print("Turtle cannot find ender chest, This is a serious issue...")
    end
    transmit("End " .. depth .. "x" .. width .. "x" .. height .. " " .. dv .. " and " .. dt)
end

if (#arg >= 3) then
    depth = tonumber(arg[1])
	width = tonumber(arg[2])
    height = tonumber(arg[3])
	for i = 4, #arg, 1 do
    	if arg[i] == "flip" then flipDirection()
        elseif arg[i] == "up" or arg[i] == "down" then dv = arg[i]
        elseif arg[i] == "left" or arg[i] == "right" then dt = arg[i]
        elseif arg[i] == "refill" then refill_lava = true
        else error("Unkown Argument #" .. i .. ": " .. arg[i])
        end
    end
else
    error("Usage: " .. get_file_name() .. " depth width height [left] [right] [up] [down] [flip]\n - left -- robot goes left (overrides right)\n - right -- robot goes right [default] (overrides left)\n - up -- robot goes up [default] (overrides down)\n - down -- robot goes down (overrides up)\n - flip -- robot immediately rotates 180 degrees\n - refill -- robot consumes lava buckets [disabled by default]")
end

start()