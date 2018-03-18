Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 1000.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script such as a suicide landing script which may require upto 1500
Print "New Config:IPU Setting:" + Config:IPU.
Set Config:Stat to false.
	
intParameters().

PRINT ("Downloading libraries").
//download dependant libraries first

FOR file IN LIST(
	"Util_Launch",
	"Launch_atm",
	"OrbMnvs",
	"Landing_atm",
	"Util_Vessel"){ 
		//Method for if to download or download again.
		IF (not EXISTS ("1:/" + file)) or (not runMode["runMode"] = 0.1)  { //Want to ignore existing files within the first runmode.
			gf_DOWNLOAD("0:/Library/",file,file).
			wait 0.001.	
		}
		RUNPATH(file).
	} 
Rel_Parameters(). 	

Function Mission_runModes{
 //TODO: Look at implimenting a Flight readout script like the KOS-Stuff_master gravity file for possible implimentation.

	if runMode["runMode"] = 0.1 { 
		Print "Run mode is:" + runMode["runMode"].
		ff_Multi_CPU_Boot_Load().
		wait 5. // ensure above mesage process has finished
		ff_preLaunch().
		ff_liftoff().
		gf_set_runmode("runMode",1.1).
	}	

	else if runMode["runMode"] = 1.1 { 
		Print "Run mode is:" + runMode["runMode"].
		ff_liftoffclimb() .
		ff_GravityTurnAoA(-3.5, "RCS", 1, 0.005).
		ff_Coast().
		Print "Free CPU Space: " + core:currentvolume:FreeSpace.
		ff_COMMS("deactivate").
		RCS off.
		lock throttle to 0.
		Print ship:orbit:semimajoraxis.
		Print ship:orbit:eccentricity.
		local tar_per is ff_Obit_sync (ff_OrbPer(sv_targetAltitude+body:radius), 4, sv_targetAltitude).
		Local True_Anom is ff_TAr (sv_targetAltitude+body:radius, ship:orbit:semimajoraxis, ship:orbit:eccentricity). // full orbital radius, Semimajoraxis, eccentricity.)
		Print "Adjustment TA: " + True_Anom.
		local TA_from_PE is ff_timeFromTA((True_Anom), ship:orbit:eccentricity).//*constant:DegToRad
		Print "Adjustment TA_from_PE: " + TA_from_PE.
		local next_apo is time:seconds + TA_from_PE.
		Print "Adjustment Time: " + next_apo.
		Print "Target Periapsis: " + tar_per.
		Print "Target Perod: " + ff_OrbPer(sv_targetAltitude+body:radius).
		Print "Target Ecc Orbit Period:" + ff_OrbPer(((sv_targetAltitude+body:radius) +(tar_per+body:radius))/2 ).
		ff_adjeccorbit (sv_targetAltitude, tar_per, next_apo-90, 10).
		RCS off.
		ff_COMMS("deactivate").
		Lock Steering to Ship:Prograde + R(90,0,0).
		Print "Preparing Deployment".
		gf_set_runmode("runMode",1.2).
		ff_COMMS().
	}
	
	else if runMode["runMode"] = 1.2{
		Local i is 1.

		If ADDONS:Available("KAC") {		  // if KAC installed	  
			Set ALM to ADDALARM ("Maneuver", time:seconds + ETA:APOAPSIS -280, SHIP:NAME ,"").// creates a KAC alarm 3 mins prior to the manevour node ADDALARM(AlarmType, UT, Name, Notes)
		}
		Until 180 > ETA:APOAPSIS {
			wait 1.
		}
		ff_CPU_Send_Msg("Omnisat16."+i, "Start").
		wait 2.
		Stage.
		gf_set_runmode("runMode",1.3).
		Print "Comsat "+i+" released.".
		Wait 200. // to allow apoapsis to pass and 180 < ETA:APOAPSIS for the next loop
	}	
	
	else if runMode["runMode"] = 1.3{
		Local i is 2.
		Lock Steering to Ship:Prograde + R(90,0,0).
		If ADDONS:Available("KAC") {		  // if KAC installed	  
			Set ALM to ADDALARM ("Maneuver", time:seconds + ETA:APOAPSIS -280, SHIP:NAME ,"").// creates a KAC alarm 3 mins prior to the manevour node ADDALARM(AlarmType, UT, Name, Notes)
		}
		Until 180 > ETA:APOAPSIS {
			wait 1.
		}
		ff_CPU_Send_Msg("Omnisat16."+i, "Start").
		wait 2.
		Stage.
		gf_set_runmode("runMode",1.4).
		Print "Comsat "+i+" released.".
		Wait 200. // to allow apoapsis to pass and 180 < ETA:APOAPSIS for the next loop
	}	
	
		else if runMode["runMode"] = 1.4{
		Local i is 3.
		Lock Steering to Ship:Prograde + R(90,0,0).
		If ADDONS:Available("KAC") {		  // if KAC installed	  
			Set ALM to ADDALARM ("Maneuver", time:seconds + ETA:APOAPSIS -280, SHIP:NAME ,"").// creates a KAC alarm 3 mins prior to the manevour node ADDALARM(AlarmType, UT, Name, Notes)
		}
		Until 180 > ETA:APOAPSIS {
			wait 1.
		}
		ff_CPU_Send_Msg("Omnisat16."+i, "Start").
		wait 2.
		Stage.
		gf_set_runmode("runMode",1.5).
		Print "Comsat "+i+" released.".
		Wait 200. // to allow apoapsis to pass and 180 < ETA:APOAPSIS for the next loop
	}	
	
		else if runMode["runMode"] = 1.5{
		Local i is 4.

		Lock Steering to Ship:Prograde + R(90,0,0).
		If ADDONS:Available("KAC") {		  // if KAC installed	  
			Set ALM to ADDALARM ("Maneuver", time:seconds + ETA:APOAPSIS -280, SHIP:NAME ,"").// creates a KAC alarm 3 mins prior to the manevour node ADDALARM(AlarmType, UT, Name, Notes)
		}
		Until 180 > ETA:APOAPSIS {
			wait 1.
		}
		ff_CPU_Send_Msg("Omnisat16."+i, "Start").
		wait 2.
		Stage.
		gf_set_runmode("runMode",2.1).
		Print "Comsat "+i+" released.".
		Wait 200. // to allow apoapsis to pass and 180 < ETA:APOAPSIS for the next loop
	}	
	
	else if runMode["runMode"] = 2.1 { 
		Lock Steering to Ship:Prograde + R(90,0,0).
		Until 240 > ETA:APOAPSIS {
			wait 3.
		}
		lock steering to ship:retrograde.
		until 10 > ETA:APOAPSIS {
			Wait 0.1.
		}
		ff_DO_Burn().
		Lock Steering to Ship:Prograde + R(90,0,0).
		Until 200 > ETA:Periapsis {
			wait 3.
		}
		ff_Reentry(15000,900,400).
		ff_ParaLand().
		gf_set_runmode("runMode",0).
	}
	
} /// end of function runmodes

