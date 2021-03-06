/******************************************************************
*                                                                 *
* OpenFlexure Microscope: Microscope baseplate                    *
*                                                                 *
* This part fits underneath the microscope - the idea is to       *
* provide a tray to store electronics, etc.                       *
*                                                                 *
* (c) Richard Bowman, December 2016                               *
* Released under the CERN Open Hardware License                   *
*                                                                 *
******************************************************************/

use <./utilities.scad>;
use <./compact_nut_seat.scad>;
use <./logo.scad>;
use <./dovetail.scad>;
include <./microscope_parameters.scad>; //All the geometric variables are now in here.
foot_z = wall_h; //height of the bottom of the feet
mount_z = foot_z + foot_height; //height for the mounting surfaces
ss_outer = ss_outer();

module leg_frame(angle){
    // Transform into the frame of one of the legs of the stage
	rotate(angle) translate([0,leg_r,]) children();
}
module each_leg(){
    // Repeat for each of the legs of the stage
	for(angle=[45,135,-135,-45]) leg_frame(angle) children();
}
module each_actuator(){
    // Repeat this for both of the actuated legs (the ones with levers)
	reflect([1,0,0]) leg_frame(45) children();
}

module add_hull_base(h=1){
    // Take the convex hull of some objects, and add it in as a
    // thin layer at the bottom
    union(){
        intersection(){
            hull() children();
            cylinder(r=9999,$fn=8,h=h); //make the base thin
        }
        children();
    }
}
module add_roof(inner_h){
    // Take the convex hull of some objects, and add the top
    // of it as a roof.  NB you must specify the height of
    // the underside of the roof - finding it automatically
    // would be too much work...
    union(){
        difference(){
            hull() children();
            cylinder(r=9999,$fn=8,h=inner_h);
        }
        children();
    }
}
module wall_vertex(r=wall_t/2, h=wall_h, x_tilt=0, y_tilt=0){
    // A cylinder, rotated by the given angles about X and Y,
    // but with the top and bottom kept in the XY plane
    // (i.e. it's sheared rather than tilted).    These form the
    // stiffening "wall" that runs around the base of 
    // the legs
    hull() repeat([tan(y_tilt), -tan(x_tilt), 1]*(h-d), 2){
        cylinder(r=r, h=d, $fn=8);
    }
}
module inner_wall_vertex(leg_angle, x, h=wall_h, y_tilt=-999, y=-zflex_l-wall_t/2){
    // A thin cylinder, close to one of the legs.  It
    // tilts inwards to clear the leg.  These form the
    // stiffening "wall" that runs around the base of 
    // the legs
    
    // leg_angle specifies the leg, x is the X position
    // of the vertex in that leg frame.  h is its height,
    // y and y_tilt override position and angle in y
    
    // unless specified, tilt the leg so the wall at the
    // edge is vertical (i.e. the bit at 45 degrees to
    // the leg frame)
    y_tilt = (y_tilt==-999) ? (x>0?6:-6) : y_tilt;
    leg_frame(leg_angle) translate([x,y,0]){
            wall_vertex(h=h,x_tilt=6,y_tilt=y_tilt);
    }
}

module z_anchor_wall_vertex(){
    // This is the vertex of the supporting wall nearest
    // to the Z anchor - it doesn't make sense to use the
    // function above as it's got the wrong symmetry.
    // We also use this in a few places so it's worth saving
    translate([-z_flexure_x-wall_t/2,-wall_t/2,0]){
        wall_vertex(h=zawall_h, y_tilt=atan(wall_t/zawall_h));
    }
}

module place_on_wall(){
    //this is a complicated transformation!  The wall runs from
    wall_start = [z_flexure_x+wall_t/2,-wall_t/2,0]; // to
    wall_end = ([1,1,0]*(leg_r+actuating_nut_r)
                 +[1,-1,0]*(12+wall_t/2))/sqrt(2);
    wall_disp = wall_end - wall_start; // vector along the wall base
    // pivot about the starting corner of the wall so X is along it
    translate(wall_start) rotate(atan(wall_disp[1]/wall_disp[0]))
    // move out to the surface (the above are centres of cylinders)
    // and then align y with the vertical axis of the wall
    translate([0,-wall_t/2,0]) rotate([90-atan(wall_t/zawall_h/sqrt(2)),0,0])
    // now X and Y are in the plane of the wall, and z=0 is its surface.
    children();
}

