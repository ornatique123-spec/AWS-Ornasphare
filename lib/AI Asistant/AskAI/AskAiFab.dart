import 'package:flutter/material.dart';
import '../../Extra/AppColors.dart';
import 'AskAiScreen.dart';
import 'core/ai_core.dart';

/// =======================================================================
///  ASK AI FLOATING BUTTON — koi pan page par ek line thi
///
///  Sales Summary ma:
///    floatingActionButton: AskAiFab(
///      module: 'sales',
///      onOpenPeriod: (ctx, moduleId, period) {
///        setState(() { fromDate = period.from; toDate = period.to; });
///        fetchSalesSummary();          // tamari existing API call
///        Navigator.pop(ctx);           // AI screen bandh kari report par paachha
///      },
///    ),
///
///  Tap = AI screen + mic sidho chalu.   Long press = mic vagar kholo.
/// =======================================================================
class AskAiFab extends StatelessWidget {
  final String module;
  final void Function(BuildContext context, String moduleId, AiPeriod period)? onOpenPeriod;
  final bool mini;

  const AskAiFab({super.key, required this.module, this.onOpenPeriod, this.mini = false});

  void _open(BuildContext context, {required bool listen}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AskAiScreen(initialModule: module, autoListen: listen, onOpenPeriod: onOpenPeriod),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _open(context, listen: false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.secondaryDark]),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () => _open(context, listen: true),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: mini ? 14 : 18, vertical: mini ? 10 : 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_rounded, color: Colors.white, size: 20),
                  if (!mini) ...[
                    const SizedBox(width: 8),
                    const Text('Ask AI',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
