import 'package:flutter/material.dart';

class AppMessage {

  /// ✅ SUCCESS
  static void success(BuildContext context, String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),

        backgroundColor: Colors.green,

        behavior: SnackBarBehavior.floating,

        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 80, // 👈 button ni upar aavse
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        duration: const Duration(seconds: 2),
      ),

    );

  }

  /// ❌ ERROR
  static void error(BuildContext context, String msg) {
    // _showSnackBar(
    //   context,
    //   msg,
    //   Colors.red,
    //   Icons.error,
    // );

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),

        backgroundColor: Colors.red,

        behavior: SnackBarBehavior.floating,

        margin: const EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: 80, // 👈 button ni upar aavse
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        duration: const Duration(seconds: 2),
      ),

    );
  }

  /// 🔥 COMMON SNACKBAR DESIGN
  static void _showSnackBar(
      BuildContext context,
      String msg,
      Color bgColor,
      IconData icon,
      ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bgColor,
        duration: const Duration(seconds: 2),

        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),

        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: const EdgeInsets.all(12),
      ),
    );
  }
}
