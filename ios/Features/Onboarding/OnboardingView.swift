import SwiftUI

struct OnboardingSlide: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let gradient: [Color]
}

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let slides: [OnboardingSlide] = [
        OnboardingSlide(
            icon: "person.fill.viewfinder",
            title: "Studio Headshot\nin 30 Seconds",
            subtitle: "Take 4 quick selfies. Our AI generates 20 professional headshots — no photographer needed.",
            gradient: [Color(hex: "667eea"), Color(hex: "764ba2")]
        ),
        OnboardingSlide(
            icon: "wand.and.stars",
            title: "3 Steps,\nNo Upload",
            subtitle: "1. Take selfies  →  2. Pick your style  →  3. Download 4K results. No browser, no waiting.",
            gradient: [Color(hex: "f093fb"), Color(hex: "f5576c")]
        ),
        OnboardingSlide(
            icon: "lock.shield.fill",
            title: "Your Privacy\nIs Protected",
            subtitle: "Photos are never sold or shared. All images are auto-deleted from our servers within 24 hours.",
            gradient: [Color(hex: "4facfe"), Color(hex: "00f2fe")]
        )
    ]

    var body: some View {
        ZStack {
            TabView(selection: $currentPage) {
                ForEach(slides.indices, id: \.self) { index in
                    SlideView(slide: slides[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()

            VStack {
                HStack {
                    Spacer()
                    Button("Skip") {
                        hasSeenOnboarding = true
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding()
                }
                Spacer()
                bottomControls
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 24) {
            PageIndicator(total: slides.count, current: currentPage)

            Button {
                if currentPage < slides.count - 1 {
                    withAnimation { currentPage += 1 }
                } else {
                    hasSeenOnboarding = true
                }
            } label: {
                Text(currentPage < slides.count - 1 ? "Continue" : "Get Started")
                    .fontWeight(.bold)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(16)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

struct SlideView: View {
    let slide: OnboardingSlide

    var body: some View {
        ZStack {
            LinearGradient(colors: slide.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()
                Image(systemName: slide.icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .symbolEffect(.bounce, value: slide.id)

                VStack(spacing: 16) {
                    Text(slide.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text(slide.subtitle)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
                Spacer()
            }
        }
    }
}

struct PageIndicator: View {
    let total: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.white : Color.white.opacity(0.4))
                    .frame(width: index == current ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3), value: current)
            }
        }
    }
}
