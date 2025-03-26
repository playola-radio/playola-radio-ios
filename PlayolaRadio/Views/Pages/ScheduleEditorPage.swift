//
//  ScheduleEditorPage.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

import Combine
import SwiftUI
import Sharing
import PlayolaPlayer

@MainActor
@Observable
class SchedulePageModel: ViewModel {
    var disposeBag: Set<AnyCancellable> = Set()

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

    init(navigationCoordinator: NavigationCoordinator = .shared) {
        self.navigationCoordinator = navigationCoordinator
        super.init()
        // Set up demo data for visual representation
        setupMockData()
    }

    // MARK: - Actions

    func showRecordingView() {
        recordingViewIsPresented = true
    }

    func showAddSongView() {
        addSongViewIsPresented = true
    }

    func hamburgerButtonTapped() {
        navigationCoordinator.slideOutMenuIsShowing = true
    }

    // MARK: - Mock Data Setup

  private func setupMockData() {
          let now = Date()
          let stationId = "f3864734-de35-414f-b0b3-e6909b0b77bd"

          // Create mock audio blocks based on the provided JSON data
          let audioImageBlock1 = AudioBlock.mockWith(
              id: "567947b9-6f02-45c9-91e1-b9ea550b295b",
              title: "Radio On The Internet",
              artist: "Playola",
              album: "Imaging",
              durationMS: 9288,
              endOfMessageMS: 8288,
              beginningOfOutroMS: 8288,
              endOfIntroMS: 1000,
              lengthOfOutroMS: 0,
              type: "audioimage",
              downloadUrl: URL(string:"https://playola-audio-images.s3.amazonaws.com/RadioOnTheInternet.m4a"),
              s3Key: "RadioOnTheInternet.m4a",
              s3BucketName: "playola-audio-images",
              imageUrl: nil
          )

          let songBlock1 = AudioBlock.mockWith(
              id: "59cef544-0253-478c-9244-a06029f52b4c",
              title: "Cheer Up",
              artist: "Courtney Patton & Jamie Lin Wilson",
              album: "Cheer Up - Single",
              durationMS: 153972,
              endOfMessageMS: 151304,
              beginningOfOutroMS: 150674,
              endOfIntroMS: 16391,
              lengthOfOutroMS: 630,
              type: "song",
              downloadUrl: URL(string: "https://playola-songs-intake.s3.amazonaws.com/01%20Cheer%20Up.m4a"),
              s3Key: "01 Cheer Up.m4a",
              s3BucketName: "playola-songs-intake",
              popularity: 7,
              imageUrl: URL(string: "https://i.scdn.co/image/ab67616d0000b27300ae7c550e9f241f9710a3f7")
          )

          let productionBlock = AudioBlock.mockWith(
              id: "f03edf46-2199-4ffa-b9af-768374e62358",
              title: "Dear John Deere - Intro",
              artist: "Bri Bagwell",
              album: "Song Intros",
              durationMS: 61056,
              endOfMessageMS: 60056,
              beginningOfOutroMS: 6839,
              endOfIntroMS: 1000,
              lengthOfOutroMS: 53217,
              type: "productionpiece",
              downloadUrl: URL(string:"https://playola-audio-images.s3.amazonaws.com/Dear%20John%20Deere%20INTRO.m4a"),
              s3Key: "Dear John Deere INTRO.m4a",
              s3BucketName: "playola-audio-images",
              imageUrl: nil
          )

          let songBlock2 = AudioBlock.mockWith(
              id: "37ad39b2-4564-45f9-9ce1-b7cad7d468cc",
              title: "Dear John Deere",
              artist: "Bri Bagwell",
              album: "When a Heart Breaks",
              durationMS: 228972,
              endOfMessageMS: 221517,
              beginningOfOutroMS: 218455,
              endOfIntroMS: 18018,
              lengthOfOutroMS: 3062,
              type: "song",
              downloadUrl: URL(string:"https://playola-songs-intake.s3.amazonaws.com/08%20Dear%20John%20Deere.m4a"),
              s3Key: "08 Dear John Deere.m4a",
              s3BucketName: "playola-songs-intake",
              popularity: 2,
              imageUrl: URL(string: "https://i.scdn.co/image/ab67616d0000b27392632ab81c47682c6ef4f44c")
          )

          let audioImageBlock2 = AudioBlock.mockWith(
              id: "a480d612-d986-4a18-a035-c7ffdc050e68",
              title: "Banned ID 5",
              artist: "Bri Bagwell",
              album: "Identification",
              durationMS: 5973,
              endOfMessageMS: 4973,
              beginningOfOutroMS: 4973,
              endOfIntroMS: 1000,
              lengthOfOutroMS: 0,
              type: "audioimage",
              downloadUrl: URL(string:"https://playola-audio-images.s3.amazonaws.com/Banned%20ID%205.m4a"),
              s3Key: "Banned ID 5.m4a",
              s3BucketName: "playola-audio-images",
              imageUrl: nil
          )

          let songBlock3 = AudioBlock.mockWith(
              id: "15ec2412-c4fc-49ea-80b5-bb683ecc8e0e",
              title: "Jesus and Handbags",
              artist: "Dalton Domino",
              album: "1806",
              durationMS: 185644,
              endOfMessageMS: 181581,
              beginningOfOutroMS: 170168,
              endOfIntroMS: 9655,
              lengthOfOutroMS: 11413,
              type: "song",
              downloadUrl: URL(string:"https://playola-songs-intake.s3.amazonaws.com/03%20Jesus%20and%20Handbags.m4a"),
              s3Key: "03 Jesus and Handbags.m4a",
              s3BucketName: "playola-songs-intake",
              popularity: 25,
              imageUrl: URL(string: "https://i.scdn.co/image/ab67616d0000b273c6c7e8962f58dcfc57ea0a06")
          )

          let productionBlock2 = AudioBlock.mockWith(
              id: "8b0d041a-be86-40f0-adf6-230295af699f",
              title: "DJ - BRI SKIT 4",
              artist: "Bri Bagwell",
              album: "Production Pieces",
              durationMS: 8981,
              endOfMessageMS: 7981,
              beginningOfOutroMS: 7981,
              endOfIntroMS: 1000,
              lengthOfOutroMS: 0,
              type: "productionpiece",
              downloadUrl: URL(string: "https://playola-audio-images.s3.amazonaws.com/DJ%3ABRI%20SKIT%204.m4a"),
              s3Key: "DJ:BRI SKIT 4.m4a",
              s3BucketName: "playola-audio-images",
              imageUrl: nil
          )

          let audioImageBlock3 = AudioBlock.mockWith(
              id: "5555ef82-8bcf-4e93-9832-86b0270f3e11",
              title: "Pay the Bands",
              artist: "Playola",
              album: "Imaging",
              durationMS: 5803,
              endOfMessageMS: 4803,
              beginningOfOutroMS: 4803,
              endOfIntroMS: 1000,
              lengthOfOutroMS: 0,
              type: "audioimage",
              downloadUrl: URL(string: "https://playola-audio-images.s3.amazonaws.com/Pay%20the%20Bands.m4a"),
              s3Key: "Pay the Bands.m4a",
              s3BucketName: "playola-audio-images",
              imageUrl: nil
          )

          let commercialBlock = AudioBlock.mockWith(
              id: "3803bc45-7b0d-47f5-8b7a-1612c80731f6",
              title: "Commercial",
              artist: "------",
              album: nil,
              durationMS: 180000,
              endOfMessageMS: 179000,
              beginningOfOutroMS: 179000,
              endOfIntroMS: 1000,
              lengthOfOutroMS: 0,
              type: "commercialblock",
              downloadUrl: URL(string: "https://playolacommercialblocks.s3.amazonaws.com/0001_commercial_block.mp3"),
              s3Key: "0001_commercial_block.mp3",
              s3BucketName: "playolacommercialblocks",
              imageUrl: nil
          )

          let audioImageBlock4 = AudioBlock.mockWith(
              id: "490b67bf-014a-4383-bf65-dad9f5cfa943",
              title: "Banned ID 8",
              artist: "Bri Bagwell",
              album: "Identification",
              durationMS: 8043,
              endOfMessageMS: 7043,
              beginningOfOutroMS: 7043,
              endOfIntroMS: 141,
              lengthOfOutroMS: 0,
              type: "audioimage",
              downloadUrl: URL(string: "https://playola-audio-images.s3.amazonaws.com/Banned%20ID%208.m4a"),
              s3Key: "Banned ID 8.m4a",
              s3BucketName: "playola-audio-images",
              imageUrl: nil
          )

          // Put one audio block in the staging area
          stagingAudioBlocks = [songBlock3]

          // Set up the now playing item
          nowPlaying = Spin.mockWith(
              id: "1b5dfb09-6172-48d6-8066-3f0b11cb0b16",
              airtime: now,
              stationId: stationId,
              audioBlock: audioImageBlock1,
              startingVolume: 1,
              fades: [Fade(atMS: 9288, toVolume: 0)],
              createdAt: now.addingTimeInterval(-5000),
              updatedAt: now.addingTimeInterval(-5000)
          )

          // Create playlist with spins
          playlist = [
              Spin.mockWith(
                  id: "28f01a81-9407-4967-ab46-2618bddede61",
                  airtime: now.addingTimeInterval(8.288),
                  stationId: stationId,
                  audioBlock: songBlock1,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 150674, toVolume: 0.3),
                      Fade(atMS: 152304, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "8c6ebe12-ab53-4d68-b989-633b2b0f1f9c",
                  airtime: now.addingTimeInterval(159.484),
                  stationId: stationId,
                  audioBlock: productionBlock,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 61056, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "793a5e8c-e8e3-4827-b16e-d726b242ca40",
                  airtime: now.addingTimeInterval(200.54),
                  stationId: stationId,
                  audioBlock: songBlock2,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 18018, toVolume: 1),
                      Fade(atMS: 220517, toVolume: 0.3),
                      Fade(atMS: 222517, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "7d6430b7-ed06-44b1-b90b-78f41d7a2b64",
                  airtime: now.addingTimeInterval(420.057),
                  stationId: stationId,
                  audioBlock: audioImageBlock2,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 5973, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "26d20f50-94b2-48d9-a189-9b082d6eb56f",
                  airtime: now.addingTimeInterval(425.03),
                  stationId: stationId,
                  audioBlock: songBlock3,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 180581, toVolume: 0.3),
                      Fade(atMS: 182581, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "4121be15-ea5c-46b1-9b9c-90412f78634d",
                  airtime: now.addingTimeInterval(606.611),
                  stationId: stationId,
                  audioBlock: productionBlock2,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 8981, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "34895f62-dd94-42d0-80b5-0862e4f80304",
                  airtime: now.addingTimeInterval(614.592),
                  stationId: stationId,
                  audioBlock: audioImageBlock3,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 5803, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "8036b708-2a76-4e96-a287-4398b92c8399",
                  airtime: now.addingTimeInterval(619.395),
                  stationId: stationId,
                  audioBlock: commercialBlock,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 180000, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "bf96f8cc-b3de-4f8e-a564-9d0663df0573",
                  airtime: now.addingTimeInterval(799.395),
                  stationId: stationId,
                  audioBlock: audioImageBlock4,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 8043, toVolume: 0)
                  ]
              ),
              Spin.mockWith(
                  id: "88357c27-d5f0-496d-8733-53b8d273be72",
                  airtime: now.addingTimeInterval(807.438),
                  stationId: stationId,
                  audioBlock: songBlock1,
                  startingVolume: 1,
                  fades: [
                      Fade(atMS: 231326, toVolume: 0.3),
                      Fade(atMS: 233326, toVolume: 0)
                  ]
              )
          ]
      }
}

