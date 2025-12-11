import SwiftUI
import UniformTypeIdentifiers
import QuickLookThumbnailing
import AppKit

struct ProcessedItem: Identifiable, Equatable {
    enum Status: Equatable {
        case removed
        case notFound
        case failed(reason: String)
    }

    let id = UUID()
    let url: URL
    let status: Status
}

enum ProcessingState: Equatable {
    case idle
    case processing
    case finished(items: [ProcessedItem])
    case error(message: String)
}

struct FileThumbnailView: View {
    let url: URL

    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .overlay(
                        Image(systemName: "doc")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    )
            }
        }
        .frame(width: 48, height: 48)
        .onAppear {
            if image == nil {
                generateThumbnail()
            }
        }
    }

    private func generateThumbnail() {
        let size = CGSize(width: 64, height: 64)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .all
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let representation = representation else { return }

            let cgImage = representation.cgImage
            let nsImage = NSImage(
                cgImage: cgImage,
                size: NSSize(width: cgImage.width, height: cgImage.height)
            )

            DispatchQueue.main.async {
                self.image = nsImage
            }
        }
    }
}

struct ContentView: View {
    @State private var processingState: ProcessingState = .idle
    @State private var isTargeted = false
    @State private var showFileImporter = false

    var body: some View {
        VStack(spacing: 20) {
            headerView

            dropZoneView
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                    return true
                }

            selectFileButton
        }
        .navigationTitle("GatePass by Nercone")
        .padding(30)
        .frame(minWidth: 800, minHeight: 600)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result: result)
        }
        .animation(.spring(), value: processingState)
    }

    private var headerView: some View {
        VStack {
            Text("GatePass")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Remove com.apple.quarantine attribute from file or folder")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var dropZoneView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(.background.opacity(0.5))
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)

            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.gray.opacity(0.4),
                    style: StrokeStyle(lineWidth: 3, dash: isTargeted ? [] : [10, 5])
                )
                .padding(2)

            contentForCurrentState
                .padding(20)
        }
    }

    @ViewBuilder
    private var contentForCurrentState: some View {
        switch processingState {
        case .idle:
            VStack(spacing: 15) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("Drop File or Folder here!")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            .transition(.opacity)

        case .processing:
            VStack(spacing: 15) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Processing...")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .transition(.opacity)

        case .finished(let items):
            resultsView(items: items)
                .transition(.scale.combined(with: .opacity))

        case .error(let message):
            errorView(message: message)
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func resultsView(items: [ProcessedItem]) -> some View {
        return VStack(spacing: 20) {

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(items) { item in
                        HStack(spacing: 12) {
                            FileThumbnailView(url: item.url)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.url.lastPathComponent)
                                    .font(.headline)
                                    .lineLimit(1)

                                Text(detailText(for: item.status))
                                    .font(.caption)
                                    .foregroundColor(detailColor(for: item.status))
                                    .lineLimit(2)
                            }

                            Spacer()

                            Image(systemName: statusIconName(for: item.status))
                                .foregroundColor(detailColor(for: item.status))
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        )
                    }
                }
            }

            Button("Start over") {
                processingState = .idle
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 70))
                .foregroundColor(.red)

            Text(message)
                .font(.title2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Start over") {
                processingState = .idle
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var selectFileButton: some View {
        Button {
            showFileImporter = true
        } label: {
            Label("Select in Dialog", systemImage: "filemenu.and.selection")
        }
        .controlSize(.large)
    }

    private func detailText(for status: ProcessedItem.Status) -> String {
        switch status {
        case .removed:
            return "Quarantine attribute removed."
        case .notFound:
            return "No quarantine attribute found."
        case .failed(let reason):
            return "Failed: \(reason)"
        }
    }

    private func detailColor(for status: ProcessedItem.Status) -> Color {
        switch status {
        case .removed:
            return .green
        case .notFound:
            return .secondary
        case .failed:
            return .red
        }
    }

    private func statusIconName(for status: ProcessedItem.Status) -> String {
        switch status {
        case .removed:
            return "checkmark.circle.fill"
        case .notFound:
            return "questionmark.circle"
        case .failed:
            return "xmark.octagon.fill"
        }
    }

    private func handleDrop(providers: [NSItemProvider]) {
        var urls: [URL] = []
        var lastError: Error?
        let group = DispatchGroup()

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    DispatchQueue.main.async {
                        if let url = url {
                            urls.append(url)
                        } else if let error = error {
                            lastError = error
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                processURLs(urls)
            } else if let error = lastError {
                processingState = .error(message: "Failed to read dropped items.\n\(error.localizedDescription)")
            }
        }
    }

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            processURLs(urls)
        case .failure(let error):
            processingState = .error(message: "Failed to read.\n\(error.localizedDescription)")
        }
    }

    private func processURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }

        processingState = .processing

        DispatchQueue.global(qos: .userInitiated).async {
            var allResults: [ProcessedItem] = []

            for url in urls {
                let results = self.processRootURL(url)
                allResults.append(contentsOf: results)
            }

            DispatchQueue.main.async {
                self.processingState = .finished(items: allResults)
            }
        }
    }

    private func processRootURL(_ url: URL) -> [ProcessedItem] {
        var results: [ProcessedItem] = []
        let fileManager = FileManager.default

        guard url.startAccessingSecurityScopedResource() else {
            let item = ProcessedItem(
                url: url,
                status: .failed(reason: "Do not have permission to access the item.")
            )
            results.append(item)
            return results
        }

        defer { url.stopAccessingSecurityScopedResource() }

        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey])
        let isDirectory = resourceValues?.isDirectory ?? url.hasDirectoryPath

        results.append(processSingleItem(at: url))

        if isDirectory {
            if let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [],
                errorHandler: { subURL, error in
                    let item = ProcessedItem(
                        url: subURL,
                        status: .failed(reason: error.localizedDescription)
                    )
                    results.append(item)
                    return true
                }
            ) {
                for case let itemURL as URL in enumerator {
                    results.append(processSingleItem(at: itemURL))
                }
            }
        }

        return results
    }

    private func processSingleItem(at url: URL) -> ProcessedItem {
        let path = url.path

        let checkTask = Process()
        checkTask.launchPath = "/usr/bin/xattr"
        checkTask.arguments = ["-p", "com.apple.quarantine", path]

        let checkPipe = Pipe()
        checkTask.standardOutput = checkPipe
        checkTask.standardError = checkPipe

        do {
            try checkTask.run()
            checkTask.waitUntilExit()

            let checkData = checkPipe.fileHandleForReading.readDataToEndOfFile()
            let checkOutput = String(data: checkData, encoding: .utf8) ?? ""

            if checkTask.terminationStatus != 0 || checkOutput.isEmpty {
                return ProcessedItem(url: url, status: .notFound)
            }

            let deleteTask = Process()
            deleteTask.launchPath = "/usr/bin/xattr"
            deleteTask.arguments = ["-d", "com.apple.quarantine", path]

            let deletePipe = Pipe()
            deleteTask.standardOutput = deletePipe
            deleteTask.standardError = deletePipe

            try deleteTask.run()
            deleteTask.waitUntilExit()

            if deleteTask.terminationStatus == 0 {
                return ProcessedItem(url: url, status: .removed)
            } else {
                let errData = deletePipe.fileHandleForReading.readDataToEndOfFile()
                let errOutput = String(data: errData, encoding: .utf8) ?? ""
                let reason = errOutput.isEmpty
                    ? "Failed to remove the quarantine attribute."
                    : errOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                return ProcessedItem(url: url, status: .failed(reason: reason))
            }

        } catch {
            return ProcessedItem(url: url, status: .failed(reason: error.localizedDescription))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
