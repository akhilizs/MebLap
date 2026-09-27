import SwiftUI
import CoreLocation

struct ReportHazardView: View {
    let coordinate: CLLocationCoordinate2D
    /// While driving: one tap reports, no extra steps.
    let quickMode: Bool
    let onPickOnMap: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(HazardStore.self) private var hazards
    @State private var selected: HazardType?
    @State private var note = ""

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label(LebanonData.landmarkDescription(for: coordinate) ?? "Selected location",
                          systemImage: "mappin.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(HazardType.allCases) { type in
                            Button { pick(type) } label: {
                                VStack(spacing: 6) {
                                    HazardPin(type: type).scaleEffect(1.3).padding(.top, 4)
                                    Text(type.title).font(.caption.weight(.medium)).multilineTextAlignment(.center)
                                    Text(type.titleAr).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, minHeight: 104)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(selected == type ? type.color.opacity(0.2) : Color(.secondarySystemBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(selected == type ? type.color : .clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !quickMode {
                        TextField("Details (optional) — e.g. right lane, near the bridge", text: $note, axis: .vertical)
                            .textFieldStyle(.roundedBorder)

                        Button {
                            if let selected {
                                hazards.report(selected, at: coordinate, note: note)
                                dismiss()
                            }
                        } label: {
                            Text("Report").font(.headline).frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.orange)
                        .disabled(selected == nil)

                        Button {
                            dismiss()
                            onPickOnMap()
                        } label: {
                            Label("Pick a different spot on the map", systemImage: "hand.tap")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle(quickMode ? "Quick report" : "Report a road hazard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func pick(_ type: HazardType) {
        if quickMode {
            hazards.report(type, at: coordinate)
            dismiss()
        } else {
            selected = type
        }
    }
}

struct HazardDetailView: View {
    let id: UUID

    @Environment(\.dismiss) private var dismiss
    @Environment(HazardStore.self) private var hazards

    var body: some View {
        NavigationStack {
            Group {
                if let report = hazards.report(with: id) {
                    List {
                        Section {
                            HStack(spacing: 14) {
                                HazardPin(type: report.type).scaleEffect(1.4)
                                VStack(alignment: .leading) {
                                    Text(report.type.title).font(.title3.bold())
                                    Text(report.type.titleAr).foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 6)
                            if let landmark = LebanonData.landmarkDescription(for: report.coordinate) {
                                Label(landmark, systemImage: "mappin.circle")
                            }
                            Label("Reported \(Format.relative(report.createdAt))", systemImage: "clock")
                            if report.confirmations > 0 {
                                Label("Confirmed \(report.confirmations)× · last \(Format.relative(report.lastConfirmedAt))",
                                      systemImage: "checkmark.seal")
                            }
                            Label("Expires \(Format.relative(report.expiresAt))", systemImage: "hourglass")
                            if !report.note.isEmpty {
                                Text(report.note)
                            }
                        }
                        Section {
                            Button {
                                hazards.confirm(id)
                                dismiss()
                            } label: {
                                Label("Still there", systemImage: "hand.thumbsup.fill")
                            }
                            Button(role: .destructive) {
                                hazards.remove(id)
                                dismiss()
                            } label: {
                                Label("Not there anymore", systemImage: "hand.thumbsdown.fill")
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("Report expired", systemImage: "clock.badge.xmark")
                }
            }
            .navigationTitle("Road hazard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}
