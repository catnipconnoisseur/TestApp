import Foundation
import Vision

// MARK: - Scene Stability Configuration

/// Centralized empirical configuration for visual scene anchoring and conversational memory.
struct SceneStabilityConfiguration: Sendable {
    /// Visual divergence threshold (0.0 = identical, 1.0 = completely divergent).
    /// Above this threshold, a frame is considered a candidate for a new physical scene.
    static let divergenceThreshold: Float = 0.50
    
    /// Required sustained duration (in seconds) of divergence before confirming a scene change.
    /// Prevents momentary hand shakes, occlusions, or blur from prematurely resetting conversational memory.
    static let confirmationDuration: TimeInterval = 0.40
    
    /// Maximum inactivity timeout (in seconds) before an active scene conversation thread naturally expires.
    static let threadInactivityTimeout: TimeInterval = 300.0 // 5 minutes
    
    /// FeaturePrint embedding cosine distance threshold for visual sub-signal evaluation.
    static let featurePrintDistanceThreshold: Float = 0.45
}

// MARK: - Conversation Turn

/// A single question-and-answer exchange within a scene-anchored conversation thread.
struct ConversationTurn: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let question: String
    let answer: InterpretationResult
    let rawAIResponse: String
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        question: String,
        answer: InterpretationResult,
        rawAIResponse: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.question = question
        self.answer = answer
        self.rawAIResponse = rawAIResponse
    }
}

// MARK: - Scene Conversation Thread

/// Manages an active multi-turn conversation thread anchored to a specific physical scene.
struct SceneConversationThread: Identifiable, Equatable, Sendable {
    let id: UUID
    let anchorScene: AnalyzedSceneReference
    private(set) var turns: [ConversationTurn]
    let createdAt: Date
    private(set) var lastActiveAt: Date
    
    var turnCount: Int { turns.count }
    var latestAnswer: InterpretationResult? { turns.last?.answer }
    var latestQuestion: String? { turns.last?.question }
    var isMultiTurn: Bool { turns.count > 1 }
    
    init(
        id: UUID = UUID(),
        anchorScene: AnalyzedSceneReference,
        turns: [ConversationTurn] = [],
        createdAt: Date = Date(),
        lastActiveAt: Date = Date()
    ) {
        self.id = id
        self.anchorScene = anchorScene
        self.turns = turns
        self.createdAt = createdAt
        self.lastActiveAt = lastActiveAt
    }
    
    /// Appends a newly completed conversation turn and updates the activity timestamp.
    mutating func appendTurn(_ turn: ConversationTurn) {
        turns.append(turn)
        lastActiveAt = turn.timestamp
    }
    
    /// Determines whether the thread has expired due to prolonged inactivity.
    func isExpired(timeout: TimeInterval = SceneStabilityConfiguration.threadInactivityTimeout) -> Bool {
        Date().timeIntervalSince(lastActiveAt) > timeout
    }
}
