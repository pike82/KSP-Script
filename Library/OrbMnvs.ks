
{ // Start of anon

//Credits: Own with utilisation of code and credits within the Hill Climb file.

///// Download Dependant libraies
local Hill_Climb is import("Hill_Climb").
local OrbMnvNode is import("OrbMnvNode").
local Util_Vessel is import("Util_Vessel").
local Util_Orbit is import("Util_Orbit").

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    local ORBManu is lex(
		"Circ", ff_Circ@,
		"adjper", ff_adjper@,
		"adjapo", ff_adjapo@,
		"adjeccorbit", ff_adjeccorbit@,
		"AdjOrbInc", ff_AdjOrbInc@,
		"AdjPlaneInc", ff_AdjPlaneInc@
    ).
	
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////
//Credits: Own

//TODO: Create a file function that seeks out both an optimum Apoapsis and Periapsis to define an eccentic orbit.
//TODO: look at the KOS-Stuff_master manu file for possible ideas on reducing and bettering the AN code and manervering code.
//TODO look at the hill climb stuff once a PEG ascent program is completed.	
	Function ff_Circ {
	//TODO: Change to work with negative inclinations.
	Print "Creating Circularisation checking in space".
	Parameter APSIS is "per", EccTarget is 0.005, int_Warp is false, IncTar is 1000.
		if runMode:haskey("ff_Node_exec") {
			OrbMnvNode["Node_exec"](int_Warp).		
		} //end runModehaskey if
		Else If  SHIP:ORBIT:ECCENTRICITY > EccTarget {
			until Ship:Altitude > (0.95 * ship:body:atm:height) {
				Wait 0.1. //ensure effectively above the atmosphere before creating the node
			}
			Print "Ecentricity:" + SHIP:ORBIT:ECCENTRICITY.
			If APSIS="per" or obt:transition = "ESCAPE"{ // this either take the variable or overides the varible if the orbit is an escape trajectory to ensure it is performed at the periapsis
				set Cirdv to Util_Orbit["CircOrbitVel"](ship:orbit:periapsis) - Util_Orbit["EccOrbitVel"](ship:orbit:periapsis, ship:orbit:semimajoraxis).
				Print "Seeking Per Circ".
				Print "Min Dv Required:"+ Cirdv.
				If IncTar = 1000{
					Set n to Node(time:seconds + ETA:PERIAPSIS,0,0,Cirdv).
					Add n.
				}
				Else{
			// use the following in the future to also conduct a change of inclination at the same time
					Hill_Climb["Seek"](Hill_Climb["freeze"](time:seconds + ETA:PERIAPSIS), Hill_Climb["freeze"](0), 0, Cirdv, 
						{ 	parameter mnv. 
							return -mnv:orbit:eccentricity - (abs(IncTar-mnv:orbit:inclination)/2).
						}//needs to be changed to deal with negative inclinations
					).
				}//end else
				OrbMnvNode["Node_exec"](int_Warp).
			}
			IF APSIS="apo"{
				set Cirdv to Util_Orbit["CircOrbitVel"](ship:orbit:apoapsis) - Util_Orbit["EccOrbitVel"](ship:orbit:apoapsis, ship:orbit:semimajoraxis).
				Print "Seeking Apo Circ".
				Print "Min Dv Required:"+ Cirdv.
				If IncTar = 1000{
					Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Cirdv).
					Add n.
				}
				Else{
			// use the following in the future to also conduct a change of inclination at the same time
					Hill_Climb["Seek"](Hill_Climb["freeze"](time:seconds + ETA:APOAPSIS), Hill_Climb["freeze"](0), 0, Cirdv, 
						{ 	parameter mnv. 
							return -mnv:orbit:eccentricity - (abs(IncTar-mnv:orbit:inclination)/2).
						} //needs to be changed to deal with negative inclinations
					).
				}
				OrbMnvNode["Node_exec"](int_Warp).
			}
		}//End else IF

	} /// End Function

