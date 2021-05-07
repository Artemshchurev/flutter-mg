import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_masked_text/flutter_masked_text.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:ortus/core.dart';
import 'package:ortus/ui/custom-app-bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ortus/ui/preloader/preloader.dart';
import './login_model.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({ Key key }) : super(key: key);

  static const String routeName = '/login';

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

const PHONE_LENGTH = 12;
const ENTER_PAGE = 0;
const REGISTRATION_PAGE = 1;
const SMS_CODE_LENGTH = 4;

class _LoginScreenState extends State<LoginScreen> {
  String authPhone = '';
  String registrationPhone = '';
  String password = '';
  bool isHiddenPassword = true;
  double currentPage = 0;
  String smsCode = '';
  int confirmationKeySecondsLeft = 0;
  Timer timer;

  MaskedTextController authPhoneController = MaskedTextController(mask: '+7 (000) 000-00-00');
  MaskedTextController registrationPhoneController = MaskedTextController(mask: '+7 (000) 000-00-00');
  TextEditingController passwordController = TextEditingController();
  TextEditingController registrationCodeController = TextEditingController();

  FocusNode passwordFocusNode;

  @override
  void initState() {
    super.initState();
    authPhoneController.beforeChange = (String previous, String next) {
      if (previous.length == 0 && next.length == (PHONE_LENGTH - 1) && next[0] == '8') {
        authPhoneController.updateText('+7' + next.substring(1));
      }
      return true;
    };

    registrationPhoneController.beforeChange = (String previous, String next) {
      if (previous.length == 0 && next.length == (PHONE_LENGTH - 1) && next[0] == '8') {
        registrationPhoneController.updateText('+7' + next.substring(1));
      }
      return true;
    };
    passwordController.addListener(() {
      final store = StoreProvider.of<AppState>(context);
      store.dispatch(ResetAuthError());
      setState(() {
        password = passwordController.text;
      });
    });

    authPhoneController.addListener(() {
      final store = StoreProvider.of<AppState>(context);
      String text = authPhoneController.text.replaceAll(new RegExp(r'[^0-9+]'), '');

      if (text != authPhone) {
        if (text == '+78' && authPhone.length < 2) {
          text = '+7';
          authPhoneController.text = text;
        }
        if (text.length == PHONE_LENGTH && password.length == 0) {
          passwordFocusNode.requestFocus();
        }
        store.dispatch(ResetAuthError());
        setState(() {
          authPhone = text;
        });
      }
    });

    registrationPhoneController.addListener(() {
      final store = StoreProvider.of<AppState>(context);
      String text = registrationPhoneController.text.replaceAll(new RegExp(r'[^0-9+]'), '');
      if (text == '+78' && registrationPhone.length < 2) {
        text = '+7';
        registrationPhoneController.text = text;
      }
      store.dispatch(ResetRegistrationError());
      setState(() {
        registrationPhone = text;
      });
    });

    passwordFocusNode = FocusNode();
  }

  @override
  void dispose() {
    // Clean up the focus node when the Form is disposed.
    passwordFocusNode.dispose();
    if (timer != null) {
      timer.cancel();
    }

    authPhoneController.dispose();
    registrationPhoneController.dispose();
    passwordController.dispose();
    registrationCodeController.dispose();
    super.dispose();
  }

  bool isNextButtonEnabled() => authPhone.length == PHONE_LENGTH && password.length > 0;

  void setPage(int pageIndex) {
    pageViewController.animateToPage(pageIndex,
        duration: Duration(milliseconds: 500), curve: Curves.ease);
  }

  resetError() {
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(ResetError());
  }

  void resetRegistrationConfirmError() {
    final store = StoreProvider.of<AppState>(context);
    if (store.state.authState.registrationConfirmError != null) {
      StoreProvider.of<AppState>(context).dispatch(ResetRegistrationConfirmError());
    }
  }

  registration(bool fetching) {
    final store = StoreProvider.of<AppState>(context);
    if (registrationPhone.length == PHONE_LENGTH && !fetching && confirmationKeySecondsLeft == 0) {
      setState(() {
        confirmationKeySecondsLeft = 60;
      });
      timer = Timer.periodic(new Duration(seconds: 1), (_timer) {
        setState(() {
          confirmationKeySecondsLeft--;
        });
        if (confirmationKeySecondsLeft == 0) {
          _timer.cancel();
        }
      });
      store.dispatch(Registration(registrationPhone));
    }
  }

