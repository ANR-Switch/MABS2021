/**
* Name: Car
* Car. 
* Author: Jean-François Erdelyi
* Tags: 
*/
model MABS2021

import "../Utilities/Logger.gaml"
import "../Utilities/Global.gaml"
import "Road.gaml"

/** 
 * General data
 */
global {
	/**
	 * IDM param
	 */

	// Maximum speed for a car
	float car_max_speed_mean <- 108 #km / #h;

	// Max acceleration
	float car_max_acceleration_mean <- (4.0 #m / (#s ^ 2));

	// Most sever break 
	float car_max_break_mean <- (3.0 #m / (#s ^ 2));

	// Reaction time
	float car_reaction_time_mean <- 1.5 #s;

	// Delta param
	float car_delta <- 4.0;
	
	/**
	 * Car param
	 */
	 
 	// Car length 
	float car_size <- 5.0 #m;

	// Spacing between two cars 
	float car_spacing <- 1.0 #m;

	/**
	 * Const
	 */

	// Car width
	float car_width <- 1.5 #m const: true;
	
	
	/**
	 * IDM advanced (not used in the paper)
	 */
	 
	// Max acceleration std dev
	float car_max_acceleration_standard_deviation <- 0.0; //(0.3 #m / (#s ^ 2));

	// Most sever break std dev
	float car_max_break_standard_deviation <- 0.0; //(0.9 #m / (#s ^ 2));

	// Reaction time  std dev
	float car_reaction_time_standard_deviation <- 0.0; //0.4 #s;

	// Reaction time std dev
	float car_max_speed_standard_deviation <- 0.0; //(3.0 #m / (#s ^ 1));

	// Cn factor (best value is 0.4)
	float car_c_n <- 0.0; // 0.4;

	// Human factor
	float car_human_factor <-  0.0 min: 0.0 max: 1.0; // 1.0;

	// Espilon value
	float car_epsilon <- 0.0;// min:(car_spacing / (sqrt(1 - (car_max_break_mean / car_max_acceleration_mean))));
	
	
	/**
	 * Optional (not used in the paper) 
	 */

	// Speed limit < 0
	bool car_speed_limit <- false;

	// If true the speed is set to 0.0 if the car can't cross the crossroad 
	bool car_speed_limit_leave <- false;


	/**
	 * Factory
	 */

	// Create a new car
	action create_car (graph car_graph, Road car_start_road, Road car_end_road) {
		// Create car
		create Car returns: values {
			// Set data
			network <- car_graph;
			start_location <- car_start_road.start;
			final_target <- car_end_road.end;

			// Join the road
			road_path <- queue<Road>(path_between(network, car_start_road.start, car_end_road.end).edges);
					
			// Pop first road
			do pop_next_road();
			if not empty(road.cars) {
				do compute_closest_and_leader();
				if closest = nil {
					speed <- get_max_freeflow_speed(road);
				} else {
					speed <- (closest as Car).speed;
				}

			} else {
				speed <- get_max_freeflow_speed(road);
			}

			ask road {
				do join(myself, simulation_date);
			}
			
			// Init meso road
			if not car_start_road.micro_model {
				// Meso log init
				ask Logger[0] {
					do log_car(myself.road, myself, myself.road.start, myself.speed);
				}
		
			}
			
			// Log origin destination
			ask Logger[0] {
				do log_data(myself.name, "origin-destination", car_start_road.name, car_end_road.name);
			}		

		}
		return values[0];

	}

}

/** 
 * Car species
 */
species Car skills: [moving] {

	/**
	 * Factory param
	 */

	// Roads network
	graph network;

	// Last road
	Road last_road <- nil;

	// Current road
	Road road;

	// Entry point
	point start_location;

	// Target
	point final_target;

	/**
	 * Drawing data
	 */

	// Default shape
	geometry default_shape <- rectangle(car_size, car_width);

	// Drawed shape
	geometry shape <- default_shape;

	/**
	 * Model computation data
	 */

	// Maximum speed for a car
	float max_speed_delta <- truncated_gauss(0.0, car_max_speed_standard_deviation);

	// Most sever break 
	float max_break <- truncated_gauss(car_max_break_mean, car_max_break_standard_deviation);

	// Max acceleration
	float max_acceleration <- truncated_gauss(car_max_acceleration_mean, car_max_acceleration_standard_deviation);

	// Reaction time
	float reaction_time <- truncated_gauss(car_reaction_time_mean, car_reaction_time_standard_deviation);

	// Current acceleration
	float acceleration min: -max_break; // max: car_max_acceleration;

	// Speed
	float speed min: (car_speed_limit ? 0.0 : -#infinity) #km / #h;

	// Desired speed 
	float desired_speed;

	// Delta speed between the current car and the leader
	float delta_speed;

	// Gap between the current car and the leader
	float actual_gap;

	// Desired minimum gap
	float desired_minimum_gap;
	
	/**
	 * Distance data
	 */

	// Target
	point target;

	// Distance to target
	float distance;

	// Is crossroad reachable
	bool reachable <- false;

	/**
	 * Speed and time data
	 */

	// Remaining speed
	float remaining_speed;

	// Freeflow travel time
	float free_flow_travel_time;

	// Freeflow travel time after BPR
	float travel_time;

	// computed speed
	float computed_speed <- 0.0;

	// Entry time
	date entry_time <- nil;

	/**
	 * Path and cars data
	 */

	// List of car in the path
	list<Car> cars;

	// Closest
	agent closest;

	// Path
	queue<Road> road_path <- [];

	/**
	 * Other computation data
	 */

	// If ture use micro model
	bool micro_model <- false;

	// If true is the leader
	bool is_leader;

	// Is registred
	bool is_registred <- false;

	/**
	 * Reflex
	 */

	// Reaction drive
	reflex compute_drive {
		if micro_model {
			// Get end crossroad
			Road next_road <- get_next_road();

			// Check if is the first car of this road
			reachable <- true;
			do get_closest_car();
			if first(road.cars) = self {
				float registry_factor <- (0.0098219 * (desired_speed * 3.6)^2) + (0.0703759 * (desired_speed * 3.6)) - 0.937986;
				if (self distance_to road.end using topology(network)) < registry_factor {
					reachable <- road.end_node.get_accessibility(next_road, simulation_date, self);
					if reachable {
						do compute_acceleration();
					} else {
						// Else "follow" the crossroad
						do compute_follower_acceleration(road.end, 0.0, 0.0);
					}

				} else {
					do compute_acceleration();
				}

			} else {
				do compute_acceleration();
			}

			// Goto and check target
			speed <- speed + (acceleration * step);
		}

		do one_step_goto(speed, simulation_date, reachable);
	}

	/**
	 * Action
	 */

	// Get next road
	Road get_next_road {
		if empty(road_path) {
			return nil;
		}

		return first(road_path);
	}

	// Pop next road
	action pop_next_road {
		last_road <- road;
		if empty(road_path) {
			road <- nil;
		} else {
			road <- pop(road_path);
		}

		return road;
	}

	// Get closest agent
	action compute_closest_and_leader {
		cars <- (get_cars(2) where (each != nil and not dead(each) and each != self and each.micro_model));
		closest <- (cars closest_to self) using topology(network);

		float registry_factor <- (0.0098219 * (desired_speed * 3.6)^2) + (0.0703759 * (desired_speed * 3.6)) - 0.937986;
		if closest != nil {
			if self distance_to closest using topology(network) > registry_factor {
				closest <- nil;
				is_leader <- true;
			} else {
				is_leader <- false;
			}

		} else {
			is_leader <- true;
		}

	}

	// Get closest car
	action get_closest_car {
		// If this is not the first car with no other car
		if not empty(first(road.cars)) and (first(road.cars) = self) and (get_next_road() = nil) {
			closest <- nil;
			is_leader <- true;
		} else {
			do compute_closest_and_leader();
		}
	}

	// Compute acceleration
	action compute_acceleration {
		if (is_leader or closest = nil) {
			do compute_leader_acceleration();
		} else {
			//do compute_follower_acceleration_standard(closest.location, (closest as Car).speed);
			do compute_follower_acceleration(closest.location, (closest as Car).speed, (closest as Car).acceleration);
		}

	}

	// Compute acceleration of leader
	action compute_leader_acceleration {
		// Compute acceleration
		acceleration <- max_acceleration * (1 - ((speed / desired_speed) ^ car_delta));
	}

	// Compute acceleration of followers
	action compute_follower_acceleration (point leader_location, float leader_speed, float leader_acceleration) {
		// Compute delta
		delta_speed <- leader_speed - speed;
		actual_gap <- (self distance_to leader_location using topology(network)) - car_size;

		// Compute minimum gap
		desired_minimum_gap <- car_spacing + (reaction_time * speed) + (car_c_n * ((speed ^ 2) / max_break)) - ((speed * delta_speed) / (2 * sqrt(max_acceleration * max_break)));

		// Compute acceleration
		float tmp_acceleration <- max_acceleration * (1 - ((speed / desired_speed) ^ car_delta) - ((desired_minimum_gap / (car_epsilon + actual_gap)) ^ 2));
		acceleration <- tmp_acceleration + (car_human_factor * leader_acceleration);
	}

	// One step goto
	action one_step_goto (float new_speed, date request_time, bool is_reachable_crossroad) {
		if micro_model {
			do goto on: network target: target speed: new_speed;
			do check_target(request_time, is_reachable_crossroad);
		} else {
			do one_step_goto_meso(speed);
		}

	}

	// One step goto
	action one_step_goto_meso (float new_speed) {
		if (closest != nil) and not dead(closest) and (closest as Car).road = road {
			float futur_gap <- (distance - (new_speed * step)) - (closest as Car).distance;
			if futur_gap > (car_size + car_spacing) {
				do goto on: network target: target speed: new_speed;
			}

		} else {
			float futur_gap <- (distance - (new_speed * step));
			if futur_gap < (car_size + car_spacing) {
				location <- target;
			} else {
				do goto on: network target: target speed: new_speed;
			}

		}

		distance <- (self distance_to target using topology(network));
	}

	// Check if the target is reached
	action check_target (date request_time, bool is_reachable_crossroad) {

		// Get the distance between the car and the target
		float registry_factor <- (0.0098219 * (desired_speed * 3.6)^2) + (0.0703759 * (desired_speed * 3.6)) - 0.937986; 
		distance <- self distance_to target using topology(network) with_precision 2;
		if not empty(road.cars) and first(road.cars) = self and not is_registred and not empty(road_path) and distance <= registry_factor {
			is_registred <- true;
			ask first(road_path) {
				do add_to_waiting_queue(myself);
			}

		}

		if distance <= 0.0 {
			// Leave road
			if not empty(road_path) and car_speed_limit_leave {
				//if is_reachable_crossroad {
				ask road {
					do leave(myself, request_time, is_reachable_crossroad);
				}
			} else {
				ask road {
					do leave(myself, request_time, is_reachable_crossroad);
				}

			}

		}

	}

	// Compute final distance
	float compute_final_distance(point log_end) {
		return self distance_to log_end using topology(network) with_precision 2;
	}

	// Init value in the new road
	action setup (date request_time) {

		// Set the road model
		micro_model <- road.micro_model;

		// Set location and target
		location <- road.start;
		target <- road.end;
		distance <- self distance_to target using topology(network) with_precision 2;

		// Set desired speed and theorical travel time
		desired_speed <- get_max_freeflow_speed(road);

		// Re init closest
		//if micro_model {
		// Get closest
		if not empty(road.cars) {
			closest <- last(road.cars);
		} else {
			closest <- nil;
		}

		is_leader <- (closest = nil);
		if micro_model {
			// *-Micro
			
			// Registred false
			is_registred <- false;
			desired_speed <- desired_speed + max_speed_delta;
			
			if last_road != nil and not last_road.micro_model {
				// Meso-Micro
	
				// Set speed
				if closest != nil {
					// Closest speed
					speed <- (closest as Car).speed;
				} else {
					// From computed speed (see tear_down action)
					speed <- computed_speed;
				}

			} else if last_road = nil and closest != nil {
				// Micro-Micro or Nil-Micro
				
				// Closest speed
				speed <- (closest as Car).speed;
			}
			speed <- min(speed, desired_speed);
		} else {
			// *-Meso
			
			// Entry time
			entry_time <- request_time;
			
			// Theorical travel time
			float delta_pos <- (remaining_speed * step);
			free_flow_travel_time <- ((road.length - delta_pos) / desired_speed);
			travel_time <- road.compute_travel_time(free_flow_travel_time);

			// Theorical speed
			speed <- ((road.length / travel_time) * 3.6) #km / #h;
		}
	}

	// Init value in the new road
	action tear_down (date request_time) {
		acceleration <- 0.0;
		if micro_model {
			remaining_speed <- speed - real_speed;
			computed_speed <- speed;
		} else {
			remaining_speed <- 0.0;
			float seconds <- milliseconds_between(entry_time, request_time) / 1000.0;
			computed_speed <- ((road.length / seconds) * 3.6) #km / #h;
			
			// Meso log OUT
			ask Logger[0] {
				do log_car(myself.road, myself, myself.road.end, myself.speed);
			}
			
		}

		do pop_next_road();
	}

	// Get list of cars 
	// The species Car as the the path to compute
	list<Car> get_cars (int nb_roads) {
		list<Car> tmp;
		if road != nil {
			tmp <- road.cars where (each.distance < distance);
		}

		int i <- 0;
		loop current_road over: road_path {
			if current_road.micro_model {
				add current_road.cars to: tmp all: true;
				i <- i + 1;
				if i >= nb_roads {
					break;
				}

			} else {
				break;
			}

		}

		return tmp;
	}
	
	// Get max freeflow speed
	float get_max_freeflow_speed (Road in_road) {
		return (min([car_max_speed_mean, in_road.max_speed]) * 3.6) #km / #h;
	}

	
	/**
	 * Aspect
	 */

	// Default aspect
	aspect default {
		shape <- default_shape rotated_by heading at_location location;
		if simple_drawing {
			draw circle(5) color: #grey;
		} else {
			float ratio;
			if acceleration > 0.0 {
				ratio <- (acceleration / max_acceleration);
				draw shape color: rgb(100 + (155 * ratio), 100, 100) border: #black;
			} else {
				ratio <- (abs(acceleration) / max_break);
				draw shape color: rgb(100, 100, 100 + (155 * ratio)) border: #black;
			}
		}

	} }

