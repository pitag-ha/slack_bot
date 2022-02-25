module Weekday = struct
  type t = [ `Mon | `Tue | `Wed | `Thu | `Fri | `Sat | `Sun ]

  type span = int

  let to_int = function
    | `Mon -> 0
    | `Tue -> 1
    | `Wed -> 2
    | `Thu -> 3
    | `Fri -> 4
    | `Sat -> 5
    | `Sun -> 6

  let span_between ~allow_zero first last =
    let first = to_int first in
    let last = to_int last in
    if last > first then last - first
    else if first = last && allow_zero then 0
    else 7 - first + last

  let span_to_secs span = span * 24 * 60 * 60
end

module Daytime = struct
  type t = int * int * int

  let time_to_secs (h, min, sec) = sec + (min * 60) + (h * 60 * 60)

  let span_between start_time end_time =
    time_to_secs end_time - time_to_secs start_time
end

let secs_till schedule_day schedule_time =
  let now = Pclock.now_d_ps () |> Ptime.v in
  let _, (current_time, _) = Ptime.to_date_time now in
  let secs_till_schedule_time =
    Daytime.span_between current_time schedule_time
  in
  let allow_zero = secs_till_schedule_time > 0 in
  let today = Ptime.weekday now in
  let days_till_schedule_day =
    Weekday.(span_between ~allow_zero today schedule_day)
  in
  Weekday.span_to_secs days_till_schedule_day + secs_till_schedule_time

let sleep_till day time =
  let nsecs_to_sleep =
    secs_till day time |> Int64.of_int |> Int64.mul 1_000_000_000L
  in
  Time.sleep_ns nsecs_to_sleep
