//
//  LoginView.swift
//  OCKSample
//
//  Created by Corey Baker on 10/29/20.
//  Copyright © 2020 Network Reconnaissance Lab. All rights reserved.
//

/*
 This is a variation of the tutorial found here:
 https://www.iosapptemplates.com/blog/swiftui/login-screen-swiftui
 */

import ParseSwift
import SwiftUI

/*
 Anything is @ is a wrapper that subscribes and refreshes
 the view when a change occurs. List to the last lecture
 in Section 2 for an explanation
 */
struct LoginView: View {
    @ObservedObject var viewModel: LoginViewModel
    @State var usersname = ""
    @State var email = ""
    @State var password = ""
    @State var firstName: String = ""
    @State var lastName: String = ""
    @State var signupLoginSegmentValue = 0
    // modify:Add the color scheme you want for your app
    private let backgroundTopColor = Color(red: 1.00, green: 0.97, blue: 0.90)
    private let backgroundMiddleColor = Color(red: 0.99, green: 0.90, blue: 0.76)
    private let backgroundBottomColor = Color(red: 0.95, green: 0.82, blue: 0.67)
    private let segmentBackgroundColor = Color(red: 0.78, green: 0.87, blue: 0.72)
    private let textFieldBackgroundColor = Color(red: 1.00, green: 0.99, blue: 0.96)
    private let titleColor = Color(red: 0.34, green: 0.23, blue: 0.18)
    private let primaryButtonColor = Color(red: 0.78, green: 0.45, blue: 0.24)
    private let secondaryButtonColor = Color(red: 0.42, green: 0.49, blue: 0.62)
    // modify:Add the color scheme you want for your app
    var body: some View {
        VStack {
            VStack(spacing: 10) {
                Image("heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90, alignment: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(titleColor.opacity(0.35), lineWidth: 2)
                    )
                    .shadow(color: titleColor.opacity(0.2), radius: 8, x: 0, y: 4)

                Text("APP_NAME")
                    .font(.largeTitle)
                    .foregroundColor(titleColor)
            }
            .padding(.top, 12)
            .padding(.bottom, 8)
            /*
             Example of how to do the picker here:
             https://www.swiftkickmobile.com/creating-a-segmented-control-in-swiftui/
             */
            Picker(selection: $signupLoginSegmentValue,
                   label: Text("LOGIN_PICKER")) {
                Text("LOGIN").tag(0)
                Text("SIGN_UP").tag(1)
            }
            .pickerStyle(.segmented)
            .background(segmentBackgroundColor)
            .cornerRadius(20.0)
            .padding()

            VStack(alignment: .leading) {
                TextField("USERNAME", text: $usersname)
                    .padding()
                    .background(textFieldBackgroundColor)
                    .cornerRadius(20.0)
                    .shadow(color: titleColor.opacity(0.12), radius: 8, x: 0, y: 4)
                SecureField("PASSWORD", text: $password)
                    .padding()
                    .background(textFieldBackgroundColor)
                    .cornerRadius(20.0)
                    .shadow(color: titleColor.opacity(0.12), radius: 8, x: 0, y: 4)

                switch signupLoginSegmentValue {
                case 1:
                    TextField("EMAIL", text: $email)
                        .padding()
                        .background(textFieldBackgroundColor)
                        .cornerRadius(20.0)
                        .shadow(color: titleColor.opacity(0.12), radius: 8, x: 0, y: 4)

                    TextField("GIVEN_NAME", text: $firstName)
                        .padding()
                        .background(textFieldBackgroundColor)
                        .cornerRadius(20.0)
                        .shadow(color: titleColor.opacity(0.12), radius: 8, x: 0, y: 4)

                    TextField("FAMILY_NAME", text: $lastName)
                        .padding()
                        .background(textFieldBackgroundColor)
                        .cornerRadius(20.0)
                        .shadow(color: titleColor.opacity(0.12), radius: 8, x: 0, y: 4)
                default:
                    EmptyView()
                }
            }.padding()

            /*
             Notice that "action" and "label" are closures
             (which is essentially afunction as argument
             like we discussed in class)
             */
            Button(action: {
                switch signupLoginSegmentValue {
                case 1:
                    Task {
                        await viewModel.signup(
                            .patient,
                            username: usersname,
                            email: email,
                            password: password,
                            firstName: firstName,
                            lastName: lastName
                        )
                    }
                default:
                    Task {
                        await viewModel.login(
                            username: usersname,
                            password: password
                        )
                    }
                }
            }, label: {
                switch signupLoginSegmentValue {
                case 1:
                    Text("SIGN_UP")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 300)
                default:
                    Text("LOGIN")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 300)
                }
            })
            .background(primaryButtonColor)
            .cornerRadius(15)

            Button(action: {
                Task {
                    await viewModel.loginAnonymously()
                }
            }, label: {
                switch signupLoginSegmentValue {
                case 0:
                    Text("LOGIN_ANONYMOUSLY")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(width: 300)
                default:
                    EmptyView()
                }
            })
            .background(secondaryButtonColor)
            .cornerRadius(15)

            // If an error occurs show it on the screen
            if let error = viewModel.loginError {
                Text("\(String(localized: "ERROR")): \(error.message)")
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .background(
            ZStack {
                LinearGradient(
                    gradient: Gradient(
                        colors: [
                            backgroundTopColor,
                            backgroundMiddleColor,
                            backgroundBottomColor
                            ]
                    ),
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(Color.white.opacity(0.45))
                    .frame(width: 220, height: 220)
                    .offset(x: -130, y: -320)
                    .blur(radius: 8)

                Circle()
                    .fill(Color(red: 0.87, green: 0.93, blue: 0.83).opacity(0.45))
                    .frame(width: 180, height: 180)
                    .offset(x: 150, y: -270)
                    .blur(radius: 12)

                Circle()
                    .fill(Color(red: 1.00, green: 0.89, blue: 0.84).opacity(0.35))
                    .frame(width: 260, height: 260)
                    .offset(x: 140, y: 420)
                    .blur(radius: 24)
            }
            .ignoresSafeArea()
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(viewModel: .init())
    }
}
