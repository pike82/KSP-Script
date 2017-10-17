
{ // Start of anon

///// Download Dependant libraies
local Hill_Climb is import("Hill_Climb").
local OrbMnvNode is import("OrbMnvNode").
local OrbMnvs is import("OrbMnvs").
local Util_Orbit is import("Util_Orbit").

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
Parameter target_Body, Target_Perapsis, maxDV is 1000, IncTar is 90, int_Warp is False. // note the target name does not need to be sourrounded by quotations
	if runMode:haskey("ff_Node_exec") {
		OrbMnvNode["Node_exec"](int_Warp).		
	} //end runModehaskey if
	Else{	
		hf_seek_SOI(target_Body, Target_Perapsis, IncTar, maxDV).
		OrbMnvNode["Node_exec"](int_Warp).
	} //end else
}  /// End Function
	
///////////////////////////////////////////////////////////////////////////////////
	
Function ff_CraftTransfer {	
	Parameter target_ves, Target_dist, Max_orbits, int_Warp is False. // note the target name does not need to be sourrounded by quotations
	if runMode:haskey("ff_Node_exec") {
		OrbMnvNode["Node_exec"](int_Warp).		
	} //end runModehaskey if
	if runMode:haskey("ff_Node_exec") = false{
		gf_set_runmode("ff_CraftTransfer",1).
		hf_TransferInc(target_ves, Target_dist, int_Warp).
	}//end if
	If runMode["ff_CraftTransfer"] = 1{
		Set temp to hf_TransferBurn(target_ves, Target_dist, Max_orbits, int_Warp).
		gf_set_runmode("ff_CraftTransferBurn",temp).
		gf_set_runmode("ff_CraftTransfer",2).
		OrbMnvNode["Node_exec"](int_Warp).
	}//end if
	If runMode["ff_CraftTransfer"] = 2{
		if time:seconds < runMode["ff_CraftTransferBurn"]{
			//Checks to see if this node has been completed in the first if statement. If so skip this step and just remove the runmodes.
			hf_TransferRV(target_ves, Target_dist, runMode["ff_CraftTransferBurn"], int_Warp).
			gf_remove_runmode("ff_CraftTransferBurn").
			OrbMnvNode["Node_exec"](int_Warp).
		}
		gf_remove_runmode("ff_CraftTransfer").
	} //end if
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
	Set arr to Util_Orbit["Find_AN_INFO"](target_vessel).
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
		OrbMnvs["AdjPlaneInc"](0, target_vessel,(Max_inc/4),int_Warp). //Conduct inc change is required.
	} // end else
	
} //end function TransferInc

///////////////////////////////////////////////////////////////////////////////////	

