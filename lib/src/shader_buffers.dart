// ignore_for_file: avoid_positional_boolean_parameters

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shader_buffers/src/custom_child.dart';
import 'package:shader_buffers/src/custom_shader_paint.dart';
import 'package:shader_buffers/src/i_channel.dart';
import 'package:shader_buffers/src/imouse.dart';
import 'package:shader_buffers/src/layer_buffer.dart';

/// the operation parameter to build the check
typedef Operation = ({
  /// the [LayerBuffer] which this check is binded to
  LayerBuffer layerBuffer,

  /// the parameter to check
  Param param,

  /// the type of operator to use (>, <, ==)
  CheckOperator checkType,

  /// the value to check
  double checkValue,

  /// the operation result to give back to dev
  void Function(ShaderController controller, bool result) operation,
});

/// parameter to check
enum Param {
  /// check X pointer position on the texture
  iMouseX,

  /// check X pointer position on the texture normalized to 0~1 range
  iMouseXNormalized,

  /// check Y pointer position on the texture
  iMouseY,

  /// check Y pointer position on the texture normalized to 0~1 range
  iMouseYNormalized,

  /// check current iTime
  iTime,

  /// check current iFrame
  iFrame,
}

/// Type of check to use (>, <, ==)
enum CheckOperator {
  /// <
  minor,

  /// >
  major,

  /// ==
  equal,
}

/// Current state of the [ShaderBuffers] widget.
enum ShaderState {
  none,
  paused,
  playing,
}

///
class ShaderController {
  void Function(Operation)? _addConditionalOperation;
  VoidCallback? _pause;
  VoidCallback? _play;
  VoidCallback? _rewind;
  void Function(LayerBuffer layer, int index1, int index2)? _swapChannels;
  ShaderState Function()? _getState;
  IMouse Function()? _getIMouse;
  IMouse Function()? _getIMouseNormalized;

  /// list of all defined operations for this controller
  List<Operation> conditionalOperation = [];

  void _setController(
    void Function(Operation) addConditionalOperation,
    VoidCallback pause,
    VoidCallback play,
    VoidCallback rewind,
    void Function(LayerBuffer layer, int index1, int index2)? swapChannels,
    ShaderState Function() getState,
    IMouse Function() getIMouse,
    IMouse Function() getIMouseNormalized,
  ) {
    _addConditionalOperation = addConditionalOperation;
    _pause = pause;
    _play = play;
    _rewind = rewind;
    _swapChannels = swapChannels;
    _getState = getState;
    _getIMouse = getIMouse;
    _getIMouseNormalized = getIMouseNormalized;
  }

  /// add an operation for checking on every frame using the given [params]
  ///
  /// ```dart
  /// // on every frame this will be checked in [shader.mainImage] buffer.
  /// // The [operation] callback will send back the
  /// // result of '(iMouseXNormalized is < 0.5)`
  /// controller.addConditionalOperation(
  ///   (
  ///     layerBuffer: shader.mainImage,
  ///     param: Param.iMouseXNormalized,
  ///     checkType: CheckOperator.minor,
  ///     checkValue: 0.5,
  ///     operation: (result) {
  ///       print('(iMouseXNormalized is < 0.5) is $result');
  ///     },
  ///   ),
  /// );
  /// ```
  void addConditionalOperation(Operation params) {
    if (_addConditionalOperation == null) {
      conditionalOperation.add(params);
    } else {
      _addConditionalOperation?.call(params);
    }
  }

  /// pause
  void pause() => _pause?.call();

  /// play
  void play() => _play?.call();

  /// reset iTime and iFrameto zero
  void rewind() => _rewind?.call();

  /// Swap channel with [index1] and [index2] of layer [layer]
  void swapChannels(LayerBuffer layer, int index1, int index2) =>
      _swapChannels?.call(layer, index1, index2);

  /// return the state
  ShaderState getState() => _getState?.call() ?? ShaderState.none;

  /// get the mouse position
  IMouse getIMouse() => _getIMouse?.call() ?? IMouse.zero;

  /// get the mouse position normalized to 0~1
  IMouse getIMouseNormalized() => _getIMouseNormalized?.call() ?? IMouse.zero;
}

