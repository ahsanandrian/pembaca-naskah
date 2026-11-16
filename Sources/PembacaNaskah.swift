import AppKit
import PDFKit
import CoreImage

// MARK: - Scene Model
struct SceneItem {
    let number: String
    let title: String
    let displayTitle: String
    let page: PDFPage
    let point: NSPoint
    let pageIndex: Int
}

// MARK: - Drag & Drop View
class DropZoneView: NSView {
    var onFileDropped: ((URL) -> Void)?
    var onClicked: (() -> Void)?
    private var isDragging = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let boundsRect = bounds.insetBy(dx: 4, dy: 4)
        let path = NSBezierPath(roundedRect: boundsRect, xRadius: 16, yRadius: 16)
        let bgColor = isDragging ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor(white: 0.14, alpha: 1.0)
        bgColor.setFill()
        path.fill()

        let strokeColor = isDragging ? NSColor.controlAccentColor : NSColor(white: 0.35, alpha: 1.0)
        strokeColor.setStroke()
        path.lineWidth = 2
        let pattern: [CGFloat] = [8, 6]
        path.setLineDash(pattern, count: 2, phase: 0)
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        onClicked?()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if hasPDF(sender) {
            isDragging = true
            return .copy
        }
        return []
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
              let pdfURL = urls.first(where: { $0.pathExtension.lowercased() == "pdf" }) else {
            return false
        }
        onFileDropped?(pdfURL)
        return true
    }

    private func hasPDF(_ info: NSDraggingInfo) -> Bool {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] else {
            return false
        }
        return urls.contains(where: { $0.pathExtension.lowercased() == "pdf" })
    }
}

