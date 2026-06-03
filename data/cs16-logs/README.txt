HLDS log files (bind-mounted from Compose).

Default host paths (relative to the Compose project / repo root):
  data/cs16-logs/respawn/    — cs16 service
  data/cs16-logs/biohazard/  — cs16-biohazard service

Override base dir in .env: CS16_LOGS_HOST_DIR=./data/cs16-logs

Run docker compose from the repo root so ./data/cs16-logs resolves correctly.
