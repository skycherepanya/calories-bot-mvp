import SwiftUI
import SwiftData
import HealthKit

// MARK: - Settings Routes

public enum SettingsSectionRoute: String, CaseIterable, Identifiable, Hashable, Sendable {
    case athleteProfile
    case healthAccess
    case aiSetup
    case accountSync
    case coachMemory

    public var id: String { rawValue }

    public var titleUk: String {
        switch self {
        case .athleteProfile: return "Профіль атлета"
        case .healthAccess: return "Доступ до Apple Health"
        case .aiSetup: return "ШІ-аналітика та конфіденційність"
        case .accountSync: return "Синхронізація та черга"
        case .coachMemory: return "Пам’ять тренера"
        }
    }

    public var subtitleUk: String {
        switch self {
        case .athleteProfile: return "Антропометрія, базові вітальні межі та цілі"
        case .healthAccess: return "Дозволи читання й запису показників здоров’я"
        case .aiSetup: return "Режим провайдера, API-конфігурація та передача даних"
        case .accountSync: return "Стан локальної черги та ручна синхронізація"
        case .coachMemory: return "Підтвердження та керування фактами для RAG"
        }
    }

    public var systemImage: String {
        switch self {
        case .athleteProfile: return "person.text.rectangle"
        case .healthAccess: return "heart.text.square"
        case .aiSetup: return "sparkles"
        case .accountSync: return "arrow.triangle.2.circlepath.icloud"
        case .coachMemory: return "brain.head.profile"
        }
    }

    public var accessibilityIdentifier: String {
        switch self {
        case .athleteProfile: return "settings_row_athlete_profile"
        case .healthAccess: return "settings_row_health_access"
        case .aiSetup: return "settings_row_ai_setup"
        case .accountSync: return "settings_row_account_sync"
        case .coachMemory: return "settings_row_coach_memory"
        }
    }
}

// MARK: - Settings Root View

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    private let environment: AppEnvironment
    @State private var navigationPath: [SettingsSectionRoute]

    public init(
        environment: AppEnvironment = .current,
        initialRoute: SettingsSectionRoute? = nil
    ) {
        self.environment = environment
        if let initialRoute {
            _navigationPath = State(initialValue: [initialRoute])
        } else {
            _navigationPath = State(initialValue: [])
        }
    }

    public var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    ForEach(SettingsSectionRoute.allCases) { route in
                        NavigationLink(value: route) {
                            SettingsRouteRow(route: route)
                        }
                        .accessibilityIdentifier(route.accessibilityIdentifier)
                    }
                } header: {
                    Text("Розділи")
                } footer: {
                    Text("Усі налаштування зберігаються локально або синхронізуються згідно з обраним середовищем.")
                }

                Section {
                    MetricRow(
                        title: "Режим середовища",
                        value: environment.isFixtureMode ? "Fixture (ізольований)" : "Live",
                        detail: environment.isFixtureMode
                            ? "Тестові провайдери без доступу до HealthKit і мережі"
                            : "Робота з Apple Health, Gemini та Supabase",
                        systemImage: environment.isFixtureMode ? "testtube.2" : "bolt.horizontal.circle",
                        statusTone: environment.isFixtureMode ? .teal : .optimal
                    )
                } header: {
                    Text("Стан застосунку")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
            .navigationTitle("Налаштування")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(LifecoreTheme.accentPrimary)
                    .accessibilityIdentifier("btn_close_settings")
                }
            }
            .navigationDestination(for: SettingsSectionRoute.self) { route in
                destinationView(for: route)
            }
        }
        .accessibilityIdentifier("screen_settings")
    }

    @ViewBuilder
    private func destinationView(for route: SettingsSectionRoute) -> some View {
        switch route {
        case .athleteProfile:
            AthleteProfileSettingsView()
        case .healthAccess:
            HealthAccessSettingsView(environment: environment)
        case .aiSetup:
            AISetupSettingsView(environment: environment)
        case .accountSync:
            AccountSyncSettingsView(environment: environment)
        case .coachMemory:
            CoachMemorySettingsView(environment: environment)
        }
    }
}

// MARK: - Settings Row

private struct SettingsRouteRow: View {
    let route: SettingsSectionRoute

