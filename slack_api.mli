type http_ctx = {
  ctx : Mimic.ctx;
  alpn_protocol : Mimic.flow -> string option;
  authenticator : (X509.Authenticator.t, [ `Msg of string ]) result;
  channel : string;
  token : string;
}

val write_opt_in_message : http_ctx:http_ctx -> (string, string) result Lwt.t
(** Writes the opt-in message to the slack channel in [http_ctx]. In case of
    success, the returned string represents the timestamp of the message. *)

val get_reactions :
  timestamp:string -> http_ctx:http_ctx -> (string list, string) result Lwt.t
(** Given a [timestamp], [get_reactions] fetches the list of slack user ids of
    the folks who've reacted to the message sent at the time of the timestamp
    (in the channel in [http_ctx]) *)

val write_matches :
  http_ctx:http_ctx -> Matches.t -> (Yojson.Safe.t, string) result Lwt.t
(** Writes a message containing the matches to the slack channel in [http_ctx] *)
