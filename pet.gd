extends Node2D

var pet_sprite: AnimatedSprite2D
var dragging = false
var drag_offset = Vector2i.ZERO
var exact_pos = Vector2.ZERO

var state = "sit"
var next_state = ""
var direction = 1 #1 for right, -1 for left
var velocity_x = 0.0
var velocity_y = 0.0
var is_falling = false
var ground_y = 0.0

var behavior_timer: Timer

func _ready():
	#transperent windows
	get_tree().get_root().transparent_bg = true
	var win = get_window()
	win.transparent = true
	win.borderless = true
	win.always_on_top = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	pet_sprite = AnimatedSprite2D.new()
	var frames = SpriteFrames.new()
	
	#folder names
	var animations = {
		"backsit": "BACKSIT",
		"backsit_to_stand": "BACKSIT_TO_STAND",
		"body_stretch": "BODY_STRETCH",
		"drop_to_stand": "DROP_TO_STAND",
		"grab": "GRAB",
		"grab_to_drop": "GRAB_TO_DROP",
		"run": "RUN",
		"sit": "SIT",
		"sit_to_standup": "SIT_TO_STANDUP",
		"stand": "STAND",
		"stand_to_backsit": "STAND_TO_BACKSIT",
		"standup_to_sit": "STANDUP_TO_SIT",
		"walk": "WALK"
	}
	
	for anim_name in animations.keys():
		var folder = animations[anim_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 4) # fps
		
		if anim_name in ["stand", "sit", "walk", "run", "grab", "backsit"]:
			frames.set_animation_loop(anim_name, true)
		else:
			frames.set_animation_loop(anim_name, false)
			
		var dir = DirAccess.open("res://assets/" + folder)
		if dir:
			var files = []
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with(".import"):
					files.append(file_name)
				file_name = dir.get_next()
			
			files.sort_custom(func(a, b): 
				return _extract_num(a) < _extract_num(b)
			)
			
			for f in files:
				var tex = load("res://assets/" + folder + "/" + f)
				if tex:
					frames.add_frame(anim_name, tex)
					
	pet_sprite.sprite_frames = frames
	add_child(pet_sprite)
	
	#handleanimation speeds dynamically
	frames.set_animation_speed("grab_to_drop", 3)
	frames.set_animation_speed("drop_to_stand", 6)
	frames.set_animation_speed("walk", 2)
	frames.set_animation_speed("run", 6)
	
	pet_sprite.animation_finished.connect(_on_animation_finished)
	
	#tesize window exactly to the maximum pet size,place sprite at center
	var max_w = 128
	var max_h = 128
	for anim in frames.get_animation_names():
		for i in range(frames.get_frame_count(anim)):
			var t = frames.get_frame_texture(anim, i)
			if t:
				var s = t.get_size()
				if s.x > max_w: max_w = s.x
				if s.y > max_h: max_h = s.y
				
	get_window().size = Vector2i(max_w, max_h)
	pet_sprite.position = Vector2(max_w, max_h) / 2.0
	
	behavior_timer = Timer.new()
	behavior_timer.one_shot = true
	behavior_timer.timeout.connect(update_behavior)
	add_child(behavior_timer)
	
	place_randomly()
	
	change_state("sit")
	behavior_timer.start(3.0)
	
	# placing cat on top of task bar
	var topmost_timer = Timer.new()
	topmost_timer.one_shot = false
	topmost_timer.wait_time = 1.0
	topmost_timer.timeout.connect(_enforce_topmost)
	add_child(topmost_timer)
	topmost_timer.start()

func _extract_num(file_name: String) -> int:
	var regex = RegEx.new()
	regex.compile("\\d+")
	var result = regex.search(file_name)
	if result:
		return result.get_string().to_int()
	return 0

func _enforce_topmost():
	var win = get_window()
	#always on top
	win.always_on_top = true
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, win.get_window_id())

func place_randomly():
	var screen_rect = DisplayServer.screen_get_usable_rect()
	var win = get_window()
	var win_size = win.size
	
	var y_offset = 53 
	ground_y = screen_rect.end.y - win_size.y + y_offset
	
	var random_x = randi_range(screen_rect.position.x, screen_rect.end.x - win_size.x)
	exact_pos = Vector2(random_x, ground_y)
	win.position = exact_pos

func change_state(new_state):
	state = new_state
	pet_sprite.play(state)

func _on_animation_finished():
	#run → standup_to_sit → sleep
	if state == "standup_to_sit":
		next_state = ""
		change_state("sit")
		return

	if next_state != "":
		change_state(next_state)
		next_state = ""
	elif state == "grab_to_drop":
		pass #for collision with ground
	elif state == "drop_to_stand":
		change_state("stand")
	elif state == "sit_to_standup":
		change_state("stand")
	elif state == "body_stretch":
		change_state("stand")
	elif state == "stand_to_backsit":
		change_state("backsit")
	elif state == "backsit_to_stand":
		change_state("stand")

