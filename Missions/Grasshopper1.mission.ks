Print ("Intilising other CPU's").

Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 1500.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script
Print "New Config:IPU Setting:" + Config:IPU.
Set Config:Stat to false.
	
LIST PROCESSORS IN ALL_PROCESSORS.

Set CORE:Part:Tag To SHIP:NAME.

for Processor in ALL_PROCESSORS {
	Print Processor:Tag.
	If Processor:Tag:CONTAINS("Stage"){
		SET MESSAGE TO Processor:Tag. // can be any serializable value or a primitive
		SET P TO PROCESSOR(Processor:Tag).
		IF P:CONNECTION:SENDMESSAGE(MESSAGE) {
			PRINT "Message sent to Inbox Stack!".
		}
		//Processor:Deactivate.
		Print Processor:Tag + " Files moved".
		copypath("0:/Launchers/" + Processor:Tag +".ks",Processor:Tag + ":/Boot.ks").
		copypath("0:/Library/knu.ks",Processor:Tag + ":/").
		set processor:bootfilename to "Boot.ks". // sets the bootfile so when activated this file will run
		Processor:Activate.
		WAIT UNTIL NOT CORE:MESSAGES:EMPTY. // If the processor activates properly it will pick up the message sent before deactivation and send a reponse everything is working
		SET RECEIVED TO CORE:MESSAGES:POP.
		IF RECEIVED:CONTENT = Processor:Tag + " Rcvd" {
			PRINT Processor:Tag + "Started".
		} ELSE {
		  PRINT "Unexpected message: " + RECEIVED:CONTENT.
		}
	}
}.		
 wait 0.5. // ensure above mesage process has finished	
 
 //TODO: Look at implimenting a Flight readout script like the KOS-Stuff_master gravity file for possible implimentation.
 
PRINT ("Downloading libraries").
//download dependant libraries first
	local Launch is import("Launch_atm").
	local Orbit_Calc is import("Orbit_Calc").
	local Node_Calc is import("Node_Calc").
	local landing is import("Landing_vac").
	local ORBManu is import("ORBManu").
	
intParameters().
Print runMode["runMode"].

