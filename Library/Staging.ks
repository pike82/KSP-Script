
{ // Start of anon

///// Download Dependant libraies
local Node_Calc is import("Node_Calc").


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
	PARAMETER stagewait is 1, EngTime is 0, ResFrac is 0,  IgniteEngine is True, FlameNo is 1000.
	local engine_count is 0.
	local EnginesFlameout is 0.
	
	
	If EngTime = 0{ /// ie. No hot staging
		///The following determiines the number of engines in the current stage that are flamed out.
		FOR eng IN engList {  //Loops through Engines in the Vessel
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				Set engine_count to engine_count + 1.
				if eng:flameout{
					SET EnginesFlameout TO EnginesFlameout + 1. //if it has a gimbal set the gimbal limit
				}
			}
		}
		If engine_count = EnginesFlameout or EnginesFlameout >= FlameNo{
		//All engines required have flamed out
			STAGE. //Decouple
			PRINT "Autostage".
			WAIT stageWait.
			If IgniteEngine = True {
				STAGE. // Start next Engine(s)
			}
		}
	}
	If EngTime > 0{ /// ie. Doing a hot stage
		///The following determiines the number of engines in the current stage that are flamed out.
		local timeRem is Node_Calc["burn_time"](ff_stage_delta_v()).
		If EngTime > timeRem{
		//All engines have flamed out
			STAGE. //Start next engine
			PRINT "Hot Staging".
			Wait EngTime + 0.1. // decouple old engine
			STAGE. // Decouple old engine
		}
	}
	If ResFrac > 0 {
	/// the following determines the lowest fraction of fuel remaining in the current staged engines tanks.
		local lowCap is 1.
		for res IN Stage:Resources{
			local cap is res:Amount/res:Capacity. // get the proportion of fuel left in the tank
			set lowCap to min(cap, lowCap). // if the amount is lower set it to the new low capacity value
		}
		If ResFrac > lowCap{
		//the remaing fraction of fule has dropped blow the staging trigger point
			//TODO: insert code regarding deactivating the engines at this point instead of staging for craft like falcon 9. The below code is for staging active engines only (like ATLAS Stage and a half)
			STAGE. //Decouple. 
			PRINT "Fuel stage".
			WAIT stageWait.
			If IgniteEngine = True {
				STAGE. // Start next Engine(s)
			}
		}
	}
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
local g is 9.81.
local engine_count is 0.
local isp is 0. // Engine ISP (s)
local RSS is True.
	// obtain ISP
	for en in engList if en:ignition and not en:flameout {
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.
	
	// obtain RSS
	for res IN Stage:Resources{
		if res:name = "LIQUIDFUEL"{
			Set RSS to False.
		}
	}
	
	If RSS = true{
	//for real fuels 
		local fuelmass is 0.
		for res IN Stage:Resources{
			set fuelmass to fuelmass + res:amount. // if the amount is lower set it to the new low capacity value
		}
	
		return (g * isp )* ln(ship:mass / (ship:mass - fuelmass)).
	
	
		// return stage:engine:isp * ln(ship:mass / (ship:mass - (stage:LQDOXYGEN + stage:LQDHYDROGEN + 
																// stage:KEROSENE + stage:Aerozine50 + stage:UDMH + 
																// stage:NTO + stage:MMH + stage:HTP + stage:IRFNA-III + 
																// stage:NitrousOxide + stage:Aniline + stage:Ethanol75 + 
																// stage:LQDAMMONIA + stage:LQDMETHANE + stage:CLF3 + stage:CLF5 + 
																// stage:DIBORANE + stage:PENTABORANE + stage:ETHANE + stage:ETHYLENE + 
																// stage:OF2 + stage:LQDFLUORINE + stage:N2F4 + stage:FurFuryl + 
																// stage:UH25 + stage:TONKA250 + stage:TONKA500 + stage:FLOX30 + 
																// stage:FLOX70 + stage: + stage:FLOX88 + stage:IWFNA + stage:IRFNA-IV + 
																// stage:AK20 + stage:AK27 + stage:CaveaB + stage:MON1 + stage:MON3 + 
																// stage:MON10 + stage:MON15 + stage:MON20 + stage:Hydyne + stage:TEATEB
																// ))).
	} Else {
	//for stock fuels
		return (isp * g * ln(m / (m - ((stage:LIQUIDFUEL*5)+(stage:Oxidizer*5))))).
	}
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
