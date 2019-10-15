import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:whereabouts/login.dart';

void main() => runApp(MyApp());

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

class _FireMapState extends State<FireMap> {
  String username;
  final LoginUser loginUser = LoginUser();

  Location location = new Location();
  LocationData currentLocation;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  MarkerId selectedMarker;
  BitmapDescriptor markerIcon;

  GoogleMapController mapController;

  Firestore firestore = Firestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  Stream<dynamic> query;
  StreamSubscription subscription;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: LatLng(14.6972207, 121.036092), zoom: 20),
          onMapCreated: _onMapCreated,
          mapType: MapType.hybrid,
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
              ),
            ),
            shape: CircleBorder(),
            color: Colors.green,
            onPressed: () => _animateToUser(),
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
            onPressed: () => _animateToUser(),
          ),
        )
      ],
    );
  }

  @override
  void initState() {
    //Sign in through google
    _getAssetIcon(context).whenComplete(() {
      location.onLocationChanged().listen((location) async {
        var markerId = MarkerId('marker_id_$username');
        if (currentLocation != location && currentLocation != null) {
          setState(() {
            print("location changed!");
            markers[markerId] = Marker(
              markerId: markerId,
              icon: markerIcon,
              position:
                  LatLng(currentLocation.latitude, currentLocation.longitude),
            );
          });
        }
        currentLocation = location;
      });
    });
    super.initState();
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  _addMarker(BuildContext context) async {
    List placeDescription = await _whereaboutsDescription(context);

    var markerIdVal = 'marker_id_1';
    var markerId = MarkerId(markerIdVal);
    var marker = Marker(
        markerId: markerId,
        position: LatLng(currentLocation.latitude, currentLocation.longitude),
        icon: BitmapDescriptor.defaultMarker,
        infoWindow: InfoWindow(
            title: placeDescription.elementAt(0),
            snippet: placeDescription.elementAt(1)));

    setState(() {
      markers[markerId] = marker;
    });
    _addGeoPoint();
  }

  _animateToUser() async {
    var pos = await location.getLocation();
    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(pos.latitude, pos.longitude), zoom: 17.0)));
  }

  _findDearest() async {}

  Future<DocumentReference> _addGeoPoint() async {
    var pos = await location.getLocation();
    GeoFirePoint point =
        geo.point(latitude: pos.latitude, longitude: pos.longitude);
    return firestore
        .collection('locations')
        .add({'position': point.data, 'name': 'Paolo Location'});
  }

  _startQuery() async {
    var pos = await location.getLocation();
    double lat = pos.latitude;
    double lng = pos.longitude;

    var ref = firestore.collection("locations");
    GeoFirePoint center = geo.point(latitude: lat, longitude: lng);
  }

  Future<BitmapDescriptor> _getAssetIcon(BuildContext context) async {
    username = await loginUser.signInWithGoogle();
    var imageType = (username.contains("Paolo"))
        ? 'assets/dearest_marker_male.png'
        : "assets/dearest_marker_female.png";

    final Completer<BitmapDescriptor> bitmapIcon =
        Completer<BitmapDescriptor>();
    final ImageConfiguration config = createLocalImageConfiguration(context);
    AssetImage(imageType)
        .resolve(config)
        .addListener(ImageStreamListener((ImageInfo image, bool sync) async {
      final ByteData bytes =
          await image.image.toByteData(format: ImageByteFormat.png);
      final BitmapDescriptor bitmap =
          BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
      bitmapIcon.complete(bitmap);
    }));

    markerIcon = await bitmapIcon.future;
    return markerIcon;
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
