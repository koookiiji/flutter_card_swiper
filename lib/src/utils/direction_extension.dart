import 'package:flutter/widgets.dart';
import 'package:flutter_card_swiper/src/enums.dart';

extension DirectionExtension on CardSwiperDirection {
  Axis get axis {
    switch (this) {
      case CardSwiperDirection.left:
      case CardSwiperDirection.right:
        return Axis.horizontal;
      default:
        throw Exception('Direction is none');
    }
  }
}
