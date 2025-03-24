import 'dart:js';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import 'main.dart';
import 'map.dart';


class SnackBarService {
  static const errorColor = Colors.red;
  static const okColor = Colors.green;

  static Future<void> showSnackBar(
      BuildContext context, String message, bool error) async {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();

    final snackBar = SnackBar(
      content: Text(message),
      backgroundColor: error ? errorColor : okColor,
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}




class Registration extends StatefulWidget {
  @override
  State<Registration> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<Registration> {



  TextEditingController emailcontroller = TextEditingController();
  TextEditingController namecontroller=TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    emailcontroller.dispose();
    namecontroller.dispose();
    passwordcontroller.dispose();
  }
  bool showError = false;



  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void> signupemailpass(String email, String pass) async {
    await _auth.signInWithEmailAndPassword(email: email, password: pass);
  }


  Future<void> registerUser(String email, String password, String name, BuildContext context) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // After successful registration, UID is available from `userCredential.user`
      String uid = userCredential.user!.uid;
      await addUserToRealtimeDatabase(uid, name, email);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MapScreen(), // Replace with your next page
        ),
      );

    } on FirebaseAuthException catch (e) {
      // Handle registration errors
      if (e.code == 'weak-password') {
        SnackBarService.showSnackBar(context, 'Пароль слишком легкий.', true);
      } else if (e.code == 'email-already-in-use') {
        SnackBarService.showSnackBar(context, 'Аккаунт с такой эл. почтой уже существует.', true);
      }
    }
  }
  bool loading = false;
  void _startLoading() async {
    // Wait for 1 second
    await Future.delayed(Duration(seconds: 2));
    // Change the state to hide CircularProgressIndicator
    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }




  Future<void> addUserToRealtimeDatabase(String uid, String name, String email) async {
    Map<String, dynamic> userData = {
      'email': email,
      'name': namecontroller.text.trim(),
      'points': 0,
    };


    await FirebaseDatabase.instance.ref('users/$uid').set(userData);

  }


  final _formKey = GlobalKey<FormState>();


  bool isDesktop(BuildContext context) => MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;

  @override
  Widget build(BuildContext context) {
    return loading?Center(child: CircularProgressIndicator(),):Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        top: true,
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key:_formKey,
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                  ),
                  Row(
                    children: [
                      if (isDesktop(context))
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width:
                                MediaQuery.of(context).size.shortestSide / 2,
                                height:
                                MediaQuery.of(context).size.shortestSide / 2,
                                child: Container(
                                  width: 300,
                                  height: 230,
                                  decoration: BoxDecoration(color: Colors.white),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(67.0),
                                    child: Image.asset(
                                      'assets/logo.png',
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 10,),
                              Text(
                                'Добро пожаловать в EcoGis!',
                                style: TextStyle(fontFamily: "Futura"),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            if (!isDesktop(context))
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width:
                                    MediaQuery.of(context).size.shortestSide /
                                        2,
                                    height:
                                    MediaQuery.of(context).size.shortestSide /
                                        2,
                                    child: Container(

                                      width: 300,
                                      height: 230,
                                      decoration:
                                      BoxDecoration(color: Colors.white,),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(67.0),
                                        child: Image.asset(

                                          'assets/logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10,),

                                  Text(
                                    'Добро пожаловать на КупимВместе,\nсистему покупки товаров',
                                    style: TextStyle(fontFamily: 'Futura'),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            SizedBox(
                              height: 10,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Введите свое имя:',
                                    style: TextStyle(
                                      fontFamily: 'Futura',
                                      fontSize: 20,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Padding(
                                  padding:
                                  EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                                  child: Container(
                                    width: 450,
                                    height: 50,
                                    child: TextFormField(
                                      controller: namecontroller,
                                      textCapitalization: TextCapitalization.none,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor:
                                        Color.fromRGBO(46, 46, 93, 0.04),
                                        labelText: 'Имя',
                                        labelStyle: TextStyle(
                                          fontFamily: 'Futura',
                                          fontWeight: FontWeight.normal,
                                        ),
                                        floatingLabelStyle: TextStyle(
                                          fontFamily: 'Futura',
                                          fontWeight: FontWeight.normal,
                                          color: Colors.brown,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Futura',
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value ) {
                                        if (value == null || value.isEmpty  ) {
                                          return 'Пожалуйста введите свое имя';
                                        }
                                        return null; // means input is correct
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20,),
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Введите почту:',
                                    style: TextStyle(
                                      fontFamily: 'Futura',
                                      fontSize: 20,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                SizedBox(height: 10,),
                                Padding(
                                  padding:
                                  EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                                  child: Container(
                                    width: 450,
                                    height: 50,
                                    child: TextFormField(
                                      controller: emailcontroller,
                                      textCapitalization: TextCapitalization.none,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor:
                                        Color.fromRGBO(46, 46, 93, 0.04),
                                        labelText: 'Электронная почта',
                                        labelStyle: TextStyle(
                                          fontFamily: 'Futura',
                                          fontWeight: FontWeight.normal,
                                        ),
                                        floatingLabelStyle: TextStyle(
                                          fontFamily: 'Futura',
                                          fontWeight: FontWeight.normal,
                                          color: Colors.brown,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Futura',
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Введите эл почту';
                                        } else if (!value.contains('@')) {
                                          return 'Введите правильную эл почту';
                                        }
                                        return null; // means input is correct
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Text(
                                    'Введите пароль:',
                                    style: TextStyle(
                                      fontFamily: 'Futura',
                                      fontSize: 20,
                                    ),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                SizedBox(
                                  height: 10,
                                ),
                                Padding(
                                  padding:
                                  EdgeInsetsDirectional.fromSTEB(8, 0, 8, 0),
                                  child: Container(
                                    width: 450,
                                    height: 50,
                                    child: TextFormField(
                                      controller: passwordcontroller,
                                      textCapitalization: TextCapitalization.none,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor:
                                        Color.fromRGBO(46, 46, 93, 0.04),
                                        labelText: 'Пароль',
                                        labelStyle: TextStyle(
                                          fontFamily: 'Futura',
                                          fontWeight: FontWeight.normal,
                                        ),
                                        floatingLabelStyle: TextStyle(
                                          fontFamily: 'Futura',
                                          fontWeight: FontWeight.normal,
                                          color: Colors.brown,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.grey,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.black,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 1,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Colors.red,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(25),
                                        ),
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Futura',
                                        fontSize: 15,
                                        fontWeight: FontWeight.normal,
                                      ),
                                      keyboardType: TextInputType.visiblePassword,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Ввведите пароль';
                                        } else if (value.length < 6) {
                                          return 'Пароль должен быть минимум 6 символов в длину';
                                        }
                                        return null; // means input is correct
                                      },
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20,),
                              ],
                            ),
                            Padding(
                              padding:
                              EdgeInsetsDirectional.fromSTEB(0, 50, 0, 0),
                              child: SizedBox(
                                height: 50,
                                width: 300,
                                child: ElevatedButton(
                                  onPressed: () {
                                    if (_formKey.currentState!.validate() && !showError) {
                                      // Call your registration logic here
                                      registerUser(
                                        emailcontroller.text.trim(),
                                        passwordcontroller.text.trim(),
                                        namecontroller.text.trim(),
                                        context, // Pass the context here
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(horizontal: 24), // Replace with your desired button color
                                    elevation: 3,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Зарегестрироваться',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w100,
                                          fontFamily: 'Futura',
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 40,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25.0, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            thickness: 0.5,
                            color: Colors.grey[700],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.0),
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width / 2,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Если у вас есть аккаунт',
                                    softWrap: true,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                GestureDetector(
                                  child: Text(
                                    ' войдите ',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                  onTap: () {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (context) => MyHomePage()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            thickness: 0.5,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10,),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
