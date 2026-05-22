import SwiftUI

enum Industry: String, CaseIterable, Identifiable {
    case tech       = "Tech"
    case finance    = "Finance"
    case legal      = "Legal"
    case medical    = "Medical"
    case creative   = "Creative"
    case sales      = "Sales"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .tech:     return "laptopcomputer"
        case .finance:  return "chart.bar.fill"
        case .legal:    return "scale.3d"
        case .medical:  return "cross.fill"
        case .creative: return "paintbrush.fill"
        case .sales:    return "person.2.fill"
        }
    }

    var stylePrompt: String {
        switch self {
        case .tech:     return "modern tech company, clean professional background"
        case .finance:  return "wall street financial district, power suit"
        case .legal:    return "law firm, authoritative professional"
        case .medical:  return "healthcare professional, clinical setting"
        case .creative: return "creative studio, artistic professional"
        case .sales:    return "approachable business professional, warm background"
        }
    }
}

enum HeadshotStyle: String, CaseIterable, Identifiable {
    case conservative = "Conservative"
    case modern       = "Modern"
    case friendly     = "Friendly"

    var id: String { rawValue }
    var description: String {
        switch self {
        case .conservative: return "Formal, traditional, trustworthy"
        case .modern:       return "Clean, contemporary, polished"
        case .friendly:     return "Warm, approachable, personable"
        }
    }

    var icon: String {
        switch self {
        case .conservative: return "briefcase.fill"
        case .modern:       return "sparkles"
        case .friendly:     return "hand.wave.fill"
        }
    }
}

@MainActor
final class StyleSelectorViewModel: ObservableObject {
    @Published var selectedIndustry: Industry = .tech
    @Published var selectedStyle: HeadshotStyle = .modern
    @Published var isGenerating = false
    @Published var error: Error?

    @AppStorage("defaultIndustry") private var savedIndustry = Industry.tech.rawValue
    @AppStorage("defaultStyle")    private var savedStyle = HeadshotStyle.modern.rawValue

    init() {
        selectedIndustry = Industry(rawValue: savedIndustry) ?? .tech
        selectedStyle = HeadshotStyle(rawValue: savedStyle) ?? .modern
    }

    func generate(photos: [UIImage], onJobStarted: @escaping (String) -> Void) {
        isGenerating = true
        savedIndustry = selectedIndustry.rawValue
        savedStyle = selectedStyle.rawValue

        Task {
            do {
                let jobId = try await HeadshotService.shared.submit(
                    photos: photos,
                    industry: selectedIndustry.rawValue,
                    style: selectedStyle.rawValue,
                    tier: "pro"
                )
                onJobStarted(jobId)
            } catch {
                self.error = error
            }
            isGenerating = false
        }
    }
}

struct StyleSelectorView: View {
    let capturedPhotos: [UIImage]

    @EnvironmentObject var coordinator: AppCoordinator
    @StateObject private var viewModel = StyleSelectorViewModel()
    @State private var showPaywall = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    photoPreviewStrip

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Industry", subtitle: "We'll tailor lighting and background")
                        industryGrid
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Style", subtitle: "Choose your professional persona")
                        styleList
                    }

                    generateButton
                }
                .padding()
            }
            .navigationTitle("Choose Your Style")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") { coordinator.goBack() }
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "")
        }
    }

    private var photoPreviewStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(capturedPhotos.indices, id: \.self) { index in
                    Image(uiImage: capturedPhotos[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var industryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
            ForEach(Industry.allCases) { industry in
                IndustryCard(
                    industry: industry,
                    isSelected: viewModel.selectedIndustry == industry
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedIndustry = industry
                    }
                }
            }
        }
    }

    private var styleList: some View {
        VStack(spacing: 10) {
            ForEach(HeadshotStyle.allCases) { style in
                StyleRow(
                    style: style,
                    isSelected: viewModel.selectedStyle == style
                ) {
                    withAnimation(.spring(response: 0.3)) {
                        viewModel.selectedStyle = style
                    }
                }
            }
        }
    }

    private var generateButton: some View {
        Button(action: {
            viewModel.generate(photos: capturedPhotos) { jobId in
                coordinator.generationStarted(jobId: jobId)
            }
        }) {
            HStack {
                if viewModel.isGenerating {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(viewModel.isGenerating ? "Starting Generation..." : "Generate Headshots")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(viewModel.isGenerating)
        .padding(.top, 8)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct IndustryCard: View {
    let industry: Industry
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: industry.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .blue)
                Text(industry.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct StyleRow: View {
    let style: HeadshotStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: style.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(style.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(14)
            .background(isSelected ? Color.blue.opacity(0.08) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