Function intParameters {
	///////////////////////
	//Ship Particualrs
	//////////////////////
	Global sv_maxGeeTarget to 4.5.  //max G force to be experienced

	Global sv_shipHeightflight to 4.1. // the height of the ship from the ground to the ship base part
	Global sv_gimbalLimit to 100. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Global sv_MaxQLimit to 0.3. //0.3 is the Equivalent of 40Kpa Shuttle was 30kps and others like mercury were 40kPa.
	
	///////////////////////
	//Ship Variable Inital Launch Parameters
	///////////////////////
 	Global sv_targetInclination to 0. //Desired Inclination
    Global sv_targetAltitude to 770000. //Desired Orbit Altitude from Sea Level
    Global sv_ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Global sv_anglePitchover to 75. //Final Pitchover angle
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
	If ship:STATUS = "PRELAUNCH"{
		global sv_intAzimith TO ff_LaunchAzimuth(sv_targetInclination,sv_targetAltitude).
	}

//Engines 
	Lock gl_Grav to ff_Gravity().
    Lock gl_TWR to MAX( 0.001, Ship:AvailableThrust / (ship:MASS*gl_Grav["G"])). //Provides the current thrust to weight ratio
	Lock gl_TWRTarget to min( gl_TWR, 
								(sv_maxGeeTarget*(9.81/gl_Grav["G"])*ship:mass)/Ship:AvailableThrust). // Provides the throttle fraction, enables the thrust to be limited based on the TWR which is dependant on the local gravity compared to normal G forces
	Lock gl_TVALMax to min(
							gl_TWRTarget, 
							(sv_MaxQLimit / max(0.01,SHIP:Q))^2
							). //use this to set the Max throttle as the TWR changes with time or the ship reaches max Q for throttleable engines.
	//Lock Throttle to gl_TVALMax. // this is the command that will need to be used in individual functions when re-setting the throttle after making the throttle zero.

	Print "end of Rel parameters".
}/////End of function
	
	