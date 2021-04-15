/**
* Name: World
* Entry point of the simulation.
* Author: Jean-François Erdelyi 
* Tags: 
*/
model MABS2021

import "Utilities/Global.gaml"
import "Utilities/EventManager.gaml"
import "Utilities/Logger.gaml"
import "Species/Crossroad.gaml"
import "Species/Road.gaml"
import "Species/Car.gaml"

/** 
 * Setup the world
 */
global {
	/**
	 * Global param
	 */

	// Starting date
	date starting_date <- date([1970, 1, 1, 0, 0, 0]);

	// Time stepƒ
	float step <- 0.1 #s;

	// Random seed
	float seed <- random_seed ? seed: 42.42;

	// Cars generator rate
	int generate_frequency <- 1; 

	/**
	 * Shapefiles
	 */

	// Dataset path	
	string dataset_path <- "../includes/";

	// Get road shape
	shape_file shape_roads <- shape_file(dataset_path + "roads.shp");

	// Get node shape
	shape_file shape_nodes <- shape_file(dataset_path + "crossroads.shp");

	// Get boundary shape
	shape_file shape_boundary <- shape_file(dataset_path + "boundary.shp");

	/**
	 * Geometry and network
	 */

	// World shape
	geometry shape <- envelope(shape_boundary);

	// Road graph
	graph full_network;

	// Graph optimizer
	string optimizer_type <- "NBAStar" among: ["NBAStar", "NBAStarApprox", "Dijkstra", "AStar", "BellmannFord", "FloydWarshall"];

	// Memorize shortest path
	bool memorize_shortest_paths <- true;
	
	// List of generator roads IN
	list<Road> in_roads;
	
	// List of generator roads OUT
	list<Road> out_roads;
	
	// Main out
	Road main_out;
	
	/**
	 * Reflex
	 */

	// Car generator
	reflex generate when: (cycle mod generate_frequency) = 0 {
		// Pick start road
		Road in <- one_of(in_roads);

		float out_selection <- rnd(0.0, 1.0);

		// Pick end road
		Road out;
		if out_selection <= 0.2 {
			out <- one_of(out_roads);				
		} else {
			out <- main_out;
		}

		// If the road is accessible
		if in.start_node != out.end_node and in.start_node.get_accessibility(in, simulation_date) {
			do create_car(full_network, in, out);
		}	
		generate_frequency <- round((3600 * (1 / step)) / inflow);
	}
	
	// Use hybridation rate
	action use_hybridation_rate(list<Road> roads) {
		ask roads {
			do force_model(true);
		}
		
		int nb_meso <- round(length(roads) * hybridation_rate);
		if nb_meso = 0 {
			return;
		}
		loop i from: 0 to: nb_meso - 1 {
			Road current_road <- one_of(roads where (each.road_model = "micro"));
			ask current_road {
				do force_model(false);
			}
		}
		
	}

	/**
	 * Init
	 */

	// Init the model
	init {
		// Start date
		date start_date <- now;
		date step_date <- now;
		
		// Create logbook
		write "Create Logbook...";
		create Logger;
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
		
		// Create event manager
		write "Create EventManager...";
		create EventManager;
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;

		// Create crossroads
		write "Create Crossroad...";
		create Crossroad from: shape_nodes;
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;

		// Create roads
		write "Create Road...";
		create Road from: shape_roads {
			//do force_model(false);
		}
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
		
		// Clean graph
		write "Clean roads and crossroads...";
		ask Crossroad {
			do init();
		}
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
		
		// Create graph
		write "Create graph...";
		full_network <- as_driving_graph(Road, Crossroad);
		full_network <- full_network with_optimizer_type optimizer_type;
		full_network <- full_network use_cache memorize_shortest_paths;
		in_roads <- Road where (each.start_node.type = "generator");
		out_roads <- Road where (each.type != "motorway" and each.end_node.type = "exit");
		main_out <- (Road where (each.type = "motorway" and each.end_node.type = "exit"))[0];
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
		
		// Translate road
		write "Translate roads...";
		ask Road {
			do init();
		}
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
			
		// Add road
		write "Register roads...";
		list<Road> main_roads <- Road where (each.type = "motorway");
		ask main_roads {
			ask Logger[0] {
				do register_road(myself);
			}		
		}
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
		
		// Setup roads
		write "Setup hybridation roads...";
		do use_hybridation_rate(main_roads);
		write "-> " + step_date milliseconds_between now + "ms";
		step_date <- now;
				
		// Write init milliseconds
		write "Init took " + start_date milliseconds_between step_date + "ms";
	}

}

