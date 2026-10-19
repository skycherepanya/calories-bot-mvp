import SwiftUI

public struct WorkoutsView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)

                    Text("Workouts & Splits")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("1km Auto-splits, heart rate decoupling (EF), elevation response, and interval telemetry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Workouts")
        }
    }
}

#Preview {
    WorkoutsView()
        .preferredColorScheme(.dark)
}
