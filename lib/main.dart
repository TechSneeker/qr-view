import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';
import 'package:vector_math/vector_math_64.dart' as vector_math;
import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';

/// Mapeamento do valor do QR Code para os dados do Pokémon:
/// 'score' é um valor em que 100 equivale ao tamanho base e 50 à metade.
final Map<String, Map<String, dynamic>> qrToPokemonData = {
  'pikachu': {
    'asset': 'assets/pikachu/scene.gltf',
    'score': 1,
  },
  'eevee': {
    'asset': 'assets/eevee/scene.gltf',
    'score': 100,
  }
};

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AR QR Pokémon',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const QRScanScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Tela para escanear o QR Code
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});
  
  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  Barcode? result;
  QRViewController? controller;
  
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Scan')),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: (result != null)
                  ? Text('Data: ${result!.code}')
                  : const Text('Escaneie um código'),
            ),
          )
        ],
      ),
    );
  }
  
  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    controller.scannedDataStream.listen((scanData) {
      if (mounted) {
        setState(() {
          result = scanData;
        });
        // Convertendo o valor para minúsculas para o mapeamento
        String qrValue = scanData.code!.toLowerCase();
        if (qrToPokemonData.containsKey(qrValue)) {
          controller.pauseCamera();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ARViewScreen(
                pokemonAsset: qrToPokemonData[qrValue]!['asset'],
                score: qrToPokemonData[qrValue]!['score'],
              ),
            ),
          );
        } else {
          if (kDebugMode) {
            print("QR Code desconhecido: $qrValue");
          }
        }
      }
    });
  }
  
  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}

/// Tela AR que renderiza o modelo 3D do Pokémon com base no asset e score passados.
class ARViewScreen extends StatefulWidget {
  final String pokemonAsset;
  final int score; // Ex: 100 = tamanho base, 50 = metade
  const ARViewScreen({super.key, required this.pokemonAsset, required this.score});
  
  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  
  ARAnchor? pokemonAnchor;
  ARNode? pokemonNode;
  bool modelAdded = false;
  
  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Pokémon')),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          // Botão para remover o modelo
          Positioned(
            bottom: 20,
            right: 20,
            child: Visibility(
              visible: modelAdded,
              child: FloatingActionButton.small(
                onPressed: removerModelo,
                tooltip: 'Remover Modelo',
                child: const Icon(Icons.delete),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    
    arSessionManager.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
    );
    
    arObjectManager.onInitialize();
    
    // Ao tocar em um plano, adiciona o modelo
    arSessionManager.onPlaneOrPointTap = onPlaneTapped;
  }
  
  Future<void> onPlaneTapped(List<ARHitTestResult> hits) async {
    if (modelAdded) return;
    
    final hit = hits.firstWhere(
      (r) => r.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );
    
    final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
    final didAddAnchor = await arAnchorManager!.addAnchor(anchor);
    if (didAddAnchor != true) return;
    
    // Calcula o fator de escala baseado no score
    double scaleFactor = widget.score / 100.0;
    // Definimos a escala base como (0.5, 0.5, 0.5)
    final baseScale = vector_math.Vector3(0.5, 0.5, 0.5);
    final adjustedScale = baseScale * scaleFactor;
    
    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: widget.pokemonAsset,
      scale: adjustedScale,
      position: vector_math.Vector3(0.0, 0.0, 0.0),
      rotation: vector_math.Vector4(0.0, 1.0, 0.0, 0.0),
    );
    
    final didAddNode = await arObjectManager!.addNode(node, planeAnchor: anchor);
    if (didAddNode != true) return;
    
    setState(() {
      modelAdded = true;
      pokemonAnchor = anchor;
      pokemonNode = node;
    });
  }
  
  Future<void> removerModelo() async {
    if (pokemonNode != null) {
      await arObjectManager!.removeNode(pokemonNode!);
    }
    if (pokemonAnchor != null) {
      await arAnchorManager!.removeAnchor(pokemonAnchor!);
    }
    
    setState(() {
      modelAdded = false;
      pokemonNode = null;
      pokemonAnchor = null;
    });
  }
}
