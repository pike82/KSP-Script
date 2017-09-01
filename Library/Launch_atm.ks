
{ // Start of anon

///// Download Dependant libraies
local Util_Engine is import("Util_Engine").
local Util_Vessel is import("Util_Vessel").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
local launch_atm is lex(
	"preLaunch", ff_preLaunch@,
	"liftoff", ff_liftoff@,
	"liftoffclimb", ff_liftoffclimb@,
	"GravityTurnAoA", ff_GravityTurnAoA@,
	"GravityTurnPres", ff_GravityTurnPres@,
	"Coast", ff_Coast@,
	"InsertionPIDSpeed", ff_InsertionPIDSpeed@,
	"InsertionPEG", ff_InsertionPEG@
).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////	
	
Function ff_preLaunch {
	//TODO: Make gimble limits work.
	Wait 1. //Alow Veriables to be set and Stabilise pre launch
	PRINT "Prelaunch.".
	Lock Throttle to gl_TVALMax.
	
	Print "Current Stage:" + STAGE:NUMBER.
	LOCK STEERING TO HEADING(90, 90). //this is locked 90,90 only until the clamps are relased

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
		
Function ff_liftoff{
	Print gl_TVALMax.
	
	STAGE. //Ignite main engines
	Set EngineStartTime to TIME:SECONDS.
	PRINT "Engines started.".
	
	Set MaxEngineThrust to 0. 
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList {  //Loops through Engines in the Vessel
		Print "eng:STAGE:" + eng:STAGE.
		Print STAGE:NUMBER.
		IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
			SET MaxEngineThrust TO MaxEngineThrust + eng:MAXTHRUST. //if it has a gimbal set the gimbal limit
			Print "Engine Thrust:" + MaxEngineThrust. 
		}
	}

	Print gl_TVALMax.
	Set CurrEngineThrust to 0.
	
	until CurrEngineThrust = MaxEngineThrust or EngineStartTime +5 > TIME:SECONDS{ // until upto thrust or the engines have attempted to get upto thrust for more than 5 seconds.
		FOR eng IN engList {  //Loops through Engines in the Vessel
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				SET CurrEngineThrust TO CurrEngineThrust + eng:THRUST. //if it has a gimbal set the gimbal limit
			}
		}
		wait 0.01.
	}
	// Print CurrEngineThrust.
	// Print MaxEngineThrust.
	// Print EngineStartTime.
	// Print TIME:SECONDS.

	//TODO:Make and abort code incase an engine fails during the start up phase.
	if EngineStartTime + 0.75 > TIME:SECONDS {wait 0.75.} // this ensures time between staging engines and clamps so they do not end up being caught up in the same physics tick
	STAGE. // Relase Clamps
	PRINT "Lift off".
	LOCK STEERING TO HEADING(0, 90). // stops all rotation until clear of the tower. This should have been set previously but is done again for redundancy
	
}/// End Function

/////////////////////////////////////////////////////////////////////////////////////	

Function ff_liftoffclimb{
	//Print(SHIP:Q).
	local LchAlt is ALT:RADAR.
	Wait UNTIL ALT:RADAR > sv_ClearanceHeight + LchAlt.
	//Print(SHIP:Q).
	LOCK STEERING TO HEADING(sv_intAzimith, 90).
	Wait UNTIL SHIP:Q > 0.015. //Ensure past clearance height and airspeed 0.018 equates to approx 50m/s or 1.5kpa which is high enough to ensure aero stability for most craft small pitching
	PRINT "Starting Pitchover".
	//Print (SHIP:Q).
	LOCK STEERING TO HEADING(sv_intAzimith, sv_anglePitchover). //move to pitchover angle
	SET t0 to TIME:SECONDS.
	WAIT UNTIL (TIME:SECONDS - t0) > 5. //allows pitchover to stabilise
}// End of Function
	
/////////////////////////////////////////////////////////////////////////////////////		

///This gravity turn tries to hold the AoA to a predefined value
	
