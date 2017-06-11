
Print ("Intilising other CPU's").

Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 500.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script
Print "New Config:IPU Setting:" + Config:IPU.
Set Config:Stat to false.

	
LIST PROCESSORS IN ALL_PROCESSORS.

Set CORE:Part:Tag To SHIP:NAME.

for Processor in ALL_PROCESSORS {
	Print Processor:Tag.
	If Processor:Tag:CONTAINS("Stage"){
		SET MESSAGE TO Processor:Tag. // can be any serializable value or a primitive
		SET P TO PROCESSOR(Processor:Tag).
		IF P:CONNECTION:SENDMESSAGE(MESSAGE) {
			PRINT "Message sent to Inbox Stack!".
		}
		//Processor:Deactivate.
		Print Processor:Tag + " Files moved".
		copypath("0:/Launchers/" + Processor:Tag +".ks",Processor:Tag + ":/Boot.ks").
		copypath("0:/Library/knu.ks",Processor:Tag + ":/").
		set processor:bootfilename to "Boot.ks". // sets the bootfile so when activated this file will run
		Processor:Activate.
		WAIT UNTIL NOT CORE:MESSAGES:EMPTY. // If the processor activates properly it will pick up the message sent before deactivation and send a reponse everything is working
		SET RECEIVED TO CORE:MESSAGES:POP.
		IF RECEIVED:CONTENT = Processor:Tag + " Rcvd" {
			PRINT Processor:Tag + "Started".
		} ELSE {
		  PRINT "Unexpected message: " + RECEIVED:CONTENT.
		}
	}
}.		
 wait 0.5. // ensure above mesage process has finished	
 
 //TODO: Look at implimenting a Flight readout script like the KOS-Stuff_master gravity file for possible implimentation.
 
PRINT ("Downloading libraries").
//download dependant libraries first
	local Launch is import("Launch_atm").
	local Orbit_Calc is import("Orbit_Calc").
	local Node_Calc is import("Node_Calc").
	//local Hover is import("Hover").

	
intParameters().
Print runMode["runMode"].

