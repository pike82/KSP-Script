
//Credits: Own with utilisation of code and credits within the Hill Climb file.

///// Download Dependant libraies

FOR file IN LIST(
	"Util_Vessel",
	"OrbMnvNode",
	"OrbMnvs",
	"Util_Orbit"){ 
		IF not EXISTS("1:/" + file) {
			RUNONCEPATH(gf_DOWNLOAD("0:/Library/",file,file)). 
			wait 0.001.
		}
		RUNPATH(file).
	}


///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    // local ORBRV is lex(
		// "BodyTransfer", ff_BodyTransfer@,
		// "CraftTransfer", ff_CraftTransfer@
    // ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////		

//TODO: look at the KOS-Stuff_master manu file for possible ideas on reducing and bettering the AN code and manervering code.


FUNCTION ff_Hohmann{

//Credit:https://github.com/ElWanderer/kOS_scripts and wiki

//TODO:look-into hohmann transfers where can use position at(orbit,time) to determine where a body will be and then make a manuver to meet it at the same time intead of purely node iterations through hill climb.

// Note this assumes a relatively circular oribit for both the Ship and the target.

PARAMETER tgt, t_pe is 100000, trans_bod is Ship:BODY, inc_tgt is 0, int_Warp is false. // trans_bod should be sun for planet transfers
	
	Local Curr_time is time:seconds.
	Print "Curr_time: "+ Curr_time.
	LOCAL Ship_Orbit is ORBITAT(SHIP,Curr_time). //ORBITAT(orbitable,time) is KOS in-built function
	LOCAL tgt_Orbit is ORBITAT(tgt,Curr_time).
	LOCAL r1 is Ship_Orbit:SEMIMAJORAXIS.
	LOCAL r2 is tgt_Orbit:SEMIMAJORAXIS + t_pe.
	
	Print Ship_Orbit. 
	Print tgt_Orbit.
	Print r1.
	Print r2.
	
	Print trans_bod:MU.
	
	LOCAL dvDepart is SQRT(trans_bod:MU/r1) * (SQRT((2*r2)/(r1+r2)) -1). // wiki Dv1 Equation
	LOCAL dvArrive is SQRT(trans_bod:MU/r1) * (1- SQRT((2*r2)/(r1+r2))). // wiki Dv2 Equation
	Print dvDepart.
	Print dvArrive.
	
	if r2 < r1 { 
		SET dvDepart TO -dvDepart. // this allows for transfers to a lower orbit
		SET dvArrive TO -dvArrive.
	}
	
	if -dvDepart = dvArrive {
		set dvArrive to 0. // allows for transfers within the same SOI where the dv arrive and depart are the same.
	}
	Print "dvArrive: " + dvArrive.

	local dv is dvDepart + dvArrive.
	Print "dv int:" + dv.
	LOCAL Trans_time is CONSTANT:PI * SQRT( ((r1+r2)^3) / (8 * trans_bod:MU) ). // wiki transfer orbit time Equation
	Print "Trans_time: "+ Trans_time.
	Print tgt_Orbit:PERIOD.
	LOCAL Tgt_travel_ang is (Trans_time / tgt_Orbit:PERIOD)* 360. // the angle the tgt moves during the transist assuming a circular orbit
	Print Tgt_travel_ang.
	LOCAL desired_phi is 180 - Tgt_travel_ang. // we want to meet the target at apoapsis so the target need to travel and end 180 degrees from where we start.
	Print desired_phi.
	LOCAL rel_ang_Change is (360 / Ship_Orbit:PERIOD) - (360 / tgt_Orbit:PERIOD). // the degrees the tgt moves each orbit by the ship each second.
	Print rel_ang_Change.
	LOCAL ship_pos is positionat(SHIP, Curr_time)-ship:body:position. //current position of the ship
	LOCAL tgt_pos is positionat(tgt, Curr_time)-tgt:body:position. //current position of the target
	
	LOCAL start_phi is VANG(ship_pos,tgt_pos). // the current angle between the ship and the tgt.
	Print start_phi.
	
	LOCAL ship_normal IS VCRS(VELOCITYAT(SHIP,curr_time):ORBIT,ship_pos).// the plane of the ship
	LOCAL ship_tgt_cross IS VCRS(ship_pos,tgt_pos).//// plane of the transfer (ie. incination diference)
	
	Print ship_normal.
	Print ship_tgt_cross.
	
	Print VDOT(ship_normal, ship_tgt_cross).
	
	if VDOT(ship_normal, ship_tgt_cross) > 0 { 
		SET start_phi TO 360 - start_phi. 
	} // this checks to see if the planes are pointed in the same direction or are pointed opposite to one another so it is known if ship is leading or lagging the tgt. 

	LOCAL phi_delta is ff_mAngle(start_phi - desired_phi). //this determines how far off the best phase angle is.
	Print "phi_delta: " + phi_delta.
	if rel_ang_Change < 0 { 
		SET phi_delta TO phi_delta - 360. //adjust for negative angle change values
	}
	Print rel_ang_Change.
	Print (phi_delta / rel_ang_Change).
	Print Curr_time.
	Local node_time is Curr_time + (phi_delta / rel_ang_Change).
	Print node_time.
	LOCAL first_est is NODE(node_time, 0, 0, dv). // this creates the node (best refined by a hill climb) which can be used to gain a good first approximation of the time required to speed up the solution.
	wait 1.0.
	Print "Node time: " + node_time.
	Print "DV: " + dv.
	Wait 5.
	
	
	if runMode:haskey("ff_Node_exec") {
		ff_Node_exec(int_Warp).		
	} //end runModehaskey if
	Else{	
		hf_seek_SOI(tgt, t_pe, inc_tgt, dv*1.2, Curr_time + (phi_delta / rel_ang_Change), 0, 0, dv).
		ff_Node_exec(int_Warp).
	} //end else
}

