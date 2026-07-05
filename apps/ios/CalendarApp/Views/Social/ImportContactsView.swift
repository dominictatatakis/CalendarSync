import SwiftUI
import Contacts

struct ImportedContact: Identifiable {
    let id = UUID()
    let name: String
    let email: String
    let source: ContactSource
    var matchedUser: AppUser?

    enum ContactSource: String {
        case instagram = "Instagram"
        case whatsapp = "WhatsApp"
        case phone = "Contacts"
    }
}

struct ImportContactsView: View {
    @EnvironmentObject var auth: AuthViewModel
    @EnvironmentObject var friends: FriendsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var contacts: [ImportedContact] = []
    @State private var selectedIDs: Set<String> = []
    @State private var isImporting = false
    @State private var isSending = false
    @State private var didSend = false
    @State private var showSourcePicker = true
    @State private var manualEmails = ""

    private let service = SupabaseService()

    var matchedCount: Int {
        contacts.filter { $0.matchedUser != nil && selectedIDs.contains($0.email) }.count
    }

    var body: some View {
        NavigationStack {
            List {
                if showSourcePicker {
                    sourceSection
                } else {
                    contactListSection
                }
            }
            .navigationTitle("Import Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Source Selection

    private var sourceSection: some View {
        Group {
            Section("Choose a source") {
                Button {
                    importFromPhoneContacts(source: .whatsapp)
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text("WA").font(.headline.bold()).foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("WhatsApp").font(.headline)
                            Text("Import from device contacts").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Button {
                    importFromPhoneContacts(source: .instagram)
                } label: {
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.88, green: 0.19, blue: 0.42))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Text("IG").font(.headline.bold()).foregroundStyle(.white)
                            }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Instagram").font(.headline)
                            Text("Import from your followers").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if isImporting {
                Section { ProgressView("Scanning contacts...") }
            }
        }
    }

    // MARK: - Contact List

    private var contactListSection: some View {
        Group {
            let matched = contacts.filter { $0.matchedUser != nil }
            let unmatched = contacts.filter { $0.matchedUser == nil }

            Section {
                Text("Found \(matched.count) of \(contacts.count) contacts on CalendarSync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !matched.isEmpty {
                Section("On CalendarSync") {
                    ForEach(matched) { contact in
                        contactRow(contact)
                    }
                }
            }

            if !unmatched.isEmpty {
                Section("Not on CalendarSync") {
                    ForEach(unmatched) { contact in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name).font(.subheadline)
                                Text(contact.email).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Not found").font(.caption).foregroundStyle(.tertiary)
                        }
                        .opacity(0.5)
                    }
                }
            }

            Section {
                if didSend {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Friend requests sent!")
                    }
                } else {
                    Button {
                        sendRequests()
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView().tint(.white)
                            }
                            Text("Send \(matchedCount) Friend Request\(matchedCount == 1 ? "" : "s")")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(matchedCount == 0 || isSending)
                }
            }
        }
    }

    private func contactRow(_ contact: ImportedContact) -> some View {
        let isSelected = selectedIDs.contains(contact.email)
        return HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? .blue : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.matchedUser?.displayName ?? contact.name)
                    .font(.subheadline.weight(.medium))
                Text(contact.email).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("On CalendarSync")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(.green)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectedIDs.contains(contact.email) {
                selectedIDs.remove(contact.email)
            } else {
                selectedIDs.insert(contact.email)
            }
        }
    }

    // MARK: - Import Logic

    private func importFromPhoneContacts(source: ImportedContact.ContactSource) {
        isImporting = true
        Task {
            let store = CNContactStore()
            let authorized: Bool
            if #available(iOS 18.0, *) {
                authorized = try await store.requestAccess(for: .contacts)
            } else {
                authorized = try await withCheckedThrowingContinuation { cont in
                    store.requestAccess(for: .contacts) { granted, error in
                        if let error { cont.resume(throwing: error) }
                        else { cont.resume(returning: granted) }
                    }
                }
            }

            guard authorized else {
                isImporting = false
                return
            }

            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactEmailAddressesKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var imported: [ImportedContact] = []

            try store.enumerateContacts(with: request) { cnContact, _ in
                let name = "\(cnContact.givenName) \(cnContact.familyName)".trimmingCharacters(in: .whitespaces)
                for email in cnContact.emailAddresses {
                    let addr = email.value as String
                    imported.append(ImportedContact(name: name.isEmpty ? addr : name, email: addr.lowercased(), source: source))
                }
            }

            // Deduplicate by email
            var seen = Set<String>()
            imported = imported.filter { seen.insert($0.email).inserted }

            // Look up which emails exist on CalendarSync
            let emails = imported.map(\.email)
            let matchedUsers = (try? await service.findUsers(byEmails: emails)) ?? []
            let matchMap = Dictionary(uniqueKeysWithValues: matchedUsers.map { ($0.email, $0) })

            for i in imported.indices {
                imported[i].matchedUser = matchMap[imported[i].email]
            }

            // Auto-select matched
            let autoSelect = Set(imported.filter { $0.matchedUser != nil }.map(\.email))

            contacts = imported.sorted { ($0.matchedUser != nil ? 0 : 1) < ($1.matchedUser != nil ? 0 : 1) }
            selectedIDs = autoSelect
            showSourcePicker = false
            isImporting = false
        }
    }

    // MARK: - Send

    private func sendRequests() {
        guard let uid = auth.currentUser?.id else { return }
        isSending = true
        Task {
            let toSend = contacts.filter { $0.matchedUser != nil && selectedIDs.contains($0.email) }
            for contact in toSend {
                guard let targetID = contact.matchedUser?.id else { continue }
                try? await service.sendFriendRequest(fromID: uid, toID: targetID)
            }
            HapticFeedback.success()
            didSend = true
            await friends.load()
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}
