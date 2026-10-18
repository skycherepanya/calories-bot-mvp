# Lifecore: AI Health Coach & Nutrition Data Warehouse
*Модуль офлайн-аналітики та архів даних*

Цей підкаталог (`Lifecore/`) містить Python-скрипти для офлайн-аналізу Apple Health та Strava даних, системні промпти AI-тренера та архівні аналітичні звіти.

**Він є частиною єдиного репозиторію Lifecore.** Продовий Telegram-бот та база даних описані в [кореневому README](../README.md).

---

## 📁 Структура

```
Lifecore/
├── data/
│   ├── health/
│   │   └── apple_health_export/
│   │       └── export.xml        # 1.97 GB — Apple Health XML архів
│   └── strava/
│       ├── activities.csv        # Всі Strava-активності
│       └── ...                   # Інші Strava CSV файли
│
├── scripts/
│   ├── deep_health_analysis.py   # XML → daily_health_summary.json (основний парсер)
│   ├── analyze_health.py         # Тренди HRV/RHR/Steps по місяцях
│   ├── analyze_steps.py          # Перевірка подвійного підрахунку кроків
│   ├── analyze_strava.py         # Темп, дистанції, HR кореляції (Strava)
│   └── sync_to_supabase.py       # Завантаження архіву в Supabase БД
│
├── prompts/                      # Системні промпти AI-тренера (reference)
│   ├── antigravity_health_assistant_prompt_sasha.md   # Саша-профіль
│   └── antigravity_health_assistant_prompt_vika.md    # Віка-профіль (multi-user)
│
└── reports/                      # Архівні аналітичні звіти
    ├── daily_health_summary.json # Генерується deep_health_analysis.py (552 KB)
    ├── Progress_Report.md        # Прогрес 2026: VO2Max +17.5%, HRV +20ms
    └── Diet_and_Activity_Analysis_Office.md  # Аналіз офісного режиму жовтень 2026
```

---

## 🚀 Порядок запуску (перший раз)

### Крок 1: Встановити Python-залежності
```bash
pip install supabase pandas python-dotenv
```

### Крок 2: Розпарсити Apple Health XML → JSON
```bash
cd Lifecore/
python scripts/deep_health_analysis.py
# → Генерує reports/daily_health_summary.json
# Зазвичай займає 2-5 хвилин (файл 1.97 GB)
```

### Крок 3: Завантажити архів в Supabase
```bash
# Після застосування міграцій 002 + 003 в Supabase:
python scripts/sync_to_supabase.py
# → Завантажує sleep_logs (HRV, RHR) + workouts (Apple Health + Strava)
```

### Крок 4: Додатковий аналіз (опціонально)
```bash
# Тренди по місяцях (HRV, RHR, Steps)
python scripts/analyze_health.py

# Аналіз кроків по джерелах (подвійний підрахунок iPhone + Watch?)
python scripts/analyze_steps.py

# Аналіз бігу (темп, дистанції, HR кореляції)
python scripts/analyze_strava.py
```

---

## 📊 Що є в даних (реальні показники 2026)

На основі звітів у `reports/`:

| Показник | Лютий 2026 | Жовтень 2026 | Зміна |
|---|---|---|---|
| **VO2 Max** | 37.73 | ~44.35 | **+17.5%** 🚀 |
| **HRV (нічний)** | 86.96 ms | 105.49 ms | **+20 ms** ✅ |
| **RHR** | 52+ уд/хв | ~49 уд/хв | **-3 уд/хв** ✅ |
| **Біг (місяць)** | — | 62 км | — |
| **Середній темп** | 7:47 хв/км | 6:39 хв/км | **-68 сек/км** 🏃 |

---

## 🔗 Зв'язок з продовим ботом

Дані з цього модуля потрапляють у продовий бот через:
1. **`sync_to_supabase.py`** → одноразовий завантаж архіву Apple Health + Strava в БД
2. **`shortcuts/ingest_health_shortcut.md`** → iOS Shortcut для щоденного автоматичного синку

Після того як дані є в БД, Telegram-команда `/coach` дає AI-аналіз відновлення на основі реальних цифр.
