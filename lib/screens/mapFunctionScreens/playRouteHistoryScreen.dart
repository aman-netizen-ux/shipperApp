import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:async/async.dart';
import 'dart:ui' as ui;
import 'package:custom_info_window/custom_info_window.dart';
// import 'package:flutter_config/flutter_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animarker/flutter_map_marker_animation.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../../Widgets/buttons/backButtonWidget.dart';
import '/constants/colors.dart';
import '/constants/fontSize.dart';
import '/constants/fontWeights.dart';
import '/constants/spaces.dart';
import '/functions/trackScreenFunctions.dart';
import '/widgets/Header.dart';
import '/widgets/playRouteDetailsWidget.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const kMarkerId = MarkerId('MarkerId1');
const kMarkerId2 = MarkerId('MarkerId2');

class PlayRouteHistory extends StatefulWidget {
  var finalDistance;
  var gpsData;
  var gpsTruckHistory;
  var gpsStoppageHistory;
  var totalRunningTime;
  var totalStoppedTime;
  var address;
  var ignition;
  String? truckNo;
  String? dateRange;

  PlayRouteHistory({
    this.ignition,
    this.address,
    this.finalDistance,
    this.gpsTruckHistory,
    this.gpsStoppageHistory,
    this.gpsData,
    this.truckNo,
    this.dateRange,
    this.totalRunningTime,
    this.totalStoppedTime,
  });

  @override
  _PlayRouteHistoryState createState() => _PlayRouteHistoryState();
}

