open Yojson.Safe
open Yojson.Safe.Util

let config =
  let config_file =
    try Sys.argv.(1) with _ -> failwith "Missing argument: config."
  in
  from_file config_file

(* TODO: Take these values are argument, read them from the main module. *)
let token = member "token" config |> to_string

let bot_id = member "bot_id" config |> to_string

open Lwt.Infix

let write_matches channel output =
  let uri = Uri.of_string "https://slack.com/api/chat.postMessage" in
  let headers =
    Cohttp.Header.of_list
      [
        ("Content-type", "application/json");
        ("Authorization", "Bearer " ^ token);
      ]
  in
  let body =
    `Assoc [ ("channel", `String channel); ("text", `String output) ]
  in
  let serialized_body = Yojson.Basic.to_string body in
  Cohttp_lwt_unix.Client.post ~headers ~body:(`String serialized_body) uri
  >>= fun (rsp, body) ->
  Cohttp_lwt.Body.to_string body >|= fun body' ->
  match Cohttp.Code.(code_of_status rsp.status |> is_success) with
  | false -> Error body'
  | true -> (
      try Ok (from_string body') with Yojson.Json_error err -> Error err)

let parse_reactions_response resp =
  try
    Ok
      (List.sort_uniq String.compare
         (List.map Util.to_string
            (List.map
               Util.(member "users")
               (from_string resp
               |> Util.(member "message")
               |> Util.(member "reactions")
               |> Util.to_list)
            |> Util.flatten)))
  with Yojson.Json_error err -> Error err

let get_reactions channel db_path =
  let open Lwt.Syntax in
  let* timestamp = Irmin_io.read_timestamp_from_irmin db_path in
  let uri =
    Uri.of_string
      (Format.sprintf
         "https://slack.com/api/reactions.get?channel=%s&timestamp=%s" channel
         timestamp)
  in
  let headers =
    Cohttp.Header.of_list [ ("Authorization", "Bearer " ^ token) ]
  in
  Cohttp_lwt_unix.Client.get ~headers uri >>= fun (rsp, body) ->
  Cohttp_lwt.Body.to_string body >|= fun body' ->
  match Cohttp.Code.(code_of_status rsp.status |> is_success) with
  | false -> Error body'
  | true -> parse_reactions_response body'

let parse_ts resp = from_string resp |> member "ts" |> to_string

let write_opt_in_message channel =
  let uri = Uri.of_string "https://slack.com/api/chat.postMessage" in
  let message =
    "Hi <!here>, who wants to pair-program this week? To opt in, react to this \
     message, for example with a :raised_hand::skin-tone-4:"
  in
  let headers =
    Cohttp.Header.of_list
      [
        ("Content-type", "application/json");
        ("Authorization", "Bearer " ^ token);
      ]
  in
  let body =
    `Assoc [ ("channel", `String channel); ("text", `String message) ]
  in
  let serialized_body = Yojson.Basic.to_string body in
  Cohttp_lwt_unix.Client.post ~headers ~body:(`String serialized_body) uri
  >>= fun (rsp, body) ->
  Cohttp_lwt.Body.to_string body >|= fun body' ->
  match Cohttp.Code.(code_of_status rsp.status |> is_success) with
  | false ->
      print_endline body';
      Error body'
  | true -> ( try Ok (parse_ts body') with Yojson.Json_error err -> Error err)
