# Quickshell Documentation

Welcome to the Quickshell configuration documentation. This folder contains comprehensive analysis, stability fixes, and refactoring guides for the project.

---

## 🚨 CRITICAL: Stability Issues (NEW - 2025-12-09)

**Problem:** Quickshell crashes after several hours of operation

### Immediate Action Required

1. **[QUICK_FIXES.md](./QUICK_FIXES.md)** ⚠️ - Fix crashes in 1 hour
2. **[SUMMARY.md](./SUMMARY.md)** - Executive summary of problems
3. **[ANALYSIS_PROBLEMS.md](./ANALYSIS_PROBLEMS.md)** - Full technical analysis
4. **[CPP_MODULES_SPEC.md](./CPP_MODULES_SPEC.md)** - C++ migration plan

### Critical Issues Found

| Issue | File | Impact | Fix Time |
|-------|------|--------|----------|
| Unsbuilt plugins | `src/plugins/` | Crashes immediately | 5 min |
| Infinite cache growth | `LauncherService.qml` | Crash in 8-12h | 10 min |
| Process leaks | `SystemMonitorService.qml` | Zombie processes | 5 min |
| Timer leaks | `NotificationService.qml` | Memory leak | 15 min |

**Total fix time:** ~1 hour
**Result:** Stable 24/7 operation

---

## Quick Start

**New to this project?** Start here:

1. **[PROJECT_OVERVIEW.md](./PROJECT_OVERVIEW.md)** ⭐ - Visual overview with tree (5 min)
2. **[QUICK_WINS.md](./QUICK_WINS.md)** - 5 minutes, save 536 lines immediately
3. **[CODE_AUDIT.md](./CODE_AUDIT.md)** - Read the full analysis (20 min)
4. **[REFACTORING_CHECKLIST.md](./REFACTORING_CHECKLIST.md)** - Step-by-step implementation guide

---

## Document Overview

### PROJECT_OVERVIEW.md ⭐
**Purpose**: Visual project overview with tree structure and statistics

**Contains**:
- Complete directory tree with `tree` command
- File count and line statistics
- Top 10 largest files
- Code distribution by category
- Visual structure diagrams
- Critical findings summary
- Quick action commands

**When to read**: First! Get the big picture

**Time**: 5 minutes

---

### CODE_AUDIT.md
**Purpose**: Comprehensive code analysis and audit report

**Contains**:
- Executive summary of issues found
- Detailed analysis of duplicate files (VolumeWidget, GlobalState)
- Code duplication patterns (MaterialCard, Icon+Text, Sliders)
- Organizational issues and naming inconsistencies
- Architecture recommendations
- 5-phase refactoring plan with time estimates
- Testing checklist
- Metrics and expected improvements

**When to read**: Before starting any refactoring work

**Time**: 20-30 minutes

---

### QUICK_WINS.md
**Purpose**: Immediate, low-risk improvements you can do in 5 minutes

**Contains**:
- Step-by-step commands to delete unused files
- File verification steps
- Typo fixes (SheduleElement → ScheduleElement)
- Remove duplicate imports
- Commit message template
- Results metrics

**When to use**: Right now! Start here for instant impact

**Time**: 5 minutes

**Impact**: -536 lines (5% code reduction)

---

### REFACTORING_CHECKLIST.md
**Purpose**: Implementation guide for component extraction and refactoring

**Contains**:
- Code templates for new components (DashboardCard, VerticalSliderCard, InfoRow)
- Before/after code examples
- File-by-file refactoring instructions
- Testing commands
- Commit strategy
- Verification steps

**When to use**: After completing quick wins, follow this for Phases 1-3

**Time**: 3-5 hours total (spread across multiple sessions)

**Impact**: -250 additional lines, significantly reduced duplication

---

### PROJECT_STRUCTURE.md
**Purpose**: Visual reference for project organization

**Contains**:
- Complete directory tree with file sizes
- Component relationship diagrams
- Code duplication maps
- Import graphs
- Statistics (current vs. after refactor)
- Recommended new structure

