import SwiftUI

public struct MealReviewSheet: View {
    @ObservedObject public var viewModel: NutritionViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: MealReviewDraft
    @State private var isSubmitting = false

    public init(viewModel: NutritionViewModel) {
        self.viewModel = viewModel
        if case .review(let d) = viewModel.captureState {
            _draft = State(initialValue: d)
        } else {
            _draft = State(initialValue: MealReviewDraft())
        }
    }

    public var body: some View {
        NavigationStack {
            content
                .background(LifecoreTheme.paperCanvas.ignoresSafeArea())
                .navigationTitle(navigationTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Скасувати") {
                            viewModel.cancelCapture()
                            dismiss()
                        }
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    }

                    if case .review = viewModel.captureState {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Підтвердити") {
                                confirmAction()
                            }
                            .bold()
                            .foregroundStyle(LifecoreTheme.statusWarning)
                            .accessibilityIdentifier("meal_review_confirm")
                            .disabled(isSubmitting)
                        }
                    }
                }
        }
        .onAppear {
            syncDraftWithState()
        }
        .onChange(of: viewModel.captureState) { _, _ in
            syncDraftWithState()
        }
    }

    private var navigationTitle: String {
        switch viewModel.captureState {
        case .analyzing:
            return "Аналіз страви"
        case .failed:
            return "Помилка розпізнавання"
        case .review:
            return "Перевірка страви"
        case .draft, .idle:
            return "Новий прийом їжі"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.captureState {
        case .analyzing(let text, let imageData):
            analyzingView(text: text, imageData: imageData)
        case .failed(let messageUk, let preservedText, let preservedImageData):
            failedView(messageUk: messageUk, preservedText: preservedText, preservedImageData: preservedImageData)
        case .review:
            reviewForm
        case .draft, .idle:
            emptyOrIdleView
        }
    }

    // MARK: - Analyzing State View

    private func analyzingView(text: String, imageData: Data?) -> some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .controlSize(.large)
                .tint(LifecoreTheme.accentTeal)

            VStack(spacing: 8) {
                Text("Аналізую страву...")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(LifecoreTheme.inkPrimary)

                Text("ШІ оцінює макроси та автоматично застосовує +12.5% дефіцитний буфер.")
                    .font(.subheadline)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if let imgData = imageData, let uiImg = UIImage(data: imgData) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .frame(maxWidth: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
            }

            if !text.isEmpty {
                Text("«\(text)»")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button("Скасувати") {
                viewModel.cancelCapture()
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(LifecoreTheme.inkSecondary)
            .padding(.bottom, 24)
        }
        .padding()
    }

    // MARK: - Failed State View

    private func failedView(messageUk: String, preservedText: String, preservedImageData: Data?) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .padding(.top, 24)

                VStack(spacing: 8) {
                    Text("Не вдалося розпізнати страву")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(LifecoreTheme.inkPrimary)

                    Text(messageUk)
                        .font(.subheadline)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                if !preservedText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Збережений опис")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                        Text(preservedText)
                            .font(.subheadline)
                            .foregroundStyle(LifecoreTheme.inkPrimary)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(LifecoreTheme.paperWell)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal, 16)
                }

                if let data = preservedImageData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .frame(maxWidth: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.retryLastAnalysis()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Повторити спробу")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LifecoreTheme.accentPrimary)
                        .foregroundStyle(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .accessibilityIdentifier("meal_analysis_retry")

                    Button(action: {
                        viewModel.switchToManualEntry()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                            Text("Ввести параметри вручну")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LifecoreTheme.paperCard)
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                        )
                    }

                    Button("Скасувати") {
                        viewModel.cancelCapture()
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - Review Form View

    private var reviewForm: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Error Banner if present
                if let err = viewModel.errorMessage {
                    errorBanner(err)
                }

                // Preserved Image Thumbnail if available
                if let data = draft.preservedImageData, let uiImg = UIImage(data: data) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 120)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // Section 1: Meal Name
                mealNameSection

                // Section 2: Energy Balance (+12.5% buffer explained)
                calorieBufferSection

                // Section 3: Macronutrients
                macrosSection

                // Section 4: Weight & Confidence
                weightAndConfidenceSection

                // Section 5: Taxonomy Quality Tags
                tagsSection

                // Section 6: Action Buttons
                actionsSection
            }
            .padding(16)
        }
    }

    private var emptyOrIdleView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Підготовка...")
                .font(.subheadline)
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Subsections

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.octagon.fill")
                .foregroundStyle(LifecoreTheme.statusDanger)
            Text(message)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.statusDanger)
            Spacer()
        }
        .padding(12)
        .background(LifecoreTheme.statusDanger.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var mealNameSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Назва страви")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.inkSecondary)

            TextField("Введіть назву", text: $draft.mealName)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(LifecoreTheme.paperCard)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                )
        }
    }

    private var calorieBufferSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Калорійність", systemImage: "flame.fill")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(LifecoreTheme.statusWarning)
                Spacer()
                Text("+12.5% буфер дефіциту")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LifecoreTheme.statusWarning.opacity(0.14))
                    .foregroundStyle(LifecoreTheme.statusWarning)
                    .clipShape(Capsule())
            }

            // Explainable calculation callout
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("Базова оцінка:")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    Text("\(Int(draft.kcalExact)) ккал")
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.inkPrimary)
                    Text("+ 12.5% =")
                        .font(.caption)
                        .foregroundStyle(LifecoreTheme.statusWarning)
                    Text("\(Int(draft.kcal)) ккал")
                        .font(.caption)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(LifecoreTheme.statusWarning)
                }

                Text("Детермінований буфер захищає від заниження калорій у ресторанних стравах та прихованих оліях.")
                    .font(.system(size: 10))
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LifecoreTheme.paperWell)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Калорії (з буфером)")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    TextField("ккал", value: Binding(
                        get: { draft.kcal },
                        set: { draft.updateBufferedKcal($0) }
                    ), format: .number)
                    .font(.headline)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(LifecoreTheme.paperCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LifecoreTheme.statusWarning.opacity(0.4), lineWidth: 1)
                    )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Базова оцінка (без буфера)")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)
                    TextField("ккал", value: Binding(
                        get: { draft.kcalExact },
                        set: { draft.updateKcalExact($0) }
                    ), format: .number)
                    .font(.headline)
                    .monospacedDigit()
                    .keyboardType(.numberPad)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(LifecoreTheme.paperCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
                }
            }
        }
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    private var macrosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Макронутрієнти (не масштабуються)", systemImage: "chart.bar.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.accentTeal)

            HStack(spacing: 10) {
                macroField(
                    title: "Білки",
                    color: LifecoreTheme.accentTeal,
                    value: Binding(
                        get: { draft.protein },
                        set: { draft.protein = max(0, $0) }
                    )
                )

                macroField(
                    title: "Жири",
                    color: LifecoreTheme.statusWarning,
                    value: Binding(
                        get: { draft.fat },
                        set: { draft.fat = max(0, $0) }
                    )
                )

                macroField(
                    title: "Вуглеводи",
                    color: LifecoreTheme.statusOptimal,
                    value: Binding(
                        get: { draft.carbs },
                        set: { draft.carbs = max(0, $0) }
                    )
                )
            }
        }
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    private func macroField(title: String, color: Color, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(color)

            HStack(spacing: 2) {
                TextField("0", value: value, format: .number)
                    .font(.headline)
                    .monospacedDigit()
                    .keyboardType(.decimalPad)
                Text("г")
                    .font(.caption)
                    .foregroundStyle(LifecoreTheme.inkSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(LifecoreTheme.paperCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color.opacity(0.3), lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var weightAndConfidenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Оцінена вага страви")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)

                    HStack(spacing: 2) {
                        TextField("Не вказано", value: Binding(
                            get: { draft.weightG },
                            set: { draft.weightG = $0.map { max(0, $0) } }
                        ), format: .number)
                        .font(.subheadline)
                        .monospacedDigit()
                        .keyboardType(.numberPad)
                        Text("г")
                            .font(.caption)
                            .foregroundStyle(LifecoreTheme.inkSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(LifecoreTheme.paperCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Confidence badge
                VStack(alignment: .leading, spacing: 4) {
                    Text("Впевненість ШІ")
                        .font(.caption2)
                        .foregroundStyle(LifecoreTheme.inkSecondary)

                    let confPercent = Int((draft.confidence ?? 0.85) * 100)
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("~\(confPercent)%")
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(LifecoreTheme.paperCard)
                    .foregroundStyle(LifecoreTheme.accentTeal)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(LifecoreTheme.ruleHairline, lineWidth: 1)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("Оцінка ШІ базується на візуальному об'ємі страви без медичних гарантій. За потреби скоригуйте вагу вручну.")
                .font(.system(size: 10))
                .foregroundStyle(LifecoreTheme.inkSecondary)
        }
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Якісні теги харчування", systemImage: "tag.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(LifecoreTheme.inkSecondary)

            FlowLayout(spacing: 8) {
                tagToggleButton(tag: "whole_food", title: "Цільна їжа", color: LifecoreTheme.statusOptimal)
                tagToggleButton(tag: "ultra_processed", title: "Ультраперероблена", color: LifecoreTheme.statusDanger)
                tagToggleButton(tag: "solid", title: "Тверда", color: LifecoreTheme.accentIndigo)
                tagToggleButton(tag: "liquid", title: "Рідка", color: Color.purple)
                tagToggleButton(tag: "fast_absorbing", title: "Швидка", color: LifecoreTheme.statusWarning)
                tagToggleButton(tag: "slow_absorbing", title: "Повільна", color: LifecoreTheme.accentTeal)
                tagToggleButton(tag: "high_sodium", title: "Солона", color: LifecoreTheme.statusWarning)
            }
        }
        .lifecoreGlassCard(cornerRadius: 16, padding: 14)
    }

    private func tagToggleButton(tag: String, title: String, color: Color) -> some View {
        let isSelected = draft.tags.contains(tag)
        return Button(action: {
            toggleTag(tag)
        }) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.18) : LifecoreTheme.paperWell)
            .foregroundStyle(isSelected ? color : LifecoreTheme.inkSecondary)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? color : LifecoreTheme.ruleHairline, lineWidth: 1)
            )
        }
    }

    private func toggleTag(_ tag: String) {
        var tags = draft.tags
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }
        draft.tags = NutritionNormalizer.normalizeTags(tags)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: confirmAction) {
                HStack(spacing: 8) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    Text("Підтвердити та записати")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LifecoreTheme.accentPrimary)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityIdentifier("meal_review_confirm")
            .disabled(isSubmitting)

            Button(action: {
                Task {
                    await viewModel.retryLastAnalysis()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Повторити розпізнавання ШІ")
                        .font(.footnote)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(LifecoreTheme.inkSecondary)
                .padding(.vertical, 6)
            }
            .accessibilityIdentifier("meal_analysis_retry")
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func confirmAction() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            do {
                _ = try await viewModel.confirmReview(draft)
                isSubmitting = false
                dismiss()
            } catch {
                isSubmitting = false
                // Error description is already set on viewModel.errorMessage
            }
        }
    }

    private func syncDraftWithState() {
        if case .review(let d) = viewModel.captureState {
            draft = d
        }
    }
}

// MARK: - FlowLayout Helper for Tag Chips

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: width, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
