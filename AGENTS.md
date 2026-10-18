# Lifecore Project Instructions & Agent Guidelines

Welcome to the **Lifecore (Native iOS-First & Athletic Performance Platform)** project.

---

## 1. Single Source of Truth
Before executing any tasks, modifying code, or creating new components:
* **Always refer to [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md)**. It contains the complete domain model, physiological calculation rules (water retention, glycogen, TEF), prompt specifications, database schema, and active architecture.
* Do not burn unnecessary tokens or blindly search files on disk — all critical architecture, business logic, and mathematical rules are consolidated in this repository's documentation.

---

## 2. Architectural Constraints and Conventions (iOS-First Pivot)
1. **iOS-First Architecture (`ios/Lifecore/`):**
   * **Primary Client & Engine:** The core application is a native iOS app built in Swift 6, SwiftUI, Swift Charts, HealthKit, and SwiftData.
   * **Legacy Backend Deprecation:** The previous Dual-Backend (`Node.js` long polling in `index.js`/`handlers/` and Deno in `supabase/functions/telegram-bot/`) is now **Legacy / Deprecated**. Agents must NOT spend effort maintaining dual parity between Node.js and Deno for new features. The Telegram bot serves purely as a secondary interface.
   * **Cloud Storage & Sync:** Supabase PostgreSQL serves as a cloud backup and synchronization layer.
2. **Strict Separation: Deterministic Math vs AI Reasoning:**
   * **Swift Math Engine:** All deterministic calculations (1km splits, pace, heart rate decoupling / cardiac drift, pure NEAT isolation, rolling weight averages, deficit calculations) **MUST** be computed natively in Swift code.
   * **Gemini AI Role:** AI models are strictly for qualitative, athletic, and causal narrative reasoning (interpreting pre-calculated telemetry numbers), NOT for guessing arithmetic or statistics.
3. **AI Coach Persona — Athletic Performance Analyst (70 / 15 / 15):**
   * **70%:** Deep breakdown of the specific workout (1km splits, pace vs HR, response to elevation/hills, cardiac drift).
   * **15%:** Historical benchmark comparison against previous similar workouts.
   * **15%:** Physiological root causes (sleep phases, HRV, RHR, pre-workout carbohydrates/deficit) explaining *why* performance changed, plus **1 actionable directive for the next 24h**.
   * **Zero Medical Alarmism:** Completely eliminate the "anxious therapist" tone. No premature "СТОП / ВІДНОВЛЕННЯ" alarms on normal RHR fluctuations; no unsolicited generic wellness advice (warm baths, meditation, etc.).
4. **Food Recognition & Nutrition Principles:**
   * Multiplier: strictly maintain the **Deficit Buffer (+12.5% kcal)** (`kcal_final = kcal_exact * 1.125`), while keeping exact grams for protein, fat, and carbs.
   * Tagging taxonomy: mandatory quality tags (`whole_food`, `solid`, `liquid`, `fast_absorbing`, `ultra_processed`, `high_sodium`).
5. **Dietary Date Convention:**
   * The dietary day shift occurs at **04:00 AM** (`shiftHours = 4`), not at midnight. All late-night meals and post-midnight workouts are attributed to the previous calendar day.

---

## 3. Working Tools and Superpowers
The project has a configured skills library in [.agents/skills/](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/.agents/skills):
* For creating new features, use `brainstorming` and `writing-plans` first.
* For writing code, use `test-driven-development` and `verification-before-completion`.
* When fixing bugs, follow `systematic-debugging`.

---

## 4. Documentation Integrity Rule
> ⚠️ **STRICT RULE:** Any change in code, database, prompts, or configuration **MUST IMMEDIATELY** be reflected in the corresponding documentation. A task is considered completed ONLY after updating the supporting documents.

Every time changes are made, the AI agent must:
1. **Record the event in [CHANGELOG.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/CHANGELOG.md):** add a new block with the date, description of what was added/changed, and a list of affected files.
2. **Synchronize [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md):** update Section 3 ("Current Implementation") and other relevant sections so reality is reflected.
3. **Update checkboxes in [docs/ROADMAP.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ROADMAP.md):** mark completed subtasks (`[x]`) or add new requirements.
4. **Update [docs/DATABASE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/DATABASE.md):** if tables were changed, columns added, indexes or migrations created.
5. **Update [docs/ARCHITECTURE.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/docs/ARCHITECTURE.md):** if new modules, endpoints, or on-device engines were added.
6. **Update [README.md](file:///Users/skycherepanya/Developer/GitHub/calories-bot-mvp/README.md):** if startup instructions, feature lists, or system roles changed.

---

## 5. Testing and Verification Rule
> ⚠️ **STRICT RULE:** After any change, you must verify it, commit it, and deploy/test it.

After completing a task and updating documentation, the AI agent must:
1. **Verify the code:** Check Swift builds (`swift build` / `xcodebuild` where applicable), Deno linting, or Node.js syntax before declaring success.
2. **Version Control:** Commit the changes to Git with a descriptive, conventional commit message and push to the repository (`origin/main`).
3. **Deploy:** If edge functions or backend scripts were updated, deploy via Supabase CLI (`supabase functions deploy ... --no-verify-jwt --use-api`).
