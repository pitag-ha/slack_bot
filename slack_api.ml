open Yojson.Safe
open Yojson.Safe.Util

type http_ctx = {
  ctx : Mimic.ctx;
  alpn_protocol : Mimic.flow -> string option;
  authenticator : (X509.Authenticator.t, [ `Msg of string ]) result;
  channel : string;
  token : string;
}

open Lwt.Infix

let post_request ~http_ctx:{ ctx; alpn_protocol; authenticator; channel; token }
    text =
  let uri = "https://slack.com/api/chat.postMessage" in
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

let get_request
    ~http_ctx:{ ctx; alpn_protocol; authenticator; channel = _; token } uri =
  let headers = [ ("Authorization", "Bearer " ^ token) ] in
  let http_config = Httpaf.Config.default in
  let config = `HTTP_1_1 http_config in
  Http_mirage_client.one_request ~meth:`GET ~config ~headers ~ctx ~alpn_protocol
    ~authenticator uri

let write_matches ~http_ctx matches =
  let msg =
    ":coffee: *Virtual Coffee* :coffee:\n :camel: Matches this week:\n"
    ^ Matches.to_string matches
    ^ "\n\
      \ :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: \
       :sheepy: :mirageos: :sheepy:\n\
       Note: I don't initiate a conversation. So, please, don't forget to \
       reach out to your coffee-chat partner(s):writing_hand:\n\
      \   Have some nice coffee chats! \n"
  in
  post_request ~http_ctx msg >|= function
  | Error err -> Error (Fmt.str "%a" Mimic.pp_error err)
  | Ok (rsp, body) -> (
      match body with
      | None -> Error "Http request to send opt in message returned no body"
      | Some body when H2.Status.is_successful rsp.status -> (
          try Ok (from_string body) with Yojson.Json_error err -> Error err)
      | _ -> Error (Fmt.str "Error code: %i" (H2.Status.to_code rsp.status)))

let parse_response resp =
  try
    Ok
      (let msg = from_string resp |> Util.(member "message") in
       match Util.member "reactions" msg with
       | `Null ->
           (* TODO: when there's 0 or no reactions, send a message along the lines of "No/only one opt-in this time. Do we want to pause the coffee-chats for some time?" instead
              of the usual slack message to the channel *)
           []
       | json -> (
           let reactions = Util.to_list json in
           let original =
             List.sort_uniq String.compare
               (List.map Util.to_string
                  (List.map Util.(member "users") reactions |> Util.flatten))
           in
           match Key_gen.curl_user_id () with
           | None -> original
           | Some curl_user_id ->
               let bot_id = Key_gen.bot_id () in
               List.map
                 (fun id -> if String.equal id bot_id then curl_user_id else id)
                 original))
  with Yojson.Json_error err -> Error err

let get_reactions ~timestamp ~http_ctx =
  let uri =
    Format.sprintf "https://slack.com/api/reactions.get?channel=%s&timestamp=%s"
      http_ctx.channel timestamp
  in
  get_request ~http_ctx uri >|= function
  | Error err -> Error (Fmt.str "%a" Mimic.pp_error err)
  | Ok (rsp, body) -> (
      match body with
      | None -> Error "Http request to send opt in message returned no body"
      | Some body when H2.Status.is_successful rsp.status -> parse_response body
      | _ -> Error (Fmt.str "Error code: %i" (H2.Status.to_code rsp.status)))

let parse_ts resp = from_string resp |> member "ts" |> to_string

let write_opt_in_message ~http_ctx =
  let text =
    ":coffee: *Virtual Coffee* :coffee:\n\
    \ Hi everyone,\n\
    \ Who wants to have a coffee-chat this week? To opt in, react to this \
     message, for example with a :raised_hand::skin-tone-4:"
  in
  post_request ~http_ctx text >|= function
  | Error err -> Error (Fmt.str "%a" Mimic.pp_error err)
  | Ok (rsp, body) -> (
      match body with
      | None -> Error "Http request to send opt in message returned no body"
      | Some body when H2.Status.is_successful rsp.status -> (
          try Ok (parse_ts body) with Yojson.Json_error err -> Error err)
      | _ -> Error (Fmt.str "Error code: %i" (H2.Status.to_code rsp.status)))
