// AMX Mod X - Script

//--------------------------------------------------------------------------------------------------

#include <amxmodx>
#include <engine>

#define PLUGIN "Admin Spectator ESP"
#define VERSION "1.0"
#define AUTHOR "KoST"

#define REQUIRED_ADMIN_LEVEL ADMIN_KICK

//--------------------------------------------------------------------------------------------------

new bool:admin[33]
new bool:first_person[33]
new spec[33]
new laser
new max_players

new weapons[30][10]={"-","P228","Scout","HE","XM1014","C4",
	"MAC-10","AUG","Smoke","Elite","Fiveseven",
	"UMP45","SIG550","Galil","Famas","USP",
	"Glock","AWP","MP5","M249","M3","M4A1",
	"TMP","G3SG1","Flash","Deagle","SG552",
	"AK47","Knife","P90"}


public plugin_precache(){
	laser=precache_model("sprites/laserbeam.spr") 
}

public plugin_init(){
	register_plugin(PLUGIN,VERSION,AUTHOR)
	register_cvar("esp","1")
	register_cvar("esp_timer","0.3")
	register_cvar("esp_box","1")
	register_cvar("esp_line","1")
	register_cvar("esp_name","1")
	register_event("SpecHealth2","spec_target","bd","1=2")
	register_event("TextMsg","spec_mode","b","2&#Spec_Mode")
	set_task(1.0,"esp_timer")
	max_players=get_maxplayers()
	server_print("^n^t%s v%s by %s^n [%d]",PLUGIN,VERSION,AUTHOR,max_players)
	
} 

public spec_mode(id){
	new specMode[32]
	read_data(2,specMode,31)
	
	if( equal(specMode, "#Spec_Mode4")){
		first_person[id]=true
	}else{
		first_person[id]=false
	}
}

public spec_target(id){
	new target=read_data(2)
	if (target!=0){
		spec[id]=target
	}
}

public client_authorized(id){
	first_person[id]=false
	if (get_user_flags(id) & REQUIRED_ADMIN_LEVEL){
		admin[id]=true
	}else{
		admin[id]=false
	}
}

public client_disconnect(id){
	admin[id]=false
}