    var body: some View {
        HStack(spacing: LifecoreLayout.spacing12) {
            Image(systemName: route.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(LifecoreTheme.accentPrimary)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(route.titleUk)
                    .font(.body.weight(.medium))
                    .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                    .fixedSize(horizontal: false, vertical: true)

                Text(route.subtitleUk)
                    .font(.caption)
                    .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: LifecoreLayout.minTouchTarget, alignment: .leading)
        .padding(.vertical, LifecoreLayout.spacing4)
    }
}

// MARK: - 1. Athlete Profile Destination

private struct AthleteProfileSettingsView: View {
    @ObservedObject private var store = AthleteProfileStore.shared
    @State private var isShowingProfileEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                SectionHeader(
                    title: "Поточні параметри атлета",
                    subtitle: "Використовуються детермінованим математичним ядром"
                )

                VStack(spacing: LifecoreLayout.spacing8) {
                    MetricRow(
                        title: "Вага та зріст",
                        value: String(format: "%.1f кг · %.0f см", store.profile.weightKg, store.profile.heightCm),
                        detail: "Вік: \(store.profile.ageYears) р.",
                        systemImage: "figure.stand",
                        statusTone: .neutral
                    )
                    Divider()
                    MetricRow(
                        title: "Пульсовий діапазон",
                        value: "\(Int(store.profile.restingHeartRateBaselineBpm))–\(Int(store.profile.maxHeartRateBpm)) уд/хв",
                        detail: "База RHR та максимальний ЧСС",
                        systemImage: "heart.fill",
                        statusTone: .optimal
                    )
                    Divider()
                    MetricRow(
                        title: "Базовий HRV (RMSSD/SDNN)",
                        value: String(format: "%.0f мс", store.profile.hrvBaselineMs),
                        detail: store.profile.hrvMethod == .hybridRMSSD ? "Гібридний RMSSD" : "Apple SDNN",
                        systemImage: "waveform.path.ecg",
                        statusTone: .teal
                    )
                    Divider()
                    MetricRow(
                        title: "Денні цілі",
                        value: "\(Int(store.profile.targetCaloriesKcal)) ккал",
                        detail: String(format: "Б %.0fг · Ж %.0fг · В %.0fг · Сон %.1f год", store.profile.targetProteinG, store.profile.targetFatG, store.profile.targetCarbsG, store.profile.targetSleepHours),
                        systemImage: "target",
                        statusTone: .indigo
                    )
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                PrimaryAction(
                    title: "Редагувати профіль атлета",
                    systemImage: "pencil",
                    action: { isShowingProfileEditor = true }
                )
                .accessibilityIdentifier("btn_settings_edit_profile")
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("Профіль атлета")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingProfileEditor) {
            AthleteProfileSheet()
        }
    }
}

// MARK: - 2. Health Access Destination

private struct HealthAccessSettingsView: View {
    let environment: AppEnvironment

    @State private var isRequesting = false
    @State private var statusState: ScreenState<String> = .content(
        "Натисніть кнопку нижче, щоб запросити або оновити системний дозвіл Apple Health.",
        isRefreshing: false,
        isStale: false
    )

    private var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                SectionHeader(
                    title: "Дозволи та приватність Apple Health",
                    subtitle: "Керування інтеграцією з HealthKit"
                )

                VStack(spacing: LifecoreLayout.spacing8) {
                    MetricRow(
                        title: "Провайдер HealthKit",
                        value: environment.healthProvider.isMock ? "Fixture (імітація)" : "Live (HealthKit)",
                        detail: environment.healthProvider.isMock
                            ? "У режимі фікстур системні діалоги не викликаються"
                            : "Підключено до локального сховища Apple Health",
                        systemImage: "heart.fill",
                        statusTone: environment.healthProvider.isMock ? .teal : .optimal
                    )
                    Divider()
                    MetricRow(
                        title: "Доступність на пристрої",
                        value: isHealthDataAvailable ? "Доступно" : "Недоступно",
                        detail: "Читання: сон, ЧСС, HRV, тренування, вага. Запис: калорії та макроси.",
                        systemImage: "iphone",
                        statusTone: isHealthDataAvailable ? .optimal : .warning
                    )
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
                    Text("Важливе зауваження щодо приватності iOS")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)

