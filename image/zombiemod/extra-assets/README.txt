Optional full Biohazard (or other mod) file tree merged into cstrike/ at build time.

Extract the official pack so this folder mirrors what belongs under Half-Life cstrike/
(e.g. models/, sound/, sprites/, addons/ — same paths as inside the zip’s cstrike folder).

Recommended from the Biohazard pack (reduces AMXX warnings):
- addons/amxmodx/data/lang/biohazard.txt
- addons/amxmodx/configs/biohazard.cfg (or whatever configs the pack documents)

LaserMine sources: git submodule vendor/Amxx-Laser-TripMine-Entity (branch no-bind-system; compiled in Dockerfile).
This pack provides runtime configs/lang the image merges at build:
- addons/amxmodx/configs/plugins/lasermine/bh_ltm_cvars.cfg
- addons/amxmodx/configs/plugins/lasermine/resources.json
- addons/amxmodx/data/lang/lasermine.txt

Then: docker compose build

If this directory only contains README / .gitkeep, the merge step is skipped.