Function Mission_runModes{
Stage. //load engines
		
	if runMode["runMode"] = 0.1 { 
		Print "Run mode is:" + runMode["runMode"].
		Node_Calc["User_Node_exec"]().
		gf_set_runmode("runMode",1.0).
		wait 5.
	}
	
	else if runMode["runMode"] = 1.0 { 
		Print "Run mode is:" + runMode["runMode"].
		landing["CABLand"]().
		gf_set_runmode("runMode",1.1).
		wait 5.
	}
	else if runMode["runMode"] = 1.1 { 
		Print "Run mode is:" + runMode["runMode"].
		landing["HoverLand"]().
		gf_set_runmode("runMode",1.2).
		wait 5.
	}
	
} /// end of function runmodes

	
Function intParameters {
	
	///////////////////////
	//Ship Particualrs
	//////////////////////
	Set sv_maxGeeTarget to 4.  //max G force to be experienced

	Set sv_shipHeightflight to 4.1. // the height of the ship from the ground to the ship base part
	Set sv_gimbalLimit to 10. //Percent limit on the Gimbal is (10% is typical to prevent vibration however may need higher for large rockets with poor control up high)
	Set sv_MaxQLimit to 0.3. //0.3 is the Equivalent of 40Kpa Shuttle was 30kps and others like mercury were 40kPa.
	
	///////////////////////
	//Ship Variable Inital Launch Parameters
	///////////////////////
 	Set sv_targetInclination to 0.02. //Desired Inclination
    Set sv_targetAltitude to 100000. //Desired Orbit Altitude from Sea Level
    Set sv_ClearanceHeight to 200. //Intital Climb to Clear the Tower and start Pitchover Maneuver
    Set sv_anglePitchover to 85. //Final Pitchover angle
	//Set sv_intAzimith TO Launch_Calc ["LaunchAzimuth"](sv_targetInclination,sv_targetAltitude).
	Set sv_landingtargetLATLNG to latlng(-0.0972092543643722, -74.557706433623). // This is for KSC but use target:geoposition if there is a specific target vessel on the surface that can be used.
	Set sv_prevMaxThrust to 0. //used to set up for the flameout function
	
	//////////////////////////////////////////
	///Ship PID Control variables//////////////////
	/////////////////////////////////////////
	Lock gl_DegDistance to (body:radius*2*constant:pi)/360.
//===ALTITUDE====
	//Desired vertical speed
	Set sv_PIDALT to PIDLOOP(0.9, 0.0, 0.0005, -10, 10).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired throttle setting
	Set sv_PIDThrott to PIDLOOP(0.1, 0.2, 0.005, 0, 1).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LATITUDE (North) ====
	//Desired velocity
	Set sv_PIDLAT to PIDLOOP(1.0, 0.0, 5.0, 5/gl_DegDistance, -5/gl_DegDistance).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	//Desired direction
	Set sv_PIDNorth to PIDLOOP(10000, 0, 0, -22.5, 22.5).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	

//===LONGITUDE (East)====
	//Desired velocity
	Set sv_PIDLONG to PIDLOOP(0.5, 0, 2.5, -5/gl_DegDistance, 5/gl_DegDistance).// SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).			
	//Desired direction	 
	Set sv_PIDEast to PIDLOOP(10000, 0, 0, -22.5, 22.5).//SET PID TO PIDLOOP(KP, KI, KD, MINOUTPUT, MAXOUTPUT).	
	
	
	///////////////////////
	//Global Lock Parameters
	//////////////////////

	//ORBIT information
    Lock gl_SEALEVELGRAVITY to body:mu / (body:radius)^2. // returns the sealevel gravity for any body that is being orbited.
	lock gl_apoEta to max(0,ETA:APOAPSIS). //Return time to Apoapsis
	lock gl_perEta to max(0,ETA:PERIAPSIS). //Return time to Periapsis
	lock gl_Ship_Ap to Ship:orbit:Apoapsis.
	lock gl_Ship_Pe to Ship:orbit:Periapsis.
	lock gl_Ship_Per to Ship:orbit:Period.
	lock gl_GRAVITY to body:mu / (ship:Altitude + body:radius)^2. //returns the current gravity experienced by the vessel
	Lock gl_Mdot to Node_Calc["Mdot"]().
	
	//Locations
	lock gl_NORTHPOLE to latlng( 90, 0).
    lock gl_KSCLAUNCHPAD to latlng(-0.0972092543643722, -74.557706433623).  //The launchpad at the KSC
	lock gl_shipLatLng to SHIP:GEOPOSITION. // provides the current co-ordiantes
	lock gl_surfaceElevation to gl_shipLatLng:TERRAINHEIGHT. // provides the height at the current co-ordinates
	lock gl_PeLatLng to ship:body:geopositionof(positionat(ship, time:seconds + gl_perEta)). //The Lat and long of the PE

	//Engines
    lock gl_TWR to MAX( 0.001, MAXTHRUST / (ship:MASS*gl_GRAVITY)). //Provides the current thrust to weight ratio
	lock gl_TWRTarget to min( gl_TWR, sv_maxGeeTarget*(9.81/gl_GRAVITY)). // enables the trust to be limited based on the TWR which is dependant on the local gravity compared to normal G forces
	Lock gl_TVALMax to min(gl_TWRTarget/gl_TWR, sv_MaxQLimit / SHIP:Q). //use this to set the Max throttle as the TWR changes with time or the ship reaches max Q for throttleable engines.
	//Lock Throttle to gl_TVALMax. // this is the command that will need to be used in individual functions when re-setting the throttle after making the throttle zero.
	
	//Ship information
	Lock gl_StageNo TO STAGE:NUMBER. //Get the Current Stage Number
	lock gl_baseALTRADAR to max( 0.1, min(ship:Altitude , ship:Altitude - gl_surfaceElevation - sv_shipHeightflight)). // Note: this assumes the root part is on the top of the ship.
	lock gl_shipHeight to ship:Altitude - gl_surfaceElevation.	// calculates the height of the ship if landed, if not landed use the flight variable or set one up seperately	
	
	//Fall Predictions and Variables
	Lock gl_AvgGravity to sqrt(		(	(gl_GRAVITY^2) +((body:mu / (gl_surfaceElevation + body:radius)^2 )^2)		)/2		).// using Root mean square function to find the average aceleration between the current point and the surface which have a squares relationship.
	Lock gl_fallTime to Orbit_Calc["quadraticPlus"](-gl_AvgGravity/2, -ship:verticalspeed, gl_baseALTRADAR).//r = r0 + vt - 1/2at^2 ===> Quadratic equiation 1/2*at^2 + bt + c = 0 a= acceleration, b=velocity, c= distance
	lock gl_fallVel to abs(ship:verticalspeed) + (gl_AvgGravity*gl_fallTime).//v = u + at
	lock gl_fallAcc to (ship:AVAILABLETHRUST/ship:mass). // note is is assumed this will be undertaken in a vaccum so the thrust and ISP will not change. Otherwise if undertaken in the atmosphere drag will require a variable thrust engine so small variations in ISP and thrust won't matter becasue the thrust can be adjusted to suit.
	lock gl_fallDist to (gl_fallVel^2)/ (2*(gl_fallAcc)). // v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a 

	
	
	//Instantaneous Predictions and variables
	lock gl_InstConImpactTime to gl_baseALTRADAR / abs(VERTICALSPEED). //gives instantaneous time to impact if vertical velocity remains constant
	Lock gl_InstMaxAcc to (ship:AVAILABLETHRUST / ship:mass). //gives max vertical acceleration at this point in time fighting gravity
	lock gl_InstkillTime to ((gl_totalSurfSpeed/gl_TWRTarget)* gl_GRAVITY) / (gl_TWRTarget). // t0 = Vel/TWR  t1 = t0*g/TWR Tf = t1 + t0 ==> ((Vel/TWR)*g)/TWR gives instantaneous time to kill all speed
	lock gl_InstfallDist to (gl_fallVel^2) / (2*(gl_InstMaxAcc)). // v^2 = u^2 + 2as ==> s = ((v^2) - (u^2))/2a
	
	// //Flight Vectors
	lock gl_rightrotation to ship:facing*r(0,90,0).
	lock gl_right to gl_rightrotation:vector. //right vector i.e. points same as right wing
	// lock gl_left to (-1)*gl_right. //left vector i.e. points same as left wing
	lock gl_up to ship:up:vector. //up is directly up perpendicular to the ground
	// lock gl_down to (-1)*gl_up. //down is directly down perpendicular to the ground
	lock gl_fore to ship:facing:vector. //fore points through the nose
	// lock gl_aft to (-1)*gl_fore. //aft points through the tail
	// lock gl_righthor to vcrs(gl_up,gl_fore). //vector pointing to right horizon
	// lock gl_lefthor to (-1)*gl_righthor.//vector pointing to left horizon
	// lock gl_forehor to vcrs(gl_righthor,gl_up). //vector pointing to fwd horizon
	// lock gl_afthor to (-1)*gl_forehor. //vector pointing to aft horizon
	lock gl_top to vcrs(gl_fore,gl_right). //top respective to the cockpit frame of reference i.e perpendicular to the wings
	// lock gl_bottom to (-1)*gl_top. //bottom respective to the cockpit frame of reference i.e perpendicular to the wings
	
	// //Flight Velocities
	// lock gl_HorSurVel to vxcl(ship:up:vector, ship:velocity:surface). //Horizontal velocity of the ground TODO:check is this is the same as SURFACESPEED
	// lock gl_VerSurVel to vdot(ship:up:vector, ship:velocity:surface). //Vertical velocity of the ground TODO:check is this is the same as VERTICALSPEED
	// lock gl_HorSurFwdVel to vxcl(gl_righthor, gl_HorVel). //Horizontal velocity of the ground Fwd Component only
	// lock gl_HorSurRightVel to vxcl(gl_forehor, gl_HorVel). //Horizontal velocity of the ground Right Component only (effectively the slide slip component as fwd should be the main component)
	// lock gl_totalSurfSpeed to SURFACESPEED + ABS(VERTICALSPEED). //true speed relative to surface		

	// //Flight Angles
	// lock gl_absaoa to vang(gl_fore,srfprograde:vector). //absolute angle of attack including yaw and pitch
	// lock gl_aoa to vang(gl_top,srfprograde:vector)-90. //pitch only component of angle of attack
	// lock gl_sideslip to vang(gl_right,srfprograde:vector)-90. //yaw only component of aoa
	// lock gl_rollangle to vang(gl_right,gl_righthor)*((90-vang(gl_top,gl_righthor))/abs(90-vang(gl_top,gl_righthor))). //roll angle, 0 at level flight
	// lock gl_pitchangle to vang(gl_fore,gl_forehor)*((90-vang(fore,up))/abs(90-vang(fore,up))). //pitch angle, 0 at level flight
	// lock gl_glideslope to vang(srfprograde:vector,gl_forehor)*((90-vang(srfprograde:vector,gl_up))/abs(90-vang(srfprograde:vector,gl_up))).
	
	Print "end of parameters".
}/////End of function

	
	