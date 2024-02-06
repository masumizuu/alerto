import 'dart:math' show cos, sqrt, asin;

import 'package:advance_expansion_tile/advance_expansion_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:v1_alerto/secrets.dart';

void main() {
  runApp(const MaterialApp(
      title: 'Alerto-Demo',
      home: Scaffold(
        body: MyApp(),))); // end of runApp;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  //variable declarations
  int selectedIndex = 0;
  late GoogleMapController mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;
  String _startAddress = '';
  String _currentAddress = '';
  String? _placeDistance;
  Set<Marker> markers = {};
  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final desrinationAddressFocusNode = FocusNode();

  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  //get current location
  getLocation() async {
    LocationPermission permission;
    permission = await Geolocator.requestPermission();

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        forceAndroidLocationManager: true);
    double lat = position.latitude;
    double long = position.longitude;

    LatLng location = LatLng(lat, long);

    setState(() {
      _currentPosition = location;
      _isLoading = false;
    });
    await _getAddress();
  }

  // Method for retrieving the current address
  _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
        "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Method for calculating the distance between two places
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      List<Location> startPlacemark = await locationFromAddress(_startAddress);

      // Use the retrieved coordinates of the current position,
      // instead of the address if the start position is user's
      // current position, as it results in better accuracy.
      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition!.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition!.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = 14.509137679337712;
      double destinationLongitude =  121.03814546777816;

      // Calculating to check that the position relative
      // to the frame, and pan & zoom the camera accordingly.
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      // Accommodate the two locations within the
      // camera view of the map
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            northeast: LatLng(northEastLatitude, northEastLongitude),
            southwest: LatLng(southWestLatitude, southWestLongitude),
          ),
          100.0,
        ),
      );

      await _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      double totalDistance = 0.0;

      // Calculating the total distance by adding the distance
      // between small segments
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
      });

      return true;
    } catch (e) {
      print(e);
    }
    return false;
  } // end

  // Formula for calculating distance between two coordinates
  // https://stackoverflow.com/a/54138876/11910277
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Create the polylines for showing the route between two places
  _createPolylines(
      double startLatitude,
      double startLongitude,
      double destinationLatitude,
      double destinationLongitude,
      ) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      Secrets.API_KEY, // Google Maps API Key
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = const PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('ALERTO'),
          titleTextStyle: GoogleFonts.getFont(
            'Inter',
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          elevation: 2,
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
              target: _currentPosition!,
              zoom: 20.0),
          polylines: Set<Polyline>.of(polylines.values),
          markers: { Marker(
            consumeTapEvents: true,
            markerId: const MarkerId('MAKATI SAMPLE'),
            position: const LatLng(14.562362946132959, 121.0293603839722),
            infoWindow: const InfoWindow(
              title: "Tenement Elementary School",
              snippet: "Evacuation center for Brgy. Western Bicutan, Taguig City",
            ),
            onTap: (){
              _calculateDistance().then((isCalculated) {
                if (isCalculated) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Distance Calculated Sucessfully'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Error Calculating Distance'),
                    ),
                  );
                }
              });
            },
          ),
            Marker(
              markerId: const MarkerId('Current Position'),
              position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            ),
          },
        ),
        bottomNavigationBar: BottomAppBar(
          clipBehavior: Clip.antiAlias,
          shape: const CircularNotchedRectangle(),
          //color: Colors.grey.shade200,
          elevation: 0,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: const Color(0x12000000),
              labelTextStyle: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  );
                }
                return const TextStyle(
                  color: Colors.black,
                  fontSize: 11,
                  fontFamily: 'Roboto',
                );
              }),
              iconTheme: MaterialStateProperty.resolveWith((states) {
                if (states.contains(MaterialState.selected)) {
                  return const IconThemeData(
                    color: Color(0xFF02045E),
                    size: 24,
                  );
                }
                return const IconThemeData(
                  color: Colors.black,
                  size: 24,
                );
              }),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            ),
            child: NavigationBar(
              animationDuration: const Duration(seconds: 3),
              selectedIndex: selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  //add to do code here
                  switch(index) {
                    case 0:
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const MyApp()),);
                      break;
                    case 1:
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const EQ()),);
                      break;
                    case 2:
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const EN()),);
                      break;
                    case 3:
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const EC()),);
                      break;
                    case 4:
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const EP()),);
                      break;
                    case 5:
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const MyApp()),);
                      break;
                  }
                });
              },
              //on destination selected
              backgroundColor: Colors.transparent,
              elevation: 0,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
              destinations: const [
                NavigationDestination(
                  icon: Icon(
                    Icons.home_outlined,
                    size: 24,
                  ),
                  selectedIcon: Icon(
                    Icons.home,
                    size: 24,
                  ),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.dashboard_outlined,
                    size: 24,
                    color: Color(0xff000000),
                  ),
                  selectedIcon: Icon(
                    Icons.dashboard,
                    size: 24,
                  ),
                  label: 'Earthquakes',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.call_outlined,
                    size: 24,
                  ),
                  selectedIcon: Icon(
                    Icons.call,
                    size: 24,
                  ),
                  label: 'Hotlines',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.list_outlined,
                    size: 24,
                  ),
                  selectedIcon: Icon(
                    Icons.list,
                    size: 24,
                  ),
                  label: 'Evacuation Centers',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.description_outlined,
                    size: 24,
                  ),
                  selectedIcon: Icon(
                    Icons.description,
                    size: 24,
                  ),
                  label: 'Procedures',
                ),
                NavigationDestination(
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 24,
                  ),
                  selectedIcon: Icon(
                    Icons.settings,
                    size: 24,
                  ),
                  label: 'Settings',
                )
              ], // destination
            ),
          ),
        ),
      ),
    );
  }
} //MAIN PAGE; MAPS + DASHBOARD

