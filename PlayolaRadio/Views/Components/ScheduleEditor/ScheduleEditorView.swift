//
//  ScheduleEditorView.swift
//  PlayolaRadio
//
//  Created by Brian D Keane on 3/26/25.
//

//import Combine
//import SwiftUI
//import PlayolaPlayer
//
//@MainActor
//@Observable
//class ScheduleEditorModel: ViewModel {
//  var stagingAreaAudioBlocks: [AudioBlock] = [.mock]
//  
//}
//
//@MainActor
//struct ScheduleEditorView: View {
//  var model: ScheduleEditorModel
////    private var subscriptions = Set<AnyCancellable>()
//
//    @State private var users1 = ["Paul", "Taylor", "Adele"]
//    @State private var users2 = ["Pauline", "Tom", "Adam"]
//
//    var body: some View {
//        GeometryReader { _ in
//            VStack {
//                HStack {
//                    Spacer()
//                        .frame(width: 10)
//                }
//
//                VStack(spacing: 0) {
//                    if model.stagingAreaAudioBlocks.count > 0 {
//                        VStack {
//                            List {
//                                ForEach(model.stagingAreaAudioBlocks, id: \.self) { audioBlock in
//                                    StagingCellView(title: audioBlock.title,
//                                                    artist: audioBlock.artist,
//                                                    imageUrl: audioBlock.imageUrl,
//                                                    type: audioBlock.type)
//                                        .onDrag { NSItemProvider(object: audioBlock.id as NSString) }
//                                }
//                                .onMove(perform: moveStagingAudioBlock)
//                                .onDelete(perform: deleteStagingAudioBlock)
//                                .frame(maxWidth: .infinity)
//                            }
//                            .listStyle(PlainListStyle())
//                            .edgesIgnoringSafeArea([.leading, .trailing])
//                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
//                            .padding(.bottom, 10)
//                            .background(Color.black)
//                            .frame(maxHeight: CGFloat(scheduleEditor.stagingAudioBlocks.count * 45 + 10))
//
//                            Image("myScheduleArrows")
//                                .background(Color.clear)
//                                .foregroundColor(Color.playolaGray)
//                                .padding(.bottom, 10)
//                        }
//                        .background(.black)
//                    }
//
//                    if let nowPlaying = scheduleEditor.nowPlaying {
//                        NowPlayingView(title: nowPlaying.audioBlock.title,
//                                       artist: nowPlaying.audioBlock.artist,
//                                       imageUrl: nowPlaying.audioBlock.imageUrl,
//                                       type: nowPlaying.audioBlock.type,
//                                       airtime: nowPlaying.airtime,
//                                       endTime: scheduleEditor.playlist.first!.airtime)
//                    }
//
//
//                    List {
//                        ForEach(scheduleEditor.playlist, id: \.self) { spin in
//                            ScheduleCellView(id: spin.id,
//                                             title: spin.audioBlock.title,
//                                             artist: spin.audioBlock.artist,
//                                             imageUrl: spin.audioBlock.imageUrl,
//                                             type: spin.audioBlock.type,
//                                             airtime: spin.airtime,
//                                             isBeingScheduled: spin.isBeingRescheduled,
//                                             playPreview: playPreview)
//                                .onDrag { NSItemProvider(object: spin.id as NSString) }
//                        }
//                        .onMove(perform: moveList2)
//                        .onInsert(of: ["public.text"], perform: dropAudioBlockIntoPlaylist)
//                        .onDelete(perform: deleteScheduledSpin)
//                    }
//                    .environment(\.defaultMinListRowHeight, 33)
//                    .background(Color.black)
//                    .frame(maxWidth: .infinity)
//                    .edgesIgnoringSafeArea(.all)
//                    .listStyle(.plain)
//                    .animation(.default)
//                    Spacer()
//                }
//            }
//        }
//    }
//
//    func playPreview(scheduleCellView: ScheduleCellView) {
//        let spinId = scheduleCellView.id
//        scheduleCellView.voiceTrackPreviewIsLoading = true
//        scheduleEditor.playPreview(spinId: spinId)?
//            .receive(on: DispatchQueue.main)
//            .sink(receiveCompletion: { _ in
//                scheduleCellView.voiceTrackPreviewIsLoading = false
//            }, receiveValue: { progress in
//                scheduleCellView.voiceTrackPreviewLoadingProgress = progress
//            })
//            .store(in: &scheduleEditor.subscriptions)  // TODO: change this -- it's hacky
//    }
//
//    func deleteStagingAudioBlock(at offsets: IndexSet) {
//        scheduleEditor.stagingAudioBlocks.remove(atOffsets: offsets)
//    }
//
//    func deleteScheduledSpin(at offsets: IndexSet) {
//        offsets.forEach { index in
//            let spinToRemove = scheduleEditor.playlist[index]
//            scheduleEditor.removeSpin(id: spinToRemove.id)
//        }
//    }
//
//    func dropAudioBlockIntoPlaylist(at index: Int, _ items: [NSItemProvider]) {
//        for item in items {
//            _ = item.loadObject(ofClass: String.self) { audioBlockId, _ in
//                if let audioBlockId = audioBlockId {
//                    DispatchQueue.main.async {
//                        if let audioBlock = self.scheduleEditor.stagingAudioBlocks.first(where: { $0.id == audioBlockId }) {
//                            self.scheduleEditor.stagingAudioBlocks.removeAll { audioBlock in
//                                audioBlock.id == audioBlockId
//                            }
//                            let playlistPosition = self.scheduleEditor.playlist[index].playlistPosition
//                            self.scheduleEditor.insertSpin(audioBlock: audioBlock, playlistPosition: playlistPosition)
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    func moveStagingAudioBlock(from source: IndexSet, to destination: Int) {
//        let startingIndex = source.first!
//        let spin = scheduleEditor.playlist[startingIndex]
//        let destinationSpin = scheduleEditor.playlist[destination]
//        let playlistPosition = destinationSpin.playlistPosition
//
//        scheduleEditor.moveSpin(spinId: spin.id, newPlaylistPosition: playlistPosition)
//    }
//
//    func moveList2(from source: IndexSet, to destination: Int) {
//        let startingIndex = source.first!
//        let spin = scheduleEditor.playlist[startingIndex]
//        print("DESTINATIONSPIN.PLAYLISTPOSITION")
//        let destinationSpin = scheduleEditor.playlist[destination]
//        let playlistPosition = destinationSpin.playlistPosition
//        let newPlaylistPosition = startingIndex > destination ? playlistPosition : playlistPosition - 1
//        scheduleEditor.moveSpin(spinId: spin.id, newPlaylistPosition: newPlaylistPosition)
//    }
//}
//
//struct ScheduleEditorView_Previews: PreviewProvider {
//    static var previews: some View {
//        ScheduleEditorView(scheduleEditor: ScheduleEditor(user: PreviewDataProvider().getUserWithExtendedPlaylist(),
//                                                          audioRecorder: PlayolaAudioRecorder(),
//                                                          spotifyTrackPicker: SpotifyTrackPicker()))
//    }
//}
