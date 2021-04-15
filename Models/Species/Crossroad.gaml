/**
* Name: Crossroad
* Crossroad.  
* Author: Jean-François Erdelyi
* Tags: 
*/
model MABS2021

import "Car.gaml"

/** 
 * Crossroad species
 */
species Crossroad {
	/**
	 * Shapefile data
	 */

	// Crossroad type
	string type <- "generator" among: ["generator", "crossroad", "exit", "passthrough"];

	/**
	 * Drawing data
	 */

	// List of colors
	map<string, rgb> colors <- ["generator"::#yellow, "crossroad"::#green, "passthrough"::#grey];

	// Shape
	geometry shape <- circle((car_size / 2.0) + car_spacing);

	// Color
	rgb color <- colors[type];

	/**
	 * Computation data
	 */

	// In roads
	list<Road> in_roads;

	// Out roads
	list<Road> out_roads;
	
	// Crossroad accessibility
	bool accessible <- true;

	/**
	 * Action
	 */

	// Clean crossroads
	action init {
		// If this is passthrough then
		// Remove the crossroad and merge the
		// Two roads
		if type = "passthrough" {
			// For each in roads
			loop in over: in_roads {
				// For each out roads
				loop out over: out_roads {
					// If the ID is note equals
					if in.id != out.id {
						// Merge all points
						list<point> line;
						loop point over: in.shape.points {
							add point to: line;
						}

						loop point over: out.shape.points {
							add point to: line;
						}

						in.shape <- polyline(line);

						// Set Crossroad-Road connections
						in.end_node <- out.end_node;
						ask in.end_node {
							do add_in_road(in);
							do remove_in_road(out);
						}

					}

				}

			}

			// Kill all out_roads and this crossroad
			ask out_roads {
				do die();
			}

			do die();
		}

	}

	// Get accessibility for a given road and car
	bool get_accessibility (Road road, date request_date, Car car <- nil) {
		if not accessible {
			return false;
		} 
		if road = nil {
			// Micro-Nil or Meso-Nil
			return true;
		} else if out_roads contains road {
			if car != nil and (not road.micro_model and car.road.micro_model) {
				// Micro-Meso if car is defined
				return road.has_capacity() and road.car_is_allowed(car) and car.road.micro_check_outflow(request_date, car);
			} else if car != nil and not (not road.micro_model and not car.road.micro_model) {
				// Not Meso-Meso if car is defined
				return road.has_capacity() and road.car_is_allowed(car);
			}
			// Meso-Meso and other situations
			return road.has_capacity();
		} else {
			write "Road is not attached to this crossroad";
			return false;
		}

	}

	/**
	 * Collections handlers
	 */

	// Add in road
	action add_in_road (Road road) {
		add road to: in_roads;
	}

	// Remove in road
	action remove_in_road (Road road) {
		remove road from: in_roads;
	}

	// Add out road
	action add_out_road (Road road) {
		add road to: out_roads;
	}
	
	/**
	 * User commands 
	 */
	
	// Switch to micro road
	user_command "Switch accessibility" {
   		if accessible {
   			color <- #red;
   			accessible <- false;
   		} else {
			color <- colors[type];
   			accessible <- true;
   		}
	}

	/**
	 * Aspect
	 */

	// Default aspect
	aspect default {
		// Draw shape
		if simple_drawing {
			draw circle(10) color: color;
		} else {
			draw shape color: color border: #black;
		}
	}

}
