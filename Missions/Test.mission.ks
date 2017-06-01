
	Print ("intilising").
	PRINT ("Downloading libraries").
	//download dependant libraries first
	local Launch is import("Launch").
	local ORBMVR is import("ORBMVR").
	local ORBRV is import("ORBRV").
	local Landing is import("Landing").

	Set runMode to 1.1.
intParameters().
Print (runMode).

Function runModes{

	Print ("inside function runmodes").
	Print TVal.
	if runMode = 1.1 {
		Print("Run mode is:" + runMode).
        Launch["preLaunch"]().
		set_runmode(1.2).
    } 
	
	else if runMode = 1.2 {
		Print ("Run mode is:" + runMode).
        Launch["liftoff"]().
		set_runmode(1.3).
		Wait 5.
    } 
	
	else if runMode = 1.3 {
		Print ("Run mode is:" + runMode).
        Launch["liftoffclimb"]().
		set_runmode(1.41).
    }

	else if runMode = 1.41 {
		Print ("Run mode is:" + runMode).
        Launch["gravityTurn1"](-1.5).
		set_runmode(1.51).
    }
	
	else if runMode = 1.51 { 
		Print ("Run mode is:" + runMode).
        Launch["highTurn1"]().
		set_runmode(2.0).
		//Unlock Int function no longer used
		Unlock TWRTarget.
		Unlock rightrotation.
		Unlock right.
		Unlock up.
		Unlock fore.
		Unlock forehor.
		Unlock Top.
		Unlock AoA.	
    }
	
	else if runMode = 2.0 { 
		Print ("Run mode is:" + runMode).
        ORBMVR["Circ"](targetInclination,"apo",0.005,True).
		set_runmode(2.1).
    }

	else if runMode = 2.1 { 
		Print ("Run mode is:" + runMode).
        ORBRV["BodyTransfer"](Mun, 50000).
		wait 300.
		set_runmode(2.11).
    }
	
	else if runMode = 2.11 { 
		Print ("Run mode is:" + runMode).
		wait (ETA:TRANSITION / 2).
        ORBRV["BodyTransfer"](Mun, 50000,100,90). //mid course correction
		wait until ship:Orbit:body = Mun.
		wait 300.
		set_runmode(2.2).
    }

	// else if runMode = 2.1 { 
		// Print ("Run mode is:" + runMode).
        // ORBMVR["adjper"](Kerbin, 81000, 100).
		// wait 10.
		// set_runmode(2.2).
    // }
	
	else if runMode = 2.2 { 
		Print ("Run mode is:" + runMode).
        ORBMVR["Circ"](90,"per").
		Wait 30.
		set_runmode(2.3).
    }	
	
	else if runMode = 2.3 { 
		Print ("Run mode is:" + runMode).
        ORBRV["BodyTransfer"](Kerbin,80000,90).
		wait until ship:Orbit:body = Kerbin.
		wait 300.
		set_runmode(2.4).
	}	

	else if runMode = 2.4 { 
		Print ("Run mode is:" + runMode).
        ORBMVR["Circ"](90,"per",0.01).
		set_runmode(3.0).
    }
	
	else if runMode = 3.0 { 
		Print ("Run mode is:" + runMode).
		lock steering to ship:retrograde.
		Wait 10.
        Landing["DO_Burn"](0).
		set_runmode(3.1).
    }
	
	else if runMode = 3.1 { 
		Print ("Run mode is:" + runMode).
        Landing["SD_Burn"]().
		set_runmode(3.2).
    }
	
	else if runMode = 3.2 { 
		Print ("Run mode is:" + runMode).
        Landing["Reentry"]().
		set_runmode(3.3).
    }
	
	else if runMode = 3.3 { 
		Print ("Run mode is:" + runMode).
        Landing["ParaLand"]().
		set_runmode(0). //Set CPU to hibernate (5 minute intervals)
    }
	
} /// end of function runmodes

	
Function intParameters {
    
	//Mission Parameters
    set tAP to 250000.
    set tPe to 250000.
	Set maxGeeTarget to 4.  //max G force to be experienced
	Set shipHeight to 25.	// the hieght of the ship to allow for height correction
	Set targetInclination to 5. //Desired Inclination
    Set targetAltitude to 85000. //Desired Orbit Altitude from Sea Level
    Set ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Set anglePitchover to 87. //Final Pitchover angle
    Set gimbalLimit to 50. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Set MaxQLimit to 0.3. //Equivalent of 40Kpa Shuttle was 30kps and other like mercury were 40kPa. warning set this to approximately 30% lower than wanted depending on launch profile as momentum may make max q higher than this.
	Print "Mission Parameters".
	
	///////////////////////
	//Body Values
	//////////////////////
	

	//ORBIT
    set SEALEVELGRAVITY to (constant():G * body:mass) / body:radius^2.
    lock GRAVITY to SEALEVELGRAVITY / ((body:radius+ALTITUDE) / body:radius)^2.
	lock apoEta to max(0,ETA:APOAPSIS). //Return time to Apoapsis
	lock perEta to max(0,ETA:PERIAPSIS). //Return time to Periapsis
	Print "Orbit".
	//Location
	//set NORTHPOLE to latlng( 90, 0).
    //set KSCLAUNCHPAD to latlng(-0.0972092543643722, -74.557706433623).  //The launchpad at the KSC
    //lock landingtargetLATLNG to target:geoposition.
    lock shipLatLng to SHIP:GEOPOSITION.
    lock surfaceElevation to shipLatLng:TERRAINHEIGHT.
	SET intAzimith TO LaunchAzimuth(targetInclination,targetAltitude).
	
	
	///////////////
	//Ship Values
	///////////////
	Print "ship values".
	//Engines
	SET prevMaxThrust TO 0.
    lock TWR to MAX( 0.001, MAXTHRUST / (MASS*GRAVITY)).
	//set ENGINESAFETY to 1. //Engage engine safety
    //set TVAL to 0. //Working throttle value
    //set FINALtval to 0. //This will be what is written to the throttle
	lock TWRTarget to min( TWR, maxGeeTarget).
	Lock TVAL to min(TWRTarget/TWR, MaxQLimit / SHIP:Q). //use this to set the throttle as the TWR changes with time or the ship reaches max Q.
	Lock Throttle to TVAL.
	SET StageNo TO STAGE:NUMBER. //Get the Current Stage Number which contains the Main Engines
	Print "instrument".
	// Instrument stuff
    //lock totalSpeed to SURFACESPEED + ABS(VERTICALSPEED).
    lock betterALTRADAR to max( 0.1, min(ALTITUDE , ALTITUDE - surfaceElevation - shipHeight)).
    // lock impactTime to betterALTRADAR / -VERTICALSPEED.
    // lock killTime to (totalSpeed/GRAVITY) / (TWRTarget).
    // lock fallTime to (-VERTICALSPEED - sqrt( VERTICALSPEED^2-(2 * (-GRAVITY) * (betterALTRADAR - 0))) ) /  ((-GRAVITY)).
	
    //the following are all vectors, mainly for use in the roll, pitch, and angle of attack calculations
    lock rightrotation to ship:facing*r(0,90,0).
    lock right to rightrotation:vector. //right and left are directly along wings
    //lock left to (-1)*right.
    lock up to ship:up:vector. //up and down are skyward and groundward
    //lock down to (-1)*up.
    lock fore to ship:facing:vector. //fore and aft point to the nose and tail
    //lock aft to (-1)*fore.
    //lock righthor to vcrs(up,fore). //right and left horizons
    //lock lefthor to (-1)*righthor.
    lock forehor to vcrs(righthor,up). //forward and backward horizons
    //lock afthor to (-1)*forehor.
    lock top to vcrs(fore,right). //above the cockpit, through the floor
    //lock bottom to (-1)*top.
	Print "angles".
    //the following are all angles, useful for control programs
    //lock absaoa to vang(fore,srfprograde:vector). //absolute angle of attack
    lock aoa to vang(top,srfprograde:vector)-90. //pitch component of angle of attack
    //lock sideslip to vang(right,srfprograde:vector)-90. //yaw component of aoa
    //lock rollangle to vang(right,righthor)*((90-vang(top,righthor))/abs(90-vang(top,righthor))). //roll angle, 0 at level flight
    //lock pitchangle to vang(fore,forehor)*((90-vang(fore,up))/abs(90-vang(fore,up))). //pitch angle, 0 at level flight
    //lock glideslope to vang(srfprograde:vector,forehor)*((90-vang(srfprograde:vector,up))/abs(90-vang(srfprograde:vector,up))).
	Print "end of parameters".
}/////End of function

Function LaunchAzimuth {

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
	PRINT ("Azimuth:" + azimuth).    
	RETURN azimuth.   
} /////End of Launch Azimuth
	
	