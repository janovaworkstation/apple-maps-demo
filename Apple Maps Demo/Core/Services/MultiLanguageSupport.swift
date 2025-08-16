import Foundation

// MARK: - MultiLanguageSupport

class MultiLanguageSupport {
    static let shared = MultiLanguageSupport()
    
    private let supportedLanguages: [SupportedLanguage]
    private let culturalContextProvider: CulturalContextProvider
    
    private init() {
        self.supportedLanguages = SupportedLanguage.allCases
        self.culturalContextProvider = CulturalContextProvider()
    }
    
    // MARK: - Public Interface
    
    func localizePrompt(
        template: PromptTemplate,
        for poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        
        let language = getSupportedLanguage(for: preferences.preferredLanguage)
        let culturalContext = culturalContextProvider.getCulturalContext(for: language, poi: poi)
        
        // Build localized prompt based on template and language
        let basePrompt = template.buildPrompt(poi: poi, context: context, preferences: preferences)
        return localizeContent(basePrompt, to: language, culturalContext: culturalContext)
    }
    
    func validateLanguageSupport(_ languageCode: String) -> Bool {
        return supportedLanguages.contains { $0.code == languageCode }
    }
    
    func getSupportedLanguages() -> [SupportedLanguage] {
        return supportedLanguages
    }
    
    func getOptimalVoiceForLanguage(_ languageCode: String) -> String {
        let language = getSupportedLanguage(for: languageCode)
        return language.preferredVoice
    }
    
    // MARK: - Private Methods
    
    private func getSupportedLanguage(for code: String) -> SupportedLanguage {
        return supportedLanguages.first { $0.code == code } ?? .english
    }
    
    private func localizeContent(
        _ content: String,
        to language: SupportedLanguage,
        culturalContext: CulturalContext
    ) -> String {
        
        var localizedContent = content
        
        // Apply language-specific modifications
        localizedContent = applyLanguageSpecificFormatting(localizedContent, language: language)
        
        // Inject cultural context
        localizedContent = injectCulturalContext(localizedContent, context: culturalContext)
        
        // Apply language-specific prompt enhancements
        localizedContent = enhancePromptForLanguage(localizedContent, language: language)
        
        return localizedContent
    }
    
    private func applyLanguageSpecificFormatting(_ content: String, language: SupportedLanguage) -> String {
        var formatted = content
        
        switch language {
        case .spanish:
            // Add cultural warmth and formality common in Spanish-speaking regions
            formatted = formatted.replacingOccurrences(of: "You'll notice", with: "Usted notará")
            formatted = formatted.replacingOccurrences(of: "Imagine", with: "Imagínese")
            
        case .french:
            // Add French cultural sophistication
            formatted = formatted.replacingOccurrences(of: "Welcome to", with: "Bienvenue à")
            formatted = formatted.replacingOccurrences(of: "Discover", with: "Découvrez")
            
        case .german:
            // Add German precision and thoroughness
            formatted = formatted.replacingOccurrences(of: "Notice the details", with: "Beachten Sie die Details")
            
        case .italian:
            // Add Italian passion and artistic appreciation
            formatted = formatted.replacingOccurrences(of: "Beautiful", with: "Bellissimo")
            
        case .japanese:
            // Add Japanese respect and mindfulness
            formatted = formatted.replacingOccurrences(of: "Please observe", with: "ご覧ください")
            
        case .chinese:
            // Add Chinese cultural reverence
            formatted = formatted.replacingOccurrences(of: "Ancient", with: "古老的")
            
        default:
            break // English and other languages use default formatting
        }
        
        return formatted
    }
    
    private func injectCulturalContext(_ content: String, context: CulturalContext) -> String {
        var enhanced = content
        
        // Add cultural greetings and expressions
        if let greeting = context.culturalGreeting {
            enhanced = "\(greeting) \(enhanced)"
        }
        
        // Add cultural context about the location
        if let culturalNote = context.localCulturalNote {
            enhanced = enhanced.replacingOccurrences(
                of: "Location Details:",
                with: "Location Details:\n\(culturalNote)\n"
            )
        }
        
        // Add culturally appropriate closing
        if let closing = context.culturalClosing {
            enhanced = "\(enhanced)\n\nCultural Note: \(closing)"
        }
        
        return enhanced
    }
    
    private func enhancePromptForLanguage(_ content: String, language: SupportedLanguage) -> String {
        var enhanced = content
        
        // Add language-specific instructions for the AI
        let languageInstructions = getLanguageSpecificInstructions(for: language)
        enhanced = "\(enhanced)\n\nLanguage-Specific Instructions:\n\(languageInstructions)"
        
        return enhanced
    }
    