public esp_timer(){
	if (get_cvar_num("esp")!=1) { // if esp is not 1, it is off
		set_task(1.0,"esp_timer") // check for reactivation in 1 sec intervals
		return PLUGIN_CONTINUE 
	}
	
	for (new i=1;i<=max_players;i++){ // loop through players
		
		if (first_person[i] && is_user_connected(i) && admin[i] && (!is_user_alive(i))){ // :)
			
			new Float:my_origin[3] 
			entity_get_vector(i,EV_VEC_origin,my_origin) // get origin of spectating admin
			
			new my_team
			my_team=get_user_team(spec[i]) // get team of spectated :)

			new Float:smallest_angle=180.0 
			new smallest_id=0
			new Float:xp=2.0,Float:yp=2.0 // x,y of hudmessage
			new Float:dist
			
			for (new s=1;s<=max_players;s++){ // loop through the targets
				if (is_user_alive(s)){ // target must be alive
					new target_team=get_user_team(s) // get team of target
					if (!(target_team==3)){ //if not spectator
						if (i!=s){ // do not target myself
							// if the target is in the other team and not spectator
							if (my_team!=target_team && (target_team==1 || target_team==2)){
								
								new Float:target_origin[3]
								// get origin of target
								entity_get_vector(s,EV_VEC_origin,target_origin)

								// get distance from me to target
								new Float:distance=vector_distance(my_origin,target_origin)
								
								if (get_cvar_num("esp_line")==1){ // if esp_line is 1
									
									new width
									if (distance<2040.0){
										// calculate width according to distance
										width=(255-floatround(distance/8.0))/3
									}else{
										width=1
									}	
									// create temp_ent
									make_TE_BEAMENTPOINT(i,target_origin,width,target_team)
								}
								
								// get vector from me to target
								new Float:v_middle[3]
								subVec(target_origin,my_origin,v_middle)
								
								// get vector pointing to bottom of green box
								new Float:v_lower[3]
								copyVec(v_middle,v_lower)
								v_lower[2]-=50.0

								// trace from me to target, getting hitpoint
								new Float:v_hitpoint[3]
								trace_line (-1,my_origin,target_origin,v_hitpoint)
								
								// get distance from me to hitpoint (nearest wall)
								new Float:distance_to_hitpoint=vector_distance(my_origin,v_hitpoint)
								
								// scale
								new Float:scaled_bone_len=distance_to_hitpoint/distance*50.0
								new Float:scaled_bone_width=distance_to_hitpoint/distance*150.0

								new Float:v_bone_start[3],Float:v_bone_end[3]
								new Float:offset_vector[3]
								// get the point 10.0 units away from wall
								normalize(v_middle,offset_vector,distance_to_hitpoint-10.0) // offset from wall
								
								// set to eye level
								new Float:eye_level[3]
								copyVec(my_origin,eye_level)
								eye_level[2]+=18.0
								addVec(offset_vector,eye_level)
								
								// start and end of green box
								copyVec(offset_vector,v_bone_start)
								copyVec(offset_vector,v_bone_end)
								v_bone_end[2]-=scaled_bone_len

								new Float:distance_target_hitpoint=distance-distance_to_hitpoint
								
								new actual_bright=255
								//draw box if esp_box=1 and if there is no line of sight between me and target
								if (distance_to_hitpoint!=distance && get_cvar_num("esp_box")==1){
									// this is to make green box darker if distance is larger
									if (distance_target_hitpoint<2040.0){
										actual_bright=(255-floatround(distance_target_hitpoint/12.0))
										
									}else{
										actual_bright=85
									}	
									make_TE_BEAMPOINTS(i,v_bone_start,v_bone_end,floatround(scaled_bone_width),target_team,actual_bright)
								}
								
								//show names if esp_name=1
								if (get_cvar_num("esp_name")==1){

									new Float:ret[2]
									new Float:x_angle=get_screen_pos(i,s,v_middle,ret)
									
									// find target with the smallest distance to crosshair (on x-axis)
									if (smallest_angle>floatabs(x_angle)){
										if (floatabs(x_angle)!=0.0){
											smallest_angle=floatabs(x_angle)
											smallest_id=s // store nearest target id..
											xp=ret[0] // and x,y coordinates of hudmessage
											yp=ret[1]
											dist=distance
										}
									}
								}
							}
						}
					}
				}
			} // inner player loop end

			if (xp>0.0 && xp<=1.0 && yp>0.0 && yp<=1.0){ // if in visible range
				// show the player info
				set_hudmessage(255, 255, 0, floatabs(xp-0.04), floatabs(yp), 0, 0.0, get_cvar_float("esp_timer"))
				new name[33]
				get_user_name(smallest_id,name,32)
				new health=get_user_health(smallest_id)
				new armor=get_user_armor(smallest_id)
				new clip,ammo
				new weapon_id=get_user_weapon (smallest_id,clip,ammo)
				if ((weapon_id-1)<0 || (weapon_id-1)>29) weapon_id=1
				show_hudmessage(i, "[%s]^narmor: %d hp: %d^nweapon: %s ^nclip: %d ammo: %d^ndistance: %d",name,armor,health,weapons[weapon_id-1],clip,ammo,floatround(dist))
			}
		}
	}
	set_task(get_cvar_float("esp_timer"),"esp_timer") // keep it going
	return PLUGIN_CONTINUE	
}

