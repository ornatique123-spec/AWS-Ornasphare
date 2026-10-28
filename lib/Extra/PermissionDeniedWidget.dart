import 'package:flutter/material.dart';
import 'package:pecifician_sysytem/Extra/AppColors.dart';

class PermissionDeniedWidget extends StatelessWidget {

  final VoidCallback? onBack;

  const PermissionDeniedWidget({
    super.key,
    this.onBack,
  });


  @override
  Widget build(BuildContext context) {

    return Center(
      child: Container(

        width: MediaQuery.of(context).size.width * 0.85,

        padding: const EdgeInsets.all(25),

        decoration: BoxDecoration(

          color: AppColors.white,

          borderRadius: BorderRadius.circular(10),

          boxShadow: [

            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0,5),
            )

          ],

        ),


        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [


            Container(

              padding: const EdgeInsets.all(15),

              decoration: BoxDecoration(

                color:AppColors.gradientBlue,

                shape: BoxShape.circle,

              ),


              child: const Icon(

                Icons.lock_outline,

                size: 45,

                color: Colors.white,

              ),

            ),


            const SizedBox(height:20),


            Text(

              "403",

              style: TextStyle(

                fontSize:50,

                fontWeight:FontWeight.bold,
                color: AppColors.textLight

              ),

            ),



            Text(

              "Access Denied",

              style: TextStyle(

                fontSize:22,

                fontWeight:FontWeight.bold,
                  color: AppColors.textPrimary

              ),

            ),


            const SizedBox(height:10),


            const Text(

              "You do not have permission to access this page.",

              textAlign:TextAlign.center,

              style:TextStyle(

                  color: AppColors.textPrimary,

                fontSize:14,

              ),

            ),


            const SizedBox(height:25),



            InkWell(

              onTap: onBack,

              child: Container(

                width:double.infinity,

                padding:const EdgeInsets.symmetric(
                  vertical:12,
                ),


                decoration:BoxDecoration(

                  color:Colors.red,

                  borderRadius:BorderRadius.circular(10),

                ),


                child:const Center(

                  child:Text(

                    "Go Back",

                    style:TextStyle(

                      color:Colors.white,

                      fontWeight:FontWeight.bold,

                    ),

                  ),

                ),

              ),

            )


          ],

        ),

      ),

    );

  }

}