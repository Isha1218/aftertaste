import 'dart:io';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/material.dart';
import 'package:food_co2_emissions_app/food_info.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:barcode_scan2/barcode_scan2.dart';

// ignore: must_be_immutable
class CustomCameraPage extends StatefulWidget {
  CustomCameraPage({super.key, required this.co2Food});

  Map<String, List<double>> co2Food;

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showScanner = false;
  bool isBarcodeClicked = false;

  @override
  void initState() {
    super.initState();
    print(widget.co2Food);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showScanner = false);
        }
      });

    _animation = Tween<double>(begin: 0, end: 260).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> scanBarcode() async {
    try {
      var result = await BarcodeScanner.scan(
          options: ScanOptions(strings: {'cancel': 'Back'}));

      if (result.type == ResultType.Barcode) {
        final scannedCode = result.rawContent;
        print('Scanned barcode: $scannedCode');
        setState(() {
          isBarcodeClicked = true;
        });
        await fetchCo2DataFromBarcode(scannedCode);
        setState(() {
          isBarcodeClicked = false;
        });
        if (widget.co2Food.isNotEmpty) {
          final result =
              await Navigator.of(context).push<Map<String, List<double>>>(
            MaterialPageRoute(
              builder: (context) => FoodInfo(
                co2Food: Map.fromEntries(
                  widget.co2Food.entries.toList()
                    ..sort((a, b) => b.value[0].compareTo(a.value[0])),
                ),
              ),
            ),
          );
          if (result != null) {
            setState(() {
              widget.co2Food = result;
            });
          }
        }
      } else {
        print('Scan cancelled or failed');
      }
    } catch (e) {
      print('Barcode scan error: $e');
    }
  }

  Future<void> fetchCo2DataFromBarcode(String barcode) async {
    var url = Uri.parse(
        'http://192.168.0.19:5000/get_co2_emissions_from_barcode?code=$barcode');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        widget.co2Food = decoded.map((key, value) {
          final listDynamic = value as List<dynamic>;
          final listDouble =
              listDynamic.map((e) => (e as num).toDouble()).toList();
          return MapEntry(key, listDouble);
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get CO2 data for barcode')));
      print('Failed to get CO2 data for barcode');
    }
  }

  Future<void> sendImage(
      String path, double screenWidth, double screenHeight) async {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final originalImage = img.decodeImage(bytes);

    if (originalImage == null) {
      print('Failed to decode image');
      return;
    }

    const scanBoxWidth = 300.0;
    const scanBoxHeight = 300.0;
    final imgWidth = originalImage.width;
    final imgHeight = originalImage.height;

    final heightScale = imgHeight / screenHeight;
    final widthScale = imgWidth / screenWidth;

    final cropWidth = (scanBoxWidth * widthScale).round();
    final cropHeight = (scanBoxHeight * heightScale).round();
    final cropX = ((imgWidth - cropWidth) / 2).round();
    final cropY = ((imgHeight - cropHeight) / 2).round();

    final cropped = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
    );

    final croppedPath =
        '${file.parent.path}/cropped_${file.uri.pathSegments.last}';
    final croppedFile = File(croppedPath)
      ..writeAsBytesSync(img.encodeJpg(cropped));

    var uri =
        Uri.parse('http://192.168.0.19:5000/get_co2_emissions_from_image');
    var request = http.MultipartRequest('POST', uri);
    request.files
        .add(await http.MultipartFile.fromPath('image', croppedFile.path));
    var response = await request.send();

    if (response.statusCode == 200) {
      final resp = await response.stream.bytesToString();
      print('Uploaded successfully');
      print(resp);
      setState(() {
        final Map<String, dynamic> decoded = jsonDecode(resp);
        widget.co2Food = decoded.map((key, value) {
          final listDynamic = value as List<dynamic>;
          final listDouble =
              listDynamic.map((e) => (e as num).toDouble()).toList();
          return MapEntry(key, listDouble);
        });
        print(widget.co2Food);
      });
    } else {
      print('Failed with status: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;

    return isBarcodeClicked
        ? Scaffold(
            backgroundColor: const Color(0xffFCEACC),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Colors.white,
                  ),
                  SizedBox(
                    height: 10,
                  ),
                  Text(
                    'This may take a moment...',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  )
                ],
              ),
            ),
          )
        : Scaffold(
            body: Stack(
              children: [
                CameraAwesomeBuilder.awesome(
                  previewFit: CameraPreviewFit.fitHeight,
                  saveConfig: SaveConfig.photo(),
                  topActionsBuilder: (state) {
                    return Container(
                      alignment: Alignment.topRight,
                      child: TextButton(
                          onPressed: () async {
                            await scanBarcode();
                          },
                          child: CircleAvatar(
                              backgroundColor: Colors.orange,
                              radius: 30,
                              child: Icon(
                                FontAwesomeIcons.barcode,
                                size: 20,
                                color: Colors.white,
                              ))),
                    );
                  },
                  middleContentBuilder: (state) => Container(),
                  bottomActionsBuilder: (state) => AwesomeBottomActions(
                    state: state,
                    left: Container(),
                    right: Container(),
                  ),
                  theme: AwesomeTheme(
                      bottomActionsBackgroundColor: Colors.transparent),
                  onMediaCaptureEvent: (mediaCapture) async {
                    if (mediaCapture.status == MediaCaptureStatus.success) {
                      setState(() => _showScanner = true);
                      _controller.forward(from: 0);
                      await sendImage(mediaCapture.captureRequest.path!,
                          screenSize.width, screenSize.height);
                      if (widget.co2Food.isNotEmpty) {
                        final result = await Navigator.of(context)
                            .push<Map<String, List<double>>>(
                          MaterialPageRoute(
                            builder: (context) => FoodInfo(
                              co2Food: Map.fromEntries(
                                widget.co2Food.entries.toList()
                                  ..sort((a, b) =>
                                      b.value[0].compareTo(a.value[0])),
                              ),
                            ),
                          ),
                        );

                        if (result != null) {
                          setState(() {
                            widget.co2Food = result;
                          });
                        }
                      }
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: !widget.co2Food.isEmpty
                        ? Container()
                        : Stack(
                            children: [
                              _buildCorner(top: 0, left: 0),
                              _buildCorner(top: 0, right: 0),
                              _buildCorner(bottom: 0, left: 0),
                              _buildCorner(bottom: 0, right: 0),
                              if (_showScanner)
                                AnimatedBuilder(
                                  animation: _animation,
                                  builder: (context, child) {
                                    return Positioned(
                                        top: _animation.value,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          height: 50,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [
                                                Colors.green,
                                                Colors.green.withOpacity(0),
                                              ],
                                            ),
                                          ),
                                        ));
                                  },
                                ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          );
  }

  Widget _buildCorner(
      {double? top, double? left, double? right, double? bottom}) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: SizedBox(
        width: 40,
        height: 40,
        child: CustomPaint(
          painter: _CornerPainter(
            isTop: bottom == null,
            isLeft: left != null,
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;

  _CornerPainter({required this.isTop, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final radius = 12.0;

    if (isTop && isLeft) {
      path.moveTo(size.width, 0);
      path.lineTo(radius, 0);
      path.arcToPoint(Offset(0, radius),
          radius: Radius.circular(radius), clockwise: false);
      path.lineTo(0, size.height);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width - radius, 0);
      path.arcToPoint(Offset(size.width, radius),
          radius: Radius.circular(radius), clockwise: true);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(size.width, size.height);
      path.lineTo(radius, size.height);
      path.arcToPoint(Offset(0, size.height - radius),
          radius: Radius.circular(radius), clockwise: true);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width - radius, size.height);
      path.arcToPoint(Offset(size.width, size.height - radius),
          radius: Radius.circular(radius), clockwise: false);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
