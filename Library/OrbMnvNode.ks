

//General Credits with ideas from the following:
// Kevin Gisi: http://youtube.com/gisikw

///// Download Dependant libraies

FOR file IN LIST(
	"Util_Engine"){ 
		//Method for if to download or download again.
		
		IF (not EXISTS ("1:/" + file)) or (not runMode["runMode"] = 0.1)  { //Want to ignore existing files within the first runmode.
			gf_DOWNLOAD("0:/Library/",file,file).
			wait 0.001.	
		}
		RUNPATH(file).
	}

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    // local OrbMnvNode is lex(
		// "Node_exec", ff_Node_exec@,
		// "User_Node_exec", ff_user_Node_exec@
    // ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////
//Credits: Own (i.e. runmode file capture) and http://youtube.com/gisikw
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
	Lock Steering to Ship:Prograde + R(90,0,0). 
	until time:seconds > starttime - 180 {
		wait 10.
	}
	
	Print "locking Steering to burn vector".
	lock steering to n:burnvector.
	// Set TVAL to 0.0.
	// Lock Throttle to TVAL.
	if autowarp warpto(starttime - 30).
	Print "Start time: " + starttime.
	RCS on.
	wait until time:seconds >= starttime.
	Print "Burn Start".
	
	Local Stage_Req is False.
	if n:burnvector:mag > ff_stage_delta_v(){
		Set Stage_Req to True.
	}
	
	until vdot(n:burnvector, v) < 0.01 {
		if ship:maxthrust < 0.1 { // checks to see if the next engine is enagaded and if it is stage to activate engine
			stage.
			wait 0.1.
			if ship:maxthrust < 0.1 {
				for part in ship:parts {
					for resource in part:resources{ 
						set resource:enabled to true.
					}
				}
				wait 0.1.
			}
		}
		//Lock Throttle to 1.
		Lock Throttle to min(max(0.0001,ff_burn_time(n:burnvector:mag)),1).
		if Stage_Req{
			ff_Flameout().
		}
		wait 0.001.
	}// end until
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
	Until firstloop = 0{
		Print "Please Create a User node: To execute the node press 1, to Skip press 0".
		Wait until terminal:input:haschar.
		Print terminal:input:haschar.
		Set termInput to terminal:input:getchar().
		
		if termInput = 1{
			If hasnode{
				ff_Node_exec().
			}
			Else{
				Print "Please make a node!!!".
			}
		}
		
		Else if termInput = 0 {
			Set firstloop to 0.
		}

		Else {
			Print "Please enter a valid selction".
		}
		Wait 0.01.
	}//end untill
	
	
}/// End Function	


