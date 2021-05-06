import 'dart:typed_data';

import 'package:expiscan/constants/constants.dart';
import 'package:expiscan/service/api_service.dart';
import 'package:expiscan/service/database_service.dart';
import 'package:expiscan/service/expiry_date_checker_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:camera/camera.dart';
import 'package:intl/intl.dart';
import 'package:openfoodfacts/model/Product.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Rectangle {
  Rectangle(
      {required this.width, required this.height, this.color = Colors.white});

  final double width;
  final double height;
  final Color? color;
}

Rect? barcodeBoundingBox;

class ScannerBoxPainter extends CustomPainter {
  ScannerBoxPainter({required this.scannerWindow});

  final Rectangle scannerWindow;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    // final paintRect = Paint()..color = scannerWindow.color!;
    final paintFrame = Paint()..color = Colors.black.withOpacity(0.6);
    // final paintBarcode = Paint()..color = Colors.white.withOpacity(0.8);

    // Maths
    double _scannerTop = center.dy - scannerWindow.height / 2;
    double _scannerBottom = center.dy + scannerWindow.height / 2;
    double _scannerLeft = center.dx - scannerWindow.width / 2;
    double _scannerRight = center.dx + scannerWindow.width / 2;

// Create Rectangles
    // final rectCenter = Rect.fromCenter(
    //     center: center,
    //     width: scannerWindow.width,
    //     height: scannerWindow.height);
    final rectTop = Rect.fromLTRB(0, 0, size.width, _scannerTop);
    final rectBottom =
        Rect.fromLTRB(0, _scannerBottom, size.width, size.height);
    final rectLeft =
        Rect.fromLTRB(0, _scannerTop, _scannerLeft, _scannerBottom);
    final rectRight =
        Rect.fromLTRB(_scannerRight, _scannerTop, size.width, _scannerBottom);

// Draw rect
    // canvas.drawRect(rectCenter, paintRect);
    canvas.drawRect(rectTop, paintFrame);
    canvas.drawRect(rectBottom, paintFrame);
    canvas.drawRect(rectLeft, paintFrame);
    canvas.drawRect(rectRight, paintFrame);
    // canvas.drawRect(barcodeBoundingBox ?? rectCenter, paintBarcode);
  }

  @override
  bool shouldRepaint(CustomPainter oldPainter) {
    return false;
  }
}

class ScanPage extends StatefulWidget {
  @override
  _ScanPageState createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with WidgetsBindingObserver {
  late CameraController _cameraController;
  String? _barcodeValue;
  String _expiryDateValue = '';
  DateTime _expiryDateTime = DateTime(2000);
  List<DateTime> _expiryList = [];
  List<String> _expiryRawValueList = [];
  late Product _product;
  bool _cameraInitialized = false;
  bool _isScanningExpiryDate = false;
  bool _isProductBestBefore = false;
  bool _isFlashOn = false;
  String? _scannerStatus;

  // ML Instance
  final BarcodeDetector _barcodeDetector =
      FirebaseVision.instance.barcodeDetector();
  final TextRecognizer _textRecognizer =
      FirebaseVision.instance.textRecognizer();

  // Painter
  final Rectangle scannerWindow =
      Rectangle(width: 320, height: 144, color: Colors.transparent);

  Future<void> _initializeCameraandStream() async {
    List<CameraDescription> cameras = await availableCameras();

    _cameraController =
        CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);

    await _cameraController.initialize();

    setState(() {
      _cameraInitialized = true;
    });

    _startStreamToBarcodeScanner();
  }

  Future<void> _turnOffFlash() async {
    if (_cameraController.value.flashMode == FlashMode.torch) {
      await _cameraController.setFlashMode(FlashMode.off);
      _isFlashOn = false;
    }
  }

  Future<void> _startStreamToBarcodeScanner() async {
    bool isDetecting = false;

    // Start ImageStream
    await _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting || !mounted) {
        return;
      }

