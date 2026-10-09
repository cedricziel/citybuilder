import CityCore
import SwiftUI

/// The route list sheet. Spec: `platform-shells` / Routes button and
/// route list, Assigning a ship to a route.
struct RouteListView: View {
    let session: GameSession
    let done: () -> Void

    private var list: RouteListViewModel {
        session.routeList
    }

    var body: some View {
        let rows = list.rows
        let idleShips = list.idleShipCount
        return NavigationStack {
            List {
                Section {
                    Button("New Route", systemImage: "plus") {
                        done()
                        session.beginRouteAuthoring()
                    }
                } footer: {
                    Text("Idle ships: \(idleShips). Or tap a port and choose Route from here.")
                }
                Section("Routes") {
                    if rows.isEmpty {
                        Text("No routes yet.").foregroundStyle(.secondary)
                    }
                    ForEach(rows) { row in
                        RouteRowView(row: row, list: list, isSelected: list.selectedRouteID == row.id, canAssignShip: idleShips > 0)
                    }
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: done) }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct RouteRowView: View {
    let row: RouteListRow
    let list: RouteListViewModel
    let isSelected: Bool
    let canAssignShip: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                list.select(isSelected ? nil : row.id)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).font(.headline)
                        Text(row.stops).font(.caption)
                        Text(row.status).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "eye.fill" : "eye")
                        .accessibilityLabel(isSelected ? "Shown on map" : "Show on map")
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            HStack {
                if row.isPaused {
                    Button("Resume", systemImage: "play.fill") { list.resume(row.id) }
                } else {
                    Button("Pause", systemImage: "pause.fill") { list.pause(row.id) }
                }
                Button(canAssignShip ? "Assign ship" : "No idle ship", systemImage: "ferry") {
                    list.assignIdleShip(to: row.id)
                }
                .disabled(!canAssignShip)
                Spacer()
                Button("Delete", systemImage: "trash", role: .destructive) { list.delete(row.id) }
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
    }
}

extension CityRootView {
    @ViewBuilder
    var routesButton: some View {
        if session.showsRoutesButton {
            Button {
                routesPresented = true
            } label: {
                Image(systemName: "ferry.fill")
                    .imageScale(.large)
                    .padding(8)
                    .background(.thinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Routes")
        }
    }
}

extension View {
    func routesSheet(session: GameSession, isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            RouteListView(session: session) { isPresented.wrappedValue = false }
        }
    }
}
