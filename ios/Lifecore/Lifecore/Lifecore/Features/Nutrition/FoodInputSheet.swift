import SwiftUI
import PhotosUI

public struct FoodInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let onLog: (_ imageJpegData: Data?, _ textDescription: String?) -> Void

    @State private var textInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isProcessingImage = false

    public init(onLog: @escaping (_ imageJpegData: Data?, _ textDescription: String?) -> Void) {
        self.onLog = onLog
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo Capture / Picker Area
                    photoSection

                    // Text Description Field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Опис страви (необов'язково)", systemImage: "pencil.line")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        TextField("Наприклад: Гречка 150г, куряче філе 120г, огірок...", text: $textInput, axis: .vertical)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(Color(red: 0.1, green: 0.11, blue: 0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                    }

                    // Quick Presets
                    quickPresetsSection

                    // Log Action Button
                    Button(action: handleLog) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Розпізнати та записати")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            canSubmit ?
                            LinearGradient(colors: [.orange, Color(red: 1.0, green: 0.4, blue: 0.0)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(canSubmit ? .black : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: canSubmit ? Color.orange.opacity(0.3) : .clear, radius: 8, y: 3)
                    }
                    .disabled(!canSubmit)
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Новий прийом їжі")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let item = newItem {
                        isProcessingImage = true
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            self.selectedImageData = data
                        }
                        isProcessingImage = false
                    }
                }
            }
        }
    }

    private var canSubmit: Bool {
        selectedImageData != nil || !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var photoSection: some View {
        VStack(spacing: 12) {
            if let imgData = selectedImageData, let uiImage = UIImage(data: imgData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    Button(action: {
                        selectedImageData = nil
                        selectedPhotoItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, Color.black.opacity(0.7))
                            .padding(8)
                    }
                }
            } else {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 38))
                            .foregroundStyle(.orange)

                        Text("Додати фото страви")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("Швидкий аналіз об'єму та інгредієнтів")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .background(Color(red: 0.1, green: 0.11, blue: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Швидкі варіанти")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    presetChip("Вівсянка з ягодами")
                    presetChip("Омлет із 3 яєць")
                    presetChip("Куряче філе з гречкою")
                    presetChip("Протеїновий шейк")
                    presetChip("Лосось із рисом")
                }
            }
        }
    }

    private func presetChip(_ text: String) -> some View {
        Button(action: {
            textInput = text
        }) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        }
    }

    private func handleLog() {
        let text = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let img = selectedImageData
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()

        // Immediate dismiss (<0.2s)
        dismiss()

        // Deliver payload to caller
        onLog(img, text.isEmpty ? nil : text)
    }
}
