@MainActor @Suite("Voicetrack Upload Tests")
struct VoicetrackUploadTests {
    @Test("Successfully uploads voicetrack and updates progress")
    func testUploadVoicetrackSuccess() async throws {
        let recordingURL = URL(fileURLWithPath: "/test/recording.m4a")
        let expectedPresignedUrl = "https://test-bucket.s3.amazonaws.com/upload"
        let expectedS3Key = "test-key"
        var uploadProgressValues: [Double] = []
        var uploadCalled = false
        var getPresignedUrlCalled = false
        
        let model = withDependencies {
            $0.genericApiClient.getVoicetrackPresignedUrl = { _, _ in
                getPresignedUrlCalled = true
                return VoicetrackPresignedURLResponse(
                    presignedUrl: expectedPresignedUrl,
                    s3Key: expectedS3Key
                )
            }
            
            $0.genericApiClient.uploadFileToPresignedUrl = { presignedUrl, fileUrl, progress in
                uploadCalled = true
                #expect(presignedUrl == expectedPresignedUrl)
                #expect(fileUrl == recordingURL)
                
                // Simulate upload progress
                progress(0.5)
                uploadProgressValues.append(0.5)
                progress(1.0)
                uploadProgressValues.append(1.0)
            }
            
            $0.audioRecorder = AudioRecorder(
                startRecording: { recordingURL },
                stopRecording: { LocalVoicetrack(fileURL: recordingURL, durationMS: 1000) },
                pauseRecording: { },
                resumeRecording: { },
                currentRecordingInfo: { RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5) },
                isRecording: { true }
            )
        } operation: {
            RecordingViewModel(stationId: "test-station") { _ in }
        }

        // Set initial recording state
        model.activeStatusView = .recording
        model.recordingURL = recordingURL
        
        // Stop recording which triggers upload
        await model.stopButtonTapped()
        
        // Verify the flow
        #expect(getPresignedUrlCalled == true)
        #expect(uploadCalled == true)
        #expect(uploadProgressValues.count == 2)
        #expect(uploadProgressValues[0] == 0.5)
        #expect(uploadProgressValues[1] == 1.0)
        #expect(model.activeStatusView == .processing("Uploading Voicetrack: 100%"))
    }
    
    @Test("Handles presigned URL fetch error")
    func testPresignedUrlError() async throws {
        let recordingURL = URL(fileURLWithPath: "/test/recording.m4a")
        let expectedError = APIError.unauthorized
        var uploadCalled = false
        
        let model = withDependencies {
            $0.genericApiClient.getVoicetrackPresignedUrl = { _, _ in
                throw expectedError
            }
            
            $0.genericApiClient.uploadFileToPresignedUrl = { _, _, _ in
                uploadCalled = true
            }
            
            $0.audioRecorder = AudioRecorder(
                startRecording: { recordingURL },
                stopRecording: { LocalVoicetrack(fileURL: recordingURL, durationMS: 1000) },
                pauseRecording: { },
                resumeRecording: { },
                currentRecordingInfo: { RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5) },
                isRecording: { true }
            )
        } operation: {
            RecordingViewModel(stationId: "test-station") { _ in }
        }

        // Set initial recording state
        model.activeStatusView = .recording
        model.recordingURL = recordingURL
        
        // Stop recording which triggers upload
        await model.stopButtonTapped()
        
        // Verify error handling
        #expect(uploadCalled == false)
        if case .error(let message) = model.activeStatusView {
            #expect(message == expectedError.localizedDescription)
        }
    }
    
    @Test("Handles upload error")
    func testUploadError() async throws {
        let recordingURL = URL(fileURLWithPath: "/test/recording.m4a")
        let expectedError = APIError.networkError(NSError(domain: "", code: -1))
        
        let model = withDependencies {
            $0.genericApiClient.getVoicetrackPresignedUrl = { _, _ in
                return VoicetrackPresignedURLResponse(
                    presignedUrl: "https://test-bucket.s3.amazonaws.com/upload",
                    s3Key: "test-key"
                )
            }
            
            $0.genericApiClient.uploadFileToPresignedUrl = { _, _, _ in
                throw expectedError
            }
            
            $0.audioRecorder = AudioRecorder(
                startRecording: { recordingURL },
                stopRecording: { LocalVoicetrack(fileURL: recordingURL, durationMS: 1000) },
                pauseRecording: { },
                resumeRecording: { },
                currentRecordingInfo: { RecordingInfo(averagePower: -20, peakPower: -10, duration: 1.5) },
                isRecording: { true }
            )
        } operation: {
            RecordingViewModel(stationId: "test-station") { _ in }
        }

        // Set initial recording state
        model.activeStatusView = .recording
        model.recordingURL = recordingURL
        
        // Stop recording which triggers upload
        await model.stopButtonTapped()
        
        // Verify error handling
        if case .error(let message) = model.activeStatusView {
            #expect(message == expectedError.localizedDescription)
        }
    }
}