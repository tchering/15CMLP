//
//  MemberPhotoStorageService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation
import UIKit

struct MemberPhotoStorageService {
    static let shared = MemberPhotoStorageService()

    func loadImage(for member: Member) -> UIImage? {
        if let storedPhotoFileName = member.storedPhotoFileName,
           let image = UIImage(contentsOfFile: fileURL(for: storedPhotoFileName).path) {
            return image
        }

        if let bundledImageName = member.bundledImageName,
           let image = UIImage(named: bundledImageName) {
            return image
        }

        return nil
    }

    func photoData(for fileName: String) -> Data? {
        try? Data(contentsOf: fileURL(for: fileName))
    }

    func savePhoto(data: Data) throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let storedData = normalizedPhotoData(from: data)
        try storedData.write(to: fileURL(for: fileName), options: [.atomic])
        return fileName
    }

    func deletePhoto(fileName: String?) {
        guard let fileName else {
            return
        }

        try? FileManager.default.removeItem(at: fileURL(for: fileName))
    }

    func replacePhotos(with photos: [String: Data]) {
        let directoryURL = photosDirectoryURL()

        if let existingFiles = try? FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) {
            for fileURL in existingFiles {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        for (fileName, data) in photos {
            try? data.write(to: fileURL(for: fileName), options: [.atomic])
        }
    }

    func photosDirectoryURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosURL = documentsURL.appendingPathComponent("MemberPhotos", isDirectory: true)

        if !FileManager.default.fileExists(atPath: photosURL.path) {
            try? FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        }

        return photosURL
    }

    func fileURL(for fileName: String) -> URL {
        photosDirectoryURL().appendingPathComponent(fileName)
    }

    private func normalizedPhotoData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.85) else {
            return data
        }

        return jpegData
    }
}
