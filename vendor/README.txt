Git submodules vendored for image build.

Amxx-Laser-TripMine-Entity (branch master) — lasermine.sma and includes.
Biohazard + ReUnion patches and default binds (v/c) live in the submodule.

After clone:

  git submodule update --init --recursive

Update lasermine:

  cd vendor/Amxx-Laser-TripMine-Entity && git fetch && git checkout master && git pull
  cd ../.. && git add vendor/Amxx-Laser-TripMine-Entity
