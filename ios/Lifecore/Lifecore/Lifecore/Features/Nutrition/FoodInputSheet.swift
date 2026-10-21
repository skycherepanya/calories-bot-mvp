import SwiftUI
import PhotosUI
import UIKit

public struct FoodInputSheet: View {
    @Environment(\.dismiss) private var dismiss

    public let onLog: (_ imageJpegData: Data?, _ textDescription: String?) -> Void

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
                            .accessibilityIdentifier("input_food_text")
                    }

                    // Quick Presets
                    quickPresetsSection

                    // Log Action Button
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
                            LinearGradient(colors: [.orange, Color(red: 1.0, green: 0.4, blue: 0.0)], startPoint: .leading, endPoint: .trailing) :
                            LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(canSubmit ? .black : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: canSubmit ? Color.orange.opacity(0.3) : .clear, radius: 8, y: 3)
                    }
                    .accessibilityIdentifier("btn_submit_food")
                    .disabled(!canSubmit || isProcessingImage)
                    .padding(.top, 10)
                }
                .padding(20)
            }
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
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button(action: { showCamera = true }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.headline)
                                    Text("Камера")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 54)
                                .background(Color.orange.opacity(0.15))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }

                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.headline)
                                Text("Галерея")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color(red: 0.1, green: 0.11, blue: 0.15))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }

                    Text("AI автоматично розпізнає страву, інгредієнти та КБЖУ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(Color(red: 0.08, green: 0.09, blue: 0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
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
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
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
