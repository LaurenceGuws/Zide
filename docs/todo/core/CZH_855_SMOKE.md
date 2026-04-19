# CZH-855: Linux startup smoke

Date: 2026-04-19  
Sprint: `CZH-S31`  
Batch: `CZH-B36`  
Gate target: `CZH-GATE-90`

## Validation Ladder

✓ zig build  
✓ zig build test  
✓ zig build -Dmode=terminal  
✓ zig build -Dmode=editor  

## Bounded Linux Terminal GUI Startup Smoke

**Test:** Launch terminal with 2-second timeout, verify no assertion panic, confirm clean termination.

**Result:** ✓ PASS

```
App name: Zide Terminal
App version: <unspecified>
App ID: LaurenceGuws.Zide.Terminal
SDL revision: SDL-3.4.0
```

Terminal started successfully, passed the prior `assertLegsInitialized` assertion point (which would have panicked before CZH-852 fix), and terminated cleanly without any GUI process left running.

## Conclusion

✓ CZH-B36 initialization contract fix resolves the Linux startup regression from CZH-B35  
✓ No assertion panic on terminal widget surface state initialization  
✓ Bounded startup completes cleanly
