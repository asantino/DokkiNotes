import Flutter
import UIKit

class ICloudHandler: NSObject, FlutterPlugin {
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "kz.dokki.dokkinotes/icloud", binaryMessenger: registrar.messenger())
        let instance = ICloudHandler()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(isICloudAvailable())
        case "uploadFile":
            if let args = call.arguments as? [String: Any],
               let localPath = args["localPath"] as? String,
               let fileName = args["fileName"] as? String {
                uploadFile(localPath: localPath, fileName: fileName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "downloadFile":
            if let args = call.arguments as? [String: Any],
               let fileName = args["fileName"] as? String {
                downloadFile(fileName: fileName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "checkForUpdates":
            if let args = call.arguments as? [String: Any],
               let fileName = args["fileName"] as? String {
                checkForUpdates(fileName: fileName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "getLastModified":
            if let args = call.arguments as? [String: Any],
               let fileName = args["fileName"] as? String {
                getLastModified(fileName: fileName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        case "deleteFile":
            if let args = call.arguments as? [String: Any],
               let fileName = args["fileName"] as? String {
                deleteFile(fileName: fileName, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - iCloud Methods
    
    private func isICloudAvailable() -> Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    private func getICloudURL() -> URL? {
        return FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
    }
    
    private func uploadFile(localPath: String, fileName: String, result: @escaping FlutterResult) {
        guard let iCloudURL = getICloudURL() else {
            result(false)
            return
        }
        
        let localURL = URL(fileURLWithPath: localPath)
        let destinationURL = iCloudURL.appendingPathComponent(fileName)
        
        // Создаём директорию Documents если не существует
        try? FileManager.default.createDirectory(at: iCloudURL, withIntermediateDirectories: true, attributes: nil)
        
        do {
            // Удаляем старый файл если существует
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Копируем файл в iCloud
            try FileManager.default.copyItem(at: localURL, to: destinationURL)
            result(true)
        } catch {
            print("iCloud upload error: \(error)")
            result(false)
        }
    }
    
    private func downloadFile(fileName: String, result: @escaping FlutterResult) {
        guard let iCloudURL = getICloudURL() else {
            result(nil)
            return
        }
        
        let sourceURL = iCloudURL.appendingPathComponent(fileName)
        
        // Проверяем существует ли файл
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            result(nil)
            return
        }
        
        // Создаём временный путь для загрузки
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(fileName)
        
        do {
            // Удаляем старый файл если существует
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.removeItem(at: localURL)
            }
            
            // Копируем файл из iCloud
            try FileManager.default.copyItem(at: sourceURL, to: localURL)
            result(localURL.path)
        } catch {
            print("iCloud download error: \(error)")
            result(nil)
        }
    }
    
    private func checkForUpdates(fileName: String, result: @escaping FlutterResult) {
        guard let iCloudURL = getICloudURL() else {
            result(false)
            return
        }
        
        let fileURL = iCloudURL.appendingPathComponent(fileName)
        result(FileManager.default.fileExists(atPath: fileURL.path))
    }
    
    private func getLastModified(fileName: String, result: @escaping FlutterResult) {
        guard let iCloudURL = getICloudURL() else {
            result(nil)
            return
        }
        
        let fileURL = iCloudURL.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            result(nil)
            return
        }
        
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let modificationDate = attributes[.modificationDate] as? Date {
                let timestamp = Int(modificationDate.timeIntervalSince1970 * 1000)
                result(timestamp)
            } else {
                result(nil)
            }
        } catch {
            print("Get last modified error: \(error)")
            result(nil)
        }
    }
    
    private func deleteFile(fileName: String, result: @escaping FlutterResult) {
        guard let iCloudURL = getICloudURL() else {
            result(false)
            return
        }
        
        let fileURL = iCloudURL.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            result(true) // Файл уже не существует
            return
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            result(true)
        } catch {
            print("Delete file error: \(error)")
            result(false)
        }
    }
}
