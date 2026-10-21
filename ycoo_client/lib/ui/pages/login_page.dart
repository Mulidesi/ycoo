import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/site_config.dart';
import '../../state/app_state.dart';
import '../theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscure = true;
  bool _remember = true;
  bool _showQuestion = false;
  bool _loading = false;
  int _questionId = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _remember = s.rememberPassword;
    if (s.savedUsername.isNotEmpty) _userCtrl.text = s.savedUsername;
    if (s.savedPassword.isNotEmpty) _passCtrl.text = s.savedPassword;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<AppState>().login(
            _userCtrl.text.trim(),
            _passCtrl.text,
            questionId: _questionId,
            answer: _answerCtrl.text.trim(),
            remember: _remember,
          );
      if (!mounted) return;
      if (!res.success) {
        setState(() => _error = res.message);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final wide = size.width >= 720;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0B1B3A), Color(0xFF173C8F), Color(0xFF2563EB)],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _blurCircle(260, Colors.lightBlueAccent.withOpacity(0.35)),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: _blurCircle(300, Colors.indigoAccent.withOpacity(0.35)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 420 : 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 40,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 域名选择：登录哪个域名，该域名即为 APP 主域名
                              _domainSelector(),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _userCtrl,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: const InputDecoration(
                                  hintText: '用户名 / UID / 邮箱',
                                  prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passCtrl,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  hintText: '密码',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 19,
                                    ),
                                    onPressed: () => setState(() => _obscure = !_obscure),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _remember,
                                    onChanged: (v) => setState(() => _remember = v ?? true),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const Text('记住密码', style: TextStyle(fontSize: 13)),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => setState(() => _showQuestion = !_showQuestion),
                                    child: Text(
                                      _showQuestion ? '收起安全提问' : '安全提问',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              if (_showQuestion) ...[
                                const SizedBox(height: 4),
                                DropdownButtonFormField<int>(
                                  value: _questionId,
                                  decoration: const InputDecoration(
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 0, child: Text('未设置（默认）')),
                                    DropdownMenuItem(value: 1, child: Text('母亲的名字')),
                                    DropdownMenuItem(value: 2, child: Text('爷爷的名字')),
                                    DropdownMenuItem(value: 3, child: Text('父亲出生的城市')),
                                    DropdownMenuItem(value: 4, child: Text('其中一位老师的名字')),
                                    DropdownMenuItem(value: 5, child: Text('个人计算机的型号')),
                                    DropdownMenuItem(value: 6, child: Text('最喜欢的餐馆名称')),
                                    DropdownMenuItem(value: 7, child: Text('驾驶执照最后四位数字')),
                                  ],
                                  onChanged: (v) => setState(() => _questionId = v ?? 0),
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _answerCtrl,
                                  decoration: const InputDecoration(hintText: '安全提问答案'),
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFDECEC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.error_outline, size: 17, color: Color(0xFFD93025)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: _loading ? null : _submit,
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppTheme.brand,
                                  minimumSize: const Size(0, 52),
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('登录'),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '没有账号？',
                                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                                  ),
                                  TextButton(
                                    onPressed: () => _openRegister(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('去源论坛注册', style: TextStyle(fontSize: 12.5)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Builder(builder: (c) {
                        final origin = c.watch<AppState>().site.origin;
                        return Text(
                          '第三方客户端 · 账号密码仅用于直连 $origin 登录\n登录信息保存在本机，不会上传到任何其他服务器',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11.5, color: Colors.white70, height: 1.6),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blurCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );

  /// 域名选择器：登录所选域名会成为 APP 主域名（持久化）。
  /// 切换即生效——登录请求、内容解析都发往该域名。
  Widget _domainSelector() {
    final st = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.dns_rounded, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text('登录域名', style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            const Spacer(),
            Text(
              '两个域名数据互通',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            for (final site in ForumSite.all)
              ButtonSegment(
                value: site.id,
                label: Text(
                  site.baseUrl.host,
                  style: const TextStyle(fontSize: 12.5),
                ),
              ),
          ],
          selected: {st.settings.siteId},
          onSelectionChanged: (selection) {
            final id = selection.first;
            if (id == st.settings.siteId) return;
            // 切换主域名：清空旧域名 Cookie，后续登录 / 请求都发往新域名
            st.switchSite(id);
          },
        ),
      ],
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF60A5FA), Color(0xFF2563EB)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.blueAccent.withOpacity(0.45), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '源',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '源坛',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 4),
        ),
        const SizedBox(height: 6),
        const Text(
          '书源 · 资源 · 交流',
          style: TextStyle(fontSize: 13, color: Colors.white70, letterSpacing: 2),
        ),
      ],
    );
  }

  void _openRegister(BuildContext context) {
    final origin = context.read<AppState>().site.origin;
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('注册账号'),
        content: Text(
          '源论坛采用邀请 / 限时开放注册。\n请在浏览器打开 $origin 完成注册后再回到这里登录。',
          style: const TextStyle(height: 1.6, fontSize: 13.5),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('知道了'))],
      ),
    );
  }
}
