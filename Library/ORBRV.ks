
{ // Start of anon

///// Download Dependant libraies
local Hill_Climb is import("Hill_Climb").
local Node_Calc is import("Node_Calc").
local ORBManu is import("ORBManu").
local Orbit_Calc is import("Orbit_Calc").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    local ORBRV is lex(
		"BodyTransfer", ff_BodyTransfer@,
		"CraftTransfer", ff_CraftTransfer@
    ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////		

//TODO: look at the KOS-Stuff_master manu file for possible ideas on reducing and bettering the AN code and manervering code.

//Ideas:

//look-into hoffman transfers where can use position at(orbit,time) to determine where a body will be and then make a manuver to meet it at the same time intead of purely node iterations through hill climb.

Function ff_BodyTransfer {	
Parameter target_Body, Target_Perapsis, maxDV is 1000, IncTar is 90, int_Warp is False.
	if runModeBmk = 0{	
		hf_seek_SOI(target_Body, Target_Perapsis, IncTar, maxDV).
		Log "Set runModeBmk to " + 1 + "." to state.ks. // set the global variable so it skips this if exited midway through
		Node_Calc["Node_exec"](int_Warp).
	} //end runModeBmk if
	Else{
		Node_Calc["Node_exec"](int_Warp).
	}//end else
}  /// End Function
	
///////////////////////////////////////////////////////////////////////////////////
	
Function ff_CraftTransfer {	
	Parameter target_ves, Target_dist, Max_orbits, int_Warp is False.
	if runModeBmk = 0{
		hf_TransferInc(target_ves, Target_dist, int_Warp).
		Set runModeBmk to 1.
		Log "Set runModeBmk to " + 1 + "." to state.ks. // set the global variable so it skips this and move to the next if statement
	}//end if
	If runModeBmk = 1{
		hf_TransferBurn["time"](target_ves, Target_dist, Max_orbits, int_Warp).
		Set TransEnd to hf_TransferBurn["time"](target_ves, Target_dist, Max_orbits, int_Warp).
		/////////Execute the RV targeting node(done outside the helper function to keep the runmode bookmark at this level////////////////
		Log "Set TransEnd to " + TransEnd + "." to state.ks. // set the variable so it passed to the next if statement
		Node_Calc["Node_exec"](int_Warp).
		Set runModeBmk to 2.
		Log "Set runModeBmk to " + 2 + "." to state.ks. // set the global variable so it skips this and move to the next if statement
	}//end if
	If runModeBmk = 2{
		hf_TransferRV(target_ves, Target_dist, TransEnd, int_Warp).
		/////////Execute the RV match node (done outside the helper function to keep the runmode bookmark at this level ////////////////
		Node_Calc["Node_exec"](int_Warp).
	} //end if
	If runModeBmk = -1{
		Node_Calc["Node_exec"](int_Warp).
	} //end else
}  /// End Function
	
///////////////////////////////////////////////////////////////////////////////////
//Helper Functions
/////////////////////////////////////////////////////////////////////////////////////
	  
function hf_seek_SOI {
	parameter target_body, target_periapsis, IncTar, maxDV,
		  start_time is time:seconds + 600. 
	local data is Hill_Climb["Seek"] (
		start_time, 0, 0, 0, 
		{  
		parameter mnv.
		if hf_transfers_to(mnv:orbit, target_body) return 1.
		return -hf_closest_approach
			(
			target_body,
			time:seconds + mnv:eta,
			time:seconds + mnv:eta + mnv:orbit:period
			). // seeks out the closest approach from the mnv node created
		} //end seek parameter
	). //stores the results as a data set enabling a search within another search. This Level is the inner search

	return Hill_Climb["Seek"](
		data[0], data[1], data[2], data[3], 
		{
		parameter mnv.
		if not hf_transfers_to(mnv:orbit, target_body) return -2^64. // failure to be within the SOI make score really low
		if (mnv:DELTAV:mag > maxDV) return -2^64. // failure to be under max dv make score really low
		return -(abs(mnv:orbit:nextpatch:periapsis - target_periapsis*1000))-(mnv:DELTAV:mag*100)-(abs(mnv:orbit:inclination-IncTar)*10).// 1000m = 10m/s = 1 degree of inclination
		} //end seek parameter
	). // this level is the outter search and uses the data parameter to do internal searches per step

}  /// End Function

///////////////////////////////////////////////////////////////////////////////////	
	  
function hf_TransferInc {
parameter target_vessel, target_distance, int_Warp is False.
	local arr is lexicon().
	Set arr to Orbit_Calc["Find_AN_INFO"](target_vessel).
	Set AN_inc to arr ["AN_inc"].
	Set Max_inc to min(
						arctan(target_distance/(target_vessel:orbit:APOAPSIS + Body:RADIUS)),
						arctan(target_distance/(ship:orbit:APOAPSIS + Body:RADIUS))
					). // gives maximum inclination possible that can still achieve target distance
					
	// Adjust for Inclination difference.
	If  (Max_inc/2) > AN_inc{
		Print "Inclination OK". // The target distance is possible with the current inclination difference.
		Print "Max Inc"+Max_inc/2.
		Print "AN Inc" + AN_inc.
	} //end if
	Else{
		Print "Inclination adjustment".
		Print "Max Inc"+Max_inc/2.
		Print "AN Inc" + AN_inc.
		ORBManu["AdjPlaneInc"](0, target_vessel,(Max_inc/4),int_Warp). //Conduct inc change is required.
	} // end else
	
} //end function TransferInc

///////////////////////////////////////////////////////////////////////////////////

function hf_TransferBurn {
	parameter target_vessel, target_distance, Max_orbits, int_Warp is False.
	// TODO:Work lead and lag to see if can be more efficient in finding an intial estimated solution or using seek instead of seek_low for a faster solution for big changes.
	//TODO: Test all sectors or orbits and  Pe and APO variations to ensure it works in all cases
	//TODO: Look into the if case and why it is not working
	//set up paramters 
	local Bod_Rad is Ship:Body:Radius.
	Local atm_Height is 0.

// Adjust for Period and eccentiricty difference.	

	Set Ap_Ves to ship:orbit:Apoapsis.
	Set Pe_Ves to ship:orbit:PERIAPSIS.
	Set Ap_Tar to target_vessel:orbit:Apoapsis.
	Set Pe_Tar to target_vessel:orbit:PERIAPSIS.
	
	Set Ship_Per to Ship:orbit:Period.
	Set Tar_Per to target_vessel:orbit:Period.
	Set Max_time to (Max_orbits * Ship_Per). //Gets the time from now until max orbit time
	Set Max_Orb_UT to  Max_time + time:seconds. //Get the UT of the max orbits.
	Set PerLead to (Ship_Per - Tar_Per). // negative indicates faster and lower orbit
	Set Orbits_Phasing to Ship_Per/PerLead. // negative indicates faster and lower orbit
	Print "Orbits_Phasing" + Orbits_Phasing.
	Set TgtBearing to target_vessel:Bearing.
	Print TgtBearing. //90 to -90 is in front while 90 to 180 to -90 both plus and minus is behind.

	// First check if reducing at Ap is possible (very close orbits with a large starting phase difference cannot change their Pe enough to find a solution for low Max Orbits.
	// These first need to have their PE lowered to allow the solution to increase the AP)
	IF Pe_Ves > Ap_Tar and abs(Orbits_Phasing) > Max_orbits {
	//intercept not possible . Must burn at APo to lower SMI and period (include a lower SMI function in the fittness calculation)
		Print "Intercept not possible, Orbit too big. decreasing Periapsis as orbits too similar to make intercept from Apoapsis stright away".
		ORBManu["adjper"](Ap_Tar-target_distance, 50, true).	
	} // end if	

// calc min Ap possible .
	If Body:Atm:Exists {
		Set atm_Height to Body:Atm:HEIGHT.
	} // end if
	Else{
		Set atm_Height to (1.15*bod_rad). //estimate of the min clearance height possible for vacuumn bodies.
	} //end else
	
	Print "atm_Height" + atm_Height.
	Set Starting_time to time:seconds +180 + (Max_orbits*7). //allows 7 seconds per orbit iteration
	
	Local result is lexicon().
	
	IF ((Ap_Ves > Ap_Tar) and (Pe_Ves < Pe_Tar)) or ((Ap_Ves < Ap_Tar) and (Pe_Ves > Pe_Tar)){
		Print "Orbits Cross".
		Print "Starting Time:" + Starting_time. 
		Print "Max Time:" + Max_Orb_UT.
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, 
			{
			if (mnv:orbit:periapsis < atm_Height) return -2^64. // failure to be above the atmosphere make score really low
			} //end if statement
		).	//end find intersect
	}//End If
	ELSE IF Pe_Ves > Ap_Tar {
	//intercept not possible . Must burn at APo to lower SMI and period (include a lower SMI function in the fittness calculation)
	Print "Intercept not possible, Orbit too big, decreasing Apoapsis at Periapsis".
		If Starting_time < (time:seconds + ETA:PERIAPSIS) {
			Set Starting_time to time:seconds +ETA:PERIAPSIS.
		}// end if
		Else{
			Set Starting_time to time:seconds + ETA:PERIAPSIS + Ship_Per.
		} // end else
		Print "Starting Time:" + Starting_time. 
		Print "Max Time:" + Max_Orb_UT.
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, {
			if (mnv:orbit:period > Ship_Per) return -2^64. // if orbital period increases rule out.
			if (mnv:orbit:periapsis < atm_Height) return -2^64. // failure to be above the atmosphere make score really low
			},"Big"
		).	//end find intersect
	}//End ELSE IF
	ELSE IF Ap_Ves < Pe_Tar  {
	//intercept not possible . Must burn at APe to Increase SMA and period (include an increase SMA function in the fittness calculation)
	
		Print "Intercept not possible, Orbit too small, increasing Apoapsis at Periapsis".
		If Starting_time < time:seconds + ETA:PERIAPSIS {
			Set Starting_time to time:seconds + ETA:PERIAPSIS.
		} //end if
		Else{
			Set Starting_time to time:seconds + ETA:PERIAPSIS + Ship_Per.
		} //end else
		Print "Starting Time:" + Starting_time. 
		Print "Max Time:" + Max_Orb_UT.
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, {
			if (mnv:orbit:period < Ship_Per) return -2^64. // if orbital period decreases rule out.
			if (mnv:orbit:periapsis < atm_Height) return -2^64. // failure to be above the atmosphere make score really low
			},
			"Small"
		).	//end find intersect
	}//End ELSE IF
	ELSE{
	//Orbits could cross with the correct orientation. The Hill climb function can be used to make the orientation correct. Lookinto if there is a specific time in the orbit which will make this be more efficent.
		Print "Orbits Cross if Orientation OK".
		Print "Starting Time:" + Starting_time. 
		Print "Max Time:" + Max_Orb_UT.
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, {
			if (mnv:orbit:period < Ship_Per) return -2^64. // if orbital period decreases rule out.
			if (mnv:orbit:periapsis < atm_Height) return -2^64. // failure to be above the atmosphere make score really low
			} //end else result
		).	//end find intersect
	}//End Else