// Helper extension to make copies
extension AudioBlock {
//    func copy() -> AudioBlock {
//        return AudioBlock(
//            id: UUID().uuidString, // Create a new ID for the copy
//            title: self.title,
//            artist: self.artist,
//            imageUrl: self.imageUrl,
//            type: self.type,
//            durationMS: self.durationMS
//        )
//    }
}

extension Date {
    func toBeautifulString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: self)
    }
}

func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter.string(from: date)
}
struct ScheduleCellView: View {
    let id: String
    let title: String
    let artist: String
    let imageUrl: URL?
    let type: String
    let airtime: Date
    let isBeingScheduled: Bool
    let playPreview: ((ScheduleCellView) -> Void)?

    @State private var voiceTrackPreviewIsLoading: Bool = false
    @State private var voiceTrackPreviewLoadingProgress: Double = 0.0

    var body: some View {
        HStack {
            // Image handling
            switch type {
            case "commercial":
                Image("greedyFace")
                    .resizable()
                    .frame(width: 45, height: 33)
                    .padding(.zero)
            case "voicetrack":
                Image("voiceTrackAlbumArtwork")
                    .resizable()
                    .frame(width: 45, height: 45)
                    .padding(.zero)
            default:
              AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 45, height: 45)
                        .clipped()
                } placeholder: {
                    Image("emptyAlbumWithOverlay")
                        .resizable()
                        .frame(width: 45, height: 45)
                }
            }

