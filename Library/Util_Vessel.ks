
{ // Start of anon

///// Download Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Util_Vessel is lex(
		"tol", ff_Tolerance@,
		"FAIRING",ff_FAIRING@,
		"COMMS",ff_COMMS@,
		"Gravity",ff_Gravity@,
		"R_chutes", ff_R_chutes@
	).

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	
	
FUNCTION ff_FAIRING {
	PARAMETER stagewait IS 0.1.

	IF SHIP:Q < 0.005 {
		FOR module IN SHIP:MODULESNAMED("ProceduralFairingDecoupler") {
			module:DOEVENT("jettison").
			PRINT "Jettisoning Fairings".
			WAIT stageWait.
		}.
	}
} // End of Function

function solarpanels{
	panels on.
}

/////////////////////////////////////////////////////////////////////////////////////
	
FUNCTION ff_Tolerance {
//Calculates if within tolerance and returns true or false
	PARAMETER a. //current value
	PARAMETER b.  /// Setpoint
	PARAMETER tol.

	RETURN (a - tol < b) AND (a + tol > b).
}


FUNCTION ff_COMMS {
	PARAMETER stagewait IS 0.1.

	IF SHIP:Q < 0.0045 {
		FOR antenna IN SHIP:MODULESNAMED("ModuleRTAntenna") {
			IF antenna:HASEVENT("activate") {
				antenna:DOEVENT("activate").
				PRINT "Activate Antennas".
				WAIT stageWait.
			}	
		}.
	}
} // End of Function

///////////////////////////////////////////////////////////////////////////////////	

function ff_R_chutes {
parameter event.
	for RealChute in ship:modulesNamed("RealChuteModule") {
		RealChute:doevent(event).
	}
}// End Function

function ff_Gravity{
	Parameter Surface_Elevation is gl_surfaceElevation.
	Set SEALEVELGRAVITY to body:mu / (body:radius)^2. // returns the sealevel gravity for any body that is being orbited.
	Set GRAVITY to body:mu / (ship:Altitude + body:radius)^2. //returns the current gravity experienced by the vessel	
	Set AvgGravity to sqrt(		(	(GRAVITY^2) +((body:mu / (Surface_Elevation + body:radius)^2 )^2)		)/2		).// using Root mean square function to find the average gravity between the current point and the surface which have a squares relationship.

	local arr is lexicon().
	arr:add ("SLG", SEALEVELGRAVITY).
	arr:add ("G", GRAVITY).
	arr:add ("AVG", AvgGravity).
	
	Return (arr).
}
	
/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Util_Vessel).
} // End of anon
