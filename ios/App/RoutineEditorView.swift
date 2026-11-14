import SwiftUI
import UIKit

struct RoutineEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RoutineDraft
    @State private var isSaving = false
    @State private var error: String?
    let save: (RoutineDraft) async throws -> Void

    init(routine: Routine?, save: @escaping (RoutineDraft) async throws -> Void) {
        _draft = State(initialValue: RoutineDraft(routine: routine))
        self.save = save
    }

    private var saveTitle: String { draft.original == nil ? "Add routine" : "Save routine" }

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    BoardErrorBanner(message: error) { self.error = nil }
                        .listRowInsets(EdgeInsets())
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reminder").font(.subheadline)
                        TextField("Reminder", text: $draft.text, axis: .vertical)
                            .accessibilityLabel("Reminder")
                            .textInputAutocapitalization(.sentences)
                            .frame(minHeight: 44)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repeat").font(.subheadline)
                        Picker("Repeat", selection: $draft.cadence) {
                            ForEach(RoutineDraft.Cadence.allCases, id: \.self) { cadence in
                                Text(cadence.rawValue).tag(cadence)
                            }
                        }
                        .labelsHidden()
                        .frame(minHeight: 44)
                    }
                    if draft.cadence == .weekly {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reminder day").font(.subheadline)
                            Picker("Reminder day", selection: $draft.weekday) {
                                ForEach(0..<7) { day in Text(RoutineSchedule.weekdays[day]).tag(day) }
                            }
                            .labelsHidden()
                            .frame(minHeight: 44)
                        }
                    } else if draft.cadence == .days {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of days").font(.subheadline)
                            TextField("Number of days", text: $draft.days)
                                .keyboardType(.numberPad)
                                .accessibilityLabel("Number of days")
                                .frame(minHeight: 44)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Start date").font(.subheadline)
                            DatePicker("Start date", selection: startDate, displayedComponents: .date)
                                .labelsHidden()
                                .frame(minHeight: 44)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Time").font(.subheadline)
                        DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .frame(minHeight: 44)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Timezone").font(.subheadline)
                        TextField("Timezone", text: $draft.timezone, axis: .vertical)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("Timezone")
                            .frame(minHeight: 44)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Repeat at the same local time. For Tuesday's uniform, choose Monday at 7 pm.")
                        Text("The timezone stays fixed when you travel. Delivery can take up to a minute, plus network delays.")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSaving { AccessibleProgressView("Saving…") }
                        else { Text(saveTitle).fixedSize(horizontal: false, vertical: true) }
                    }
                    .frame(minHeight: 44)
                    .disabled(draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button("Cancel edit") { dismiss() }
                        .frame(minHeight: 44)
                }
            }
            // These pickers represent wall-clock components, not instants in the device timezone.
            .environment(\.calendar, RoutineSchedule.calendar)
            .environment(\.timeZone, RoutineSchedule.calendar.timeZone)
            .disabled(isSaving)
            .tint(.primary)
            .navigationTitle(saveTitle)
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: error) { _, message in
                if let message { UIAccessibility.post(notification: .announcement, argument: message) }
            }
        }
    }

    private var startDate: Binding<Date> {
        Binding(get: { RoutineSchedule.date(draft.startDate)! }, set: {
            draft.startDate = RoutineSchedule.localDate($0, timezone: RoutineSchedule.calendar.timeZone)
        })
    }

    private var time: Binding<Date> {
        Binding(get: {
            RoutineSchedule.calendar.date(from: DateComponents(year: 2001, month: 1, day: 1,
                                                                hour: draft.hour, minute: draft.minute))!
        }, set: {
            draft.hour = RoutineSchedule.calendar.component(.hour, from: $0)
            draft.minute = RoutineSchedule.calendar.component(.minute, from: $0)
        })
    }

    private func submit() async {
        guard !isSaving else { return }
        isSaving = true
        error = nil
        do {
            _ = try draft.values()
            try await save(draft)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
        isSaving = false
    }
}
