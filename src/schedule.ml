(* Time at which the message should be sent in UTC *)
let schedule_time = (20, 00, 0)

let weekday_to_int = function
  | `Mon -> 0
  | `Tue -> 1
  | `Wed -> 2
  | `Thu -> 3
  | `Fri -> 4
  | `Sat -> 5
  | `Sun -> 6

let time_to_secs (h, min, sec) = sec + (min * 60) + (h * 60 * 60)

let time_since_last_message now schedule_day =
  let weekday = Ptime.weekday now in
  let _current_date, (current_time, _) = Ptime.to_date_time now in
  (* secs_passed is negative if we are before schedule time *)
  let secs_passed = time_to_secs current_time - time_to_secs schedule_time in
  if weekday = schedule_day && secs_passed < 0 then -secs_passed
  else
    let days_passed =
      let days_since_schedule_day =
        (weekday_to_int weekday - weekday_to_int schedule_day + 7) mod 7
      in
      60 * 60 * 24 * days_since_schedule_day
    in
    let full_week = 60 * 60 * 24 * 7 in
    full_week - days_passed - secs_passed

let sleep_secs secs =
  let nsecs_of_secs s = Int64.(mul (of_int s) 1_000_000_000L) in
  Time.sleep_ns (nsecs_of_secs secs)

let sleep_till_next_opt_in () =
  let schedule_day = `Mon in
  let now = Pclock.now_d_ps () |> Ptime.v in
  sleep_secs (time_since_last_message now schedule_day)

let sleep_till_next_matches () =
  let schedule_day = `Tue in
  let now = Pclock.now_d_ps () |> Ptime.v in
  sleep_secs (time_since_last_message now schedule_day)
