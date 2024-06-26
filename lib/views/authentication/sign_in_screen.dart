import 'package:farm/keys/route_keys.dart';
import 'package:farm/models/api/user/user_details.dart';
import 'package:farm/models/api/user/user_response.dart';
import 'package:farm/models/screen_args/verify_code_screen_args.dart';
import 'package:farm/services/user_service.dart';
import 'package:farm/styles/color_style.dart';
import 'package:farm/utility/auth_util.dart';
import 'package:farm/utility/loading_util.dart';
import 'package:farm/utility/pref_util.dart';
import 'package:farm/utility/toast_util.dart';
import 'package:farm/widgets/buttons/custom_rounded_button.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool isPhoneInputValid = false;
  String initialCountry = 'PK';
  PhoneNumber _phoneNumber = PhoneNumber(isoCode: 'PK');
  bool isLoadingPhoneButton = false;
  bool isLoadingGoogleButton = false;
  bool isLoadingFacebookButton = false;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  UserService userService = UserService();

  Future<String?> _getFcmToken() async {
    await _firebaseMessaging.requestPermission();
    return await _firebaseMessaging.getToken();
  }

  _signInWithPhone() async {
    if (_phoneNumber.phoneNumber != null) {
      setState(() {
        isLoadingPhoneButton = true;
      });
      await AuthUtil.verifyPhoneNumber(_phoneNumber.phoneNumber!,
          (userCredential) {
        if (userCredential != null) {
          String emailOrPhone = userCredential.user!.email != null
              ? userCredential.user!.email!
              : userCredential.user!.phoneNumber!;
          _signInToServer(userCredential.user!.uid, emailOrPhone);
        }
      }, (errorCode) {
        setState(() {
          isLoadingPhoneButton = false;
        });
        print(errorCode);
        switch (errorCode) {
          case "invalid-verification-code":
            ToastUtil.showToast("Please enter a valid code");
            break;
          case "invalid-credential":
            ToastUtil.showToast("Please enter a valid phone number");
            break;
          case "invalid-verification-id":
            ToastUtil.showToast("Verification failed, please try again");
            break;
          default:
            ToastUtil.showToast(errorCode);
            break;
        }
      }, (verificationId, resendToken) {
        setState(() {
          isLoadingPhoneButton = false;
        });
        Navigator.of(context).pushNamed(
          verifyCodeRoute,
          arguments: VerifyCodeScreenArgs(
            phoneNumber: _phoneNumber.phoneNumber ?? "",
            verificationId: verificationId,
            resendToken: resendToken,
          ),
        );
      }, (verificationId) {
        setState(() {
          isLoadingPhoneButton = false;
        });
        ToastUtil.showToast("Your request timed out, please try again later");
      });
    }
  }

  _moveToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil(homeRoute, (route) => false);
  }

  _signInToServer(String uid, String emailOrNumber) async {
    String? token = await _getFcmToken();
    userService.signInUser(uid, emailOrNumber, token).then((value) {
      setState(() {
        isLoadingFacebookButton = false;
        isLoadingGoogleButton = false;
        isLoadingPhoneButton = false;
      });
      if (value.error == null) {
        UserResponse userResponse = value.snapshot;
        if (userResponse.success ?? false) {
          UserDetails user = userResponse.data!.user!;
          _saveUserData(user);
          _moveToHome();
        } else {
          ToastUtil.showToast(userResponse.message ?? "");
        }
      } else {
        ToastUtil.showToast(value.error ?? "");
      }
    });
  }

  _saveUserData(UserDetails user) {
    PrefUtil().setUserId = user.fireUid ?? "";
    PrefUtil().setUserToken = user.authToken ?? "";
    PrefUtil().setUserPhoneOrEmail = user.phoneOrEmail ?? "";
    PrefUtil().setUserRole = user.role ?? "";
    PrefUtil().setUserLoggedIn = true;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: AbsorbPointer(
          absorbing: isLoadingPhoneButton ||
              isLoadingFacebookButton ||
              isLoadingGoogleButton,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: double.maxFinite,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ColorStyle.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 5,
                      blurRadius: 5,
                      offset: const Offset(1, 3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: SizedBox(
                            height: 200,
                            width: 200,
                            child: SvgPicture.asset(
                                "assets/svgs/login_image.svg")),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 5, horizontal: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: ColorStyle.lightTextColor, width: 0.5),
                        ),
                        child: InternationalPhoneNumberInput(
                          onInputChanged: (PhoneNumber number) {
                            setState(() {
                              _phoneNumber = number;
                            });
                          },
                          onInputValidated: (bool value) {
                            setState(() {
                              isPhoneInputValid = value;
                            });
                          },
                          selectorConfig: const SelectorConfig(
                            selectorType: PhoneInputSelectorType.DIALOG,
                            useBottomSheetSafeArea: true,
                          ),
                          spaceBetweenSelectorAndTextField: 0,
                          ignoreBlank: false,
                          cursorColor: ColorStyle.primaryColor,
                          textStyle:
                              const TextStyle(color: ColorStyle.textColor),
                          selectorTextStyle:
                              const TextStyle(color: ColorStyle.lightTextColor),
                          initialValue: _phoneNumber,
                          textFieldController: _phoneController,
                          inputDecoration: const InputDecoration(
                            border: InputBorder.none,
                          ),
                          formatInput: true,
                          keyboardType: const TextInputType.numberWithOptions(),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 55,
                        width: double.infinity,
                        child: CustomRoundedButton(
                          "Sign In",
                          () {
                            if (isPhoneInputValid) {
                              _signInWithPhone();
                            } else {
                              ToastUtil.showToast(
                                  "Please enter a valid phone number");
                            }
                          },
                          widgetButton: isLoadingPhoneButton
                              ? LoadingUtil.showInButtonLoader()
                              : null,
                          borderColor: ColorStyle.whiteColor,
                          buttonBackgroundColor: isPhoneInputValid
                              ? ColorStyle.secondaryPrimaryColor
                              : ColorStyle.secondaryPrimaryColor
                                  .withOpacity(0.3),
                          textColor: ColorStyle.whiteColor,
                          waterColor: ColorStyle.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: IntrinsicHeight(
                              child: Divider(
                                thickness: 1,
                                color: ColorStyle.lightTextColor,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              "OR",
                              style: TextStyle(
                                color: ColorStyle.lightTextColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: IntrinsicHeight(
                              child: Divider(
                                thickness: 1,
                                color: ColorStyle.lightTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildSocialSignOnButton('Google', () {
                        setState(() {
                          isLoadingGoogleButton = true;
                        });
                        AuthUtil.signInWithGoogle().then((userCredential) {
                          if (userCredential != null) {
                            String emailOrPhone =
                                userCredential.user!.email != null
                                    ? userCredential.user!.email!
                                    : userCredential.user!.phoneNumber!;
                            _signInToServer(
                                userCredential.user!.uid, emailOrPhone);
                          } else {
                            setState(() {
                              isLoadingGoogleButton = false;
                            });
                          }
                        });
                      }),
                      _buildSocialSignOnButton('Facebook', () {
                        setState(() {
                          isLoadingFacebookButton = true;
                        });
                        AuthUtil.signInWithFacebook().then((userCredential) {
                          if (userCredential != null) {
                            String emailOrPhone =
                                userCredential.user!.email != null
                                    ? userCredential.user!.email!
                                    : userCredential.user!.phoneNumber!;
                            _signInToServer(
                                userCredential.user!.uid, emailOrPhone);
                          }
                        });
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _buildSocialSignOnButton(String title, Function onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: SizedBox(
        height: 55,
        width: double.infinity,
        child: CustomRoundedButton(
          "",
          widgetButton: (title == "Google" && isLoadingGoogleButton) ||
                  (title == "Facebook" && isLoadingFacebookButton)
              ? Center(child: LoadingUtil.showInButtonLoader())
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 30,
                        width: 30,
                        child: Image.asset(
                            "assets/pngs/${title.toLowerCase()}.png"),
                      ),
                      //SizedBox(width: 20),
                      Expanded(
                        child: Text(
                          "Sign In with $title",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: ColorStyle.whiteColor,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(
                        height: 30,
                        width: 30,
                      ),
                    ],
                  ),
                ),
          () {
            onTap();
          },
          borderColor: ColorStyle.primaryColor,
          buttonBackgroundColor: ColorStyle.secondaryPrimaryColor,
          waterColor: ColorStyle.primaryColor,
        ),
      ),
    );
  }
}
