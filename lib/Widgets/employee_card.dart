import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shipper_app/Widgets/alertDialog/update_employee_alert_dialog.dart';
import 'package:shipper_app/Widgets/customRoleCell.dart';
import 'package:shipper_app/Widgets/remove_employee_alert_dialog.dart';
import 'package:shipper_app/functions/get_role_of_employee.dart';
import 'package:shipper_app/models/company_users_model.dart';
import '../constants/colors.dart';
import '../constants/fontSize.dart';
import '../constants/fontWeights.dart';
import '../constants/radius.dart';
import '../constants/spaces.dart';
import '../models/popup_model_for_employee_card.dart';

//TODO: This card is used to display the employee name/uid and role in the company and also we can edit the role as well as delete the employee from company database
class EmployeeCard extends StatelessWidget {
  CompanyUsers companyUsersModel;
  
  EmployeeCard({Key? key, required this.companyUsersModel}) : super(key: key);


  List<Map<String, dynamic>> employeeDataList = [];

// Function to add an employee to the list
  void addEmployee(Map<String, dynamic> employeeData) {
    employeeDataList.add(employeeData);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: fetchUserData(companyUsersModel.uid),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          // Assuming snapshot.data contains the data in the format [Name, Email, Role]
          String name = snapshot.data[0]!;
          String email = snapshot.data[1]!;
          String role = companyUsersModel.role;

          // Create a map to hold the data of the current employee
          Map<String, dynamic> employeeData = {
            'Name': name,
            'Email': email,
            'Role': role,
          };
          return Expanded(
        child: Row(
          children: [
            Expanded(
                flex: 4,
                child: Center(
                    child: Container(
                        padding: const EdgeInsets.only(left: 8,top : 12),
                        child: Text(
                          '$name',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                              color: kLiveasyColor,
                              fontSize: 15,
                              fontFamily: 'Montserrat'),
                        )))),
            const VerticalDivider(
              color: Colors.grey,
            ),

            Expanded(
                flex: 5,
                child: Center(
                    child: Container(
                        padding: const EdgeInsets.only(left: 8,top : 12),
                        child: Text(
                          '$email',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: kLiveasyColor,
                              fontSize: 15,
                              fontFamily: 'Montserrat'),
                        )))),
            const VerticalDivider(
              color: Colors.grey,
            ),

            Expanded(
                flex: 3,
                child: Center(
                    child: Container(
                        padding: const  EdgeInsets.only( top : 12),
                        child: CustomRole(
                              selectedRole: '$role',
                              roleChanged: (newRole) {
                                Future.delayed(Duration.zero, () {
                                  updateUser(context, newRole);
                                });
                              }),))),
            const VerticalDivider(
              color: Colors.grey,
            ),

            Expanded(
                flex: 3,
                child: Center(
                    child: Container(
                        padding: const EdgeInsets.only(left: 8,top : 12),
                        
                        child: GestureDetector(
                          onTap: (){
                            removeUser(context, '$email');
                          },
                          child: const Image(
                                              image: AssetImage(
                                                  'assets/icons/deleteIcon.png')),
                        ),
                          ))),
            
            ],
            ),
            );
        } else {
          return Container();
        }
      },
    );
  }

  PopupMenuItem<PopUpMenuForEmployee> showEachItemFromList(
          PopUpMenuForEmployee item) =>
      PopupMenuItem<PopUpMenuForEmployee>(
          value: item,
          child: Row(
            children: [
              Image(
                image: AssetImage(item.iconImage),
                height: size_6 + 1,
                width: size_6 + 1,
              ),
              SizedBox(
                width: space_1 + 2,
              ),
              Text(
                item.itemText,
                style: TextStyle(
                  fontWeight: mediumBoldWeight,
                ),
              ),
            ],
          ));

  

  void updateUser(BuildContext context, String newRole) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return UpdateEmployeeRole(
              employeeUid: companyUsersModel.uid, selectedRole: newRole);
        });
 
  }

  removeUser(BuildContext context, String name) {
    showDialog(
        context: context,
        builder: (BuildContext context) {
          return RemoveEmployee(
              employeeUid: companyUsersModel.uid, employeeName: name);
        });
  }

  Future<List> fetchUserData(String uid) async {
    try {
      final String uidApiEmail = dotenv.get("getUid");
      final response = await http
          .get(Uri.parse("$uidApiEmail/$uid"), headers: <String, String>{
        'Content-Type': 'application/json; charset = UTF-8',
      });

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        final email = jsonData['email'];
        final name = jsonData['name'] ?? '';

        return [name, email];
      } else {
        //print('Request failed with status: ${response.statusCode}.');
        return [];
      }
    } catch (e) {
      //print('Error fetching user data: $e');
      return [];
    }
  }
}


