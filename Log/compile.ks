Print "Compiling".
Set compile_Lex to lexicon().

IF NOT EXISTS ("0:/LOG/compileLog.ks"){ // ensure the compile log exisits before writing to it
	log " " to "0:/LOG/compileLog.ks".
}
runpath ("0:/LOG/compileLog.ks").
//SET CONTENTS TO OPEN("0:/LOG/compilelog.ks"):READALL:STRING.

//list files in fileList.
Set fileList to open("0:/Library/"):List(). // creates a lexicon list of all files in the library directory
File_List_compile("0:/Library/").
Set fileList to open("0:/Missions/"):List(). // creates a lexicon list of all files in the library directory
File_List_compile("0:/Missions/").
//Set fileList to open("0:/Boot/"):List(). // creates a lexicon list of all files in the library directory
//File_List_compile("0:/Boot/").
Print "Filelists created".

Function File_List_compile{	
Parameter path.
	for f in fileList:values{
		//if f:isfile{ //ignores folders as these will throw an error on the extension call
			if f:extension = "ks" and not filelist:haskey(f:name + "m") { // a ks file with no  present in the archive, compile and add to the lexicon
				Compile path + f:name.
				compile_Lex:add(f:name, f:Size).
				Print "Compiled new file: " + f:name.
			} Else if f:extension = "ks" and not compile_lex:haskey(f:name) { // a ks file with no ksm file in the lexicon, compile and add to the lexicon
				Compile path + f:name.
				compile_Lex:add(f:name, f:Size).
				Print "Compiled new file: " + f:name.
			} Else if f:extension = "ks" and compile_lex:haskey(f:name){ // if ks file with a ksm file in the lexicon file.
				if compile_lex[f:name] <> f:Size { //if the size is not the same create a new compile file
					Compile path + f:name.
					Set compile_lex[f:name] to f:Size.
					Print "re-compiled existing file:" + f:name.
				}
			} 
		//}
	}
} // End function
Deletepath ("0:/LOG/compileLog.ks").

Set i to 0.0.
set keylist to compile_Lex:keys.
until i > compile_Lex:length-1{
	LOG "compile_Lex:add(" +char(34)+ keylist[i] +char(34)+ "," + compile_Lex[keylist[i]] + ")." to "0:/LOG/compileLog.ks".
	Set i to i+1.
}

