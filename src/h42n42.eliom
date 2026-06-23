module%server App = Eliom_registration.App (struct
	let application_name = "h42n42"
	let global_data_path = None
end)

let%server main_service =
	Eliom_service.create
		~path:(Eliom_service.Path [])
		~meth:(Eliom_service.Get Eliom_parameter.unit)
		()

module%client Client = struct
	open Js_of_ocaml

	let now () = (new%js Js.date_now)##getTime /. 1000.0

	let window_width () = float_of_int Dom_html.window##.innerWidth
	let window_height () = float_of_int Dom_html.window##.innerHeight

	(* environment *)
	let toxic_river_height = 50.0
	let hospital_height = 50.0

	(* spawn *)
	let initial_creet_count = 10
	let spawn_interval = 15.0

	(* creet physics and movement *)
	let default_radius = 20.0
	let base_speed = 15.0
	let spawn_speed_mult = 3.0
	let chase_speed_mult = 3.0
	let random_direction_chance = 0.01

	(* infection and sickness *)
	let contamination_chance = 0.02
	let sick_speed_multiplier = 0.85

	(* mutations *)
	let mutation_check_interval = 10.0
	let berserk_chance = 0.1
	let mean_chance = 0.2
	let berserk_max_radius_mult = 4.0
	let berserk_growth_mult = 1.1
	let mean_shrink_mult = 0.85
	let mean_lifetime = 60.0

	(* game loop and difficulty *)
	let loop_dt = 0.02	(* seconds *)
	let supervisor_sleep = 0.1 (* seconds between supervisor() calls *)
	let speed_increase_rate = 0.003

	type state = Healthy | Sick | Berserk | Mean
	
	type creet = {
		id : int;
		mutable x : float;
		mutable y : float;
		mutable vx : float;
		mutable vy : float;
		mutable state : state;
		mutable speed_multiplier : float;
		mutable radius : float;
		mutable dead : bool;
		mutable being_dragged : bool;
		mutable mutation_checked_time : float;
		mutable time_as_mean : float;
		elt : Dom_html.divElement Js.t;
	}
	
	let creets : creet list ref = ref []
	let game_speed_multiplier = ref 1.0
	let is_game_over = ref false
	let next_id = ref 0
	
	let distance creet1 creet2 =
		let dx = creet1.x -. creet2.x in
		let dy = creet1.y -. creet2.y in
		Float.sqrt (dx *. dx +. dy *. dy)

	let check_overlap creet1 creet2 =
		distance creet1 creet2 < creet1.radius +. creet2.radius

	let infect creet =
		if creet.state = Healthy && not creet.being_dragged then begin	(* infect only if is healthy and not being dragged *)
			creet.state <- Sick;
			creet.speed_multiplier <- sick_speed_multiplier;
			creet.mutation_checked_time <- now ();
			creet.elt##.className := Js.string "creet sick"	(* change css style *)
		end

	let heal creet =
		if creet.state = Sick then begin
			creet.state <- Healthy;
			creet.speed_multiplier <- 1.0;
			creet.elt##.className := Js.string "creet healthy"	(* change css style *)
		end

	let remove_creet creet =
		creet.dead <- true;
		creets := List.filter (fun other_creet -> other_creet.id <> creet.id) !creets;
		let parent = creet.elt##.parentNode in
		Js.Opt.iter parent (fun parent_node -> Dom.removeChild parent_node creet.elt)

	let spawn_creet () =
		let id = !next_id in
		incr next_id;
		let radius = default_radius in
		let creet = {
			id;
			x = Random.float (window_width () -. 2. *. radius) +. radius;
			y = Random.float (window_height () -. toxic_river_height -. hospital_height -. 2. *. radius) +. toxic_river_height +. radius;
			vx = (Random.float 2.0 -. 1.0) *. 2.0;
			vy = (Random.float 2.0 -. 1.0) *. 2.0;
			state = Healthy;
			radius;
			speed_multiplier = 1.0;
			dead = false;
			being_dragged = false;
			mutation_checked_time = 0.0;
			time_as_mean = 0.0;
			elt = Eliom_content.Html.To_dom.of_div (Eliom_content.Html.D.div ~a:[Eliom_content.Html.D.a_class ["creet"; "healthy"]] [])
		} in
		let len = Float.sqrt (creet.vx *. creet.vx +. creet.vy *. creet.vy) in		(* PYTHAGORE PYTHAGORE PYTHAGORE PYTHAGORE irl *)
		creet.vx <- (creet.vx /. len) *. spawn_speed_mult;		(* normalize x velocity *)
		creet.vy <- (creet.vy /. len) *. spawn_speed_mult;		(* normalize y velocity *)
		
		let container = Dom_html.document##getElementById (Js.string "creets-container") in		(* get the container element *)
		Js.Opt.iter container (fun node -> Dom.appendChild node creet.elt);		(* add creet to container *)
		
		creets := creet :: !creets; (* add new creet to list *)
		
		(* function to handle mouse events *)
		Lwt.async (fun () ->
			Js_of_ocaml_lwt.Lwt_js_events.mousedowns creet.elt (fun ev _ ->
				Dom.preventDefault ev;
				if creet.state = Berserk || creet.state = Mean then
					Lwt.return ()	(* can't catch mean or berserk *)
				else begin
					creet.being_dragged <- true;	(* start drag *)
					let offset_x = float_of_int ev##.clientX -. creet.x in
					let offset_y = float_of_int ev##.clientY -. creet.y in
					let drag_t = Js_of_ocaml_lwt.Lwt_js_events.mousemoves Dom_html.window (fun ev2 _ ->
						creet.x <- float_of_int ev2##.clientX -. offset_x;
						creet.y <- float_of_int ev2##.clientY -. offset_y;
						creet.elt##.style##.left := Js.string (Printf.sprintf "%.2fpx" creet.x);
						creet.elt##.style##.top := Js.string (Printf.sprintf "%.2fpx" creet.y);
						Lwt.return ()
					) in
					let%lwt _ = Js_of_ocaml_lwt.Lwt_js_events.mouseup Dom_html.window in
					Lwt.cancel drag_t;
					creet.being_dragged <- false;	(* stop drag *)
					if creet.state = Sick && creet.y +. creet.radius > window_height () -. hospital_height then		(* if release in hospital *)
						heal creet;
					Lwt.return ()
				end
			)
		);

		let rec loop () =
			if creet.dead || !is_game_over then
				Lwt.return ()
			else begin
				if not creet.being_dragged then begin

					(* mutation logic *)
					if creet.state = Sick then begin
						let current_time = now () in
						if current_time -. creet.mutation_checked_time >= mutation_check_interval then begin
							creet.mutation_checked_time <- current_time;
							let random_chance = Random.float 1.0 in
							if random_chance < berserk_chance then begin
								creet.state <- Berserk;
								creet.elt##.className := Js.string "creet berserk";	(* change css style *)
							end else if random_chance < mean_chance then begin
								creet.state <- Mean;
								creet.radius <- creet.radius *. mean_shrink_mult;
								creet.elt##.className := Js.string "creet mean";	(* change css style *)
							end
						end
					end;

					if creet.state = Berserk then begin
						let current_time = now () in
						if current_time -. creet.mutation_checked_time >= mutation_check_interval then begin
								creet.mutation_checked_time <- current_time;
								creet.radius <- creet.radius *. berserk_growth_mult;
								if creet.radius >= default_radius *. berserk_max_radius_mult then
									remove_creet creet
						end
					end;

					if creet.state = Mean then begin
						creet.time_as_mean <- creet.time_as_mean +. loop_dt;
						if creet.time_as_mean >= mean_lifetime then
							remove_creet creet
						else begin
								(* chase nearest healthy *)
								let nearest = List.fold_left (fun nearest other ->
									if other.state = Healthy && not other.dead then
										let dist = distance creet other in
										match nearest with
										| None -> Some (other, dist)	(* first iteration *)
										| Some (_, min_d) when dist < min_d -> Some (other, dist)	(* check dist between mean creet and target (other), if closer than current nearest update nearest *)
										| _ -> nearest	(* else keep current nearest *)
									else nearest
								) None !creets in
								match nearest with
								| Some (target, _) ->
										let dx = target.x -. creet.x in
										let dy = target.y -. creet.y in
										let len = Float.sqrt (dx *. dx +. dy *. dy) in
										if len > 0.0 then begin
											creet.vx <- (dx /. len) *. chase_speed_mult;
											creet.vy <- (dy /. len) *. chase_speed_mult;
										end
								| None -> ()	(* no healthy creet found, don't change direction *)
						end
					end;

					(* random direction change *)
					if Random.float 1.0 < random_direction_chance && creet.state <> Mean then begin
						let angle = Random.float (2.0 *. Float.pi) in
						let speed = Float.sqrt (creet.vx *. creet.vx +. creet.vy *. creet.vy) in
						creet.vx <- speed *. cos angle;
						creet.vy <- speed *. sin angle;
					end;

					(* update pos *)
					creet.x <- creet.x +. creet.vx *. base_speed *. loop_dt *. creet.speed_multiplier *. !game_speed_multiplier;
					creet.y <- creet.y +. creet.vy *. base_speed *. loop_dt *. creet.speed_multiplier *. !game_speed_multiplier;

					(* wall collisions *)
					let win_width = window_width () and win_height = window_height () in
					if creet.x -. creet.radius < 0.0 then begin
						creet.x <- creet.radius;
						creet.vx <- -. creet.vx
					end;
					if creet.x +. creet.radius > win_width then begin
						creet.x <- win_width -. creet.radius;
						creet.vx <- -. creet.vx
					end;
					if creet.y -. creet.radius < 0.0 then begin
						creet.y <- creet.radius;
						creet.vy <- -. creet.vy
					end;
					if creet.y +. creet.radius > win_height then begin
						creet.y <- win_height -. creet.radius;
						creet.vy <- -. creet.vy
					end;

					(* toxic river *)
					if creet.y -. creet.radius < toxic_river_height then
						infect creet;
				end;

				(* contagion *)
				if creet.state <> Healthy then begin		(* if not healthy *)
					List.iter (fun other ->		(* list all creets, other = creet being checked *)
						if other.state = Healthy && check_overlap creet other then
							if Random.float 1.0 < contamination_chance then 
								infect other
					) !creets	(* iter over creets *)
				end;

				(* render by updating css of creet's html element *)
				if not creet.dead then begin
					creet.elt##.style##.left := Js.string (Printf.sprintf "%.2fpx" creet.x);	(* update left/right position *)
					creet.elt##.style##.top := Js.string (Printf.sprintf "%.2fpx" creet.y);		(* update top/bottom position *)
					creet.elt##.style##.width := Js.string (Printf.sprintf "%.2fpx" (creet.radius *. 2.0));		(* update width *)
					creet.elt##.style##.height := Js.string (Printf.sprintf "%.2fpx" (creet.radius *. 2.0));	(* update height *)
				end;

				let%lwt () = Js_of_ocaml_lwt.Lwt_js.sleep loop_dt in
				loop ()
			end
		in
		Lwt.async loop

	let start () =
		Random.self_init ();
		for _ = 1 to initial_creet_count do		(* spawn x initial creets *)
			spawn_creet ()
		done;

		(* game supervisor thread *)
		let rec supervisor () =
			if !is_game_over then
				Lwt.return ()
			else begin
				(* check game over *)
				let alive = List.length !creets in
				let healthy = List.length (List.filter (fun creet -> creet.state = Healthy) !creets) in
				if alive = 0 || healthy = 0 then begin
					is_game_over := true;
					let go_div = Dom_html.document##getElementById (Js.string "game-over") in
					Js.Opt.iter go_div (fun node -> node##.style##.display := Js.string "block");
					Lwt.return ()
				end else begin
					game_speed_multiplier := !game_speed_multiplier +. speed_increase_rate;		(* increase game speed *)
					let%lwt () = Js_of_ocaml_lwt.Lwt_js.sleep supervisor_sleep in
					supervisor ()
				end
			end
		in
		Lwt.async supervisor;

		(* spawner thread *)
		let rec spawner () =
			if !is_game_over then
				Lwt.return ()
			else begin
				let%lwt () = Js_of_ocaml_lwt.Lwt_js.sleep spawn_interval in
				let healthy = List.length (List.filter (fun creet -> creet.state = Healthy) !creets) in
				if healthy > 0 && not !is_game_over then
					spawn_creet ();
				spawner ()
			end
		in
		Lwt.async spawner
end

let%server () =
	App.register
		~service:main_service
		(fun () () ->
			let _ = [%client (Client.start () : unit)] in
			let open Eliom_content.Html.D in
			Lwt.return
				(html
						(head (title (txt "H42N42"))
							[css_link ~uri:(make_uri ~service:(Eliom_service.static_dir ()) ["css"; "h42n42.css"]) ()])
						(body [
								div ~a:[a_id "game-board"] [
									div ~a:[a_id "toxic-river"] [];
									div ~a:[a_id "hospital"] [];
									div ~a:[a_id "creets-container"] [];
								];
								div ~a:[a_id "game-over"; a_style "display: none;"] [txt "game over"];
							])))
