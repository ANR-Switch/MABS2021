/**
* Name: Logger
* Log data.
* Author: Jean-François Erdelyi 
* Tags: 
*/
model MABS2021

import "../Species/Road.gaml"

/** 
 * General data
 */
global {
	/**
	 * Logbook param
	 */
	
	// File path
	string logbook_file_path <- "../Logs/";
	
	// Cycle threshold
	int logbook_cycle_threshold <- 10000;
	
	// If true, then write data
	bool logbook_write_data <- false;
	
	// If true, then write data	when the cycle is reached
	bool logbook_cycle_activated <- false;
	
	// If true, then flush buffer when logbook write data in the file 
	bool logbook_flush <- true;
	
	// If true, then log data
	bool logger_activated <- false;
}

/** 
 * Logger species
 */
species Logger skills: [logging] {
	/**
	 * Computation data
	 */

	// Path to log
	list<Road> roads;
	
	// Distance of path
	float path_length <- 0.0;
	
	// Last point
	point last_point;

	/**
	 * Reflex
	 */

	// Log data periodically
	reflex log_data when: logger_activated {
		// For each car
		loop road over: roads {
			if road.micro_model {
				loop car over: road.cars {
					float x <- path_length - car.compute_final_distance(last_point);
					
					do log_data(car.name, "location", string(time), string(x));
				}
				float k <- road.compute_k();
				float u <- road.compute_u();
			
				do log_data(road.name, "density", string(k), string(u));
			}
		}
	}
	
	// Write data when cycle threshold is reached
	reflex write_data when: logbook_cycle_activated and (cycle != 0) and ((cycle mod logbook_cycle_threshold) = 0) {
		do write_data(replace(world.name, ' ', '_') + "_i" + inflow + "_h" + hybridation_rate);
	}
	
	// Write data "manualy"
	reflex write_data_manualy when: logbook_write_data {
		logbook_write_data <- false;
		do write_data();
	}
	
	/**
	 * Action
	 */
	 
	// Log data manualy 
	action log_data (string data_name, string data_entry, string data_x, string data_y <- nil) {
		if logger_activated {
			if data_y = nil {
				do log_plot_1d section: data_name entry: data_entry x: data_x;
			} else {
				do log_plot_2d section: data_name entry: data_entry x: data_x y: data_y;			
			}
		}
	}
		
	// Log car
	action log_car(Road road, Car car, point start, float speed) {
		if logger_activated and road in roads {
			// Meso log init
			float x <- (path_length - (start distance_to last_point using topology(network))) with_precision 2;
			do log_data(car.name, "location", string(time), string(x));
			
			float k <- road.compute_k();
			float u <- speed;
			do log_data(road.name, "density", string(k), string(u));
		}
	}
	
	// Write data into file
	action write_data(string title <- (name + "_" + now)) {
		// General data
		do log_data("general", "average_duration", average_duration);
		do log_data("general", "total_duration", total_duration);
		
		// General param
		do log_data("param", "step", string(step));
		do log_data("param", "random_seed", string(random_seed));
		do log_data("param", "seed", string(seed));
		do log_data("param", "cycle", string(cycle));
		
		// Flow and hybridation
		do log_data("param", "inflow", string(inflow));
		do log_data("param", "main_outflow", string(main_outflow));
		do log_data("param", "hybridation_rate", string(hybridation_rate));
		
		// Car & road param
		do log_data("param", "car_spacing", string(car_spacing));
		do log_data("param", "car_size", string(car_size));
		do log_data("param", "road_jam_lim", string(road_jam_lim));
		
		// Meso road
		do log_data("param", "road_vehicule_per_hour", string(road_vehicule_per_hour));
		do log_data("param", "road_alpha", string(road_alpha));
		do log_data("param", "road_beta", string(road_beta));
		do log_data("param", "road_gamma", string(road_gamma));
		
		// IDM
		do log_data("param", "car_max_acceleration_mean", string(car_max_acceleration_mean));
		do log_data("param", "car_max_break_mean", string(car_max_break_mean));
		do log_data("param", "car_max_speed_mean", string(car_max_speed_mean));
		do log_data("param", "car_reaction_time_mean", string(car_reaction_time_mean));
		do log_data("param", "car_max_acceleration_standard_deviation", string(car_max_acceleration_standard_deviation));
		do log_data("param", "car_max_break_standard_deviation", string(car_max_break_standard_deviation));
		do log_data("param", "car_max_speed_standard_deviation", string(car_max_speed_standard_deviation));
		do log_data("param", "car_reaction_time_standard_deviation", string(car_reaction_time_standard_deviation));
		do log_data("param", "car_c_n", string(car_c_n));
		do log_data("param", "car_human_factor", string(car_human_factor));
		do log_data("param", "car_epsilon", string(car_epsilon));
		
		float current_path_length <- 0.0;
		loop road over: roads {
			current_path_length <- current_path_length + road.length;
			do log_data(road.name, "road_model", string(road.road_model));
			ask road {
				if is_jammed {
					jam_duration <- jam_duration + ((jam_start_date milliseconds_between simulation_date) / 1000.0);
				}	
			}
			do log_data(road.name, "jam_duration", string(road.jam_duration));			
			do log_data(road.name, "border", string(0.0), string(current_path_length));
			do log_data(road.name, "border", string(logbook_cycle_threshold * step), string(current_path_length));
		
		}
		do write file_name: (logbook_file_path + title + ".json") flush: logbook_flush;
	}
	
	// Add road
	action register_road(Road road) {
		add road to: roads;
		path_length <- path_length + road.length;
		last_point <- road.end;
	}
} 
