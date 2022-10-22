type t
(** A value of type [t] contains the combination of all matches of one coffee
    chat round *)

val to_string : t -> string
val to_db_entry : t -> Yojson.Safe.t
val of_db_entry : Yojson.Safe.t -> t

module Score_machine : sig
  type matches

  type t
  (** Used to compute a "score" for a potential new match, based on all matches
      in the past. Scores are then minimized to avoid repeating the same
      matches. *)

  val get : current_time:float -> old_matches:(string * matches) list -> t
  (** Get a score machine instance *)

  val compute : score_machine:t -> matches -> int
  (** Given a score machine instance and a combination of matches, compute the
      score of that combination of matches. The higher the score, the more and
      most recent are the repeats with past matches; i.e. the higher the score,
      the worst. *)
end
with type matches := t

val generate :
  num_iter:int ->
  get_random_int:(unit -> int) ->
  score_machine:Score_machine.t ->
  opt_ins:string list ->
  t Lwt.t
(** Generates [num_iter] combinations of matches between all [opt_ins] and
    chooses the combination with the lowest score, i.e. the one with the least
    (and least recent) repeats of past matches. *)
