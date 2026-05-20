Optional local AMXX overrides (not committed).

Drop *.amxx here only if you need a vendor binary without in-tree .sma sources.
Files are gitignored; docker compose build copies them, then stage amxx-build
overwrites any name that was compiled from extra-assets/.../scripting/.

Normal workflow: edit .sma under extra-assets/.../scripting/ and rebuild the image.
