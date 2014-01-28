-- math.round function
function math.round(number, decimals)
	local multiply = 10 ^ (decimals or 0)
	return math.floor(number * multiply + 0.5) / multiply
end

class "FiniteFuelExtend"

function FiniteFuelExtend:__init()
	-- Configurable
	self.pricePerFuelPoint = 0.05
	
	-- Type arrays
	self.vehicleGasTypes = {
		Car = 1,
		Watercraft = 2,
		Aircraft = 3
	}

	-- Create GUI
	self:CreateGui()
	
	self.textColor = Color(255, 0, 0)
	self.vehicleInfo = nil
	self.currentGasStation = nil
	self.refuelPrice = nil

	Events:Subscribe("FiniteFuelEnteredGasStation", self, self.EnteredGasStation)
	Events:Subscribe("FiniteFuelExitedGasStation", self, self.ExitedGasStation)
	Events:Subscribe("FiniteFuelReturnGetFuel", self, self.ReturnGetFuel)
	Events:Subscribe("LocalPlayerInput", self, self.LocalPlayerInput)
end

function FiniteFuelExtend:CreateGui()
	-- Used to prevent mouse movement in game while the window is open
	self.mouseEvents = {
		[Action.LookDown] = true,
		[Action.LookLeft] = true,
		[Action.LookRight] = true,
		[Action.LookUp] = true,
		[Action.Fire] = true,
		[Action.FireLeft] = true,
		[Action.FireRight] = true,
		[Action.McFire] = true,
		[Action.VehicleFireLeft] = true,
		[Action.VehicleFireRight] = true
	}

	self.window = Window.Create()
	self.window:SetVisible(false)
	self.window:SetTitle("Buy Fuel")
	self.window:SetSize(Vector2(200, 100))
	self.window:SetPositionRel(Vector2(0.5, 0.5) - self.window:GetSizeRel() / 2)
	self.window:DisableResizing()
	self.window:Subscribe("WindowClosed", function() self:ShowWindow(false) end)
	
	self.buyButton = Button.Create(self.window)
	self.buyButton:SetDock(GwenPosition.Fill)
	self.buyButton:SetText("Refuel ($0)")
	self.buyButton:Subscribe("Press", self, self.BuyButtonPressed)
end

function FiniteFuelExtend:ShowWindow(show)
	-- Hide window
	if not show then
		self.window:SetVisible(false)
		Mouse:SetVisible(false)
		return
	end
	
	-- Make mouse and window visible
	Mouse:SetVisible(true)
	self.window:SetVisible(true)
end

function FiniteFuelExtend:LocalPlayerInput(args)
	if not self.window:GetVisible() then return true end
	
	-- Prevent in-game mouse movemnet if window is open
	if self.mouseEvents[args.input] then return false end
end

function FiniteFuelExtend:BuyButtonPressed()
	-- Buy button pressed
	if self.refuelPrice == nil or self.currentGasStation == nil then return end
	
	-- Calculate how much fuel we can buy
	local newFuelAmount = self.vehicleInfo.tankSize
	local playerMoney = LocalPlayer:GetMoney()
	
	if playerMoney == 0 then
		Chat:Print("You have no money!", self.textColor)
		return
	elseif playerMoney < self.refuelPrice then
		-- The amount of points the player can buy with their current money
		local buyableFuel = playerMoney / self.pricePerFuelPoint
		
		-- New fuel amount = vehicle's current fuel, plus the amount of fuel points the player can buy with their current money
		newFuelAmount = self.vehicleInfo.fuel + buyableFuel
		
		Network:Send("FiniteFuelExtendWithdrawMoney", playerMoney)
		Chat:Print("You bought " .. math.round(buyableFuel) .. " fuel for $" .. math.round(playerMoney, 2) .. ".", self.textColor)
	else
		Network:Send("FiniteFuelExtendWithdrawMoney", self.refuelPrice)
		Chat:Print("You bought " .. math.round(self.vehicleInfo.tankSize - self.vehicleInfo.fuel) .. " fuel for $" .. math.round(self.refuelPrice, 2) .. ".", self.textColor)
	end

	-- Tell FiniteFuel to set the fuel
	Events:Fire("FiniteFuelSetFuel", newFuelAmount)
	
	-- Hide window
	self:ShowWindow(false)
end

function FiniteFuelExtend:EnteredGasStation(args)
	-- Player entered gas station
	local vehicle = args.vehicle
	local vehicleGasType = args.vehicleGasType
	local fuel = args.fuel
	local tankSize = args.tankSize
	local gasStationPosition = args.gasStation.position
	local gasStationGasType = args.gasStation.gasType
	
	-- Check if vehicle can refuel at this gas station
	if gasStationGasType ~= vehicleGasType then
		Chat:Print("You cannot refuel this type of vehicle at this gas station.", self.textColor)
		return
	end
	
	-- Save current gas station
	self.currentGasStation = args.gasStation
	
	-- Request current vehicle info
	Events:Fire("FiniteFuelGetFuel")
end

function FiniteFuelExtend:ExitedGasStation(args)
	local vehicle = args.vehicle
	local gasStationPosition = args.gasStation.position
	local gasStationGasType = args.gasStation.gasType
	
	self.currentGasStation = nil

	-- Player left the gas station
	self:ShowWindow(false)
	self.refuelPrice = nil
end

function FiniteFuelExtend:ReturnGetFuel(args)
	if self.currentGasStation == nil then return end

	-- Got current vehicle information from FiniteFuel {vehicle, vehicleGasType, fuel, tankSize}
	local vehicle = args.vehicle
	local vehicleGasType = args.vehicleGasType
	local fuel = args.fuel
	local tankSize = args.tankSize
	
	-- Save vehicle info
	self.vehicleInfo = args
	
	-- Calculate refuel price, and set buy button text
	local fuelMissing = tankSize - fuel
	self.refuelPrice = fuelMissing * self.pricePerFuelPoint
	
	self.buyButton:SetText("Refuel ($" .. math.round(self.refuelPrice, 2) .. ")")
	
	self:ShowWindow(true)
end

-- Initialize class
FiniteFuelExtend()