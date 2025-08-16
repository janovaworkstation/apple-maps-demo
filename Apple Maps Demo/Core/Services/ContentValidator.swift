import Foundation
import NaturalLanguage

// MARK: - ContentValidator

class ContentValidator {
    
    private let minDuration: TimeInterval = 45  // 45 seconds minimum
    private let maxDuration: TimeInterval = 120 // 2 minutes maximum
    private let wordsPerMinute: Double = 150    // Average speaking rate
    
    // Inappropriate content detection patterns
    private let inappropriatePatterns: [String] = [
        // Add patterns for content filtering - keeping family-friendly
        "inappropriate", "offensive", "controversial"
    ]
    
    // Quality indicators
    private let qualityIndicators = QualityIndicators()
    
    // MARK: - Public Validation Interface
    
    func validateContent(_ content: GeneratedContent, for poi: PointOfInterest) async throws -> ValidatedContent {
        
        let text = content.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic validation checks
        try validateTextLength(text)
        try validateContentAppropriate(text)
        try validateAudioFile(content.audioURL)
        try validateDuration(text)
        
        // Quality assessment
        let quality = await assessContentQuality(text, for: poi)
        
        // Structure validation
        let structure = validateContentStructure(text)
        
        // Language validation
        let language = detectAndValidateLanguage(text)
        
        return ValidatedContent(
            text: text,
            audioURL: content.audioURL,
            quality: quality,
            structure: structure,
            language: language,
            validatedAt: Date(),
            wordCount: countWords(text),
            estimatedDuration: estimateSpeechDuration(text)
        )
    }
    
    // MARK: - Validation Methods
    
    private func validateTextLength(_ text: String) throws {
        guard !text.isEmpty else {
            throw ContentValidationError.emptyContent
        }
        
        let wordCount = countWords(text)
        let minWords = Int(minDuration * wordsPerMinute / 60)
        let maxWords = Int(maxDuration * wordsPerMinute / 60)
        
        guard wordCount >= minWords else {
            throw ContentValidationError.contentTooShort(wordCount: wordCount, minimum: minWords)
        }
        
        guard wordCount <= maxWords else {
            throw ContentValidationError.contentTooLong(wordCount: wordCount, maximum: maxWords)
        }
    }
    
    private func validateContentAppropriate(_ text: String) throws {
        let lowercaseText = text.lowercased()
        
        for pattern in inappropriatePatterns {
            if lowercaseText.contains(pattern) {
                throw ContentValidationError.inappropriateContent(pattern: pattern)
            }
        }
        
        // Check for excessive repetition
        if hasExcessiveRepetition(text) {
            throw ContentValidationError.excessiveRepetition
        }
    }
    
    private func validateAudioFile(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ContentValidationError.audioFileNotFound
        }
        
