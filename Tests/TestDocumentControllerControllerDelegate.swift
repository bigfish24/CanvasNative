//
//  TestDocumentControllerDelegate.swift
//  CanvasNative
//
//  Created by Sam Soffes on 2/23/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import Foundation
import CanvasNative

typealias Message = (BlockNode, Int)

final class TestDocumentControllerDelegate: DocumentControllerDelegate {

	// MARK: - Properties

	var blocks = [BlockNode]()
	var presentationString: NSMutableString = ""

	var willUpdate: (Void -> Void)?
	var didInsert: ((BlockNode, Int) -> Void)?
	var didRemove: ((BlockNode, Int) -> Void)?
	var didUpdate: (Void -> Void)?

	var blockTypes: [String] {
		return blocks.map { String($0.dynamicType) }
	}

	var blockDictionaries: [[String: AnyObject]] {
		// Note that we're checking what the delegate thinks the blocks are. This makes sure all of the delegate
		// messages fire in the right order. If they didn't, this would be wrong and the test would fail. Yay.
		return blocks.map { $0.dictionary }
	}


	// MARK: - ControllerDelegate

	func documentControllerWillUpdateDocument(controller: DocumentController) {
		willUpdate?()
	}

	func documentController(controller: DocumentController, didReplaceCharactersInPresentationStringInRange range: NSRange, withString string: String) {
		presentationString.replaceCharactersInRange(range, withString: string)
	}

	func documentController(controller: DocumentController, didInsertBlock block: BlockNode, atIndex index: Int) {
		blocks.insert(block, atIndex: index)
		didInsert?(block, index)
	}

	func documentController(controller: DocumentController, didRemoveBlock block: BlockNode, atIndex index: Int) {
		blocks.removeAtIndex(index)
		didRemove?(block, index)
	}

	func documentControllerDidUpdateDocument(controller: DocumentController) {
		didUpdate?()
	}
}
