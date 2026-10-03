local UIStyle = require(script.Parent.UIStyle)

local ResponsiveLayout = {}

local function read(value)
	return if type(value) == "function" then value() else value
end

function ResponsiveLayout.Resolve(size: UDim2, parentSize: Vector2, aspectRatio: number?): Vector2
	local width = size.X.Scale * parentSize.X + size.X.Offset
	local height = size.Y.Scale * parentSize.Y + size.Y.Offset
	if aspectRatio then
		width = math.min(width, height * aspectRatio)
		height = width / aspectRatio
	end
	return Vector2.new(math.max(width, 1), math.max(height, 1))
end

function ResponsiveLayout.ToScale(value: UDim2, parentSize: Vector2): UDim2
	return UDim2.fromScale(
		value.X.Scale + value.X.Offset / parentSize.X,
		value.Y.Scale + value.Y.Offset / parentSize.Y
	)
end

function ResponsiveLayout.Viewport(viewportSize)
	return {
		ReferenceSize = function()
			local size = read(viewportSize)
			-- Preserve the single authored composition and its aspect ratios; only high-resolution growth is damped.
			local reference = UIStyle.ReferenceViewport
			local factor = math.min(1, reference.X / math.max(size.X, 1), reference.Y / math.max(size.Y, 1))
			return Vector2.new(math.max(size.X * factor, 1), math.max(size.Y * factor, 1))
		end,
	}
end

local function container(size, parent, aspectRatio, isBase: boolean)
	local layout = {}
	layout.ReferenceSize = function()
		return ResponsiveLayout.Resolve(read(size), parent.ReferenceSize(), read(aspectRatio))
	end
	layout.AspectRatio = function()
		return read(aspectRatio)
	end
	layout.Size = function()
		local authored = read(size)
		local reference = parent.ReferenceSize()
		if isBase then
			-- User invariant: screen containers retain a pixel base and responsive growth;
			-- descendants use parent-relative Scale, never another viewport growth factor.
			local growth = UIStyle.BaseContainerScaleWeight
			return UDim2.new(
				authored.X.Scale * growth, authored.X.Offset + authored.X.Scale * (1 - growth) * reference.X,
				authored.Y.Scale * growth, authored.Y.Offset + authored.Y.Scale * (1 - growth) * reference.Y
			)
		end
		return ResponsiveLayout.ToScale(authored, reference)
	end
	layout.Scale = function(value)
		return function()
			return ResponsiveLayout.ToScale(read(value), layout.ReferenceSize())
		end
	end
	layout.Position = function(value, anchorPoint)
		return function()
			local authored = read(value)
			local anchor = read(anchorPoint) or Vector2.zero
			local reference = parent.ReferenceSize()
			local growth = UIStyle.BaseContainerScaleWeight
			-- Keep center/edge anchoring exact; damp only the distance away from that anchor.
			return UDim2.new(
				anchor.X + (authored.X.Scale - anchor.X) * growth,
				authored.X.Offset + (authored.X.Scale - anchor.X) * (1 - growth) * reference.X,
				anchor.Y + (authored.Y.Scale - anchor.Y) * growth,
				authored.Y.Offset + (authored.Y.Scale - anchor.Y) * (1 - growth) * reference.Y
			)
		end
	end
	layout.FittedSize = function(viewportSize: Vector2): Vector2
		return ResponsiveLayout.Resolve(layout.Size(), viewportSize, read(aspectRatio))
	end
	layout.Padding = function(value, axis: string)
		return function()
			local authored = read(value)
			return UDim.new(authored.Scale + authored.Offset / layout.ReferenceSize()[axis], 0)
		end
	end
	return layout
end

function ResponsiveLayout.Base(size, viewport, aspectRatio)
	return container(size, viewport, aspectRatio, true)
end

function ResponsiveLayout.Child(size, parent, aspectRatio)
	return container(size, parent, aspectRatio, false)
end

return ResponsiveLayout
