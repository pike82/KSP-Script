
{ // Start of anon

///// Download Dependant libraies
local Staging is import("Staging").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
local launch_atm is lex(
	"preLaunch", ff_preLaunch@,
	"liftoff", ff_liftoff@,
	"liftoffclimb", ff_liftoffclimb@,
	"GravityTurn1", ff_GravityTurn1@,
	"GravityTurn2", ff_GravityTurn2@,
	"Insertion1", ff_Insertion1@,
	"Insertion2", ff_Insertion2@,
	"Insertion3", ff_Insertion3@
).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////	
	
Function ff_preLaunch {
	//TODO: Make gimble limits work.
	Wait 1. //Alow Veriables to be set and Stabilise pre launch
	PRINT "Prelaunch.".
	Lock Throttle to gl_TVALMax.
	
	SET StageNo TO STAGE:NUMBER. //Get the Current Stage Number which contains the Main Engines

	LOCK STEERING TO HEADING(90, 90). //this is locked 90,90 only until the clamps are relased

	//Set the Gimbal limit for engines where possible
	LIST ENGINES IN engList. //Get List of Engines in the vessel
	FOR eng IN engList {  //Loops through Engines in the Vessel
		IF eng:STAGE = StageNo { //Check to see if the engine is in the current Stage
			IF eng:HASGIMBAL{ //Check to see if it has a gimbal
				SET eng:GIMBAL:LIMIT TO gimbalLimit. //if it has a gimbal set the gimbal limit
			}
		}
	}
	} /// End Function	
		
/////////////////////////////////////////////////////////////////////////////////////	
		
Function ff_liftoff{
	Print gl_TVALMax.
	STAGE. //Ignite main engines
	PRINT "Engines started.".
	WAIT 3. //Ensures engines are at full thrust
	Print gl_TVALMax.
	STAGE. // Relase Clamps
	PRINT "Lift off".
	LOCK STEERING TO HEADING(0, 90). // stops all rotation until clear of the tower
	
}/// End Function

/////////////////////////////////////////////////////////////////////////////////////	

Function ff_liftoffclimb{
	Print(SHIP:Q).
	local LchAlt is ALT:RADAR.
	Wait UNTIL ALT:RADAR > sv_ClearanceHeight + LchAlt.
	Print(SHIP:Q).
	LOCK STEERING TO HEADING(sv_intAzimith, 90).
	Wait UNTIL SHIP:Q > 0.015. //Ensure past clearance height and airspeed 0.018 equates to approx 50m/s or 1.5kpa which is high enough to ensure stability
	PRINT "Starting Pitchover".
	Print (SHIP:Q).
	LOCK STEERING TO HEADING(sv_intAzimith, sv_anglePitchover). //move to pitchover angle
	SET t0 to TIME:SECONDS.
	WAIT UNTIL (TIME:SECONDS - t0) > 5. //allows pitchover to stabilise
}// End of Function
	
/////////////////////////////////////////////////////////////////////////////////////		

///This gravity turn tries to hold the AoA to a predefined value
	
Function ff_GravityTurn1{	
	PARAMETER AoATarget is 0.0, Kp is 0.15, Ki is 0.35, Kd is 0.7, PID_Min is -0.1, PID_Max is 0.1. 
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
	
	UNTIL (SHIP:Apoapsis > sv_targetAltitude) {  //this will need to change so it is not hard set.
		Staging["Flameout"]().
		Staging["FAIRING"]().
		Staging["COMMS"]().

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
		Print PIDAngle:PTerm.
		Print PIDAngle:ITerm.
		Print PIDAngle:DTerm.
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
	
Function ff_GravityTurn2{	
Parameter waitPitch is 0.
Parameter targetApoeta is 120.

	SET fullySteeredAngle to 90 - waitPitch.
	SET atmpGround TO SHIP:SENSORS:PRES.
	//SET atmp_end to 0.

	LOCK altitude to ALT:RADAR.
	LOCK atmp to ship:sensors:pres.
	LOCK atmoDensity to atmp / atmpGround.
	LOCK gl_apoeta to max(0,ETA:APOAPSIS).

	LOCK firstPhasePitch to fullySteeredAngle - (fullySteeredAngle * atmoDensity).
	LOCK STEERING to HEADING(azimuth, 90 - firstPhasePitch).
	UNTIL gl_apoeta >= targetApoeta {
		Staging["Flameout"]().
		Staging["FAIRING"]().
		Staging["COMMS"]().
		set endTurnAltitude to altitude.
		set endRurnOrbitSpeed to SHIP:VELOCITY:ORBIT:MAG.
		set secondPhasePitch to firstPhasePitch.
	}
	UNLOCK firstPhasePitch.
	UNLOCK STEERING.
	UNLOCK atmoDensity.
	UNLOCK atmp.

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

} // End of Function

/////////////////////////////////////////////////////////////////////////////////////
	
Function ff_Insertion1{ // intended to keep a low AoA and coast to Ap allowing another function (hill climb in this case) to calculate the insertion burn
	
	LOCK STEERING TO HEADING(sv_intAzimith, 0). //move to pitchover angle
	Lock Throttle to 0.
	//Parameter coast_time is (apoEta-30).
	//Wait coast_time.
}// End of Function

/////////////////////////////////////////////////////////////////////////////////////
	
Function ff_Insertion2{ // to be worked on this function is intended to keep a constant ascent rate
	Set intTTapo to gl_apoEta.
	Set intdAlt to (sv_targetAltitude - SHIP:APOAPSIS).
	
	LOCK targetTTapo to (intTTapo * (max(1,(sv_targetAltitude - SHIP:APOAPSIS))/intdAlt)).
	Set highPitch to gravPitch.	///Intital setup
	
	SET Kp TO 0.3. //this needs to be pass through or predetermined via trial and error
	SET Ki TO 0.002. //this needs to be pass through or predetermined via trial and error
	SET Kd TO 12.0. //this needs to be pass through or predetermined via trial and error
	//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT). 13.135s and 1, trailing with 1 an 57.54,
	Set PIDAngle to PIDLOOP(Kp, Ki, Kd).//,-2.5,2.5).
	
	LOCK STEERING TO HEADING(sv_intAzimith, highPitch). //move to pitchover angle
	
	Set StartLogtime to TIME:SECONDS.
	//Log "# Time, # high pitch, # gl_apoEta, # dPitch, # PTerm , # ITerm , # DTerm" to Apo.csv.
	
	UNTIL (SHIP:APOAPSIS > sv_targetAltitude) And (SHIP:PERIAPSIS > sv_targetAltitude) OR (gl_apoEta > gl_perEta) OR (SHIP:APOAPSIS > sv_targetAltitude + 10000){
		Staging["Flameout"]().
		Staging["FAIRING"]().
		Staging["COMMS"]().

		Set PIDAngle:SETPOINT to targetTTapo.
		SET dPitch TO PIDAngle:UPDATE(TIME:SECONDS, apoEta).
		// you can also get the output value later from the PIDLoop object
		// SET OUT TO PID:OUTPUT.
		Set highPitch to max((-5+((targetTTapo/intTTapo)*2)), min((10*(targetTTapo/intTTapo))+5,(highPitch + dPitch))). //current pitch setting plus the change from the PID
		
		Clearscreen.
		
		Print (apoEta).
		Print (targetTTapo).
		Print (dPitch).
		Print (highPitch).
		Print (SHIP:Q).
		Print (TVAL).
		Print (TWRTarget).
		Print (TWR).
		Print (maxGeeTarget).
		Print (Ship:Verticalspeed).
		Print (intTTapo).
		Print (intdAlt).
		Print (PIDAngle:PTerm).
		Print (PIDAngle:ITerm).
		Print (PIDAngle:DTerm).
		Switch to 0.
		Log (TIME:SECONDS - StartLogtime) +","+ (highPitch) +","+(gl_apoEta) +","+ (dPitch) +","+ (PIDAngle:PTerm) +","+ (PIDAngle:ITerm) +","+ (PIDAngle:DTerm) to Apo.csv.
		Switch to 1.
		Wait 0.1.
	}	/// End of Until
Unlock targetTTapo.
}// End of Function

	
/////////////////////////////////////////////////////////////////////////////////////
	
Function ff_Insertion3{ // PEG Code

//instead of PEG look into keeping the Periapasis LatLong the same position via PID

}// End of Function
	

Function ff_Insertion4{ // PID Code stepping time to Apo

Set intdAlt to (sv_targetAltitude - SHIP:APOAPSIS).
Set TgtTtAPO to 45. ///Intital setup
Set highPitch to gl_pitchangle.	///Intital setup

SET Kp TO 0.3. //this needs to be pass through or predetermined via trial and error
SET Ki TO 0.002. //this needs to be pass through or predetermined via trial and error
SET Kd TO 12.0. //this needs to be pass through or predetermined via trial and error
//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT). 13.135s and 1, trailing with 1 an 57.54,
Set PIDAngle to PIDLOOP(Kp, Ki, Kd).//,-2.5,2.5).

LOCK STEERING TO HEADING(sv_intAzimith, highPitch). //move to pitchover angle

Set StartLogtime to TIME:SECONDS.
//Log "# Time, # high pitch, # gl_apoEta, # dPitch, # PTerm , # ITerm , # DTerm" to Apo.csv.

UNTIL (SHIP:APOAPSIS > sv_targetAltitude) And (SHIP:PERIAPSIS > sv_targetAltitude) OR (gl_apoEta > gl_perEta) OR (SHIP:APOAPSIS > sv_targetAltitude + 10000){
	
	Set PIDAngle:SETPOINT to TgtTtAPO.
	SET dPitch TO PIDAngle:UPDATE(TIME:SECONDS, gl_apoEta).
	// you can also get the output value later from the PIDLoop object
	// SET OUT TO PID:OUTPUT.
	Set highPitch to (highPitch + dPitch). //current pitch setting plus the change from the PID
	
	Clearscreen.
	
	Print (gl_apoEta).
	Print (tgtTtapo).
	Print (dPitch).
	Print (highPitch).
	Print (Ship:Verticalspeed).
	Print (intdAlt).
	Print (PIDAngle:PTerm).
	Print (PIDAngle:ITerm).
	Print (PIDAngle:DTerm).
	//Switch to 0.
	//Log (TIME:SECONDS - StartLogtime) +","+ (highPitch) +","+(gl_apoEta) +","+ (dPitch) +","+ (PIDAngle:PTerm) +","+ (PIDAngle:ITerm) +","+ (PIDAngle:DTerm) to Apo.csv.
	//Switch to 1.
	Wait 0.1.
}	/// End of Until
Unlock targetTTapo.

}// End of Function	
	
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

	
///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(launch_atm).
} // End of anon