**When to use**: Reference during refactoring, or when understanding project architecture

**Time**: 5-10 minutes to browse

---

## Recommended Reading Order

### For Quick Cleanup (Total: 10 minutes)
1. QUICK_WINS.md → Execute immediately
2. PROJECT_STRUCTURE.md → Quick overview

### For Full Refactoring (Total: 1 hour + implementation time)
1. CODE_AUDIT.md → Understand the issues (30 min)
2. PROJECT_STRUCTURE.md → See the big picture (10 min)
3. REFACTORING_CHECKLIST.md → Implementation guide (20 min + work)

### For New Team Members
1. PROJECT_STRUCTURE.md → Learn architecture
2. CODE_AUDIT.md → Understand technical debt
3. REFACTORING_CHECKLIST.md → See improvement plan

---

## Summary of Issues Found

### Critical (Do Now)
- ❌ **VolumeWidget2.qml** - 527 lines of unused code
- ❌ **GlobalState.qml** - 8 lines, superseded by GlobalStates
- ❌ **TrayMenu.qml.bak** - Backup file in version control

**Action**: Delete these files (5 minutes)

---

### High Priority (Do This Week)
- 🔴 **MaterialCard pattern** duplicated 9 times (~90 lines)
- 🔴 **Audio management** duplicated between VolumeWidget2 and AudioTab (~200 lines)
- 🔴 **Inline sliders** in MainTab.qml should be extracted (~70 lines)

**Action**: Create reusable components (3-4 hours)

---

### Medium Priority (Do This Month)
- 🟡 **Typo**: SheduleElement → ScheduleElement
- 🟡 **InfoRow pattern** duplicated 5+ times (~45 lines)
- 🟡 **Tray files** organization (4 files in wrong location)
- 🟡 **Duplicate imports** in StatusBar.qml

**Action**: Fix naming and organization (2 hours)

---

### Low Priority (Do Eventually)
- 🟢 **Commented code** in multiple files
- 🟢 **Empty directories** (display/, layout/, system/)
- 🟢 **Inconsistent spacing** tokens
- 🟢 **Missing documentation** (style guide)

**Action**: Clean up and document (2 hours)

---

## Expected Outcomes

### After Quick Wins (5 minutes)
```
Files:     76 → 73 (-3)
Lines:     10,781 → 10,245 (-536, -5%)
Dead Code: 536 → 0 lines
```

### After Phase 1 (DashboardCard extraction, 1 hour)
```
Lines:     10,245 → 9,995 (-250, -2.5%)
Duplication: -10%
```

### After Phase 2 (VerticalSliderCard, 30 min)
```
Lines:     9,995 → 9,925 (-70)
MainTab.qml: 210 → 140 lines
```

### After Phase 3 (InfoRow pattern, 30 min)
```
Lines:     9,925 → 9,845 (-80)
UserInfoElement.qml: 119 → ~70 lines
```

### Total After All Phases
```
Files:     76 QML (same, but better organized)
Lines:     10,781 → 9,795 (-986, -9.1%)
Duplication: -40%
Maintainability: +++
Code Reuse: +40%
```

---

## How to Execute

### Step 1: Quick Wins (Required, 5 min)
```bash
cd /home/at1ass/.config/quickshell/shell

# Delete unused files
git rm src/features/statusbar/VolumeWidget2.qml
git rm src/features/GlobalState.qml
git rm src/features/dashboard/components/maintab_elements/TrayMenu.qml.bak

# Fix typo
git mv src/features/dashboard/components/maintab_elements/SheduleElement.qml \
       src/features/dashboard/components/maintab_elements/ScheduleElement.qml

# Update import in MainTab.qml (line 157)
# Remove duplicate imports in StatusBar.qml (lines 8, 10)

git commit -m "refactor: Remove unused files and fix naming"
```

