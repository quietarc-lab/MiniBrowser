import XCTest
@testable import MiniBrowser

final class RuntimeUserAgentGeneratorTests: XCTestCase {
    func testGeneratedCandidateUsesCuratedMobileTemplate() {
        let generator = RuntimeUserAgentGenerator(indexSource: { _ in 0 })

        let generated = generator.generate(isRestricted: { _ in false })

        XCTAssertNotNil(generated)
        XCTAssertTrue(RuntimeUserAgentGenerator.isValid(generated!))
        XCTAssertEqual(generated?.family, "Safari")
        XCTAssertEqual(generated?.device, "iPhone")
    }

    func testRestrictedCandidateIsSkippedAndGenerationStopsAfterBoundedAttempts() {
        let generator = RuntimeUserAgentGenerator(indexSource: { _ in 0 })
        let generated = generator.generate(isRestricted: { _ in true })

        XCTAssertNil(generated)
        XCTAssertEqual(RuntimeUserAgentGenerator.maximumAttempts, 32)
    }

    func testIndexSourceIsNormalized() {
        let generator = RuntimeUserAgentGenerator(indexSource: { _ in -1 })

        let generated = generator.generate(isRestricted: { _ in false })

        XCTAssertNotNil(generated)
        XCTAssertTrue(RuntimeUserAgentGenerator.isValid(generated!))
    }

    func testGeneratorSelectsAnIndependentCuratedOSVariant() {
        let generator = RuntimeUserAgentGenerator(indexSource: { _ in 50 })

        let generated = generator.generate(isRestricted: { _ in false })

        XCTAssertEqual(generated?.device, "iPhone")
        XCTAssertEqual(generated?.osVersion, "18_6")
        XCTAssertTrue(RuntimeUserAgentGenerator.isValid(generated!))
    }
}
