import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Page where users can submit a request to add a new exercise. This collects
/// basic information about the exercise and optional preview and video URLs.
class ExerciseRequestPage extends StatefulWidget {
  const ExerciseRequestPage({super.key});

  @override
  State<ExerciseRequestPage> createState() => _ExerciseRequestPageState();
}

class _ExerciseRequestPageState extends State<ExerciseRequestPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _previewController = TextEditingController();
  final TextEditingController _videoController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _previewController.dispose();
    _videoController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _submitting = false;
        _error = 'You must be logged in to submit a request.';
      });
      return;
    }
    try {
      final videoUrls = _videoController.text.trim().isNotEmpty
          ? _videoController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : null;
      final int? sets = _setsController.text.trim().isNotEmpty
          ? int.tryParse(_setsController.text.trim())
          : null;
      final int? reps = _repsController.text.trim().isNotEmpty
          ? int.tryParse(_repsController.text.trim())
          : null;
      final Map<String, dynamic> insertData = {
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'preview_url': _previewController.text.trim().isNotEmpty
            ? _previewController.text.trim()
            : null,
        'video_urls': videoUrls,
        'recommended_sets': sets,
        'recommended_reps': reps,
      };
      final response = await _client.from('exercise_requests').insert(insertData);
      if (response.error != null) {
        throw response.error!;
      }
      // On success, go back and show a snackbar
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exercise request submitted!')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request New Exercise')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Exercise Name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _previewController,
                  decoration: const InputDecoration(
                    labelText: 'Preview URL',
                    hintText: 'Link to an image',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _videoController,
                  decoration: const InputDecoration(
                    labelText: 'Video URLs',
                    hintText: 'Comma separated URLs',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _setsController,
                        decoration: const InputDecoration(
                          labelText: 'Recommended Sets',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _repsController,
                        decoration: const InputDecoration(
                          labelText: 'Recommended Reps',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_error != null)
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: Text(_submitting ? 'Submitting...' : 'Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}