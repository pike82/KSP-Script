
///// Download Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	// local Util_Engine is lex(
		// "FLAMEOUT", ff_FLAMEOUT@,
		// "stage_delta_v", ff_stage_delta_v@,
		// "burn_time", ff_burn_time@,
		// "mdot", ff_mdot@,
		// "Vel_Exhaust", ff_Vel_Exhaust@
	// ).

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	

//Credits : Own with ideas chopped an changed from multiple KOS reddit posts
	
FUNCTION ff_FLAMEOUT {
	PARAMETER Ullage is "RCS", stagewait is 2, ResFrac is 0.1.
	local engine_count is 0.
	local EnginesFlameout is 0.
	
	//Print "Flameout".
	
	If Ullage = "RCS"{ /// ie. Use RCS or nothing to provide ullage
	//Print "RCS Flameout".
		///The following determiines the number of engines in the current stage that are flamed out.
		LIST engines IN engList.
		FOR eng IN engList {  //Loops through Engines in the Vessel
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				Set engine_count to engine_count + 1.
				if eng:flameout{
					SET EnginesFlameout TO EnginesFlameout + 1. 
				}
			}
		}
		//Print STAGE:NUMBER.
		//Print EnginesFlameout.
		//Print engine_count.
		If engine_count = EnginesFlameout {
		//All engines required have flamed out
			local RCSState is RCS. //Get the Current RCS State
			RCS ON. //provide ullage
			STAGE. //Decouple
			PRINT "RCS Ullage".
			WAIT stageWait.
			// TODOD: local propStat is "thePart":GetModule("ModuleEnginesRF"):GetField("propellantStatus"). Note this is not tested so it needs to be determined if it can work with real fuels to determine if real feuls is installed
			STAGE. // Start next Engine(s)
			Set RCS to RCSState. //stop ullage or leave RCS on if it was on before
		}
	}
	
	If Ullage = "boost"{ //i.e strap on solids or other boosters around a main engine that continues to burn so no ullage required
	Print "Boost Flameout".
		///The following determiines the number of engines in the current stage that are flamed out.
		LIST engines IN engList.
		FOR eng IN engList {  //Loops through Engines in the Vessel
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				Set engine_count to engine_count + 1.
				if eng:flameout{
					SET EnginesFlameout TO EnginesFlameout + 1.
				}
			}
		}
		If EnginesFlameout >= stageWait{ // stage wait in this instance is used to determine the number of boosters flamedout to intiate the staging
		//All engines required have flamed out
			STAGE. //Decouple half stage
			PRINT "Releasing boosters".
			Wait 0.1.
			Print "Removing throttle limits".
			FOR eng IN engList {  //Loops through Engines in the Vessel
				IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
						SET eng:THRUSTLIMIT to 100. // Throttle up any throttle limited engines now we have less thrusters 
				}
			}
			
		}
	}
	
	If Ullage = "hot"{ /// ie. Doing a hot stage
	Print "Hot Flameout".
		///The following determiines the number of engines in the current stage that are flamed out.
		local timeRem is ff_burn_time(ff_stage_delta_v()).
		If stageWait > timeRem{ //Stage wait is actually the amount of burn time left in the tanks before stating the hot stage
			STAGE. //Start next engines
			PRINT "Hot Staging".
			Wait timeRem + 0.1. // decouple old engine, the + 0.1 ensure the engine is flamed out
			STAGE. // Decouple old engine
		}
	}
	
	If Ullage = "half"{ /// ie. Doing a half stage like Atlas which is based on time
	Print "Half Flameout".
		///The following determiines the number of engines in the current stage that are flamed out.
		local timeRem is ff_burn_time(ff_stage_delta_v()).
		If stageWait > timeRem{ //Stage wait is actually the amount of burn time left in the tanks before stating the half staging
			PRINT "Half Staging".
			STAGE. // Decouple the half stage
		}
	}
	
	If Ullage = "fuel"{ /// ie. Doing a stage dependant on fuel remainng for boosters like falcon 9
	Print "fuel Falmeout".
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
				STAGE. // Start next Engine(s)
			}
		}
	}
} // End of Function
	
///////////////////////////////////////////////////////////////////////////////////	

//Credits : Not Own!! TODO attempt to find original source
	
