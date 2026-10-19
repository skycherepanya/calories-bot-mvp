import SwiftUI

public struct TrendsView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.08).ignoresSafeArea()

                VStack(spacing: 20) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 64))
                        .foregroundStyle(.cyan)

                    Text("Longitudinal Trends")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    Text("7-day and 14-day rolling body weight averages, HRV baseline drifts, and autonomic stability.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .navigationTitle("Trends")
        }
    }
}

#Preview {
    TrendsView()
        .preferredColorScheme(.dark)
}
