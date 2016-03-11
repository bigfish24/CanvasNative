//
//  ControllerRemoveTests.swift
//  CanvasNative
//
//  Created by Sam Soffes on 3/9/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import XCTest
@testable import CanvasNative

class ControllerRemoveTests: XCTestCase {

	// MARK: - Properties

	let controller = Controller()
	let delegate = TestControllerDelegate()


	// MARK: - XCTestCase

	override func setUp() {
		super.setUp()
		controller.delegate = delegate
	}


	// MARK: - Tests

	func testRemoveBlock() {
		// Initial state
		controller.string = "⧙doc-heading⧘Title\nOne\n⧙blockquote⧘> Two"

		let range = NSRange(location: 19, length: 4)
		let replacement = ""
		let blockRange = controller.blockRangeForCharacterRange(range, string: replacement)
		XCTAssertEqual(NSRange(location: 1, length: 1), blockRange)

		let blockquote = controller.blocks[2]

		// Will update
		let will = expectationWithDescription("controllerWillUpdateNodes")
		delegate.willUpdate = { will.fulfill() }

		// Remove
		let remove = expectationWithDescription("controller:didRemoveBlock:atIndex:")
		delegate.didRemove = { block, index in
			XCTAssertEqual("Paragraph", String(block.dynamicType))
			XCTAssertEqual(1, index)
			remove.fulfill()
		}

		// Update
		let update = expectationWithDescription("controller:didUpdateLocationForBlock:atIndex:withBlock:")
		delegate.didUpdateLocation = { before, index, after in
			XCTAssertEqual("Blockquote", String(before.dynamicType))
			XCTAssertEqual(blockquote.range, before.range)
			XCTAssertEqual(1, index)
			XCTAssertEqual("Blockquote", String(after.dynamicType))
			XCTAssertEqual(NSRange(location: 19, length: 17), after.range)

			update.fulfill()
		}

		// Did update
		let did = expectationWithDescription("controllerDidUpdateNodes")
		delegate.didUpdate = { did.fulfill() }

		// Ignored
		delegate.didInsert = { _, _ in XCTFail("Shouldn't insert.") }
		delegate.didReplaceContent = { _, _, _ in XCTFail("Shouldn't replace.") }

		// Edit characters
		controller.replaceCharactersInRange(range, withString: replacement)

		// Wait for expectations
		waitForExpectationsWithTimeout(0.5, handler: nil)

		// Check blocks
		XCTAssertEqual("⧙doc-heading⧘Title\n⧙blockquote⧘> Two", controller.string)
		XCTAssertEqual("Title\nTwo", delegate.presentationString)
		XCTAssertEqual(parse(controller.string), delegate.blockDictionaries)
	}

	func testRemoveEnd() {
		// Initial state
		controller.string = "⧙doc-heading⧘Title\nOne\n⧙blockquote⧘> Two"

		let range = NSRange(location: 21, length: 1)
		let replacement = ""
		let blockRange = controller.blockRangeForCharacterRange(range, string: replacement)
		XCTAssertEqual(NSRange(location: 1, length: 1), blockRange)

		let paragraph = controller.blocks[1]
		let blockquote = controller.blocks[2]

		// Will update
		let will = expectationWithDescription("controllerWillUpdateNodes")
		delegate.willUpdate = { will.fulfill() }

		// Replace
		let replace = expectationWithDescription("controller:didReplaceContentForBlock:atIndex:withBlock:")
		delegate.didReplaceContent = { before, index, after in
			XCTAssertEqual("Paragraph", String(before.dynamicType))
			XCTAssertEqual(paragraph.range, before.range)
			XCTAssertEqual(1, index)
			XCTAssertEqual("Paragraph", String(after.dynamicType))
			XCTAssertEqual(NSRange(location: 19, length: 2), after.range)

			replace.fulfill()
		}

		// Update
		let update = expectationWithDescription("controller:didUpdateLocationForBlock:atIndex:withBlock:")
		delegate.didUpdateLocation = { before, index, after in
			XCTAssertEqual("Blockquote", String(before.dynamicType))
			XCTAssertEqual(blockquote.range, before.range)
			XCTAssertEqual(2, index)
			XCTAssertEqual("Blockquote", String(after.dynamicType))
			XCTAssertEqual(NSRange(location: 22, length: 17), after.range)

			update.fulfill()
		}

		// Did update
		let did = expectationWithDescription("controllerDidUpdateNodes")
		delegate.didUpdate = { did.fulfill() }

		// Ignored
		delegate.didInsert = { _, _ in XCTFail("Shouldn't insert.") }
		delegate.didRemove = { _, _ in XCTFail("Shouldn't remove.") }

		// Edit characters
		controller.replaceCharactersInRange(range, withString: replacement)

		// Wait for expectations
		waitForExpectationsWithTimeout(0.5, handler: nil)

		// Check blocks
		XCTAssertEqual("⧙doc-heading⧘Title\nOn\n⧙blockquote⧘> Two", controller.string)
		XCTAssertEqual("Title\nOn\nTwo", delegate.presentationString)
		XCTAssertEqual(parse(controller.string), delegate.blockDictionaries)
	}

	func testJoinBlock() {
		// Initial state
		controller.string = "⧙doc-heading⧘Title\nOne\nTwo"

		let range = NSRange(location: 22, length: 1)
		let replacement = ""
		let blockRange = controller.blockRangeForCharacterRange(range, string: replacement)
		XCTAssertEqual(NSRange(location: 1, length: 2), blockRange)

		// Edit characters
		controller.replaceCharactersInRange(range, withString: replacement)

		// Check blocks
		XCTAssertEqual("⧙doc-heading⧘Title\nOneTwo", controller.string)
		XCTAssertEqual("Title\nOneTwo", delegate.presentationString)
		XCTAssertEqual(parse(controller.string), delegate.blockDictionaries)
	}

	func testMultipleJoin() {
		// Initial state
		controller.string = "⧙doc-heading⧘Title\nOne\nTwo\nThree"

		let range = NSRange(location: 22, length: 5)
		let replacement = ""
		let blockRange = controller.blockRangeForCharacterRange(range, string: replacement)
		XCTAssertEqual(NSRange(location: 1, length: 3), blockRange)

		// Edit characters
		controller.replaceCharactersInRange(range, withString: replacement)

		// Check blocks
		XCTAssertEqual("⧙doc-heading⧘Title\nOneThree", controller.string)
		XCTAssertEqual("Title\nOneThree", delegate.presentationString)
		XCTAssertEqual(parse(controller.string), delegate.blockDictionaries)
	}

	func testMultipleRemoveBlock() {
		controller.string = "⧙doc-heading⧘Title\nOne\nTwo\nThree\nFour"
		controller.replaceCharactersInRange(NSRange(location: 22, length: 10), withString: "")
		XCTAssertEqual("⧙doc-heading⧘Title\nOne\nFour", controller.string)
		XCTAssertEqual("Title\nOne\nFour", delegate.presentationString)
		XCTAssertEqual(parse(controller.string), delegate.blockDictionaries)

		controller.string = "⧙doc-heading⧘Title\nOne\nTwo\nThree\nFour"
		controller.replaceCharactersInRange(NSRange(location: 23, length: 10), withString: "")
		XCTAssertEqual("⧙doc-heading⧘Title\nOne\nFour", controller.string)
		XCTAssertEqual("Title\nOne\nFour", delegate.presentationString)
		XCTAssertEqual(parse(controller.string), delegate.blockDictionaries)
	}
}