            Spacer().frame(width: 10)

            VStack(alignment: .leading) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))

                if type != "voicetrack" && type != "commercial" {
                    Text(artist)
                        .foregroundColor(.gray)
                        .font(.system(size: 10, weight: .semibold))
                }
            }

            Spacer()

            // Voice track preview or airtime
            if type == "voicetrack" {
                if voiceTrackPreviewIsLoading {
                    // Implement circular progress view if needed
                    Text("Loading...")
                        .foregroundColor(.gray)
                } else {
                    Button(action: {
                        playPreview?(self)
                    }) {
                        Image("myScheduleCellPlayEnabled")
                            .resizable()
                            .frame(width: 20, height: 20)
                    }
                }
            }

            // Scheduling indicator or airtime
            if isBeingScheduled {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(width: 23, height: 23)
            } else {
                Text("at \(airtime.toBeautifulString())")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }

            // Reorder handle
            Image("myScheduleCellHandle")
                .padding(.trailing, 10)
        }
        .frame(height: type == "commercial" ? 33 : 45)
        .background(type == "commercial" ? Color.black : Color(hex: "333333"))
    }
}

// Enum to match the type string in AudioBlock
enum AudioBlockType: String {
    case song
    case commercial = "commercialblock"
    case voicetrack
    case audioimage
    case productionpiece
}
//
//struct ScheduleEditorView: View {
//    @Bindable var model: SchedulePageModel
//
//    var body: some View {
//        GeometryReader { _ in
//            VStack(spacing: 0) {
//                // Staging Audio Blocks Section
//                if !model.stagingAudioBlocks.isEmpty {
//                    VStack(spacing: 0) {
//                        List {
//                            ForEach(model.stagingAudioBlocks, id: \.id) { audioBlock in
//                                StagingCellView(audioBlock: audioBlock)
//                                    .listRowInsets(EdgeInsets())
//                                    .listRowSeparator(.hidden)
//                                    .background(Color.black)
//                                    .onDrag { NSItemProvider(object: audioBlock.id as NSString) }
//                            }
//                            .onMove(perform: moveStagingAudioBlock)
//                            .onDelete(perform: deleteStagingAudioBlock)
//                        }
//                        .listStyle(PlainListStyle())
//                        .frame(height: CGFloat(model.stagingAudioBlocks.count * 45))
//                        .background(Color.black)
//
//                        Image("myScheduleArrows")
//                            .resizable()
//                            .aspectRatio(contentMode: .fit)
//                            .frame(height: 20)
//                            .background(Color.clear)
//                            .foregroundColor(.gray)
//                            .padding(.vertical, 10)
//                    }
//                    .background(Color.black)
//                }
//
//                // Now Playing Section
//                if let nowPlaying = model.nowPlaying {
//                    ScheduleNowPlayingView2(
//                        title: nowPlaying.audioBlock?.title ?? "Unknown Title",
//                        artist: nowPlaying.audioBlock?.artist ?? "Unknown Artist",
//                        imageUrl: nowPlaying.audioBlock?.imageUrl,
//                        type: nowPlaying.audioBlock?.type ?? "",
//                        airtime: nowPlaying.airtime,
//                        endTime: model.playlist.first?.airtime ?? nowPlaying.airtime
//                    )
//                }
//
//                // Playlist Section
//                List {
//                    ForEach(model.playlist, id: \.id) { spin in
//                        ScheduleCellView(
//                            id: spin.id,
//                            title: spin.audioBlock?.title ?? "Unknown Title",
//                            artist: spin.audioBlock?.artist ?? "Unknown Artist",
//                            imageUrl: spin.audioBlock?.imageUrl,
//                            type: spin.audioBlock?.type ?? "",
//                            airtime: spin.airtime,
//                            isBeingScheduled: false,
//                            playPreview: nil
//                        )
//                        .listRowInsets(EdgeInsets())
//                        .listRowSeparator(.hidden)
//                        .background(Color.black)
//                        .onDrag { NSItemProvider(object: spin.id as NSString) }
//                    }
//                    .onMove(perform: movePlaylistItem)
//                    .onInsert(of: ["public.text"], perform: dropAudioBlockIntoPlaylist)
//                    .onDelete(perform: deleteScheduledSpin)
//                }
//                .environment(\.defaultMinListRowHeight, 33)
//                .listStyle(PlainListStyle())
//                .background(Color.black)
//
//                Spacer()
//            }
//            .background(Color.black)
//        }
//    }
//
//    // Existing methods remain the same
//    func deleteStagingAudioBlock(at offsets: IndexSet) {
//        model.stagingAudioBlocks.remove(atOffsets: offsets)
//    }
//
//    func deleteScheduledSpin(at offsets: IndexSet) {
//        offsets.forEach { index in
//            let spinToRemove = model.playlist[index]
//            // Implement actual removal logic
//        }
//    }
//
//    func dropAudioBlockIntoPlaylist(at index: Int, _ items: [NSItemProvider]) {
//        for item in items {
//            _ = item.loadObject(ofClass: String.self) { audioBlockId, _ in
//                if let audioBlockId = audioBlockId {
//                    DispatchQueue.main.async {
//                        if let audioBlock = self.model.stagingAudioBlocks.first(where: { $0.id == audioBlockId }) {
//                            // Remove from staging
//                            self.model.stagingAudioBlocks.removeAll { $0.id == audioBlockId }
//
//                            // TODO: Implement spin insertion
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    func moveStagingAudioBlock(from source: IndexSet, to destination: Int) {
//        model.stagingAudioBlocks.move(fromOffsets: source, toOffset: destination)
//    }
//
//    func movePlaylistItem(from source: IndexSet, to destination: Int) {
//        model.playlist.move(fromOffsets: source, toOffset: destination)
//    }
//}
//
//// Simple StagingCellView adapted to use AudioBlock
//struct StagingCellView: View {
//    let audioBlock: AudioBlock
//
//    var body: some View {
//        HStack {
//          AsyncImage(url: audioBlock.imageUrl) { image in
//                image
//                    .resizable()
//                    .aspectRatio(contentMode: .fill)
//                    .frame(width: 45, height: 45)
//                    .clipped()
//            } placeholder: {
//                Image("emptyAlbumWithOverlay")
//                    .resizable()
//                    .frame(width: 45, height: 45)
//            }
//
//            VStack(alignment: .leading) {
//                Text(audioBlock.title)
//                    .foregroundColor(.white)
//                Text(audioBlock.artist)
//                    .foregroundColor(.gray)
//                    .font(.caption)
//            }
//
//            Spacer()
//        }
//        .background(Color(hex: "333333"))
//    }
//}

// ScheduleNowPlayingView to match the original design
struct ScheduleNowPlayingView2: View {
    let title: String
    let artist: String
    let imageUrl: URL?
    let type: String
    let airtime: Date
    let endTime: Date

    var body: some View {
        HStack {
            AsyncImage(url: imageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 45, height: 45)
                    .clipped()
            } placeholder: {
                Image("emptyAlbumWithOverlay")
                    .resizable()
                    .frame(width: 45, height: 45)
            }

            VStack(alignment: .leading) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
                Text(artist)
                    .foregroundColor(.gray)
                    .font(.system(size: 10, weight: .semibold))
            }

            Spacer()

            Text(airtime.toBeautifulString())
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
        .frame(height: 45)
        .background(Color(hex: "333333"))
    }
}


//// Preview with mock data
//struct ScheduleEditorView_Previews: PreviewProvider {
//    static var previews: some View {
//        ScheduleEditorView(model: SchedulePageModel())
//    }
//}

import SwiftUI

struct BroadcastView: View {
//    var scheduleEditor: ScheduleEditor

    init() {
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.white]
//        audioRecorder = PlayolaAudioRecorder()
//        spotifyTrackPicker = SpotifyTrackPicker()
//        scheduleEditor = ScheduleEditor(user: sessionStore.user!, audioRecorder: audioRecorder, spotifyTrackPicker: spotifyTrackPicker)
    }

//    var audioRecorder: PlayolaAudioRecorder = .init()
//    var spotifyTrackPicker: SpotifyTrackPicker = .init()

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
                
//                if let _ = self.sessionStore.user {
//                    ScheduleEditorView(scheduleEditor: self.scheduleEditor)
//                        .frame(maxHeight: .infinity)
//                }
            }

        }
        .foregroundStyle(.white)
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
                BroadcastView()
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
