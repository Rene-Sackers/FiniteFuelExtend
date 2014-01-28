Network:Subscribe("FiniteFuelExtendWithdrawMoney", function(amount, player)
	local newMoney = player:GetMoney() - amount
	if newMoney < 0 then newMoney = 0 end
	player:SetMoney(newMoney)
end)