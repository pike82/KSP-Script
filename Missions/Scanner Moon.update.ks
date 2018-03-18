Print ("Intilising other CPU's").

Print "Old Config:IPU Setting:" + Config:IPU.
Set Config:IPU to 1000.// this needs to be set based on the maximum number of processes happening at once, usually 500 is enought unless its going to be a very heavy script such as a suicide landing script which may require upto 1500
Print "New Config:IPU Setting:" + Config:IPU.
Set Config:Stat to false.

gf_set_runmode("runMode",0.1).

Function Mission_runModes{
		
	if runMode["runMode"] = 0.1 { 
		unlock all.
			gf_set_runmode("runMode",0).
	}	

} /// end of function runmodes
