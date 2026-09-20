local TagPrefix = "InventoryItemKey_"

local InventoryItemKey = {}

function InventoryItemKey.Get(InstanceValue: Instance?): string?
	if not InstanceValue then return nil end
	for _, Tag in InstanceValue:GetTags() do
		if string.sub(Tag, 1, #TagPrefix) == TagPrefix then
			local ItemKey = string.sub(Tag, #TagPrefix + 1)
			if ItemKey ~= "" then return ItemKey end
		end
	end
	return nil
end

function InventoryItemKey.Set(InstanceValue: Instance, ItemKey: string)
	InstanceValue:AddTag(TagPrefix .. ItemKey)
end

return InventoryItemKey
