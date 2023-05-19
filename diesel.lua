print("Starting Diesel Control v3.5\n")
--End config

--Constants
local component = require("component")
local computer = require("computer")
local event = require("event")
local diesel = component.ie_diesel_generator
local gpu = component.gpu
local rs = component.redstone
 --Variables
local dogen = (require("shell").parse(...)[1]) == "gen"
if dogen then print("Generator enabled") end


--Enable computer control of the generator.
if dogen then
    diesel.enableComputerControl(true)
    diesel.setEnabled(false)
end

local function display(str)
    local x = gpu.getViewport() - (string.len(str) - 1)
    gpu.set(x, 1, str)
end

local function getCaps()
    --Reset on every read
    local totalMax = 0
    local total = 0
    --Read every capacitor's max charge, and it's charge
    for addr, typ in component.list("v_capacitor") do
        totalMax = totalMax + component.invoke(addr, "getMaxEnergyStored")
        total = total + component.invoke(addr, "getEnergyStored")
    end
    if totalMax == 0 then error("no capacitors :(") end
    --Return the charge level in percent form.
    return math.ceil((total / totalMax) * 100)
end



local function getTank()
    local raw = diesel.getTankInfo()
    local out = {}
    out["percent"] = math.ceil((raw["amount"] / raw["capacity"]) * 100)
    out["type"] = raw["label"]
    return out
end
local cooldown = 0

local function run()
    if math.ceil(computer.energy() / computer.maxEnergy()*100) <= 90 and computer.uptime() + 5 > cooldown then
        rs.setOutput(1, 15)
        os.sleep(0.5)
        rs.setOutput(1, 0)
        cooldown = computer.uptime()
    end
    --Read the charge level in percent
    charge = getCaps()
    if not charge then display("Error") end
    --Read the fuel level and type
    if charge ~= lastMeas then
        if charge > 90 then
            status = "Off "
            --Be quiet, diesel generator!
            if dogen then diesel.setEnabled(false) end
        elseif charge < 80 then
            status = " On "
            --Diesel generator is being loud and obnoxious
            if dogen then diesel.setEnabled(true) end
        end
        if status then display("Done") end
        
        display(status .. charge .. "%")
    end
    --Set the last measurement so we can tell if it has
    --changed while we were away.
    lastMeas = charge
end

local timer = event.timer(2, run, math.huge)


local function stop()
    print("Caught interrupt, stopping.")
    --Stop main control loop
    event.cancel(timer)
    if dogen then
        --Shutdown generator
        diesel.setEnabled(false)
        diesel.enableComputerControl(false)
    end
    --Stop script
    event.ignore("interrupted", stop)
    print("Stopped")
end
event.listen("interrupted", stop)
print("Initialisation complete.")