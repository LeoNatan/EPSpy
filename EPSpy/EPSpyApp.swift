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

extension Array where Element == [Double] {
	public func min() -> Double {
		sums().min()!
	}

	public func max() -> Double {
		sums().max()!
	}

	func sums() -> [Double] {
		map { $0.sum() }
	}

	func sum() -> Double {
		return sums().reduce(0, +)
	}

	func average() -> Double {
		return self.sum() / Double(self.count)
	}

	func stdDev() -> Double {
		let mean = self.average()
		let v = sums().reduce(0, { $0 + ($1-mean)*($1-mean) })
		return sqrt(v / (Double(self.count) - 1))
	}

	func median() -> Double {
		let sortedArray = sums().sorted()
		if count % 2 != 0 {
			return sortedArray[count / 2]
		} else {
			return (sortedArray[count / 2] + sortedArray[count / 2 - 1]) / 2.0
		}
	}
}

func generateReport(from results: [String: Any]) -> String {
    var rv = [String]()

    let totalDuration = results["totalDuration"] as? Double
    let runResults = results["results"] as? [[Double]]
    let computeDevices = results["computeDevices"] as? [String: Any]
    let hostMachine = results["hostMachine"] as? [String: Any]
    let runInformation = results["runInformation"] as? [String: Any]
	let parsedText = results["parseResults"] as? [[String: Any]]

    guard let totalDuration else {
        return ""
    }

    rv.append("Total Duration: \(totalDuration)")
    if let runInformation, let iterations = runInformation["iterations"] as? Int {
        rv.append("Iterations: \(iterations)")
    }
	if let runInformation, let inputScale = runInformation["inputScale"] as? Double {
		rv.append("Input Scale: \(inputScale.formatted(.percent.precision(.fractionLength(0))))")
	}
    if let runInformation, let parallel = runInformation["parallel"] as? Bool {
        rv.append("Parallel: \(parallel ? "Yes" : "No")")
    }
    if let runInformation, let processTarget = runInformation["processTarget"] as? UInt, let processTarget = BenchmarkTargetProcess(rawValue: processTarget) {
        rv.append("Target Process: \(processTarget.description.capitalized)")
    }

	if let hostMachine {
		rv.append("\nHost Environment")
		rv.append("----------------\n")
		if let os = hostMachine["os"] as? String {
			rv.append("macOS \(os)")
		}
		if let visionRevision = hostMachine["visionRevision"] as? Int {
			rv.append("Text Recognition Revision: \(visionRevision)")
		}
		if let hw_model = hostMachine["hw_model"] as? String {
			rv.append("Model: \(hw_model)")
		}
		if let hw_machine = hostMachine["hw_machine"] as? String {
			rv.append("Machine: \(hw_machine)")
		}
	}

    if let computeDevices {
        rv.append("\nCompute Devices")
		rv.append("---------------\n")
        if let availableDevices = computeDevices["availableDevices"] as? [String] {
            rv.append("Available:")
            for device in availableDevices.sorted() {
                rv.append("\t\(device)")
            }
        }
        if let supportedDevices = computeDevices["supportedDevicesMain"] as? [String] {
            rv.append("Supported:")
            for device in supportedDevices.sorted() {
                rv.append("\t\(device)")
            }
        }
        if let deviceUsed = computeDevices["deviceUsed"] as? String {
            rv.append("Used: \(deviceUsed)")
        } else {
            rv.append("Used: Auto")
        }
    }

    if let runResults, runResults.count > 0 {
        let totalStr = "\(runResults.count)"
        rv.append("\nIterations")
		rv.append("----------\n")
        for result in runResults.enumerated() {
            let padded = NSString(format: "%\(totalStr.count)u" as NSString, result.offset + 1)
			
			var times = [String]()
			for time in result.element {
				times.append(time.formattedForDisplay())
			}
			if(times.count == 1) {
				rv.append("\(padded): \(times.joined(separator: " + "))")
			} else {
				rv.append("\(padded): \(result.element.sum().formattedForDisplay()) (\(times.joined(separator: " + ")))")
			}

        }
        rv.append("\nMin: \(runResults.min().formattedForDisplay())")
        rv.append("Max: \(runResults.max().formattedForDisplay())")
        rv.append("Average: \(runResults.average().formattedForDisplay())")
        rv.append("Median: \(runResults.median().formattedForDisplay())")
        rv.append("Standard Deviation: \(runResults.stdDev().formattedForDisplay())")
    }

	if let parsedText {
		rv.append("\nParsed Text")
		rv.append("-----------\n")

		var strings = [String]()
		for parsed in parsedText {
			guard let confidence = parsed["confidence"] as? Float,
				  let string = parsed["string"] as? String else {
				continue
			}

			let padded = NSString(format: "%4s" as NSString, (confidence.formatted(.percent.precision(.fractionLength(0))) as NSString).utf8String!)
			strings.append("(\(padded)) \(string)")
		}
		rv.append(strings.joined(separator: "\n"))
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
	@AppStorage("inputScale")
	var inputScale: Double = 1.0
    @AppStorage("correct")
    var correct: Bool = true

    @MainActor
	func toggleRecording() async {
        recording = true
        do {
            results = try await EPRecordingServiceConnector.processImage(at: exportURL!,
                                                                         iterations: UInt(processIterations),
                                                                         parallel: runInParallel,
                                                                         devicePredicate: devicePredicate,
																		 inputScale: inputScale,
                                                                         correct: correct,
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
                HStack {
                    Text("Input Scale")
                    Spacer()
                    Slider(value: $inputScale, in: 0.1...1.05, step: 0.05)
                    if inputScale > 1.0 {
                        Text("CV").frame(width: 40)
                    } else if inputScale == 1.0 {
                        Text("URL").frame(width: 40)
                    } else {
                        Text(inputScale.formatted(.percent.precision(.fractionLength(0)))).frame(width: 40)
                    }
                }
                Toggle(isOn: $correct) {
                    Text("Uses Language Correction")
                }
            } header: {
                Text("Settings")
            }
            Section {
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
                Picker("Device", selection: $devicePredicate) {
                    Text("Auto").tag(nil as String?)
                    Divider()
                    Text("CPU").tag("cpu" as String?)
                    Text("GPU").tag("gpu" as String?)
                    Text("Neural Engine").tag("neural" as String?)
                }.pickerStyle(.menu)
                Toggle(isOn: $runInDaemon) {
                    Text("Run in Daemon")
                }
            }
            Section {
                VStack {
                    if let results, let duration = results["totalDuration"] as? Double {
                        HStack {
                            Text(duration.formattedForDisplay())
                            if let results = results["results"] as? [[Double]] {
                                Text("(\(results.count) Iterations)")
                            }
                            Spacer()
                            Button("Results") {
                                openWindow(id: "report", value: ResultWrapper(results: results))
                            }
                        }
                    } else {
						EmptyView()
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
        .fileImporter(isPresented: $pathPickerPresented, allowedContentTypes: [.image]) { result in
            exportURL = try? result.get()
            pathPickerPresented = false
        }
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

		TextEditor(text: Binding.constant(report))
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
			.multilineTextAlignment(.leading)
			.monospaced()
			.textSelection(.enabled)
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
		.commands {
			TextEditingCommands()
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
