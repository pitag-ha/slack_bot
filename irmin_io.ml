open Lwt.Infix
module Store = Irmin_mirage_git.Mem.KV.Make (Irmin.Contents.String)

let info message () =
  Store.Info.v ~author:"Sonja Heinze & Gargi Sharma" ~message 0L

type matches = { matched : string list list } [@@deriving yojson]
type timestamp = string

let get_old_matches db_path =
  let open Lwt.Syntax in
  let git_config = Irmin_git.config ~bare:true db_path in
  let* epoch_list =
    Store.Repo.v git_config >>= Store.main >>= fun t ->
    (* todo: also handle the case of directories with an error message*)
    Store.list t [ "matches" ] >|= List.map (fun (step, _) -> step)
  in
  let* matches =
    Store.Repo.v git_config >>= Store.main >>= fun t ->
    Lwt_list.map_s (fun epoch -> Store.get t [ "matches"; epoch ]) epoch_list
  in
  Lwt.return (List.combine epoch_list matches)

let write_matches_to_irmin ~get_current_time our_match db_path =
  let git_config = Irmin_git.config ~bare:true db_path in
  let yojson_string_to_print =
    Yojson.Safe.to_string (matches_to_yojson { matched = our_match })
  in
  let current_time = get_current_time () in
  let (year, month, day), _ = Ptime.to_date_time current_time in
  let message = Printf.sprintf "Matches %i/%i/%i" day month year in
  Store.Repo.v git_config >>= Store.main >>= fun t ->
  let current_time_s = Ptime.to_rfc3339 current_time in
  Store.set_exn t
    [ "matches"; current_time_s ]
    yojson_string_to_print ~info:(info message)

let write_timestamp_to_irmin timestamp db_path =
  let git_config = Irmin_git.config ~bare:true db_path in
  let message = "last opt-in message's timestamp" in
  Store.Repo.v git_config >>= Store.main >>= fun t ->
  Store.set_exn t [ "last_timestamp" ] timestamp ~info:(info message)

let read_timestamp_from_irmin db_path =
  let git_config = Irmin_git.config ~bare:true db_path in
  Store.Repo.v git_config >>= Store.main >>= fun t ->
  Store.get t [ "last_timestamp" ]
