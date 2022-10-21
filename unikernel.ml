open Lwt.Syntax

let write_matches_to_irmin_and_slack ~get_current_time ~http_ctx matches irmin =
  let* result = Slack_api.write_matches ~http_ctx matches in
  match result with
  | Ok _ ->
      let epoch = get_current_time () in
      let* res = Irmin_io.write_matches ~epoch matches irmin in
      let () =
        match res with
        | Ok () -> Format.printf "Updating db should have worked!\n"
        | Error (`Msg e) -> Format.eprintf "Error trying to update db: %s" e
      in
      Lwt.return ()
  | Error e ->
      Format.printf "Http Request to write to slack failed with error : %s" e;
      Lwt.return ()

let write_opt_in_to_irmin_and_slack ~http_ctx irmin =
  let* result = Slack_api.write_opt_in_message ~http_ctx in
  match result with
  | Ok ts ->
      let* res = Irmin_io.write_timestamp ~ts irmin in
      let () =
        match res with
        | Ok () -> Format.printf "Updating db should have worked!\n"
        | Error (`Msg e) -> Format.eprintf "Error trying to update db: %s" e
      in
      Lwt.return ()
  | Error e ->
      Format.printf "Http Request to write to slack failed with error : %s\n%!"
        e;
      Lwt.return ()

let rec main ~clock ~sleep_till ~sleep_for_ns ~get_current_time ~get_random_int
    ~git_ctx ~http_ctx ~num_iter =
  (* let () = Logs.set_level (Some Debug) in *)
  let is_test = Key_gen.test () in
  let* irmin = Irmin_io.connect_store ~git_ctx in
  let* () = Irmin_io.pull irmin in
  let* () = if is_test then Lwt.return () else sleep_till `Mon (09, 00, 0) in
  let* () = write_opt_in_to_irmin_and_slack ~http_ctx irmin in
  let* () =
    if is_test then sleep_for_ns 60000000000L else sleep_till `Tue (09, 00, 0)
  in
  let* score_machine =
    let+ old_matches = Irmin_io.read_matches irmin in
    let current_time = get_current_time () |> Ptime.to_float_s in
    Matches.Score_machine.get ~current_time ~old_matches
  in
  let* timestamp = Irmin_io.read_timestamp irmin in
  let* reactions = Slack_api.get_reactions ~timestamp ~http_ctx in
  (* FIXME*)
  let opt_ins =
    match reactions with
    | Error e ->
        Printf.eprintf "Error trying to fetch opt-ins: %s" e;
        []
    | Ok opt_ins -> opt_ins
  in
  let* new_matches =
    Matches.generate ~num_iter ~get_random_int ~score_machine ~opt_ins
  in
  let* () =
    write_matches_to_irmin_and_slack ~get_current_time ~http_ctx new_matches
      irmin
  in
  main ~clock ~sleep_till ~sleep_for_ns ~get_current_time ~get_random_int
    ~http_ctx ~git_ctx ~num_iter

module Client
    (HTTP : Http_mirage_client.S)
    (Time : Mirage_time.S)
    (Clock : Mirage_clock.PCLOCK)
    (Random : Mirage_random.S) (_ : sig end) =
struct
  let start ctx _time clock _random git_ctx =
    let http_ctx =
      {
        Slack_api.ctx;
        alpn_protocol = HTTP.alpn_protocol;
        authenticator = HTTP.authenticator;
        channel = Key_gen.channel ();
        token = Key_gen.token ();
      }
    in
    let num_iter = Key_gen.num_iter () in
    let sleep_till, sleep_for_ns =
      let module Schedule = Schedule.Sleep (Time) in
      (Schedule.sleep_till, Schedule.sleep_for_ns)
    in
    let get_current_time () = Clock.now_d_ps clock |> Ptime.v in
    let get_random_int () =
      (*FIXME??: why 4 and why 0? *)
      Cstruct.HE.get_uint32 (Random.generate 4) 0 |> Int32.to_int |> abs
    in
    main ~clock ~sleep_till ~sleep_for_ns ~get_current_time ~get_random_int
      ~http_ctx ~git_ctx ~num_iter
end
