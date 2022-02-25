open Yojson.Basic
open Yojson.Basic.Util

let config =
  let config_file =
    try Sys.argv.(1) with _ -> failwith "Missing argument: config."
  in
  from_file config_file

let test_channel = member "test_channel_id" config |> to_string

open Types

let test_case =
  { channel = test_channel; db_path = "irmin/new"; num_iter = 1000 }

let write_matches_to_irmin_and_slack our_match case =
  let open Lwt.Syntax in
  let output = Match.to_string our_match in
  let () = Printf.printf "%s" output in
  let* result = Http_requests.write_matches case.channel output in
  match result with
  | Ok _ -> Irmin_io.write_matches_to_irmin our_match case.db_path
  | Error e ->
      Format.printf "Http Request to write to slack failed with error : %s" e;
      Lwt.return ()

let write_opt_in_to_irmin_and_slack case =
  let open Lwt.Syntax in
  let* result = Http_requests.write_opt_in_message case.channel in
  match result with
  | Ok ts -> Irmin_io.write_timestamp_to_irmin ts case.db_path
  | Error e ->
      Format.printf "Http Request to write to slack failed with error : %s" e;
      Lwt.return ()

let main case =
  let open Lwt.Syntax in
  let* () = Schedule.sleep_till `Mon (10, 00, 0) in
  let* () = write_opt_in_to_irmin_and_slack case in
  let* () = Schedule.sleep_till `Tue (10, 00, 0) in
  let* most_optimum = Match.get_most_optimum case in
  write_matches_to_irmin_and_slack most_optimum case

let () =
  while true do
    Lwt_main.run (main test_case)
  done
