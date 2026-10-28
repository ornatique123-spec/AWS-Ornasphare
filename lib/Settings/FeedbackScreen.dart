import 'package:flutter/material.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppMessage.dart';
import '../Extra/AppColors.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController messageController = TextEditingController();

  int selectedRating = 0;
  bool isSubmitting = false;

  final List<Map<String, dynamic>> feedbackTypes = [
    {"label": "Bug Report", "icon": Icons.bug_report_outlined},
    {"label": "Suggestion", "icon": Icons.lightbulb_outline},
    {"label": "Complaint", "icon": Icons.report_gmailerrorred_outlined},
    {"label": "Other", "icon": Icons.more_horiz},
  ];

  String? selectedType;

  @override
  void dispose() {
    subjectController.dispose();
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _introCard(),
                    const SizedBox(height: 18),

                    _sectionTitle(Icons.star_outline, "RATE YOUR EXPERIENCE"),
                    const SizedBox(height: 10),
                    _ratingCard(),

                    const SizedBox(height: 18),

                    _sectionTitle(Icons.category_outlined, "FEEDBACK TYPE"),
                    const SizedBox(height: 10),
                    _feedbackTypeGrid(),

                    const SizedBox(height: 18),

                    _sectionTitle(Icons.edit_note_outlined, "DETAILS"),
                    const SizedBox(height: 10),
                    _detailsCard(),

                    const SizedBox(height: 24),

                    _submitButton(),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ HEADER
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Text(
            "Feedback",
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ INTRO CARD
  Widget _introCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark.withOpacity(0.7),
            AppColors.secondaryDark.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "We value your feedback",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Help us improve by sharing your thoughts",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ SECTION TITLE
  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryDark.withOpacity(0.7),
                AppColors.secondaryDark.withOpacity(0.7),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 13),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.bold,
            fontSize: 12.5,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  /// ✅ RATING CARD (Star rating)
  Widget _ratingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              int starValue = index + 1;
              return InkWell(
                onTap: () {
                  setState(() => selectedRating = starValue);
                },
                borderRadius: BorderRadius.circular(30),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    selectedRating >= starValue
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: selectedRating >= starValue
                        ? Colors.amber
                        : Colors.grey.shade400,
                    size: 38,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            _ratingLabel(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  String _ratingLabel() {
    switch (selectedRating) {
      case 1:
        return "Poor";
      case 2:
        return "Fair";
      case 3:
        return "Good";
      case 4:
        return "Very Good";
      case 5:
        return "Excellent";
      default:
        return "Tap a star to rate";
    }
  }

  /// ✅ FEEDBACK TYPE GRID
  Widget _feedbackTypeGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: feedbackTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        final type = feedbackTypes[index];
        bool isSelected = selectedType == type["label"];

        return InkWell(
          onTap: () {
            setState(() => selectedType = type["label"]);
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryDark.withOpacity(0.1)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? AppColors.primaryDark : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  type["icon"],
                  size: 18,
                  color: isSelected
                      ? AppColors.primaryDark
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    type["label"],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                      color:
                      isSelected ? AppColors.primaryDark : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ✅ DETAILS CARD (Subject + Message)
  Widget _detailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Subject",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          _textField(subjectController, "Enter subject"),

          const SizedBox(height: 14),

          const Text(
            "Message",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          _textField(
            messageController,
            "Write your feedback here...",
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  Widget _textField(
      TextEditingController controller,
      String hint, {
        int maxLines = 1,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.black, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  /// ✅ SUBMIT BUTTON
  Widget _submitButton() {
    return InkWell(
      // onTap: isSubmitting ? null : submitFeedback,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primaryDark.withOpacity(0.7),
              AppColors.secondaryDark.withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isSubmitting
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.send_outlined, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                "Submit Feedback",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ VALIDATION + API SUBMIT
  // Future<void> submitFeedback() async {
  //   if (selectedRating == 0) {
  //     AppMessage.error(context, "Please select a rating");
  //     return;
  //   }
  //
  //   if (selectedType == null) {
  //     AppMessage.error(context, "Please select a feedback type");
  //     return;
  //   }
  //
  //   if (messageController.text.trim().isEmpty) {
  //     AppMessage.error(context, "Please enter your feedback message");
  //     return;
  //   }
  //
  //   setState(() => isSubmitting = true);
  //
  //   try {
  //     final body = {
  //       "rating": selectedRating,
  //       "type": selectedType,
  //       "subject": subjectController.text.trim(),
  //       "message": messageController.text.trim(),
  //     };
  //
  //     final response = await ApiHelper().postRequest(
  //       ApiConstants.feedback, // 🔥 ApiConstants ma add karo
  //       body,
  //     );
  //
  //     setState(() => isSubmitting = false);
  //
  //     if (response != null &&
  //         (response.statusCode == 200 || response.statusCode == 201)) {
  //       AppMessage.success(
  //         context,
  //         response.data["message"] ?? "Feedback submitted successfully",
  //       );
  //
  //       setState(() {
  //         selectedRating = 0;
  //         selectedType = null;
  //         subjectController.clear();
  //         messageController.clear();
  //       });
  //
  //       Navigator.pop(context);
  //     } else {
  //       AppMessage.error(
  //         context,
  //         response?.data["message"] ?? "Failed to submit feedback",
  //       );
  //     }
  //   } catch (e) {
  //     setState(() => isSubmitting = false);
  //     AppMessage.error(context, "Something went wrong. Please try again.");
  //   }
  // }
}