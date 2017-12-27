////////////////////////////////
//Generic Boot Script for all vessels
////////////////////////////////

//Boot Script Functions are:
//Handles moves between runModes by storing current runmode in Jason file
//Loading the KNU file which manages function calls from the mission file.
//Checking for and downloading new and updated mission file(s)
//Handling on screen notification messages

//@LAZYGLOBAL OFF. //Turns off auto global call of parameters and prevents verbose errors where calling recursive functions

WAIT 5. //ensures all game physiscs have loaded
gf_stopWarp(). //ensure there is no warping occuring
gf_killthrottle(). // ensures no active throttle unless specified later

// open up the KOS terminal

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 55.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 10.

/////////////////////////////////////////
// THE ACTUAL SHIP BOOTUP PROCESS
/////////////////////////////////////////
Print ("==BOOT FILE INITIALISATION==").
Local bootLast is TIME:SECONDS. // boot last is used to clear the cache to force a mission file recompile
Global runMode is Lexicon().//boot file initialisation of runMode parameter which is used to call/select file functions
runMode:add("runMode", 0.1).

Global gV_log_file is "0:/log/" + gf_txtSpace_Rep(SHIP:NAME) + ".txt".
gf_PrintLog(SHIP:NAME).

////////////////////////////////////////////////////////////////////

// Recover bootLast from file or use default
if exists (BootLast.ks) {
	runpath (BootLast.ks).
	Print "BootLast time exists and set to: " + BootLast.
} 
else {
	gf_set_BootCache(TIME:SECONDS). // create the bootlast file
	Print "BootLast time created and set to:" + BootLast.
}


If bootLast < TIME:SECONDS - 30{
	/// the CPU has not been rebooted for a while and likley needs to have the cache cleared
	Print "CPU Cache has not been cleared recently rebooting".
	gf_set_BootCache(TIME:SECONDS). // update the bootlast file with the current time.
	Wait 3.
	Reboot. // reboot the CPU to clear the cache and force the CPU to recompile the Mission file.
} 

////////////////////////////////////////////////////////////////////

//Determine if want to use ks or ksm files
Switch to 0.
Set ext to ".ksm".
if ext = ".ksm"{
	runpath ("0:/Log/Compile.ks").
}
Switch to 1.

// Recover runmode from file or use default
if exists (state.ks) {
	runpath (state.ks).

} 
else {
	gf_set_runmode("runMode", 0.1). // ensure a new state file is created
}

////////////////////////////////////////////////////////////////////

ON AG10 {
	SET runMode["runMode"] to -1. //Stop CPU RunMode
} //End program

////////////////////////////////////////////////////////////////////

//Mission Files set up
Print "Getting Missions Names".
LOCAL newMission TO SHIP:NAME + ".mission"+ ext.
LOCAL newUpdate TO SHIP:NAME + ".update"+ ext.
  
// Check connection and ensure a mission file and Knu file is present in the first boot up.
IF ADDONS:RT:HASCONNECTION(SHIP) or ADDONS:RT:HASLOCALCONTROL(SHIP) or ADDONS:AVAILABLE("RT")=False {  //See if there is a connection
	Print ("==INITIALISATION FILE CHECKS==").
	Print ("Checking for knu file").
	If not exists ("knu" + ext){
		gf_DOWNLOAD ("0:/Library/","knu"+ ext,"knu"+ ext).
	}
	Print ("Checking for mission file").
	gf_checkUpdate().
	If not exists ("Mission"+ ext) {
		gf_Download("0:/Missions/",newMission,"Mission"+ ext).
	}
}

//Ensure Knu and mission file loaded, especially after a reboot
RUNONCEPATH ("1:/knu"+ ext).
RUNONCEPATH ("1:/Mission"+ ext).


Local bootTime To TIME:SECONDS.
Print "Intial Runmode: " + Runmode:Values.

