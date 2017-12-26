
{ // Start of anon

//Whole file is a work in progress


//// http://www.movable-type.co.uk/scripts/latlong.html is a good source for bearing information on goecords on sphere

///// Download Dependant libraies
local Util_Engine is import("Util_Engine").
local Util_Vessel is import("Util_Vessel").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

	local Util_landing is lex(
		"Suicide_info", ff_Suicide_info@
	).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////
function ff_Suicide_info{

}


Function ff_goodLand{ // this is to be reviewed and parts put in vac_landing
	// Parameter ThrottelStartTime is 0.1, SafeAlt is 50, TargetLatLng is "Null", MaxSlopeAng is 1.
	
	// //this landing tries to burn purely horizontal and uses a pid to determine the desired downwards velocity and then a second PID to determine the pitch required to maintain the desire downward velocity
	
	
	// //Body Rotation
	
	// Set Bod_rot to Ship:Body:RotationPeriod.
	// Set Bod_Ang_Ajust to (ETA:PERIAPSIS /Bod_rot)*360. //angle of roation the body will incur before the ship get to the PE
	// //Set Bod_rot_Dir to Ship:Body:Angularvel // lonk into SHIP:ORBIT:BODY:ROTATIONPERIOD and the time from LAN to PE in an eliptical orbit. We know the time from LAN to PE will be constant so we will have a fixed rotation of the body to PE (during the transit of the argument of perioapsis) and there for know where PE will be for a given LAN. Therefore we will need to adjust the orbit so we have that we pass over a given LAN and therefore a given PE at the target.
	// //TODO: work out how to tell if the orbit is in the same direction as the body rotation.
	
	// Set PePos to positionat(Ship, ETA:PERIAPSIS + TIME:SECONDS). //Returns the ship-raw position at the PE
	// Set PePos to ship:Body:GEOPOSITIONOF(PePos). //Converts the predicted PE into geo-cordinates
	// Set PePos:Lat to PePos:Lat - Bod_Ang_Ajust. //TODO: Ensure this does not need a Clamp angle function for multiple roations or large values that make things negative

	// //Set ShipPeUpVec to PePos - body:position.
	// Set PEVec to velocityat(Ship, ETA:PERIAPSIS + TIME:SECONDS):Surface.
	// //horz
	// Set PeHorzVel to PEVec:mag. // its known at PE the verVel is Zero so all velocity must be horizontal
	// //Vertical
	// Set PeVerVel to 0. // its known at PE the verVel is Zero
	// Set PeVerBurnDist to Orbit:Periapsis - (PePos:TERRAINHEIGHT + SafeAlt). 
	// Set PeAvgGravity to sqrt(		(	(body:mu / (Orbit:Periapsis + body:radius)^2) +((body:mu / (PePos:TERRAINHEIGHT + body:radius)^2 )^2)		)/2		).// Root Mean square method
	// Set PeFallTime to Orbit_Calc["quadraticPlus"](-PeAvgGravity/2, -PeVerVel, PeVerBurnDist).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	// Set PeFallVel to abs(PeVerVel) + (PeAvgGravity*PeFallTime).//v = u + at
	
	// //times
	// Set HorzBurnTime to Util_Engine["burn_time"](PeHorzVel). // Burn Time if pure horizontal burn
	// Set HozBurnTimeGravCancel to (HorzBurnTime /(sqrt(PeAvgGravity^2 + gl_TWR^2))/ HorzBurnTime ). //Approximate Burn Time required if performing CAB to PE
	// Set VerBurnTime to Util_Engine["burn_time"](PeFallVel). //Burn time required if performing Suicide burn at PE

	// //Suicide burn Calcs
	
	// Set SuBurnDistToStop to Altitude - gl_PeLatLng:TERRAINHEIGHT - SafeAlt. // Calculates the distance between the craft and the intended stopping height
	// Set SuBurnTimeFallToStop to Orbit_Calc["quadraticPlus"](-PeAvgGravity/2, -VERTICALSPEED, SuBurnDistToStop).// the time to fall from the current position to the the intended stopping height r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	// Set SuBurnVel to abs(VERTICALSPEED) + (PeAvgGravity*SuBurnTimeFallToStop).// the dv required to perform the suicide burn. v = u + at
	// Set SuBurnVelTime to Util_Engine["burn_time"](SuBurnVel)*PeAvgGravity.
	// Set SuBurnAcc to (ship:AVAILABLETHRUST/ship:mass). // note is is assumed this will be undertaken in a vaccum so the thrust and ISP will not change. Otherwise if undertaken in the atmosphere drag will require a variable thrust engine so small variations in ISP and thrust won't matter becasue the thrust can be adjusted to suit.
	// Set SuBurnDist to 1000000000000000. // Intial Value to get into the loop
	// Set SuBurnDistOld to 1. // Intial Value to get into the loop
	// Set loopI to 0.
	// Set SuBurnDist to ((SuBurnVel)^2)/ (2*(SuBurnAcc)). // height traversed while undertaking the suicide burn. v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a
	
	// //below is a test loop to see if gravity losses need to be taken into account when determining the correct suicide burn altitude
	
	// Until (abs(SuBurnDist - SuBurnDistOld) > 0.5) or (loopI > 10){ /// loop to find the velocity required to cancel out gravity losses during the suicide burn.
		// Set SuBurnDistOld to SuBurnDist.
		// Set SuBurnGravLoss to SuBurnVelTime*PeAvgGravity. //Gravity loss estimate on dv required.
		// Set SuBurnVelTime to Util_Engine["burn_time"](SuBurnVel+SuBurnGravLoss). //new burn time required including dv adjusted with gravity loss.
		// Set SuBurnDist to ((SuBurnVel)^2)/ (2*(SuBurnAcc)). // height traversed while undertaking the suicide burn. v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a
		// Set LoopI to LoopI + 1.
	// }
	
	// Set BurnHeightDiff to SuBurnDistToStop - SuBurnDist. // the currect distance until the suicde burn needs to start.
	
	// //Create PID to adjust the craft pitch (without thrusting downward) which maintains a BurnHeightDiff of zero and regulates the velocity of burn height change if not zero reventing a pitch above the horizontal.
	

	// if PeFallTime > VerBurnTime + HorzBurnTime +10 { //ensure the amount of time remaing after performing a pure horizontal burn enable the craft to still perform a suicide burn is sufficent plus a margin for error and craft rotation (10s).
		// Set StartTime to HozBurnTimeGravCancel. //This conditions means we can burn horizontally only and don't need to worry about altitude loss during the burn
	// }  
	// Else {
		// If PeFallTime =1{
			// ////TODO: this is where i left off
		// }
		// Else {
			// Set StartTime to HorzBurnTime + HozBurnTimeGravCancel
		// }
	
		
	// Until ETA:PERIAPSIS < HorzBurnTime {
	// lock steering to - vcrs(SHIP:UP:VECTOR,SHIP:FACING:STARVECTOR) //point retrograde to the horizon
		// Clearscreen.
		// Print PeHorzVel.
		// Print PeVerBurnDist.
		// Print PeFallTime.
		// Print HorzBurnTime.
		// Print VerBurnTime.
		// Print totalBurnTime.
		// Print ETA:PERIAPSIS.
		// wait 0.01.
	// }
	// Print "Starting CAB".
	// Set Start_burn_time to time:seconds.
	// Set HorzBurnTimeEta to HorzBurnTime + Start_burn_time.
	// Set TotBurnTimeEta to HorzBurnTime + Start_burn_time.
	// Print Start_burn_time.
	// Print HorzBurnTimeEta.
	// Print TotBurnTimeEta.
	// Print time:seconds.
	// Until time:seconds > HorzBurnTimeEta{
		// Lock Throttle to 1.0.
		// wait 0.01.
	// }
	// Lock Throttle to 0.0.
	// lock steering to ship:up:vector. // point upwards
} //End of Function

////////////////////////////////////////////////////////////////


////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

// Credits: www.moveable-type.co.uk

function hf_gs_distance {
parameter gs_p1, gs_p2. //(point1,point2). 
	//Need to ensure converted to radians TODO Test if this still works in degrees
	Set P1Lat to gs_p1:lat * constant:DegtoRad.
	Set P2Lat to gs_p2:lat * constant:DegtoRad.
	Set P1Lng to gs_p1:lng * constant:DegtoRad.
	Set P2Lng to gs_p2:lng * constant:DegtoRad.
	set resultA to 	sin((P1Lat-P2Lat)/2)^2 + 
					cos(P1Lat)*cos(P2Lat)*
					sin((P1Lng-P2Lng)/2)^2.
	set resultB to 2*arctan2(sqrt(resultA),sqrt(1-resultA)).
	set result to body:radius*resultB. // this is the "Haversine" formula go to www.moveable-type.co.uk for more information

	// set resultA to 	sin((gs_p1:lat-gs_p2:lat)/2)^2 + 
					// cos(gs_p1:lat)*cos(gs_p2:lat)*
					// sin((gs_p1:lng-gs_p2:lng)/2)^2.
	// set resultB to 2*arctan2(sqrt(resultA),sqrt(1-resultA)).
	// set result to body:radius*resultB. // this is the "Haversine" formula go to www.moveable-type.co.uk for more information
return result.
}

////////////////////////////////////////////////////////////////

// Credits: www.moveable-type.co.uk

function hf_gs_bearing {
parameter gs_p1, gs_p2. //(point1,point2). 
	//Need to ensure converted to radians TODO Test if this still works in degrees
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
////////////////////////////////////////////////////////////////

// Credits: Own

Function hf_PIDControlLoop{
Parameter lastdt, lastLat, lastLng.
	
	SET ALTSpeed TO sv_PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
	Set LATSpeed to sv_PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat degrees/sec
	Set LONGSpeed to sv_PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long degress/sec
	
	Set sv_PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
	Set sv_PIDNorth:SETPOINT to LATSpeed.
	Set sv_PIDEast:SETPOINT to LONGSpeed. 
	
	Set NorthSpeed to (gl_shipLatLng:Lat - lastLat)/(TIME:SECONDS-lastdt).
	Set EastSpeed to (gl_shipLatLng:Lng - lastLng)/(TIME:SECONDS-lastdt).
	
	SET ThrottSetting TO sv_PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
	SET NorthDirection TO sv_PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
	SET EastDirection TO sv_PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed

	Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
	Lock Throttle to ThrottSetting.	
	
	Set Flight_Arr to flight["Fall"].
	
	ClearScreen.
	Print "Landing".		
	Print "===============================".		
	Print "Lat: " + gl_shipLatLng:Lat.
	Print "Lat diff: " + sv_PIDLAT:Pterm/sv_PIDLAT:KP.		
	Print "PIDLAT Out: " + sv_PIDLAT:OUTPUT.			
	Print "Desired LATSpeed: " + LATSpeed.			
	Print "NorthSpeed: " + NorthSpeed.
	Print "NorthDirection: " + NorthDirection.		
	Print "===============================".		
	Print "Long: " + gl_shipLatLng:Lng.
	Print "Long diff: " + sv_PIDLONG:Pterm/sv_PIDLONG:KP.
	Print "PIDLONG Out: " + sv_PIDLONG:OUTPUT.
	Print "Desired LONGSpeed: " + LONGSpeed.
	Print "EastSpeed: " + EastSpeed.		
	Print "EastDirection: " + EastDirection.		
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
	Print "Alt" + ship:Altitude.
	Print "Ground Alt" + gl_surfaceElevation.
	Print "Radar" + gl_baseALTRADAR.
	Print "Heading: " + ship:heading.
	Print "Bearing: " + ship:bearing.
	Print "True Bearing: " + hf_gs_bearing(gl_shipLatLng,gl_NORTHPOLE).
	Print "===============================".
	Print "Base fall time: " + sqrt((2*gl_baseALTRADAR)/(gl_GRAVITY)).
	Print "Fall time: " + Flight_Arr["fallTime"].	
	Print "Fall vel: " + Flight_Arr["fallVel"].

	
	Set lastLat to gl_shipLatLng:Lat.
	Set lastLng to gl_shipLatLng:Lng.
	Set lastdt to TIME:SECONDS.
	Local Result is lexicon().
	Result:add("lastLat",lastLat).
	Result:add("lastLng",lastLng).
	Result:add("lastdt",lastdt).
	Return Result.
}



//////////////////////////////////////////////////////////
//// These are from others code and needs to be checked for reduncancy or if they can be used



function hf_geoDistance { //Approx in meters
	parameter geo1.
	parameter geo2.
	return (geo1:POSITION - geo2:POSITION):MAG.
}
function hf_geoDir { //compass angle of direction to landing spot
	parameter geo1.
	parameter geo2.
	return ARCTAN2(geo1:LNG - geo2:LNG, geo1:LAT - geo2:LAT).
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
	
  export(Util_landing).
} // End of anon