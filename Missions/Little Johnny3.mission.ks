Print ("Intilising other CPU's").

Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 1000.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script such as a suicide landing script which may require upto 1500
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
intParameters().

PRINT ("Downloading libraries").
//download dependant libraries first
	local Util_Vessel is import("Util_Vessel").
	local Util_Launch is import("Util_Launch").
	local Launch_atm is import("Launch_atm").
	local landing_atm is import("landing_atm").

Print gl_surfaceElevation.
Print gl_baseALTRADAR.

Rel_Parameters(). 	

Print "debug".

Function Mission_runModes{
		
	if runMode["runMode"] = 0.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch_atm["preLaunch"]().
		Launch_atm["liftoff"]().
		gf_set_runmode("runMode",1.1).
	}	

	else if runMode["runMode"] = 1.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Launch_atm["liftoffclimb"]() .
		
		until ship:apoapsis >sv_targetAltitude{
			wait 0.01.
		}
		lock throttle to 0.
		until gl_baseALTRADAR > 40000 or ship:VERTICALSPEED < 0{
			Wait 0.1.
		}
		Util_Vessel["collect_science"]().
		until ship:VERTICALSPEED < 0{
			Wait 0.1.
		}
		gf_set_runmode("runMode",2.1).
	}	
	
	else if runMode["runMode"] = 2.1 { 
		Print "Run mode is:" + runMode["runMode"].
		landing_atm["Reentry"](15000, 700, 300).
		landing_atm["ParaLand"](10000).
		gf_set_runmode("runMode",3.1).
		wait 1000.
	}	
} /// end of function runmodes

Function intParameters {
	///////////////////////
	//Ship Particualrs
	//////////////////////
	Global sv_maxGeeTarget to 4.  //max G force to be experienced

	Global sv_shipHeightflight to 4.1. // the height of the ship from the ground to the ship base part
	Global sv_gimbalLimit to 10. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Global sv_MaxQLimit to 0.3. //0.3 is the Equivalent of 40Kpa Shuttle was 30kps and others like mercury were 40kPa.
	
	///////////////////////
	//Ship Variable Inital Launch Parameters
	///////////////////////
 	Global sv_targetInclination to 180. //Desired Inclination
    Global sv_targetAltitude to 75000. //Desired Orbit Altitude from Sea Level
    Global sv_ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Global sv_anglePitchover to 78. //Final Pitchover angle
	Global sv_landingtargetLATLNG to latlng(-0.0972092543643722, -74.557706433623). // This is for KSC but use target:geoposition if there is a specific target vessel on the surface that can be used.
	Global sv_prevMaxThrust to 0. //used to set up for the flameout function
	
	//////////////////////////////////////////
	///Ship PID Control variables//////////////////
	/////////////////////////////////////////
	
//===ALTITUDE====
	//Desired vertical speed
	Global sv_PIDALT to PIDLOOP(0.9, 0.0, 0.0005, -5, 10).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired throttle setting
	Global sv_PIDThrott to PIDLOOP(0.1, 0.2, 0.005, 0.05, 1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LATITUDE (North) ====
	//Desired velocity
	Global sv_PIDLAT to PIDLOOP(1, 0.0, 5, -0.005, 0.005).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired direction
	Global sv_PIDNorth to PIDLOOP(5000, 0, 2000, -2.5, 2.5).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LONGITUDE (East)====
	//Desired velocity
	Global sv_PIDLONG to PIDLOOP(1, 0, 5, -0.005, 0.005).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).			
	//Desired direction	 
	Global sv_PIDEast to PIDLOOP(5000, 0, 2000, -2.5, 2.5).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===Direction ====
	//Desired velocity
	Global sv_PIDDIST to PIDLOOP(0.1, 0, 0.5, -2, 2).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).			
	//Desired direction	 
	Global sv_PIDDIR to PIDLOOP(1.5, 0, 0, -2.5, 2.5).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	
	///////////////////////
	//Global Locked Parameters
	//////////////////////
//Locations	
	lock gl_shipLatLng to SHIP:GEOPOSITION. // provides the current co-ordiantes
	lock gl_surfaceElevation to gl_shipLatLng:TERRAINHEIGHT. // provides the height at the current co-ordinates
	lock gl_baseALTRADAR to max( 0.1, min(ship:Altitude , ship:Altitude - gl_surfaceElevation - sv_shipHeightflight)). // Note: this assumes the root part is on the top of the ship.
		
	Print "end of parameters".
}/////End of function

Function Rel_Parameters {

	Global sv_intAzimith TO Util_Launch ["LaunchAzimuth"](sv_targetInclination,sv_targetAltitude).

//Engines 
	Lock gl_Grav to Util_Vessel["Gravity"]().
    Lock gl_TWR to MAX( 0.001, MAXTHRUST / (ship:MASS*gl_Grav["G"])). //Provides the current thrust to weight ratio
	Lock gl_TWRTarget to min( gl_TWR, sv_maxGeeTarget*(9.81/gl_Grav["G"])). // enables the trust to be limited based on the TWR which is dependant on the local gravity compared to normal G forces
	Lock gl_TVALMax to min(
							gl_TWRTarget/gl_TWR, 
							sv_MaxQLimit / max(0.01,SHIP:Q)
							). //use this to set the Max throttle as the TWR changes with time or the ship reaches max Q for throttleable engines.
	//Lock Throttle to gl_TVALMax. // this is the command that will need to be used in individual functions when re-setting the throttle after making the throttle zero.

	Print "end of Rel parameters".
}/////End of function
	
	