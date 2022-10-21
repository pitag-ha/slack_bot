type t
(*** A value of type [t] contains all matches of one coffee chat round *)

val to_string : t -> string
val to_db_entry : t -> Yojson.Safe.t
val of_db_entry : Yojson.Safe.t -> t

module Score_machine : sig
  type matches
  type t
  (*** Used to compute a "score" for a potential new match, based on all matches in the past. Scores are then minimized to avoid repeating the same matches. *)

  val get : current_time:float -> old_matches:(string * matches) list -> t
  val compute : score_machine:t -> matches -> int
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
    repeats of past matches. *)
