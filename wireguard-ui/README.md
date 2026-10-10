# Note: Use the Correct Commands For Stopping and Starting wg-easy

Use `sudo docker compose up / down`, not `sudo docker compose start / stop`. Otherwise, the container is not properly destroyed and you may experience problems during startup because of inconsistent state.

# Default `PersistentKeepalive` for new clients

wg-easy copies the admin default into each client at creation time, so set it before creating clients:

1. Open the UI → **Admin Panel** → **Config**.
2. Set **Persistent Keepalive** to `25` and **Save**.

New clients then get `PersistentKeepalive = 25` in their config.

Existing clients keep their own value: edit each client, set Persistent Keepalive to `25`, then re-download/re-import its config.

# Admin password

Passwords must be at least 12 characters.

- **Initial password**: set `WG_ADMIN_PASSWORD` in `.env` (`cp .env.example .env`); it feeds `INIT_PASSWORD`, which is only used on the very first boot, when `./data` is empty. Changing it later has no effect.
- **Change it (knowing the current one)**: UI → **Account** → enter the current and new password.
- **Reset it (forgotten)**: run on the host. This also clears TOTP (2FA) settings:

  ```bash
  docker exec -it wg-easy cli db:admin:reset --password='<new-password>'
  ```

  Prefix the command with a space (or delete it from shell history afterwards) so the password is not saved in history.

After the first boot, remove the `INIT_*` block (and any `.env` holding the password) from the server copy so the password does not stay on disk.