Return result.
	
} //end function transferburn

///////////////////////////////////////////////////////////////////////////////////

function hf_TransferRV {
parameter target_vessel, target_distance, result, int_Warp is False.

	//Kills Relative velocity

	Local result1 is lexicon().
	Local result2 is lexicon().

	/////////Get the RV time after execution////////////////
	Set result1 to hf_separation_orbits(target_vessel, result["time"]()-1000, result +1000, 10,target_distance).
	Set result2 to hf_separation_orbits(target_vessel, result1["time"]()-10, result1["time"]() +10, 1,target_distance).
	Print "Cancel Relative Velocity Seperation Result:" + result2["seperation"]() + " at " + result2["time"]().

	Hill_Climb["Seek_low"](Hill_Climb["freeze"](result2["time"]()), 0, Hill_Climb["freeze"](0), 0,{  
		parameter mnv.
		Local v1 is velocityat(target_vessel, result2["time"]()+0.1):orbit. //check velocity after node
		Local v2 is velocityat(ship, result2["time"]() +0.1):orbit. //check velocity after node
		Local RelVel is (v1-v2):mag.
		return - abs(RelVel). // End Return, seeks out the node which cancels relative velocity
	} // end hill climb fit section.
	, true
	). ///End Hill Climb	
} //end function transfer RV

