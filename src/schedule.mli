module Weekday : sig
  type t = [ `Fri | `Mon | `Sat | `Sun | `Thu | `Tue | `Wed ]

  type span = int

  val span_between : allow_zero:bool -> t -> t -> int
  (** Exposed for testing purposes*)
end

module Daytime : sig
  type t = int * int * int
  (** The format of [t] is (hour, minutes, seconds) *)

  val span_between : t -> t -> int
  (** Exposed for testing purposes. [span_between] is negative if the start_time is already past the end_time *)
end

val secs_till : Weekday.t -> Daytime.t -> int
(** Exposed for testing purposes*)

val sleep_till : Weekday.t -> Daytime.t -> unit Lwt.t
(** [sleep_till day time] makes the OS sleep for the number of seconds left
    until the most proximate moment in which it is weekday [day] at [time] o'clock.
    [time] is in UTC. *)
