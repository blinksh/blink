import XCTest
@testable import Blink

class AutoThemeToggleTests: XCTestCase {
  
  override func setUp() {
    super.setUp()
    BLKDefaults.loadDefaults()
  }
  
  override func tearDown() {
    BLKDefaults.setAutoThemeToggleEnabled(false)
    BLKDefaults.setLightThemeName("Default")
    BLKDefaults.setDarkThemeName("Default")
    BLKDefaults.saveDefaults()
    super.tearDown()
  }
  
  func testAutoThemeToggleDefaults() {
    XCTAssertFalse(BLKDefaults.isAutoThemeToggleEnabled())
    XCTAssertEqual(BLKDefaults.selectedLightThemeName(), "Default")
    XCTAssertEqual(BLKDefaults.selectedDarkThemeName(), "Default")
  }
  
  func testEnablingAutoThemeToggle() {
    BLKDefaults.setAutoThemeToggleEnabled(true)
    XCTAssertTrue(BLKDefaults.isAutoThemeToggleEnabled())
  }
  
  func testSettingLightAndDarkThemes() {
    BLKDefaults.setLightThemeName("Light")
    BLKDefaults.setDarkThemeName("Dark")
    
    XCTAssertEqual(BLKDefaults.selectedLightThemeName(), "Light")
    XCTAssertEqual(BLKDefaults.selectedDarkThemeName(), "Dark")
  }
  
  func testCurrentThemeNameForAppearanceWithAutoToggleDisabled() {
    BLKDefaults.setAutoThemeToggleEnabled(false)
    BLKDefaults.setThemeName("Custom")
    
    let currentTheme = BLKDefaults.currentThemeNameForAppearance()
    XCTAssertEqual(currentTheme, "Custom")
  }
  
  func testThemeApplicationPostsNotification() {
    let expectation = self.expectation(forNotification: NSNotification.Name(rawValue: BKAppearanceChanged), object: nil, handler: nil)
    
    BLKDefaults.applyCurrentTheme()
    
    waitForExpectations(timeout: 1.0, handler: nil)
  }
}
