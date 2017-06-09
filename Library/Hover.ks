
{ // Start of anon

///// Download Dependant libraies
local Staging is import("Staging").
local Orbit_Calc is import("Orbit_Calc").
local Node_Calc is import("Node_Calc").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

	local landing_vac is lex(
		"SuBurn",ff_SuBurn@,
		"SuBurn_NoThrottle",ff_SuBurn_NoThrottle@,
		"CABLand", ff_CABLand@,
		"CABLand_NoThrottle", ff_CABLand_NoThrottle@,
		"Hover",ff_Hover@
	).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

Function ff_SuBurn {	
Parameter SafeAlt is 50, TargetLatLng is "Null", MaxSlopeAng is 1.

Until (gl_fallTime < (gl_fallBurnTime + (SafeAlt/ship:verticalspeed))) or (gl_fallDist < ( gl_baseALTRADAR + SafeAlt)){
	Clearscreen.
	Print "gl_InstMaxVertAcc:" + gl_InstMaxVertAcc.
	Print "gl_fallTime:" + gl_fallTime.
	Print "gl_fallVel:" + gl_fallVel.
	Print "gl_fallDist:" + gl_fallDist.
	Print "gl_fallBurnTime:" + gl_fallBurnTime.
	Wait 0.001.
}
until (Ship:Status = "LANDED"){
	Lock Throttle to minstopDist / gl_baseALTRADAR.
	if (gl_baseALTRADAR < 0.25) or (Ship:Status = "LANDED"){
		Lock Throttle to 0.
		Break.
	}
} // end Until
} //End of Function


////////////////////////////////////////////////////////////////

Function ff_SuBurn_NoThrottle {	
Parameter SafeAlt is 5, TargetLatLng is "Null", MaxSlopeAng is 1.

Lock maxDeAcel to (ship:availiblethrust / ship:mass) - gl_GRAVITY. //gives max acceleration upwards at this point in time
Lock fallTime to Orbit_Cals["quadraticMinus"](gl_GRAVITY, ship:verticalspeed, gl_baseALTRADAR).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation at2^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
lock ImpactVel to ship:verticalspeed + (gl_GRAVITY*fallTime).//v = u + at
lock minstopDist to ship:verticalspeed^2 / (2*maxDeAcel). // v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a
Lock ShipBurnTime to Node_Calc["burn_time"](ImpactVel). 

Until (fallTime < (ShipBurnTime +(Safealt/ship:verticalspeed)) or (minstopDist < ( gl_baseALTRADAR +SafeAlt)){
	Clearscreen.
	Print "maxDeAcel:" + maxDeAcel.
	Print "fallTime:" + fallTime.
	Print "ImpactVel:" + ImpactVel.
	Print "minstopDist:" + minstopDist.
	Print "ShipBurnTime:" + ShipBurnTime.
	Wait 0.001.
}

until (Ship:Status = "LANDED"){
	Lock Throttle to 1.
	if (fallTime < (ShipBurnTime +(Safealt/ship:verticalspeed)) or (minstopDist < ( gl_baseALTRADAR +SafeAlt)){
		Lock Throttle to 0.
		Break.
	}
}
	
} //End of Function

////////////////////////////////////////////////////////////////

Function ff_CABLand{ 
	Parameter SafeAlt is 50, TargetLatLng is "Null", MaxSlopeAng is 1.
	
	Set HorzBurn to velocityat(Ship, gl_perEta + TIME:SECONDS):Surface.
	Set PeVerBurnDist to Orbit:Periapsis - (gl_PeLatLng:TERRAINHEIGHT + SafeAlt + (sv_shipHeight/2)). 
	Set PeGravity to gl_SEALEVELGRAVITY / ((Orbit:Periapsis+ALTITUDE) / body:radius)^2.
	Set VerBurn to sqrt(2*PeGravity*PeVerBurnDist).
	Set HorzBurnTime to Node_Calc["burn_time"](HorzBurn).
	Set VerBurnTime to Node_Calc["burn_time"](VerBurn).
	Set VerBurnTime to VerBurnTime
	Set totalBurnTime to HorzBurnTime + VerBurnTime.
	Set fallTime to Orbit_Cals["quadraticMinus"]((PeGravity+gl_SEALEVELGRAVITY)/2, 0, PeVerBurnDist)//r = r0 + vt - 1/2at^2 ===> Quadratic equiation at2^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
} //End of Function

////////////////////////////////////////////////////////////////

Function ff_CABLand_NoThrottle{ 
	Parameter SafeAlt is 50, TargetLatLng is "Null", MaxSlopeAng is 1.
	
	Set HorzBurn to velocityat(Ship, gl_perEta + TIME:SECONDS):Surface.
	Set PeVerBurnDist to Orbit:Periapsis - (gl_PeLatLng:TERRAINHEIGHT + SafeAlt + (sv_shipHeight/2)). 
	Set PeGravity to gl_SEALEVELGRAVITY / ((Orbit:Periapsis+ALTITUDE) / body:radius)^2.
	Set VerBurn to sqrt(2*PeGravity*PeVerBurnDist).
	Set HorzBurnTime to Node_Calc["burn_time"](HorzBurn).
	Set VerBurnTime to Node_Calc["burn_time"](VerBurn).
	Set VerBurnTime to VerBurnTime
	Set totalBurnTime to HorzBurnTime + VerBurnTime.
	Set fallTime to Orbit_Cals["quadraticMinus"]((PeGravity+gl_SEALEVELGRAVITY)/2, 0, PeVerBurnDist)//r = r0 + vt - 1/2at^2 ===> Quadratic equiation at2^2 + bt + c = 0 a= acceleration, b=velocity, c= distance

} //End of Function

////////////////////////////////////////////////////////////////

Function ff_hover {	

	
} //End of Function

////////////////////////////////////////////////////////////////

lock steerdir to lookdirup(-ship:velocity:surface, topvec).
lock steering to steerdir.

set steeringmanager:pitchpid:kp to 2.
set steeringmanager:yawpid:kp to 2.
set steeringmanager:rollpid:kp to 2.

set mu to ship:body:mu.

set vh to 0.
set lowestpart to ship:rootpart.
set vh to vdot(lowestpart:position, ship:facing:vector).
for p in ship:parts {
    local tmp is vdot(p:position, ship:facing:vector).
    if tmp < vh {
        set lowestpart to p.
        set vh to tmp.
    }
}
lock vesselH to -vdot(lowestpart:position - ship:rootpart:position, ship:facing:vector).
lock height to max(altitude - ship:geoposition:terrainheight - vesselH - 1, 0.01).

lock localg to mu / (ship:position - ship:body:position):mag ^ 2.
lock maxAccel to ship:availablethrust/ship:mass.
lock vAccel to ship:availablethrust/ship:mass * max(vdot(ship:up:vector, ship:facing:vector), 0.1).
lock hAccel to ship:availablethrust/ship:mass * vxcl(ship:facing:vector, ship:up:vector):mag.
lock targetAccel to vVel ^ 2 / 2 / height.

lock tset to (targetAccel + localg) / vAccel.

set burntime to 0.
set burnEta to 9 * 10^10.
set tmp1 to 0.
set tmp2 to 0.

lock impactEta to quadraticMinus((vAccel * throttle - localg) / 2, vVel, height).


////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////


function hf_terrainDist { //GEOPOSITION:TERRAINHEIGHT doesn't see water so it will be negative (underwater)if over water.
	if SHIP:GEOPOSITION:TERRAINHEIGHT > 0{
		RETURN SHIP:ALTITUDE - SHIP:GEOPOSITION:TERRAINHEIGHT.
	} else {
		RETURN SHIP:ALTITUDE.
	}
}
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
    return Orbit_Calcs["quadraticMinus"]((acc * thrtl - g), vel, h).
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