Function Mission_runModes{
	Set Timebase to TIME:SECONDS. 
	Print "Timebase" + Timebase.
	Set BaseLoc to gl_shipLatLng.
	Set BaseHeight to gl_surfaceElevation.
	Set SteerDirection to HEADING(90,90).///HEADING(compass, pitch)
	LOCK STEERING TO SteerDirection.
	Set ThrottSetting to 0.0.
	Lock Throttle to ThrottSetting.
	Set TgtCoord to latlng(BaseLoc:lat- 0.01, BaseLoc:lng + 0.01).
	Set lastdt to TIME:SECONDS.
	Set DegDistance to (body:radius*2*constant:pi)/360.
	//Set NorthVec to 
	//Set EastVec to 
	
	
	//===ALTITUDE====
	//Desired velocity
	Set KpALT to 0.9. 
	Set KiALT to 0.0. 
	Set KdALT to 0.0005. 
	Set ALT_Min to -5. 
	Set ALT_Max to 5. 
	Set PIDALT to PIDLOOP(KpALT, KiALT, KdALT, ALT_Min, ALT_Max).// , PID_Min, PID_Max).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

	//Desired throttle setting
	Set KpThrott to 0.1. 
	Set KiThrott to 0.2. 
	Set KdThrott to 0.005. 
	Set Thrott_Min to 0. 
	Set Thrott_Max to 1. 
	Set PIDThrott to PIDLOOP(KpThrott, KiThrott, KdThrott, Thrott_Min, Thrott_Max).// , PID_Min, PID_Max).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	


//===LATITUDE (North) ====
	//Desired velocity
	Set KpLAT to 1.0. 
	Set KiLAT to 0.0. 
	Set KdLAT to 5.0. 
	Set LAT_Min to -5/DegDistance. 
	Set LAT_Max to 5/DegDistance. 
	Set PIDLAT to PIDLOOP(KpLAT, KiLAT, KdLAT, LAT_Min, LAT_Max).// , PID_Min, PID_Max).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	
	//Desired direction
	Set KpNorth to 10000. 
	Set KiNorth to 0. 
	Set KdNorth to 0. 
	Set North_Min to -2.5. 
	Set North_Max to 2.5. 
	Set PIDNorth to PIDLOOP(KpNorth, KiNorth, KdNorth, North_Min, North_Max).// , PID_Min, PID_Max).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	


//===LONGITUDE (East)====
	//Desired velocity
	Set KpLONG to 0.5. 
	Set KiLONG to 0.0. 
	Set KdLONG to 2.5. 
	Set LONG_Min to -5/DegDistance. 
	Set LONG_Max to 5/DegDistance. 
	Set PIDLONG to PIDLOOP(KpLONG, KiLONG, KdLONG, LONG_Min, LONG_Max).// , PID_Min, PID_Max).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
		
	//Desired direction	
	Set KpEast to 10000. 
	Set KiEast to 0. 
	Set KdEast to 0. 
	Set East_Min to -2.5. 
	Set East_Max to 2.5. 
	Set PIDEast to PIDLOOP(KpEast, KiEast, KdEast, East_Min, East_Max).// , PID_Min, PID_Max).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	

//	Set PIDThrott:SETPOINT to 0.
//	Set PIDPitch:SETPOINT to 0.
//	Set PIDYaw:SETPOINT to 0.
	Set SteerDirection to UP + r(0,0,180). // r(pitch, yaw, roll) set roll to zero (intially pointing at 180 degress), this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required
	Set lastLat to gl_shipLatLng:Lat.//inital set up
	Set lastLng to gl_shipLatLng:Lng.//inital set up
	Stage. // starts engine

////// Climb///////
	
	Set PIDALT:SETPOINT to 50.0.
	Set PIDLAT:Setpoint to gl_shipLatLng:Lat.
	Set PIDLONG:Setpoint to gl_shipLatLng:Lng.
	Until Timebase + 20 < TIME:SECONDS {

		SET ALTSpeed TO PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
		Set LATSpeed to PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat degrees/sec
		Set LONGSpeed to PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long degress/sec
		
		Set PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
		Set PIDNorth:SETPOINT to LATSpeed.
		Set PIDEast:SETPOINT to LONGSpeed. 
		
		Set NorthSpeed to (gl_shipLatLng:Lat - lastLat)/(TIME:SECONDS-lastdt).
		Set EastSpeed to (gl_shipLatLng:Lng - lastLng)/(TIME:SECONDS-lastdt).
		
		SET ThrottSetting TO PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
		SET NorthDirection TO PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
		SET EastDirection TO PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed

		Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
		
		
		ClearScreen.
		Print "Climbing and hover".		
		Print "Time Passed: " + (TIME:SECONDS - Timebase).
		Print "===============================".
		Print "Base: " + BaseLoc.
		Print "===============================".		
		Print "Lat: " + gl_shipLatLng:Lat.
		Print "Lat diff: " + PIDLAT:Pterm/PIDLAT:KP.		
		Print "PIDLAT Out: " + PIDLAT:OUTPUT.			
		Print "Desired LATSpeed: " + LATSpeed.			
		Print "NorthSpeed: " + NorthSpeed.
		Print "NorthDirection: " + NorthDirection.		
		Print "===============================".		
		Print "Long: " + gl_shipLatLng:Lng.
		Print "Long diff: " + PIDLONG:Pterm/PIDLONG:KP.
		Print "PIDLONG Out: " + PIDLONG:OUTPUT.
		Print "Desired LONGSpeed: " + LONGSpeed.
		Print "EastSpeed: " + EastSpeed.		
		Print "EastDirection: " + EastDirection.		
		Print "===============================".	
		Print "ALT Kp: " + PIDALT:Pterm.
		Print "ALT Ki: " + PIDALT:Iterm.
		Print "ALT Kd: " + PIDALT:Dterm.
		Print "ALT Out: " + PIDALT:OUTPUT.
		Print "===============================".
		Print "Thrott Kp: " + PIDThrott:Pterm.
		Print "Thrott Ki: " + PIDThrott:Iterm.
		Print "Thrott Kd: " + PIDThrott:Dterm.
		Print "Thrott Out: " + PIDThrott:OUTPUT.
		Print "===============================".
		//Print "Delta throttle: "+ dThrot.
		Print "Throttle Setting: "+ ThrottSetting.
		Print "Radar" + gl_baseALTRADAR.
		Print "Distance from Base: " + gs_distance(BaseLoc,gl_shipLatLng).
		Print "Heading: " + ship:heading.
		Print "Bearing: " + ship:bearing.
		Print "True Bearing: " + gs_bearing(gl_shipLatLng,gl_NORTHPOLE).
		// Switch to 0.
		// LOG (TIME:SECONDS - Timebase) + "," + verticalspeed + "," + ThrotSetting TO "testflight.csv".
		// Switch to 1.
		Set lastLat to gl_shipLatLng:Lat.
		Set lastLng to gl_shipLatLng:Lng.
		Set lastdt to TIME:SECONDS.
		Wait 0.1.
	}

////// Move away///////
	
	Set PIDALT:SETPOINT to 100.0.
	Set PIDLAT:Setpoint to TgtCoord:Lat.
	Set PIDLONG:Setpoint to TgtCoord:Lng.
	Until Timebase + 100 < TIME:SECONDS {
		SET ALTSpeed TO PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
		Set LATSpeed to PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat degrees/sec
		Set LONGSpeed to PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long degress/sec
		
		Set PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
		Set PIDNorth:SETPOINT to LATSpeed.
		Set PIDEast:SETPOINT to LONGSpeed. 
		
		Set NorthSpeed to (gl_shipLatLng:Lat - lastLat)/(TIME:SECONDS-lastdt).
		Set EastSpeed to (gl_shipLatLng:Lng - lastLng)/(TIME:SECONDS-lastdt).
		
		SET ThrottSetting TO PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
		SET NorthDirection TO PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
		SET EastDirection TO PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed

		Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
			
		
		ClearScreen.
		Print "Moving Away".		
		Print "Time Passed: " + (TIME:SECONDS - Timebase).
		Print "===============================".
		Print "Tgt: " + TgtCoord.
		Print "===============================".		
		Print "Lat: " + gl_shipLatLng:Lat.
		Print "Lat diff: " + PIDLAT:Pterm/PIDLAT:KP.		
		Print "PIDLAT Out: " + PIDLAT:OUTPUT.			
		Print "Desired LATSpeed: " + LATSpeed.			
		Print "NorthSpeed: " + NorthSpeed.
		Print "NorthDirection: " + NorthDirection.		
		Print "===============================".		
		Print "Long: " + gl_shipLatLng:Lng.
		Print "Long diff: " + PIDLONG:Pterm/PIDLONG:KP.
		Print "PIDLONG Out: " + PIDLONG:OUTPUT.
		Print "Desired LONGSpeed: " + LONGSpeed.
		Print "EastSpeed: " + EastSpeed.		
		Print "EastDirection: " + EastDirection.		
		Print "===============================".	
		Print "ALT Kp: " + PIDALT:Pterm.
		Print "ALT Ki: " + PIDALT:Iterm.
		Print "ALT Kd: " + PIDALT:Dterm.
		Print "ALT Out: " + PIDALT:OUTPUT.
		Print "===============================".
		Print "Thrott Kp: " + PIDThrott:Pterm.
		Print "Thrott Ki: " + PIDThrott:Iterm.
		Print "Thrott Kd: " + PIDThrott:Dterm.
		Print "Thrott Out: " + PIDThrott:OUTPUT.
		Print "===============================".
		//Print "Delta throttle: "+ dThrot.
		Print "Throttle Setting: "+ ThrottSetting.
		Print "Radar" + gl_baseALTRADAR.
		Print "Distance from Base: " + gs_distance(BaseLoc,gl_shipLatLng).
		Print "Heading: " + ship:heading.
		Print "Bearing: " + ship:bearing.
		Print "True Bearing: " + gs_bearing(gl_shipLatLng,gl_NORTHPOLE).
		// Switch to 0.
		// LOG (TIME:SECONDS - Timebase) + "," + verticalspeed + "," + ThrotSetting TO "testflight.csv".
		// Switch to 1.
		Set lastLat to gl_shipLatLng:Lat.
		Set lastLng to gl_shipLatLng:Lng.
		Set lastdt to TIME:SECONDS.
		Wait 0.1.
	}

////// Move back///////	
	
	Set PIDALT:SETPOINT to 50.0.
	Set PIDLAT:Setpoint to BaseLoc:Lat.
	Set PIDLONG:Setpoint to BaseLoc:Lng.
	Until Timebase + 200 < TIME:SECONDS {
		SET ALTSpeed TO PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
		Set LATSpeed to PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat degrees/sec
		Set LONGSpeed to PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long degress/sec
		
		Set PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
		Set PIDNorth:SETPOINT to LATSpeed.
		Set PIDEast:SETPOINT to LONGSpeed. 
		
		Set NorthSpeed to (gl_shipLatLng:Lat - lastLat)/(TIME:SECONDS-lastdt).
		Set EastSpeed to (gl_shipLatLng:Lng - lastLng)/(TIME:SECONDS-lastdt).
		
		SET ThrottSetting TO PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
		SET NorthDirection TO PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
		SET EastDirection TO PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed

		Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
				
		
		ClearScreen.
		Print "Moving Back".		
		Print "Time Passed: " + (TIME:SECONDS - Timebase).
		Print "===============================".
		Print "Tgt: " + TgtCoord.
		Print "===============================".		
		Print "Lat: " + gl_shipLatLng:Lat.
		Print "Lat diff: " + PIDLAT:Pterm/PIDLAT:KP.		
		Print "PIDLAT Out: " + PIDLAT:OUTPUT.			
		Print "Desired LATSpeed: " + LATSpeed.			
		Print "NorthSpeed: " + NorthSpeed.
		Print "NorthDirection: " + NorthDirection.		
		Print "===============================".		
		Print "Long: " + gl_shipLatLng:Lng.
		Print "Long diff: " + PIDLONG:Pterm/PIDLONG:KP.
		Print "PIDLONG Out: " + PIDLONG:OUTPUT.
		Print "Desired LONGSpeed: " + LONGSpeed.
		Print "EastSpeed: " + EastSpeed.		
		Print "EastDirection: " + EastDirection.		
		Print "===============================".	
		Print "ALT Kp: " + PIDALT:Pterm.
		Print "ALT Ki: " + PIDALT:Iterm.
		Print "ALT Kd: " + PIDALT:Dterm.
		Print "ALT Out: " + PIDALT:OUTPUT.
		Print "===============================".
		Print "Thrott Kp: " + PIDThrott:Pterm.
		Print "Thrott Ki: " + PIDThrott:Iterm.
		Print "Thrott Kd: " + PIDThrott:Dterm.
		Print "Thrott Out: " + PIDThrott:OUTPUT.
		Print "===============================".
		//Print "Delta throttle: "+ dThrot.
		Print "Throttle Setting: "+ ThrottSetting.
		Print "Radar" + gl_baseALTRADAR.
		Print "Distance from Base: " + gs_distance(BaseLoc,gl_shipLatLng).
		Print "Heading: " + ship:heading.
		Print "Bearing: " + ship:bearing.
		Print "True Bearing: " + gs_bearing(gl_shipLatLng,gl_NORTHPOLE).
		// Switch to 0.
		// LOG (TIME:SECONDS - Timebase) + "," + verticalspeed + "," + ThrotSetting TO "testflight.csv".
		// Switch to 1.
		Set lastLat to gl_shipLatLng:Lat.
		Set lastLng to gl_shipLatLng:Lng.
		Set lastdt to TIME:SECONDS.
		Wait 0.1.
	}	
	
	
////// LAND///////	
	
	Set PIDALT:MAXOUTPUT to 10.
	Set PIDALT:MINOUTPUT to -10.
	Set PIDALT:SETPOINT to -0.3. // make negative so it actually touches down instead of hovering the last foot.
	Set PIDLAT:Setpoint to gl_shipLatLng:Lat.
	Set PIDLONG:Setpoint to gl_shipLatLng:Lng.
	
	Until Ship:Status = "Landed" {
		SET ALTSpeed TO PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
		Set LATSpeed to PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat degrees/sec
		Set LONGSpeed to PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long degress/sec
		
		Set PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
		Set PIDNorth:SETPOINT to LATSpeed.
		Set PIDEast:SETPOINT to LONGSpeed. 
		
		Set NorthSpeed to (gl_shipLatLng:Lat - lastLat)/(TIME:SECONDS-lastdt).
		Set EastSpeed to (gl_shipLatLng:Lng - lastLng)/(TIME:SECONDS-lastdt).
		
		SET ThrottSetting TO PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
		SET NorthDirection TO PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
		SET EastDirection TO PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed

		Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
			
		
		ClearScreen.
		Print "Landing".		
		Print "Time Passed: " + (TIME:SECONDS - Timebase).
		Print "===============================".
		Print "Base: " + BaseLoc.
		Print "===============================".		
		Print "Lat: " + gl_shipLatLng:Lat.
		Print "Lat diff: " + PIDLAT:Pterm/PIDLAT:KP.		
		Print "PIDLAT Out: " + PIDLAT:OUTPUT.			
		Print "Desired LATSpeed: " + LATSpeed.			
		Print "NorthSpeed: " + NorthSpeed.
		Print "NorthDirection: " + NorthDirection.		
		Print "===============================".		
		Print "Long: " + gl_shipLatLng:Lng.
		Print "Long diff: " + PIDLONG:Pterm/PIDLONG:KP.
		Print "PIDLONG Out: " + PIDLONG:OUTPUT.
		Print "Desired LONGSpeed: " + LONGSpeed.
		Print "EastSpeed: " + EastSpeed.		
		Print "EastDirection: " + EastDirection.		
		Print "===============================".	
		Print "ALT Kp: " + PIDALT:Pterm.
		Print "ALT Ki: " + PIDALT:Iterm.
		Print "ALT Kd: " + PIDALT:Dterm.
		Print "ALT Out: " + PIDALT:OUTPUT.
		Print "===============================".
		Print "Thrott Kp: " + PIDThrott:Pterm.
		Print "Thrott Ki: " + PIDThrott:Iterm.
		Print "Thrott Kd: " + PIDThrott:Dterm.
		Print "Thrott Out: " + PIDThrott:OUTPUT.
		Print "===============================".
		//Print "Delta throttle: "+ dThrot.
		Print "Throttle Setting: "+ ThrottSetting.
		Print "Radar" + gl_baseALTRADAR.
		Print "Distance from Base: " + gs_distance(BaseLoc,gl_shipLatLng).
		Print "Heading: " + ship:heading.
		Print "Bearing: " + ship:bearing.
		Print "True Bearing: " + gs_bearing(gl_shipLatLng,gl_NORTHPOLE).
		// Switch to 0.
		// LOG (TIME:SECONDS - Timebase) + "," + verticalspeed + "," + ThrotSetting TO "testflight.csv".
		// Switch to 1.
		Set lastLat to gl_shipLatLng:Lat.
		Set lastLng to gl_shipLatLng:Lng.
		Set lastdt to TIME:SECONDS.
		Wait 0.1.
	}

	
	Set ThrottSetting to 0.0.
	Set SHIP:CONTROL:PILOTMAINTHROTTLE to 0.0.
	Print "Landed".
	Wait 3.
	gf_set_runmode("runMode",-1).
	
} /// end of function runmodes

	declare function gs_distance {
    declare parameter gs_p1, gs_p2. //(point1,point2). Need to ensure converted to radians
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.
    set resultA to 	sin((P1Lat-P2Lat)/2)^2 + 
					cos(P1Lat)*cos(P2Lat)*
					sin((P1Lng-P2Lng)/2)^2.
	set resultB to 2*arctan2(sqrt(resultA),sqrt(1-resultA)).
    set result to body:radius*resultB. // this is the "Haversine" formula go to www.moveable-type.co.uk for more information
	
	// set resultA to 	sin((gs_p1:lat-gs_p2:lat)/2)^2 + 
					// cos(gs_p1:lat)*cos(gs_p2:lat)*
					// sin((gs_p1:lng-gs_p2:lng)/2)^2.
	// set resultB to 2*arctan2(sqrt(resultA),sqrt(1-resultA)).
    // set result to body:radius*resultB. // this is the "Haversine" formula go to www.moveable-type.co.uk for more information
    return result.
    }
	
	declare function gs_bearing {
    declare parameter gs_p1, gs_p2. //(point1,point2). Need to ensure converted to radians
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.
	
	set resultA to (cos(P1Lat)*sin(P2Lat)) -(sin(P1Lat)*cos(P2Lat)*cos(P2Lng-P1Lng)).
	set resultB to sin(P2Lng-P1Lng)*cos(P2Lat).
    set result to  arctan2(resultA, resultB).// this is the intial bearing formula go to www.moveable-type.co.uk for more informationn
	
	
    // set resultA to (cos(gs_p1:lat)*sin(gs_p2:lat)) -(sin(gs_p1:lat)*cos(gs_p2:lat)*cos(gs_p2:lng-gs_p1:lng)).
	// set resultB to sin(gs_p2:lng-gs_p1:lng)*cos(gs_p2:lat).
    // set result to  arctan2(resultA, resultB).// this is the intial bearing formula go to www.moveable-type.co.uk for more informationn
    return result.
    }

	
