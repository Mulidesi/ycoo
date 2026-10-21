import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycoo_client/core/storage/automation_models.dart';
import 'package:ycoo_client/state/app_state.dart';

/// 自动回复预设初始化：
/// 首次启动 / 老版本升级 / 预设被清空，三种情况都必须有内容可发。
void main() {
  group('默认预设', () {
    test('首次启动就带满 5 条默认预设', () {
      final s = AppSettings();
      expect(s.replyPresets, isNotEmpty);
      expect(s.effectivePresets.length, Preset.maxCount);
      expect(s.effectivePresets.first.text, AppSettings.defaultReplyPresets.first);
      expect(s.primaryReplyContent, isNotEmpty);
    });

    test('默认预设全部合法：非空、不超长、互不重复', () {
      const texts = AppSettings.defaultReplyPresets;
      expect(texts.length, Preset.maxCount);
      expect(texts.toSet().length, texts.length, reason: '默认预设不能重复');
      for (final t in texts) {
        expect(t.trim(), isNotEmpty);
        expect(t.length, lessThanOrEqualTo(Preset.maxLength));
      }
    });

    test('默认预设不含占位符残留（避免回复里出现 {author}）', () {
      for (final t in AppSettings.defaultReplyPresets) {
        expect(t.contains('{'), isFalse, reason: t);
      }
    });
  });

  group('升级 / 异常输入', () {
    test('老版本存了空数组 → 补默认预设', () {
      final s = AppSettings.fromJson(<String, dynamic>{
        'replyPresets': <String>[],
        'replyContent': '感谢分享，感谢楼主！',
      });
      expect(s.effectivePresets.length, Preset.maxCount);
    });

    test('老版本只有自定义 replyContent → 沿用它', () {
      final s = AppSettings.fromJson(<String, dynamic>{'replyContent': '自定义回复内容'});
      expect(s.effectivePresets.single.text, '自定义回复内容');
    });

    test('预设全是空白 → 回落到默认预设', () {
      final s = AppSettings(replyPresets: <String>['  ', '', '\t']);
      expect(s.effectivePresets.length, Preset.maxCount);
    });

    test('预设超长（>200）被丢弃，剩空的回落到默认', () {
      final long = 'x' * 201;
      final s = AppSettings(replyPresets: <String>[long]);
      expect(s.effectivePresets.length, Preset.maxCount);
    });

    test('老版本只存了一条内置默认语 → 升级为整套默认预设', () {
      final s = AppSettings.fromJson(<String, dynamic>{
        'replyPresets': <String>[AppSettings.defaultReplyPresets.first],
      });
      expect(s.effectivePresets.length, Preset.maxCount);
    });

    test('正常预设原样保留，不会被默认值覆盖', () {
      final s = AppSettings(replyPresets: <String>['A', 'B']);
      expect(s.effectivePresets.map((e) => e.text).toList(), <String>['A', 'B']);
    });

    test('toJson / fromJson 往返不丢预设', () {
      final s = AppSettings(replyPresets: <String>['第一条', '第二条']);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.effectivePresets.map((e) => e.text).toList(), <String>['第一条', '第二条']);
    });
  });

  group('保存与队列同步', () {
    test('清空预设保存后回落到默认，队列仍有可用预设', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.init();

      await st.updateReplyPresets(<String>['', '   ']);

      expect(st.settings.replyPresets, isNotEmpty);
      expect(st.settings.effectivePresets.length, Preset.maxCount);
      expect(st.replyQueue.validPresetCount, Preset.maxCount);
      // 首条预设同步到兼容字段
      expect(st.settings.replyContent, st.settings.effectivePresets.first.text);
      st.dispose();
    });

    test('首次 init 后队列即可用（无需手动设置预设）', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final st = AppState();
      await st.init();

      expect(st.replyQueue.validPresetCount, greaterThan(0));
      // 引擎能挑出一条预设并渲染
      final preset = st.automation.pickPreset(st.settings.effectivePresets);
      expect(preset.text.trim(), isNotEmpty);
      st.dispose();
    });

    test('老版本配置（空预设 + 旧 replyContent）init 后队列可用', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'settings': '{"replyPresets":[],"replyContent":"感谢分享，感谢楼主！","autoReply":true}',
      });
      final st = AppState();
      await st.init();

      expect(st.replyQueue.validPresetCount, Preset.maxCount);
      st.dispose();
    });
  });
}
