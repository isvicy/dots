' Note: put this script in `C:\Users\<username>\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup`
Set ws = WScript.CreateObject("wscript.shell")

' Start WSL
ws.run "wsl -d Ubuntu-24.04", 0

' Wait for a moment to ensure WSL has started
WScript.Sleep 5000  ' Wait for 5 seconds, adjust as needed

' Create and execute PowerShell command using BurntToast
' Note: you need installed BurntToast before using this command.
' Do this before in you powershell with admin privilege: `Install-Module -Name BurntToast -Force`,
' and then test the installation with: `New-BurntToastNotification -Text "Hello", "This is a test notification"`
ps_cmd = "powershell -Command ""New-BurntToastNotification -Text 'WSL Started', 'Ubuntu-24.04 has been started'"""
ws.run ps_cmd, 0
