import SwiftUI

struct ContentView: View {
    // MARK: - State
    @State private var nameText = ""
    @State private var statusText = "status: "
    @State private var count = 0
    @State private var dblCount = 0
    @State private var flagOn = false
    @State private var searchText = ""
    @State private var sliderValue: Double = 0
    @State private var selectedSegment = 0
    @State private var pickedColor = "Red"
    @State private var quantity = 0.0
    @State private var progress = 0.5
    @State private var notesText = ""
    @State private var tableSelection: String? = nil
    @State private var showAlert = false
    @State private var isSearchFocused = true

    private let fileItems = ["document.pdf", "photo.jpg", "notes.txt"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Element 1: nameField
                TextField("Name", text: $nameText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("nameField")
                    .onChange(of: nameText) { _, newVal in
                        statusText = "status: \(newVal)"
                    }

                // Element 2: statusLabel
                Text(statusText)
                    .accessibilityIdentifier("statusLabel")

                // Element 3: countLabel
                Text("count: \(count)")
                    .accessibilityIdentifier("countLabel")

                // Element 4: dblLabel
                Text("dbl: \(dblCount)")
                    .accessibilityIdentifier("dblLabel")

                // Element 5: okButton
                Button("OK") { count += 1 }
                    .accessibilityIdentifier("okButton")

                // Element 6: dblButton (double tap via TapGesture)
                Text("Double Tap")
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(6)
                    .accessibilityIdentifier("dblButton")
                    .onTapGesture(count: 2) { dblCount += 1 }

                // Element 7: flagCheckbox
                HStack {
                    Text("Flag:")
                    Toggle("", isOn: $flagOn)
                        .labelsHidden()
                        .accessibilityIdentifier("flagCheckbox")
                        .onChange(of: flagOn) { _, val in
                            statusText = "status: flag=\(val ? "true" : "false")"
                        }
                }

                // Element 8: colorSwatch
                Rectangle()
                    .fill(Color(red: 52/255, green: 120/255, blue: 246/255))
                    .frame(height: 44)
                    .accessibilityIdentifier("colorSwatch")

                // Element 9: searchField
                TextField("Search", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("searchField")

                // Elements 10 & 11: scrollView + scroll-end
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(0..<9, id: \.self) { i in
                            Text("item-\(i)")
                                .accessibilityIdentifier("item-\(i)")
                        }
                        Text("scroll-end")
                            .accessibilityIdentifier("scroll-end")
                    }
                    .padding(8)
                }
                .frame(height: 120)
                .accessibilityIdentifier("scrollView")

                // Elements 12 & 13: slider + sliderValueLabel
                HStack {
                    Slider(value: $sliderValue, in: 0...100)
                        .accessibilityIdentifier("slider")
                    Text("slider: \(Int(sliderValue))")
                        .accessibilityIdentifier("sliderValueLabel")
                }

                // Element 14: rightClickTarget (long press for context menu)
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 44)
                    .overlay(Text("Right Click Here").foregroundColor(.secondary))
                    .accessibilityIdentifier("rightClickTarget")
                    .contextMenu {
                        // Element 15: contextAction
                        Button("ContextAction") {
                            statusText = "status: context-tapped"
                        }
                        .accessibilityIdentifier("contextAction")
                    }

                // Elements 17 & 18: modeSegment + segmentLabel
                Picker("Mode", selection: $selectedSegment) {
                    Text("Alpha").tag(0)
                    Text("Beta").tag(1)
                    Text("Gamma").tag(2)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("modeSegment")

                Text("segment: \(selectedSegment)")
                    .accessibilityIdentifier("segmentLabel")

                // Elements 19 & 20: colorPicker + pickerLabel
                HStack {
                    Menu {
                        Button("Red") { pickedColor = "Red" }
                        Button("Green") { pickedColor = "Green" }
                        Button("Blue") { pickedColor = "Blue" }
                    } label: {
                        Text("Color")
                    }
                    .accessibilityIdentifier("colorPicker")

                    Text("pick: \(pickedColor)")
                        .accessibilityIdentifier("pickerLabel")
                }

                // Elements 21 & 22: quantityStepper + quantityLabel
                HStack {
                    Stepper("", value: $quantity, in: 0...10, step: 1)
                        .labelsHidden()
                        .accessibilityIdentifier("quantityStepper")
                    Text("qty: \(Int(quantity))")
                        .accessibilityIdentifier("quantityLabel")
                }

                // Elements 23 & 24: uploadProgress + advanceButton
                ProgressView(value: progress)
                    .accessibilityIdentifier("uploadProgress")
                    .accessibilityValue(String(format: "%.1f", progress))

                Button("Advance") { progress = 1.0 }
                    .accessibilityIdentifier("advanceButton")

                // Element 25: notesArea
                TextEditor(text: $notesText)
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.4))
                    .accessibilityIdentifier("notesArea")

                // Element 26: termsLink
                Button("Terms & Conditions") {
                    statusText = "status: link-tapped"
                }
                .accessibilityIdentifier("termsLink")

                // Elements 27-31: fileTable + tableSelLabel
                VStack(spacing: 0) {
                    ForEach(fileItems, id: \.self) { filename in
                        Button(action: {
                            tableSelection = filename
                        }) {
                            HStack {
                                Text(filename)
                                    .foregroundColor(.primary)
                                    .accessibilityIdentifier("row-\(filename)")
                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                        }
                        .accessibilityIdentifier("row-\(filename)")
                        Divider()
                    }
                }
                .background(Color(UIColor.systemBackground))
                .border(Color.secondary.opacity(0.3))
                .accessibilityIdentifier("fileTable")

                Text("table-sel: \(tableSelection ?? "none")")
                    .accessibilityIdentifier("tableSelLabel")

                // Elements 32-34: alertButton + alert
                Button("Show Alert") { showAlert = true }
                    .accessibilityIdentifier("alertButton")
                    .alert("Are you sure?", isPresented: $showAlert) {
                        Button("Confirm") {
                            statusText = "status: alert-confirmed"
                        }
                        .accessibilityIdentifier("confirmButton")
                        Button("Cancel", role: .cancel) {
                            statusText = "status: alert-cancelled"
                        }
                        .accessibilityIdentifier("cancelButton")
                    }

                // Elements 35 & 36: lockedButton + disabledLabel
                HStack {
                    Button("Locked") {}
                        .disabled(true)
                        .accessibilityIdentifier("lockedButton")
                    Text("locked: true")
                        .accessibilityIdentifier("disabledLabel")
                }
            }
            .padding(16)
        }
        .toolbar {
            // Element 16: toggleFlag
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Toggle Flag") {
                    flagOn.toggle()
                    statusText = "status: flag=\(flagOn ? "true" : "false")"
                }
                .accessibilityIdentifier("toggleFlag")
            }
        }
    }
}
