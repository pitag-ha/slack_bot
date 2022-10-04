(lang dune 2.7)

(name slack_bot)

(generate_opam_files true)

(authors
 "Gargi Sharma <gs051095@gmail.com>"
 "Sonja Heinze <sonjaleaheinze@gmail.com>")

(source
 (github gs0510/slack_bot))

(package
 (name slack_bot)
 (depends
  ppx_deriving_yojson
  lwt
  yojson
  irmin-unix
  cohttp-lwt-unix
  mirage-time-unix
  ptime
  mirage-clock-unix))
