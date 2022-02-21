open Lwt.Infix
open Yojson.Basic.Util
module Git_store = Irmin_unix.Git.FS.KV (Irmin.Contents.String)

let info message =
  Irmin_unix.info ~author:"Sonja Heinze & Gargi Sharma" "%s" message

type matches = { matched : string list list } [@@deriving yojson]

type timestamp = string

let get_old_matches db_path =
  let open Lwt.Syntax in
  let git_config = Irmin_git.config ~bare:true db_path in
  let* epoch_list =
    Git_store.Repo.v git_config >>= Git_store.master >>= fun t ->
    (* todo: also handle the case of directories with an error message*)
    Git_store.list t [ "matches" ] >|= List.map (fun (step, _) -> step)
  in
  let* matches =
    Git_store.Repo.v git_config >>= Git_store.master >>= fun t ->
    Lwt_list.map_s
      (fun epoch -> Git_store.get t [ "matches"; epoch ])
      epoch_list
  in
  Lwt.return (List.combine epoch_list matches)

let write_matches_to_irmin our_match db_path =
  let git_config = Irmin_git.config ~bare:true db_path in
  let yojson_string_to_print =
    Yojson.Safe.to_string (matches_to_yojson { matched = our_match })
  in
  let tm = Unix.time () |> Unix.gmtime in
  let message =
    Printf.sprintf "Matches %i/%i/%i" tm.tm_mday (tm.tm_mon + 1)
      (tm.tm_year + 1900)
  in
  Git_store.Repo.v git_config >>= Git_store.master >>= fun t ->
  Git_store.set_exn t
    [ "matches"; string_of_float (Unix.time ()) ]
    yojson_string_to_print ~info:(info message)

let write_timestamp_to_irmin timestamp db_path =
  let git_config = Irmin_git.config ~bare:true db_path in
  let message = "last opt-in message's timestamp" in
  Git_store.Repo.v git_config >>= Git_store.master >>= fun t ->
  Git_store.set_exn t [ "last_timestamp" ] timestamp ~info:(info message)

let read_timestamp_from_irmin db_path =
  let git_config = Irmin_git.config ~bare:true db_path in
  Git_store.Repo.v git_config >>= Git_store.master >>= fun t ->
  Git_store.get t [ "last_timestamp" ]
