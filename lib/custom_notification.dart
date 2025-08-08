import 'package:flutter/material.dart';

class CustomNotification extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const CustomNotification({
    Key? key,
    required this.message,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      bottom: 0,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          elevation: 4.0,
          borderRadius: BorderRadius.circular(8.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8, // 화면 너비의 80%
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 20.0,
            ), // 패딩 증가
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).primaryColor.withOpacity(0.9), // 앱의 주 색상 사용
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white), // 정보 아이콘으로 변경
                const SizedBox(width: 16.0), // 아이콘과 텍스트 사이 간격 증가
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18.0,
                    ), // 폰트 크기 증가
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: onDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showCustomNotification({
  required BuildContext context,
  required String message,
}) {
  OverlayEntry? overlayEntry;

  overlayEntry = OverlayEntry(
    builder:
        (context) => CustomNotification(
          message: message,
          onDismiss: () {
            overlayEntry?.remove();
          },
        ),
  );

  Overlay.of(context).insert(overlayEntry);

  Future.delayed(const Duration(seconds: 3), () {
    overlayEntry?.remove();
  });
}