  registrationConfirm(bool fetching) {
    final store = StoreProvider.of<AppState>(context);

    if (smsCode.length != 0 && !fetching) {
      store.dispatch(RegistrationConfirm(smsCode));
    }
  }

  resetRegistrationConfirmation(bool fetching) {
    if (!fetching) {
      final store = StoreProvider.of<AppState>(context);
      store.dispatch(ResetRegistrationConfirmKey());
    }
  }

  auth(bool fetching) {
    final store = StoreProvider.of<AppState>(context);

    if (authPhone.length == PHONE_LENGTH && password != '' && !fetching) {
      store.dispatch(Auth(authPhone, password));
    }

    if (authPhone.length != PHONE_LENGTH) {
      store.dispatch(SetAuthError(''));
    }
  }

  PageController pageViewController = PageController();

  @override
  Widget build(BuildContext context) {
    return new StoreConnector<AppState, AuthModel>(
        key: ValueKey('StoreConnectorInLogin'),
        distinct: true,
        onInitialBuild: (props) {
          resetError();
          if (props.isAuth) {
            //Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
            Navigator.pushReplacementNamed(context, '/');
          }
        },
        onWillChange: (prevProps, props) {
          if (props.isAuth) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          }
        },
        converter: (store) {
          return AuthModel(
              isAuth: store.state.authState.user != null &&
                  store.state.authState.user.id != null,
              authError: store.state.authState.authError ?? '',
              registrationError: store.state.authState.registrationError ?? '',
              registrationConfirmError: store.state.authState.registrationConfirmError ?? '',
              fetching: store.state.hangarState.fetching[Auth.fetchingLabel] == true ||
                  store.state.hangarState.fetching['registration'] == true,
              clientId: store.state.authState.clientId ?? null,
              registrationConfirmKey: store.state.authState.registrationConfirmKey ?? null
          );
        },
        onDispose: (store) {
          store.dispatch(ClearAjaxError());
        },
        builder: (context, AuthModel props) {
          final vw = MediaQuery.of(context).size.width / 100;
          final TextStyle barTextStyle =
          TextStyle(fontWeight: FontWeight.w600, fontSize: 5 * vw);
          final inputBorder = OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: new BorderRadius.all(Radius.circular(vw * 27.7)));
          pageViewController.addListener(() {
            if (MediaQuery.of(context).viewInsets.bottom != 0.0) {
              FocusScope.of(context).unfocus();
            }
            setState(() {
              currentPage = pageViewController.page;
            });
          });

          return Scaffold(
            appBar: CustomAppBar(
              automaticallyImplyLeading: false,
              title: OrtusLogo(width: MediaQuery.of(context).size.width * 0.27),
            ),
            backgroundColor: const Color(0xffF6F7F9),

            body: Stack(
              children: <Widget>[
                SafeArea(
                  child: Column(
                    children: <Widget>[
                      Container(
                        width: 72.5 * vw,
                        child: Stack(
                          children: <Widget>[
                            Padding(
                              padding:
                              EdgeInsets.only(top: 7.7 * vw, bottom: 2.23 * vw),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  GestureDetector(
                                    onTap: () => setPage(ENTER_PAGE),
                                    child: Text('Вход', style: barTextStyle),
                                  ),
                                  GestureDetector(
                                    onTap: () => setPage(REGISTRATION_PAGE),
                                    child: Text('Регистрация', style: barTextStyle),
                                  )
                                ],
                              ),
                            ),
                            AnimatedPositioned(
                              duration: Duration(milliseconds: 100),
                              left: currentPage * 40 * vw,
                              bottom: 0,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                color: const Color(0xFF6B67DF),
                                width: currentPage < 0.5 ? 13.3 * vw : 35.8 * vw,
                                height: 0.83 * vw,
                              ),
                            )
                          ],
                        ),
                      ),
                      Expanded(child: PageView(
                        controller: pageViewController,
                        children: <Widget>[
                          SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  top: 16.6 * vw, left: 3.8 * vw, right: 3.8 * vw),
                              child: Container(
                                child: Column(
                                  children: <Widget>[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            left: 1.9 * vw, bottom: 5.3 * vw),
                                        child: Text(
                                          'Введите номер телефона и пароль',
                                          style: TextStyle(
                                              fontSize: 3.9 * vw,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 5.3 * vw),
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        controller: authPhoneController,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 3.9 * vw
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Телефон',
                                          hintStyle: TextStyle(
                                              color: const Color(0xFF979797)
                                          ),
                                          contentPadding: EdgeInsets.only(left: 5.8 * vw),
                                          border: InputBorder.none,
                                          fillColor: Colors.white,
                                          filled: true,
                                          enabledBorder: inputBorder,
                                          focusedBorder: inputBorder,
                                        ),
                                      ),
                                    ),
                                    TextField(
                                      obscureText: isHiddenPassword,
                                      controller: passwordController,
                                      focusNode: passwordFocusNode,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 3.9 * vw
                                      ),
                                      decoration: InputDecoration(
                                          hintText: 'Пароль',
                                          hintStyle: TextStyle(
                                              color: const Color(0xFF979797)
                                          ),
                                          contentPadding:
                                          EdgeInsets.only(left: 5.8 * vw),
                                          border: InputBorder.none,
                                          fillColor: Colors.white,
                                          filled: true,
                                          enabledBorder: inputBorder,
                                          focusedBorder: inputBorder,
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                isHiddenPassword =
                                                !isHiddenPassword;
                                              });
                                            },
                                            icon: SvgPicture.asset(
                                              'assets/auth/eye.svg',
                                              color: isHiddenPassword
                                                  ? const Color(0xFFC4C4C8)
                                                  : const Color(0xFF6B67DF),
                                            ),
                                          )),
                                    ),
                                    Visibility(
                                      visible: props.authError.length > 0,
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 1.7 * vw, left: 5.8 * vw, right: 5.8 * vw),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          // alignment: Alignment.topLeft,
                                          children: <Widget>[
                                            Padding(
                                              padding: EdgeInsets.only(top: 1 * vw),
                                              child: SvgPicture.asset(
                                                'assets/auth/danger.svg',
                                                width: 3.6 * vw,
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsets.only(left: 2 * vw),
                                                child: Text(
                                                  props.authError,
                                                  style: TextStyle(
                                                    fontSize: 3.3 * vw,
                                                    color: const Color(0xFFEB5757),
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(top: 5.3 * vw),
                                      child: GestureDetector(
                                        onTap: () {
                                          Navigator.pushNamed(
                                              context,
                                              '/password-recovery',
                                              arguments: authPhone
                                          );
                                        },
                                        child: Text(
                                          'Я забыл пароль',
                                          style: TextStyle(
                                            fontSize: 3.3 * vw,
                                            color: const Color(0xFF0078FF),
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(top: 5 * vw),
                                      child: SizedBox(
                                        width: 66.1 * vw,
                                        height: 12.2 * vw,
                                        child: FlatButton(
                                          child: Text(
                                            'Далее',
                                            style: TextStyle(
                                                fontSize: 5 * vw,
                                                color: Colors.white),
                                          ),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(7 * vw)),
                                          color: const Color(0xFF6B67DF),
                                          disabledColor: const Color(0xFFC4C4C8),
                                          textColor: Colors.white,
                                          onPressed:
                                          isNextButtonEnabled() ? () => auth(props.fetching) : null,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  top: 16.6 * vw, left: 3.8 * vw, right: 3.8 * vw),
                              child: Container(
                                child: Column(
                                  children: <Widget>[
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            left: 1.9 * vw, bottom: 5.3 * vw),
                                        child: Text(
                                          'Введите номер телефона',
                                          style: TextStyle(
                                              fontSize: 3.9 * vw,
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                    Stack(
                                      alignment: Alignment.centerRight,
                                      children: <Widget>[
                                        TextField(
                                            enabled: props.registrationConfirmKey == null,
                                            controller: registrationPhoneController,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              hintText: 'Телефон',
                                              hintStyle: TextStyle(
                                                  color: const Color(0xFF979797)
                                              ),
                                              contentPadding: EdgeInsets.only(left: 5.8 * vw),
                                              border: InputBorder.none,
                                              fillColor: props.registrationConfirmKey == null ? Colors.white : const Color(0xFFE5E5E5),
                                              filled: true,
                                              enabledBorder: inputBorder,
                                              disabledBorder: inputBorder,
                                              focusedBorder: inputBorder,
                                            ),
                                            style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 3.9 * vw)
                                        ),
                                        Visibility(
                                          visible: props.registrationConfirmKey != null,
                                          child: IconButton(
                                            onPressed: () {
                                              resetRegistrationConfirmError();
                                              resetRegistrationConfirmation(props.fetching);
                                              registrationPhoneController.text = '';
                                              registrationCodeController.text = '';
                                              setState(() {
                                                confirmationKeySecondsLeft = 0;
                                              });
                                              timer.cancel();
                                            },
                                            icon: SvgPicture.asset(
                                                'assets/auth/cross.svg'
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                    Visibility(
                                      visible: props.registrationError.length > 0,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            top: 1.7 * vw,
                                            bottom: 6.4 * vw
                                        ),
                                        child: Stack(
                                          alignment: Alignment.centerLeft,
                                          children: <Widget>[
                                            SvgPicture.asset(
                                              'assets/auth/danger.svg',
                                              width: 3.6 * vw,
                                            ),
                                            Padding(
                                              padding: EdgeInsets.only(left: 5.6 * vw),
                                              child: Text(
                                                props.registrationError,
                                                style: TextStyle(
                                                    fontSize: 3.3 * vw,
                                                    color: const Color(0xFFEB5757)
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                    ),
                                    Visibility(
                                      visible: props.registrationConfirmKey != null,
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 5.3 * vw),
                                        child: TextField(
                                          controller: registrationCodeController,
                                          maxLength: SMS_CODE_LENGTH,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            counterText: '',
                                            hintText: 'Код доступа',
                                            hintStyle: TextStyle(
                                                color: const Color(0xFF979797)
                                            ),
                                            contentPadding: EdgeInsets.only(left: 5.8 * vw),
                                            border: InputBorder.none,
                                            fillColor: Colors.white,
                                            filled: true,
                                            enabledBorder: inputBorder,
                                            focusedBorder: inputBorder,
                                          ),
                                          onChanged: (text) {
                                            resetRegistrationConfirmError();
                                            setState(() {
                                              smsCode = text;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    Visibility(
                                      visible: props.registrationConfirmError != '',
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 3.9 * vw),
                                        child: Text(
                                          props.registrationConfirmError,
                                          style: TextStyle(
                                              fontSize: 3.3 * vw,
                                              color: const Color(0xFFEB5757)
                                          ),
                                        ),
                                      ),
                                    ),
                                    Visibility(
                                      visible: props.registrationConfirmKey != null,
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            top: 3.9 * vw,
                                            bottom: 6.4 * vw
                                        ),
                                        child: GestureDetector(
                                          onTap: () => registration(props.fetching),
                                          child: Text(
                                            confirmationKeySecondsLeft == 0
                                                ? 'Выслать код повторно'
                                                : 'Выслать код повторно (через $confirmationKeySecondsLeft сек)',
                                            style: TextStyle(
                                                color: const Color(0xFF6B67DF),
                                                fontSize: 3.3 * vw
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                          top: props.registrationError.length > 0 || props.registrationConfirmKey != null
                                              ? 0
                                              : 12.8 * vw
                                      ),
                                      child: SizedBox(
                                        width: 66.1 * vw,
                                        height: 12.2 * vw,
                                        child: FlatButton(
                                          child: Text(
                                            props.registrationConfirmKey == null
                                                ? 'Получить код'
                                                : 'Подтвердить телефон',
                                            style: TextStyle(
                                                fontSize: 5 * vw,
                                                color: Colors.white
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                              BorderRadius.circular(7 * vw)),
                                          color: const Color(0xFF6B67DF),
                                          disabledColor: const Color(0xFFC4C4C8),
                                          textColor: Colors.white,
                                          onPressed: props.registrationConfirmKey == null
                                              ? registrationPhone.length == PHONE_LENGTH
                                              ? () => registration(props.fetching)
                                              : null
                                              : smsCode.length == SMS_CODE_LENGTH
                                              ? () => registrationConfirm(props.fetching)
                                              : null,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          )
                        ],
                      )),
                    ],
                  ),
                ),
                Preloader(props.fetching)
              ],
            ),
          );
        });
  }
}