Function intParameters {
	
	///////////////////////
	//Ship Particualrs
	//////////////////////
	Set sv_maxGeeTarget to 4.  //max G force to be experienced
	Set sv_shipHeight to 4.1.	// the hieght of the ship to allow for height correction	
	Set sv_gimbalLimit to 10. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Set sv_MaxQLimit to 0.3. //0.3 is the Equivalent of 40Kpa Shuttle was 30kps and others like mercury were 40kPa.
	
	///////////////////////
	//Ship Variable Inital Launch Parameters
	///////////////////////
 	Set sv_targetInclination to 0.02. //Desired Inclination
    Set sv_targetAltitude to 100000. //Desired Orbit Altitude from Sea Level
    Set sv_ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Set sv_anglePitchover to 85. //Final Pitchover angle
	//Set sv_intAzimith TO Launch_Calc ["LaunchAzimuth"](sv_targetInclination,sv_targetAltitude).
	Set sv_landingtargetLATLNG to latlng(-0.0972092543643722, -74.557706433623). // This is for KSC but use target:geoposition if there is a specific target vessel on the surface that can be used.
	Set sv_prevMaxThrust to 0. //used to set up for the flameout function
	///////////////////////
	//Global Lock Parameters
	//////////////////////

	//ORBIT information
    Lock gl_SEALEVELGRAVITY to (constant():G * body:mass) / body:radius^2. // returns the sealevel gravity for any body that is being orbited.
	lock gl_apoEta to max(0,ETA:APOAPSIS). //Return time to Apoapsis
	lock gl_perEta to max(0,ETA:PERIAPSIS). //Return time to Periapsis
	lock gl_Ship_Ap to Ship:orbit:Apoapsis.
	lock gl_Ship_Pe to Ship:orbit:Periapsis.
	lock gl_Ship_Per to Ship:orbit:Period.
	lock gl_GRAVITY to gl_SEALEVELGRAVITY / ((body:radius+ALTITUDE) / body:radius)^2. //returns the current gravity experienced by the vessel
	
	//Locations
	lock gl_NORTHPOLE to latlng( 90, 0).
    lock gl_KSCLAUNCHPAD to latlng(-0.0972092543643722, -74.557706433623).  //The launchpad at the KSC
	lock gl_shipLatLng to SHIP:GEOPOSITION. // provides the current co-ordiantes
	lock gl_surfaceElevation to gl_shipLatLng:TERRAINHEIGHT. // provides the height at the current co-ordinates
	lock gl_PeLatLng to ship:body:geopositionof(positionat(ship, time:seconds + gl_perEta)). //The Lat and long of the PE

	//Engines
    lock gl_TWR to MAX( 0.001, MAXTHRUST / (ship:MASS*gl_GRAVITY)). //Provides the current thrust to weight ratio
	lock gl_TWRTarget to min( gl_TWR, sv_maxGeeTarget*(9.81/gl_GRAVITY)). // enables the trust to be limited based on the TWR which is dependant on the local gravity compared to normal G forces
	Lock gl_TVALMax to min(gl_TWRTarget/gl_TWR, sv_MaxQLimit / SHIP:Q). //use this to set the Max throttle as the TWR changes with time or the ship reaches max Q for throttleable engines.
	//Lock Throttle to gl_TVALMax. // this is the command that will need to be used in individual functions when re-setting the throttle after making the throttle zero.
	
	//Ship information
	Lock gl_StageNo TO STAGE:NUMBER. //Get the Current Stage Number
	lock gl_baseALTRADAR to max( 0.1, min(ALTITUDE , ALTITUDE - gl_surfaceElevation - sv_shipHeight)).
	
	
	//Fall Predictions and Variables
	Lock gl_fallTime to Orbit_Calc["quadraticMinus"](gl_GRAVITY, ship:verticalspeed, gl_baseALTRADAR).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation at2^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	lock gl_fallVel to ship:verticalspeed + (gl_GRAVITY*gl_fallTime).//v = u + at
	lock gl_fallDist to ship:verticalspeed^2 / (2*gl_InstMaxVertAcc). // v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a
	Lock gl_fallBurnTime to Node_Calc["burn_time"](gl_fallVel). 
	
	//Instantaneous Predictions and variables
	lock gl_InstConImpactTime to gl_baseALTRADAR / abs(VERTICALSPEED). //gives instantaneous time to impact if vertical velocity remains constant
	Lock gl_InstMaxVertAcc to (ship:AVAILABLETHRUST / ship:mass) - gl_GRAVITY. //gives max vertical acceleration at this point in time fighting gravity
	Lock gl_InstMaxHorzAcc to (ship:AVAILABLETHRUST / ship:mass). //gives max horizontal acceleration at this point in time
	lock gl_InstkillTime to ((gl_totalSurfSpeed/gl_TWRTarget)* gl_GRAVITY) / (gl_TWRTarget). // t0 = Vel/TWR  t1 = t0*g/TWR Tf = t1 + t0 ==> ((Vel/TWR)*g)/TWR gives instantaneous time to kill all speed
	
	
	//Flight Vectors
	lock gl_rightrotation to ship:facing*r(0,90,0).
	lock gl_right to gl_rightrotation:vector. //right vector i.e. points same as right wing
	lock gl_left to (-1)*gl_right. //left vector i.e. points same as left wing
	lock gl_up to ship:up:vector. //up is directly up perpendicular to the ground
	lock gl_down to (-1)*gl_up. //down is directly down perpendicular to the ground
	lock gl_fore to ship:facing:vector. //fore points through the nose
	lock gl_aft to (-1)*gl_fore. //aft points through the tail
	lock gl_righthor to vcrs(gl_up,gl_fore). //vector pointing to right horizon
	lock gl_lefthor to (-1)*gl_righthor.//vector pointing to left horizon
	lock gl_forehor to vcrs(gl_righthor,gl_up). //vector pointing to fwd horizon
	lock gl_afthor to (-1)*gl_forehor. //vector pointing to aft horizon
	lock gl_top to vcrs(gl_fore,gl_right). //top respective to the cockpit frame of reference i.e perpendicular to the wings
	lock gl_bottom to (-1)*gl_top. //bottom respective to the cockpit frame of reference i.e perpendicular to the wings
	
	//Flight Velocities
	lock gl_HorSurVel to vxcl(ship:up:vector, ship:velocity:surface). //Horizontal velocity of the ground TODO:check is this is the same as SURFACESPEED
	lock gl_VerSurVel to vdot(ship:up:vector, ship:velocity:surface). //Vertical velocity of the ground TODO:check is this is the same as VERTICALSPEED
	lock gl_HorSurFwdVel to vxcl(gl_righthor, gl_HorVel). //Horizontal velocity of the ground Fwd Component only
	lock gl_HorSurRightVel to vxcl(gl_forehor, gl_HorVel). //Horizontal velocity of the ground Right Component only (effectively the slide slip component as fwd should be the main component)
	lock gl_totalSurfSpeed to SURFACESPEED + ABS(VERTICALSPEED). //true speed relative to surface		

	//Flight Angles
	lock gl_absaoa to vang(gl_fore,srfprograde:vector). //absolute angle of attack including yaw and pitch
	lock gl_aoa to vang(gl_top,srfprograde:vector)-90. //pitch only component of angle of attack
	lock gl_sideslip to vang(gl_right,srfprograde:vector)-90. //yaw only component of aoa
	lock gl_rollangle to vang(gl_right,gl_righthor)*((90-vang(gl_top,gl_righthor))/abs(90-vang(gl_top,gl_righthor))). //roll angle, 0 at level flight
	lock gl_pitchangle to vang(gl_fore,gl_forehor)*((90-vang(fore,up))/abs(90-vang(fore,up))). //pitch angle, 0 at level flight
	lock gl_glideslope to vang(srfprograde:vector,gl_forehor)*((90-vang(srfprograde:vector,gl_up))/abs(90-vang(srfprograde:vector,gl_up))).
	
	Print "end of parameters".
}/////End of function

	
	