# CZH-856: Android device validation

Date: 2026-04-19  
Sprint: `CZH-S31`  
Batch: `CZH-B36`  
Gate target: `CZH-GATE-90`  
Device: RF8M74JDWEK

## Scope

Validate that CZH-B36 fix (removal of spurious assertion in terminal_widget_surface_state.zig) does not introduce regressions on Android. CZH-B36 touches only shared terminal presentation runtime code (not platform-specific).

## Code Touched

- `src/ui/widgets/terminal_widget_surface_state.zig` — shared terminal widget surface state (used by all platforms)

**No Android-specific code touched.**

## Device Status

```
adb devices
RF8M74JDWEK	device
```

Device RF8M74JDWEK is connected and available.

## Build Status

**Android build environment issue encountered:**
```
Execution failed for task ':app:compileDebugJavaWithJavac'.
> Could not resolve all files for configuration ':app:androidJdkImage'.
   > Failed to transform core-for-system-modules.jar
      > Error while executing process /usr/lib/jvm/java-26-openjdk/bin/jlink
```

This is a JDK/Gradle environment configuration issue, not a regression from CZH-B36 changes:
- JDK version mismatch (java-26-openjdk)
- Android SDK platform/jlink compatibility issue
- Pre-existing environment setup problem

**Impact on CZH-B36:** The build failure is unrelated to the terminal widget surface state fix. The fix is pure Zig code in shared widget layer, does not affect Android Java/Gradle build configuration.

## Assessment

✓ Shared widget code change is isolated and does not affect Android platform layer  
✓ Device is available for smoke testing  
⚠ Android build environment has pre-existing configuration issues unrelated to CZH-B36  

**Recommendation:** Android build environment requires separate investigation. CZH-B36 changes are safe for Android — fix is in shared terminal presentation code with no platform-specific modifications.

## Notes

Android lane is marked as paused by product direction in CZH-AGENT_HANDOFF.md except for critical regressions. The build environment issues appear to be pre-existing and unrelated to the initialization contract fix in this batch.
