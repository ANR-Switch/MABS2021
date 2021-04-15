/**
* Name: Create highway
* Create highway. 
* Author: Jean-François Erdelyi
* Tags: 
*/
model MABS2021

global {

	// Params
	float length <- 10.0 #km;
	float segment <- 1.0 #km;
	int nb_entry <- 2;
	int nb_exit <- 2;
	geometry shape <- rectangle(length, length / 4.0);

	// Geneate default highway
	init {
		do generate_highway();
	}

	// Generate highway
	action generate_highway {
		ask Road {
			do die();
		}
		ask Crossroad {
			do die();
		}
		ask Boundary {
			do die();
		}
		
		// Generator data
		bool first <- true;
		float remaining_length <- length;
		float current_segment <- segment;
		point a <- nil;
		point b <- nil;
		Road last_road <- nil;
		Crossroad last_crossroad <- nil;
		int nb_generated <- 0;
		int nb_connexion_in <- 0;
		int nb_connexion_out <- 0;
		
		// Loop until the length is reached
		loop while: remaining_length > 0.0 {
			remaining_length <- remaining_length - segment;
			if remaining_length < 0.0 {
				current_segment <- remaining_length;
				remaining_length <- 0.0;
			} else {
				if a = nil and b = nil {
					a <- {0.0, length / 8.0};
					b <- {current_segment, length / 8.0};
				} else {
					a <- b;
					b <- {b.x + current_segment, length / 8.0};
				}

				create Road returns: roads {
					type <- "motorway";
					shape <- line(a, b);
					road_model <- 'meso';
				}

				create Crossroad returns: crossroads {
					shape <- a;
					if first {
						type <- "generator";
						add roads[0] to: out_roads;
						ask roads[0] {
							in_crossroad <- myself;
						}

						first <- false;
					} else {
						type <- "crossroad";
						add last_road to: in_roads;
						ask last_road {
							out_crossroad <- myself;
						}

						add roads[0] to: out_roads;
						ask roads[0] {
							in_crossroad <- myself;
						}

					}

				}

				last_road <- roads[0];
				last_crossroad <- crossroads[0];
			}

			if remaining_length <= 0.0 {
				create Crossroad {
					shape <- b;
					type <- "exit";
					add last_road to: in_roads;
					ask last_road {
						out_crossroad <- myself;
					}

				}

			}
			
			nb_generated <- nb_generated + 1;
		}
		
		loop times: nb_entry {
			Crossroad crossroad <- one_of (Crossroad where (each.connexion_in = false and each.type = "crossroad"));
			crossroad.connexion_in <- true;
			
			do create_connexion(crossroad, false);
		}
		
		loop times: nb_exit {
			Crossroad crossroad <- one_of (Crossroad where (each.connexion_out = false and each.type = "crossroad"));
			crossroad.connexion_out <- true;
			
			do create_connexion(crossroad, true);
		}
			
		create Boundary {
			shape <- myself.shape;
		}
		
		write "Number of roads: " + nb_generated;
	}
	
	action create_connexion(Crossroad out, bool exit) {
		create Crossroad returns: crossroads {
			if exit {
				shape <- {out.location.x + segment, out.location.y + segment};
				type <- "exit";				
			} else {
				shape <- {out.location.x - segment, out.location.y - segment};
				type <- "generator";
			}
		}
		
		create Road {
			type <- "motorway_link";
			max_speed <- 70.0 #km/#h;
			if exit {
				shape <- line(out.location, crossroads[0].location);
				
				in_crossroad <- out;
				out_crossroad <- crossroads[0];	
			} else {
				shape <- line(crossroads[0].location, out.location);
				
				in_crossroad <- crossroads[0];
				out_crossroad <- out;
			}
			road_model <- 'micro';
			ask in_crossroad {
				add myself to: out_roads;
			}
			ask out_crossroad {
				add myself to: in_roads;
			}
		}

	}
	

	// (Re)Generate highway 
	user_command "Generate highway" {
		do generate_highway();
	}

	// Save shapefile
	user_command "Save shapefiles" {
		save Boundary type: "shp" to: "../includes/boundary.shp";
		save Road type: "shp" to: "../includes/roads.shp" attributes: ['road_model'::road_model, 'max_speed'::max_speed, 'type'::type];
		save Crossroad type: "shp" to: "../includes/crossroads.shp" attributes: ['type'::type];
	}

}

// Boundary
species Boundary {

	aspect default {
		draw shape border: #grey empty: true;
	}

}

// Roads
species Road {
	string type;
	string road_model;
	Crossroad in_crossroad;
	Crossroad out_crossroad;
	float max_speed <- 130.0#km/#h;

	aspect default {
		draw shape + 2 color: (road_model = 'micro') ? #blue : #green;
	}

}

// Crossroads
species Crossroad {
	string type;
	list<Road> in_roads;
	list<Road> out_roads;
	bool connexion_in <- false;
	bool connexion_out <- false;

	// Create exit
	user_command "Create exit" {
		ask world {
			do create_connexion(myself, true);			
		}
	}
	
	// Create entry
	user_command "Create entry" {
		ask world {
			do create_connexion(myself, false);	
		}
	}

	aspect default {
		draw circle(4) color: (type = 'generator' or type = 'exit') ? #yellow : #green border: #black;
	}

}

// Experiment
experiment "Create highway" type: gui {
// Params
	parameter "Highway length" var: length;
	parameter "Road segment length" var: segment;
	parameter "Number of entries" var: nb_entry;
	parameter "Number of exits" var: nb_exit;
	output {
		display "Highway" {
			species Boundary;
			species Road;
			species Crossroad;
		}

	}

}