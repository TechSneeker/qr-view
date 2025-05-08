import 'package:flutter/material.dart';
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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eevee AR',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const EeveeARView(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class EeveeARView extends StatefulWidget {
  const EeveeARView({super.key});

  @override
  State<EeveeARView> createState() => _EeveeARViewState();
}

class _EeveeARViewState extends State<EeveeARView> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  ARAnchor? eeveeAnchor;
  ARNode? eeveeNode;
  bool eeveeAdicionado = false;

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eevee AR')),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: Visibility(
              visible: eeveeAdicionado,
              child: FloatingActionButton.small(
                onPressed: removerEevee,
                tooltip: 'Remover Eevee',
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

    arSessionManager.onPlaneOrPointTap = onPlaneTapped;
  }

  Future<void> onPlaneTapped(List<ARHitTestResult> hits) async {
    if (eeveeAdicionado) return;

    final hit = hits.firstWhere(
      (r) => r.type == ARHitTestResultType.plane,
      orElse: () => hits.first,
    );

    final anchor = ARPlaneAnchor(transformation: hit.worldTransform);
    final didAddAnchor = await arAnchorManager!.addAnchor(anchor);
    if (didAddAnchor != true) return;

    final node = ARNode(
      type: NodeType.localGLTF2,
      uri: "assets/espeon/scene.gltf",
      scale: vector_math.Vector3(0.5, 0.5, 0.5),
      position: vector_math.Vector3(0.0, 0.0, 0.0),
      rotation: vector_math.Vector4(0.0, 1.0, 0.0, 0.0),
    );

    final didAddNode = await arObjectManager!.addNode(node, planeAnchor: anchor);
    if (didAddNode != true) return;

    setState(() {
      eeveeAdicionado = true;
      eeveeAnchor = anchor;
      eeveeNode = node;
    });
  }

  Future<void> removerEevee() async {
    if (eeveeNode != null) {
      await arObjectManager!.removeNode(eeveeNode!);
    }
    if (eeveeAnchor != null) {
      await arAnchorManager!.removeAnchor(eeveeAnchor!);
    }

    setState(() {
      eeveeAdicionado = false;
      eeveeNode = null;
      eeveeAnchor = null;
    });
  }
}
