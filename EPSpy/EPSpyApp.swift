//
//  EPSpyApp.swift
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

import UniformTypeIdentifiers
import SwiftUI

extension Array: @retroactive FileDocument {
	public init(configuration: ReadConfiguration) {
		self.init()
	}
	
	public static var readableContentTypes: [UTType] {
        [.plainText]
	}
	
	public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		FileWrapper()
	}
}

extension BenchmarkTargetProcess: CustomStringConvertible {
    public var description: String {
        switch self {
        case .local:
            "in-process"
        case .userService:
            "user service"
        case .rootDaemon:
            "root daemon"
        default:
            fatalError()
        }
    }
}

extension Array where Element: FloatingPoint {

    func sum() -> Element {
        return self.reduce(0, +)
    }

    func average() -> Element {
        return self.sum() / Element(self.count)
    }

    func stdDev() -> Element {
        let mean = self.average()
        let v = self.reduce(0, { $0 + ($1-mean)*($1-mean) })
        return sqrt(v / (Element(self.count) - 1))
    }

    func median() -> Element {
        let sortedArray = sorted()
        if count % 2 != 0 {
            return sortedArray[count / 2]
        } else {
            return (sortedArray[count / 2] + sortedArray[count / 2 - 1]) / (2.0 as! Element)
        }
    }

}

func generateReport(from results: [String: Any]) -> String {
    var rv = [String]()

    let totalDuration = results["totalDuration"] as? Double
    let runResults = results["results"] as? [Double]
    let computeDevices = results["computeDevices"] as? [String: Any]
//    let hostMachine = results["hostMachine"] as? [String: Any]
    let runInformation = results["runInformation"] as? [String: Any]

    guard let totalDuration else {
        return ""
    }

    rv.append("Total Duration: \(totalDuration)")
    if let runInformation, let iterations = runInformation["iterations"] as? Int {
        rv.append("Iterations: \(iterations)")
    }
    if let runInformation, let parallel = runInformation["parallel"] as? Bool {
        rv.append("Parallel: \(parallel ? "Yes" : "No")")
    }
    if let runInformation, let processTarget = runInformation["processTarget"] as? UInt, let processTarget = BenchmarkTargetProcess(rawValue: processTarget) {
        rv.append("Target Process: \(processTarget.description.capitalized)")
    }
    if let computeDevices {
        rv.append("\nCompute Devices:")
        if let availableDevices = computeDevices["availableDevices"] as? [String] {
            rv.append("\tAvailable:")
            for device in availableDevices.sorted() {
                rv.append("\t\t\(device)")
            }
        }
        if let supportedDevices = computeDevices["supportedDevicesMain"] as? [String] {
            rv.append("\tSupported:")
            for device in supportedDevices.sorted() {
                rv.append("\t\t\(device)")
            }
        }
        if let deviceUsed = computeDevices["deviceUsed"] as? String {
            rv.append("\tUsed: \(deviceUsed)")
        } else {
            rv.append("\tUsed: Auto")
        }
    }

    if let runResults, runResults.count > 0 {
        let totalStr = "\(runResults.count)"
        rv.append("\nIterations:")
        for result in runResults.enumerated() {
            let padded = NSString(format: "%\(totalStr.count)u" as NSString, result.offset + 1)
            rv.append("\t\(padded): \(result.element.formattedForDisplay())")
        }
        rv.append("Min: \(runResults.min()!.formattedForDisplay())")
        rv.append("Max: \(runResults.max()!.formattedForDisplay())")
        rv.append("Average: \(runResults.average().formattedForDisplay())")
        rv.append("Median: \(runResults.median().formattedForDisplay())")
        rv.append("Standard Deviation: \(runResults.stdDev().formattedForDisplay())")
    }

    return rv.joined(separator: "\n")
}

extension Double {
    func formattedForDisplay() -> String {
        if isNaN {
            return "-"
        }
        return Duration.seconds(self).formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2, fractionalSecondsLength: 5)))
    }
}

struct ContentView: View {
	@State
	var recording: Bool = false
	
	@State
	var pathPickerPresented: Bool = false

    @State
    var results: [String: Any]? = nil

    @AppStorage("runInDaemon")
    var runInDaemon: Bool = false
	@AppStorage("imagePath")
	var exportURL: URL?
    @AppStorage("processIterations")
    var processIterations: Int = 20
    @AppStorage("devicePredicate")
    var devicePredicate: String?
    @AppStorage("runInParallel")
    var runInParallel: Bool = false

    @MainActor
	func toggleRecording() async {
        recording = true
        do {
            results = try await EPRecordingServiceConnector.processImage(at: exportURL!,
                                                                         iterations: UInt(processIterations),
                                                                         parallel: runInParallel,
                                                                         devicePredicate: devicePredicate,
                                                                         targetProcess: runInDaemon ? .rootDaemon : .local)
        } catch {
            NSAlert(error: error).runModal()
        }
        recording = false
    }

