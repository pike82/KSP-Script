
{ // Start of anon

///// Download Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    local Node_Calc is lex(
		"Node_exec", ff_Node_exec@,
		"burn_time", ff_burn_time@,
		"Mass_Change", ff_Mass_Change@
    ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////

//Note: A shut down engine(inactivated) will not allow this function to work
function ff_Node_exec { // this function executes the node when ship has one
// used to determine if the node exceution started and needs to return to this point.

parameter autowarp is 0, Alrm is True, n is nextnode, v is n:burnvector, starttime is time:seconds + n:eta - ff_burn_time(v:mag/2). 
	print "executing node".		  
	If runMode:haskey("ff_Node_exec") = false{
		If ADDONS:Available("KAC") AND Alrm {		  // if KAC installed	  
			Set ALM to ADDALARM ("Maneuver", starttime -180, SHIP:NAME ,"").// creates a KAC alarm 3 mins prior to the manevour node
		}
	}
	gf_set_runmode("ff_Node_exec",1).

	Print "locking Steering".
	lock steering to n:burnvector.
	// Set TVAL to 0.0.
	// Lock Throttle to TVAL.
	if autowarp warpto(starttime - 30).
	Print "Start time: " + starttime.
	wait until time:seconds >= starttime.
	Print "Burn Start".
	//local t is 0.
	//lock throttle to t.
	until vdot(n:burnvector, v) < 0.01 {
	  if ship:maxthrust < 0.1 {
		stage.
		wait 0.1.
		if ship:maxthrust < 0.1 {
		  for part in ship:parts {
			for resource in part:resources set resource:enabled to true.
		  }
		  wait 0.1.
		}
	  }
	  //set t to min(Staging["burn_time"](n:burnvector:mag), 1).
	  Lock Throttle to min(ff_burn_time(n:burnvector:mag), 1).
	  wait 0.1.
	}
	Lock Throttle to 0.0.
	Print "Burn Complete".
	unlock steering.
	remove nextnode.
	wait 0.

	gf_remove_runmode("ff_Node_exec").

}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
	  
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
	
function ff_Mass_Change {
parameter time.
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
set thrust to thrust * 1000. // Engine Thrust (kg * m/s²)
return (thrust/(g * isp))*time. //kg of change
}/// End Function
	
	

///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(Node_Calc).
} // End of anon

