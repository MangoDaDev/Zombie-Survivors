local GuiService = game:GetService("GuiService")

local SafeArea = {}

function SafeArea.GetTopOffset(ExtraPadding: number?): number
	return GuiService.TopbarInset.Height + (ExtraPadding or 0)
end

function SafeArea.GetChangedSignal(): RBXScriptSignal
	return GuiService:GetPropertyChangedSignal("TopbarInset")
end

return SafeArea
