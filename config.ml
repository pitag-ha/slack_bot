open Mirage

type http_client = HTTP_client

let http_client = typ HTTP_client

let token =
  let doc = Key.Arg.info ~doc:"slack bot token" [ "token" ] in
  Key.(create "token" Arg.(required string doc))

let channel =
  let doc =
    Key.Arg.info ~doc:"ID of the channel to send the messages to" [ "channel" ]
  in
  Key.(create "channel" Arg.(required string doc))

let client =
  let packages =
    [
      package "cohttp-mirage";
      package "duration";
      package "yojson";
      package "ptime";
      (* package "irmin"; *)
      (* package "irmin-mirage"; *)
      package "irmin-mirage-git";
      (* package "git-mirage"; *)
      (* package "git-cohttp-mirage"; *)
      package ~sublibs:[] "ppx_deriving";
      package ~sublibs:[] "ppx_deriving_yojson";
    ]
  in
  main ~keys:[ key token; key channel ] ~packages "Unikernel.Client"
  @@ http_client @-> time @-> pclock @-> random @-> job

let stack = generic_stackv4v6 default_network
let dns = generic_dns_client stack

let http_client =
  let connect _ modname = function
    | [ _time; _pclock; _tcpv4v6; ctx ] ->
        Fmt.str {ocaml|%s.connect %s|ocaml} modname ctx
    | _ -> assert false
  in
  let packages = [ package "httpaf"; package "h2"; package "paf" ] in
  impl ~packages ~connect "Http_mirage_client.Make"
    (time @-> pclock @-> tcpv4v6 @-> git_client @-> http_client)

let http_client =
  let happy_eyeballs =
    git_happy_eyeballs stack dns (generic_happy_eyeballs stack dns)
  in
  http_client $ default_time $ default_posix_clock $ tcpv4v6_of_stackv4v6 stack
  $ happy_eyeballs

let () =
  (* let res_dns = resolver_dns stack in
     let conduit = conduit_direct ~tls:true stack in *)
  let job =
    [
      client $ http_client $ default_time $ default_posix_clock $ default_random;
    ]
  in
  register "friendly-unikernel" job
