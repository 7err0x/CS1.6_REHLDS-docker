Host-backed HLDS ban / IP files for this Compose stack.

Runtime layout
--------------
- Docker named volume **cs16-state** still holds maps, AMXX vault, config.cfg, etc.
- These two files are **bind-mounted from the host** over the volume paths so you can
  edit them on the host and have the server write them with **writeid** / **writeip**:

  ./data/cs16-state/banned.cfg  →  /var/cs16/state/hlds-meta/banned.cfg
                                   (= cstrike/banned.cfg via image symlink)
  ./data/cs16-state/listip.cfg  →  /var/cs16/state/hlds-meta/listip.cfg

Permanent bans
--------------
1. Get the ID from **status** (must look like STEAM_0:0:123 or STEAM_1:1:123 — Y is 0 or 1).
2. Either:
     rcon banid 0 STEAM_0:0:123
     rcon banid 0 STEAM_1:0:123
     rcon writeid
     rcon kick "name"
   or edit **banned.cfg** here, then **rcon exec banned.cfg** (or changelevel).

Do **not** run writeid after temporary chat-filter bans — bio_chatfilter no longer
calls writeid so it will not wipe this file.

Other files
-----------
**config.cfg** in this folder is legacy/sample only; live client/server userconfig
lives in the **cs16-state** volume under hlds-meta-*/config.cfg.