// MARK: - Main Window Controller
class MainWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private var uploadView: NSView!
    private var readerSplitView: NSSplitView!
    private var sceneTableView: NSTableView!
    private var sceneSearchField: NSSearchField!
    private var sceneCountBadge: NSTextField!
    private var docTitleLabel: NSTextField!
    private var textSearchField: NSSearchField!
    private var searchCountLabel: NSTextField!
    private var zoomLabel: NSTextField!
    private var themeButton: NSButton!
    private var pdfView: PDFView!

    private var allScenes: [SceneItem] = []
    private var filteredScenes: [SceneItem] = []
    private var searchMatches: [PDFSelection] = []
    private var currentMatchIndex: Int = -1
    private var isDarkMode: Bool = true

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pembaca Naskah"
        window.minSize = NSSize(width: 820, height: 560)
        window.center()
        window.appearance = NSAppearance(named: .darkAqua)
        self.init(window: window)
        setupUI()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        setupUploadView(in: contentView)
        setupReaderView(in: contentView)

        readerSplitView.isHidden = true
    }

    private func setupUploadView(in container: NSView) {
        uploadView = NSView(frame: container.bounds)
        uploadView.autoresizingMask = [.width, .height]
        container.addSubview(uploadView)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        uploadView.addSubview(stack)

        let title = NSTextField(labelWithString: "Pembaca Naskah")
        title.font = NSFont.systemFont(ofSize: 32, weight: .bold)

        let subtitle = NSTextField(labelWithString: "Buka file PDF skenario. Mendukung select text, pencarian teks, dan navigasi nomor scene.")
        subtitle.font = NSFont.systemFont(ofSize: 14)
        subtitle.textColor = .secondaryLabelColor

        let dropZone = DropZoneView(frame: NSRect(x: 0, y: 0, width: 480, height: 220))
        dropZone.translatesAutoresizingMaskIntoConstraints = false
        dropZone.widthAnchor.constraint(equalToConstant: 480).isActive = true
        dropZone.heightAnchor.constraint(equalToConstant: 220).isActive = true
        dropZone.onClicked = { [weak self] in self?.openPDFPanel() }
        dropZone.onFileDropped = { [weak self] url in self?.loadPDF(url: url) }

        let dzLabel = NSTextField(labelWithString: "Pilih File PDF\natau seret & lepas file ke sini")
        dzLabel.alignment = .center
        dzLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        dzLabel.textColor = .secondaryLabelColor
        dzLabel.translatesAutoresizingMaskIntoConstraints = false
        dropZone.addSubview(dzLabel)
        NSLayoutConstraint.activate([
            dzLabel.centerXAnchor.constraint(equalTo: dropZone.centerXAnchor),
            dzLabel.centerYAnchor.constraint(equalTo: dropZone.centerYAnchor)
        ])

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(subtitle)
        stack.addArrangedSubview(dropZone)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: uploadView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: uploadView.centerYAnchor)
        ])
    }

    private func setupReaderView(in container: NSView) {
        readerSplitView = NSSplitView(frame: container.bounds)
        readerSplitView.autoresizingMask = [.width, .height]
        readerSplitView.isVertical = true
        readerSplitView.dividerStyle = .thin
        container.addSubview(readerSplitView)

        // LEFT SIDEBAR
        let sidebar = NSView(frame: NSRect(x: 0, y: 0, width: 290, height: 800))
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        sidebar.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        sidebar.widthAnchor.constraint(lessThanOrEqualToConstant: 420).isActive = true

        let headerView = NSView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(headerView)

        let headerTitle = NSTextField(labelWithString: "DAFTAR SCENE")
        headerTitle.font = NSFont.systemFont(ofSize: 11, weight: .bold)
        headerTitle.textColor = .secondaryLabelColor
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(headerTitle)

        sceneCountBadge = NSTextField(labelWithString: "0")
        sceneCountBadge.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        sceneCountBadge.textColor = .labelColor
        sceneCountBadge.alignment = .center
        sceneCountBadge.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(sceneCountBadge)

        sceneSearchField = NSSearchField()
        sceneSearchField.placeholderString = "Cari nomor / nama scene..."
        sceneSearchField.controlSize = .small
        sceneSearchField.target = self
        sceneSearchField.action = #selector(filterScenesAction(_:))
        sceneSearchField.delegate = self
        sceneSearchField.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(sceneSearchField)

        let tableScroll = NSScrollView()
        tableScroll.hasVerticalScroller = true
        tableScroll.drawsBackground = false
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(tableScroll)

        sceneTableView = NSTableView()
        sceneTableView.headerView = nil
        sceneTableView.backgroundColor = .clear
        sceneTableView.rowHeight = 28
        sceneTableView.dataSource = self
        sceneTableView.delegate = self
        sceneTableView.target = self
        sceneTableView.action = #selector(sceneRowClicked(_:))

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("SceneCol"))
        col.resizingMask = .autoresizingMask
        sceneTableView.addTableColumn(col)
        tableScroll.documentView = sceneTableView

        let closeBtn = NSButton(title: "Tutup PDF", target: self, action: #selector(closePDF))
        closeBtn.bezelStyle = .rounded
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(closeBtn)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 10),
            headerView.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            headerView.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            headerView.heightAnchor.constraint(equalToConstant: 24),

            headerTitle.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerTitle.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            sceneCountBadge.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            sceneCountBadge.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),

            sceneSearchField.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            sceneSearchField.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 10),
            sceneSearchField.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -10),

            tableScroll.topAnchor.constraint(equalTo: sceneSearchField.bottomAnchor, constant: 8),
            tableScroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor),
            tableScroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            tableScroll.bottomAnchor.constraint(equalTo: closeBtn.topAnchor, constant: -10),

            closeBtn.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 12),
            closeBtn.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -12),
            closeBtn.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -12)
        ])

        // RIGHT PANE
        let mainPane = NSView(frame: NSRect(x: 0, y: 0, width: 890, height: 800))

        let topbar = NSView()
        topbar.translatesAutoresizingMaskIntoConstraints = false
        mainPane.addSubview(topbar)

        docTitleLabel = NSTextField(labelWithString: "Naskah")
        docTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        docTitleLabel.lineBreakMode = .byTruncatingMiddle
        docTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(docTitleLabel)

        textSearchField = NSSearchField()
        textSearchField.placeholderString = "Cari teks di naskah (Cmd+F)..."
        textSearchField.controlSize = .small
        textSearchField.target = self
        textSearchField.action = #selector(performTextSearch(_:))
        textSearchField.delegate = self
        textSearchField.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(textSearchField)

        searchCountLabel = NSTextField(labelWithString: "")
        searchCountLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        searchCountLabel.textColor = .secondaryLabelColor
        searchCountLabel.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(searchCountLabel)

        let prevMatchBtn = NSButton(title: "▲", target: self, action: #selector(findPreviousMatch))
        prevMatchBtn.bezelStyle = .rounded
        prevMatchBtn.controlSize = .small
        prevMatchBtn.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(prevMatchBtn)

        let nextMatchBtn = NSButton(title: "▼", target: self, action: #selector(findNextMatch))
        nextMatchBtn.bezelStyle = .rounded
        nextMatchBtn.controlSize = .small
        nextMatchBtn.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(nextMatchBtn)

        themeButton = NSButton(title: "☀️", target: self, action: #selector(toggleTheme))
        themeButton.bezelStyle = .rounded
        themeButton.controlSize = .small
        themeButton.toolTip = "Toggle Dark/Light Mode"
        themeButton.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(themeButton)

        let zoomOutBtn = NSButton(title: "-", target: self, action: #selector(zoomOut))
        zoomOutBtn.bezelStyle = .rounded
        zoomOutBtn.controlSize = .small
        zoomOutBtn.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(zoomOutBtn)

        zoomLabel = NSTextField(labelWithString: "100%")
        zoomLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        zoomLabel.alignment = .center
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(zoomLabel)

        let zoomInBtn = NSButton(title: "+", target: self, action: #selector(zoomIn))
        zoomInBtn.bezelStyle = .rounded
        zoomInBtn.controlSize = .small
        zoomInBtn.translatesAutoresizingMaskIntoConstraints = false
        topbar.addSubview(zoomInBtn)

        pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displaysPageBreaks = true
        pdfView.backgroundColor = NSColor(white: 0.1, alpha: 1.0)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        mainPane.addSubview(pdfView)

        NSLayoutConstraint.activate([
            topbar.topAnchor.constraint(equalTo: mainPane.topAnchor),
            topbar.leadingAnchor.constraint(equalTo: mainPane.leadingAnchor),
            topbar.trailingAnchor.constraint(equalTo: mainPane.trailingAnchor),
            topbar.heightAnchor.constraint(equalToConstant: 44),

            docTitleLabel.leadingAnchor.constraint(equalTo: topbar.leadingAnchor, constant: 14),
            docTitleLabel.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),
            docTitleLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 240),

            textSearchField.leadingAnchor.constraint(greaterThanOrEqualTo: docTitleLabel.trailingAnchor, constant: 12),
            textSearchField.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),
            textSearchField.widthAnchor.constraint(equalToConstant: 210),

            searchCountLabel.leadingAnchor.constraint(equalTo: textSearchField.trailingAnchor, constant: 6),
            searchCountLabel.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),

            prevMatchBtn.leadingAnchor.constraint(equalTo: searchCountLabel.trailingAnchor, constant: 4),
            prevMatchBtn.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),

            nextMatchBtn.leadingAnchor.constraint(equalTo: prevMatchBtn.trailingAnchor, constant: 2),
            nextMatchBtn.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),

            themeButton.leadingAnchor.constraint(equalTo: nextMatchBtn.trailingAnchor, constant: 12),
            themeButton.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),

            zoomOutBtn.leadingAnchor.constraint(equalTo: themeButton.trailingAnchor, constant: 8),
            zoomOutBtn.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),

            zoomLabel.leadingAnchor.constraint(equalTo: zoomOutBtn.trailingAnchor, constant: 4),
            zoomLabel.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),
            zoomLabel.widthAnchor.constraint(equalToConstant: 42),

            zoomInBtn.leadingAnchor.constraint(equalTo: zoomLabel.trailingAnchor, constant: 4),
            zoomInBtn.trailingAnchor.constraint(equalTo: topbar.trailingAnchor, constant: -14),
            zoomInBtn.centerYAnchor.constraint(equalTo: topbar.centerYAnchor),

            pdfView.topAnchor.constraint(equalTo: topbar.bottomAnchor),
            pdfView.leadingAnchor.constraint(equalTo: mainPane.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: mainPane.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: mainPane.bottomAnchor)
        ])

        readerSplitView.addArrangedSubview(sidebar)
        readerSplitView.addArrangedSubview(mainPane)
        readerSplitView.setPosition(290, ofDividerAt: 0)

        applyTheme()
    }

    // MARK: - Actions
    @objc func openPDFPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            loadPDF(url: url)
        }
    }

    func loadPDF(url: URL) {
        guard let document = PDFDocument(url: url) else {
            let alert = NSAlert()
            alert.messageText = "Gagal Membuka PDF"
            alert.informativeText = "File tidak dapat dibaca sebagai dokumen PDF."
            alert.runModal()
            return
        }

        pdfView.document = document
        pdfView.autoScales = true
        docTitleLabel.stringValue = url.lastPathComponent
        updateZoomLabel()

        allScenes = extractScenes(from: document)
        filteredScenes = allScenes
        sceneSearchField.stringValue = ""
        sceneCountBadge.stringValue = "\(allScenes.count)"
        sceneTableView.reloadData()

        searchMatches = []
        currentMatchIndex = -1
        searchCountLabel.stringValue = ""
        textSearchField.stringValue = ""
        pdfView.highlightedSelections = nil

        uploadView.isHidden = true
        readerSplitView.isHidden = false
        applyTheme()
    }

    @objc func closePDF() {
        pdfView.document = nil
        allScenes = []
        filteredScenes = []
        searchMatches = []
        sceneTableView.reloadData()
        readerSplitView.isHidden = true
        uploadView.isHidden = false
    }

    @objc func focusSearchField() {
        if !readerSplitView.isHidden {
            window?.makeFirstResponder(textSearchField)
        }
    }

    @objc func toggleTheme() {
        isDarkMode.toggle()
        applyTheme()
    }

    private func applyTheme() {
        window?.appearance = NSAppearance(named: isDarkMode ? .darkAqua : .aqua)
        themeButton?.title = isDarkMode ? "☀️" : "🌙"

        guard let pdfView = pdfView else { return }
        pdfView.wantsLayer = true
        pdfView.layerUsesCoreImageFilters = true

        if isDarkMode {
            pdfView.backgroundColor = NSColor(white: 0.08, alpha: 1.0)
            var filters: [CIFilter] = []
            if let invert = CIFilter(name: "CIColorInvert") {
                filters.append(invert)
            }
            if let hue = CIFilter(name: "CIHueAdjust") {
                hue.setValue(Double.pi, forKey: kCIInputAngleKey)
                filters.append(hue)
            }
            pdfView.contentFilters = filters
        } else {
            pdfView.backgroundColor = NSColor(white: 0.88, alpha: 1.0)
            pdfView.contentFilters = []
        }
    }

    @objc func zoomIn() {
        pdfView.zoomIn(nil)
        updateZoomLabel()
    }

    @objc func zoomOut() {
        pdfView.zoomOut(nil)
        updateZoomLabel()
    }

    private func updateZoomLabel() {
        let pct = Int(round(pdfView.scaleFactor * 100))
        zoomLabel.stringValue = "\(pct)%"
    }

    // MARK: - Scene Extraction with Spatial Scene Number Detection
    private func extractScenes(from document: PDFDocument) -> [SceneItem] {
        var scenes: [SceneItem] = []
        let headingPattern = #"^\s*(\d+[A-Za-z]?\s+)?(INT\.|EXT\.|INT\/EXT\.|INT\.\/EXT\.)"#
        let leadingNumPattern = #"^\s*(\d+[A-Za-z]?)\b"#
        let trailingNumPattern = #"\b(\d+[A-Za-z]?)\s*\*?\s*$"#

        guard let headingRegex = try? NSRegularExpression(pattern: headingPattern, options: [.caseInsensitive]),
              let leadingNumRegex = try? NSRegularExpression(pattern: leadingNumPattern, options: []),
              let trailingNumRegex = try? NSRegularExpression(pattern: trailingNumPattern, options: []) else {
            return scenes
        }

        var fallbackCounter = 1

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            let lines = pageText.components(separatedBy: .newlines)
            var searchStartOffset = 0

            for rawLine in lines {
                let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
                let nsLine = line as NSString
                let lineRange = NSRange(location: 0, length: nsLine.length)

                if !line.isEmpty, headingRegex.firstMatch(in: line, options: [], range: lineRange) != nil {
                    var targetPoint = NSPoint(x: 0, y: pageBounds.height)
                    var extractedNumber = ""
                    var cleanTitle = line

                    let fullNS = pageText as NSString
                    let foundRange = fullNS.range(of: line, options: [], range: NSRange(location: searchStartOffset, length: fullNS.length - searchStartOffset))
                    if foundRange.location != NSNotFound {
                        if let selection = page.selection(for: foundRange) {
                            let bounds = selection.bounds(for: page)
                            targetPoint = NSPoint(x: 0, y: bounds.maxY + 24)

                            // Check full horizontal band at the same Y-level on the PDF page
                            let rowRect = NSRect(x: 0, y: bounds.minY - 4, width: pageBounds.width, height: bounds.height + 8)
                            if let rowText = page.selection(for: rowRect)?.string {
                                let normalizedRow = rowText.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                                let nsRow = normalizedRow as NSString
                                let rowRange = NSRange(location: 0, length: nsRow.length)

                                if let m = leadingNumRegex.firstMatch(in: normalizedRow, options: [], range: rowRange) {
                                    extractedNumber = nsRow.substring(with: m.range(at: 1))
                                } else if let m = trailingNumRegex.firstMatch(in: normalizedRow, options: [], range: rowRange) {
                                    extractedNumber = nsRow.substring(with: m.range(at: 1))
                                }
                            }
                        }
                        searchStartOffset = foundRange.location + foundRange.length
                    }

                    // Fallback: check leading/trailing number inside the line itself
                    if extractedNumber.isEmpty {
                        if let m = leadingNumRegex.firstMatch(in: line, options: [], range: lineRange) {
                            extractedNumber = nsLine.substring(with: m.range(at: 1))
                            cleanTitle = nsLine.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                        } else if let m = trailingNumRegex.firstMatch(in: line, options: [], range: lineRange) {
                            extractedNumber = nsLine.substring(with: m.range(at: 1))
                            cleanTitle = nsLine.substring(to: m.range.lowerBound).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    } else {
                        // Strip leading/trailing duplicate number from cleanTitle if present
                        let cleanNS = cleanTitle as NSString
                        if let m = leadingNumRegex.firstMatch(in: cleanTitle, options: [], range: NSRange(location: 0, length: cleanNS.length)),
                           cleanNS.substring(with: m.range(at: 1)) == extractedNumber {
                            cleanTitle = cleanNS.substring(from: m.range.upperBound).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        let cleanNS2 = cleanTitle as NSString
                        if let m = trailingNumRegex.firstMatch(in: cleanTitle, options: [], range: NSRange(location: 0, length: cleanNS2.length)),
                           cleanNS2.substring(with: m.range(at: 1)) == extractedNumber {
                            cleanTitle = cleanNS2.substring(to: m.range.lowerBound).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }

                    let finalNumber = extractedNumber.isEmpty ? "\(fallbackCounter)" : extractedNumber
                    fallbackCounter += 1

                    let display = "\(finalNumber). \(cleanTitle)"
                    scenes.append(SceneItem(number: finalNumber, title: cleanTitle, displayTitle: display, page: page, point: targetPoint, pageIndex: pageIndex))
                }
            }
        }
        return scenes
    }

    @objc func filterScenesAction(_ sender: NSSearchField) {
        let q = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            filteredScenes = allScenes
        } else {
            filteredScenes = allScenes.filter { $0.displayTitle.lowercased().contains(q) }
        }
        sceneCountBadge.stringValue = "\(filteredScenes.count)"
        sceneTableView.reloadData()
    }

    @objc func sceneRowClicked(_ sender: NSTableView) {
        let row = sender.selectedRow
        guard row >= 0 && row < filteredScenes.count else { return }
        let scene = filteredScenes[row]
        let dest = PDFDestination(page: scene.page, at: scene.point)
        pdfView.go(to: dest)
    }

    // MARK: - Text Search in PDF
    @objc func performTextSearch(_ sender: NSSearchField) {
        let query = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, let doc = pdfView.document else {
            searchMatches = []
            currentMatchIndex = -1
            searchCountLabel.stringValue = ""
            pdfView.highlightedSelections = nil
            return
        }

        searchMatches = doc.findString(query, withOptions: [.caseInsensitive])
        pdfView.highlightedSelections = searchMatches

        if searchMatches.isEmpty {
            currentMatchIndex = -1
            searchCountLabel.stringValue = "0/0"
        } else {
            currentMatchIndex = 0
            goToMatch(at: currentMatchIndex)
        }
    }

    @objc func findNextMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        goToMatch(at: currentMatchIndex)
    }

    @objc func findPreviousMatch() {
        guard !searchMatches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        goToMatch(at: currentMatchIndex)
    }

    private func goToMatch(at index: Int) {
        let selection = searchMatches[index]
        selection.color = NSColor.systemYellow.withAlphaComponent(0.5)
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.go(to: selection)
        searchCountLabel.stringValue = "\(index + 1)/\(searchMatches.count)"
    }

    // MARK: - NSSearchFieldDelegate
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        if field == sceneSearchField {
            filterScenesAction(field)
        } else if field == textSearchField && field.stringValue.isEmpty {
            searchMatches = []
            currentMatchIndex = -1
            searchCountLabel.stringValue = ""
            pdfView.highlightedSelections = nil
        }
    }

    // MARK: - NSTableViewDataSource & Delegate
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredScenes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("SceneCell")
        let cell: NSTextField
        if let reused = tableView.makeView(withIdentifier: id, owner: self) as? NSTextField {
            cell = reused
        } else {
            cell = NSTextField(labelWithString: "")
            cell.identifier = id
            cell.font = NSFont.systemFont(ofSize: 12)
            cell.lineBreakMode = .byTruncatingTail
        }
        cell.stringValue = filteredScenes[row].displayTitle
        cell.toolTip = filteredScenes[row].displayTitle
        return cell
    }
}

// MARK: - AppDelegate
class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: MainWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        windowController = MainWindowController()
        windowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if url.pathExtension.lowercased() == "pdf" {
            windowController.loadPDF(url: url)
            return true
        }
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // App Menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Keluar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // File Menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Buka PDF...", action: #selector(MainWindowController.openPDFPanel), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Tutup PDF", action: #selector(MainWindowController.closePDF), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu

        // Edit Menu (supports Copy, Select All, Find)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cari Teks...", action: #selector(MainWindowController.focusSearchField), keyEquivalent: "f")
        editMenu.addItem(withTitle: "Cari Berikutnya", action: #selector(MainWindowController.findNextMatch), keyEquivalent: "g")
        let prevItem = NSMenuItem(title: "Cari Sebelumnya", action: #selector(MainWindowController.findPreviousMatch), keyEquivalent: "G")
        prevItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(prevItem)
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