### Step 2: Component Extraction (Optional, 3-5 hours)
Follow **REFACTORING_CHECKLIST.md** for detailed instructions:
- Phase 1: DashboardCard (1 hour)
- Phase 2: VerticalSliderCard (30 min)
- Phase 3: InfoRow (30 min)
- Phase 4: Audio components (3 hours)

### Step 3: Testing
```bash
# Visual verification
quickshell  # or your start command

# Check for errors
qml6 src/core/config/Config.qml

# Verify imports
grep -r "SheduleElement\|VolumeWidget2\|GlobalState[^s]" src/
# Should return nothing
```

---

## Files in This Directory

```
docs/
├── README.md                    ← You are here
│
├── Stability Analysis (NEW - Critical!)
├── SUMMARY.md                   ← Executive summary of crash issues ⚠️
├── QUICK_FIXES.md               ← Fix crashes in 1 hour ⚠️
├── ANALYSIS_PROBLEMS.md         ← Full technical analysis (30 min read)
└── CPP_MODULES_SPEC.md          ← C++ migration specs
│
├── Code Quality Analysis
├── PROJECT_OVERVIEW.md          ← Visual overview with tree ⭐
├── QUICK_WINS.md                ← Cleanup: 5 min, -536 lines
├── CODE_AUDIT.md                ← Full refactoring analysis (20 min)
├── REFACTORING_CHECKLIST.md     ← Step-by-step implementation
├── PROJECT_STRUCTURE.md         ← Architecture reference
└── WINDOW_ARCHITECTURE.md       ← Future windows design
```

---

## Contribution Guidelines

When adding to this project:

1. **Use reusable components** instead of copy-paste
2. **Follow naming conventions**:
   - Components: `MaterialCard.qml`, `IconButton.qml`
   - Dashboard widgets: `ClockWidget.qml`, `WeatherWidget.qml`
   - Services: `AudioService.qml`, `SystemMonitorService.qml`
3. **No backup files** in version control (use git instead)
4. **No commented code** (use git history)
5. **Document patterns** in this folder

---

## Questions?

- **Where to start?** → Read QUICK_WINS.md
- **Need full details?** → Read CODE_AUDIT.md
- **Want step-by-step?** → Follow REFACTORING_CHECKLIST.md
- **Need overview?** → Check PROJECT_STRUCTURE.md
- **Lost in code?** → All docs reference line numbers and file paths

---

## Metrics Dashboard

### Stability Metrics (NEW - Critical!)

| Metric | Current | After Fixes | Status |
|--------|---------|-------------|--------|
| Time to Crash | 4-8 hours | 24+ hours | ❌ Fix needed |
| Memory Leak | ~100MB/hour | <10MB/hour | ❌ Fix needed |
| Zombie Processes | 50+/hour | 0 | ❌ Fix needed |
| Unsbuilt Plugins | 3 modules | 0 | ❌ Build needed |

### Code Quality Metrics

| Metric | Current | Target | Progress |
|--------|---------|--------|----------|
| Total Lines | 10,781 | 9,795 | 0% → 100% |
| Dead Code | 536 | 0 | ❌ Not started |
| Duplication | ~40% | <10% | ❌ Not started |
| Code Reuse | ~20% | 60% | ❌ Not started |
| Typos | 1 | 0 | ❌ Not started |
| Backup Files | 1 | 0 | ❌ Not started |

**Update this after each phase!**

---

## Success Criteria

✅ Phase complete when:
- [ ] All critical files deleted
- [ ] No syntax errors
- [ ] Dashboard renders correctly
- [ ] All interactive elements work
- [ ] No console errors/warnings
- [ ] Code committed to git
- [ ] Metrics dashboard updated

---

**Generated**: 2025-10-09
**Last Updated**: 2025-12-09 (Stability analysis added)
**Status**: 🚨 Critical stability fixes needed
**Priority**:
1. Fix crashes (1 hour) - CRITICAL
2. Quick wins (5 min) - Cleanup
3. Full refactor (5 hours) - Code quality

**Expected Benefits**:
- Stability: 4-8h → 24/7
- Code size: -9% lines
- Code reuse: +40%
- Duplication: -40%
