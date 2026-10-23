import SwiftUI

// A celebration, not an explanation (DECISIONS 029): once a week, last week's
// leftover allowance becomes a ticket for something it could buy. Tearing off
// the stub dismisses it.
struct WeeklyReportView: View {
    let report: WeeklyReport
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var isPresented = false
    @State private var isStubTorn = false
    @State private var isDismissing = false

    private static let cornerRadius: CGFloat = 20
    private static let notchRadius: CGFloat = 8

    // Whole dollars, rounded down, so the ticket never promises a cent that
    // wasn't there.
    private var displayedLeft: Decimal {
        report.left.rounded(scale: 0, mode: .down)
    }

    private var tier: Tier? { Tier.matching(displayedLeft) }

    static func hasTicket(for report: WeeklyReport) -> Bool {
        Tier.matching(report.left.rounded(scale: 0, mode: .down)) != nil
    }

    var body: some View {
        ZStack {
            Color.leftReportScrim
                .ignoresSafeArea()
                .opacity(isPresented ? 1 : 0)
                .onTapGesture { dismiss(tearing: false) }
                .accessibilityHidden(true)

            if let tier {
                ViewThatFits(in: .vertical) {
                    ticket(tier)
                    ScrollView { ticket(tier) }
                        .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.lg)
                .scaleEffect(isPresented ? 1 : 0.94)
                .opacity(isPresented ? 1 : 0)
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { dismiss(tearing: false) }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.2)) {
                isPresented = true
            }
        }
    }

    // MARK: - Ticket

    private func ticket(_ tier: Tier) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                header(tier)
                artwork(tier)
            }
            .background(tier.ground.fill, in: TicketShape(notchEdge: .bottom,
                                                          cornerRadius: Self.cornerRadius,
                                                          notchRadius: Self.notchRadius))

            stub(tier)
                .rotationEffect(.degrees(isStubTorn ? 7 : 0), anchor: .topLeading)
                .offset(y: isStubTorn ? 420 : 0)
                .opacity(isStubTorn ? 0 : 1)
        }
        .foregroundStyle(Color.leftReportInk)
        .tracking(BudgetTypography.appTracking)
    }

    private func header(_ tier: Tier) -> some View {
        VStack(spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text("Last week")
                Spacer(minLength: AppSpacing.sm)
                Text((report.weekStart..<report.lastDay).formatted(.interval.month(.abbreviated).day()))
            }
            .font(.dmSans(.caption, weight: .medium))
            .textCase(.uppercase)
            .foregroundStyle(tier.ground.label)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last week, \((report.weekStart..<report.lastDay).formatted(.interval.month(.wide).day()))")

            Rectangle()
                .fill(tier.ground.rule)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.top, AppSpacing.lg)
        .padding(.horizontal, AppSpacing.lg)
    }

    private func artwork(_ tier: Tier) -> some View {
        VStack(spacing: AppSpacing.lg) {
            Image(tier.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 120 : 190)
                .accessibilityLabel(tier.imageDescription)

            VStack(spacing: AppSpacing.sm) {
                HeroMoneyText(amount: displayedLeft, size: 48, suffix: "left.", showsCents: false)
                    .frame(maxWidth: .infinity)

                Text(tier.caption)
                    .font(.dmSans(.body))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, AppSpacing.lg)
        .padding([.horizontal, .bottom], AppSpacing.lg)
    }

    private func stub(_ tier: Tier) -> some View {
        Button { dismiss(tearing: true) } label: {
            Text("Tear it off")
                .font(.dmSans(.callout, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(tier.ground.stub, in: TicketShape(notchEdge: .top,
                                                      cornerRadius: Self.cornerRadius,
                                                      notchRadius: Self.notchRadius))
        .overlay(alignment: .top) {
            Perforation()
                .stroke(tier.ground.perforation, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(height: 1)
                .padding(.horizontal, Self.notchRadius + AppSpacing.xxs)
                .accessibilityHidden(true)
        }
        .accessibilityHint("Dismisses last week's report")
    }

    // MARK: - Dismissal

    private func dismiss(tearing: Bool) {
        guard !isDismissing else { return }
        isDismissing = true

        guard tearing, !reduceMotion else {
            withAnimation(.easeOut(duration: 0.2)) {
                isPresented = false
            } completion: {
                onDismiss()
            }
            return
        }

        // A short run of light taps reads as paper ripping.
        Task { @MainActor in
            for _ in 0..<3 {
                HapticFeedback.lightImpact()
                try? await Task.sleep(for: .milliseconds(45))
            }
        }
        withAnimation(.easeIn(duration: 0.35)) {
            isStubTorn = true
        }
        withAnimation(.easeOut(duration: 0.25).delay(0.2)) {
            isPresented = false
        } completion: {
            onDismiss()
        }
    }
}

// MARK: - Tiers

private extension WeeklyReportView {
    enum Ground {
        case tan, periwinkle, butter

        var fill: Color {
            switch self {
            case .tan: .leftReportTan
            case .periwinkle: .leftReportPeriwinkle
            case .butter: .leftReportButter
            }
        }

        var label: Color {
            switch self {
            case .tan: .leftReportTanLabel
            case .periwinkle: .leftReportPeriwinkleLabel
            case .butter: .leftReportButterLabel
            }
        }

        var rule: Color {
            switch self {
            case .tan: .leftReportTanRule
            case .periwinkle: .leftReportPeriwinkleRule
            case .butter: .leftReportButterRule
            }
        }

        var perforation: Color {
            switch self {
            case .tan: .leftReportTanPerforation
            case .periwinkle: .leftReportPeriwinklePerforation
            case .butter: .leftReportButterPerforation
            }
        }

        var stub: Color {
            switch self {
            case .tan: .leftReportTanStub
            case .periwinkle: .leftReportPeriwinkleStub
            case .butter: .leftReportButterStub
            }
        }
    }

    // Grounds rotate for variety; they never imply a good or bad week.
    struct Tier {
        let minimum: Decimal
        let imageName: String
        let imageDescription: String
        let caption: String
        let ground: Ground

        // Ascending. The highest minimum at or below the leftover wins.
        static let all: [Tier] = [
            Tier(minimum: 4, imageName: "WeeklyIcedTea",
                 imageDescription: "A can of iced tea",
                 caption: "That’s enough for at least one iced tea.", ground: .tan),
            Tier(minimum: 22, imageName: "WeeklyUmbrella",
                 imageDescription: "Someone running through the rain",
                 caption: "That’s enough for a new umbrella.", ground: .periwinkle),
            Tier(minimum: 58, imageName: "WeeklyMovieDate",
                 imageDescription: "Two people sharing popcorn at the movies",
                 caption: "That’s perfect for a movie date.", ground: .butter),
            Tier(minimum: 94, imageName: "WeeklyFancyDinner",
                 imageDescription: "A whole fish on a plate",
                 caption: "Enough to not be afraid when the waiter says “market price.”", ground: .tan),
            Tier(minimum: 178, imageName: "WeeklyConcert",
                 imageDescription: "A hand holding a drink and concert tickets",
                 caption: "Enough for a concert and overpriced drinks.", ground: .butter),
            Tier(minimum: 412, imageName: "WeeklyWeekendAway",
                 imageDescription: "A small house among trees",
                 caption: "That’s a relaxing weekend away.", ground: .tan),
            Tier(minimum: 738, imageName: "WeeklyFlight",
                 imageDescription: "A plane flying through clouds",
                 caption: "That’s a flight to somewhere warm.", ground: .periwinkle),
        ]

        // TODO: Weeks under the lowest tier, including zero and overspent
        // weeks, get no report until that ticket is designed.
        static func matching(_ left: Decimal) -> Tier? {
            all.last { left >= $0.minimum }
        }
    }
}

// MARK: - Shapes

// The ticket is two pieces so each keeps its half of the notch when torn.
// Notches are true cutouts, so whatever is behind the ticket shows through.
private struct TicketShape: Shape {
    let notchEdge: VerticalEdge
    let cornerRadius: CGFloat
    let notchRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let rounded = notchEdge == .bottom
            ? UnevenRoundedRectangle(topLeadingRadius: cornerRadius,
                                     topTrailingRadius: cornerRadius,
                                     style: .continuous)
            : UnevenRoundedRectangle(bottomLeadingRadius: cornerRadius,
                                     bottomTrailingRadius: cornerRadius,
                                     style: .continuous)
        let y = notchEdge == .bottom ? rect.maxY : rect.minY
        let diameter = notchRadius * 2
        var notches = Path()
        notches.addEllipse(in: CGRect(x: rect.minX - notchRadius, y: y - notchRadius,
                                      width: diameter, height: diameter))
        notches.addEllipse(in: CGRect(x: rect.maxX - notchRadius, y: y - notchRadius,
                                      width: diameter, height: diameter))
        return rounded.path(in: rect).subtracting(notches)
    }
}

private struct Perforation: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

private extension Color {
    // MARK: - Weekly report (DECISIONS 029)

    // Celebration grounds, not plan meaning. The ticket keeps its light ground
    // in both appearances because the artwork is drawn on light paper, so each
    // role resolves to the same value in dark mode. Every tint is solid: labels
    // meet 4.5:1 on their ground, and nothing layers opacity over the artwork.
    static let leftReportTan = reportColor(0xE7E2D0)
    static let leftReportTanLabel = reportColor(0x636259)
    static let leftReportTanRule = reportColor(0xD6D2C1)
    static let leftReportTanPerforation = reportColor(0xBCB9AA)
    static let leftReportTanStub = reportColor(0xF2EFE5)

    static let leftReportPeriwinkle = reportColor(0xA5B7F1)
    static let leftReportPeriwinkleLabel = reportColor(0x414858)
    static let leftReportPeriwinkleRule = reportColor(0x99AADF)
    static let leftReportPeriwinklePerforation = reportColor(0x8896C4)
    static let leftReportPeriwinkleStub = reportColor(0xCED7F7)

    static let leftReportButter = reportColor(0xF5F2AE)
    static let leftReportButterLabel = reportColor(0x68684C)
    static let leftReportButterRule = reportColor(0xE3E0A1)
    static let leftReportButterPerforation = reportColor(0xC8C68E)
    static let leftReportButterStub = reportColor(0xFAF8D2)

    // Ink on every report ground, regardless of appearance.
    static let leftReportInk = reportColor(0x121212)

    // Intentionally translucent: its job is to let Today show
    // through behind the ticket.
    static let leftReportScrim = Color.black.opacity(0.4)

    static func reportColor(_ hex: UInt) -> Color {
        Color(.sRGB,
              red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255,
              opacity: 1)
    }
}
