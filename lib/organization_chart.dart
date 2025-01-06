import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

// Employee model remains the same
class Employee {
  final int coId;
  final int empId;
  final String imageUrl;
  final String name;
  final String? reportsTo;
  final String office;
  final String area;
  final List<Employee> children;

  const Employee({
    required this.coId,
    required this.empId,
    required this.imageUrl,
    required this.name,
    this.reportsTo,
    required this.office,
    required this.area,
    required this.children,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        coId: json['CO_ID'] as int,
        empId: json['EMP_ID'] as int,
        imageUrl: json['imageUrl'] as String,
        name: json['name'] as String,
        reportsTo: json['REPORTS_TO'] as String?,
        office: json['office'] as String,
        area: json['area'] as String,
        children: (json['children'] as List<dynamic>)
            .map((e) => Employee.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrganizationGraphPage extends StatefulWidget {
  const OrganizationGraphPage({super.key});

  @override
  State<OrganizationGraphPage> createState() => _OrganizationGraphPageState();
}

class _OrganizationGraphPageState extends State<OrganizationGraphPage> {
  late Employee rootEmployee;
  final ScrollController _verticalController = ScrollController();

  @override
  void initState() {
    super.initState();
    final jsonMap = json.decode(
            "{\"CO_ID\":0,\"EMP_ID\":87,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Tanvir Ahmad\",\"REPORTS_TO\":null,\"office\":\"D365 CRM Consultant\",\"area\":\"Manager\",\"children\":[{\"CO_ID\":0,\"EMP_ID\":51,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Humayun Sheikh\",\"REPORTS_TO\":\"87\",\"office\":\"ERP DEV\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":88,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Mudasar Hanif\",\"REPORTS_TO\":\"87\",\"office\":\"D365 CRM Consultant TL\",\"area\":\"Developer\",\"children\":[{\"CO_ID\":0,\"EMP_ID\":7,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Sarmad Mushtaq\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Senior SQA TL\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":36,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Sana Mehmood\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Manager\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":12,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Tahir\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Dot Net Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":5,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Waleed Shoukat\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Senior SQA\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":65,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Ali  Hassan\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":70,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"ABDUL-SHAHIED Shahid\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":74,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Salman Atiq\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":78,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"MUHAMMAD UMAIR Akram\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":1,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Usman Shoaib\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":2,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Maryam Abbasi\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":10,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Moiz\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":15,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Ans Nawaz\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":19,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"ABDUL Ghaffar\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":29,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Asim Mumtaz\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":31,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Farhad Hassan\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":46,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Sohail Yousaf\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":59,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Imtiaz Afaal\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":63,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"ARSALAN Mehboob\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":97,\"imageUrl\":\"SavedImages/bbfe377a-938b-4fa5-a8db-f0e16abd2486WhatsApp Image 2024-11-17 at 16.56.27_d05a58ee.jpg\",\"name\":\"ZORAIZ Khan\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":104,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"MUHAMMAD MUDASSIR Afzal\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":106,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Sufyan Siddique\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":7,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Sarmad Mushtaq\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Senior SQA TL\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":36,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Sana Mehmood\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Manager\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":12,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Tahir\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Dot Net Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":5,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Waleed Shoukat\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Senior SQA\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":65,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Ali  Hassan\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":70,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"ABDUL-SHAHIED Shahid\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":74,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Salman Atiq\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":78,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"MUHAMMAD UMAIR Akram\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":1,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Usman Shoaib\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":2,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Maryam Abbasi\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":10,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Moiz\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":15,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Ans Nawaz\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":19,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"ABDUL Ghaffar\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":29,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Asim Mumtaz\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":31,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Farhad Hassan\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":46,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Muhammad Sohail Yousaf\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":59,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Imtiaz Afaal\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":63,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"ARSALAN Mehboob\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":97,\"imageUrl\":\"SavedImages/bbfe377a-938b-4fa5-a8db-f0e16abd2486WhatsApp Image 2024-11-17 at 16.56.27_d05a58ee.jpg\",\"name\":\"ZORAIZ Khan\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":104,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"MUHAMMAD MUDASSIR Afzal\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":106,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Sufyan Siddique\",\"REPORTS_TO\":\"88\",\"office\":\"D365 CRM Consultant\",\"area\":\"Developer\",\"children\":[]}]},{\"CO_ID\":0,\"EMP_ID\":114,\"imageUrl\":\"Content/images/default-pic.png\",\"name\":\"Farman ullah Kundi\",\"REPORTS_TO\":\"87\",\"office\":\"ERP DEV\",\"area\":\"Developer\",\"children\":[]},{\"CO_ID\":0,\"EMP_ID\":115,\"imageUrl\":\"SavedImages/4f2e4d86-e004-4f83-97ef-80b8886bc417316268438_3211833072372444_4414238857530084237_n.jpg\",\"name\":\"Mubashir Hassan\",\"REPORTS_TO\":\"87\",\"office\":\"ERP DEV\",\"area\":\"Senior SQA\",\"children\":[]}]}")
        as Map<String, dynamic>;
    rootEmployee = Employee.fromJson(jsonMap);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Chart',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        // Wrap with Center
        child: Scrollbar(
          controller: _verticalController,
          child: SingleChildScrollView(
            controller: _verticalController,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: OrgChartNode(
                employee: rootEmployee,
                isRoot: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrgChartNode extends StatefulWidget {
  final Employee employee;
  final bool isRoot;

  const OrgChartNode({
    super.key,
    required this.employee,
    this.isRoot = false,
  });

  @override
  State<OrgChartNode> createState() => _OrgChartNodeState();
}

class _OrgChartNodeState extends State<OrgChartNode> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Center(
      // Center the entire node
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmployeeCard(),
          if (_isExpanded && widget.employee.children.isNotEmpty) ...[
            Container(
              width: 3,
              height: 16,
              color: const Color.fromARGB(255, 223, 56, 56),
            ),
            _buildChildrenRows(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmployeeCard() {
    return SizedBox(
      width: 180,
      child: Card(
        elevation: widget.isRoot ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: widget.isRoot
              ? BorderSide(color: Theme.of(context).primaryColor, width: 1)
              : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (widget.employee.children.isNotEmpty) {
              setState(() => _isExpanded = !_isExpanded);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildAvatar(),
                const SizedBox(height: 4),
                _buildEmployeeInfo(),
                if (widget.employee.children.isNotEmpty)
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color.fromARGB(255, 12, 79, 38),
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChildrenRows() {
    final children = widget.employee.children;
    final List<Widget> rows = [];

    for (var i = 0; i < children.length; i += 2) {
      final rowChildren = <Widget>[];

      // Add first child
      rowChildren.add(
        Expanded(
          child: Center(
            child: Column(
              children: [
                Container(
                  width: 1,
                  height: 16,
                  color: const Color.fromARGB(255, 5, 74, 36),
                ),
                OrgChartNode(employee: children[i]),
              ],
            ),
          ),
        ),
      );

      // Add second child if exists
      if (i + 1 < children.length) {
        rowChildren.add(
          Expanded(
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 1,
                    height: 16,
                    color: const Color.fromARGB(255, 8, 8, 7),
                  ),
                  OrgChartNode(employee: children[i + 1]),
                ],
              ),
            ),
          ),
        );
      } else {
        // Add empty expanded widget for single child to maintain centering
        rowChildren.add(const Expanded(child: SizedBox()));
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: SizedBox(
            width: 600, // Fixed width for two cards + spacing
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rowChildren,
            ),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color.fromARGB(255, 33, 135, 164),
          child: ClipOval(
            child: Image.network(
              widget.employee.imageUrl,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  LucideIcons.user,
                  size: 20,
                  color: Color.fromARGB(255, 16, 20, 17),
                );
              },
            ),
          ),
        ),
        if (widget.isRoot)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.crown,
                size: 10,
                color: Color.fromARGB(255, 131, 121, 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmployeeInfo() {
    return Column(
      children: [
        Text(
          widget.employee.name,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          widget.employee.area,
          style: TextStyle(
            fontSize: 10,
            color: const Color.fromARGB(255, 245, 51, 51),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          widget.employee.office,
          style: TextStyle(
            fontSize: 9,
            color: const Color.fromARGB(255, 9, 128, 90),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