Function ff_BodyTransfer {	
Parameter target_Body, Target_Perapsis, maxDV is 1000, IncTar is 90, int_Warp is False. // note the target name does not need to be sourrounded by quotations
	if runMode:haskey("ff_Node_exec") {
		ff_Node_exec(int_Warp).		
	} //end runModehaskey if
	Else{	
		hf_seek_SOI(target_Body, Target_Perapsis, IncTar, maxDV).
		ff_Node_exec(int_Warp).
	} //end else
}  /// End Function
	
///////////////////////////////////////////////////////////////////////////////////

//Credits: Own
	
Function ff_CraftTransfer {	
	Parameter target_ves, Target_dist, Max_orbits, int_Warp is False. // note the target name does not need to be surrounded by quotations
	if runMode:haskey("ff_Node_exec") {
		ff_Node_exec(int_Warp).		
	} //end runModehaskey if
	if runMode:haskey("ff_Node_exec") = false{
		gf_set_runmode("ff_CraftTransfer",1).
		hf_TransferInc(target_ves, Target_dist, int_Warp).
	}//end if
	If runMode["ff_CraftTransfer"] = 1{
		Set temp to hf_TransferBurn(target_ves, Target_dist, Max_orbits, int_Warp).
		gf_set_runmode("ff_CraftTransferBurn",temp).
		gf_set_runmode("ff_CraftTransfer",2).
		ff_Node_exec(int_Warp).
	}//end if
	If runMode["ff_CraftTransfer"] = 2{
		if time:seconds < runMode["ff_CraftTransferBurn"]{
			//Checks to see if this node has been completed in the first if statement to allow a follow up mid cousrse burn. If so skip this step and just remove the runmodes.
			hf_TransferRV(target_ves, Target_dist, runMode["ff_CraftTransferBurn"], int_Warp).
			ff_Node_exec(int_Warp).
		}
		gf_remove_runmode("ff_CraftTransfer").
	} //end if
}  /// End Function
	
///////////////////////////////////////////////////////////////////////////////////
//Helper Functions
/////////////////////////////////////////////////////////////////////////////////////
//Credits: http://youtube.com/gisikw
	  
