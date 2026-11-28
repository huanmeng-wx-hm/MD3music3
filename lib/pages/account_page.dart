import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/kugou_api/kugou_api_client.dart';

/// 右栏：账号 / 会员 / 关于。登录走旧仓那套二维码 API。
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with WidgetsBindingObserver {
  final _api = KugouApiClient();
  bool _logged = false;
  String _nickname = '未登录';
  String _vip = '—';

  Timer? _qrTimer;
  bool _qrActive = false;
  bool _pollInFlight = false;
  bool _dialogOpen = false;
  String? _qrKey;
  final ValueNotifier<String> _qrStatus = ValueNotifier<String>('等待扫码…');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    _stopPolling();
    _qrStatus.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从酷狗 App 切回来时立刻补一次检查，不用干等 2 秒周期。
    if (state == AppLifecycleState.resumed && _qrActive) {
      _pollOnce();
    }
  }

  Future<void> _refresh() async {
    final ok = await _api.isLoggedInWhenReady();
    String nick = '未登录';
    String vip = '—';
    if (ok) {
      final u = await _api.getUserDetail();
      nick = (u?.nickname != null && u!.nickname!.isNotEmpty)
          ? u.nickname!
          : '已登录';
      final v = await _api.getUserVipDetail();
      if (v == null) {
        vip = '未获取';
      } else if (v.isVip) {
        vip = 'VIP · 到期 ${v.conceptExpireTime ?? v.expireTime ?? "未知"}';
      } else {
        vip = '非会员';
      }
    }
    if (mounted) {
      setState(() {
        _logged = ok;
        _nickname = nick;
        _vip = vip;
      });
    }
  }

  void _stopPolling() {
    _qrTimer?.cancel();
    _qrTimer = null;
    _qrActive = false;
    _pollInFlight = false;
  }

  Future<void> _pollOnce() async {
    if (!_qrActive || _pollInFlight || _qrKey == null) return;
    _pollInFlight = true;
    try {
      final c = await _api.checkLoginQr(_qrKey!);
      final s = c?.status;
      if (s == 4) {
        // 登录成功。原仓是 KugouProvider.checkQrCode() 在这里落盘凭证，
        // 而 checkLoginQr() 本身只返回状态，不写 token —— 从零版漏了这步。
        if (c?.token != null && c?.userid != null) {
          await _api.setLoginCookies(
            c!.token!,
            c.userid!,
            vipToken: c.vipToken,
          );
          _qrStatus.value = '登录成功';
          _stopPolling();
          if (mounted && _dialogOpen) {
            Navigator.of(context).pop();
          }
          if (mounted) await _refresh();
        } else {
          _qrStatus.value = '登录响应缺少凭证，请刷新二维码重试';
        }
      } else if (s == 2 || s == 803) {
        _qrStatus.value = '已扫码，请在手机上确认登录';
      } else if (s == 1) {
        _qrStatus.value = '等待扫码…';
      } else if (s == 0 || s == 800) {
        _qrStatus.value = '二维码已过期，请重新点登录';
        _stopPolling();
      }
      // 其它状态 / null：网络抖动或中间态，下个周期继续，不中途放弃。
    } catch (_) {
      // 单次请求失败不中断轮询。
    } finally {
      _pollInFlight = false;
    }
  }

  Future<void> _login() async {
    if (_qrActive) return;
    final key = await _api.getLoginQrKey();
    if (key?.qrcode == null) {
      _toast('二维码获取失败，请重试');
      return;
    }
    final qr = await _api.createLoginQr(key!.qrcode!);
    if (qr?.base64 == null) {
      _toast('二维码生成失败，请重试');
      return;
    }
    Uint8List bytes;
    try {
      final raw = qr!.base64!.contains(',')
          ? qr.base64!.split(',').last
          : qr.base64!;
      bytes = base64Decode(raw);
    } catch (_) {
      _toast('二维码图片解析失败');
      return;
    }
    if (!mounted) return;

    _qrKey = key.qrcode!;
    _qrStatus.value = '等待扫码…';
    _qrActive = true;
    _pollInFlight = false;
    _dialogOpen = true;

    // 关键：轮询必须在弹窗打开期间就跑起来。
    // 写在 await showDialog(...) 后面的话，要等弹窗关掉才开始，
    // 用户扫码时 App 一个请求都不发 —— 就是"切回来没反应"。
    _qrTimer = Timer.periodic(const Duration(seconds: 2), (_) => _pollOnce());

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('扫码登录'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: Image.memory(bytes, fit: BoxFit.contain),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: _qrStatus,
              builder: (_, v, __) => Text(v, textAlign: TextAlign.center),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _stopPolling();
              _dialogOpen = false;
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
    // 无论是登录成功自动关、还是取消 / 返回键关，都别留后台轮询。
    _dialogOpen = false;
    _stopPolling();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: ListView(
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(_nickname),
            subtitle: Text(_logged ? '酷狗账号已登录' : '点此扫码登录'),
            onTap: _logged ? null : _login,
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('会员'),
            subtitle: Text(_vip),
            onTap: _refresh,
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于'),
            subtitle: Text('MD3Music3 · 1.0.0+1 · 轻量下载播放器'),
          ),
        ],
      ),
    );
  }
}