                    Text("З міркувань конфіденційності Apple iOS не дозволяє жодному застосунку достовірно визначити, чи користувач заборонив доступ на читання даних HealthKit — у разі відмови система просто повертає порожні вибірки. Якщо графіки або пульс не оновлюються, перевірте дозволи у «Параметри → Здоров’я → Доступ до даних і пристроїв → Lifecore».")
                        .font(.footnote)
                        .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                ScreenStateView(
                    state: statusState,
                    onRetry: { Task { await requestHealthAuthorization() } }
                ) { message in
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                        .padding(LifecoreLayout.spacing12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LifecoreTheme.semanticWell)
                        )
                }

                PrimaryAction(
                    title: "Оновити дозволи Apple Health",
                    systemImage: "checkmark.shield",
                    isLoading: isRequesting,
                    action: { Task { await requestHealthAuthorization() } }
                )
                .accessibilityIdentifier("btn_request_health_auth")
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("Доступ до Apple Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestHealthAuthorization() async {
        isRequesting = true
        defer { isRequesting = false }

        do {
            try await environment.healthProvider.requestAuthorization()
            if environment.healthProvider.isMock {
                statusState = .content(
                    "Режим фікстур: запит авторизації оброблено без звернення до системного HealthKit.",
                    isRefreshing: false,
                    isStale: false
                )
            } else {
                statusState = .content(
                    "Системний запит дозволів Apple Health завершено. За потреби перевірте перемикачі читання в системних налаштуваннях.",
                    isRefreshing: false,
                    isStale: false
                )
            }
        } catch {
            statusState = .failed(
                message: "Не вдалося виконати запит дозволів: \(error.localizedDescription)",
                retained: nil
            )
        }
    }
}

// MARK: - 3. AI Setup Destination

private struct AISetupSettingsView: View {
    let environment: AppEnvironment

    @State private var customKeyInput: String = ""
    @State private var feedbackMessage: String?

