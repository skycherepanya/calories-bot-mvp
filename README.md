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
│  Continuous Heart Rate • Sleep Phases • Workouts • HRV │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 2: Swift Deterministic Math & Telemetry Engine  │
│  1km Splits • Cardiac Drift % • Isolated NEAT • TEF    │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 3: Local Persistence & Cloud Synchronization    │
│  SwiftData (Local-First Offline) ◄──► Supabase Cloud   │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│  Layer 4: Presentation & AI Athletic Intelligence      │
│  SwiftUI Bevel-Style Dashboard • Gemini Athletic Coach │
└────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
lifecore/
├── AGENTS.md                  # Single-agent rules & iOS-first guidelines
├── PROJECT_KNOWLEDGE.md       # Master Single Source of Truth
├── CHANGELOG.md               # Changelog & architectural milestones
│
├── ios/                       🍏 Primary Codebase: Native iOS App (Swift 6)
│   ├── README.md              Xcode project guide & capability setup
│   └── Lifecore/
│       ├── Lifecore.xcodeproj
│       └── Lifecore/
│           ├── LifecoreApp.swift         Main SwiftUI App entry point
│           ├── ContentView.swift         Dark-mode Quantified Self dashboard
│           ├── HealthKitManager.swift    Async HealthKit queries (sleep, HRV, RHR)
│           ├── HealthPayload.swift       Codable data models matching schema
│           ├── LifecoreAPIService.swift  URLSession client for Supabase sync
│           └── LifecoreSyncIntent.swift  AppIntent for iOS automations
│
├── supabase/                  ☁️ Cloud Persistence Layer (Supabase PostgreSQL)
│   ├── functions/
│   │   ├── ingest-health/     ✅ Active telemetry ingestion endpoint
│   │   └── telegram-bot/      ⚠️ Legacy / Deprecated Telegram webhook
│   └── migrations/            PostgreSQL schema migrations (001–005)
│
├── docs/                      📚 Architecture & Documentation
│   ├── ARCHITECTURE.md        Comprehensive system architecture
│   ├── DATABASE.md            PostgreSQL schema & data dictionary
│   ├── ROADMAP.md             iOS-First development roadmap
│   └── RFC_WORKOUT_GRANULARITY_AND_COACH_ARCHITECTURE.md
│
├── handlers/                  ⚠️ Legacy: Node.js Telegram Bot Handlers
├── utils/                     ⚠️ Legacy: Node.js Bot Utilities
└── index.js                   ⚠️ Legacy: Node.js Long-Polling Entry Point
```

---

## ⚙️ Setup & Development

### 1. iOS Application (Primary)
1. Open `ios/Lifecore/Lifecore.xcodeproj` in **Xcode 16+**.
2. Ensure **HealthKit** and **AppIntents** capabilities are assigned to your Apple Developer Team.
3. Build and run on a physical iPhone connected to an Apple Watch for live HealthKit telemetry.

### 2. Cloud Synchronization (Supabase)
Ensure your environment variables are configured in `.env` (or Supabase Secrets for functions):
```env
SUPABASE_URL="https://xxxxxxxxxxxx.supabase.co"
SUPABASE_KEY="anon-or-service-role-key"
INGEST_SECRET="your-ingest-secret"
GEMINI_API_KEY="your-google-ai-studio-key"
```
