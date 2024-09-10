import 'package:flutter/material.dart';
import 'package:shader_buffers/shader_buffers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          ShaderBuffers(
          height: 300,
            controller: ShaderController(),
            mainImage: LayerBuffer(
              shaderAssetsName: 'shaders/Mario World.frag',
            ),
          ),
          ShaderBuffers(
            height: 300,
            key: UniqueKey(),
            controller: ShaderController(),
            mainImage: LayerBuffer(
              shaderAssetsName: 'shaders/Broken Time Portal.frag',
            )..setChannels([IChannel(assetsTexturePath: 'assets/Noise Image Generator.png')]),
          ),
        ],
      ),
    );
  }
}