function hf_seek_SOI {
	parameter target_body, target_periapsis, IncTar, maxDV,
		  start_time is time:seconds + 600, r is 0, n is 0, p is 0. 
		  Print "Seeking SOI".
	local data is ff_Seek_low (
		start_time, r, n, p, 
		{  
		parameter mnv.
		if hf_transfers_to(mnv:orbit, target_body) return 1.
		//TODO: put in inorge capability using "target_orbit:hasnextpatch and target_orbit:nextpatch:body <> target_body" so that it will ignore/is sceptical of results which use another body for a gravity assist as boundary cases around this can affect the hill climb results.
		return -hf_closest_approach
			(
			target_body,
			time:seconds + mnv:eta,
			time:seconds + mnv:eta + mnv:orbit:period
			). // seeks out the closest approach from the mnv node created
		} //end seek parameter
	). //stores the results as a data set enabling a search within another search. This Level is the inner search
	Print "SOI Found Refining solution".
	return ff_Seek_low(
		data[0], data[1], data[2], data[3], 
		{
		parameter mnv.
		if not hf_transfers_to(mnv:orbit, target_body) return -2^64. // failure to be within the SOI make score really low
		if (mnv:DELTAV:mag > maxDV) return -2^64. // failure to be under max dv make score really low
		//Print "Per: " + (mnv:orbit:nextpatch:periapsis - target_periapsis).
		//Print "Inc: " +(mnv:orbit:nextpatch:inclination-IncTar).
		return -(abs((mnv:orbit:nextpatch:periapsis - target_periapsis)*1000))-(mnv:DELTAV:mag*100)-(abs(mnv:orbit:nextpatch:inclination-IncTar)*10).// 1000m = 10m/s = 1 degree of inclination
		} //end seek parameter
	). // this level is the outter search and uses the data parameter to do internal searches per step

}  /// End Function


///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
	  
function hf_TransferInc {
parameter target_vessel, target_distance, int_Warp is False.
	local arr is lexicon().
	Set arr to ff_Find_AN_INFO(target_vessel).
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
		ff_AdjPlaneInc(0, target_vessel,(Max_inc/4),int_Warp). //Conduct inc change is required.
	} // end else
	
} //end function TransferInc

///////////////////////////////////////////////////////////////////////////////////	
//Credits: Own

Function hf_Orbit_Phasing {	
parameter target_vessel, Max_orbits.

	Set Tar_Per to target_vessel:orbit:Period.
	Set Max_time to (Max_orbits * Ship:orbit:Period). //Gets the time from now until max orbit time
	Set Max_Orb_UT to  Max_time + time:seconds. //Get the UT of the max orbits.
	Set PerLead to (Ship:orbit:Period - Tar_Per). // Value in seconds of the difference in period times. Negative indicates faster and lower orbit.
	Print "PerLead: " + PerLead.
	
	//Need to think of logic relating to per lead being positive vs negative. Positve the orbit diff needs to be 360 - orbdiff becasue it needs to take the long way around.
	
	Set Orbits_Phasing to Ship:orbit:Period/PerLead. // The number of orbits required between phasings negative indicates faster and lower orbit
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
	Print "PerLead: " + PerLead.
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
	
	Set LongDiffTime to (longDiff/360)*Ship:orbit:Period. //Time difference between longitudes
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
//Credits: Own

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
		Set Starting_time to time:seconds + ETA:PERIAPSIS + Ship:orbit:Period.
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
			ff_adjPer(Ap_Tar-target_distance, 50, true). //reduces periapsis to be lower that the target crafts Apoapsis - the target distance to ensure inside the Apoapsis
			Set Starting_time to time:seconds + ETA:PERIAPSIS. // need to recalculate the starting time based on the new orbit (we know we are at the apoapsis so enough time before the periapsis).
		}
		//Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height, "Big").	//end find intersect
	}//End If
	
	ELSE IF Ship:orbit:Apoapsis < Pe_Tar  {
	//intercept not possible . Must burn at APe to Increase SMA and period (include an increase SMA function in the fittness calculation)
		Print "Intercept not possible, Orbit too small, increasing Apoapsis at Periapsis".
		if orbCatchup > Max_orbits{
			Print "Increasing Apoapsis from Periapsis as orbits too similar to make intercept in max orbits".
			ff_adjApo(Pe_Tar+target_distance, 50, true). //increases apoapsis to be higher than the target crafts periapsis - the target distance to ensure inside the Apoapsis
			Set Starting_time to time:seconds + ETA:PERIAPSIS. // need to recalculate the starting time based on the new orbit (we know we are at the apoapsis so enough time before the periapsis).
		}
		//Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height, "Small").	//end find intersect
	}//End ELSE IF
	
	Else IF ((Ship:orbit:Apoapsis > Ap_Tar) and (Ship:orbit:Periapsis < Pe_Tar)) or ((Ship:orbit:Apoapsis < Ap_Tar) and (Ship:orbit:Periapsis > Pe_Tar)){
		Print "Orbits Cross".
		if orbCatchup > Max_orbits{
		Print "Cannot lower orbit to meet, raising apoapsis too allow possible intercept".
		 	Set PerReq to Ship:orbit:Period + (ShipTgtDiffTime/(Max_orbits-2)). //minus two as there can be upto one orbit of manevers before and then an additional one for security as it better to allow for a higher orbit in finding a solution.
			Print "PerReq: " + PerReq.
			Set SMAReq to  ((body:mu * (PerReq^2))/(4*(Constant:pi^2)))^(1/3).     //a = cuberoot((mu *t^2)/4*pi^2)
			Print "SMAReq: " + SMAReq.
			Set ApReq to ((2*SMAReq) - (Ship:orbit:Periapsis + body:radius))- body:radius. //Ap = 2SMA-Pe Note: Units in distance from centre of body so need radius conversion for calc and then back.
			Print "ApReq: " + ApReq.
			ff_adjapo(ApReq, 50, true).
			Set Starting_time to time:seconds + ETA:PERIAPSIS. // need to recalculate the starting time based on the new orbit (we know we have just passed the periapsis).
		}
		//Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height).	//end find intersect
	}//End Else If
	
	ELSE{
	//Orbits could cross with the correct orientation. The Hill climb function can be used to make the orientation correct. Lookinto if there is a specific time in the orbit which will make this be more efficent.
		Print "Orbits Cross if Orientation OK".
		//TODO put in a way to determine the orientation.
		//Wait 10.0. //debugging
		Set result to hf_find_intersect (target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height).	//end find intersect
	}//End Else

