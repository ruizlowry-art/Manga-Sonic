import 'package:flutter/material.dart';
import 'package:manga_sonic/features/browse/site_screen.dart';

class SiteListTab extends StatefulWidget {
  const SiteListTab({super.key});

  @override
  State<SiteListTab> createState() => _SiteListTabState();
}

class _SiteListTabState extends State<SiteListTab> {
  static const List<Map<String, String>> _sites = [
    {
      'name': 'ManhuaTop',
      'url': 'https://manhuatop.org/',
      'logoUrl':
          'https://www.google.com/s2/favicons?domain=manhuatop.org&sz=128',
    },
    {
      'name': 'AsuraComic',
      'url': 'https://asurascans.com/',
      'logoUrl': 'https://asurascans.com/images/logo.webp',
    },
    {
      'name': 'ManhuaPlus',
      'url': 'https://manhuaplus.top/',
      'logoUrl':
          'https://www.google.com/s2/favicons?domain=manhuaplus.top&sz=128',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView.builder(
          itemCount: _sites.length + 3,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: 10.0,
                ),
                child: Text(
                  'MangaSonic',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              );
            }
            if (index == 1) {
              return const Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 10.0,
                  bottom: 8.0,
                ),
                child: Text(
                  'AVAILABLE SOURCES',
                  style: TextStyle(
                    color: Colors.blueGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              );
            }
            if (index == _sites.length + 2) {
              return const SizedBox.shrink();
            }

            final site = _sites[index - 2];
            final isCustom = site['isCustom'] == 'true';
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4.0,
              ),
              child: Card(
                color: const Color(0xFF1E1E24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Builder(
                        builder: (context) {
                          if (site['logoUrl'] != null) {
                            return Image.network(
                              site['logoUrl']!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, err, trace) => Icon(
                                Icons.public,
                                color: Theme.of(context).primaryColor,
                              ),
                            );
                          }
                          return Icon(
                            Icons.public,
                            color: Theme.of(context).primaryColor,
                          );
                        },
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          site['name']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCustom) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CUSTOM',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    site['url']!.replaceAll('https://', '').replaceAll('/', ''),
                    style: const TextStyle(
                      color: Colors.blueGrey,
                      fontSize: 12,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiteScreen(
                          siteName: site['name']!,
                          siteUrl: site['url']!,
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