Print ("==COMMENCING RUNMODE LOOP==").
// the next loop continuously checks for updates inbetween runmodes and also initiates the mission file
until runMode["runMode"] = -1 {
	//Print ("Run mode boot loop").
    //if a mission file exisits run it
	If exists ("mission"+ ext){
		Print "Mission Exists, Starting runmode".
		Mission_runModes(). // run the mission runmodes function in the mission file
		Print "Runmode: " + Runmode:Values.
	}
	// in between run modes check for a mission update
	If TIME:SECONDS - bootTime > 10{
		Print "Checking For Mission Update".
		gf_checkUpdate().
		Print "CPU Space Capacity: " + core:currentvolume:Capacity.
		Print "Free CPU Space: " + core:currentvolume:FreeSpace.
		Print "CPU Power Drain: " + core:currentvolume:Powerrequirement.
		wait 0.01.
		Set bootTime to TIME:SECONDS.
	}
	//Print ("Run modes in boot loop").
	If runMode["Runmode"] = 0{
		Print "Entering Hibernation mode".
		Unlock All. //Need to determine if this is a good idea as you will need to reset any locked values
		Wait 300. //if runmode is zero enter hibernation mode and only check in every 5 minute to conserve power
	}
    wait 0.001.
}

////////////////////////////////////////////////////////////////////
//GLOBAL FUNCTIONS
////////////////////////////////////////////////////////////////////

// Persist runmode to disk
function gf_set_runmode { // use quotations if you want to use string runmode names
parameter key, mode.
	Log "Set runmode["+char(34)+ key +char(34)+"] to " + mode + "." to state.ks.
	set runmode[key] to mode.
	Print "Runmode " + key + " set to : " + runmode[key].
}

function gf_remove_runmode { // use quotations if you want to use string runmode names
parameter key.
	Log "runmode:remove("+ char(34)+ key + char(34)+")." to state.ks.
	runmode:Remove(key).
	Print "Runmode " + key + " Removed".
}

// Persist bootlast to disk
function gf_set_BootCache { // use quotations if you want to use string runmode names
parameter BootCache.
	If Exists (BootLast.ks){ //ensures there is something to delete if no state has been set.
		Deletepath (BootLast.ks).
	}
	Log "Set bootLast to " + BootCache + "." to BootLast.ks.
	set bootLast to BootCache.
}

// If we have a connection, see if there are new instructions. If so, download and run them.

Function gf_checkUpdate {
	IF ADDONS:RT:HASCONNECTION(SHIP) or ADDONS:RT:HASLOCALCONTROL(SHIP) {  //See if theconnection status has changed since being called
		  PRINT "Update Comms OK".
		//IF coreName CONTAINS ("launcher") {      // If a launcher Core exists
			//UPDATEQ("0:/launchers/", coreName + "launcher.ks", "launcher.ks").  //Try to upload the launcher file
			//RUN launcher.ks.
		 //} //End of Core name if statement
		//ELSE {
			IF EXISTS("0:/updateQ/" + newUpdate) {  //If a mission file exisits download and overwirte the current mission file
				PRINT "Update Exists, loading update".
				gf_UPDATEQ("0:/updateQ/", newUpdate, "mission"+ ext).
				wait 0.2.
				// Switch to 1.
				// RUNONCEPATH (mission.ks).
		 } //End of new mission if statement
		//} //End of Core ELSE statement
	} // End of Addons connection if statement
	Print "Finished update checks".
}// end function check update

//////////////////////////////////////////////////////

// Get a file from KSC UpdateQ folder (note: This deletes the file from the UpdateQ folder)
FUNCTION gf_UPDATEQ {
PARAMETER filePath, name, newName.
   
   PRINT (filePath+name).
   IF EXISTS (filePath+name) {
        PRINT ("1:/" + newName).
        IF EXISTS("1:/" + newName) {
            DELETEPATH ("1:/" + newName). // allows mission files to be overwritten
			Print "Deleting existing file".
        }
        COPYPATH (filePath+name, "1:/" + newName). // creates new file with file name on local volume
		DELETEPATH (filePath+name). // Removes file from KSC so it is no longer Q'd
		RUNPATH (newName). //Runs new file downloaded
		Print("Update Completed").
    } // End of if filepath + name     
   ELSE { 
		Print "Update file not found".
   } //End of Else
} //End of Function UpdateQ

//////////////////////////////////////////////////////

