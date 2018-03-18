


//Credits: Own with utilisation of code and credits within the Hill Climb file.

///// Download Dependant libraies

FOR file IN LIST(
	"Hill_Climb",
	"OrbMnvNode",
	"Util_Vessel",
	"Util_Orbit"){ 
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

    // local ORBManu is lex(
		// "Circ", ff_Circ@,
		// "adjper", ff_adjper@,
		// "adjapo", ff_adjapo@,
		// "adjeccorbit", ff_adjeccorbit@,
		// "AdjOrbInc", ff_AdjOrbInc@,
		// "AdjPlaneInc", ff_AdjPlaneInc@
    // ).
	
////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////
//Credits: Own

//TODO: Create a file function that seeks out both an optimum Apoapsis and Periapsis to define an eccentic orbit.
//TODO: look at the KOS-Stuff_master manu file for possible ideas on reducing and bettering the AN code and manervering code.
//TODO look at the hill climb stuff once a PEG ascent program is completed.	
	Function ff_Circ {
	//TODO: Change to work with negative inclinations.
	Print "Creating Circularisation, checking to see if vessel is in space".
	Parameter APSIS is "per", EccTarget is 0.005, int_Warp is false, IncTar is 1000.
		if runMode:haskey("ff_Node_exec") {
			ff_Node_exec(int_Warp).		
		} //end runModehaskey if
		Else If  SHIP:ORBIT:ECCENTRICITY > EccTarget {
			until Ship:Altitude > (0.95 * ship:body:atm:height) {
				Wait 0.1. //ensure effectively above the atmosphere before creating the node
			}
			Print "Ecentricity:" + SHIP:ORBIT:ECCENTRICITY.
			If APSIS="per" or obt:transition = "ESCAPE"{ // this either take the variable or overides the varible if the orbit is an escape trajectory to ensure it is performed at the periapsis
				if ship:orbit:semimajoraxis > 0 {
					set Cirdv to ff_CircOrbitVel((ship:orbit:periapsis) - ff_EccOrbitVel(ship:orbit:periapsis, ship:orbit:semimajoraxis)).
				}
				Else{
					Print "Escape Trajectory Detected".
					set Cirdv to ff_EccOrbitVel(ship:orbit:periapsis, ship:orbit:semimajoraxis) - ff_CircOrbitVel(ship:orbit:periapsis).
					If Cirdv > 0{
						set Cirdv to -Cirdv. //ensures that a capture div is obtain regardless of approach.
					}
				}
				Print "Seeking Per Circ".
				Print "Min Dv Required:"+ Cirdv.
				If IncTar = 1000{
					Set n to Node(time:seconds + ETA:PERIAPSIS,0,0,Cirdv).
					Add n.
				}
				Else{
			// use the following in the future to also conduct a change of inclination at the same time
					ff_Seek_low(ff_freeze(time:seconds + ETA:PERIAPSIS), ff_freeze(0), 0, Cirdv, 
						{ 	parameter mnv. 
							return -mnv:orbit:eccentricity - (abs(IncTar-mnv:orbit:inclination)/2).
						}//needs to be changed to deal with negative inclinations
					).
				}//end else
				ff_Node_exec(int_Warp).
			}
			IF APSIS="apo"{
				set Cirdv to ff_CircOrbitVel(ship:orbit:apoapsis) - ff_EccOrbitVel(ship:orbit:apoapsis, ship:orbit:semimajoraxis).
				Print "Seeking Apo Circ".
				Print "Min Dv Required:"+ Cirdv.
				If IncTar = 1000{
					Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Cirdv).
					Add n.
				}
				Else{
			// use the following in the future to also conduct a change of inclination at the same time
					ff_Seek_low(ff_freeze(time:seconds + ETA:APOAPSIS), ff_freeze(0), 0, Cirdv, 
						{ 	parameter mnv. 
							return -mnv:orbit:eccentricity - (abs(IncTar-mnv:orbit:inclination)/2).
						} //needs to be changed to deal with negative inclinations
					).
				}
				ff_Node_exec(int_Warp).
			}
		}//End else IF

	} /// End Function