///////////////////////////////////////////////////////////////////////////////////	
	  
function hf_transfers_to {
parameter target_orbit, target_body.
return (target_orbit:hasnextpatch and
		target_orbit:nextpatch:body = target_body). // returns true if the next patch is the intended target. (look at making this potentially search through the patches to make work for sling shots via the mun etc.)
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
	  
function hf_closest_approach {
parameter target_body, start_time, end_time.
local start_slope is hf_slope_at(target_body, start_time).
local end_slope is hf_slope_at(target_body, end_time).
local middle_time is (start_time + end_time) / 2.
local middle_slope is hf_slope_at(target_body, middle_time).
until (end_time - start_time < 0.1) or middle_slope < 0.1 {
  if (middle_slope * start_slope) > 0
	set start_time to middle_time.
  else
	set end_time to middle_time.
  set middle_time to (start_time + end_time) / 2.
  //Print "middle_time" + middle_time.
  set middle_slope to hf_slope_at(target_body, middle_time).
  Print "middle_slope" + middle_slope.
  //Wait 1.0.
}
return hf_separation_at(target_body, middle_time).
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
	  
function hf_slope_at {
parameter target_body, at_time.
return (
  hf_separation_at(target_body, at_time + 1) -
  hf_separation_at(target_body, at_time - 1)
) / 2.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
	  
function hf_separation_at {
parameter target_body, at_time.
	// Print (positionat(ship, at_time) - positionat(target_body, at_time)):mag.
	return (positionat(ship, at_time) - positionat(target_body, at_time)):mag.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	

function hf_separation_orbits {
parameter target_body, Start_time, EndTime, StepSize, Target_distance is 1500.
Set WinSep to 2^64.
Set WinTime to 0.
	FROM {local y is Start_time.} 
	UNTIL y > EndTime // Loop untill at max time
	STEP {set y to y+StepSize.} // 
	DO{
		If (abs(hf_separation_at(target_body, y) - Target_distance) < abs(WinSep - Target_distance)) {
			Set WinSep to hf_separation_at(target_body, y). 
			Set WinTime to y.
		}
	} // do loop
	local SepArr is lexicon().
	SepArr:add ("seperation", WinSep).
	SepArr:add ("time", WinTime).
	return (SepArr).
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	

Function hf_find_intersect {
parameter target_vessel, Starting_time, Target_distance, Max_Orb_UT, if_condition, Modifier is "not used".
Local result is lexicon().
Local result1 is lexicon().
Local result2 is lexicon().
Local result3 is lexicon().
Local tempResult is 0.
	Hill_Climb["Seek_low"](Hill_Climb["freeze"](Starting_time), 0, Hill_Climb["freeze"](0), 0,
		{  	parameter mnv.
			Set result to hf_separation_orbits(target_vessel, Starting_time, Max_Orb_UT, 60, target_distance).
			Set result1 to hf_separation_orbits(target_vessel, result["time"]()-200, result["time"]() +200, 10, target_distance).
			Set result2 to hf_separation_orbits(target_vessel, result1["time"]()-20, result1["time"]() +20, 3, target_distance).
			Set result3 to hf_separation_orbits(target_vessel, result2["time"]()-6, result2["time"]() +6, 1, target_distance).
			Print "Intercept Target Seperation Result:" + result3["seperation"]() + " at " + result3["time"]().
			Set tempResult to abs(result3["seperation"]() - target_distance).
			Set bodRad to Body:RADIUS.
			If Modifier = "Small"{
				Set tempMod to hf_ecc_modifier((mnv:orbit:apoapsis),(target_vessel:orbit:periapsis)).
			}
			Else If Modifier = "Big"{
				Set tempMod to hf_ecc_modifier((target_vessel:orbit:apoapsis), (mnv:orbit:periapsis)).
			} 
			Else{
				Set tempMod to 1.
			}
			Print "Temp Mod:" + tempMod.
			if_condition.
			return -(tempResult + tempMod). // End Return, seeks out the closest approach from the mnv node created
		} // end hill climb fit section.
	). ///End Hill Climb
	return(result3).
} // End Function

///////////////////////////////////////////////////////////////////////////////////	

Function hf_ecc_modifier{
Parameter lower_val, higher_val.

	If lower_val < higher_val{
		return ((higher_val/(higher_val-(higher_val-lower_val)))*1000000000).
	}
	Else{
		return (1).
	}
} // End Function
///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(ORBRV).
} // End of anon



