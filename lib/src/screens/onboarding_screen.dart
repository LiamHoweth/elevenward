import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

final class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final pages = <({IconData icon, String title, String body})>[
      (
        icon: Icons.offline_bolt_outlined,
        title: uiCopy(locale, 'onboardingOfflineTitle'),
        body: uiCopy(locale, 'onboardingOfflineBody'),
      ),
      (
        icon: Icons.fitness_center_rounded,
        title: uiCopy(locale, 'onboardingFocusTitle'),
        body: uiCopy(locale, 'onboardingFocusBody'),
      ),
      (
        icon: Icons.flare_rounded,
        title: uiCopy(locale, 'onboardingLifeTitle'),
        body: uiCopy(locale, 'onboardingLifeBody'),
      ),
    ];
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/visual/stadium-graphite.png',
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  ElevenwardColors.ink.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? .65
                        : .9,
                  ),
                  ElevenwardColors.ink,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: Text(uiCopy(locale, 'skip')),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    onPageChanged: (value) => setState(() => _page = value),
                    itemBuilder: (context, index) {
                      final item = pages[index];
                      return Semantics(
                        namesRoute: true,
                        label:
                            '${uiCopy(locale, 'step')} ${index + 1} ${uiCopy(locale, 'of')} ${pages.length}',
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 24,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: ElevenwardColors.grassDark,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Icon(
                                  item.icon,
                                  size: 42,
                                  color: ElevenwardColors.grass,
                                ),
                              ),
                              const SizedBox(height: 28),
                              Text(
                                item.title,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displaySmall,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                item.body,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: ElevenwardColors.muted,
                                  fontSize: 17,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          pages.length,
                          (index) => Container(
                            width: index == _page ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: index == _page
                                  ? ElevenwardColors.grass
                                  : ElevenwardColors.line,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton(
                        onPressed: _finishing
                            ? null
                            : () => _next(pages.length),
                        child: Text(
                          _page == pages.length - 1
                              ? uiCopy(locale, 'startCareer')
                              : uiCopy(locale, 'continue'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _next(int count) async {
    if (_page == count - 1) return _finish();
    await _pageController.nextPage(
      duration: motionDuration(context, const Duration(milliseconds: 240)),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    await widget.onComplete();
  }
}
