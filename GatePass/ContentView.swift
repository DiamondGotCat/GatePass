import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    enum ProcessingState: Equatable {
        case idle
        case processing
        case success(message: String)
        case error(message: String)
    }

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
        .frame(minWidth: 400, minHeight: 400)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item]
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
                .padding(40)
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

        case .success(let message):
            resultView(
                iconName: "checkmark.circle.fill",
                iconColor: .green,
                message: message
            )
            .transition(.scale.combined(with: .opacity))

        case .error(let message):
            resultView(
                iconName: "xmark.octagon.fill",
                iconColor: .red,
                message: message
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func resultView(iconName: String, iconColor: Color, message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 70))
                .foregroundColor(iconColor)
            
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

    private func handleDrop(providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        _ = provider.loadObject(ofClass: URL.self) { url, error in
            DispatchQueue.main.async {
                if let url = url {
                    processURL(url)
                } else if let error = error {
                    processingState = .error(message: "Failed to Read.\n\(error.localizedDescription)")
                }
            }
        }
    }

    private func handleFileSelection(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            processURL(url)
        case .failure(let error):
            processingState = .error(message: "Failed to Read.\n\(error.localizedDescription)")
        }
    }

    private func processURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            processingState = .error(message: "Do not have permission to access the file.")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        processingState = .processing

        let path = url.path.replacingOccurrences(of: " ", with: "\\ ")
        let fileName = url.lastPathComponent

        let task = Process()
        task.launchPath = "/usr/bin/xattr"

        task.arguments = ["-p", "com.apple.quarantine", path]
        
        let checkPipe = Pipe()
        task.standardOutput = checkPipe
        task.standardError = checkPipe
        
        do {
            try task.run()
            task.waitUntilExit()

            let checkData = checkPipe.fileHandleForReading.readDataToEndOfFile()
            let checkOutput = String(data: checkData, encoding: .utf8) ?? ""

            if task.terminationStatus != 0 || checkOutput.isEmpty {
                processingState = .success(message: "Not found quarantine attribute for \(fileName)")
                return
            }

            let deleteTask = Process()
            deleteTask.launchPath = "/usr/bin/xattr"
            deleteTask.arguments = ["-d", "com.apple.quarantine", path]
            
            try deleteTask.run()
            deleteTask.waitUntilExit()
            
            if deleteTask.terminationStatus == 0 {
                processingState = .success(message: "Successfully removed the quarantine attribute from \(fileName)")
            } else {
                processingState = .error(message: "Failed to remove the quarantine attribute from \(fileName)")
            }
            
        } catch {
            processingState = .error(message: "Failed to execute command.\n\(error.localizedDescription)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
