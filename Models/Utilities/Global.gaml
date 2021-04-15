/**
* Name: Global
* Global data. 
* Author: Jean-François Erdelyi 
* Tags: 
*/

model Global

/** 
 * General data
 */
global {
	/**
	 * Computation data
	 */
	 
	// First date
	date first_date <- date([1970, 1, 1, 0, 0, 0]) const: true;
	 
	// Now
	date now function: (first_date + (machine_time / 1000) + 3600);

	// Starting system date	
	date system_starting_date <- now const: true;
	date system_stop_date;

	// Simulation date
	date simulation_date update: starting_date + time;
	
	// If true, use simplified shapes
	bool simple_drawing <- false;
	
	// Inflow
	float inflow <- 2000.0;
	
	// Main outflow
	float main_outflow <- 0.8 min: 0.0 max: 1.0;
	
	// Hybridation rate
	float hybridation_rate <- 0.0 min: 0.0 max: 1.0;
	
	// If true use random seed
	bool random_seed <- true;
	
}
