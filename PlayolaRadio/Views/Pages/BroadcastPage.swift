//
//  BroadcastPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

import Combine
import SwiftUI
import Sharing
import PlayolaPlayer
import Dependencies

@MainActor
@Observable
class BroadcastPageModel: ViewModel {
  var disposeBag: Set<AnyCancellable> = Set()
  var station: Station
  var schedule: Schedule?

  var scheduleEditorModel: ScheduleEditorModel!

  // MARK: - State
  var recordingViewIsPresented: Bool = false
  var addSongViewIsPresented: Bool = false
  var presentedAlert: PlayolaAlert?

  // Demo data for display
  var stagingAudioBlocks: [AudioBlock] = []
  var playlist: [Spin] = []
  var nowPlaying: Spin?

  // MARK: - Dependencies
  @ObservationIgnored var navigationCoordinator: NavigationCoordinator
  @ObservationIgnored @Dependency(APIClient.self) var apiClient

  init(station: Station, navigationCoordinator: NavigationCoordinator = .shared) {
    self.station = station
    self.navigationCoordinator = navigationCoordinator
    self.scheduleEditorModel = ScheduleEditorModel(station: station)
    print("BroadcastPageModel init with station: \(station.id)")
    super.init()
  }

  // MARK: - Actions
  func viewAppeared() async {
    print("BroadcastPageModel viewAppeared for station: \(station.id)")
    self.schedule = try? await apiClient.fetchSchedule(stationId: station.id)
  }
  func showRecordingView() {
    recordingViewIsPresented = true
  }

  func showAddSongView() {
    addSongViewIsPresented = true
  }

  func hamburgerButtonTapped() {
    navigationCoordinator.slideOutMenuIsShowing = true
  }
}

struct BroadcastPage: View {
  var model: BroadcastPageModel

  init(model: BroadcastPageModel) {
    self.model = model
  }

  @State var recordingViewIsPresented: Bool = false
  @State var addSongViewIsPresented: Bool = false

  var body: some View {
    ZStack {
      Color.black
        .edgesIgnoringSafeArea(.all)

      VStack {
        Spacer()
          .frame(height: 20.0)
        HStack {
          Spacer()
          Spacer()
          VStack {
            Button {
              recordingViewIsPresented = true
            } label: {
              Image("recordVoicetrackIcon")
                .resizable()
                .frame(width: 100.0, height: 100.0)
            }
            Text("Add a VoiceTrack")
              .font(.custom("OpenSans", size: 12.0))
          }

          Spacer()

          VStack {
            Button {
              addSongViewIsPresented = true

            } label: {
              Image("addSongIcon")
                .resizable()
                .frame(width: 100.0, height: 100.0)
            }
            Text("Add a Song")
              .font(.custom("OpenSans", size: 12.0))
          }

          Spacer()
          Spacer()
        }

        Spacer()
          .frame(height: 20.0)

        if model.schedule != nil {
          ScheduleEditorView(model: model.scheduleEditorModel)
        }
      }

    }
    .foregroundStyle(.white)
    .onAppear {
      Task {
        await model.viewAppeared()
      }
    }
    //        .sheet(isPresented: $recordingViewIsPresented) {
    //            VoiceTrackRecorderView(audioRecorder: self.audioRecorder, isPresented: $recordingViewIsPresented)
    //        }
    //        .sheet(isPresented: $addSongViewIsPresented) {
    //            AddSongView(isPresented: $addSongViewIsPresented)
    //        }.environmentObject(spotifyTrackPicker)
  }
}

struct BroadcastView_Previews: PreviewProvider {
  static var previews: some View {
    TabView {
      NavigationView {
        BroadcastPage(model: BroadcastPageModel(station: .mock))
          .navigationTitle("Broadcast")
          .navigationBarTitleDisplayMode(.inline)
      }
      .tabItem {
        Image(systemName: "play.fill")
        Text("Broadcast")
      }
    }
  }
}
