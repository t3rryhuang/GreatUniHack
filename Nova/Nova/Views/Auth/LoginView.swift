import SwiftUI

/// Sign in and sign up. Ported from login.tsx.
struct LoginView: View {
    @Environment(AppModel.self) private var model
    @State private var viewModel = LoginViewModel()
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }

    var body: some View {
        NovaScreen {
            NovaLockup()
                .frame(maxWidth: .infinity)
                .padding(.top, Spacing.xxl)
                .padding(.bottom, Spacing.md)

            Text("See your spending before it happens.")
                .font(.novaSection)
                .foregroundStyle(NovaColor.heading)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Picker("Mode", selection: $viewModel.mode) {
                ForEach(LoginViewModel.Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                if viewModel.mode == .signUp {
                    field("Full name") {
                        TextField("Alex Taylor", text: $viewModel.name)
                            .textContentType(.name)
                            .focused($focus, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focus = .email }
                    }
                }
                field("Email") {
                    TextField("you@example.com", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                field("Password") {
                    SecureField("At least 6 characters", text: $viewModel.password)
                        .textContentType(viewModel.mode == .signIn ? .password : .newPassword)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit { Task { await viewModel.submit(model: model) } }
                }
            }

            if let error = viewModel.errorMessage {
                NovaNotice(kind: .error, title: "Couldn't sign in", message: error)
            }

            Button {
                focus = nil
                Task { await viewModel.submit(model: model) }
            } label: {
                if viewModel.isWorking { ProgressView().tint(NovaColor.onAction) } else { Text(viewModel.mode.rawValue) }
            }
            .buttonStyle(.novaPrimary)
            .disabled(!viewModel.canSubmit || viewModel.isWorking)
            .padding(.top, Spacing.xs)

            Text("Demo mode: any email and a password of 6 or more characters will work.")
                .font(.novaCaption)
                .foregroundStyle(NovaColor.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(label).font(.novaCallout.weight(.semibold)).foregroundStyle(NovaColor.heading)
            content().novaField()
        }
    }
}