Function ff_GravityTurnAoA{	
	PARAMETER AoATarget is 0.0, Flametime is 1.0, Kp is 0.15, Ki is 0.35, Kd is 0.7, PID_Min is -0.1, PID_Max is 0.1. 
	// General rule of thumb, set first stage dV to around 1700 - 1900 for Kerbin. Set the target AoA to (-(TWR^2))+1 ie. 1.51 = -1.25	
	Set dPitch to 0.
	Set MaxQ to 0.
	Set gravPitch to sv_anglePitchover.	///Intital setup
	LOCK STEERING TO HEADING(sv_intAzimith, gravPitch). //move to pitchover angle
	
	//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT). 0.7 and 2.72s
	Set PIDAngle to PIDLOOP(Kp, Ki, Kd,PID_Min,PID_Max).
	Set PIDAngle:SETPOINT to AoATarget.
	Set StartLogtime to TIME:SECONDS.
	//Log "# Time, # grav pitch, # AoA, # dPitch, # PTerm , # ITerm , # DTerm" to AOA.csv.
	
	UNTIL (SHIP:Q < MaxQ*0.1) {  //this will need to change so it is not hard set.
		Util_Engine["Flameout"](Flametime).
		Util_Vessel["FAIRING"]().
		Util_Vessel["COMMS"]().

		SET dPitch TO PIDAngle:UPDATE(TIME:SECONDS, gl_AoA).
		// you can also get the output value later from the PIDLoop object
		// SET OUT TO PID:OUTPUT.
		Set gravPitch to max(min(sv_anglePitchover,(gravPitch + dPitch)),0). //current pitch setting plus the change from the PID
		if SHIP:Q > MaxQ {
			Set MaxQ to SHIP:Q.
		}
		Clearscreen.
		Print "AOA: "+(gl_AoA).
		Print "Delta Pitch: "+(dPitch).
		Print "Setpoint Pitch: "+(gravPitch).
		Print "Q: "+(SHIP:Q).
		Print "Max Q: "+(MaxQ).
		Print "Stage: "+(STAGE:NUMBER).
		Print "TWR: "+(gl_TWR).
		Print "TWRTarget: "+(gl_TWRTarget).
		Print "Max G: "+(sv_maxGeeTarget).
		Print "Throttle Setting: "+(gl_TVALMax).
		Print PIDAngle:PTerm. //For determining the Correct PID Values
		Print PIDAngle:ITerm. //For determining the Correct PID Values
		Print PIDAngle:DTerm. //For determining the Correct PID Values
		//PID Log for tuning
		// Switch to 0.
		// Log (TIME:SECONDS - StartLogtime) +","+ (gravPitch) +","+(gl_AoA) +","+ (dPitch) +","+ (PIDAngle:PTerm) +","+ (PIDAngle:ITerm) +","+ (PIDAngle:DTerm) to AOA.csv.
		// Switch to 1.
		//End PID Log loop
		Wait 0.05.
	}	/// End of Until
} // End of Function

/////////////////////////////////////////////////////////////////////////////////////	

//This gravity turn is a work in progress however it it intended to follow a predefined path based on the ratio of atmospheric pressure  
	
Function ff_GravityTurnPres{
	PARAMETER PresMultiple is 1.0.	
	
	Set MaxQ to 0.
	Set gravPitch to sv_anglePitchover.	///Intital setup
	LOCK STEERING TO HEADING(sv_intAzimith, gravPitch). //move to pitchover angle
	SET ATMPGround TO SHIP:SENSORS:PRES.
	
	SET fullySteeredAngle to 90 - waitPitch.
	LOCK atmp to ship:sensors:pres.
	LOCK atmoDensity to atmp / atmpGround.

	LOCK firstPhasePitch to (gravPitch * atmoDensity).
	LOCK STEERING to HEADING(azimuth, firstPhasePitch).
	UNTIL SHIP:Apoapsis > sv_targetAltitude {
		Util_Engine["Flameout"]().
		Util_Vessel["FAIRING"]().
		Util_Vessel["COMMS"]().
	}
	UNLOCK firstPhasePitch.
	UNLOCK atmoDensity.
	UNLOCK atmp.

} // End of Function

/////////////////////////////////////////////////////////////////////////////////////
	
Function ff_Coast{ // intended to keep a low AoA and coast to Ap allowing another function (hill climb in this case) to calculate the insertion burn

	LOCK STEERING TO ship:facing:vector. //maintain current alignment
	LOCK Throttle to 0.

}// End of Function

/////////////////////////////////////////////////////////////////////////////////////

