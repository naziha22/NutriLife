import SwiftUI

struct SplashView: View {
    @State private var showText = false
    var body: some View {
        ZStack {
            LinearGradient(colors: [AppColor.green, AppColor.greenDark], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            VStack(spacing: 22) {
                LogoView(size: 160, onDark: true)
                AnimatedTitle(text: "NutriLife", highlightFrom: 5)
                Text(L("splash.tagline")).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    .opacity(showText ? 1 : 0).offset(y: showText ? 0 : 10)
                ProgressView().tint(.white).padding(.top, 16).opacity(showText ? 1 : 0)
            }
        }
        .onAppear { withAnimation(.easeOut(duration: 0.6).delay(1.8)) { showText = true } }
    }
}

struct AuthFlowView: View {
    @EnvironmentObject var auth: AuthViewModel
    @State private var showRegister = false
    var body: some View {
        ZStack {
            if showRegister {
                RegisterView { withAnimation(.easeInOut) { auth.clearMessages(); showRegister = false } }
                    .transition(.move(edge: .trailing))
            } else {
                LoginView { withAnimation(.easeInOut) { auth.clearMessages(); showRegister = true } }
                    .transition(.move(edge: .leading))
            }
        }
    }
}

private struct AuthHeader: View {
    let title: String; let subtitle: String
    var body: some View {
        VStack(spacing: 10) {
            LogoView(size: 92)
            Text(title).font(.system(size: 28, weight: .bold, design: .rounded))
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.padding(.top, 30)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.red)
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct LoginView: View {
    @EnvironmentObject var auth: AuthViewModel
    var onSwitch: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var submitted = false
    @State private var showForgot = false

    private var emailError: String? { submitted ? Validator.email(email) : nil }
    private var passwordError: String? { submitted ? (password.isEmpty ? L("val.password.required") : nil) : nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AuthHeader(title: L("auth.login.title"), subtitle: L("auth.login.subtitle"))
                AppTextField(title: L("auth.email"), icon: "envelope", text: $email, error: emailError, keyboard: .emailAddress)
                AppTextField(title: L("auth.password"), icon: "lock", text: $password, isSecure: true, error: passwordError)
                HStack { Spacer(); Button(L("auth.forgot")) { showForgot = true }.font(.footnote.weight(.semibold)).foregroundStyle(AppColor.accent) }
                if let m = auth.errorMessage { ErrorBanner(message: m) }
                CustomButton(title: L("auth.login.button"), icon: "arrow.right.circle.fill", isLoading: auth.isLoading) {
                    submitted = true
                    guard Validator.email(email) == nil, !password.isEmpty else { return }
                    Task { await auth.signIn(email: email, password: password) }
                }
                HStack { Rectangle().frame(height: 1).opacity(0.15); Text(L("auth.or")).font(.footnote).foregroundStyle(.secondary); Rectangle().frame(height: 1).opacity(0.15) }
                CustomButton(title: L("auth.google"), icon: "g.circle.fill", style: .secondary) { Task { await auth.signInWithGoogle() } }
                HStack(spacing: 4) {
                    Text(L("auth.noaccount")).foregroundStyle(.secondary)
                    Button(L("auth.signup.link"), action: onSwitch).fontWeight(.bold).foregroundStyle(AppColor.green)
                }.font(.subheadline).padding(.top, 8)
            }.padding(.horizontal, 24).animation(.easeOut(duration: 0.25), value: auth.errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColor.background.ignoresSafeArea())
        .sheet(isPresented: $showForgot) { ForgotPasswordSheet(initialEmail: email).presentationDetents([.medium]) }
    }
}

struct RegisterView: View {
    @EnvironmentObject var auth: AuthViewModel
    var onSwitch: () -> Void
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var submitted = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AuthHeader(title: L("auth.register.title"), subtitle: L("auth.register.subtitle"))
                AppTextField(title: L("auth.name"), icon: "person", text: $name, error: submitted ? Validator.name(name) : nil)
                AppTextField(title: L("auth.email"), icon: "envelope", text: $email, error: submitted ? Validator.email(email) : nil, keyboard: .emailAddress)
                AppTextField(title: L("auth.password"), icon: "lock", text: $password, isSecure: true, error: submitted ? Validator.password(password) : nil)
                AppTextField(title: L("auth.confirm"), icon: "lock.rotation", text: $confirm, isSecure: true, error: submitted ? Validator.confirm(password, confirm) : nil)
                if let m = auth.errorMessage { ErrorBanner(message: m) }
                CustomButton(title: L("auth.register.button"), icon: "person.badge.plus", style: .accent, isLoading: auth.isLoading) {
                    submitted = true
                    guard Validator.name(name) == nil, Validator.email(email) == nil,
                          Validator.password(password) == nil, Validator.confirm(password, confirm) == nil else { return }
                    Task { await auth.register(name: name, email: email, password: password) }
                }
                CustomButton(title: L("auth.google"), icon: "g.circle.fill", style: .secondary) { Task { await auth.signInWithGoogle() } }
                HStack(spacing: 4) {
                    Text(L("auth.hasaccount")).foregroundStyle(.secondary)
                    Button(L("auth.signin.link"), action: onSwitch).fontWeight(.bold).foregroundStyle(AppColor.green)
                }.font(.subheadline).padding(.top, 8)
            }.padding(.horizontal, 24).animation(.easeOut(duration: 0.25), value: auth.errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppColor.background.ignoresSafeArea())
    }
}

struct ForgotPasswordSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State var initialEmail: String
    @State private var email = ""
    @State private var submitted = false
    @State private var sent = false

    var body: some View {
        VStack(spacing: 16) {
            Text(L("auth.forgot.title")).font(.title3.bold()).padding(.top, 24)
            Text(L("auth.forgot.message")).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            AppTextField(title: L("auth.email"), icon: "envelope", text: $email, error: submitted ? Validator.email(email) : nil, keyboard: .emailAddress)
            if sent { Label(L("auth.forgot.sent"), systemImage: "checkmark.circle.fill").foregroundStyle(AppColor.green).font(.footnote) }
            if let m = auth.errorMessage, !sent { Text(m).font(.footnote).foregroundStyle(.red) }
            CustomButton(title: sent ? L("common.close") : L("auth.forgot.send"), isLoading: auth.isLoading) {
                if sent { dismiss(); return }
                submitted = true
                guard Validator.email(email) == nil else { return }
                Task { sent = await auth.resetPassword(email: email) }
            }
            Spacer()
        }.padding(.horizontal, 24).onAppear { email = initialEmail; auth.clearMessages() }
    }
}
