open Yojson.Basic.Util

let () = Random.init (int_of_float (Unix.time ()))

let shuffle list =
  let nd =
    List.map
      (fun c ->
        let random = Random.bits () in
        (random, c))
      list
  in
  let sond = List.sort compare nd in
  List.map snd sond

let rec pair_up_list (acc : string list list) (members : string list) :
    string list list =
  match members with
  | [] -> acc
  | [ last ] -> (
      match acc with [] -> [ [ last ] ] | fst :: tl -> (last :: fst) :: tl)
  | f :: s :: tl -> pair_up_list ([ f; s ] :: acc) tl

let to_string (matches_list : string list list) =
  (List.map (List.map (fun member -> "<@" ^ member ^ ">")) matches_list
  |> List.fold_left
       (fun acc current_match ->
         acc ^ String.concat " with " current_match ^ "\n")
       ":camel: Matches this week:\n")
  ^ "\n\
    \ :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: :sheepy: \
     :sheepy:\n\
     Note: I don't initiate a conversation. You'll have to reach out to your \
     pair-programming partner(s) by yourself:writing_hand:\n\
    \   Have some nice pair-programming sessions! \n"

let get_most_optimum (case : Types.case_record) =
  let open Lwt.Syntax in
  let* members = Http_requests.get_reactions case.channel case.db_path in
  match members with
  | Error _ -> assert false
  | Ok [] -> Lwt.return [ [] ]
  | Ok [ only_member ] -> Lwt.return [ [ only_member ] ]
  | Ok [ first; second ] -> Lwt.return [ [ first; second ] ]
  | Ok members ->
      let* old_matches = Irmin_io.get_old_matches case.db_path in
      let tbl = Score.construct_hashmap old_matches in
      let rec loop num_iter best_match best_score =
        if num_iter = case.num_iter then
          let _ = Printf.printf "\n Number iterations: %d \n" num_iter in
          best_match
        else
          let new_match = members |> shuffle |> pair_up_list [] in
          let new_score = Score.compute_total tbl new_match in
          match new_score with
          | 0 ->
              let _ = Printf.printf "\n Number iterations: %d \n" num_iter in
              new_match
          | _ ->
              if new_score < best_score then
                loop (num_iter + 1) new_match new_score
              else loop (num_iter + 1) best_match best_score
      in
      let first_match = members |> shuffle |> pair_up_list [] in
      Lwt.return (loop 1 first_match (Score.compute_total tbl first_match))
