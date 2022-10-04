(* open Lwt.Syntax *)

module Client
    (HTTP : Http_mirage_client.S)
    (Time : Mirage_time.S)
    (Clock : Mirage_clock.PCLOCK)
    (Random : Mirage_random.S) =
struct
  let start ctx _time clock _random =
    let http_ctx =
      {
        Http_requests.ctx;
        alpn_protocol = HTTP.alpn_protocol;
        authenticator = HTTP.authenticator;
      }
    in
    let test_case =
      {
        Types.channel = Key_gen.channel ();
        db_path = "irmin/pairing_bot_testing";
        num_iter = 1000;
      }
    in
    let module Main_loop = Slack_bot.Main_loop (HTTP) (Time) (Clock) (Random) in
    Main_loop.main ~clock ~http_ctx test_case
end
