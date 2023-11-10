extends Spatial

const key_dist = 200

# Open field parameters:
# There is a scaling factor that I don't really understand relative to the spatial transform in the 
# 3d tscn explorer. The origin is shared, but on the explorer the max is 1.5 and the min is -1.5
# on the goggles, the min is -0.75 and the max is 0.75
const track_length = 1.5
const scene_duration = 1800 # Max duration of the scene
const trial_duration = 60 # Max duration of each trial
const scene_name = "barronBehaviour"
const reward_dur = 0.05 # Duration to open liquid reward valve)
const num_reps = 40 # Max number of trials 
const reward_xloc = 0 # Location of reward (start wall = -0.5, end wall = 0.5) 0 on 3d explorer 
const reward_zloc = 0.5 # Location of reward (start wall = -0.5, end wall = 0.5) 0.5 on 3d explorer
const min_start_distance = 0.75 # Minimum distance the mouse can start from the reward
const reward_range = 0.15 # Maximum distance to the reward before a reward is given
const after_reward_delay = 3 # Time after a reward is given before new trial starts
const reward_rate = 1.0 # Fraction of trials which are rewarded (randomly)
const guaranteed_rewards = 3 # Number of beginning trials to guarantee rewards

# Eye parameters
const inter_eye_distance = 0.01
const head_radius = 0.04  # Must be large enough to keep eye cameras from getting too close to walls
const eye_pitch = 10  # Degrees from the horizontal
const eye_yaw = 45  # Degrees away from the head yaw

# Movement parameters
const frames_per_second = 60.0
const thrust_gain = -0.01 #meters per step
const slip_gain = 0.01 #meters per step
const yaw_gain = 5 #degrees per step
const mouse_gain = 0.0135

# Viewport nodes
onready var lefthead = get_node("HeadKinBody/Control/HBoxContainer/ViewportContainer/TextureRect/Viewport/LeftEyeBody")
onready var righthead = get_node("HeadKinBody/Control/HBoxContainer/ViewportContainer2/TextureRect/Viewport/RightEyeBody")
onready var lefteye = get_node("HeadKinBody/Control/HBoxContainer/ViewportContainer/TextureRect/Viewport/LeftEyeBody/LeftEyePivot")
onready var righteye = get_node("HeadKinBody/Control/HBoxContainer/ViewportContainer2/TextureRect/Viewport/RightEyeBody/RightEyePivot")
onready var colorrect = get_node("HeadKinBody/Control/HBoxContainer/ViewportContainer/ColorRect")
onready var fpslabel = get_node("HeadKinBody/Control/HBoxContainer/ViewportContainer2/Label")

# Head/eye position variables
var head_yaw = 0 # Degrees; 0 points along -z; 90 points to +x
var head_thrust = 0 # +points to -z
var head_slip = 0 # +points to +x
var head_x = 0
var head_z = 0
var head_y = 0
var head_yaw_angle = 0
var LeftEyeDirection = Vector3.ZERO # Direction the left eye is pointing
var RightEyeDirection = Vector3.ZERO 

# Logging/saving stuff
var current_rep = 1
var rewarded = 0
var reward_trial = 1
var rewarded_frame = 0
var reward_out = 0
var lick_in = 0
var distance_to_reward = 0
var times := [] # Timestamps of frames rendered in the last second
var fps := 0 # Frames per second
var current_frame = 0
var dataNames = ['head_yaw', 'head_thrust', 'head_slip', 'head_x', 'head_z', 'head_yaw_angle', 'reward_out', 'lick_in', 'ms_now']
var dataArray := []
var dataLog := []
var timestamp = "_"
var ms_start := OS.get_ticks_msec()
var ms_now := OS.get_ticks_msec()


