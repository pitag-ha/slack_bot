{ config, pkgs, ... }:

let
  slack_bot = pkgs.callPackage ../. {};

in

{
  imports = [ # It's a VM running on the cloud so be small
    <nixpkgs/nixos/modules/profiles/headless.nix>
    <nixpkgs/nixos/modules/profiles/minimal.nix>
  ];

  options = with pkgs.lib; { bot_config = mkOption { type = types.path; }; };

  config = {
    networking.hostName = "slack-bot";
    time.timeZone = "Europe/Paris";

    # Make the image smaller
    security.polkit.enable = false; # Disable polkit
    services.udisks2.enable = false; # Closure is 200Mb and pulls polkit

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;
    services.openssh.permitRootLogin = "prohibit-password";

    # TODO: Asserts that it's not empty
    # users.users.root.openssh.authorizedKeys.keys

    # A user to run the bot as
    users.users.slack-bot = { isNormalUser = true; };

    # Don't allow users to be added/modified imperatively
    users.mutableUsers = false;

    # Service running the bot
    systemd.services.slack-bot = {
      enable = true;
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${slack_bot}/bin/slack_bot "${config.bot_config}"
      '';
    };
  };
}
