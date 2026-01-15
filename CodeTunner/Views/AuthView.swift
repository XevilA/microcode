//
//  AuthView.swift
//  CodeTunner
//
//  Login/Register UI with Google and Email
//
//  SPU AI CLUB - Dotmini Software
//

import SwiftUI

struct AuthView: View {
    @StateObject private var authService = AuthService.shared
    @State private var isLogin = true
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Logo
                    logoView
                    
                    // Auth Form
                    formView
                    
                    // Social Login
                    socialLoginView
                    
                    // Toggle Login/Register
                    toggleView
                }
                .padding(32)
            }
        }
        .frame(width: 450, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(isLogin ? "Welcome Back" : "Create Account")
                .font(.title2.bold())
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
    
    private var logoView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("IDX Cloud")
                .font(.title.bold())
            
            Text("Collaborate in real-time with your team")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var formView: some View {
        VStack(spacing: 16) {
            // Display Name (Register only)
            if !isLogin {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Your name", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            // Email
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("your@email.com", text: $email)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Password
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("••••••••", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Confirm Password (Register only)
            if !isLogin {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirm Password")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    SecureField("••••••••", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            // Submit Button
            Button {
                Task { await submitForm() }
            } label: {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isLogin ? "Sign In" : "Create Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(authService.isLoading || !isFormValid)
        }
    }
    
    private var socialLoginView: some View {
        VStack(spacing: 16) {
            // Divider with text
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or continue with")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            
            // Google Sign-In
            Button {
                Task { await signInWithGoogle() }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill")
                        .font(.title2)
                    Text("Continue with Google")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            
            // Apple Sign-In
            Button {
                // Apple Sign-In
            } label: {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title2)
                    Text("Continue with Apple")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var toggleView: some View {
        HStack {
            Text(isLogin ? "Don't have an account?" : "Already have an account?")
                .foregroundColor(.secondary)
            Button(isLogin ? "Sign Up" : "Sign In") {
                withAnimation {
                    isLogin.toggle()
                    clearForm()
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .font(.subheadline)
    }
    
    private var isFormValid: Bool {
        if isLogin {
            return !email.isEmpty && !password.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty && !displayName.isEmpty && password == confirmPassword
        }
    }
    
    private func submitForm() async {
        do {
            if isLogin {
                try await authService.signInWithEmail(email: email, password: password)
            } else {
                try await authService.signUpWithEmail(email: email, password: password, displayName: displayName)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func signInWithGoogle() async {
        do {
            try await authService.signInWithGoogle()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        displayName = ""
    }
}

// MARK: - User Profile View

struct UserProfileView: View {
    @ObservedObject var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            if let user = authService.currentUser {
                // Avatar
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(user.displayName.prefix(1).uppercased())
                            .font(.title.bold())
                            .foregroundColor(.white)
                    )
                
                // User Info
                VStack(spacing: 8) {
                    Text(user.displayName)
                        .font(.title2.bold())
                    Text(user.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Badges
                    HStack(spacing: 8) {
                        if user.isEarlyAccess {
                            Label("Early Access", systemImage: "star.fill")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                        
                        if user.isPremium {
                            Label("Premium", systemImage: "crown.fill")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.purple.opacity(0.2))
                                .foregroundColor(.purple)
                                .cornerRadius(8)
                        }
                    }
                }
                
                Divider()
                
                // Stats
                HStack(spacing: 32) {
                    VStack {
                        Text("0")
                            .font(.title2.bold())
                        Text("Projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack {
                        Text("0")
                            .font(.title2.bold())
                        Text("Collaborations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sign Out
                Button {
                    authService.signOut()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding(32)
        .frame(width: 350, height: 450)
    }
}

#Preview {
    AuthView()
}