public Float:get_screen_pos(id,id2,Float:v_me_to_target[3],Float:Ret[2]){
	new Float:v_aim[3]
	VelocityByAim(id,1,v_aim) // get aim vector
	new Float:aim[3]
	copyVec(v_aim,aim) // make backup copy of v_aim
	v_aim[2]=0.0 // project aim vector vertically to x,y plane
	new Float:v_target[3]
	copyVec(v_me_to_target,v_target)
	v_target[2]=0.0 // project target vector vertically to x,y plane
	// both v_aim and v_target are in the x,y plane, so angle can be calculated..
	new Float:x_angle
	new Float:x_pos=get_screen_pos_x(v_target,v_aim,x_angle) // get the x coordinate of hudmessage..
	new Float:y_pos=get_screen_pos_y(v_me_to_target,aim) // get the y coordinate of hudmessage..
	Ret[0]=x_pos 
	Ret[1]=y_pos
	return x_angle
}

public Float:get_screen_pos_x(Float:target[3],Float:aim[3],&Float:xangle){
	new Float:x_angle=floatacos(vectorProduct(aim,target)/(getVecLen(aim)*getVecLen(target)),1) // get angle between vectors
	new Float:x_pos
	//this part is a bit tricky..
	//the problem is that the 'angle between vectors' formula returns always positive values
	//how can be determined if the target vector is on the left or right side of the aim vector? with only positive angles?
	//the solution:
	//the scalar triple product returns the volume of the parallelepiped that is created by three input vectors
	//
	//i used the aim and target vectors as the first two input parameters
	//and the third one is a vector pointing straight upwards [0,0,1]
	//if now the target is on the left side of spectator origin the created parallelepipeds volume is negative 
	//and on the right side positive
	//now we can turn x_angle into a signed value..
	if (scalar_triple_product(aim,target)<0.0) x_angle*=-1 // make signed
	if (x_angle>=-45.0 && x_angle<=45.0){ // if in fov of 90
		x_pos=1.0-(floattan(x_angle,degrees)+1.0)/2.0 // calulate y_pos of hudmessage
		xangle=x_angle
		return x_pos
	}
	xangle=0.0
	return -2.0
}

public Float:get_screen_pos_y(Float:v_target[3],Float:aim[3]){
	new Float:target[3]
	
	// rotate vector about z-axis directly over the direction vector (to get height angle)
	rotateVectorZ(v_target,aim,target)

	// get angle between aim vector and target vector
	new Float:y_angle=floatacos(vectorProduct(aim,target)/(getVecLen(aim)*getVecLen(target)),1) // get angle between vectors

	new Float:y_pos
	new Float:norm_target[3],Float:norm_aim[3]

	// get normalized target and aim vectors
	normalize(v_target,norm_target,1.0)
	normalize(aim,norm_aim,1.0)
	
	//since the 'angle between vectors' formula returns always positive values
	if (norm_target[2]<norm_aim[2]) y_angle*=-1 //make signed

	if (y_angle>=-45.0 && y_angle<=45.0){ // if in fov of 90
		y_pos=1.0-(floattan(y_angle,degrees)+1.0)/2.0 // calulate y_pos of hudmessage
		if (y_pos>=0.0 && y_pos<=1.0) return y_pos
	}
	return -2.0
}

// Vector Operations -------------------------------------------------------------------------------

public Float:getVecLen(Float:Vec[3]){
	new Float:VecNull[3]={0.0,0.0,0.0}
	new Float:len=vector_distance(Vec,VecNull)
	return len
}

public Float:scalar_triple_product(Float:a[3],Float:b[3]){
	new Float:up[3]={0.0,0.0,1.0}
	new Float:Ret[3]
	Ret[0]=a[1]*b[2]-a[2]*b[1]
	Ret[1]=a[2]*b[0]-a[0]*b[2]
	Ret[2]=a[0]*b[1]-a[1]*b[0]
	return vectorProduct(Ret,up)
}

public normalize(Float:Vec[3],Float:Ret[3],Float:multiplier){
	new Float:len=getVecLen(Vec)
	copyVec(Vec,Ret)
	Ret[0]/=len
	Ret[1]/=len
	Ret[2]/=len
	Ret[0]*=multiplier
	Ret[1]*=multiplier
	Ret[2]*=multiplier
}

