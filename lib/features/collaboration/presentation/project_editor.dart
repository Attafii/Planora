import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/product_widgets.dart';
import '../models/project.dart';

class ProjectEditor extends StatefulWidget {
  const ProjectEditor({super.key, this.project});
  final Project? project;
  @override
  State<ProjectEditor> createState() => _ProjectEditorState();
}

class _ProjectEditorState extends State<ProjectEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title, _description;
  bool _dirty = false, _saved = false;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.project?.title);
    _description = TextEditingController(text: widget.project?.description);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty || _saved,
    onPopInvokedWithResult: (didPop, result) async {
      if (!didPop &&
          await confirm(
            context,
            title: 'Discard unsaved changes?',
            message: 'Your edits have not been saved.',
            action: 'Discard',
          )) {
        if (context.mounted) {
          setState(() => _saved = true);
          Navigator.pop(context);
        }
      }
    },
    child: ProductPage(
      title: widget.project == null ? 'New project' : 'Edit project',
      subtitle: 'A focused space for your shared outcome.',
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _form,
            onChanged: () => setState(() => _dirty = true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _title,
                  validator: Validators.required,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Project name',
                    hintText: 'What are you working on together?',
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _description,
                  maxLines: 5,
                  maxLength: 4000,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Make the purpose clear to your collaborators.',
                  ),
                ),
                const SizedBox(height: 32),
                BusyButton(
                  label: 'Save project',
                  onPressed: () async {
                    if (!_form.currentState!.validate()) return;
                    await AppScope.of(context).collaboration.save({
                      'title': _title.text,
                      'description': _description.text,
                    }, id: widget.project?.id);
                    if (context.mounted) {
                      _saved = true;
                      feedback(context, 'Project saved');
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