// Get a file from KSC
FUNCTION gf_DOWNLOAD {
PARAMETER filePath, name, newName.
   
   Print ("Download of " + name + " Commencing").
   PRINT (filePath+name).
   IF EXISTS (filePath+name) {
        PRINT ("1:/" + newName).
        IF EXISTS("1:/" + newName) {
            DELETEPATH ("1:/" + newName). // if name existis allow file to be overwritten
        }
        ELSE  {
            COPYPATH (filePath+name, "1:/" + newName). // creates new file with file name on local volume
            RUNPATH (newName). //Runs new file downloaded
            Print "New File "+ newName +" Downloaded".
			Print "CPU Space Capacity: " + core:currentvolume:Capacity.
			Print "Free CPU Space: " + core:currentvolume:FreeSpace.
			Print "CPU Power Drain: " + core:currentvolume:Powerrequirement.
        } //End of Else
    } // End of if filepath + name     
   ELSE { 
		Print "Download file not found".
   } //End of Else
} //End of Function Download
 
//////////////////////////////////////////////////////
 
 FUNCTION gf_stopWarp
{
  KUNIVERSE:TIMEWARP:CANCELWARP().
  WAIT UNTIL SHIP:UNPACKED.
}
 
 //////////////////////////////////////////////////////
 
 FUNCTION gf_killthrottle
{
  LOCK THROTTLE TO 0.
  SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
}
 
 //////////////////////////////////////////////////////
 
 FUNCTION gf_txtSpace_Rep // used to insert an underscore into a file name instead of a space
{
  PARAMETER txt, l is 0, s is "_".
  RETURN (""+txt):PADLEFT(l):REPLACE(" ",s).
}

 ////////////////////////////////////////////////////// 
 
 FUNCTION gf_PrintLog
{
  PARAMETER txt, timForm is true.
  
	IF timForm { 
		SET txt TO gf_formatMET() + " " + txt. 
	}
  
	IF gV_log_file <> "" { 
		LOG txt TO gV_log_file. 
	}
}

FUNCTION gf_formatMET
{
  LOCAL m_time is Round(MISSIONTIME).
    return gf_formatTS(TIME:SECONDS - m_time).
}

FUNCTION gf_formatTS
{
  PARAMETER u_time1, u_time2 IS TIME:SECONDS.
  LOCAL ts is (TIME - TIME:SECONDS) + ABS(u_time1 - u_time2).
  RETURN "[T+" + gf_txtSpace_Rep(ts:YEAR - 1, 2,"0") + " " + gf_txtSpace_Rep(ts:DAY - 1, 3,"0") + " " + ts:CLOCK + "]".
}

 ////////////////////////////////////////////////////// 
 
 // Initialisation of global variables for the graphical user interface display
 // Global gv_gui_Status is 0.
 // Global gv_gui_Runmode is 0.
 // Global gv_gui_RunmodeLoopName is 0.
 // Global gv_gui_DisplayInfo is lexicon().
 // Global gv_gui_OtherInfo is 0. 
// function gf_PrintDisplay {
    // clearscreen.
    // print "===OVERALL STATUS===".
	// //Print "   Runmode:    " + runmode.
	
	// print "===LANDING STATUS===".
    // //PRINT "VELOCITY".
    // //print "   surface:    " + round(ship:velocity:surface:mag).
    // //print "   vertical:   " + round(vVel).
    // //print "   horizontal: " + round(hVel:mag).
    // print "ACCELERATION".
    // //print "   target:     " + round(targetAccel, 3).
    // //print "   max:        " + round(maxAccel, 3).
    // //print "   vertical:   " + round(vAccel, 3).
    // //print "   horizontal: " + round(hAccel, 3).
    // //print "   local g:    " + round(localg, 3).
    // print "OTHER".
    // print "   radar:      " + round(height, 3).
    // print "   tset:       " + round(tset, 5).
    // print "   tmp1:       " + round(tmp1, 5).
    // print "   tmp2:       " + round(tmp2, 5).
    // //print "   impact eta: " + round(impactEta, 2).
    // //print "   free eta:   " + round(freeImpactEta, 2).
    // print "   burntime:   " + round(burntime, 5).
    // print "   burneta:    " + round(burnEta, 5).
    // //print "   steer error:" + round(steeringmanager:angleerror, 5).
    // print "STAT LINE:".
    // print "   " + statline.
    // print "====================".
// }

// function gf_SetStatLine {
// parameter str.
    // set statline to str.
    // verbose(str).
// }
  