Function hf_Orbit_Phasing {	
parameter target_vessel, Max_orbits.

	Set Tar_Per to target_vessel:orbit:Period.
	Set Max_time to (Max_orbits * Ship:orbit:Periapsisr). //Gets the time from now until max orbit time
	Set Max_Orb_UT to  Max_time + time:seconds. //Get the UT of the max orbits.
	Set PerLead to (Ship:orbit:Periapsisr - Tar_Per). // Value in seconds of the difference in period times. Negative indicates faster and lower orbit.
	Print "PerLead: " + PerLead.
	
	//Need to think of logic relating to per lead being positive vs negative. Positve the orbit diff needs to be 360 - orbdiff becasue it needs to take the long way around.
	
	Set Orbits_Phasing to Ship:orbit:Periapsisr/PerLead. // The number of orbits required between phasings negative indicates faster and lower orbit
	Print "Orbits_Phasing" + Orbits_Phasing.
	Set minOrbits_Phasing to  Orbits_Phasing/Max_orbits.
	Set tgt_perEta to max(0,ETA:PERIAPSIS).
	Set tgt_PeLatLng to target_vessel:body:geopositionof(positionat(target_vessel, time:seconds + tgt_perEta)). //The Lat and long of the PE
	
	// Arrange Longitudes on in 360 reference
	Set tgt_PeLng to tgt_PeLatLng:lng.
	Print "tgt_PeLng Pre: " + tgt_PeLng.
	if tgt_PeLng < 0
		set tgt_PeLng to 360 + tgt_PeLng.
	else
		set tgt_PeLng to tgt_PeLng.
	Print "tgt_PeLng Post: " + tgt_PeLng. 
	
	Set ShipPeLng to gl_PeLatLng:lng.
	Print "ShipPeLng Pre: " + ShipPeLng.
	if ShipPeLng < 0
		set ShipPeLng to 360 + ShipPeLng.
	else
		set ShipPeLng to ShipPeLng.
	Print "ShipPeLng Post: " + ShipPeLng.
		
	// Work out the angle required to be covered
	
	If PerLead > 0 { // Target aproaching ship from behind
		if ShipPeLng > tgt_PeLng{
			Set longDiff to ShipPeLng - tgt_PeLng.		
		} //then just need ship minus tgt as it is infront
		if ShipPeLng < tgt_PeLng{
			Set longDiff to 360 + ShipPeLng - tgt_PeLng.			
		} //then the target needs to go the full way around so 360 + diff
	}
	
	If PerLead < 0 { // Ship aproaching ship from behind
		if tgt_PeLng > ShipPeLng {
			Set longDiff to tgt_PeLng - ShipPeLng.		
		} //then just need tgt minus ship as it is infront
		if  tgt_PeLng < ShipPeLng {
			Set longDiff to 360 + tgt_PeLng - ShipPeLng.			
		} //then the ship needs to go the full way around so 360 + diff
	}		
	Print "longDiff: " + longDiff.
	
	Set LongDiffTime to (longDiff/360)*Ship:orbit:Periapsisr. //Time difference between longitudes
	Print "LongDiffTime: " + LongDiffTime.
	Set tgtShiptPeTime to tgt_perEta - LongDiffTime. //Time for the target to be over the ship PE (approx)
	Print "tgtShiptPeTime: " + tgtShiptPeTime.
	Print "ETA:PERIAPSIS: " + ETA:PERIAPSIS. // Ship time to Pe
	Set ShipTgtDiffTime to abs(ETA:PERIAPSIS - tgtShiptPeTime). //Time phase difference between the ship and the Target.
	Print "ShipTgtDiffTime: " + ShipTgtDiffTime.
	Set orbCatchup to abs(ShipTgtDiffTime / PerLead).
	Print "orbCatchup : " + orbCatchup.

	local arr is lexicon().
	arr:add ("Tar_Per", Tar_Per).
	arr:add ("Max_Orb_UT", Max_Orb_UT).
	arr:add ("Orbits_Phasing", Orbits_Phasing).
	arr:add ("ShipTgtDiffTime", ShipTgtDiffTime).
	arr:add ("orbCatchup", orbCatchup).
	
	Return (arr).
} // End Function

///////////////////////////////////////////////////////////////////////////////////

