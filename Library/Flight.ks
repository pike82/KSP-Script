
{ // Start of anon

///// Download Dependant libraies
//local Node_Calc is import("Node_Calc").


///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Flight is lex(
		"FLAMEOUT", ff_STAGEFLAMEOUT@,
		"tol", ff_Tolerance@,
		"FAIRING",ff_FAIRING@,
		"COMMS",ff_COMMS@,
		"stage_delta_v", ff_stage_delta_v@,
		"R_chutes", ff_R_chutes@
	).

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	
	
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

	lock gl_PeLatLng to ship:body:geopositionof(positionat(ship, time:seconds + gl_perEta)). //The Lat and long of the PE


	//Ship information
	Lock gl_StageNo TO STAGE:NUMBER. //Get the Current Stage Number
	lock gl_landedshipHeight to ship:Altitude - gl_surfaceElevation.	// calculates the height of the ship if landed, if not landed use the flight variable or set one up seperately	
	
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
	lock gl_left to (-1)*gl_right. //left vector i.e. points same as left wing
	lock gl_up to ship:up:vector. //up is directly up perpendicular to the ground
	lock gl_down to (-1)*gl_up. //down is directly down perpendicular to the ground
	lock gl_fore to ship:facing:vector. //fore points through the nose
	lock gl_aft to (-1)*gl_fore. //aft points through the tail
	lock gl_righthor to vcrs(gl_up,gl_fore). //vector pointing to right horizon
	lock gl_lefthor to (-1)*gl_righthor.//vector pointing to left horizon
	lock gl_forehor to vcrs(gl_righthor,gl_up). //vector pointing to fwd horizon
	lock gl_afthor to (-1)*gl_forehor. //vector pointing to aft horizon
	lock gl_top to vcrs(gl_fore,gl_right). //top respective to the cockpit frame of reference i.e perpendicular to the wings
	lock gl_bottom to (-1)*gl_top. //bottom respective to the cockpit frame of reference i.e perpendicular to the wings
	
	// //Flight Velocities
	lock gl_HorSurVel to vxcl(ship:up:vector, ship:velocity:surface). //Horizontal velocity of the ground TODO:check is this is the same as SURFACESPEED
	lock gl_VerSurVel to vdot(ship:up:vector, ship:velocity:surface). //Vertical velocity of the ground TODO:check is this is the same as VERTICALSPEED
	lock gl_HorSurFwdVel to vxcl(gl_righthor, gl_HorVel). //Horizontal velocity of the ground Fwd Component only
	lock gl_HorSurRightVel to vxcl(gl_forehor, gl_HorVel). //Horizontal velocity of the ground Right Component only (effectively the slide slip component as fwd should be the main component)
	lock gl_totalSurfSpeed to SURFACESPEED + ABS(VERTICALSPEED). //true speed relative to surface		

	// //Flight Angles
	lock gl_absaoa to vang(gl_fore,srfprograde:vector). //absolute angle of attack including yaw and pitch
	lock gl_aoa to vang(gl_top,srfprograde:vector)-90. //pitch only component of angle of attack
	lock gl_sideslip to vang(gl_right,srfprograde:vector)-90. //yaw only component of aoa
	lock gl_rollangle to vang(gl_right,gl_righthor)*((90-vang(gl_top,gl_righthor))/abs(90-vang(gl_top,gl_righthor))). //roll angle, 0 at level flight
	lock gl_pitchangle to vang(gl_fore,gl_forehor)*((90-vang(fore,up))/abs(90-vang(fore,up))). //pitch angle, 0 at level flight
	lock gl_glideslope to vang(srfprograde:vector,gl_forehor)*((90-vang(srfprograde:vector,gl_up))/abs(90-vang(srfprograde:vector,gl_up))).
	
	
/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Flight).
} // End of anon
