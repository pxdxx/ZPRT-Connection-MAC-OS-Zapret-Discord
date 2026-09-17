import SwiftUI

struct ContentView: View {
    @Bindable var state: AppState
    @State private var dismissedUpdateTag: String?

    private var palette: StudioPalette {
        state.isDarkTheme ? .dark : .light
    }

    var body: some View {
        ZStack {
            AtmosphereBackground()
                .id(state.isDarkTheme ? "dark" : "light")
                .transition(.opacity)

            VStack(spacing: 0) {
                Group {
                    switch state.screen {
                    case .home:
                        ScrollView(showsIndicators: false) {
                            HomeView(state: state)
                                .padding(.horizontal, 18)
                                .padding(.bottom, 12)
                        }
                    case .settings:
                        SettingsView(state: state)
                            .padding(.horizontal, 18)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.2), value: state.screen)

                if let notice = state.notice {
                    NoticeBanner(notice: notice, onDismiss: state.dismissNotice)
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }

                BottomNavBar(selection: state.screen) { screen in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        state.show(screen)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 16)
            }
        }
        .environment(\.studioPalette, palette)
        .preferredColorScheme(state.isDarkTheme ? .dark : .light)
        .animation(.spring(response: 0.55, dampingFraction: 0.86), value: state.isDarkTheme)
        .frame(
            minWidth: OutpostDimens.windowMinWidth,
            idealWidth: OutpostDimens.windowWidth,
            minHeight: OutpostDimens.windowMinHeight,
            idealHeight: OutpostDimens.windowHeight
        )
        .sheet(isPresented: Binding(
            get: { state.availableRelease != nil && state.availableRelease?.tagName != dismissedUpdateTag },
            set: { isPresented in
                if !isPresented { dismissedUpdateTag = state.availableRelease?.tagName }
            }
        )) {
            if let release = state.availableRelease {
                UpdateAvailableSheet(
                    release: release,
                    updating: state.updatingNow,
                    onUpdate: { Task { await state.updateNow() } },
                    onLater: { dismissedUpdateTag = release.tagName }
                )
            }
        }
    }
}

#Preview {
    ContentView(state: AppState())
}
