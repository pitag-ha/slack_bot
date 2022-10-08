open Mirage

type http_client = HTTP_client

let http_client = typ HTTP_client

let token =
  let doc = Key.Arg.info ~doc:"slack bot token" [ "token" ] in
  Key.(create "token" Arg.(required string doc))

let remote =
  let doc = Key.Arg.info ~doc:"Remote Git repository." [ "r"; "remote" ] in
  Key.(create "remote" Arg.(required string doc))

let channel =
  let doc =
    Key.Arg.info ~doc:"ID of the channel to send the messages to" [ "channel" ]
  in
  Key.(create "channel" Arg.(required string doc))

let ssh_key =
  let doc =
    Key.Arg.info ~doc:"Private ssh key (rsa:<seed> or ed25519:<b64-key>)."
      [ "ssh-key" ]
  in
  Key.(create "ssh-key" Arg.(opt (some string) None doc))

let ssh_authenticator =
  let doc =
    Key.Arg.info ~doc:"SSH host key authenticator." [ "ssh-authenticator" ]
  in
  Key.(create "ssh_authenticator" Arg.(opt (some string) None doc))

let tls_authenticator =
  let doc =
    Key.Arg.info ~doc:"TLS host authenticator." [ "tls-authenticator" ]
  in
  Key.(create "https_authenticator" Arg.(opt (some string) None doc))

let nameservers =
  let doc = Key.Arg.info ~doc:"Nameserver." [ "nameserver" ] in
  Key.(create "nameserver" Arg.(opt_all string doc))

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
  main
    ~keys:[ key token; key channel; key remote; key nameservers ]
    ~packages "Unikernel.Client"
  @@ http_client @-> time @-> pclock @-> random @-> git_client @-> job

let http_client =
  let connect _ modname = function
    | [ _time; _pclock; _tcpv4v6; ctx ] ->
        Fmt.str {ocaml|%s.connect %s|ocaml} modname ctx
    | _ -> assert false
  in
  let packages = [ package "httpaf"; package "h2"; package "paf" ] in
  impl ~packages ~connect "Http_mirage_client.Make"
    (time @-> pclock @-> tcpv4v6 @-> git_client @-> http_client)

let stack = generic_stackv4v6 default_network
let dns = generic_dns_client ~nameservers stack

let git, http =
  let happy_eyeballs =
    git_happy_eyeballs stack dns (generic_happy_eyeballs stack dns)
  in
  let tcp = tcpv4v6_of_stackv4v6 stack in
  ( merge_git_clients
      (git_tcp tcp happy_eyeballs)
      (merge_git_clients
         (git_ssh ~key:ssh_key ~authenticator:ssh_authenticator tcp
            happy_eyeballs)
         (git_http ~authenticator:tls_authenticator tcp happy_eyeballs)),
    http_client $ default_time $ default_posix_clock
    $ tcpv4v6_of_stackv4v6 stack $ happy_eyeballs )

let () =
  let job =
    [
      client $ http $ default_time $ default_posix_clock $ default_random $ git;
    ]
  in
  register "coffee-chats" job