public rotateVectorZ(Float:Vec[3],Float:direction[3],Float:Ret[3]){
	// rotates vector about z-axis
	new Float:tmp[3]
	copyVec(Vec,tmp)
	tmp[2]=0.0
	new Float:dest_len=getVecLen(tmp)
	copyVec(direction,tmp)
	tmp[2]=0.0
	new Float:tmp2[3]
	normalize(tmp,tmp2,dest_len)
	tmp2[2]=Vec[2]
	copyVec(tmp2,Ret)
}

public Float:vectorProduct(Float:Vec1[3],Float:Vec2[3]){
	return Vec1[0]*Vec2[0]+Vec1[1]*Vec2[1]+Vec1[2]*Vec2[2]
}

public copyVec(Float:Vec[3],Float:Ret[3]){
	Ret[0]=Vec[0]
	Ret[1]=Vec[1]
	Ret[2]=Vec[2]
}

public subVec(Float:Vec1[3],Float:Vec2[3],Float:Ret[3]){
	Ret[0]=Vec1[0]-Vec2[0]
	Ret[1]=Vec1[1]-Vec2[1]
	Ret[2]=Vec1[2]-Vec2[2]
}

public addVec(Float:Vec1[3],Float:Vec2[3]){
	Vec1[0]+=Vec2[0]
	Vec1[1]+=Vec2[1]
	Vec1[2]+=Vec2[2]
}

// Temporary Entities ------------------------------------------------------------------------------
// there is a list of much more temp entities at: http://djeyl.net/forum/index.php?s=80ec5b9163006b5cbd0a51dd198e563a&act=Attach&type=post&id=290870
// all messages are sent with MSG_ONE_UNRELIABLE flag to avoid overflow in case of very low esp_timer setting and much targets

public make_TE_IMPLOSION(id,Float:Vec[3]){
	message_begin(MSG_ONE_UNRELIABLE ,SVC_TEMPENTITY,{0,0,0},id) //message begin
	write_byte(14)
	write_coord(floatround(Vec[0])) // start position
	write_coord(floatround(Vec[1]))
	write_coord(floatround(Vec[2]))
	write_byte(255) // radius
	write_byte(10) // count
	write_byte(floatround(get_cvar_float("esp_timer")*10)) // life in 0.1's
	message_end()
}

public make_TE_BEAMPOINTS(id,Float:Vec1[3],Float:Vec2[3],width,target_team,brightness){
	message_begin(MSG_ONE_UNRELIABLE ,SVC_TEMPENTITY,{0,0,0},id) //message begin
	write_byte(0)
	write_coord(floatround(Vec1[0])) // start position
	write_coord(floatround(Vec1[1]))
	write_coord(floatround(Vec1[2]))
	write_coord(floatround(Vec2[0])) // end position
	write_coord(floatround(Vec2[1]))
	write_coord(floatround(Vec2[2]))
	write_short(laser) // sprite index
	write_byte(3) // starting frame
	write_byte(0) // frame rate in 0.1's
	write_byte(floatround(get_cvar_float("esp_timer")*10)) // life in 0.1's
	write_byte(width) // line width in 0.1's
	write_byte(0) // noise amplitude in 0.01's
	write_byte(0)
	write_byte(255)
	write_byte(0)
	write_byte(brightness) // brightness)
	write_byte(0) // scroll speed in 0.1's
	message_end()
}

public make_TE_BEAMENTPOINT(id,Float:target_origin[3],width,target_team){
	message_begin(MSG_ONE_UNRELIABLE,SVC_TEMPENTITY,{0,0,0},id)
	write_byte(1)
	write_short(id)
	write_coord(floatround(target_origin[0]))
	write_coord(floatround(target_origin[1]))
	write_coord(floatround(target_origin[2]))
	write_short(laser)
	write_byte(1)		
	write_byte(1)
	write_byte(floatround(get_cvar_float("esp_timer")*10))
	write_byte(width)
	write_byte(0)
	write_byte(150)
	write_byte(0)
	write_byte(0)
	write_byte(255)
	write_byte(0)
	message_end()
}