class _PlayRouteHistoryState extends State<PlayRouteHistory>
    with WidgetsBindingObserver {
  double value = 0;
  List<Marker> customMarkers = [];
  String? time;
  Map<PolylineId, Polyline> polylines = {};
  late List<LatLng> polylineCoordinates2;
  bool isPaused = false;
  late var subscription;
  final Set<Polyline> _polyline = {};
  late LatLng lastlatLngMarker = LatLng(gpsData.last.lat, gpsData.last.lng);
  late CameraPosition camPosition;
  Completer<GoogleMapController> _controller = Completer();
  // String googleAPiKey = FlutterConfig.get("mapKey");
  String googleAPiKey = dotenv.get('mapKey');

  late BitmapDescriptor pinLocationIconTruck;
  var direction;
  List<LatLng> latlng = [];
  var gpsData = [];
  var gpsTruckHistory = [];
  var gpsStoppageHistory = [];
  var stops = [];
  var totalDistance;
  String? dateRange;
  var logger = Logger();
  int i = 0;
  var start;
  var end;
  late DateTimeRange newRange;
  var selectedDateString = [];
  DateTime today = DateTime.now();
  DateTime yesterday = DateTime.now().subtract(Duration(days: 1));
  DateTimeRange selectedDate = DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 1)), end: DateTime.now());
  bool showBottomMenu = true;
  var markers = <MarkerId, Marker>{};
  var controller = Completer<GoogleMapController>();
  var stream;
  var streamedData = [];
  var Locations = [];
  late Uint8List markerIcon;
  var routeTime = [];
  var routeSpeed = [];
  CustomInfoWindowController _customInfoWindowController =
      CustomInfoWindowController();
  var totalRunningTime;
  var totalStoppedTime;

  var col1 = const Color(0xff878787);
  var col2 = const Color(0xffFF5C00);
  var maptype = MapType.normal;
  double zoom = 15;
  bool zoombutton = false;
  late GoogleMapController _googleMapController;
  double averagelat = 0;
  double averagelon = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      initfunction();
      getTruckHistory();
      getDateRange();
      getInfoWindow();
      check();
      print("PLAY ROUTE HISTORY DONE ------");
    } catch (e) {
      logger.e("Error is $e");
    }
    if (mounted) {
      setState(() {
        camPosition = CameraPosition(
            target: LatLng(
                gpsTruckHistory[0].latitude, gpsTruckHistory[0].longitude),
            zoom: 12.5);
        stream = Stream.periodic(
                Duration(milliseconds: 470), (count) => Locations[count])
            .take(Locations.length);
      });
      value = routeTime.length.toDouble();
    }
    // stream.forEach((value) {
    //   streamedData.add(value);
    // });
  }

  initfunction() {
    var logger = Logger();
    // logger.i("in initState 1 function");
    setState(() {
      gpsData = widget.gpsData;
      gpsTruckHistory = widget.gpsTruckHistory;
      gpsStoppageHistory = widget.gpsStoppageHistory;
      dateRange = widget.dateRange;
      totalRunningTime = widget.totalRunningTime;
      totalStoppedTime = widget.totalStoppedTime;
      // fromDate = widget.fromDate;
      // toDate = widget.toDate;
    });

    addstops(gpsStoppageHistory);
    getLatLngList();
  }

  //REFRESH MAP WHEN APP RESUMED ----------------------
  void onMapCreated(GoogleMapController controller) {
    controller.setMapStyle("[]");
    _controller.complete(controller);
    _customInfoWindowController.googleMapController = controller;
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.inactive:
        print('appLifeCycleState inactive');
        break;
      case AppLifecycleState.resumed:
        final GoogleMapController controller = await _controller.future;
        onMapCreated(controller);
        print('appLifeCycleState resumed');
        break;
      case AppLifecycleState.paused:
        print('appLifeCycleState paused');
        break;
      case AppLifecycleState.detached:
        print('appLifeCycleState detached');
        break;
    }
  }

  getInfoWindow() {
    var logger = Logger();
    logger.i("in getInfoWindow function");
    routeTime = [];
    routeSpeed = [];
    int a = 0;
    int c = 0;
    for (int i = 0; i < gpsTruckHistory.length; i++) {
      c = a + 10;
      if (gpsTruckHistory[a].speed >= 2) {
        var time = getISOtoIST(gpsTruckHistory[a].deviceTime);
        routeTime.add("$time");
        routeSpeed.add("${(gpsTruckHistory[a].speed).toStringAsFixed(2)} km/h");
      }
      a = c;
      if (a >= gpsTruckHistory.length) {
        break;
      }
    }
    print("Route Time ${routeTime}");
    print("Route speed ${routeSpeed}");
  }

  addstops(var gpsStoppage) async {
    var logger = Logger();
    logger.i("in addstops function");
    FutureGroup futureGroup = FutureGroup();
    for (int i = 0; i < gpsStoppage.length; i++) {
      var future = getStops(gpsStoppage[i], i);
      futureGroup.add(future);
    }
    futureGroup.close();
    await futureGroup.future;
    print("STOPS DONE __");
  }

  getStops(var gpsStoppage, int i) async {
    var logger = Logger();
    logger.i("in getStops function");
    stops = [];
    for (var stop in gpsStoppageHistory) {
      stops.add(LatLng(stop.latitude, stop.longitude));
    }
    print("Stop Locations $stops");
    for (int i = 0; i < stops.length; i++) {
      markerIcon = await getBytesFromCanvas(i + 1, 100, 100);
      setState(() {
        customMarkers.add(Marker(
          markerId: MarkerId("Stop Mark $i"),
          position: stops[i],
          icon: kIsWeb
              ? BitmapDescriptor.fromBytes(markerIcon, size: const Size(40, 40))
              : BitmapDescriptor.fromBytes(markerIcon),
        ));
      });
    }
  }

  void check() {
    print("Stop Locations $stops");
    print("Route time  $routeTime");
  }

  //Function to get EVERY 10th LAT LONG
  getLatLngList() {
    var logger = Logger();
    logger.i("in get lat long list function");
    Locations.clear();
    int a = 0;
    int c = 0;
    for (int i = 0; i < gpsTruckHistory.length; i++) {
      c = a + 10;
      if (gpsTruckHistory[a].speed >= 2)
        Locations.add(
            LatLng(gpsTruckHistory[a].latitude, gpsTruckHistory[a].longitude));
      a = c;
      if (a >= gpsTruckHistory.length) {
        break;
      }
    }
  }

  getDateRange() {
    var logger = Logger();
    logger.i("in getDateRange function");
    var splitted = dateRange!.split(" - ");
    var start1 = getFormattedDateForDisplay2(splitted[0]).split(", ");
    var end1 = getFormattedDateForDisplay2(splitted[1]).split(", ");
    start = start1[0];
    end = end1[0];
    print("Start is ${start} and ENd is ${end}");
  }

  //New location when truck moves
  void newLocationUpdate(LatLng latLng) async {
    markerIcon = await getBytesFromCanvas2(
        routeTime[i].toString(), routeSpeed[i].toString(), 600, 150);
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: 2.5, size: Size(100, 200)),
            'assets/icons/playHistoryPin.png')
        .then((value) => {
              if (mounted)
                {
                  print(
                      "--------------------------------------> in newLocationUpdate:${latlng}"),
                  setState(() {
                    print("value ${value.toString()}");
                    pinLocationIconTruck = value;
                    // }),
                    // setState(() {
                    markers[kMarkerId] = Marker(
                        markerId: kMarkerId,
                        position: latLng,
                        icon: value,
                        anchor: const Offset(0.5, 0.5),
                        rotation: 90,
                        onTap: () {
                          print("Tapped");
                        });
                    customMarkers.add(Marker(
                      markerId: kMarkerId2,
                      position: latLng,
                      icon: kIsWeb
                          ? BitmapDescriptor.fromBytes(markerIcon,
                              size: const Size(40, 40))
                          : BitmapDescriptor.fromBytes(markerIcon),
                    ));
                  }) //setState
                }
            });

    print("markers $markers");
    i = i + 1;
  }

  getTruckHistory() {
    var logger = Logger();
    logger.i("in truck historyfunction");
    polylineCoordinates2 = getPoylineCoordinates2(gpsTruckHistory);
    _getPolyline(polylineCoordinates2);
  }

  _getPolyline(List<LatLng> polylineCoordinates2) {
    var logger = Logger();
    // logger.i("in polyline function 2");
    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: loadingWidgetColor,
      points: polylineCoordinates2,
      width: 2,
    );

    //
    setState(() {
      polylines[id] = polyline;
    });
    print("polylines $polylines");

    _addPolyLine();
  }

  _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.blue,
      width: 4,
      points: polylineCoordinates2,
      visible: true,
    );
    setState(() {
      polylines[id] = polyline;
      _polyline.add(polyline);
    });
  }

  loadData() {
    // Locations.forEach((element) {
    //   value = Locations.indexOf(element).toDouble();
    //   sleep(Duration(seconds: 1));
    // });
    // streamedData.toList().forEach((element) {
    //
    //   newLocationUpdate(element);
    // });
  }

  void dispose() {
    logger.i("Activity is disposed");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double threshold = 100;

    return SafeArea(
      child: Scaffold(
          backgroundColor: white,
          body: GestureDetector(
            onTap: () {
              setState(() {
                showBottomMenu = !showBottomMenu;
              });
            },
            onPanEnd: (details) {
              if (details.velocity.pixelsPerSecond.dy > threshold) {
                this.setState(() {
                  showBottomMenu = false;
                });
              } else if (details.velocity.pixelsPerSecond.dy < -threshold) {
                this.setState(() {
                  showBottomMenu = true;
                });
              }
            },
            child: Stack(
              children: <Widget>[
                Positioned(
                  right: 0,
                  top: space_13,
                  child: Container(
                      width: MediaQuery.of(context).size.width / 1.5,
                      height: MediaQuery.of(context).size.height - space_13,
                      child: Stack(children: <Widget>[
                        Animarker(
                          curve: Curves.easeIn,
                          angleThreshold: 30,
                          zoom: 11,
                          useRotation: true,
                          duration: Duration(milliseconds: 500),
                          mapId: controller.future
                              .then<int>((value) => value.mapId),
                          //Grab Google Map Id
                          markers: markers.values.toSet(),
                          child: GoogleMap(
                            markers: customMarkers.toSet(),
                            polylines: Set.from(polylines.values),
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: false,
                            initialCameraPosition: camPosition,
                            compassEnabled: true,
                            mapType: maptype,
                            onMapCreated: (gController) async {
                              subscription = stream.listen(
                                (data) => {
                                  // print("data"),
                                  newLocationUpdate(data),
                                  value = Locations.indexOf(data).toDouble(),
                                },
                              );
                              controller.complete(gController);
                              _customInfoWindowController.googleMapController =
                                  gController;
                            },
                            gestureRecognizers: <
                                Factory<OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                () => EagerGestureRecognizer(),
                              ),
                            },
                          ),
                        ),
                        // Map Button
                        Positioned(
                          left: 20,
                          top: 20,
                          child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey,
                                  width: 0.25,
                                ),
                              ),
                              //  height: 40,
                              child: Row(
                                children: [
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                        color: col2,
                                        borderRadius:
                                            const BorderRadius.horizontal(
                                                left: Radius.circular(5)),
                                        boxShadow: [
                                          const BoxShadow(
                                            color:
                                                Color.fromRGBO(0, 0, 0, 0.25),
                                            offset: Offset(
                                              0,
                                              4,
                                            ),
                                            blurRadius: 4,
                                            spreadRadius: 0.0,
                                          ),
                                        ]),
                                    child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            this.maptype = MapType.normal;
                                            col1 = const Color(0xff878787);
                                            col2 = const Color(0xffFF5C00);
                                          });
                                        },
                                        child: const Text(
                                          'Map',
                                          style: TextStyle(
                                            color: Colors.white,
                                          ),
                                        )),
                                  ),
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: col1,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              right: Radius.circular(5)),
                                      //  border: Border.all(color: Colors.black),
                                    ),
                                    child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            this.maptype = MapType.satellite;
                                            col2 = const Color(0xff878787);
                                            col1 = const Color(0xffFF5C00);
                                          });
                                        },
                                        child: const Text('Satellite',
                                            style: TextStyle(
                                              color: Colors.black,
                                            ))),
                                  )
                                ],
                              )
                              /*        FloatingActionButton(
                            heroTag: "btn1",
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            child: const Icon(Icons.my_location,
                                size: 22, color: Color(0xFF152968)),
                            onPressed: () {
                              setState(() {
                                this.maptype = (this.maptype == MapType.normal)
                                    ? MapType.satellite
                                    : MapType.normal;
                              });
                            },
                          ),
                            */
                              ),
                        ),
                        // Zoom In Button
                        Positioned(
                          right: 10,
                          bottom: 100,
                          child: SizedBox(
                            height: 40,
                            child: FloatingActionButton(
                              heroTag: "btn2",
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              child: const Icon(Icons.zoom_in,
                                  size: 22, color: Color(0xFF152968)),
                              onPressed: () {},
                            ),
                          ),
                        ),
                        // Zoom out Button
                        Positioned(
                          right: 10,
                          bottom: 50,
                          child: SizedBox(
                            height: 40,
                            child: FloatingActionButton(
                              heroTag: "btn3",
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              child: const Icon(Icons.zoom_out,
                                  size: 22, color: Color(0xFF152968)),
                              onPressed: () {},
                            ),
                          ),
                        ),
                        // stack button
                        Positioned(
                          right: 10,
                          bottom: 150,
                          child: SizedBox(
                            height: 40,
                            child: FloatingActionButton(
                              heroTag: "btn4",
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              child: Container(
                                  child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/icons/layers.png',
                                  width: 20,
                                  height: 20,
                                ),
                              )),
                              onPressed: () {},
                            ),
                          ),
                        ),
                      ])),
                ),

                // Positioned(
                //     top: 20,
                //     left: 20,
                //     child: FloatingActionButton(
                //       backgroundColor: Colors.white,
                //       onPressed: () => Navigator.pop(context),
                //       child: Icon(Icons.arrow_back_ios_new_rounded,
                //           color: Colors.black),
                //     )),
                // Positioned(
                //   top: 0,
                //   child: Container(
                //     width: MediaQuery.of(context).size.width,
                //     color: white,
                //     child: Column(
                //         // mainAxisAlignment: MainAxisAlignment.start,
                //         children: [
                //           Container(
                //             margin: EdgeInsets.fromLTRB(
                //                 space_3, space_3, 0, space_3),
                //             child: Row(
                //               mainAxisAlignment: MainAxisAlignment.start,
                //               children: [
                //                 Header(
                //                     reset: false,
                //                     text: "${widget.truckNo}",
                //                     backButton: true),
                //               ],
                //             ),
                //           ),
                //           Container(
                //               margin: EdgeInsets.fromLTRB(
                //                   space_9, space_2, 0, space_2),
                //               child: Row(
                //                   mainAxisAlignment: MainAxisAlignment.start,
                //                   children: [
                //                     Container(
                //                         child: Column(
                //                       children: [
                //                         Row(children: [
                //                           Image(
                //                             image: AssetImage(
                //                                 'assets/icons/distanceCovered.png'),
                //                             height: 23,
                //                           ),
                //                           SizedBox(
                //                             width: space_1,
                //                           ),
                //                           Container(
                //                             alignment: Alignment.centerLeft,
                //                             width: 170,
                //                             child: Column(
                //                               children: [
                //                                 Row(
                //                                   children: [
                //                                     Text("travelled".tr + " ",
                //                                         softWrap: true,
                //                                         style: TextStyle(
                //                                             color: liveasyGreen,
                //                                             fontSize: size_6,
                //                                             fontStyle: FontStyle
                //                                                 .normal,
                //                                             fontWeight:
                //                                                 regularWeight)),
                //                                     Text(
                //                                         "${(gpsData.last.distance / 1000).toStringAsFixed(2)} km",
                //                                         softWrap: true,
                //                                         style: TextStyle(
                //                                             color: black,
                //                                             fontSize: size_6,
                //                                             fontStyle: FontStyle
                //                                                 .normal,
                //                                             fontWeight:
                //                                                 regularWeight)),
                //                                   ],
                //                                 ),
                //                                 Row(
                //                                   mainAxisAlignment:
                //                                       MainAxisAlignment.start,
                //                                   children: [
                //                                     Text("$totalRunningTime ",
                //                                         softWrap: true,
                //                                         style: TextStyle(
                //                                             color: grey,
                //                                             fontSize: size_6,
                //                                             fontStyle: FontStyle
                //                                                 .normal,
                //                                             fontWeight:
                //                                                 regularWeight)),
                //                                   ],
                //                                 )
                //                               ],
                //                             ),
                //                           ),
                //                         ]),
                //                         SizedBox(
                //                           height: space_3,
                //                         ),
                //                         Row(children: [
                //                           Icon(Icons.pause, size: size_11),
                //                           SizedBox(
                //                             width: space_1,
                //                           ),
                //                           Container(
                //                             alignment: Alignment.centerLeft,
                //                             width: 170,
                //                             child: Column(
                //                               children: [
                //                                 Row(
                //                                   children: [
                //                                     Text(
                //                                         "${gpsStoppageHistory.length} ",
                //                                         softWrap: true,
                //                                         style: TextStyle(
                //                                             color: black,
                //                                             fontSize: size_6,
                //                                             fontStyle: FontStyle
                //                                                 .normal,
                //                                             fontWeight:
                //                                                 regularWeight)),
                //                                     Text("stops".tr,
                //                                         softWrap: true,
                //                                         style: TextStyle(
                //                                             color: red,
                //                                             fontSize: size_6,
                //                                             fontStyle: FontStyle
                //                                                 .normal,
                //                                             fontWeight:
                //                                                 regularWeight)),
                //                                   ],
                //                                 ),
                //                                 Row(
                //                                   mainAxisAlignment:
                //                                       MainAxisAlignment.start,
                //                                   children: [
                //                                     Text("$totalStoppedTime ",
                //                                         softWrap: true,
                //                                         style: TextStyle(
                //                                             color: grey,
                //                                             fontSize: size_6,
                //                                             fontStyle: FontStyle
                //                                                 .normal,
                //                                             fontWeight:
                //                                                 regularWeight)),
                //                                   ],
                //                                 )
                //                               ],
                //                             ),
                //                           ),
                //                         ]),
                //                       ],
                //                     )),
                //                     SizedBox(width: space_1),
                //                     Container(
                //                       child: Column(
                //                         children: [
                //                           Text(
                //                               "${(gpsData.last.speed).toStringAsFixed(2)}" +
                //                                   "km/h".tr,
                //                               style: TextStyle(
                //                                   color: liveasyGreen,
                //                                   fontSize: size_10,
                //                                   fontStyle: FontStyle.normal,
                //                                   fontWeight: regularWeight)),
                //                           Text("status".tr,
                //                               style: TextStyle(
                //                                   color: black,
                //                                   fontSize: size_6,
                //                                   fontStyle: FontStyle.normal,
                //                                   fontWeight: regularWeight))
                //                         ],
                //                       ),
                //                     )
                //                   ])),
                //           SizedBox(
                //             height: 8,
                //           )
                //         ]),
                //   ),
                // ),

                //top bar
                Positioned(
                  top: 0,
                  width: MediaQuery.of(context).size.width,
                  child: Container(
                      color: white,
                      height: space_13,
                      width: MediaQuery.of(context).size.width,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  margin: EdgeInsets.fromLTRB(
                                      space_3, 10, space_3, 0),
                                  child: Header(
                                      reset: false,
                                      // add variable for check status time or device
                                      text: "${widget.truckNo} ",
                                      backButton: true),
                                ),
                                //dropmenu[NOT Functional]
                                // Container(
                                //   margin: const EdgeInsets.fromLTRB(
                                //       10, 0, 10, 10),
                                //   child: DropdownButton(
                                //     underline: Container(),
                                //     hint: Padding(
                                //       padding:
                                //           const EdgeInsets.only(right: 12.0),
                                //       child: Container(
                                //           decoration: const BoxDecoration(
                                //             borderRadius: BorderRadius.only(
                                //               topLeft: Radius.circular(8),
                                //               bottomLeft: Radius.circular(8),
                                //             ),
                                //           ),
                                //           child: const Text('24 hours')),
                                //     ),
                                //     icon: Container(
                                //       width: 36,
                                //       child: Row(children: [
                                //         Expanded(
                                //           child: Container(
                                //             width: 36,
                                //             height: 40,
                                //             decoration: const BoxDecoration(
                                //               color: Color(0xff152968),
                                //               borderRadius: BorderRadius.only(
                                //                 topRight: Radius.circular(8),
                                //                 bottomRight:
                                //                     Radius.circular(8),
                                //               ),
                                //             ),
                                //             child: const Icon(
                                //                 Icons.keyboard_arrow_down,
                                //                 size: 15,
                                //                 color: white),
                                //           ),
                                //         ),
                                //       ]),
                                //     ),
                                //     style: TextStyle(
                                //         color: const Color(0xff3A3A3A),
                                //         fontSize: size_6,
                                //         fontStyle: FontStyle.normal,
                                //         fontWeight: FontWeight.w400),
                                //     // Not necessary for Option 1
                                //     value: _selectedLocation,
                                //     onChanged: (newValue) {
                                //       setState(() {
                                //         _selectedLocation =
                                //             newValue.toString();
                                //       });
                                //       customSelection(_selectedLocation);
                                //     },
                                //     items: _locations.map((location) {
                                //       return DropdownMenuItem(
                                //         child: Container(
                                //             //  width: 74,
                                //             child: new Text(location.tr)),
                                //         value: location,
                                //       );
                                //     }).toList(),
                                //   ),
                                // ),
                              ],
                            ),
                          ],
                        ),
                      )),
                ),

                //bottom bar
                AnimatedPositioned(
                  curve: Curves.easeInOut,
                  duration: Duration(milliseconds: 200),
                  left: 0,
                  top: space_13,
                  // bottom: (showBottomMenu) ? -100 : -(height / 2.2),
                  child: PlayRouteDetailsWidget(
                    finalDistance: widget.finalDistance,
                    totalStop: gpsStoppageHistory.length,
                    address: widget.address,
                    dateRange: dateRange,
                    gpsData: gpsData,
                    truckNo: widget.truckNo,
                  ),
                ),

                //Add sliderbar
                Positioned(
                  top: MediaQuery.of(context).size.height / 2,
                  left: 0,
                  child: Container(
                    width: MediaQuery.of(context).size.width / 3 - 50,
                    height: 80,
                    color: backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              top: -20,
                              left: 10,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  boxShadow: [BoxShadow(blurRadius: 5)],
                                  color: Colors.white,
                                ),
                                padding: EdgeInsets.all(3),
                                child: FloatingActionButton(
                                  heroTag: "btn3",
                                  backgroundColor:
                                      Color.fromRGBO(21, 41, 104, 1),
                                  mini: true,
                                  onPressed: () {
                                    print("-------------------->Pause button");
                                    print("Paused----------------->$isPaused");
                                    setState(() {
                                      if (isPaused) {
                                        subscription.resume();
                                      } else {
                                        subscription.pause();
                                      }
                                      isPaused = !isPaused;
                                    });
                                    //print(streamedData);
                                  },
                                  child: isPaused
                                      ? Icon(Icons.play_arrow)
                                      : Icon(Icons.pause),
                                ),
                              ),
                            ),
                            Positioned(
                                left: 30,
                                // bottom: 10,
                                top: 8,
                                child: Container(
                                  // color: Colors.green,
                                  width: MediaQuery.of(context).size.width / 3 -
                                      70,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 20),
                                        child: Text(
                                          "    ${widget.truckNo}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Slider(
                                        thumbColor: Colors.green,
                                        activeColor: Colors.green,
                                        min: 0,
                                        max: Locations.length.toDouble(),
                                        value: value,
                                        divisions: 20,
                                        onChanged: (value) {
                                          setState(() {
                                            this.value = value;
                                            print(Locations[value.toInt()]);
                                          });
                                          print(value);
                                        },
                                      ),
                                    ],
                                  ),
                                )),
                            Positioned(
                                right: -10,
                                top: -15,
                                child: FloatingActionButton(
                                  heroTag: "btn4",
                                  backgroundColor: Colors.white,
                                  mini: true,
                                  onPressed: () {},
                                  child: Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                ))
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                //MENU PLACE
              ],
            ),
          )),
    );
  }
}
