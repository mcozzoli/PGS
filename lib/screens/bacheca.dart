import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class BachecaScreen extends StatefulWidget {
  const BachecaScreen({super.key});
  @override
  State<BachecaScreen> createState() => _BachecaScreenState();
}

class _BachecaScreenState extends State<BachecaScreen> {
  List<Message>? _messages;
  bool _canPost = false;
  bool _loading = true;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final app = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final r = await app.api.getMap('/messages');
      final list = (r['messages'] as List? ?? r['items'] as List? ?? [])
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _canPost = r['canPost'] == true || app.board.canPost;
      // segna come letto
      app.api.request('/messages/read', method: 'POST').catchError((_) => {});
      app.board = BoardInfo(unread: 0, canPost: _canPost);
      app.touch();
      if (mounted) setState(() => _messages = list);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final app = context.read<AppState>();
    try {
      await app.api.request('/messages', method: 'POST', body: {'text': text});
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Message m) async {
    final app = context.read<AppState>();
    try {
      await app.api.request('/messages/${m.id}', method: 'DELETE');
      await _load();
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final canDelete = app.user!.isAdmin;
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  const PageTitle('📣', 'Bacheca'),
                  if ((_messages ?? []).isEmpty)
                    const PgsCard(
                        child: Center(
                            child: Text('Ancora nessuna comunicazione.')))
                  else
                    ...(_messages!).map((m) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _msgCard(m, canDelete),
                        )),
                ]),
        ),
      ),
      if (_canPost)
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Scrivi una comunicazione…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _msgCard(Message m, bool canDelete) {
    final when = m.ts != null
        ? DateFormat('d MMM, HH:mm', 'it')
            .format(DateTime.fromMillisecondsSinceEpoch(m.ts!))
        : '';
    return PgsCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('📣 ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(m.author ?? 'Comunicazione',
                style: const TextStyle(
                    fontWeight: FontWeight.w900, color: PgsColors.blue800)),
          ),
          if (canDelete)
            InkWell(
              onTap: () => _delete(m),
              child: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.black38),
            ),
        ]),
        const SizedBox(height: 6),
        Text(m.text),
        const SizedBox(height: 8),
        Row(children: [
          Text(when,
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
          const Spacer(),
          if (m.reads > 0)
            Text('👁 letto da ${m.reads}',
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ]),
      ]),
    );
  }
}
