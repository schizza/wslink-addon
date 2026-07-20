# Changelog

## 0.0.8 — Sincere apology + fix for the 0.0.7 breakage

**Please update immediately if you are on 0.0.7.**

First, I owe every affected user a big apology. **I'm sorry.**
Version 0.0.7 broke the WU/PWS upload flow for everyone using the
[SWS12500](https://github.com/schizza/sws12500) integration (and any
similar integration that reads credentials from the query string). If
your weather station data stopped landing in Home Assistant after the
0.0.7 auto-update, that was on me — not on your station, your network,
or the integration. Thank you to everyone who filed an issue,
rolled back, and helped diagnose it — especially
[@dominikprucha](https://github.com/dominikprucha) in
[#18](https://github.com/schizza/wslink-addon/issues/18) who nailed the
root cause.

### What was wrong in 0.0.7

0.0.7 switched the two `proxy_pass` directives to use a variable
upstream (`set $ha_upstream ...`) so nginx could re-resolve Home
Assistant's internal IP without an add-on restart. That part was
correct. What I missed is a well-known nginx quirk:

> When `proxy_pass` contains a variable **and** a URI, nginx no longer
> appends the original request's query string automatically.

So `?ID=...&PASSWORD=...` never reached Home Assistant. The SWS12500
integration returned **401 "No security data provided!"** for every
upload, and — because Home Assistant treats repeated 401s as failed
logins (`ip_ban_enabled: true`) — after 5 failures the add-on's own
container IP got **IP-banned**, cutting the station off completely.
That's why restarting the station or re-saving the URL in the WSLink
app sometimes *seemed* to help briefly, and why some setups just went
dark.

### Fix in 0.0.8

- Append `$is_args$args` to both `proxy_pass` targets so the query
  string is forwarded again.
- Add `X-Forwarded-For $remote_addr` so, if Home Assistant ever bans
  again, it bans the actual station's IP — not the add-on itself. This
  requires `use_x_forwarded_for: true` and `trusted_proxies` in your HA
  `http:` config to take effect; without it, HA behaves as before.
- Keep the good parts of 0.0.7 (resolver, timeouts, larger
  `worker_connections`).

### If you're currently locked out

1. Update the add-on to 0.0.8.
2. In Home Assistant, go to **Settings → System → Logs**, or the
   `ip_bans.yaml` file in `/config`, and remove any entry for the
   add-on's internal IP (usually starts with `172.30.`).
3. Restart Home Assistant so the ban list is reloaded.
4. Your station should start uploading again on its next cycle
   (~12 seconds).

Again — sorry for the disruption.

---

## 0.0.7 — Broken, do not use

Introduced variable upstream + `resolver` + timeouts, but dropped the
query string (see 0.0.8 notes). Superseded by 0.0.8.

## 0.0.6

- Pin exact base images so Supervisor rebuilds no longer fail when a
  cached image drifts ([#10](https://github.com/schizza/wslink-addon/issues/10)).
- Regenerate DH parameters at 4096 bits when recreating certificates.

## 0.0.5

- Add `/status`, `/status/internal`, and `/healthz` endpoints for
  diagnostics.
- Localization: Czech and English translation files.
- Support for the PWS (`/data/upload.php`) protocol alongside WU.
