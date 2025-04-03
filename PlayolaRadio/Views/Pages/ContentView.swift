@MainActor
struct AppView: View {
    var sideBarWidth = UIScreen.main.bounds.size.width * 0.5
    @State var offset: CGFloat = 0
    @GestureState var gestureOffset: CGFloat = 0
    @Shared(.navigationCoordinator) var navigationCoordinator
    @Shared(.auth) var auth

    private let menuTransitionAnimation = Animation.interactiveSpring(
        response: 0.5,
        dampingFraction: 0.8,
        blendDuration: 0
    )

    @MainActor
    init() {
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().tintColor = .white
        UINavigationBar.appearance().prefersLargeTitles = true
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.black.edgesIgnoringSafeArea(.all)

                navigationCoordinator.createNavigationStack()
                    .offset(x: max(self.offset + self.gestureOffset, 0))
                    .animation(menuTransitionAnimation, value: gestureOffset)
                    .animation(menuTransitionAnimation, value: offset)
                    .overlay(
                        GeometryReader { _ in
                            EmptyView()
                        }
                        .background(.black.opacity(0.6))
                        .opacity(getBlurRadius())
                        .animation(menuTransitionAnimation, value: navigationCoordinator.slideOutMenuIsShowing)
                        .onTapGesture {
                            withAnimation(menuTransitionAnimation) {
                                navigationCoordinator.slideOutMenuIsShowing.toggle()
                            }
                        }
                    )

                SideMenuView(model: SideMenuViewModel())
                    .frame(width: sideBarWidth)
                    .animation(menuTransitionAnimation, value: gestureOffset)
                    .offset(x: -sideBarWidth)
                    .offset(x: max(self.offset + self.gestureOffset, 0))
            }
            .gesture(
                DragGesture()
                    .updating($gestureOffset, body: { value, out, _ in
                        if value.translation.width > 0 && navigationCoordinator.slideOutMenuIsShowing {
                            out = value.translation.width * 0.1
                        } else {
                            out = min(value.translation.width, sideBarWidth)
                        }
                    })
                    .onEnded(onEnd(value:))
            )
            .onChange(of: navigationCoordinator.slideOutMenuIsShowing) { _, newValue in
                withAnimation(menuTransitionAnimation) {
                    if newValue {
                        offset = sideBarWidth
                    } else {
                        offset = 0
                    }
                }
            }
        }
    }

    func getBlurRadius() -> CGFloat {
        let progress = (offset + gestureOffset) / (UIScreen.main.bounds.height * 0.50)
        return progress
    }

    func onEnd(value: DragGesture.Value) {
        let translation = value.translation.width

        withAnimation(menuTransitionAnimation) {
            if translation > 0 && translation > (sideBarWidth * 0.6) {
                navigationCoordinator.slideOutMenuIsShowing = true
            } else if -translation > (sideBarWidth / 2) {
                navigationCoordinator.slideOutMenuIsShowing = false
            } else {
                if offset == 0 || !navigationCoordinator.slideOutMenuIsShowing {
                    return
                }
                navigationCoordinator.slideOutMenuIsShowing = true
            }
        }
    }
}