/// Widget to paint the shader with the given [LayerBuffer]s.
///
class ShaderBuffers extends StatefulWidget {
  /// [mainImage] shader must be given.
  /// The more [buffers] the more performances will be affected.
  ///
  /// Think of [mainImage] as the `Image` layer fragment
  /// and [buffers] as `Buffer[A-D]` in ShaderToy.com
  /// [mainImage] layer image is the one displayed.
  ///
  /// Each image [buffers] are computed from the 1st to the last,
  /// then [mainImage] that will display the resulting image.
  ///
  /// This widget provides to the fragment shader the following uniforms:
  /// * `sampler2D iChannel[0-N] as many as defined in [LayerBuffer.channels]
  /// * `vec2 iResolution` the widget width and height
  /// * `float iTime` the current time in seconds from the start of rendering
  /// * `float iFrame` the currentrendering frame number
  /// * `vec4 iMouse` for the user interaction with pointer. See [IMouse]
  ///
  /// ```dart
  /// /// The main layer uses `shader_main.frag` as fragment shader source and some float uniforms
  /// final mainImage = LayerBuffer(
  ///   shaderAssetsName: 'assets/shaders/shader_main.glsl',
  ///   floatUniforms: [0.5, 1],
  /// );
  /// /// This [LayerBuffer] uses 'shader_bufferA.glsl' as the fragment shader
  /// /// and a channel that uses an assets image.
  /// final bufferA = LayerBuffer(
  ///   shaderAssetsName: 'assets/shaders/shader_bufferA.glsl',
  /// );
  /// /// Then you can optionally assign to it the input textures needed by the fragment
  /// bufferA.setChannels([
  ///   IChannel(assetsTexturePath: 'assets/bricks.jpg'),
  /// ]);
  /// /// This [LayerBuffer] uses 'shader_bufferB.glsl' as the fragment shader
  /// /// and `bufferA` as texture
  /// final bufferB = LayerBuffer(
  ///   shaderAssetsName: 'assets/shaders/shader_bufferB.glsl',
  /// ),
  /// bufferB.setChannels([
  ///   IChannel(buffer: bufferA),
  /// ]);
  ///
  /// ShaderBuffer(
  ///   mainImage: mainImage,
  ///   buffers: [ bufferA, bufferB ],
  /// )
  /// ```
  const ShaderBuffers({
    required this.mainImage,
    required this.controller,
    this.width,
    this.height,
    this.startPaused = false,
    this.buffers = const[],
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerDownNormalized,
    this.onPointerMoveNormalized,
    this.onPointerUpNormalized,
    super.key,
  });

  /// The width of texture used by this widget if there are no layers with
  /// an IChannel using a child widget.
  final double? width;

  /// The height of texture used by this widget if there are no layers with
  /// an IChannel using a child widget.
  final double? height;

  /// Whether or not to start ticking
  final bool startPaused;

  /// Main layer shader.
  final LayerBuffer mainImage;

  /// Other optional channels
  final List<LayerBuffer> buffers;

  /// controller for this widget.
  final ShaderController controller;

  /// pointer callbacks to get position in texture size range.
  final void Function(ShaderController controller, Offset position)?
      onPointerDown;
  final void Function(ShaderController controller, Offset position)?
      onPointerMove;
  final void Function(ShaderController controller, Offset position)?
      onPointerUp;

  /// pointer callbacks to get normalized position 0~1 range
  final void Function(ShaderController controller, Offset position)?
      onPointerDownNormalized;
  final void Function(ShaderController controller, Offset position)?
      onPointerMoveNormalized;
  final void Function(ShaderController controller, Offset position)?
      onPointerUpNormalized;

  @override
  State<ShaderBuffers> createState() => _ShaderBuffersState();
}

