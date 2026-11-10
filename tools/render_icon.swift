// Original resolution-independent Dooms Day App compass mark. Run from the repository root.
import AppKit
import Foundation

func png(_ size: Int) -> Data {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
    bytesPerRow: size * 4, space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
  context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)
  let green = CGColor(red: 0.12, green: 0.28, blue: 0.22, alpha: 1)
  let cream = CGColor(red: 0.95, green: 0.96, blue: 0.88, alpha: 1)
  let gold = CGColor(red: 0.95, green: 0.73, blue: 0.35, alpha: 1)
  context.setFillColor(green)
  context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
  context.setStrokeColor(cream)
  context.setLineWidth(20)
  context.strokeEllipse(in: CGRect(x: 190, y: 190, width: 644, height: 644))
  context.setLineWidth(10)
  for index in 0..<12 {
    let angle = Double(index) * Double.pi / 6
    let inner = index % 3 == 0 ? 266.0 : 286.0
    context.move(to: CGPoint(x: 512 + cos(angle) * inner, y: 512 + sin(angle) * inner))
    context.addLine(to: CGPoint(x: 512 + cos(angle) * 305, y: 512 + sin(angle) * 305))
    context.strokePath()
  }
  context.setFillColor(gold)
  context.move(to: CGPoint(x: 512, y: 765))
  context.addLine(to: CGPoint(x: 407, y: 470))
  context.addLine(to: CGPoint(x: 512, y: 510))
  context.addLine(to: CGPoint(x: 617, y: 470))
  context.closePath(); context.fillPath()
  context.setFillColor(cream)
  context.move(to: CGPoint(x: 512, y: 259))
  context.addLine(to: CGPoint(x: 407, y: 470))
  context.addLine(to: CGPoint(x: 512, y: 430))
  context.addLine(to: CGPoint(x: 617, y: 470))
  context.closePath(); context.fillPath()
  context.setFillColor(gold)
  context.fillEllipse(in: CGRect(x: 492, y: 858, width: 40, height: 40))
  return NSBitmapImageRep(cgImage: context.makeImage()!).representation(using: .png, properties: [:])!
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let icons = root.appendingPathComponent("ios/Runner/Assets.xcassets/AppIcon.appiconset")
let metadata = try JSONSerialization.jsonObject(with: Data(contentsOf: icons.appendingPathComponent("Contents.json"))) as! [String: Any]
for entry in metadata["images"] as! [[String: String]] {
  guard let name = entry["filename"], let dimensions = entry["size"], let scale = entry["scale"] else { continue }
  let side = Double(dimensions.components(separatedBy: "x")[0])!
  let multiplier = Double(scale.replacingOccurrences(of: "x", with: ""))!
  try png(Int(side * multiplier)).write(to: icons.appendingPathComponent(name))
}
for (density, size) in [("mdpi",48),("hdpi",72),("xhdpi",96),("xxhdpi",144),("xxxhdpi",192)] {
  try png(size).write(to: root.appendingPathComponent("android/app/src/main/res/mipmap-\(density)/ic_launcher.png"))
}
try png(1024).write(to: root.appendingPathComponent("docs/app-icon.png"))
