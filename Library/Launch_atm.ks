
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
Function ff_preLaunch {
	//TODO: Make gimble limits work.
	Wait 1. //Alow Variables to be set and Stabilise pre launch
	PRINT "Prelaunch.".
	Lock Throttle to gl_TVALMax().
	
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
// Credit: Own recreated from ideas in mix of general		
Function ff_liftoff{
	
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
	// Print CurrEngineThrust.
	// Print MaxEngineThrust.
	// Print EngineStartTime.
	// Print TIME:SECONDS.

	//TODO:Make and abort code incase an engine fails during the start up phase.
	Wait until Stage:Ready . // this ensures time between staging engines and clamps so they do not end up being caught up in the same physics tick
	STAGE. // Relase Clamps
	PRINT "Lift off".
	//TODO: change the lock steering to heading as the core part may not be rotated correctly. need to find a away to ensure current rotation is kept.
	LOCK STEERING TO HEADING(0, 90). // stops all rotation until clear of the tower. This should have been set previously but is done again for redundancy
	
}/// End Function

/////////////////////////////////////////////////////////////////////////////////////	
// Credit: Own recreated from ideas in mix of general
Function ff_liftoffclimb{
	//Print(SHIP:Q).
	local LchAlt is ALT:RADAR.
	Wait UNTIL ALT:RADAR > sv_ClearanceHeight + LchAlt.
	LOCK STEERING TO HEADING(sv_intAzimith, 90).
	//Print(SHIP:Q).
	Wait UNTIL SHIP:Q > 0.015. //Ensure past clearance height and airspeed 0.015 equates to approx 50m/s or 1.5kpa which is high enough to ensure aero stability for most craft small pitching	
	PRINT "Starting Pitchover".
	//Print (SHIP:Q).
	LOCK STEERING TO HEADING(sv_intAzimith, sv_anglePitchover). //move to pitchover angle
	SET t0 to TIME:SECONDS.
	WAIT UNTIL (TIME:SECONDS - t0) > 5. //allows pitchover to stabilise
}// End of Function
	
/////////////////////////////////////////////////////////////////////////////////////		

///This gravity turn tries to hold the AoA to a predefined value
// Credit: Own recreated from ideas in mix of general
Function ff_GravityTurnAoA{	
	PARAMETER AoATarget is 0.0, ullage is "RCS", Flametime is 1.0, EndFunc is 0.05, Kp is 0.15, Ki is 0.35, Kd is 0.7, PID_Min is -0.1, PID_Max is 0.1. 
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
	
	UNTIL (SHIP:Q < MaxQ*EndFunc) {
		Set Angles to ff_Angles().
		Set angofAttack to Angles["aoa"].

		SET dPitch TO PIDAngle:UPDATE(TIME:SECONDS,angofAttack).
		// you can also get the output value later from the PIDLoop object
		// SET OUT TO PID:OUTPUT.
		Set gravPitch to max(min(sv_anglePitchover,(gravPitch + dPitch)),0). //current pitch setting plus the change from the PID
		if SHIP:Q > MaxQ {
			Set MaxQ to SHIP:Q.
		}
		Clearscreen.
		ff_Flameout(ullage).
		ff_FAIRING().
		ff_COMMS().
		Print "AOA: "+ angofAttack.
		Print "AOA tgt: "+ AoATarget.
		Print "Delta Pitch: "+(dPitch).
		Print "Setpoint Pitch: "+(gravPitch).
		Print "Q: "+(SHIP:Q).
		Print "Max Q: "+(MaxQ).
		Print "Stage: "+(STAGE:NUMBER).
		Print "TWR: "+(gl_TWR()).
		Print "TWRTarget: "+(gl_TWRTarget()).
		Print "Max G: "+(sv_maxGeeTarget).
		Print "Throttle Setting: "+(gl_TVALMax()).
		//Print PIDAngle:PTerm. //For determining the Correct PID Values
		//Print PIDAngle:ITerm. //For determining the Correct PID Values
		//Print PIDAngle:DTerm. //For determining the Correct PID Values
		//PID Log for tuning
		// Switch to 0.
		// Log (TIME:SECONDS - StartLogtime) +","+ (gravPitch) +","+(gl_AoA) +","+ (dPitch) +","+ (PIDAngle:PTerm) +","+ (PIDAngle:ITerm) +","+ (PIDAngle:DTerm) to AOA.csv.
		// Switch to 1.
		//End PID Log loop
		Wait 0.1.
	}	/// End of Until
} // End of Function

/////////////////////////////////////////////////////////////////////////////////////	

//This gravity turn is a work in progress however it it intended to follow a predefined path based on the ratio of atmospheric pressure  
// Credit: Own recreated from ideas in mix of general	
Function ff_GravityTurnPres{
	PARAMETER PresMultiple is 0.25, ullage is "RCS".
	
	Set MaxQ to 0.
	Set intPitch to sv_anglePitchover.	///Intital setup
	LOCK STEERING TO HEADING(sv_intAzimith, intPitch). //move to pitchover angle
	SET ATMPGround TO SHIP:SENSORS:PRES.
	
	LOCK atmp to ship:sensors:pres.
	LOCK atmoDensity to (atmp / atmpGround) ^ PresMultiple.

	LOCK currPitch to (intPitch * atmoDensity).
	LOCK STEERING to HEADING(sv_intAzimith, currPitch).
	UNTIL SHIP:Apoapsis > sv_targetAltitude {
		Clearscreen.
		Print "Pitch: " + currPitch.
		Print "Pressure: " + atmp.
		Print "Pressure Ratio: " + atmoDensity.
		ff_Flameout(ullage).
		ff_FAIRING().
		ff_COMMS().
		wait 0.001.
	}
	wait 0.001.
	LOCK STEERING TO ship:facing:vector.
	UNLOCK currPitch.
	UNLOCK atmoDensity.
	UNLOCK atmp.
	LOCK Throttle to 0.
	RCS on.

	

} // End of Function

/////////////////////////////////////////////////////////////////////////////////////
// Credit: Own recreated from ideas in mix of general	
Function ff_Coast{ // intended to keep a low AoA and burn then coast to Ap allowing another function (hill climb in this case) to calculate the insertion burn
	Parameter ullage is "RCS".
	Print "Coasting Phase".
	LOCK STEERING TO ship:facing:vector. //maintain current alignment
	RCS on.
	UNTIL SHIP:Apoapsis > sv_targetAltitude {
		ff_Flameout(ullage).
		ff_FAIRING().
		ff_COMMS().
	}
	LOCK Throttle to 0.

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
	

/////////////////////////////////////////////////////////////////////////////////////
// Credits: Own modifications to:
// http://www.orbiterwiki.org/wiki/Powered_Explicit_Guidance
//With Large assisstance and corrections from:
// https://github.com/Noiredd/PEGAS
// https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/19660006073.pdf
// https://amyparent.com/post/automating-rocket-launches/
Function ff_InsertionPEG{ // PEG Code

parameter tgt_pe. //target periapsis
parameter tgt_ap. //target apoapsis
parameter tgt_inc. //target inclination
parameter u is 0. // target true anomaly in degrees(0 = insertion at Pe)
parameter ullage is "RCS".
    
    set ra to body:radius + tgt_ap. //full Ap
    set rp to body:radius + tgt_pe. //full pe
	Print "tgtra " + tgt_ap.
	Print "tgtrp " + tgt_pe.
	Print body:radius.
	Print "ra " + ra.
	Print "rp " + rp.

	//TODO: Look at replaceing some of the belwo with the Util Orbit Functions or including it in the Util orbit functions.
	
    local sma is (ra+rp)/2. //sma
    local ecc is (ra-rp)/(ra+rp). //eccentricity
    local vp is sqrt((2*body:mu*ra)/(rp*2*sma)).
	Print "vp " +vp.
    local rc is (sma*(1-ecc^2))/(1+ecc*cos(u)). // this is the target radius based on the desire true anomoly
    print "rc "+rc.
    local vc is sqrt((vp^2) + 2*body:mu*((1/rc)-(1/rp))). // this is the target velocity at the target radius
    print "vc "+vc.
    local uc is 90 - arcsin((rp*vp)/(rc*vc)).
    
    set tgt_r to rc.
    set tgt_vy to vc*sin(uc). // this is the split of the target velocity at the point in time
    set tgt_vx to vc*cos(uc). // this is the split of the target velocity at the point in time
    
    set tgt_h to vcrs(v(tgt_r, 0, 0), v(tgt_vy, tgt_vx, 0)):mag.

    Print "PEG convergence enabled".
    
    local last is missiontime. //missiontime is a KOS variable which gets this ingame Misson elased time for the craft
    local A is 0. //peg variable
    local B is 0. //peg variable
    local C is 0. //peg variable
    local converged is -10.
    local delta is 0. //time between peg loops
	local T is 100. //intial guess on time to thrust cut off
	local peg_step is 0.1.
    
    local s_r is ship:orbit:body:distance.
    //local s_acc tis ship:sensors:acc:mag.
    local s_acc is ship:AVAILABLETHRUST/ship:mass.
	Print "s_acc " + s_acc.
    local s_vy is ship:verticalspeed.
    local s_vx is sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
	
	local s_ve is Util_Engine["Vel_Exhaust"]().
	local tau is s_ve/s_acc.
	
    local peg is hf_peg_cycle(A, B, T, peg_step, tau, tgt_vy, tgt_vx, tgt_r, s_vy, s_vx, s_r, s_acc).  // inital run through the cycle with first estimations
    wait 0.001.
    Print "Entering Convergence loop".
	//Loop through updating the parameters until the break condition is met
    until false {
        
        set s_r to ship:orbit:body:distance.
		//set s_acc to ship:sensors:acc:mag.
		set s_acc to ship:AVAILABLETHRUST/ship:mass.
		set s_vy to ship:verticalspeed.
		set s_vx to sqrt(ship:velocity:orbit:sqrmagnitude - ship:verticalspeed^2).
		Set tau to s_ve/s_acc.
        set delta to missiontime - last. // set change to base time the PEG Started and now
		Print "Mission Time " + missiontime.
        //Set last to missiontime. // create a new last MET for the next loop
		Print "delta " + delta.
		Print "peg_step " + peg_step.
		
        if(delta >= peg_step) {  // this is used to ensure a minimum time step occurs before undertaking the next peg cycle
            Print "Convergence Step".
			Set peg to hf_peg_cycle(A, B, T, delta, tau, tgt_vy, tgt_vx, tgt_r, s_vy, s_vx, s_r, s_acc).
			Set last to missiontime.
			if abs( (T-2*delta)/peg[3]-1 ) < 0.01 {  //if the time returned is within 1% of the old T guess to burnout allow convergence to progress 
				//ClearScreen.
                if converged < 0 {
                    set converged to converged+1. //(this is done over ten ticks to ensure the convergence solution selected is accurate enough over ten ship location updates rather than relying on only one convergence solution to enter a closed loop)
					Print "Convergence step +1".
                } else if converged = 0 {
                    set converged to 1.
                    Print("closed loop enabled").
                }
            } 

            set A to peg[0].
            set B to peg[1].
            set C to peg[2].
            set T to peg[3].
            
        }

        //set s_pitch to (A + B*T + C). //wiki Estimation fr,T = A + B*T + C noting T in this instance is the T until the estimated next step so its really delta or just zero if you consider what it should be now.
        set s_pitch to (A + B*delta + C). //wiki Estimation fr,T = A + B*T + C noting T in this instance is the T until the estimated next step so its really delta or just zero if you consider what it should be now.
		//set s_pitch to max(-1, min(s_pitch, 1)). // limit the pitch change to between 1 and -1 with is -90 and 90 degress
        //set s_pitch to arcsin(s_pitch). //covert into degress
		
        if converged = 1 {

			If Util_Vessel["Tol"](orbit:inclination, tgt_inc, 0.1){
				LOCK STEERING TO heading(ship:heading, s_pitch).
			}Else{
				LOCK STEERING TO heading(ff_FlightAzimuth(tgt_inc, tgt_vx), s_pitch).
			}
			ClearScreen.
			Print "closed loop Steering".
			Print "Pitch: " + s_pitch.
			Print (A + B*T + C).
			Print "A: " + A.
			Print "B: " + B.
			Print "C: " + C.
			Print "T: " + T.
			Print "CT:" + peg[4].
			Print "dv:" + peg[5].
			Print "delta: " + delta.
			Print "missiontime: " + missiontime.
			Print abs(T - delta).
			
            if(abs(T - delta) < 1) {
                break. //break when the time left to burn minus the last step incriment  is less than 0.2 seconds remaining so we do not enter that last few step(s) where decimal and estmation accuracy becomes vital.
            }
        }

        wait 0.01. 
    }
    
	Unlock STEERING.
	LOCK Throttle to 0.
    set ship:control:pilotmainthrottle to 0.
    
    // Print "SECO".
    // for e in s_eng {
        // if e:ignition and e:allowshutdown {
            // //e:shutdown.
        // }
    // }
    //set ship:control:neutralize to true.
    //set g_steer to ship:prograde.
    wait 30.
} // end of function

	
///////////////////////////////////////////////////////////////////////////////////
//Helper function for the files functions
/////////////////////////////////////////////////////////////////////////////////////
// Credits: Same as ff_InsertionPEG
function hf_peg_cycle {
    parameter A.
    parameter B.
    parameter T.
    parameter delta.
	parameter tau.
	parameter tgt_vy.
	parameter tgt_vx.
	parameter tgt_r.
	parameter s_vy.
	parameter s_vx.
	parameter s_r.
	parameter s_acc.
    
	local s_ve is ff_Vel_Exhaust().
    
	///if first time through get inital A and B values
    if A = 0 and B = 0 {
        local ab is hf_peg_solve(T, tau, tgt_vy, tgt_r, s_vy, s_r).
        set A to ab[0].
        set B to ab[1].
    }
    Print "s_r: " + s_r.
    local T_dash is T - delta.
	local A_dash is A - delta*B.
	local B_dash is B.
    Print "delta: " + delta.
    local h0 is vcrs(v(s_r, 0, 0), v(s_vy, s_vx, 0)):mag. //current angular momentum
	Print "h0: " + h0.
    local dh is tgt_h - h0. //angular momentum to gain
    Print "dh: " + dh.
	
    Local C is (body:mu/s_r^2 - (s_vx^2/s_r))/s_acc. //portion of vehicle acceleration used to counteract gravity
	Print "C: " + C.
    local fr is A_dash + C. //sin pitch at current time	
    local CT is ((body:mu/tgt_r^2) - (tgt_vx^2/tgt_r)) / (s_acc / (1-(T_dash/tau))). //Gravity and centrifugal force term at cutoff
	Print (body:mu/tgt_r^2).
	Print (tgt_vx^2/tgt_r).
    Print ((body:mu/tgt_r^2) - (tgt_vx^2/tgt_r)).
	Print (s_acc / (1-(T_dash/tau))).
	Print "CT: " + CT.
	Print "body:mu " + body:mu.
	Print "tgt_r" + tgt_r.
	Print "tgt_vx" + tgt_vx.
	Print "T dash" + T_dash.
	Print "tau " + tau.
	
    local frT is A_dash + B_dash*T_dash + CT. //sin pitch at burnout
    local frdot is (frT-fr)/T_dash. //approximate rate of sin pitch
	Print "A_dash: " + A_dash.
	Print "B_dash: " + B_dash.
	Print "frt: " + frT.
	Print "fr: " + fr.
    Print "frdot: " + frdot.
    local ft is 1 - (fr^2)/2. //cos pitch
    local ftdot is -fr*frdot. //cos pitch speed
    local ftdd is -(frdot^2)/2. //cos pitch acceleration
	Print "ft: " + ft.
	Print "ftdot: " + ftdot.
    Print "ftdd: " + ftdd.
    local mean_r is (tgt_r + s_r)/2.
	Print "mean_r: " + mean_r.
    local dv is (dh/mean_r) + ((s_ve*T) * (ftdot+(ftdd*tau))) + ((ftdd*s_ve*(T^2))/2). //note this is from nasa manual equation 36
	//local dv is (dh/mean_r) + (s_ve*T) + (ftdot+(ftdd*tau)) + ((ftdd*s_ve*(T^2))/2).// note this is from wiki
	Print T.
	Print (dh/mean_r).
	Print (s_ve*T_dash).
	Print (ftdot+(ftdd*tau)).
	Print ((ftdd*s_ve*(T^2))/2).
	Print "fDV: " + dv.
	Print (ft + ftdot*tau + ftdd*(tau^2)).
    set dv to abs(dv / (ft + (ftdot*tau) + (ftdd*(tau^2)))). // big equation from wiki near end of estimated
	Print "DV: " + dv.
    local T_plus is tau*(1 - constant:e ^ (-dv/s_ve)). // estimated updated burnout time
    Print "T_plus" + T_plus.
	if abs(t_plus-tau)/tau < 0.001{ //if the result is too close to a full burnout try again until the craft is in a better position to converge
		Set t_plus to T_dash*0.95. 
		Print "new T-Plus" + T_plus.
	}
    if(T_plus >= 2) { // this effectively when the solution starts to become very sensitive and A and B should not longer be re-calculated
        local ab is hf_peg_solve(T_plus, tau, tgt_vy, tgt_r, s_vy, s_r).
        set A to ab[0].
        set B to ab[1].
    } else {
        Print ("terminal guidance enabled").
        set A to A_dash.
        set B to B_dash.
    }
	wait 0.01.
    return list(A, B, C, T_plus, CT, dv).
}

///////////////////////////////////////////////////////////////////////////////////
// Credits: Same as ff_InsertionPEG

// Estimate, returns A and B coefficient for guidance
function hf_peg_solve {
    parameter T.//Estimated time until burnout
    parameter tau. // tau = ve/a which is the time to burn the vehicle completely if it were all propellant
	parameter tgt_vy.
	parameter tgt_r.
	parameter s_vy.
	parameter s_r.
	
	local s_ve is ff_Vel_Exhaust().

    local b0 is -s_ve * ln(1 - (T/tau)). //Wiki eq 7a
    local b1 is (b0*tau) - (s_ve*T). //Wiki eq 7b
    local c0 is b0*T - b1. //Wiki eq 7c
    local c1 is (c0*tau) - (s_ve * T^2)/2. //Wiki eq 7d
    local mb0 is tgt_vy - s_vy.  //Wiki Major loop algortthm MB Matrix top
    local mb1 is (tgt_r - s_r) - s_vy*T. //Wiki Major loop algortthm MB Matrix bottom
    local d is (b0*c1 - b1*c0). // //Wiki Major loop algortthm intermediate stage to solve for Mx from Ma and Mb
    
    local B is (mb1/c0 - mb0/b0) / (c1/c0 - b1/b0). 
	local A is (mb0 - b1*B) / b0.
	Print "Peg Solve".
    Print "s_ve " + s_ve.
	Print "T " + T.
	Print "tau " + tau.
	Print "A " + A.
	Print "B " + B.
    return list(A, B).
}

