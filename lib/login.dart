import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import "dart:io";

class LoginUser {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn();

  String name;

  Future<String> signInWithGoogle() async {

    final GoogleSignInAccount googleSignInAccount = await googleSignIn.signIn();
    final GoogleSignInAuthentication googleSignInAuthentication =
        await googleSignInAccount.authentication;

    final AuthCredential credential = GoogleAuthProvider.getCredential(
      accessToken: googleSignInAuthentication.accessToken,
      idToken: googleSignInAuthentication.idToken,
    );

  FirebaseUser user;
    
  if(Platform.isIOS){
    AuthResult auth = await _auth.signInWithEmailAndPassword(email: "paolo.tolentino@gmail.com", password: "siopaolo8974");
    FirebaseUser user = auth.user;
  } else {
    FirebaseUser user = (await _auth.signInWithCredential(credential)).user;
  }

  assert(!user.isAnonymous);
  assert(await user.getIdToken() != null);

  final FirebaseUser currentUser = await _auth.currentUser();
  assert(user.uid == currentUser.uid);

  name = user.email;
  if(name.contains(" ")){
    name = name.substring(0, name.indexOf(" "));
  }
  return name;
  }
}
