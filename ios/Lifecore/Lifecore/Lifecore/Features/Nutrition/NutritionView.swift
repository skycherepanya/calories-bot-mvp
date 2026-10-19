import SwiftUI

public struct NutritionView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 64))
                        .foregroundStyle(.orange)

                    Text("Frictionless Nutrition")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("Fast camera capture with +12.5% caloric buffer, cooked-state estimation, and 04:00 AM day shift.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Nutrition")
        }
    }
}

#Preview {
    NutritionView()
        .preferredColorScheme(.dark)
}
