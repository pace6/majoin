import 'flex_event.dart';

/// 3 demo Flex bubbles: receipt, product card, restaurant menu.
class FlexDemos {
  static final all = <String, FlexBubble>{
    'Receipt': receipt(),
    'Product card': productCard(),
    'Restaurant menu': restaurantMenu(),
  };

  static FlexBubble receipt() => FlexBubble(
        altText: 'Receipt #1023',
        body: FlexBox(
          layout: 'vertical',
          spacing: 'md',
          contents: [
            FlexText(text: 'RECEIPT', weight: 'bold', size: 'lg', color: '#1A1A1A'),
            FlexText(text: 'Order #1023', size: 'sm', color: '#888888'),
            FlexSeparator(),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: 'Iced Latte', size: 'sm'),
              FlexText(text: '฿85', size: 'sm', align: 'end'),
            ]),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: 'Croissant', size: 'sm'),
              FlexText(text: '฿55', size: 'sm', align: 'end'),
            ]),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: 'Service 10%', size: 'sm', color: '#888888'),
              FlexText(text: '฿14', size: 'sm', align: 'end', color: '#888888'),
            ]),
            FlexSeparator(),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: 'Total', weight: 'bold'),
              FlexText(text: '฿154', weight: 'bold', align: 'end', color: '#06C755'),
            ]),
          ],
        ),
        footer: FlexBox(
          layout: 'vertical',
          spacing: 'sm',
          contents: [
            FlexButton(
              style: 'primary',
              action: FlexAction.uri(label: 'View order', uri: 'https://example.com/orders/1023'),
            ),
          ],
        ),
      );

  static FlexBubble productCard() => FlexBubble(
        altText: 'Wireless Headphones — ฿2,990',
        hero: FlexImage(
          url: 'https://picsum.photos/seed/headphones/600/390',
          aspectRatio: '20:13',
          aspectMode: 'cover',
        ),
        body: FlexBox(
          layout: 'vertical',
          spacing: 'sm',
          contents: [
            FlexText(text: 'Wireless Headphones', weight: 'bold', size: 'lg'),
            FlexText(
              text: 'Active noise cancellation, 30hr battery, USB-C charging.',
              size: 'sm',
              color: '#666666',
            ),
            FlexBox(layout: 'horizontal', spacing: 'sm', contents: [
              FlexText(text: '★ 4.6', size: 'sm', color: '#FFB400'),
              FlexText(text: '(1,234 reviews)', size: 'sm', color: '#888888'),
            ]),
            FlexText(text: '฿2,990', weight: 'bold', size: 'xl', color: '#06C755'),
          ],
        ),
        footer: FlexBox(
          layout: 'horizontal',
          spacing: 'sm',
          contents: [
            FlexButton(
              style: 'secondary',
              action: FlexAction.postback(label: 'Save', data: 'save:headphones-001'),
            ),
            FlexButton(
              style: 'primary',
              action: FlexAction.uri(label: 'Buy now', uri: 'https://example.com/p/headphones-001'),
            ),
          ],
        ),
      );

  static FlexBubble restaurantMenu() => FlexBubble(
        altText: 'Today\'s menu — Café Majoin',
        hero: FlexImage(
          url: 'https://picsum.photos/seed/cafe/600/390',
          aspectRatio: '20:13',
        ),
        body: FlexBox(
          layout: 'vertical',
          spacing: 'md',
          contents: [
            FlexText(text: 'Café Majoin', weight: 'bold', size: 'lg'),
            FlexText(text: 'Today\'s specials', size: 'sm', color: '#888888'),
            FlexSeparator(),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: '🥐  Almond croissant', size: 'sm'),
              FlexText(text: '฿65', size: 'sm', align: 'end'),
            ]),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: '🥗  Caesar salad', size: 'sm'),
              FlexText(text: '฿180', size: 'sm', align: 'end'),
            ]),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: '🍝  Carbonara', size: 'sm'),
              FlexText(text: '฿220', size: 'sm', align: 'end'),
            ]),
            FlexBox(layout: 'horizontal', contents: [
              FlexText(text: '☕  Flat white', size: 'sm'),
              FlexText(text: '฿95', size: 'sm', align: 'end'),
            ]),
          ],
        ),
        footer: FlexBox(
          layout: 'horizontal',
          spacing: 'sm',
          contents: [
            FlexButton(
              style: 'link',
              action: FlexAction.uri(label: 'Call', uri: 'tel:+66800000000'),
            ),
            FlexButton(
              style: 'primary',
              action: FlexAction.uri(label: 'Reserve', uri: 'https://example.com/reserve'),
            ),
          ],
        ),
      );
}
