import 'package:flutter/material.dart';

class TeamLogoWidget extends StatelessWidget {
  final String? url;
  final String teamName;
  final double size;

  const TeamLogoWidget({
    super.key,
    required this.url,
    required this.teamName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = url?.trim() ?? '';
    final hasValidUrl = cleanUrl.isNotEmpty &&
        cleanUrl != 'null' &&
        cleanUrl.startsWith('http');

    final initial = teamName.trim().isNotEmpty
        ? teamName.trim().substring(0, 1).toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF22283A),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF333D56), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasValidUrl
            ? Image.network(
                cleanUrl,
                width: size,
                height: size,
                fit: BoxFit.contain,
                headers: const {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                  'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
                },
                errorBuilder: (context, error, stackTrace) => _fallback(initial),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: SizedBox(
                      width: size * 0.45,
                      height: size * 0.45,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white38,
                      ),
                    ),
                  );
                },
              )
            : _fallback(initial),
      ),
    );
  }

  Widget _fallback(String initial) {
    return Container(
      color: const Color(0xFF2A3145),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.42,
          ),
        ),
      ),
    );
  }
}