class Tene extends StatefulWidget {
  const Tene({super.key});

  @override
  State<Tene> createState() => _TeneState();
} //evac center redirects to this

class _TeneState extends State<Tene> {

  //variable declarations
  int selectedIndex = 0;
  late GoogleMapController mapController;
  LatLng teneLoc = const LatLng(14.562362946132959, 121.0293603839722);

  LatLng? _currentPosition;
  bool _isLoading = true;
  String _startAddress = '';
  String _currentAddress = '';
  String? _placeDistance;
  Set<Marker> markers = {};
  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final desrinationAddressFocusNode = FocusNode();

  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  //get current location
  getLocation() async {
    LocationPermission permission;
    permission = await Geolocator.requestPermission();

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        forceAndroidLocationManager: true);
    double lat = position.latitude;
    double long = position.longitude;

    LatLng location = LatLng(lat, long);

    setState(() {
      _currentPosition = location;
      _isLoading = false;
    });
    await _getAddress();
  }

  // Method for retrieving the current address
  _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
        "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // Method for calculating the distance between two places
  Future<bool> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      List<Location> startPlacemark = await locationFromAddress(_startAddress);

      // Use the retrieved coordinates of the current position,
      // instead of the address if the start position is user's
      // current position, as it results in better accuracy.
      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition!.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition!.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = 14.562362946132959;
      double destinationLongitude =  121.0293603839722;

      // Calculating to check that the position relative
      // to the frame, and pan & zoom the camera accordingly.
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      // Accommodate the two locations within the
      // camera view of the map
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            northeast: LatLng(northEastLatitude, northEastLongitude),
            southwest: LatLng(southWestLatitude, southWestLongitude),
          ),
          100.0,
        ),
      );

      await _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      double totalDistance = 0.0;

      // Calculating the total distance by adding the distance
      // between small segments
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
      });

      return true;
    } catch (e) {
      print(e);
    }
    return false;
  } // end

  // Formula for calculating distance between two coordinates
  // https://stackoverflow.com/a/54138876/11910277
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Create the polylines for showing the route between two places
  _createPolylines(
      double startLatitude,
      double startLongitude,
      double destinationLatitude,
      double destinationLongitude,
      ) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      Secrets.API_KEY, // Google Maps API Key
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = const PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
  }
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Brgy. Western Bicutan'),
          titleTextStyle: GoogleFonts.getFont(
            'Inter',
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
          elevation: 2,
          leading: IconButton(
            iconSize: 24,
            onPressed: () {
              // add to do code here
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : GoogleMap(
          myLocationButtonEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: _onMapCreated,
          polylines: Set<Polyline>.of(polylines.values),
          initialCameraPosition: CameraPosition(
              target: teneLoc,
              zoom: 20.0),
          markers: { const Marker(
            markerId:  MarkerId('MAKATI SAMPLE'),
            position:  LatLng(14.562362946132959, 121.0293603839722),
            infoWindow:  InfoWindow(
              title: "Tenement Elementary School",
              snippet: "Evacuation center for Brgy. Western Bicutan, Taguig City",
            ),
          ),Marker(
            markerId: const MarkerId('Current Position'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          ),
          },
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.indigo,
          mini: true,
          onPressed: () {
            //add to do code here
            _calculateDistance().then((isCalculated) {
              if (isCalculated) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Distance Calculated Sucessfully'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context)
                    .showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Error Calculating Distance'),
                  ),
                );
              }
            });
          },
          elevation: 12,
          child: const Icon(Icons.navigation),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniStartFloat,
      ),
    );
  }
} //tenement focus

