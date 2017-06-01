////////////////////////////////
//Generic Boot Script for all vessels
////////////////////////////////

//Boot Script Functions are:
//Handles moves between runModes by storing current runmode in Jason file
//Loading the KNU file which manages function calls from the mission file.
//Checking for and downloading new and updated mission file(s)
//Handling on screen notification messages

@LAZYGLOBAL OFF. //Turns off auto global call of parameters and prevents verbose errors where calling recursive functions

WAIT 5. //ensures all game physiscs have loaded
Lock THROTTLE TO 0. // ensures no active throttle unless specified later
// open up the KOS terminal

CORE:PART:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
SET TERMINAL:HEIGHT TO 65.
SET TERMINAL:WIDTH TO 35.
SET TERMINAL:BRIGHTNESS TO 0.8.
SET TERMINAL:CHARHEIGHT TO 8.
SET TERMINAL:CHARWIDTH TO 6.

/////////////////////////////////////////
// THE ACTUAL SHIP BOOTUP PROCESS
/////////////////////////////////////////
Print ("==BOOT FILE INITIALISATION==").
Local bootLast is TIME:SECONDS. // boot last is used to clear the cache to force a mission file recompile
Global runMode is 0.1.//boot file initialisation of runMode parameter which is used to call/select file functions
Global runModeBmk is 0.//boot file initialisation of runModeBmk parameter whic is used to call/select helper functions at the file function level only. (do not use this at the helper function level)
Global runModeNode is 0.//boot file initialisation of runModeNode parameter for the execution of a node within the Node_Calcs file level only. (File functions should skip to the correct node execution and this will skip to the active node)

////////////////////////////////////////////////////////////////////

// Recover bootLast from file or use default
if exists (BootLast.ks) {
	runpath (BootLast.ks).
	Print "BootLast set to: " + BootLast.
} 
else {
	gf_set_BootCache(TIME:SECONDS). // create the bootlast file
}
Print "BootLast Initial:" + BootLast. // debug of the current Bootlast time

If bootLast < TIME:SECONDS - 30{
	/// the CPU has not been rebooted for a while and likley needs to have the cache cleared
	Print "CPU Cache has not been cleared recently rebooting".
	gf_set_BootCache(TIME:SECONDS). // update the bootlast file with the current time.
	Wait 3.
	Reboot. // reboot the CPU to clear the cache and force the CPU to recompile the Mission file.
} 

////////////////////////////////////////////////////////////////////

// Recover runmode from file or use default
if exists (state.ks) {
	runpath (state.ks).

} 
else {
	gf_set_runmode(0.1). // ensure a new state file is created
}

////////////////////////////////////////////////////////////////////

ON AG10 {
	SET runMode to -1. //Stop CPU RunMode
} //End program

////////////////////////////////////////////////////////////////////

//Mission Files set up
Print "Getting Missions Names".
LOCAL newMission TO SHIP:NAME + ".mission.ks".
LOCAL newUpdate TO SHIP:NAME + ".update.ks".
  
// Check connection and ensure a mission file and Knu file is present in the first boot up.
IF ADDONS:RT:HASCONNECTION(SHIP) or ADDONS:RT:HASLOCALCONTROL(SHIP) {  //See if there is a connection
	Print ("==INITIALISATION FILE CHECKS==").
	Print ("Checking for knu file").
	If not exists (knu.ks){
		gf_DOWNLOAD ("0:/Library/","knu.ks","knu.ks").
	}
	Print ("Checking for mission file").
	gf_checkUpdate().
	If not exists (Mission.ks) {
		gf_Download("0:/Missions/",newMission,"Mission.KS").
	}
}

//Ensure Knu and mission file loaded, especially after a reboot
RUNONCEPATH (knu.ks).
RUNONCEPATH (Mission.ks).


Local bootTime To TIME:SECONDS.
Print "Intial Runmode: " + Runmode.
Print "Intial runModeBmk: " + runModeBmk.
Print "Initial runModeNode: " + runModeNode.

Print ("==COMMENCING RUNMODE LOOP==").
// the next loop continuously checks for updates inbetween runmodes and also initiates the mission file
until runMode = -1 {
	//Print ("Run mode boot loop").
    //if a mission file exisits run it
	If exists (mission.ks){
		Print "Mission Exists, Starting runmode".
		runModes(). // run the runmodes function in the mission file
		Print "Runmode: " + Runmode.
		Print "runModeBmk: " + runModeBmk.
		Print "runModeNode: " + runModeNode.
	}
	// in between run modes check for a mission update
	If TIME:SECONDS - bootTime > 10{
		Print "Checking For Mission Update".
		gf_checkUpdate().
		wait 0.2.
		Set bootTime to TIME:SECONDS.
	}
	//Print ("Run modes in boot loop").
	If runMode = 0{
		Print "Entering Hibernation mode".
		Unlock All. //Need to determine if this is a good idea as you will need to reset any lock values
		Wait 300. //if runmode is zero enter hibernation mode and only check in every 5 minute to conserve power
	}
    wait 0.001.
}

////////////////////////////////////////////////////////////////////
//GLOBAL FUNCTIONS
////////////////////////////////////////////////////////////////////

// Persist runmode to disk
function gf_set_runmode { // use quotations if you want to use string runmode names
parameter mode.
	if exists (State.ks){ 
		//ensures there is something to delete if no state has been set.
		Deletepath (State.ks).
	}
	Log "Set runmode to " + mode + "." to state.ks.
	set runmode to mode.
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
				gf_UPDATEQ("0:/updateQ/", newUpdate, "mission.ks").
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
              Print "New File Downloaded".
         } //End of Else
    } // End of if filepath + name     
   ELSE { 
		Print "Download file not found".
   } //End of Else
} //End of Function Download
 
//////////////////////////////////////////////////////
 
// function gf_PrintDisplay {
    // clearscreen.
    // print "===OVERALL STATUS===".
	// //Print "   Runmode:    " + round(ship:velocity:surface:mag).
	
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
  