open Yojson.Safe
open Yojson.Safe.Util

type http_ctx = {
  ctx : Mimic.ctx;
  alpn_protocol : Mimic.flow -> string option;
  authenticator : (X509.Authenticator.t, [ `Msg of string ]) result;
}

open Lwt.Infix

let post_request ~text ~channel ~ctx ~alpn_protocol ~authenticator =
  let uri = "https://slack.com/api/chat.postMessage" in
  let token = Key_gen.token () in
  let headers =
    [
      ("Content-type", "application/json"); ("Authorization", "Bearer " ^ token);
    ]
  in
  let unserialized_body =
    `Assoc [ ("channel", `String channel); ("text", `String text) ]
  in
  let body = Yojson.Basic.to_string unserialized_body in
  let http_config = Httpaf.Config.default in
  let config = `HTTP_1_1 http_config in
  Http_mirage_client.one_request ~meth:`POST ~config ~headers ~body ~ctx
    ~alpn_protocol ~authenticator uri

let get_request ~ctx ~alpn_protocol ~authenticator uri =
  let token = Key_gen.token () in
  let headers = [ ("Authorization", "Bearer " ^ token) ] in
  let http_config = Httpaf.Config.default in
  let config = `HTTP_1_1 http_config in
  Http_mirage_client.one_request ~meth:`GET ~config ~headers ~ctx ~alpn_protocol
    ~authenticator uri

let write_matches ~http_ctx:{ ctx; alpn_protocol; authenticator } channel output
    =
  post_request ~text:output ~channel ~ctx ~alpn_protocol ~authenticator
  >|= function
  | Error err -> Error (Fmt.str "%a" Mimic.pp_error err)
  | Ok (rsp, body) -> (
      match body with
      | None -> Error "Http request to send opt in message returned no body"
      | Some body when H2.Status.is_successful rsp.status -> (
          try Ok (from_string body) with Yojson.Json_error err -> Error err)
      | _ -> Error (Fmt.str "Error code: %i" (H2.Status.to_code rsp.status)))

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

let get_reactions ~http_ctx:{ ctx; alpn_protocol; authenticator } channel
    db_path =
  let open Lwt.Syntax in
  let* timestamp = Irmin_io.read_timestamp_from_irmin db_path in
  let uri =
    Format.sprintf "https://slack.com/api/reactions.get?channel=%s&timestamp=%s"
      channel timestamp
  in
  get_request ~ctx ~alpn_protocol ~authenticator uri >|= function
  | Error err -> Error (Fmt.str "%a" Mimic.pp_error err)
  | Ok (rsp, body) -> (
      match body with
      | None -> Error "Http request to send opt in message returned no body"
      | Some body when H2.Status.is_successful rsp.status ->
          parse_reactions_response body
      | _ -> Error (Fmt.str "Error code: %i" (H2.Status.to_code rsp.status)))

let parse_ts resp = from_string resp |> member "ts" |> to_string

let write_opt_in_message ~http_ctx:{ ctx; alpn_protocol; authenticator } channel
    =
  let text =
    "Hi <!here>, who wants to pair-program this week? To opt in, react to this \
     message, for example with a :raised_hand::skin-tone-4:"
  in
  post_request ~text ~channel ~ctx ~alpn_protocol ~authenticator >|= function
  | Error err -> Error (Fmt.str "%a" Mimic.pp_error err)
  | Ok (rsp, body) -> (
      match body with
      | None -> Error "Http request to send opt in message returned no body"
      | Some body when H2.Status.is_successful rsp.status -> (
          try Ok (parse_ts body) with Yojson.Json_error err -> Error err)
      | _ -> Error (Fmt.str "Error code: %i" (H2.Status.to_code rsp.status)))
