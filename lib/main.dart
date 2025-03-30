import 'package:flutter/material.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:vector_math/vector_math_64.dart';

void main() {
  runApp(MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: Text("ARCore com Flutter")),
      body: ARViewExample(),
    ),
  ));
}

class ARViewExample extends StatefulWidget {
  @override
  _ARViewExampleState createState() => _ARViewExampleState();
}

class _ARViewExampleState extends State<ARViewExample> {
  ArCoreController? arCoreController;

  void _onArCoreViewCreated(ArCoreController controller) {
    arCoreController = controller;
    _add3DModel();
  }

  void _add3DModel() {
    final node = ArCoreReferenceNode(
      name: "MeuModelo3D",
      object3DFileName: "eevee.fbx",
      position: Vector3(0, 0, -1), // Posição relativa à câmera
      scale: Vector3(0.5, 0.5, 0.5), // Ajuste conforme necessário
    );
    arCoreController?.addArCoreNode(node);
  }

  @override
  void dispose() {
    arCoreController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArCoreView(
      onArCoreViewCreated: _onArCoreViewCreated,
    );
  }
}
