import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_card_swiper/src/card_animation.dart';
import 'package:flutter_card_swiper/src/controller/card_swiper_controller.dart';
import 'package:flutter_card_swiper/src/enums.dart';
import 'package:flutter_card_swiper/src/properties/allowed_swipe_direction.dart';
import 'package:flutter_card_swiper/src/typedefs.dart';
import 'package:flutter_card_swiper/src/utils/number_extension.dart';
import 'package:flutter_card_swiper/src/utils/undoable.dart';

class CardSwiper extends StatefulWidget {
  final NullableCardBuilder cardBuilder;
  final int cardsCount;
  final int initialIndex;
  final CardSwiperController? controller;
  final Duration duration;
  final EdgeInsetsGeometry padding;
  final double maxAngle;
  final int threshold;
  final double scale;
  final bool isDisabled;
  final CardSwiperOnSwipe? onSwipe;
  final CardSwiperOnEnd? onEnd;
  final CardSwiperOnTapDisabled? onTapDisabled;
  final AllowedSwipeDirection allowedSwipeDirection;
  final bool isLoop;
  final int numberOfCardsDisplayed;
  final CardSwiperOnUndo? onUndo;
  final CardSwiperDirectionChange? onSwipeDirectionChange;
  final Offset backCardOffset;

  const CardSwiper({
    required this.cardBuilder,
    required this.cardsCount,
    this.controller,
    this.initialIndex = 0,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
    this.duration = const Duration(milliseconds: 200),
    this.maxAngle = 30,
    this.threshold = 30, // スワイプの閾値を小さくする
    this.scale = 0.9,
    this.isDisabled = false,
    this.onTapDisabled,
    this.onSwipe,
    this.onSwipeDirectionChange,
    this.onEnd,
    this.allowedSwipeDirection = const AllowedSwipeDirection.all(),
    this.isLoop = true,
    this.numberOfCardsDisplayed = 2,
    this.onUndo,
    this.backCardOffset = const Offset(0, 40),
    super.key,
  })  : assert(
  maxAngle >= 0 && maxAngle <= 360,
  'maxAngle must be between 0 and 360',
  ),
        assert(
        threshold >= 1 && threshold <= 100,
        'threshold must be between 1 and 100',
        ),
        assert(
        scale >= 0 && scale <= 1,
        'scale must be between 0 and 1',
        ),
        assert(
        numberOfCardsDisplayed >= 1 && numberOfCardsDisplayed <= cardsCount,
        'you must display at least one card, and no more than [cardsCount]',
        ),
        assert(
        initialIndex >= 0 && initialIndex < cardsCount,
        'initialIndex must be between 0 and [cardsCount]',
        );

  @override
  State createState() => _CardSwiperState();
}