///////////////////////////////////////////////////////////////////////////////////		
//Credits: Own
	
	Function ff_adjper {
	Parameter Target_Perapsis, Target_Tolerance is 500, int_Warp is false, IncTar is 1000.
		if runMode:haskey("ff_Node_exec") {
			ff_Node_exec(int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting Per".
			set newsma to (ship:orbit:apoapsis+(body:radius*2)+Target_Perapsis)/2.
			set Edv to ff_EccOrbitVel(ship:orbit:apoapsis, newsma)- ff_EccOrbitVel(ship:orbit:apoapsis).
			print "Estimated dv:"+ Edv.
			If IncTar = 1000{
				Set n to Node(time:seconds + ETA:APOAPSIS,0,0,Edv).
				Add n.
			}
			Else{
			// use the following in the future to also conduct a change of inclination at the same time
				ff_Seek_low(ff_freeze(time:seconds + ETA:APOAPSIS), ff_freeze(0), 0, Edv, 
					{ 	parameter mnv. 
						if ff_tol(mnv:orbit:periapsis, Target_Perapsis , Target_Tolerance) return 0. 
						return -(abs(Target_Perapsis-mnv:orbit:periapsis) / Target_Perapsis)- (abs(IncTar-mnv:orbit:inclination)/2). 
					}
				).
			}
			ff_Node_exec(int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
	
	Function ff_adjapo {
	Parameter Target_Apoapsis, Target_Tolerance is 500, int_Warp is false, IncTar is 1000.
		if runMode:haskey("ff_Node_exec") {
			ff_Node_exec(int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting Apo".
			set newsma to (ship:orbit:periapsis+(body:radius*2)+Target_Apoapsis)/2.
			set Edv to ff_EccOrbitVel(ship:orbit:periapsis, newsma)- ff_EccOrbitVel(ship:orbit:periapsis).
			print "Estimated dv:" + Edv.
			If IncTar = 1000{
				Set n to Node(time:seconds + ETA:PERIAPSIS,0,0,Edv).
				Add n.
			}
			Else{
			// use the following in the future to also conduct a change of inclination at the same time
				ff_Seek_low(ff_freeze(time:seconds + ETA:PERIAPSIS), ff_freeze(0), 0, Edv, 
					{ 	parameter mnv. 
						if ff_tol(mnv:orbit:apoapsis, Target_Apoapsis , Target_Tolerance) return 0. 
						return -(abs(Target_Apoapsis-mnv:orbit:Apoapsis) / Target_Apoapsis)- (abs(IncTar-mnv:orbit:inclination)/2). 
					}
				).
			}
			ff_Node_exec(int_Warp).
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
			ff_Node_exec(int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting Eccentirc orbit". 
			Print Target_Apoapsis.
			Print Target_Perapsis.
			Print StartingTime.
			ff_Seek_low(
				ff_freeze(StartingTime), 0, ff_freeze(0), 0, { 
					parameter mnv. 
					if ff_tol(mnv:orbit:apoapsis, Target_Apoapsis , Target_Tolerance) 
					and ff_tol(mnv:orbit:periapsis, Target_Perapsis , Target_Tolerance)return 0. 
					return -(abs(Target_Apoapsis-mnv:orbit:Apoapsis))-(abs(Target_Perapsis-mnv:orbit:periapsis)). 
				}
			).
			ff_Node_exec(int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
	
	Function ff_AdjOrbInc {
	Parameter Target_Inc, target_Body is Ship:Orbit:body,int_Warp is false.
		if runMode:haskey("ff_Node_exec") {
			ff_Node_exec(int_Warp).		
		} //end runModehaskey if
		Else {
			Print "Adusting inc".
			ff_Seek_low(
				ff_freeze(time:seconds + ETA:APOAPSIS), ff_freeze(0), 0, ff_freeze(0), { parameter mnv. return -abs(mnv:orbit:inclination - Target_Inc). }
			).
			ff_Node_exec(int_Warp).
		} //end else
	}	/// End Function

///////////////////////////////////////////////////////////////////////////////////
//Credits: Own

	Function ff_AdjPlaneInc {
	Parameter Target_Inc, target_Body, Target_Tolerance is 0.05, int_Warp is false.
		if runMode:haskey("ff_Node_exec") {
			ff_Node_exec(int_Warp).		
		} //end runModehaskey if
		Else{
			Print "Adusting inc plane".
			Local UT is ff_Find_AN_UT(target_Body).
		
			Wait 1.
			ff_Seek_low(
				ff_freeze(UT), 0, 0, 0, { 
					parameter mnv. 				
					if ff_tol((mnv:orbit:inclination - target_Body:orbit:inclination), Target_Inc, Target_Tolerance){
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
			wait 1.
			
			Print "tgt LAN " + target_Body:orbit:LAN.
			Print "Ship LAN " + Ship:orbit:LAN.
			Print "Check LAN Diff".
			Print mod(720 + target_Body:orbit:LAN + Ship:orbit:LAN,360).
			If mod(720 + target_Body:orbit:LAN + Ship:orbit:LAN,360) < 90 or mod(720 + target_Body:orbit:LAN + Ship:orbit:LAN,360) > 270{
				local oldnode is nextnode.
				local newnode is node(time:seconds + oldnode:ETA, oldnode:RADIALOUT, -oldnode:NORMAL, oldnode:PROGRADE).
				Print oldnode:NORMAL.
				Remove nextnode.
				Add newnode.
				Print "Normal Burn inversed".
			}
			
			wait 1.
			ff_Node_exec(int_Warp).
		} //end else
	}	/// End Function


///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
// Note: this assumes you are already roughly at the period desired, and only reqquires fine tuning via RCS thrusters. This fine tuning will be done at a specifed altitude (i.e Apoapsis) .
	Function ff_FineAdjPeriod {
	Parameter Target_Per, Tol.
		RCS on.
		
		Lock Steering to Ship:Prograde + R(0,90,0). //set to radial
		wait 10. //allow time for rotation.
		Local Curr_period is Ship:orbit:Period .
		Local Speed is min(1, max(-1, Curr_period - Target_Per)).
		local vec is V(0,0,Speed ).
		Print Speed.
		print vec.
		Until abs(Curr_period - Target_Per) < Tol{
			SET SHIP:CONTROL:TRANSLATION to (vec) .
			Clearscreen.
			Print "Target Period: " + Target_Per.
			Print "Current Period: " + Curr_period.
			Print "Period Diff: " + abs(Curr_period - Target_Per).
			Print "Speed : " + Speed.
			Set Curr_period to Ship:orbit:Period .
			Set Speed to min(1, max(-1, Curr_period - Target_Per)).
			Set vec to V(0,0,Speed ).
			Print vec.
			wait 0.01.
		}
		RCS off.
	}	/// End Function
	
///////////////////////////////////////////////////////////////////////////////////
//Credits: Own
// This return the orbital altitude of the missing APO or PER depending on what alt value you use .
	Function ff_Obit_sync {
	Parameter target_orbit_period, Num_Sat, alt.
	
		local Orbit_period is target_orbit_period - (target_orbit_period/Num_Sat).//ie. Target orbit period of 3000 secs with three sats will aim for an orbit of 2000 secs
		local sma is (  
						(
						(body:mu*(Orbit_period^2)) /
						(4*(constant():pi^2)  )
						)
						^ (1/3)
					).
		
		Return ((2*sma)-(alt+body:radius))-body:radius.
	}	/// End Function

