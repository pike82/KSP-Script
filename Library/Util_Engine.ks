
{ // Start of anon

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Util_Engine is lex(
		"FLAMEOUT", ff_STAGEFLAMEOUT@,
		"stage_delta_v", ff_stage_delta_v@,
		"burn_time", ff_burn_time@,
		"mdot", ff_mdot@,
		"Vel_Exhaust", ff_Vel_Exhaust@
	).

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	

//Credits : Own with ideas chopped an changed from multiple KOS reddit posts
	
FUNCTION ff_STAGEFLAMEOUT {
	PARAMETER Ullage is "RCS", stagewait is 2, ResFrac is 0.1.
	local engine_count is 0.
	local EnginesFlameout is 0.
	
	Print "Flameout".
	
	If Ullage = "RCS"{ /// ie. Use RCS or nothing to provide ullage
	Print "RCS Flameout".
		///The following determiines the number of engines in the current stage that are flamed out.
		FOR eng IN engList {  //Loops through Engines in the Vessel
			IF eng:STAGE >= STAGE:NUMBER { //Check to see if the engine is in the current Stage
				Set engine_count to engine_count + 1.
				if eng:flameout{
					SET EnginesFlameout TO EnginesFlameout + 1. 
				}
			}
		}
		Print STAGE:NUMBER.
		Print EnginesFlameout.
		Print engine_count.
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
//Credits: Multiple KOS rediit posts
	
function ff_burn_time {
parameter dV.
	local g is 9.81.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
	local m is ship:mass * 1000. // Starting mass (kg)
	local e is constant():e. // Base of natural log
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
	set thrust to thrust * 1000. // Engine Thrust (kg * m/s²)
	return g * m * isp * (1 - e^(-dV/(g*isp))) / thrust.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	

//Credits: Own
	
function ff_mdot {
	local g is 9.81.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
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
	local g is 9.81.  // Gravitational acceleration constant used in game for Isp Calculation (m/s²)
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
	
/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Util_Engine).
} // End of anon
