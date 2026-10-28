import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Api_Constant/ApiConstants.dart';
import '../../Api_Constant/api_helper.dart';
import '../../Extra/AppMessage.dart';
import '../Dashboard/HomeScreen.dart';
import '../Extra/AppColors.dart';

class LiveMetalRatesScreen extends StatefulWidget {
  const LiveMetalRatesScreen({super.key});

  @override
  State<LiveMetalRatesScreen> createState() => _LiveMetalRatesScreenState();
}

class _LiveMetalRatesScreenState extends State<LiveMetalRatesScreen> {
  bool isLoading = true;
  List rates = [];
  String source = "";
  String updatedAt = "";
  Timer? autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    loadRates();

    /// 🔥 Auto refresh every 30 seconds
    autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      loadRates(silent: true);
    });
  }

  @override
  void dispose() {
    autoRefreshTimer?.cancel();
    super.dispose();
  }
  String selectedSymbol = "GOLD";
  /// ✅ API CALL
  Future<void> loadRates({bool silent = false}) async {

    final response = await ApiHelper().getRequest(
      ApiConstants.live_metal_rates,
      showLoading: false,
    );

    if (response?.statusCode == 200 &&
        response?.data["success"] == true) {

      final data = response!.data;

      setState(() {
        rates = data["data"] ?? [];
        source = data["source"]?.toString() ?? "";
        updatedAt = data["updated_at"]?.toString() ?? "";


      });

    } else {
      if (!silent) {
        AppMessage.error(context, "Failed to load live rates");
      }
    }
  }

  String v(dynamic value) {
    if (value == null) return "-";
    return value.toString();
  }

  String formatRate(dynamic rate) {
    if (rate == null) return "-";
    double val = double.tryParse(rate.toString()) ?? 0;
    return val
        .toStringAsFixed(0)
        .replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+(\d)(?!\d))'),
          (m) => "${m[1]},",
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const HomeScreen(),
          ),
        );
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              _header(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => loadRates(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // _sourceCard(),
                        // const SizedBox(height: 5),

                        // Transform.translate(
                        //   offset: const Offset(0, -2),
                        //   child: Align(
                        //     alignment: Alignment.center,
                        //     child: InkWell(
                        //       onTap: () => loadRates(),
                        //       child: Container(
                        //         padding: const EdgeInsets.only(left: 10,right: 10,top: 5,bottom: 5),
                        //         decoration: BoxDecoration(
                        //           color: AppColors.background,
                        //           borderRadius: BorderRadius.circular(5),
                        //           border: Border.all(color: AppColors.border),
                        //         ),
                        //         child: Text(
                        //           v(updatedAt),
                        //           style: const TextStyle(
                        //             color: Colors.black,
                        //             fontWeight: FontWeight.w500,
                        //             fontSize: 11.5,
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //   ),
                        // ),
                        // const SizedBox(height: 5),
                        _topRateCard(),

                        const SizedBox(height: 5),

                        _sectionTitle(Icons.workspace_premium_outlined,
                            "GOLD RATES"),
                        const SizedBox(height: 5),
                        ..._filteredRates("GLD").asMap().entries.map(
                              (entry) => _rateCard(
                            entry.value,
                            isGold: true,
                            index: entry.key,
                          ),
                        ),

                        const SizedBox(height: 5),

                        _sectionTitle(
                            Icons.circle_outlined, "SILVER RATES"),
                        const SizedBox(height: 10),
                        ..._filteredRates("SLV").asMap().entries.map(
                              (entry) => _rateCard(
                            entry.value,
                            isGold: false,
                            index: entry.key,
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List _filteredRates(String prefix) {
    return rates
        .where((r) =>
        r["symbol"].toString().toUpperCase().startsWith(prefix))
        .toList();
  }

  /// ✅ HEADER
  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 0,
        bottom: 5,
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
          /// 🔥 CENTER TITLE
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  "assets/static/text.png",
                  height: 30,
                  width: 150,
                  fit: BoxFit.cover,
                ),

                const SizedBox(height: 2),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        color: Colors.green,
                        size: 8,
                      ),
                      SizedBox(width: 6),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: "LIVE ",
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.green,
                                letterSpacing: 1.2,
                              ),
                            ),
                            TextSpan(
                              text: "METAL RATES",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.orange,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Align(
                      //   alignment: Alignment.centerRight,
                      //   child: InkWell(
                      //     onTap: () => loadRates(),
                      //     child: Container(
                      //       padding: const EdgeInsets.all(5),
                      //       decoration: BoxDecoration(
                      //         color: AppColors.background,
                      //         borderRadius: BorderRadius.circular(5),
                      //         border: Border.all(color: AppColors.border),
                      //       ),
                      //       child:Text(
                      //         "${v(updatedAt)}",
                      //         style: const TextStyle(
                      //           color: Colors.black,
                      //           fontSize: 11.5,
                      //         ),
                      //       ),
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  ),
                );
              },
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
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () => loadRates(),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(
                  Icons.refresh,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ SOURCE / UPDATED AT CARD
  Widget _sourceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryDark.withOpacity(0.7),
            AppColors.secondaryDark.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
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
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Image.asset(
              "assets/static/logo1.png",
              height: 30,
              width: 30,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Source : ",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Text(
                      "OrnaSphere",
                      style: TextStyle(
                        color: Color(0xffC8A96A),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Updated: ${v(updatedAt)}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                SizedBox(width: 5),
                Text(
                  "LIVE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
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
          child: Icon(icon, color: Colors.white, size: 12),
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

  /// ✅ RATE CARD
  Widget _rateCard(
      Map rate, {
        required bool isGold,
        required int index,
      }){
    String direction = (rate["direction"] ?? "flat").toString();
    num change = rate["change"] ?? 0;

    Color directionColor;
    IconData directionIcon;

    if (direction == "up") {
      directionColor = const Color(0xff2ECC71);
      directionIcon = Icons.arrow_upward_rounded;
    } else if (direction == "down") {
      directionColor = const Color(0xffE74C3C);
      directionIcon = Icons.arrow_downward_rounded;
    } else {
      directionColor = Colors.black;
      directionIcon = Icons.remove_rounded;
    }

    Color metalColor =
    isGold ? const Color(0xffC8A96A) : const Color(0xffC0C0C0);

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(5),
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
          Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Radio<String>(
                    value: rate["symbol"],
                    groupValue: selectedSymbol,
                    activeColor: AppColors.primaryDark,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: const VisualDensity(
                      horizontal: -4,
                      vertical: -4,
                    ),
                    onChanged: (value) {
                      saveSelectedRate(value!);
                    },
                  ),

                  const SizedBox(width: 4),

                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: metalColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Icon(
                      isGold
                          ? Icons.workspace_premium
                          : Icons.workspace_premium,
                      color: metalColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v(rate["symbol"]),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      v(rate["city"]),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: metalColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: metalColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  "₹${formatRate(rate["rate"])}",
                  style: TextStyle(
                    color: directionColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),


            ],
          ),

          const SizedBox(height: 5),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.trending_up,
                          size: 14, color: Colors.green.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "High: ",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        formatRate(rate["high"]),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 14,
                  color: AppColors.border,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.trending_down,
                          size: 14, color: Colors.red.shade600),
                      const SizedBox(width: 4),
                      Text(
                        "Low: ",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        formatRate(rate["low"]),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topRateCard() {

    final gold = rates.firstWhere(
          (e) => e["symbol"] == "GOLD",
      orElse: () => <String, dynamic>{},
    );

    final silver = rates.firstWhere(
          (e) => e["symbol"] == "SILVER",
      orElse: () => <String, dynamic>{},
    );

    final usd = rates.firstWhere(
          (e) => e["symbol"] == "USD INR",
      orElse: () => <String, dynamic>{},
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _rateItem(gold, Icons.workspace_premium)),
          Container(width: 1, height: 40, color: Colors.black),
          Expanded(child: _rateItem(silver, Icons.circle)),
          Container(width: 1, height: 40, color: Colors.black),
          Expanded(child: _rateItem(usd, Icons.currency_exchange)),
        ],
      ),
    );
  }

  Widget _rateItem(Map item, IconData icon) {

    Color iconColor;
    Color textColor;

    switch (item["symbol"]) {
      case "GOLD":
        iconColor = const Color(0xFFC8A96A); // Gold
        break;

      case "SILVER":
        iconColor = const Color(0xFFC0C0C0); // Silver
        break;

      case "USD INR":
        iconColor = Colors.green;
        break;

      default:
        iconColor = Colors.black;
    }

    // Rate color direction પ્રમાણે
    switch (item["direction"]) {
      case "up":
        textColor = Colors.green;
        break;

      case "down":
        textColor = Colors.red;
        break;

      default:
        textColor = Colors.black;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 20,
        ),

        const SizedBox(height: 2),

        Text(
          item["symbol"] ?? "",
          style:TextStyle(
            fontWeight: FontWeight.bold,
            color: iconColor,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 2),

        Text(
          "${item["formatted_rate"]}",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Future<void> saveSelectedRate(String symbol) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      "selected_rate_symbol",
      symbol,
    );

    setState(() {
      selectedSymbol = symbol;
    });
  }
}