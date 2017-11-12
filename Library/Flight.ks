
{ // Start of anon

//General Credits with ideas from the following:
// https://github.com/KK4TEE/kOSPrecisionLand

///// Download Dependant libraies
local Util_Orbit is import("Util_orbit").


///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Flight is lex(
		"Vectors",ff_Vectors@,
		"Velocities",ff_Velocities@,
		"Angles", ff_Angles@
	).

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	
	
	//TODO: Develop function to allow for atmospheric re-entry landings
	
	//Locations
	Set gl_NORTHPOLE to latlng( 90, 0).
    Set gl_KSCLAUNCHPAD to latlng(-0.0972092543643722, -74.557706433623).  //The launchpad at the KSC

	lock gl_PeLatLng to ship:body:geopositionof(positionat(ship, time:seconds + ETA:PERIAPSIS)). //The Lat and long of the PE

	//Ship information
	lock gl_landedshipHeight to ship:Altitude - gl_surfaceElevation.	// calculates the height of the ship if landed, if not landed use the flight variable or set one up seperately	
	
	
	Function ff_Vectors{
	// //Flight Vectors Note: this is more for reference as its usually better to just type the vector in, rather than calling this function.
		set vec_right to SHIP:FACING:STARVECTOR. //right vector i.e. points same as right wing
		//lock vec_left to (-1)*vec_right. //left vector i.e. points same as left wing
		set vec_fore to SHIP:FACING:FOREVECTOR. //fore points through the nose
		//lock vec_aft to (-1)*vec_fore. //aft points through the tail
		lock vec_top to SHIP:FACING:TOPVECTOR. //top respective to the cockpit frame of reference i.e perpendicular to the wings
		//lock vec_bottom to (-1)*vec_top. //bottom respective to the cockpit frame of reference i.e perpendicular to the wings
		
		Set vec_up to SHIP:UP:VECTOR. //up is directly up perpendicular to the ground
		//lock vec_down to (-1)*vec_up. //down is directly down perpendicular to the ground
		Set vec_righthor to vcrs(SHIP:UP:VECTOR,SHIP:FACING:FOREVECTOR). //vector pointing to right horizon
		//lock vec_lefthor to (-1)*vec_righthor.//vector pointing to left horizon
		Set vec_forehor to vcrs(SHIP:UP:VECTOR,SHIP:FACING:STARVECTOR). //vector pointing to fwd horizon
		//lock vec_afthor to (-1)*vec_forehor. //vector pointing to aft horizon
		
		local arr is lexicon().
		arr:add ("right", vec_right).
		arr:add ("up", vec_up).
		arr:add ("fore", vec_fore).
		arr:add ("righthor", vec_righthor).
		arr:add ("forehor", vec_forehor).
		arr:add ("top", vec_top).
		
		Return(arr).
	}
	
	Function ff_Velocities{
	// //Flight Velocities
		set vel_HorSurVel to SHIP:GROUNDSPEED. //Pure horizontal speed over ground
		set vel_VerSurVel to SHIP:VERTICALSPEED. //Vertical velocity of the ground 
		set vel_HorSurFwdVel to vxcl(vcrs(SHIP:UP:VECTOR,SHIP:FACING:FOREVECTOR), vel_HorSurVel). //Horizontal velocity of the ground Fwd Component only
		set vel_HorSurRightVel to vxcl(vcrs(SHIP:UP:VECTOR,SHIP:FACING:STARVECTOR), vel_HorSurVel). //Horizontal velocity of the ground Right Component only (effectively the slide slip component as fwd should be the main component)
		set vel_totalSurfSpeed to sqrt( ((SHIP:GROUNDSPEED)^2) + ((SHIP:VERTICALSPEED)^2) ). //true speed relative to surface		
		
		local arr is lexicon().
		arr:add ("HorSurFwdVel", vel_HorSurFwdVel).
		arr:add ("HorSurRightVel", vel_HorSurRightVel).
		arr:add ("totalSurfSpeed", vel_totalSurfSpeed).
		
		Return(arr).
	}
	
	Function ff_Angles{
	// //Flight Angles
		local vec_arr is ff_Vectors().
	
		Set ang_absaoa to vang(vec_arr["fore"],srfprograde:vector). //absolute angle of attack including yaw and pitch
		Set ang_aoa to vang(vec_arr["top"],srfprograde:vector)-90. //pitch only component of angle of attack
		set ang_sideslip to vang(vec_arr["right"],srfprograde:vector)-90. //yaw only component of aoa
		set ang_rollangle to vang(vec_arr["right"],vec_righthor)*((90-vang(vec_arr["top"],vec_arr["righthor"]))/abs(90-vang(vec_arr["top"],vec_arr["righthor"]))). //roll angle, 0 at level flight
		set ang_pitchangle to vang(vec_arr["fore"],vec_arr["forehor"])*((90-vang(vec_arr["fore"],vec_arr["up"]))/abs(90-vang(vec_arr["fore"],vec_arr["up"]))). //pitch angle, 0 at level flight
		set ang_glideslope to vang(srfprograde:vector,vec_arr["forehor"])*((90-vang(srfprograde:vector,vec_arr["up"]))/abs(90-vang(srfprograde:vector,vec_arr["up"]))).
		
		local arr is lexicon().
		arr:add ("absaoa", ang_absaoa).
		arr:add ("aoa", ang_aoa).
		arr:add ("sideslip", ang_sideslip).
		arr:add ("rollangle", ang_rollangle).
		arr:add ("pitchangle", ang_pitchangle).
		arr:add ("glideslope", ang_glideslope).
		
		Return(arr).
	}
	
/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Flight).
} // End of anon
