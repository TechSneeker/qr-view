import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:flutter/rendering.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Code Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  late ArCoreController arCoreController;
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  final GlobalKey repaintBoundaryKey = GlobalKey();

  QRViewController? controller;
  bool isImageVisible = false;
  bool isTransitioning = false;
  Uint8List? frozenImage;
  double opacity = 1.0;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          if (!isImageVisible)
            RepaintBoundary(
              key: repaintBoundaryKey,
              child: QRView(
                key: qrKey,
                onQRViewCreated: _onQRViewCreated,
                overlay: QrScannerOverlayShape(
                  borderColor: Colors.red,
                  borderRadius: 10,
                  borderLength: 30,
                  borderWidth: 10,
                  cutOutSize: 300,
                ),
              ),
            ),

          if (frozenImage != null)
            AnimatedOpacity(
              duration: Duration(milliseconds: 700),
              opacity: opacity,
              child: Image.memory(
                frozenImage!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),

          if (isImageVisible)
            ArCoreView(onArCoreViewCreated: _onArCoreViewCreated),
        ],
      ),
    );
  }

  void _onQRViewCreated(QRViewController ctrl) {
    controller = ctrl;
    controller!.scannedDataStream.listen((scanData) async {
      final code = scanData.code;
      print("QR Code detectado: $code");

      if (code != null && !isTransitioning) {
        isTransitioning = true;

        // Captura a imagem da câmera
        final boundary = repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final ui.Image image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        frozenImage = byteData!.buffer.asUint8List();

        setState(() {}); // Atualiza com a imagem congelada

        // Faz o fade-out da imagem
        await Future.delayed(Duration(milliseconds: 100));
        setState(() {
          opacity = 0.0;
        });

        // Espera o fade-out terminar
        await Future.delayed(Duration(milliseconds: 700));

        // Troca para AR
        controller?.pauseCamera();
        setState(() {
          isImageVisible = true;
          frozenImage = null;
        });
      }
    });
  }

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    _addSphere(arCoreController);
    _addCylindre(arCoreController);
    _addCube(arCoreController);
  }

  void _addSphere(ArCoreController controller) {
    final material = ArCoreMaterial(color: Color.fromARGB(120, 66, 134, 244));
    final sphere = ArCoreSphere(materials: [material], radius: 0.1);
    final node = ArCoreNode(shape: sphere, position: vector.Vector3(0, 0, -1.5));
    controller.addArCoreNode(node);
  }

  void _addCylindre(ArCoreController controller) {
    final material = ArCoreMaterial(color: Colors.red, reflectance: 1.0);
    final cylindre = ArCoreCylinder(materials: [material], radius: 0.5, height: 0.3);
    final node = ArCoreNode(shape: cylindre, position: vector.Vector3(0.0, -0.5, -2.0));
    controller.addArCoreNode(node);
  }

  void _addCube(ArCoreController controller) {
    final material = ArCoreMaterial(color: Color.fromARGB(120, 66, 134, 244), metallic: 1.0);
    final cube = ArCoreCube(materials: [material], size: vector.Vector3(0.5, 0.5, 0.5));
    final node = ArCoreNode(shape: cube, position: vector.Vector3(-0.5, 0.5, -3.5));
    controller.addArCoreNode(node);
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
