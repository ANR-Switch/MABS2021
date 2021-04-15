/**
* Name: Road
* Road species. 
* Author: Jean-François Erdelyi
* Tags: 
*/
model MABS2021

import "../Utilities/EventManager.gaml"
import "Crossroad.gaml"
import "Car.gaml"

/** 
 * General data
 */
global {
	/**
	 * Roads params
	 */
	
	// Vehicule per minutes
	int road_vehicule_per_hour <- 2000;
	
	// BPR equilibrium alpha
	float road_alpha <- 1.0;
	
	// BPR equilibrium beta
	float road_beta <- 0.15;
	
	// BPR equilibrium gamma
	float road_gamma <- 4.0;
	
	// Congestion limit
	float road_jam_lim <- 0.3 min: 0.0 max: 1.0;
}

/**
 * Road virtual species
 */
species Road skills: [scheduling] {	

	/**
	 * Shapefile data
	 */
	 
	// Road ID
	int id;
	 
	// Road max speed
	float max_speed <- 130.0 #km / #h;
	
	// Model
	string road_model <- "micro" among: ["micro", "meso"];
	
	// Road type
	string type;
	
	/**
	 * Capacity data
	 */
	 
	// Lengh
	float length;

	// Maximum space capacity of the road (in meters)
	float max_capacity min: 10.0;

	// Actual free space capacity of the road (in meters)
	float current_capacity min: 0.0 max: max_capacity;

	// Jam percentage
	float jam_percentage <- 0.0;
	
	/**
	 * Graph data
	 */
	 
	// Start crossroad node
	Crossroad start_node;

	// End crossroad node
	Crossroad end_node;
	
	// First point
	point start;

	// Last point	
	point end;
	
	/**
	 * Cars data
	 */

	// The list of car in this road
	queue<Car> cars <- [];
	
	// Waiting cars
	queue<Car> waiting_cars <- [];
	
	// Request time of each car
	map<Car, date> request_times <- [];
	 
	/**
	 * Computation data
	 */
	
	// Outflow duration
	float outflow_duration <- 1 / (road_vehicule_per_hour / 3600)  #s;
	
	// If true use micro model
	bool micro_model <- road_model = "micro" ? true : false;

	// Road color
	rgb color <- micro_model ? #blue : #green;
			
	// Number of out veh total
	int nb_out_total <- 0;

	// Last out date
	date last_out <- nil;
	
	/**
	 * Jam data
	 */
	
	// If true the road is jammed
	bool is_jammed <- false;
	
	// Start jam
	date jam_start_date <- nil;
	
	// Jam duration
	float jam_duration <- 0.0;
	
	/**
	 * Init
	 */

	// Init the model
	init {
		// Get crossroad		
		start_node <- Crossroad closest_to first(self.shape.points);
		end_node <- Crossroad closest_to last(self.shape.points);
		
		// Add this road to out_road of the start node
		ask start_node {
			do add_out_road(myself);
		}
		
		// Force the location
		shape.points[0] <- start_node.location;
		shape.points[length(shape.points) - 1] <- end_node.location;
		
		// Add this road to in_road of the end node
		ask end_node {
			do add_in_road(myself);
		}
	
		// Set event manager
		event_manager <- EventManager[0];
	}
	
	/**
	 * Reflex 
	 */
	 	 
	 // Check micro waitings if micro model and there is waiting agents and if the first one is from micro model
	 reflex check_waiting_cyclic when: micro_model and not empty(waiting_cars) and not first(waiting_cars).road.micro_model {
		do check_and_add_waiting_agents(simulation_date);
	 } 
	 
	/**
	 * Init action
	 */
	 
	 // Translate and init
	action init_with_translation {		
		// Get translations (in order to draw two roads if there is two directions)
		point trans;
		point A <- start_node.location;
		point B <- end_node.location;
		
		if (A = B) {
			trans <- {0, 0};
		} else {
			point u <- {-(B.y - A.y) / (B.x - A.x), 1};
			float angle <- angle_between(A, B, A + u);
			if (angle < 150) {
				trans <- u / norm(u);
			} else {
				trans <- -u / norm(u);
			}

		}
		shape <- (shape) translated_by (trans * 20);
		
		do init();
	}
	
	// Init
	action init {
		start <- first(shape.points);
		end <- last(shape.points);
		length <- shape.perimeter;
		max_capacity <- length;
		current_capacity <- max_capacity;
		jam_percentage <- ((max_capacity - current_capacity) / max_capacity);
	}

	/**
	 * General action
	 */

	// Join the road
	action join (Car car, date request_time, bool from_waiting_queue <- false) {
		if micro_model {
			do micro_join(car, request_time, from_waiting_queue);
		} else {
			do meso_join(car, request_time, from_waiting_queue);
		}
		
		if not is_jammed and jam_percentage >= road_jam_lim {
			jam_start_date <- request_time;
			is_jammed <- true;
		}
	}

	// Leave the road
	action leave (Car car, date request_time, bool from_waiting_queue <- false) {
		if micro_model {
			do micro_leave(car, request_time, from_waiting_queue);
		} else {
			do meso_leave(car, request_time, from_waiting_queue);
		}
		
		if is_jammed and jam_percentage < road_jam_lim {
			jam_duration <- jam_duration + ((jam_start_date milliseconds_between request_time) / 1000.0);
			is_jammed <- false;
		}
	}
		
	// Check if there is waiting agents and add it if it's possible
	action check_and_add_waiting_agents (date request_time) {
		// Check if waiting tranport can be join the road
		loop while: not empty(waiting_cars) {
			// If the first car is not in micro_model and the road is accessible
			if (not first(waiting_cars).road.micro_model) and (start_node.get_accessibility(self, request_time, first(waiting_cars))) {				
				// Get first car			
				Car car <- first(waiting_cars);
				
				// Leave previous road
				if car.road != nil {
					ask car.road {
						do leave(car, request_time, true);
					}				
				} else {
					// If this the first road, join directly
					do join(car, request_time, true);
				}
			} else {
				break;
			}
		}
	}
		
	// Just the current capacity
	bool has_capacity {
		// If micro model check if there is enough space
		if micro_model {
			if not empty(cars) {
				return last(cars) distance_to start > (car_size + car_spacing);			
			}
			return true;		
		} else {
			// Else, capacity check
			return (current_capacity >= car_size + car_spacing);
		}
	}
	
	// Check if the next car allowed is the given one
	bool car_is_allowed(Car car) {
		return (not empty(waiting_cars) and first(waiting_cars) = car) or (empty(waiting_cars) and car.road = nil);
	}
	
	// Force model
	action force_model(bool is_micro_model) {
		color <- is_micro_model ? #blue : #green;
		micro_model <- is_micro_model;
		road_model <- is_micro_model ? "micro" : "meso";
	}

	// Update capacity
	action update_capacity(float space) {
		current_capacity <- current_capacity + space;
		jam_percentage <- ((max_capacity - current_capacity) / max_capacity);
	}

	/**
	 * Micro action
	 */
	 
	 // Join the road
	action micro_join (Car car, date request_time, bool from_waiting_queue) {
		// Update capacity 
		do update_capacity(- car_size - car_spacing);
		
		ask car {
			// Set values
			do setup(request_time);
	
			// Remaining speed
			do one_step_goto(remaining_speed, request_time, true);
		}

		// Add car and time to travel
		do add_car_with_check(car, from_waiting_queue);
	}

	// Leave the road
	action micro_leave (Car car, date request_time, bool from_waiting_queue) {
		// Remove car
		Car pop_car <- remove_car(car, request_time);
		
		// Change capacity
		do update_capacity(car_size + car_spacing);
		
		// Change capacity
		ask pop_car {
			// Tear down
			do tear_down(request_time);	
		}
		
		// If there is another road
		if pop_car.road != nil {
			// Join new road
			ask pop_car.road {
				do join(pop_car, request_time, from_waiting_queue);
			}
		} else {
			ask pop_car {
				do die();
			}
		}
	}

	/**
	 * Meso action
	 */
	 
	// Join the road
	action meso_join (Car car, date request_time, bool from_waiting_queue) {
		// Change capacity
		do update_capacity(- car_size - car_spacing);
		
		ask car {
			// Set values
			do setup(request_time);
			
			// Remaining speed
			do one_step_goto_meso (remaining_speed);
		}
		
		// Add car and time to travel
		do meso_add_car_with_check(car, (request_time + car.travel_time), from_waiting_queue);
		
		// If this is the first car
		if length(cars) = 1 {
			do check_and_schedule_first_agent(request_time);		
		}
	}
	 
	// Leave the road
	action meso_leave (Car car, date request_time, bool from_waiting_queue) {

		// Check first
		if not empty(cars) and first(cars) != car {
			write "Something wrong in meso_leave " + self + " " + car + " at " + cycle;
		}
			
		// If there is another road
		Road next_road <- car.get_next_road();
		if next_road != nil {
			bool reachable;
			if from_waiting_queue {
				reachable <- true;
			} else {
				reachable <- end_node.get_accessibility(next_road, request_time, car);
			}
			// If joined
			if reachable {
				// Pop
				Car pop_car <- remove_car(car, request_time);
				
				// Change capacity
				do update_capacity(car_size + car_spacing);

				// Tear down 
				ask pop_car {
					do tear_down(request_time);
				}
		
				// Check and add car
				do check_waiting(request_time);

				// Join new road
				ask next_road {
					do join(pop_car, request_time, from_waiting_queue);
				}				
			} else {
				ask next_road {
					do add_to_waiting_queue(car);
				}
			}
		} else {
			// Pop
			Car pop_car <- remove_car(car, request_time);
			
			// Change capacity
			do update_capacity(car_size + car_spacing);
			
			// Tear down
			ask pop_car {
				do tear_down(request_time);
			}
	
			// Check and add car
			do check_waiting(request_time); 

			// Do die
			ask pop_car {
				do die();
			}
		}
	}
		
	// End travel
	action end_travel(Car car, date request_time, bool from_signal <- false) {
		if last_out = nil {
			do leave(car, request_time);
		} else {
			float delta <- compute_delta(request_time);
			if check_outflow_with_delta(request_time, delta) {
				do leave(car, request_time);
			} else {
				// If the car has crossed the road
				date signal_date <- request_time + (outflow_duration - delta);
				
				// If the signal date is equals to the actual step date then execute it directly
				if signal_date = (starting_date + time) {
					do leave(car, request_time + (outflow_duration - delta));
				} else if not from_signal {
					do later the_action: meso_leave_signal at: signal_date refer_to: car;					
				}
			}
		}
	}
	
	// Check outflow accessibility
	float compute_delta (date request_time) {
		return milliseconds_between(last_out, request_time) / 1000.0;
	}
	
	// Check outflow accessibility
	bool check_outflow_with_delta (date request_time, float delta) {
		outflow_duration <- 1 / (road_vehicule_per_hour / 3600) #s;
		return delta >= outflow_duration;
	}
	
	// Check outflow accessibility
	bool micro_check_outflow (date request_time, Car car) {
		if last_out = nil {
			return true;
		}
		outflow_duration <- 1 / (road_vehicule_per_hour / 3600) #s;
		
		float delta_t <- milliseconds_between(last_out, request_time) / 1000.0;
		float delta_x <- car distance_to end using topology(network);
		float time_to_reach <- delta_x / car.speed;
		
		/*write (car.name + " : " + (delta_t + time_to_reach));
		write delta_x;
		write delta_t;
		write time_to_reach;*/
		
		return (delta_t + time_to_reach) >= outflow_duration;
	}

	// Check waiting agents
	action check_waiting(date request_time) {
		do check_and_schedule_first_agent(request_time);
		do check_and_add_waiting_agents(request_time);
	}
	
	// Check first car and execute end_travel if needed
	action check_first_agent (date request_time, bool from_signal <- false) {		
		if not empty(cars) {
			Car car <- first(cars);
			date end_road_date; 
			if request_time > request_times[car] {
				end_road_date <- request_time;
			} else {
				end_road_date <- request_times[car];
			}
			
			if end_road_date = request_time {
				do end_travel(car, end_road_date, from_signal);	
			}
		}
	}
	
	// Check first car and execute end_travel if needed (can also schedule)
	action check_and_schedule_first_agent (date request_time) {		
		if not empty(cars) {
			Car car <- first(cars);
			date end_road_date; 
			if request_time > request_times[car] {
				end_road_date <- request_time;
			} else {
				end_road_date <- request_times[car];
			}
			
			if end_road_date = (starting_date + time) {
				do end_travel(car, end_road_date);			
			} else {
				do later the_action: end_travel_signal at: end_road_date refer_to: car;			
			}
		}
	}

	// Freeflow travel time
	float compute_travel_time(float free_flow_travel_time) {		
		return free_flow_travel_time * (road_alpha + road_beta * (jam_percentage ^ road_gamma));			
	}
	
	/**
	 * Meso signal
	 */

	// Leave signal
	action meso_leave_signal {
		do meso_leave(refer_to as Car, event_date, false);
	}
	
	// End signal
	action end_travel_signal {
		do end_travel(refer_to as Car, event_date);
	}
	
	
	/**
	 * Handler action
	 */

	// Add car
	action add_car (Car car) {
		push item: car to: cars;
	}

	// Add car to waiting queue
	action add_to_waiting_queue (Car car) {
		push item: car to: waiting_cars;
	}
		
	// Add car with check
	action add_car_with_check (Car car, bool from_waiting_queue) {
		// *-* coupling
		// If there is last road and from_waiting_queue is true or is last road is micro
		if car.last_road != nil and (from_waiting_queue or car.last_road.micro_model) {
			Car first <- first(waiting_cars);
			if first != car {
				write "Something wrong in add_car_with_check " + self + " (" + car + " vs " + first + ") at " + cycle;
			} else {
				first <- pop(waiting_cars);
			}
		}
		
		// Add car
		do add_car (car);
	}
	
	// Add car with check
	action meso_add_car_with_check (Car car, date request_time, bool from_waiting_queue) {
		// Add car
		add request_time at: car to: request_times;			
		do add_car_with_check (car, from_waiting_queue);		
	}
	
	// Remove car from the queue with check
	Car remove_car (Car car, date request_time) {
		// Save last_out date
		last_out <- request_time;
		nb_out_total <- nb_out_total + 1;

		// Remove car of request_times
		if not micro_model {
			remove key: car from: request_times;			
		}

		// Get and check first car in the queue
		Car first <- first(cars);
		if first != car {
			write "Something wrong in remove_car " + self + " (" + car + " vs " + first + ") at " + cycle;
			// Return given car
			return car;
		}
		
		// Return first car
		return pop(cars);
	}
	
	/**
	 * Log data
	 */

	// Density
	float compute_k {
		return length(cars) / length;
	}
	
	// Mean speed
	float compute_u {
		if length(cars) <= 0 {
			return 0.0;
		}
		float mean_speed <- 0.0;
		
		ask cars {
			mean_speed <- mean_speed + speed;
		}
		return (mean_speed / length(cars)); // m/s
		
	}
	
	/**
	 * User commands 
	 */
	
	// Switch to micro road
	user_command "Switch to micro" when: not micro_model and empty(cars) {
   		do force_model(true);
	}
	
	// Switch to meso road
	user_command "Switch to meso" when: micro_model and empty(cars) {
   		do force_model(false);
	}	
	
	/**
	 * Aspect
	 */

	// Default aspect
	aspect default {
		if simple_drawing {
			draw shape color: rgb(255 * jam_percentage, 0, 0);
		} else {
			color <- micro_model ? #blue : #green;
			draw shape + 1 border: color color: rgb(255 * jam_percentage, 0, 0) width: 3;
		}
	}

}