        // Check file size (basic validation)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // Audio files should be at least 100KB for reasonable quality
            guard fileSize > 100_000 else {
                throw ContentValidationError.audioFileTooSmall
            }
        } catch {
            throw ContentValidationError.audioFileError(error.localizedDescription)
        }
    }
    
    private func validateDuration(_ text: String) throws {
        let estimatedDuration = estimateSpeechDuration(text)
        
        guard estimatedDuration >= minDuration else {
            throw ContentValidationError.estimatedDurationTooShort(estimatedDuration)
        }
        
        guard estimatedDuration <= maxDuration else {
            throw ContentValidationError.estimatedDurationTooLong(estimatedDuration)
        }
    }
    
    // MARK: - Quality Assessment
    
    private func assessContentQuality(_ text: String, for poi: PointOfInterest) async -> ContentQuality {
        var score = 0
        let maxScore = 20
        
        // Check for engaging opening (5 points)
        if hasEngagingOpening(text) { score += 5 }
        
        // Check for specific details (4 points)
        if hasSpecificDetails(text) { score += 4 }
        
        // Check for smooth transition ending (4 points)
        if hasSmoothTransition(text) { score += 4 }
        
        // Check for POI relevance (3 points)
        if isRelevantToPOI(text, poi: poi) { score += 3 }
        
        // Check for educational value (2 points)
        if hasEducationalValue(text) { score += 2 }
        
        // Check for conversational tone (2 points)
        if hasConversationalTone(text) { score += 2 }
        
        let percentage = Double(score) / Double(maxScore)
        
        switch percentage {
        case 0.85...: return .excellent
        case 0.70..<0.85: return .good
        case 0.50..<0.70: return .fair
        default: return .poor
        }
    }
    
    // MARK: - Content Structure Validation
    
    private func validateContentStructure(_ text: String) -> ContentStructure {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let hasOpening = sentences.count > 0 && isEngagingOpening(sentences[0])
        let hasBody = sentences.count > 2
        let hasClosing = sentences.count > 0 && isTransitionClosing(sentences.last ?? "")
        
        return ContentStructure(
            sentenceCount: sentences.count,
            hasEngagingOpening: hasOpening,
            hasInformativeBody: hasBody,
            hasTransitionClosing: hasClosing,
            averageSentenceLength: sentences.isEmpty ? 0 : sentences.map { $0.count }.reduce(0, +) / sentences.count
        )
    }
    
    // MARK: - Language Detection and Validation
    
    private func detectAndValidateLanguage(_ text: String) -> LanguageValidation {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        let detectedLanguage = recognizer.dominantLanguage?.rawValue ?? "unknown"
        let confidence = recognizer.languageHypotheses(withMaximum: 1).first?.value ?? 0.0
        
        return LanguageValidation(
            detectedLanguage: detectedLanguage,
            confidence: confidence,
            isHighConfidence: confidence > 0.8
        )
    }
    
    // MARK: - Helper Methods
    
    private func countWords(_ text: String) -> Int {
        return text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
    
    private func estimateSpeechDuration(_ text: String) -> TimeInterval {
        let wordCount = countWords(text)
        return (Double(wordCount) / wordsPerMinute) * 60
    }
    
    private func hasExcessiveRepetition(_ text: String) -> Bool {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let wordCounts = Dictionary(grouping: words) { $0 }.mapValues { $0.count }
        
        // Check if any word appears more than 10% of total words (excluding common words)
        let commonWords = Set(["the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with", "by", "is", "was", "are", "were", "this", "that", "these", "those"])
        
        for (word, count) in wordCounts {
            if !commonWords.contains(word) && count > words.count / 10 {
                return true
            }
        }
        return false
    }
    
    // MARK: - Quality Check Methods
    
    private func hasEngagingOpening(_ text: String) -> Bool {
        let openingPhrases = ["imagine", "picture", "welcome to", "step into", "discover", "explore", "look around"]
        let firstSentence = text.lowercased().prefix(100)
        return openingPhrases.contains { firstSentence.contains($0) }
    }
    
    private func isEngagingOpening(_ sentence: String) -> Bool {
        let engagingWords = ["imagine", "picture", "welcome", "discover", "explore", "step", "look"]
        return engagingWords.contains { sentence.lowercased().contains($0) }
    }
    
    private func hasSpecificDetails(_ text: String) -> Bool {
        // Check for dates, numbers, or specific names
        let datePattern = #"\b\d{4}\b|\b\d{1,2}th century\b"#
        let numberPattern = #"\b\d+\b"#
        
        let hasNumbers = text.range(of: numberPattern, options: .regularExpression) != nil
        let hasProperNouns = text.range(of: #"\b[A-Z][a-z]+\b"#, options: .regularExpression) != nil
        
        return hasNumbers && hasProperNouns
    }
    
    private func hasSmoothTransition(_ text: String) -> Bool {
        let transitionPhrases = ["next", "continue", "proceed", "move on", "head to", "let's go", "follow"]
        let lastSentence = String(text.suffix(150)).lowercased()
        return transitionPhrases.contains { lastSentence.contains($0) }
    }
    
    private func isTransitionClosing(_ sentence: String) -> Bool {
        let transitionWords = ["next", "continue", "proceed", "move", "head", "follow", "ready"]
        return transitionWords.contains { sentence.lowercased().contains($0) }
    }
    
    private func isRelevantToPOI(_ text: String, poi: PointOfInterest) -> Bool {
        let poiKeywords = [poi.name.lowercased(), poi.category.rawValue.lowercased()]
        let textLower = text.lowercased()
        
        return poiKeywords.contains { textLower.contains($0) }
    }
    
    private func hasEducationalValue(_ text: String) -> Bool {
        let educationalWords = ["history", "built", "designed", "created", "established", "founded", "discovered", "invented"]
        let textLower = text.lowercased()
        return educationalWords.contains { textLower.contains($0) }
    }
    
    private func hasConversationalTone(_ text: String) -> Bool {
        let conversationalWords = ["you", "your", "we", "us", "notice", "see", "hear", "feel"]
        let textLower = text.lowercased()
        let conversationalCount = conversationalWords.filter { textLower.contains($0) }.count
        return conversationalCount >= 2
    }
}

// MARK: - Supporting Types

struct ValidatedContent {
    let text: String
    let audioURL: URL
    let quality: ContentQuality
    let structure: ContentStructure
    let language: LanguageValidation
    let validatedAt: Date
    let wordCount: Int
    let estimatedDuration: TimeInterval
}

struct ContentStructure {
    let sentenceCount: Int
    let hasEngagingOpening: Bool
    let hasInformativeBody: Bool
    let hasTransitionClosing: Bool
    let averageSentenceLength: Int
    
    var isWellStructured: Bool {
        return hasEngagingOpening && hasInformativeBody && hasTransitionClosing && sentenceCount >= 3
    }
}

struct LanguageValidation {
    let detectedLanguage: String
    let confidence: Double
    let isHighConfidence: Bool
}

struct QualityIndicators {
    let engagingOpenings = ["imagine", "picture", "welcome to", "step into", "discover"]
    let transitionPhrases = ["next", "continue", "proceed", "move on", "head to"]
    let educationalWords = ["history", "built", "designed", "established", "founded"]
}

// MARK: - Error Types

enum ContentValidationError: LocalizedError {
    case emptyContent
    case contentTooShort(wordCount: Int, minimum: Int)
    case contentTooLong(wordCount: Int, maximum: Int)
    case inappropriateContent(pattern: String)
    case excessiveRepetition
    case audioFileNotFound
    case audioFileTooSmall
    case audioFileError(String)
    case estimatedDurationTooShort(TimeInterval)
    case estimatedDurationTooLong(TimeInterval)
    case qualityTooLow(ContentQuality)
    
    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "Generated content is empty"
        case .contentTooShort(let wordCount, let minimum):
            return "Content too short: \(wordCount) words (minimum: \(minimum))"
        case .contentTooLong(let wordCount, let maximum):
            return "Content too long: \(wordCount) words (maximum: \(maximum))"
        case .inappropriateContent(let pattern):
            return "Content contains inappropriate material: \(pattern)"
        case .excessiveRepetition:
            return "Content contains excessive word repetition"
        case .audioFileNotFound:
            return "Generated audio file not found"
        case .audioFileTooSmall:
            return "Generated audio file is too small"
        case .audioFileError(let details):
            return "Audio file error: \(details)"
        case .estimatedDurationTooShort(let duration):
            return "Estimated duration too short: \(Int(duration))s"
        case .estimatedDurationTooLong(let duration):
            return "Estimated duration too long: \(Int(duration))s"
        case .qualityTooLow(let quality):
            return "Content quality too low: \(quality.description)"
        }
    }
}