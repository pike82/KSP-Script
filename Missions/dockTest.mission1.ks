
Print ("intilising").
PRINT ("Downloading libraries").
//download file handers
local ShipRV is import("RV").

Set runMode to 1.1.
Function runModes{
Print ("inside function runmodes").
Wait 2.
	if runMode = 1.1 {
		Print("Run mode is:" + runMode).
        ShipRV["dok_dock"]("TestPort", "TargetPort", "DockTarget"). // Name of port on Docking vessel, Name of Target port, Name of Target Vessel, Safe distance (optional)
		set_runmode(0). //Set CPU to hibernate (5 minute intervals)
    }
	
}



