-- == Data ==
-- Constants
local SERVER_CHANNEL = 65534
local ERROR_SERVER_CHANNEL = 65535
local DEFAULT_BACKGROUND = colors.black
local DEFAULT_TEXT = colors.white
-- == Peripherals ==
local modem = nil
local peripherals = peripheral.getNames()
for name = 1, #peripherals, 1 do
    if(peripheral.getType(peripherals[name]) == "modem") then
        modem = peripheral.wrap(peripherals[name])
        break
    end
end

function resetColor()
    term.setTextColor(DEFAULT_TEXT)
    term.setBackgroundColor(DEFAULT_BACKGROUND)
end

function getName(channel_id)
    if(channel_id == 0) then
        return "White"
    elseif(channel_id == 1) then
        return "Orange"
    elseif(channel_id == 2) then
        return "Magenta"
    elseif(channel_id == 3) then
        return "Light Blue"
    elseif(channel_id == 4) then
        return "Yellow"
    elseif(channel_id == 5) then
        return "Lime"
    elseif(channel_id == 6) then
        return "Pink"
    elseif(channel_id == 7) then
        return "Gray"
    elseif(channel_id == 8) then
        return "Light Gray"
    elseif(channel_id == 9) then
        return "Cyan"
    elseif(channel_id == 10) then
        return "Purple"
    elseif(channel_id == 11) then
        return "Blue"
    elseif(channel_id == 12) then
        return "Brown"
    elseif(channel_id == 13) then
        return "Green"
    elseif(channel_id == 14) then
        return "Red"
    elseif(channel_id == 15) then
        return "Black"
    end
end

function setColor(channel_id)
    if(channel_id == 0) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.white)
    elseif(channel_id == 1) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.orange)
    elseif(channel_id == 2) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.magenta)
    elseif(channel_id == 3) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.lightBlue)
    elseif(channel_id == 4) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.yellow)
    elseif(channel_id == 5) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.lime)
    elseif(channel_id == 6) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.pink)
    elseif(channel_id == 7) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.gray)
    elseif(channel_id == 8) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.lightGray)
    elseif(channel_id == 9) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.cyan)
    elseif(channel_id == 10) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.purple)
    elseif(channel_id == 11) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.blue)
    elseif(channel_id == 12) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.brown)
    elseif(channel_id == 13) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.green)
    elseif(channel_id == 14) then
        term.setTextColor(colors.black)
        term.setBackgroundColor(colors.red)
    elseif(channel_id == 15) then
        term.setTextColor(colors.white)
        term.setBackgroundColor(colors.black)
    end
end

function handleRequests()
    while(true) do
        local event, modemSide, senderChannel, replyChannel, message, senderDistance = os.pullEvent("modem_message")
        setColor(replyChannel)
        io.write(message)
        resetColor()
        io.write("\n")
    end
end

function start()
    if(modem == nil) then
        error("Error, this program requires a Modem!")
    end
    modem.open(ERROR_SERVER_CHANNEL)
    term.setTextColor(colors.green)
    print("Awake and Listening on Port " .. ERROR_SERVER_CHANNEL)
    handleRequests()
end

start()