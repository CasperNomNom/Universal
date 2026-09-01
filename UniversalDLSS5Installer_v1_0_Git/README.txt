Universal DLSS 5 Installer v1.12
================================

Current release
---------------
v1.12 adds automatic Watch Dogs-safe FeedKit cleanup. It also includes the
GitHub release updater and Purple appearance theme introduced in v1.1, while
retaining the locked SR2 Neural Rendering Settings UI baseline and mini console.

No later Natural Pipeline, automatic iMMERSE, release-tag experiments, or other
discarded branches are included in this release.

Universal DLSS 5 Installer v1.12
Saints Row 2 - Neural Rendering Settings UI

This build updates the working SR2 DXVK/Vulkan path to the upstream
v0.8.0-beta.3 matched 32-bit feeder package.

Important settings change
-------------------------
Do not use old shader-side Neural Rendering sliders.

In-game:
  Home -> Add-ons -> DLSS 5 Feed

The Add-ons page is the authoritative control panel for:
- feed status and mode
- HDR/depth overrides
- motion-vector scale
- Advanced settings
- DLSS render preset
- 32-bit host Neural Rendering controls

For 32-bit host neural settings such as Neural Uplift, NR Intensity,
Style, Local Structure, Local Tone, Auto Mask and UI Correction:
  change the setting, then click APPLY.

Why this matters
----------------
The older shader-uniform settings bridge is obsolete. A setup can be
rendering successfully while old visible shader sliders do nothing.

Installer changes
-----------------
- downloads v0.8.0-beta.3 dynamically from the GitHub release API
- installs addon32 + host64 + DLSS5_Feed.fx as one matched protocol set
- verifies the feeder version from dlss5-feed.log
- reports the Add-ons settings architecture in Verify
- adds a Neural Rendering controls / Add-ons UI help button
- retains Mode 1 transport validation and Mode 2 NR verification
- retains DXVK for SR2 because dgVoodoo caused the reproducible SR2 crash


Locked baseline note
--------------------
This build is based ONLY on:
  v1.0 - SR2 Neural Rendering Settings UI

The only carried-forward UI addition is the two-line non-clickable mini
debug console on the Installer page. Later Natural Pipeline, iMMERSE,
release-tag, and other experimental branch changes are not included.
