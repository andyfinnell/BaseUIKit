import BaseKit
import CoreText
import Testing

@testable import BaseUIKit

struct FontResolverTests {
    // MARK: - Family fallback

    @Test func serifGenericFamilyResolvesToTimesFamily() async throws {
        let request = FontRequest(families: ["serif"], pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(
            resolved.postScriptName.contains("Times"),
            "serif should resolve via Times family; got \(resolved.postScriptName)")
    }

    @Test func sansSerifGenericFamilyResolvesToHelveticaFamily() async throws {
        let request = FontRequest(families: ["sans-serif"], pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(
            resolved.postScriptName.contains("Helvetica"),
            "sans-serif should resolve via Helvetica family; got \(resolved.postScriptName)")
    }

    @Test func missingFamilyFallsBackToNextInList() async throws {
        let request = FontRequest(
            families: ["NonExistentFont123", "Courier"], pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(resolved.postScriptName.contains("Courier"))
    }

    @Test func missingFamilyFallsBackToTimesByDefault() async throws {
        let request = FontRequest(families: ["NonExistentFont123"], pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(!resolved.postScriptName.isEmpty)
    }

    // MARK: - Descriptor traits

    @Test func smallCapsRequestAttachesLowerCaseFeatureSetting() async throws {
        let request = FontRequest(
            families: ["Helvetica"], smallCaps: true, pointSize: 16)
        let descriptor = FontResolver.test_fontDescriptor(for: request)
        let features =
            CTFontDescriptorCopyAttribute(descriptor, kCTFontFeatureSettingsAttribute)
            as? [[String: Any]]
        let hasLowerCaseSmallCaps =
            features?.contains { feature in
                let typeID = feature[kCTFontFeatureTypeIdentifierKey as String] as? Int
                let selectorID = feature[kCTFontFeatureSelectorIdentifierKey as String] as? Int
                return typeID == kLowerCaseType
                    && selectorID == kLowerCaseSmallCapsSelector
            } ?? false
        #expect(
            hasLowerCaseSmallCaps,
            "smallCaps=true should attach LowerCase/SmallCaps feature setting")
    }

    @Test func notSmallCapsRequestAttachesNoFeatureSetting() async throws {
        let request = FontRequest(
            families: ["Helvetica"], smallCaps: false, pointSize: 16)
        let descriptor = FontResolver.test_fontDescriptor(for: request)
        let features =
            CTFontDescriptorCopyAttribute(descriptor, kCTFontFeatureSettingsAttribute)
            as? [[String: Any]]
        #expect(
            features == nil || features?.isEmpty == true,
            "Default request should not attach a feature settings dict")
    }

    @Test func widthTraitFlowsIntoDescriptorTraits() async throws {
        let request = FontRequest(
            families: ["Helvetica"], widthTrait: -0.5, pointSize: 16)
        let descriptor = FontResolver.test_fontDescriptor(for: request)
        let traits =
            CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute)
            as? [String: Any]
        let width = traits?[kCTFontWidthTrait as String] as? CGFloat
        #expect(width == -0.5)
    }

    @Test func italicFlagFlowsIntoSymbolicTraits() async throws {
        let request = FontRequest(
            families: ["Helvetica"], italic: true, pointSize: 16)
        let descriptor = FontResolver.test_fontDescriptor(for: request)
        let traits =
            CTFontDescriptorCopyAttribute(descriptor, kCTFontTraitsAttribute)
            as? [String: Any]
        let symbolic = traits?[kCTFontSymbolicTrait as String] as? UInt32 ?? 0
        let italicBit = CTFontSymbolicTraits.traitItalic.rawValue
        #expect(symbolic & italicBit == italicBit, "italic=true should set the italic bit")
    }

    // MARK: - Size adjust

    @Test func sizeAdjustScalesPointSize() async throws {
        // Helvetica at 16pt has x-height ~7.5pt (ratio ~0.47). Requesting
        // aspect 0.6 should grow the rendered size to ~20.4pt.
        let request = FontRequest(
            families: ["Helvetica"], sizeAdjustAspect: 0.6, pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(
            resolved.pointSize > 16.0,
            "aspect=0.6 should grow Helvetica from its ~0.47; got \(resolved.pointSize)")
    }

    @Test func noSizeAdjustLeavesPointSizeAlone() async throws {
        let request = FontRequest(families: ["Helvetica"], pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(resolved.pointSize == 16.0)
    }

    // MARK: - Metric accessors

    @Test func resolvedFontExposesNonZeroMetrics() async throws {
        let request = FontRequest(families: ["Helvetica"], pointSize: 16)
        let resolved = FontResolver.resolve(request)
        #expect(resolved.ascent > 0)
        #expect(resolved.descent > 0)
        #expect(resolved.xHeight > 0)
        #expect(resolved.capHeight > 0)
        #expect(resolved.naturalLineHeight > resolved.ascent)
    }

    // MARK: - Candidate expansion

    @Test func serifGenericExpandsToTimesCandidates() async throws {
        let candidates = FontResolver.candidates(forFamily: "serif")
        #expect(candidates == ["Times New Roman", "Times"])
    }

    @Test func unknownFamilyExpandsToItself() async throws {
        let candidates = FontResolver.candidates(forFamily: "Helvetica")
        #expect(candidates == ["Helvetica"])
    }

    @Test func systemUIIsRecognized() async throws {
        #expect(FontResolver.isSystemUIFamily("system-ui"))
        #expect(FontResolver.isSystemUIFamily("ui-sans-serif"))
        #expect(!FontResolver.isSystemUIFamily("Helvetica"))
    }
}
