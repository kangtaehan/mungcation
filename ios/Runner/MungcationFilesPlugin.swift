import Flutter
import UIKit
import UniformTypeIdentifiers

final class MungcationFilesPlugin: NSObject, FlutterPlugin, UIDocumentPickerDelegate {
  private var pendingImport: FlutterResult?
  private var sharing = false
  private static let maxBytes = 32 * 1024 * 1024
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "mungcation/files", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(MungcationFilesPlugin(), channel: channel)
  }
  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.filter { $0.activationState == .foregroundActive }
    var controller = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let presented = controller?.presentedViewController { controller = presented }
    return controller
  }
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if sharing || pendingImport != nil { result(FlutterError(code: "busy", message: "열려 있는 파일 작업을 먼저 마쳐 주세요.", details: nil)); return }
    switch call.method {
    case "share":
      let args = call.arguments as? [String: Any] ?? [:]
      guard let path = args["path"] as? String else { result(FlutterError(code: "path", message: "내보낼 파일이 없어요.", details: nil)); return }
      let url = URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath()
      let exportRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("mungcation_exports", isDirectory: true)
        .standardizedFileURL.resolvingSymlinksInPath().path + "/"
      guard url.path.hasPrefix(exportRoot), FileManager.default.fileExists(atPath: url.path), ["json", "gpx"].contains(url.pathExtension.lowercased()) else { result(FlutterError(code: "path", message: "앱에서 만든 내보내기 파일만 열 수 있어요.", details: nil)); return }
      guard let controller = presenter() else { result(FlutterError(code: "presentation", message: "공유 화면을 열지 못했어요.", details: nil)); return }
      sharing = true
      let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
      if let popover = activity.popoverPresentationController {
        popover.sourceView = controller.view
        popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
        popover.permittedArrowDirections = []
      }
      activity.completionWithItemsHandler = { [weak self] _, completed, _, error in
        DispatchQueue.main.async {
          self?.sharing = false
          if let error = error {result(FlutterError(code: "share", message: error.localizedDescription, details: nil))}
          else {result(completed)}
        }
      }
      controller.present(activity, animated: true)
    case "pickBackup":
      guard let controller = presenter() else { result(FlutterError(code: "presentation", message: "파일 선택 화면을 열지 못했어요.", details: nil)); return }
      let picker: UIDocumentPickerViewController
      if #available(iOS 14.0, *) { picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json], asCopy: true) }
      else { picker = UIDocumentPickerViewController(documentTypes: ["public.json"], in: .import) }
      picker.allowsMultipleSelection = false
      picker.delegate = self
      pendingImport = result
      controller.present(picker, animated: true)
    default: result(FlutterMethodNotImplemented)
    }
  }
  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let completion = pendingImport; pendingImport = nil; completion?(nil)
  }
  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let completion = pendingImport else { return }
    pendingImport = nil
    guard let url = urls.first else { completion(nil); return }
    let accessed = url.startAccessingSecurityScopedResource()
    defer {
      if accessed { url.stopAccessingSecurityScopedResource() }
      let path = url.standardizedFileURL.resolvingSymlinksInPath().path
      let inbox = URL(fileURLWithPath: NSHomeDirectory()).resolvingSymlinksInPath().path + "/Documents/Inbox/"
      let temporary = URL(fileURLWithPath: NSTemporaryDirectory()).standardizedFileURL.resolvingSymlinksInPath().path
      let temporaryPrefix = temporary.hasSuffix("/") ? temporary : temporary + "/"
      if path.hasPrefix(inbox) || path.hasPrefix(temporaryPrefix) {try? FileManager.default.removeItem(at: url)}
    }
    do {
      let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
      guard size > 0, size <= Self.maxBytes else { completion(FlutterError(code: "size", message: "32MB 이하의 멍케이션 백업을 선택해 주세요.", details: nil)); return }
      let data = try Data(contentsOf: url, options: [.mappedIfSafe])
      guard data.count <= Self.maxBytes else { completion(FlutterError(code: "size", message: "백업 파일이 너무 커요.", details: nil)); return }
      completion(FlutterStandardTypedData(bytes: data))
    } catch { completion(FlutterError(code: "read", message: "백업 파일을 읽지 못했어요.", details: nil)) }
  }
}
