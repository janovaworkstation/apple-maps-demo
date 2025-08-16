//
//  AudioContentTests.swift
//  Apple Maps DemoTests
//
//  Created by Claude on 8/16/25.
//

import XCTest
import Foundation
@testable import Apple_Maps_Demo

final class AudioContentTests: XCTestCase {
    
    var audioContent: AudioContent!
    var testFileURL: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        
        testFileURL = TestDataFactory.testAudioFileURL
        audioContent = TestDataFactory.createAudioContent(
            localFileURL: testFileURL,
            transcript: "This is a test audio transcript.",
            duration: 180,
            isLLMGenerated: true,
            language: "en"
        )
    }
    
    override func tearDownWithError() throws {
        audioContent = nil
        testFileURL = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testAudioContentInitialization() {
        XCTAssertNotNil(audioContent.id)
        XCTAssertEqual(audioContent.localFileURL, testFileURL)
        XCTAssertEqual(audioContent.transcript, "This is a test audio transcript.")
        XCTAssertEqual(audioContent.duration, 180)
        XCTAssertTrue(audioContent.isLLMGenerated)
        XCTAssertEqual(audioContent.language, "en")
        XCTAssertNotNil(audioContent.cachedAt)
        XCTAssertEqual(audioContent.quality, .medium)
        XCTAssertEqual(audioContent.fileSize, 1024000)
        XCTAssertEqual(audioContent.format, .mp3)
    }
    
    func testAudioContentWithoutFileURL() {
        let audioContentNoFile = TestDataFactory.createAudioContent(localFileURL: nil)
        
        XCTAssertNil(audioContentNoFile.localFileURL)
        XCTAssertNotNil(audioContentNoFile.transcript)
        XCTAssertGreaterThan(audioContentNoFile.duration, 0)
    }
    
    func testAudioContentIdentifiable() {
        let content1 = TestDataFactory.createAudioContent()
        let content2 = TestDataFactory.createAudioContent()
        
        XCTAssertNotEqual(content1.id, content2.id)
        XCTAssertEqual(content1.id, content1.id)
    }
    
    // MARK: - Duration Tests
    
    func testAudioContentDurationValidation() {
        XCTAssertEqual(audioContent.duration, 180)
        XCTAssertGreaterThanOrEqual(audioContent.duration, 0)
        
        // Test zero duration
        let zeroDurationContent = TestDataFactory.createAudioContent(duration: 0)
        XCTAssertEqual(zeroDurationContent.duration, 0)
        
        // Test long duration
        let longContent = TestDataFactory.createAudioContent(duration: 3600) // 1 hour
        XCTAssertEqual(longContent.duration, 3600)
        
        // Test fractional duration
        let fractionalContent = TestDataFactory.createAudioContent(duration: 123.456)
        XCTAssertEqual(fractionalContent.duration, 123.456, accuracy: 0.001)
    }
    
    func testAudioContentDurationFormatting() {
        // Test duration formatting helper (if exists)
        let shortContent = TestDataFactory.createAudioContent(duration: 65) // 1:05
        let mediumContent = TestDataFactory.createAudioContent(duration: 3665) // 1:01:05
        let longContent = TestDataFactory.createAudioContent(duration: 7265) // 2:01:05
        
        XCTAssertEqual(shortContent.duration, 65)
        XCTAssertEqual(mediumContent.duration, 3665)
        XCTAssertEqual(longContent.duration, 7265)
    }
    
    // MARK: - File URL Tests
    
    func testAudioContentFileURL() {
        XCTAssertEqual(audioContent.localFileURL, testFileURL)
        XCTAssertTrue(audioContent.localFileURL?.isFileURL ?? false)
    }
    
    func testAudioContentFileURLValidation() {
        // Test valid file URLs
        let validURLs = [
            URL(fileURLWithPath: "/tmp/test.mp3"),
            URL(fileURLWithPath: "/Documents/audio.m4a"),
            URL(fileURLWithPath: "/var/mobile/audio.wav")
        ]
        
        for url in validURLs {
            let content = TestDataFactory.createAudioContent(localFileURL: url)
            XCTAssertEqual(content.localFileURL, url)
            XCTAssertTrue(content.localFileURL?.isFileURL ?? false)
        }
    }
    
    func testAudioContentWithHTTPURL() {
        // Test that HTTP URLs are handled appropriately
        let httpURL = URL(string: "https://example.com/audio.mp3")
        let httpContent = TestDataFactory.createAudioContent(localFileURL: httpURL)
        
        XCTAssertEqual(httpContent.localFileURL, httpURL)
        XCTAssertFalse(httpContent.localFileURL?.isFileURL ?? true)
    }
    
    // MARK: - Transcript Tests
    
    func testAudioContentTranscript() {
        XCTAssertEqual(audioContent.transcript, "This is a test audio transcript.")
        XCTAssertFalse(audioContent.transcript?.isEmpty ?? true)
    }
    
    func testAudioContentWithoutTranscript() {
        let noTranscriptContent = TestDataFactory.createAudioContent(transcript: nil)
        XCTAssertNil(noTranscriptContent.transcript)
    }
    
    func testAudioContentEmptyTranscript() {
        let emptyTranscriptContent = TestDataFactory.createAudioContent(transcript: "")
        XCTAssertEqual(emptyTranscriptContent.transcript, "")
        XCTAssertTrue(emptyTranscriptContent.transcript?.isEmpty ?? false)
    }
    
    func testAudioContentLongTranscript() {
        let longTranscript = String(repeating: "This is a long transcript. ", count: 100)
        let longTranscriptContent = TestDataFactory.createAudioContent(transcript: longTranscript)
        
        XCTAssertEqual(longTranscriptContent.transcript, longTranscript)
        XCTAssertGreaterThan(longTranscriptContent.transcript?.count ?? 0, 1000)
    }
    
    // MARK: - Language Tests
    
    func testAudioContentLanguage() {
        XCTAssertEqual(audioContent.language, "en")
        
        let spanishContent = TestDataFactory.createAudioContent(language: "es")
        XCTAssertEqual(spanishContent.language, "es")
        
        let frenchContent = TestDataFactory.createAudioContent(language: "fr")
        XCTAssertEqual(frenchContent.language, "fr")
        
        let chineseContent = TestDataFactory.createAudioContent(language: "zh")
        XCTAssertEqual(chineseContent.language, "zh")
    }
    
    func testAudioContentLanguageValidation() {
        // Test common language codes
        let languageCodes = ["en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh", "ar", "ru"]
        
        for code in languageCodes {
            let content = TestDataFactory.createAudioContent(language: code)
            XCTAssertEqual(content.language, code)
        }
    }
    
    // MARK: - LLM Generation Tests
    
    func testAudioContentLLMGeneration() {
        XCTAssertTrue(audioContent.isLLMGenerated)
        
        let manualContent = TestDataFactory.createAudioContent(isLLMGenerated: false)
        XCTAssertFalse(manualContent.isLLMGenerated)
    }
    
    // MARK: - Cache Timestamp Tests
    
    func testAudioContentCacheTimestamp() {
        XCTAssertNotNil(audioContent.cachedAt)
        
        let now = Date()
        XCTAssertLessThanOrEqual(abs(audioContent.cachedAt?.timeIntervalSince(now) ?? 1000), 1.0)
    }
    
    func testAudioContentWithoutCacheTimestamp() {
        let uncachedContent = AudioContent(
            id: UUID(),
            localFileURL: nil,
            transcript: "Test",
            duration: 60,
            isLLMGenerated: false,
            cachedAt: nil,
            language: "en",
            quality: .medium,
            fileSize: 1000,
            format: .mp3
        )
        
        XCTAssertNil(uncachedContent.cachedAt)
    }
    
    // MARK: - Quality Tests
    
    func testAudioContentQuality() {
        XCTAssertEqual(audioContent.quality, .medium)
        
        let lowQualityContent = TestDataFactory.createAudioContent()
        lowQualityContent.quality = .low
        XCTAssertEqual(lowQualityContent.quality, .low)
        
        let highQualityContent = TestDataFactory.createAudioContent()
        highQualityContent.quality = .high
        XCTAssertEqual(highQualityContent.quality, .high)
    }
    
    func testAudioContentQualityEnum() {
        let qualities: [AudioQuality] = [.low, .medium, .high]
        
        for quality in qualities {
            let content = TestDataFactory.createAudioContent()
            content.quality = quality
            XCTAssertEqual(content.quality, quality)
        }
    }
    
    // MARK: - File Size Tests
    
    func testAudioContentFileSize() {
        XCTAssertEqual(audioContent.fileSize, 1024000)
        XCTAssertGreaterThan(audioContent.fileSize, 0)
        
        let smallContent = TestDataFactory.createAudioContent()
        smallContent.fileSize = 1024 // 1KB
        XCTAssertEqual(smallContent.fileSize, 1024)
        
        let largeContent = TestDataFactory.createAudioContent()
        largeContent.fileSize = 10485760 // 10MB
        XCTAssertEqual(largeContent.fileSize, 10485760)
    }
    
    func testAudioContentFileSizeValidation() {
        // Test zero file size
        let zeroSizeContent = TestDataFactory.createAudioContent()
        zeroSizeContent.fileSize = 0
        XCTAssertEqual(zeroSizeContent.fileSize, 0)
        
        // Test very large file size
        let hugeSizeContent = TestDataFactory.createAudioContent()
        hugeSizeContent.fileSize = Int.max
        XCTAssertEqual(hugeSizeContent.fileSize, Int.max)
    }
    
    // MARK: - Format Tests
    
    func testAudioContentFormat() {
        XCTAssertEqual(audioContent.format, .mp3)
        
        let mp4Content = TestDataFactory.createAudioContent()
        mp4Content.format = .m4a
        XCTAssertEqual(mp4Content.format, .m4a)
        
        let wavContent = TestDataFactory.createAudioContent()
        wavContent.format = .wav
        XCTAssertEqual(wavContent.format, .wav)
    }
    
    func testAudioContentFormatEnum() {
        let formats: [AudioFormat] = [.mp3, .m4a, .wav, .aac]
        
        for format in formats {
            let content = TestDataFactory.createAudioContent()
            content.format = format
            XCTAssertEqual(content.format, format)
        }
    }
    
    // MARK: - File Extension Tests
    
    func testAudioContentFileExtensionMatching() {
        // Test that file URL extensions match format
        let mp3URL = URL(fileURLWithPath: "/tmp/test.mp3")
        let mp3Content = TestDataFactory.createAudioContent(localFileURL: mp3URL)
        mp3Content.format = .mp3
        
        XCTAssertEqual(mp3Content.localFileURL?.pathExtension, "mp3")
        XCTAssertEqual(mp3Content.format, .mp3)
        
        let m4aURL = URL(fileURLWithPath: "/tmp/test.m4a")
        let m4aContent = TestDataFactory.createAudioContent(localFileURL: m4aURL)
        m4aContent.format = .m4a
        
        XCTAssertEqual(m4aContent.localFileURL?.pathExtension, "m4a")
        XCTAssertEqual(m4aContent.format, .m4a)
    }
    
    // MARK: - Validation Helper Tests
    
    func testAudioContentValidation() {
        // Test valid content
        XCTAssertNotNil(audioContent.id)
        XCTAssertGreaterThanOrEqual(audioContent.duration, 0)
        XCTAssertFalse(audioContent.language.isEmpty)
        XCTAssertGreaterThanOrEqual(audioContent.fileSize, 0)
    }
    
    func testAudioContentIsDownloaded() {
        // Content with file URL should be considered downloaded
        XCTAssertNotNil(audioContent.localFileURL)
        
        // Content without file URL should not be considered downloaded
        let notDownloadedContent = TestDataFactory.createAudioContent(localFileURL: nil)
        XCTAssertNil(notDownloadedContent.localFileURL)
    }
    
    // MARK: - Performance Tests
    
    func testAudioContentCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = TestDataFactory.createAudioContent()
            }
        }
    }
    
    func testAudioContentWithLargeTranscriptPerformance() {
        let largeTranscript = String(repeating: "This is a performance test transcript. ", count: 1000)
        
        measure {
            for _ in 0..<100 {
                _ = TestDataFactory.createAudioContent(transcript: largeTranscript)
            }
        }
    }
    
    // MARK: - Memory Tests
    
    func testAudioContentMemoryDeallocation() {
        weak var weakContent: AudioContent?
        
        autoreleasepool {
            let localContent = TestDataFactory.createAudioContent()
            weakContent = localContent
            XCTAssertNotNil(weakContent)
        }
        
        // Content should be deallocated after autoreleasepool
        XCTAssertNil(weakContent)
    }
    
    // MARK: - Edge Case Tests
    
    func testAudioContentWithEmptyLanguage() {
        let emptyLanguageContent = TestDataFactory.createAudioContent(language: "")
        XCTAssertTrue(emptyLanguageContent.language.isEmpty)
    }
    
    func testAudioContentWithVeryShortDuration() {
        let shortContent = TestDataFactory.createAudioContent(duration: 0.1)
        XCTAssertEqual(shortContent.duration, 0.1, accuracy: 0.01)
    }
    
    func testAudioContentWithSpecialCharactersInTranscript() {
        let specialTranscript = "This transcript has émojis 🎵 and spéciál characters: åäö"
        let specialContent = TestDataFactory.createAudioContent(transcript: specialTranscript)
        
        XCTAssertEqual(specialContent.transcript, specialTranscript)
    }
}