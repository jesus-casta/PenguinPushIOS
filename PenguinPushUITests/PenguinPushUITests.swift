import XCTest

final class PenguinPushUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-ui-testing-save"]
        app.launch()
        app.launchArguments = ["--ui-testing"]
    }
    override func tearDownWithError() throws { XCUIDevice.shared.orientation = .portrait; app.terminate() }
    private func expectMoves(_ count: Int) {
        let counters = app.staticTexts["gameCounters"]
        let predicate = NSPredicate(format: "label BEGINSWITH %@", "\(count) pasos")
        expectation(for: predicate, evaluatedWith: counters)
        waitForExpectations(timeout: 5)
    }
    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testTapWalkAvoidsBoxesAndResumes() {
        XCTAssertTrue(app.buttons["Derecha"].waitForExistence(timeout: 10))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.544, dy: 0.393)).tap()
        expectMoves(0)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.854, dy: 0.393)).tap()
        expectMoves(5)
        XCTAssertTrue(app.staticTexts["gameCounters"].label.contains("0 empujes"))
        screenshot("igloos-tap-walk")
        app.terminate(); app.launch(); expectMoves(5)
        app.buttons["Deshacer"].tap(); expectMoves(4)
    }
    func testDirectStartupMovementAndResume() {
        XCTAssertTrue(app.buttons["Derecha"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.webViews.count, 0)
        XCTAssertFalse(app.staticTexts["¿Quién va a jugar?"].exists)
        expectMoves(0)
        app.buttons["Derecha"].tap(); expectMoves(1)
        screenshot("native-portrait")
        app.terminate(); app.launch(); expectMoves(1)
        XCTAssertFalse(app.staticTexts["¿Quién va a jugar?"].exists)
        app.buttons["Deshacer"].tap(); expectMoves(0)
        app.buttons["Ajustes"].tap()
        app.buttons["Nueva partida · elegir pingüino"].tap()
        XCTAssertTrue(app.staticTexts["¿Quién va a jugar?"].waitForExistence(timeout: 5))
        app.buttons["Pingüina"].tap()
        app.buttons["Empezar nueva partida"].tap()
        expectMoves(0)
        app.buttons["Derecha"].tap(); expectMoves(1)
        app.terminate(); app.launch(); expectMoves(1)
        screenshot("native-pink-restored")
    }
    func testAdventureUnlocksOneStageAtATime() {
        XCTAssertTrue(app.buttons["Derecha"].waitForExistence(timeout: 10))
        app.buttons["Ajustes"].tap()
        XCTAssertTrue(app.buttons["stage-0"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stage-0"].isEnabled)
        XCTAssertFalse(app.buttons["stage-1"].isEnabled)
        app.buttons["Listo"].tap()
        app.buttons["Derecha"].tap(); expectMoves(1)
        app.buttons["Derecha"].tap()
        XCTAssertTrue(app.buttons["Siguiente etapa"].waitForExistence(timeout: 5))
        screenshot("adventure-stage-complete")
        app.buttons["Siguiente etapa"].tap(); expectMoves(0)
        XCTAssertTrue(app.staticTexts["adventureProgress"].label.contains("ETAPA 2 DE 8"))
        app.buttons["Ajustes"].tap()
        XCTAssertTrue(app.buttons["stage-1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["stage-1"].isEnabled)
        XCTAssertFalse(app.buttons["stage-2"].isEnabled)
        app.buttons["Listo"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.staticTexts["adventureProgress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["adventureProgress"].label.contains("ETAPA 2 DE 8"))
    }
    func testLandscapeControlsAndSettings() {
        XCTAssertTrue(app.buttons["Derecha"].waitForExistence(timeout: 10))
        XCUIDevice.shared.orientation = .landscapeLeft
        let right = app.buttons["Derecha"]
        expectation(for: NSPredicate { element, _ in (element as? XCUIElement)?.isHittable == true }, evaluatedWith: right)
        waitForExpectations(timeout: 5)
        screenshot("native-landscape-settled")
        XCTAssertTrue(right.isHittable)
        XCTAssertTrue(app.buttons["Arriba"].isHittable)
        XCTAssertTrue(app.buttons["Abajo"].isHittable)
        XCTAssertTrue(app.buttons["Izquierda"].isHittable)
        screenshot("native-landscape-before-movement")
        app.buttons["Derecha"].tap(); expectMoves(1)
        screenshot("native-landscape")
        app.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        app.buttons["Listo"].tap()
        XCTAssertTrue(right.waitForExistence(timeout: 5))
    }
}
