
//General Credits with ideas from the following:
// Kevin Gisi: http://youtube.com/gisikw
// KOS Community library
// https://github.com/KK4TEE/kOSPrecisionLand


///// Download Dependant libraies
FOR file IN LIST(
	"Flight",
	"Util_Vessel",
	"Util_Launch",
	"Util_Engine",
	"Util_Orbit"){ 
		//Method for if to download or download again.
		
		IF (not EXISTS ("1:/" + file)) or (not runMode["runMode"] = 0.1)  { //Want to ignore existing files within the first runmode.
			gf_DOWNLOAD("0:/Library/",file,file).
			wait 0.001.	
		}
		RUNPATH(file).
	}

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
// local launch_atm is lex(
	// "preLaunch", ff_preLaunch@,
	// "liftoff", ff_liftoff@,
	// "liftoffclimb", ff_liftoffclimb@,
	// "GravityTurnAoA", ff_GravityTurnAoA@,
	// "GravityTurnPres", ff_GravityTurnPres@,
	// "Coast", ff_Coast@,
	// "InsertionPIDSpeed", ff_InsertionPIDSpeed@,
	// "InsertionPEG", ff_InsertionPEG@
// ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////	
// Credit: Own recreated from ideas in mix of general	
Function ff_Vac_preLaunch {
	//TODO: Make gimble limits work.
	Wait 1. //Alow Variables to be set and Stabilise pre launch
	PRINT "Prelaunch.".
	Lock Throttle to gl_TVALMax().
	
	Print "Current Stage:" + STAGE:NUMBER.
	LOCK STEERING TO SHIP:UP:VECTOR.

	//Set the Gimbal limit for engines where possible
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList {  //Loops through Engines in the Vessel
		//IF eng:STAGE = STAGE:NUMBER { //Check to see if the engine is in the current Stage, Note this is only used if you want a specific stage gimbal limit, otherwise it is applied to all engines
			IF eng:HASGIMBAL{ //Check to see if it has a gimbal
				SET eng:GIMBAL:LIMIT TO sv_gimbalLimit. //if it has a gimbal set the gimbal limit
				Print "Gimbal Set".
			}
		//}
	}
} /// End Function	
		
/////////////////////////////////////////////////////////////////////////////////////	
// Credit: Own recreated from ideas in mix of general		
Function ff_vac_liftoff{
	
	STAGE. //Ignite main engines
	Set EngineStartTime to TIME:SECONDS.
	PRINT "Engines started.".
	
	Set MaxEngineThrust to 0. 
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList {  //Loops through Engines in the Vessel
		Print "eng:STAGE:" + eng:STAGE.
		Print STAGE:NUMBER.
		IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
			SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. 
			Print "Engine Thrust:" + MaxEngineThrust. 
		}
	}

	Set CurrEngineThrust to 0.
	
	until CurrEngineThrust = MaxEngineThrust or EngineStartTime +5 > TIME:SECONDS{ // until upto thrust or the engines have attempted to get upto thrust for more than 5 seconds.
		FOR eng IN engList {  //Loops through Engines in the Vessel
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				SET CurrEngineThrust TO CurrEngineThrust + eng:THRUST. //add thrust to overall thrust
			}
		}
		wait 0.01.
	}

	//TODO:Make and abort code incase an engine fails during the start up phase.
	if EngineStartTime + 0.75 > TIME:SECONDS {wait 0.75.} // this ensures time between staging engines and clamps so they do not end up being caught up in the same physics tick
	until Ship:Verticalspeed > 1{
		wait 0.1.
	}
	PRINT "Lift off".
	//TODO: change the lock steering to heading as the core part may not be rotated correctly. need to find a away to ensure current rotation is kept.
	LOCK STEERING TO SHIP:UP:VECTOR. //This should have been set previously but is done again for redundancy
	
}/// End Function

/////////////////////////////////////////////////////////////////////////////////////	
// Credit: Own recreated from ideas in mix of general
Function ff_vac_liftoffclimb{
	set twr to .....
	
	set launchangle to 
	
	
	
	Set Dist to 0.
	Set profiletime to 0.
	Set tgtPERad to tgtalt+body:radius.
	Set EndHorzVel to ff_CircOrbitVel(tgtalt).
	Set Horzvel to 0.
	Set StartMass to (ship:mass * 1000).
	
	until Horzvel >= EndHorzVel {//run the iteration until the velocity is at orbital velocity
		Set StartMass to StartMass - ff_mdot().
		Set acc to (ship:availablethrust* 1000)/(StartMass). //the acceleration of the ship in one second
		
		Set GravCancel to ((body:mu/(tgtPERad^2)) - ((Horzvel^2)/tgtPERad))/acc. //portion of vehicle acceleration used to counteract gravity as per PEG ascent guidance formula in one second
		
		Set Horzvel to Horzvel + abs(acc - GravCancel). // current horz velocity plus the acceleration in the horizontal direction.
		Set dist to dist + Horzvel.
		Set profiletime to profiletime + 1.
		Clearscreen.
		Print acc.
		Print GravCancel.
		Print Horzvel.
		Print dist.
		Print profiletime.
		wait 0.01.
	}
	
	Set TgtVert Velocity to alt/profiletime.
	PRINT "Starting Pitchover".
	LOCK STEERING TO HEADING(sv_intAzimith, sv_anglePitchover). //move to pitchover angle
	SET t0 to TIME:SECONDS.
	WAIT UNTIL (TIME:SECONDS - t0) > 5. //allows pitchover to stabilise
}// End of Function
	
