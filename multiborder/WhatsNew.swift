//
//  WhatsNew.swift
//  multiborder
//
//  The sheet shown once after an update, listing the release's main features.
//

import SwiftUI

enum WhatsNew {
    /// The release the sheet describes. Raise it, and update `features`, for the next release worth a sheet;
    /// people who saw an earlier one then see it once more.
    static let release = "3.0"
    /// Until this day the sheet shows even on new installs, since everyone getting 3.0 early is new to its features.
    /// 2.x recorded nothing that marks every update, so this also catches people who never changed a setting.
    static let showsEveryoneUntil = DateComponents(calendar: .current, year: 2026, month: 11, day: 15).date!

    struct Feature: Identifiable {
        let systemImage: String
        let title: LocalizedStringKey
        let detail: LocalizedStringKey
        var id: String { systemImage }
    }

    static let features = [
        Feature(systemImage: "square.and.arrow.up", title: "Borders from anywhere",
                detail: "Add a border while editing in Photos (More > Extensions > multiborder) and change it later, or add borders from the share sheet or with Shortcuts."),
        Feature(systemImage: "square.dashed", title: "Borders your way",
                detail: "Set a different width for each side, round the corners, add a shadow, or fill the border with a soft blur of the photo."),
        Feature(systemImage: "text.below.photo", title: "Camera settings caption",
                detail: "Show the date taken, title, filename, your handle, camera, focal length, aperture, shutter speed and ISO above and below the photo. Drag them into place, and choose the font and icons."),
        Feature(systemImage: "gearshape", title: "Settings",
                detail: "Save downloads to an album, choose their format and keep each photo’s original date."),
    ]
}

struct WhatsNewSheet: View {

    @Environment(\.dismiss) private var dismiss
    /// Whether the feature tips show, applied as the sheet closes.
    @State var showsTips: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("What’s New")
                            .font(.spaceMono(28))
                            .foregroundStyle(.white)
                            .accessibilityAddTraits(.isHeader)
                        Text("in multiborder \(WhatsNew.release)")
                            .font(.spaceMono(16))
                            .foregroundStyle(.stone400)
                    }
                    ForEach(WhatsNew.features) { feature in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: feature.systemImage)
                                .font(.system(size: 24))
                                .foregroundStyle(.accent)
                                .frame(width: 36)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(feature.title)
                                    .font(.spaceMono(16))
                                    .foregroundStyle(.white)
                                Text(feature.detail)
                                    .font(.spaceMono(13))
                                    .foregroundStyle(.stone300)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 40)
                .padding(.bottom, 16)
            }
            .scrollBounceBehavior(.basedOnSize)

            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $showsTips) {
                    Text("Show me").font(.spaceMono(16)).foregroundStyle(.white)
                }
                .tint(.accent)
                .sensoryFeedback(.selection, trigger: showsTips)
                Text("Point out each new feature the first time you see it.")
                    .font(.spaceMono(12))
                    .foregroundStyle(.stone400)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            Button {
                dismiss()
            } label: {
                Text("Continue")
                    .font(.spaceMono(18))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(.accent, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .background(LinearGradient(colors: [Color(.stone800), Color(.stone900)], startPoint: .top, endPoint: .bottom))
        .preferredColorScheme(.dark)
        // Also when swiped away.
        .onDisappear { FeatureTips.isEnabled = showsTips }
    }
}

#Preview {
    Color.black.sheet(isPresented: .constant(true)) { WhatsNewSheet(showsTips: true) }
}
