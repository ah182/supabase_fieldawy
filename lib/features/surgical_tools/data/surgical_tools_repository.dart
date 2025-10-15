import 'package:fieldawy_store/features/surgical_tools/domain/surgical_tool_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SurgicalToolsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Admin: Get all surgical tools (catalog)
  Future<List<SurgicalTool>> adminGetAllSurgicalTools() async {
    try {
      final response = await _supabase
          .from('surgical_tools')
          .select('''
            id,
            tool_name,
            company,
            image_url,
            created_by,
            created_at,
            updated_at
          ''')
          .order('created_at', ascending: false);

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => SurgicalTool.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch surgical tools: $e');
    }
  }

  // Admin: Get all distributor surgical tools with joined data
  Future<List<DistributorSurgicalTool>> adminGetAllDistributorSurgicalTools() async {
    try {
      final response = await _supabase
          .from('distributor_surgical_tools')
          .select('''
            id,
            distributor_id,
            distributor_name,
            surgical_tool_id,
            description,
            price,
            created_at,
            updated_at,
            surgical_tools!inner(
              tool_name,
              company,
              image_url
            )
          ''')
          .order('created_at', ascending: false);

      if (response == null) {
        return [];
      }

      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) {
        final map = json as Map<String, dynamic>;
        // Flatten the surgical_tools nested object
        if (map['surgical_tools'] != null) {
          final toolData = map['surgical_tools'] as Map<String, dynamic>;
          map['tool_name'] = toolData['tool_name'];
          map['company'] = toolData['company'];
          map['image_url'] = toolData['image_url'];
        }
        return DistributorSurgicalTool.fromJson(map);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch distributor surgical tools: $e');
    }
  }

  // Admin: Delete surgical tool from catalog
  Future<bool> adminDeleteSurgicalTool(String id) async {
    try {
      await _supabase
          .from('surgical_tools')
          .delete()
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to delete surgical tool: $e');
    }
  }

  // Admin: Delete distributor surgical tool
  Future<bool> adminDeleteDistributorSurgicalTool(String id) async {
    try {
      await _supabase
          .from('distributor_surgical_tools')
          .delete()
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to delete distributor surgical tool: $e');
    }
  }

  // Admin: Update distributor surgical tool
  Future<bool> adminUpdateDistributorSurgicalTool({
    required String id,
    required String description,
    required double price,
  }) async {
    try {
      await _supabase
          .from('distributor_surgical_tools')
          .update({
            'description': description,
            'price': price,
          })
          .eq('id', id);

      return true;
    } catch (e) {
      throw Exception('Failed to update distributor surgical tool: $e');
    }
  }
}