//===================================ROUTES

// calling routes

class FL1 extends StatelessWidget {
  const FL1({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'First-Launch',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Firstlaunch(),
      ),
    );
  }
} //first launch

class OT extends StatelessWidget {
  const OT({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'OTP',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Otp(),
      ),
    );
  }
} //OTP

class EQ extends StatelessWidget {
  const EQ({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Earthquakes',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Equake(),
      ),
    );
  }
} //eq

class EC extends StatelessWidget {
  const EC({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MyApp Demo',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: EvacCenter(),
      ),
    );
  }
} //evac center

class EP extends StatelessWidget {
  const EP({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Emergency Procedures',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Eprod(),
      ),
    );
  }
} //emergency procedures

class TS extends StatelessWidget {
  const TS({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'TSUNAMI',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Tsunami(),
      ),
    );
  }
} //tsunami

class EN extends StatelessWidget {
  const EN({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Emergency Numbers',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Enum(),
      ),
    );
  }
} //emergency numbers

//ROUTE CODES

class Firstlaunch extends StatelessWidget {
  const Firstlaunch({super.key});

  @override
  Widget build(BuildContext context) {

    //responsive
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double screenWidth = mediaQueryData.size.width;
    double screenHeight = mediaQueryData.size.height;

    return Container(
      width: screenWidth,
      height: screenHeight,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xB202045E), Color(0xB21DAEEF), Color(0xB20077B6)],
          stops: [0, 1, 1],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          alignment: AlignmentDirectional.center,
          clipBehavior: Clip.none,
          children: <Widget> [
            Align(
              alignment: const Alignment(0.0, -0.27),
              child: Container(
                width: 128,
                height: 128,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    width: 5,
                    color: const Color(0xFF0077B6),
                  ),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.0, 0.0),
              child: Text(
                'Welcome!',
                style: GoogleFonts.getFont(
                  'Inter',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),textAlign: TextAlign.center,
              ),
            ),
            Align(
              alignment: const Alignment(0.0, -0.27),
              child: Image.network(
                'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F3YeyF4i1zTBffu6E65ql%2Febec611a6443f21a62ac68ab8a24c518d4bf9fe5lerto-removebg%201.png?alt=media&token=03afe9de-c6de-4507-80bd-aa4b1f42f634',
                width: 109,
                height: 113,
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: const Alignment(0.0, 0.13),
              child: SizedBox(
                width: 250,
                height: 43,
                child: TextField(
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Roboto',
                  ),
                  textAlign: TextAlign.left,
                  textAlignVertical: TextAlignVertical.center,
                  autocorrect: false,
                  minLines: null,
                  cursorHeight: 14,
                  cursorRadius: const Radius.circular(2),
                  cursorColor: const Color(0xFF5C69E5),
                  decoration: InputDecoration(
                    labelStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    hintText: '09XXXXXXXXX',
                    hintStyle: const TextStyle(
                      color: Color(0xFF7F7F7F),
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    hintMaxLines: 1,
                    errorStyle: const TextStyle(
                      color: Color(0xFFFF0000),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                    errorMaxLines: 1,
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    focusColor: Colors.black,
                    hoverColor: const Color(0x197F7F7F),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                      ),
                    ),
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.0, 0.26),
              child: SizedBox(
                width: 166,
                child: OutlinedButton(
                  onPressed: () {
                    //add to do code here
                    Navigator.push(context, MaterialPageRoute(builder:
                        (context) => const OT()),);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.white,
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    shadowColor: const Color(0xFFA5A5A5),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    visualDensity: VisualDensity.standard,
                    elevation: 0,
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Verify phone number',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class Otp extends StatelessWidget {
  const Otp({super.key});

  @override
  Widget build(BuildContext context) {

    //responsive
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double screenWidth = mediaQueryData.size.width;
    double screenHeight = mediaQueryData.size.height;

    return Container(
      width: screenWidth,
      height: screenHeight,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xB202045E), Color(0xB21DAEEF), Color(0xB20077B6)],
          stops: [0, 1, 1],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: const Alignment(0.0, -0.15),
              child: Text(
                'Enter OTP',
                style: GoogleFonts.getFont(
                  'Inter',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.0, 0.0),
              child: SizedBox(
                width: 250,
                height: 43,
                child: TextField(
                  keyboardType: TextInputType.text,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Roboto',
                  ),
                  textAlign: TextAlign.left,
                  textAlignVertical: TextAlignVertical.center,
                  autocorrect: false,
                  minLines: null,
                  cursorHeight: 14,
                  cursorRadius: const Radius.circular(2),
                  cursorColor: const Color(0xFF5C69E5),
                  decoration: InputDecoration(
                    labelStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    floatingLabelStyle: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    hintText: '',
                    hintStyle: const TextStyle(
                      color: Color(0xFF7F7F7F),
                      fontSize: 14,
                      fontFamily: 'Roboto',
                    ),
                    hintMaxLines: 1,
                    errorStyle: const TextStyle(
                      color: Color(0xFFFF0000),
                      fontSize: 12,
                      fontFamily: 'Roboto',
                    ),
                    errorMaxLines: 1,
                    floatingLabelBehavior: FloatingLabelBehavior.auto,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 16),
                    filled: true,
                    fillColor: Colors.grey.shade200,
                    focusColor: Colors.black,
                    hoverColor: const Color(0x197F7F7F),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4.0),
                      borderSide: const BorderSide(
                        color: Colors.transparent,
                      ),
                    ),
                    focusedErrorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0.0, 0.15),
              child: SizedBox(
                width: 173,
                child: OutlinedButton(
                  onPressed: () {
                    // add to do code here
                    Navigator.push(context, MaterialPageRoute(builder:
                        (context) => const MyApp()),);
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Colors.white,
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.transparent,
                    shadowColor: const Color(0xFFA5A5A5),
                    padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Roboto',
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    visualDensity: VisualDensity.standard,
                    elevation: 0,
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Verify phone number',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class Equake extends StatelessWidget {
  const Equake({super.key});

  @override
  Widget build(BuildContext context) {

    //responsive
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double screenWidth = mediaQueryData.size.width;
    double screenHeight = mediaQueryData.size.height;

    return Container(
      width: screenWidth,
      height: screenHeight,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xB202045E), Color(0xB21DAEEF), Color(0xB20077B6)],
          stops: [0, 1, 1],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Align(
              alignment: const Alignment(0.0, -0.15),
              child: Text(
                'Soon...',
                style: GoogleFonts.getFont(
                  'Inter',
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EvacCenter extends StatefulWidget {
  const EvacCenter({Key? key}) : super(key: key);

  @override
  State<EvacCenter> createState() => _EvacCenter();
}

class _EvacCenter extends State<EvacCenter> {
  ///You use GlobalKey to manually collapse, exapnd or toggle Expansion tile
  final GlobalKey<AdvanceExpansionTileState> _globalKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: <Widget> [
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: AdvanceExpansionTile(
                  key: _globalKey,
                  title: const Text('Western Bicutan',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontFamily: 'Inter',
                    ),),
                  children: [
                    ListTile(
                        title: Text(
                          'Tenement Elementary School',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'G25Q+J7C, Veterans Rd, Taguig, 1630 Metro Manila',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        onTap: () {
                          // add to do code here
                          Navigator.push(context, MaterialPageRoute(builder:
                              (context) => const Tene()),);
                        }
                    ),
                  ] //wesbi
              ),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        leading: IconButton(
          iconSize: 24,
          onPressed: () {
            // add to do code here
            Navigator.push(context, MaterialPageRoute(builder:
                (context) => const MyApp()),);
          },
          icon: const Icon(Icons.arrow_back),
        ),
        automaticallyImplyLeading: false,
        title: const Text('Evacuation Centers'),
        elevation: 0,
        shadowColor: Colors.black,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        centerTitle: true,
        titleTextStyle: GoogleFonts.getFont(
          'Inter',
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} // end evac

class Eprod extends StatelessWidget {
  const Eprod({super.key});

  @override
  Widget build(BuildContext context) {

    //responsive
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double screenWidth = mediaQueryData.size.width;
    //double screenHeight = mediaQueryData.size.height;

    return Container(
      width: screenWidth,
      height: 825,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
              children: <Widget> [
                //your widgets here
                SizedBox(
                  width: screenWidth,
                  child: AppBar(
                    leading: IconButton(
                      iconSize: 24,
                      onPressed: () {
                        // add to do code here
                        Navigator.push(context, MaterialPageRoute(builder:
                            (context) => const MyApp()),);
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    automaticallyImplyLeading: false,
                    title: const Text('Emergency Procedures'),
                    elevation: 0,
                    shadowColor: Colors.black,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    centerTitle: true,
                    titleTextStyle: GoogleFonts.getFont(
                      'Inter',
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
       //appbar
                GestureDetector(
                  onTap: () {
                    //add to do code here
                    Navigator.push(context, MaterialPageRoute(builder:
                        (context) => const TS()),);
                  },
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 5.0),
                    child: Image.network(
                      'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/99HG994pcFgCJpIki5zcXDsUlX93%2Fuploads%2Fimages%2Ftsunami.png?alt=media&token=0cf4d80a-f4be-4230-8cbd-2e5c7382c3e9',
                      width: screenWidth,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),// TSUNAMI
                Container(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/99HG994pcFgCJpIki5zcXDsUlX93%2Fuploads%2Fimages%2Feq.png?alt=media&token=35402f75-62e4-4918-9f7a-ac931a944a8f',
                    width: screenWidth,
                    fit: BoxFit.contain,
                  ),
                ),// EARTHQUAKES
                Container(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/99HG994pcFgCJpIki5zcXDsUlX93%2Fuploads%2Fimages%2Ftyphoons.png?alt=media&token=6d2ebc8f-e76d-4d0a-a75a-4b462a4eb99d',
                    width: screenWidth,
                    fit: BoxFit.contain,
                  ),
                ),//TYPHOONS
                Container(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Image.network(
                    'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/99HG994pcFgCJpIki5zcXDsUlX93%2Fuploads%2Fimages%2Fve.png?alt=media&token=9f349d8c-03b9-4829-a8ac-1f8cf1b311a6',
                    width: screenWidth,
                    fit: BoxFit.contain,
                  ),
                ),//VOLCANIC ERUPTION
              ] // end of widgets
          ) // columns
      ),
    );
  }
}

class Tsunami extends StatelessWidget {
  const Tsunami({super.key});

  @override
  Widget build(BuildContext context) {
    //responsive
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double screenWidth = mediaQueryData.size.width;

    return Container(
      width: screenWidth,
      height: 1500,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
              children: <Widget> [
                //your widgets here
                SizedBox(
                  width: screenWidth,
                  child: AppBar(
                    leading: IconButton(
                      iconSize: 24,
                      onPressed: () {
                        // add to do code here
                        Navigator.push(context, MaterialPageRoute(builder:
                            (context) => const EP()),);
                      },
                      icon: const Icon(Icons.arrow_back),
                    ),
                    automaticallyImplyLeading: false,
                    title: const Text('Emergency Procedures'),
                    elevation: 0,
                    shadowColor: Colors.black,
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    centerTitle: true,
                    titleTextStyle: GoogleFonts.getFont(
                      'Inter',
                      color: Colors.black,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                //appbar
                Image.network(
                  'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/99HG994pcFgCJpIki5zcXDsUlX93%2Fuploads%2Fimages%2Ftsunami(3).png?alt=media&token=7928563b-99fe-46b0-81ab-6ecd76c2f412',
                  width: screenWidth,
                  height: 60,
                  fit: BoxFit.contain,
                ),
                // background ng tsunami text
                SizedBox(
                  width: screenWidth,
                  height: 35,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 17.0, top: 12.0),
                    child: Text(
                      'What...',
                      style: GoogleFonts.getFont(
                        'Inter',
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                //what...
                SizedBox(
                  width: screenWidth,
                  height: 117,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 17.0, right: 17.0),
                    child: Text(
                      'Tsunamis are giant waves caused by earthquakes or volcanic eruptions under the sea. Out in the depths of the ocean, tsunami waves do not dramatically increase in height. But as the waves travel inland, they build up to higher and higher heights as the depth of the ocean  decreases. The speed of tsunami waves depends on ocean depth rather than the distance from the source of the wave. \n\n',
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.getFont(
                        'Inter',
                        color: Colors.black,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                //p1
                SizedBox(
                  width: screenWidth,
                  height: 35,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 17.0, top: 12.0),
                    child: Text(
                      'What to do...',
                      style: GoogleFonts.getFont(
                        'Inter',
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                //what to do...
                SizedBox(
                  width: screenWidth,
                  height: 210,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 17.0, right: 17.0),
                    child: Text(
                      "Given the limited warning time for a local tsunami, natural warning signs may be your first alert that something is wrong. If you observe warning signs, don't wait for guidance. Take action immediately. Suppose you are in a tsunami hazard, evacuation zone, or low-lying coastal area and feel an earthquake. In that case, the ocean acts strange, or a roar is coming from the sea, so a tsunami is possible and could arrive within minutes. Water movement may look like a fast-rising flood or a wall of water or drain away suddenly, showing the ocean floor like a shallow tide. If you observe these natural warning signs, evacuate the beach and move to higher ground immediately. Do not wait for official guidance. This could generate or be a sign of a local tsunami with minimal warning time.\n\n",
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.getFont(
                        'Inter',
                        color: Colors.black,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                //p2
                Image.network(
                  'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F3YeyF4i1zTBffu6E65ql%2F0f0bce225608051fffdf5a076bc6962a318958d8tsunami%201.png?alt=media&token=059530c6-387d-4665-aa2b-1ff1d1da0795',
                  width: screenWidth,
                  height: 186,
                  fit: BoxFit.cover,
                ),
                //warning signs pic
                SizedBox(
                  width: screenWidth,
                  height: 35,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 17.0, top: 12.0),
                    child: Text(
                      'Aftermath...',
                      style: GoogleFonts.getFont(
                        'Inter',
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                //aftermath
                SizedBox(
                  width: screenWidth,
                  height: 450,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 17.0, right: 17.0),
                    child: Text(
                      "A tsunami may be destructive or non-destructive. If the tsunami were destructive, emergency search and rescue operations would immediately start on land and at sea. It is essential to wait for official messaging that an area is safe and re-entry is allowed. Following a tsunami or a Tsunami Warning, here are some things to be aware of:\n\nTsunami waves may keep coming for hours, every 10 minutes to one hour apart. The first wave may not be the largest.\n\nA cancellation is different than an all-clear message. A cancellation is issued only after an evaluation of water-level data confirms that a destructive tsunami will not impact an area under a warning, advisory, or watch or that a tsunami has diminished to a level where additional damage is not expected.\n\nCoastal tsunami impact areas could be flooded, debris from structures may block roads and highways, and major utilities disrupted for days to weeks or longer. Be aware that you may be unable to return to coastal areas for hours or days. The public cannot re-enter these areas until it is safe.\n\nFollowing a Tsunami Warning or Tsunami Advisory, it may be unsafe to return to the beach for hours or even days.\n\nIt's essential to stay informed. Check local radio/TV stations for emergency information regarding safety and disaster assistance.\n\n\n",
                      textAlign: TextAlign.justify,
                      style: GoogleFonts.getFont(
                        'Inter',
                        color: Colors.black,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                //p3
              ] // end of widgets
          ) // columns
      ),
    );
  }
}

class Enum extends StatelessWidget {
  const Enum({super.key});

  @override
  Widget build(BuildContext context) {
    //responsive
    MediaQueryData mediaQueryData = MediaQuery.of(context);
    double screenWidth = mediaQueryData.size.width;
    double screenHeight = mediaQueryData.size.height;

    return Container(
      width: screenWidth,
      height: screenHeight,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
                width: screenWidth,
                child: AppBar(
                  leading: IconButton(
                    iconSize: 24,
                    onPressed: () {
                      // add to do code here
                      Navigator.push(context, MaterialPageRoute(builder:
                          (context) => const MyApp()),);
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                  automaticallyImplyLeading: false,
                  title: const Text('Emergency Numbers'),
                  elevation: 0,
                  shadowColor: Colors.black,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  centerTitle: true,
                  titleTextStyle: GoogleFonts.getFont(
                    'Inter',
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            Positioned(
              left: 40,
              top: 121,
              child: Container(
                width: 354,
                height: 615,
                clipBehavior: Clip.hardEdge,
                decoration: const BoxDecoration(),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 1,
                      top: 2,
                      child: Container(
                        width: 98,
                        height: 100,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(
                          color: Color(0x66313639),
                          borderRadius:
                          BorderRadius.all(Radius.elliptical(49, 50)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 1,
                      top: 169,
                      child: Container(
                        width: 98,
                        height: 100,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(
                          color: Color(0x66313639),
                          borderRadius:
                          BorderRadius.all(Radius.elliptical(49, 50)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 1,
                      top: 336,
                      child: Container(
                        width: 98,
                        height: 100,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(
                          color: Color(0x66313639),
                          borderRadius:
                          BorderRadius.all(Radius.elliptical(49, 50)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 1,
                      top: 503,
                      child: Container(
                        width: 98,
                        height: 100,
                        clipBehavior: Clip.hardEdge,
                        decoration: const BoxDecoration(
                          color: Color(0x66313639),
                          borderRadius:
                          BorderRadius.all(Radius.elliptical(49, 50)),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 31,
                      child: SizedBox(
                        width: 146,
                        height: 47,
                        child: Text(
                          '(02) 165-7777\n(02) 789-3200',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 205,
                      child: SizedBox(
                        width: 228,
                        height: 30,
                        child: Text(
                          '+63 917 550 3727',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 372,
                      child: SizedBox(
                        width: 228,
                        height: 30,
                        child: Text(
                          '+63 917 821 0896',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 126,
                      top: 539,
                      child: SizedBox(
                        width: 228,
                        height: 30,
                        child: Text(
                          '+63 937 587 0000',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 80,
                      child: SizedBox(
                        width: 228,
                        height: 51,
                        child: Text(
                          'Waste segregation, no smoking\nviolations, and environmental \nissues',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 126,
                      top: 230,
                      child: SizedBox(
                        width: 228,
                        height: 51,
                        child: Text(
                          'Fire, floods, accidents, and \nother calamities',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 126,
                      top: 400,
                      child: SizedBox(
                        width: 228,
                        height: 51,
                        child: Text(
                          'Health emergencies',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 564,
                      child: SizedBox(
                        width: 228,
                        height: 51,
                        child: Text(
                          'Child protection',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 127,
                      top: 27,
                      child: Image.network(
                        'https://storage.googleapis.com/codeless-dev.appspot.com/uploads%2Fimages%2F3YeyF4i1zTBffu6E65ql%2F0aaf4804a1814103021af5ec13b64a41.png',
                        width: 135,
                        height: 1,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 127,
                      top: 199,
                      child: Image.network(
                        'https://storage.googleapis.com/codeless-dev.appspot.com/uploads%2Fimages%2F3YeyF4i1zTBffu6E65ql%2F0aaf4804a1814103021af5ec13b64a41.png',
                        width: 135,
                        height: 1,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 127,
                      top: 366,
                      child: Image.network(
                        'https://storage.googleapis.com/codeless-dev.appspot.com/uploads%2Fimages%2F3YeyF4i1zTBffu6E65ql%2F0aaf4804a1814103021af5ec13b64a41.png',
                        width: 135,
                        height: 1,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 127,
                      top: 533,
                      child: Image.network(
                        'https://storage.googleapis.com/codeless-dev.appspot.com/uploads%2Fimages%2F3YeyF4i1zTBffu6E65ql%2F0aaf4804a1814103021af5ec13b64a41.png',
                        width: 135,
                        height: 1,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 0,
                      child: SizedBox(
                        width: 228,
                        height: 29,
                        child: Text(
                          'Taguig City Hall',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 172,
                      child: SizedBox(
                        width: 228,
                        height: 29,
                        child: Text(
                          'Rescue Team',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 339,
                      child: SizedBox(
                        width: 228,
                        height: 29,
                        child: Text(
                          'Doctor-on-call',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 125,
                      top: 495,
                      child: SizedBox(
                        width: 206,
                        height: 40,
                        child: Text(
                          'Youth Welfare, Development, and Protection',
                          style: GoogleFonts.getFont(
                            'Inter',
                            color: Colors.black,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 1,
                      child: Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F3YeyF4i1zTBffu6E65ql%2F25829f9cd44411054300011cbaa8e4ca99cae437ch%201.png?alt=media&token=d107f748-9fa6-480b-839a-d7e5ab06a677',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 170,
                      child: Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F3YeyF4i1zTBffu6E65ql%2F9eed9f70ab4e08befe11076330dbacb3414a4c83rescue%201.png?alt=media&token=4bd61899-296f-4a96-b2e9-a56bb10039e3',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 337,
                      child: Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F3YeyF4i1zTBffu6E65ql%2Fe5741966cfd0a73232d943fd9d3658acb848deb8doctor%201.png?alt=media&token=807c6b9b-e514-4a3f-8883-1dc2aaf9614e',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 503,
                      child: Image.network(
                        'https://firebasestorage.googleapis.com/v0/b/codeless-app.appspot.com/o/projects%2F3YeyF4i1zTBffu6E65ql%2F1c5d449b2954cfc6892eec4ebfffa51d26d29e8eyouth%201.png?alt=media&token=2a376c48-af51-499f-8905-8243f1d64f5e',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}



