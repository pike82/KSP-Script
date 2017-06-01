
{ // Start of anon

//http://www.bogan.ca/orbits/kepler/orbteqtn.html
//https://en.wikipedia.org/wiki/Orbital_mechanics

///// Download Dependant libraies
local Hill_Climb is import("Hill_Climb").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    local Orbit_Calc is lex(
		"EccOrbitVel", ff_EccOrbitVel@,
		"CircOrbitVel", ff_CircOrbitVel@,
		"Find_AN_INFO", ff_Find_AN_INFO@,
		"Find_AN_UT", ff_Find_AN_UT@,
		"TAr", ff_TAr@,
		"TAtimeFromPE", ff_TAtimeFromPE@
    ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

function ff_EccOrbitVel{
	parameter alt.
	parameter sma is ship:orbit:semimajoraxis.
	local vel is sqrt(Body:MU*((2/(alt+body:radius))-(1/sma))).
	return vel.
}
	
declare function ff_CircOrbitVel{
	parameter alt.
	return sqrt((constant:g*body:mass)/(alt+body:radius)).
}

Function ff_Find_AN_INFO {
	parameter tgt.
	///Orbital vectors
	local ship_V is ship:obt:velocity:orbit.//:normalized * 9000000000.
	local tar_V is tgt:obt:velocity:orbit.//:normalized * 9000000000.

	///Position vectors
	Local ship_r is ship:position - body:position.
	Local tar_r is tgt:position - body:position.

	////plane normals also known as H or angular momentum
	local ship_N is vcrs(ship_V,ship_r).//:normalized * 9000000000.
	local tar_N is vcrs(tar_V,tar_r).//:normalized * 9000000000.

	/// AN vector which is perpendicular to the plane normals
	set AN to vcrs(ship_N,tar_N):normalized. // the magnitude is irrelavent as it is a combination of parralellograms which has not real meaning
	Set AN_inc to vang(ship_N,tar_N). // the inclination change angle

	local arr is lexicon().
	arr:add ("ship_V", ship_V).
	arr:add ("ship_r", ship_r).
	arr:add ("ship_N", ship_N).
	arr:add ("tar_V", tar_V).
	arr:add ("tar_r", tar_r).
	arr:add ("tar_N", tar_N).
	arr:add ("AN", AN).
	arr:add ("AN_inc", AN_inc).
	
	Return (arr).
	
}/// End Function

Function ff_Find_AN_UT {
//TODO: Remove redundant code relating to sector adjustment once fully tested.
//TODO: Remove redundant code relating to Ship TA and AN Eccetric anomoly and Mean anomoly once the time to PE code is fully tested.
//TODO: Remove redundant array call from AN info.
	parameter tgt.
	Print "Finding AN/DN..".		  
	//Conduct manever at the AN or DN to ensure inclination	is spot on and low dv.
	local arr is lexicon().
	Set arr to ff_Find_AN_INFO(tgt).
	Set ship_V to arr ["ship_V"].
	Set ship_r to arr ["ship_r"].
	Set ship_N to arr ["ship_N"].
	Set tar_V to arr ["tar_V"].
	Set tar_r to arr ["tar_r"].
	Set tar_N to arr ["tar_N"].
	Set ship_V to arr ["ship_V"].
	Set AN to arr ["AN"].
	Set AN_inc to arr ["AN_inc"].

	//Current Ship Information.
	Set Ship_e to Ship:orbit:Eccentricity.
	Set Ship_Per to Ship:orbit:Period.
	Set ship_eta_apo to eta:apoapsis.
	Set ship_eta_PE to eta:periapsis.
	Set Ship_a to ship:orbit:SEMIMAJORAXIS.

//// Below is possibly redundant code relating to ensure the TA value is correct for all sectors of an orbit. The new TA calculation looks to take this into account sufficiently however this is to be kept untll this function is tested for all sectors of the orbit.	

	// //Calculate True Anomoly
	// Set Ship_True_Anom to hf_DegToRad(ff_TAr(ship_r:mag, ship_a, ship_e)).
	// // Print "Ship True Anom" + Ship_True_Anom.
	//Calculate True anomoly for AN
	Set AN_True_Anom to hf_DegToRad(hf_TAvec(AN)).
	Print "AN True Anom alt Rad" + AN_True_Anom.
	
	// //Determine what segment of the orbit the ship is in to determine how the Anomoly is used to calculate AN UT.
	// Print "vdot: " + vdot(vcrs(Ship_N,AN),Ship_r).//(DNPE+ , PEAN +), (ANAP -, APDN -)
	// //DNPE Set AN_True_Anom to AN_True_Anom - Ship_True_Anom
	// //PEAN Set AN_True_Anom to AN_True_Anom + Ship_True_Anom (full circuit) Set AN_True_Anom to AN_True_Anom + Ship_True_Anom (near circuit)
	// //ANAP Set AN_True_Anom to Ship_True_Anom - AN_True_Anom
	// //APDN Set AN_True_Anom to 2*constant:pi - Ship_True_Anom - AN_True_Anom

	// Print "vang(Ship_r,AN) deg" + vang(Ship_r,AN).
	// If ship_eta_PE > ship_eta_apo{
		// If vdot(vcrs(Ship_N,AN),Ship_r) > 0 {
			// Set AN_True_Anom to AN_True_Anom_old + Ship_True_Anom. //PEAN
		// } 
		// ELSE {
			// Set AN_True_Anom to Ship_True_Anom - AN_True_Anom. //ANAP
		// }
	// } //end if
	// Else{
		// If vdot(vcrs(Ship_N,AN),Ship_r) > 0 {
			// Set AN_True_Anom to AN_True_Anom_old - Ship_True_Anom. //DNPE
		// } 
		// ELSE {
			// Set AN_True_Anom to 2*constant:pi - Ship_True_Anom - AN_True_Anom. //APDN
		// }
	// } // end else
	// Print "AN True Anom Rad orbit adjusted for sector" + AN_True_Anom.

	Set AN_Ecc_Anom to hf_EccAnom(Ship_e, AN_True_Anom).
	Print "AN Ecc Anom Rad" + AN_Ecc_Anom.
	Set AN_Mean_Anom to hf_MeanAnom (Ship_e, AN_Ecc_Anom).
	Print "AN Mean Anom Rad" + AN_Mean_Anom.

	Set AN_time_From_PE to ff_TAtimeFromPE(AN_True_Anom,Ship_e).
	Print "AN_time_From_PE: " + AN_time_From_PE.
	Set AN_time to ship_eta_PE + AN_time_From_PE.
	Print "AN_time " + AN_time.	
	
	If (time:seconds + AN_time) < (time:seconds + 240){
		Set AN_time to time:seconds + AN_time + Ship_Per. //put on next orbit as its too close to calculate in time.
	}
	Else {
		Set AN_time to time:seconds + AN_time.
	}
	
	Print "AN_time UT" + AN_time.
	
	//Refine the UT using hill climb
	Hill_Climb["Seek"](AN_time, Hill_Climb["freeze"](0), Hill_Climb["freeze"](0), Hill_Climb["freeze"](0), { 
		parameter mnv. 
		Set AN_time to time:seconds + mnv:ETA.
		return - vang ((positionat(ship, time:seconds + mnv:eta)-body:position),AN). // want the angle to be zero between the ship radial vector and the AN node.
		}
	).
	Print "Final AN time" + AN_time.
	Remove nextnode.
	wait 0.1.
	Return (AN_time).

}/// End Function

function ff_TAr {
	parameter r, SMA, ecc. // full orbital radius, Semimajoraxis, eccentricity.
	local p is hf_OrbSLR(SMA, ecc).
	local TA is arccos(p / r / ecc - 1 / ecc).
	//Print "TAr:" + TA.
	return TA. // Returns the True Anomoly at specified radius in degress
	//Old version
	//Set TA to ((ship_a*(1-(ship_e*ship_e))) - ship_r:mag) / (ship_e * ship_r:mag).
	//Set TA to arccos( TA ).//eq(4.82)
	
}

function ff_TAtimeFromPE {
	parameter TA, ecc. // True anomoly (must be in radians), eccentricity.
	local EA is hf_EccAnom(ecc, TA).
	Print "EA:" + EA.
	local MA is hf_MeanAnom(ecc, EA).
	Print "MA:" + MA.
	local TA_time is MA/(2*constant:pi/Ship:orbit:Period).
	//Print "TA Time From PE:" + TA_time.
	return TA_time. //TA time from PE in seconds
}


////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

function hf_OrbVel {
	parameter r, SMA, mu. // full orbital raduis, Semimajoraxis, mu.
	return sqrt(mu * (2 / r - 1 / SMA)). //returns Orbital velocity for specific orbit and radius
}

function hf_OrbPer {
	parameter a, mu. // Semimajoraxis, mu.
	return 2 * constant:pi * sqrt(a^3/mu).//returns Orbital period
}

function hf_HorVecAt {
	parameter ut. // universal time
	local vBod is ship:body:position - positionat(ship, ut).
	return vxcl(vBod,velocityat(ship, ut):orbit). //returns the surface horizontal velocity vector component of the ship vector at a specific time. 
}

function hf_OrbSLR {
	parameter SMA, ecc. // Semimajoraxis, eccentricity.
	Local p is SMA * (1 - ecc ^ 2).
	//Print "SLR:" + p.
	return p. //Returns the Semilatus rectum
}

function hf_TAvec {
	parameter vec. // a vector along ships orbit that you want the TA for.
	set orbnorm to hf_normalvector(ship). // gives vector from ship to centre of body
	set vecProj to vxcl(orbnorm,vec). // this provides the vector projected to the ships current plane
	set vPEr to positionat(ship,time:seconds+eta:periapsis)-ship:body:position. // gives vector of periapsis
	set TA to vang(vPEr,vecProj). // give angle between the two (TA raw)
	if abs(vang(vecProj,vcrs(orbnorm,vPEr))) < 90 {
		return 360-TA.
	}
	else{
		return TA. // Returns the True Anomoly of a vector along the ships orbit in degrees
	}
}

function hf_EccAnom {
	parameter ecc, TA. // eccentricity, True Anomoly (in radians or degrees).
	local E is arccos((ecc + cos(TA)) / (1 + ecc * cos(TA))).
	//Print "EccAnom:" + E.
	return E. //Eccentric Anomoly in True anomoly input (radians or degrees)
	//Old version
	//Set E to arctan(sqrt(1-(ecc*ecc))*sin(TA) ) / ( ecc + cos(TA) )
}

function hf_MeanAnom {
	parameter ecc, EccAnom. // eccentricity, Eccentric Anomoly (in radians or degrees).
	local MA is EccAnom - ecc * sin(EccAnom).
	//Print "MeanAnom:" + MA.
	return MA. //Mean Anomoly in EccAnom input(radians or degrees)
}

function hf_quadraticPlus {
	parameter a, b, c.
	return (b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
}

function hf_quadraticMinus {
	parameter a, b, c.
	return (-b - sqrt(max(b ^ 2 - 4 * a * c, 0))) / (2 * a).
}

function hf_normalvector{
	parameter ves.
	set vel to velocityat(ves,time:seconds):orbit.
	set norm to vcrs(vel,ves:up:vector). 
	return norm:normalized.// gives vector pointing towards centre of body from ship
}

function hf_RadToDeg {
	parameter rad.
	return rad * 180 / constant:pi. // converts angles in radians to degrees
}
function hf_DegToRad {
	parameter deg.
	return deg * constant:pi / 180. // converts angles in degrees to radians
}

// declare function clamp360 {
	// declare parameter deg360.
	// if (abs(deg360) > 360) { 
		// set deg360 to mod(deg360, 360). 
	// }
	// until deg360 > 0 {
		// set deg360 to deg360 + 360.
	// }
	// return deg360.
// }

// declare function clamp180 {
	// declare parameter deg180.
	// set deg180 to clamp360(deg180).
	// //if deg > 180 { return 360 - deg. } // always returned positive, wanted to get negative, but not sure that I'm not exploiting the bug
	// if deg180 > 180 { return deg180 - 360. }
	// return deg180.
// }


// declare function getEtaTrueAnomOrbitable {
	// declare parameter ta, ves.
	// local ecc is ves:obt:eccentricity.
	// local mu is ves:body:mu.
	// local a is ves:obt:semimajoraxis.
	// local ta0 is ves:obt:trueanomaly.
    // set ta to clamp360(ta).
	// local En is getEAnom(ecc, ta).
	// local E0 is getEAnom(ecc, ta0).
	// local Mn is getMAnom(ecc, En).
	// local M0 is getMAnom(ecc, E0).
	// local dM is Mn - M0.
	// local eta is dM/RadToDeg(sqrt(mu/(abs(a^3)))).
	// until eta > 0 {
		// set eta to eta + ves:obt:period.
	// }
	// until eta < ves:obt:period {
		// set eta to eta - ves:obt:period.
	// }
	// return eta.
// }




// declare function ANTA{
	// parameter orb1.
	// parameter orb2.
	// set van to vcrs(normalvector(orb1),normalvector(orb2)). //AN vector to body centre
	// return TAFV(van).
// }




///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(Orbit_Calc).
} // End of anon

