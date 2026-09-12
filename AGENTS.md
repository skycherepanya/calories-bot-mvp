# Lifecore Project Instructions & Agent Guidelines

Welcome to the **Lifecore (Quantified Self Health Data Warehouse)** project.

## 1. Single Source of Truth
Before executing any tasks, modifying code, or creating new components:
* **Always refer to [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md)**. It contains the complete domain model, physiological calculation rules (water retention, glycogen, TEF), prompts, database schema, and the status of both backend implementations.
* Do not burn unnecessary tokens or blindly search files on disk — all critical information is consolidated in this project.

## 2. Architectural Constraints and Conventions
1. **Dual Implementation:**
   - **Node.js (Long Polling):** [index.js](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/index.js), the [handlers/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/handlers/) folder, and [utils/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/utils/). Used for rapid local testing and development.
   - **Supabase Edge Function (Webhook):** [supabase/functions/telegram-bot/index.ts](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/supabase/functions/telegram-bot/index.ts). Used for serverless production.
   - Any logic changes (e.g., new commands, prompts, tags, or database interactions) must be synchronously applied to both implementations.
2. **AI Prompt and Response Format:**
   - Default model: `gemini-3.6-flash`.
   - Always require `responseMimeType: "application/json"`.
   - Must strictly maintain the `Deficit Buffer` rule (multiplying `kcal * 1.15`, while keeping exact values for protein, fat, and carbs).
   - Must return an array of quality tags (`tags: ['whole_food', 'solid', ...]`).
3. **Dietary Date:**
   - A day shift occurs at **04:00 AM** (`shiftHours = 4`), not at midnight. All late-night meals are credited to the previous day.
4. **Security:**
   - Filtering by `ALLOWED_USER_ID` is mandatory for any incoming message or callback button.

## 3. Working Tools and Superpowers
The project has a configured skills library in [.agents/skills/](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/.agents/skills):
* For creating new features, use `brainstorming` and `writing-plans` first.
* For writing code, use `test-driven-development` and `verification-before-completion`.
* When fixing bugs, follow `systematic-debugging`.

## 4. Documentation Integrity Rule
> ⚠️ **STRICT RULE:** Any change in code, database, prompts, or configuration **MUST IMMEDIATELY** be reflected in the corresponding documentation. A task is considered completed ONLY after updating the supporting documents.

Every time changes are made, the AI agent must:
1. **Record the event in [CHANGELOG.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/CHANGELOG.md):** add a new block with the date, description of what was added/changed, and a list of affected files.
2. **Synchronize [PROJECT_KNOWLEDGE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/PROJECT_KNOWLEDGE.md):** update section 3 ("Current Implementation") so the status of files and logic reflects reality.
3. **Update checkboxes in [docs/ROADMAP.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ROADMAP.md):** mark completed subtasks (`[x]`) or add new requirements if they arose during development.
4. **Update [docs/DATABASE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/DATABASE.md):** if tables were changed, columns added, indexes or migrations created.
5. **Update [docs/ARCHITECTURE.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/docs/ARCHITECTURE.md):** if new modules, endpoints, webhooks, or external integrations were added.
6. **Update [README.md](file:///Users/skycherepanya/Documents/GitHub/calories-bot-mvp/README.md):** if startup commands, feature lists, or environment variables changed.

## 5. Testing and Deployment Rule
> ⚠️ **STRICT RULE:** After any change, you must verify it, commit it, and deploy it.

After completing a task and updating documentation, the AI agent must:
1. **Test the changes:** Verify that the code works correctly (e.g. by starting the Node.js bot locally or checking for syntax errors).
2. **Version Control:** Commit the changes to Git with a descriptive message and push them to the repository.
3. **Deploy:** Restart the local bot or deploy the Supabase Edge Function (`supabase functions deploy telegram-bot --no-verify-jwt --use-api`) so the changes take effect in production.
