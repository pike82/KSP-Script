
{ // Start of anon

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Staging is lex(
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
	
FUNCTION ff_STAGEFLAMEOUT {
	PARAMETER stagewait IS 1.

	IF MAXTHRUST < (sv_prevMaxThrust - 10) {
		STAGE. //Decouple
		PRINT "Autostage".
		WAIT stageWait.
		STAGE. // Start next Engine
	}
	SET sv_prevMaxThrust TO MAXTHRUST.
} // End of Function
	
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

	IF SHIP:Q < 0.005 {
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
	
Function ff_stage_delta_v {
//Calculates the amount of delta v for the current stage    
local m is ship:mass * 1000. // Starting mass (kg)
local g is ship:orbit:body:mu/ship:obt:body:radius^2.
local engine_count is 0.
local isp is 0. // Engine ISP (s)
	for en in all_engines if en:ignition and not en:flameout {
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.

//for real fuels  
//return stage:engine:isp * ln(ship:mass / (ship:mass - (stage:LQDOXYGEN + stage:LQDHYDROGEN + stage:KEROSENE + stage:Aerozine50 + stage:UDMH + stage:NTO + stage:MMH + stage:HTP + stage:IRFNA-III + stage:NitrousOxide + stage:Aniline + stage:Ethanol75 + stage:LQDAMMONIA + stage:LQDMETHANE + stage:CLF3 + stage:CLF5 + stage:DIBORANE + stage:PENTABORANE + stage:ETHANE + stage:ETHYLENE + stage:OF2 + stage:LQDFLUORINE + stage:N2F4 + stage:FurFuryl + stage:UH25 + stage:TONKA250 + stage:TONKA500 + stage:FLOX30 + stage:FLOX70 + stage: + stage:FLOX88 + stage:IWFNA + stage:IRFNA-IV + stage:AK20 + stage:AK27 + stage:CaveaB + stage:MON1 + stage:MON3 + stage:MON10 + stage:MON15 + stage:MON20 + stage:Hydyne + stage:TEATEB))).
//for stock fuels
return (isp * g * ln(m / (m - ((stage:LIQUIDFUEL*5)+(stage:Oxidizer*5))))).
}./// End Function

///////////////////////////////////////////////////////////////////////////////////	
	
function ff_R_chutes {
parameter event.
for RealChute in ship:modulesNamed("RealChuteModule") {
	RealChute:doevent(event).
}
}// End Function

	
/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Staging).
} // End of anon
