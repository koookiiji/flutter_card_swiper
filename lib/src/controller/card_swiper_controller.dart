import 'dart:async';

import 'package:flutter_card_swiper/src/enums.dart';

/// A controller that can be used to trigger swipes on a CardSwiper widget.
class CardSwiperController {
  final _eventController = StreamController<ControllerEvent>.broadcast();

  /// Stream of events that can be used to swipe the card.
  Stream<ControllerEvent> get events => _eventController.stream;

  /// Swipe the card to a specific direction.
  void swipe(CardSwiperDirection direction) {
    _eventController.add(ControllerSwipeEvent(direction));
  }

  // Undo the last swipe
  void undo() {
    _eventController.add(const ControllerUndoEvent());
  }

  // Change the top card to a specific index.
  void moveTo(int index) {
    _eventController.add(ControllerMoveEvent(index));
  }

  Future<void> dispose() async {
    await _eventController.close();
  }
}

sealed class ControllerEvent {
  const ControllerEvent();
}

class ControllerSwipeEvent extends ControllerEvent {
  final CardSwiperDirection direction;
  const ControllerSwipeEvent(this.direction);
}

class ControllerUndoEvent extends ControllerEvent {
  const ControllerUndoEvent();
}

class ControllerMoveEvent extends ControllerEvent {
  final int index;
  const ControllerMoveEvent(this.index);
}
