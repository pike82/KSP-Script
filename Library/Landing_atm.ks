
{ // Start of anon

///// Download Dependant libraies
local Util_Engine is import("Util_Engine").
local Util_Vessel is import("Util_Vessel").
local Util_Orbit is import("Util_Orbit").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

	local landing_atm is lex(
		"DO_Burn", ff_DO_Burn@,
		"SD_Burn", ff_SD_Burn@,
		"Reentry", ff_Reentry@,
		"ParaLand", ff_ParaLand@
	).
	
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

	Function ff_DO_Burn{
	Parameter TarHeight is 30000.
		until Ship:Periapsis < TarHeight {
			lock steering to ship:retrograde.
			Lock Throttle to gl_TVALMax.
		}
	Lock Throttle to 0.0.
	}// End Function

///////////////////////////////////////////////////////////////////////////////////	
	
	Function ff_SD_Burn{

	Lock gr to (ship:orbit:body:mu/ship:obt:body:radius^2)-(ship:orbit:body:mu/((ship:body:atm:height+ship:body:radius)^2)). // avg accelaration experienced
	Set R_min to ship:orbit:periapsis + ship:obt:body:radius.
	Set Sdv to Util_Engine["stage_delta_v"]().
	Set PreMechEngy to - (ship:orbit:body:mu/(2*ship:orbit:semimajoraxis)).//this is in kJ/kg
	Set MechEngyChange to 0.5*Ship:mass*(Sdv*Sdv).
	Set newsma to -(ship:orbit:body:mu/(2*(PreMechEngy-MechEngyChange))).
	Set newsmaEcc to 1 - (R_min /newsma).
	Set CurTA to Util_Orbit["TAr"](Body:Altitude+ship:obt:body:radius,ship:orbit:semimajoraxis,ship:orbit:eccentricity).
	Set AtmTA to Util_Orbit["TAr"](ship:body:atm:height+ship:obt:body:radius,ship:orbit:semimajoraxis,ship:orbit:eccentricity).
	Set TTAtmoUT to Util_Orbit["TAtimeFromPE"](ship:orbit:eccentricity,CurTA) - Util_Orbit["TAtimeFromPE"](ship:orbit:eccentricity,AtmTA) + time:seconds.
	Set newAtmTAUT to Util_Orbit["TAr"](ship:body:atm:height+ship:obt:body:radius, newsma, newsmaEcc) + time:seconds.
	Lock TTAtmo to abs(
						(-verticalspeed + 
							sqrt(
								(
									(verticalspeed^2)-
									(4*-gr*(Body:Altitude - Body:Atm:HEIGHT))
								)
							)
						) 
						/ (2*-gr)
					).

	Lock Throttle to 0.0.
	Print Sdv .
	Print PreMechEngy.//Mean motion constant
	Print MechEngyChange.
	Print newsma.
	Print newsmaEcc.
	Print CurTA.
	Print AtmTA.
	Print TTAtmoUT.
	Print newAtmTAUT.
	Wait 2.
	until TTAtmo - Util_Engine["burn_time"](Sdv) < 0{
		Clearscreen.
			Print "Height from ATM:" + (abs(gl_baseALTRADAR - Body:Atm:HEIGHT)).
			Print "Vertical Speed:" + (verticalspeed).
			Print "g:" +(gr).
			Print "Time To ATM:" + (TTAtmo).
			Print "Time To ATMUT:" + (TTAtmoUT).
			Print "Mew Time To ATMUT:" + (newAtmTAUT).
			Print "Burn Time:" +(Util_Engine["burn_time"](Sdv)).
			Print "Delta V:" +(Util_Engine["stage_delta_v"]()).
			Print "Current TA V:" + CurTA.
			Print "Atmosphere TA:" + AtmTA.
		wait 1.0.
		If Body:Altitude < ship:body:atm:height{
			Break. // break if something has gone wrong to get out of the loop
		}
	}// End Until
	Lock Throttle to gl_TVALMax.
	Set Pitch to -30.	///Intital setup
	LOCK STEERING TO up + R(Pitch,0,0). //move to pitchover angle	
	until Body:Altitude < ship:body:atm:height  {
			//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).
			Set PIDAngle to PIDLOOP(2, 0.1, 0.5,-0.1,0.1).
			Set PIDAngle:SETPOINT to Ship:periapsis.
			SET dPitch TO PIDAngle:UPDATE(TIME:SECONDS, Ship:periapsis).
			// you can also get the output value later from the PIDLoop object
			// SET OUT TO PID:OUTPUT.
			Set Pitch to max(min(89,(gravPitch + dPitch)),-89). //current pitch setting plus the change from the PID
	} //End Until
	Lock Throttle to 0.0.
	lock steering to SHIP:FACING:STARVECTOR. // point side on to jettistion any remaing stages so they don't come back at the craft
	// need to input an if upright condition here instead of wait.
	Wait 5.
	Stage. //remove engine once finshed orbiting
	lock steering to ship:retrograde.//Points back to retrograde for re-entry
	}// End Function

///////////////////////////////////////////////////////////////////////////////////	

	Function ff_Reentry{
	Parameter ReEndalt is 5000.
	RCS on.
		until gl_baseALTRADAR < ReEndalt {
			lock steering to ship:retrograde.
		}
	Lock Throttle to 0.0.
	}// End Function

///////////////////////////////////////////////////////////////////////////////////	
	
	Function ff_ParaLand{
	Parameter dep_Alt is 2000.
	Print (gl_baseALTRADAR).
	Wait 5.0.
	//Util_Vessel["R_chutes"]("arm parachute").
	//Util_Vessel["R_chutes"]("disarm parachute").
	//Util_Vessel["R_chutes"]("deploy parachute").
	//Util_Vessel["R_chutes"]("cut chute").
		until gl_baseALTRADAR < dep_Alt {
			lock steering to ship:retrograde.
		}
	Lock Throttle to 0.0.
	CHUTESSAFE ON.
	Util_Vessel["R_chutes"]("deploy chute"). //used when real chutes is installed
	RCS off.
	}// End Function

///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(landing_atm).
} // End of anon