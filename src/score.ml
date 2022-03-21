open Yojson.Basic
open Yojson.Basic.Util

let parsing_json all_matches_json = to_list all_matches_json |> List.map to_list

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

let single_match_score epoch =
  let now = Unix.time () in
  let value = float_of_string epoch in
  let day = 86400. in
  if (now -. value) /. day <= 9. then 10
  else if (now -. value) /. day <= 16. then 5
  else if (now -. value) /. day <= 28. then 3
  else if (now -. value) /. day <= 56. then 2
  else 1

(* TODO: make the following two functions somehow reasonable!!!! xD *)
let construct_hashmap all_old_matches =
  let tbl = Hashtbl.create 256 in
  List.iter
    (fun (epoch, match_json) ->
      let value = single_match_score epoch in
      from_string match_json |> member "matched" |> parsing_json
      |> List.iter (fun current_match ->
             match List.length current_match with
             | 2 ->
                 update_key
                   (List.nth current_match 0 |> to_string)
                   (List.nth current_match 1 |> to_string)
                   tbl value
             | 3 ->
                 update_key
                   (List.nth current_match 0 |> to_string)
                   (List.nth current_match 1 |> to_string)
                   tbl value;
                 update_key
                   (List.nth current_match 1 |> to_string)
                   (List.nth current_match 2 |> to_string)
                   tbl value;
                 update_key
                   (List.nth current_match 0 |> to_string)
                   (List.nth current_match 2 |> to_string)
                   tbl value
             | _ -> Printf.printf "The match in the db with epoch %s is neither a pair nor a triple. It has been ignored." epoch))
    all_old_matches;
  tbl

let compute_total tbl matches =
  List.fold_left
    (fun score current_match ->
      let pair_score =
        match List.length current_match with
        | 2 ->
            get_score (List.nth current_match 0) (List.nth current_match 1) tbl
        | 3 ->
            get_score (List.nth current_match 0) (List.nth current_match 1) tbl
            + get_score (List.nth current_match 1) (List.nth current_match 2)
                tbl
            + get_score (List.nth current_match 0) (List.nth current_match 2)
                tbl
        | _ -> failwith "not accounted for!"
      in
      score + pair_score)
    0 matches
