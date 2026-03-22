//
//  OCRTextRecognitionService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import UIKit
import Vision

struct OCRTextRecognitionService {
    func recognizeText(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRRecognitionError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["fr-FR", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let recognizedLines = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return recognizedLines.joined(separator: "\n")
    }

    enum OCRRecognitionError: Error {
        case invalidImage
    }
}