///////////////////// MAIN STRUCTURE STARTS HERE ///////////////
union(){
	//base
	difference(){
		union(){
            ////////////// Reinforcing wall and base /////////////////
            // First, go around the inside of the legs, under the stage.
            // This starts at the Z nut seat.  Add_hull generates the 
            // flat base of the structure.  I've split it into two
            // blocks, because the shape is not convex so the base
            // would be bigger than the walls otherwise.
            add_hull_base(base_t) reflect([1,0,0]) sequential_hull(){
                z_anchor_wall_vertex();
                inner_wall_vertex(135, leg_outer_w/2, zawall_h);
                inner_wall_vertex(135, -leg_outer_w/2, wall_h);
                inner_wall_vertex(-135, leg_outer_w/2, wall_h);
            }
            add_hull_base(base_t) {
                // Next, link the XY actuators to the wall
                reflect([1,0,0]) sequential_hull(){
                    z_anchor_wall_vertex(); // join at the Z anchor
                    // anchor at the same angle on the actuator
                    // NB the base of the wall is outside the
                    // base of the screw seat
                    leg_frame(45) translate([-ss_outer[0]/2+wall_t/2,actuating_nut_r,0]){
                        rotate(-45) wall_vertex(y_tilt=atan(wall_t/zawall_h));
                    }
                    // neatly join to the screw seat (actuator column)
                    leg_frame(45) translate([0,actuating_nut_r,0]) screw_seat_outline(h=base_t);
                }
                // Finally, link the actuators together
                reflect([1,0,0]) hull(){
                    leg_frame(45) translate([ss_outer[0]/2-1,actuating_nut_r,-d]) wall_vertex();
                    for(p=base_mounting_holes) translate(p){  
                        if(p[0]<0 && p[1]>0) wall_vertex();
                    }
                }
                hull(){
                    for(p=base_mounting_holes) translate(p){  
                        if(p[1]>0) wall_vertex();
                    }
                }
                // add a small object to make sure the base is big enough
                wall_vertex(h=base_t);
                
                //these are the holes to mount onto the baseplate 
                for(p=base_mounting_holes) translate(p){  
                    cylinder(r=4, h=mount_z);
                }
                reflect([1,0,0]) hull(){
                    inner_wall_vertex(135, leg_outer_w/2, zawall_h);
                    z_anchor_wall_vertex(); 
                    for(p=base_mounting_holes) translate(p){  
                        if(p[0]<0 && p[1]<0) cylinder(r=4, h=mount_z);
                    }
                }
                //Actuator housings (screw seats and motor mounts)
                each_actuator() translate([0,actuating_nut_r,0]){
                    //this makes a "cup" for the microscope feet
                    sequential_hull(){
                        translate([0,0,0]) screw_seat_outline(h=1);
                        translate([0,0,mount_z-foot_height-1.2]) screw_seat_outline(h=1);
                        translate([0,0,mount_z-foot_height]) screw_seat_outline(h=2,adjustment=1.2);
                    }
                }
            }           
		}
         
        //////  Things we need to cut out holes for... /////////// 
        //these are the holes to mount onto the baseplate 
        for(p=base_mounting_holes) translate(p){  
           translate([0,0,3]) cylinder(r=2.5*1.1,h=999); 
        }
        
        //Actuator housings (screw seats and motor mounts)
        each_actuator() translate([0,actuating_nut_r,0]){
            //this makes a "cup" for the microscope feet
            translate([0,0,mount_z-foot_height]) screw_seat_outline(h=999,adjustment=0.2);
            translate([0,0,0.5]) screw_seat_outline(h=999,adjustment=-wall_t);
        }
        
	} ///////// End of things to chop out of base/walls ///////

}

//%rotate(180) translate([0,2.5,-2]) cube([25,24,2],center=true);
