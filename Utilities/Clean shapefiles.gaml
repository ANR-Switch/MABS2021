/**
* Name: Clean shapefiles
* Clean shapefiles. 
* Author: Jean-François Erdelyi
* Tags: 
*/
model MABS2021

global {
	shape_file roads_shape_file <- shape_file("../includes/Shapefiles/roads.shp");
	shape_file boundary_shape_file <- shape_file("../includes/Shapefiles/boundary.shp");
	geometry shape <- envelope(boundary_shape_file);

	// Tolerance for reconnecting nodes
	float tolerance <- 3.0;
	// If true, split the lines at their intersection
	bool split_lines <- false;
	// If true, keep only the main connected components of the network
	bool reduce_to_main_connected_components <- false;
	// Road to save
	list<road> roads_to_save;
	
	float min_length <- 1000#m;
	float min_length_motorway_link <- 100#m;

	init {
		create road from: roads_shape_file;
		create boundary from: boundary_shape_file;
		ask road where not (each.type = 'motorway' or (each.type = 'motorway_link')) {
			do die;
		}

		add extract_road_by_type('motorway') to: roads_to_save all: true;
		add extract_road_by_type('motorway_link') to: roads_to_save all: true;
		loop tmp_road over: roads_to_save {
			list<point> tmp_line;
			loop tmp_point over: tmp_road.shape.points {
				if (tmp_point overlaps boundary[0]) {
					add tmp_point to: tmp_line;
				}

			}
			
			if length(tmp_line) <= 1 {
				ask tmp_road {
					do die();					
				}
			} else {
				tmp_road.shape <- polyline(tmp_line);
			}
		}

		do create_crossroads();
		do merge_small_roads();
		do merge_small_roads();
		ask crossroad {
			if empty(in_roads) {
				type <- "generator";
			} else if empty(out_roads) {
				type <- "exit";
			} else {
				type <- "crossroad";
			}

		}

		ask crossroad where (each.type = "generator") {
			ask (crossroad where (each.type = "exit")) closest_to self {
				myself.location <- self.location;
				ask myself.out_roads {
					shape.points[0] <- myself.location;
				}

				myself.in_roads <- self.in_roads;
				loop in over: self.in_roads {
					in.out_crossroad <- myself;
				}

				do die();
				break;
			}

		}
	}

	list<road> extract_road_by_type (string road_type) {
	// Get roads
		list<road> roads <- road where (each.type = road_type);

		// Clean data, with the given options
		list<geometry> clean_lines <- clean_network(roads collect each.shape, tolerance, split_lines, reduce_to_main_connected_components);

		// Kill previous roads
		ask roads {
			do die();
		}

		// Create new road
		create road from: clean_lines returns: values {
			type <- road_type;
			road_model <- type = "motorway" ? "meso" : "micro";
		}

		return values;
	}

	// Switch to micro road
	action create_crossroads {
		ask road {
			create crossroad {
				location <- first(myself.shape.points);
				ask crossroad {
					if myself != self and myself distance_to self < 3 #m {
						myself.location <- self.location;
						do die();
					}

				}

			}

			create crossroad {
				location <- last(myself.shape.points);
				ask crossroad {
					if myself != self and myself distance_to self < 3 #m {
						myself.location <- self.location;
						do die();
					}

				}

			}

		}

		ask road {
			ask crossroad {
				if first(myself.shape.points) distance_to self < 3 #m {
					myself.shape.points[0] <- self.location;
					add myself to: out_roads;
					myself.in_crossroad <- self;
				}

				if last(myself.shape.points) distance_to self < 3 #m {
					myself.shape.points[length(myself.shape.points) - 1] <- self.location;
					add myself to: in_roads;
					myself.out_crossroad <- self;
				}

			}

		}

	}

	action merge_small_roads {
		ask crossroad {
			// For each in roads
			if length(in_roads) = 1 and length(out_roads) = 1 {
				loop in over: in_roads {
					// If the ID is note equals
					if not dead(in) and in.shape.perimeter < min_length {
						loop out over: out_roads {
							if not dead(out) and out.type = in.type {
								// Merge all points
								list<point> line;
								loop pt over: in.shape.points {
									add pt to: line;
								}

								loop pt over: out.shape.points {
									add pt to: line;
								}

								in.shape <- polyline(line);
								remove out from: out.out_crossroad.in_roads;
								add in to: out.out_crossroad.in_roads;
								in.out_crossroad <- out.out_crossroad;
								ask out {
									do die;
								}

								do die;
							}

						}

					}

				}

				loop out over: out_roads {
				// If the ID is note equals
					if not dead(out) and out.shape.perimeter < min_length {
						loop in over: in_roads {
							if not dead(in) and in.type = out.type {
							// Merge all points
								list<point> line;
								loop pt over: in.shape.points {
									add pt to: line;
								}

								loop pt over: out.shape.points {
									add pt to: line;
								}

								out.shape <- polyline(line);
								remove in from: in.in_crossroad.out_roads;
								add out to: in.in_crossroad.out_roads;
								out.in_crossroad <- in.in_crossroad;
								ask in {
									do die;
								}

								do die;
							}

						}

					}

				}

			}

		}

		ask road {
			if shape.perimeter < min_length_motorway_link and type = "motorway_link" {
				remove self from: out_crossroad.in_roads;
				remove self from: in_crossroad.out_roads;
				do die();
			}

		}

		ask crossroad {
			if empty(in_roads) and empty(out_roads) {
				do die();
			}

		}

	}

	// Switch to micro road
	user_command "Save shapefiles" {
		save boundary type: "shp" to: "../includes/boundary.shp";
		save road type: "shp" to: "../includes/roads.shp" attributes: ['type'::type, 'road_model'::road_model];
		save crossroad type: "shp" to: "../includes/crossroads.shp" attributes: ['type'::type];
	}

}

species road {
	string type;
	string road_model;
	crossroad in_crossroad;
	crossroad out_crossroad;

	aspect default {
		draw shape color: (type = 'motorway') ? #blue : #red;
	}

}

species boundary {

	aspect default {
		draw shape border: #grey wireframe: true;
	}

}

species crossroad {
	string type;
	list<road> in_roads;
	list<road> out_roads;

	aspect default {
		draw circle(4) color: (type = 'generator' or type = 'exit') ? #yellow : #green;
	}

}

experiment "Clean shapefiles" type: gui {
	output {
		display "Clean shapefiles" {
			species boundary;
			species road;
			species crossroad;
		}

	}

}