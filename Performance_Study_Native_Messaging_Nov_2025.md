# Browser Launcher Pro Performance Study (Nov 2025)

Making sense of “health checks,” memory usage, and CPU impact — explained in plain English.

## TL;DR

- The extension runs a single native “ping” when you open the popup (and only again if you click the heartbeat button). There’s no background loop.
- CPU impact: effectively negligible — a tiny, split‑second task you won’t notice.
- Memory impact: also negligible. No steady growth from the health check.
- The Memory badge shows the extension’s own memory, not your system’s total RAM.

## What we measured

We looked at two things users care about:

1) Health check behavior (how often it runs and what it does)
2) Memory and CPU usage (whether there are spikes or slowdowns)

## How the health check works

- When you open the extension popup, it sends a quick “ping” to the native helper app using Chrome’s native messaging feature.
- If you press the heartbeat button, it sends another ping on demand.
- That’s it — there’s no repeating timer or background loop for this check.

What happens during a ping:
- The extension sends a tiny JSON message like { action: "ping" }.
- The native helper app replies immediately.
- If nothing responds within ~4 seconds, the UI shows “Timeout,” and stops. No retries or loops.

## The Memory badge, clarified

- The badge in the footer shows the extension popup’s memory (its JavaScript heap), not your computer’s total RAM.
- Typical values are small (a few MB to a few dozen MB, depending on what’s visible in the popup).
- If you’ve ever seen a huge number in the past (like tens of GB), that was system RAM — we fixed the display to show only the extension’s memory.

## What we found (impact overview)

CPU
- One ping uses a tiny bit of CPU for a split second. Even pressing the heartbeat multiple times won’t matter on modern machines.

Memory
- The health check allocates a few short‑lived objects in the popup. Garbage collection cleans these up quickly. No ongoing growth.

Native helper app
- Depending on your OS configuration, the helper either starts briefly to reply and exits, or stays ready to respond. Either way, it’s quick and light.

Bottom line: no noticeable performance hit from the health check.

## Why you won’t see spikes

- There’s no interval timer hammering the native app.
- The check runs only when you open the popup (or click the button).
- Work done during a single check is tiny — just a small message and response.

## If you want continuous monitoring (optional)

We don’t run health checks in a loop by default. If you ever want continuous monitoring, here’s how we’d keep it efficient:
- Only check while the popup is visible.
- Reuse a single connection instead of re‑connecting each time.
- Back off (check less often) if errors or timeouts occur.

## Verify it yourself (under 1 minute)

Method A — Chrome Task Manager
1) Open the extension popup.
2) Press Shift+Esc to open Chrome Task Manager.
3) Look at the Browser Launcher Pro process while you click the heartbeat button a few times.
4) You should see memory stay steady and CPU blips that are too small to notice.

Method B — Performance panel (optional)
1) Open the popup, open DevTools > Performance, click Record for ~5–10 seconds.
2) Click the heartbeat once or twice, stop recording.
3) You’ll see tiny scripting tasks; nothing sustained.

Method C — Native helper visibility (optional)
1) Open Windows Task Manager or Process Explorer.
2) Click the heartbeat; you may see the helper appear briefly (if it doesn’t stay resident). It closes right after replying.

## FAQ

Q: Why did I see 20+ GB earlier?
A: That was your system’s total memory. The badge now shows only the extension’s memory footprint.

Q: Is the 4‑second timeout a problem?
A: No. It’s there to avoid hanging if the native helper isn’t available. After 4 seconds, the UI shows “Timeout” and stops.

Q: Can I run health checks continuously?
A: You can, but it’s not necessary. If ever enabled, we’d follow the efficiency rules above (visible‑only, connection reuse, backoff).

## Version notes

- Study date: November 2025
- Extension architecture: Manifest V3 with a Python native messaging helper
- Scope: Popup health check and popup memory badge

—

Questions or want the raw details? Open an issue or reach us via the project’s support links.
