Optional compiled AMXX plugins copied into the image at build time.

Place biohazard.amxx here (from the official Biohazard v2.00 Beta 3b pack on AlliedModders),
then run: docker compose build

The Dockerfile copies every *.amxx from this directory into addons/amxmodx/plugins/.
