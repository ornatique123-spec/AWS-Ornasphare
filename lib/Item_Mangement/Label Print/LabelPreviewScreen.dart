import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pecifician_sysytem/Extra/AppColors.dart';
import 'package:pecifician_sysytem/Item_Mangement/Label%20Print/Label_print_Screen.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';

class LabelPreviewScreen extends StatefulWidget {
  final List selectedData;
  final String selectedLabelType;

  const LabelPreviewScreen({
    super.key,
    required this.selectedData,
    required this.selectedLabelType,
  });

  @override
  State<LabelPreviewScreen> createState() =>
      _LabelPreviewScreenState();
}

class _LabelPreviewScreenState
    extends State<LabelPreviewScreen> {

  Uint8List? getQrImage(String? base64String) {
    try {
      if (base64String == null || base64String.isEmpty) {
        return null;
      }

      if (base64String.contains(',')) {
        return base64Decode(
          base64String.split(',').last,
        );
      }

      return base64Decode(base64String);
    } catch (e) {
      return null;
    }
  }
  int skipLabels = 0;

  TextEditingController fromDateController = TextEditingController();
  TextEditingController toDateController = TextEditingController();
  Future<void> _selectDate(TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      controller.text = "${picked.day}-${picked.month}-${picked.year}";
    }
  }
  final TextEditingController skipController =
  TextEditingController();
  @override
  Widget build(BuildContext context) {

    final width = MediaQuery.of(context).size.width;
    final size = MediaQuery.of(context).size;
    final height = size.height;
    final isMobile = width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.white,

      body: Stack(
        children: [

          /// 🔥 MAIN BODY
          Column(
            children: [

              /// 🔥 APPBAR SPACE
              SizedBox(
                height:
                MediaQuery.of(context).padding.top + 40,
              ),

              /// 🔥 FILTER
              filterWidget(),

              /// 🔥 DIVIDER
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: double.infinity,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark.withOpacity(0.1),
                      AppColors.primaryDark,
                      AppColors.secondaryDark.withOpacity(0.4),
                      AppColors.primaryDark.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              /// 🔥 PREVIEW
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),

                  scrollDirection: Axis.horizontal,

                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// 🔥 FIRST A4 PAGE
                        buildA4Page(width),

                        const SizedBox(width: 20),

                        /// 🔥 SECOND A4 PAGE
                        buildA4Page(width),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),

          /// 🔥 CUSTOM APPBAR
          Positioned(
            top: 0,
            left: 0,
            right: 0,

            child: Container(
              padding: const EdgeInsets.only(
                top: 30,
                left: 16,
                right: 16,
                bottom: 16,
              ),

              child: Stack(
                alignment: Alignment.center,

                children: [

                  /// 🔥 TITLE
                  const Text(
                    "Label Preview",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  /// ✅ LEFT BACK ICON
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context, true),
                      child: Container(
                        padding: EdgeInsets.all(isMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color:AppColors.primaryDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                    ),
                  ),

                  /// RIGHT NOTIFICATION ICON
                  // Align(
                  //   alignment: Alignment.centerRight,
                  //
                  //   child: Container(
                  //     padding: EdgeInsets.all(isMobile ? 6 : 8),
                  //
                  //     decoration: BoxDecoration(
                  //       color: Colors.white,
                  //
                  //       borderRadius: BorderRadius.circular(8),
                  //
                  //       boxShadow: [
                  //         BoxShadow(
                  //           color: AppColors.shadow,
                  //
                  //           blurRadius: 20,
                  //
                  //           offset: const Offset(5, 10),
                  //         ),
                  //       ],
                  //     ),
                  //
                  //     child: Stack(
                  //       clipBehavior: Clip.none,
                  //
                  //       children: [
                  //         Icon(
                  //           Icons.notifications_none,
                  //
                  //           size: isMobile ? 22 : 24,
                  //
                  //           color: Colors.red,
                  //         ),
                  //
                  //         Positioned(
                  //           right: -2,
                  //
                  //           top: -2,
                  //
                  //           child: Container(
                  //             height: 8,
                  //
                  //             width: 8,
                  //
                  //             decoration: const BoxDecoration(
                  //               color: Colors.red,
                  //
                  //               shape: BoxShape.circle,
                  //             ),
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),

      /// 🔥 BOTTOM BUTTON
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Container(
          margin: const EdgeInsets.only(left: 16,bottom: 16,right: 16),
          //padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryDark.withOpacity(0.8),
                AppColors.secondaryDark.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              savefinalizeBulkItems();
            },
            child: const Text(
              "Print PDF",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      )
    );
  }

  Future<void> savefinalizeBulkItems() async {

    if (widget.selectedData.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select at least one item"),
        ),
      );

      return;
    }

    /// 🔥 IDS LIST
    List ids = widget.selectedData
        .map((e) => e["id"])
        .toList();

    /// 🔥 REQUEST BODY
    Map<String, dynamic> body = {

      "ids": ids,
      "label_format" : widget.selectedLabelType,
      "start_position": skipController.text

      /// 🔥 EMPTY LABEL COUNT
      //"skip_labels": skipLabels,
    };

    print("📤 REQUEST BODY: $body");

    final response = await ApiHelper().postRequest1(
      ApiConstants.Qr_pdf,
      body,
    );

    if (response != null &&
        response.statusCode == 200) {

      final dir =
      await getApplicationDocumentsDirectory();

      final file = File(
        "${dir.path}/qr_labels.pdf",
      );

      await file.writeAsBytes(response.data);

      await OpenFile.open(file.path);

    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to Save Data"),
        ),
      );
    }
  }


  Future<void> generatePdf() async {

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,

        margin: const pw.EdgeInsets.all(10),

        build: (pw.Context context) {

          return pw.GridView(
            crossAxisCount: 2,

            childAspectRatio: 2.5,

            crossAxisSpacing: 6,
            mainAxisSpacing: 6,

            children: List.generate(
              widget.selectedData.length,

                  (index) {

                final item =
                widget.selectedData[index];

                /// 🔥 QR IMAGE
                Uint8List? imageBytes =
                getQrImage(
                  item["qr_image"],
                );

                return pw.Container(
                  padding:
                  const pw.EdgeInsets.all(4),

                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: PdfColors.grey300,
                      width: 1,
                    ),
                  ),

                  child: pw.Row(
                    children: [

                      /// 🔥 LEFT LABEL
                      pw.Expanded(
                        child: buildPdfLabel(
                          item,
                          imageBytes,
                        ),
                      ),

                      /// 🔥 CENTER DIVIDER
                      pw.Container(
                        width: 1,
                        height: 40,

                        margin:
                        const pw.EdgeInsets.symmetric(
                          horizontal: 4,
                        ),

                        color: PdfColors.grey300,
                      ),

                      /// 🔥 RIGHT LABEL
                      pw.Expanded(
                        child: buildPdfLabel(
                          item,
                          imageBytes,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );

    /// 🔥 SAVE PDF
    final dir =
    await getApplicationDocumentsDirectory();

    final file = File(
      "${dir.path}/labels.pdf",
    );

    await file.writeAsBytes(
      await pdf.save(),
    );

    /// 🔥 OPEN PDF
    await OpenFile.open(file.path);
  }

  /// 🔥 SINGLE LABEL (PROPER VERSION)
  Widget buildLabel(
      dynamic item,
      Uint8List? imageBytes,
      ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [


        /// 🔥 QR CODE TEXT
        Text(
          item["qr_code"] ?? "",
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        /// 🔥 QR IMAGE (TOP)
        if (imageBytes != null)
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            child: Image.memory(
              imageBytes,
              height: 32,
              width: 32,
              fit: BoxFit.contain,
            ),
          ),


      ],
    );
  }


  /// 🔥 SINGLE LABEL (PROPER VERSION)
  Widget buildLabelTwoBarcode(
      dynamic item,
      Uint8List? imageBytes,
      ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [


        /// 🔥 QR CODE TEXT
        Text(
          "Wt: ${item["gross_weight"] ?? 0}",
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        /// 🔥 QR IMAGE (TOP)
        if (imageBytes != null)
          Container(
            margin: const EdgeInsets.only(bottom: 0),
            child: Image.memory(
              imageBytes,
              height: 28,
              width: 28,
              fit: BoxFit.contain,
            ),
          ),
        /// 🔥 QR CODE TEXT
        Text(
          item["qr_code"] ?? "",
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

      ],
    );
  }
  /// 🔥 FILTER WIDGET
  Widget filterWidget() {

    return Container(
      margin: const EdgeInsets.fromLTRB(
        10,
        5,
        10,
        0,
      ),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Column(
        children: [


          /// 🔥 START LABEL NUMBER
          TextField(
            controller: skipController,

            keyboardType: TextInputType.number,

            style: const TextStyle(
              color: Colors.black,
            ),

            decoration: InputDecoration(
              hintText: "Start From Label No",

              hintStyle: TextStyle(
                color: Colors.grey.shade600,
              ),

              filled: true,
              fillColor: Colors.white,

              contentPadding:
              const EdgeInsets.symmetric(
                vertical: 10,
                horizontal: 10,
              ),

              border: OutlineInputBorder(
                borderRadius:
                BorderRadius.circular(5),
              ),
            ),

            onChanged: (value) {

              setState(() {

                /// 🔥 1 ENTER = 0 SKIP
                /// 🔥 6 ENTER = 5 SKIP

                int entered =
                    int.tryParse(value) ?? 1;

                skipLabels =
                entered <= 1 ? 0 : entered - 1;
              });
            },
          ),
          const SizedBox(height: 10),
          /// 🔥 DATE ROW
          // Row(
          //   children: [
          //     Expanded(
          //       child: InkWell(
          //         onTap: () => _selectDate(fromDateController),
          //         child: IgnorePointer(
          //           child: TextField(
          //             controller: fromDateController,
          //             style: const TextStyle(color: Colors.black),
          //             decoration: InputDecoration(
          //               hintText: "From Date",
          //               hintStyle: TextStyle(color: Colors.grey.shade600),
          //               suffixIcon: const Icon(Icons.calendar_today, size: 18,color: AppColors.primaryDark,),
          //               filled: true,
          //               fillColor: Colors.white,
          //               contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          //               border: OutlineInputBorder(
          //                   borderRadius: BorderRadius.circular(8),
          //                   borderSide: BorderSide(color: AppColors.border)
          //               ),
          //
          //               enabledBorder: OutlineInputBorder(
          //                 borderRadius: BorderRadius.circular(8),
          //                 borderSide: BorderSide(color:AppColors.border),
          //               ),
          //
          //               focusedBorder: OutlineInputBorder(
          //                 borderRadius: BorderRadius.circular(8),
          //                 borderSide: BorderSide(color: AppColors.border),
          //               ),
          //
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //
          //     const SizedBox(width: 8),
          //
          //     Expanded(
          //       child: InkWell(
          //         onTap: () => _selectDate(toDateController),
          //         child: IgnorePointer(
          //           child: TextField(
          //             controller: toDateController,
          //             style: const TextStyle(color: Colors.black),
          //             decoration: InputDecoration(
          //               hintText: "To Date",
          //               hintStyle: TextStyle(color: Colors.grey.shade600),
          //               suffixIcon: const Icon(Icons.calendar_today, size: 18,color: AppColors.primaryDark,),
          //               filled: true,
          //               fillColor: Colors.white,
          //               contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
          //               border: OutlineInputBorder(
          //                   borderRadius: BorderRadius.circular(8),
          //                   borderSide: BorderSide(color: AppColors.border)
          //               ),
          //
          //               enabledBorder: OutlineInputBorder(
          //                 borderRadius: BorderRadius.circular(8),
          //                 borderSide: BorderSide(color:AppColors.border),
          //               ),
          //
          //               focusedBorder: OutlineInputBorder(
          //                 borderRadius: BorderRadius.circular(8),
          //                 borderSide: BorderSide(color: AppColors.border),
          //               ),
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ],
          // ),
          //
          // const SizedBox(height: 10),

          /// 🔥 BUTTONS
          Row(
            children: [

              /// SHOW
              Expanded(
                child: InkWell(
                  onTap: () {
                    //applyDateFilter(); // 🔥 CALL HERE
                    print("Apply Filter");
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryDark.withOpacity(0.7),
                          AppColors.secondaryDark.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Center(
                      child: Text(
                        "Show",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              /// CLEAR
              Expanded(
                child: InkWell(
                  onTap: () {
                  },

                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color:AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        "Clear",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }


  Widget buildA4Page(double width) {

    print("SELECTED TYPE: ${widget.selectedLabelType}");
    /// 🔥 DEFAULT LAYOUT
    if (widget.selectedLabelType == "Default") {
      return buildDefaultLayout(width);
    }

    /// 🔥 50-50 LAYOUT
    else if (widget.selectedLabelType == "50-50") {
      return build5050Layout(width);
    }

    /// 🔥 TWO BARCODE
    else {
      return buildTwoBarcodeLayout(width);
    }
  }


  Widget buildTwoBarcodeLayout(double width) {

    /// 🔥 FINAL LIST
    List finalList = [];

    /// 🔥 EMPTY LABELS
    for (int i = 0; i < skipLabels; i++) {
      finalList.add(null);
    }

    /// 🔥 REAL DATA
    finalList.addAll(widget.selectedData);

    return Container(

      width: width * 0.95,

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),

        borderRadius: BorderRadius.circular(6),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
          ),
        ],
      ),

      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,

        // physics:
        // const NeverScrollableScrollPhysics(),

        itemCount: finalList.length,

        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,

          childAspectRatio: 2.7,

          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),

        itemBuilder: (context, index) {

          final item = finalList[index];

          /// 🔥 EMPTY LABEL
          if (item == null) {

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black12,
                  width: 1,
                ),
              ),
            );
          }

          Uint8List? imageBytes =
          getQrImage(item["qr_image"]);

          return Container(
            padding: const EdgeInsets.all(0),

            decoration: BoxDecoration(
              borderRadius:BorderRadius.all(Radius.circular(5)),
              border: Border.all(
                color: AppColors.border,
                width: 2,
              ),
            ),

            child: Row(
              children: [

                /// 🔥 LEFT LABEL
                Expanded(
                  child: buildLabelTwoBarcode(
                    item,
                    imageBytes,
                  ),
                ),

                /// 🔥 CENTER DIVIDER
                Container(
                  width: 1,
                  height: 45,

                  margin:
                  const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),

                  color: Colors.black12,
                ),

                /// 🔥 RIGHT LABEL
                Expanded(
                  child: buildLabelTwoBarcode1(
                    item,
                    imageBytes,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildDefaultLayout(double width) {

    /// 🔥 FINAL LIST
    List finalList = [];

    /// 🔥 EMPTY LABELS
    for (int i = 0; i < skipLabels; i++) {
      finalList.add(null);
    }

    /// 🔥 REAL DATA
    finalList.addAll(widget.selectedData);

    return Container(

      width: width * 0.95,

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),

        borderRadius: BorderRadius.circular(6),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
          ),
        ],
      ),

      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,

        // physics:
        // const NeverScrollableScrollPhysics(),

        itemCount: finalList.length,

        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,

          childAspectRatio: 3.0,

          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),

        itemBuilder: (context, index) {

          final item = finalList[index];

          /// 🔥 EMPTY LABEL
          if (item == null) {

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
            );
          }

          Uint8List? imageBytes =
          getQrImage(item["qr_image"]);

          return Container(
            padding: const EdgeInsets.all(0),

            decoration: BoxDecoration(
              borderRadius:BorderRadius.all(Radius.circular(5)),
              border: Border.all(
                color: AppColors.border,
                width: 2,
              ),
            ),
            
            child: Row(
              children: [

                /// 🔥 LEFT LABEL
                Expanded(
                  child: buildLabel(
                    item,
                    imageBytes,
                  ),
                ),

                /// 🔥 CENTER DIVIDER
                Container(
                  width: 1,
                  height: 45,

                  margin:
                  const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),

                  color: Colors.black12,
                ),

                /// 🔥 RIGHT LABEL
                Expanded(
                  child: buildLabel(
                    item,
                    imageBytes,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget build5050Layout(double width) {

    /// 🔥 FINAL LIST
    List finalList = [];

    /// 🔥 EMPTY LABELS
    for (int i = 0; i < skipLabels; i++) {
      finalList.add(null);
    }

    /// 🔥 REAL DATA
    finalList.addAll(widget.selectedData);

    return Container(

      width: width * 0.95,

      padding: const EdgeInsets.all(10),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),

        borderRadius: BorderRadius.circular(6),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
          ),
        ],
      ),

      child: GridView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,

        // physics:
        // const NeverScrollableScrollPhysics(),

        itemCount: finalList.length,

        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,

          childAspectRatio: 3,

          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),

        itemBuilder: (context, index) {

          final item = finalList[index];

          /// 🔥 EMPTY LABEL
          if (item == null) {

            return Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.black12,
                  width: 1,
                ),
              ),
            );
          }

          Uint8List? imageBytes =
          getQrImage(item["qr_image"]);

          return Container(
            padding: const EdgeInsets.all(4),

            decoration: BoxDecoration(
              borderRadius:BorderRadius.all(Radius.circular(5)),
              border: Border.all(
                color: AppColors.border,
                width: 2,
              ),
            ),

            child: Row(
              children: [

                /// 🔥 LEFT LABEL
                Expanded(
                  child: buildLabel5050(
                    item,
                    imageBytes,
                  ),
                ),

                /// 🔥 CENTER DIVIDER
                Container(
                  width: 1,
                  height: 45,

                  margin:
                  const EdgeInsets.symmetric(
                    horizontal: 4,
                  ),

                  color: Colors.black12,
                ),

                /// 🔥 RIGHT LABEL
                Expanded(
                  child: buildLabel5050(
                    item,
                    imageBytes,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }


  pw.Widget buildPdfLabel(
      dynamic item,
      Uint8List? imageBytes,
      ) {

    return pw.Row(
      crossAxisAlignment:
      pw.CrossAxisAlignment.center,

      children: [

        /// 🔥 QR IMAGE
        if (imageBytes != null)
          pw.Container(
            margin: const pw.EdgeInsets.only(
              right: 4,
            ),

            child: pw.Image(
              pw.MemoryImage(imageBytes),

              width: 28,
              height: 28,
              fit: pw.BoxFit.contain,
            ),
          ),

        /// 🔥 TEXT
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment:
            pw.CrossAxisAlignment.start,

            mainAxisAlignment:
            pw.MainAxisAlignment.center,

            children: [

              /// 🔥 QR CODE
              pw.Text(
                item["qr_code"] ?? "",

                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight:
                  pw.FontWeight.bold,
                ),

                maxLines: 1,
              ),

              pw.SizedBox(height: 1),

              /// 🔥 ITEM NAME
              pw.Text(
                item["item_name"] ?? "",

                style: const pw.TextStyle(
                  fontSize: 7,
                ),

                maxLines: 1,
              ),

              pw.SizedBox(height: 1),

              /// 🔥 WEIGHT
              pw.Text(
                "Wt: ${item["gross_weight"]}",

                style: const pw.TextStyle(
                  fontSize: 7,
                ),

                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 🔥 SINGLE LABEL (PROPER + CLEAN + PRINT READY)
  Widget buildLabel5050(
      dynamic item,
      Uint8List? imageBytes,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [

        /// 🔥 QR IMAGE
        if (imageBytes != null)
          Container(
            margin: const EdgeInsets.only(right: 6),
            child: Image.memory(
              imageBytes,
              height: 35,
              width: 35,
              fit: BoxFit.contain,
            ),
          ),

        /// 🔥 TEXT SECTION
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔥 QR CODE
              Text(
                item["qr_code"] ?? "",
                style: const TextStyle(
                  fontSize: 5,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 0),

              /// 🔥 WEIGHT
              Text(
                "Wt: ${item["gross_weight"] ?? 0}",
                style: const TextStyle(
                  fontSize: 5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 0),
              /// 🔥 ITEM NAME
              Text(
                "Lt: ${item["other_weight"] ?? 0}",
                style: const TextStyle(
                  fontSize: 5,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 0),

              Text(
                "Nt: ${item["net_weight"] ?? 0}",
                style: const TextStyle(
                  fontSize: 5,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 0),
              Text(
                "OC: ${item["sale_other"] ?? 0}",
                style: const TextStyle(
                  fontSize: 5,
                  color: Colors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            ],
          ),
        ),
      ],
    );
  }

  Widget buildLabelTwoBarcode1(
      dynamic item,
      Uint8List? imageBytes,
      ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [


        /// 🔥 QR CODE TEXT
        Text(
          item["qr_code"] ?? "",
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        /// 🔥 QR IMAGE (TOP)
        if (imageBytes != null)
          Container(
            margin: const EdgeInsets.only(bottom: 0),
            child: Image.memory(
              imageBytes,
              height: 28,
              width: 28,
              fit: BoxFit.contain,
            ),
          ),
        /// 🔥 QR CODE TEXT
        Text(
          "Wt: ${item["gross_weight"] ?? 0}",
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

      ],
    );
  }
}