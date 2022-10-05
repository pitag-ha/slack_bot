(* open Yojson.Basic
      open Yojson.Basic.Util

   let config =
      let config_file =
        try Sys.argv.(1) with _ -> failwith "Missing argument: config."
      in
      from_file config_file *)

(* let test_channel = member "test_channel_id" config |> to_string
   let real_channel = member "real_channel" config |> to_string *)

(* open Lwt.Syntax *)
open Types

(* let real_case =
   {
     channel = real_channel;
     db_path = "irmin/pairing_bot";
     num_iter = 100000000;
   } *)

module Main_loop
    (HTTP : Http_mirage_client.S)
    (Time : Mirage_time.S)
    (Clock : Mirage_clock.PCLOCK)
    (Random : Mirage_random.S) =
struct
  let get_random_int () =
    Cstruct.HE.get_uint32 (Random.generate 4) 0 |> Int32.to_int |> abs

  let write_matches_to_irmin_and_slack ~get_current_time ~http_ctx
      our_match case irmin =
    let open Lwt.Syntax in
    let output = Match.to_string our_match in
    let () = Printf.printf "%s" output in
    let* result = Http_requests.write_matches ~http_ctx case.channel output in
    match result with
    | Ok _ ->
        (* FIXME: do some error handling*)
        let* _ = Irmin_io.write_matches_to_irmin ~get_current_time our_match irmin in
        Lwt.return ()
    | Error e ->
        Format.printf "Http Request to write to slack failed with error : %s" e;
        Lwt.return ()

  let write_opt_in_to_irmin_and_slack ~http_ctx case irmin =
    let open Lwt.Syntax in
    let* result = Http_requests.write_opt_in_message ~http_ctx case.channel in
    match result with
    | Ok ts ->
        print_endline "http request successful\n";
        Irmin_io.write_timestamp_to_irmin ts irmin
    | Error e ->
        Format.printf
          "Http Request to write to slack failed with error : %s\n%!" e;
        Lwt.return ()

  let rec main ~clock ~git_ctx ~http_ctx case =
    let open Lwt.Syntax in
    (* let () = Logs.set_level (Some Debug) in *)
    let* (active_branch, remote) as irmin = Irmin_io.connect_store ~git_ctx in
    let* () = Irmin_io.pull active_branch remote in
    let get_current_time () = Clock.now_d_ps clock |> Ptime.v in

    let module Schedule = Schedule.Sleep (Time) in
    let open Lwt.Syntax in
    let* () = Schedule.sleep_till `Mon (09, 00, 0) in
    let* () = write_opt_in_to_irmin_and_slack ~http_ctx case irmin in
    let* () = Schedule.sleep_till `Tue (15, 20, 0) in
    let* most_optimum = Match.get_most_optimum ~get_random_int ~get_current_time ~http_ctx case irmin in
    let* () = write_matches_to_irmin_and_slack ~get_current_time ~http_ctx most_optimum case irmin in
    main ~clock ~http_ctx ~git_ctx case
end
