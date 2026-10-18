# iOS 27 Shortcut: Lifecore Health Sync

> **OS Target:** iOS 27 (Optimized for Apple Intelligence & native "Otherwise If")  
> **Hardware:** iPhone 16 Pro, Apple Watch Ultra  
> **UI Language:** English  
> **Призначення:** Автоматичний збір телеметрії здоров'я, сну та тренувань з HealthKit і відправка в Deno Edge Function `ingest-health` (Supabase PostgreSQL).

---

## 1. Credentials & Environment Parameters

Всі параметри твого облікового запису та сервера:

* **Shortcut Name:** `Lifecore Sync`
* **SUPABASE_URL:** `https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health`
* **SECRET:** `3c021bc09943639b6e1abd58f90a6434208093169e70875f`
* **USER_ID:** `472025574`

---

## 2. English Prompt for iOS 27 AI Generator (Ultra-Detailed & Bug-Free)

> ⚠️ **Чому виникала помилка з «5500 результатів» та незрозумілими змінними:**
> 1. **5500 результатів:** Екшен `Find Health Samples` (для кроків або сну) створився **без фільтра дати** або з фільтром «All», і Apple Health підтягнув усю історію за всі роки! А потім цикл намагався 5500 разів її обробити. У новому промпті додано жорсткі обмеження (`Limit: 60` для сну та `Limit: 300` для кроків), тому шорткат фізично більше ніколи не зчитає 5500 семплів!
> 2. **Каша зі змінними:** Apple Intelligence за замовчуванням ліпить «Magic Variables» (автозв'язки між діями), замість того щоб створювати блоки `Set Variable`. Нижче наведено промпт із явною імперативною директивою `Add action "Set Variable" with Variable Name ...` для кожного кроку.

В iOS 27 у додатку **Shortcuts** натисни **`+`** і встав цей ультра-деталізований промпт:

```text
Create a shortcut named "Lifecore Sync". Follow these exact steps with explicit "Set Variable" actions and strict sample limits:

1. Dates:
- Add action "Current Date". Add action "Format Date" with Custom Format "yyyy-MM-dd". Add action "Set Variable" with Variable Name "today_date".
- Add action "Current Date". Add action "Adjust Date" to Subtract 1 day. Add action "Format Date" with Custom Format "yyyy-MM-dd". Add action "Set Variable" with Variable Name "sleep_date".

2. Autonomic Recovery Biomarkers:
- Add action "Find Health Samples": Type: "Heart Rate Variability", Sort by: "Start Date", Order: "Latest First", Limit: 1. Add action "Get Details of Health Sample": Detail: "Value". Add action "Round Number" to 1 decimal place. Add action "Set Variable" with Variable Name "hrv_val".
- Add action "Find Health Samples": Type: "Resting Heart Rate", Sort by: "Start Date", Order: "Latest First", Limit: 1. Add action "Get Details of Health Sample": Detail: "Value". Add action "Round Number" to 1 decimal place. Add action "Set Variable" with Variable Name "rhr_val".

3. Daily Activity & NEAT:
- Add action "Find Health Samples": Type: "Step Count", Filter: "Start Date is Today", Limit: 300. Add action "Calculate Statistics": Operation: "Sum". Add action "Round Number" to 0 decimal places. Add action "Set Variable" with Variable Name "steps_val".
- Add action "Find Health Samples": Type: "Active Energy", Filter: "Start Date is Today", Limit: 300. Add action "Calculate Statistics": Operation: "Sum". Add action "Round Number" to 0 decimal places. Add action "Set Variable" with Variable Name "active_kcal_val".
- Add action "Find Health Samples": Type: "Walking + Running Distance", Filter: "Start Date is Today", Limit: 300. Add action "Calculate Statistics": Operation: "Sum". Add action "Round Number" to 1 decimal place. Add action "Set Variable" with Variable Name "dist_val".

4. Sleep Stages (Apple Watch Ultra):
- Add action "Find Health Samples": Type: "Sleep Analysis", Filter: "Start Date is in the last 1 days", Sort by: "Start Date", Order: "Latest First", Limit: 60.
- Add action "Repeat with Each" for the found sleep samples:
  - Add action "Get Details of Health Sample": Detail: "Value" from Repeat Item.
  - Add action "Get Details of Health Sample": Detail: "Duration" from Repeat Item.
  - Add action "If" Value contains "Deep": Add action "Add to Variable" Duration to variable "DeepDurations".
  - Add action "Otherwise If" Value contains "REM": Add action "Add to Variable" Duration to variable "REMDurations".
  - Add action "Otherwise If" Value contains "Core": Add action "Add to Variable" Duration to variable "CoreDurations".
  - Add action "End If".
- Add action "End Repeat".
- After Repeat:
  - Add action "Calculate Statistics": Sum of "DeepDurations". Add action "Calculate": divide by 3600. Add action "Round Number" to 2 decimal places. Add action "Set Variable" with Variable Name "deep_hours".
  - Add action "Calculate Statistics": Sum of "REMDurations". Add action "Calculate": divide by 3600. Add action "Round Number" to 2 decimal places. Add action "Set Variable" with Variable Name "rem_hours".
  - Add action "Calculate Statistics": Sum of "CoreDurations". Add action "Calculate": divide by 3600. Add action "Round Number" to 2 decimal places. Add action "Set Variable" with Variable Name "core_hours".
  - Add action "Calculate": "deep_hours" + "rem_hours" + "core_hours". Add action "Round Number" to 2 decimal places. Add action "Set Variable" with Variable Name "total_hours".

5. Workouts:
- Add action "Find Workouts": Filter: "Start Date is Today", Sort by: "Start Date", Order: "Latest First", Limit: 1.
- Add action "If" Workouts has any value:
  - Add action "Get Details of Workout": Duration in minutes. Add action "Set Variable" with Variable Name "w_dur".
  - Add action "Get Details of Workout": Average Heart Rate. Add action "Set Variable" with Variable Name "w_hr".
  - Add action "Get Details of Workout": Maximum Heart Rate. Add action "Set Variable" with Variable Name "w_max_hr".
  - Add action "Get Details of Workout": Active Energy Burned. Add action "Set Variable" with Variable Name "w_kcal".
  - Add action "Get Details of Workout": Distance. Add action "Set Variable" with Variable Name "w_dist".
  - Add action "Get Details of Workout": Workout Type. Add action "Set Variable" with Variable Name "w_type".
  - Add action "Get Details of Workout": Start Date formatted as ISO 8601. Add action "Set Variable" with Variable Name "w_start".
  - Add action "Text" with content:
    , "workout": {"type": "w_type", "duration_min": w_dur, "avg_heart_rate": w_hr, "max_heart_rate": w_max_hr, "active_calories": w_kcal, "distance_km": w_dist, "started_at": "w_start"}
  - Add action "Set Variable" with Variable Name "workout_fragment".
- Add action "Otherwise":
  - Add action "Text" (leave completely empty). Add action "Set Variable" with Variable Name "workout_fragment".
- Add action "End If".

6. Payload & HTTP POST Webhook:
- Add action "Text" containing this JSON structure:
{"secret": "3c021bc09943639b6e1abd58f90a6434208093169e70875f", "user_id": 472025574, "daily_activity": {"date": "today_date", "steps": steps_val, "active_kcal": active_kcal_val, "distance_km": dist_val}, "sleep": {"sleep_date": "sleep_date", "total_hours": total_hours, "deep_hours": deep_hours, "rem_hours": rem_hours, "core_hours": core_hours, "hrv_avg_ms": hrv_val, "rhr_bpm": rhr_val} workout_fragment}
- Add action "Get Contents of URL": URL: "https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health", Method: POST, Header: "Content-Type": "application/json", Request Body: File (select the Text action).
- Add action "If" Contents of URL contains "ok":
  - Add action "Show Notification" with title "Lifecore": "Synced successfully".
- Add action "Otherwise":
  - Add action "Show Notification" with title "Lifecore": "Sync failed".
- Add action "End If".
```


---

## 3. Step-by-Step Manual Setup (English UI / Пояснення українською)

Якщо складаєш вручну або перевіряєш згенеровані екшени, ось точні англійські назви дій та параметрів:

---

### Step 1: Date Preparation

1. **Activity Date (`today_date`):**
   * Action: **Current Date**
   * Action: **Format Date** $\rightarrow$ Date Format: `Custom` $\rightarrow$ Format String: `yyyy-MM-dd`
   * Action: **Set Variable** $\rightarrow$ Name: `today_date`

2. **Sleep Date (`sleep_date`):**
   * Action: **Current Date**
   * Action: **Adjust Date** $\rightarrow$ `Subtract` `1` `day`
   * Action: **Format Date** $\rightarrow$ Date Format: `Custom` $\rightarrow$ Format String: `yyyy-MM-dd`
   * Action: **Set Variable** $\rightarrow$ Name: `sleep_date`

---

### Step 2: Autonomic Biomarkers (HRV & RHR)

1. **Heart Rate Variability (SDNN):**
   * Action: **Find Health Samples**:
     * Type: `Heart Rate Variability`
     * Sort by: `Start Date`
     * Order: `Latest First`
     * Limit: `1` sample
   * Action: **Get Details of Health Sample**:
     * Detail: `Value`
   * Action: **Round Number** $\rightarrow$ to `1` decimal place
   * Action: **Set Variable** $\rightarrow$ Name: `hrv_val`

2. **Resting Heart Rate (RHR):**
   * Action: **Find Health Samples**:
     * Type: `Resting Heart Rate`
     * Sort by: `Start Date`, Order: `Latest First`, Limit: `1` sample
   * Action: **Get Details of Health Sample**:
     * Detail: `Value`
   * Action: **Round Number** $\rightarrow$ to `1` decimal place
   * Action: **Set Variable** $\rightarrow$ Name: `rhr_val`

---

### Step 3: Daily Activity & NEAT

1. **Step Count:**
   * Action: **Find Health Samples**:
     * Type: `Step Count`
     * Filter: `Start Date` `is Today`
   * Action: **Calculate Statistics**:
     * Operation: `Sum`
   * Action: **Round Number** $\rightarrow$ to `0` decimal places
   * Action: **Set Variable** $\rightarrow$ Name: `steps_val`

2. **Active Energy Burned:**
   * Action: **Find Health Samples**:
     * Type: `Active Energy`
     * Filter: `Start Date` `is Today`
   * Action: **Calculate Statistics** $\rightarrow$ `Sum`
   * Action: **Round Number** $\rightarrow$ to `0` decimal places
   * Action: **Set Variable** $\rightarrow$ Name: `active_kcal_val`

3. **Walking + Running Distance:**
   * Action: **Find Health Samples**:
     * Type: `Walking + Running Distance`
     * Filter: `Start Date` `is Today`
   * Action: **Calculate Statistics** $\rightarrow$ `Sum`
   * Action: **Round Number** $\rightarrow$ to `1` decimal place
   * Action: **Set Variable** $\rightarrow$ Name: `dist_val`

---

### Step 4: Sleep Stages Parsing (Apple Watch Ultra + iOS 27 "Otherwise If")

> ⚡ **Чому це працює блискавично:** Фільтр `Start Date is in the last 1 day` повертає лише ~30–50 семплів за минулу ніч. На A18 Pro цей цикл займає лише 1 секунду.

1. **Find Sleep Samples:**
   * Action: **Find Health Samples**:
     * Type: `Sleep Analysis`
     * Filter: `Start Date` `is in the last 1 days`

2. **Loop with iOS 27 "Otherwise If":**
   * Action: **Repeat with Each** (input: Health Samples):
     * Action: **Get Details of Health Sample** $\rightarrow$ Detail: `Value` (from Repeat Item)
     * Action: **Get Details of Health Sample** $\rightarrow$ Detail: `Duration` (from Repeat Item)
     * Action: **If** `[Value]` **contains** `Deep`:
       * Action: **Add to Variable** $\rightarrow$ Variable: `DeepDurations` (add Duration)
     * Action (iOS 27): **Otherwise If** `[Value]` **contains** `REM`:
       * Action: **Add to Variable** $\rightarrow$ Variable: `REMDurations`
     * Action (iOS 27): **Otherwise If** `[Value]` **contains** `Core`:
       * Action: **Add to Variable** $\rightarrow$ Variable: `CoreDurations`
     * Action: **End If**
   * Action: **End Repeat**

3. **Calculate Stage Hours:**
   * **Deep Sleep:**
     * Action: **Calculate Statistics** $\rightarrow$ `Sum` of `DeepDurations`
     * Action: **Calculate** $\rightarrow$ `[Sum] / 3600`
     * Action: **Round Number** $\rightarrow$ to `2` decimal places $\rightarrow$ Variable: `deep_hours`
   * **REM Sleep:**
     * Action: **Calculate Statistics** $\rightarrow$ `Sum` of `REMDurations`
     * Action: **Calculate** $\rightarrow$ `[Sum] / 3600`
     * Action: **Round Number** $\rightarrow$ to `2` decimal places $\rightarrow$ Variable: `rem_hours`
   * **Core Sleep:**
     * Action: **Calculate Statistics** $\rightarrow$ `Sum` of `CoreDurations`
     * Action: **Calculate** $\rightarrow$ `[Sum] / 3600`
     * Action: **Round Number** $\rightarrow$ to `2` decimal places $\rightarrow$ Variable: `core_hours`
   * **Total Sleep:**
     * Action: **Calculate** $\rightarrow$ `deep_hours + rem_hours + core_hours`
     * Action: **Round Number** $\rightarrow$ to `2` decimal places $\rightarrow$ Variable: `total_hours`

---

### Step 5: Workouts (Conditional)

1. Action: **Find Workouts**:
   * Filter: `Start Date` `is Today`
   * Sort by: `Start Date`, Order: `Latest First`, Limit: `1`
2. Action: **If** `[Workouts]` **has any value**:
   * Action: **Get Details of Workout**:
     * `Duration` (minutes) $\rightarrow$ `w_dur`
     * `Average Heart Rate` $\rightarrow$ `w_hr`
     * `Maximum Heart Rate` $\rightarrow$ `w_max_hr`
     * `Active Energy Burned` $\rightarrow$ `w_kcal`
     * `Distance` (km) $\rightarrow$ `w_dist`
     * `Workout Type` $\rightarrow$ `w_type`
     * `Start Date` (Format: ISO 8601: `yyyy-MM-dd'T'HH:mm:ssZZZZZ`) $\rightarrow$ `w_start`
   * Action: **Text** (named `workout_json_fragment`):
     ```json
     ,
       "workout": {
         "type": "[w_type]",
         "duration_min": [w_dur],
         "avg_heart_rate": [w_hr],
         "max_heart_rate": [w_max_hr],
         "active_calories": [w_kcal],
         "distance_km": [w_dist],
         "started_at": "[w_start]"
       }
     ```
3. Action: **Otherwise**:
   * Action: **Text** (leave completely blank) $\rightarrow$ `workout_json_fragment`
4. Action: **End If**

---

### Step 6: Single Text Action JSON Payload

Додай екшен **Text** і встав цей шаблон. Заміни змінні у квадратних дужках на відповідні **Magic Variables**:

```json
{
  "secret": "3c021bc09943639b6e1abd58f90a6434208093169e70875f",
  "user_id": 472025574,
  "daily_activity": {
    "date": "[today_date]",
    "steps": [steps_val],
    "active_kcal": [active_kcal_val],
    "distance_km": [dist_val]
  },
  "sleep": {
    "sleep_date": "[sleep_date]",
    "total_hours": [total_hours],
    "deep_hours": [deep_hours],
    "rem_hours": [rem_hours],
    "core_hours": [core_hours],
    "hrv_avg_ms": [hrv_val],
    "rhr_bpm": [rhr_val]
  }[workout_json_fragment]
}
```

---

### Step 7: HTTP POST Request to Supabase

1. Action: **Get Contents of URL**:
   * URL: `https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health`
   * Method: **POST**
   * Headers:
     * Key: `Content-Type`, Value: `application/json`
   * Request Body: **File** (або **Text**) $\rightarrow$ вибери змінну з **Step 6** (Text).
2. Action: **If** `[Contents of URL]` **contains** `"ok":true`:
   * Action: **Show Notification**:
     * Text: `✅ Lifecore synced: HRV [hrv_val] ms | Sleep [total_hours]h`
3. Action: **Otherwise**:
   * Action: **Show Notification**:
     * Text: `⚠️ Lifecore sync failed: [Contents of URL]`
4. Action: **End If**

---

## 4. Automations Setup (iOS 27 English UI)

В додатку **Shortcuts** перейди у вкладку **Automation**:

### Automation 1: Daily Morning Sync
* Tap **`+`** (New Automation)
* Select **Time of Day** $\rightarrow$ `09:00 AM`
* Repeat: **Daily**
* Execution Mode: Select **Run Immediately** (toggle off *Ask Before Running* & *Notify When Run*)
* Action: **Run Shortcut** $\rightarrow$ choose `Lifecore Sync`

### Automation 2: Post-Workout Instant Sync
* Tap **`+`**
* Select **Apple Watch Workout**
* Trigger: **Ends**
* Execution Mode: **Run Immediately**
* Action: **Run Shortcut** $\rightarrow$ choose `Lifecore Sync`

---

## 5. Verification & Testing

1. Натисни кнопку **Run (Play)** у правому нижньому кутку редактора шорткату.
2. При першому запиті доступу до HealthKit обери **Turn On All** (Sleep, HRV, Heart Rate, Steps, Workouts).
3. Має з'явитися сповіщення: `✅ Lifecore synced: HRV ... ms | Sleep ... h`.
4. Перевір результат у Telegram: введи `/stats` або `/coach` — дані миттєво підтягнуться.
