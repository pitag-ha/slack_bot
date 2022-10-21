# Coffeeeeee

Coffee is good. And colleagues are the best.

If you have the right env variables (notice: if they're stored in a file called `config_env.sh`, they'll be set automatically), you can build this coffee chat unikernel via `create.sh unikernel coffee <unix/hvt/virtio>`.

What this unikernel does: it sends a message to your Slack channel `$CHANNEL` every Monday to ask who wants to have a coffee chat this week. It then sends another message on Tuesday containing the necessary info for this week's coffee chats: everyone who's opted in (by reacting to the first message) is randomly matched with someone else who has opted in. The unikernel is smarter than purely random though: it tries to avoid repeats with past matches.
