//
//  NativeController.swift
//  CanvasNative
//
//  Created by Sam Soffes on 2/18/16.
//  Copyright © 2016 Canvas Labs, Inc. All rights reserved.
//

import Foundation

public protocol NativeControllerDelegate: class {
	func nativeControllerWillUpdateNodes(nativeController: NativeController)

	func nativeController(nativeController: NativeController, didInsertBlock block: BlockNode, atIndex index: UInt)

	func nativeController(nativeController: NativeController, didRemoveBlock block: BlockNode, atIndex index: UInt)

	// The block's content changed.
	func nativeController(nativeController: NativeController, didReplaceContentForBlock before: BlockNode, atIndex index: UInt, withBlock after: BlockNode)

	// The block's metadata changed.
	func nativeController(nativeController: NativeController, didUpdateLocationForBlock before: BlockNode, atIndex index: UInt, withBlock after: BlockNode)

	func nativeControllerDidUpdateNodes(nativeController: NativeController)
}


public final class NativeController {

	// MARK: - Properties

	public weak var delegate: NativeControllerDelegate?

	public private(set) var blocks = [BlockNode]()

	private let text: NSMutableString = ""


	// MARK: - Initializers

	public init(text: String? = nil, delegate: NativeControllerDelegate? = nil) {
		self.delegate = delegate

		if let text = text {
			replaceCharactersInRange(NSRange(location: 0, length: self.text.length), withString: text)
		}
	}


	// MARK: - Changing Text

	public func replaceCharactersInRange(range: NSRange, withString string: String) {

		// Notify the delegate we're beginning
		willUpdate()

		// Update the text representation
		text.replaceCharactersInRange(range, withString: string)

		// Reparse the invalid range of document
		let invalidRange = parseRange(range: range, stringLength: (string as NSString).length)
		let parsedBlocks = Parser.parse(string: text, range: invalidRange)

		// Finalize the new blocks
		blocks = applyParsedBlocks(parsedBlocks, parseRange: invalidRange)

		// Notify the delegate we're done
		didUpdate()
	}


	// MARK: - Private

	private func applyParsedBlocks(parsedBlocks: [BlockNode], parseRange: NSRange) -> [BlockNode] {
		// Start to calculate the new blocks
		var workingBlocks = blocks

		// There were existing blocks. Calculate replacements.
		if let blockRange = blockRangeForCharacterRange(parseRange) {
			let updatedBlocks = [BlockNode](blocks[blockRange])
			let blockDelta = parsedBlocks.count - blockRange.count
			var replaced = 0

			// Inserting
			if blockDelta > 0 {
				for i in 0..<blockDelta {
					let block = parsedBlocks[i]
					let index = i + blockRange.startIndex
					workingBlocks.insert(block, atIndex: index)
					replaced += 1
					didInsert(block: block, index: index)
				}
			}

			// TODO: Deleting
			if blockDelta < 0 {

			}

			// Replace the remaining blocks
			for i in replaced..<parsedBlocks.count {
				let after = parsedBlocks[i]
				let index = i + blockRange.startIndex
				let before = workingBlocks[index]
				workingBlocks.removeAtIndex(index)
				workingBlocks.insert(after, atIndex: index)
				didReplace(before: before, index: index, after: after)
			}

			// Update blocks after edit
			//
			// TODO: Adding `blockDelta` here probably isn't right. We need to account for new lines between blocks in
			// a better way.
			let afterCharacterDelta = Int(characterLengthOfBlocks(parsedBlocks)) - Int(characterLengthOfBlocks(updatedBlocks)) + blockDelta
			let afterRange = (blockRange.endIndex + blockDelta)..<workingBlocks.endIndex

			for index in afterRange {
				let before = workingBlocks[index]
				var after = before
				after.offset(afterCharacterDelta)
				workingBlocks[index] = after
				didUpdate(before: before, index: index, after: after)
			}
		}

		// There weren't any blocks in the edited range. Append them after the last block before the edit or at the end.
		else {
			let offset = lastBlockIndexForCharacterRange(parseRange)

			for (i, block) in parsedBlocks.enumerate() {
				let index = offset + i
				workingBlocks.insert(block, atIndex: index)
				didInsert(block: block, index: index)
			}

			let afterCharacterDelta = parsedBlocks.map { $0.enclosingRange.length }.reduce(0, combine: +)

			for index in (offset + parsedBlocks.count)..<workingBlocks.count {
				let before = workingBlocks[index]
				var after = before
				after.offset(afterCharacterDelta)
				workingBlocks[index] = after
				didUpdate(before: before, index: index, after: after)
			}
		}

		// TODO: Unify updating locations
		// TODO: Recalculate positionable

		return workingBlocks
	}

	private func parseRange(range range: NSRange, stringLength: Int) -> NSRange {
		var invalidRange = range
		invalidRange.length = stringLength

		let rangeMax = range.max

		for block in blocks {
			if block.enclosingRange.location >= rangeMax {
				break
			}

			if block.enclosingRange.max - 1 == range.location {
				invalidRange.location += 1
				invalidRange.length -= 1
				break
			}
		}

		return text.lineRangeForRange(invalidRange)
	}

	private func characterLengthOfBlocks(blocks: [BlockNode]) -> UInt {
		return blocks.map { UInt($0.range.length) }.reduce(0, combine: +)
	}

	private func lastBlockIndexForCharacterRange(range: NSRange) -> Int {
		var index: Int?

		for (i, block) in blocks.enumerate() {
			if block.enclosingRange.location < range.location {
				index = i
			} else if block.enclosingRange.location > range.location {
				break
			}
		}

		return (index ?? -1) + 1
	}

	private func blockRangeForCharacterRange(range: NSRange) -> Range<Int>? {
		let location = range.location
		let max = range.max

		var start: Int?
		var end: Int?

		for (i, block) in blocks.enumerate() {
			if block.enclosingRange.location >= max {
				break
			}

			// If the index is in range, add it to the output
			if block.enclosingRange.location >= location && block.enclosingRange.max < max {
				if start == nil {
					start = i
				}

				end = i
			}
		}

		guard let rangeStart = start, rangeEnd = end else { return nil }
		return rangeStart...rangeEnd
	}

	private func willUpdate() {
		delegate?.nativeControllerWillUpdateNodes(self)
	}

	private func didUpdate() {
		delegate?.nativeControllerDidUpdateNodes(self)
	}

	private func didInsert(block block: BlockNode, index: Int) {
		delegate?.nativeController(self, didInsertBlock: block, atIndex: UInt(index))
	}

	private func didReplace(before before: BlockNode, index: Int, after: BlockNode) {
		let i = UInt(index)

		if before.dynamicType == after.dynamicType {
			delegate?.nativeController(self, didReplaceContentForBlock: before, atIndex: i, withBlock: after)
			return
		}

		delegate?.nativeController(self, didRemoveBlock: before, atIndex: i)
		delegate?.nativeController(self, didInsertBlock: after, atIndex: i)
	}

	private func didUpdate(before before: BlockNode, index: Int, after: BlockNode) {
		delegate?.nativeController(self, didUpdateLocationForBlock: before, atIndex: UInt(index), withBlock: after)
	}
}
