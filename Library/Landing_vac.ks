
{ // Start of anon

//Most components of this file are self researched with some with ideas sourced from https://github.com/KK4TEE/kOSPrecisionLand
// and http://www.danielrings.com/2014/08/07/kspkos-grasshopper-a-model-of-spacexs-grasshopper-program-in-the-kerbal-space-program-using-the-kos-mod/


///// Download Dependant libraies
local Util_Engine is import("Util_Engine").
local Util_Landing is import("Util_Landing").
local Util_Vessel is import("Util_Vessel").
//local Flight is import("Flight").
local Util_Orbit is import("Util_orbit").
local Hill_Climb is import("Hill_Climb").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

	local landing_vac is lex(
		"SuBurn",ff_SuBurn@,
		"CAB", ff_CAB@,
		"BestLand", ff_BestLand@,
		"HoverLand",ff_HoverLand@,
		"LandingPointSetup",ff_LandingPointSetup@
	).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////
//Credits: Own

Function ff_SuBurn {	
Parameter ThrottelStartUp is 0.1, SafeAlt is 75, EndVelocity is 0.5. // end velocity must be positive
	Lock Throttle to 0.0.
	local Flight_Arr is lexicon().
	set Flight_Arr to hf_fall().
	LOCK STEERING to HEADING(90,90). // Lock in upright posistion and fixed rotation
	Until Flight_Arr["fallDist"] + SafeAlt + (ThrottelStartUp * abs(ship:verticalspeed)) > gl_baseALTRADAR{ // until the radar height is at the suicide burn height plus safe altitude and an allowance for the engine to throttle up to max thrust
		//Run screen update loop to inform of suicide burn wait.
		Set Flight_Arr to hf_fall().
		Clearscreen.
		Print "gl_fallTime:" + Flight_Arr["fallTime"].
		Print "gl_fallVel:" + Flight_Arr["fallVel"].
		Print "gl_fallDist:" + Flight_Arr["fallDist"].
		Print "gl_fallBurnTime:" + Util_Engine["burn_time"](Flight_Arr["fallVel"]).
		Print "Radar Alt:" + gl_baseALTRADAR.
		Wait 0.001.
	}
	//Burn Height has been reached start the burn
	until abs(verticalspeed) < EndVelocity  {
		Lock Throttle to 1.0.
		if (gl_baseALTRADAR < 0.25) or (Ship:Status = "LANDED"){ // this is used if the burn is intended to land the craft.
			Lock Throttle to 0.
			Unlock Throttle.
			Break.
		}
		Wait 0.01.
	} // end Until
	// Note: if the ship does not meet these conditions the throttle will still be locked at 1, you will need to ensure a landing has taken place or add in another section in the runtime to ensure the throttle does not stay at 1 an make the craft go back upwards.
} //End of Function

//////////////////////////////////////////////////////////////////
//Credits: Own with ideas sourced from http://www.danielrings.com/2014/08/07/kspkos-grasshopper-a-model-of-spacexs-grasshopper-program-in-the-kerbal-space-program-using-the-kos-mod/
// The hover land function maintains a hovers position and moves the ship to the coordinates wanted at the vertical speed requested in the ship veriable limits
Function ff_hoverLand {	
Parameter Hover_alt is 50, BaseLoc is gl_shipLatLng. 
	Set sv_PIDALT:SETPOINT to Hover_alt.
	Set sv_PIDLAT:Setpoint to BaseLoc:Lat.
	Set sv_PIDLONG:Setpoint to BaseLoc:Lng.
	Set SteerDirection to HEADING(90,90). // inital setup
	LOCK STEERING TO SteerDirection.
	
	Set distanceTol to 0.	
	local dtStore is lexicon().
	dtStore:add("lastdt", TIME:SECONDS).
	dtStore:add("lastPos",LATLNG(0,0)).
	
	Until distanceTol > 3 { // until the ship is hovering above the set down loaction for 3 seconds (to allow for PID stability before heading down)
		ClearScreen.
		Print "Moving to Landing Position".	
		Set dtStore to hf_LandingPIDControlLoop(dtStore["lastdt"], dtStore["lastPos"]).
		if hf_geoDistance(BaseLoc, gl_shipLatLng) < 0.5{ //0.5m error before descent. Using geoDistance as distance is expected to be small (less than 1km)
			Set distanceTol to distanceTol + 0.1.	
		}
		Else{
			Set distanceTol to 0.
		}

		Wait 0.1.
	}	
	//Set SteerDirection to HEADING(90,90). // TODO: This was in the old script, need to ensure this can be removed as it would be better if continual refinement can happen during the descent too.

	Set sv_PIDALT:SETPOINT to -0.25. // set just below the surface to ensure touchdown
	Until(gl_baseALTRADAR < 0.25) or (Ship:Status = "LANDED"){
		ClearScreen.
		Print "Landing".
		Set dtStore to hf_LandingPIDControlLoop(dtStore["lastdt"], dtStore["lastPos"]).
		Wait 0.1.
	}
	Lock Throttle to 0.
	Unlock Throttle.
	Unlock Steering. // Note this was decided on as it will draw power/RCS otherwise and the user can make SAS active if they want to keep the active vessel upright
} //End of Function

////////////////////////////////////////////////////////////////

// The CAB land function maintains a pure constant altitude during the burn and therefore may not be appropriate for highly elliptical orbits as it will maintain a constant altitude when the burn starts which may be well above the periapsis and therefore not ideal. 
//It is intended once the CAB is complete that a seperate function is used to rotate the vessel to conduct a suicide land / hover land.

//Credits: OWN

Function ff_CAB{ 
	//this landing tries to burn purely horizontal and uses a pid to determine the desired downwards velocity and cancel it out through a pitch change. It does not stop the throttle or point upwards, that is upto the user to code in or allow a transistion into another function.

	Parameter ThrottelStartTime is 0.1, SafeAlt is 50, TargetLatLng is "Null", EndHorzVel is 0. // throttle start time is the time it take the trottle to get up to full power TODO: have this also take into account the rotation of the body so it can target a specific landing spot.
	
	Set PEVec to velocityat(Ship, ETA:PERIAPSIS + TIME:SECONDS):Surface.
	Set Horzvel to PEVec:mag. // its known at PE the verVel is Zero so all velocity must in theory be horizontal	
	
	Set Dist to 0.
	Set profiletime to 0.
	Set tgtPERad to Orbit:Periapsis+body:radius.
	Set StartMass to (ship:mass * 1000).
	
	until Horzvel <= EndHorzVel {//run the iteration until the ground velocity is 0 or another value if specified
		Set StartMass to StartMass - Util_Engine["mdot"]().
		Set acc to (ship:availablethrust* 1000)/(StartMass). //the acceleration of the ship in one second
		
		Set GravCancel to ((body:mu/(tgtPERad^2)) - ((Horzvel^2)/tgtPERad))/acc. //portion of vehicle acceleration used to counteract gravity as per PEG ascent guidance formula in one second
		
		Set Horzvel to Horzvel - abs(acc - GravCancel). // current horz velocity minus the acceleration in the horitontal direction.
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
	
	Set BurnStartTime to (ETA:PERIAPSIS + TIME:SECONDS) - profiletime.
	If ETA:PERIAPSIS < profiletime +10 {
		Set BurnStartTime to BurnStartTime + Ship:orbit:period. // ensures it will start the burn on the next orbit if too early with a 10 second buffer to allow for alignment and processing finish
	}
	
	local m is ship:mass * 1000. // Starting mass (kg)
	local e is constant():e. // Base of natural log
	local EstDv is (Util_Engine["Vel_Exhaust"]() * ln(m / (m - (profiletime*Util_Engine["mdot"])))).
	
	Until time:seconds > BurnStartTime{
		clearscreen.
		Print "Burn Time :" + profiletime.
		Print "Burn Horizontal Velocity to Cancel:" + PEVec:mag.
		Print "Burn Estimated dV:" + EstDv.
		Print "Burn Dist:" + dist.
		Print "Wating for CAB Start in :" + (BurnStartTime - Time:seconds).
		Lock steering to ship:retrograde. 
		wait 0.001.
	}
	
	Set PIDVV to PIDLOOP(0.03, 0, 0.05, -0.1, 0.1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	Set PIDVV:SETPOINT to 0. // we want the altitude to remain constant so no vertical velocity.
	Set highpitch to 0.

	//lock steering to retrograde * r(-highPitch, 0, 0):vector.
	Lock Horizon to VXCL(UP:VECTOR, -VELOCITY:SURFACE). //negative makes it retrograde
	LOCK STEERING TO LOOKDIRUP(ANGLEAXIS(-highPitch,
                        VCRS(horizon,BODY:POSITION))*horizon,
						FACING:TOPVECTOR).//lock to retrograde at horizon
	
	Set Basetime to time:seconds.
	Lock Throttle to 1.0.
	Until (Basetime + profiletime) - time:seconds < 0 OR SHIP:GROUNDSPEED < 2{
		//Create PID to adjust the craft pitch (without thrusting downward) which maintains a vertical velocity of zero and regulates the velocity of burn height change if not zero reventing a pitch above the horizontal.		
		Set dpitch TO PIDVV:UPDATE(TIME:SECONDS, verticalspeed). //Get the PID on the AlT diff as desired vertical velocity
		Set highpitch to max(highpitch + dpitch,0). // Ensure the pitch does not go below zero as gravity will efficently lower the veritcal velocity if required
		Clearscreen.
		Print "Undertaking CAB".
		Print "Ground Speed: " + SHIP:GROUNDSPEED.
		Print "Pitch: " + highpitch.
		Print "Burn Ending in : " + ((Basetime + profiletime) - time:seconds).
		wait 0.01.
	}
	unlock Steering.
} //End of Function

////////////////////////////////////////////////////////////////

//Credits: OWN

Function ff_BestLand{ 
	Parameter ThrottelStartTime is 0.1, SafeAlt is 50, TargetLatLng is "Null", EndHorzVel is 0. // throttle start time is the time it take the trottle to get up to full power
	
	Set PEVec to velocityat(Ship, ETA:PERIAPSIS + TIME:SECONDS):Surface.
	Set Horzvel to abs(PEVec:mag). // its known at PE the verVel is Zero so all velocity must in theory be horizontal	
	Set VerVel to 0.
	Set VerDist to 0.
	Set Dist to 0.
	Set profiletime to 0.
	Set tgtPERad to Orbit:Periapsis+body:radius.
	Set StartMass to (ship:mass * 1000).

	until Horzvel <= EndHorzVel {//run the iteration until the ground velocity is 0 or another value if specified
		Set VerVelStart to VerVel.
		Set StartMass to StartMass - Util_Engine["mdot"]().
		Set acc to (ship:availablethrust* 1000)/(StartMass). //the acceleration of the ship in one second
		Set VertAccel to ((body:mu/((tgtPERad-VerDist)^2)) - ((Horzvel^2)/(tgtPERad-VerDist))). //portion of vehicle acceleration used to counteract gravity as per PEG ascent guidance formula in one second
		Set VerVel to VerVelStart - abs(VertAccel). // current vertical velocity.
		Set VerDist to VerDist - ((VerVelStart + VerVel)/2).
		Set Horzvel to Horzvel - abs(acc).
		Set dist to dist + Horzvel.
		Set profiletime to profiletime + 1.
		Clearscreen.
		Print acc.
		Print VertAccel.
		Print Horzvel.
		Print VerDist.
		Print VerVel.
		Print dist.
		Print profiletime. // note this is the worst case burn time if a CAB needs to be performed. //Ideally it will be shorter.
		wait 0.001.
	} // note this estimates based ona CAB which is the worst case senario, but in reality it should be able to burn for less time than estimated.
	

	Set BurnStartTime to (ETA:PERIAPSIS + TIME:SECONDS) - profiletime.
	If ETA:PERIAPSIS < profiletime +10 {
		Set BurnStartTime to BurnStartTime + Ship:orbit:period. // ensures it will start the burn on the next orbit if too early with a 10 second buffer to allow for alignment and processing finish
	}
	
	local m is ship:mass * 1000. // Starting mass (kg)
	local e is constant():e. // Base of natural log
	local mdot is Util_Engine["mdot"]().
	Set massloss to profiletime * mdot.
	local EstDv is Util_Engine["Vel_Exhaust"]().
	Set EstDv to EstDv * ln(m / (m - massloss)).
	
	Until time:seconds > BurnStartTime{
		clearscreen.
		Print "Burn Time :" + profiletime.
		Print "Burn Horizontal Velocity to Cancel:" + PEVec:mag.
		Print "Burn Estimated dV:" + EstDv.
		Print "Burn Dist:" + dist.
		Print "Wating for burn Start in :" + (BurnStartTime - Time:seconds).
		Lock steering to ship:retrograde. 
		wait 0.001.
	}
	
	local Flight_Arr is lexicon().
	set Flight_Arr to hf_fall().
	Set Basetime to time:seconds.
	
	Set PIDFALL to PIDLOOP((ship:availablethrust / (ship:mass*100)), 0, 0.1, -500, 0).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	Set PIDFALL:SETPOINT to 0. // we want zero fall speed when the difference between actuall hieght and fall height is zero.
	
	Set PIDVV to PIDLOOP(0.03, 0, 0.05, -0.1, 0.1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	Set highpitch to 0.
	
	//lock steering to retrograde * r(-highPitch, 0, 0):vector.
	Lock Horizon to VXCL(UP:VECTOR, -VELOCITY:SURFACE). //negative velocity makes it retrograde
	LOCK STEERING TO LOOKDIRUP(ANGLEAXIS(-highPitch,
                        VCRS(horizon,BODY:POSITION))*horizon,
						FACING:TOPVECTOR).//lock to retrograde at horizon
	Lock Throttle to 1.0.
	until (Basetime + profiletime +10 ) - time:seconds < 0 OR SHIP:GROUNDSPEED < 2{ //TODO: Make it so the +10 is not hardcoded in.
		Set tgtFallheight to Flight_Arr["fallDist"] + SafeAlt + (ThrottelStartTime * abs(ship:verticalspeed)).
		Set FALLSpeed to PIDFALL:UPDATE(TIME:SECONDS, gl_baseALTRADAR - tgtFallheight).
		Set PIDVV:SETPOINT to FALLSpeed.
		Set dpitch TO PIDVV:UPDATE(TIME:SECONDS, verticalspeed). //Get the PID on the AlT diff as desired vertical velocity
		Set highpitch to max(highpitch + dpitch,0). // Ensure the pitch does not go below zero as gravity will efficently lower the veritcal velocity if required
		Clearscreen.
		Print "Limiting Descent Speed".
		Print "Ground Speed: " + SHIP:GROUNDSPEED.
		Print "tgtFallheight:" + tgtFallheight.
		Print "Fall Clearance:" + (gl_baseALTRADAR - tgtFallheight).
		Print "Fall speed:" + Fallspeed.
		Print "Vertical speed:" + verticalspeed.
		Print "Pitch: " + highpitch.
		Print "Burn Ending in : " + ((Basetime + profiletime) - time:seconds).
		wait 0.01.
	}
	Unlock Steering.
} //End of Function

///////////////////////////////////////////////////////////////

//Credits: OWN

// this function determines if the current orbit PE passes close to the target landing area or if a correction burn needs to be made
Function ff_LandingPointSetup{ 
	Parameter tgt_point, max_dist is 500, Max_Orbits is 100. // throttle start time is the time it take the trottle to 	
	
	Local Orbit_OK is hf_CheckInc(tgt_point:Lat, Ship:inclination).
	If NOt Orbit_ok {
	//Put code here to conduct a plane change so the orbit inclination is high enough to reach the lattitude
	

	}
	
	//Once the inclination is suitable, find the next orbit which passes near the landing spot.
	Local Landing_Param is hf_findNextPass(tgt_point, max_dist, max_orbits).
	
	If not Landing_Param[2] { // no acceptable solution was found as found pass will be false
	// put code in here to adjust the orbit so it can be a suitable solution. noting we have the closest distance and its time returned in the array, which can help with the orbit adjustment. I suggest using a hill climb along with the find next path to find a suitable solution.
	
	
		// look into SHIP:ORBIT:BODY:ROTATIONPERIOD and the time from LAN to PE in an eliptical orbit. We know the time from LAN to PE will be constant so we will have a fixed rotation of the body to PE (during the transit of the argument of perioapsis) and there for know where PE will be for a given LAN. Therefore we will need to adjust the orbit so we have that we pass over a given LAN and therefore a given PE at the target.
	// //TODO: work out how to tell if the orbit is in the same direction as the body rotation.
	
	}
	//otherwise return the time, distance and confirmation of an acceptable pass.
	Return (Landing_Param).

} //End of Function

////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////
Function hf_Fall{
//Fall Predictions and Variables
	local fallTime is Util_Orbit["quadraticPlus"](-gl_Grav["Avg"]/2, -ship:verticalspeed, gl_baseALTRADAR).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	local fallVel is abs(ship:verticalspeed) + (gl_Grav["Avg"]*fallTime).//v = u + at
	local fallAcc is (ship:AVAILABLETHRUST/ship:mass). // note is is assumed this will be undertaken in a vaccum so the thrust and ISP will not change. Otherwise if undertaken in the atmosphere drag will require a variable thrust engine so small variations in ISP and thrust won't matter becasue the thrust can be adjusted to suit.
	local fallDist is (fallVel^2)/ (2*(fallAcc)). // v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a 
	
	local arr is lexicon().
	arr:add ("fallTime", fallTime).
	arr:add ("fallVel", fallVel).
	arr:add ("fallAcc", fallAcc).
	arr:add ("fallDist", fallDist).
	
	Return(arr).
}

/////////////////////////////////////////
//Credit:https://github.com/ElWanderer/kOS_scripts 

FUNCTION hf_CheckInc{
PARAMETER lat,inc. // returns true is the inclination is high enough to pass the specified lattitude
  RETURN (inc > 0 AND MIN(inc,180-inc) >= ABS(lat)).
}

/////////////////////////////////////////
//Credit:https://github.com/ElWanderer/kOS_scripts 

/// Returns the True anomolies where the orbit reaches a specific lattitude
FUNCTION hf_TAatLat{
PARAMETER lat.

  IF NOT hf_CheckInc(lat, ship:INCLINATION) { RETURN -1. } // double check the inclinations is ok
  
  LOCAL ArgPer IS hf_mAngle(Ship:ARGUMENTOFPERIAPSIS).
  Local Ang1 is hf_mAngle(ARCSIN((SIN(lat)/SIN(ship:INCLINATION))) - ArgPer).
  
  LOCAL ta_extreme_lat IS hf_mAngle(90 - ArgPer).
  IF lat < 0 { 
	SET ta_extreme_lat TO hf_mAngle(270 - ArgPer). 
  }
  Local Ang2 is hf_mAngle((2 * ta_extreme_lat) - Ang1).  
  RETURN list(Ang1, Ang2).
}

/////////////////////////////////////////
//Credit:https://github.com/ElWanderer/kOS_scripts 

FUNCTION hf_mAngle{
PARAMETER a.

  UNTIL a >= 0 { SET a TO a + 360. }
  RETURN MOD(a,360).
  
}

/////////////////////////////////////////
//Credit:https://github.com/ElWanderer/kOS_scripts 

FUNCTION hf_findNextPass{
  // max_dist in metres
PARAMETER tgt_landing, max_dist, max_orbits is 100.

	LOCAL base_time IS TIME:SECONDS.
	LOCAL return_time IS 0. // the UC time returned when the vessel is at the closest distance
	LOCAL return_dist IS 1000000. // the distance value returned by this function, initially set very high to allow for smaller distances to overwrite it
	LOCAL orbit_count IS 0.
	LOCAL found_pass IS FALSE.
	LOCAL TA1_first IS TRUE. // Keeps track of which TA is next.
	
	LOCAL ship_period IS Ship:ORBIT:PERIOD.
	LOCAL max_orbits_time IS max_orbits * Ship:ORBIT:PERIOD.
	
	LOCAL ArgLATs is hf_TAatLat(tgt_landing:lat). // the TA's when the craft passes the latitude
		
	LOCAL TA1 IS ArgLATs[0].
	LOCAL TA2 IS ArgLATs[1].
	LOCAL TA1_time IS base_time + Util_Orbit["timeFromTA"] (TA1, ship:orbit:eccentricity). 
	LOCAL TA2_time IS base_time + Util_Orbit["timeFromTA"] (TA2, ship:orbit:eccentricity).

	IF TA2_time < TA1_time { // check to see which TA we are passing first
		SET TA1_first TO FALSE. 
	}

	UNTIL found_pass OR orbit_count >= max_orbits { // loop until solition found or the max orbits has been reached
		SET orbit_count TO orbit_count + 1.

		LOCAL pass_count IS 0.
		
		UNTIL found_pass OR pass_count > 1 { // loop until a solution has been found or a full orbit has taken place.
			LOCAL pass_time IS 0.
			IF (pass_count = 0 AND ta1_first) OR
				(pass_count = 1 AND NOT ta1_first) { 
				SET pass_time TO ta1_time. 
			}
			ELSE { 
				SET pass_time TO ta2_time. 
			} // this section is used to determine which TA time to use
			

			Set Spot to hf_BodyPositionAt(pass_time). // Set the spot to the predicted Co-ords when the ship passes over.
			
			IF ABS(spot:LNG - tgt_landing:LNG) < 3 {  // checks if within 3 degrees longitude
				Local ShortDistTime is hill_climb["optimize"] (
					pass_time, 
					{
						Parameter new_time. 
						Set new_pos to hf_BodyPositionAt(new_time).
						Set new_dist to hf_gs_distance(new_pos, tgt_landing). // Using gs_Distance as the distance is expected to be large.
						Return - new_dist.
					}, 
					0.5 // look in 0.5 second incriments arount the time it passess over the lattitude for the nearest distance
				).
				local Short_pos is hf_BodyPositionAt(ShortDistTime).
				Local Short_dist is hf_gs_distance(new_pos, tgt_landing).// get the new lowest distance found
				If  Short_dist < return_dist { //update so even if a suitable pass is not found the closest pass is found.
					Set return_dist TO Short_dist.
					SET return_time TO ShortDistTime.
				}
				IF Short_dist < max_dist AND Short_dist >= 0 { // checks to see if with the max distance tolerance
				  SET found_pass TO TRUE.
				}
			}
			SET pass_count TO pass_count + 1.
		}

		SET TA1_time TO TA1_time + ship_period. //moves onto the next orbit
		SET TA2_time TO TA2_time + ship_period. //moves onto the next orbit
	  }
	  RETURN list(return_time, return_dist, found_pass).
}

///////////////////////////////////////////////////////////////////////
//Returns the coordiates that the ship will be over at a given time accounting for planet rotation.
Function hf_BodyPositionAt{

//Credits:Own

Parameter Pass_time.
	LOCAL BodRotTime is Body:ROTATIONPERIOD.
	LOCAL spot is Body:GEOPOSITIONOF(POSITIONAT(ship,pass_time)). // Get Coordinates when passing lattitude point assuming no rotation
	LOCAL time_diff is MOD(pass_time - TIME:SECONDS, BodRotTime). // get the time until this point is reached
	LOCAL new_lng is hf_mAngle(spot:LNG - (time_diff * 360 / BodRotTime)). // find the rotation of the body during this time and what the longatude will be.
	Return LATlNG(spot:LAT,new_lng).
}


Function hf_LandingPIDControlLoop{
Parameter lastdt, lastPos.
	Set lastdt to min(TIME:SECONDS-0.01, lastdt). //Ensures there is a time difference so there is no divide by zero
	Set DegDistance to (body:radius*2*constant:pi)/360.
	Set Tgt to LATLNG(sv_PIDLAT:Setpoint,sv_PIDLONG:Setpoint).
	
	Set LatDist to hf_geoDistance(LATLNG(gl_shipLatLng:Lat,tgt:Lng),tgt). // distance to tgt in Lat metres only
	Set LngDist to hf_geoDistance(LATLNG(tgt:Lat,gl_shipLatLng:Lng),tgt). // distance to tgt in Lng metres only
	
	SET ALTSpeed TO sv_PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
	Set LATSpeed to sv_PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat in m/s
	Set LONGSpeed to sv_PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long in m/s
	
	Set sv_PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
	Set sv_PIDNorth:SETPOINT to LATSpeed. // the new desired speed in m/s
	Set sv_PIDEast:SETPOINT to LONGSpeed. // the new desired speed in m/s
	
	Set NorthSpeed to (gl_shipLatLng:Lat - LastPos:Lat)/(TIME:SECONDS-lastdt).
	Set EastSpeed to (gl_shipLatLng:Lng - LastPos:Lng)/(TIME:SECONDS-lastdt).
	
	Set Splitarr to hf_geoVelSplit (gl_shipLatLng,LastPos).
	
	Set NorthSpeed1 to Splitarr[0]:mag.
	Set EastSpeed1 to Splitarr[1]:mag.
	
	SET ThrottSetting TO sv_PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
	SET NorthDirection TO sv_PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
	SET EastDirection TO sv_PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed
	
	
	Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
		
	Lock Throttle to ThrottSetting.	
	
	Set Flight_Arr to hf_fall().	
	Print "===============================".
	Print "Target Lat: " + sv_PIDLAT:Setpoint.	
	Print "Current Lat: " + gl_shipLatLng:Lat.
	Print "Lat diff: " + (sv_PIDLAT:Setpoint - gl_shipLatLng:Lat).	
	Print "LATSpeed:"	+ LATSpeed.
	Print "NorthSpeed:" + NorthSpeed.
	Print "NorthSpeed1:" + NorthSpeed1.
	Print "NorthDirection:" + NorthDirection.
	Print "===============================".
	Print "Target Long: " + sv_PIDLONG:Setpoint.		
	Print "Current Long: " + gl_shipLatLng:Lng.
	Print "Long diff: " + (sv_PIDLONG:Setpoint - gl_shipLatLng:Lng).
	Print "LONGSpeed:"	+ LONGSpeed.
	Print "EastSpeed:" + EastSpeed.
	Print "EastSpeed1:" + EastSpeed1.
	Print "EastDirection:" + EastDirection.
	Print "===============================".
	Print "Calc tgt Dist:" + hf_geoDistance(gl_shipLatLng, tgt).	
	Print "===============================".	
	Print "ALT Kp: " + sv_PIDALT:Pterm.
	Print "ALT Ki: " + sv_PIDALT:Iterm.
	Print "ALT Kd: " + sv_PIDALT:Dterm.
	Print "ALT Out: " + sv_PIDALT:OUTPUT.
	Print "===============================".
	Print "Thrott Kp: " + sv_PIDThrott:Pterm.
	Print "Thrott Ki: " + sv_PIDThrott:Iterm.
	Print "Thrott Kd: " + sv_PIDThrott:Dterm.
	Print "Thrott Out: " + sv_PIDThrott:OUTPUT.
	Print "===============================".
	//Print "Delta throttle: "+ dThrot.
	Print "Throttle Setting: "+ ThrottSetting.
	Print "Current Alt" + ship:Altitude.
	Print "Ground Alt" + gl_surfaceElevation.
	Print "Ground Dist" + gl_baseALTRADAR.
	Print "tgt Bearing :" + tgt:bearing.
	Print "Calc tgt Bearing:" + hf_geoDir(gl_shipLatLng, tgt).
	Print "Calc True tgt Bearing: " + hf_gs_bearing(gl_shipLatLng,tgt).
	Print "tgt Heading :" + tgt:heading.
	Print "===============================".
	Print "Base fall time: " + sqrt((2*gl_baseALTRADAR)/(gl_GRAV["G"])).
	Print "Fall time: " + Flight_Arr["fallTime"].	
	Print "Fall vel: " + Flight_Arr["fallVel"].
	Print "===============================".
	
	Set lastPos to gl_shipLatLng.
	Set lastdt to TIME:SECONDS.
	
	Local Result is lexicon().
	
	Result:add("lastPos",lastPos).
	Result:add("lastdt",lastdt).
	
	Return Result.
}

//////////////////////////////////////////////////////////
function hf_geoVelSplit{

//Credits: https://www.reddit.com/r/Kos/comments/438e1o/converting_latitudelongitude_to_distance_in_meters/
Parameter LatLng1, LatLng2.
	Set pos1 to LatLng1:position.
	Set pos2 to LatLng2:position.
	set distance to (pos1-pos2):mag.

	set north_vector to heading(0,0):vector.
	set east_vector to heading(90,0):vector.

	set vel_lat to vxcl(vcrs(SHIP:UP:VECTOR,north_vector), SHIP:velocity:surface).
	set vel_lng to vxcl(vcrs(SHIP:UP:VECTOR,east_vector), SHIP:velocity:surface).
	
	Return list(vel_lat, vel_lng).

}

function hf_geoDistance { //Approx in meters using straight line. Good for flat surface approximatation and low computation. Does not take into accout curvature.
	parameter geo1.
	parameter geo2.
	return (geo1:POSITION - geo2:POSITION):MAG.
}

function hf_gs_distance {

//use this distance for where larger distances are expected. 
// this is the "Haversine" formula go to www.moveable-type.co.uk for more information
parameter gs_p1, gs_p2. //(point1,point2). 
	//Need to ensure converted to radians 
	//TODO Test if this still works in degrees
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.
	set resultA to 	sin((P1Lat-P2Lat)/2)^2 + 
					cos(P1Lat)*cos(P2Lat)*
					sin((P1Lng-P2Lng)/2)^2.
	set resultB to 2*arctan2(sqrt(resultA),sqrt(1-resultA)).
	set result to body:radius*resultB. // this is the "Haversine" formula go to www.moveable-type.co.uk for more information
	
return result.
}

function hf_geoDir { //compass angle of direction to landing spot
	parameter geo1.
	parameter geo2.
	return ARCTAN2(geo1:LNG - geo2:LNG, geo1:LAT - geo2:LAT).
}

function hf_gs_bearing {
parameter gs_p1, gs_p2. //(point1,point2). 
	//Need to ensure converted to radians 
	//TODO Test if this still works in degrees
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.

	set resultA to (cos(P1Lat)*sin(P2Lat)) -(sin(P1Lat)*cos(P2Lat)*cos(P2Lng-P1Lng)).
	set resultB to sin(P2Lng-P1Lng)*cos(P2Lat).
	set result to  arctan2(resultA, resultB).// this is the intial bearing formula go to www.moveable-type.co.uk for more informationn


	// set resultA to (cos(gs_p1:lat)*sin(gs_p2:lat)) -(sin(gs_p1:lat)*cos(gs_p2:lat)*cos(gs_p2:lng-gs_p1:lng)).
	// set resultB to sin(gs_p2:lng-gs_p1:lng)*cos(gs_p2:lat).
	// set result to  arctan2(resultA, resultB).// this is the intial bearing formula go to www.moveable-type.co.uk for more information
return result.
}

function hf_ImpactEta {
    parameter acc, thrtl, g, vel, h.
    return Orbit_Calc["quadraticMinus"]((acc * thrtl - g), vel, h).
}

function hf_cardVel {
	//Convert velocity vectors relative to SOI into east and north.
	local vect IS SHIP:VELOCITY:SURFACE.
	local eastVect is VCRS(UP:VECTOR, NORTH:VECTOR).
	local eastComp IS scalarProj(vect, eastVect).
	local northComp IS scalarProj(vect, NORTH:VECTOR).
	local upComp IS scalarProj(vect, UP:VECTOR).
	RETURN V(eastComp, upComp, northComp).
}

function velPitch { //angle of ship velocity relative to horizon
	LOCAL cardVelFlat IS V(cardVelCached:X, 0, cardVelCached:Z).
	RETURN VANG(cardVelCached, cardVelFlat).
}
function velDir { //compass angle of velocity
	return ARCTAN2(cardVelCached:X, cardVelCached:Y).
}
function scalarProj { //Scalar projection of two vectors. Find component of a along b. a(dot)b/||b||
	parameter a.
	parameter b.
	if b:mag = 0 { PRINT "scalarProj: Tried to divide by 0. Returning 1". RETURN 1. } //error check
	RETURN VDOT(a, b) * (1/b:MAG).
}



///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(landing_vac).
} // End of anon