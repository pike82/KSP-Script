
{// anon Function keeps all variables and functions used within here preventing them from being global unless stated as global

//The KNU Kerbal Not Unix format (see ep 34 vi on youtube for details). 
//This is designed to pass function values into libraries and retrive the results since functions cannont be called from otherfunctions past a certian level

	local s is stack().
	local d is lex().
	
	global import is{ // used to check if the file is on the local library drive and also to temporarily store and run it as the current file in use as a lexicon.
		parameter n.
		Print "Importing " + n.
		s:push(n). //appends a message to the stack
		//if exists("1:/"+n) deletepath("1:/"+n). //Ensures the newest version is uploaded.
		copypath("0:/library/"+n,"1:/"). // if the .ks file does not exist search the whole archive folder for it and copy it to the local drive
		runpath("1:/"+n).  //run the .ks file
		return d[n]. // adds the stack to lexicon d. which is returned to the requestor. This is obtained when the library exports the information and places it on this stack.
	}.
	
	global export is{ // export is used at the end of the individual library files to export a list of functions contained within the file which can be called up
		parameter v.
		set d[s:pop()] to v. //(pop() returns and removes the oldest message in the queue from lexicon d). this store the output on the stack so the return part of the import file can passs it onto the requestor.
	}.

}// End of anon
