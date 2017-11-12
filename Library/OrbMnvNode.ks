
{ // Start of anon

//General Credits with ideas from the following:
// Kevin Gisi: http://youtube.com/gisikw

///// Download Dependant libraies
local Util_Engine is import("Util_Engine").
///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    local OrbMnvNode is lex(
		"Node_exec", ff_Node_exec@,
		"User_Node_exec", ff_user_Node_exec@
    ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////
//Credits: Own (i.e. runmode file capture) and http://youtube.com/gisikw
//Note: A shut down engine(inactivated) will not allow this function to work
function ff_Node_exec { // this function executes the node when ship has one
// used to determine if the node exceution started and needs to return to this point.

parameter autowarp is 0, Alrm is True, n is nextnode, v is n:burnvector, starttime is time:seconds + n:eta - Util_Engine["burn_time"](v:mag/2). 
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
	  //set t to min(Util_Engine["burn_time"](n:burnvector:mag), 1).
	  Lock Throttle to min(Util_Engine["burn_time"](n:burnvector:mag), 1).
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
//Credits: Own

function ff_user_Node_exec {
	Clearscreen.
	local firstloop is 1.	
	local secloop is 1.
	Until firstloop = 0{
		Print "Please Create a User node: To execute the node press 1, to Skip press 0".
		Set termInput to terminal:input:getchar().
		//Wait until terminal:input:haschar.
		if termInput = 0 {
			Set firstloop to 0.
		}
		else if termInput = 1{
			If hasnode{
				ff_Node_exec().
				until secLoop = 0{
					Print "Do you wish to create another node Y/N?".
					Set termInput to terminal:input:getchar().
					//Wait until terminal:input:haschar.
					If termInput = "Y"{
						Set firstloop to 1.
					}
					If Else = "N"{
						Set firstloop to 0.
						Set secloop to 0.
					}
					Else{
						Print "Please enter a valid selction".
					}
				}
			}
			Else{
				Print "Please make a node!!!".
			}
		}
		Else {
			Print "Please enter a valid selction".
		}
		Wait 0.01.
	}//end untill
	
	
	
	
}/// End Function	

///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(OrbMnvNode).
} // End of anon

