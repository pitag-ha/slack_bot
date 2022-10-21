type t
(* Represents a full Irmin db: in-memory store plus remote counter-part *)

val connect_store : git_ctx:Mimic.ctx -> t Lwt.t
(** Connects to the db *)

val pull : t -> unit Lwt.t
(** Pulls the db data from the persistent remote Irmin store into the in-memory
    store *)

val write_matches :
  epoch:Ptime.t -> Matches.t -> t -> (unit, [> Rresult.R.msg ]) result Lwt.t
(** Writes an [epoch] -> [matches] entry to the in-memory Irmin store; pushes
    the in-memory store to the remote store. *)

val read_matches : t -> (string * Matches.t) list Lwt.t
(** Reads all matches in history from the in-memory store. The output list
    contains one item per past coffee round. Each round is represented as a pair
    (epoch, matches). *)

val write_timestamp : ts:string -> t -> (unit, [> Rresult.R.msg ]) result Lwt.t
(** Writes a timestamp to the in-memory Irmin store; pushes the in-memory store
    to the remote store. This functionality is meant to store the timestamp of
    the last slack opt-in message, which is needed to query reactions to that
    message later *)

val read_timestamp : t -> string Lwt.t
(** Reads the last timestamp in the in-memory Irmin store. That timestamp is
    meant to be the timestamp of the last opt-in slack message. *)