class _ShaderBuffersState extends State<ShaderBuffers>
    with TickerProviderStateMixin {
  Ticker? ticker;
  late Stopwatch iTime;
  late IMouseController iMouse;
  late double iFrame;
  late bool isInitialized;
  late bool startPausedAccomplished;
  late ShaderState state;
  late Offset startingPosition;
  late bool hasChildren;
  late BoxConstraints previousConstraints;
  final layers = <Widget>[];
  ValueNotifier<int> relayout = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() {
    ticker?.dispose();
    iMouse = IMouseController(width: 10, height: 10);
    startingPosition = const Offset(1, 1);
    iFrame = 0;
    iTime = Stopwatch();
    ticker = createTicker(tick);
    relayout.value = DateTime.now().millisecondsSinceEpoch;

    if (!widget.startPaused) {
      _play();
    } else {
      _pause();
    }

    /// setup the controller for this widget
    widget.controller._setController(
      _addConditionalOperation,
      _pause,
      _play,
      _rewind,
      _swapChannels,
      _getState,
      _getIMouse,
      _getIMouseNormalized,
    );

    layoutChildren();

    // Add the additional operations after the 1st frame built
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      /// eventually add the operations added before putting this
      /// in the widgets tree
      if (widget.controller.conditionalOperation.isNotEmpty) {
        for (final f in widget.controller.conditionalOperation) {
          _addConditionalOperation(f);
        }
        widget.controller.conditionalOperation.clear();
      }
    });
  }

  /// Add the children of all [IChannel](s)
  /// If an [IChannel] has a child, add it using [CustomChildBuilder] else
  /// using a [RawImage] of the computed shader image
  void layoutChildren() {
    /// The [layers] list contains at first the [mainImage] and then all the
    /// [buffer] [IChannel]s.
    /// The size of the main widget displayed is relative to the first child
    /// in this list. If there are no children, the size is taken from
    /// parent constraints.
    layers.clear();
    for (var i = (widget.mainImage.channels?.length ?? 0) - 1; i >= 0; i--) {
      if (widget.mainImage.channels![i].child != null) {
        layers.add(
          CustomChildBuilder(
            layerChannel: widget.mainImage.channels![i],
            enabled: state == ShaderState.playing,
            child: widget.mainImage.channels![i].child,
          ),
        );
      } else {
        layers.add(RawImage(image: widget.mainImage.layerImage?.clone()));
      }
    }

    for (var n = 0; n < widget.buffers.length; n++) {
      for (var i = (widget.buffers[n].channels?.length ?? 0) - 1;
          i >= 0;
          i--) {
        if (widget.buffers[n].channels![i].child != null) {
          layers.add(
            CustomChildBuilder(
              layerChannel: widget.buffers[n].channels![i],
              enabled: state == ShaderState.playing,
              child: widget.buffers[n].channels![i].child,
            ),
          );
        } else {
          layers.add(RawImage(image: widget.buffers[n].layerImage?.clone()));
        }
      }
    }
  }

  void _pause() {
    if (ticker?.isActive ?? false) {
      state = ShaderState.paused;
      iTime.stop();
      ticker?.stop();
    }
  }

  void _play() {
    if (!(ticker?.isActive ?? false)) {
      state = ShaderState.playing;
      iMouse.start(startingPosition);
      ticker?.start();
      iTime.start();
    }
  }

  void _rewind() {
    iMouse
      ..start(startingPosition)
      ..end();
    iFrame = 0;
    iTime.reset();
    if (state == ShaderState.paused) {
      Future.delayed(Duration.zero, () {
        relayout.value = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  /// swap channels
  void _swapChannels(LayerBuffer layer, int index1, int index2) {
    if (layer.channels?.isEmpty ?? true) return;
    RangeError.checkValidIndex(index1, layer.channels, 'index1');
    RangeError.checkValidIndex(index2, layer.channels, 'index2');
    final tmp = layer.channels![index1];
    layer.channels![index1] = layer.channels![index2];
    layer.channels![index2] = tmp;
    layoutChildren();
  }

  ShaderState _getState() => state;

  /// Add the callback function operations.
  void _addConditionalOperation(Operation p) {
    switch (p.param) {
      case Param.iMouseX:
        switch (p.checkType) {
          case CheckOperator.minor:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.iMouse.x < p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.major:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.iMouse.x > p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.equal:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.iMouse.x == p.checkValue,
                  );
                }
              },
            );
        }

      case Param.iMouseXNormalized:
        switch (p.checkType) {
          case CheckOperator.minor:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.getIMouseNormalized().x < p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.major:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.getIMouseNormalized().x > p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.equal:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.getIMouseNormalized().x == p.checkValue,
                  );
                }
              },
            );
        }

      case Param.iMouseY:
        switch (p.checkType) {
          case CheckOperator.minor:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.iMouse.y < p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.major:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.iMouse.y > p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.equal:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.iMouse.y == p.checkValue,
                  );
                }
              },
            );
        }

      case Param.iMouseYNormalized:
        switch (p.checkType) {
          case CheckOperator.minor:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.getIMouseNormalized().y < p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.major:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.getIMouseNormalized().y > p.checkValue,
                  );
                }
              },
            );
          case CheckOperator.equal:
            p.layerBuffer.conditionalOperation.add(
              () {
                if (iMouse.currState == PointerState.onPointerMove) {
                  p.operation(
                    widget.controller,
                    iMouse.getIMouseNormalized().y == p.checkValue,
                  );
                }
              },
            );
        }

      case Param.iTime:
        switch (p.checkType) {
          case CheckOperator.minor:
            p.layerBuffer.conditionalOperation.add(
              () => p.operation(
                widget.controller,
                iTime.elapsedMilliseconds < p.checkValue,
              ),
            );
          case CheckOperator.major:
            p.layerBuffer.conditionalOperation.add(
              () => p.operation(
                widget.controller,
                iTime.elapsedMilliseconds > p.checkValue,
              ),
            );
          case CheckOperator.equal:
            p.layerBuffer.conditionalOperation.add(
              () => p.operation(
                widget.controller,
                iTime.elapsedMilliseconds == p.checkValue,
              ),
            );
        }

      case Param.iFrame:
        switch (p.checkType) {
          case CheckOperator.minor:
            p.layerBuffer.conditionalOperation.add(
              () => p.operation(
                widget.controller,
                iFrame < p.checkValue,
              ),
            );
          case CheckOperator.major:
            p.layerBuffer.conditionalOperation.add(
              () => p.operation(
                widget.controller,
                iFrame > p.checkValue,
              ),
            );
          case CheckOperator.equal:
            p.layerBuffer.conditionalOperation.add(
              () => p.operation(
                widget.controller,
                iFrame == p.checkValue,
              ),
            );
        }
    }
  }

  IMouse _getIMouse() => iMouse.iMouse;

  IMouse _getIMouseNormalized() => iMouse.iMouseNormalized;

  @override
  void didUpdateWidget(covariant ShaderBuffers oldWidget) {
    super.didUpdateWidget(oldWidget);
    init();
  }

  @override
  void reassemble() {
    super.reassemble();
    init();
  }

  @override
  void dispose() {
    ticker?.dispose();
    super.dispose();
  }

  /// compute layer image at every ticks
  void tick(Duration elapsed) {
    iFrame++;
    if (context.mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (details) {
        print('DOWN');
        if (state == ShaderState.playing) {
          iMouse.start(details.localPosition);
        }
        startingPosition = details.localPosition;
        widget.onPointerDown
            ?.call(widget.controller, Offset(iMouse.iMouse.x, iMouse.iMouse.y));
        widget.onPointerDownNormalized?.call(
          widget.controller,
          () {
            final normalized = iMouse.getIMouseNormalized();
            return Offset(normalized.x, normalized.y);
          }.call(),
        );
      },
      onPointerMove: (details) {
        if (state == ShaderState.playing) {
          iMouse.update(details.localPosition);
        }
        widget.onPointerMove
            ?.call(widget.controller, Offset(iMouse.iMouse.x, iMouse.iMouse.y));
        widget.onPointerMoveNormalized?.call(
          widget.controller,
          () {
            final normalized = iMouse.getIMouseNormalized();
            return Offset(normalized.x, normalized.y);
          }.call(),
        );
      },
      onPointerCancel: (details) {
        if (state == ShaderState.playing) {
          iMouse.end();
        }
        widget.onPointerUp
            ?.call(widget.controller, Offset(iMouse.iMouse.x, iMouse.iMouse.y));
        widget.onPointerUpNormalized?.call(
          widget.controller,
          () {
            final normalized = iMouse.getIMouseNormalized();
            return Offset(normalized.x, normalized.y);
          }.call(),
        );
      },
      onPointerUp: (details) {
        if (state == ShaderState.playing) {
          iMouse.end();
        }
        widget.onPointerUp
            ?.call(widget.controller, Offset(iMouse.iMouse.x, iMouse.iMouse.y));
        widget.onPointerUpNormalized?.call(
          widget.controller,
          () {
            final normalized = iMouse.getIMouseNormalized();
            return Offset(normalized.x, normalized.y);
          }.call(),
        );
      },
      child: RepaintBoundary(
        child: ValueListenableBuilder(
          valueListenable: relayout,
          builder: (_, __, ___) {
            return CustomShaderPaint(
              mainImage: widget.mainImage,
              buffers: widget.buffers,
              iTime: iTime.elapsedMilliseconds / 1000.0,
              iFrame: iFrame,
              iMouse: iMouse.iMouse,
              width: widget.width,
              height: widget.height,
              relayout: __,
              builder: (size) {
                /// CustomShaderPaint has been laid out, set iMouse window size
                iMouse = IMouseController(
                  width: size.width,
                  height: size.height,
                );
              },
              children: layers,
            );
          },
        ),
      ),
    );
  }
}
