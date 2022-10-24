type t = string list list [@@deriving yojson]
type db_entry = { matched : t } [@@deriving yojson]

let upcast matches = { matched = matches }
let downcast { matched = matches } = matches
let to_db_entry matches = db_entry_to_yojson @@ upcast matches

let of_db_entry entry =
  match db_entry_of_yojson entry with
  | Ok res -> downcast res
  | Error e ->
      Printf.eprintf "Data base entry couldn't be parsed: %s\n%!" e;
      exit 1

module Score_machine = struct
  type t = (string * string, int) Hashtbl.t

  let order_pair uid1 uid2 = if uid1 < uid2 then (uid1, uid2) else (uid2, uid1)

  let update_key uid1 uid2 tbl value =
    let pair = order_pair uid1 uid2 in
    match Hashtbl.find_opt tbl pair with
    | Some num_matches -> Hashtbl.replace tbl pair (num_matches + value)
    | None -> Hashtbl.add tbl pair value

  let get_score uid1 uid2 tbl =
    let pair = order_pair uid1 uid2 in
    match Hashtbl.find_opt tbl pair with
    | Some num_matches -> num_matches
    | None -> 0

  let single_match_score ~current_time epoch =
    let value, _, _ = Ptime.of_rfc3339 epoch |> Result.get_ok in
    let value = Ptime.to_float_s value in
    let day = 86400. in
    (* TODO: the scores should depend on the number of people opting in:
       if very few people are opting in, the most important is to avoid repeats from last week. *)
    if (current_time -. value) /. day <= 9. then 50
    else if (current_time -. value) /. day <= 16. then 5
    else if (current_time -. value) /. day <= 28. then 3
    else if (current_time -. value) /. day <= 56. then 2
    else 0

  (* TODO: make the following two functions somehow reasonable!!!! xD *)
  let get ~current_time ~old_matches =
    let tbl = Hashtbl.create 256 in
    List.iter
      (fun (epoch, matches) ->
        let value = single_match_score ~current_time epoch in
        List.iter
          (fun current_match ->
            match List.length current_match with
            | 2 ->
                update_key (List.nth current_match 0) (List.nth current_match 1)
                  tbl value
            | 3 ->
                update_key (List.nth current_match 0) (List.nth current_match 1)
                  tbl value;
                update_key (List.nth current_match 1) (List.nth current_match 2)
                  tbl value;
                update_key (List.nth current_match 0) (List.nth current_match 2)
                  tbl value
            | _ ->
                Printf.printf
                  "The match in the db with epoch %s is neither a pair nor a \
                   triple. It has been ignored.\n%!"
                  epoch)
          matches)
      old_matches;
    tbl

  let compute ~score_machine:tbl matches =
    List.fold_left
      (fun score current_match ->
        let pair_score =
          match List.length current_match with
          | 2 ->
              get_score (List.nth current_match 0) (List.nth current_match 1)
                tbl
          | 3 ->
              get_score (List.nth current_match 0) (List.nth current_match 1)
                tbl
              + get_score (List.nth current_match 1) (List.nth current_match 2)
                  tbl
              + get_score (List.nth current_match 0) (List.nth current_match 2)
                  tbl
          | _ -> failwith "not accounted for!"
        in
        score + pair_score)
      0 matches
end

let to_string (matches_list : t) =
  List.map (List.map (fun member -> "<@" ^ member ^ ">")) matches_list
  |> List.fold_left
       (fun acc current_match ->
         acc ^ String.concat " with " current_match ^ "\n")
       ""

let shuffle ~get_random_int list =
  let nd =
    List.map
      (fun c ->
        let random = get_random_int () in
        (random, c))
      list
  in
  let sond = List.sort compare nd in
  List.map snd sond

let rec pair_up acc members =
  match members with
  | [] -> acc
  | [ last ] -> (
      (* if we want to avoid triples:
         match acc with
            | [] -> [ [ last ] ]
            | fst :: tl ->
                [ last; List.nth fst 0 ] :: [ last; List.nth fst 1 ] :: tl)
                (* [fst] being of length 2 is an invariant of [pair_up] *)
      *)
      match acc with [] -> [ [ last ] ] | fst :: tl -> (last :: fst) :: tl)
  | f :: s :: tl -> pair_up ([ f; s ] :: acc) tl

let generate ~num_iter ~get_random_int ~score_machine ~opt_ins : t Lwt.t =
  match opt_ins with
  | [] -> Lwt.return [ [] ]
  | [ only_member ] -> Lwt.return [ [ only_member ] ]
  | [ first; second ] -> Lwt.return [ [ first; second ] ]
  | opt_ins ->
      let rec loop i best_match best_score =
        if i = num_iter then
          let _ = Printf.printf "\n Number iterations: %d \n%!" i in
          best_match
        else
          let new_match = opt_ins |> shuffle ~get_random_int |> pair_up [] in
          let new_score = Score_machine.compute ~score_machine new_match in
          match new_score with
          | 0 ->
              let _ = Printf.printf "\n Number iterations: %d \n%!" i in
              new_match
          | _ ->
              if new_score < best_score then loop (i + 1) new_match new_score
              else loop (i + 1) best_match best_score
      in
      let first_match = opt_ins |> shuffle ~get_random_int |> pair_up [] in
      Lwt.return
        (loop 1 first_match (Score_machine.compute ~score_machine first_match))
