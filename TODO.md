# TODO

- (highest priority): make the bot sustainably accessible (currently, accessibility is only given via a "small hack").
    concretely, add communication with the bot:
    - [join]: triggers opting in. it's the same as reacting to the opt-in message
    - [leave]: triggers opting back out again (i.e. one has opted in, but wants to opt-out again). it's the same as un-reacting to the opt-int message
    - [status]: shows the current status of the bot; i.e.
        - "next opt-in message will be on ..."
        - "we're currently in opt-in phase. so far, the people who have opted in are ..."
- new feature: write a private message to each matched couple/triple proposing a time for their chat
- new feature: avoid matching two people at the same office
- use upstream `httpaf` (it's released now) instead of "vendoring" it into http_mirage_client.{ml,mli}
- improve `create.sh`. to start with, write it in OCaml
- have a look at the TODOs and FIXMEs in the code
- improve the logging and error messages and make them more coherent
