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

## 2. English Prompt for iOS 27 AI Generator (Apple Intelligence)

В iOS 27 у додатку **Shortcuts** при натисканні на **`+`** введи цей промпт англійською мовою в поле генератора:

```text
Create a shortcut named "Lifecore Sync":
1. Find the 1 most recent sample of Heart Rate Variability (SDNN), get its Value, round to 1 decimal, and set variable hrv_val.
2. Find the 1 most recent sample of Resting Heart Rate, get its Value, round to 1 decimal, and set variable rhr_val.
3. Find Step Count samples where Start Date is Today, calculate Sum, round to 0 decimals, and set variable steps_val.
4. Find Active Energy Burned samples where Start Date is Today, calculate Sum, round to 0 decimals, and set variable active_kcal_val.
5. Find Walking + Running Distance samples where Start Date is Today, calculate Sum, round to 1 decimal, and set variable dist_val.
6. Format Current Date as "yyyy-MM-dd" and set variable today_date. Adjust Current Date by subtracting 1 day, format as "yyyy-MM-dd", and set variable sleep_date.
7. Find Sleep Analysis samples where Start Date is in the last 1 day. Repeat with each: if Value contains Deep, add Duration to DeepDurations; otherwise if Value contains REM, add Duration to REMDurations; otherwise if Value contains Core, add Duration to CoreDurations.
8. Calculate Sum of DeepDurations / 3600 rounded to 2 decimals as deep_hours. Calculate Sum of REMDurations / 3600 rounded to 2 decimals as rem_hours. Calculate Sum of CoreDurations / 3600 rounded to 2 decimals as core_hours. Calculate total_hours as deep_hours + rem_hours + core_hours.
9. Find Workouts where Start Date is Today, latest first, limit 1. If found, extract duration in minutes, avg heart rate, max heart rate, active calories, and distance.
10. Build a JSON text payload with secret "3c021bc09943639b6e1abd58f90a6434208093169e70875f", user_id 472025574, daily_activity object, sleep object, and optional workout object.
11. Send HTTP POST request to "https://khmviccwbuktnvdxhnwg.supabase.co/functions/v1/ingest-health" with Content-Type application/json and the JSON text as body.
12. If response contains '"ok":true', show notification "Lifecore synced successfully", otherwise show notification "Lifecore sync failed".
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
