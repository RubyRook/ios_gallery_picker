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
        FileManager.default.clearTmpDirectory()

        switch call.method {
            case "imagesPicker":
                self.arguments = call.arguments as? NSDictionary
                self.result = result
                self.setupImageConfig()
                self.imagesPicker()

            default:
                result(FlutterMethodNotImplemented)
        }
    }

    private func setupImageConfig() {
        let config = ZLPhotoConfiguration.default()

        config.customAlertWhenNoAuthority { type in
            if (type == .camera) {
                var message = "Go to settings → enable camera access."
                if var appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] {
                    message = "Go to settings → “\(appName)” and enable camera access."
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

    private func imagesPicker() {
        let ps = ZLPhotoPreviewSheet()
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first

        ps.selectImageBlock = { [weak self] results, isOriginal in
            let group = DispatchGroup()
            var data: Array<NSDictionary> = Array<NSDictionary>()

            for result in results {
                group.enter()

                let asset = result.asset
                let image = result.image
                let fileName = self!.getFileName(asset:asset)
                let format = NSString(string: fileName).pathExtension.lowercased()

                if var media = self!.copyUIImage(image, fileName: fileName, format: format, id: asset.localIdentifier ?? "") {
                    data.append(NSDictionary(dictionary: media))
                }
                group.leave();
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

    private func copyUIImage(_ image: UIImage, fileName: String, format: String? = nil, id: String) -> [String : Any]? {
        var data: Data?

        if "png" == format {
            data = image.pngData()
        } else {
            data = image.jpegData(compressionQuality: CGFloat(0.9))
        }

        guard let data = data else {
            return nil
        }

        /*let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(fileName)*/
        let fileURL = getURL(fileName: fileName)

        do {
            try data.write(to: fileURL)
            let media = [
                "id": id,
                "path": fileURL.path,
                "name": fileName,
                "width": Int(image.size.width) as NSNumber,
                "height": Int(image.size.height) as NSNumber,
            ] as [String : Any]
            return media
        }
        catch {
            print("Error saving image: \(error)")
            return nil
        }
    }

    private func getStringDate() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH_mm_ss_SSSS"
        return formatter.string(from: date)
    }

    private func getFileName(asset: PHAsset) -> String {
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

    private func getURL(fileName:String) -> URL {
        if #available(iOS 10.0, *) {
            return FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName)")
        }
        else {
            return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("\(fileName)")
        }
    }

    private func showAlertPermission(title: String, message: String) {
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













