import SwiftUI
import PhotosUI
import UIKit

public struct FoodInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let onLog: (_ imageJpegData: Data?, _ textDescription: String?) -> Void

    fileprivate static let isCameraAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)

    @State private var textInput: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var isProcessingImage = false
    @State private var showCamera = false

    public init(onLog: @escaping (_ imageJpegData: Data?, _ textDescription: String?) -> Void) {
        self.onLog = onLog
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Block 1: Compact Photo / Camera Area
                    photoSection

                    // Block 2: Text Description & Presets
                    textSection

                    // Submit Action Button
                    submitButton
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("sheet_food_input")
            .background(Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Новий прийом їжі")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати") { dismiss() }
                        .accessibilityIdentifier("btn_close_food_input")
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView { capturedImage in
                    processAndStoreImage(capturedImage)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let item = newItem {
                        isProcessingImage = true
                        if let rawData = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: rawData) {
                            await MainActor.run {
                                processAndStoreImage(uiImage)
                            }
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

    // MARK: - Block 1: Media / Photo Capture

    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Фото страви (опціонально)", systemImage: "camera.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            if let imgData = selectedImageData, let uiImage = UIImage(data: imgData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 140)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button(action: {
                        selectedImageData = nil
                        selectedPhotoItem = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white, Color.black.opacity(0.7))
                            .padding(8)
                    }
                }
            } else {
                HStack(spacing: 12) {
                    if Self.isCameraAvailable {
                        Button(action: { showCamera = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.fill")
                                    .font(.subheadline)
                                Text("Камера")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(LifecoreTheme.strainOrange.opacity(0.14))
                            .foregroundStyle(LifecoreTheme.strainOrange)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(LifecoreTheme.strainOrange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.subheadline)
                            Text("Галерея")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 0.1, green: 0.11, blue: 0.15))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Block 2: Text Description & Presets

    private var textSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Опис страви", systemImage: "pencil.line")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if textInput.isEmpty {
                    Text("Наприклад: Гречка 150г, куряче філе 120г, огірок...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $textInput)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: 80, maxHeight: 110)
                    .accessibilityIdentifier("input_food_text")
            }
            .background(Color(red: 0.1, green: 0.11, blue: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            quickPresetsSection
        }
    }

    private var submitButton: some View {
        Button(action: handleLog) {
            HStack(spacing: 8) {
                if isProcessingImage {
                    ProgressView()
                        .tint(.black)
                    Text("Обробка фото...")
                        .fontWeight(.bold)
                } else {
                    Image(systemName: "sparkles")
                    Text("Розпізнати та записати")
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                canSubmit ?
                LinearGradient(colors: [LifecoreTheme.strainOrange, Color(red: 1.0, green: 0.35, blue: 0.0)], startPoint: .leading, endPoint: .trailing) :
                LinearGradient(colors: [.gray.opacity(0.25), .gray.opacity(0.25)], startPoint: .leading, endPoint: .trailing)
            )
            .foregroundStyle(canSubmit ? .black : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: canSubmit ? LifecoreTheme.strainOrange.opacity(0.3) : .clear, radius: 8, y: 3)
        }
        .accessibilityIdentifier("btn_submit_food")
        .disabled(!canSubmit || isProcessingImage)
        .padding(.top, 6)
    }

    private func processAndStoreImage(_ image: UIImage) {
        let maxDimension: CGFloat = 1280.0
        let originalSize = image.size
        var targetImage = image

        if max(originalSize.width, originalSize.height) > maxDimension {
            let scale = maxDimension / max(originalSize.width, originalSize.height)
            let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            targetImage = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }

        if let jpegData = targetImage.jpegData(compressionQuality: 0.75) {
            self.selectedImageData = jpegData
        }
    }

    private var quickPresetsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Швидкі варіанти")
                .font(.caption2)
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
        .padding(.top, 4)
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
        .accessibilityIdentifier(text == "Вівсянка з ягодами" ? "preset_oatmeal" : "preset_\(text)")
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

// MARK: - Camera Picker View

struct CameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = FoodInputSheet.isCameraAvailable ? .camera : .photoLibrary
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
