# Platform module guidance

- Platform contains helpers built around Roblox platform services, account identity, thumbnails, and synchronized server time.
- Keep gameplay rules and persistence decisions out of this category.
- Yielding platform calls must be obvious to callers. Use `pcall` only for Roblox service calls that can genuinely fail, and return a clear fallback or nil.
- Prefer Roblox-native synchronized APIs such as `Workspace:GetServerTimeNow()` over external HTTP time services.
- Avoid repeated API calls when a stable result can be cached, but do not introduce caching until a real caller benefits from it.
