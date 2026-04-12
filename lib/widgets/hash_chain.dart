import 'package:flutter/material.dart';

class HashChainVisualization extends StatelessWidget {
  const HashChainVisualization({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 18, color: Color(0xFF0EA5E9)),
              const SizedBox(width: 8),
              const Text(
                'HASH CHAIN VISUALIZATION',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                    SizedBox(width: 6),
                    Text('CHAIN SYNCHRONIZED',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _chainBlock(
                  number: '#8,421', hash: '0x9E1...2E', isCurrent: false),
              _arrow(),
              _chainBlock(
                  number: '#8,422', hash: '0x7D4...F3A', isCurrent: true),
              _arrow(),
              _chainBlock(
                  number: '#8,423', hash: '0x4B2...A98', isCurrent: false),
            ],
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'CURRENT STATE: UNBROKEN',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                  letterSpacing: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chainBlock(
      {required String number, required String hash, required bool isCurrent}) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF0EA5E9).withOpacity(0.1)
            : const Color(0xFF0A0E17),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isCurrent
                ? const Color(0xFF0EA5E9)
                : Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(number,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(hash,
              style: const TextStyle(
                  fontFamily: 'monospace', fontSize: 9, color: Colors.white54)),
          if (isCurrent)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('ACTIVE HEAD',
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0EA5E9))),
            ),
        ],
      ),
    );
  }

  Widget _arrow() {
    return Icon(Icons.arrow_forward,
        size: 20, color: Colors.white.withOpacity(0.3));
  }
}