Function ff_InsertionPIDSpeed{ // PID Code stepping time to Apo
PARAMETER 	ApTarget, Kp is 0.3, Ki is 0.0002, Kd is 12, PID_Min is -0.1, PID_Max is 0.1, 
			vKp is -0.01, vKi is 0.0002, vKd is 12, vPID_Min is -10, vPID_Max is 1000.
	
	Set highPitch to 30.	///Intital setup TODO: change this to reflect the current pitch
	LOCK STEERING TO HEADING(sv_intAzimith, highPitch). //move to pitchover angle
	Set PIDALT to PIDLOOP(vKp, vKi, vKd, vPID_Min, vPID_Max). // used to create a vertical speed
	Set PIDALT:SETPOINT to 0. // What the altitude difference to be zero
	//TODO: Look into making the vertical speed also dependant of the TWR as low thrust upper stages may want to keep a higher initial vertical speed.
	
	Set PIDAngle to PIDLOOP(Kp, Ki, Kd, PID_Min, PID_Max). // used to find a desired pitch angle from the vertical speed
	
	UNTIL ((SHIP:APOAPSIS > sv_targetAltitude) And (SHIP:PERIAPSIS > sv_targetAltitude))  OR (SHIP:APOAPSIS > sv_targetAltitude*1.1){
		Util_Engine["Flameout"](1, 0.01).
		Util_Vessel["FAIRING"]().
		Util_Vessel["COMMS"]().
		
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
	

/////////////////////////////////////////////////////////////////////////////////////
	
Function ff_InsertionPEG{ // PEG Code



}// End of Function
	

/////////////////////////////////////////////////////////////////////////////////////
	
Function ff_Insertion5{ // PID Code stepping time to Apo

 LOCAL AZMPID IS PIDLOOP(0.1,0,0.05,-1, 1).
    SET AZMPID:SETPOINT TO Tincl.

    LOCAL FPAPID IS PIDLOOP(0.1,0.05,0.05,-1, 1).
    SET FPAPID:SETPOINT TO Tperg.

    LOCAL ROLLPID IS PIDLOOP(0.1,0,0.01,-1, 1).
    SET ROLLPID:SETPOINT TO 0.
    PRINT "INITIATING SECOND STAGE CLOSED LOOP CONTROL...". WAIT 2.
    PRINT "SECOND STAGE IGNITION.".
    STAGE.
    UNLOCK STEERING.
    UNTIL SHIP:MAXTHRUST = 0 {
		SET FPAPID:SETPOINT TO altitude / 50000. // this change the setpoint at every loop 
	
        SET SHIP:CONTROL:YAW   TO AZMPID:UPDATE(TIME:SECONDS, SHIP:INCLINATION).
        SET SHIP:CONTROL:PITCH TO FPAPID:UPDATE(TIME:SECONDS, SHIP:APOAPSIS).
        SET SHIP:CONTROL:ROLL  TO ROLLPID:UPDATE(TIME:SECONDS, SHIP:FACING:ROLL).
        WAIT 0.01.
    }

}// End of Function	



	// Parameter waitPitch is 0.
	// Parameter targetApoeta is 120.

	// SET fullySteeredAngle to 90 - waitPitch.
	// SET ATMPGround TO SHIP:SENSORS:PRES.
	// //SET atmp_end to 0.

	// LOCK altitude to ALT:RADAR.
	// LOCK atmp to ship:sensors:pres.
	// LOCK atmoDensity to atmp / atmpGround.
	// LOCK gl_apoeta to max(0,ETA:APOAPSIS).

	// LOCK firstPhasePitch to fullySteeredAngle - (fullySteeredAngle * atmoDensity).
	// LOCK STEERING to HEADING(azimuth, 90 - firstPhasePitch).
	// UNTIL gl_apoeta >= targetApoeta {
		// Staging["Flameout"]().
		// Staging["FAIRING"]().
		// Staging["COMMS"]().
		// set endTurnAltitude to altitude.
		// set endRurnOrbitSpeed to SHIP:VELOCITY:ORBIT:MAG.
		// set secondPhasePitch to firstPhasePitch.
	// }
	// UNLOCK firstPhasePitch.
	// UNLOCK STEERING.
	// UNLOCK atmoDensity.
	// UNLOCK atmp.

//This is a possible insertion code to be looked at in the future.
	
	// SET atmoEndAltitude to 110000.
	// SET tolerance to targetApoeta * 0.5.
	// LOCK shipAngle to VANG(SHIP:UP:VECTOR, SHIP:SRFPROGRADE:VECTOR).
	// LOCK correctiondAmp to (altitude - endTurnAltitude) / (atmoEndAltitude - endTurnAltitude).
	// LOCK mx to shipAngle + (maxCorrection * correctiondAmp).
	// LOCK mi to shipAngle - (maxCorrection * correctiondAmp).
	// LOCK orbitSpeedFactor to ((targetOrbitSpeed - SHIP:VELOCITY:ORBIT:MAG) / (targetOrbitSpeed - endRurnOrbitSpeed)).
	// LOCK tApoEta to targetApoeta * orbitSpeedFactor. 
	// SET ae to 0.
	// LOCK correction to max(-maxCorrection*0.3,((tApoEta - ae) / tolerance) * maxCorrection).
	// LOCK secondPhasePitch to max(mi,min(mx, shipAngle - correction )).
	// LOCK STEERING to HEADING(azimuth, 90 - secondPhasePitch).

//} // End of Function
	
///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(launch_atm).
} // End of anon
