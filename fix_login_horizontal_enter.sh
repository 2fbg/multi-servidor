#!/usr/bin/env bash
set -e

echo "== Corrigindo login horizontal, botão Entrar e Enter =="

if [ ! -f "pubspec.yaml" ]; then
  echo "ERRO: rode dentro da pasta do projeto Flutter."
  exit 1
fi

mkdir -p backup_fix_login
cp lib/main.dart "backup_fix_login/main_$(date +%Y%m%d_%H%M%S).dart"

python3 - <<'PY'
from pathlib import Path

p = Path("lib/main.dart")
txt = p.read_text()

start = txt.find("class LoginPage extends StatefulWidget")
end = txt.find("class HomePage extends StatefulWidget", start)

if start == -1 or end == -1:
    raise SystemExit("Não encontrei LoginPage ou HomePage para substituir.")

new_login = r'''
class LoginPage extends StatefulWidget {
  final VoidCallback onLogin;
  const LoginPage({super.key, required this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final userCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  final userFocus = FocusNode();
  final passFocus = FocusNode();

  bool hide = true;
  bool savePassword = true;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    loadSaved();
  }

  @override
  void dispose() {
    userCtrl.dispose();
    passCtrl.dispose();
    userFocus.dispose();
    passFocus.dispose();
    super.dispose();
  }

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();

    userCtrl.text = prefs.getString('login_user') ?? '';
    passCtrl.text = prefs.getString('login_pass') ?? '';
    savePassword = prefs.getBool('save_password') ?? true;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> save() async {
    if (submitting) return;

    final user = userCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite usuário e senha para entrar.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => submitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('login_user', user);
      await prefs.setBool('save_password', savePassword);

      if (savePassword) {
        await prefs.setString('login_pass', pass);
        await prefs.remove('erase_password_on_next_logout');
      } else {
        // Mantém a senha somente até sair do app pelo botão Sair.
        await prefs.setString('login_pass', pass);
        await prefs.setBool('erase_password_on_next_logout', true);
      }

      if (mounted) {
        widget.onLogin();
      }
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  Widget loginContent(double maxHeight) {
    final compact = maxHeight < 520;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Card(
        color: kPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 26 : 32,
            vertical: compact ? 18 : 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.live_tv,
                color: kRed,
                size: compact ? 44 : 58,
              ),
              SizedBox(height: compact ? 6 : 12),
              Text(
                'Multi Servidor',
                style: TextStyle(
                  fontSize: compact ? 34 : 42,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: compact ? 16 : 24),
              TextField(
                controller: userCtrl,
                focusNode: userFocus,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.text,
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(passFocus);
                },
                decoration: const InputDecoration(
                  labelText: 'Usuário',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              SizedBox(height: compact ? 10 : 14),
              TextField(
                controller: passCtrl,
                focusNode: passFocus,
                obscureText: hide,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.visiblePassword,
                onSubmitted: (_) => save(),
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: hide ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(hide ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => hide = !hide),
                  ),
                ),
              ),
              SizedBox(height: compact ? 6 : 10),
              Row(
                children: [
                  Checkbox(
                    value: savePassword,
                    activeColor: kRed,
                    onChanged: (v) => setState(() => savePassword = v ?? true),
                  ),
                  const Expanded(
                    child: Text(
                      'Salvar senha neste aparelho',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 14),
              SizedBox(
                width: double.infinity,
                height: compact ? 46 : 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: kRed),
                  onPressed: submitting ? null : save,
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.login),
                  label: Text(submitting ? 'Entrando...' : 'Entrar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: loginContent(constraints.maxHeight),
              ),
            );
          },
        ),
      ),
    );
  }
}

'''

txt = txt[:start] + new_login + "\n" + txt[end:]
p.write_text(txt)
print("Login substituído com sucesso.")
PY

dart format lib/main.dart
flutter analyze 2>&1 | tail -n 40

echo ""
echo "Se não tiver ERROR acima, envie:"
echo "git add ."
echo "git commit -m 'Corrige login horizontal e enter para entrar'"
echo "git push"
