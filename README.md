# Lifecore 2.0: Native iOS-First & Athletic Performance Platform

**Lifecore** is a personal, native Quantified Self health and endurance platform. Built with **Swift 6, SwiftUI, HealthKit, and Supabase**, the system integrates high-frequency physiological telemetry from Apple Watch, camera-based nutrition tracking, on-device deterministic sports mathematics, and Gemini AI to deliver elite endurance coaching without vendor lock-in.

---

## ⚡ Key Capabilities (Lifecore 2.0)

### 🍏 Native iOS Application (`ios/Lifecore/`)
* **Bevel-Style Dashboard:** Modern dark-mode interface presenting daily Readiness, Cardiovascular Strain, and Caloric Balance at a glance.
* **HealthKit Native Telemetry:** Direct on-device queries (<5ms) for sleep architecture (Deep, REM, Core, Awake), morning HRV SDNN, resting heart rate (RHR), and continuous workout telemetry.
* **1-Tap & Automated Sync:** `LifecoreSyncIntent` integrates with iOS Shortcuts, Action Button, Siri, and background automations.

### 🏃 Athletic Split Telemetry & Running Engine
* **Kilometer-by-Kilometer Splits:** Granular analysis of every kilometer (pace, average heart rate, elevation gain/loss $\Delta h$, cadence).
* **Cardiac Drift & Decoupling ($EF$):** Deterministic evaluation of aerobic decoupling ($\Delta EF$) between the first and second half of runs to detect cardiovascular fatigue, dehydration, and glycogen depletion.
* **Pure NEAT Isolation:** Mathematical extraction of non-exercise activity thermogenesis ($\text{NEAT} = \max(0, \text{daily\_active\_kcal} - \sum \text{workout\_kcal})$) avoiding duplicate calorie counting.

### 🤖 AI Athletic Performance Analyst (70 / 15 / 15)
* **70% Workout Execution:** Granular breakdown of pacing stability, heart rate spikes on hills, and cardiovascular efficiency.
* **15% Historical Benchmark:** Objective comparison against past similar endurance sessions.
* **15% Physiological Root Causes:** Explaining performance deltas through sleep stages, autonomic recovery (HRV/RHR), and nutritional glycogen reserves.
* **Actionable Directive:** 1 concrete, non-medical training instruction for the next 24 hours.

### 📸 Frictionless Nutrition Logging
* **Vision-Based Food Recognition:** Camera capture powered by Gemini Vision with automated portion estimation and macronutrient breakdown.
* **Guaranteed Deficit Buffer (+12.5%):** Automatically multiplies calculated calories by ×1.125 to protect the user's caloric deficit.
* **4-Hour Dietary Day Shift:** The dietary date resets at 04:00 AM, correctly attributing late-night meals to the preceding physiological cycle.

---

## 🏗️ 4-Layer On-Device Architecture

```
┌────────────────────────────────────────────────────────┐
│  Layer 1: Canonical Source of Truth (Apple HealthKit)  │
│  Apple Watch Ultra & iPhone 16 Pro (<5ms direct query) │
│  Sleep Stages • HRV SDNN • Sleeping RHR • Series Data  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 2: Swift Deterministic Math & Telemetry Engine  │
│  Readiness (0-100%) • Strain • Pure NEAT Isolation     │
│  1km Auto-Splits • Laps • EF • Cardiac Drift % • GAP   │
│  7d / 14d Rolling Weight Averages (Water Noise Filter) │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 3: Local Persistence & Cloud Synchronization    │
│  SwiftData (Local-First Offline Storage)               │
│  ▲                                                     │
│  └──► Async Backup: Supabase (meals, workout_analyses) │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 4: Presentation & AI Athletic Intelligence      │
│  SwiftUI Bevel-Style Dashboard (Today, Workouts, etc.) │
│  Gemini Vision Food Parser (+12.5% buffer, tags)       │
│  AI Athletic Performance Analyst (70 / 15 / 15)        │
└────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
lifecore/
├── AGENTS.md                  # Token economy rules & agent instructions (English)
├── PROJECT_KNOWLEDGE.md       # Master Single Source of Truth (English)
├── ARCHITECTURAL_PIVOT_IOS_FIRST.md # Master architectural pivot directive
├── CHANGELOG.md               # Milestones & engineering log
│
├── ios/                       🍏 Primary Client: Native iOS App (Swift 6)
│   ├── README.md              # Capabilities & Xcode configuration guide
│   └── Lifecore/
│       ├── Lifecore.xcodeproj
│       └── Lifecore/
│           ├── App/           # LifecoreApp.swift, MainTabView.swift
│           ├── Core/
│           │   ├── HealthKit/ # HealthKitManager.swift, WorkoutTelemetryExtractor.swift
│           │   ├── MathEngine/# ReadinessCalculator.swift, WorkoutMathEngine.swift
│           │   ├── AI/        # GeminiService.swift, FoodPrompt.swift, CoachPrompt.swift
│           │   └── Storage/   # SwiftDataModels.swift, SupabaseSyncService.swift
│           ├── Features/      # Today/, Workouts/, Nutrition/, Trends/
│           └── Intents/       # LifecoreSyncIntent.swift, LogMealIntent.swift
│
├── docs/                      📚 Architecture & Technical Specifications
│   ├── ARCHITECTURE.md        # 4-layer on-device architecture specification
│   ├── DATABASE.md            # PostgreSQL cloud warehouse schema & data dictionary
│   └── ROADMAP.md             # Native iOS-first development roadmap
│
├── supabase/                  ☁️ Cloud Warehouse Layer (Supabase PostgreSQL)
│   └── migrations/            # SQL DDL migrations (001–005, 20260904160000)
│
└── [Tag: v1.0-telegram-archive] 📦 Safely preserved legacy Telegram, Deno & Python code in Git history
```

---

## ⚙️ Setup & Development

### 1. iOS Application (Primary)
1. Open `ios/Lifecore/Lifecore/Lifecore.xcodeproj` in **Xcode 16+**.
2. Ensure **HealthKit** and **AppIntents** capabilities are assigned to your Apple Developer Team.
3. Build and run on a physical iPhone connected to an Apple Watch for live HealthKit telemetry.

### 2. Cloud Synchronization (Supabase)
Direct on-device synchronization from native iOS (`SupabaseSyncService.swift`) into Supabase PostgreSQL:
- Supabase Project URL & Anon/Service Role Key configured in `ios/Lifecore/Lifecore/Core/Storage/SupabaseSyncService.swift` (or via environment/runtime configuration).
- Local-first architecture guarantees 100% offline functionality with async cloud persistence.
- To inspect or access historical v1.0 Telegram Bot & Deno Edge Function code: `git checkout v1.0-telegram-archive`.

