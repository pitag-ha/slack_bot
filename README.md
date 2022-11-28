# Coffeeeeee

Coffee is good. And colleagues are the best.

## What this unikernel does

It sends a message to your Slack channel `$CHANNEL` every other Monday to ask who wants to have a coffee chat this week. It then sends another message on Tuesday containing the necessary info for this week's coffee chats: everyone who's opted in (by reacting to the first message) is randomly matched with someone else who has opted in. The unikernel is smarter than purely random though: it tries to avoid repeats with past matches.

## How to build this unikernel

If you have the right env variables (notice: if they're stored in a file called `config_env.sh`, they'll be set automatically), you can build this coffee chat unikernel via `create.sh unikernel coffee <unix/hvt/virtio>`.

## Accessibility

This bot is currently badly designed in terms of accessibility: the way to interact with the bot, is to react to a Slack message. Not every Slack user can react to a Slack message though. There's an item on the TODO list to improve accessibility (it's marked as highest priority). It's highly appreciated, if anyone wants to pick it up and open a PR! In the meanwhile, the workaround is that users who can't react to Slack messages, can use a bot that reacts for them. For that, open an issue, so that your bot's ID will be turned into your Slack ID when parsing the reactions. Then, you can run the following `curl` command to opt-in:

```
curl -d "channel=<channel_id>" -d "name=hand" -d "timestamp=<time_stamp>" -H "Authorization: Bearer <bot_token>" -X POST https://slack.com/api/reactions.add
```
