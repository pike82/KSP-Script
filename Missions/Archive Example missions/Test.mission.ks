Print ("Intilising other CPU's").

Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 1500.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script such as a suicide landing script which will require 1500
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
	local Util_Vessel is import("Util_Vessel").
	local Launch is import("Launch_atm").
	local Util_Launch is import("Util_Launch").
	local OrbMnvs is import("OrbMnvs").
	local OrbRv is import("OrbRv").
	local Landing_vac is import("Landing_vac").
	
	
intParameters().
Print runMode["runMode"].

Function Mission_runModes{
		
	if runMode["runMode"] = 0.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch["preLaunch"]().
		gf_set_runmode("runMode",1.0).
	}
	
	else if runMode["runMode"] = 1.0 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch["liftoff"]().
		gf_set_runmode("runMode",1.1).
	}
	
	else if runMode["runMode"] = 1.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch["liftoffclimb"]().
		gf_set_runmode("runMode",1.2).
	}
	
	else if runMode["runMode"] = 1.2 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch["GravityTurnAoA"](0.05).
		gf_set_runmode("runMode",1.3).
	}
	
	// else if runMode["runMode"] = 1.2 { 
		// Print "Run mode is:" + runMode["runMode"].
		// Launch["GravityTurnPres"]().
		// gf_set_runmode("runMode",1.3).
	// }
	
	else if runMode["runMode"] = 1.3 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch["Coast"]().
		gf_set_runmode("runMode",2.1).
	}
	
	// else if runMode["runMode"] = 1.3 { 
		// Print "Run mode is:" + runMode["runMode"].
		// Launch["InsertionPIDSpeed"](sv_targetAltitude).
		// gf_set_runmode("runMode",2.1).
	// }
	
	// else if runMode["runMode"] = 1.3 { 
		// Print "Run mode is:" + runMode["runMode"].
		// Launch["InsertionPEG"](sv_targetAltitude, sv_targetAltitude, sv_targetInclination).
		// gf_set_runmode("runMode",2.1).
	// }
	
	else if runMode["runMode"] = 2.1 { 
		Print "Run mode is:" + runMode["runMode"].
		orbmnvs["circ"]("apo", 0.001, false, sv_targetInclination).
		gf_set_runmode("runMode",3.1).
	}
	
	else if runMode["runMode"] = 3.1 { 
		Print "Run mode is:" + runMode["runMode"].
		orbrv["BodyTransfer"](Mun, 10000, 1000).
		gf_set_runmode("runMode",3.2).
	}
	
	else if runMode["runMode"] = 3.2 { 
		Print "Run mode is:" + runMode["runMode"].
		wait until ship:body:name = "Mun". 
		Print "Waiting for SOI Stabilisation".
		wait 60.// ensure SOI transfer complete
		orbmnvs["adjapo"](10000, 500, false, sv_targetInclination).
		gf_set_runmode("runMode",4.1).
	}
	
	else if runMode["runMode"] = 4.1 { 
		Print "Run mode is:" + runMode["runMode"].
		orbmnvs["circ"]("per", 0.01, false, 90).
		gf_set_runmode("runMode",5.1).
	}

	else if runMode["runMode"] = 5.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Landing_vac["CAB"]().
		gf_set_runmode("runMode",6.1).
	}	
	
} /// end of function runmodes

	
Function intParameters {
	
	///////////////////////
	//Ship Particualrs
	//////////////////////
	Set sv_maxGeeTarget to 4.  //max G force to be experienced

	Set sv_shipHeightflight to 4.1. // the height of the ship from the ground to the ship base part
	Set sv_gimbalLimit to 10. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Set sv_MaxQLimit to 0.3. //0.3 is the Equivalent of 40Kpa Shuttle was 30kps and others like mercury were 40kPa.
	
	///////////////////////
	//Ship Variable Inital Launch Parameters
	///////////////////////
 	Set sv_targetInclination to 5. //Desired Inclination
    Set sv_targetAltitude to 85000. //Desired Orbit Altitude from Sea Level
    Set sv_ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Set sv_anglePitchover to 86. //Final Pitchover angle
	Set sv_intAzimith TO Util_Launch ["LaunchAzimuth"](sv_targetInclination,sv_targetAltitude).
	Set sv_landingtargetLATLNG to latlng(-0.0972092543643722, -74.557706433623). // This is for KSC but use target:geoposition if there is a specific target vessel on the surface that can be used.
	Set sv_prevMaxThrust to 0. //used to set up for the flameout function
	
	//////////////////////////////////////////
	///Ship PID Control variables//////////////////
	/////////////////////////////////////////
	Lock gl_DegDistance to (body:radius*2*constant:pi)/360.
//===ALTITUDE====
	//Desired vertical speed
	Set sv_PIDALT to PIDLOOP(0.9, 0.0, 0.0005, -10, 10).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired throttle setting
	Set sv_PIDThrott to PIDLOOP(0.1, 0.2, 0.005, 0, 1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LATITUDE (North) ====
	//Desired velocity
	Set sv_PIDLAT to PIDLOOP(1.0, 0.0, 5.0, 5/gl_DegDistance, -5/gl_DegDistance).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired direction
	Set sv_PIDNorth to PIDLOOP(10000, 0, 0, -22.5, 22.5).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LONGITUDE (East)====
	//Desired velocity
	Set sv_PIDLONG to PIDLOOP(0.5, 0, 2.5, -5/gl_DegDistance, 5/gl_DegDistance).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).			
	//Desired direction	 
	Set sv_PIDEast to PIDLOOP(10000, 0, 0, -22.5, 22.5).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	
	
	///////////////////////
	//Global Lock Parameters
	//////////////////////
	Lock gl_Grav to Util_Vessel["Gravity"]().
//Engines
    lock gl_TWR to MAX( 0.001, MAXTHRUST / (ship:MASS*gl_Grav["G"])). //Provides the current thrust to weight ratio
	lock gl_TWRTarget to min( gl_TWR, sv_maxGeeTarget*(9.81/gl_Grav["G"])). // enables the trust to be limited based on the TWR which is dependant on the local gravity compared to normal G forces
	Lock gl_TVALMax to min(gl_TWRTarget/gl_TWR, sv_MaxQLimit / SHIP:Q). //use this to set the Max throttle as the TWR changes with time or the ship reaches max Q for throttleable engines.
	//Lock Throttle to gl_TVALMax. // this is the command that will need to be used in individual functions when re-setting the throttle after making the throttle zero.
//Locations	
	lock gl_shipLatLng to SHIP:GEOPOSITION. // provides the current co-ordiantes
	lock gl_surfaceElevation to gl_shipLatLng:TERRAINHEIGHT. // provides the height at the current co-ordinates
	lock gl_baseALTRADAR to max( 0.1, min(ship:Altitude , ship:Altitude - gl_surfaceElevation - sv_shipHeightflight)). // Note: this assumes the root part is on the top of the ship.
	
	
	Print "end of parameters".
}/////End of function

	
	