/////////////////////////////////////////////////////////////////////////////////////
// Credit: Own recreated from ideas in mix of general
Function ff_InsertionPIDSpeed{ // PID Code stepping time to Apo. Note this can only attempt to launch into a circular orbit
PARAMETER 	ApTarget, ullage is "RCS", Kp is 0.3, Ki is 0.0002, Kd is 12, PID_Min is -0.1, PID_Max is 0.1, 
			vKp is -0.01, vKi is 0.0002, vKd is 12, vPID_Min is -10, vPID_Max is 1000.
	
	//TODOD: Find out the desired velocity of the AP Target and make this the desired velocity and have the loop cut out when the desired velocity is reached.
	
	Set highPitch to 30.	///Intital setup TODO: change this to reflect the current pitch
	LOCK STEERING TO HEADING(sv_intAzimith, highPitch). //move to pitchover angle
	Set PIDALT to PIDLOOP(vKp/((ship:maxthrust/ship:mass)^2), vKi, vKd, vPID_Min, vPID_Max). // used to create a vertical speed
	Set PIDALT:SETPOINT to 0. // What the altitude difference to be zero
	//TODO: Look into making the vertical speed also dependant of the TWR as low thrust upper stages may want to keep a higher initial vertical speed.
	
	Set PIDAngle to PIDLOOP(Kp, Ki, Kd, PID_Min, PID_Max). // used to find a desired pitch angle from the vertical speed. 
		
	
	UNTIL ((SHIP:APOAPSIS > sv_targetAltitude) And (SHIP:PERIAPSIS > sv_targetAltitude))  OR (SHIP:APOAPSIS > sv_targetAltitude*1.1){
		ff_Flameout(ullage).
		ff_FAIRING().
		ff_COMMS().
		
		Set PIDALT:KP to vKp/((ship:maxthrust/ship:mass)^2). //adjust the kp values and therefore desired vertical speed based on the TWR^2
		
		SET ALTSpeed TO PIDALT:UPDATE(TIME:SECONDS, ApTarget-ship:altitude). //update the PID with the altitude difference
		Set PIDAngle:SETPOINT to ALTSpeed. // Sets the desired vertical speed for input into the pitch
		
		SET dPitch TO PIDAngle:UPDATE(TIME:SECONDS, Ship:Verticalspeed). //used to find the change in pitch required to obtain the desired vertical speed.
		Set highPitch to (highPitch + dPitch). //current pitch setting plus the change from the PID
		
		Clearscreen.
		
		Print "Time to AP:" + (gl_apoEta).
		Print "Desired Vertical Speed:" + (ALTSpeed).		
		Print "Current Vertical Speed:" + (Ship:Verticalspeed).
		Print "Pitch Correction:" + (dPitch).
		Print "Desired pitch:" + (highPitch).
		Print "PIDAngle:PTerm:"+ (PIDAngle:PTerm).
		Print "PIDAngle:ITerm:"+ (PIDAngle:ITerm).
		Print "PIDAngle:DTerm:"+ (PIDAngle:DTerm).
		Print "PIDAlt:PTerm:"+ (PIDAlt:PTerm).
		Print "PIDAlt:ITerm:"+ (PIDAlt:ITerm).
		Print "PIDAlt:DTerm:"+ (PIDAlt:DTerm).
		//Switch to 0.
		//Log (TIME:SECONDS - StartLogtime) +","+ (highPitch) +","+(gl_apoEta) +","+ (dPitch) +","+ (PIDAngle:PTerm) +","+ (PIDAngle:ITerm) +","+ (PIDAngle:DTerm) to Apo.csv.
		//Switch to 1.
		Wait 0.1.
	}	/// End of Until
	//TODO: Create code to enable this to allow for a different AP to PE as required, rather than just circularisation at AP.
	Unlock STEERING.
	LOCK Throttle to 0.

}// End of Function	
	