function hf_TransferBurn {
parameter target_vessel, target_distance, Max_orbits, int_Warp is False.
	//TODO: Test all sectors or orbits and  Pe and APO variations to ensure it works in all cases
	//TODO: Look into the if case and why it is not working

	// Adjust for Period and eccentiricty difference.	

	Set Ap_Tar to target_vessel:orbit:Apoapsis.
	Set Pe_Tar to target_vessel:orbit:PERIAPSIS.

	local arr is lexicon().
	Set arr to hf_Orbit_Phasing(target_vessel, Max_orbits).
	Set Orbits_Phasing to arr ["Orbits_Phasing"].
	Set Max_Orb_UT to arr ["Max_Orb_UT"].
	Set ShipTgtDiffTime to arr ["ShipTgtDiffTime"].
	Set orbCatchup to arr ["orbCatchup"].
	
// calc min Pe possible .
local Bod_Rad is Ship:Body:Radius.
Local atm_Height is 0.

	If Body:Atm:Exists {
		Set atm_Height to Body:Atm:HEIGHT.
	} // end if
	Else{
		Set atm_Height to (1.15*bod_rad). //estimate of the min clearance height possible for vacuumn bodies.
	} //end else
	Print "atm_Height" + atm_Height.
	
//Performa all changes at periapsis for the orbital Mnv. Make the starting time to the next Periapsis or the one after if its too close.
	Set Starting_time to time:seconds +180 + (Max_orbits*7). //allows 7 seconds per orbit iteration
	If Starting_time < (time:seconds + ETA:PERIAPSIS) {
			Set Starting_time to time:seconds +ETA:PERIAPSIS.
	}// end if
	Else{
		Set Starting_time to time:seconds + ETA:PERIAPSIS + Ship:orbit:Periapsisr.
	} // end else
	Print "Starting Time:" + Starting_time. 
	Print "Max Time:" + Max_Orb_UT.

/////Look at the current orbits and see if RV can occur, if not adjust and find a solution.
	Local result is lexicon().
	
	IF Ship:orbit:Periapsis > Ap_Tar {
	//intercept not possible . Must burn at APo to lower Pe so orbits cross.
	Print "Intercept not possible, Orbit too big, decreasing Apoapsis at Periapsis".
		if orbCatchup > Max_orbits{
			Print "Decreasing Periapsis from Apoapsis as orbits too similar to make intercept in max orbits".
			OrbMnvs["adjper"](Ap_Tar-target_distance, 50, true). //reduces periapsis to be lower that the target crafts Apoapsis - the target distance to ensure inside the Apoapsis
			Set Starting_time to time:seconds + ETA:PERIAPSIS. // need to recalculate the starting time based on the new orbit (we know we are at the apoapsis so enough time before the periapsis).
		}
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height, "Big").	//end find intersect
	}//End If
	
	ELSE IF Ship:orbit:Apoapsis < Pe_Tar  {
	//intercept not possible . Must burn at APe to Increase SMA and period (include an increase SMA function in the fittness calculation)
		Print "Intercept not possible, Orbit too small, increasing Apoapsis at Periapsis".
		if orbCatchup > Max_orbits{
			Print "Increasing Apoapsis from Periapsis as orbits too similar to make intercept in max orbits".
			OrbMnvs["adjApo"](Pe_Tar+target_distance, 50, true). //increases apoapsis to be higher than the target crafts periapsis - the target distance to ensure inside the Apoapsis
			Set Starting_time to time:seconds + ETA:PERIAPSIS. // need to recalculate the starting time based on the new orbit (we know we are at the apoapsis so enough time before the periapsis).
		}
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height, "Small").	//end find intersect
	}//End ELSE IF
	
	Else IF ((Ship:orbit:Apoapsis > Ap_Tar) and (Ship:orbit:Periapsis < Pe_Tar)) or ((Ship:orbit:Apoapsis < Ap_Tar) and (Ship:orbit:Periapsis > Pe_Tar)){
		Print "Orbits Cross".
		if orbCatchup > Max_orbits{
		 	Set PerReq to Ship:orbit:Periapsisr + (ShipTgtDiffTime/(Max_orbits-2)). //minus two as there can be upto one orbit of manevers before and then an additional one for security as it better to allow for a higher orbit in finding a solution.
			Print "PerReq: " + PerReq.
			Set SMAReq to  ((body:mu * (PerReq^2))/(4*(Constant:pi^2)))^(1/3).     //a = cuberoot((mu *t^2)/4*pi^2)
			Print "SMAReq: " + SMAReq.
			Set ApReq to ((2*SMAReq) - (Ship:orbit:Periapsis + body:radius))- body:radius. //Ap = 2SMA-Pe Note: Units in distance from centre of body so need radius conversion for calc and then back.
			Print "ApReq: " + ApReq.
			OrbMnvs["adjapo"](ApReq, 50, true).
			Set Starting_time to time:seconds + ETA:PERIAPSIS. // need to recalculate the starting time based on the new orbit (we know we have just passed the periapsis).
		}
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height).	//end find intersect
	}//End Else If
	
	ELSE{
	//Orbits could cross with the correct orientation. The Hill climb function can be used to make the orientation correct. Lookinto if there is a specific time in the orbit which will make this be more efficent.
		Print "Orbits Cross if Orientation OK".
		//TODO put in a way to determine the orientation.
		Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height).	//end find intersect
	}//End Else

Return result["Time"].
	
} //end function transferburn

///////////////////////////////////////////////////////////////////////////////////

function hf_TransferRV {
parameter target_vessel, target_distance, result, int_Warp is False.

	//Kills Relative velocity

	Local result1 is lexicon().
	Local result2 is lexicon().
	Print "Result time: " + result.
	/////////Get the RV time after execution////////////////
	Set result1 to hf_separation_orbits(target_vessel, result -1000, result +1000, 10,target_distance).
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
parameter target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height, Modifier is "not used".
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
				Set tempMod to hf_ecc_modifier((mnv:orbit:apoapsis),(target_vessel:orbit:periapsis + (3*target_distance))).
			}
			Else If Modifier = "Big"{
				Set tempMod to hf_ecc_modifier((target_vessel:orbit:apoapsis), (mnv:orbit:periapsis + (3*target_distance))).
			} 
			Else{
				Set tempMod to 1.
			}
			Print "Temp Mod:" + tempMod.
			if (mnv:orbit:periapsis < atm_Height) {Print "ATM Low". return -2^64.} // failure to be above the atmosphere make score really low
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