Function ff_stage_delta_v {

//Calculates the amount of delta v for the current stage    
local m is ship:mass * 1000. // Starting mass (kg)
local g is 9.80665.
local engine_count is 0.
local isp is 0. // Engine ISP (s)
local RSS is True.
local fuelmass is 0.
	// obtain ISP
	LIST engines IN engList.
	for en in engList 
	if en:ignition and not en:flameout {
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
		local fuels is list("LQDOXYGEN", "LQDHYDROGEN", "KEROSENE", "Aerozine50", "UDMH", "NTO", "MMH", 
			"HTP", "IRFNA-III", "NitrousOxide", "Aniline", "Ethanol75", "LQDAMMONIA", "LQDMETHANE", 
			"CLF3", "CLF5", "DIBORANE", "PENTABORANE", "ETHANE", "ETHYLENE", "OF2", "LQDFLUORINE", 
			"N2F4", "FurFuryl", "UH25", "TONKA250", "TONKA500", "FLOX30", "FLOX70", "", "FLOX88", 
			"IWFNA", "IRFNA-IV", "AK20", "AK27", "CaveaB", "MON1", "MON3", "MON10", "MON15", "MON20", "Hydyne", "TEATEB").

		for res in STAGE:RESOURCES{
			for f in fuels{
				if f = res:NAME{
					SET fuelMass TO fuelMass + res:DENSITY*res:AMOUNT.
				}
			}
		}

	} Else {
	//for stock fuels
		local fuels is list("LiquidFuel", "Oxidizer", "SolidFuel", "MonoPropellant").
		for res in STAGE:RESOURCES{
			for f in fuels{
				if f = res:NAME{
					SET fuelMass TO fuelMass + res:DENSITY*res:AMOUNT.
				}
			}
		}
	}
	//TODO:Think about removing RCS components or making it an input term as this could be a significant proportion of the deltaV which is not used.
	return (isp * g * ln(m / (m - fuelMass))).
}./// End Function

///////////////////////////////////////////////////////////////////////////////////	
//Credits: Multiple KOS rediit posts
	
function ff_burn_time {
parameter dV.
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local m is ship:mass * 1000. // Starting mass (kg)
	local e is constant():e. // Base of natural log
	local engine_count is 0.
	local thrust is 0.
	local isp is 0. // Engine ISP (s)
	
	//TODO: look at comapring the dv with the ff_stage_delta_v. If less look at the engine in the next stage and determine the delta_v and time to burn until the dv has been meet.
	list engines in all_engines.
	for en in all_engines if en:ignition and not en:flameout {
	  set thrust to thrust + en:availablethrust.
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	
	if engine_count = 0{
		return 1.
	}
	
	set isp to isp / engine_count.
	set thrust to thrust * 1000. // Engine Thrust (kg * m/s²)
	return g * m * isp * (1 - e^(-dV/(g*isp))) / thrust.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	

//Credits: Own
	
function ff_mdot {
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local engine_count is 0.
	local thrust is 0.
	local isp is 0. // Engine ISP (s)
	list engines in all_engines.
	for en in all_engines if en:ignition and not en:flameout {
	  set thrust to thrust + en:availablethrust.
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.
	set thrust to thrust* 1000.// Engine Thrust (kg * m/s²)
	return (thrust/(g * isp)). //kg of change
}/// End Function
	
///////////////////////////////////////////////////////////////////////////////////	
//Credits: Own	
	
function ff_Vel_Exhaust {
	local g is 9.80665.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local engine_count is 0.
	local thrust is 0.
	local isp is 0. // Engine ISP (s)
	list engines in all_engines.
	for en in all_engines if en:ignition and not en:flameout {
	  set thrust to thrust + en:availablethrust.
	  set isp to isp + en:isp.
	  set engine_count to engine_count + 1.
	}
	set isp to isp / engine_count.
	return g *isp.///thrust). //
}/// End Function
	
///////////////////////////////////////////////////////////////////////////////////	

//Credits: Own	
	
function ff_RCS {
	Parameter RCS_switch is "False".
	list parts in all_parts.
	for part in all_parts if Part:RESOURCES = "monoprop" {
		Print Part.
		Set Part:RESOURCE:enabled to RCS_switch.
	}
}/// End Function
	
///////////////////////////////////////////////////////////////////////////////////	
