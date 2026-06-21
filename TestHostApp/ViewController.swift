import UIKit

class ViewController: UIViewController {

    // MARK: - State
    private var count = 0
    private var dblCount = 0
    private var flagOn = false

    // MARK: - Element 1: nameField
    private let nameField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Name"
        tf.borderStyle = .roundedRect
        tf.accessibilityIdentifier = "nameField"
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    // MARK: - Element 2: statusLabel
    private let statusLabel: UILabel = {
        let l = UILabel()
        l.text = "status: "
        l.accessibilityIdentifier = "statusLabel"
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Element 3: countLabel
    private let countLabel: UILabel = {
        let l = UILabel()
        l.text = "count: 0"
        l.accessibilityIdentifier = "countLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Element 4: dblLabel
    private let dblLabel: UILabel = {
        let l = UILabel()
        l.text = "dbl: 0"
        l.accessibilityIdentifier = "dblLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Element 5: okButton
    private let okButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("OK", for: .normal)
        b.accessibilityIdentifier = "okButton"
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Element 6: dblButton
    private let dblButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Double Tap", for: .normal)
        b.accessibilityIdentifier = "dblButton"
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Element 7: flagCheckbox
    private let flagCheckbox: UISwitch = {
        let s = UISwitch()
        s.isOn = false
        s.accessibilityIdentifier = "flagCheckbox"
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Element 8: colorSwatch
    private let colorSwatch: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 52/255, green: 120/255, blue: 246/255, alpha: 1)
        v.accessibilityIdentifier = "colorSwatch"
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Element 9: searchField
    private let searchField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Search"
        tf.borderStyle = .roundedRect
        tf.accessibilityIdentifier = "searchField"
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    // MARK: - Elements 10 & 11: scrollView + scroll-end
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.accessibilityIdentifier = "scrollView"
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let scrollContentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // MARK: - Element 12: slider, Element 13: sliderValueLabel
    private let slider: UISlider = {
        let s = UISlider()
        s.minimumValue = 0
        s.maximumValue = 100
        s.value = 0
        s.accessibilityIdentifier = "slider"
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let sliderValueLabel: UILabel = {
        let l = UILabel()
        l.text = "slider: 0"
        l.accessibilityIdentifier = "sliderValueLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Element 14: rightClickTarget
    private let rightClickTarget: UIView = {
        let v = UIView()
        v.backgroundColor = .systemGray5
        v.accessibilityIdentifier = "rightClickTarget"
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // MARK: - Element 17: modeSegment, Element 18: segmentLabel
    private let modeSegment: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Alpha", "Beta", "Gamma"])
        sc.selectedSegmentIndex = 0
        sc.accessibilityIdentifier = "modeSegment"
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let segmentLabel: UILabel = {
        let l = UILabel()
        l.text = "segment: 0"
        l.accessibilityIdentifier = "segmentLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Element 19: colorPicker, Element 20: pickerLabel
    private let pickerLabel: UILabel = {
        let l = UILabel()
        l.text = "pick: Red"
        l.accessibilityIdentifier = "pickerLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var colorPicker: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Color", for: .normal)
        b.accessibilityIdentifier = "colorPicker"
        b.translatesAutoresizingMaskIntoConstraints = false
        let red = UIAction(title: "Red", identifier: UIAction.Identifier("Red")) { [weak self] _ in
            self?.pickerLabel.text = "pick: Red"
        }
        let green = UIAction(title: "Green", identifier: UIAction.Identifier("Green")) { [weak self] _ in
            self?.pickerLabel.text = "pick: Green"
        }
        let blue = UIAction(title: "Blue", identifier: UIAction.Identifier("Blue")) { [weak self] _ in
            self?.pickerLabel.text = "pick: Blue"
        }
        b.menu = UIMenu(title: "", children: [red, green, blue])
        b.showsMenuAsPrimaryAction = true
        return b
    }()

    // MARK: - Element 21: quantityStepper, Element 22: quantityLabel
    private let quantityStepper: UIStepper = {
        let s = UIStepper()
        s.minimumValue = 0
        s.maximumValue = 10
        s.value = 0
        s.stepValue = 1
        s.accessibilityIdentifier = "quantityStepper"
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let quantityLabel: UILabel = {
        let l = UILabel()
        l.text = "qty: 0"
        l.accessibilityIdentifier = "quantityLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Elements 23 & 24: uploadProgress + advanceButton
    private let uploadProgress: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progress = 0.5
        p.accessibilityIdentifier = "uploadProgress"
        p.accessibilityValue = "0.5"
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private let advanceButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Advance", for: .normal)
        b.accessibilityIdentifier = "advanceButton"
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Element 25: notesArea
    private let notesArea: UITextView = {
        let tv = UITextView()
        tv.text = ""
        tv.font = UIFont.systemFont(ofSize: 14)
        tv.layer.borderColor = UIColor.systemGray4.cgColor
        tv.layer.borderWidth = 1
        tv.layer.cornerRadius = 4
        tv.accessibilityIdentifier = "notesArea"
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Element 26: termsLink
    private let termsLink: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Terms & Conditions", for: .normal)
        b.accessibilityIdentifier = "termsLink"
        b.accessibilityTraits = .link
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Elements 27-31: fileTable + tableSelLabel
    private let fileTable: UITableView = {
        let tv = UITableView()
        tv.accessibilityIdentifier = "fileTable"
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let tableSelLabel: UILabel = {
        let l = UILabel()
        l.text = "table-sel: none"
        l.accessibilityIdentifier = "tableSelLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let fileItems = ["document.pdf", "photo.jpg", "notes.txt"]

    // MARK: - Elements 32-34: alertButton
    private let alertButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Show Alert", for: .normal)
        b.accessibilityIdentifier = "alertButton"
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Elements 35-36: lockedButton + disabledLabel
    private let lockedButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("Locked", for: .normal)
        b.isEnabled = false
        b.accessibilityIdentifier = "lockedButton"
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let disabledLabel: UILabel = {
        let l = UILabel()
        l.text = "locked: true"
        l.accessibilityIdentifier = "disabledLabel"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "TestHostApp"
        setupNavigationBar()
        setupScrollContent()
        setupMainLayout()
        setupActions()
        setupContextMenu()
        setupTableView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchField.becomeFirstResponder()
    }

    // MARK: - Navigation Bar (Element 16: toggleFlag)

    private func setupNavigationBar() {
        let toggleFlagItem = UIBarButtonItem(
            title: "Toggle Flag",
            style: .plain,
            target: self,
            action: #selector(toggleFlagTapped)
        )
        toggleFlagItem.accessibilityIdentifier = "toggleFlag"
        navigationItem.rightBarButtonItem = toggleFlagItem
    }

    // MARK: - Scroll Content Setup (Elements 10-11)

    private func setupScrollContent() {
        // Items 0-8
        for i in 0..<9 {
            let label = UILabel()
            label.text = "item-\(i)"
            label.accessibilityIdentifier = "item-\(i)"
            scrollContentStack.addArrangedSubview(label)
        }

        // scroll-end label (Element 11)
        let scrollEndLabel = UILabel()
        scrollEndLabel.text = "scroll-end"
        scrollEndLabel.accessibilityIdentifier = "scroll-end"
        scrollContentStack.addArrangedSubview(scrollEndLabel)

        scrollView.addSubview(scrollContentStack)
        NSLayoutConstraint.activate([
            scrollContentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 8),
            scrollContentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            scrollContentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            scrollContentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -8),
            scrollContentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -16),
        ])
    }

    // MARK: - Main Layout

    private func setupMainLayout() {
        // Outer scroll view to hold all content
        let outerScroll = UIScrollView()
        outerScroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(outerScroll)

        NSLayoutConstraint.activate([
            outerScroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            outerScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            outerScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            outerScroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.isLayoutMarginsRelativeArrangement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        outerScroll.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.topAnchor),
            stack.leadingAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: outerScroll.contentLayoutGuide.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: outerScroll.frameLayoutGuide.widthAnchor),
        ])

        // Add all subviews to stack
        stack.addArrangedSubview(row(label: "Name:", view: nameField))
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(countLabel)
        stack.addArrangedSubview(dblLabel)

        let buttonRow = UIStackView(arrangedSubviews: [okButton, dblButton])
        buttonRow.spacing = 16
        stack.addArrangedSubview(buttonRow)

        let flagRow = UIStackView(arrangedSubviews: [UILabel.make("Flag:"), flagCheckbox])
        flagRow.spacing = 8
        stack.addArrangedSubview(flagRow)

        colorSwatch.heightAnchor.constraint(equalToConstant: 44).isActive = true
        stack.addArrangedSubview(colorSwatch)

        stack.addArrangedSubview(row(label: "Search:", view: searchField))

        // Scroll view (inner) for items
        scrollView.heightAnchor.constraint(equalToConstant: 120).isActive = true
        stack.addArrangedSubview(scrollView)

        let sliderRow = UIStackView(arrangedSubviews: [slider, sliderValueLabel])
        sliderRow.spacing = 8
        stack.addArrangedSubview(sliderRow)

        rightClickTarget.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let rcLabel = UILabel()
        rcLabel.text = "Right Click Here"
        rcLabel.textColor = .secondaryLabel
        rcLabel.translatesAutoresizingMaskIntoConstraints = false
        rightClickTarget.addSubview(rcLabel)
        NSLayoutConstraint.activate([
            rcLabel.centerXAnchor.constraint(equalTo: rightClickTarget.centerXAnchor),
            rcLabel.centerYAnchor.constraint(equalTo: rightClickTarget.centerYAnchor),
        ])
        stack.addArrangedSubview(rightClickTarget)

        stack.addArrangedSubview(modeSegment)
        stack.addArrangedSubview(segmentLabel)

        let pickerRow = UIStackView(arrangedSubviews: [colorPicker, pickerLabel])
        pickerRow.spacing = 8
        stack.addArrangedSubview(pickerRow)

        let stepperRow = UIStackView(arrangedSubviews: [quantityStepper, quantityLabel])
        stepperRow.spacing = 8
        stack.addArrangedSubview(stepperRow)

        stack.addArrangedSubview(uploadProgress)
        stack.addArrangedSubview(advanceButton)

        notesArea.heightAnchor.constraint(equalToConstant: 80).isActive = true
        stack.addArrangedSubview(notesArea)

        stack.addArrangedSubview(termsLink)

        fileTable.heightAnchor.constraint(equalToConstant: 132).isActive = true
        stack.addArrangedSubview(fileTable)
        stack.addArrangedSubview(tableSelLabel)

        stack.addArrangedSubview(alertButton)

        let disabledRow = UIStackView(arrangedSubviews: [lockedButton, disabledLabel])
        disabledRow.spacing = 8
        stack.addArrangedSubview(disabledRow)
    }

    // MARK: - Actions

    private func setupActions() {
        nameField.addTarget(self, action: #selector(nameFieldChanged), for: .editingChanged)
        okButton.addTarget(self, action: #selector(okTapped), for: .touchUpInside)
        flagCheckbox.addTarget(self, action: #selector(flagChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
        modeSegment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        quantityStepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
        advanceButton.addTarget(self, action: #selector(advanceTapped), for: .touchUpInside)
        termsLink.addTarget(self, action: #selector(termsLinkTapped), for: .touchUpInside)
        alertButton.addTarget(self, action: #selector(alertTapped), for: .touchUpInside)

        // Double-tap for dblButton
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(dblButtonDoubleTapped))
        doubleTap.numberOfTapsRequired = 2
        dblButton.addGestureRecognizer(doubleTap)
    }

    private func setupContextMenu() {
        let interaction = UIContextMenuInteraction(delegate: self)
        rightClickTarget.addInteraction(interaction)
    }

    private func setupTableView() {
        fileTable.dataSource = self
        fileTable.delegate = self
        fileTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    // MARK: - Action Handlers

    @objc private func nameFieldChanged() {
        statusLabel.text = "status: \(nameField.text ?? "")"
    }

    @objc private func okTapped() {
        count += 1
        countLabel.text = "count: \(count)"
    }

    @objc private func dblButtonDoubleTapped() {
        dblCount += 1
        dblLabel.text = "dbl: \(dblCount)"
    }

    @objc private func flagChanged() {
        flagOn = flagCheckbox.isOn
        statusLabel.text = "status: flag=\(flagOn ? "true" : "false")"
        updateToggleFlagBarItem()
    }

    @objc private func toggleFlagTapped() {
        flagOn.toggle()
        flagCheckbox.setOn(flagOn, animated: true)
        statusLabel.text = "status: flag=\(flagOn ? "true" : "false")"
        updateToggleFlagBarItem()
    }

    private func updateToggleFlagBarItem() {
        // Update the bar button item tint to indicate state
        navigationItem.rightBarButtonItem?.tintColor = flagOn ? .systemBlue : nil
    }

    @objc private func sliderChanged() {
        sliderValueLabel.text = "slider: \(Int(slider.value))"
    }

    @objc private func segmentChanged() {
        segmentLabel.text = "segment: \(modeSegment.selectedSegmentIndex)"
    }

    @objc private func stepperChanged() {
        quantityLabel.text = "qty: \(Int(quantityStepper.value))"
    }

    @objc private func advanceTapped() {
        uploadProgress.progress = 1.0
        uploadProgress.accessibilityValue = "1.0"
    }

    @objc private func termsLinkTapped() {
        statusLabel.text = "status: link-tapped"
    }

    @objc private func alertTapped() {
        let alert = UIAlertController(title: "Are you sure?", message: nil, preferredStyle: .alert)
        let confirm = UIAlertAction(title: "Confirm", style: .default) { [weak self] _ in
            self?.statusLabel.text = "status: alert-confirmed"
        }
        confirm.accessibilityIdentifier = "confirmButton"
        let cancel = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.statusLabel.text = "status: alert-cancelled"
        }
        cancel.accessibilityIdentifier = "cancelButton"
        alert.addAction(confirm)
        alert.addAction(cancel)
        present(alert, animated: true)
    }

    // MARK: - Helpers

    private func row(label text: String, view: UIView) -> UIStackView {
        let lbl = UILabel()
        lbl.text = text
        lbl.setContentHuggingPriority(.required, for: .horizontal)
        let stack = UIStackView(arrangedSubviews: [lbl, view])
        stack.spacing = 8
        return stack
    }
}

// MARK: - UIContextMenuInteractionDelegate (Elements 14, 15)

extension ViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let action = UIAction(
                title: "ContextAction",
                identifier: UIAction.Identifier("contextAction")
            ) { _ in
                self?.statusLabel.text = "status: context-tapped"
            }
            action.accessibilityIdentifier = "contextAction"
            return UIMenu(title: "", children: [action])
        }
    }
}

// MARK: - UITableViewDataSource / Delegate (Elements 27-31)

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fileItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let filename = fileItems[indexPath.row]
        cell.textLabel?.text = filename
        cell.textLabel?.accessibilityIdentifier = "row-\(filename)"
        cell.accessibilityIdentifier = "row-\(filename)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let filename = fileItems[indexPath.row]
        tableSelLabel.text = "table-sel: \(filename)"
    }
}

// MARK: - UILabel helper

private extension UILabel {
    static func make(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        return l
    }
}
