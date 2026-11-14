// Exports macOS's arrow pointer for the website replica:
//   swiftc -O -o /tmp/cursor brand/cursor.swift && /tmp/cursor website/public/cursor-arrow.png
import AppKit
// Saves macOS's arrow pointer as its largest bitmap, and prints its size and hot spot in points.
_ = NSApplication.shared
let cursor = NSCursor.arrow
let image = cursor.image
var rect = NSRect(origin: .zero, size: image.size)
guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: [.ctm: AffineTransform(scale: 2)]) else { fatalError("no image") }
let rep = NSBitmapImageRep(cgImage: cg)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("points \(image.size.width)x\(image.size.height) pixels \(cg.width)x\(cg.height) hotspot \(cursor.hotSpot.x),\(cursor.hotSpot.y)")
