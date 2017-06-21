
{ // Start of anon

///// Download Dependant libraies
local Staging is import("Staging").
local Orbit_Calcs is import("Orbit_Calc").
local Node_Calc is import("Node_Calc").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

	local landing_vac is lex(
		"SuBurn",ff_SuBurn@,
		"CABLand", ff_CABLand@,
		"HoverLand",ff_HoverLand@
	).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

Function ff_SuBurn {	
Parameter ThrottelStartUp is 0.1, SafeAlt is 50, EndVelocity is 1. // end velocity must be positive

Until gl_fallDist < ( gl_baseALTRADAR + SafeAlt + (ThrottelStartUp * ship:verticalspeed)){ 
	//Run screen update loop to inform of suicide burn wait.
	Clearscreen.
	Print "maxStopAcc:" + maxStopAcc.
	Print "gl_fallTime:" + gl_fallTime.
	Print "gl_fallVel:" + gl_fallVel.
	Print "gl_fallDist:" + gl_fallDist.
	Print "gl_fallBurnTime:" + Node_Calc["burn_time"](gl_fallVel).
	Wait 0.001.
}

until (Ship:Status = "LANDED") or verticalspeed < EndVelocity  {
	Lock Throttle to 1.0.
	if (gl_baseALTRADAR < 0.25) or (Ship:Status = "LANDED"){
		Lock Throttle to 0.
		Break.
	}
} // end Until

if (gl_baseALTRADAR < 0.25) or (Ship:Status = "LANDED"){
	Lock Throttle to 0.
} // Note: if the ship does not meet these conditions the throttle will still be locked a 1, you will need to ensure a landing has taken place or add in another section in the runtime to ensure the throttle does not stay at 1.
} //End of Function


////////////////////////////////////////////////////////////////

Function ff_CABLand{ 
	Parameter ThrottelStartUp is 0.1, SafeAlt is 50, TargetLatLng is "Null", MaxSlopeAng is 1.
	
	Set PePos to positionat(Ship, gl_perEta + TIME:SECONDS).
	Set ShipPeUpVec to PePos - body:position.
	Set PEVel to velocityat(Ship, gl_perEta + TIME:SECONDS):Surface.
	//horz
	Set PeHorzVel to vxcl(ShipPeUpVec:normalized, PEVel):mag.
	//Vertical
	Set PeVerVel to vdot(ShipPeUpVec:normalized, PEVel):mag.
	Set PeVerBurnDist to Orbit:Periapsis - (gl_PeLatLng:TERRAINHEIGHT + SafeAlt). 
	Set PeAvgGravity to sqrt(		(	(body:mu / (Orbit:Periapsis+ALTITUDE)^2) +((body:mu / (gl_PeLatLng:TERRAINHEIGHT + body:radius)^2 )^2)		)/2		).// Root Mean square method
	Set PeFallTime to Orbit_Calc["quadraticPlus"](-PeAvgGravity/2, -PeVerVel, PeVerBurnDist).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	Set PeFallVel to abs(PeVerVel) + (PeAvgGravity*PeFallTime).//v = u + at
	//times
	Set HorzBurnTime to Node_Calc["burn_time"](PeHorzVel).
	Set VerBurnTime to Node_Calc["burn_time"](PeFallVel).
	Set totalBurnTime to HorzBurnTime + VerBurnTime.
	
	Until gl_perEta < HorzBurnTime {
	lock steering to lookdirup(-ship:velocity:surface, gl_Top). //point retrograde
		wait 0.01.
		ClearScreen.
		Print "Waiting For Burn Start".
	}
	
	Set Start_burn_time to time:seconds.
	Set HorzBurnTimeEta to HorzBurnTime + Start_burn_time.
	
	Until time:seconds < HorzBurnTimeEta{
		Lock Throttle to 1.0.
		ClearScreen.
		Print "Commencing CAB".
	
	}
	lock steering to gl_up. // point upwards
} //End of Function

////////////////////////////////////////////////////////////////


Function ff_hover {	
Parameter Hover_alt is 50, BaseLoc is gl_shipLatLng 
	Set sv_PIDALT:SETPOINT to Hover_alt.
	Set sv_PIDLAT:Setpoint to BaseLoc:Lat.
	Set sv_PIDLONG:Setpoint to BaseLoc:Lng.
	
	Set distanceTol to 0.
	
	Until distanceTol < 3 { // until the ship is hovering above the set down loaction for 3 seconds (to allow for PID stability)
		hf_PIDControlLoop().
		if gs_distance(BaseLoc,gl_shipLatLng) < 0.1{
			Set distanceTol to distanceTol + 0.1	
		}
		Else{
			Set distanceTol to 0.
		}

		Wait 0.1.
	}	

	
} //End of Function

////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////
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

Function hf_PIDControlLoop{
	SET ALTSpeed TO PIDALT:UPDATE(TIME:SECONDS, gl_baseALTRADAR). //Get the PID on the AlT diff as desired vertical velocity
	Set LATSpeed to PIDLAT:Update(TIME:SECONDS, gl_shipLatLng:Lat).//Get the PID on the Lat diff as desired lat degrees/sec
	Set LONGSpeed to PIDLONG:UPDATE(TIME:SECONDS, gl_shipLatLng:Lng). //Get the PID on the Long diff as desired long degress/sec
	
	Set PIDThrott:SETPOINT to ALTSpeed. // Set the ALT diff PID as the desired vertical speed
	Set PIDNorth:SETPOINT to LATSpeed.
	Set PIDEast:SETPOINT to LONGSpeed. 
	
	Set NorthSpeed to (gl_shipLatLng:Lat - lastLat)/(TIME:SECONDS-lastdt).
	Set EastSpeed to (gl_shipLatLng:Lng - lastLng)/(TIME:SECONDS-lastdt).
	
	SET ThrottSetting TO PIDThrott:UPDATE(TIME:SECONDS, verticalspeed). // PID the vertical velocity with the new desired speed
	SET NorthDirection TO PIDNorth:UPDATE(TIME:SECONDS, NorthSpeed). // PID the North velocity with the new desired speed
	SET EastDirection TO PIDEast:UPDATE(TIME:SECONDS, EastSpeed). // PID the East velocity with the new desired speed

	Set SteerDirection to UP + r(-NorthDirection,-EastDirection,180). // r(pitch, yaw, roll) set roll to zero, this will allow pitch to equal Lat(North) direction required and Yaw(East) to equal Long direction required		
		
	
	ClearScreen.
	Print "Landing".		
	Print "Time Passed: " + (TIME:SECONDS - Timebase).
	Print "===============================".
	Print "Base: " + BaseLoc.
	Print "===============================".		
	Print "Lat: " + gl_shipLatLng:Lat.
	Print "Lat diff: " + PIDLAT:Pterm/PIDLAT:KP.		
	Print "PIDLAT Out: " + PIDLAT:OUTPUT.			
	Print "Desired LATSpeed: " + LATSpeed.			
	Print "NorthSpeed: " + NorthSpeed.
	Print "NorthDirection: " + NorthDirection.		
	Print "===============================".		
	Print "Long: " + gl_shipLatLng:Lng.
	Print "Long diff: " + PIDLONG:Pterm/PIDLONG:KP.
	Print "PIDLONG Out: " + PIDLONG:OUTPUT.
	Print "Desired LONGSpeed: " + LONGSpeed.
	Print "EastSpeed: " + EastSpeed.		
	Print "EastDirection: " + EastDirection.		
	Print "===============================".	
	Print "ALT Kp: " + PIDALT:Pterm.
	Print "ALT Ki: " + PIDALT:Iterm.
	Print "ALT Kd: " + PIDALT:Dterm.
	Print "ALT Out: " + PIDALT:OUTPUT.
	Print "===============================".
	Print "Thrott Kp: " + PIDThrott:Pterm.
	Print "Thrott Ki: " + PIDThrott:Iterm.
	Print "Thrott Kd: " + PIDThrott:Dterm.
	Print "Thrott Out: " + PIDThrott:OUTPUT.
	Print "===============================".
	//Print "Delta throttle: "+ dThrot.
	Print "Throttle Setting: "+ ThrottSetting.
	Print "Radar" + gl_baseALTRADAR.
	Print "Distance from Base: " + gs_distance(BaseLoc,gl_shipLatLng).
	Print "Heading: " + ship:heading.
	Print "Bearing: " + ship:bearing.
	Print "True Bearing: " + gs_bearing(gl_shipLatLng,gl_NORTHPOLE).
	Print "===============================".
	Print "Base fall time: " + sqrt((2*gl_baseALTRADAR)/(gl_GRAVITY)).
	Print "Fall time: " + gl_fallTime.	
	Print "Fall time alt: " + gl_fallTimealt.	
	Print "Fall vel: " + gl_fallVel.
	Print "Fall dist: " + gl_fallDist.
	Print "Fall burn time: " + Node_Calc["burn_time"](gl_fallVel).
	Print "Max fall acceleration: " +gl_fallAcc.
	// Switch to 0.
	// LOG (TIME:SECONDS - Timebase) + "," + verticalspeed + "," + ThrotSetting TO "testflight.csv".
	// Switch to 1.
	Set lastLat to gl_shipLatLng:Lat.
	Set lastLng to gl_shipLatLng:Lng.
	Set lastdt to TIME:SECONDS.
}

//// These are fomr others code and needs to be checked for reduncancy or if they can be used



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
	
  export(landing_vac).
} // End of anon