    private func getLanguageSpecificInstructions(for language: SupportedLanguage) -> String {
        switch language {
        case .english:
            return """
            - Use clear, engaging American English
            - Include varied sentence structures for audio appeal
            - Use active voice and conversational tone
            """
            
        case .spanish:
            return """
            - Use warm, welcoming tone typical of Spanish-speaking tour guides
            - Include cultural references appropriate to Spanish-speaking tourists
            - Use formal "usted" for respect, informal "tú" for warmth as appropriate
            - Ensure content flows naturally when spoken in Spanish
            """
            
        case .french:
            return """
            - Use sophisticated, culturally refined French
            - Include artistic and historical appreciation common in French culture
            - Use appropriate French cultural references and expressions
            - Maintain elegant and intellectual tone
            """
            
        case .german:
            return """
            - Use precise, informative German with attention to detail
            - Include technical and historical accuracy valued in German culture
            - Use clear, well-structured sentences appropriate for audio
            - Include cultural context relevant to German-speaking visitors
            """
            
        case .italian:
            return """
            - Use passionate, expressive Italian with appreciation for art and beauty
            - Include cultural enthusiasm and artistic sensibility
            - Use warm, engaging tone with Italian cultural expressions
            - Emphasize visual and aesthetic aspects
            """
            
        case .japanese:
            return """
            - Use respectful, mindful Japanese with appropriate honorifics
            - Include cultural awareness and respect for place and history
            - Use patient, contemplative pacing suitable for Japanese listeners
            - Include concepts of harmony and cultural appreciation
            """
            
        case .chinese:
            return """
            - Use culturally sensitive Chinese with respect for tradition
            - Include historical context and cultural reverence
            - Use appropriate Chinese cultural concepts and values
            - Emphasize harmony between past and present
            """
            
        case .portuguese:
            return """
            - Use warm, melodic Portuguese with Brazilian or European variations as appropriate
            - Include cultural warmth and hospitality common in Portuguese-speaking cultures
            - Use engaging, storytelling approach valued in Portuguese culture
            """
            
        case .russian:
            return """
            - Use rich, expressive Russian with cultural depth
            - Include historical context and cultural pride
            - Use formal but warm tone appropriate for Russian cultural values
            """
            
        case .arabic:
            return """
            - Use respectful, culturally sensitive Arabic
            - Include appropriate cultural and religious sensitivity
            - Use formal Arabic suitable for diverse Arabic-speaking audiences
            - Respect cultural values and traditions
            """
        }
    }
}

// MARK: - Cultural Context Provider

class CulturalContextProvider {
    
    func getCulturalContext(for language: SupportedLanguage, poi: PointOfInterest) -> CulturalContext {
        
        let greeting = getCulturalGreeting(for: language)
        let localNote = getLocalCulturalNote(for: language, poi: poi)
        let closing = getCulturalClosing(for: language)
        
        return CulturalContext(
            language: language,
            culturalGreeting: greeting,
            localCulturalNote: localNote,
            culturalClosing: closing,
            timeFormat: getTimeFormat(for: language),
            dateFormat: getDateFormat(for: language)
        )
    }
    
    private func getCulturalGreeting(for language: SupportedLanguage) -> String? {
        switch language {
        case .spanish:
            return "¡Bienvenidos! Welcome to this special place."
        case .french:
            return "Bonjour et bienvenue! Welcome to this remarkable location."
        case .german:
            return "Guten Tag! Welcome to this historically significant site."
        case .italian:
            return "Benvenuti! Welcome to this beautiful place."
        case .japanese:
            return "いらっしゃいませ。Welcome to this honored location."
        case .chinese:
            return "欢迎! Welcome to this culturally significant place."
        default:
            return nil
        }
    }
    
    private func getLocalCulturalNote(for language: SupportedLanguage, poi: PointOfInterest) -> String? {
        // This would be enhanced with a database of cultural context for different regions/POIs
        switch language {
        case .spanish:
            return "This location holds special significance in the local Spanish-speaking community."
        case .french:
            return "This site represents important cultural heritage."
        case .german:
            return "This location demonstrates significant historical and architectural importance."
        default:
            return nil
        }
    }
    
    private func getCulturalClosing(for language: SupportedLanguage) -> String? {
        switch language {
        case .spanish:
            return "¡Que disfruten su visita! Enjoy your visit!"
        case .french:
            return "Profitez bien de votre visite!"
        case .german:
            return "Genießen Sie Ihren Besuch!"
        case .italian:
            return "Godetevi la vostra visita!"
        case .japanese:
            return "素晴らしい訪問をお楽しみください。"
        default:
            return nil
        }
    }
    
    private func getTimeFormat(for language: SupportedLanguage) -> String {
        switch language {
        case .english:
            return "12-hour"
        default:
            return "24-hour"
        }
    }
    
    private func getDateFormat(for language: SupportedLanguage) -> String {
        switch language {
        case .english:
            return "MM/dd/yyyy"
        case .german:
            return "dd.MM.yyyy"
        default:
            return "dd/MM/yyyy"
        }
    }
}

// MARK: - Supporting Types

enum SupportedLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case chinese = "zh"
    case russian = "ru"
    case arabic = "ar"
    
    var code: String {
        return self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .russian: return "Русский"
        case .arabic: return "العربية"
        }
    }
    
    var preferredVoice: String {
        switch self {
        case .english: return "alloy"
        case .spanish: return "nova"
        case .french: return "shimmer"
        case .german: return "echo"
        case .italian: return "fable"
        case .portuguese: return "nova"
        case .japanese: return "alloy"
        case .chinese: return "echo"
        case .russian: return "fable"
        case .arabic: return "shimmer"
        }
    }
    
    var isRTL: Bool {
        return self == .arabic
    }
}

struct CulturalContext {
    let language: SupportedLanguage
    let culturalGreeting: String?
    let localCulturalNote: String?
    let culturalClosing: String?
    let timeFormat: String
    let dateFormat: String
}