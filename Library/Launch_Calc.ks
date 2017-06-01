
{ // Start of anon

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Launch_Calcs is lex(
		"LaunchAzimuth", ff_LaunchAzimuth@,
		"launchwindow", ff_launchwindow@
	).

	
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

//TODO:	Add in a launch window calculator. look at the KOS-Stuff_master launch window file for inspiration.

//Calculates the Azimuth required at Launch to meet a specific inclination on a body
Function ff_LaunchAzimuth {

PARAMETER targetInclination, targetAltitude.

	PRINT "Finding Azimuth".

	SET launchLoc to SHIP:GEOPOSITION.
	SET initAzimuth TO arcsin(max(min(cos(targetInclination) / cos(launchLoc:LAT),1),-1)). //Sets the intital direction for launch to meet the required azimuth
	SET targetOrbitSpeed TO SQRT(SHIP:BODY:MU / (targetAltitude+SHIP:BODY:RADIUS)). // Sets the orbital speed based on the target altitude
	SET bodyRotSpeed TO (SHIP:BODY:RADIUS/SHIP:BODY:ROTATIONPERIOD). //Sets the rotational velocity at the equator
	SET rotvelx TO targetOrbitSpeed*sin(initAzimuth) - (bodyRotSpeed*cos(launchLoc:LAT)). //Sets the x vector required adjusted for launch site location away from the equator
	SET rotvely TO targetOrbitSpeed*cos(initAzimuth). //Sets the y Vector required
	SET azimuth TO (arctan(rotvelx / rotvely)). //Sets the adjusted inclinationation angle based on the rotation of the planet
	//SET azimuth TO -(arctan(rotvelx / rotvely))+180. //Sets the adjusted inclinationation angle based on the rotation of the planet
	IF targetInclination < 0 {
		SET azimuth TO 180-azimuth.
	} //Normalises to a launch in the direction of body rotation
	PRINT ("Lanuch Azimuth:" + azimuth).    
	RETURN azimuth.   
} // End of Function
	
/////////////////////////////////////////////////////////////////////////////////////

function ff_launchwindow{
Parameter target.
Parameter ascendLongDiff is 0.2.

	local IncPoss is true.
	//  Lock the angle difference to the solar prime  
	lock DeltaLAN to mod((360-target:orbit:lan) + body:rotationangle,360). // gets the modulas (remainder from integer division) to get the angle to the LAN
	
	// Obtain the ship Longitude in a 360 degree reference (default is -180 to 180)
	if longitude<0
		set shiplon to abs(longitude).
	else
		set shiplon to 360-longitude.
	
	if target:orbit:inclination < abs(latitude) { //If the inclination of the target is less than the lattidue of the ship it will not pass over the site as the max latitude of its path is too low.
		set IncPoss to False.
		set incDiff to ship:orbit:inclination-target:orbit:inclination.
		Print "Latitude unable to allow normal Launch to inclination!!!".
	}
	else{// A normal launch is possible with the target passing overhead.
		set offset to hf_tricalc().
		set incDiff to 0.
	}
	
	local diffPlaneAng is 1000. //Set higher than the max inclination so it enters the loop
	//TODO: Look into making the untill loop +0.2 soft coded as this may be different on other bodies
	until diffPlaneAng < incDiff + ascendLongDiff{
		if diffPlaneAng > 30{
			set warp to 4.
		}
		else if diffPlaneAng < 50 and diffPlaneAng > incDiff + 6{
			set warp to 4.
		}
		else if diffPlaneAng <incDiff +6 and diffPlaneAng > incDiff + 1.5{
			set warp to 3.
		}
		else if diffPlaneAng <incDiff +1.5 and diffPlaneAng > incDiff + 1.0{
			set warp to 2.
		}
		else if diffPlaneAng <incDiff +1.0 and diffPlaneAng > incDiff + 0.2{
			set warp to 1.
		}
		if IncPoss = False {
			set diffPlaneAng to vang(hf_normalvector(ship),hf_normalvector(target)).// finds the angle between the orbital planes
			Print "Relative Inclination:   " + diffPlaneAng.
			print "Minimum R. Inclination: " + incDiff.
		}
		else{
			set diffPlaneAng to abs((shiplon + offset) - DeltaLAN).
			print "Relative LAN to Target: " + diffPlaneAng.
		}
		wait .001.
	}
	set warp to 0.
	wait 5.
	return.
}

////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////

function hf_tricalc{
	local a is latitude.
	local alpha is target:orbit:inclination.
	local b is 0.
	local c is 0.
	local bell is 90.
	local gamma is 0.
	if sin(a)*sin(bell)/sin(alpha) >1 {
		set b to 90.
		}
	else{
		set b to arcsin(sin(a)*sin(bell)/sin(alpha)).
	}
	set c to 2*arctan(tan(.5*(a-b))*(sin(.5*(alpha+bell))/sin(.5*(alpha-bell)))).
	return c.
}

function hf_normalvector{
	parameter ves.
	set vel to velocityat(ves,time:seconds):orbit.
	set norm to vcrs(vel,ves:up:vector). 
	return norm:normalized.// gives vector pointing towards centre of body from ship
}

/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Launch_Calcs).
} // End of anon
