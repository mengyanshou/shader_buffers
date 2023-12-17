// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:shader_buffers/src/imouse.dart';

/// class to define the kind of channel textures that will
/// be used by [LayerBuffer].
///
/// Only one of the parameters can be given.
class IChannel {
  IChannel({
    this.child,
    this.buffer,
    this.assetsTexturePath,
    this.isSelf = false,
  }) : assert(
          !(!isSelf &&
              child != null &&
              buffer != null &&
              assetsTexturePath != null),
          'Only [isSelf] or [child] or [buffer] or [assetsTexturePath]'
          ' must be given!',
        );

  /// the widget used by this [IChannel]
  final Widget? child;

  /// the assets image if [child] exists
  ui.Image? childTexture;

  final bool isSelf;

  /// the buffer used by this [IChannel]
  LayerBuffer? buffer;

  /// the assets image path used by this [IChannel]
  String? assetsTexturePath;

  /// the assets image if [assetsTexturePath] exists
  ui.Image? assetsTexture;

  /// all textures loaded?
  bool isInited = false;

  /// eventually load textures
  Future<bool> init() async {
    if (isInited) return true;

    isInited = true;
    // Load all the assets textures
    if (assetsTexturePath != null) {
      try {
        final assetImageByteData = await rootBundle.load(assetsTexturePath!);
        final codec = await ui.instantiateImageCodec(
          assetImageByteData.buffer.asUint8List(),
        );
        assetsTexture = (await codec.getNextFrame()).image;
      } catch (e) {
        debugPrint('Error loading assets image! $e');
        isInited = false;
      }
    }

    return isInited;
  }
}

/// Class used to define a buffers or the main image layer.
///
class LayerBuffer {
  /// Class used to define a buffers or the main image.
  ///
  /// It takes the [shaderAssetsName] and a list of [IChannel]
  /// used as textures.
  ///
  /// ```dart
  /// final bufferA = LayerBuffer(
  ///   shaderAssetsName: 'assets/shaders/shader3_bufferA.glsl',
  /// );
  /// // you can then set optional channels:
  /// bufferA.setChannels([
  ///   IChannel(buffer: bufferA),
  ///   IChannel(assetsTexturePath: 'assets/bricks.jpg'),
  /// ]);
  /// ```
  LayerBuffer({
    required this.shaderAssetsName,
    this.floatUniforms,
  });

  /// The fragment shader source to use
  final String shaderAssetsName;

  /// additional floats uniforms
  List<double>? floatUniforms;

  /// the channels this shader will use
  List<IChannel>? channels;

  /// the fragment program used by this layer
  ui.FragmentProgram? _program;

  /// the fragment shader used by this layer
  ui.FragmentShader? _shader;

  /// The last image computed
  ui.Image? layerImage;

  /// Used internally when shader or channel are not yet initialized
  ui.Image? blankImage;

  List<void Function()> conditionalOperation = [];

  /// set channels of this layer
  void setChannels(List<IChannel> chan) {
    channels = chan.toList();
  }

  /// swap channels
  void swapChannels(int index1, int index2) {
    if (channels?.isEmpty ?? true) return;
    RangeError.checkValidIndex(index1, channels, 'index1');
    RangeError.checkValidIndex(index2, channels, 'index2');
    final tmp = channels![index1];
    channels![index1] = channels![index2];
    channels![index2] = tmp;
  }

  /// Initialize the shader and the textures if any
  Future<bool> init() async {
    var loaded = true;
    loaded = await _loadShader();
    loaded &= await _loadIAssetsTextures();
    debugPrint('LayerBuffer.init() loaded: $loaded  $shaderAssetsName');
    return loaded;
  }

  /// load fragment shader
  Future<bool> _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset(shaderAssetsName);
      _shader = _program?.fragmentShader();
    } on Exception catch (e) {
      debugPrint('Cannot load shader $shaderAssetsName! $e');
      return false;
    }
    return true;
  }

  /// load the blank image and initialize all channel textures
  Future<bool> _loadIAssetsTextures() async {
    /// setup blankImage. Displayed when the layerImage is not yet available
    try {
      final assetImageByteData = await rootBundle
          .load('packages/shader_buffers/assets/blank_16x16.bmp');
      final codec = await ui.instantiateImageCodec(
        assetImageByteData.buffer.asUint8List(),
      );
      blankImage = (await codec.getNextFrame()).image;
    } on Exception catch (e) {
      debugPrint('Cannot load blankImage! $e');
      return false;
    }

    // Load all the assets textures if any
    if (channels == null) return true;
    for (var i = 0; i < channels!.length; ++i) {
      for (final element in channels!) {
        if (!element.isInited) {
          if (!await channels![i].init()) return false;
        }
      }
    }
    return true;
  }

  void dispose() {
    // _shader?.dispose();
    layerImage?.dispose();
    layerImage = null;
  }

  /// draw the shader into [layerImage]
  /// clear cache mem
  /// sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
  void computeLayer(
    Size iResolution,
    double iTime,
    double iFrame,
    IMouse iMouse,
  ) {
    if (_shader == null) return;

    for (final f in conditionalOperation) {
      f();
    }

    _shader!
      ..setFloat(0, iResolution.width) // iResolution
      ..setFloat(1, iResolution.height)
      ..setFloat(2, iTime) // iTime
      ..setFloat(3, iFrame) // iFrame
      ..setFloat(4, iMouse.x) // iMouse
      ..setFloat(5, iMouse.y)
      ..setFloat(6, iMouse.z)
      ..setFloat(7, iMouse.w);

    /// eventually add more floats uniforms from [floatsUniforms]
    for (var i = 8; i < (floatUniforms?.length ?? 0) + 8; i++) {
      _shader!.setFloat(i, floatUniforms![i - 8]);
    }

    /// eventually add sampler2D uniforms
    for (var i = 0; i < (channels?.length ?? 0); i++) {
      if (channels![i].assetsTexturePath != null) {
        _shader!.setImageSampler(i, channels![i].assetsTexture ?? blankImage!);
      } else if (channels![i].child != null) {
        _shader!.setImageSampler(i, channels![i].childTexture ?? blankImage!);
      } else {
        _shader!.setImageSampler(
          i,
          channels![i].isSelf
              ? layerImage ?? blankImage!
              : channels![i].buffer?.layerImage ?? blankImage!,
        );
      }
    }

    layerImage?.dispose();
    layerImage = null;

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      Offset.zero & iResolution,
      ui.Paint()..shader = _shader,
    );
    final picture = recorder.endRecording();
    layerImage = picture.toImageSync(
      iResolution.width.ceil(),
      iResolution.height.ceil(),
    );
    picture.dispose();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayerBuffer &&
          runtimeType == other.runtimeType &&
          shaderAssetsName == other.shaderAssetsName &&
          channels == other.channels &&
          _program == other._program &&
          _shader == other._shader;

  @override
  int get hashCode =>
      shaderAssetsName.hashCode ^
      channels.hashCode ^
      _program.hashCode ^
      _shader.hashCode;
}
