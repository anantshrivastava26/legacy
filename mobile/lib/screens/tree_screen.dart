import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'person_detail_screen.dart';

/// Family tree with pinch-zoom and pan (InteractiveViewer).
/// People are laid out by generation; parent-child lines are drawn
/// with a CustomPainter.
class TreeScreen extends StatefulWidget {
  final String familyId;
  const TreeScreen({super.key, required this.familyId});

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  List<TreeNode> nodes = [];
  List<TreeEdge> edges = [];
  bool loading = true;

  static const double cardWidth = 150;
  static const double cardHeight = 76;
  static const double hGap = 26;
  static const double vGap = 90;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AppState>().api;
      final res = await api.get('/api/families/${widget.familyId}/tree');
      if (mounted) {
        setState(() {
          nodes =
              (res['nodes'] as List).map((e) => TreeNode.fromJson(e)).toList();
          edges =
              (res['edges'] as List).map((e) => TreeEdge.fromJson(e)).toList();
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => loading = false);
        showError(context, e);
      }
    }
  }

  /// Positions for each node, grouped by generation rows.
  Map<String, Offset> _layout() {
    final byGen = <int, List<TreeNode>>{};
    for (final n in nodes) {
      byGen.putIfAbsent(n.generation, () => []).add(n);
    }
    final generations = byGen.keys.toList()..sort();
    final positions = <String, Offset>{};
    final maxRowCount = byGen.values
        .map((l) => l.length)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final totalWidth = maxRowCount * (cardWidth + hGap);

    for (final gen in generations) {
      final row = byGen[gen]!;
      // Keep spouses next to each other
      row.sort((a, b) => a.lastName.compareTo(b.lastName));
      final rowWidth = row.length * (cardWidth + hGap);
      final startX = (totalWidth - rowWidth) / 2;
      for (var i = 0; i < row.length; i++) {
        positions[row[i].id] = Offset(
          startX + i * (cardWidth + hGap) + hGap / 2,
          gen * (cardHeight + vGap) + 40,
        );
      }
    }
    return positions;
  }

  @override
  Widget build(BuildContext context) {
    final positions = _layout();
    final maxX = positions.values
        .map((o) => o.dx)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = positions.values
        .map((o) => o.dy)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final canvasSize = Size(maxX + cardWidth + 60, maxY + cardHeight + 60);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Tree')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : nodes.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text(
                      'The tree is empty.\nAdd your first family member to begin!',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 20, color: AppColors.textMuted),
                    ),
                  ),
                )
              : InteractiveViewer(
                  constrained: false,
                  minScale: 0.3,
                  maxScale: 3.0,
                  boundaryMargin: const EdgeInsets.all(200),
                  child: SizedBox(
                    width: canvasSize.width,
                    height: canvasSize.height,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: canvasSize,
                          painter: _EdgePainter(
                            positions: positions,
                            edges: edges,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                          ),
                        ),
                        for (final n in nodes)
                          if (positions.containsKey(n.id))
                            Positioned(
                              left: positions[n.id]!.dx,
                              top: positions[n.id]!.dy,
                              child: _NodeCard(
                                node: n,
                                width: cardWidth,
                                height: cardHeight,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(
                                      familyId: widget.familyId,
                                      personId: n.id,
                                      canEdit: true,
                                    ),
                                  ),
                                ).then((_) => _load()),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final TreeNode node;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _NodeCard({
    required this.node,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = switch (node.gender) {
      'MALE' => AppColors.peacock,
      'FEMALE' => AppColors.maroon,
      _ => AppColors.gold,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: node.isLiving ? Colors.white : const Color(0xFFF0E8DC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent, width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              node.fullName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark),
            ),
            if (node.dateOfBirth != null)
              Text(
                'b. ${node.dateOfBirth!.year}',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _EdgePainter extends CustomPainter {
  final Map<String, Offset> positions;
  final List<TreeEdge> edges;
  final double cardWidth;
  final double cardHeight;

  _EdgePainter({
    required this.positions,
    required this.edges,
    required this.cardWidth,
    required this.cardHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final parentPaint = Paint()
      ..color = AppColors.peacock
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final spousePaint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (final e in edges) {
      final from = positions[e.fromPersonId];
      final to = positions[e.toPersonId];
      if (from == null || to == null) continue;

      if (e.type == 'SPOUSE') {
        final a = Offset(from.dx + cardWidth, from.dy + cardHeight / 2);
        final b = Offset(to.dx, to.dy + cardHeight / 2);
        canvas.drawLine(a, b, spousePaint);
      } else {
        // parent bottom-center -> child top-center, elbow line
        final start = Offset(from.dx + cardWidth / 2, from.dy + cardHeight);
        final end = Offset(to.dx + cardWidth / 2, to.dy);
        final midY = (start.dy + end.dy) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(start.dx, midY)
          ..lineTo(end.dx, midY)
          ..lineTo(end.dx, end.dy);
        canvas.drawPath(path, parentPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) =>
      oldDelegate.positions != positions || oldDelegate.edges != edges;
}
