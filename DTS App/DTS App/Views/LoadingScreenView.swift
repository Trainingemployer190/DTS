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

                // Overlay gradient for better text readability
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.3),
                        Color.clear,
                        Color.black.opacity(0.4)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Money bag emojis in background
                VStack {
                    HStack {
                        Text("💰")
                            .font(.system(size: 40))
                            .opacity(0.3)
                        Spacer()
                        Text("💰")
                            .font(.system(size: 35))
                            .opacity(0.2)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("💰")
                            .font(.system(size: 30))
                            .opacity(0.25)
                        Spacer()
                        Text("💰")
                            .font(.system(size: 45))
                            .opacity(0.15)
                    }
                    Spacer()
                    HStack {
                        Text("💰")
                            .font(.system(size: 25))
                            .opacity(0.2)
                        Spacer()
                        Text("💰")
                            .font(.system(size: 38))
                            .opacity(0.3)
                    }
                }
                .padding()

                VStack {
                    Spacer()

                    // Money theme centered display
                    VStack(spacing: 20) {
                        Text("💰💰 Make Me Money! 💰💰")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 3, x: 2, y: 2)
                            .multilineTextAlignment(.center)

                        Text("DTS App")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                    }

                    Spacer()

                    // Loading bar container
                    VStack(spacing: 15) {
                        // Loading bar track
                        ZStack(alignment: .leading) {
                            // Track background
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(Color.green, lineWidth: 2)
                                )

                            // Progress fill
                            RoundedRectangle(cornerRadius: 15)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.green, .yellow]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: progress * (geometry.size.width - 80), height: 30)
                                .animation(.easeOut(duration: 0.1), value: progress)

                            // Moving dollar bill
                            HStack {
                                Text("💵")
                                    .font(.system(size: 24))
                                    .offset(x: progress * (geometry.size.width - 120))
                                    .animation(.easeOut(duration: 0.1), value: progress)

                                Spacer()
                            }
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