/**
 * Experiment
 */

// Main experiment
experiment "IDM Event Queue" type: gui {

	// Global
	parameter "Dataset path" var: dataset_path category: "General";
	parameter "Starting Date" var: starting_date category: "General";
	parameter "Step" var: step category: "General";
	parameter "Random seed" var: random_seed category: "General";
	parameter "Seed" var: seed category: "General";
	parameter "Main inflow" var: inflow category: "General";
	parameter "Main outflow" var: main_outflow category: "General";	
	parameter "Hybridation rate" var: hybridation_rate category: "General";
	parameter "Simple drawing" var: simple_drawing category: "General";

	// Car & road param
	parameter "Spacing" var: car_spacing category: "Car & Road";
	parameter "Car size" var: car_size category: "Car & Road";
	parameter "Speed limit < 0" var: car_speed_limit category: "Car & Road";
	parameter "Speed limit crossroad" var: car_speed_limit_leave category: "Car & Road";
	parameter "Density limit" var: road_jam_lim category: "Car & Road";
	
	// IDM param
	parameter "Mean acceleration" var: car_max_acceleration_mean category: "IDM";
	parameter "Mean break" var: car_max_break_mean category: "IDM";
	parameter "Mean reaction time" var: car_reaction_time_mean category: "IDM";
	parameter "Mean speed" var: car_max_speed_mean category: "IDM";
	
	parameter "Acceleration standard deviation" var: car_max_acceleration_standard_deviation category: "IDM";
	parameter "Break standard deviation" var: car_max_break_standard_deviation category: "IDM";
	parameter "Reaction time standard deviation" var: car_reaction_time_standard_deviation category: "IDM";
	parameter "Speed standard deviation" var: car_max_speed_standard_deviation category: "IDM";
	
	parameter "Delta (assumed always 4.0)" var: car_delta category: "IDM";
	parameter "Car Cn (best value is 0.4)" var: car_c_n category: "IDM";
	parameter "Human factor (best value is 1.0)" var: car_human_factor category: "IDM";
	parameter "Car espilon (depends on capability and jam distance)" var: car_epsilon category: "IDM";

	// Queue road param
	parameter "Vehicule per hour" var: road_vehicule_per_hour category: "Queue road";
	parameter "BPR alpha" var: road_alpha category: "Queue road";
	parameter "BPR beta" var: road_beta category: "Queue road";
	parameter "BPR gamma" var: road_gamma category: "Queue road";

	// Logbook param
	parameter "Logbook file path" var: logbook_file_path category: "Logbook";
	parameter "Logbook force write" var: logbook_write_data category: "Logbook";
	parameter "Logbook activated" var: logger_activated category: "Logbook";
	parameter "Logbook cyclic activated" var: logbook_cycle_activated category: "Logbook";
	parameter "Logbook cycle threshold" var: logbook_cycle_threshold category: "Logbook";
	parameter "Logbook flush" var: logbook_flush category: "Logbook";

	// Output
	output {
		display main_window type: opengl {
			species Road;
			species Crossroad;
			species Car;
		}

	}

}

// Batch exepriment
experiment 'Batch IDM Event Queue' type: batch repeat: 20 keep_seed: true until: ( cycle > 6000 ) {	
	// Global
	parameter "Random seed" var: random_seed category: "General" <- true;
	parameter "Main inflow" var: inflow category: "General" <- 2250.0; //among: [1500.0, 2000.0, 2400.0];
	parameter "Hybridation rate" var: hybridation_rate category: "General" min: 0.0 max: 1.0 step: 0.1;

	// Logbook param
	parameter "Logbook activated" var: logger_activated category: "Logbook" <- true;
	parameter "Logbook cyclic activated" var: logbook_cycle_activated category: "Logbook" <- true;
	parameter "Logbook cyclic threshold" var: logbook_cycle_threshold category: "Logbook" <- 6000;
}