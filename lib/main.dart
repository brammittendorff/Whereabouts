import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:whereabouts/login.dart';

void main(){
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      body: FireMap(),
    ));
  }
}

class FireMap extends StatefulWidget {
  _FireMapState createState() => _FireMapState();
}

class _FireMapState extends State<FireMap>{
  bool isFollowingUser = false;
  bool isFollowingPartner;

  String username;
  BitmapDescriptor markerIconUser;
  BitmapDescriptor markerIconPartner;

  Location location = new Location();
  LocationData userCurrentLocation;
  LocationData partnerCurrentLocation;

  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  MarkerId selectedMarker;
  int markerCount = 1;
  List markerIconList = List();

  GoogleMapController mapController;

  Firestore firestore = Firestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: LatLng(14.6972207, 121.036092), zoom: 20),
          onMapCreated: _onMapCreated,
          mapType: MapType.normal,
          myLocationButtonEnabled: false,
          onCameraMove: (_cameraLocation) {
            if (_cameraLocation !=
                CameraPosition(
                    target: LatLng(userCurrentLocation.latitude,
                        userCurrentLocation.longitude))) {
              _stopFollowing();
            }
          },
          markers: Set<Marker>.of(markers.values),
        ),
        Positioned(
          bottom: 80,
          right: 0,
          child: FlatButton(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.my_location,
                color: Colors.white,
                size: 30,
              ),
            ),
            shape: CircleBorder(),
            color: Colors.green,
            onPressed: () => _followUser(),
          ),
        ),
        Positioned(
          bottom: 140,
          right: 0,
          child: FlatButton(
            shape: CircleBorder(),
            color: Colors.green,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 30,
              ),
            ),
            onPressed: () => _addMarker(context),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 10,
          right: 10,
          child: MaterialButton(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
            color: Colors.amber,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Find Dearest!",
                style: TextStyle(fontSize: 22),
              ),
            ),
            onPressed: () => _followPartner(),
          ),
        )
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    //Wait for Sign In to Finish Before Tracking
    _loginUser().whenComplete(() {
      _getAssetIcon(context).whenComplete(() {
        markerIconUser = (username.contains("paolo"))
            ? markerIconList.elementAt(0)
            : markerIconList.elementAt(1);
        markerIconPartner = (username.contains("paolo"))
            ? markerIconList.elementAt(1)
            : markerIconList.elementAt(0);

        location.onLocationChanged().listen((pos) {
          userCurrentLocation = pos;
          _addUserLocation();
          _addPartnerLocation();
        });
        _startQuery();
      });
    });
    super.initState();
  }

  void _onMapCreated(GoogleMapController controller) async {
    userCurrentLocation = await location.getLocation();
    setState(() {
      mapController = controller;
      mapController.animateCamera(CameraUpdate.newLatLng(
          LatLng(userCurrentLocation.latitude, userCurrentLocation.longitude)));
    });
  }

  _loginUser() async {
    username = await LoginUser().signInWithGoogle();
  }

  _followUser() {
    setState(() {
      isFollowingUser = true;
    });
  }

  _followPartner() {
    setState(() {
      isFollowingPartner = true;
    });
  }

  _stopFollowing() {
    setState(() {
      isFollowingUser = false;
      isFollowingPartner = false;
    });
  }

  _addMarker(BuildContext context) async {
    List placeDescription = await _whereaboutsDescription(context);
    if (placeDescription != null) {
      var markerIdVal = 'marker_id_$markerCount';
      var markerId = MarkerId(markerIdVal);
      var marker = Marker(
          markerId: markerId,
          position: LatLng(
              userCurrentLocation.latitude, userCurrentLocation.longitude),
          icon: BitmapDescriptor.defaultMarker,
          infoWindow: InfoWindow(
            title: placeDescription.elementAt(0),
            snippet: placeDescription.elementAt(1),
            onTap: () => _onInfoWindowPressed(markerId),
          ));
      setState(() {
        markers[markerId] = marker;
      });
      _addGeoPoint(
          placeDescription.elementAt(0), placeDescription.elementAt(1));
    }
  }

  _removeMarker(MarkerId markerId) async {
    firestore
        .collection("locations")
        .where('placeReason',
            isEqualTo: markers[markerId].infoWindow.snippet.toString())
        .getDocuments()
        .then((snapshots) {
      snapshots.documents.forEach((document) {
        firestore.runTransaction((Transaction myTransaction) {
          return myTransaction.delete(document.reference);
        });
      });
    });
    setState(() {
      markers.remove(markerId);
    });
  }

  _onInfoWindowPressed(MarkerId markerId) async {
    showDialog(
        barrierDismissible: true,
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Remove Marker?"),
            content: Text("Do you wish to remove you this marker?"),
            actions: <Widget>[
              FlatButton(
                child: Text("Cancel"),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              FlatButton(
                  child: Text("Confirm"),
                  onPressed: () {
                    Navigator.of(context).pop(_removeMarker(markerId));
                  }),
            ],
          );
        });
  }

  void _updateMarker(List<DocumentSnapshot> documentList) {
    List<MarkerId> _markId = List();
    markers.forEach((id, marker) {
      if (id.toString().contains("paolo") ||
          id.toString().contains("madelyne")) {
      } else {
        _markId.add(id);
      }
    });

    _markId.forEach((id) {
      markers.remove(id);
    });

    documentList.forEach((DocumentSnapshot document) {
      var markerIdVal = "marker_id_$markerCount";
      var markerId = MarkerId(markerIdVal);
      GeoPoint pos = document.data['position']['geopoint'];
      var marker = Marker(
        markerId: markerId,
        position: LatLng(pos.latitude, pos.longitude),
        icon: BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
            title: document.data['placeName'],
            snippet: document.data['placeReason'],
            onTap: () {
              _onInfoWindowPressed(markerId);
            }),
      );
      markers[markerId] = marker;
      markerCount++;
    });
    setState(() {});
  }

  _startQuery() async {
    // print("Starting Query");
    // Make a referece to firestore
    var ref = firestore.collection('locations').where('name',
        isEqualTo: (username.contains("paolo")) ? "madelyne" : "paolo");
    ref.snapshots().listen((markerData) => _updateMarker(markerData.documents));
  }

  _addPartnerLocation() async {
    Map<String, double> locationMap = Map<String, double>();
    firestore
        .collection("users")
        .document((username.contains("paolo") ? "madelyne" : "paolo"))
        .snapshots()
        .listen((doc) {
      var markerIdVal = "marker_id_${doc.data['name']}";
      var markerId = MarkerId(markerIdVal);
      GeoPoint pos = doc.data['position']['geopoint'];

      locationMap['latitude'] = pos.latitude;
      locationMap['longitude'] = pos.longitude;

      partnerCurrentLocation = LocationData.fromMap(locationMap);
      var marker = Marker(
          markerId: markerId,
          icon: markerIconPartner,
          position: LatLng(pos.latitude, pos.longitude),
          infoWindow: InfoWindow.noText);

      if (isFollowingPartner) {
        mapController.animateCamera(
            CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
      }

      setState(() {
        markers[markerId] = marker;
      });
    });
  }

  _addUserLocation() async {
    var markerId = MarkerId('marker_id_$username');

    if (isFollowingUser) {
      print("following!");
      mapController.moveCamera(CameraUpdate.newLatLng(
          LatLng(userCurrentLocation.latitude, userCurrentLocation.longitude)));
    }

    setState(() {
      markers[markerId] = Marker(
        markerId: markerId,
        icon: markerIconUser,
        position:
            LatLng(userCurrentLocation.latitude, userCurrentLocation.longitude),
      );
    });

    GeoFirePoint point = geo.point(
        latitude: userCurrentLocation.latitude,
        longitude: userCurrentLocation.longitude);
    return firestore
        .collection('users')
        .document(username)
        .setData({'position': point.data});
  }

  Future<DocumentReference> _addGeoPoint(
      String placeName, String placeReason) async {
    var pos = await location.getLocation();
    GeoFirePoint point =
        geo.point(latitude: pos.latitude, longitude: pos.longitude);
    return firestore.collection('locations').add({
      'position': point.data,
      'name': username,
      'placeName': placeName,
      'placeReason': placeReason
    });
  }

  _getAssetIcon(
    BuildContext context,
  ) async {
    username = username.split(".").elementAt(0);
    BitmapDescriptor markerIcon;
    List userList = List();
    userList.add('assets/dearest_marker_male.png');
    userList.add('assets/dearest_marker_female.png');

    for (int i = 0; i < 2; i++) {
      final Completer<BitmapDescriptor> bitmapIcon =
          Completer<BitmapDescriptor>();
      final ImageConfiguration config = createLocalImageConfiguration(context);
      AssetImage(userList.elementAt(i))
          .resolve(config)
          .addListener(ImageStreamListener((ImageInfo image, bool sync) async {
        final ByteData bytes =
            await image.image.toByteData(format: ImageByteFormat.png);
        final BitmapDescriptor bitmap =
            BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
        bitmapIcon.complete(bitmap);
      }));
      markerIcon = await bitmapIcon.future;
      markerIconList.add(markerIcon);
    }

    return markerIconList;
  }

  Future<List> _whereaboutsDescription(BuildContext context) async {
    List placeDescription = List();
    var placeNameController = TextEditingController();
    var placeReasonController = TextEditingController();
    return showDialog<List>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("Where am I?"),
            content: Column(
              children: <Widget>[
                TextFormField(
                  controller: placeNameController,
                  autofocus: true,
                  maxLines: 1,
                  decoration: InputDecoration(
                      alignLabelWithHint: true,
                      labelText: 'Place Name',
                      hintText: 'What is this placed called'),
                ),
                TextFormField(
                  controller: placeReasonController,
                  autofocus: true,
                  decoration: InputDecoration(
                    alignLabelWithHint: true,
                    labelText: 'Place Description',
                    hintText: 'Why are you here?',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              FlatButton(
                child: Text("Confirm"),
                onPressed: () {
                  placeDescription.add(placeNameController.text);
                  placeDescription.add(placeReasonController.text);
                  Navigator.of(context).pop(placeDescription);
                },
              )
            ],
          );
        });
  }
}
