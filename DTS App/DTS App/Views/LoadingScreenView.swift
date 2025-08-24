import SwiftUI

// MARK: - Custom Loading Screen

struct LoadingScreenView: View {
    @State private var progress: CGFloat = 0.0
    @State private var isComplete = false
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var floatingOffset: CGFloat = 0
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
                        Color.black.opacity(0.4),
                        Color.clear,
                        Color.black.opacity(0.5)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // Animated money bag emojis in background
                VStack {
                    HStack {
                        Text("💰")
                            .font(.system(size: 40))
                            .opacity(0.4)
                            .rotationEffect(.degrees(rotationAngle))
                            .scaleEffect(pulseScale)
                            .offset(y: floatingOffset)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: floatingOffset)
                        Spacer()
                        Text("💰")
                            .font(.system(size: 35))
                            .opacity(0.3)
                            .rotationEffect(.degrees(-rotationAngle * 0.7))
                            .scaleEffect(pulseScale * 0.9)
                            .offset(y: -floatingOffset * 0.8)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("💰")
                            .font(.system(size: 30))
                            .opacity(0.35)
                            .rotationEffect(.degrees(rotationAngle * 1.2))
                            .scaleEffect(pulseScale * 1.1)
                            .offset(y: floatingOffset * 0.6)
                        Spacer()
                        Text("💰")
                            .font(.system(size: 45))
                            .opacity(0.25)
                            .rotationEffect(.degrees(-rotationAngle * 0.5))
                            .scaleEffect(pulseScale * 0.8)
                            .offset(y: -floatingOffset * 1.2)
                    }
                    Spacer()
                    HStack {
                        Text("💰")
                            .font(.system(size: 25))
                            .opacity(0.3)
                            .rotationEffect(.degrees(rotationAngle * 1.5))
                            .scaleEffect(pulseScale * 1.2)
                            .offset(y: floatingOffset * 0.4)
                        Spacer()
                        Text("💰")
                            .font(.system(size: 38))
                            .opacity(0.4)
                            .rotationEffect(.degrees(-rotationAngle * 0.9))
                            .scaleEffect(pulseScale)
                            .offset(y: -floatingOffset * 0.9)
                    }
                }
                .padding()

                VStack {
                    Spacer()

                    // Animated money theme centered display
                    VStack(spacing: 20) {
                        Text("💰💰 Make Me Money! 💰💰")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundColor(.yellow)
                            .shadow(color: .black, radius: 3, x: 2, y: 2)
                            .multilineTextAlignment(.center)
                            .scaleEffect(pulseScale)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseScale)

                        Text("DTS App")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black, radius: 2, x: 1, y: 1)
                            .offset(y: floatingOffset * 0.3)
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

                            // Animated moving dollar bill
                            HStack {
                                Text("💵")
                                    .font(.system(size: 24))
                                    .rotationEffect(.degrees(rotationAngle * 0.3))
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
            startAnimations()
            startLoading()
        }
    }

    private func startAnimations() {
        // Start continuous rotation animation
        withAnimation(.linear(duration: 8.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Start pulsing animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }

        // Start floating animation
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            floatingOffset = 10
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
