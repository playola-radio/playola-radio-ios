//
//  InvitationCodePageTests.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 8/18/25.
//

import Dependencies
import Sharing
import XCTest

@testable import PlayolaRadio

@MainActor
final class InvitationCodePageTests: XCTestCase {
  func testInit_SetsInitialValues() async {
    let model = InvitationCodePageModel()

    XCTAssertEqual(model.invitationCode, "")
    XCTAssertNil(model.errorMessage)
    XCTAssertEqual(model.mode, .invitationCodeInput)
  }
  
  func testSignInButtonTapped_EmptyCode_ShowsErrorMessage() async {
    let model = InvitationCodePageModel()
    model.invitationCode = ""
    
    await model.signInButtonTapped()
    
    XCTAssertEqual(model.errorMessage, "Please enter an invitation code")
  }
  
  func testSignInButtonTapped_ValidCode_ClearsErrorAndCallsDismiss() async {
    var dismissCalled = false
    
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "VALID123")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }
    
    model.invitationCode = "VALID123"
    model.errorMessage = "Previous error"
    model.onDismiss = { dismissCalled = true }
    
    await model.signInButtonTapped()
    
    XCTAssertNil(model.errorMessage)
    XCTAssertTrue(dismissCalled)
  }
  
  func testSignInButtonTapped_InvalidCode_ShowsServerErrorMessage() async {
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "INVALID123")
        throw InvitationCodeError.invalidCode("Invitation code has expired")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }
    
    model.invitationCode = "INVALID123"
    
    await model.signInButtonTapped()
    
    XCTAssertEqual(model.errorMessage, "Invitation code has expired")
  }
  
  func testSignInButtonTapped_UnexpectedError_ShowsGenericErrorMessage() async {
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "ERROR123")
        throw APIError.dataNotValid
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }
    
    model.invitationCode = "ERROR123"
    
    await model.signInButtonTapped()
    
    XCTAssertEqual(model.errorMessage, "An unexpected error occurred. Please try again.")
  }
  
  func testSignInButtonTapped_ValidCode_CallsDismiss() async {
    var dismissCalled = false
    
    let model = withDependencies {
      $0.api.verifyInvitationCode = { code in
        XCTAssertEqual(code, "VALID123")
      }
      $0.continuousClock = ImmediateClock()
    } operation: {
      InvitationCodePageModel()
    }
    
    model.invitationCode = "VALID123"
    model.onDismiss = { dismissCalled = true }
    
    await model.signInButtonTapped()
    
    XCTAssertTrue(dismissCalled)
  }
}
