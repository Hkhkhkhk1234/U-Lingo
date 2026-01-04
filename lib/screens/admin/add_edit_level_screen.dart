import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Screen for creating new language learning levels or editing existing ones.
/// 
/// This screen manages both quizzes and pronunciation exercises for each level.
/// It uses Firebase Firestore for persistence and supports full CRUD operations.
/// 
/// The screen validates that at least one quiz exists before allowing save,
/// ensuring data integrity for the learning experience.
class AddEditLevelScreen extends StatefulWidget {
  /// Firestore document ID when editing an existing level, null when creating new
  final String? levelId;
  
  /// Existing level data passed from the previous screen for editing
  final Map<String, dynamic>? levelData;

  const AddEditLevelScreen({
    Key? key,
    this.levelId,
    this.levelData,
  }) : super(key: key);

  @override
  State<AddEditLevelScreen> createState() => _AddEditLevelScreenState();
}

class _AddEditLevelScreenState extends State<AddEditLevelScreen> {
  // Form validation key ensures all fields are validated before submission
  final _formKey = GlobalKey<FormState>();
  
  // Controllers manage text input state and allow programmatic text updates
  final _levelIdController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  // In-memory storage of quizzes and pronunciations before Firestore save
  // Using List<Map> for flexible JSON-like structure compatible with Firestore
  List<Map<String, dynamic>> _quizzes = [];
  List<Map<String, dynamic>> _pronunciations = [];

  // Prevents multiple simultaneous save operations and shows loading indicator
  bool _isLoading = false;
  
  // Computed property determines if we're editing (levelId exists) or creating new
  bool get _isEditing => widget.levelId != null;

