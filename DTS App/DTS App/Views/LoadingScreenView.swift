import SwiftUI

// MARK: - Custom Loading Screen

struct LoadingScreenView: View {
    @State private var progress: CGFloat = 0.0
    @State private var isComplete = false
    let onComplete: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with your "Make Me Money" meme image
                Image("loading_background")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // Simple overlay for text readability
                Color.black.opacity(0.3)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    Spacer()

                    // Simple loading bar
                    VStack(spacing: 15) {
                        ZStack(alignment: .leading) {
                            // Track background
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.white.opacity(0.6), lineWidth: 2)
                                )

                            // Progress fill
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.white)
                                .frame(width: progress * (geometry.size.width - 80), height: 30)
                        }
                        .frame(height: 30)
                        .padding(.horizontal, 40)

                        Text("Loading... \(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 1, x: 1, y: 1)
                    }
                    .padding(.bottom, 80)
                }
            }
        }
        .onAppear {
            startLoading()
        }
    }

    private func startLoading() {
        // Simulate loading process with realistic timing
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            progress += 0.015

            if progress >= 1.0 {
                timer.invalidate()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isComplete = true
                    onComplete()
                }
            }
        }
    }
}

#Preview {
    LoadingScreenView {
        print("Loading complete!")
    }
}