class _CardSwiperState<T extends Widget> extends State<CardSwiper>
    with SingleTickerProviderStateMixin {
  late CardAnimation _cardAnimation;
  late AnimationController _animationController;

  SwipeType _swipeType = SwipeType.none;
  CardSwiperDirection _detectedDirection = CardSwiperDirection.none;
  CardSwiperDirection _detectedHorizontalDirection = CardSwiperDirection.none;
  bool _tappedOnTop = false;

  final _undoableIndex = Undoable<int?>(null);
  final Queue<CardSwiperDirection> _directionHistory = Queue();

  int? get _currentIndex => _undoableIndex.state;

  int? get _nextIndex => getValidIndexOffset(1);

  bool get _canSwipe => _currentIndex != null && !widget.isDisabled;

  @override
  void initState() {
    super.initState();

    _undoableIndex.state = widget.initialIndex;

    widget.controller?.events.listen(_controllerListener);

    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    )
      ..addListener(_animationListener)
      ..addStatusListener(_animationStatusListener);

    _cardAnimation = CardAnimation(
      animationController: _animationController,
      maxAngle: widget.maxAngle,
      initialScale: widget.scale,
      allowedSwipeDirection: widget.allowedSwipeDirection,
      initialOffset: widget.backCardOffset,
      onSwipeDirectionChanged: onSwipeDirectionChanged,
    );
  }

  void onSwipeDirectionChanged(CardSwiperDirection direction) {
    _detectedHorizontalDirection = direction;
    widget.onSwipeDirectionChange
        ?.call(_detectedHorizontalDirection, CardSwiperDirection.none);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Padding(
          padding: widget.padding,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: List.generate(numberOfCardsOnScreen(), (index) {
                  if (index == 0) return _frontItem(constraints);
                  return _backItem(constraints, index);
                }).reversed.toList(),
              );
            },
          ),
        );
      },
    );
  }

  Widget _frontItem(BoxConstraints constraints) {
    return Positioned(
      left: _cardAnimation.left,
      top: _cardAnimation.top,
      child: GestureDetector(
        child: Transform.rotate(
          angle: _cardAnimation.angle,
          child: ConstrainedBox(
            constraints: constraints,
            child: widget.cardBuilder(
              context,
              _currentIndex!,
              (100 * _cardAnimation.left / widget.threshold).ceil(),
              (100 * _cardAnimation.top / widget.threshold).ceil(),
            ),
          ),
        ),
        onTap: () async {
          if (widget.isDisabled) {
            await widget.onTapDisabled?.call();
          }
        },
        onPanStart: (tapInfo) {
          if (!widget.isDisabled) {
            final renderBox = context.findRenderObject()! as RenderBox;
            final position = renderBox.globalToLocal(tapInfo.globalPosition);

            if (position.dy < renderBox.size.height / 2) _tappedOnTop = true;
          }
        },
        onPanUpdate: (tapInfo) {
          if (!widget.isDisabled) {
            setState(
                  () => _cardAnimation.update(
                tapInfo.delta.dx,
                tapInfo.delta.dy,
                _tappedOnTop,
              ),
            );
          }
        },
        onPanEnd: (tapInfo) {
          if (_canSwipe) {
            _tappedOnTop = false;
            _onEndAnimation();
          }
        },
      ),
    );
  }

  Widget _backItem(BoxConstraints constraints, int index) {
    return Positioned(
      top: (widget.backCardOffset.dy * index) - _cardAnimation.difference.dy,
      left: (widget.backCardOffset.dx * index) - _cardAnimation.difference.dx,
      child: Transform.scale(
        scale: _cardAnimation.scale - ((1 - widget.scale) * (index - 1)),
        child: ConstrainedBox(
          constraints: constraints,
          child: widget.cardBuilder(context, getValidIndexOffset(index)!, 0, 0),
        ),
      ),
    );
  }

  void _controllerListener(ControllerEvent event) {
    switch (event) {
      case ControllerSwipeEvent(:final direction):
        _swipe(direction);
        break;
      case ControllerUndoEvent():
        _undo();
        break;
      case ControllerMoveEvent(:final index):
        _moveTo(index);
        break;
    }
  }

  void _animationListener() {
    if (_animationController.status == AnimationStatus.forward) {
      setState(_cardAnimation.sync);
    }
  }

  Future<void> _animationStatusListener(AnimationStatus status) async {
    if (status == AnimationStatus.completed) {
      switch (_swipeType) {
        case SwipeType.swipe:
          await _handleCompleteSwipe();
          break;
        default:
          break;
      }

      _reset();
    }
  }

  Future<void> _handleCompleteSwipe() async {
    final isLastCard = _currentIndex! == widget.cardsCount - 1;
    final shouldCancelSwipe = await widget.onSwipe
        ?.call(_currentIndex!, _nextIndex, _detectedDirection) ==
        false;

    if (shouldCancelSwipe) {
      return;
    }

    _undoableIndex.state = _nextIndex;
    _directionHistory.add(_detectedDirection);

    if (isLastCard) {
      widget.onEnd?.call();
    }
  }

  void _reset() {
    onSwipeDirectionChanged(CardSwiperDirection.none);
    _detectedDirection = CardSwiperDirection.none;
    setState(() {
      _animationController.reset();
      _cardAnimation.reset();
      _swipeType = SwipeType.none;
    });
  }

  void _onEndAnimation() {
    final direction = _getEndAnimationDirection();
    final isValidDirection = _isValidDirection(direction);

    if (isValidDirection) {
      _swipe(direction);
    } else {
      _goBack();
    }
  }

  CardSwiperDirection _getEndAnimationDirection() {
    if (_cardAnimation.left.abs() > widget.threshold) {
      return _cardAnimation.left.isNegative
          ? CardSwiperDirection.left
          : CardSwiperDirection.right;
    }
    return CardSwiperDirection.none;
  }

  bool _isValidDirection(CardSwiperDirection direction) {
    switch (direction) {
      case CardSwiperDirection.left:
        return widget.allowedSwipeDirection.left;
      case CardSwiperDirection.right:
        return widget.allowedSwipeDirection.right;
      default:
        return false;
    }
  }

  void _swipe(CardSwiperDirection direction) {
    if (_currentIndex == null) return;
    _swipeType = SwipeType.swipe;
    _detectedDirection = direction;
    _cardAnimation.animate(context, direction);
  }

  void _goBack() {
    _swipeType = SwipeType.back;
    _cardAnimation.animateBack(context);
  }

  void _undo() {
    if (_directionHistory.isEmpty) return;
    if (_undoableIndex.previousState == null) return;

    final direction = _directionHistory.last;
    final shouldCancelUndo = widget.onUndo?.call(
      _currentIndex,
      _undoableIndex.previousState!,
      direction,
    ) ==
        false;

    if (shouldCancelUndo) {
      return;
    }

    _undoableIndex.undo();
    _directionHistory.removeLast();
    _swipeType = SwipeType.undo;
    _cardAnimation.animateUndo(context, direction);
  }

  void _moveTo(int index) {
    if (index == _currentIndex) return;
    if (index < 0 || index >= widget.cardsCount) return;

    setState(() {
      _undoableIndex.state = index;
    });
  }

  int numberOfCardsOnScreen() {
    if (widget.isLoop) {
      return widget.numberOfCardsDisplayed;
    }
    if (_currentIndex == null) {
      return 0;
    }

    return math.min(
      widget.numberOfCardsDisplayed,
      widget.cardsCount - _currentIndex!,
    );
  }

  int? getValidIndexOffset(int offset) {
    if (_currentIndex == null) {
      return null;
    }

    final index = _currentIndex! + offset;
    if (!widget.isLoop && !index.isBetween(0, widget.cardsCount - 1)) {
      return null;
    }
    return index % widget.cardsCount;
  }
}