# Called when the node enters the scene tree for the first time.
func _ready():
	var td = OS.get_datetime() # time dictionary
	ms_start = OS.get_ticks_msec()
	timestamp = String(td.year) + "_" + String(td.month) + "_" + String(td.day) + "_" + String(td.hour) + "_" + String(td.minute) + "_" + String(td.second)

	# Head positions
	randomize()
	head_y = 0.01 + head_radius
	head_yaw_angle = randf()*360
	head_x = track_length*(randf()-0.5)
	head_z = track_length*(randf()-0.5)
	distance_to_reward = sqrt(((head_x-reward_xloc)*(head_x-reward_xloc)) + ((head_z-reward_zloc)*(head_z-reward_zloc)))
	while (distance_to_reward<min_start_distance):
		head_x = track_length*(randf()-0.5)
		head_z = track_length*(randf()-0.5)
		distance_to_reward = sqrt(((head_x-reward_xloc)*(head_x-reward_xloc)) + ((head_z-reward_zloc)*(head_z-reward_zloc)))
		
	rewarded = 0
	reward_trial = (randf()<=reward_rate) || (current_rep<=guaranteed_rewards)
	if reward_trial:
		print("rep " + String(current_rep))
	else:
		print("rep " + String(current_rep) + " (no reward)")
	
	#input setup
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	#calculate fps (method 2)
	ms_now = OS.get_ticks_msec() - ms_start
	times.append(ms_now)
	while times.size() > 0 and times[0] <= ms_now - 1000:
		times.pop_front() # Remove frames older than 1 second in the `times` array
	fps = times.size()
	current_frame += 1
	
	#calculate head position
	head_yaw_angle += mouse_gain*yaw_gain*head_yaw
	head_z += mouse_gain*(thrust_gain*head_thrust*cos(deg2rad(head_yaw_angle)) + slip_gain*head_slip*sin(deg2rad(head_yaw_angle)))
	head_x += mouse_gain*(-thrust_gain*head_thrust*sin(deg2rad(head_yaw_angle)) + slip_gain*head_slip*cos(deg2rad(head_yaw_angle)))
	#fpslabel.text = str(head_x) 

	if (current_frame % 10) == 0:
		print("Distance to reward: " + String(distance_to_reward))
		print("Head_x", String(head_x))
		print("Head_z", String(head_z))
		print("\n")
	
	#keep head inside of linear track
	if head_z>((track_length/2)-head_radius):
		head_z = (track_length/2)-head_radius
	if head_z<(-(track_length/2)+head_radius):
		head_z = -(track_length/2)+head_radius
	if head_x>((track_length/2)-head_radius):
		head_x = (track_length/2)-head_radius
	if head_x<(-(track_length/2)+head_radius):
		head_x = -(track_length/2)+head_radius
		
	#translate body position
	righthead.translation.z = head_z
	righthead.translation.x = head_x
	righthead.translation.y = head_y
	lefthead.translation.z = head_z
	lefthead.translation.x = head_x
	lefthead.translation.y = head_y
	
	#translate eyes relative to body
	lefteye.translation.z = head_z - inter_eye_distance*sin(deg2rad(head_yaw_angle))
	lefteye.translation.x = head_x - inter_eye_distance*cos(deg2rad(head_yaw_angle))
	righteye.translation.z = head_z + inter_eye_distance*sin(deg2rad(head_yaw_angle))
	righteye.translation.x = head_x + inter_eye_distance*cos(deg2rad(head_yaw_angle))
	
	#rotate eyes relative to body
	lefteye.rotation_degrees.y = -head_yaw_angle+eye_yaw
	lefteye.rotation_degrees.x = eye_pitch
	righteye.rotation_degrees.y = -head_yaw_angle-eye_yaw
	righteye.rotation_degrees.x = eye_pitch
	
	#control color button based on current position
	distance_to_reward = sqrt(((head_x-reward_xloc)*(head_x-reward_xloc)) + ((head_z-reward_zloc)*(head_z-reward_zloc)))
	if reward_trial && (distance_to_reward<=reward_range) && rewarded==0:
		#for using xinput rumble output
		Input.start_joy_vibration(0,1,1,reward_dur)
		colorrect.color = Color(1, 1, 1)
		rewarded = 1
		reward_out = 1
		rewarded_frame = current_frame
	else: 
		if reward_trial && (reward_out==1) && ((current_frame-rewarded_frame)>=(reward_dur*frames_per_second)):
			reward_out = 0
			colorrect.color = Color(0, 0, 0)
	
	#log data
	dataArray = [head_yaw, head_thrust, head_slip, head_x, head_z, head_yaw_angle, reward_out, lick_in, ms_now]
	for i in range(dataArray.size()):
		dataLog.append(dataArray[i])
	
	#update text label
