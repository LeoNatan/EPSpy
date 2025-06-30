//
//  FilterEditor.swift
//  EPSpy
//
//  Created by Léo Natan on 30/6/25.
//

import Cocoa

class FilterEditor: NSViewController {
	@IBOutlet @ViewLoading
	var predicateEditor: NSPredicateEditor

    override func viewDidLoad() {
        super.viewDidLoad()
        
		predicateEditor.objectValue = emptyPredicate()
    }
	
	override func viewWillAppear() {
		super.viewWillAppear()
		
		view.window?.minSize = NSSize(width: 300, height: 200)
	}
    
	fileprivate
	func emptyPredicate() -> NSPredicate {
		NSCompoundPredicate(type: .and, subpredicates: [])
	}
	
	var predicateData: Data? {
		set {
			guard let newValue,
				  let predicate = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPredicate.self, from: newValue) else {
				predicateEditor.objectValue = emptyPredicate()
				return
			}
			
			predicateEditor.objectValue = predicate
		}
		get {
			return try? NSKeyedArchiver.archivedData(withRootObject: predicateEditor.objectValue as Any, requiringSecureCoding: false)
		}
	}
	
	var completionHandler: ((FilterEditor) -> Void)?
	
	@IBAction fileprivate
	func save(_ sender: Any) {
		if let window = view.window {
			window.sheetParent?.endSheet(window)
		}
		completionHandler?(self)
	}
	
	@IBAction fileprivate
	func cancel(_ sender: Any) {
		if let window = view.window {
			window.sheetParent?.endSheet(window)
		}
	}
	
	@IBAction fileprivate
	func delete(_ sender: Any) {
		self.predicateData = nil
		save(sender)
	}
}
