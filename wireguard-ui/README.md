# Note: Use the Correct Commands For Stopping and Starting wg-easy

Use `sudo docker compose up / down`, not `sudo docker compose start / stop`. Otherwise, the container is not properly destroyed and you may experience problems during startup because of inconsistent state.
