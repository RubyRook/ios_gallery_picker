import Flutter
import Foundation
import Photos
import UIKit
import ZLPhotoBrowser

public class IosGalleryPickerPlugin: NSObject, FlutterPlugin, UINavigationControllerDelegate {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ios_gallery_picker", binaryMessenger: registrar.messenger())
        let instance = IosGalleryPickerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    var arguments: NSDictionary? = nil
    var result: FlutterResult? = nil

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.arguments = call.arguments as? NSDictionary
        self.result = result

        switch call.method {
            case "imagesPickerAsset":
                self.setupImageConfig()
                self.imagesPickerAsset()

            default:
                result(FlutterMethodNotImplemented)
        }
    }

    private func setupImageConfig() {
        let config = ZLPhotoConfiguration.default()

        config.customAlertWhenNoAuthority { type in
            if (type == .camera) {
                var message = "Go to “Settings” and enable camera access."

                if var appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") {
                    if #available(iOS 18.0, *) {
                        message = "Go to “Settings” → “Apps” → “\(appName)” and enable camera access."
                    }
                    else {
                        message = "Go to “Settings” → “\(appName)” and enable camera access."
                    }
                }

                self.showAlertPermission(
                    title: "Camera has been turned off",
                    message: message
                )
            }
        }

        config.allowSelectGif = arguments?["allowSelectGif"] as? Bool ?? false
        config.allowTakePhotoInLibrary = arguments?["allowTakePhotoInLibrary"] as? Bool ?? false
        config.maxSelectCount = arguments?["maxSelectCount"] as? Int ?? 1

        config.allowSelectVideo = false
        config.allowSelectLivePhoto = false
        config.allowSelectOriginal = false
        config.allowSlideSelect = true

        config.allowEditImage = false
        config.allowMixSelect = false
        config.allowPreviewPhotos = false

        let uiConfig = ZLPhotoUIConfiguration.default()
        uiConfig.columnCount = 5
    }

    // MARK: Asset select.
    private func imagesPickerAsset() { // checked
        let deliveryMode = arguments?["deliveryMode"] as? Int ?? 0
        let ps = ZLPhotoPreviewSheet()
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first

        ps.selectImageBlock = { [weak self] results, isOriginal in
            let group = DispatchGroup()
            let selectedAssets = results.map { $0.asset }
            var data: Array<NSDictionary> = Array<NSDictionary>()

            for asset in selectedAssets {
                group.enter()

                let fileName = self!.getFileName(asset:asset)
                let localUrl = self!.getURL(fileName: fileName)

                var media = [
                    "id": asset.localIdentifier ?? "",
                    "name": fileName,
                    "width": Int(asset.pixelWidth) as NSNumber,
                    "height": Int(asset.pixelHeight) as NSNumber,
                ] as [String : Any]

                self!.writePhoto(asset:asset, url:localUrl, deliveryMode:deliveryMode, completionBlock:{(url) in
                    media["path"] = url.path
                    data.append(NSDictionary(dictionary: media))
                    group.leave();
                })
            }

            group.notify(queue: .main){
                self!.result!(data);
            }
        }

        ps.cancelBlock = {
            var data: Array<NSDictionary> = Array<NSDictionary>()
            self.result!(data);
        }

        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }

            ps.showPhotoLibrary(sender: topController)
        }
    }

    private func writePhoto(asset: PHAsset, url: URL, deliveryMode: Int = 0, completionBlock:@escaping ((URL) -> Void)) { // checked
        let option = PHImageRequestOptions()
        if asset.zl.isGif {
            option.version = .original
        }
        option.isNetworkAccessAllowed = true
        option.resizeMode = .fast

        if (deliveryMode == 0) {
            option.deliveryMode = .opportunistic
        }
        else if (deliveryMode == 1) {
            option.deliveryMode = .highQualityFormat
        }
        else if (deliveryMode == 2) {
            option.deliveryMode = .fastFormat
        }

        let resultHandler: (Data?) -> Void = { data in
            do {
                try data?.write(to: url)
                DispatchQueue.main.async {
                    completionBlock(url)
                }
            }
            catch {
                print("Error saving image: \(error)")
            }
        }

        if #available(iOS 13.0, *) {
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: option) { data, _, _, info in
                resultHandler(data)
            }
        }
        else {
            PHImageManager.default().requestImageData(for: asset, options: option) { data, _, _, info in
                resultHandler(data)
            }
        }
    }

    // MARK: Support method.
    private func getStringDate(dateFormat:String = "HH_mm_ss_SSSS") -> String { // checked
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = dateFormat
        return formatter.string(from: date)
    }

    private func getFileName(asset: PHAsset) -> String { // checked
        var fileName = getStringDate()+".JPG"
        let resources = PHAssetResource.assetResources(for: asset)

        if let resource = resources.first {
            fileName = resource.originalFilename
        }
        else if let forKey = asset.value(forKey: "filename") as? String {
            fileName = forKey
        }

        return fileName
    }

    private func getURL(fileName:String) -> URL { // checked
        let name = "\(UUID().uuidString)-\(fileName)"

        if #available(iOS 10.0, *) {
            return FileManager.default.temporaryDirectory.appendingPathComponent("\(name)")
        }
        else {
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("\(name)")
        }
    }

    private func showAlertPermission(title: String, message: String) { // checked
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Setting", style: .default) { (_) -> Void in
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
               return
            }

            if UIApplication.shared.canOpenURL(settingsUrl) {
               UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .default, handler: nil)

        alert.addAction(cancelAction)
        alert.addAction(settingsAction)
        alert.preferredAction = settingsAction

        UIApplication.topViewController()?.present(alert, animated: true, completion: nil)
    }

    private func getAsset(localIdentifier: String?) -> PHAsset? {
        guard let id = localIdentifier else {
            return nil
        }

        let result = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        return result.firstObject
    }
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
        } catch {
            print(error)
        }
    }
}

extension UIApplication {
    class func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        if let alert = base as? UIAlertController {
            if let navigationController = alert.presentingViewController as? UINavigationController {
                return navigationController.viewControllers.last
            }
            return alert.presentingViewController
        }
        return base
    }
}













