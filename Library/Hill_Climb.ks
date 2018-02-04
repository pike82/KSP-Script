

//Credits: All script and ideas are all from the following with a couple of modifications to allow more refined seeking if required:
// http://youtube.com/gisikw

///////////////////////////////////////////////////////////////////////////////////
///// List of functions that can be called externally
///////////////////////////////////////////////////////////////////////////////////

    // local Hill_Climb is lex(
		// "freeze", ff_freeze@,
		// "seek", ff_seek@,
		// "seek_low" , ff_seek_low@,
		// "seek_verylow" , ff_seek_verylow@,
		// "optimize", ff_optimize@
    // ).

////////////////////////////////////////////////////////////////
//File Functions
////////////////////////////////////////////////////////////////	  
	  
// Creates a lexicon of parameters which are stored and fixed for each evaluation as part of the evaluation and are therefore "frozen"
  function ff_freeze {
	parameter n. 
	return lex("frozen", n).
  }/// End Function


///////////////////////////////////////////////////////////////////////////////////		
	  
  function ff_seek {
	parameter t, r, n, p, fitness, fine is False,
			  data is list(t, r, n, p),
			  fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
	set data to ff_optimize(data, fit, 100). // search in 100m/s incriments
	set data to ff_optimize(data, fit, 10). // search in 10m/s incriments
	set data to ff_optimize(data, fit, 1). // search in 1m/s incriments
	set data to ff_optimize(data, fit, 0.1). // search in 0.1m/s incriments
	If Fine{
		set data to ff_optimize(data, fit, 0.01). // search in 0.01m/s incriments
	}
	fit(data). //sets the final manuver node and returns its parameters
	wait 0. 
	return data. // returns the manevour node parameters to where the function was called
  }/// End Function

///////////////////////////////////////////////////////////////////////////////////		  
 
  function ff_seek_low {
	parameter t, r, n, p, fitness, fine is False,
			  data is list(t, r, n, p),
			  fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
	set data to ff_optimize(data, fit, 10). // search in 10m/s incriments
	set data to ff_optimize(data, fit, 1). // search in 1m/s incriments
	set data to ff_optimize(data, fit, 0.1). // search in 0.1m/s incriments
	fit(data). //sets the final manuver node and returns its parameters
	If Fine{
		set data to ff_optimize(data, fit, 0.01). // search in 0.01m/s incriments
	}
	wait 0. 
	return data. // returns the manevour node parameters to where the function was called
  }/// End Function
  
  
  ///////////////////////////////////////////////////////////////////////////////////		  
 
  function ff_seek_verylow {
	parameter t, r, n, p, fitness, fine is False,
			  data is list(t, r, n, p),
			  fit is hf_orbit_fitness(fitness@).  // time, radial, normal, prograde, fitness are the parameters passed in for the node to be found. passes fitness through as a delegate to orbital fitness in this case { parameter mnv. return -mnv:orbit:eccentricity. } is passed through as a local function but any scorring evaluation can be passed through
	set data to ff_optimize(data, fit, 1). // search in 1m/s incriments
	set data to ff_optimize(data, fit, 0.1). // search in 0.1m/s incriments
	set data to ff_optimize(data, fit, 0.01). // search in 0.01m/s incriments
	fit(data). //sets the final manuver node and returns its parameters
	If Fine{
		set data to ff_optimize(data, fit, 0.001). // search in 0.01m/s incriments
	}
	wait 0. 
	return data. // returns the manevour node parameters to where the function was called
  }/// End Function

///////////////////////////////////////////////////////////////////////////////////		 
	 
  function ff_optimize {
	parameter data, fitness, step_size,
	winning is list(fitness(data), data),
	improvement is hf_best_neighbor(winning, fitness, step_size). // collect current node info, the parameter to evaluate, and the incriment size(note: there was a comma here not a full stop if something goes wrong)// a list of the fitness score and the data, sets the first winning node to the original data passed through(note: there was a comma here not a full stop if something goes wrong)// calculates the first improvement node to make it through the until loop
	until improvement[0] <= winning[0] { // this loops until the imporvment fitness score is lower than the current winning value fitness score (top of the hill is reached)
	  set winning to improvement. // sets the winning node to the improvement node just found
	  set improvement to hf_best_neighbor(winning, fitness, step_size). // runs the best neighbour function to find a better node using the current node that is winning
	}
	return winning[1]. // returns the second column of the winning list "(data)", instead of "fitness(data)"
  }/// End Function

	  
////////////////////////////////////////////////////////////////
//Helper Functions
////////////////////////////////////////////////////////////////  
	  
	 // Returns paramters from the frozen lexicon
	function hf_unfreeze {
		parameter v. 
		if hf_frozen(v) return v["frozen"]. 
		else return v.
	}/// End Function
	
///////////////////////////////////////////////////////////////////////////////////		
	
	// identifies if the paramter is frozen
	function hf_frozen {
		parameter v. 
		return (v+""):indexof("frozen") <> -1.
	}/// End Function
	
///////////////////////////////////////////////////////////////////////////////////		  
 
	  
	function hf_orbit_fitness {
		parameter fitness. // the parameter used to evaluate fitness
		return {
			parameter data.
			until not hasnode { 
				remove nextnode. // Used to remove any existing nodes
				wait 0. 
			} 
		  local new_node is node(
			hf_unfreeze(data[0]), hf_unfreeze(data[1]),
			hf_unfreeze(data[2]), hf_unfreeze(data[3])). //Collects Node parameters from the Frozen Lexicon, presented in time, radial, normal, prograde.
		  add new_node. // produces new node in the game
		  wait 0.
		  return fitness(new_node). // returns the manevour node parameters to where the function was called
		}.
	}/// End Function
	
	
///////////////////////////////////////////////////////////////////////////////////		  
	  	  
	function hf_best_neighbor {
		parameter best, fitness, step_size. // best is the winning list and contains two coloumns
		for neighbor in hf_neighbors(best[1], step_size) { //send to neighbours function the node information and the step size to retune a list of the neighbours
		  local score is fitness(neighbor). // Set up for the score to analyse what is returned by neigbour. This is what finds the fitness score by looking at the mnv node orbit eccentricity that was passed through as delegate into fitness
		  if score > best[0] set best to list(score, neighbor). //if the eccentricity score of the neighbour is better save the mnv result to best
		}
		return best. //return the best result of all the neighbours
	}/// End Function

	
///////////////////////////////////////////////////////////////////////////////////		  
	  
	  function hf_neighbors {
		parameter data, step_size, results is list().
		for i in range(0, data:length) if not hf_frozen(data[i]) { // for each of the data points sent through check if the data is frozen (i.e. is a value that should not be changed). 
		  local increment is data:copy.
		  local decrement is data:copy.
		  set increment[i] to increment[i] + step_size. //for each of the data points allowed to be changed increment up by the step size
		  set decrement[i] to decrement[i] - step_size. //for each of the data points allowed to be changed increment up by the step size
		  results:add(increment).
		  results:add(decrement).
		}
		return results. // Return the list of neighbours for the data that can be changed (i.e. unfrozen)
	  }  /// End Function	  
	  