func update_behavior():
	if dragging or is_falling:
		behavior_timer.start(1.0)
		return

	if next_state != "":
		behavior_timer.start(randf_range(3.0, 7.0))
		return

	#weights: sit=0.20, walk=0.20, run=0.15, stand=0.15, turn=0.10, sleep=0.10, backsit=0.10
	var r = randf()
	var new_intent = ""
	if r < 0.20:
		new_intent = "sit"
	elif r < 0.40:
		new_intent = "walk"
	elif r < 0.55:
		new_intent = "run"
	elif r < 0.70:
		new_intent = "stand"
	elif r < 0.80:
		new_intent = "turn"
	else:
		new_intent = "backsit"

	if new_intent == "turn":
		direction *= -1
		var sub_choices = ["walk", "run", "stand", "sit", "backsit"]
		new_intent = sub_choices[randi() % sub_choices.size()]
	
	var current_is_down = (state == "sit")
	var current_is_standing = (state in ["stand", "walk"])
	var current_is_backsit = (state == "backsit")
	var wants_to_stand = (new_intent in ["walk", "run", "stand"])
	
	#backsit transitions
	if current_is_standing and new_intent == "backsit":
		change_state("stand_to_backsit")
		next_state = ""
	elif current_is_backsit and wants_to_stand:
		change_state("backsit_to_stand")
		next_state = new_intent
	elif current_is_backsit and new_intent == "sit":
		change_state("backsit_to_stand")
		next_state = "stand"
	elif current_is_down and new_intent == "backsit":
		change_state("sit_to_standup")
		next_state = "stand"
	elif current_is_down and wants_to_stand:
		change_state("sit_to_standup")
		next_state = new_intent
	elif current_is_standing and new_intent == "sit":
		change_state("standup_to_sit")
		next_state = new_intent
	#run → walk → stand
	elif state == "run" and new_intent == "stand":
		# Slow down to walk first, then stop
		change_state("walk")
		velocity_x = randf_range(30.0, 60.0) * direction
		behavior_timer.start(randf_range(1.0, 2.5))
		return
	elif state == "run" and new_intent == "walk":
		change_state("walk")
		velocity_x = randf_range(30.0, 60.0) * direction
		behavior_timer.start(randf_range(2.0, 4.0))
		return
	else:
		change_state(new_intent)
	
	if new_intent == "walk" or next_state == "walk":
		velocity_x = randf_range(30.0, 60.0) * direction
	elif new_intent == "run" or next_state == "run":
		velocity_x = randf_range(120.0, 180.0) * direction
	
	if new_intent == "backsit":
		behavior_timer.start(randf_range(4.0, 10.0))
	else:
		behavior_timer.start(randf_range(3.0, 7.0))

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_offset = Vector2i(get_window().size.x / 2, 25)
			
			exact_pos = DisplayServer.mouse_get_position() - drag_offset
			get_window().position = exact_pos
			
			change_state("grab")
			next_state = ""
			velocity_x = 0
			velocity_y = 0
		else:
			dragging = false
			exact_pos = Vector2(get_window().position)
			change_state("grab_to_drop")
			next_state = ""
			is_falling = true
			behavior_timer.start(1.0)

func _process(delta):
	pet_sprite.flip_h = direction == 1

	if dragging:
		#mouse is moving while dragging - reset idle timer
		exact_pos = DisplayServer.mouse_get_position() - drag_offset
		get_window().position = exact_pos
		return

	var win = get_window()
	var current_screen = win.current_screen
	var screen_rect = DisplayServer.screen_get_usable_rect(current_screen)
	
	var y_offset = 53
	ground_y = screen_rect.end.y - win.size.y + y_offset
	
	if exact_pos.y < ground_y:
		velocity_y += 400.0 * delta #gravity
		if is_falling and velocity_y > 300.0:
			velocity_y = 300.0 #terminal velocity
	else:
		velocity_y = 0
		exact_pos.y = ground_y
		
	if state == "walk":
		if abs(velocity_x) < 1.0:
			velocity_x = randf_range(30.0, 60.0) * direction
		exact_pos.x += velocity_x * delta
	elif state == "run":
		if abs(velocity_x) < 1.0:
			velocity_x = randf_range(120.0, 180.0) * direction
		exact_pos.x += velocity_x * delta
		
	exact_pos.y += velocity_y * delta
	
	#screen edge collisions
	if exact_pos.x <= screen_rect.position.x:
		exact_pos.x = screen_rect.position.x
		direction = 1
		velocity_x = randf_range(30.0, 60.0) if state != "run" else randf_range(120.0, 180.0)
		#don't interrupt fall/grab animations at the edge
		if not is_falling and state not in ["walk", "run", "grab_to_drop", "grab", "drop_to_stand"]:
			change_state("walk")
			next_state = ""
	elif exact_pos.x >= screen_rect.end.x - win.size.x:
		exact_pos.x = screen_rect.end.x - win.size.x
		direction = -1
		velocity_x = -(randf_range(30.0, 60.0) if state != "run" else randf_range(120.0, 180.0))
		#don't interrupt fall/grab animations at the edge
		if not is_falling and state not in ["walk", "run", "grab_to_drop", "grab", "drop_to_stand"]:
			change_state("walk")
			next_state = ""
		
	var hit_ground = false
	if exact_pos.y >= ground_y:
		exact_pos.y = ground_y
		hit_ground = true
		
	win.position = Vector2i(roundi(exact_pos.x), roundi(exact_pos.y))
	
	if hit_ground and is_falling:
		is_falling = false
		change_state("drop_to_stand")
		next_state = "stand"
