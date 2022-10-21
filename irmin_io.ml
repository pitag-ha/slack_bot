open Lwt.Infix
open Lwt.Syntax
module Store = Irmin_mirage_git.Mem.KV.Make (Irmin.Contents.String)
module Sync = Irmin.Sync.Make (Store)

type t = { branch : Store.t; remote : Irmin.remote }

let connect_store ~git_ctx =
  let config = Irmin_git.config "." in
  let remote, branch =
    match String.split_on_char '#' (Key_gen.remote ()) with
    | [ remote; branch ] -> (remote, branch)
    | _ -> (Key_gen.remote (), "main")
  in
  Store.Repo.v config >>= fun repository ->
  Store.of_branch repository branch >>= fun active_branch ->
  Lwt.return
    { branch = active_branch; remote = Store.remote ~ctx:git_ctx remote }

let pull { branch; remote } =
  Sync.pull branch remote `Set >>= function
  | Error err ->
      Fmt.failwith "Couldn't pull from irmin store: %a" Sync.pp_pull_error err
  | Ok (`Empty | `Head _) -> Lwt.return ()

let push { branch; remote } =
  Sync.push branch remote >>= function
  | Ok `Empty ->
      print_endline "Pushing to upstream irmin was possibly useless.";
      Lwt.return_ok ()
  | Ok (`Head _commit1) ->
      print_endline "Pushed something probably useful to upstream irmin";
      Lwt.return_ok ()
  | Error err ->
      Format.eprintf ">>> %a.\n%!" Sync.pp_push_error err;
      Lwt.return_error (Rresult.R.msgf "%a" Sync.pp_push_error err)

let update_db ~dir ~content ~irmin ~info =
  let* () = Store.set_exn irmin.branch dir content ~info in
  push irmin

let info message () =
  Store.Info.v ~author:"Sonja Heinze & Gargi Sharma & Enguerrand Decorne"
    ~message 0L

let write_matches ~epoch our_match irmin =
  let content = Yojson.Safe.to_string (Matches.to_db_entry our_match) in
  let (year, month, day), _ = Ptime.to_date_time epoch in
  let message = Printf.sprintf "Matches %i/%i/%i" day month year in
  let epoch_s = Ptime.to_rfc3339 epoch in
  update_db ~dir:[ "matches"; epoch_s ] ~content ~irmin ~info:(info message)

let write_timestamp ~ts irmin =
  let message = "last opt-in message's timestamp" in
  update_db ~dir:[ "last_timestamp" ] ~content:ts ~irmin ~info:(info message)

let read_matches { branch; _ } =
  let* epoch_list =
    Store.list branch [ "matches" ] >|= List.map (fun (step, _) -> step)
  in
  let* matches_json =
    Lwt_list.map_s
      (fun epoch -> Store.get branch [ "matches"; epoch ])
      epoch_list
  in
  let matches =
    List.map
      (fun s -> Matches.of_db_entry @@ Yojson.Safe.from_string s)
      matches_json
  in
  Lwt.return (List.combine epoch_list matches)

let read_timestamp { branch; _ } = Store.get branch [ "last_timestamp" ]
