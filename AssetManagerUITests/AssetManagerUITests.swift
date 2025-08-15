//
//  AssetManagerUITests.swift
//  AssetManagerUITests
//
//  Created by yimin.cao on 2025/8/15.
//

import XCTest

final class AssetManagerUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launchArguments.append("-uiTestAddSampleData")
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

final class AssetRowSwipeActionsTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSwipeRowShowsSellAndDelete() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-uiTestAddSampleData")
        app.launch()

        // 定位第一个资产行（根据我们设置的标识符前缀）
        // 为简化，直接查找任何包含前缀的元素
        let firstRow = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'AssetRow_'")).firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "首个资产行未出现")

        // 右滑
        firstRow.swipeLeft()

        // 断言卖出和删除按钮出现
        let sellButton = app.buttons["sell_button"]
        let deleteButton = app.buttons["delete_button"]
        XCTAssertTrue(sellButton.waitForExistence(timeout: 2), "未出现卖出按钮")
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 2), "未出现删除按钮")
    }
}
