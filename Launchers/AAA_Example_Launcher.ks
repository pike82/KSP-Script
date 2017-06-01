
RUNONCEPATH (knu.ks).
PRINT ("Downloading Stage libraries").
//download dependant libraries first
local Landing is import("Landing").

Set Ship_Name TO SHIP:NAME.

//Print RECEIVED:CONTENT.
UNTIL CORE:MESSAGES:EMPTY { // until we have sent a message back
	Print "Inside Message Loop".
	SET RECEIVED TO CORE:MESSAGES:POP().
	IF RECEIVED:CONTENT = Core:Tag {
		PRINT CORE:Tag + " Powering Up".
		//set_runmode(1.1).
		SET MESSAGE TO Core:Tag+" Rcvd". // can be any serializable value or a primitive
		SET P TO Processor(Ship_Name).
		IF P:CONNECTION:SENDMESSAGE(MESSAGE) {
			PRINT "Message sent!".
		}
	} 	ELSE {
			PRINT "Unexpected message: " + RECEIVED:CONTENT.
		}
		Wait 2.0. //checks every second
}
Print "Waiting on Seperation".
Until Ship_Name <> SHIP:NAME { // Checks to see if it has been seperated from the main vessel
	Wait 3.0. 
}
Wait 3.0.

Set runMode to 1.1.
intParameters().
Print (runMode).

Function runModes{

	Print ("inside function runmodes").
	Print TVal.
	
	if runMode = 1.1 { 
		lock steering to ship:retrograde.
		Wait 10.
		set_runmode(1.2).
    }
	
	else if runMode = 1.2 { 
		Print ("Run mode is:" + runMode).
        Landing["Reentry"]().
		set_runmode(1.3).
    }
	
	else if runMode = 1.3 { 
		Print ("Run mode is:" + runMode).
        Landing["ParaLand"]().
		set_runmode(0).
		Processor:Deactivate. //turn off processor
    }
	
} /// end of function runmodes

	
Function intParameters {
    
	//Mission Parameters
    set tAP to 250000.
    set tPe to 250000.
	Set maxGeeTarget to 4.  //max G force to be experienced
	Set shipHeight to 25.	// the hieght of the ship to allow for height correction
	Set targetInclination to 1. //Desired Inclination
    Set targetAltitude to 85000. //Desired Orbit Altitude from Sea Level
    Set ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Set anglePitchover to 85. //Final Pitchover angle
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
	//SET intAzimith TO LaunchAzimuth(targetInclination,targetAltitude).
	
	
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

	
	