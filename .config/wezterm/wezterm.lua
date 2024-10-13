-- Pull in the wezterm API
local wezterm = require("wezterm")
local mux = wezterm.mux
local act = wezterm.action

-- This table will hold the configuration.
local config = {}

-- In newer versions of wezterm, use the config_builder which will
-- help provide clearer error messages
if wezterm.config_builder then
	config = wezterm.config_builder()
end

wezterm.on("gui-startup", function(cmd)
	local _, _, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
end)

-- This is where you actually apply your config choices
-- timeout_milliseconds defaults to 1000 and can be omitted
config.leader = { key = "m", mods = "CTRL", timeout_milliseconds = 1000 }
config.keys = {
	{
		key = "|",
		mods = "LEADER|SHIFT",
		action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "-",
		mods = "LEADER",
		action = act.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "f",
		mods = "LEADER",
		action = act.ShowTabNavigator,
	},
	{
		key = "c",
		mods = "LEADER",
		action = act.SpawnTab("CurrentPaneDomain"),
	},
	{
		key = "x",
		mods = "LEADER",
		action = act.CloseCurrentPane({ confirm = false }),
	},
	{ key = "T", mods = "LEADER", action = act.ShowLauncher },
	{
		key = ",",
		mods = "LEADER",
		action = act.PromptInputLine({
			description = "Enter new name for tab",
			action = wezterm.action_callback(function(window, _, line)
				-- line will be `nil` if they hit escape without entering anything
				-- An empty string if they just hit enter
				-- Or the actual line of text they wrote
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}),
	},
	-- tmux style pane navigation
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	{
		key = "Enter",
		mods = "CTRL",
		action = act({ SendString = "\x1b[13;5u" }),
	},
	{ key = "Enter", mods = "NONE", action = act.SendKey({ key = "Enter" }) },
	{ key = "Enter", mods = "SHIFT", action = wezterm.action({ SendString = "\x1b[13;2u" }) },
}
for i = 1, 8 do
	-- <leader> + number to activate that tab
	table.insert(config.keys, {
		key = tostring(i),
		mods = "LEADER",
		action = act.ActivateTab(i - 1),
	})
end
-- For example, changing the color scheme:
config.color_scheme = "Bright (base16)"
config.font = wezterm.font_with_fallback({
	"Rec Mono Casual",
	"MesloLGS NF",
	"Operator Mono Book",
	"JetBrainsMono Nerd Font",
	"FireCode Nerd Font",
})
config.tab_bar_at_bottom = true
config.font_size = 13.0
config.window_decorations = "RESIZE"

local launch_menu = {}
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.default_domain = "SSH:wsl"
	table.insert(launch_menu, {
		label = "PowerShell",
		args = { "powershell.exe", "-NoLogo" },
	})
end
config.launch_menu = launch_menu
-- and finally, return the configuration to wezterm
return config