  @override
  void initState() {
    super.initState();
    // Pre-populate form fields when editing an existing level
    // This provides a seamless editing experience with existing data visible
    if (_isEditing && widget.levelData != null) {
      _levelIdController.text = widget.levelData!['levelId'].toString();
      _titleController.text = widget.levelData!['title'] ?? '';
      _descriptionController.text = widget.levelData!['description'] ?? '';
      
      // Create mutable copies to allow in-memory modifications before save
      _quizzes = List<Map<String, dynamic>>.from(
        widget.levelData!['quizzes'] ?? [],
      );
      _pronunciations = List<Map<String, dynamic>>.from(
        widget.levelData!['pronunciations'] ?? [],
      );
    }
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    // Flutter requires manual disposal of TextEditingControllers
    _levelIdController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Validates form data and saves level to Firestore.
  /// 
  /// Business rule: At least one quiz must exist to maintain learning quality.
  /// Updates existing document if editing, creates new document if adding.
  /// Uses server timestamp to ensure consistent time across clients.
  Future<void> _saveLevel() async {
    if (!_formKey.currentState!.validate()) return;

    // Enforce business rule: levels must have content to be useful
    if (_quizzes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one quiz'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare data structure matching Firestore schema
      final levelData = {
        'levelId': int.parse(_levelIdController.text),
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'quizzes': _quizzes,
        'pronunciations': _pronunciations,
        // Server timestamp ensures consistent ordering across devices
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEditing) {
        // Update existing document preserving createdAt timestamp
        await FirebaseFirestore.instance
            .collection('levels')
            .doc(widget.levelId)
            .update(levelData);
      } else {
        // Create new document with both created and updated timestamps
        levelData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('levels').add(levelData);
      }

      // Check mounted before UI operations to prevent setState on disposed widget
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Level updated successfully'
                  : 'Level created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      // Display error to user for debugging and awareness
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always reset loading state, even if save fails
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Opens dialog for adding a new quiz to the level.
  /// Dialog pattern keeps quiz creation logic isolated and reusable.
  void _addQuiz() {
    showDialog(
      context: context,
      builder: (context) => _QuizDialog(
        onSave: (quiz) {
          setState(() {
            _quizzes.add(quiz);
          });
        },
      ),
    );
  }

  /// Opens dialog pre-populated with existing quiz data for editing.
  /// Uses index to update the correct quiz in the list after save.
  void _editQuiz(int index) {
    showDialog(
      context: context,
      builder: (context) => _QuizDialog(
        quiz: _quizzes[index],
        onSave: (quiz) {
          setState(() {
            _quizzes[index] = quiz;
          });
        },
      ),
    );
  }

  /// Removes quiz from in-memory list. Changes persist only after save.
  void _deleteQuiz(int index) {
    setState(() {
      _quizzes.removeAt(index);
    });
  }

  /// Opens dialog for adding a new pronunciation word to the level.
  void _addPronunciation() {
    showDialog(
      context: context,
      builder: (context) => _PronunciationDialog(
        onSave: (pronunciation) {
          setState(() {
            _pronunciations.add(pronunciation);
          });
        },
      ),
    );
  }

  /// Opens dialog pre-populated with existing pronunciation data for editing.
  void _editPronunciation(int index) {
    showDialog(
      context: context,
      builder: (context) => _PronunciationDialog(
        pronunciation: _pronunciations[index],
        onSave: (pronunciation) {
          setState(() {
            _pronunciations[index] = pronunciation;
          });
        },
      ),
    );
  }

  /// Removes pronunciation word from in-memory list.
  void _deletePronunciation(int index) {
    setState(() {
      _pronunciations.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Level' : 'Add New Level',style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold),),
        backgroundColor: const Color(0xFFF5F5F5),
        actions: [
          // Hide save button during loading to prevent duplicate submissions
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save, color:Colors.black),
              onPressed: _saveLevel,
              tooltip: 'Save Level',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Information Section
            // Groups related fields for better visual organization
            Card(
              color:const Color(0xFFF5F5F5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _levelIdController,
                      decoration: const InputDecoration(
                        labelText: 'Level ID *',
                        hintText: 'e.g., 1, 2, 3...',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Level ID is required';
                        }
                        // Ensure level ID is a valid integer for proper sorting
                        if (int.tryParse(value!) == null) {
                          return 'Must be a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Level Title *',
                        hintText: 'e.g., Basic Greetings',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Title is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        hintText: 'e.g., Learn common greetings',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value?.isEmpty ?? true) {
                          return 'Description is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Quizzes Section
            // Uses card-based layout for visual hierarchy and easy management
            Card(
              color:const Color(0xFFF5F5F5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quizzes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addQuiz,
                          icon: const Icon(Icons.add,color: Colors.white),
                          label: const Text('Add Quiz',style: TextStyle(color: Colors.white),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Counter provides quick feedback on content quantity
                    Text(
                      '${_quizzes.length} quiz(es) added',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    // Empty state guides user to add their first quiz
                    if (_quizzes.isEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.quiz_outlined,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No quizzes added yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      // Display all quizzes with edit/delete actions
                      // Uses asMap() to get both index and value for operations
                      ..._quizzes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final quiz = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.blue[50],
                          child: ListTile(
                            // Numbered badges help users track quiz order
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(
                              quiz['audio'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(quiz['question'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editQuiz(index),
                                  color: Colors.blue,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _deleteQuiz(index),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Pronunciation Section
            // Similar structure to quizzes but for pronunciation practice
            Card(
              color:const Color(0xFFF5F5F5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Pronunciation Practice',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _addPronunciation,
                          icon: const Icon(Icons.add,color:Colors.white),
                          label: const Text('Add Word',style: TextStyle(color: Colors.white),),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_pronunciations.length} word(s) added',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    if (_pronunciations.isEmpty) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.mic_none,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No pronunciation words added yet',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      ..._pronunciations.asMap().entries.map((entry) {
                        final index = entry.key;
                        final pron = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          color: Colors.orange[50],
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            // Display word with pinyin for quick reference
                            title: Row(
                              children: [
                                Text(
                                  pron['word'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  pron['pinyin'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(pron['translation'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () => _editPronunciation(index),
                                  color: Colors.orange,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  onPressed: () => _deletePronunciation(index),
                                  color: Colors.red,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Primary Save Button
            // Duplicates AppBar save for easier access without scrolling
            ElevatedButton.icon(
              onPressed: _saveLevel,
              icon: const Icon(Icons.save, color:Colors.white),
              label: Text(_isEditing ? 'Update Level' : 'Create Level',style: TextStyle(color: Colors.white),),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 16,),
          ],
        ),
      ),
    );
  }
}

/// Dialog for creating or editing quiz questions.
/// 
/// Manages a single quiz with audio text, question, four options, and correct answer.
/// Uses callback pattern to return data to parent without tight coupling.
class _QuizDialog extends StatefulWidget {
  /// Existing quiz data for editing, null when creating new quiz
  final Map<String, dynamic>? quiz;
  
  /// Callback invoked when user saves the quiz with validated data
  final Function(Map<String, dynamic>) onSave;

  const _QuizDialog({
    Key? key,
    this.quiz,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Separate controllers for each quiz field allow independent validation
  final _audioController = TextEditingController();
  final _questionController = TextEditingController();
  final _option1Controller = TextEditingController();
  final _option2Controller = TextEditingController();
  final _option3Controller = TextEditingController();
  final _option4Controller = TextEditingController();
  final _correctController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate fields when editing existing quiz
    if (widget.quiz != null) {
      _audioController.text = widget.quiz!['audio'] ?? '';
      _questionController.text = widget.quiz!['question'] ?? '';
      
      // Safely extract options array and populate individual controllers
      final options = List<String>.from(widget.quiz!['options'] ?? []);
      if (options.length >= 4) {
        _option1Controller.text = options[0];
        _option2Controller.text = options[1];
        _option3Controller.text = options[2];
        _option4Controller.text = options[3];
      }
      _correctController.text = widget.quiz!['correct'] ?? '';
    }
  }

  @override
  void dispose() {
    // Dispose all seven controllers to prevent memory leaks
    _audioController.dispose();
    _questionController.dispose();
    _option1Controller.dispose();
    _option2Controller.dispose();
    _option3Controller.dispose();
    _option4Controller.dispose();
    _correctController.dispose();
    super.dispose();
  }

  /// Validates and packages quiz data for parent callback.
  /// Trims whitespace to prevent storage of unnecessary spaces.
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Package data in structure matching Firestore schema
    final quiz = {
      'audio': _audioController.text.trim(),
      'question': _questionController.text.trim(),
      // Options stored as array for easy iteration in quiz UI
      'options': [
        _option1Controller.text.trim(),
        _option2Controller.text.trim(),
        _option3Controller.text.trim(),
        _option4Controller.text.trim(),
      ],
      'correct': _correctController.text.trim(),
    };

    widget.onSave(quiz);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor:const Color(0xFFF5F5F5),
      title: Text(widget.quiz == null ? 'Add Quiz' : 'Edit Quiz'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Audio field stores Chinese text for text-to-speech
              TextFormField(
                controller: _audioController,
                decoration: const InputDecoration(
                  labelText: 'Audio Text (Chinese) *',
                  hintText: 'e.g., 你好',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(
                  labelText: 'Question *',
                  hintText: 'e.g., What does this mean?',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // Four separate option fields ensure consistent quiz structure
              TextFormField(
                controller: _option1Controller,
                decoration: const InputDecoration(
                  labelText: 'Option 1 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _option2Controller,
                decoration: const InputDecoration(
                  labelText: 'Option 2 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _option3Controller,
                decoration: const InputDecoration(
                  labelText: 'Option 3 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _option4Controller,
                decoration: const InputDecoration(
                  labelText: 'Option 4 *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // Correct answer must match one option exactly for validation
              TextFormField(
                controller: _correctController,
                decoration: const InputDecoration(
                  labelText: 'Correct Answer *',
                  hintText: 'Must match one of the options',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',style:TextStyle(color:Colors.black),),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Save',style:TextStyle(color:Colors.black),),
        ),
      ],
    );
  }
}

/// Dialog for creating or editing pronunciation practice words.
/// 
/// Captures Chinese characters, pinyin romanization, English translation,
/// and pronunciation tips to help learners master tones and sounds.
class _PronunciationDialog extends StatefulWidget {
  /// Existing pronunciation data for editing, null when creating new word
  final Map<String, dynamic>? pronunciation;
  
  /// Callback invoked when user saves with validated pronunciation data
  final Function(Map<String, dynamic>) onSave;

  const _PronunciationDialog({
    Key? key,
    this.pronunciation,
    required this.onSave,
  }) : super(key: key);

  @override
  State<_PronunciationDialog> createState() => _PronunciationDialogState();
}

class _PronunciationDialogState extends State<_PronunciationDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Four controllers for the complete pronunciation practice entry
  final _wordController = TextEditingController();
  final _pinyinController = TextEditingController();
  final _translationController = TextEditingController();
  final _tipsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-populate when editing existing pronunciation word
    if (widget.pronunciation != null) {
      _wordController.text = widget.pronunciation!['word'] ?? '';
      _pinyinController.text = widget.pronunciation!['pinyin'] ?? '';
      _translationController.text = widget.pronunciation!['translation'] ?? '';
      _tipsController.text = widget.pronunciation!['tips'] ?? '';
    }
  }

  @override
  void dispose() {
    // Clean up all four controllers
    _wordController.dispose();
    _pinyinController.dispose();
    _translationController.dispose();
    _tipsController.dispose();
    super.dispose();
  }

  /// Validates and packages pronunciation data for parent callback.
  void _save() {
    if (!_formKey.currentState!.validate()) return;

    // Structure matches Firestore pronunciation schema
    final pronunciation = {
      'word': _wordController.text.trim(),
      'pinyin': _pinyinController.text.trim(),
      'translation': _translationController.text.trim(),
      'tips': _tipsController.text.trim(),
    };

    widget.onSave(pronunciation);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor:const Color(0xFFF5F5F5),
      title: Text(
        widget.pronunciation == null
            ? 'Add Pronunciation Word'
            : 'Edit Pronunciation Word',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Larger font for Chinese characters improves readability
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(
                  labelText: 'Chinese Word *',
                  hintText: 'e.g., 你好',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontSize: 20),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // Pinyin provides phonetic guide for pronunciation
              TextFormField(
                controller: _pinyinController,
                decoration: const InputDecoration(
                  labelText: 'Pinyin *',
                  hintText: 'e.g., nǐ hǎo',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _translationController,
                decoration: const InputDecoration(
                  labelText: 'English Translation *',
                  hintText: 'e.g., Hello',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              // Tips field provides context on tone and pronunciation nuances
              TextFormField(
                controller: _tipsController,
                decoration: const InputDecoration(
                  labelText: 'Pronunciation Tips *',
                  hintText: 'e.g., The tone goes down then up',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',style:TextStyle(color:Colors.black),),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          child: const Text('Save',style:TextStyle(color:Colors.black),),
        ),
      ],
    );
  }
}