    private var hasUserOverrideKey: Bool {
        let key = UserDefaults.standard.string(forKey: "GEMINI_API_KEY") ?? ""
        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var apiStatusSummary: (value: String, detail: String, tone: MetricStatusTone) {
        if environment.isFixtureMode || environment.aiProvider.isMock {
            return (
                "Локальний Fixture",
                "Використовується детермінований MockAIProvider без зовнішніх запитів.",
                .teal
            )
        }

        let liveKey = GeminiService.shared.currentApiKey ?? ""
        if liveKey.isEmpty {
            return (
                "Не налаштовано",
                "Ключ Gemini API відсутній. Вкажіть власний ключ нижче.",
                .danger
            )
        } else if hasUserOverrideKey {
            return (
                "Власний ключ",
                "Активний ключ із локального збереженого налаштування пристрою.",
                .optimal
            )
        } else {
            return (
                "Стандартний ключ",
                "Використовується вбудована конфігурація Lifecore Gemini API.",
                .optimal
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                SectionHeader(
                    title: "ШІ-провайдер та передача даних",
                    subtitle: "Прозорість використання зовнішніх моделей"
                )

                VStack(spacing: LifecoreLayout.spacing8) {
                    MetricRow(
                        title: "Провайдер AI",
                        value: environment.aiProvider.isMock ? "Fixture (MockAI)" : "Live (Google Gemini)",
                        detail: environment.aiProvider.isMock
                            ? "Мережеві запити вимкнено"
                            : "Аналіз страв та інтерпретація тренувань",
                        systemImage: "cpu",
                        statusTone: environment.aiProvider.isMock ? .teal : .optimal
                    )
                    Divider()
                    let status = apiStatusSummary
                    MetricRow(
                        title: "Стан API-конфігурації",
                        value: status.value,
                        detail: status.detail,
                        systemImage: "key.fill",
                        statusTone: status.tone
                    )
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
                    Text("Що передається зовнішньому ШІ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)

                    Text("Усі числові розрахунки (спліти, дрейф ЧСС, HRV, ACWR) виконуються локально на пристрої. Зовнішньому API Google Gemini надсилаються лише зведені текстові підсумки тренувань, підтверджені нотатки пам’яті та фото або опис страви — тільки коли ви запускаєте ШІ-аналіз чи чат з тренером.")
                        .font(.footnote)
                        .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                if !environment.isFixtureMode && !environment.aiProvider.isMock {
                    VStack(alignment: .leading, spacing: LifecoreLayout.spacing12) {
                        Text("Власний ключ Gemini API (необов’язково)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)

                        SecureField("Вставте GEMINI_API_KEY", text: $customKeyInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(LifecoreLayout.spacing12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(LifecoreTheme.semanticWell)
                            )

                        PrimaryAction(
                            title: "Зберегти власний ключ",
                            systemImage: "checkmark.circle",
                            isDisabled: customKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                            action: saveCustomKey
                        )

                        if hasUserOverrideKey {
                            Button(role: .destructive, action: clearCustomKey) {
                                Text("Скинути власний ключ до стандартного")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: LifecoreLayout.minTouchTarget)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(LifecoreLayout.spacing16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LifecoreTheme.semanticCard)
                    )
                }

                if let feedbackMessage {
                    Text(feedbackMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LifecoreTheme.statusOptimal)
                        .padding(LifecoreLayout.spacing12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LifecoreTheme.semanticWell)
                        )
                }
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("ШІ-аналітика")
        .navigationBarTitleDisplayMode(.inline)
        .lifecoreKeyboardDismissToolbar()
    }

    private func saveCustomKey() {
        let trimmed = customKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: "GEMINI_API_KEY")
        GeminiService.shared.setApiKey(trimmed)
        customKeyInput = ""
        feedbackMessage = "Власний ключ Gemini API збережено."
    }

    private func clearCustomKey() {
        UserDefaults.standard.removeObject(forKey: "GEMINI_API_KEY")
        GeminiService.shared.setApiKey(GeminiService.defaultApiKey)
        feedbackMessage = "Повернуто стандартну конфігурацію ключа."
    }
}

// MARK: - 4. Account & Sync Destination

private struct AccountSyncSettingsView: View {
    let environment: AppEnvironment

    @State private var pendingCount: Int = 0
    @State private var isSyncing: Bool = false
    @State private var syncState: ScreenState<String> = .content(
        "Локальні зміни накопичуються в черзі та надсилаються в хмару при синхронізації.",
        isRefreshing: false,
        isStale: false
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                SectionHeader(
                    title: "Хмарна синхронізація",
                    subtitle: "Стан локальної черги SyncOutbox"
                )

                VStack(spacing: LifecoreLayout.spacing8) {
                    MetricRow(
                        title: "Режим синхронізації",
                        value: environment.syncProvider.isMock ? "Fixture (Локальний)" : "Live (Supabase)",
                        detail: environment.syncProvider.isMock
                            ? "Мережева передача вимкнена"
                            : "Двостороннє резервування записів",
                        systemImage: "icloud",
                        statusTone: environment.syncProvider.isMock ? .teal : .optimal
                    )
                    Divider()
                    MetricRow(
                        title: "Операцій у черзі",
                        value: "\(pendingCount)",
                        detail: pendingCount == 0
                            ? "Усі локальні зміни синхронізовано"
                            : "Очікують відправки у Supabase",
                        systemImage: "tray.full",
                        statusTone: pendingCount == 0 ? .optimal : .warning
                    )
                }
                .padding(LifecoreLayout.spacing16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LifecoreTheme.semanticCard)
                )

                ScreenStateView(
                    state: syncState,
                    onRetry: { Task { await triggerManualSync() } }
                ) { summary in
                    Text(summary)
                        .font(.footnote)
                        .foregroundStyle(LifecoreTheme.semanticSecondaryLabel)
                        .padding(LifecoreLayout.spacing12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(LifecoreTheme.semanticWell)
                        )
                }

                PrimaryAction(
                    title: "Синхронізувати зараз",
                    systemImage: "arrow.triangle.2.circlepath",
                    isLoading: isSyncing,
                    action: { Task { await triggerManualSync() } }
                )
                .accessibilityIdentifier("btn_manual_sync")
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("Синхронізація")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshOutboxCount() }
    }

    private func refreshOutboxCount() {
        let context = ModelContext(environment.modelContainer)
        let pending = (try? SyncOutbox.shared.fetchPendingOperations(in: context)) ?? []
        pendingCount = pending.count
    }

    private func triggerManualSync() async {
        isSyncing = true
        defer {
            isSyncing = false
            refreshOutboxCount()
        }

        do {
            let mealsSynced = try await environment.syncProvider.syncPendingMeals()
            let analysesSynced = try await environment.syncProvider.syncPendingAnalyses()
            if environment.syncProvider.isMock {
                syncState = .content(
                    "Режим фікстур: перевірку синхронізації виконано локально (0 мережевих запитів).",
                    isRefreshing: false,
                    isStale: false
                )
            } else {
                syncState = .content(
                    "Синхронізацію завершено: передано прийомів їжі — \(mealsSynced), аналізів тренувань — \(analysesSynced).",
                    isRefreshing: false,
                    isStale: false
                )
            }
        } catch {
            syncState = .failed(
                message: "Помилка синхронізації: \(error.localizedDescription)",
                retained: "Операцій у черзі залишилось: \(pendingCount)"
            )
        }
    }
}

// MARK: - 5. Coach Memory Destination

private struct CoachMemoryFactItem: Identifiable, Sendable, Equatable {
    let id: UUID
    let factTextUk: String
    let category: String
    let isPinnedGoal: Bool
    let confirmationStatus: String

    init(entity: AthleteMemoryEntity) {
        self.id = entity.id
        self.factTextUk = entity.factTextUk
        self.category = entity.category
        self.isPinnedGoal = entity.isPinnedGoal
        self.confirmationStatus = entity.confirmationStatus
    }
}

private struct CoachMemorySettingsView: View {
    let environment: AppEnvironment
    @State private var state: ScreenState<[CoachMemoryFactItem]> = .loading

    private var modelContext: ModelContext {
        ModelContext(environment.modelContainer)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LifecoreLayout.spacing16) {
                SectionHeader(
                    title: "Факти пам’яті тренера",
                    subtitle: "Підтверджені нотатки та кандидати, витягнуті з діалогів",
                    actionTitle: "Оновити",
                    action: loadFacts
                )

                ScreenStateView(
                    state: state,
                    emptyTitle: "Пам’ять порожня",
                    emptyMessage: "Тут з’являтимуться ваші цілі, травми та інсайти тренера після діалогів.",
                    emptySystemImage: "brain.head.profile",
                    onRetry: loadFacts
                ) { facts in
                    VStack(spacing: LifecoreLayout.spacing12) {
                        ForEach(facts) { fact in
                            CoachMemoryFactCard(
                                fact: fact,
                                onConfirm: {
                                    _ = AthleteMemoryStorageService.confirmCandidateFact(id: fact.id, in: modelContext)
                                    loadFacts()
                                },
                                onDelete: {
                                    AthleteMemoryStorageService.deleteFact(id: fact.id, in: modelContext)
                                    loadFacts()
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, LifecoreLayout.pageInset)
            .padding(.vertical, LifecoreLayout.spacing16)
        }
        .background(LifecoreTheme.semanticCanvas.ignoresSafeArea())
        .navigationTitle("Пам’ять тренера")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFacts() }
    }

    private func loadFacts() {
        let facts = AthleteMemoryStorageService
            .fetchAllFacts(includeCandidates: true, in: modelContext)
            .map { CoachMemoryFactItem(entity: $0) }
        if facts.isEmpty {
            state = .empty
        } else {
            state = .content(facts, isRefreshing: false, isStale: false)
        }
    }
}

private struct CoachMemoryFactCard: View {
    let fact: CoachMemoryFactItem
    let onConfirm: () -> Void
    let onDelete: () -> Void

    private var isCandidate: Bool {
        fact.confirmationStatus == "candidate"
    }

    private var categoryTitleUk: String {
        switch fact.category {
        case "goal": return "Ціль"
        case "injury_note": return "Травма / самопочуття"
        case "nutrition_habit": return "Звичка харчування"
        case "workout_feel": return "Відчуття на тренуванні"
        case "coach_insight": return "Інсайт тренера"
        default: return fact.category
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LifecoreLayout.spacing8) {
            HStack(alignment: .center, spacing: LifecoreLayout.spacing8) {
                Text(categoryTitleUk)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LifecoreTheme.accentTeal)

                if fact.isPinnedGoal {
                    Label("Закріплено", systemImage: "pin.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(LifecoreTheme.statusWarning)
                }

                Spacer()

                Text(isCandidate ? "Кандидат" : "Підтверджено")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isCandidate ? LifecoreTheme.statusWarning : LifecoreTheme.statusOptimal)
                    .padding(.horizontal, LifecoreLayout.spacing8)
                    .padding(.vertical, LifecoreLayout.spacing4)
                    .background(
                        Capsule()
                            .fill((isCandidate ? LifecoreTheme.statusWarning : LifecoreTheme.statusOptimal).opacity(0.12))
                    )
            }

            Text(fact.factTextUk)
                .font(.body)
                .foregroundStyle(LifecoreTheme.semanticPrimaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: LifecoreLayout.spacing12) {
                if isCandidate {
                    Button(action: onConfirm) {
                        Label("Підтвердити", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(LifecoreTheme.statusOptimal)
                            .frame(minHeight: LifecoreLayout.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("btn_confirm_memory_\(fact.id.uuidString)")
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Label("Видалити", systemImage: "trash")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(LifecoreTheme.statusDanger)
                        .frame(minHeight: LifecoreLayout.minTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("btn_delete_memory_\(fact.id.uuidString)")
            }
        }
        .padding(LifecoreLayout.spacing16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LifecoreTheme.semanticCard)
        )
    }
}
