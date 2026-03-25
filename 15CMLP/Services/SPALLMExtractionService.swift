//
//  SPALLMExtractionService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct SPALLMExtractionService {
    struct Configuration {
        let apiKey: String
        let model: String
        let baseURL: URL
        let organizationID: String?
        let projectID: String?

        init(
            apiKey: String,
            model: String = "gpt-5",
            baseURL: URL = URL(string: "https://api.openai.com/v1/responses")!,
            organizationID: String? = nil,
            projectID: String? = nil
        ) {
            self.apiKey = apiKey
            self.model = model
            self.baseURL = baseURL
            self.organizationID = organizationID
            self.projectID = projectID
        }

        static func load() -> Configuration? {
            let environment = ProcessInfo.processInfo.environment
            let fileSecrets = LocalSecrets.load()
            let apiKey = (
                fileSecrets?.apiKey ??
                environment["OPENAI_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ) ?? ""

            guard !apiKey.isEmpty else {
                return nil
            }

            let model = (
                fileSecrets?.model ??
                environment["OPENAI_MODEL"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            ) ?? "gpt-5"
            let organizationID = environment["OPENAI_ORGANIZATION_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            let projectID = environment["OPENAI_PROJECT_ID"]?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty

            return Configuration(
                apiKey: apiKey,
                model: model,
                organizationID: organizationID,
                projectID: projectID
            )
        }
    }

    private let configuration: Configuration?
    private let urlSession: URLSession

    init(
        configuration: Configuration? = Configuration.load(),
        urlSession: URLSession = .shared
    ) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    func extractEntries(from rawText: String) async throws -> [SPAEntry] {
        let trimmedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty else {
            throw ExtractionError.emptyInput
        }

        guard let configuration else {
            throw ExtractionError.missingAPIKey
        }

        var request = URLRequest(url: configuration.baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Client-Request-Id")

        if let organizationID = configuration.organizationID {
            request.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }

        if let projectID = configuration.projectID {
            request.setValue(projectID, forHTTPHeaderField: "OpenAI-Project")
        }

        let payload = ResponseRequest(
            model: configuration.model,
            instructions: Self.instructions,
            input: trimmedText,
            store: false,
            text: .init(format: .spaEntriesSchema)
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExtractionError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let apiError = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            throw ExtractionError.apiFailure(
                statusCode: httpResponse.statusCode,
                message: apiError?.error.message ?? "The LLM extraction request failed."
            )
        }

        let decodedResponse = try JSONDecoder().decode(ResponseEnvelope.self, from: data)

        guard let outputText = decodedResponse.outputText else {
            throw ExtractionError.missingOutputText
        }

        do {
            let payload = try JSONDecoder().decode(ExtractedSPARowsPayload.self, from: Data(outputText.utf8))
            return payload.rows.map { row in
                SPAEntry(
                    grade: row.grade.trimmingCharacters(in: .whitespacesAndNewlines),
                    nom: row.nom.trimmingCharacters(in: .whitespacesAndNewlines),
                    position: row.position.trimmingCharacters(in: .whitespacesAndNewlines),
                    observation: row.observation.trimmingCharacters(in: .whitespacesAndNewlines),
                    debut: row.debut.trimmingCharacters(in: .whitespacesAndNewlines),
                    fin: row.fin.trimmingCharacters(in: .whitespacesAndNewlines),
                    rawSourceText: row.rawSourceText
                )
            }
        } catch {
            throw ExtractionError.invalidJSONPayload
        }
    }
}

extension SPALLMExtractionService {
    enum ExtractionError: LocalizedError {
        case emptyInput
        case missingAPIKey
        case invalidResponse
        case missingOutputText
        case invalidJSONPayload
        case apiFailure(statusCode: Int, message: String)

        var errorDescription: String? {
            switch self {
            case .emptyInput:
                return "No OCR text was available for SPA extraction."
            case .missingAPIKey:
                return "OpenAI API key is missing. Add OPENAI_API_KEY to your run scheme environment."
            case .invalidResponse:
                return "The LLM extraction response was invalid."
            case .missingOutputText:
                return "The LLM did not return any structured text output."
            case .invalidJSONPayload:
                return "The LLM response could not be decoded into SPA rows."
            case .apiFailure(let statusCode, let message):
                return "OpenAI API error \(statusCode): \(message)"
            }
        }
    }
}

private extension SPALLMExtractionService {
    static let instructions = """
    You are an OCR extraction system for French SPA personnel sheets.

    Your job is to extract personnel rows from the scanned SPA and return structured data.

    STRICT COLUMN ORDER:
    Grade | Nom | Position | Observation | Début | Fin

    RULES:
    1. Extract only actual personnel rows.
    2. Ignore page title, section number, date header, totals, attendance stats, footer, and summary blocks.
    3. Each row represents one person only.
    4. A row begins with a valid Grade such as:
       LTN, SCH, SGT, CC1, CCH, CPL, 1CL, SDT
    5. Map fields exactly as follows:
       - Grade = military rank code
       - Nom = surname (usually uppercase)
       - Position = short code such as STGext, DIV, SAUT, ENC, FS, MCD, DRT, REC, PER
       - Observation = free text mission/training/comment
       - Début = first date in DD/MM/YYYY format
       - Fin = second date in DD/MM/YYYY format
    6. If a field is missing, return an empty string.
    7. Do not merge multiple people into one row.
    8. Do not place names or grades inside Observation.
    9. Do not place dates inside Observation.
    10. Preserve accents and punctuation.
    11. Reconstruct rows even if OCR text is split across multiple lines.

    VALIDATION STEP (MANDATORY):
    - Each row must contain exactly one Grade and one Nom.
    - Nom must not be a first name.
    - Prénom must not appear in final output.
    - Position must be a known short code, not a name.
    - Dates must be valid DD/MM/YYYY.
    - If multiple people appear in one row, split them.
    - If a row is ambiguous, split or correct it using best judgment.

    OUTPUT FORMAT:
    Return ONLY a JSON object with this shape:
    { "rows": [ ... ] }
    """
}

private extension SPALLMExtractionService {
    struct ResponseRequest: Encodable {
        let model: String
        let instructions: String
        let input: String
        let store: Bool
        let text: ResponseText
    }

    struct ResponseText: Encodable {
        let format: ResponseFormat
    }

    struct ResponseFormat: Encodable {
        let type: String
        let name: String
        let strict: Bool
        let schema: JSONSchema

        static let spaEntriesSchema = ResponseFormat(
            type: "json_schema",
            name: "spa_entries",
            strict: true,
            schema: .spaEntries
        )
    }

    struct JSONSchema: Encodable {
        let type: String
        let properties: [String: SchemaProperty]
        let required: [String]
        let additionalProperties: Bool

        static let spaEntries = JSONSchema(
            type: "object",
            properties: [
                "rows": .array(items: .spaEntryObject)
            ],
            required: ["rows"],
            additionalProperties: false
        )
    }

    struct SchemaProperty: Encodable {
        let type: String
        let items: SchemaItems?
        let properties: [String: SchemaProperty]?
        let required: [String]?
        let additionalProperties: Bool?

        static let string = SchemaProperty(
            type: "string",
            items: nil,
            properties: nil,
            required: nil,
            additionalProperties: nil
        )

        static let spaEntryObject = SchemaProperty(
            type: "object",
            items: nil,
            properties: [
                "Grade": .string,
                "Nom": .string,
                "Position": .string,
                "Observation": .string,
                "Début": .string,
                "Fin": .string
            ],
            required: ["Grade", "Nom", "Position", "Observation", "Début", "Fin"],
            additionalProperties: false
        )

        static func array(items: SchemaItems) -> SchemaProperty {
            SchemaProperty(
                type: "array",
                items: items,
                properties: nil,
                required: nil,
                additionalProperties: nil
            )
        }
    }

    struct SchemaItems: Encodable {
        let type: String
        let properties: [String: SchemaProperty]
        let required: [String]
        let additionalProperties: Bool

        static let spaEntryObject = SchemaItems(
            type: "object",
            properties: [
                "Grade": .string,
                "Nom": .string,
                "Position": .string,
                "Observation": .string,
                "Début": .string,
                "Fin": .string
            ],
            required: ["Grade", "Nom", "Position", "Observation", "Début", "Fin"],
            additionalProperties: false
        )
    }

    struct ResponseEnvelope: Decodable {
        let output: [OutputItem]

        var outputText: String? {
            output
                .first(where: { $0.type == "message" })?
                .content?
                .first(where: { $0.type == "output_text" })?
                .text
        }
    }

    struct OutputItem: Decodable {
        let type: String
        let content: [OutputContent]?
    }

    struct OutputContent: Decodable {
        let type: String
        let text: String?
    }

    struct ExtractedSPARow: Decodable {
        let grade: String
        let nom: String
        let position: String
        let observation: String
        let debut: String
        let fin: String

        var rawSourceText: String {
            [grade, nom, position, observation, debut, fin]
                .joined(separator: " | ")
        }

        enum CodingKeys: String, CodingKey {
            case grade = "Grade"
            case nom = "Nom"
            case position = "Position"
            case observation = "Observation"
            case debut = "Début"
            case fin = "Fin"
        }
    }

    struct ExtractedSPARowsPayload: Decodable {
        let rows: [ExtractedSPARow]
    }

    struct APIErrorEnvelope: Decodable {
        let error: APIError
    }

    struct APIError: Decodable {
        let message: String
    }

    struct LocalSecrets {
        let apiKey: String?
        let model: String?

        static func load(bundle: Bundle = .main) -> LocalSecrets? {
            guard let url = bundle.url(forResource: "LocalSecrets", withExtension: "plist"),
                  let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                return nil
            }

            let apiKey = (plist["OPENAI_API_KEY"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
            let model = (plist["OPENAI_MODEL"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty

            return LocalSecrets(apiKey: apiKey, model: model)
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
