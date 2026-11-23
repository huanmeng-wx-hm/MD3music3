import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/kugou_api/kugou_api_client.dart';
import '../services/kugou_api/kugou_models.dart';

/// 右栏：账号 / 会员 / 关于。登录走旧仓那套二维码 API。
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _api = KugouApiClient();
  bool _logged = false;
  String _nickname = '未登录';
  String _vip = '—';

  @override
  void initState() {
    super.initState();
    _refresh();
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

  Future<void> _login() async {
    final key = await _api.getLoginQrKey();
    if (key?.qrcode == null) return;
    final qr = await _api.createLoginQr(key!.qrcode!);
    if (qr?.base64 == null || !mounted) return;
    final bytes = base64Decode(
        qr!.base64!.contains(',') ? qr.base64!.split(',').last : qr.base64!);
    Timer? timer;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('扫码登录'),
        content: SizedBox(
          width: 220,
          height: 220,
          child: Image.memory(bytes, fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
            onPressed: () {
              timer?.cancel();
              Navigator.pop(ctx);
            },
            child: const Text('取消'),
          ),
        ],
      ),
    );
    timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      final c = await _api.checkLoginQr(key.qrcode!);
      if (c?.token != null || c?.status == 2) {
        t.cancel();
        await _refresh();
      }
    });
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
