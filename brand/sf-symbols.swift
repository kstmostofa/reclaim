// Renders the SF Symbols the website's app replica uses into website/public/sf-symbols:
//   swiftc -O -o /tmp/sf-symbols brand/sf-symbols.swift && /tmp/sf-symbols website/public/sf-symbols \
//     internaldrive shippingbox hammer archivebox iphone square.stack.3d.up gearshape.2 chart.bar.doc.horizontal \
//     doc.richtext doc.on.doc shippingbox.circle lock.shield magnifyingglass checkmark.circle app.dashed doc.text \
//     sidebar.left sidebar.right chevron.down checkmark arrow.clockwise chevron.right
// SF Symbols are Apple's; they are used here only to depict this Mac app's own interface.

import AppKit

// Renders SF Symbols as black-on-transparent PNG masks, each centred on the same square canvas so they line up.
let out = CommandLine.arguments[1]
let names = Array(CommandLine.arguments.dropFirst(2))
let canvas: CGFloat = 24, scale: CGFloat = 4, pointSize: CGFloat = 15

for name in names {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular, scale: .medium)
    guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
        print("missing \(name)"); continue
    }
    let px = Int(canvas * scale)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: canvas, height: canvas)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = symbol.size
    let rect = NSRect(x: (canvas - s.width) / 2, y: (canvas - s.height) / 2, width: s.width, height: s.height)
    symbol.draw(in: rect)
    NSGraphicsContext.restoreGraphicsState()
    let file = name.replacingOccurrences(of: ".", with: "-") + ".png"
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out + "/" + file))
    print("\(file) \(s.width)x\(s.height)")
}
