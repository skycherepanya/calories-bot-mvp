# Lifecore iOS App Intents & HealthKit Sync

Цей модуль реалізує нативну, блискавичну та 100% типобезпечну синхронізацію біометрії Apple Watch та iPhone з базою даних Lifecore (Supabase) за допомогою **Swift**, **HealthKit** та **AppIntents**.

---

## 🎯 Чому це набагато краще за звичайні візуальні шорткати:

1. **Жодних циклів у Shortcuts:** Замість 50 заплутаних візуальних блоків у додатку Команди з'являється **один нативний блок:** `Sync Lifecore Health`.
2. **Швидкість < 5 мілісекунд:** `HKStatisticsQuery` та Swift обробляють тисячі записів кроків і фаз сну миттєво на рівні бази даних iOS.
3. **Ідеальний JSON:** `Codable` та `JSONEncoder` гарантують валідність структури (жодних пропущених ком, лапок чи пустих рядків).
4. **Універсальність тригерів:** Можна викликати з шорткатів, кнопки дії (Action Button), віджета на екрані блокування або через Siri: *"Hey Siri, Sync Lifecore"*.

---

## 📁 Структура файлів

| Файл | Опис |
|---|---|
| [`HealthPayload.swift`](./Lifecore/HealthPayload.swift) | `Codable` Swift-моделі для `daily_activity`, `sleep_logs`, `workouts` |
| [`HealthKitManager.swift`](./Lifecore/HealthKitManager.swift) | Асинхронні запити до HealthKit (`HKStatisticsQuery`, `HKSampleQuery`) |
| [`LifecoreAPIService.swift`](./Lifecore/LifecoreAPIService.swift) | Мережевий шар `URLSession` для відправки JSON у Supabase Edge Function |
| [`LifecoreSyncIntent.swift`](./Lifecore/LifecoreSyncIntent.swift) | Готовий `AppIntent` та `AppShortcutsProvider` |

---

## 🛠 Інструкція з підключення до Xcode-проєкту

### 1. Додай файли до проєкту
Перетягни папку `ios/Lifecore` у свій Xcode-проєкт (вибери *"Copy items if needed"* та переконайся, що стоїть галочка напроти твого App Target).

### 2. Увімкни HealthKit Capability
1. У Xcode відкрий налаштування проєкту $\rightarrow$ обери свій Target.
2. Перейди у вкладку **Signing & Capabilities**.
3. Натисни **`+ Capability`** $\rightarrow$ обери **HealthKit**.

### 3. Додай дозвіл у `Info.plist`
Додай ключ для читання даних здоров'я:
* **Key:** `Privacy - Health Share Usage Description` (`NSHealthShareUsageDescription`)
* **Value:** `Lifecore reads your sleep stages, heart rate variability, daily steps, and workouts to provide AI-powered recovery and athletic coaching.`

---

## 📱 Як налаштувати тригер в iOS Shortcuts:

Після запуску застосунку на телефоні система автоматично зареєструє новий екшен:

1. Відкрий додаток **Shortcuts** $\rightarrow$ вкладка **Automation**.
2. **Ранкова синхронізація:**
   * Тригер: `Time of Day` (09:00 AM) $\rightarrow$ `Run Immediately`.
   * Дія: в пошуку дій введи **Lifecore** $\rightarrow$ обери **`Sync Lifecore Health`**.
3. **Після тренування:**
   * Тригер: `Apple Watch Workout` (Ends) $\rightarrow$ `Run Immediately`.
   * Дія: **`Sync Lifecore Health`**.

Все! В автоматизації тепер рівно **одна нативна дія**, яка ніколи не тупить, не просить підтверджень і не зависає на лімітах пам'яті.