Return result["Time"].
	
} //end function transferburn

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own

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

	ff_Seek_low(ff_freeze(result2["time"]()), 0, ff_freeze(0), 0,{  
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
//Credits: http://youtube.com/gisikw
	  
function hf_transfers_to {
parameter target_orbit, target_body.
return (target_orbit:hasnextpatch and
		target_orbit:nextpatch:body = target_body). // returns true if the next patch is the intended target. (look at making this potentially search through the patches to make work for sling shots via the mun etc.)
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
//Credits: http://youtube.com/gisikw
	  
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
  //Print "middle_slope" + middle_slope.
  //Wait 1.0.
}
local Sep is hf_separation_at(target_body, middle_time).
Print "Seperation is: " + Sep.
return Sep.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
//Credits: http://youtube.com/gisikw
	  
function hf_slope_at {
parameter target_body, at_time.
return (
  hf_separation_at(target_body, at_time + 1) -
  hf_separation_at(target_body, at_time - 1)
) / 2.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
//Credits: http://youtube.com/gisikw
	  
function hf_separation_at {
parameter target_body, at_time.
	// Print (positionat(ship, at_time) - positionat(target_body, at_time)):mag.
	return (positionat(ship, at_time) - positionat(target_body, at_time)):mag.
}/// End Function

///////////////////////////////////////////////////////////////////////////////////	
//Credits: http://youtube.com/gisikw

function hf_separation_orbits {
parameter target_body, Start_time, EndTime, StepSize, Target_distance is 1500.
Set WinSep to 2^64.
Set WinTime to 0.
	FROM {local y is Start_time.} 
	UNTIL y > EndTime // Loop until at max time
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

//Credits: http://youtube.com/gisikw

Function hf_find_intersect {
parameter target_vessel, Starting_time, Target_distance, Max_Orb_UT, atm_Height, Modifier is "not used".
Local result is lexicon().
Local result1 is lexicon().
Local result2 is lexicon().
Local result3 is lexicon().
Local tempResult is 0.
	ff_Seek_low(ff_freeze(Starting_time), 0, ff_freeze(0), 0,
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
//Credits: Own

Function hf_ecc_modifier{
Parameter lower_val, higher_val.

	If lower_val < higher_val{
		return ((higher_val/(higher_val-(higher_val-lower_val)))*1000000000).
	}
	Else{
		return (1).
	}
} // End Function





