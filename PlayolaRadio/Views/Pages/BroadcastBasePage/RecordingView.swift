//
//  RecordingView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 4/11/25.
//

import SwiftUI

struct RecordingView: View {
    @Bindable var model: RecordingViewModel
    @Environment(\.dismiss) private var dismiss

    private let visualizerHeight: CGFloat = 120
    private let barWidth: CGFloat = 20
    private let spacing: CGFloat = 2
    private let numberOfBars = 10

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                // Title
                Text("Record VoiceTrack")
                    .font(.custom("OpenSans", size: 24))
                    .foregroundStyle(.white)
                    .padding(.top, 20)

                Spacer()

                // Recording Status and Timer
                Group {
                    statusView
                }
                .foregroundStyle(.white)

                Spacer()

                // Controls
                HStack(spacing: 40) {
                    // Cancel Button (only show when not recording)
                    if model.showCancelButton {
                        Button {
                            model.cleanup()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundStyle(.white)
                        }
                    }

                    // Record/Stop Button
                    Button {
                      Task  { await model.recordButtonTapped() }
                    } label: {
                      Image(systemName: model.recordButtonImage.rawValue)
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(model.recordButtonColor)
                    }
                    .disabled(!model.recordButtonEnabled)
                }
                .padding(.bottom, 40)
            }
            .rotationEffect(.degrees(180))
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var statusView: some View {
      switch model.activeStatusView {
        case .idle(let title):
            Text(title)
                .font(.custom("OpenSans", size: 18))
        case .counting(let count):
            CountdownOverlay(count: count)
        case .recording:
            recordingView
        case .processing(let message):
            VStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text(message)
                    .font(.custom("OpenSans", size: 16))
                    .padding(.top, 8)
            }
        case .completed:
            VStack {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.green)
                Text("Voicetrack Added!")
                    .font(.custom("OpenSans", size: 18))
                    .padding(.top, 8)
            }
        case .error(let errorMessage):
            Text(errorMessage)
                .foregroundStyle(.red)
        }
    }

    private var recordingView: some View {
        VStack(spacing: 20) {
            Text(formatDuration(model.duration))
                .font(.custom("OpenSans", size: 24))
                .frame(height: 30)

            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .frame(width: CGFloat(numberOfBars) * (barWidth + spacing), height: visualizerHeight)

                HStack(spacing: spacing) {
                    ForEach(0..<numberOfBars, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.red)
                            .frame(width: barWidth)
                            .frame(height: scaledHeight(power: model.averagePower))
                            .animation(.easeOut(duration: 0.1), value: model.averagePower)
                    }
                }
            }
            .frame(height: visualizerHeight)
            .clipped()
        }
    }

    // MARK: - Helper Functions

//    private func handleRecordButton() {
//        switch model.state {
//        case .idle:
//            model.startRecording { voicetrack in
//                // Handle completed recording with LocalVoicetrack
//                dismiss()
//            }
//        case .recording:
//            model.stopRecording()
//        default:
//            break
//        }
//    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func scaledHeight(power: Float) -> CGFloat {
        let minDb: Float = -60
        let maxDb: Float = 0
        let minHeight: CGFloat = 10
        let maxHeight: CGFloat = visualizerHeight

        let normalizedPower = min(max(power, minDb), maxDb)
        let powerRatio = (normalizedPower - minDb) / (maxDb - minDb)
        return minHeight + CGFloat(powerRatio) * (maxHeight - minHeight)
    }
}

#Preview {
  RecordingView(model: RecordingViewModel(stationId: "testId"))
}
