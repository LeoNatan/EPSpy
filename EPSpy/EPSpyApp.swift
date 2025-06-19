//
//  EPSpyApp.swift
//  EPSpy
//
//  Created by Léo Natan on 18/6/25.
//

import UniformTypeIdentifiers
import SwiftUI
import EndpointSecurity

extension Array: @retroactive FileDocument {
	public init(configuration: ReadConfiguration) {
		self.init()
	}
	
	public static var readableContentTypes: [UTType] {
		[.json]
	}
	
	public func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
		FileWrapper()
	}
}

extension Array: @retroactive RawRepresentable where Element == es_event_type_t {
	public init?(rawValue: String) {
		guard
			let data = rawValue.data(using: .utf8),
			let result = try? JSONDecoder().decode([UInt32].self, from: data)
		else { return nil }
		self = result.compactMap { es_event_type_t($0) }
	}
	
	public var rawValue: String {
		guard
			let data = try? JSONEncoder().encode(self.map { $0.rawValue }),
			let result = String(data: data, encoding: .utf8)
		else { return "" }
		return result
	}
}

extension NSButton {
	open override var focusRingType: NSFocusRingType {
		get { .none }
		set { }
	}
}

struct ContentView: View {
	@State
	var recording: Bool = false
	
	@State
	var pathPickerPresented: Bool = false
	@AppStorage("exportPath")
	var exportURL: URL?
	
	let supportedProcessEvents: [(name: String, value: es_event_type_t)] = [
		("ES_EVENT_TYPE_NOTIFY_EXEC", ES_EVENT_TYPE_NOTIFY_EXEC),
		("ES_EVENT_TYPE_NOTIFY_FORK", ES_EVENT_TYPE_NOTIFY_FORK),
		("ES_EVENT_TYPE_NOTIFY_EXIT", ES_EVENT_TYPE_NOTIFY_EXIT)
	].sorted { $0.name.compare($1.name) == .orderedAscending }
	
	let supportedFileEvents: [(name: String, value: es_event_type_t)] = [
		("ES_EVENT_TYPE_NOTIFY_OPEN", ES_EVENT_TYPE_NOTIFY_OPEN),
		("ES_EVENT_TYPE_NOTIFY_CLOSE", ES_EVENT_TYPE_NOTIFY_CLOSE),
		("ES_EVENT_TYPE_NOTIFY_WRITE", ES_EVENT_TYPE_NOTIFY_WRITE),
	].sorted { $0.name.compare($1.name) == .orderedAscending }
	
	let supportedOtherEvents: [(name: String, value: es_event_type_t)] = [
		("ES_EVENT_TYPE_NOTIFY_XPC_CONNECT", ES_EVENT_TYPE_NOTIFY_XPC_CONNECT),
	].sorted { $0.name.compare($1.name) == .orderedAscending }
	
	@AppStorage("events")
	var events: [es_event_type_t] = []
	
	@AppStorage("ignorePlatformProcesses")
	var ignorePlatformProcesses: Bool = true
	@AppStorage("expandProcess")
	var expandProcess: Bool = false
	@AppStorage("recordLaunchArguments")
	var recordLaunchArguments: Bool = false
	@AppStorage("recordEnvironmentVariables")
	var recordEnvironmentVariables: Bool = false
	
	var body: some View {
		Form {
			Section {
				HStack {
					Text(exportURL?.path ?? "<No file selected>")
						.foregroundStyle(exportURL != nil ? Color(NSColor.controlTextColor) : .red)
					Spacer()
					Button("Browse") {
						pathPickerPresented = true
					}
				}
			} header: {
				Text("Recording File")
			}
			Section {
				ForEach(supportedProcessEvents, id: \.value) { supportedEvent in
					Toggle(supportedEvent.name, isOn: Binding(get: {
						events.contains(supportedEvent.value)
					}, set: { newValue in
						if newValue {
							events.append(supportedEvent.value)
						} else {
							events.removeAll { $0 == supportedEvent.value }
						}
					})).focusEffectDisabled()
				}
			} header: {
				Text("Process Events")
			}
			Section {
				ForEach(supportedFileEvents, id: \.value) { supportedEvent in
					Toggle(supportedEvent.name, isOn: Binding(get: {
						events.contains(supportedEvent.value)
					}, set: { newValue in
						if newValue {
							events.append(supportedEvent.value)
						} else {
							events.removeAll { $0 == supportedEvent.value }
						}
					})).focusEffectDisabled()
				}
			} header: {
				Text("File Events")
			}
			Section {
				ForEach(supportedOtherEvents, id: \.value) { supportedEvent in
					Toggle(supportedEvent.name, isOn: Binding(get: {
						events.contains(supportedEvent.value)
					}, set: { newValue in
						if newValue {
							events.append(supportedEvent.value)
						} else {
							events.removeAll { $0 == supportedEvent.value }
						}
					})).focusEffectDisabled()
				}
			} header: {
				Text("Other Events")
			}
			Section {
				Toggle("Ignore Apple Processes", isOn: $ignorePlatformProcesses)
				Toggle("Expand Process", isOn: $expandProcess)
				Toggle("Record Launch Arguments", isOn: $recordLaunchArguments)
				Toggle("Record Environment Variables", isOn: $recordEnvironmentVariables)
			} header: {
				Text("Options")
			}.toggleStyle(.checkbox)
		}
		.formStyle(.grouped)
		.disabled(recording)
		.fixedSize(horizontal: true, vertical: true)
//		.frame(maxHeight: 350)
		.toolbar {
			ToolbarItem(placement: .confirmationAction) {
				Button {
					if recording {
						EPRecordingServiceConnector.stopRecording()
						recording = false
					} else {
						recording = EPRecordingServiceConnector.startRecording(with: exportURL!, events: events.map { NSNumber(value: $0.rawValue) }, options: {
							let options = EPRecorderOptions()
							options.ignorePlatformProcesses = ignorePlatformProcesses
							options.expandProcess = expandProcess
							options.recordLaunchArguments = recordLaunchArguments
							options.recordEnvironmentVariables = recordEnvironmentVariables
							return options
						}())
					}
				} label: {
					Label {
						Text(recording ? "Stop" : "Record")
					} icon: {
						Image(systemName: recording ? "stop.fill" : "play.fill")
					}
				}
				.disabled(exportURL == nil || events.count == 0)
			}
		}
		.fileExporter(isPresented: $pathPickerPresented, document: [], contentType: .json, defaultFilename: "recording") { result in
			exportURL = try? result.get()
			pathPickerPresented = false
		}
	}
}

#Preview {
	ContentView()
}

@main
struct EPSpyApp: App {
	@NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
	
    var body: some Scene {
        WindowGroup {
            ContentView()
		}
		.restorationBehavior(.disabled)
		.defaultPosition(.center)
		.windowResizability(.contentSize)
    }
	
	class AppDelegate: NSObject, NSApplicationDelegate {
		func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
			true
		}
	}
}
