-- Pull in the wezterm API
local wezterm = require("wezterm")
local mux = wezterm.mux

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

-- This is where you actually apply your config choices
-- timeout_milliseconds defaults to 1000 and can be omitted
config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{
		key = "|",
		mods = "LEADER|SHIFT",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "f",
		mods = "LEADER|CTRL",
		action = wezterm.action.ShowTabNavigator,
	},
	-- Send "CTRL-A" to the terminal when pressing CTRL-A, CTRL-A
	{
		key = "a",
		mods = "LEADER|CTRL",
		action = wezterm.action.SendKey({ key = "a", mods = "CTRL" }),
	},
	{
		key = "t",
		mods = "LEADER|CTRL",
		action = wezterm.action.SpawnTab("CurrentPaneDomain"),
	},
	{ key = "l", mods = "LEADER", action = wezterm.action.ShowLauncher },
}

-- For example, changing the color scheme:
config.color_scheme = "Bamboo Multiplex"
config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font = wezterm.font_with_fallback({
	"Rec Mono Casual",
	"FireCode Nerd Font",
	"JetBrainsMono Nerd Font",
})
config.tab_bar_at_bottom = true
config.default_domain = "WSL:Ubuntu-22.04"
config.font_size = 12.0

local launch_menu = {}
if wezterm.target_triplet == "x86_64-pc-windows-msvc" then
	table.insert(launch_menu, {
		label = "PowerShell",
		args = { "powershell.exe", "-NoLogo" },
	})
end
-- and finally, return the configuration to wezterm
return config
