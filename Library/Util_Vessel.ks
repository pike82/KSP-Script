
{ // Start of anon

///// Download Dependant libraies

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////
	local Util_Vessel is lex(
		"tol", ff_Tolerance@,
		"FAIRING",ff_FAIRING@,
		"COMMS",ff_COMMS@,
		"Gravity",ff_Gravity@,
		"R_chutes_seq", ff_R_chutes_seq@,
		"R_chutes", ff_R_chutes@,
		"collect_science", ff_collect_science@
	).

/////////////////////////////////////////////////////////////////////////////////////	
//File Functions	
/////////////////////////////////////////////////////////////////////////////////////	
	
FUNCTION ff_FAIRING {
	PARAMETER stagewait IS 0.1.

	IF SHIP:Q < 0.005 {
		FOR module IN SHIP:MODULESNAMED("ProceduralFairingDecoupler") {
			module:DOEVENT("jettison").
			PRINT "Jettisoning Fairings".
			WAIT stageWait.
		}.
	}
} // End of Function

function solarpanels{
	panels on.
}

/////////////////////////////////////////////////////////////////////////////////////
	
FUNCTION ff_Tolerance {
//Calculates if within tolerance and returns true or false
	PARAMETER a. //current value
	PARAMETER b.  /// Setpoint
	PARAMETER tol.

	RETURN (a - tol < b) AND (a + tol > b).
}


FUNCTION ff_COMMS {
	PARAMETER stagewait IS 0.1.

	IF SHIP:Q < 0.0045 {
		FOR antenna IN SHIP:MODULESNAMED("ModuleRTAntenna") {
			IF antenna:HASEVENT("activate") {
				antenna:DOEVENT("activate").
				PRINT "Activate Antennas".
				WAIT stageWait.
			}	
		}.
	}
} // End of Function

///////////////////////////////////////////////////////////////////////////////////	
//Credit https://github.com/KSP-KOS/KOS/issues/1522

function ff_R_chutes_seq {

	set lp to ship:partstagged("DrogueChute").
	set drogues to list().
	Set i to 0.
	until i>=lp:length{
		drogues:add(lp[i]:getmodule("moduleparachute")). //drogue chutes
		set i to i+1.
	}
	set lp to ship:partstagged("MainChute").
	set mainchutes to list().
	set i to 0.
	until i>=lp:length{
		mainchutes:add(lp[i]:getmodule("moduleparachute")). //main chutes
		set i to i+1.
	}
	set lestimestamp to time:seconds.
	When ((time:seconds>lestimestamp+2)and(alt:radar<6000)) then{
		print "drogues armed".
		when drogues[0]:getfield("safe to deploy?")="safe" then {
			set i to 0.
			until i>=drogues:length {
				if drogues[i]:hasevent("deploy chute") {
					drogues[i]:doevent("deploy chute").
				} 
				set i to i+1.
			}
		}
	}
	print "drogues deployed".
	set lestimestamp to time:seconds.
	When ((time:seconds>lestimestamp+0.5)and(alt:radar<2000)) then {
		print "main chutes armed".
		when mainchutes[0]:getfield("safe to deploy?")="safe" then {
			set i to 0.
			until i>=mainchutes:length {
				if mainchutes[i]:hasevent("deploy chute") {
					mainchutes[i]:doevent("deploy chute").
				}
				set i to i+1.
			}
		}
	}
	print "main chutes deployed".
	
}// End Function

function ff_R_chutes {
parameter event.

	//["R_chutes"]("arm parachute").
	//["R_chutes"]("disarm parachute").
	//["R_chutes"]("deploy parachute").
	//["R_chutes"]("cut chute").
	for RealChute in ship:modulesNamed("RealChuteModule") {
		RealChute:doevent(event).
	}
}// End Function

///////////////////////////////////////////////////////////////////////////////////

function ff_Gravity{
	Parameter Surface_Elevation is gl_surfaceElevation.
	Set SEALEVELGRAVITY to body:mu / (body:radius)^2. // returns the sealevel gravity for any body that is being orbited.
	Set GRAVITY to body:mu / (ship:Altitude + body:radius)^2. //returns the current gravity experienced by the vessel	
	Set AvgGravity to sqrt(		(	(GRAVITY^2) +((body:mu / (Surface_Elevation + body:radius)^2 )^2)		)/2		).// using Root mean square function to find the average gravity between the current point and the surface which have a squares relationship.

	local arr is lexicon().
	arr:add ("SLG", SEALEVELGRAVITY).
	arr:add ("G", GRAVITY).
	arr:add ("AVG", AvgGravity).
	
	Return (arr).
}
///////////////////////////////////////////////////////////////////
// credit https://gist.github.com/darkbushido/e8197aff208491c9739bd37350606ae0	


function ff_collect_science {
	local SL to lex(). 
	local SMS to lex().
    local DMMS to list("ModuleScienceExperiment", "DMModuleScienceAnimate", "DMBathymetry").
    
	for module_name in DMMS {
		for SM in SHIP:ModulesNamed(module_name) {
			local SP to SM:PART.
			if NOT SMS:HASKEY(SP:NAME) {
				if hf_highlight_part(SP, SM) {
					SMS:ADD(SP:NAME, LIST(SM)).
				}
			} else if SMS:HASKEY(SP:NAME) AND NOT SMS[SP:NAME]:CONTAINS(SP) {
				if hf_highlight_part(SP, SM) {
					SMS[SP:NAME]:ADD(SM).
				}
			}
		}
	}
    for SM_name in SMS:KEYS {
		print "Collecting Science From: "+SM_name.
		if  SM_name = "dmUSPresTemp" {
			for SM in SMS[SM_name] { 
				hf_do_science(SM). 
			}
		}
		else { 
			SET SM to SMS[SM_name][0]. 
			hf_do_science(SM).
		}
    }
    wait 0.5.
    hf_transfer_science().
    wait 0.5.
}
  
function hf_highlight_part {
    parameter SP, SM.
    if not SM:HASDATA and not SM:INOPERABLE { 
		HIGHLIGHT(SP, BLUE). return true. 
	}
    else if SM:HASDATA { 
		HIGHLIGHT(SP, GREEN). 
	}
    else { 
		HIGHLIGHT(SP, YELLOW). 
		return false. 
	}
} 
  
function hf_do_science {
    parameter SM.
    if not SM:HASDATA and not SM:INOPERABLE {
		local t to time:seconds.
		HIGHLIGHT(SM:PART, RED). SM:DEPLOY.
		until (SM:HASDATA or (time:seconds > t+10)) {
			print ".". wait 1.
		}
	}
}
  
function hf_transfer_science {
    for sc in ship:modulesnamed("ModuleScienceContainer") {
		print "Transfering Science".
		sc:doaction("collect all", true).
		wait 0.
    }
}
	
	
	
// function ff_Science
// {
  // parameter one_use IS TRUE, overwrite IS FALSE.
	// local exp_list is LIST().
	// SET exp_list to SHIP:MODULESNAMED("ModuleScienceExperiment").
	// FOR exp IN exp_list { 
	
		// IF NOT exp:INOPERABLE AND (exp:RERUNNABLE OR one_use) {
			// IF exp:DEPLOYED AND overwrite { 
				// resetMod(exp). 
			// }
			// IF NOT exp:DEPLOYED {   
				// exp:DEPLOY().
				// WAIT UNTIL exp:HASDATA. 
			// }
		// }
	// }
// }	//end function
	
/////////////////////////////////////////////////////////////////////////////////////
//Export list of functions that can be called externally for the mission file	to use
/////////////////////////////////////////////////////////////////////////////////////
	
    export(Util_Vessel).
} // End of anon