#	fpslabel.text = str(fps) + " FPS" 
	fpslabel.text = str(lick_in) 
#	fpslabel.text = ""
	
	#reset inputs
	head_thrust = 0
	head_slip = 0
	head_yaw = 0
	
	#next trial
	if (rewarded && (current_frame-rewarded_frame)>=(after_reward_delay*frames_per_second)) || (current_frame > trial_duration*frames_per_second):
		save_logs(current_rep,dataLog,dataNames) #save current logged data to a new file
		dataLog = [] #clear saved data
		current_frame = 1
		current_rep += 1
		if (current_rep>num_reps):
			get_tree().quit() 
		else:
			head_yaw_angle = randf()*360
			head_x = track_length*(randf()-0.5)
			head_z = track_length*(randf()-0.5)
			distance_to_reward = sqrt(((head_x-reward_xloc)*(head_x-reward_xloc)) + ((head_z-reward_zloc)*(head_z-reward_zloc)))
			while distance_to_reward<min_start_distance:
				head_x = track_length*(randf()-0.5)
				head_z = track_length*(randf()-0.5)
				distance_to_reward = sqrt(((head_x-reward_xloc)*(head_x-reward_xloc)) + ((head_z-reward_zloc)*(head_z-reward_zloc)))
			rewarded = 0
			reward_trial = randf()<=reward_rate || (current_rep<=guaranteed_rewards)
			if reward_trial:
				print("rep " + String(current_rep))
			else:
				print("rep " + String(current_rep) + " (no reward)")

	
func _input(ev):
	if ev is InputEventKey and ev.is_pressed():
		if ev.scancode == KEY_ESCAPE:
			get_tree().quit() 
		if ev.scancode == KEY_UP:
			head_thrust += key_dist
		if ev.scancode == KEY_DOWN:
			head_thrust -= key_dist
		if ev.scancode == KEY_RIGHT:
			head_yaw += key_dist
		if ev.scancode == KEY_LEFT:
			head_yaw -= key_dist

			
	if ev is InputEventMouseMotion:
		head_yaw += ev.relative.x
		head_thrust += ev.relative.y
		
	if ev is InputEventMouseButton:
		if ev.is_pressed():
			if ev.button_index == BUTTON_WHEEL_UP:
				head_slip += 1
			if ev.button_index == BUTTON_WHEEL_DOWN:
				head_slip -= 1
			
	if ev is InputEventJoypadMotion:
		if ev.get_axis()==2:
			lick_in = round(1000*ev.get_axis_value());
		else:
			print("Unexpected button pressed: ",ev.get_button_index(),", ",Input.get_joy_button_string(ev.get_button_index()))
		


func save_logs(current_rep,dataLog,dataNames):
	var file = File.new()
	var numColumns = dataNames.size()
	var numRows = dataLog.size()/numColumns
	var n = 0
	if (file.open("res://logs//" + timestamp + "_" + scene_name + "_rep" + String(current_rep) + "_godotlogs.txt", File.WRITE)== OK):
		for i in range(numColumns):
			file.store_string(String(dataNames[i]))
			if i<(numColumns-1):
				file.store_string(",")
		file.store_string("\r")
		for l in range(numRows):
			for i in range(numColumns):
				file.store_string(String(dataLog[n]))
				if i<(numColumns-1):
					file.store_string(",")
				n = n+1
			file.store_string("\r")
		file.close()
