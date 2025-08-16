import Foundation

// MARK: - PromptTemplate Protocol

protocol PromptTemplate {
    var type: PromptTemplateType { get }
    var systemMessage: String { get }
    
    func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String
}

// MARK: - Base Template Implementation

class BasePromptTemplate: PromptTemplate {
    let type: PromptTemplateType
    
    init(type: PromptTemplateType) {
        self.type = type
    }
    
    var systemMessage: String {
        """
        You are an expert tour guide providing engaging, informative audio content for location-based tours. 
        Your responses should be conversational, educational, and perfectly timed for audio consumption.
        Always maintain an enthusiastic but professional tone that makes locations come alive for visitors.
        """
    }
    
    func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        fatalError("Subclasses must implement buildPrompt")
    }
    
    // MARK: - Common Prompt Components
    
    func buildBaseContext(poi: PointOfInterest, context: TourContext, preferences: UserPreferences) -> String {
        """
        Context:
        - Tour: \(context.tourName)
        - Location: \(poi.name)
        - Previous stops: \(context.visitedPOIs.joined(separator: ", "))
        - Tour progress: \(context.elapsedTime) minutes elapsed
        - Language: \(preferences.preferredLanguage)
        - Voice style: \(preferences.voiceType.rawValue)
        - User's \(context.visitedPOIs.count.ordinal) stop on this tour
        """
    }
    
    func buildRequirements(targetDuration: String = "60-90 seconds") -> String {
        """
        Requirements:
        - Duration: \(targetDuration) when spoken at normal pace
        - Tone: Conversational and engaging
        - Structure: Hook → Information → Transition
        - Include fascinating details that most visitors wouldn't know
        - End with a smooth transition encouraging movement to the next location
        - Be specific and vivid in descriptions
        """
    }
}

// MARK: - Historical Template

class HistoricalPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .historical)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create compelling historical narration for "\(poi.name)".
        
        Focus Areas:
        - Historical significance and timeline
        - Key historical figures associated with this location
        - Stories and events that happened here
        - How this place influenced the surrounding area
        - Historical context within the broader region
        
        Location Details:
        \(poi.poiDescription)
        
        \(buildRequirements())
        
        Style Notes:
        - Tell stories, don't just list facts
        - Use "imagine" and "picture this" to create vivid scenes
        - Connect past events to what visitors can see today
        - Include specific dates and names when relevant
        """
    }
}

// MARK: - Cultural Template

class CulturalPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .cultural)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create engaging cultural narrative for "\(poi.name)".
        
        Focus Areas:
        - Cultural significance and traditions
        - Artistic, literary, or musical connections
        - Local customs and practices
        - Cultural evolution over time
        - Notable cultural figures or movements
        - How this place represents the local culture
        
        Location Details:
        \(poi.poiDescription)
        
        \(buildRequirements())
        
        Style Notes:
        - Celebrate the richness of local culture
        - Explain cultural practices in accessible terms
        - Share interesting cultural anecdotes
        - Connect cultural elements to modern life
        - Be respectful and inclusive in language
        """
    }
}

// MARK: - Culinary Template

class CulinaryPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .culinary)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create appetizing culinary narrative for "\(poi.name)".
        
        Focus Areas:
        - Signature dishes and local specialties
        - Culinary history and traditions
        - Ingredients sourced from the region
        - Cooking techniques and preparation methods
        - Food culture and dining customs
        - Chef stories or restaurant history
        
        Location Details:
        \(poi.poiDescription)
        
        \(buildRequirements())
        
        Style Notes:
        - Make food descriptions mouth-watering
        - Explain the "why" behind culinary traditions
        - Include sensory details (aromas, textures, flavors)
        - Share food-related cultural insights
        - Mention what makes this place special for food lovers
        """
    }
}

// MARK: - Natural Template

class NaturalPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .natural)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create immersive natural narrative for "\(poi.name)".
        
        Focus Areas:
        - Natural features and geological formation
        - Flora and fauna specific to this area
        - Seasonal changes and natural cycles
        - Ecological significance and conservation
        - Natural phenomena visitors might observe
        - Relationship between nature and human activity
        
        Location Details:
        \(poi.poiDescription)
        
        \(buildRequirements())
        
        Style Notes:
        - Paint vivid pictures of natural beauty
        - Explain natural processes in accessible terms
        - Encourage observation and mindfulness
        - Share fascinating natural facts
        - Connect visitors emotionally to the environment
        """
    }
}

// MARK: - Architectural Template

class ArchitecturalPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .architectural)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create fascinating architectural narrative for "\(poi.name)".
        
        Focus Areas:
        - Architectural style and design elements
        - Construction techniques and materials
        - Architect and design team background
        - Historical context of the building period
        - Functional aspects and intended use
        - Architectural innovations or unique features
        
        Location Details:
        \(poi.poiDescription)
        
        \(buildRequirements())
        
        Style Notes:
        - Help visitors "read" the building's visual language
        - Explain design choices and their significance
        - Point out details visitors might miss
        - Connect architecture to broader historical movements
        - Make technical concepts accessible to general audiences
        """
    }
}

// MARK: - Personalized Template

class PersonalizedPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .personalized)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create personalized narrative for "\(poi.name)" building on the visitor's tour journey.
        
        Focus Areas:
        - Connect this stop to previous locations visited
        - Reference the visitor's evolving tour experience
        - Highlight patterns or themes emerging in the tour
        - Personalize based on the time spent touring
        - Create narrative continuity with previous stops
        - Build anticipation for upcoming locations
        
        Location Details:
        \(poi.poiDescription)
        
        Previous Tour Experience:
        - Visited: \(context.visitedPOIs.joined(separator: ", "))
        - Tour duration so far: \(context.elapsedTime) minutes
        
        \(buildRequirements())
        
        Style Notes:
        - Reference specific previous stops when relevant
        - Acknowledge the visitor's journey and curiosity
        - Create a sense of discovery and progression
        - Use phrases like "Now that you've seen..." or "Building on what you experienced at..."
        - Make the visitor feel like they're getting a truly customized experience
        """
    }
}

// MARK: - General Template

class GeneralPromptTemplate: BasePromptTemplate {
    init() {
        super.init(type: .general)
    }
    
    override func buildPrompt(
        poi: PointOfInterest,
        context: TourContext,
        preferences: UserPreferences
    ) -> String {
        """
        \(buildBaseContext(poi: poi, context: context, preferences: preferences))
        
        Create engaging general narrative for "\(poi.name)".
        
        Focus Areas:
        - Most interesting and unique aspects of this location
        - What makes this place special or noteworthy
        - Interesting stories or facts visitors should know
        - Visual elements worth pointing out
        - Connection to the local community or region
        - Why this location was included in the tour
        
        Location Details:
        \(poi.poiDescription)
        
        \(buildRequirements())
        
        Style Notes:
        - Find the most compelling angle for this location
        - Balance education with entertainment
        - Include surprising or little-known facts
        - Help visitors appreciate what they're seeing
        - Create enthusiasm for exploration
        """
    }
}

// MARK: - Helper Extensions

extension Int {
    var ordinal: String {
        switch self {
        case 1: return "first"
        case 2: return "second"
        case 3: return "third"
        case 4: return "fourth"
        case 5: return "fifth"
        default: return "\(self)th"
        }
    }
}