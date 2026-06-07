import SwiftUI

private let autoDismissSeconds: TimeInterval = 5

struct WelcomeView: View {
    let onGetStarted: () -> Void
    @State private var didFinish = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Welcome")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Check current conditions and a multi-day forecast for any city.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Get started") {
                finish()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .padding(24)
        .task {
            try? await Task.sleep(for: .seconds(autoDismissSeconds))
            finish()
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onGetStarted()
    }
}

#Preview {
    WelcomeView(onGetStarted: {})
}
