//
//  PlayolaTokenProviderTests.swift
//  PlayolaRadioTests
//
//  Created by Brian D Keane on 2/13/25.
//

@testable import PlayolaRadio
import Sharing
import Testing

@MainActor
struct PlayolaTokenProviderTests {
    
    @Suite("getCurrentToken")
    struct GetCurrentToken {
        @Test("Returns nil when user not logged in")
        func testReturnsNilWhenUserNotLoggedIn() async {
            @Shared(.auth) var auth = Auth()
            let tokenProvider = PlayolaTokenProvider()
            
            let token = await tokenProvider.getCurrentToken()
            
            #expect(token == nil)
        }
        
        @Test("Returns JWT when user is logged in")
        func testReturnsJWTWhenUserLoggedIn() async {
            let expectedJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature"
            @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
            let tokenProvider = PlayolaTokenProvider()
            
            let token = await tokenProvider.getCurrentToken()
            
            #expect(token == expectedJWT)
        }
        
        @Test("Returns nil immediately after user signs out")
        func testReturnsNilAfterUserSignsOut() async {
            @Shared(.auth) var auth = Auth(jwtToken: "initial.jwt.token")
            let tokenProvider = PlayolaTokenProvider()
            
            // Sign out user
            auth = Auth()
            
            let token = await tokenProvider.getCurrentToken()
            #expect(token == nil)
        }
    }
    
    @Suite("refreshToken")
    struct RefreshToken {
        @Test("Returns nil when user not logged in")
        func testReturnsNilWhenUserNotLoggedIn() async {
            @Shared(.auth) var auth = Auth()
            let tokenProvider = PlayolaTokenProvider()
            
            let token = await tokenProvider.refreshToken()
            
            #expect(token == nil)
        }
        
        @Test("Returns current JWT when user is logged in")
        func testReturnsCurrentJWTWhenUserLoggedIn() async {
            let expectedJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.test.signature"
            @Shared(.auth) var auth = Auth(jwtToken: expectedJWT)
            let tokenProvider = PlayolaTokenProvider()
            
            let token = await tokenProvider.refreshToken()
            
            #expect(token == expectedJWT)
        }
    }
    
    @Suite("Reactive Authentication State Changes")
    struct ReactiveAuthChanges {
        @Test("Immediately reflects auth state changes")
        func testImmediatelyReflectsAuthStateChanges() async {
            @Shared(.auth) var auth = Auth()
            let tokenProvider = PlayolaTokenProvider()
            
            // Initially no token
            #expect(await tokenProvider.getCurrentToken() == nil)
            
            // User logs in
            let jwt = "new.jwt.token"
            auth = Auth(jwtToken: jwt)
            
            // Token provider immediately reflects the change
            #expect(await tokenProvider.getCurrentToken() == jwt)
            
            // User logs out
            auth = Auth()
            
            // Token provider immediately reflects the logout
            #expect(await tokenProvider.getCurrentToken() == nil)
        }
        
        @Test("Multiple auth state changes are tracked correctly")
        func testMultipleAuthStateChangesTracked() async {
            @Shared(.auth) var auth = Auth()
            let tokenProvider = PlayolaTokenProvider()
            
            let tokens = ["first.jwt.token", "second.jwt.token", "third.jwt.token"]
            
            for expectedToken in tokens {
                auth = Auth(jwtToken: expectedToken)
                let actualToken = await tokenProvider.getCurrentToken()
                #expect(actualToken == expectedToken)
            }
            
            // Final logout
            auth = Auth()
            #expect(await tokenProvider.getCurrentToken() == nil)
        }
    }
}