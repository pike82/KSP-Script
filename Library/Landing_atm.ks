
//Credits:own

///// Download Dependant libraies

FOR file IN LIST(
	"Util_Engine",
	"Util_Vessel",
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

	// local landing_atm is lex(
		// "DO_Burn", ff_DO_Burn@,
		// "SD_Burn", ff_SD_Burn@,
		// "Reentry", ff_Reentry@,
		// "ParaLand", ff_ParaLand@
	// ).
	
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

	Function ff_DO_Burn{
	Parameter TarHeight is 30000.
		until Ship:Periapsis < TarHeight {
			lock steering to ship:retrograde.
			Lock Throttle to gl_TVALMax().
			wait 0.001.
		}
	Lock Throttle to 0.0.
	Print "De-orbit height reached".
	}// End Function

///////////////////////////////////////////////////////////////////////////////////	
	
	Function ff_SD_Burn{

		// Set gr to ((body:mu/((tgtPERad-VerDist)^2)) - ((Horzvel^2)/(tgtPERad-VerDist))). //portion of vehicle acceleration used to counteract gravity as per PEG ascent guidance formula in one second
		
		
		
		
		// until Horzvel <= EndHorzVel {//run the iteration until the ground velocity is 0 or another value if specified
			// Set VerVelStart to VerVel.
			// Set StartMass to StartMass - ff_mdot().
			// Set acc to (ship:availablethrust* 1000)/(StartMass). //the acceleration of the ship in one second
			// Set VertAccel to ((body:mu/((tgtPERad-VerDist)^2)) - ((Horzvel^2)/(tgtPERad-VerDist))). //portion of vehicle acceleration used to counteract gravity as per PEG ascent guidance formula in one second
			// Set VerVel to VerVelStart - abs(VertAccel). // current vertical velocity.
			// Set VerDist to VerDist - ((VerVelStart + VerVel)/2).
			// Set Horzvel to Horzvel - abs(acc).
			// Set dist to dist + Horzvel.
			// Set profiletime to profiletime + 1.
			// Clearscreen.
			// Print acc.
			// Print VertAccel.
			// Print Horzvel.
			// Print VerDist.
			// Print VerVel.
			// Print dist.
			// Print profiletime. // note this is the worst case burn time if a CAB needs to be performed. //Ideally it will be shorter.
			// wait 0.001.
		// } // note this estimates based ona CAB which is the worst case senario, but in reality it should be able to burn for less time than estimated.
	
		
		
		
		
	Lock gr to (ship:orbit:body:mu/ship:obt:body:radius^2)-(ship:orbit:body:mu/((ship:body:atm:height+ship:body:radius)^2)). // avg accelaration experienced
	Set R_min to ship:orbit:periapsis + ship:obt:body:radius.
	Set Sdv to ff_stage_delta_v().
	Set PreMechEngy to - (ship:orbit:body:mu/(2*ship:orbit:semimajoraxis)).//this is in kJ/kg
	Set MechEngyChange to 0.5*Ship:mass*(Sdv*Sdv).
	Set newsma to -(ship:orbit:body:mu/(2*(PreMechEngy-MechEngyChange))).
	Set newsmaEcc to 1 - (R_min /newsma).
	Set CurTA to ff_TAr(Body:Altitude+ship:obt:body:radius,ship:orbit:semimajoraxis,ship:orbit:eccentricity).
	Set AtmTA to ff_TAr(ship:body:atm:height+ship:obt:body:radius,ship:orbit:semimajoraxis,ship:orbit:eccentricity).
	Set TTAtmoUT to ff_TAtimeFromPE(ship:orbit:eccentricity,CurTA) - ff_TAtimeFromPE(ship:orbit:eccentricity,AtmTA) + time:seconds.
	Set newAtmTAUT to ff_TAr(ship:body:atm:height+ship:obt:body:radius, newsma, newsmaEcc) + time:seconds.
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
	until TTAtmo - ff_burn_time(Sdv) < 0{
		Clearscreen.
			Print "Height from ATM:" + (abs(gl_baseALTRADAR() - Body:Atm:HEIGHT)).
			Print "Vertical Speed:" + (verticalspeed).
			Print "g:" +(gr).
			Print "Time To ATM:" + (TTAtmo).
			Print "Time To ATMUT:" + (TTAtmoUT).
			Print "Mew Time To ATMUT:" + (newAtmTAUT).
			Print "Burn Time:" +(ff_burn_time(Sdv)).
			Print "Delta V:" +(ff_stage_delta_v()).
			Print "Current TA V:" + CurTA.
			Print "Atmosphere TA:" + AtmTA.
		wait 1.0.
		If Body:Altitude < ship:body:atm:height{
			Break. // break if something has gone wrong to get out of the loop
		}
	}// End Until
	Lock Throttle to gl_TVALMax().
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
			WAIT 0.001.
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
	Parameter exit_alt is 15000, maxspeed is 1500, minspeed is 400.
		Lock Throttle to 0.0.
		RCS on.
		lock steering to ship:retrograde.
		until gl_baseALTRADAR() < exit_alt {
			if ship:airspeed > maxspeed{
				Lock Throttle to gl_TVALMax().
			}
			if ship:airspeed < minspeed{
				Lock Throttle to 0.0.
			}
			wait 0.01.
		}//end until
		Lock Throttle to 0.0.
		
	}// End Function

///////////////////////////////////////////////////////////////////////////////////	
	
	Function ff_ParaLand{
	Parameter dep_Alt is 20000.
	Print (gl_baseALTRADAR()).
	//Util_Vessel["R_chutes"]("arm parachute").
	//Util_Vessel["R_chutes"]("disarm parachute").
	//Util_Vessel["R_chutes"]("deploy parachute").
	//Util_Vessel["R_chutes"]("cut chute").
		lock steering to ship:retrograde.
		Lock Throttle to 0.
		until gl_baseALTRADAR() < dep_Alt{
			wait 0.1.
		}
		CHUTESSAFE ON.
		ff_R_chutes("arm parachute"). //used when real chutes is installed
		RCS off.
	}// End Function