      isDetecting = true;
      if (_cameraController.value.isStreamingImages)
        await _scanBarcode(_grabImage(image), image.width, image.height)
            .whenComplete(() => isDetecting = false);
    });
  }

  Future<void> _startStreamToTextRecognizer() async {
    bool isDetecting = false;
    _isScanningExpiryDate = true;
    // Start ImageStream
    await _cameraController.startImageStream((CameraImage image) async {
      if (isDetecting || !mounted) {
        return;
      }

      isDetecting = true;
      if (_cameraController.value.isStreamingImages)
        await _scanText(_grabImage(image), image.width, image.height)
            .whenComplete(() => isDetecting = false);
    });
  }

  FirebaseVisionImage _grabImage(CameraImage image) {
    final FirebaseVisionImageMetadata metadata = FirebaseVisionImageMetadata(
        rawFormat: image.format.raw,
        size: Size(image.width.toDouble(), image.height.toDouble()),
        planeData: image.planes
            .map((currentPlane) => FirebaseVisionImagePlaneMetadata(
                bytesPerRow: currentPlane.bytesPerRow,
                height: currentPlane.height,
                width: currentPlane.width))
            .toList(),
        rotation: ImageRotation.rotation90);
    return FirebaseVisionImage.fromBytes(
        _concatenatePlanes(image.planes), metadata);
  }

  Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  bool _haveAllPoints(Rect scannerBox, List<Offset> cornerPoints) {
    bool result = true;
    cornerPoints.forEach((element) {
      result = scannerBox.contains(element);
    });

    return result;
  }

  Future _scanBarcode(
      FirebaseVisionImage image, int imageWidth, int imageHeight) async {
    final List<Barcode> barcodes = await _barcodeDetector.detectInImage(image);

    final Rect scannerBox = Rect.fromCenter(
        center: Size(imageHeight.toDouble(), imageWidth.toDouble())
            .center(Offset.zero),
        width: scannerWindow.width,
        height: scannerWindow.height);

    for (Barcode barcode in barcodes) {
      final List<Offset> cornerPoints = barcode.cornerPoints;

      // print(cornerPoints);
      // Rect boundingBox = barcode.boundingBox!;

      // final doesIntersect = scannerBox.intersect(boundingBox);
      // final bool doesContain = doesIntersect == boundingBox;

      if (barcode.valueType != BarcodeValueType.product) {
        setState(() {
          _scannerStatus = 'Point your camera at a food\'s barcode';
        });
        continue;
      }

      if (_haveAllPoints(scannerBox, cornerPoints)) {
        await _cameraController
            .stopImageStream()
            .then((_) => _showFoodConfirmationModal());

        print('found ${barcode.displayValue}');
        setState(() {
          _scannerStatus = 'Barcode scanned';
          _barcodeValue = barcode.displayValue;
        });
        return;
      } else if (barcode.boundingBox!.overlaps(scannerBox)) {
        setState(() {
          _scannerStatus = 'Move closer to the food\'s barcode';
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _scannerStatus = null;
      });
    }
  }

  Future _scanText(
      FirebaseVisionImage image, int imageWidth, int imageHeight) async {
    final VisionText visionText = await _textRecognizer.processImage(image);
    final Rect scannerBox = Rect.fromCenter(
        center: Size(imageHeight.toDouble(), imageWidth.toDouble())
            .center(Offset.zero),
        width: scannerWindow.width,
        height: scannerWindow.height);

    for (TextBlock block in visionText.blocks) {
      for (TextLine line in block.lines) {
        // final Rect boundingBox = line.boundingBox!;
        // final doesIntersect = scannerBox.intersect(boundingBox);
        // final bool doesContain = doesIntersect == boundingBox;
        //  Lots of regex
        if (!isExpiryDate(line.text!)) continue;
        // print('==== LINE ====');
        // print(line.text);
        // if (scannerBox.overlaps(line.boundingBox!)) {
        if (scannerBox.overlaps(line.boundingBox!)) {
          print(visionText.text);
          if (_cameraController.value.isStreamingImages)
            await _cameraController.stopImageStream();
          // .then((_) => _showExpiryDateConfirmationModal());

          _expiryDateValue = line.text!
              .trim()
              .toUpperCase()
              .replaceAll(RegExp(r'-*\/*\.* *'), '');
          _expiryRawValueList.add(_expiryDateValue);
          _expiryDateTime = parseDate(_expiryDateValue);
          _expiryList.add(_expiryDateTime);

          setState(() {
            _scannerStatus = 'Found';
            _isScanningExpiryDate = false;
          });

          // return;
        } else if (block.boundingBox!.overlaps(scannerBox)) {
          setState(() {
            _scannerStatus = 'Move closer to the Expiry Date';
          });
          return;
        }
      }
    }

    if (!_cameraController.value.isStreamingImages && _expiryList.isNotEmpty) {
      if (visionText.text != null) {
        if (visionText.text!.contains(RegExp(r'((best)?(before:?))|(bb:)',
            multiLine: true, caseSensitive: false)))
          setState(() {
            _isProductBestBefore = true;
          });
      }
      _showExpiryDateConfirmationModal();
    }

    if (mounted) {
      setState(() {
        _scannerStatus = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _initializeCameraandStream();
  }

  @override
  void dispose() {
    super.dispose();
    if (WidgetsBinding.instance != null)
      WidgetsBinding.instance!.removeObserver(this);
    if (_cameraController.value.isStreamingImages)
      _cameraController.stopImageStream();
    _cameraController.dispose();
    _barcodeDetector.close();
    _textRecognizer.close();
  }

  // if device sleeps, and unlocked again resume()
  @override
  Future didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed && _cameraInitialized == true) {
      await _cameraController.initialize();
      if (_cameraController.value.isStreamingImages)
        _cameraController.stopImageStream();
      if (_isScanningExpiryDate)
        _startStreamToTextRecognizer();
      else
        _startStreamToBarcodeScanner();
    }
  }

  void _showFoodConfirmationModal() {
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      bool _continue = false;
      _turnOffFlash();

      await showModalBottomSheet(
          context: context,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (BuildContext context) {
            if (_barcodeValue != null) {
              return FutureBuilder(
                  future: getProduct(_barcodeValue!),
                  builder: (context, snapshot) {
                    if (snapshot.hasData &&
                        snapshot.connectionState == ConnectionState.done) {
                      _product = snapshot.data as Product;
                      return Container(
                        child: Column(
                          children: [
                            ListTile(
                              leading: IconButton(
                                icon: Icon(Icons.replay_rounded,
                                    color: Theme.of(context).accentColor),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                              title: Text('Is this the item?',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20)),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.check,
                                  color: Theme.of(context).accentColor,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _continue = true;
                                },
                              ),
                            ),
                            Divider(),
                            SizedBox(
                              height: 225,
                              width: MediaQuery.of(context).size.width,
                              child: _product.imageFrontUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: _product.imageFrontUrl!,
                                      progressIndicatorBuilder:
                                          (context, url, downloadProgress) =>
                                              Center(
                                        child: CircularProgressIndicator(
                                            value: downloadProgress.progress),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Icon(Icons.error),
                                      fit: BoxFit.contain,
                                    )
                                  : Icon(Icons.image_not_supported_outlined,
                                      size: 100),
                            ),
                            ListTile(
                              contentPadding:
                                  EdgeInsets.fromLTRB(25, 15, 25, 0),
                              isThreeLine: true,
                              title: Text(_product.productName!),
                              subtitle: Text(_product.brands ??
                                  '' + '\nBarcode: ' + _product.barcode!),
                            )
                          ],
                        ),
                      );
                    } else if (snapshot.hasError) {
                      return SimpleModalError(error: snapshot.error);
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  });
            } else {
              return SimpleModalError();
            }
          });

      if (!_continue) _startStreamToBarcodeScanner();
      if (_continue) _startStreamToTextRecognizer();
    });
  }

  void _showExpiryDateConfirmationModal() {
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      bool _continue = false;
      var _radioGroup = _expiryList[0];
      _turnOffFlash();

      await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (BuildContext context) {
            if (_expiryDateValue.isNotEmpty) {
              return DraggableScrollableSheet(
                  expand: false,
                  maxChildSize: 0.9,
                  builder: (context, scrollableController) {
                    return SingleChildScrollView(
                      controller: scrollableController,
                      child: StatefulBuilder(
                        builder: (context, setState) => Column(
                          children: [
                            ListTile(
                              leading: IconButton(
                                icon: Icon(Icons.replay_rounded,
                                    color: Theme.of(context).accentColor),
                                onPressed: () {
                                  _expiryList = [];
                                  _expiryRawValueList = [];
                                  _isProductBestBefore = false;
                                  Navigator.of(context).pop();
                                },
                              ),
                              title: Text(
                                'Is this the expiry date?',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              trailing: IconButton(
                                icon: Icon(
                                  Icons.check,
                                  color: Theme.of(context).accentColor,
                                ),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  _continue = true;
                                },
                              ),
                            ),
                            Divider(),
                            ListView.builder(
                                itemCount: _expiryList.length,
                                shrinkWrap: true,
                                controller: scrollableController,
                                itemBuilder: (context, index) {
                                  return RadioListTile(
                                      contentPadding:
                                          EdgeInsets.fromLTRB(25, 15, 25, 15),
                                      value: _expiryList[index],
                                      groupValue: _radioGroup,
                                      onChanged: (value) {
                                        setState(() {
                                          _radioGroup = value as DateTime;
                                        });
                                      },
                                      title: Text(DateFormat('dd MMMM y')
                                          .format(_expiryList[index])),
                                      subtitle: Text(
                                          'Scanned: ${_expiryRawValueList[index]}'));
                                }),
                            SwitchListTile(
                                secondary: Icon(Icons.compare),
                                title: Text('Expiry Date is Best Before'),
                                subtitle: Text(
                                    'Switch to on if best before, off if Use By date.'),
                                onChanged: (value) {
                                  _isProductBestBefore = value;
                                  setState(() {});
                                },
                                value: _isProductBestBefore),
                          ],
                        ),
                      ),
                    );
                  });
            } else {
              return SimpleModalError();
            }
          });

      if (!_continue) _startStreamToTextRecognizer();
      if (_continue) {
        Food entry = Food(
            name: (_product.brands == null ? '' : '${_product.brands}: ') +
                _product.productName!,
            picturePath:
                _product.imageFrontUrl == null ? '' : _product.imageFrontUrl,
            expiryDate: _radioGroup,
            isBestBefore: _isProductBestBefore ? 1 : 0,
            note: '',
            pantryId: 1);
        Navigator.pop(context);
        ExpiscanDB.addEntry(foodTableName, entry);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      _cameraInitialized
          ? CameraPreview(_cameraController)
          : Center(
              child: CircularProgressIndicator(),
            ),
      Scaffold(
        appBar: AppBar(
          title: Text('Scan Food\'s ' +
              (_isScanningExpiryDate ? 'Expiry Date' : 'Barcode')),
          backgroundColor: Theme.of(context).accentColor.withOpacity(0.5),
          actions: [
            IconButton(
                icon: _isFlashOn
                    ? Icon(Icons.flash_on_rounded)
                    : Icon(Icons.flash_off_rounded),
                onPressed: () {
                  setState(() {
                    _isFlashOn = !_isFlashOn;
                  });
                  if (_isFlashOn) {
                    _cameraController.setFlashMode(FlashMode.torch);
                  } else {
                    _cameraController.setFlashMode(FlashMode.off);
                  }
                }),
            IconButton(
                icon: Icon(Icons.help_outline_rounded),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (builder) => AlertDialog(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.help_outline_rounded,
                                  color: Theme.of(context).accentColor,
                                ),
                                Text(' Help'),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                    'Point the scanner window to a food product\'s barcode / expiry date and a popup from below will appear.'),
                                SizedBox(height: 10),
                                Text(
                                    'If there isn\'t any image on the popup, you can just add them later in the edit food section.'),
                                SizedBox(height: 10),
                                Text(
                                    'This expiry date scanner only supports Date / Month / Year date formatting.')
                              ],
                            ),
                            actions: [
                              TextButton(
                                  onPressed: Navigator.of(context).pop,
                                  child: Text('CLOSE'))
                            ],
                          ));
                })
          ],
        ),
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                  painter: ScannerBoxPainter(scannerWindow: scannerWindow)),
            ),
            Positioned(
                left: 0,
                right: 0,
                bottom: 50,
                child: Text(
                  _scannerStatus ??
                      'Point the window to a food\'s ' +
                          (_isScanningExpiryDate ? 'expiry date' : 'barcode'),
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ))
          ],
        ),
      )
    ]);
  }
}

class SimpleModalError extends StatelessWidget {
  final Object? error;
  SimpleModalError({this.error = 'null'});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Icon(Icons.error_outline),
          Text('Error, please try again'),
          Text('Err msg: $error'),
          ElevatedButton(
              onPressed: Navigator.of(context).pop, child: Text('Exit'))
        ],
      ),
    );
  }
}