    @Environment(\.openWindow) private var openWindow

	var body: some View {
		Form {
			Section {
				HStack {
					Text(exportURL?.path ?? "<No image selected>")
						.foregroundStyle(exportURL != nil ? Color(NSColor.controlTextColor) : .red)
					Spacer()
					Button("Browse…") {
						pathPickerPresented = true
					}
				}
			} header: {
				Text("Image to Process")
			}
            Section {
                Toggle(isOn: $runInDaemon) {
                    Text("Run in Daemon")
                }
                Picker("Device", selection: $devicePredicate) {
                    Text("Auto").tag(nil as String?)
                    Divider()
                    Text("CPU").tag("cpu" as String?)
                    Text("GPU").tag("gpu" as String?)
                    Text("Neural Engine").tag("neural" as String?)
                }.pickerStyle(.menu)
                HStack {
                    Text("Iterations")
                    Spacer()
                    Slider(value: .init {
                        Double(processIterations)
                    } set: { newValue in
                        processIterations = Int(newValue)
                    }, in: 1.0...200.0)
                    Text(processIterations.formatted()).frame(width: 30)
                }
                Toggle(isOn: $runInParallel) {
                    Text("Run in Parallel")
                }
            } header: {
                Text("Settings")
            }
            Section {
                VStack {
                    if let results, let duration = results["totalDuration"] as? Double {
                        HStack {
                            Text(duration.formattedForDisplay())
                            if let results = results["results"] as? [Double] {
                                Text("(\(results.count) Iterations)")
                            }
                            Spacer()
                            Button("Results") {
                                openWindow(id: "report", value: ResultWrapper(results: results))
                                //                            savePickerDefaultName = "benchmark"
                                //                            savePickerPresented.toggle()
                            }
                        }
                    } else {
                        Text(0.0.formattedForDisplay())
                    }
                }.frame(height: 24.0)
            } header: {
                Text("Results")
            }
		}
		.formStyle(.grouped)
		.disabled(recording)
		.fixedSize(horizontal: false, vertical: true)
		.frame(width: 500)
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button {
					Task {
						await toggleRecording()
					}
				} label: {
					Label {
						Text("Process")
					} icon: {
						Image(systemName: recording ? "stop.fill" : "play.fill")
					}
				}
				.disabled(exportURL == nil || recording == true)
			}
		}
        .scrollDisabled(true)
        .fileImporter(isPresented: $pathPickerPresented, allowedContentTypes: [.image], onCompletion: { result in
            exportURL = try? result.get()
            pathPickerPresented = false
        })
	}
}

#Preview {
	ContentView()
}

struct ResultWrapper: Codable, Hashable {
    let results: [String: Any]

    init(results: [String: Any]) {
        self.results = results
    }

    init(from decoder: any Decoder) throws {
        fatalError()
    }

    func encode(to encoder: any Encoder) throws {
        fatalError()
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        false
    }

    func hash(into hasher: inout Hasher) {
        fatalError()
    }
}

struct ResultView: View {
    let results: [String: Any]

    @State
    var savePickerPresented: Bool = false
    @State
    var savePickerDefaultName: String = "benchmark"

    var body: some View {
        let report = generateReport(from: results)

        ScrollView {
            Text(report)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .multilineTextAlignment(.leading)
                .monospaced()
                .textSelection(.enabled)
                .padding(4)
        }
        .frame(minWidth: 600, minHeight: 360)
        .navigationTitle("Benchmark Results")
        .windowFullScreenBehavior(.disabled)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    savePickerPresented.toggle()
                } label: {
                    Label {
                        Text("Save")
                    } icon: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
            }
        }
        .fileExporter(isPresented: $savePickerPresented, document: [], contentType: .plainText, defaultFilename: savePickerDefaultName) { result in
            do {
                let outputURL = try result.get()
                try generateReport(from: results).write(to: outputURL, atomically: true, encoding: .utf8)
                NSWorkspace.shared.open(outputURL)
            } catch {}
        }
    }
}

@main
struct EPSpyApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
    var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("CSMark")
		}
//		.restorationBehavior(.disabled)
		.defaultPosition(.center)
		.windowResizability(.contentSize)

        WindowGroup(id: "report", for: ResultWrapper.self) { $resultWrapper in
            let results = resultWrapper!.results

            ResultView(results: results)
        }
        .restorationBehavior(.disabled)
        .windowResizability(.contentSize)
    }
	
	class AppDelegate: NSObject, NSApplicationDelegate {
		func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
			true
		}
	}
}