///////////////////////////////////////////////////////////////////////////////////		
//Credits: Own
	
	Function ff_adjper {
	Parameter Target_Perapsis, Target_Tolerance is 500, int_Warp is false, IncTar is 1000.
		if runMode:haskey("ff_Node_exec") {
			OrbMnvNode["Node_exec"](int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting Per".
			set newsma to (ship:orbit:apoapsis+(body:radius*2)+Target_Perapsis)/2.
			set Edv to Util_Orbit["EccOrbitVel"](ship:orbit:apoapsis, newsma)- Util_Orbit["EccOrbitVel"](ship:orbit:apoapsis).
			print "Estimated dv:"+ Edv.
			If IncTar = 1000{
				Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Edv).
				Add n.
			}
			Else{
			// use the following in the future to also conduct a change of inclination at the same time
				Hill_Climb["Seek"](Hill_Climb["freeze"](time:seconds + ETA:APOAPSIS), Hill_Climb["freeze"](0), 0, Edv, 
					{ 	parameter mnv. 
						if Util_Vessel["tol"](mnv:orbit:periapsis, Target_Perapsis , Target_Tolerance) return 0. 
						return -(abs(Target_Perapsis-mnv:orbit:periapsis) / Target_Perapsis)- (abs(IncTar-mnv:orbit:inclination)/2). 
					}
				).
			}
			OrbMnvNode["Node_exec"](int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
	
	Function ff_adjapo {
	Parameter Target_Apoapsis, Target_Tolerance is 500, int_Warp is false, IncTar is 1000.
		if runMode:haskey("ff_Node_exec") {
			OrbMnvNode["Node_exec"](int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting Apo".
			set newsma to (ship:orbit:periapsis+(body:radius*2)+Target_Apoapsis)/2.
			set Edv to Util_Orbit["EccOrbitVel"](ship:orbit:periapsis, newsma)- Util_Orbit["EccOrbitVel"](ship:orbit:periapsis).
			print "Estimated dv:" + Edv.
			If IncTar = 1000{
				Set n to Node(time:seconds + ETA:PERIAPSIS,0,0,Edv).
				Add n.
			}
			Else{
			// use the following in the future to also conduct a change of inclination at the same time
				Hill_Climb["Seek"](Hill_Climb["freeze"](time:seconds + ETA:PERIAPSIS), Hill_Climb["freeze"](0), 0, Edv, 
					{ 	parameter mnv. 
						if Util_Vessel["tol"](mnv:orbit:apoapsis, Target_Apoapsis , Target_Tolerance) return 0. 
						return -(abs(Target_Apoapsis-mnv:orbit:Apoapsis) / Target_Apoapsis)- (abs(IncTar-mnv:orbit:inclination)/2). 
					}
				).
			}
			OrbMnvNode["Node_exec"](int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////

//Credits: Own

//TODO: Use Position at to make this more efficent and accurate by undertaking the burn when the ship will be at the new periapsis or apoapsis (depends on if more or less energy is required via SMA)
//TODO: Use the master Stuff manu file as an example to determine the perpendicualr vector at the burn point so the dV and node can be created without the hill climb.
// This will only get the correct orbit if teh ship is below the target apoapsis at the time of the burn, otherwise the apoapsis cannot be lowered enough.
	Function ff_adjeccorbit {
	Parameter Target_Apoapsis, Target_Perapsis, StartingTime is time:seconds + 300, Target_Tolerance is 500, int_Warp is false.
		if runMode:haskey("ff_Node_exec") {
			OrbMnvNode["Node_exec"](int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting Eccentirc orbit". 
			Hill_Climb["Seek"](
				Hill_Climb["freeze"](StartingTime), 0, Hill_Climb["freeze"](0), 0, { 
					parameter mnv. 
					if (Util_Vessel["tol"](mnv:orbit:apoapsis, Target_Apoapsis , Target_Tolerance) 
					and Util_Vessel["tol"](mnv:orbit:periapsis, Target_Perapsis , Target_Tolerance))return 0. 
					return -(abs(Target_Apoapsis-mnv:orbit:Apoapsis))-(abs(Target_Perapsis-mnv:orbit:periapsis)). 
				}
			).
			OrbMnvNode["Node_exec"](int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
	
	Function ff_AdjOrbInc {
	Parameter Target_Inc, target_Body is Ship:Orbit:body,int_Warp is false.
		if runMode:haskey("ff_Node_exec") {
			OrbMnvNode["Node_exec"](int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting inc".
			Hill_Climb["Seek"](
				Hill_Climb["freeze"](time:seconds + ETA:APOAPSIS), Hill_Climb["freeze"](0), 0, Hill_Climb["freeze"](0), { parameter mnv. return -abs(mnv:orbit:inclination - Target_Inc). }
			).
			OrbMnvNode["Node_exec"](int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own

	Function ff_AdjPlaneInc {
	Parameter Target_Inc, target_Body, Target_Tolerance is 0.05, int_Warp is false.
		if runMode:haskey("ff_Node_exec") {
			OrbMnvNode["Node_exec"](int_Warp).		
		} //end runModehaskey if
		Else{
			Print "Adusting inc plane".
			Local UT is Util_Orbit["Find_AN_UT"](target_Body).
			Hill_Climb["Seek"](
				Hill_Climb["freeze"](UT), 0, 0, 0, { 
					parameter mnv. 
					if Util_Vessel["tol"]((mnv:orbit:inclination - target_Body:orbit:inclination), Target_Inc, Target_Tolerance){
						return
						- (mnv:DELTAV:mag) 
						- abs(ship:orbit:apoapsis-mnv:orbit:apoapsis) 
						- abs(ship:orbit:periapsis - mnv:orbit:periapsis). 
					} 
					Else{
						return
						-(abs(Target_Inc - (mnv:orbit:inclination - target_Body:orbit:inclination))*1000000)
						- (mnv:DELTAV:mag) 
						- abs(ship:orbit:apoapsis-mnv:orbit:apoapsis) 
						- abs(ship:orbit:periapsis - mnv:orbit:periapsis). 
					}
				}
				, True
			).
			OrbMnvNode["Node_exec"](int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
  export(ORBManu).
} // End of anon



